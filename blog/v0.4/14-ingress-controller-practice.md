# 从零开始的云原生之旅（十四）：Ingress Controller 实战：Nginx Ingress 深度解析

> Ingress Controller 是应用层路由的核心，但要注意它与 Istio 的架构冲突！

## 📖 文章目录

- [前言](#前言)
- [一、Ingress Controller 深度解析](#一ingress-controller-深度解析)
- [二、Nginx Ingress 安装与配置](#二nginx-ingress-安装与配置)
- [三、高级路由配置实战](#三高级路由配置实战)
- [四、⚠️ Ingress vs Istio：架构冲突分析](#四️-ingress-vs-istio架构冲突分析)
- [五、从 Ingress 迁移到 Istio](#五从-ingress-迁移到-istio)
- [结语](#结语)

---

## 前言

在《Ingress 深度剖析：从 Service 到统一入口》中，我们已经把 Ingress 的概念、架构、PathType 等规范梳理清楚。带着这些“底层逻辑”来到实战环节，很多读者都会遇到和我一样的真实场景：

> 集群里既想用 Nginx Ingress 暴露服务，又想拥抱 Istio 的金丝雀发布，结果入口混乱、流量失控。

所以这篇文章不止是“如何安装一个 Ingress Controller”，而是围绕一个真实练手项目展开：

- ✅ 用 **场景化流程** 拆解 Nginx Ingress Controller 的工作机理
- ✅ 一步步部署、验证，并处理常见踩坑（hosts、端口、证书）
- ✅ 通过高级路由案例（路径、域名、TLS）提升实战深度
- ⚠️ **重点拆解** 与 Istio 共存时的架构冲突与决策
- ✅ 给出迁移 Istio 的“Checklist”，让演进有据可依

读完你应该能做到：先基于 Nginx Ingress 驾驭北向流量，然后在需要更强治理能力时从容迁移到服务网格。

---

## 一、Ingress Controller 深度解析

### 1.1 Ingress Controller 的工作原理

```text
外部请求 (http://app.local/api/v1/version)
    ↓
云 LoadBalancer / NodePort (127.0.0.1:80)
    ↓
Ingress Controller Pod (Nginx)
    ├─ 监听 Ingress 资源变化
    ├─ 动态生成 Nginx 配置
    └─ 执行 L7 路由
    ↓
根据 Ingress 规则匹配
    ├─ /api/* → api-service:8080
    └─ /* → frontend-service:8080
    ↓
目标 Service
    ↓
后端 Pod
```

从这个链路可以看到：

1. **入口统一**：外部请求无论来自浏览器还是脚本，都先命中集群层面的 LoadBalancer/NodePort。
2. **控制器监听**：Nginx Ingress Controller 持续 watch Kubernetes API，一旦 Ingress 资源变更就热更新自身配置。
3. **路由决策**：最终由 Nginx 进程执行 L7 规则，将请求转发到对应 Service，再由 kube-proxy 完成 Pod 级别的负载均衡。

只要记住“Ingress 负责描述、Controller 负责执行”，就不会再把 YAML 当成流量入口本身。

**核心组件**：
1. **Ingress 资源**: YAML 定义的路由规则
2. **Ingress Controller**: 实际的路由执行者（Nginx Pod）
3. **Service**: 路由的目标

### 1.2 Nginx Ingress Controller 内部机制

```bash
# Ingress Controller 会监听 K8s API
# 当发现 Ingress 资源变化时:

1. 获取所有 Ingress 规则
2. 生成 Nginx 配置文件
3. 执行 nginx -t (测试配置)
4. 执行 nginx -s reload (热重载)
```

**生成的 Nginx 配置示例**（真实存在于 Controller Pod 内部的 ConfigMap/临时文件中）：

```nginx
server {
    listen 80;
    server_name app.local;
    
    location /api {
        proxy_pass http://api-service.default.svc.cluster.local:8080;
    }
    
    location / {
        proxy_pass http://frontend-service.default.svc.cluster.local:8080;
    }
}
```

> 📌 提示：可以通过 `kubectl exec -n ingress-nginx <controller-pod> -- cat /etc/nginx/nginx.conf` 直接查看控制器实时生成的配置，有助于理解 YAML 与实际代理行为的映射关系。

---

## 二、Nginx Ingress 安装与配置

### 2.1 minikube 环境安装

在 v0.4 项目里我们使用 minikube 复现生产场景。确保你已经完成以下准备：

- 已启动 `minikube`，且 `kubectl config current-context` 指向该集群
- `kubectl get nodes` 状态为 `Ready`
- Docker daemon 可用（构建自定义镜像时需要）

安装步骤如下：

```bash
# 启用 Ingress 插件
minikube addons enable ingress

# 验证安装
kubectl get pods -n ingress-nginx
# NAME                                        READY   STATUS
# ingress-nginx-controller-xxx                1/1     Running

# 查看 Ingress Controller 的 Service
kubectl get svc -n ingress-nginx
# NAME                                 TYPE           EXTERNAL-IP   PORT(S)
# ingress-nginx-controller             LoadBalancer   <pending>     80:30080/TCP,443:30443/TCP
```

> 如果 Service 类型仍为 `LoadBalancer` 且 EXTERNAL-IP 始终 `<pending>`，在本地环境可以通过 `minikube tunnel` 命令为其分配一个可访问的本地地址。

### 2.2 使用 Ingress 暴露服务

```yaml
# k8s/v0.4/ingress/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: app.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 8080
```

这段 Ingress 做了三件事：明确使用 `nginx` 控制器、绑定 `app.local` 域名，以及为 `/api` 与 `/` 指定不同的 Service。配合 hosts 文件即可实现“同一域名对应多后端服务”的典型场景。

### 2.3 验证 Ingress

```bash
# 应用配置
kubectl apply -f k8s/v0.4/ingress/ingress.yaml

# 查看 Ingress
kubectl get ingress
# NAME          CLASS   HOSTS       ADDRESS     PORTS   AGE
# app-ingress   nginx   app.local   127.0.0.1   80      1m

# 配置 hosts 文件
# Windows: C:\Windows\System32\drivers\etc\hosts
# 127.0.0.1 app.local

# 测试访问
curl -H "Host: app.local" http://127.0.0.1/api/v1/version
```

执行完毕后，HTTP 头里的 Host 会被保存下来，Nginx Ingress 会根据规则将其转发到 `api-service`，返回版本信息。

### 2.4 常见问题与排查

| 现象 | 原因定位 | 解决办法 |
|------|----------|----------|
| `curl` 返回 404 | Host 未命中、路径不匹配 | 检查 `curl -v` 输出中的 `> Host:`，以及 Ingress `paths` 是否采用正确的 `pathType` |
| 浏览器访问报错 | hosts 文件未更新 | 重新编辑本地 hosts，或通过 `minikube tunnel` 暴露真实地址 |
| `kubectl get ingress` 地址为空 | Controller 未接管 | 确认 Ingress 上的 `ingressClassName` 与控制器配置一致 |
| HTTPS 报证书无效 | Secret 未创建或绑定错误 | 使用 `kubectl create secret tls` 创建 TLS Secret，并在 Ingress `tls` 段填入正确名称 |

---

## 三、高级路由配置实战

### 3.1 基于路径的精确路由

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: advanced-ingress
  annotations:
    # URL 重写
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: app.local
    http:
      paths:
      # /api/v1/* → api-service:8080/*
      - path: /api/v1(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

这里借助 `rewrite-target` 注解，把外部 `/api/v1/*` 映射为后端的 `/*`，既保持 URL 语义，也避免后端出现层级不一致的问题。

### 3.2 基于域名的多服务路由

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-domain-ingress
spec:
  rules:
  # api.example.com → api-service
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
  
  # web.example.com → frontend-service
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 8080
```

多域名场景在企业中非常常见。例如 `api.example.com` 暴露 REST API，而 `web.example.com` 提供静态页面。借助 Ingress 可以只用一个控制器统一接入。

### 3.3 配置 TLS/HTTPS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    # HTTP 自动跳转 HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 8080
```

TLS 配置的关键点在于证书管理：

1. 先通过 `kubectl create secret tls app-tls-secret --cert=cert.pem --key=key.pem` 创建 Secret；
2. 在 Ingress `tls` 中声明域名和 Secret 名称；
3. 如果希望 HTTP 自动跳转 HTTPS，可组合 `ssl-redirect` 注解。

---

## 四、⚠️ Ingress vs Istio：架构冲突分析

### 4.1 为什么不能混用？

**架构冲突**：

```text
┌──────────────────────────────────────────────┐
│  Ingress 架构                                 │
│                                              │
│  外部 → Nginx Ingress (80/443)               │
│           ↓                                  │
│        Service (ClusterIP)                   │
│           ↓                                  │
│        Pod (无 Sidecar)                      │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Istio 架构                                   │
│                                              │
│  外部 → Istio IngressGateway (80/443)        │
│           ↓                                  │
│        VirtualService (路由规则)              │
│           ↓                                  │
│        Pod (Envoy Sidecar)                   │
└──────────────────────────────────────────────┘
```

**冲突点**：

1. **端口冲突**：
   ```
   Nginx Ingress Controller:  80/443
   Istio IngressGateway:      80/443
   ❌ 两者都想监听相同端口
   ```

2. **流量路径不明确**：

   ```text
   外部请求到达后，走哪个入口？
   - 走 Nginx？那 Istio 的流量管理失效
   - 走 Istio？那 Ingress 配置无效
   ```

3. **配置冲突**：

   ```yaml
   # Ingress 说：/api 路由到 api-service
   - path: /api
     backend:
       service:
         name: api-service
   
   # VirtualService 说：/api/v1 按 90/10 分流
   - match:
     - uri:
         prefix: /api/v1
     route:
     - destination:
         host: api-service
         subset: v1
       weight: 90
   
   ❌ 谁优先？规则如何合并？
   ```

### 4.2 真实场景：我踩的坑

**问题现象**：
```bash
# 部署了 Ingress
kubectl apply -f k8s/v0.4/ingress/ingress.yaml

# 又部署了 Istio Gateway
kubectl apply -f k8s/v0.4/istio/gateway.yaml
kubectl apply -f k8s/v0.4/istio/virtual-service.yaml

# 测试访问
curl -H "Host: app.local" http://127.0.0.1/api/v1/version
# 返回: nginx 404 Not Found

# 问题：流量走到了 Nginx Ingress，但 Istio 的流量分配没生效！
```

**根本原因**：
- `minikube tunnel` 把 127.0.0.1:80 映射到了第一个 LoadBalancer Service
- 而 Nginx Ingress 的 Service 先于 Istio IngressGateway 创建
- 导致所有流量都进入 Nginx，Istio 完全被绕过

### 4.3 功能对比：Ingress vs Istio

| 功能 | Nginx Ingress | Istio Gateway |
|------|---------------|---------------|
| **基本路由** | ✅ 支持 | ✅ 支持 |
| **TLS/HTTPS** | ✅ 支持 | ✅ 支持 |
| **流量分割** | ❌ 不支持 | ✅ 支持（VirtualService weight） |
| **金丝雀发布** | ⚠️ 需要 Lua/Canary 模块 | ✅ 原生支持 |
| **熔断** | ❌ 不支持 | ✅ 支持（DestinationRule） |
| **限流** | ✅ 注解配置 | ✅ EnvoyFilter |
| **mTLS** | ❌ 不支持 | ✅ 自动 mTLS |
| **服务间路由** | ❌ 仅北向入口 | ✅ 东西向 + 南北向 |
| **观测能力** | ⚠️ 依赖外部方案 | ✅ 与 Prometheus/Kiali 紧耦合 |
| **资源消耗** | ✅ 低 | ⚠️ 高（每个 Pod 一个 Sidecar） |

如果想要更系统化地评估，可以回顾上一篇《Ingress 深度剖析》，先从功能、架构再到成本做出决策，再进入本篇的实践流程。

### 4.4 如何选择？

**选择 Ingress（Nginx）**：

```text
✅ 适用场景:
- 简单的 Web 应用或 BFF 层
- 只需要基于域名/路径的基本路由
- 对资源成本敏感、节点规格较小

❌ 不适用场景:
- 计划实施金丝雀、蓝绿、A/B Tests
- 希望统一治理东西向服务调用
- 需要服务间强制加密（mTLS）
```

**选择 Istio**：

```text
✅ 适用场景:
- 拥有多个微服务、需要跨多个版本的流量调度
- 对重试、熔断、限流、故障注入等治理能力有要求
- 需要搭建链路追踪、指标采集、可视化网格图

❌ 不适用场景:
- 只有少量服务且流量稳定
- 团队对服务网格缺乏运维经验
- 集群资源紧张（Sidecar 带来 CPU/内存开销）
```

---

## 五、从 Ingress 迁移到 Istio

### 5.1 迁移前的准备

**1. 确认迁移原因**：

```text
我的迁移原因：
✅ 需要实现 90/10 金丝雀发布
✅ 需要流量分割和灰度策略
✅ 后续需要 mTLS 和熔断功能
```

**2. 理解配置映射**：

| Ingress | Istio | 说明 |
|---------|-------|------|
| Ingress | Gateway | 入口定义 |
| Ingress rules | VirtualService | 路由规则 |
| Service | DestinationRule | 目标策略 |

### 5.2 迁移步骤

**步骤 1：安装 Istio**
```bash
# 下载 Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.20.0

# 安装（demo 配置，包含 IngressGateway）
istioctl install --set profile=demo -y

# 验证安装
kubectl get pods -n istio-system
```

**步骤 2：删除 Ingress（避免冲突）**
```bash
# ⚠️ 重要：先删除 Ingress
kubectl delete -f k8s/v0.4/ingress/ingress.yaml

# 确认删除
kubectl get ingress
# No resources found
```

**步骤 3：为 Pod 注入 Sidecar**
```yaml
# deployment-v1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v1
spec:
  template:
    metadata:
      labels:
        app: api
        version: v1
        sidecar.istio.io/inject: "true"  # 启用 Sidecar 注入
```

**步骤 4：创建 Istio Gateway**
```yaml
# k8s/v0.4/istio/gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: app-gateway
spec:
  selector:
    istio: ingressgateway  # 使用 Istio IngressGateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "app.local"
```

**步骤 5：创建 VirtualService**
```yaml
# k8s/v0.4/istio/virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-vs
spec:
  hosts:
  - api-service.default.svc.cluster.local
  - app.local
  gateways:
  - app-gateway  # 绑定到 Gateway
  - mesh         # 同时支持集群内部调用
  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: api-service.default.svc.cluster.local
        subset: v1
      weight: 90  # 90% 流量到 v1
    - destination:
        host: api-service.default.svc.cluster.local
        subset: v2
      weight: 10  # 10% 流量到 v2
```

**步骤 6：创建 DestinationRule**
```yaml
# k8s/v0.4/istio/destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-dr
spec:
  host: api-service.default.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

**步骤 7：部署和验证**
```bash
# 部署 Istio 配置
kubectl apply -f k8s/v0.4/istio/gateway.yaml
kubectl apply -f k8s/v0.4/istio/virtual-service.yaml
kubectl apply -f k8s/v0.4/istio/destination-rule.yaml

# 重启 Pod 使 Sidecar 生效
kubectl rollout restart deployment api-v1
kubectl rollout restart deployment api-v2

# 验证 Sidecar 注入
kubectl get pods
# NAME                      READY   STATUS
# api-v1-xxx                2/2     Running  ← 2/2 表示有 Sidecar
# api-v2-xxx                2/2     Running

# 测试访问
curl -H "Host: app.local" http://127.0.0.1/api/v1/version
```

### 5.3 迁移后的验证

**验证流量分配**：
```powershell
# 发起 100 次请求统计版本分布
$results = 1..100 | ForEach-Object {
  curl.exe -s -H "Host: app.local" http://127.0.0.1/api/v1/version |
    ConvertFrom-Json
}

$results | Group-Object version | Select-Object Name, Count
# Name Count
# ---- -----
# v1      88
# v2      12

# ✅ 符合 90/10 预期！
```

---

## 结语

这篇文章深入分析了 Ingress 和 Istio 的架构差异：

**核心要点**：
1. ⚠️ **Ingress 和 Istio Gateway 不能混用**，会导致端口冲突和路由混乱
2. 📊 **功能对比**：Ingress 简单易用，Istio 功能强大但复杂
3. 🔄 **迁移路径**：删除 Ingress → 部署 Istio → 注入 Sidecar → 配置路由
4. ✅ **验证方法**：检查 Sidecar 注入、测试流量分配

**我的选择**：
- 为了实现金丝雀发布（90/10 流量分割），选择了 Istio
- 删除了 Ingress 配置，避免冲突
- 成功实现了预期的流量分配效果

**下一步**：
- 深入学习 Istio 的流量管理
- 实现更复杂的灰度发布策略
- 探索 Istio 的熔断、限流等高级功能

---

**相关文章**：
- 上一篇：《从 Service 到 Ingress：K8s 服务暴露完全指南》
- 下一篇：《初探服务网格：Istio 让微服务更简单》
