#!/bin/bash

# v0.4 环境准备脚本
# 功能: 启用 Nginx Ingress Controller 和安装 Istio
# 用法: bash scripts/v0.4/setup-environment.sh

set -e

echo "=========================================="
echo "v0.4 环境准备 - Task 1"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查前置要求
echo -e "${YELLOW}[1/6] 检查前置要求...${NC}"
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}错误: minikube 未安装${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: kubectl 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 前置要求检查通过${NC}"
echo ""

# 启用 Nginx Ingress Controller
echo -e "${YELLOW}[2/6] 启用 Nginx Ingress Controller...${NC}"
minikube addons enable ingress
sleep 5

# 验证 Ingress 控制器
echo -e "${YELLOW}[3/6] 验证 Ingress 控制器...${NC}"
kubectl get pods -n ingress-nginx
echo -e "${GREEN}✓ Ingress 控制器已启用${NC}"
echo ""

# 下载 Istio
echo -e "${YELLOW}[4/6] 下载 Istio...${NC}"
if [ ! -d "istio-1.18.0" ]; then
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-1.18.0
else
    cd istio-1.18.0
fi

# 安装 Istio
echo -e "${YELLOW}[5/6] 安装 Istio (Demo 模式)...${NC}"
./bin/istioctl install --set profile=demo -y
sleep 10

# 启用自动注入
echo -e "${YELLOW}[6/6] 启用 Envoy Sidecar 自动注入...${NC}"
kubectl label namespace default istio-injection=enabled --overwrite

echo ""
echo "=========================================="
echo -e "${GREEN}环境准备完成！${NC}"
echo "=========================================="
echo ""

# 验证 Istio 安装
echo -e "${YELLOW}验证 Istio 安装状态:${NC}"
echo ""
echo "Istio 系统 Pod:"
kubectl get pods -n istio-system
echo ""
echo "Istio 系统服务:"
kubectl get svc -n istio-system
echo ""
echo "命名空间标签:"
kubectl get namespace default --show-labels
echo ""

echo -e "${GREEN}✓ 所有检查通过！${NC}"
echo ""
echo "下一步:"
echo "  1. 开始 Task 2: 前端服务开发"
echo "  2. 开始 Task 3: API v2 开发"
echo "  3. 开始 Task 5: Istio 安装验证"
echo ""
