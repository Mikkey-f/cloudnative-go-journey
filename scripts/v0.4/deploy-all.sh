#!/bin/bash

# v0.4 完整部署脚本
# 功能: 一键部署所有 v0.4 组件
# 用法: bash scripts/v0.4/deploy-all.sh

set -e

echo "=========================================="
echo "v0.4 完整部署脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 0. 构建镜像
echo -e "${YELLOW}[0/7] 构建 Docker 镜像...${NC}"
bash scripts/v0.4/build-images.sh
echo ""

# 1. 部署前端服务
echo -e "${YELLOW}[1/7] 部署前端服务...${NC}"
kubectl apply -f k8s/v0.4/frontend/deployment.yaml
kubectl apply -f k8s/v0.4/frontend/service.yaml
echo -e "${GREEN}✓ 前端服务已部署${NC}"
echo ""

# 2. 部署 API v1
echo -e "${YELLOW}[2/7] 部署 API v1 (9 个副本)...${NC}"
kubectl apply -f k8s/v0.4/api/deployment-v1.yaml
echo -e "${GREEN}✓ API v1 已部署${NC}"
echo ""

# 3. 部署 API v2
echo -e "${YELLOW}[3/7] 部署 API v2 (1 个副本)...${NC}"
kubectl apply -f k8s/v0.4/api/deployment-v2.yaml
echo -e "${GREEN}✓ API v2 已部署${NC}"
echo ""

# 4. 部署 API Service
echo -e "${YELLOW}[4/7] 部署 API Service...${NC}"
kubectl apply -f k8s/v0.4/api/service.yaml
echo -e "${GREEN}✓ API Service 已部署${NC}"
echo ""

# 5. 部署 Ingress
echo -e "${YELLOW}[5/7] 部署 Ingress...${NC}"
kubectl apply -f k8s/v0.4/ingress/ingress.yaml
echo -e "${GREEN}✓ Ingress 已部署${NC}"
echo ""

# 6. 部署 Istio 配置
echo -e "${YELLOW}[6/7] 部署 Istio 配置...${NC}"
kubectl apply -f k8s/v0.4/istio/virtual-service.yaml
kubectl apply -f k8s/v0.4/istio/destination-rule.yaml
echo -e "${GREEN}✓ Istio 配置已部署${NC}"
echo ""

# 等待 Pod 启动
echo -e "${YELLOW}等待 Pod 启动...${NC}"
sleep 10

# 显示部署状态
echo ""
echo -e "${BLUE}========== 部署状态 ==========${NC}"
echo ""

echo "前端 Pod:"
kubectl get pods -l app=frontend
echo ""

echo "API v1 Pod:"
kubectl get pods -l app=api,version=v1
echo ""

echo "API v2 Pod:"
kubectl get pods -l app=api,version=v2
echo ""

echo "Services:"
kubectl get svc -l app=frontend,app=api
echo ""

echo "Ingress:"
kubectl get ingress
echo ""

echo "VirtualService:"
kubectl get virtualservices
echo ""

echo "DestinationRule:"
kubectl get destinationrules
echo ""

# 最终提示
echo -e "${GREEN}========== 部署完成！ ==========${NC}"
echo ""
echo "下一步:"
echo "  1. 配置本地 hosts: 127.0.0.1 app.local"
echo "  2. 验证 Ingress: bash scripts/v0.4/verify-ingress.sh"
echo "  3. 验证流量分配: bash scripts/v0.4/traffic-verify.sh"
echo ""
echo "测试命令:"
echo "  - 前端: curl http://app.local/"
echo "  - API: curl http://app.local/api/v1/hello"
echo "  - 版本: curl http://app.local/api/v1/version"
echo ""
