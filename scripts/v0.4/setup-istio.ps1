# v0.4 Istio 快速安装脚本 (Windows)
# 使用: .\scripts\v0.4\setup-istio.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "v0.4 Istio 快速安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 下载 Istio
Write-Host "[1/5] 下载 Istio..." -ForegroundColor Yellow
$workDir = "$env:TEMP\istio"
$zipPath = "$workDir\istio.zip"

if (-not (Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}

$downloadUrl = "https://github.com/istio/istio/releases/download/1.20.0/istio-1.20.0-win.zip"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
    Write-Host "✓ 下载完成" -ForegroundColor Green
}
catch {
    Write-Host "✗ 下载失败，请手动下载: $downloadUrl" -ForegroundColor Red
    exit 1
}

# 步骤 2: 解压
Write-Host "[2/5] 解压 Istio..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force
    Write-Host "✓ 解压完成" -ForegroundColor Green
}
catch {
    Write-Host "✗ 解压失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤 3: 添加到 PATH
Write-Host "[3/5] 配置 PATH..." -ForegroundColor Yellow
$istioDir = Get-ChildItem -Path $workDir -Directory -Filter "istio-*" | Select-Object -First 1
$binPath = Join-Path $istioDir.FullName "bin"
$env:PATH = "$binPath;$env:PATH"
Write-Host "✓ PATH 已配置: $binPath" -ForegroundColor Green

# 步骤 4: 安装 Istio
Write-Host "[4/5] 安装 Istio 到集群..." -ForegroundColor Yellow
try {
    & "$binPath\istioctl.exe" install --set profile=demo -y
    Write-Host "✓ Istio 已安装" -ForegroundColor Green
}
catch {
    Write-Host "✗ 安装失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤 5: 启用 Sidecar 注入
Write-Host "[5/5] 启用 Sidecar 自动注入..." -ForegroundColor Yellow
try {
    kubectl label namespace default istio-injection=enabled --overwrite
    Write-Host "✓ Sidecar 注入已启用" -ForegroundColor Green
}
catch {
    Write-Host "✗ 启用失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Istio 安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "1. 重启 Pod: kubectl rollout restart deployment api-v1 api-v2" -ForegroundColor Cyan
Write-Host "2. 部署资源: kubectl apply -f k8s/v0.4/istio/" -ForegroundColor Cyan
Write-Host "3. 验证: kubectl get virtualservice" -ForegroundColor Cyan
Write-Host ""
