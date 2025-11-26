#!/bin/bash
# 一键合并 feature/optimize 到 main 并推送到 GitHub

set -e

echo "=========================================="
echo "开始合并到 main 分支并推送到 GitHub"
echo "=========================================="
echo ""

# 1. 检查当前分支
CURRENT_BRANCH=$(git branch --show-current)
echo "当前分支: $CURRENT_BRANCH"

# 2. 检查是否有未提交的修改
if ! git diff-index --quiet HEAD --; then
    echo "检测到未提交的修改，正在提交..."
    git add -A
    git commit -s -m "chore: 更新文件引用

- 更新 README.md 中的脚本文件名引用
- 同步文件变更

Signed-off-by: $(git config user.name) <$(git config user.email)>"
    echo "✓ 修改已提交"
else
    echo "✓ 没有未提交的修改"
fi

# 3. 切换到 main 分支
echo ""
echo "切换到 main 分支..."
git checkout main
echo "✓ 已切换到 main 分支"

# 4. 拉取最新的 main 分支
echo ""
echo "拉取最新的 main 分支..."
git pull origin main || echo "⚠ 拉取失败或无需拉取，继续执行..."

# 5. 合并 feature/optimize 分支
echo ""
echo "合并 feature/optimize 分支到 main..."
if git merge feature/optimize --no-edit; then
    echo "✓ 合并成功"
else
    echo "✗ 合并失败，可能存在冲突"
    echo "请手动解决冲突后运行: git push origin main"
    exit 1
fi

# 6. 推送到 GitHub
echo ""
echo "推送到 GitHub..."
if git push origin main; then
    echo ""
    echo "=========================================="
    echo "✓ 成功！代码已合并到 main 并推送到 GitHub"
    echo "=========================================="
    echo ""
    echo "查看远程仓库: https://github.com/jimmycheng603/marquez-airflow"
else
    echo "✗ 推送失败，请检查网络连接和权限"
    exit 1
fi

