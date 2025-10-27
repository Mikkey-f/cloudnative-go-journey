# 快速开始指南

> 5 分钟快速部署 CloudNative Go Journey v0.1

## 前置要求

```bash
✅ Go 1.21+
✅ Docker Desktop
✅ kubectl
✅ Minikube
```

---

## 🚀 一键部署

### 方法 1：逐步执行（推荐初学者）

```powershell
# 1. 克隆项目
git clone https://github.com/yourname/cloudnative-go-journey.git
cd cloudnative-go-journey

# 2. 下载依赖
go mod tidy

# 3. 本地测试（可选）
go run src/main.go
# 另开终端测试：curl http://localhost:8080/health
# Ctrl+C 停止

# 4. 构建 Docker 镜像
docker build -t cloudnative-go-api:v0.1 .

# 5. 启动 Minikube
minikube start

# 6. 加载镜像到 Minikube
minikube image load cloudnative-go-api:v0.1

# 7. 部署到 K8s
kubectl apply -f k8s/v0.1/

# 8. 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=api --timeout=60s

# 9. 访问服务
minikube service api-service
```

---

### 方法 2：自动化脚本

```powershell
# 运行部署脚本（如果提供）
.\scripts\deploy-v0.1.ps1
```

---

## 🔍 验证部署

```powershell
# 查看所有资源
kubectl get all

# 预期输出：
# NAME                              READY   STATUS    RESTARTS   AGE
# pod/api-server-xxx                1/1     Running   0          1m
# pod/api-server-yyy                1/1     Running   0          1m
#
# NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
# service/api-service   NodePort    10.96.123.45    <none>        8080:30080/TCP   1m
#
# NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/api-server   2/2     2            2           1m
```

---

## 🧪 测试接口

```powershell
# 获取服务 URL
$url = minikube service api-service --url

# 健康检查
curl "$url/health"
# 输出：{"status":"healthy","uptime":"1m30s"}

# Hello 接口
curl "$url/api/v1/hello?name=World"
# 输出：{"message":"Hello, World!","pod":"api-server-xxx","timestamp":"..."}

# 应用信息
curl "$url/api/v1/info"
# 输出：{"app":"cloudnative-go-journey","version":"v0.1.0",...}

# Prometheus 指标
curl "$url/metrics"
# 输出：# HELP api_requests_total ...
```

---

## 📊 查看运行状态

```powershell
# 查看 Pod
kubectl get pods

# 查看 Pod 日志
kubectl logs -l app=api -f

# 查看 Pod 详情
kubectl describe pod <pod-name>

# 查看 Service
kubectl get svc api-service

# 查看 Endpoints
kubectl get endpoints api-service
```

---

## 🛠️ 常用操作

### 扩容/缩容

```powershell
# 扩容到 3 个副本
kubectl scale deployment api-server --replicas=3

# 缩容到 1 个副本
kubectl scale deployment api-server --replicas=1
```

### 查看日志

```powershell
# 实时查看所有 Pod 日志
kubectl logs -l app=api -f --tail=50

# 查看特定 Pod 日志
kubectl logs <pod-name> -f
```

### 重启 Pod

```powershell
# 滚动重启
kubectl rollout restart deployment api-server

# 删除 Pod（会自动重建）
kubectl delete pod <pod-name>
```

### 端口转发（调试用）

```powershell
# 转发到本地 8080
kubectl port-forward svc/api-service 8080:8080

# 然后访问 http://localhost:8080
```

---

## 🧹 清理资源

```powershell
# 删除 K8s 资源
kubectl delete -f k8s/v0.1/

# 停止 Minikube
minikube stop

# 删除 Minikube 集群（可选）
minikube delete

# 删除 Docker 镜像（可选）
docker rmi cloudnative-go-api:v0.1
```

---

## ❌ 故障排查

### Pod 状态不是 Running

```powershell
# 查看 Pod 详情
kubectl describe pod <pod-name>

# 查看事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 常见问题：
# - ImagePullBackOff → 镜像没加载到 Minikube
#   解决：minikube image load cloudnative-go-api:v0.1
#
# - CrashLoopBackOff → 容器启动失败
#   解决：kubectl logs <pod-name>
```

### Service 无法访问

```powershell
# 检查 Endpoints
kubectl get endpoints api-service

# 如果 Endpoints 为空：
# 1. 检查 Pod 是否 Ready
kubectl get pods

# 2. 检查标签是否匹配
kubectl get pods --show-labels

# 3. 检查健康检查
kubectl describe pod <pod-name> | Select-String -Pattern "Liveness|Readiness" -Context 3
```

### 端口冲突

```powershell
# 如果 30080 端口被占用，修改 Service
kubectl edit svc api-service

# 或删除 nodePort 行，让 K8s 自动分配
```

---

## 📚 下一步

- 📖 阅读 [v0.1 完成总结](docs/v0.1/COMPLETION-SUMMARY.md)
- 🎓 学习 [Kubernetes 基础知识](docs/v0.1/K8S-BASICS.md)
- 🚀 准备 v0.2：StatefulSet、DaemonSet、CronJob

---

## 💡 小贴士

```
1. 修改代码后重新部署：
   docker build -t cloudnative-go-api:v0.1 .
   minikube image load cloudnative-go-api:v0.1
   kubectl rollout restart deployment api-server

2. 查看实时日志：
   kubectl logs -l app=api -f

3. 快速测试：
   curl $(minikube service api-service --url)/health

4. 查看资源使用（需要 metrics-server）：
   minikube addons enable metrics-server
   kubectl top pods
```

---

**快速开始成功？开始探索云原生的世界吧！** 🌟
