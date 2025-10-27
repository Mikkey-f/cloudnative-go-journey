# v0.1 故障排查指南

> 快速诊断和解决 v0.1 部署中的问题

---

## 🔍 快速诊断流程

```
遇到问题？按以下顺序检查：

1. Docker 是否运行？
   docker ps
   
2. Minikube 是否运行？
   minikube status
   
3. 镜像是否存在？
   minikube image ls | Select-String "cloudnative"
   
4. Pod 是否 Running？
   kubectl get pods
   
5. Service 是否有 Endpoints？
   kubectl get endpoints api-service
   
6. 健康检查是否通过？
   kubectl describe pod <pod-name> | Select-String "Liveness|Readiness"
```

---

## 🐳 Docker 问题

### 问题：Docker daemon 未运行

**症状**：
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**检查**：
```powershell
docker ps
```

**解决**：
1. 启动 Docker Desktop
2. 等待 Docker 完全启动（图标不再转动）
3. 重试命令

---

### 问题：镜像构建失败

**症状**：
```
ERROR [builder 3/6] RUN go mod download
```

**检查**：
```powershell
# 查看详细错误
docker build -t cloudnative-go-api:v0.1 . --no-cache

# 检查 go.mod
cat go.mod
```

**解决**：
```powershell
# 1. 确保 go.mod 存在且正确
go mod tidy

# 2. 设置 Go 代理（如果网络慢）
$env:GOPROXY = "https://goproxy.cn,direct"

# 3. 重新构建
docker build -t cloudnative-go-api:v0.1 .
```

---

### 问题：容器启动后立即退出

**症状**：
```
docker ps -a
# STATUS: Exited (1) 2 seconds ago
```

**检查**：
```powershell
# 查看日志
docker logs <container-id>
```

**常见原因**：
1. 二进制文件执行权限问题
2. 端口被占用
3. 配置错误

**解决**：
```powershell
# 进入容器调试（如果容器能启动）
docker run -it --entrypoint sh cloudnative-go-api:v0.1

# 手动执行
./api
```

---

## ☸️ Kubernetes 问题

### 问题：Pod 一直 Pending

**症状**：
```
NAME                READY   STATUS    RESTARTS   AGE
api-server-xxx      0/1     Pending   0          5m
```

**检查**：
```powershell
kubectl describe pod <pod-name>
```

**常见原因和解决**：

**原因 1：资源不足**
```
Events:
  Warning  FailedScheduling  Failed to schedule: Insufficient memory
```
**解决**：
```powershell
# 增加 Minikube 资源
minikube delete
minikube start --cpus=2 --memory=4096
```

**原因 2：节点没有 Ready**
```powershell
kubectl get nodes
# NAME       STATUS     ROLES           AGE
# minikube   NotReady   control-plane   5m
```
**解决**：等待节点 Ready 或重启 Minikube

---

### 问题：Pod 是 ImagePullBackOff

**症状**：
```
NAME                READY   STATUS             RESTARTS   AGE
api-server-xxx      0/1     ImagePullBackOff   0          2m
```

**检查**：
```powershell
kubectl describe pod <pod-name>
```

**原因**：镜像不在 Minikube 中

**解决**：
```powershell
# 1. 检查镜像是否存在
minikube image ls | Select-String "cloudnative"

# 2. 如果不存在，加载镜像
minikube image load cloudnative-go-api:v0.1

# 3. 删除 Pod 让它重新拉取
kubectl delete pod <pod-name>

# 4. 观察新 Pod
kubectl get pods -w
```

---

### 问题：Pod 是 CrashLoopBackOff

**症状**：
```
NAME                READY   STATUS             RESTARTS   AGE
api-server-xxx      0/1     CrashLoopBackOff   5          5m
```

**检查**：
```powershell
# 查看日志
kubectl logs <pod-name>

# 查看上一次容器的日志
kubectl logs <pod-name> --previous
```

**常见原因**：

**原因 1：应用启动失败**
```
# 日志显示：
panic: runtime error: invalid memory address
```
**解决**：修复代码 bug

**原因 2：端口冲突（不太可能）**
```
# 日志显示：
bind: address already in use
```
**解决**：检查是否有其他容器使用相同端口

**原因 3：健康检查太严格**
```
Events:
  Warning  Unhealthy  Liveness probe failed
```
**解决**：调整探针参数
```yaml
livenessProbe:
  initialDelaySeconds: 30  # 增加启动等待时间
  failureThreshold: 5      # 增加失败容忍次数
```

---

### 问题：Pod Running 但 Service 无法访问

**症状**：
```
kubectl get pods
# NAME                READY   STATUS    RESTARTS   AGE
# api-server-xxx      1/1     Running   0          2m

curl http://<service-url>/health
# curl: (7) Failed to connect
```

**检查清单**：

**1. Service 是否存在？**
```powershell
kubectl get svc api-service
```

**2. Endpoints 是否有 Pod IP？**
```powershell
kubectl get endpoints api-service

# 应该看到：
# NAME          ENDPOINTS
# api-service   10.244.0.5:8080,10.244.0.6:8080
```

**3. 标签是否匹配？**
```powershell
# Service selector
kubectl get svc api-service -o yaml | Select-String "selector" -Context 2

# Pod labels
kubectl get pods --show-labels
```

**4. Pod 是否 Ready？**
```powershell
kubectl get pods

# READY 应该是 1/1，不是 0/1
```

**解决**：

**如果 Endpoints 为空**：
```yaml
# 检查 Service 的 selector 是否匹配 Pod 的 labels

# service.yaml
spec:
  selector:
    app: api  # ← 这个

# deployment.yaml
template:
  metadata:
    labels:
      app: api  # ← 必须匹配
```

