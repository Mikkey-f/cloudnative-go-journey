# v0.1 自动化部署脚本
# CloudNative Go Journey

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CloudNative Go Journey v0.1 部署" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 检查必要工具
function Check-Command {
    param($cmd)
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "错误：$cmd 未安装" -ForegroundColor Red
        exit 1
    }
}

Write-Host "1. 检查环境..." -ForegroundColor Yellow
Check-Command "docker"
Check-Command "kubectl"
Check-Command "minikube"
Write-Host "   环境检查通过 ✓" -ForegroundColor Green
Write-Host ""

# 启动 Minikube
Write-Host "2. 启动 Minikube..." -ForegroundColor Yellow
$status = minikube status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Minikube 未运行，正在启动..." -ForegroundColor Gray
    minikube start --cpus=2 --memory=4096
} else {
    Write-Host "   Minikube 已运行 ✓" -ForegroundColor Green
}
Write-Host ""

# 构建镜像
Write-Host "3. 构建 Docker 镜像..." -ForegroundColor Yellow
docker build -t cloudnative-go-api:v0.1 . -q
if ($LASTEXITCODE -eq 0) {
    Write-Host "   镜像构建成功 ✓" -ForegroundColor Green
} else {
    Write-Host "   镜像构建失败 ✗" -ForegroundColor Red
    exit 1
}

# 查看镜像大小
$imageSize = docker images cloudnative-go-api:v0.1 --format "{{.Size}}"
Write-Host "   镜像大小: $imageSize" -ForegroundColor Gray
Write-Host ""

# 加载到 Minikube
Write-Host "4. 加载镜像到 Minikube..." -ForegroundColor Yellow
minikube image load cloudnative-go-api:v0.1
Write-Host "   镜像加载完成 ✓" -ForegroundColor Green
Write-Host ""

# 部署到 K8s
Write-Host "5. 部署到 Kubernetes..." -ForegroundColor Yellow
kubectl apply -f k8s/v0.1/ | Out-Null
Write-Host "   部署配置已应用 ✓" -ForegroundColor Green
Write-Host ""

# 等待 Pod 就绪
Write-Host "6. 等待 Pod 就绪..." -ForegroundColor Yellow
Write-Host "   (最多等待 60 秒)" -ForegroundColor Gray
kubectl wait --for=condition=ready pod -l app=api --timeout=60s 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Pod 已就绪 ✓" -ForegroundColor Green
} else {
    Write-Host "   警告：Pod 未就绪，请检查状态" -ForegroundColor Yellow
}
Write-Host ""

# 显示部署状态
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  部署状态" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Pods:" -ForegroundColor Yellow
kubectl get pods -l app=api
Write-Host ""

Write-Host "Service:" -ForegroundColor Yellow
kubectl get svc api-service
Write-Host ""

Write-Host "Endpoints:" -ForegroundColor Yellow
kubectl get endpoints api-service
Write-Host ""

# 获取服务 URL
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  访问服务" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$serviceUrl = minikube service api-service --url
Write-Host "服务 URL: $serviceUrl" -ForegroundColor Green
Write-Host ""

Write-Host "测试命令：" -ForegroundColor Yellow
Write-Host "  curl $serviceUrl/health" -ForegroundColor Gray
Write-Host "  curl $serviceUrl/api/v1/hello" -ForegroundColor Gray
Write-Host "  curl $serviceUrl/api/v1/info" -ForegroundColor Gray
Write-Host ""

# 测试健康检查
Write-Host "快速健康检查：" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$serviceUrl/health" -TimeoutSec 5
    Write-Host "  ✓ 健康检查通过：$($response.status)" -ForegroundColor Green
} catch {
    Write-Host "  ! 健康检查失败，请手动验证" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "  1. 浏览器访问：minikube service api-service" -ForegroundColor White
Write-Host "  2. 查看日志：kubectl logs -l app=api -f" -ForegroundColor White
Write-Host "  3. 查看文档：docs/v0.1/COMPLETION-SUMMARY.md" -ForegroundColor White
Write-Host ""
