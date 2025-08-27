#!/bin/bash
set -e

echo "::group::Steam Deploy - Starting deployment"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# SteamCMD のインストール先を決定
# 優先順位: RUNNER_TEMP > TMPDIR > /tmp > checkout directory
if [ -n "${RUNNER_TEMP}" ]; then
    STEAMCMD_DIR="${RUNNER_TEMP}/steamcmd"
elif [ -n "${TMPDIR}" ]; then
    STEAMCMD_DIR="${TMPDIR}/steamcmd"
elif [ -d "/tmp" ]; then
    STEAMCMD_DIR="/tmp/steamcmd_$$"
else
    STEAMCMD_DIR="${GITHUB_WORKSPACE:-.}/.steamcmd"
fi

STEAMCMD_BIN="${STEAMCMD_DIR}/steamcmd.sh"
echo "SteamCMD will be installed to: ${STEAMCMD_DIR}"

detect_os() {
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "::error::Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
}

download_steamcmd() {
    local os_type="$1"
    
    echo "::group::Downloading SteamCMD for ${os_type}"
    
    if [ -f "${STEAMCMD_BIN}" ]; then
        echo "SteamCMD already exists at ${STEAMCMD_BIN}"
    else
        mkdir -p "${STEAMCMD_DIR}"
        cd "${STEAMCMD_DIR}"
        
        if [ "${os_type}" = "linux" ]; then
            echo "Downloading SteamCMD for Linux..."
            curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
        elif [ "${os_type}" = "macos" ]; then
            echo "Downloading SteamCMD for macOS..."
            curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz" | tar zxvf -
        fi
        
        chmod +x "${STEAMCMD_BIN}"
    fi
    
    echo "::endgroup::"
}

setup_config_vdf() {
    echo "::group::Setting up config.vdf"
    
    CONFIG_DIR="${STEAMCMD_DIR}/config"
    mkdir -p "${CONFIG_DIR}"
    
    echo "${STEAM_CONFIG_VDF}" | base64 -d > "${CONFIG_DIR}/config.vdf"
    
    if [ ! -f "${CONFIG_DIR}/config.vdf" ]; then
        echo "::error::Failed to create config.vdf"
        exit 1
    fi
    
    echo "config.vdf has been created at ${CONFIG_DIR}/config.vdf"
    echo "::endgroup::"
}

