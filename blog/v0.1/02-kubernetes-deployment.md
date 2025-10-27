# 从零开始的云原生之旅（二）：第一次部署到 K8s

> Kubernetes 零基础到成功部署 | 记录所有踩过的坑

## 文章目录

- 前言
- 一、K8s 是个啥？（5 分钟速成）
  - 1.1 为什么需要 K8s
  - 1.2 三个核心概念
  - 1.3 流程图解
- 二、环境准备
  - 2.1 安装 Minikube
  - 2.2 启动本地集群
- 三、编写 K8s 配置
  - 3.1 Deployment - 告诉 K8s 运行什么
  - 3.2 Service - 告诉 K8s 怎么访问
  - 3.3 两者的关系
- 四、部署实战
  - 4.1 镜像加载（第一个大坑）
  - 4.2 应用部署
  - 4.3 访问服务
- 五、踩坑实录
  - 5.1 ImagePullBackOff（镜像找不到）
  - 5.2 标签不匹配（Service 找不到 Pod）
  - 5.3 负载均衡的大发现
- 六、验证和测试
- 结语

---

## 前言

上一篇《把 Go 应用塞进 Docker》中，我成功把镜像优化到了 16MB。

**现在面临新问题**：
- 镜像有了，怎么部署？
- 听说 Kubernetes 很强大，但完全不会
- 网上教程都是命令行，看不懂在干啥

**我的情况**：
- ✅ 会 Go
- ✅ 会 Docker 基础
- ❌ Kubernetes 零基础
- ❌ 不知道 Pod、Deployment、Service 是啥

如果你也是这样，这篇文章适合你！我会用**最白话的方式**讲清楚 K8s。

---

## 一、K8s 是个啥？（5 分钟速成）

### 1.1 为什么需要 K8s

我之前用 Docker 部署是这样的：

```bash
# 服务器 1
docker run -d -p 8080:8080 my-api:v1

# 服务器 2  
docker run -d -p 8080:8080 my-api:v1

# 问题来了：
❌ 容器挂了，要手动重启
❌ 流量怎么分配到 2 台服务器？
❌ 想扩容到 10 个容器？手动运行 10 次？
❌ 滚动更新？先停 1 个，启动新的，再停下一个...手动？
```

**Kubernetes 就是解决这些问题的**：
```
你告诉 K8s："我要 2 个容器"
K8s 自动：
✅ 创建 2 个容器
✅ 监控状态，挂了自动重启
✅ 负载均衡（自动分配流量）
✅ 滚动更新（自动替换旧版本）
✅ 扩缩容（改个数字就行）
```

**简单说**：K8s = Docker 的自动化管理工具。

---

### 1.2 三个核心概念

学 K8s 之前，我觉得概念太多了。后来发现，**入门只需要搞懂 3 个**：

#### **概念 1：Pod（最小单位）**

```
Pod = 一个或多个容器的组合

你的 Docker 容器 → 运行在 Pod 里
Pod 有自己的 IP（10.244.0.5）
Pod 是临时的（随时可能被删除重建）

类比：
Pod = 快递盒
容器 = 快递盒里的商品
```

**图示**：
```
┌─────────────────┐
│     Pod         │
│  ┌──────────┐   │
│  │ Container│   │  ← 你的 Go 程序
│  │(my-api)  │   │
│  └──────────┘   │
│  IP: 10.244.0.5 │
└─────────────────┘
```

---

#### **概念 2：Deployment（Pod 管理器）**

```
Deployment = 管理 Pod 的工具

你说：我要 2 个 Pod
Deployment 做：
  - 创建 2 个 Pod
  - Pod 挂了？自动重启
  - 要更新？自动滚动更新
  - 要扩容？自动创建新 Pod

类比：
Deployment = 工厂厂长
Pod = 工人
```

**图示**：
```
┌────────────────────────────┐
│   Deployment               │
│   "我要 2 个 Pod"          │
│                            │
│  ┌──────────┐ ┌──────────┐│
│  │  Pod 1   │ │  Pod 2   ││
│  └──────────┘ └──────────┘│
└────────────────────────────┘
```

---

#### **概念 3：Service（负载均衡器）**

