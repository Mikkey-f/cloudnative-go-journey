#!/bin/bash
# v0.5 环境部署脚本
# 用法: ./deploy-env.sh [dev|staging|prod]

set -e

ENV=$1

if [ -z "$ENV" ]; then
    echo "❌ 错误: 请指定环境"
    echo "用法: $0 [dev|staging|prod]"
    exit 1
fi

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ 错误: 无效的环境: $ENV"
    echo "有效环境: dev, staging, prod"
    exit 1
fi

echo "🚀 开始部署 $ENV 环境..."

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl 未安装"
    exit 1
fi

# 检查 kustomize
if ! command -v kustomize &> /dev/null; then
    echo "⚠️  kustomize 未安装，使用 kubectl kustomize"
fi

# 部署
echo "📦 应用 Kustomize 配置..."
kubectl apply -k "../../k8s/v0.5/overlays/$ENV"

echo "⏳ 等待 Deployment 就绪..."
kubectl rollout status deployment/${ENV}-api -n default --timeout=2m

echo "✅ $ENV 环境部署成功!"
echo ""
echo "📊 查看 Pod 状态:"
kubectl get pods -l env=$ENV -n default

echo ""
echo "🔍 查看 ConfigMap:"
kubectl describe configmap ${ENV}-api-config -n default | head -20

echo ""
echo "🌐 访问服务:"
echo "  kubectl port-forward svc/${ENV}-api-service 8080:80"
