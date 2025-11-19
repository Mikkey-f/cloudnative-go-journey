# 🚀 v0.5 部署和测试命令清单（PowerShell）

> **v0.5 版本说明**: 聚焦配置管理功能，仅包含后端服务。前端服务请参考 v0.4。

## 📦 v0.5 核心功能

- ✅ Viper 多配置源加载
- ✅ ConfigMap 动态挂载
- ✅ 配置热更新（fsnotify）
- ✅ 配置管理 API
- ✅ 配置验证和默认值
- ✅ 多环境管理（dev/staging/prod）

---

## 📋 前置准备

### 1. 检查环境

```powershell
# 检查 Go 版本
go version

# 检查 Docker
docker version

# 检查 Kubernetes
kubectl cluster-info
kubectl get nodes

# 检查 Minikube（如果使用）
minikube status
```

### 2. 更新 Go 依赖

```powershell
# 进入项目根目录
cd f:\workSpace\goWorkSpace\cloudnative-go-journey-plan

# 更新依赖
go get github.com/spf13/viper@v1.18.2
go get github.com/fsnotify/fsnotify@v1.7.0
go get github.com/go-playground/validator/v10@v10.16.0
go mod tidy

# 验证依赖
go list -m all | Select-String "viper|fsnotify|validator"
```

### 3. 验证编译

```powershell
cd src\backend
go build -o backend.exe .

# 查看生成的文件
ls backend.exe
```

---

## 🏠 本地测试（无 K8s）

### 启动本地 Redis（可选）

```powershell
# 使用 Docker 启动 Redis
docker run -d --name redis-local -p 6379:6379 redis:alpine

# 验证 Redis
docker ps | Select-String redis
```

### 启动服务

```powershell
# 方式 1: 直接运行
cd src\backend
go run main.go

# 方式 2: 编译后运行
.\backend.exe

# 方式 3: 指定环境变量
$env:REDIS_HOST="localhost"
$env:REDIS_PORT="6379"
.\backend.exe
```

### 测试配置 API

```powershell
# 1. 健康检查
Invoke-WebRequest -Uri "http://localhost:8080/health" -Method GET

# 2. 获取完整配置（脱敏）
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config" -Method GET | ConvertTo-Json -Depth 10

# 3. 获取指定字段
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/log.level" -Method GET | ConvertTo-Json

# 4. 获取可热更新字段列表
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/hot-reloadable" -Method GET | ConvertTo-Json

# 5. 手动触发配置重载
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/reload" -Method POST | ConvertTo-Json

# 使用 curl（如果安装了）
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/config
```

---

## 🐳 Docker 镜像构建

### 构建镜像

```powershell
# 回到项目根目录
cd f:\workSpace\goWorkSpace\cloudnative-go-journey-plan

# 构建后端镜像（v0.5 仅包含后端）
docker build -f docker\v0.5\Dockerfile -t api:v0.5.0 .

# 查看镜像
docker images | Select-String "api.*v0.5"

# 查看镜像详情
docker inspect api:v0.5.0
```

### 本地测试镜像

```powershell
# 运行容器（连接本地 Redis）
docker run -d --name api-v0.5-test `
  -p 8080:8080 `
  -e REDIS_HOST=host.docker.internal `
  -e REDIS_PORT=6379 `
  api:v0.5.0

# 查看容器状态
docker ps | Select-String api-v0.5

# 查看容器日志
docker logs api-v0.5-test

# 测试容器
Invoke-RestMethod -Uri "http://localhost:8080/health"

# 清理容器
docker stop api-v0.5-test
docker rm api-v0.5-test
```

---

## ☸️ Minikube 环境准备

### 启动 Minikube

```powershell
# 启动 Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# 验证状态
minikube status
kubectl get nodes
```

### 切换到 Minikube Docker 环境

