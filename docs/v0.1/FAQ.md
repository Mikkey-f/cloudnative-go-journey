# v0.1 常见问题 FAQ

> 收集 v0.1 开发和部署中的常见问题

---

## 🐳 Docker 相关

### Q1: 镜像构建失败，提示找不到 go.mod

**错误**：
```
COPY go.mod go.sum ./
ERROR: failed to compute cache key: "/go.mod" not found
```

**原因**：Docker 构建上下文不对，或者 go.mod 不在项目根目录

**解决**：
```powershell
# 确保在项目根目录执行
cd F:\workSpace\goWorkSpace\cloudnative-go-journey-plan
docker build -t cloudnative-go-api:v0.1 .
```

---

### Q2: 镜像大小超过 20MB，接近 150MB

**原因**：使用了单阶段构建，包含了完整的 Go 环境

**解决**：确保使用多阶段构建
```dockerfile
# 阶段 1：构建
FROM golang:1.21-alpine AS builder
...

# 阶段 2：运行（只复制二进制）
FROM alpine:latest
COPY --from=builder /app/api .
```

---

### Q3: 容器启动失败，提示权限问题

**错误**：
```
standard_init_linux.go:228: exec user process caused: permission denied
```

**原因**：二进制文件没有执行权限

**解决**：在 Dockerfile 中添加
```dockerfile
RUN chmod +x /app/api
```

---

### Q4: 健康检查一直失败

**错误**：Docker 容器状态显示 (unhealthy)

**原因**：
1. 应用启动慢，healthcheck 太早开始
2. 健康检查路径错误
3. 端口不对

**解决**：
```dockerfile
# 增加启动等待时间
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
```

---

## ☸️ Kubernetes 相关

### Q5: Pod 状态一直是 ImagePullBackOff

**错误**：
```
NAME                          READY   STATUS             RESTARTS   AGE
api-server-xxx                0/1     ImagePullBackOff   0          2m
```

**原因**：Minikube 找不到镜像（镜像只在本地 Docker，没在 Minikube）

**解决**：
```powershell
# 加载镜像到 Minikube
minikube image load cloudnative-go-api:v0.1

# 验证
minikube image ls | Select-String "cloudnative"

# 重启 Deployment
kubectl rollout restart deployment api-server
```

---

### Q6: Pod 状态是 CrashLoopBackOff

**错误**：
```
NAME                          READY   STATUS             RESTARTS   AGE
api-server-xxx                0/1     CrashLoopBackOff   5          5m
```

**原因**：容器启动失败，不断重启

**解决**：
```powershell
# 查看日志
kubectl logs <pod-name>

# 常见原因：
# 1. 端口被占用（不太可能在容器内）
# 2. 环境变量配置错误
# 3. 代码有 bug

# 查看详细信息
kubectl describe pod <pod-name>
```

---

### Q7: Pod 启动慢，Readiness Probe 失败

**错误**：
```
Warning  Unhealthy  10s (x5 over 30s)  kubelet  Readiness probe failed
```

**原因**：应用启动需要时间，但 Probe 等待时间太短

**解决**：调整 deployment.yaml
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10  # 增加等待时间
  periodSeconds: 5
```

---

### Q8: Service 无法访问，显示 Connection refused

**原因 1**：Endpoints 为空（Pod 没有被 Service 选中）

**解决**：
```powershell
# 检查 Endpoints
kubectl get endpoints api-service

# 如果 Endpoints 为空，检查标签
kubectl get pods --show-labels

# Service selector 和 Pod labels 必须匹配
```

**原因 2**：Pod 还没有 Ready

**解决**：
```powershell
# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -l app=api --timeout=60s
```

---

### Q9: minikube service 命令无法打开浏览器

**原因**：Windows 环境问题或浏览器未设置为默认

**解决**：
```powershell
# 获取 URL 手动访问
$url = minikube service api-service --url
Write-Host "Service URL: $url"

# 手动访问
curl $url/health

# 或在浏览器打开
Start-Process $url
```

---

### Q10: kubectl get pods 显示 Pending

**错误**：
```
NAME                          READY   STATUS    RESTARTS   AGE
api-server-xxx                0/1     Pending   0          2m
```

**原因**：资源不足或调度问题

**解决**：
```powershell
# 查看详情
kubectl describe pod <pod-name>

# 常见原因：
# 1. 节点资源不足
#    解决：minikube start --cpus=2 --memory=4096

# 2. PVC 未绑定（v0.1 不涉及）

