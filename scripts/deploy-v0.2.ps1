# ========================================
# CloudNative Go Journey v0.2 部署脚本
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CloudNative Go Journey v0.2" -ForegroundColor Cyan
Write-Host "  编排升级版 - 部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ========================================
# 1. 检查前置条件
# ========================================
Write-Host "📋 检查前置条件..." -ForegroundColor Yellow

# 检查 Minikube
Write-Host "  检查 Minikube..." -NoNewline
try {
    $minikubeStatus = minikube status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " ✅" -ForegroundColor Green
    } else {
        Write-Host " ❌ Minikube 未运行" -ForegroundColor Red
        Write-Host "请先启动 Minikube: minikube start" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host " ❌ Minikube 未安装" -ForegroundColor Red
    exit 1
}

# 检查 kubectl
Write-Host "  检查 kubectl..." -NoNewline
try {
    kubectl version --client --short 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
} catch {
    Write-Host " ❌ kubectl 未安装" -ForegroundColor Red
    exit 1
}

# 检查 Docker
Write-Host "  检查 Docker..." -NoNewline
try {
    docker version 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
} catch {
    Write-Host " ❌ Docker 未安装" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ========================================
# 2. 切换到 Minikube Docker 环境
# ========================================
Write-Host "🔄 切换到 Minikube Docker 环境..." -ForegroundColor Yellow
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
Write-Host "  ✅ Docker 环境已切换" -ForegroundColor Green
Write-Host ""

# ========================================
# 3. 构建镜像
# ========================================
Write-Host "🏗️  构建 Docker 镜像..." -ForegroundColor Yellow

# 构建 API 服务镜像
Write-Host "  构建 API 服务镜像..." -NoNewline
docker build -t cloudnative-go-api:v0.2 . 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 构建失败" -ForegroundColor Red
    exit 1
}

# 构建日志采集器镜像
Write-Host "  构建日志采集器镜像..." -NoNewline
docker build -f Dockerfile.log-collector -t log-collector:v0.2 . 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 构建失败" -ForegroundColor Red
    exit 1
}

# 构建清理任务镜像
Write-Host "  构建清理任务镜像..." -NoNewline
docker build -f Dockerfile.cleanup-job -t cleanup-job:v0.2 . 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 构建失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  镜像列表:" -ForegroundColor Cyan
docker images | Select-String "v0.2"
Write-Host ""

# ========================================
# 4. 部署到 Kubernetes
# ========================================
Write-Host "🚀 部署到 Kubernetes..." -ForegroundColor Yellow

# 部署 Redis
Write-Host "  部署 Redis (StatefulSet)..." -NoNewline
kubectl apply -f k8s/v0.2/redis/ 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 部署失败" -ForegroundColor Red
    exit 1
}

Write-Host "  等待 Redis 就绪..." -NoNewline
kubectl wait --for=condition=ready pod -l app=redis --timeout=60s 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ⚠️  超时，继续部署..." -ForegroundColor Yellow
}

# 部署 API 服务
Write-Host "  部署 API 服务 (Deployment)..." -NoNewline
kubectl apply -f k8s/v0.2/api/ 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 部署失败" -ForegroundColor Red
    exit 1
}

Write-Host "  等待 API 服务就绪..." -NoNewline
kubectl wait --for=condition=ready pod -l app=api --timeout=60s 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ⚠️  超时，继续部署..." -ForegroundColor Yellow
}

# 部署日志采集器
Write-Host "  部署日志采集器 (DaemonSet)..." -NoNewline
kubectl apply -f k8s/v0.2/log-collector/ 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 部署失败" -ForegroundColor Red
    exit 1
}

# 部署清理任务
Write-Host "  部署清理任务 (CronJob)..." -NoNewline
kubectl apply -f k8s/v0.2/cleanup-job/ 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌ 部署失败" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ========================================
# 5. 验证部署
# ========================================
Write-Host "🔍 验证部署..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  Pods:" -ForegroundColor Cyan
kubectl get pods -o wide

Write-Host ""
Write-Host "  Services:" -ForegroundColor Cyan
kubectl get svc

Write-Host ""
Write-Host "  StatefulSet:" -ForegroundColor Cyan
kubectl get statefulset

Write-Host ""
Write-Host "  DaemonSet:" -ForegroundColor Cyan
kubectl get daemonset

Write-Host ""
Write-Host "  CronJob:" -ForegroundColor Cyan
kubectl get cronjob

Write-Host ""
Write-Host "  PVC:" -ForegroundColor Cyan
kubectl get pvc

Write-Host ""

# ========================================
# 6. 获取访问信息
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$MINIKUBE_IP = minikube ip
Write-Host "📍 Minikube IP: $MINIKUBE_IP" -ForegroundColor Yellow
Write-Host ""
Write-Host "🌐 访问地址:" -ForegroundColor Cyan
Write-Host "  API 服务:     http://${MINIKUBE_IP}:30080" -ForegroundColor White
Write-Host "  健康检查:     http://${MINIKUBE_IP}:30080/health" -ForegroundColor White
Write-Host "  Redis 测试:   http://${MINIKUBE_IP}:30080/api/v1/cache/test" -ForegroundColor White
Write-Host "  配置信息:     http://${MINIKUBE_IP}:30080/api/v1/config" -ForegroundColor White
Write-Host ""
Write-Host "📝 测试命令:" -ForegroundColor Cyan
Write-Host "  # 测试 API" -ForegroundColor Gray
Write-Host "  curl http://${MINIKUBE_IP}:30080/health" -ForegroundColor White
Write-Host ""
Write-Host "  # 创建数据" -ForegroundColor Gray
Write-Host "  curl -X POST http://${MINIKUBE_IP}:30080/api/v1/data ``" -ForegroundColor White
Write-Host "    -H 'Content-Type: application/json' ``" -ForegroundColor White
Write-Host "    -d '{""key"":""test:1"",""value"":""Hello v0.2"",""ttl"":3600}'" -ForegroundColor White
Write-Host ""
Write-Host "  # 获取数据" -ForegroundColor Gray
Write-Host "  curl http://${MINIKUBE_IP}:30080/api/v1/data/test:1" -ForegroundColor White
Write-Host ""
Write-Host "🔍 查看日志:" -ForegroundColor Cyan
Write-Host "  kubectl logs -l app=api --tail=50" -ForegroundColor White
Write-Host "  kubectl logs redis-0 --tail=50" -ForegroundColor White
Write-Host "  kubectl logs -l app=log-collector --tail=50" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

