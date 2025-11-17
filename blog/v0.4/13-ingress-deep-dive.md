# 从零开始的云原生之旅（十三）：Ingress 深度剖析——从 Service 到统一入口

> 要掌握 Ingress，必须先看懂 Kubernetes 在 L4/L7 之间的分工，再理解 Ingress 资源与 Ingress Controller 的协作方式。

## 📖 文章目录

- [前言：为什么要在 Nginx 实战之前再写一篇 Ingress 文](#前言为什么要在-nginx-实战之前再写一篇-ingress-文)
- [一、回顾 Service 暴露方式：Ingress 的位置在哪？](#一回顾-service-暴露方式ingress-的位置在哪)
- [二、为什么需要 Ingress：从 URL 到后端的决策链路](#二为什么需要-ingress从-url-到后端的决策链路)
- [三、Ingress 三层架构：声明、控制器、数据面](#三ingress-三层架构声明控制器数据面)
- [四、Ingress 资源规范全解析](#四ingress-资源规范全解析)
  - [4.1 元数据与 IngressClass](#41-元数据与-ingressclass)
  - [4.2 规则匹配：Host、Path、Backend](#42-规则匹配hostpathbackend)
  - [4.3 PathType 与匹配策略](#43-pathtype-与匹配策略)
  - [4.4 默认后端与 404 处理](#44-默认后端与-404-处理)
- [五、IngressClass 与多控制器共存实践](#五ingressclass-与多控制器共存实践)
- [六、TLS 终止与证书管理](#六tls-终止与证书管理)
- [七、常见注解分类：让 Ingress 更聪明](#七常见注解分类让-ingress-更聪明)
- [八、请求生命周期：一次外部访问发生了什么](#八请求生命周期一次外部访问发生了什么)
- [九、Ingress Controller 生态对比](#九ingress-controller-生态对比)
- [十、Ingress 的局限与演进：何时选择 Istio](#十ingress-的局限与演进何时选择-istio)
- [十一、实战清单：排查与最佳实践](#十一实战清单排查与最佳实践)
- [结语：为下一篇 Istio 铺路](#结语为下一篇-istio-铺路)

---

## 前言：为什么要在 Nginx 实战之前再写一篇 Ingress 文

在《从 Service 到 Ingress：K8s 服务暴露完全指南》中，我们站在宏观视角梳理了四种服务暴露方式；而《Ingress Controller 实战：Nginx Ingress 深度解析》则直接进入实操。很多读者反馈在动手之前仍然对 **Ingress 本质** 与 **资源规范** 感到困惑。这篇文章正是为了解答：

- Ingress 是什么？在哪一层起作用？
- Ingress 资源、IngressController 与 Service 如何协作？
- PathType、IngressClass、默认后端等规范字段到底如何使用？
- 为什么 Ingress 做不到金丝雀、熔断？何时应该迁移到 Istio？

---

## 一、回顾 Service 暴露方式：Ingress 的位置在哪？

| 层级 | 方式 | 适用范围 | 能力 | 成本 |
|------|------|----------|------|------|
| L3/L4 | ClusterIP | 集群内部 | Pod 发现、负载均衡 | ✅ 低 |
| L3/L4 | NodePort | 集群外部（固定端口） | 暴露端口、无 L7 路由 | ⚠️ 中 |
| L3/L4 | LoadBalancer | 云厂商 / LB | 自动申请公网负载均衡 | ⚠️ 中 |
| **L7** | **Ingress** | **统一入口** | **基于域名/路径的应用层路由** | ⚠️ 中 |

Ingress 不是替代 Service，而是在 **LoadBalancer / NodePort** 之后，提供 **HTTP(S) 层的路由和策略**。

---

## 二、为什么需要 Ingress：从 URL 到后端的决策链路

设想一个 SaaS 平台：

```text
https://api.company.com/v1/users
https://dashboard.company.com/
https://admin.company.com/
```

没有 Ingress 时，我们要为每个服务单独暴露端口或者申请 LB，不仅浪费资源，也难以统一管理证书、WAF、重写等需求。Ingress 将不同域名和路径的 **路由决策集中管理**，所有外部请求统一先进入 Ingress，再由它决定转向哪个 Service。

---

## 三、Ingress 三层架构：声明、控制器、数据面

```mermaid
graph LR
    A[Ingress 资源<br/>networking.k8s.io/v1] -- watch --> B[Ingress Controller<br/>自定义控制器]
    B -- 配置下发 --> C[数据平面<br/>Nginx/Envoy/HAProxy]
    C -- L7 转发 --> D[Service]<br/>
```

1. **声明面（Ingress 资源）**：存储在 etcd 中的 YAML 配置，只负责描述路由规则。
2. **控制面（Ingress Controller）**：监听 Ingress 资源变化，生成具体实现（例如 Nginx 配置文件）。
3. **数据面（代理进程）**：真正接收请求并执行 HTTP 路由、TLS 终止等功能。

这三层缺一不可。单独创建 Ingress 资源而没有控制器，等同于写了 YAML 但无人执行。

---

## 四、Ingress 资源规范全解析

### 4.1 元数据与 IngressClass

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx  # 绑定特定控制器
```

- `metadata.annotations`：为控制器传递特定行为，如重写、限流。
- `spec.ingressClassName`：指定使用哪一个 Ingress Controller；未指定时依据默认 IngressClass。

### 4.2 规则匹配：Host、Path、Backend

```yaml
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

- `host`：域名匹配，可为空（匹配所有域）。
- `paths`：同一域名下的路径规则，顺序匹配。
- `backend`：最终转发到的 Service + Port。

### 4.3 PathType 与匹配策略

| PathType | 描述 | 典型用法 |
|----------|------|----------|
| `Prefix` | 基于前缀匹配，请求路径必须以 `/v1` 开头 | REST API 分组 |
| `Exact` | 完全匹配，大小写敏感 | 健康检查 `/healthz` |
| `ImplementationSpecific` | 由控制器自行定义，可能支持正则 | Nginx 特有 regex |

在 Kubernetes 1.22+ 中必须显式指定 `pathType`，避免歧义。

### 4.4 默认后端与 404 处理

```yaml
spec:
  defaultBackend:
    service:
      name: default-404
      port:
        number: 80
```

如果请求不匹配任何 `rules`，Ingress 会将其转发到默认后端。常见做法是部署一个返回统一 404 页面的 Service，避免泄露内部信息。

---

## 五、IngressClass 与多控制器共存实践

集群中可能同时存在多个控制器（如 Nginx、Traefik、HAProxy）。通过 IngressClass 可以显式声明使用哪一个：

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
```

控制器启动时会注册自己的 `controller` 字段，只处理匹配的 Ingress。这样我们可以：

- 将业务流量交给 Nginx，静态文件交给 Traefik。
- 在同一集群演练新的控制器而不影响旧流量。

---

## 六、TLS 终止与证书管理

Ingress 支持在入口处终止 TLS：

```yaml
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
```

关键要点：

1. Secret 必须是 `type: kubernetes.io/tls`，包含 `tls.crt` 和 `tls.key`。
2. 多个域名可以共享同一个证书（SAN）。
3. 控制器通常支持自动跳转 HTTP → HTTPS，可通过注解启用。
4. 在多租户环境下应当使用证书管理器（如 cert-manager）自动续期。

---

## 七、常见注解分类：让 Ingress 更聪明

虽然 Ingress 规范保持精简，但控制器提供了大量注解扩展。以 Nginx 为例：

| 分类 | 代表注解 | 功能 |
|------|----------|------|
| 重写/转发 | `nginx.ingress.kubernetes.io/rewrite-target` | URL 重写 |
| 超时/连接 | `nginx.ingress.kubernetes.io/proxy-read-timeout` | 转发超时 |
| 限流 | `nginx.ingress.kubernetes.io/limit-rps` | QPS 限制 |
| 认证 | `nginx.ingress.kubernetes.io/auth-url` | 外部鉴权 |
| Header | `nginx.ingress.kubernetes.io/configuration-snippet` | 自定义 Nginx 片段 |

⚠️ 注意：注解是控制器私有的，迁移到另一种控制器时需要重新审视配置等价性。

---

## 八、请求生命周期：一次外部访问发生了什么

1. **DNS** 将 `app.example.com` 解析到 LoadBalancer IP。
2. LB 将请求发送到 Kubernetes 节点上的 Ingress Controller Service。
3. Ingress Controller Pod 中的代理进程（Nginx/Envoy）接收请求。
4. 代理根据缓存的配置（由 Ingress 资源生成）匹配 Host/Path。
5. 代理与目标 Service 建立连接，并按负载均衡策略转发到 Pod。
6. Pod 返回响应，经由代理回传给客户端。

整个过程对应用透明，应用只需暴露 ClusterIP Service。

---

## 九、Ingress Controller 生态对比

| 控制器 | 实现 | 优势 | 局限 |
|--------|------|------|------|
| Nginx Ingress | Nginx + Lua | 成熟稳定，生态庞大 | 配置复杂，扩展需依赖注解 |
| Traefik | Go 原生 + CRD | 动态配置，内置服务发现 | 高级特性需要 Enterprise 版 |
| HAProxy Ingress | HAProxy | 高性能，支持高级 TCP | 社区相对较小 |
| Kong Ingress | Kong API Gateway | 原生支持 API 网关能力 | 资源占用高 |
| AWS/GCP Ingress | 云厂商 LB | 与云生态深度集成 | 绑定特定云厂商 |
| **Istio Gateway** | Envoy（服务网格入口） | 与 Service Mesh 深度结合 | 依赖 Istio 体系，成本高 |

---

## 十、Ingress 的局限与演进：何时选择 Istio

Ingress 专注于 **北向流量（North-South）**，无法解决以下需求：

- 服务之间的东西向流量治理（调用链、熔断、重试、指标）。
- 细粒度的流量切分（金丝雀、A/B 测试、镜像流量）。
- 零信任要求下的服务间 mTLS。

当系统演进到复杂微服务拓扑时，Ingress 往往成为瓶颈，这也是我们在 v0.4 中引入 Istio 的原因：

```text
Ingress → 解决统一入口问题
Istio   → 解决服务网格治理问题
```

---

## 十一、实战清单：排查与最佳实践

- **先验证控制器是否运行**：`kubectl get pods -n ingress-nginx`。
- **通过 events 排查**：`kubectl describe ingress app-ingress` 查看调度到哪个 IngressClass、是否创建成功。
- **善用默认后端**：提供统一错误页，便于观测未命中规则的流量。
- **避免过度依赖注解**：抽象复用常见配置，防止迁移困难。
- **分环境管理证书**：生产环境务必配置自动续期和审计。
- **监控代理指标**：关注连接数、响应时间、后端错误率。
- **与 Service 策略配合**：Service 的 SessionAffinity、ExternalTrafficPolicy 对链路有重要影响。

---

## 结语：为下一篇 Istio 铺路

至此，我们从概念、规范、生态和实践等维度彻底理解了 Ingress。它是进入 Kubernetes 北向流量的必经之路，却也有与生俱来的边界。下一篇《初探服务网格：Istio 让微服务更简单》将接棒，讲述如何在 Istio 中延续入口能力，并将流量治理扩展到整个微服务拓扑。

> 先理解好 Ingress 的角色，再拥抱 Istio，你会更清楚每一层的价值与取舍。