# 3. 污点/容忍度问题
#    解决：检查 nodeSelector 和 tolerations
```

---

## 🔧 开发相关

### Q11: go mod download 很慢

**原因**：网络问题，访问国外源慢

**解决**：
```powershell
# 使用 Go 代理
go env -w GOPROXY=https://goproxy.cn,direct

# 或临时使用
$env:GOPROXY = "https://goproxy.cn,direct"
go mod download
```

---

### Q12: 修改代码后，K8s 里的 Pod 没有更新

**原因**：镜像标签相同（v0.1），K8s 认为镜像没变

**解决方法 1**：使用 imagePullPolicy: Always
```yaml
# deployment.yaml
containers:
- name: api
  image: cloudnative-go-api:v0.1
  imagePullPolicy: Always  # 总是拉取镜像
```

**解决方法 2**：重新加载镜像并重启（推荐）
```powershell
# 1. 重新构建
docker build -t cloudnative-go-api:v0.1 .

# 2. 重新加载到 Minikube
minikube image load cloudnative-go-api:v0.1

# 3. 重启 Deployment
kubectl rollout restart deployment api-server

# 4. 观察更新
kubectl rollout status deployment api-server
```

**解决方法 3**：使用唯一标签
```powershell
# 使用时间戳或 commit hash
docker build -t cloudnative-go-api:v0.1-20251026 .
```

---

### Q13: 本地运行正常，容器里报错

**原因**：环境差异

**常见问题**：
1. **文件路径问题**
   ```go
   // 错误：使用绝对路径
   f, _ := os.Open("C:\\config\\app.yaml")

   // 正确：使用相对路径或环境变量
   f, _ := os.Open("./config/app.yaml")
   ```

2. **依赖缺失**
   ```dockerfile
   # 确保所有依赖都在 go.mod 中
   RUN go mod download
   ```

3. **静态编译问题**
   ```dockerfile
   # 必须使用 CGO_ENABLED=0
   RUN CGO_ENABLED=0 go build ...
   ```

---

### Q14: Prometheus 指标没有数据

**原因**：没有请求或中间件没工作

**解决**：
```powershell
# 1. 发送几个请求
curl http://localhost:8080/api/v1/hello
curl http://localhost:8080/api/v1/hello
curl http://localhost:8080/health

# 2. 查看指标
curl http://localhost:8080/metrics | Select-String "api_requests"

# 应该看到：
# api_requests_total{endpoint="/api/v1/hello"...} 2
```

---

## 🌐 网络相关

### Q15: Windows 防火墙阻止连接

**症状**：Docker Desktop 或 Minikube 无法启动

**解决**：
1. 打开 Windows Defender 防火墙
2. 允许 Docker Desktop 和 VirtualBox
3. 或临时关闭防火墙测试

---

### Q16: 无法访问 NodePort

**原因**：Minikube 网络隔离

**解决**：
```powershell
# 方法 1：使用 minikube service（推荐）
minikube service api-service

# 方法 2：使用 kubectl port-forward
kubectl port-forward svc/api-service 8080:8080

# 方法 3：获取 Minikube IP
minikube ip
# 然后访问 http://<minikube-ip>:30080
```

---

## 🐛 其他问题

### Q17: Minikube 启动失败

**错误**：VT-x/AMD-v 未启用

**解决**：
1. 进入 BIOS
2. 启用虚拟化技术（Intel VT-x 或 AMD-V）
3. 重启电脑

---

### Q18: Docker Desktop 启动慢

**原因**：WSL2 或 Hyper-V 问题

**解决**：
```powershell
# 重启 Docker Desktop
# 或重启 WSL2
wsl --shutdown
```

---

### Q19: kubectl 命令找不到

**原因**：kubectl 没有添加到 PATH

**解决**：
```powershell
# 检查是否安装
kubectl version --client

# 如果未找到，重新安装或配置 PATH
```

---

### Q20: 想重置一切，从头开始

**完全清理**：
```powershell
# 1. 删除 K8s 资源
kubectl delete -f k8s/v0.1/

# 2. 删除 Minikube 集群
minikube delete

# 3. 删除 Docker 镜像
docker rmi cloudnative-go-api:v0.1

# 4. 重新开始
minikube start
# 然后按照部署文档重新操作
```

---

## 📚 更多帮助

- 📖 [部署指南](k8s/v0.1/README.md)
- 🎓 [K8s 基础知识](K8S-BASICS.md)
- 📝 [完成总结](COMPLETION-SUMMARY.md)
- 💬 [GitHub Issues](https://github.com/yourname/cloudnative-go-journey/issues)

---

**问题没有列出？** 欢迎提 Issue 或 PR 补充！
