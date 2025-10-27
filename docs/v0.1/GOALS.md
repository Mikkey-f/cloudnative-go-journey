# v0.1 - 基础版 交付目标

## 🎯 核心目标

通过 v0.1，你将学会：
1. ✅ 开发一个生产级的 Go HTTP API 服务
2. ✅ 使用多阶段构建打包轻量 Docker 镜像（< 20MB）
3. ✅ 理解 Kubernetes 核心资源：Pod、Deployment、Service
4. ✅ 配置健康检查和资源限制
5. ✅ 在本地 Minikube 集群部署和访问服务

## 📋 具体交付物

### 1. Go 服务代码
- [x] HTTP 服务器（使用 Gin 框架）
- [x] 健康检查接口（`/health`）
- [x] 业务接口（`/api/hello`）
- [x] Prometheus 指标接口（`/metrics`）
- [x] 日志中间件
- [x] 配置管理

### 2. Docker 镜像
- [x] 多阶段 Dockerfile
- [x] 镜像大小 < 20MB
- [x] 使用非 root 用户运行
- [x] 健康检查配置

### 3. Kubernetes 配置
- [x] Deployment 配置
  - 副本数：2
  - 资源限制（CPU/内存）
  - 健康检查探针
- [x] Service 配置
  - NodePort 类型
  - 端口映射

### 4. 文档
- [x] 项目 README
- [x] v0.1 部署说明
- [x] 本地开发指南

## 🎓 Kubernetes 核心概念（你需要学习的）

### Pod（最小部署单元）
```
Pod = 一个或多个容器的集合
- 共享网络命名空间
- 共享存储卷
- 临时的、可替换的
```

### Deployment（部署控制器）
```
Deployment 管理 Pod 的生命周期
- 声明期望的副本数
- 滚动更新
- 回滚能力
- 自动重启失败的 Pod
```

### Service（服务发现和负载均衡）
```
Service 为 Pod 提供稳定的访问入口
- ClusterIP: 集群内部访问
- NodePort: 节点端口暴露（我们用这个）
- LoadBalancer: 云厂商负载均衡
```

### 健康检查
```
Liveness Probe（存活探针）
- 检测容器是否还活着
- 失败 → 重启容器

Readiness Probe（就绪探针）
- 检测容器是否准备好接收流量
- 失败 → 从 Service 移除
```

## ✅ 验收标准

完成 v0.1 后，你应该能够：

1. **本地运行**
   ```bash
   go run src/main.go
   curl http://localhost:8080/health
   # 返回: {"status":"healthy"}
   ```

2. **Docker 运行**
   ```bash
   docker build -t cloudnative-go-api:v0.1 .
   docker run -p 8080:8080 cloudnative-go-api:v0.1
   curl http://localhost:8080/health
   ```

3. **Kubernetes 部署**
   ```bash
   kubectl apply -f k8s/v0.1/
   kubectl get pods
   # 显示 2 个 Running 的 Pod
   
   minikube service api-service
   # 浏览器打开服务
   ```

4. **健康检查验证**
   ```bash
   kubectl describe pod <pod-name>
   # 看到 Liveness 和 Readiness 都是成功的
   ```

5. **资源限制验证**
   ```bash
   kubectl top pod
   # 查看资源使用情况
   ```

## 📊 预计时间

- **有 Docker 基础** + **会 Go**：2-3 天
- **边学 K8s**：再加 1-2 天
- **总计**：3-5 天（每天 2-3 小时）

## 🎁 额外收获

完成后你还会学到：
- Go 项目的标准结构
- Prometheus 指标暴露
- 优雅关闭服务
- 多阶段构建优化技巧
- K8s YAML 配置技巧
- kubectl 常用命令

---

**下一步：检查你的开发环境！**
