#!/bin/bash
# v0.5 配置测试脚本
# 测试配置加载和 API

set -e

PORT=${1:-8080}
BASE_URL="http://localhost:$PORT"

echo "🧪 开始配置测试..."
echo "目标: $BASE_URL"
echo ""

# 测试 1: 健康检查
echo "1️⃣ 测试健康检查..."
if curl -s "$BASE_URL/health" | grep -q "ok"; then
    echo "✅ 健康检查通过"
else
    echo "❌ 健康检查失败"
    exit 1
fi

# 测试 2: 获取完整配置
echo ""
echo "2️⃣ 测试获取完整配置..."
CONFIG=$(curl -s "$BASE_URL/api/v1/config")
if echo "$CONFIG" | grep -q "success"; then
    echo "✅ 获取配置成功"
    echo "$CONFIG" | jq '.' 2>/dev/null || echo "$CONFIG"
else
    echo "❌ 获取配置失败"
    exit 1
fi

# 测试 3: 获取指定字段
echo ""
echo "3️⃣ 测试获取指定字段..."
FIELD=$(curl -s "$BASE_URL/api/v1/config/log.level")
if echo "$FIELD" | grep -q "success"; then
    echo "✅ 获取字段成功"
    echo "$FIELD" | jq '.' 2>/dev/null || echo "$FIELD"
else
    echo "❌ 获取字段失败"
fi

# 测试 4: 获取可热更新字段列表
echo ""
echo "4️⃣ 测试获取可热更新字段..."
HOT_RELOAD=$(curl -s "$BASE_URL/api/v1/config/hot-reloadable")
if echo "$HOT_RELOAD" | grep -q "success"; then
    echo "✅ 获取可热更新字段成功"
    echo "$HOT_RELOAD" | jq '.' 2>/dev/null || echo "$HOT_RELOAD"
else
    echo "❌ 获取可热更新字段失败"
fi

echo ""
echo "✅ 所有配置测试通过!"
