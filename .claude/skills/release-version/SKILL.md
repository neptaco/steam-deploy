---
name: release-version
description: GitHub Action のリリース手順をガイドする。「リリース」「バージョン更新」「v1 更新」と言われた場合に使用
disable-model-invocation: true
argument-hint: "[version e.g., v1.1.0]"
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# GitHub Action リリース手順

このスキルは steam-deploy のリリース手順をガイドします。

## 引数

`$ARGUMENTS` にバージョン番号を指定できます（例: v1.1.0）。指定がない場合は分析結果から提案します。

## 手順

### 1. 現在の状態を確認

以下を実行して現状を把握してください：

```bash
# 最新のセマンティックバージョンタグを取得
LATEST_TAG=$(git tag -l 'v*.*.*' | sort -V | tail -1)
if [ -z "$LATEST_TAG" ]; then
  # セマンティックバージョンがなければ v1 などのメジャータグを使用
  LATEST_TAG=$(git tag -l 'v[0-9]' | sort -V | tail -1)
fi
echo "Latest tag: $LATEST_TAG"

# タグ一覧
git tag -l | sort -V

# 最新タグが指しているコミット
git rev-parse $LATEST_TAG

# 最新コミット
git rev-parse HEAD

# 差分コミット
git log ${LATEST_TAG}..HEAD --oneline --no-merges
```

### 2. 変更内容を分析してリリースノートを作成

コミットを以下のカテゴリに分類：

| プレフィックス | カテゴリ | バージョン影響 |
|--------------|---------|--------------|
| `feat:` | New Features | マイナー ↑ |
| `fix:` | Bug Fixes | パッチ ↑ |
| `docs:` | Documentation | パッチ ↑ |
| `refactor:` | Refactoring | パッチ ↑ |
| `perf:` | Performance | パッチ ↑ |
| `chore:` | Chores | パッチ ↑ |
| `BREAKING CHANGE` | Breaking Changes | メジャー ↑ |

### 3. バージョン番号を決定

引数でバージョンが指定されていない場合、変更内容から提案：
- **破壊的変更がある** → メジャーバージョン up (v2.0.0)
- **feat: がある** → マイナーバージョン up (v1.x.0)
- **fix/docs などのみ** → パッチバージョン up (v1.x.x)

### 4. リリースノート案を作成してユーザーに確認

以下の形式でリリースノートを作成し、**AskUserQuestion ツールを使ってユーザーに確認**してください：

```markdown
## What's Changed

### New Features
- 機能の説明 (コミットハッシュ)

### Bug Fixes
- 修正の説明 (コミットハッシュ)

### Documentation
- ドキュメント変更の説明

### Other Changes
- その他の変更

**Full Changelog**: https://github.com/neptaco/steam-deploy/compare/{LATEST_TAG}...{NEW_VERSION}
```

AskUserQuestion で以下を確認：
- 提案バージョン番号が正しいか
- リリースノートの内容が正しいか
- リリースを実行してよいか

### 5. リリースを実行

ユーザーの承認後、以下を実行：

```bash
# タグを作成してプッシュ
git tag {VERSION}
git push origin {VERSION}

# リリースノートをファイルに保存
cat > /tmp/release_notes.md << 'EOF'
{リリースノート内容}
EOF

# GitHub リリースを作成
gh release create {VERSION} --notes-file /tmp/release_notes.md

# 一時ファイル削除
rm /tmp/release_notes.md
```

### 6. メジャーバージョンタグの更新確認

リリース公開後、`.github/workflows/update-major-version.yml` が自動実行されます。

```bash
# ワークフロー実行状況を確認
gh run list --workflow=update-major-version.yml --limit=1
```

### 7. 最終確認

```bash
# タグを再取得
git fetch --tags --force

# v1 が新しいリリースを指しているか確認
git rev-parse v1
git rev-parse {VERSION}  # 同じコミットを指すはず
```

## 手動で v1 を更新する場合

ワークフローが失敗した場合：

```bash
git tag -fa v1 -m "Update v1 tag to {VERSION}"
git push origin v1 --force
```

## 注意事項

- メジャーバージョンタグ（v1）の force push は正常な動作です
- ユーザーは `@v1` で常に最新の v1.x.x を取得できます
- 破壊的変更がある場合は新しいメジャーバージョン（v2）を作成してください
