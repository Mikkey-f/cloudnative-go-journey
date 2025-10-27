#!/bin/bash

# v0.1 环境检查脚本

echo "=========================================="
echo "  CloudNative Go Journey - 环境检查"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    if command -v $1 &> /dev/null; then
        version=$($2)
        echo -e "${GREEN}✓${NC} $1 已安装: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $1 未安装"
        return 1
    fi
}

echo "1. 检查 Go 环境"
echo "----------------------------"
check_command "go" "go version"
echo ""

echo "2. 检查 Docker 环境"
echo "----------------------------"
check_command "docker" "docker --version"
if docker ps &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon 正在运行"
else
    echo -e "${RED}✗${NC} Docker daemon 未运行，请启动 Docker Desktop"
fi
echo ""

echo "3. 检查 kubectl"
echo "----------------------------"
check_command "kubectl" "kubectl version --client --short 2>/dev/null || kubectl version --client"
echo ""

echo "4. 检查 Minikube"
echo "----------------------------"
check_command "minikube" "minikube version --short"
if minikube status &> /dev/null; then
    echo -e "${GREEN}✓${NC} Minikube 集群正在运行"
    minikube status
else
    echo -e "${YELLOW}!${NC} Minikube 集群未运行"
    echo "  提示：运行 'minikube start' 启动集群"
fi
echo ""

echo "5. 检查可选工具"
echo "----------------------------"
check_command "k9s" "k9s version --short" || echo "  推荐安装 k9s: https://k9scli.io/"
check_command "helm" "helm version --short" || echo "  可选安装 helm: https://helm.sh/"
echo ""

echo "=========================================="
echo "  环境检查完成"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 如果有 ✗ 标记，请先安装对应工具"
echo "  2. 运行 'minikube start' 启动本地 K8s 集群"
echo "  3. 阅读 docs/v0.1/K8S-BASICS.md 学习 K8s 基础"
echo ""
