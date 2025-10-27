# Kubernetes 基础知识速成（v0.1 必备）

> 边学边做，只讲 v0.1 需要用到的核心概念

## 🎯 学习目标

5 分钟理解 K8s 核心概念，够用于 v0.1 部署。

---

## 1. 什么是 Kubernetes？

```
Kubernetes (K8s) = 容器编排平台

你有很多 Docker 容器需要管理：
❌ 手动启动容器太麻烦
❌ 容器挂了需要手动重启
❌ 多个容器如何负载均衡？
❌ 配置如何管理？

✅ K8s 帮你自动化所有这些！
```

### 核心理念：声明式 API

```yaml
# 你告诉 K8s "我想要什么"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3  # 我要 3 个副本

# K8s 负责实现：
# - 创建 3 个 Pod
# - 监控它们的状态
# - 挂了自动重启
# - 始终保持 3 个 Running
```

---

## 2. 核心资源（v0.1 用到的）

### 📦 Pod - 最小部署单元

```
Pod = 一个或多个容器的组合

┌─────────────────┐
│     Pod         │
│  ┌──────────┐   │
│  │ Container│   │  ← 你的 Go 应用容器
│  └──────────┘   │
│                 │
│  IP: 10.1.2.3   │  ← Pod 有自己的 IP
└─────────────────┘

特点：
- Pod 是临时的（随时可能被删除重建）
- Pod 内容器共享网络和存储
- 通常不直接创建 Pod，而是通过 Deployment
```

**实际使用**：
```bash
# 查看 Pod
kubectl get pods

# 查看详细信息
kubectl describe pod <pod-name>

# 查看日志
kubectl logs <pod-name>

# 进入 Pod 执行命令
kubectl exec -it <pod-name> -- sh
```

---

### 🚀 Deployment - 部署控制器

```
Deployment = 管理 Pod 的控制器

你说：我要 3 个副本
K8s 做：
  1. 创建 3 个 Pod
  2. 持续监控
  3. Pod 挂了？立即重建
  4. 更新镜像？滚动更新
  5. 出问题？一键回滚

┌────────────────────────────┐
│      Deployment            │
│                            │
│  期望状态：3 个副本        │
│  当前状态：3 个副本        │
│                            │
│  ┌──────┐ ┌──────┐ ┌──────┐│
│  │ Pod1 │ │ Pod2 │ │ Pod3 ││
│  └──────┘ └──────┘ └──────┘│
└────────────────────────────┘
```

**配置示例**：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 2  # 副本数
  selector:
    matchLabels:
      app: api
  template:  # Pod 模板
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: your-image:v0.1
        ports:
        - containerPort: 8080
```

**常用命令**：
```bash
# 查看 Deployment
kubectl get deployments

# 扩容/缩容
kubectl scale deployment api-server --replicas=5

# 查看滚动更新状态
kubectl rollout status deployment api-server

# 回滚
kubectl rollout undo deployment api-server
```

---

### 🌐 Service - 服务发现和负载均衡

```
为什么需要 Service？

问题：Pod IP 会变化
  Pod1: 10.1.2.3  ← 重启后
  Pod1: 10.1.2.8  ← IP 变了！

解决：Service 提供稳定的访问入口
  Service: api-service (固定 IP: 10.96.0.10)
    ↓ 自动负载均衡
  ┌─────┬─────┬─────┐
  Pod1  Pod2  Pod3
```

**Service 类型**：

| 类型 | 用途 | 访问方式 |
|------|------|---------|
| **ClusterIP** | 集群内部访问 | 只能集群内访问 |
| **NodePort** | 通过节点端口暴露（v0.1 用这个） | `<NodeIP>:<NodePort>` |
| **LoadBalancer** | 云厂商负载均衡 | 云环境自动分配外部 IP |

**NodePort 示例**（v0.1 使用）：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: NodePort
  selector:
    app: api  # 选择哪些 Pod
  ports:
  - port: 8080        # Service 端口
    targetPort: 8080  # Pod 端口
    nodePort: 30080   # 节点端口（可选，自动分配 30000-32767）
```

访问方式：
```bash
# Minikube 环境
minikube service api-service

# 或手动访问
minikube ip  # 获取节点 IP
# 然后访问 http://<minikube-ip>:30080
```

---

## 3. 健康检查（Health Checks）

K8s 通过探针（Probe）检查容器健康状态：

### Liveness Probe（存活探针）

```
作用：检测容器是否还活着

失败 → K8s 重启容器

使用场景：
- 应用死锁
- 内存泄漏导致无响应
```

### Readiness Probe（就绪探针）

```
作用：检测容器是否准备好接收流量

失败 → 从 Service 摘除，不发送流量

使用场景：
- 应用启动中（加载配置、连接数据库）
- 临时过载，需要暂停接收请求
```

**配置示例**：
```yaml
containers:
- name: api
  image: api:v0.1
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30  # 启动后等待 30 秒
    periodSeconds: 10        # 每 10 秒检查一次
  
  readinessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
```

