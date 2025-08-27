#!/bin/bash

# リリーススクリプト
# 使用方法: ./release.sh [major|minor|patch]

set -e

# 現在のバージョンを取得（最新のタグから）
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Latest tag: $LATEST_TAG"

# バージョン番号を分解
VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

# バージョンをインクリメント
case "$1" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch|*)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
MAJOR_VERSION="v${MAJOR}"

echo "Creating new version: $NEW_VERSION"

# 新しいバージョンタグを作成
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"

# メジャーバージョンタグを更新
git tag -fa "$MAJOR_VERSION" -m "Update $MAJOR_VERSION to $NEW_VERSION"

echo "Tags created locally. Push with:"
echo "  git push origin $NEW_VERSION"
echo "  git push origin $MAJOR_VERSION --force"
echo ""
echo "Or push all at once:"
echo "  git push origin $NEW_VERSION && git push origin $MAJOR_VERSION --force"