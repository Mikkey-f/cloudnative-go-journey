#!/bin/bash

# v0.4 Istio 验证脚本
# 功能: 验证 Istio 安装和配置是否正常
# 用法: bash scripts/v0.4/verify-istio.sh

set -e

echo "=========================================="
echo "v0.4 Istio 验证 - Task 5"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS=true

# 1. 检查 Istio 命名空间
echo -e "${YELLOW}[1/6] 检查 Istio 命名空间...${NC}"
if kubectl get namespace istio-system &> /dev/null; then
    echo -e "${GREEN}✓ istio-system 命名空间存在${NC}"
else
    echo -e "${RED}✗ istio-system 命名空间不存在${NC}"
    PASS=false
fi
echo ""

# 2. 检查 Istiod
echo -e "${YELLOW}[2/6] 检查 Istiod 控制平面...${NC}"
if kubectl get pods -n istio-system | grep -q "istiod"; then
    echo -e "${GREEN}✓ Istiod 正在运行${NC}"
    kubectl get pods -n istio-system | grep istiod
else
    echo -e "${RED}✗ Istiod 未运行${NC}"
    PASS=false
fi
echo ""

# 3. 检查 Envoy 代理
echo -e "${YELLOW}[3/6] 检查 Envoy 代理...${NC}"
if kubectl get pods -n istio-system | grep -q "envoy"; then
    echo -e "${GREEN}✓ Envoy 代理正在运行${NC}"
    kubectl get pods -n istio-system | grep envoy
else
    echo -e "${YELLOW}⚠ Envoy 代理未找到（可能在其他命名空间）${NC}"
fi
echo ""

# 4. 检查自动注入
echo -e "${YELLOW}[4/6] 检查 Sidecar 自动注入...${NC}"
LABEL=$(kubectl get namespace default --show-labels | grep -o "istio-injection=[^,]*" || echo "")
if [ -n "$LABEL" ] && echo "$LABEL" | grep -q "enabled"; then
    echo -e "${GREEN}✓ Sidecar 自动注入已启用${NC}"
    echo "  标签: $LABEL"
else
    echo -e "${RED}✗ Sidecar 自动注入未启用${NC}"
    PASS=false
fi
echo ""

# 5. 检查 VirtualService
echo -e "${YELLOW}[5/6] 检查 VirtualService...${NC}"
if kubectl get virtualservices -n default &> /dev/null; then
    VS_COUNT=$(kubectl get virtualservices -n default 2>/dev/null | wc -l)
    if [ $VS_COUNT -gt 1 ]; then
        echo -e "${GREEN}✓ VirtualService 已配置${NC}"
        kubectl get virtualservices -n default
    else
        echo -e "${YELLOW}⚠ 未找到 VirtualService（可能尚未部署）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ VirtualService 资源不可用${NC}"
fi
echo ""

# 6. 检查 DestinationRule
echo -e "${YELLOW}[6/6] 检查 DestinationRule...${NC}"
if kubectl get destinationrules -n default &> /dev/null; then
    DR_COUNT=$(kubectl get destinationrules -n default 2>/dev/null | wc -l)
    if [ $DR_COUNT -gt 1 ]; then
        echo -e "${GREEN}✓ DestinationRule 已配置${NC}"
        kubectl get destinationrules -n default
    else
        echo -e "${YELLOW}⚠ 未找到 DestinationRule（可能尚未部署）${NC}"
    fi
else
    echo -e "${YELLOW}⚠ DestinationRule 资源不可用${NC}"
fi
echo ""

# 最终结果
if [ "$PASS" = true ]; then
    echo -e "${GREEN}========== Istio 验证通过！ ==========${NC}"
    echo ""
    echo "Istio 已成功安装并配置！"
    echo ""
    echo "下一步:"
    echo "  1. 部署应用 Pod"
    echo "  2. 验证 Envoy Sidecar 自动注入"
    echo "  3. 配置 VirtualService 和 DestinationRule"
    echo ""
else
    echo -e "${RED}========== Istio 验证失败！ ==========${NC}"
    echo ""
    echo "请检查:"
    echo "  1. Istio 是否已安装: istioctl install --set profile=demo -y"
    echo "  2. 自动注入是否已启用: kubectl label namespace default istio-injection=enabled"
    echo "  3. Istiod 是否正在运行: kubectl get pods -n istio-system"
    echo ""
    exit 1
fi
