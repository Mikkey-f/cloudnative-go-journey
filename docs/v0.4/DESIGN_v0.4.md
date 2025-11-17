# v0.4 架构设计文档 (DESIGN)

> 系统架构、模块设计、接口规范

**创建时间**: 2025-11-14  
**版本**: v0.4 - 服务治理版  
**状态**: 架构设计

---

## 🏗️ 整体架构

### 系统分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Layer 1: 入口层                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Ingress (Nginx Controller)                          │   │
│  │ ├─ 基于域名路由：app.local                          │   │
│  │ ├─ 基于路径路由：/api, /                            │   │
│  │ └─ HTTPS 终止（可选）                              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                Layer 2: 服务层                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Frontend Service │  │  API Service     │                │
│  │ (ClusterIP)      │  │  (ClusterIP)     │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│            Layer 3: 服务网格层 (Istio)                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ VirtualService + DestinationRule                    │   │
│  │ ├─ 流量路由规则                                    │   │
│  │ ├─ 金丝雀发布 (90/10)                              │   │
│  │ └─ 熔断、重试、超时                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              Layer 4: 数据平面层 (Envoy)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Envoy        │  │ Envoy        │  │ Envoy        │      │
│  │ Sidecar      │  │ Sidecar      │  │ Sidecar      │      │
│  │ (Frontend)   │  │ (API)        │  │ (Redis)      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              Layer 5: 应用层                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Frontend Pod │  │ API Pod      │  │ Redis Pod    │      │
│  │ (1 个)       │  │ (v1+v2)      │  │ (1 个)       │      │
│  │              │  │ (10 个)      │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 核心组件

#### 1. Ingress 层

**职责**: 外部流量入口

```yaml
# 配置示例
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: nginx
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

**特点**:
- K8s 原生资源
- 基于路径和域名的路由
- 支持 HTTPS/TLS
- 由 Nginx Ingress Controller 实现

---

#### 2. Service 层

**职责**: 服务发现和负载均衡

```yaml
# Frontend Service
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP

---
# API Service
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

**特点**:
- ClusterIP 类型（内部访问）
- 选择器匹配 Pod
- 负载均衡到后端 Pod

---

#### 3. Istio 服务网格层

**职责**: 应用层流量管理

##### 3.1 VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-vs
spec:
  hosts:
  - api-service
  http:
  - route:
    - destination:
        host: api-service
        subset: v1
      weight: 90
    - destination:
        host: api-service
        subset: v2
      weight: 10
    timeout: 5s
    retries:
      attempts: 3
      perTryTimeout: 2s
```

**职责**:
- 定义流量路由规则
- 支持百分比分流（金丝雀发布）
- 支持超时和重试

##### 3.2 DestinationRule

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-dr
spec:
  host: api-service
  trafficPolicy:
    connectionPool:
      http:
        http1MaxPendingRequests: 50
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

**职责**:
- 定义子集（基于标签）
- 配置连接池
- 配置熔断和异常检测

---

#### 4. Envoy 数据平面

**职责**: 流量拦截和执行

```
Pod 内部:
┌──────────────────────────┐
│ Pod                      │
│ ┌────────────────────┐   │
│ │ 应用容器           │   │
│ │ (Go 应用)          │   │
│ └────────────────────┘   │
│ ┌────────────────────┐   │
│ │ Envoy Sidecar      │   │
│ │ ├─ 拦截流量       │   │
│ │ ├─ 执行规则       │   │
│ │ ├─ 收集指标       │   │
│ │ └─ 记录日志       │   │
│ └────────────────────┘   │
└──────────────────────────┘
```

**职责**:
- 拦截进出 Pod 的所有流量
- 执行 VirtualService 规则
- 执行 DestinationRule 策略
- 收集流量指标

---

### 数据流向

#### 请求流程

```
1. 外部用户发送请求
   curl http://app.local/api/hello

2. Ingress 接收请求
   ├─ 匹配规则：/api → api-service
   └─ 转发到 api-service:8080

3. Service 负载均衡
   ├─ 选择一个 API Pod
   └─ 转发到 Pod IP:8080

4. Envoy Sidecar 拦截
   ├─ 读取 VirtualService 规则
   ├─ 决定转发到 v1 还是 v2
   │  └─ 90% 概率 → v1
   │  └─ 10% 概率 → v2
   └─ 转发到目标 Pod

5. 应用处理请求
   ├─ 处理业务逻辑
   └─ 返回响应

6. Envoy 记录指标
   ├─ 请求数
   ├─ 响应时间
   ├─ 错误率
   └─ 流量分配
```

---

## 📦 模块设计

### 前端服务模块

**文件**: `src/handler/frontend.go`

```go
package handler