```powershell
# 获取 Docker 环境变量
minikube docker-env --shell powershell | Invoke-Expression

# 验证是否切换成功
docker ps | Select-String k8s

# 重新构建镜像（在 Minikube 内部）
cd f:\workSpace\goWorkSpace\cloudnative-go-journey-plan
docker build -f docker\v0.5\Dockerfile -t api:v0.5.0 .

# 验证镜像在 Minikube 中
docker images | Select-String api
```

### 部署 Redis（如果需要）

```powershell
# 部署 Redis
kubectl apply -f k8s\v0.4\redis\deployment.yaml
kubectl apply -f k8s\v0.4\redis\service.yaml

# 验证 Redis
kubectl get pods -l app=redis
kubectl get svc redis-service
```

---

## 🚀 K8s 部署（多环境）

### 部署 Dev 环境

```powershell
# 应用配置
kubectl apply -k k8s\v0.5\overlays\dev

# 查看资源
kubectl get all -l env=dev
kubectl get configmap -l env=dev

# 等待 Pod 就绪
kubectl rollout status deployment/dev-api -n default

# 查看 Pod 详情
kubectl get pods -l env=dev -o wide

# 查看 Pod 日志
kubectl logs -l env=dev --tail=50

# 描述 ConfigMap
kubectl describe configmap dev-api-config
```

### 部署 Staging 环境

```powershell
kubectl apply -k k8s\v0.5\overlays\staging
kubectl get pods -l env=staging
kubectl rollout status deployment/staging-api
kubectl logs -l env=staging --tail=30
```

### 部署 Prod 环境

```powershell
kubectl apply -k k8s\v0.5\overlays\prod
kubectl get pods -l env=prod
kubectl rollout status deployment/prod-api
kubectl logs -l env=prod --tail=30
```

### 查看所有环境

```powershell
# 查看所有 v0.5 Pod
kubectl get pods -l version=v0.5

# 查看所有 ConfigMap
kubectl get configmap | Select-String api-config

# 查看所有 Service
kubectl get svc | Select-String api-service
```

---

## 🔍 访问和测试服务

### 端口转发

```powershell
# Dev 环境（新开 PowerShell 窗口）
kubectl port-forward svc/dev-api-service 8080:80

# Staging 环境
kubectl port-forward svc/staging-api-service 8081:80

# Prod 环境
kubectl port-forward svc/prod-api-service 8082:80
```

### 测试 Dev 环境

```powershell
# 健康检查
Invoke-RestMethod -Uri "http://localhost:8080/health"

# 获取配置
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config" | ConvertTo-Json -Depth 10

# 获取日志级别
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/log.level" | ConvertTo-Json

# 获取可热更新字段
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/hot-reloadable" | ConvertTo-Json

# 版本接口
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/version" | ConvertTo-Json
```

### 测试 Staging 环境

```powershell
Invoke-RestMethod -Uri "http://localhost:8081/health"
Invoke-RestMethod -Uri "http://localhost:8081/api/v1/config" | ConvertTo-Json
```

### 测试 Prod 环境

```powershell
Invoke-RestMethod -Uri "http://localhost:8082/health"

# Prod 环境配置 API 应该被禁用
Invoke-RestMethod -Uri "http://localhost:8082/api/v1/config"
```

---

## 🔥 配置热更新测试

### 方式 1: 编辑 ConfigMap

```powershell
# 1. 获取 Pod 名称
$POD_NAME = kubectl get pods -l app=api,env=dev -o jsonpath='{.items[0].metadata.name}'
Write-Host "Pod Name: $POD_NAME"

# 2. 查看当前配置
kubectl exec $POD_NAME -- cat /etc/config/config.yaml

# 3. 编辑 ConfigMap（修改 log.level 从 debug 改为 info）
kubectl edit configmap dev-api-config

# 或者使用 patch 方式
kubectl patch configmap dev-api-config --type merge -p @'
{
  "data": {
    "config.yaml": "server:\n  environment: \"development\"\n  version: \"v0.5.0-dev\"\n\nlog:\n  level: \"info\"\n  enable_stacktrace: true\n\nredis:\n  pool_size: 5"
  }
}
'@

# 4. 等待同步（最多 120 秒）
Start-Sleep -Seconds 60

# 5. 验证配置文件已更新
kubectl exec $POD_NAME -- cat /etc/config/config.yaml

# 6. 查看应用日志（看是否有配置重载消息）
kubectl logs $POD_NAME --tail=30

# 7. 验证 API 配置已更新
kubectl exec $POD_NAME -- curl -s localhost:8080/api/v1/config/log.level
```

