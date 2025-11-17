#!/bin/bash

# v0.4 镜像构建脚本
# 功能: 一键构建所有 Docker 镜像
# 用法: bash scripts/v0.4/build-images.sh

set -e

echo "=========================================="
echo "v0.4 Docker 镜像构建"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi

echo -e "${YELLOW}Docker 版本:${NC}"
docker --version
echo ""

# 1. 构建后端镜像（v1 和 v2 使用同一镜像，通过环境变量区分）
echo -e "${YELLOW}[1/2] 构建后端镜像 (api:latest)...${NC}"
docker build -f docker/v0.4/Dockerfile.backend -t api:latest .
echo -e "${GREEN}✓ api:latest 构建完成${NC}"
echo ""

# 2. 构建前端镜像
echo -e "${YELLOW}[2/2] 构建前端镜像 (frontend:latest)...${NC}"
docker build -f docker/v0.4/Dockerfile.frontend -t frontend:latest .
echo -e "${GREEN}✓ frontend:latest 构建完成${NC}"
echo ""

# 显示镜像列表
echo -e "${BLUE}========== 镜像列表 ==========${NC}"
echo ""
docker images | grep -E "api|frontend" || echo "未找到镜像"
echo ""

echo -e "${GREEN}========== 构建完成！ ==========${NC}"
echo ""
echo "镜像信息:"
echo "  - api:latest       (后端 - v1 和 v2 使用同一镜像，通过 API_VERSION 环境变量区分)"
echo "  - frontend:latest  (前端服务)"
echo ""
echo "下一步:"
echo "  1. 部署到 Kubernetes: bash scripts/v0.4/deploy-all.sh"
echo "  2. 验证部署: bash scripts/v0.4/verify-ingress.sh"
echo "  3. 测试流量: bash scripts/v0.4/traffic-verify.sh"
echo ""
