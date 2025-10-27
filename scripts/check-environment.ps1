# v0.1 Environment Check Script (PowerShell for Windows)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CloudNative Go Journey - Environment Check" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Check-Command {
    param (
        [string]$CommandName,
        [string]$VersionArg
    )
    
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        try {
            $version = Invoke-Expression "$CommandName $VersionArg" 2>&1
            Write-Host "[OK] $CommandName installed: $($version[0])" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "[OK] $CommandName installed" -ForegroundColor Green
            return $true
        }
    } else {
        Write-Host "[FAIL] $CommandName not installed" -ForegroundColor Red
        return $false
    }
}

Write-Host "1. 检查 Go 环境" -ForegroundColor Yellow
Write-Host "----------------------------"
Check-Command "go" "version"
Write-Host ""

Write-Host "2. 检查 Docker 环境" -ForegroundColor Yellow
Write-Host "----------------------------"
Check-Command "docker" "--version"
try {
    docker ps *>$null
    if ($?) {
        Write-Host "✓ Docker daemon 正在运行" -ForegroundColor Green
    } else {
        Write-Host "✗ Docker daemon 未运行，请启动 Docker Desktop" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Docker daemon 未运行，请启动 Docker Desktop" -ForegroundColor Red
}
Write-Host ""

Write-Host "3. 检查 kubectl" -ForegroundColor Yellow
Write-Host "----------------------------"
Check-Command "kubectl" "version --client --short"
Write-Host ""

Write-Host "4. 检查 Minikube" -ForegroundColor Yellow
Write-Host "----------------------------"
$hasMinikube = Check-Command "minikube" "version --short"
if ($hasMinikube) {
    try {
        $status = minikube status 2>$null
        if ($?) {
            Write-Host "✓ Minikube 集群正在运行" -ForegroundColor Green
            minikube status
        } else {
            Write-Host "! Minikube 集群未运行" -ForegroundColor Yellow
            Write-Host "  提示：运行 'minikube start' 启动集群" -ForegroundColor Gray
        }
    } catch {
        Write-Host "! Minikube 集群未运行" -ForegroundColor Yellow
        Write-Host "  提示：运行 'minikube start' 启动集群" -ForegroundColor Gray
    }
}
Write-Host ""

Write-Host "5. 检查可选工具" -ForegroundColor Yellow
Write-Host "----------------------------"
if (-not (Check-Command "k9s" "version")) {
    Write-Host "  推荐安装 k9s: https://k9scli.io/" -ForegroundColor Gray
}
if (-not (Check-Command "helm" "version --short")) {
    Write-Host "  可选安装 helm: https://helm.sh/" -ForegroundColor Gray
}
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  环境检查完成" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步：" -ForegroundColor Green
Write-Host "  1. 如果有 ✗ 标记，请先安装对应工具" -ForegroundColor White
Write-Host "  2. 运行 'minikube start' 启动本地 K8s 集群" -ForegroundColor White
Write-Host "  3. 阅读 docs/v0.1/K8S-BASICS.md 学习 K8s 基础" -ForegroundColor White
Write-Host ""