### 方式 2: 手动触发重载

```powershell
# 端口转发
kubectl port-forward $POD_NAME 8080:8080

# 手动触发重载
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/reload" -Method POST | ConvertTo-Json
```

### 方式 3: 监控配置变更

```powershell
# 实时查看日志，等待配置变更
kubectl logs $POD_NAME -f | Select-String "配置"
```

---

## 📊 查看和调试

### 查看 ConfigMap

```powershell
# 查看 ConfigMap 列表
kubectl get configmap -l version=v0.5

# 查看详情
kubectl describe configmap dev-api-config

# 导出为 YAML
kubectl get configmap dev-api-config -o yaml

# 查看具体配置内容
kubectl get configmap dev-api-config -o jsonpath='{.data.config\.yaml}'
```

### 查看 Pod 配置挂载

```powershell
$POD_NAME = kubectl get pods -l app=api,env=dev -o jsonpath='{.items[0].metadata.name}'

# 查看挂载点
kubectl exec $POD_NAME -- ls -la /etc/config

# 查看配置文件
kubectl exec $POD_NAME -- cat /etc/config/config.yaml

# 进入 Pod 交互式 Shell
kubectl exec -it $POD_NAME -- /bin/sh
```

### 查看日志

```powershell
# 查看最近日志
kubectl logs -l env=dev --tail=100

# 实时查看
kubectl logs -l env=dev -f

# 查看所有容器日志
kubectl logs -l env=dev --all-containers=true

# 查看前一个容器日志（如果重启过）
kubectl logs $POD_NAME --previous
```

### 查看事件

```powershell
# 查看 Pod 事件
kubectl describe pod $POD_NAME

# 查看命名空间事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 过滤错误事件
kubectl get events --field-selector type=Warning
```

---

## 🧪 完整测试流程

```powershell
# ============================================
# 第一步: 准备环境
# ============================================
cd f:\workSpace\goWorkSpace\cloudnative-go-journey-plan

# 更新依赖
go mod tidy

# 编译验证
cd src\backend
go build -o backend.exe .
cd ..\..

# ============================================
# 第二步: 构建镜像
# ============================================
# 启动 Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# 切换 Docker 环境
minikube docker-env --shell powershell | Invoke-Expression

# 构建后端镜像（v0.5 仅后端）
docker build -f docker\v0.5\Dockerfile -t api:v0.5.0 .

# 验证镜像
docker images | Select-String "api.*v0.5"

# ============================================
# 第三步: 部署 Redis（如果需要）
# ============================================
kubectl apply -f k8s\v0.4\redis\deployment.yaml
kubectl apply -f k8s\v0.4\redis\service.yaml
kubectl wait --for=condition=ready pod -l app=redis --timeout=60s

# ============================================
# 第四步: 部署 Dev 环境
# ============================================
kubectl apply -k k8s\v0.5\overlays\dev

# 等待就绪
kubectl rollout status deployment/dev-api --timeout=2m

# 查看状态
kubectl get pods -l env=dev
kubectl get configmap -l env=dev

# ============================================
# 第五步: 端口转发（新开窗口）
# ============================================
$POD_NAME = kubectl get pods -l app=api,env=dev -o jsonpath='{.items[0].metadata.name}'
kubectl port-forward $POD_NAME 8080:8080

# ============================================
# 第六步: 测试 API（另一个窗口）
# ============================================
# 健康检查
Invoke-RestMethod -Uri "http://localhost:8080/health"

# 获取配置
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config" | ConvertTo-Json -Depth 5

# 获取日志级别
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/log.level" | ConvertTo-Json

# 获取可热更新字段
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/hot-reloadable" | ConvertTo-Json

# ============================================
# 第七步: 测试热更新
# ============================================
# 查看当前配置
kubectl exec $POD_NAME -- cat /etc/config/config.yaml

# 修改 ConfigMap
kubectl edit configmap dev-api-config
# 修改 log.level: debug -> info

# 等待同步（120秒内）
Start-Sleep -Seconds 60

# 验证更新
kubectl exec $POD_NAME -- cat /etc/config/config.yaml
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config/log.level" | ConvertTo-Json

# 查看日志
kubectl logs $POD_NAME --tail=30

# ============================================
# 第八步: 清理（可选）
# ============================================
kubectl delete -k k8s\v0.5\overlays\dev
kubectl delete -f k8s\v0.4\redis\
```

