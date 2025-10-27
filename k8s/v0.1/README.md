# v0.1 部署指南

> 从零开始部署你的第一个云原生 Go 服务到 Kubernetes

## 📋 前置条件

✅ Go 1.21+  
✅ Docker Desktop  
✅ kubectl  
✅ Minikube

## 🚀 快速开始

### 1. 初始化 Go Module

```bash
# 在项目根目录
go mod tidy
```

### 2. 本地测试

```bash
# 运行服务
go run src/main.go

# 测试接口（另开一个终端）
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/hello
curl http://localhost:8080/api/v1/info
curl http://localhost:8080/metrics
```

预期输出：
```json
// /health
{"status":"healthy","uptime":"5s"}

// /api/v1/hello
{"message":"Hello, CloudNative!","pod":"","timestamp":"2024-01-01T00:00:00Z"}

// /api/v1/info
{"app":"cloudnative-go-journey","env":"","golang":"1.21+","hostname":"...","message":"Welcome to CloudNative Go Journey! 🚀","version":"v0.1.0"}
```

### 3. 构建 Docker 镜像

```bash
# 构建镜像
docker build -t cloudnative-go-api:v0.1 .

# 查看镜像
docker images | grep cloudnative-go-api

# 预期镜像大小 < 20MB
```

### 4. 测试 Docker 镜像

```bash
# 运行容器
docker run -d -p 8080:8080 --name api-test cloudnative-go-api:v0.1

# 测试
curl http://localhost:8080/health

# 查看日志
docker logs api-test

# 停止并删除
docker stop api-test
docker rm api-test
```

### 5. 启动 Minikube

```bash
# 启动 Minikube 集群
minikube start --driver=docker

# 验证
kubectl get nodes
# 应该看到一个 minikube 节点，状态为 Ready
```

### 6. 加载镜像到 Minikube

⚠️ **重要步骤**：Minikube 有独立的 Docker 环境，需要手动加载镜像

```bash
# 方法1：加载本地镜像（推荐）
minikube image load cloudnative-go-api:v0.1

# 方法2：在 Minikube 的 Docker 环境中构建
eval $(minikube docker-env)
docker build -t cloudnative-go-api:v0.1 .

# 验证镜像已加载
minikube image ls | grep cloudnative-go-api
```

### 7. 部署到 Kubernetes

```bash
# 应用配置
kubectl apply -f k8s/v0.1/

# 或者分别应用
kubectl apply -f k8s/v0.1/deployment.yaml
kubectl apply -f k8s/v0.1/service.yaml
```

### 8. 验证部署

```bash
# 查看所有资源
kubectl get all

# 查看 Pod（应该有2个）
kubectl get pods
# 等待状态变为 Running

# 查看 Pod 详细信息
kubectl describe pod <pod-name>

# 查看 Service
kubectl get svc
# 应该看到 api-service，类型为 NodePort
```

### 9. 访问服务

```bash
# 方法1：使用 Minikube service 命令（推荐，自动打开浏览器）
minikube service api-service

# 方法2：手动访问
# 获取 Minikube IP 和 NodePort
minikube ip
kubectl get svc api-service -o jsonpath='{.spec.ports[0].nodePort}'

# 访问 http://<minikube-ip>:30080/health

# 方法3：端口转发（开发调试用）
kubectl port-forward svc/api-service 8080:8080
# 然后访问 http://localhost:8080
```

### 10. 测试接口

```bash
# 获取服务 URL
export SERVICE_URL=$(minikube service api-service --url)

# 健康检查
curl $SERVICE_URL/health

# Hello 接口
curl $SERVICE_URL/api/v1/hello?name=Kubernetes

# 应用信息
curl $SERVICE_URL/api/v1/info

# Prometheus 指标
curl $SERVICE_URL/metrics
```

## 📊 验证清单

完成后，确保以下都正常：

### ✅ Pod 状态
```bash
kubectl get pods
# 应该有 2 个 Pod，状态都是 Running
```

### ✅ 健康检查
```bash
kubectl describe pod <pod-name> | grep -A 10 Liveness
kubectl describe pod <pod-name> | grep -A 10 Readiness
# 应该都显示成功
```

### ✅ 日志输出
```bash
kubectl logs -l app=api --tail=20
# 应该看到请求日志
```

### ✅ Service 可访问
```bash
curl $(minikube service api-service --url)/health
# 应该返回 {"status":"healthy",...}
```

## 🔍 常用调试命令

### 查看 Pod 日志
```bash
# 实时查看日志
kubectl logs -f <pod-name>

# 查看所有 api Pod 的日志
kubectl logs -l app=api --tail=50 -f
```

### 进入 Pod 调试
```bash
kubectl exec -it <pod-name> -- sh
```

### 查看 Pod 详细信息
```bash
kubectl describe pod <pod-name>
```

### 查看事件
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 查看资源使用（需要先启用 metrics-server）
```bash
# 启用 metrics-server
minikube addons enable metrics-server

# 等待 1-2 分钟后
kubectl top pods
kubectl top nodes
```

## 🧹 清理资源

### 删除 K8s 资源
```bash
# 删除部署
kubectl delete -f k8s/v0.1/

# 或者逐个删除
kubectl delete deployment api-server
kubectl delete service api-service

# 验证
kubectl get all
```

### 停止 Minikube
```bash
# 停止集群（保留数据）
minikube stop

# 删除集群（完全清理）
minikube delete
```

## ❌ 常见问题

### Q1: Pod 一直是 ImagePullBackOff 或 ErrImagePull

**原因**：Minikube 找不到镜像

**解决**：
```bash
# 确保镜像已加载到 Minikube
minikube image load cloudnative-go-api:v0.1

# 验证
minikube image ls | grep cloudnative-go-api
```

### Q2: Pod 一直是 CrashLoopBackOff

**原因**：容器启动失败

**解决**：
```bash
# 查看日志
kubectl logs <pod-name>

# 查看详细信息
kubectl describe pod <pod-name>

# 常见原因：
# 1. 代码有错误
# 2. 端口冲突
# 3. 健康检查配置错误
```

### Q3: Service 无法访问

**原因**：Service 配置或网络问题

**解决**：
```bash
# 检查 Service
kubectl get svc
kubectl describe svc api-service

# 检查 Pod 是否被选中
kubectl get endpoints api-service

# 使用端口转发测试
kubectl port-forward svc/api-service 8080:8080
curl http://localhost:8080/health
```

### Q4: go mod download 很慢

**解决**：使用 Go 代理
```bash
# Linux/Mac
export GOPROXY=https://goproxy.cn,direct

# Windows PowerShell
$env:GOPROXY = "https://goproxy.cn,direct"

# 或写入 go.mod 同级目录
go env -w GOPROXY=https://goproxy.cn,direct
```

### Q5: Minikube 启动失败

**解决**：
```bash
# 删除旧集群
minikube delete

# 重新启动
minikube start --driver=docker

# 如果还是失败，尝试其他驱动
minikube start --driver=virtualbox  # 或 hyperv
```

## 📚 下一步

完成 v0.1 后，你可以：

1. ✅ 修改代码，重新构建并部署
2. ✅ 尝试扩容：`kubectl scale deployment api-server --replicas=3`
3. ✅ 查看 Prometheus 指标并理解
4. ✅ 学习 v0.2：添加 StatefulSet、DaemonSet、CronJob

## 🎉 恭喜！

你已经成功部署了第一个云原生 Go 应用到 Kubernetes！

---

**有问题？** 查看 `docs/v0.1/TROUBLESHOOTING.md` 或提 Issue
