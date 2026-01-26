# Steam Deploy Action (Docker-free)

A GitHub Action that deploys to Steam using SteamCMD without Docker.
Works on Windows, macOS, Linux self-hosted runners, and GitHub-hosted runners.

## Features

- 🐳 No Docker required - works on self-hosted runners
- 🍎 macOS support
- 🐧 Linux support
- 🪟 Windows support
- 📦 Multiple depot support (up to 9)
- 🔧 Auto-downloads SteamCMD each run

## Usage

### Basic Example

```yaml
name: Deploy to Steam
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    # or macOS: runs-on: macos-latest
    # or self-hosted: runs-on: self-hosted

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Steam
        uses: neptaco/steam-deploy@v1
        with:
          username: ${{ secrets.STEAM_USERNAME }}
          configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
          appId: '1234567'
          buildDescription: 'Automated build from GitHub Actions'
          rootPath: 'build'
```

### Multiple Depots Example (Auto-generated IDs)

```yaml
- name: Deploy to Steam with multiple depots (auto ID)
  uses: neptaco/steam-deploy@v1
  with:
    username: ${{ secrets.STEAM_USERNAME }}
    configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
    appId: '1234567'
    buildDescription: 'Multi-depot build'
    rootPath: '.'
    depot1Path: 'windows'  # Auto ID: 1234568
    depot2Path: 'mac'      # Auto ID: 1234569
    depot3Path: 'linux'    # Auto ID: 1234570
    releaseBranch: 'prerelease'  # Deploy to prerelease branch
```

### Multiple Depots Example (Explicit IDs)

```yaml
- name: Deploy to Steam with multiple depots (explicit ID)
  uses: neptaco/steam-deploy@v1
  with:
    username: ${{ secrets.STEAM_USERNAME }}
    configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
    appId: '1234567'
    buildDescription: 'Multi-depot build'
    rootPath: '.'
    depot1Id: '1234568'  # Windows Depot ID (explicit)
    depot1Path: 'windows'
    depot2Id: '1234569'  # Mac Depot ID (explicit)
    depot2Path: 'mac'
    depot3Id: '1234570'  # Linux Depot ID (explicit)
    depot3Path: 'linux'
```

**Note**:
- When Depot Path is specified and Depot ID is omitted, ID is auto-generated as `App ID + number` (e.g., App ID 1234567 → 1234568, 1234569, ...)
- Depot IDs must be pre-configured in the Steamworks Partner site

### Custom VDF File

```yaml
- name: Deploy with custom VDF
  uses: neptaco/steam-deploy@v1
  with:
    username: ${{ secrets.STEAM_USERNAME }}
    configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
    appId: '1234567'
    vdfPath: './custom_app_build.vdf'
```

## Input Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `username` | Yes | Steam username |
| `configVdf` | Yes | Steam config.vdf file contents (Base64 encoded) |
| `appId` | Yes | Steam App ID |
| `buildDescription` | Optional | Build description |
| `rootPath` | Optional | Root path for build files (default: `.`) |
| `vdfPath` | Optional | Path to custom VDF file |
| `releaseBranch` | Optional | Target branch for deployment (e.g., prerelease, beta, default) |
| `debugBranch` | Optional | Set to `true` to include debug files (default: `false`) |
| `depot1Id` | Optional | Depot 1 ID (auto: App ID + 1) |
| `depot1Path` | Optional | Depot 1 path |
| `depot2Id` | Optional | Depot 2 ID (auto: App ID + 2) |
| `depot2Path` | Optional | Depot 2 path |
| `depot3Id` | Optional | Depot 3 ID (auto: App ID + 3) |
| `depot3Path` | Optional | Depot 3 path |
| `depot4Id` | Optional | Depot 4 ID (auto: App ID + 4) |
| `depot4Path` | Optional | Depot 4 path |
| `depot5Id` | Optional | Depot 5 ID (auto: App ID + 5) |
| `depot5Path` | Optional | Depot 5 path |
| `depot6Id` | Optional | Depot 6 ID (auto: App ID + 6) |
| `depot6Path` | Optional | Depot 6 path |
| `depot7Id` | Optional | Depot 7 ID (auto: App ID + 7) |
| `depot7Path` | Optional | Depot 7 path |
| `depot8Id` | Optional | Depot 8 ID (auto: App ID + 8) |
| `depot8Path` | Optional | Depot 8 path |
| `depot9Id` | Optional | Depot 9 ID (auto: App ID + 9) |
| `depot9Path` | Optional | Depot 9 path |

**Note**:
- Specifying a Depot Path adds that depot to the VDF
- Depot Path is relative to ContentRoot (no `./` prefix needed)
- When Depot Path is specified and Depot ID is omitted, ID is auto-generated as `App ID + number`

## Setup

### 1. Steam Guard Configuration

You need to disable Steam Guard or use a config.vdf file to bypass authentication.

### 2. Getting config.vdf

1. Log in to SteamCMD on your local machine
2. Copy the config.vdf file:
   - **Windows**: `C:\Users\<username>\AppData\Local\Steam\steamcmd\config\config.vdf`
   - **macOS**: `~/Library/Application Support/Steam/steamcmd/config/config.vdf`
   - **Linux**: `~/.steam/steamcmd/config/config.vdf`
3. Base64 encode:
   - **Windows (PowerShell)**: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("config.vdf")) | Set-Clipboard`
   - **macOS**: `base64 -i config.vdf | pbcopy`
   - **Linux**: `base64 config.vdf | xclip -selection clipboard`
4. Save as `STEAM_CONFIG_VDF` in GitHub Secrets

### 3. GitHub Secrets Configuration

Set the following in your repository's Settings > Secrets and variables > Actions:

- `STEAM_USERNAME`: Steam username
- `STEAM_CONFIG_VDF`: Base64-encoded config.vdf

## File Exclusions

By default, the following files are automatically excluded:
- `*.DS_Store` (always excluded)
- `*.pdb` (when debugBranch is false)
- `**/*_BurstDebugInformation_DoNotShip*` (when debugBranch is false)
- `**/*_BackUpThisFolder_ButDontShipItWithYourGame*` (when debugBranch is false)

Set `debugBranch: 'true'` to deploy debug builds.

## Supported Environments

- ✅ GitHub-hosted runners (ubuntu-latest, macos-latest, windows-latest)
- ✅ Self-hosted runners (Linux, macOS, Windows)

## Troubleshooting

### Linux Dependency Errors

Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install lib32gcc-s1
```

CentOS/RHEL:
```bash
sudo yum install glibc.i686 libstdc++.i686
```

### macOS Permission Errors

```bash
chmod +x ~/steamcmd/steamcmd.sh
```

### Windows Execution Policy Errors

If you encounter execution policy errors on Windows self-hosted runners:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### config.vdf Errors

Verify config.vdf is correctly Base64 encoded:
```bash
# Linux/macOS
echo $STEAM_CONFIG_VDF | base64 -d

# Windows (PowerShell)
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:STEAM_CONFIG_VDF))
```

## License

MIT

## Contributing

Issues and Pull Requests are welcome!

## References

- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [Steam Partner Documentation](https://partner.steamgames.com/)
