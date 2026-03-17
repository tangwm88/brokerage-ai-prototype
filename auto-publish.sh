#!/bin/bash
# 原型自动发布脚本

set -e

echo "=== 原型自动发布开始 ==="
echo "时间: $(date)"
echo "仓库: brokerage-ai-prototype"

# 检查是否有变更
if [ -z "$(git status --porcelain . 2>/dev/null)" ]; then
    echo "✓ 无变更，无需发布"
    exit 0
fi

echo "发现变更，准备发布..."

# 添加变更
git add index.html index_v1.html dashboard.html organization.html 2>/dev/null || true
git add institutional_brokerage_chat/ 2>/dev/null || true

# 提交
COMMIT_MSG="auto: 自动更新原型 $(date '+%Y-%m-%d %H:%M')"
git commit -m "$COMMIT_MSG" || echo "无变更需要提交"
echo "✓ 已提交"

# 推送
echo "正在推送到 GitHub..."
if timeout 60 git push origin main; then
    echo "✓ 推送成功"
    echo ""
    echo "=== 发布完成 ==="
    echo "GitHub Pages: https://tangwm88.github.io/brokerage-ai-prototype/"
    echo "员工工作台: https://tangwm88.github.io/brokerage-ai-prototype/index_v1.html"
    echo "数据看板: https://tangwm88.github.io/brokerage-ai-prototype/dashboard.html"
    echo "组织管理: https://tangwm88.github.io/brokerage-ai-prototype/organization.html"
    exit 0
else
    echo "× 推送超时，将在下次自动重试"
    exit 1
fi
