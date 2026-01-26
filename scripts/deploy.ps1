#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

Write-Host "::group::Steam Deploy - Starting deployment"

# SteamCMD installation directory
if ($env:RUNNER_TEMP) {
    $script:STEAMCMD_DIR = Join-Path $env:RUNNER_TEMP "steamcmd"
} elseif ($env:TEMP) {
    $script:STEAMCMD_DIR = Join-Path $env:TEMP "steamcmd"
} else {
    $script:STEAMCMD_DIR = Join-Path (Get-Location) ".steamcmd"
}

$script:STEAMCMD_BIN = Join-Path $STEAMCMD_DIR "steamcmd.exe"
Write-Host "SteamCMD will be installed to: $STEAMCMD_DIR"

function Validate-Environment {
    Write-Host "::group::Validating environment"

    if ($env:DRY_RUN -eq "true") {
        Write-Host "::notice::Dry run mode enabled - skipping credential validation"
        if (-not $env:STEAM_APP_ID) {
            Write-Host "::error::STEAM_APP_ID is required even in dry run mode"
            exit 1
        }
        Write-Host "Environment validation passed (dry run)"
        Write-Host "::endgroup::"
        return
    }

    if (-not $env:STEAM_USERNAME) {
        Write-Host "::error::STEAM_USERNAME is required"
        exit 1
    }

    if (-not $env:STEAM_CONFIG_VDF) {
        Write-Host "::error::STEAM_CONFIG_VDF is required"
        exit 1
    }

    if (-not $env:STEAM_APP_ID) {
        Write-Host "::error::STEAM_APP_ID is required"
        exit 1
    }

    Write-Host "Environment validation passed"
    Write-Host "::endgroup::"
}

function Download-SteamCMD {
    Write-Host "::group::Downloading SteamCMD for Windows"

    if (Test-Path $STEAMCMD_BIN) {
        Write-Host "SteamCMD already exists at $STEAMCMD_BIN"
    } else {
        New-Item -ItemType Directory -Force -Path $STEAMCMD_DIR | Out-Null

        $zipPath = Join-Path $STEAMCMD_DIR "steamcmd.zip"
        $url = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

        Write-Host "Downloading SteamCMD for Windows..."
        $retryCount = 0
        $maxRetries = 3
        $retryDelay = 5

        while ($retryCount -lt $maxRetries) {
            try {
                Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
                break
            } catch {
                $retryCount++
                if ($retryCount -eq $maxRetries) {
                    Write-Host "::error::Failed to download SteamCMD after $maxRetries attempts"
                    throw
                }
                Write-Host "Download failed, retrying in $retryDelay seconds... (attempt $retryCount/$maxRetries)"
                Start-Sleep -Seconds $retryDelay
            }
        }

        Write-Host "Extracting SteamCMD..."
        Expand-Archive -Path $zipPath -DestinationPath $STEAMCMD_DIR -Force
        Remove-Item $zipPath -Force
    }

    Write-Host "::endgroup::"
}

function Setup-ConfigVdf {
    Write-Host "::group::Setting up config.vdf"

    $configDir = Join-Path $STEAMCMD_DIR "config"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    $configPath = Join-Path $configDir "config.vdf"
    $decodedBytes = [System.Convert]::FromBase64String($env:STEAM_CONFIG_VDF)
    [System.IO.File]::WriteAllBytes($configPath, $decodedBytes)

    if (-not (Test-Path $configPath)) {
        Write-Host "::error::Failed to create config.vdf"
        exit 1
    }

    Write-Host "config.vdf has been created at $configPath"
    Write-Host "::endgroup::"
}

function Test-SteamLogin {
    Write-Host "::group::Testing Steam login"

    Write-Host "Testing login with user: $env:STEAM_USERNAME"

    # Login test (+quit to exit immediately)
    & $STEAMCMD_BIN +login $env:STEAM_USERNAME +quit 2>&1 | Where-Object { $_ -notmatch "enum_names.cpp \(2184\)" }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "::notice::Steam login successful!"
    } else {
        Write-Host "::error::Steam login failed with exit code $LASTEXITCODE"
        Write-Host "Please check your credentials and config.vdf"
        exit $LASTEXITCODE
    }

    Write-Host "::endgroup::"
}