import (
    "github.com/gin-gonic/gin"
)

// FrontendHandler 处理前端请求
func FrontendHandler(c *gin.Context) {
    // 返回简单的 HTML 页面
    // 展示系统架构和流量分配
}

// HealthCheck 健康检查
func FrontendHealthCheck(c *gin.Context) {
    // 返回 200 OK
}
```

**职责**:
- 返回前端 HTML 页面
- 展示系统架构
- 显示流量分配信息

---

### API 服务模块

**复用现有代码**:
- `src/handler/hello.go` - 基础接口
- `src/handler/info.go` - 信息接口
- `src/handler/cache.go` - 缓存接口
- `src/handler/data.go` - 数据接口

**新增接口**:
- `/api/v1/version` - 返回版本信息（用于验证金丝雀发布）

---

### 验证脚本模块

**文件**: `scripts/traffic-verify.sh`

```bash
#!/bin/bash

# 功能：验证金丝雀发布流量分配
# 方式：发送 100 个请求，统计 v1 和 v2 的比例

# 实现逻辑：
# 1. 发送 100 个请求到 /api/v1/version
# 2. 统计返回 "v1" 的次数
# 3. 统计返回 "v2" 的次数
# 4. 计算百分比
# 5. 验证是否在 85%-95% 范围内
```

---

## 🔌 接口契约定义

### HTTP 接口

#### 前端服务

```
GET /
├─ 返回前端 HTML 页面
├─ 状态码: 200
└─ Content-Type: text/html

GET /health
├─ 健康检查
├─ 返回: {"status": "healthy"}
└─ 状态码: 200
```

#### API 服务

```
GET /api/v1/version
├─ 返回版本信息
├─ 返回: {"version": "v1"} 或 {"version": "v2"}
└─ 状态码: 200

GET /api/v1/hello
├─ 返回问候信息
├─ 返回: {"message": "Hello from v1"}
└─ 状态码: 200

（其他现有接口保持不变）
```

---

## 🔄 部署流程

### 部署步骤

```
Step 1: 安装 Nginx Ingress Controller
  └─ minikube addons enable ingress

Step 2: 安装 Istio
  └─ istioctl install --set profile=demo -y

Step 3: 启用自动注入
  └─ kubectl label namespace default istio-injection=enabled

Step 4: 部署前端服务
  ├─ kubectl apply -f k8s/v0.4/frontend/deployment.yaml
  └─ kubectl apply -f k8s/v0.4/frontend/service.yaml

Step 5: 部署 API v1 和 v2
  ├─ kubectl apply -f k8s/v0.4/api/deployment-v1.yaml
  ├─ kubectl apply -f k8s/v0.4/api/deployment-v2.yaml
  └─ kubectl apply -f k8s/v0.4/api/service.yaml

Step 6: 配置 Ingress
  └─ kubectl apply -f k8s/v0.4/ingress/ingress.yaml

Step 7: 配置 Istio
  ├─ kubectl apply -f k8s/v0.4/istio/destination-rule.yaml
  └─ kubectl apply -f k8s/v0.4/istio/virtual-service.yaml

Step 8: 验证部署
  ├─ kubectl get pods
  ├─ kubectl get svc
  ├─ kubectl get ingress
  └─ kubectl get virtualservices
```

---

## 🧪 测试策略

### 单元测试

- ✅ 前端处理器测试
- ✅ API 版本接口测试
- ✅ 健康检查测试

### 集成测试

- ✅ Ingress 路由测试
- ✅ Service 负载均衡测试
- ✅ Istio 流量分流测试

### 验收测试

- ✅ 流量分配准确度测试（100 次请求）
- ✅ 金丝雀发布演示
- ✅ 故障转移测试

---

## 📊 性能指标

### 目标指标

| 指标 | 目标 | 说明 |
|------|------|------|
| Ingress 延迟 | < 100ms | 路由转发延迟 |
| Envoy 开销 | < 10% CPU | Sidecar 资源占用 |
| 流量分配准确度 | > 90% | 金丝雀发布准确度 |
| 服务可用性 | > 99% | 正常运行时间 |

---

## 🔒 安全设计

### 当前版本

- ✅ 基本的网络隔离（Service ClusterIP）
- ✅ 健康检查验证
- ✅ 错误处理和日志

### 后续版本（v1.0）

- ⏳ mTLS 加密
- ⏳ 授权策略
- ⏳ JWT 认证

---

## 📝 设计总结

**架构特点**:
- 分层清晰：入口层 → 服务层 → 网格层 → 数据平面 → 应用层
- 职责分明：每层有明确的职责
- 易于扩展：支持添加更多服务
- 便于学习：逐层理解云原生架构

**下一步**: 进入 **Atomize（任务分解）阶段**

---