**如果 Pod 不 Ready**：
```powershell
# 查看 Readiness Probe
kubectl describe pod <pod-name> | Select-String "Readiness"

# 测试健康检查端点
kubectl port-forward pod/<pod-name> 8080:8080
curl http://localhost:8080/ready
```

---

### 问题：无法通过 NodePort 访问

**症状**：
```
minikube service api-service
# 浏览器打开，但连接失败
```

**检查**：
```powershell
# 1. 获取 Minikube IP
minikube ip

# 2. 获取 NodePort
kubectl get svc api-service
# PORT(S): 8080:30080/TCP
#               ↑ NodePort

# 3. 手动访问
curl http://<minikube-ip>:30080/health
```

**解决**：

**方法 1：使用 service 命令**
```powershell
minikube service api-service --url
# 使用返回的 URL
```

**方法 2：使用 port-forward**
```powershell
kubectl port-forward svc/api-service 8080:8080
# 然后访问 http://localhost:8080
```

---

## 🔧 开发问题

### 问题：修改代码后 Pod 没有更新

**原因**：镜像标签没变，K8s 认为镜像相同

**解决**：
```powershell
# 完整的更新流程
# 1. 重新构建镜像
docker build -t cloudnative-go-api:v0.1 .

# 2. 重新加载到 Minikube
minikube image load cloudnative-go-api:v0.1

# 3. 滚动重启 Deployment
kubectl rollout restart deployment api-server

# 4. 观察更新过程
kubectl rollout status deployment api-server

# 5. 验证更新
kubectl get pods
kubectl logs -l app=api --tail=20
```

---

### 问题：健康检查失败

**症状**：
```
Events:
  Warning  Unhealthy  Readiness probe failed: Get "http://...": dial tcp: connect: connection refused
```

**检查**：
```powershell
# 1. Pod 内测试
kubectl exec -it <pod-name> -- sh
wget -O- http://localhost:8080/health

# 2. 端口转发测试
kubectl port-forward pod/<pod-name> 8080:8080
curl http://localhost:8080/health
```

**常见原因**：

**原因 1：应用启动慢**
```yaml
# 增加等待时间
readinessProbe:
  initialDelaySeconds: 10  # 从 5 改为 10
```

**原因 2：健康检查路径错误**
```yaml
# 确保路径正确
readinessProbe:
  httpGet:
    path: /ready  # 不是 /health
    port: 8080
```

**原因 3：端口不对**
```yaml
# 确保端口匹配
readinessProbe:
  httpGet:
    port: 8080  # 必须和容器端口一致
```

---

## 📊 监控和日志

### 实时查看日志

```powershell
# 所有 api Pod 的日志
kubectl logs -l app=api -f --tail=50

# 特定 Pod 的日志
kubectl logs <pod-name> -f

# 上一次容器的日志（如果 Pod 重启了）
kubectl logs <pod-name> --previous
```

### 查看事件

```powershell
# 所有事件（按时间排序）
kubectl get events --sort-by=.metadata.creationTimestamp

# 只看 Warning
kubectl get events --field-selector type=Warning

# 特定 Pod 的事件
kubectl describe pod <pod-name> | Select-String "Events:" -Context 0,20
```

### 查看资源使用

```powershell
# 启用 metrics-server
minikube addons enable metrics-server

# 等待 1-2 分钟后
kubectl top nodes
kubectl top pods
```

---

## 🛠️ 调试命令

### 进入 Pod 调试

```powershell
# 进入 Pod 的 shell
kubectl exec -it <pod-name> -- sh

# 在 Pod 内：
ps aux              # 查看进程
netstat -tuln       # 查看端口
wget -O- http://localhost:8080/health  # 测试接口
```

### 临时 Debug Pod

```powershell
# 创建一个临时 Pod 用于调试
kubectl run debug --image=alpine --rm -it -- sh

# 在 debug Pod 内测试
apk add curl
curl http://api-service:8080/health
```

### 端口转发

```powershell
# 转发 Service
kubectl port-forward svc/api-service 8080:8080

# 转发特定 Pod
kubectl port-forward pod/<pod-name> 8080:8080

# 后台运行
Start-Job -ScriptBlock { kubectl port-forward svc/api-service 8080:8080 }
```

---

## 🔄 重置和清理

### 重启所有

```powershell
# 1. 重启 Deployment（Pod 会滚动更新）
kubectl rollout restart deployment api-server

# 2. 重启 Minikube
minikube stop
minikube start
```

### 完全清理

```powershell
# 1. 删除 K8s 资源
kubectl delete -f k8s/v0.1/

# 2. 删除所有 Pod（强制）
kubectl delete pods --all --grace-period=0 --force

# 3. 删除 Minikube 集群
minikube delete

# 4. 重新开始
minikube start
```

---

## 📞 获取帮助

如果以上方法都无法解决问题：

1. **收集信息**：
   ```powershell
   # 保存所有相关信息到文件
   kubectl get all > debug-info.txt
   kubectl describe pod <pod-name> >> debug-info.txt
   kubectl logs <pod-name> >> debug-info.txt
   minikube logs >> debug-info.txt
   ```

2. **查看文档**：
   - [FAQ](FAQ.md)
   - [K8s 基础知识](K8S-BASICS.md)
   - [部署指南](../../k8s/v0.1/README.md)

3. **寻求帮助**：
   - 提 [GitHub Issue](https://github.com/yourname/cloudnative-go-journey/issues)
   - 附上收集的信息
   - 描述复现步骤

---

**记住：90% 的问题都是配置错误或镜像问题！** 🔍