```
问题：Pod IP 会变
Pod 1: 10.244.0.5  ← 重启后
Pod 1: 10.244.0.8  ← IP 变了！怎么访问？

Service = 稳定的访问入口
- 提供固定的 IP 和域名
- 自动找到后面的 Pod
- 自动负载均衡

类比：
Service = 公司前台
Pod = 具体的员工
找人 → 先找前台 → 前台帮你转接
```

**图示**：
```
外部请求
    ↓
┌─────────────────────┐
│  Service            │
│  (api-service)      │
│  IP: 10.96.123.45   │  ← 固定不变
└─────────┬───────────┘
          │ 负载均衡
     ┌────┴────┐
     ↓         ↓
  Pod 1     Pod 2
(IP 会变) (IP 会变)
```

**就这 3 个概念**，够用了！其他的边做边学。

---

### 1.3 流程图解

**完整的请求流程**：

```
用户浏览器
    ↓
http://192.168.49.2:30080/health  ← NodePort（节点端口，对外暴露）
    ↓
┌──────────────────────────────────┐
│  Minikube 节点                    │
│  (你的本地 K8s 集群)              │
│                                  │
│  Service (api-service)           │
│  "我来负载均衡"                   │
│      ↓                           │
│  ┌────┴────┐                     │
│  ↓         ↓                     │
│ Pod 1    Pod 2                   │
│ (你的   (你的                     │
│  容器)   容器)                    │
└──────────────────────────────────┘
```

---

## 二、环境准备

### 2.1 安装 Minikube

Minikube = 本地的 K8s 集群（用于学习和开发）

```powershell
# Windows 安装
choco install minikube

# 或下载安装包
https://minikube.sigs.k8s.io/docs/start/
```

### 2.2 启动本地集群

```bash
minikube start --cpus=2 --memory=4096

# 等待启动...
# 😄  Microsoft Windows 10 上的 minikube v1.32.0
# ✨  自动选择 docker 驱动
# 🐳  正在准备 Kubernetes v1.28.3...
# 🏄  Done! kubectl is now configured to use "minikube"

# 验证
kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.28.3
```

✅ 集群启动成功！

---

## 三、编写 K8s 配置

K8s 用 YAML 文件配置，我需要写 2 个文件。

### 3.1 Deployment - 告诉 K8s 运行什么

创建文件：`k8s/v0.1/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment          # 类型：Deployment
metadata:
  name: api-server        # Deployment 的名字
spec:
  replicas: 2             # 我要 2 个 Pod（重点！）
  
  selector:               # 我管理哪些 Pod？
    matchLabels:
      app: api            # 我管理 app=api 的 Pod
  
  template:               # Pod 模板（怎么创建 Pod）
    metadata:
      labels:
        app: api          # 给 Pod 打标签（重要！后面会用到）
    spec:
      containers:
      - name: api
        image: cloudnative-go-api:v0.1  # 我的镜像
        imagePullPolicy: IfNotPresent   # 本地镜像（重要！）
        
        ports:
        - containerPort: 8080
        
        # 资源限制（防止一个 Pod 占用所有资源）
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        
        # 健康检查（K8s 会定期访问这些接口）
        livenessProbe:           # 存活检查
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10  # 启动后等 10 秒再检查
          periodSeconds: 10        # 每 10 秒检查一次
        
        readinessProbe:          # 就绪检查
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**关键点标注**：
```
replicas: 2             ← 想要几个 Pod
selector.app: api       ← Deployment 管理哪些 Pod
template.labels.app: api ← Pod 的标签（必须和上面匹配！）
imagePullPolicy: IfNotPresent  ← 用本地镜像（重要！）
```

---

### 3.2 Service - 告诉 K8s 怎么访问

创建文件：`k8s/v0.1/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  type: NodePort        # 类型：节点端口（本地开发用）
  
  selector:             # 选择哪些 Pod？
    app: api            # 选择 app=api 的 Pod（和 Deployment 的标签对应！）
  
  ports:
  - port: 8080          # Service 端口
    targetPort: 8080    # Pod 端口
    nodePort: 30080     # 节点端口（30000-32767）
```

**关键连接点**：
```yaml
# Service 通过这个找 Pod
Service:
  selector:
    app: api      ← 关键：选择标签

# Deployment 给 Pod 打了这个标签
Deployment:
  template:
    metadata:
      labels:
        app: api  ← 关键：Pod 标签