prepare_vdf_file() {
    echo "::group::Preparing VDF file" >&2
    
    local vdf_file="${VDF_PATH}"
    
    if [ -z "${vdf_file}" ] || [ ! -f "${vdf_file}" ]; then
        vdf_file="${STEAMCMD_DIR}/app_build_${STEAM_APP_ID}.vdf"
        
        # ROOT_PATH を絶対パスに変換
        local content_root="${ROOT_PATH:-.}"
        if [[ "${content_root}" != /* ]]; then
            # 相対パスの場合、GITHUB_WORKSPACE または現在のディレクトリからの絶対パスに変換
            if [ -n "${GITHUB_WORKSPACE}" ]; then
                content_root="${GITHUB_WORKSPACE}/${content_root}"
            else
                content_root="$(cd "${content_root}" 2>/dev/null && pwd)" || content_root="$(pwd)/${content_root}"
            fi
        fi
        
        echo "Creating VDF file at ${vdf_file}" >&2
        echo "Content root: ${content_root}" >&2
        cat > "${vdf_file}" << EOF
"appbuild"
{
    "appid" "${STEAM_APP_ID}"
    "desc" "${BUILD_DESCRIPTION}"
    "buildoutput" "${STEAMCMD_DIR}/steam_content/logs"
    "contentroot" "${content_root}"
    "setlive" ""
    "preview" "0"
    "local" ""
    
    "depots"
    {
EOF

        # 9つの depot をチェック
        for i in 1 2 3 4 5 6 7 8 9; do
            depot_id_var="DEPOT${i}_ID"
            depot_path_var="DEPOT${i}_PATH"
            depot_id="${!depot_id_var}"
            depot_path="${!depot_path_var}"
            
            # Path が設定されている場合
            if [ -n "${depot_path}" ]; then
                # ID が指定されていない場合は自動生成（App ID + 番号）
                if [ -z "${depot_id}" ]; then
                    depot_id=$((STEAM_APP_ID + i))
                    echo "Auto-generating Depot ${i} ID: ${depot_id}" >&2
                fi
                
                # depot_path をそのまま使用（ContentRoot からの相対パスとして）
                echo "Depot ${i} path: ${depot_path}" >&2
                
                cat >> "${vdf_file}" << EOF
        "${depot_id}"
        {
            "FileMapping"
            {
                "LocalPath" "./${depot_path}/*"
                "DepotPath" "."
                "recursive" "1"
            }
            "FileExclusion" "*.DS_Store"
        }
EOF
            elif [ -n "${depot_id}" ]; then
                echo "::warning::Depot ${i}: ID specified but Path is missing (ID: ${depot_id})" >&2
            fi
        done
        
        echo '    }' >> "${vdf_file}"
        echo '}' >> "${vdf_file}"
    fi
    
    echo "VDF file prepared at ${vdf_file}" >&2
    echo "::endgroup::" >&2
    
    # 標準出力にはファイルパスのみを返す
    echo "${vdf_file}"
}

install_dependencies() {
    local os_type="$1"
    
    echo "::group::Installing dependencies for ${os_type}"
    
    if [ "${os_type}" = "macos" ]; then
        echo "Checking for required macOS dependencies..."
    elif [ "${os_type}" = "linux" ]; then
        if command -v apt-get &> /dev/null; then
            echo "Installing Linux dependencies (lib32gcc1)..."
            sudo apt-get update -qq
            sudo apt-get install -y lib32gcc1 || sudo apt-get install -y lib32gcc-s1
        elif command -v yum &> /dev/null; then
            echo "Installing Linux dependencies (glibc.i686)..."
            sudo yum install -y glibc.i686 libstdc++.i686
        fi
    fi
    
    echo "::endgroup::"
}

run_steamcmd_deployment() {
    local vdf_file="$1"
    
    echo "::group::Running SteamCMD deployment"
    
    local steamcmd_script="${STEAMCMD_DIR}/steamcmd_script.txt"
    cat > "${steamcmd_script}" << EOF
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir ${STEAMCMD_DIR}/steam_content
login ${STEAM_USERNAME}
run_app_build "${vdf_file}"
quit
EOF

    echo "Executing SteamCMD..."
    # 注: enum_names.cpp の警告は SteamCMD の既知のバグで無害です
    "${STEAMCMD_BIN}" +runscript "${steamcmd_script}" 2>&1 | grep -v "enum_names.cpp (2184)" || true
    
    local exit_code=${PIPESTATUS[0]}
    
    if [ ${exit_code} -ne 0 ]; then
        echo "::error::SteamCMD deployment failed with exit code ${exit_code}"
        
        # ログファイルの場所を確認
        local log_dir="${STEAMCMD_DIR}/steam_content/logs"
        if [ -f "${log_dir}/stderr.txt" ]; then
            echo "::group::SteamCMD Error Log"
            cat "${log_dir}/stderr.txt"
            echo "::endgroup::"
        fi
        
        exit ${exit_code}
    fi
    
    echo "::endgroup::"
}

cleanup() {
    echo "::group::Cleanup"
    
    # スクリプトファイルの削除
    if [ -f "${STEAMCMD_DIR}/steamcmd_script.txt" ]; then
        echo "Removing steamcmd_script.txt"
        rm -f "${STEAMCMD_DIR}/steamcmd_script.txt"
    fi
    
    # VDFファイルの削除
    if [ -f "${STEAMCMD_DIR}/app_build_${STEAM_APP_ID}.vdf" ]; then
        echo "Removing app_build_${STEAM_APP_ID}.vdf"
        rm -f "${STEAMCMD_DIR}/app_build_${STEAM_APP_ID}.vdf"
    fi
    
    # config.vdf の削除（セキュリティのため）
    if [ -f "${STEAMCMD_DIR}/config/config.vdf" ]; then
        echo "Removing config.vdf for security"
        rm -f "${STEAMCMD_DIR}/config/config.vdf"
    fi
    
    # 一時ディレクトリの場合は SteamCMD 全体を削除
    if [[ "${STEAMCMD_DIR}" == /tmp/* ]] || [[ "${STEAMCMD_DIR}" == "${RUNNER_TEMP}"/* ]] || [[ "${STEAMCMD_DIR}" == "${TMPDIR}"/* ]]; then
        echo "Removing temporary SteamCMD directory: ${STEAMCMD_DIR}"
        rm -rf "${STEAMCMD_DIR}"
    fi
    
    echo "::endgroup::"
}

validate_environment() {
    echo "::group::Validating environment"
    
    if [ -z "${STEAM_USERNAME}" ]; then
        echo "::error::STEAM_USERNAME is required"
        exit 1
    fi
    
    if [ -z "${STEAM_CONFIG_VDF}" ]; then
        echo "::error::STEAM_CONFIG_VDF is required"
        exit 1
    fi
    
    if [ -z "${STEAM_APP_ID}" ]; then
        echo "::error::STEAM_APP_ID is required"
        exit 1
    fi
    
    echo "Environment validation passed"
    echo "::endgroup::"
}

main() {
    validate_environment
    
    OS_TYPE=$(detect_os)
    echo "Detected OS: ${OS_TYPE}"
    
    install_dependencies "${OS_TYPE}"
    
    download_steamcmd "${OS_TYPE}"
    
    setup_config_vdf
    
    VDF_FILE=$(prepare_vdf_file)
    
    run_steamcmd_deployment "${VDF_FILE}"
    
    cleanup
    
    echo "::notice::Steam deployment completed successfully!"
}

# エラー時もクリーンアップを確実に実行
trap cleanup EXIT INT TERM
main "$@"