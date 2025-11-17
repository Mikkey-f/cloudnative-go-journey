#!/bin/bash

# v0.4 流量验证脚本
# 功能: 验证金丝雀发布流量分配 (90/10)
# 用法: bash scripts/v0.4/traffic-verify.sh

set -e

echo "=========================================="
echo "v0.4 流量验证 - Task 8"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
API_URL="http://app.local/api/v1/version"
REQUEST_COUNT=100
V1_THRESHOLD_MIN=85
V1_THRESHOLD_MAX=95

echo -e "${YELLOW}配置信息:${NC}"
echo "  API 地址: $API_URL"
echo "  请求次数: $REQUEST_COUNT"
echo "  v1 目标范围: ${V1_THRESHOLD_MIN}%-${V1_THRESHOLD_MAX}%"
echo ""

# 检查 curl 命令
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: curl 未安装${NC}"
    exit 1
fi

# 发送请求并统计
echo -e "${YELLOW}发送 $REQUEST_COUNT 个请求...${NC}"
echo ""

V1_COUNT=0
V2_COUNT=0
ERROR_COUNT=0

for i in $(seq 1 $REQUEST_COUNT); do
    # 显示进度
    if [ $((i % 10)) -eq 0 ]; then
        echo -ne "\r已完成: $i/$REQUEST_COUNT"
    fi

    # 发送请求
    RESPONSE=$(curl -s "$API_URL" 2>/dev/null || echo "")

    # 解析响应
    if echo "$RESPONSE" | grep -q '"version":"v1"'; then
        ((V1_COUNT++))
    elif echo "$RESPONSE" | grep -q '"version":"v2"'; then
        ((V2_COUNT++))
    else
        ((ERROR_COUNT++))
    fi
done

echo -ne "\r已完成: $REQUEST_COUNT/$REQUEST_COUNT\n"
echo ""

# 计算百分比
TOTAL=$((V1_COUNT + V2_COUNT))
if [ $TOTAL -eq 0 ]; then
    echo -e "${RED}错误: 没有收到有效响应${NC}"
    echo "  v1 响应: $V1_COUNT"
    echo "  v2 响应: $V2_COUNT"
    echo "  错误响应: $ERROR_COUNT"
    exit 1
fi

V1_PERCENT=$((V1_COUNT * 100 / TOTAL))
V2_PERCENT=$((V2_COUNT * 100 / TOTAL))

# 显示结果
echo -e "${BLUE}========== 流量分配结果 ==========${NC}"
echo ""
echo -e "v1 (稳定版本): ${YELLOW}$V1_COUNT${NC} 次 (${YELLOW}$V1_PERCENT%${NC})"
echo -e "v2 (新版本):   ${YELLOW}$V2_COUNT${NC} 次 (${YELLOW}$V2_PERCENT%${NC})"
echo -e "错误响应:      ${YELLOW}$ERROR_COUNT${NC} 次"
echo ""

# 验证结果
echo -e "${BLUE}========== 验证结果 ==========${NC}"
echo ""

PASS=true

# 检查 v1 比例
if [ $V1_PERCENT -ge $V1_THRESHOLD_MIN ] && [ $V1_PERCENT -le $V1_THRESHOLD_MAX ]; then
    echo -e "${GREEN}✓ v1 比例验证通过${NC} ($V1_PERCENT% 在 ${V1_THRESHOLD_MIN}%-${V1_THRESHOLD_MAX}% 范围内)"
else
    echo -e "${RED}✗ v1 比例验证失败${NC} ($V1_PERCENT% 不在 ${V1_THRESHOLD_MIN}%-${V1_THRESHOLD_MAX}% 范围内)"
    PASS=false
fi

# 检查 v2 比例
V2_THRESHOLD_MIN=$((100 - V1_THRESHOLD_MAX))
V2_THRESHOLD_MAX=$((100 - V1_THRESHOLD_MIN))
if [ $V2_PERCENT -ge $V2_THRESHOLD_MIN ] && [ $V2_PERCENT -le $V2_THRESHOLD_MAX ]; then
    echo -e "${GREEN}✓ v2 比例验证通过${NC} ($V2_PERCENT% 在 ${V2_THRESHOLD_MIN}%-${V2_THRESHOLD_MAX}% 范围内)"
else
    echo -e "${RED}✗ v2 比例验证失败${NC} ($V2_PERCENT% 不在 ${V2_THRESHOLD_MIN}%-${V2_THRESHOLD_MAX}% 范围内)"
    PASS=false
fi

# 检查错误率
ERROR_RATE=$((ERROR_COUNT * 100 / REQUEST_COUNT))
if [ $ERROR_RATE -lt 5 ]; then
    echo -e "${GREEN}✓ 错误率验证通过${NC} ($ERROR_RATE% < 5%)"
else
    echo -e "${RED}✗ 错误率验证失败${NC} ($ERROR_RATE% >= 5%)"
    PASS=false
fi

echo ""

# 最终结果
if [ "$PASS" = true ]; then
    echo -e "${GREEN}========== 验证通过！ ==========${NC}"
    echo ""
    echo "金丝雀发布流量分配正常！"
    echo "  - v1 (稳定版本) 获得约 90% 的流量"
    echo "  - v2 (新版本) 获得约 10% 的流量"
    echo ""
    exit 0
else
    echo -e "${RED}========== 验证失败！ ==========${NC}"
    echo ""
    echo "流量分配不符合预期，请检查:"
    echo "  1. VirtualService 配置是否正确"
    echo "  2. DestinationRule 配置是否正确"
    echo "  3. v1 和 v2 Pod 是否都在运行"
    echo "  4. Envoy Sidecar 是否已注入"
    echo ""
    exit 1
fi
