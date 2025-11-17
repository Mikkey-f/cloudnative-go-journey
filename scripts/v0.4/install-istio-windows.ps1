# v0.4 Istio Windows 安装脚本
# 功能: 在 Windows 上下载并安装 Istio
# 使用: .\scripts\v0.4\install-istio-windows.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "v0.4 Istio Windows 安装脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 设置工作目录
$workDir = "$env:TEMP\istio-download"
if (-not (Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir | Out-Null
}

Write-Host "[1/6] 下载 Istio..." -ForegroundColor Yellow

# 下载 Istio
$downloadUrl = "https://github.com/istio/istio/releases/download/1.20.0/istio-1.20.0-win.zip"
$zipPath = "$workDir\istio.zip"

try {
    Write-Host "从 $downloadUrl 下载..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
    Write-Host "✓ Istio 下载完成" -ForegroundColor Green
} catch {
    Write-Host "✗ 下载失败: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "备选方案: 手动下载" -ForegroundColor Yellow
    Write-Host "1. 访问: https://github.com/istio/istio/releases" -ForegroundColor White
    Write-Host "2. 下载最新的 istio-*-win.zip" -ForegroundColor White
    Write-Host "3. 解压到任意目录" -ForegroundColor White
    Write-Host "4. 将 bin 目录添加到 PATH 环境变量" -ForegroundColor White
    exit 1
}

Write-Host "[2/6] 解压 Istio..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force
    Write-Host "✓ Istio 解压完成" -ForegroundColor Green
} catch {
    Write-Host "✗ 解压失败: $_" -ForegroundColor Red
    exit 1
}

# 找到 Istio 目录
$istioDir = Get-ChildItem -Path $workDir -Directory -Filter "istio-*" | Select-Object -First 1
if (-not $istioDir) {
    Write-Host "✗ 找不到 Istio 目录" -ForegroundColor Red
    exit 1
}

$istioPath = $istioDir.FullName
$binPath = Join-Path $istioPath "bin"

Write-Host "[3/6] 添加 istioctl 到 PATH..." -ForegroundColor Yellow

# 检查 istioctl 是否已在 PATH 中
$currentPath = $env:PATH
if ($currentPath -like "*$binPath*") {
    Write-Host "✓ istioctl 已在 PATH 中" -ForegroundColor Green
} else {
    # 临时添加到当前 PowerShell 会话
    $env:PATH = "$binPath;$env:PATH"
    Write-Host "✓ istioctl 已添加到当前会话 PATH" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠ 提示: 为了永久添加，请执行以下步骤:" -ForegroundColor Yellow
    Write-Host "1. 打开 '编辑系统环境变量'" -ForegroundColor White
    Write-Host "2. 点击 '环境变量' 按钮" -ForegroundColor White
    Write-Host "3. 在 '系统变量' 中找到 'Path'" -ForegroundColor White
    Write-Host "4. 点击 '编辑'，添加: $binPath" -ForegroundColor White
    Write-Host "5. 点击 '确定' 保存" -ForegroundColor White
    Write-Host ""
}

Write-Host "[4/6] 验证 istioctl..." -ForegroundColor Yellow
try {
    $version = & "$binPath\istioctl.exe" version --remote=false
    Write-Host "✓ istioctl 验证成功" -ForegroundColor Green
    Write-Host $version -ForegroundColor Gray
}
catch {
    Write-Host "✗ istioctl 验证失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[5/6] 安装 Istio 到 Kubernetes..." -ForegroundColor Yellow
try {
    & "$binPath\istioctl.exe" install --set profile=demo -y
    Write-Host "✓ Istio 已安装到集群" -ForegroundColor Green
}
catch {
    Write-Host "✗ Istio 安装失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[6/6] 启用 Sidecar 自动注入..." -ForegroundColor Yellow
try {
    kubectl label namespace default istio-injection=enabled --overwrite
    Write-Host "✓ Sidecar 自动注入已启用" -ForegroundColor Green
}
catch {
    Write-Host "✗ 启用 Sidecar 注入失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Istio 安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "1. 重启应用 Pod:" -ForegroundColor White
Write-Host "   kubectl rollout restart deployment api-v1" -ForegroundColor Cyan
Write-Host "   kubectl rollout restart deployment api-v2" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. 部署 Istio 资源:" -ForegroundColor White
Write-Host "   kubectl apply -f k8s/v0.4/istio/destination-rule.yaml" -ForegroundColor Cyan
Write-Host "   kubectl apply -f k8s/v0.4/istio/virtual-service.yaml" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 验证部署:" -ForegroundColor White
Write-Host "   kubectl get virtualservice" -ForegroundColor Cyan
Write-Host "   kubectl get destinationrule" -ForegroundColor Cyan
Write-Host ""