**探针类型**：
- `httpGet`：HTTP GET 请求（常用）
- `tcpSocket`：TCP 连接检查
- `exec`：执行命令

---

## 4. 资源限制（Resources）

为什么需要资源限制？
```
❌ 没有限制：一个容器吃掉所有内存，其他容器崩溃
✅ 有限制：每个容器只能用规定的资源
```

### Requests vs Limits

```yaml
resources:
  requests:  # 请求（保证资源）
    memory: "128Mi"
    cpu: "250m"
  limits:    # 限制（最大资源）
    memory: "256Mi"
    cpu: "500m"
```

| 字段 | 含义 | 说明 |
|------|------|------|
| **requests** | 保证资源 | K8s 调度时保证这么多资源 |
| **limits** | 最大资源 | 超过 CPU limit → 限流<br>超过内存 limit → 杀死容器 |

**单位说明**：
- CPU：`1` = 1核，`500m` = 0.5核，`250m` = 0.25核
- 内存：`128Mi` = 128 MiB，`1Gi` = 1 GiB

**最佳实践**：
```yaml
# 生产环境建议
resources:
  requests:
    memory: "128Mi"  # 保证 128Mi
    cpu: "100m"      # 保证 0.1 核
  limits:
    memory: "256Mi"  # 最多 256Mi
    cpu: "500m"      # 最多 0.5 核
```

---

## 5. 标签（Labels）和选择器（Selectors）

```
Labels = 资源的标签（键值对）
Selector = 用标签选择资源

┌────────────┐
│   Pod 1    │
│ app=api    │  ← 标签
│ env=prod   │
└────────────┘

Service 选择器：
  selector:
    app: api  ← 选择所有 app=api 的 Pod
```

**实际应用**：
```yaml
# Deployment 创建的 Pod 有标签
template:
  metadata:
    labels:
      app: api
      version: v0.1

# Service 通过标签选择 Pod
selector:
  app: api  # 选择所有 app=api 的 Pod
```

**查看标签**：
```bash
kubectl get pods --show-labels
kubectl get pods -l app=api  # 筛选 app=api 的 Pod
```

---

## 6. Namespace（命名空间）

```
Namespace = 资源隔离

default ← 默认命名空间（v0.1 用这个）
kube-system ← K8s 系统组件
kube-public ← 公共资源
```

v0.1 我们使用 `default` 命名空间，暂不深入。

---

## 7. kubectl 核心命令速查

### 查看资源
```bash
kubectl get pods                    # 查看 Pod
kubectl get deployments             # 查看 Deployment
kubectl get services                # 查看 Service
kubectl get all                     # 查看所有资源

kubectl get pods -o wide            # 显示更多信息（IP、节点）
kubectl get pods -w                 # 实时监控（watch）
```

### 详细信息
```bash
kubectl describe pod <pod-name>     # Pod 详细信息
kubectl describe deployment <name>  # Deployment 详细信息
kubectl describe service <name>     # Service 详细信息
```

### 日志和调试
```bash
kubectl logs <pod-name>             # 查看日志
kubectl logs <pod-name> -f          # 实时日志
kubectl logs <pod-name> --previous  # 查看上一个容器的日志

kubectl exec -it <pod-name> -- sh   # 进入容器
kubectl port-forward pod/<pod-name> 8080:8080  # 端口转发
```

### 应用配置
```bash
kubectl apply -f file.yaml          # 应用配置
kubectl apply -f directory/         # 应用目录下所有配置
kubectl delete -f file.yaml         # 删除资源
```

### 其他
```bash
kubectl get events                  # 查看事件
kubectl top pods                    # 查看资源使用（需要 metrics-server）
kubectl scale deployment <name> --replicas=3  # 扩缩容
```

---

## 8. Minikube 特定命令

```bash
# 启动集群
minikube start

# 停止集群
minikube stop

# 删除集群
minikube delete

# 查看状态
minikube status

# 获取 IP
minikube ip

# 访问 Service（自动打开浏览器）
minikube service <service-name>

# SSH 到 Minikube 节点
minikube ssh

# 查看 Dashboard
minikube dashboard
```

---

## 🎯 v0.1 工作流总结

```bash
# 1. 编写代码
# 2. 构建镜像
docker build -t api:v0.1 .

# 3. 加载到 Minikube（重要！）
minikube image load api:v0.1

# 4. 应用 K8s 配置
kubectl apply -f k8s/v0.1/

# 5. 查看部署
kubectl get pods
kubectl get svc

# 6. 访问服务
minikube service api-service

# 7. 查看日志
kubectl logs -l app=api

# 8. 清理
kubectl delete -f k8s/v0.1/
```

---

## 📚 进一步学习

- **官方教程**：https://kubernetes.io/zh-cn/docs/tutorials/
- **交互式学习**：https://killercoda.com/kubernetes
- **可视化工具**：安装 `k9s` 或使用 `minikube dashboard`

---

**恭喜！你已经掌握了 v0.1 需要的所有 K8s 知识！**

下一步：开始写代码 → `docs/v0.1/TUTORIAL.md`