# 两者通过标签连接！
```

---

### 3.3 两者的关系

**用图理解**：

```
┌──────────────────────────────┐
│  Service (api-service)       │
│  "我负责接收流量"            │
│                              │
│  selector: app=api           │
│  "我要找 app=api 的 Pod"     │
└──────────┬───────────────────┘
           │
           │ 通过标签选择
           ↓
┌──────────────────────────────┐
│  Deployment (api-server)     │
│  "我负责管理 Pod"            │
│                              │
│  replicas: 2                 │
│  template.labels: app=api    │
│  "我创建的 Pod 有这个标签"   │
│                              │
│  ┌─────────┐  ┌─────────┐   │
│  │ Pod 1   │  │ Pod 2   │   │
│  │app=api  │  │app=api  │   │
│  └─────────┘  └─────────┘   │
└──────────────────────────────┘

流量流向：
用户 → Service → 选择 Pod → 转发请求
```

**记住**：Deployment 和 Service 通过**标签（labels）**连接！

---

## 四、部署实战

### 4.1 镜像加载（第一个大坑）⚠️

我天真地以为：

```bash
# 1. 本地构建镜像
docker build -t cloudnative-go-api:v0.1 .

# 2. 直接部署到 K8s
kubectl apply -f k8s/v0.1/

# 3. 应该就能跑了吧？
```

**结果**：

```bash
kubectl get pods

# NAME                READY   STATUS             RESTARTS   AGE
# api-server-xxx      0/1     ImagePullBackOff   0          2m
#                             ↑ 这是啥？
```

**ImagePullBackOff** = 镜像拉取失败，不断重试。

**我查日志**：
```bash
kubectl describe pod api-server-xxx

# Events:
#   Warning  Failed   Failed to pull image "cloudnative-go-api:v0.1": 
#            rpc error: code = Unknown desc = Error response from daemon: 
#            pull access denied, repository does not exist or may require 'docker login'
```

**懵了**：镜像明明在本地 Docker 里啊！

---

**真相**：

```
Docker Desktop 的镜像
     ↕  不同的环境！
Minikube 的 Docker

┌──────────────────────┐
│  Windows 本机        │
│  Docker Desktop      │
│  镜像: my-api ✅     │
└──────────────────────┘
         ↕ 隔离！
┌──────────────────────┐
│  Minikube VM         │
│  独立的 Docker       │
│  镜像: 空 ❌         │  ← Minikube 里没有镜像！
└──────────────────────┘
```

**解决方法**：把镜像加载到 Minikube

```bash
# 关键命令！
minikube image load cloudnative-go-api:v0.1

# 验证
minikube image ls | grep cloudnative
# 看到镜像了 ✅
```

**这个坑浪费了我 30 分钟！** 😭

---

### 4.2 应用部署

镜像加载好后，开始部署：

```bash
# 应用配置文件
kubectl apply -f k8s/v0.1/

# 输出：
# deployment.apps/api-server created
# service/api-service created

# 查看 Pod
kubectl get pods

# 等待状态变成 Running...
# NAME                          READY   STATUS    RESTARTS   AGE
# api-server-59dfcf76d4-26psx   1/1     Running   0          30s
# api-server-59dfcf76d4-nlj5w   1/1     Running   0          30s
```

**看到 2 个 Pod 都是 Running**，激动啊！第一次成功！🎉

---

### 4.3 访问服务

**又遇到新问题**：Pod 跑起来了，怎么访问？

试了好几种方法：

#### **方法 1：minikube service（推荐）**

```bash
minikube service api-service

# 输出：
# ❗  因为你正在使用 windows 上的 Docker 驱动程序，所以需要打开终端才能运行它。
# |-----------|-------------|-------------|-------------------------|
# | NAMESPACE |    NAME     | TARGET PORT |           URL           |
# |-----------|-------------|-------------|-------------------------|
# | default   | api-service |        8080 | http://127.0.0.1:62218  |
# |-----------|-------------|-------------|-------------------------|
# 🎉  正通过默认浏览器打开服务 default/api-service...

# 浏览器自动打开，访问成功！✅
```

---

#### **方法 2：kubectl port-forward（调试用）**

```bash
kubectl port-forward svc/api-service 8080:8080