function Prepare-VdfFile {
    Write-Host "::group::Preparing VDF file"

    $vdfFile = $env:VDF_PATH

    if (-not $vdfFile -or -not (Test-Path $vdfFile)) {
        $vdfFile = Join-Path $STEAMCMD_DIR "app_build_$env:STEAM_APP_ID.vdf"

        # Convert ROOT_PATH to absolute path
        $contentRoot = if ($env:ROOT_PATH) { $env:ROOT_PATH } else { "." }
        if (-not [System.IO.Path]::IsPathRooted($contentRoot)) {
            if ($env:GITHUB_WORKSPACE) {
                $contentRoot = Join-Path $env:GITHUB_WORKSPACE $contentRoot
            } else {
                $contentRoot = Join-Path (Get-Location) $contentRoot
            }
        }
        $contentRoot = (Resolve-Path $contentRoot).Path

        Write-Host "Creating VDF file at $vdfFile"
        Write-Host "Content root: $contentRoot"

        $vdfContent = @"
"appbuild"
{
    "appid" "$env:STEAM_APP_ID"
    "desc" "$env:BUILD_DESCRIPTION"
    "buildoutput" "$($STEAMCMD_DIR -replace '\\', '/')/steam_content/logs"
    "contentroot" "$($contentRoot -replace '\\', '/')"
    "setlive" "$env:RELEASE_BRANCH"
    "preview" "0"
    "local" ""

    "depots"
    {
"@

        # Check 9 depots
        for ($i = 1; $i -le 9; $i++) {
            $depotIdVar = "DEPOT${i}_ID"
            $depotPathVar = "DEPOT${i}_PATH"
            $depotId = [Environment]::GetEnvironmentVariable($depotIdVar)
            $depotPath = [Environment]::GetEnvironmentVariable($depotPathVar)

            if ($depotPath) {
                # Auto-generate ID if not specified
                if (-not $depotId) {
                    $depotId = [int]$env:STEAM_APP_ID + $i
                    Write-Host "Auto-generating Depot $i ID: $depotId"
                }

                Write-Host "Depot $i path: $depotPath"

                # Exclude debug files unless DEBUG_BRANCH is true
                if ($env:DEBUG_BRANCH -ne "true") {
                    $vdfContent += @"

        "$depotId"
        {
            "FileMapping"
            {
                "LocalPath" "./$depotPath/*"
                "DepotPath" "."
                "recursive" "1"
            }
            "FileExclusion" "*.DS_Store"
            "FileExclusion" "*.pdb"
            "FileExclusion" "**/*_BurstDebugInformation_DoNotShip*"
            "FileExclusion" "**/*_BackUpThisFolder_ButDontShipItWithYourGame*"
        }
"@
                } else {
                    # Debug branch: only exclude .DS_Store
                    $vdfContent += @"

        "$depotId"
        {
            "FileMapping"
            {
                "LocalPath" "./$depotPath/*"
                "DepotPath" "."
                "recursive" "1"
            }
            "FileExclusion" "*.DS_Store"
        }
"@
                }
            } elseif ($depotId) {
                Write-Host "::warning::Depot ${i}: ID specified but Path is missing (ID: $depotId)"
            }
        }

        $vdfContent += @"

    }
}
"@

        $vdfContent | Out-File -FilePath $vdfFile -Encoding UTF8 -NoNewline
    }

    Write-Host "VDF file prepared at $vdfFile"
    Write-Host "::endgroup::"

    return $vdfFile
}

function Run-SteamCMDDeployment {
    param([string]$VdfFile)

    Write-Host "::group::Running SteamCMD deployment"

    $steamcmdScript = Join-Path $STEAMCMD_DIR "steamcmd_script.txt"
    @"
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir $($STEAMCMD_DIR -replace '\\', '/')/steam_content
login $env:STEAM_USERNAME
run_app_build "$($VdfFile -replace '\\', '/')"
quit
"@ | Out-File -FilePath $steamcmdScript -Encoding UTF8 -NoNewline

    Write-Host "Executing SteamCMD..."
    # Note: enum_names.cpp warning is a known harmless SteamCMD bug
    & $STEAMCMD_BIN +runscript $steamcmdScript 2>&1 | Where-Object { $_ -notmatch "enum_names.cpp \(2184\)" }

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host "::error::SteamCMD deployment failed with exit code $exitCode"

        # Check for log files
        $logDir = Join-Path $STEAMCMD_DIR "steam_content/logs"
        $stderrLog = Join-Path $logDir "stderr.txt"
        if (Test-Path $stderrLog) {
            Write-Host "::group::SteamCMD Error Log"
            Get-Content $stderrLog
            Write-Host "::endgroup::"
        }

        exit $exitCode
    }

    Write-Host "::endgroup::"
}

function Invoke-Cleanup {
    Write-Host "::group::Cleanup"

    # Remove script file
    $scriptFile = Join-Path $STEAMCMD_DIR "steamcmd_script.txt"
    if (Test-Path $scriptFile) {
        Write-Host "Removing steamcmd_script.txt"
        Remove-Item $scriptFile -Force
    }

    # Remove VDF file
    $vdfFile = Join-Path $STEAMCMD_DIR "app_build_$env:STEAM_APP_ID.vdf"
    if (Test-Path $vdfFile) {
        Write-Host "Removing app_build_$env:STEAM_APP_ID.vdf"
        Remove-Item $vdfFile -Force
    }

    # Remove config.vdf (for security)
    $configVdf = Join-Path $STEAMCMD_DIR "config/config.vdf"
    if (Test-Path $configVdf) {
        Write-Host "Removing config.vdf for security"
        Remove-Item $configVdf -Force
    }

    # Remove entire SteamCMD directory if in temp location
    if ($STEAMCMD_DIR -like "$env:RUNNER_TEMP*" -or $STEAMCMD_DIR -like "$env:TEMP*") {
        Write-Host "Removing temporary SteamCMD directory: $STEAMCMD_DIR"
        Remove-Item $STEAMCMD_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "::endgroup::"
}

function Main {
    try {
        Validate-Environment
        Download-SteamCMD

        if ($env:DRY_RUN -eq "true") {
            Write-Host "::notice::Dry run mode - skipping config.vdf setup"
        } else {
            Setup-ConfigVdf
        }

        $vdfFile = Prepare-VdfFile

        if ($env:DRY_RUN -eq "true") {
            Write-Host "::notice::Dry run mode - skipping Steam login and deployment"
            Write-Host "::group::Generated VDF file"
            Get-Content $vdfFile
            Write-Host "::endgroup::"
            Write-Host "::notice::Dry run completed successfully!"
        } else {
            Test-SteamLogin
            Run-SteamCMDDeployment -VdfFile $vdfFile
            Write-Host "::notice::Steam deployment completed successfully!"
        }
    } finally {
        Invoke-Cleanup
    }
}

Main
