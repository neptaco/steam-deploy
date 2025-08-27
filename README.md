# Steam Deploy Action (Docker-free)

Docker を使用せずに SteamCMD で Steam にデプロイする GitHub Action です。
macOS、Linux のセルフホストランナーおよび GitHub ホストランナーで動作します。

## 特徴

- 🐳 Docker 不要 - セルフホストランナーでも動作
- 🍎 macOS 対応
- 🐧 Linux 対応
- 📦 SteamCMD を毎回自動ダウンロード
- 🔧 複数の depot に対応（最大9つ）

## 使用方法

### 基本的な使用例

```yaml
name: Deploy to Steam
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    # または macOS: runs-on: macos-latest
    # またはセルフホスト: runs-on: self-hosted
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Steam
        uses: your-username/steam-deploy@v1
        with:
          username: ${{ secrets.STEAM_USERNAME }}
          configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
          appId: '1234567'
          buildDescription: 'Automated build from GitHub Actions'
          rootPath: './build'
```

### 複数 depot の例（ID自動生成）

```yaml
- name: Deploy to Steam with multiple depots (auto ID)
  uses: your-username/steam-deploy@v1
  with:
    username: ${{ secrets.STEAM_USERNAME }}
    configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
    appId: '1234567'
    buildDescription: 'Multi-depot build'
    rootPath: '.'
    depot1Path: './windows'  # 自動で ID: 1234568
    depot2Path: './mac'      # 自動で ID: 1234569
    depot3Path: './linux'    # 自動で ID: 1234570
```

### 複数 depot の例（ID明示指定）

```yaml
- name: Deploy to Steam with multiple depots (explicit ID)
  uses: your-username/steam-deploy@v1
  with:
    username: ${{ secrets.STEAM_USERNAME }}
    configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
    appId: '1234567'
    buildDescription: 'Multi-depot build'
    rootPath: '.'
    depot1Id: '1234568'  # Windows版の Depot ID（明示指定）
    depot1Path: './windows'
    depot2Id: '1234569'  # Mac版の Depot ID（明示指定）
    depot2Path: './mac'
    depot3Id: '1234570'  # Linux版の Depot ID（明示指定）
    depot3Path: './linux'
```

**注意**: 
- Depot ID を省略した場合、`App ID + 番号` で自動生成されます（例: App ID 1234567 → 1234568, 1234569, ...）
- Depot ID は Steamworks Partner サイトで事前に設定されている必要があります

### カスタム VDF ファイルの使用

```yaml
- name: Deploy with custom VDF
  uses: your-username/steam-deploy@v1
  with:
    username: ${{ secrets.STEAM_USERNAME }}
    configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
    appId: '1234567'
    vdfPath: './custom_app_build.vdf'
```

## 入力パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `username` | ✅ | Steam のユーザー名 |
| `configVdf` | ✅ | Steam config.vdf ファイルの内容（Base64エンコード） |
| `appId` | ✅ | Steam App ID |
| `buildDescription` | ❌ | ビルドの説明文 |
| `rootPath` | ❌ | ビルドファイルのルートパス（デフォルト: `.`） |
| `vdfPath` | ❌ | カスタム VDF ファイルへのパス |
| `depot1Id` | ❌ | Depot 1 の ID（省略時は App ID + 1） |
| `depot1Path` | ❌ | Depot 1 のパス |
| `depot2Id` | ❌ | Depot 2 の ID（省略時は App ID + 2） |
| `depot2Path` | ❌ | Depot 2 のパス |
| `depot3Id` | ❌ | Depot 3 の ID（省略時は App ID + 3） |
| `depot3Path` | ❌ | Depot 3 のパス |
| `depot4Id` | ❌ | Depot 4 の ID（省略時は App ID + 4） |
| `depot4Path` | ❌ | Depot 4 のパス |
| `depot5Id` | ❌ | Depot 5 の ID（省略時は App ID + 5） |
| `depot5Path` | ❌ | Depot 5 のパス |
| `depot6Id` | ❌ | Depot 6 の ID（省略時は App ID + 6） |
| `depot6Path` | ❌ | Depot 6 のパス |
| `depot7Id` | ❌ | Depot 7 の ID（省略時は App ID + 7） |
| `depot7Path` | ❌ | Depot 7 のパス |
| `depot8Id` | ❌ | Depot 8 の ID（省略時は App ID + 8） |
| `depot8Path` | ❌ | Depot 8 のパス |
| `depot9Id` | ❌ | Depot 9 の ID（省略時は App ID + 9） |
| `depot9Path` | ❌ | Depot 9 のパス |

**注意**: 
- Depot Path を指定すると、その Depot が VDF に追加されます
- Depot ID を省略した場合、`App ID + 番号` で自動生成されます

## セットアップ

### 1. Steam Guard の設定

Steam Guard を無効化するか、config.vdf ファイルを使用して認証をバイパスする必要があります。

### 2. config.vdf の取得

1. ローカルマシンで SteamCMD にログイン
2. `~/.steam/steamcmd/config/config.vdf` ファイルをコピー
3. Base64 エンコード: `base64 -i config.vdf | pbcopy` (macOS) または `base64 config.vdf | xclip -selection clipboard` (Linux)
4. GitHub Secrets に `STEAM_CONFIG_VDF` として保存

### 3. GitHub Secrets の設定

リポジトリの Settings > Secrets and variables > Actions で以下を設定：

- `STEAM_USERNAME`: Steam のユーザー名
- `STEAM_CONFIG_VDF`: Base64 エンコードされた config.vdf

## 動作環境

- ✅ GitHub ホストランナー (ubuntu-latest, macos-latest)
- ✅ セルフホストランナー (Linux, macOS)
- ❌ Windows（未対応）

## トラブルシューティング

### Linux での依存関係エラー

Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install lib32gcc-s1
```

CentOS/RHEL:
```bash
sudo yum install glibc.i686 libstdc++.i686
```

### macOS での権限エラー

```bash
chmod +x ~/steamcmd/steamcmd.sh
```

### config.vdf エラー

config.vdf が正しく Base64 エンコードされていることを確認：
```bash
echo $STEAM_CONFIG_VDF | base64 -d
```

## ライセンス

MIT

## 貢献

Issue や Pull Request は歓迎します！

## 参考

- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [Steam Partner Documentation](https://partner.steamgames.com/)