# 输出：
# Forwarding from 127.0.0.1:8080 -> 8080

# 然后访问 http://localhost:8080
```

**区别**：
```
minikube service → 经过 Service 负载均衡
port-forward    → 直连 Pod（不负载均衡）
```

---

## 五、踩坑实录

### 5.1 ImagePullBackOff（镜像找不到）

**完整排查过程**：

```bash
# 1. 发现问题
kubectl get pods
# STATUS: ImagePullBackOff

# 2. 查看详情
kubectl describe pod api-server-xxx

# 3. 看到报错
# Failed to pull image "cloudnative-go-api:v0.1"

# 4. 检查本地镜像
docker images | grep cloudnative
# 本地有啊！

# 5. 检查 Minikube 镜像
minikube image ls | grep cloudnative
# 空的！  ← 找到问题了

# 6. 解决
minikube image load cloudnative-go-api:v0.1

# 7. 删除 Pod 让它重建
kubectl delete pod api-server-xxx

# 8. 验证
kubectl get pods
# STATUS: Running  ← 成功！
```

**教训**：每次重新构建镜像，都要重新 `minikube image load`！

---

### 5.2 标签不匹配（Service 找不到 Pod）

**现象**：

```bash
kubectl get svc
# NAME          TYPE       CLUSTER-IP      PORT(S)          AGE
# api-service   NodePort   10.96.123.45    8080:30080/TCP   5m

# 访问服务
curl http://192.168.49.2:30080/health
# curl: (7) Failed to connect  ← 连不上！
```

**排查**：

```bash
# 检查 Endpoints（Service 找到的 Pod 列表）
kubectl get endpoints api-service

# NAME          ENDPOINTS
# api-service   <none>  ← 空的！Service 没找到任何 Pod！
```

**问题在哪**？

```bash
# 查看 Service 的 selector
kubectl get svc api-service -o yaml | grep -A 2 selector
# selector:
#   app: api-server  ← 这里

# 查看 Pod 的 labels
kubectl get pods --show-labels
# NAME             LABELS
# api-server-xxx   app=api  ← 这里

# 不匹配！！！
# Service 找 "app=api-server"
# Pod 标签是 "app=api"
# 当然找不到！
```

**我的错误**（deployment.yaml）：
```yaml
template:
  metadata:
    labels:
      app: api      # 写成了 api

# 但 service.yaml 里：
selector:
  app: api-server  # 写成了 api-server
```

**修复**：统一改成 `app: api`

```bash
# 重新应用配置
kubectl apply -f k8s/v0.1/

# 检查 Endpoints
kubectl get endpoints api-service
# NAME          ENDPOINTS
# api-service   10.244.0.5:8080,10.244.0.6:8080  ← 有了！
```

✅ 现在能访问了！

**教训**：Service selector 和 Pod labels 必须**完全一致**（区分大小写）！

---

### 5.3 负载均衡的大发现 ⭐

这是我觉得最有意思的一个发现。

#### **问题来了**

我想验证负载均衡，写了个脚本：

```powershell
# 启动 port-forward
kubectl port-forward svc/api-service 8080:8080

# 循环请求 30 次
for ($i=1; $i -le 30; $i++) {
    $response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/info"
    Write-Host "请求 $i : $($response.hostname)"
}
```

**结果**：
```
请求 1 : api-server-xxx
请求 2 : api-server-xxx
请求 3 : api-server-xxx
...
请求 30 : api-server-xxx  ← 全是同一个 Pod！
```

**我的疑问**：负载均衡呢？不是有 2 个 Pod 吗？

---

#### **开始调查**

```bash
# 1. 检查 Pod 数量
kubectl get pods
# 确实有 2 个 Pod，都在 Running

# 2. 检查 Endpoints
kubectl get endpoints api-service
# api-service   10.244.0.16:8080,10.244.0.18:8080
# 2 个 IP 都在，说明 2 个 Pod 都 Ready

# 3. 那为什么不负载均衡？
```

---

#### **真相揭晓**

Google 了一圈，终于明白了：

```
kubectl port-forward 的工作原理：

1. kubectl 看到你要转发 Service
2. kubectl 查询这个 Service 有哪些 Pod
3. kubectl 随机选一个 Pod（比如 26psx）
4. kubectl 和这个 Pod 建立 WebSocket 长连接
5. 你的所有请求都通过这个长连接转发