---

## 🧹 清理环境

### 删除指定环境

```powershell
# 删除 Dev
kubectl delete -k k8s\v0.5\overlays\dev

# 删除 Staging
kubectl delete -k k8s\v0.5\overlays\staging

# 删除 Prod
kubectl delete -k k8s\v0.5\overlays\prod
```

### 删除所有 v0.5 资源

```powershell
# 删除所有带标签的资源
kubectl delete all -l version=v0.5
kubectl delete configmap -l version=v0.5
```

### 清理 Docker

```powershell
# 停止并删除本地容器
docker stop api-v0.5-test
docker rm api-v0.5-test
docker stop redis-local
docker rm redis-local

# 删除镜像
docker rmi api:v0.5.0
```

### 停止 Minikube

```powershell
# 停止
minikube stop

# 删除（谨慎）
minikube delete
```

---

## 🔧 常用调试命令

### 问题排查

```powershell
# Pod 无法启动
kubectl describe pod $POD_NAME
kubectl logs $POD_NAME
kubectl get events --field-selector involvedObject.name=$POD_NAME

# ConfigMap 未生效
kubectl get configmap dev-api-config -o yaml
kubectl exec $POD_NAME -- ls -la /etc/config

# 服务无法访问
kubectl get svc -l env=dev
kubectl get endpoints -l env=dev

# 镜像拉取失败
kubectl describe pod $POD_NAME | Select-String -Pattern "Image|Pull"
```

### 性能监控

```powershell
# 查看资源使用
kubectl top nodes
kubectl top pods -l env=dev

# 查看 Pod 详情
kubectl get pod $POD_NAME -o yaml
```

---

## 💡 提示和技巧

### PowerShell 技巧

```powershell
# 设置别名
Set-Alias k kubectl

# 保存常用命令
function Get-DevPod {
    kubectl get pods -l app=api,env=dev -o jsonpath='{.items[0].metadata.name}'
}

# 快速查看日志
function Show-DevLogs {
    kubectl logs -l env=dev --tail=50 -f
}

# 快速测试配置
function Test-Config {
    Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config" | ConvertTo-Json -Depth 5
}
```

### 环境变量设置

```powershell
# 临时设置
$env:KUBECONFIG="C:\Users\YourName\.kube\config"

# 持久化设置（添加到 PowerShell Profile）
notepad $PROFILE
# 添加: $env:KUBECONFIG="C:\Users\YourName\.kube\config"
```

---

## 📚 参考资源

- **脚本**: `scripts/v0.5/*.sh`（Bash 版本，可在 Git Bash 中运行）
- **K8s 配置**: `k8s/v0.5/README.md`
- **架构设计**: `docs/v0.5/DESIGN_v0.5.md`
- **任务分解**: `docs/v0.5/TASK_v0.5.md`

---

**祝部署顺利！** 🎉

有任何问题随时反馈！
