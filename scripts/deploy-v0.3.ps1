#!/usr/bin/env pwsh
<#
.SYNOPSIS
    部署 CloudNative Go Journey v0.3（弹性伸缩版）

.DESCRIPTION
    自动化部署脚本，包括：
    - 构建 Docker 镜像
    - 检查 Metrics Server
    - 部署应用和 HPA
    - 验证部署状态

.PARAMETER SkipBuild
    跳过 Docker 构建（如果镜像已存在）

.PARAMETER SkipMetricsCheck
    跳过 Metrics Server 检查

.EXAMPLE
    .\deploy-v0.3.ps1
    
.EXAMPLE
    .\deploy-v0.3.ps1 -SkipBuild
#>

param(
    [switch]$SkipBuild,
    [switch]$SkipMetricsCheck
)

# ============= 配置 =============

$VERSION = "v0.3"
$IMAGE_NAME = "cloudnative-api:$VERSION"
$NAMESPACE = "default"
$K8S_DIR = "k8s/$VERSION"

# ============= 颜色输出 =============

function Write-Step {
    param([string]$Message)
    Write-Host "`n🔹 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

# ============= 主逻辑 =============

Write-Host @"

╔═══════════════════════════════════════════════╗
║   CloudNative Go Journey - v0.3 部署脚本      ║
║   弹性伸缩版（HPA + Metrics Server）           ║
╚═══════════════════════════════════════════════╝

"@ -ForegroundColor Magenta

# 步骤 1: 检查前置条件
Write-Step "检查前置条件..."

# 检查 kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl 未安装或不在 PATH 中"
    exit 1
}

# 检查 docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker 未安装或不在 PATH 中"
    exit 1
}

# 检查集群连接
try {
    kubectl cluster-info | Out-Null
    Write-Success "Kubernetes 集群连接正常"
} catch {
    Write-Error "无法连接到 Kubernetes 集群"
    exit 1
}

# 步骤 2: 检查 Metrics Server
if (-not $SkipMetricsCheck) {
    Write-Step "检查 Metrics Server..."
    
    $metricsServer = kubectl get deployment metrics-server -n kube-system 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Metrics Server 未安装"
        Write-Info "HPA 需要 Metrics Server 才能工作"
        
        $install = Read-Host "是否现在安装 Metrics Server? (y/n)"
        
        if ($install -eq 'y') {
            Write-Step "安装 Metrics Server..."
            
            kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
            
            # 针对本地环境（Docker Desktop/Minikube/Kind）打补丁
            Write-Info "为本地环境添加 --kubelet-insecure-tls 参数..."
            
            kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
                {
                    "op": "add",
                    "path": "/spec/template/spec/containers/0/args/-",
                    "value": "--kubelet-insecure-tls"
                }
            ]'
            
            Write-Info "等待 Metrics Server 就绪（最多 60 秒）..."
            kubectl wait --for=condition=available --timeout=60s deployment/metrics-server -n kube-system
            
            Start-Sleep -Seconds 10
            
            Write-Success "Metrics Server 安装完成"
        } else {
            Write-Warning "跳过 Metrics Server 安装，HPA 可能无法正常工作"
        }
    } else {
        Write-Success "Metrics Server 已安装"
    }
    
    # 验证 Metrics API
    Write-Step "验证 Metrics API..."
    $topNodes = kubectl top nodes 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Metrics API 正常工作"
        Write-Host $topNodes
    } else {
        Write-Warning "Metrics API 暂时不可用，请稍后重试"
    }
}

# 步骤 3: 构建 Docker 镜像
if (-not $SkipBuild) {
    Write-Step "构建 Docker 镜像..."
    
    docker build -t $IMAGE_NAME -f Dockerfile .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker 镜像构建失败"
        exit 1
    }
    
    Write-Success "Docker 镜像构建完成: $IMAGE_NAME"
} else {
    Write-Info "跳过 Docker 构建（使用已存在的镜像）"
}

# 步骤 4: 部署到 Kubernetes
Write-Step "部署应用到 Kubernetes..."

# 部署 Deployment
Write-Info "应用 Deployment..."
kubectl apply -f "$K8S_DIR/api/deployment.yaml"

# 部署 Service
Write-Info "应用 Service..."
kubectl apply -f "$K8S_DIR/api/service.yaml"

# 等待 Deployment 就绪
Write-Info "等待 Pods 就绪（最多 60 秒）..."
kubectl wait --for=condition=available --timeout=60s deployment/cloudnative-api -n $NAMESPACE

Write-Success "应用部署完成"

# 步骤 5: 部署 HPA
Write-Step "部署 HPA..."

kubectl apply -f "$K8S_DIR/api/hpa.yaml"

Start-Sleep -Seconds 3

Write-Success "HPA 部署完成"

# 步骤 6: 验证部署
Write-Step "验证部署状态..."

Write-Host "`n📦 Pods:" -ForegroundColor Yellow
kubectl get pods -l app=cloudnative-api -n $NAMESPACE

Write-Host "`n🌐 Services:" -ForegroundColor Yellow
kubectl get svc cloudnative-api-service -n $NAMESPACE

Write-Host "`n📊 HPA:" -ForegroundColor Yellow
kubectl get hpa cloudnative-api-hpa -n $NAMESPACE

# 步骤 7: 显示访问信息
Write-Step "获取访问地址..."

$nodePort = kubectl get svc cloudnative-api-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}'

Write-Host @"

╔═══════════════════════════════════════════════╗
║              部署完成！                        ║
╚═══════════════════════════════════════════════╝

🌐 服务访问地址:
   http://localhost:$nodePort

📍 测试端点:
   健康检查:     http://localhost:$nodePort/health
   Hello:        http://localhost:$nodePort/api/v1/hello
   CPU 负载:     http://localhost:$nodePort/api/v1/workload/cpu?iterations=10000000
   内存负载:     http://localhost:$nodePort/api/v1/workload/memory?size=50&duration=3
   混合负载:     http://localhost:$nodePort/api/v1/workload?type=mixed&intensity=50

📊 监控命令:
   监控 HPA:     kubectl get hpa cloudnative-api-hpa -w
   监控 Pods:    kubectl get pods -l app=cloudnative-api -w
   查看资源:     kubectl top pods -l app=cloudnative-api
   查看事件:     kubectl get events --sort-by='.lastTimestamp' -n $NAMESPACE

🧪 运行压测:
   k6 run k6-tests/hpa-test.js

📚 查看详细信息:
   kubectl describe hpa cloudnative-api-hpa
   kubectl describe deployment cloudnative-api

"@ -ForegroundColor Green

Write-Success "🎉 v0.3 部署完成！开始你的 HPA 实验吧！"