流程：
localhost:8080 
  → kubectl 长连接
  → 固定的 Pod (26psx)  ← 绕过了 Service！

所以：port-forward 不经过 Service，当然看不到负载均衡！
```

---

#### **正确的测试方法**

**在集群内部测试**（真实的使用场景）：

```bash
# 创建一个临时 Pod
kubectl run test-pod --image=alpine --rm -it -- sh

# 进入 Pod 后，安装 curl
apk add curl

# 测试负载均衡
for i in $(seq 1 20); do
    curl -s http://api-service:8080/api/v1/info | grep hostname
    sleep 0.2
done

# 退出
exit
```

**结果**：
```json
{"hostname":"api-server-26psx",...}  ← Pod 1
{"hostname":"api-server-nlj5w",...}  ← Pod 2  ✅ 切换了！
{"hostname":"api-server-26psx",...}  ← Pod 1  ✅ 又切换了！
{"hostname":"api-server-nlj5w",...}  ← Pod 2
...

统计：Pod 1 出现 13 次，Pod 2 出现 7 次
负载均衡正常！✅
```

**为什么集群内能看到负载均衡**？

```
集群内访问流程：
test-pod 
  → curl http://api-service:8080
  → DNS 解析 → 10.96.123.45（Service IP）
  → iptables 规则匹配
  → 随机选择一个 Pod
  → 转发请求 ✅

每次 curl 都是新连接
→ 每次都重新负载均衡 ✅
```

**网络路径对比**：

```
port-forward（不负载均衡）:
Windows → kubectl 隧道 → 固定 Pod

集群内访问（负载均衡）:
Pod → Service → iptables → 随机选 Pod
```

**恍然大悟**！

---

## 六、验证和测试

### 最终验证清单

```bash
# 1. Pod 状态
kubectl get pods
# 2 个 Pod，都是 Running ✅

# 2. Service 状态
kubectl get svc api-service
# TYPE: NodePort ✅

# 3. Endpoints
kubectl get endpoints api-service
# 2 个 IP:Port ✅

# 4. 浏览器访问
minikube service api-service
# 浏览器打开，能访问 ✅

# 5. 负载均衡（集群内测试）
kubectl run test --image=alpine --rm -it -- sh
apk add curl
for i in $(seq 1 20); do curl -s http://api-service:8080/api/v1/info | grep hostname; done
# 看到不同的 hostname ✅
```

全部通过！第一次 K8s 部署成功！🎊

---

## 结语

第一次部署到 Kubernetes，从完全不懂到成功运行，我学到了：

**核心概念**：
- Pod = 最小单位（容器组）
- Deployment = 管理 Pod（自动重启、更新）
- Service = 负载均衡器（稳定入口）

**关键技巧**：
- 镜像必须加载到 Minikube
- selector 和 labels 必须匹配
- port-forward 是调试工具，不走负载均衡
- 要测负载均衡，在集群内测

**踩过的坑**：
- ImagePullBackOff → `minikube image load`
- Service 找不到 Pod → 检查标签
- 看不到负载均衡 → 用对测试方法

**思维转变**：
```
Docker 思维：
- 我手动 run 容器
- 我手动管理

K8s 思维：
- 我告诉 K8s 我要什么（YAML）
- K8s 自动帮我实现
- 声明式 > 命令式
```

下一篇我会深入讲**健康检查和资源限制**的配置，这两个看似简单，但坑更多！

---

**本文完整代码**：https://github.com/yourname/cloudnative-go-journey

今天的分享到这里就结束啦！如果觉得文章还不错的话，欢迎：
- ⭐ 给项目点个 Star
- 💬 评论区聊聊你部署 K8s 时遇到的坑
- 📤 转发给正在学 K8s 的朋友

**你遇到过 ImagePullBackOff 吗？怎么解决的？欢迎评论区交流！**

---

**作者**：一个踩坑无数的云原生学习者  
**日期**：2025-10-27  
**系列**：CloudNative Go Journey v0.1

上一篇：[《从零开始的云原生之旅（一）：把 Go 应用塞进 Docker》](01-go-containerization.md)  
下一篇：[《从零开始的云原生之旅（三）：健康检查差点把我坑死》](03-health-checks-and-resources.md)
