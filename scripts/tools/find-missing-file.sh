#!/bin/bash
set -e

TARGET="docs/**/docker-info.md"
echo "🔍 开始寻找 $TARGET ..."

# 1. 工作区
echo "👉 检查工作目录..."
find ./docs -type f -name "docker-info.md" 2>/dev/null || echo "❌ 工作目录未找到"

# 2. 暂存区
echo "👉 检查 Git 暂存区 (index)..."
git ls-files --stage | grep "docker-info.md" || echo "❌ 暂存区未找到"

# 3. 最近提交 (HEAD~50)
echo "👉 检查最近 50 次提交..."
git log -n 50 --pretty=format:"%h %s" -- docs/**/docker-info.md 2>/dev/null || echo "❌ 最近提交未找到"

# 4. reflog 历史
echo "👉 检查 reflog..."
for h in $(git reflog --pretty=format:"%H" | head -50); do
  git ls-tree -r $h --name-only | grep "docs/.*/docker-info.md" && echo "✅ 在提交 $h 中找到"
done || echo "❌ reflog 未找到"

# 5. stash
echo "👉 检查 stash..."
git stash list | while read stash; do
  name=$(echo $stash | cut -d: -f1)
  git ls-tree -r "$name" --name-only | grep "docs/.*/docker-info.md" && echo "✅ 在 $name 中找到"
done || echo "❌ stash 未找到"

# 6. dangling blobs
echo "👉 检查 lost+found (dangling blobs)..."
git fsck --lost-found | grep blob | while read type hash; do
  git show $hash | grep -q "docker" && echo "✅ 在 blob $hash 中可能找到内容"
done || echo "❌ lost+found 未找到"

echo "🔎 搜索完成"
