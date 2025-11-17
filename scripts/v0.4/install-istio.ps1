# v0.4 Istio Installation Script for Windows
# Usage: .\scripts\v0.4\install-istio.ps1

Write-Host "========================================"
Write-Host "v0.4 Istio Installation"
Write-Host "========================================"
Write-Host ""

# Step 1: Download Istio
Write-Host "[1/5] Downloading Istio..." -ForegroundColor Yellow
$workDir = "$env:TEMP\istio"
$zipPath = "$workDir\istio.zip"

if (-not (Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}

$downloadUrl = "https://github.com/istio/istio/releases/download/1.20.0/istio-1.20.0-win.zip"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
    Write-Host "OK: Download completed" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Download failed" -ForegroundColor Red
    Write-Host "Please download manually: $downloadUrl" -ForegroundColor Yellow
    exit 1
}

# Step 2: Extract
Write-Host "[2/5] Extracting Istio..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force
    Write-Host "OK: Extract completed" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Extract failed: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Configure PATH
Write-Host "[3/5] Configuring PATH..." -ForegroundColor Yellow
$istioDir = Get-ChildItem -Path $workDir -Directory -Filter "istio-*" | Select-Object -First 1
$binPath = Join-Path $istioDir.FullName "bin"
$env:PATH = "$binPath;$env:PATH"
Write-Host "OK: PATH configured: $binPath" -ForegroundColor Green

# Step 4: Install Istio
Write-Host "[4/5] Installing Istio to cluster..." -ForegroundColor Yellow
try {
    & "$binPath\istioctl.exe" install --set profile=demo -y
    Write-Host "OK: Istio installed" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Installation failed: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Enable Sidecar Injection
Write-Host "[5/5] Enabling Sidecar auto-injection..." -ForegroundColor Yellow
try {
    kubectl label namespace default istio-injection=enabled --overwrite
    Write-Host "OK: Sidecar injection enabled" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to enable sidecar injection: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "OK: Istio installation completed!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart Pods: kubectl rollout restart deployment api-v1 api-v2" -ForegroundColor Cyan
Write-Host "2. Deploy resources: kubectl apply -f k8s/v0.4/istio/" -ForegroundColor Cyan
Write-Host "3. Verify: kubectl get virtualservice" -ForegroundColor Cyan
Write-Host ""
