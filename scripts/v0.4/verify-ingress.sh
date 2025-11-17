#!/bin/bash

# v0.4 Ingress 验证脚本
# 功能: 验证 Ingress 配置和路由是否正常
# 用法: bash scripts/v0.4/verify-ingress.sh

set -e

echo "=========================================="
echo "v0.4 Ingress 验证 - Task 9"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=true

# 1. 检查 Ingress 是否存在
echo -e "${YELLOW}[1/5] 检查 Ingress 配置...${NC}"
if kubectl get ingress app-ingress -n default &> /dev/null; then
    echo -e "${GREEN}✓ Ingress 'app-ingress' 存在${NC}"
else
    echo -e "${RED}✗ Ingress 'app-ingress' 不存在${NC}"
    PASS=false
fi
echo ""

# 2. 检查 Ingress 状态
echo -e "${YELLOW}[2/5] 检查 Ingress 状态...${NC}"
kubectl get ingress app-ingress -n default
echo ""

# 3. 检查 Ingress 控制器
echo -e "${YELLOW}[3/5] 检查 Ingress 控制器...${NC}"
if kubectl get pods -n ingress-nginx | grep -q "nginx-ingress-controller"; then
    echo -e "${GREEN}✓ Nginx Ingress Controller 正在运行${NC}"
else
    echo -e "${RED}✗ Nginx Ingress Controller 未运行${NC}"
    PASS=false
fi
echo ""

# 4. 检查后端服务
echo -e "${YELLOW}[4/5] 检查后端服务...${NC}"

# 检查 frontend-service
if kubectl get svc frontend-service -n default &> /dev/null; then
    echo -e "${GREEN}✓ frontend-service 存在${NC}"
else
    echo -e "${RED}✗ frontend-service 不存在${NC}"
    PASS=false
fi

# 检查 api-service
if kubectl get svc api-service -n default &> /dev/null; then
    echo -e "${GREEN}✓ api-service 存在${NC}"
else
    echo -e "${RED}✗ api-service 不存在${NC}"
    PASS=false
fi
echo ""

# 5. 显示路由规则
echo -e "${YELLOW}[5/5] Ingress 路由规则:${NC}"
kubectl describe ingress app-ingress -n default | grep -A 10 "Rules:"
echo ""

# 最终结果
if [ "$PASS" = true ]; then
    echo -e "${GREEN}========== Ingress 验证通过！ ==========${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 配置本地 hosts: 127.0.0.1 app.local"
    echo "  2. 测试前端: curl http://app.local/"
    echo "  3. 测试 API: curl http://app.local/api/v1/hello"
    echo ""
else
    echo -e "${RED}========== Ingress 验证失败！ ==========${NC}"
    echo ""
    echo "请检查:"
    echo "  1. Ingress 配置文件是否正确"
    echo "  2. 后端服务是否已部署"
    echo "  3. Ingress 控制器是否正在运行"
    echo ""
    exit 1
fi
