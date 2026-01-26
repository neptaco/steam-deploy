---
name: release-preview
description: 最新タグからの変更をまとめてリリース内容とバージョン番号を提案する。「リリースプレビュー」「次のバージョン」「変更まとめ」と言われた場合に使用
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
---

# リリースプレビュー

最新のタグからの変更内容を分析し、リリース情報とバージョン番号を提案します。

## 手順

### 1. 現在の状態を取得

以下のコマンドを実行して情報を収集してください：

```bash
# 最新のセマンティックバージョンタグを取得（v1 などのメジャータグを除外）
LATEST_TAG=$(git tag -l 'v*.*.*' | sort -V | tail -1)
echo "Latest tag: $LATEST_TAG"

# タグがない場合は初期コミットから
if [ -z "$LATEST_TAG" ]; then
  echo "No semantic version tags found. Will analyze all commits."
  LATEST_TAG=$(git rev-list --max-parents=0 HEAD)
fi
```

```bash
# 最新タグから HEAD までのコミットログ
git log ${LATEST_TAG}..HEAD --oneline --no-merges
```

```bash
# 変更されたファイル一覧
git diff ${LATEST_TAG}..HEAD --stat
```

```bash
# 現在のタグ一覧
git tag -l | sort -V
```

### 2. 変更内容を分析

コミットを以下のカテゴリに分類してください：

#### 変更タイプの判定基準

| プレフィックス | カテゴリ | バージョン影響 |
|--------------|---------|--------------|
| `feat:` | 新機能 | マイナー ↑ |
| `fix:` | バグ修正 | パッチ ↑ |
| `docs:` | ドキュメント | パッチ ↑ |
| `refactor:` | リファクタリング | パッチ ↑ |
| `perf:` | パフォーマンス改善 | パッチ ↑ |
| `test:` | テスト | パッチ ↑ |
| `chore:` | 雑務 | パッチ ↑ |
| `BREAKING CHANGE` | 破壊的変更 | メジャー ↑ |

### 3. 出力フォーマット

以下の形式でレポートを作成してください：

---

## リリースプレビュー

**現在のバージョン**: `{LATEST_TAG}`
**提案バージョン**: `{PROPOSED_VERSION}`
**変更タイプ**: {patch/minor/major}

### 変更内容

#### 新機能 (Features)
- {feat コミットの一覧}

#### バグ修正 (Bug Fixes)
- {fix コミットの一覧}

#### その他の変更
- {その他のコミット}

### 破壊的変更
- {該当する場合のみ記載}

### リリースノート案

```markdown
## What's Changed

{変更内容を箇条書きで要約}

**Full Changelog**: https://github.com/neptaco/steam-deploy/compare/{LATEST_TAG}...{PROPOSED_VERSION}
```

### 次のステップ

リリースを実行するには：
```
/release-version {PROPOSED_VERSION}
```

---

## バージョン番号の決定ルール

現在のバージョンが `v1.2.3` の場合：

1. **破壊的変更がある** → `v2.0.0`
2. **新機能がある（feat:）** → `v1.3.0`
3. **修正のみ** → `v1.2.4`

初回リリースの場合は `v1.0.0` を提案してください。
