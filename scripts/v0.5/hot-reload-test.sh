#!/bin/bash
# v0.5 配置热更新测试脚本
# 测试 ConfigMap 更新后自动重载

set -e

ENV=${1:-dev}
POD_NAME=$(kubectl get pods -l app=api,env=$ENV -n default -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "❌ 未找到 Pod"
    exit 1
fi

echo "🔥 开始热更新测试..."
echo "Pod: $POD_NAME"
echo ""

# 1. 获取当前配置
echo "1️⃣ 获取当前日志级别..."
kubectl exec $POD_NAME -n default -- curl -s localhost:8080/api/v1/config/log.level | jq '.'

# 2. 修改 ConfigMap
echo ""
echo "2️⃣ 修改 ConfigMap (log.level: info -> debug)..."
kubectl patch configmap ${ENV}-api-config -n default --type merge -p '{"data":{"config.yaml":"server:\n  environment: \"development\"\n  version: \"v0.5.0-dev\"\n\nlog:\n  level: \"debug\"\n  enable_stacktrace: true\n\nredis:\n  pool_size: 5"}}'

echo "✅ ConfigMap 已修改"

# 3. 等待同步（K8s 最多 120 秒）
echo ""
echo "3️⃣ 等待配置同步（最多 120 秒）..."
for i in {1..24}; do
    sleep 5
    echo "⏳ 等待中... ($((i*5))s)"
    
    # 检查日志级别是否更新
    LEVEL=$(kubectl exec $POD_NAME -n default -- curl -s localhost:8080/api/v1/config/log.level 2>/dev/null | jq -r '.data.value' 2>/dev/null || echo "error")
    
    if [ "$LEVEL" = "debug" ]; then
        echo ""
        echo "✅ 配置已热更新! (耗时: $((i*5))秒)"
        echo ""
        echo "4️⃣ 验证新配置:"
        kubectl exec $POD_NAME -n default -- curl -s localhost:8080/api/v1/config/log.level | jq '.'
        exit 0
    fi
done

echo ""
echo "❌ 配置热更新超时（120秒）"
echo "当前日志级别仍为: $LEVEL"
exit 1
