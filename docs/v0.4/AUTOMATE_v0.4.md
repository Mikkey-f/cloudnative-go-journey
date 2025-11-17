# v0.4 自动化执行计划 (AUTOMATE)

> 代码实现、配置部署、脚本编写、文档交付

**创建时间**: 2025-11-14  
**版本**: v0.4 - 服务治理版  
**状态**: 自动化执行阶段

---

## 📋 执行计划概览

**总任务数**: 12 个原子任务  
**总时间**: 18 小时  
**执行周期**: 2-3 周  
**并行度**: 3 个任务可并行

---

## 🎯 Phase 1: 环境准备 (1 小时)

### Task 1: 环境准备

**目标**: 启用 Ingress Controller 和安装 Istio

**执行步骤**:

```bash
# 1. 启用 Nginx Ingress Controller
minikube addons enable ingress

# 2. 验证 Ingress 控制器
kubectl get pods -n ingress-nginx

# 3. 下载 Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.18.0

# 4. 安装 Istio
./bin/istioctl install --set profile=demo -y

# 5. 启用自动注入
kubectl label namespace default istio-injection=enabled

# 6. 验证 Istio 安装
kubectl get pods -n istio-system
```

**验收标准**:
- [ ] Ingress 控制器正常运行
- [ ] Istio 控制平面部署成功
- [ ] 自动注入已启用
- [ ] 所有 Pod 状态为 Running

**交付物**: 无代码，仅环境配置

---

## 🎯 Phase 2: 代码开发 (2 小时)

### Task 2: 前端服务开发

**目标**: 创建前端服务处理器和 HTML 页面

**文件**: `src/handler/frontend.go`

**执行步骤**:

1. **创建前端处理器**
   - 创建 `src/handler/frontend.go`
   - 实现 `FrontendHandler` 函数
   - 返回 HTML 页面
   - 包含系统架构展示
   - 包含流量分配信息

2. **创建 HTML 页面**
   - 简单的 HTML 页面
   - 展示系统架构图
   - 显示当前服务信息
   - 包含实时流量统计

3. **注册路由**
   - 在 `src/main.go` 中注册 `/` 路由
   - 注册 `/health` 健康检查

**代码框架**:

```go
package handler

import (
    "github.com/gin-gonic/gin"
)

// FrontendHandler 处理前端请求
func FrontendHandler(c *gin.Context) {
    // 返回 HTML 页面
    c.HTML(200, "index.html", gin.H{
        "title": "CloudNative Go Journey v0.4",
        "version": "v0.4",
    })
}

// HealthCheck 健康检查
func HealthCheck(c *gin.Context) {
    c.JSON(200, gin.H{
        "status": "healthy",
        "service": "frontend",
    })
}
```

**验收标准**:
- [ ] 代码编译通过
- [ ] 单元测试通过
- [ ] 本地运行正常
- [ ] 返回 HTML 页面正确

---

### Task 3: API v2 开发

**目标**: 创建 API v2 版本和版本接口

**文件**: 
- `src/handler/version.go` (新增)
- `Dockerfile.v2` (新增)

**执行步骤**:

1. **创建版本接口**
   - 创建 `src/handler/version.go`
   - 实现 `/api/v1/version` 接口
   - 返回 `{"version": "v2"}`

2. **构建 v2 Docker 镜像**
   - 创建 `Dockerfile.v2`
   - 复制 v1 Dockerfile
   - 修改版本标识为 v2
   - 构建镜像

3. **标记和推送镜像**
   - 标记镜像为 `api:v2`
   - 推送到本地仓库

**代码框架**:

```go
package handler

import "github.com/gin-gonic/gin"

// VersionHandler 返回版本信息
func VersionHandler(c *gin.Context) {
    c.JSON(200, gin.H{
        "version": "v2",
        "service": "api",
    })
}
```

**验收标准**:
- [ ] 代码编译通过
- [ ] Docker 镜像构建成功
- [ ] 镜像大小 < 50MB
- [ ] `/api/v1/version` 返回 v2

---

## 🎯 Phase 3: 配置部署 (2 小时)

### Task 4: Ingress 配置

**目标**: 创建 Ingress 配置文件

**文件**: `k8s/v0.4/ingress/ingress.yaml`

**执行步骤**:

1. **创建目录结构**
   ```bash
   mkdir -p k8s/v0.4/ingress
   mkdir -p k8s/v0.4/istio
   mkdir -p k8s/v0.4/frontend
   mkdir -p k8s/v0.4/api
   ```

2. **创建 Ingress 配置**
   - 配置基于路径的路由
   - `/api` → api-service
   - `/` → frontend-service
   - 支持域名 `app.local`

3. **创建部署脚本**
   - `k8s/v0.4/ingress/deploy.sh`
   - 应用 Ingress 配置

**配置框架**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
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

**验收标准**:
- [ ] Ingress 创建成功
- [ ] 配置文件格式正确
- [ ] 路由规则清晰
- [ ] 部署脚本可执行

---

### Task 5: Istio 安装验证

**目标**: 验证 Istio 部署和自动注入

**执行步骤**:

1. **验证 Istio 控制平面**
   ```bash
   kubectl get pods -n istio-system
   kubectl get svc -n istio-system
   ```

2. **验证自动注入**
   ```bash
   kubectl label namespace default istio-injection=enabled
   kubectl get namespace default --show-labels
   ```

3. **部署测试 Pod**
   - 部署一个测试 Pod
   - 验证 Envoy Sidecar 自动注入

**验收标准**:
- [ ] Istiod 正常运行
- [ ] Envoy 正常运行
- [ ] 自动注入已启用
- [ ] 新 Pod 自动注入 Sidecar

---

### Task 6: VirtualService 配置

**目标**: 创建 VirtualService 配置文件

**文件**: `k8s/v0.4/istio/virtual-service.yaml`

**执行步骤**:

1. **创建 VirtualService**
   - 配置 90/10 流量分流
   - 配置超时和重试
   - 支持多个目标

2. **配置路由规则**
   - 90% 流量到 v1
   - 10% 流量到 v2

**配置框架**:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-vs
  namespace: default
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

**验收标准**:
- [ ] VirtualService 创建成功
- [ ] 权重配置正确 (90/10)
- [ ] 超时和重试配置正确
- [ ] 配置文件格式正确

---

### Task 7: DestinationRule 配置

**目标**: 创建 DestinationRule 配置文件

**文件**: `k8s/v0.4/istio/destination-rule.yaml`

**执行步骤**:

1. **创建 DestinationRule**
   - 定义 v1 和 v2 子集
   - 配置连接池
   - 配置熔断检测

2. **配置子集**
   - v1: 标签 version=v1
   - v2: 标签 version=v2

**配置框架**:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-dr
  namespace: default
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

**验收标准**:
- [ ] DestinationRule 创建成功
- [ ] 子集定义正确
- [ ] 连接池配置正确
- [ ] 熔断配置正确

---

## 🎯 Phase 4: 验证和文档 (11 小时)

### Task 8: 流量验证脚本

**目标**: 创建流量验证脚本

**文件**: `scripts/traffic-verify.sh`

**执行步骤**:

1. **创建验证脚本**
   - 发送 100+ 个请求
   - 统计 v1 和 v2 的响应
   - 计算百分比
   - 验证准确度

2. **脚本逻辑**
   ```bash
   #!/bin/bash
   
   # 发送 100 个请求
   # 统计 v1 和 v2 的比例
   # 验证是否在 85%-95% 范围内
   ```

**验收标准**:
- [ ] 脚本执行成功
- [ ] 统计结果准确
- [ ] v1 比例在 85%-95%
- [ ] v2 比例在 5%-15%

---

### Task 9: 部署验证

**目标**: 验证所有组件正常运行

**执行步骤**:

1. **验证 Ingress**
   ```bash
   kubectl get ingress
   curl http://app.local/
   curl http://app.local/api/v1/version
   ```

2. **验证 Istio**
   ```bash
   kubectl get virtualservices
   kubectl get destinationrules
   ```

3. **验证流量分配**
   ```bash
   bash scripts/traffic-verify.sh
   ```

4. **验证所有 Pod**
   ```bash
   kubectl get pods
   kubectl get svc
   ```

**验收标准**:
- [ ] Ingress 正常工作
- [ ] Istio 正常工作
- [ ] 金丝雀发布验证通过
- [ ] 所有 Pod 正常运行

---

### Task 10: 文档编写

**目标**: 编写完整的部署和架构文档

**文件**:
- `docs/v0.4/DEPLOYMENT-GUIDE.md`
- `docs/v0.4/ARCHITECTURE.md`
- `docs/v0.4/TROUBLESHOOTING.md`

**执行步骤**:

1. **部署指南**
   - 完整的部署步骤
   - 前置要求
   - 故障排查

2. **架构说明**
   - 系统架构图
   - 组件说明
   - 数据流向

3. **故障排查**
   - 常见问题
   - 解决方案
   - 调试技巧

**验收标准**:
- [ ] 部署指南完整
- [ ] 步骤清晰可执行
- [ ] 故障排查全面
- [ ] 文档格式规范

---

### Task 11: 博客创建

**目标**: 创建 4 篇配套技术博客

**文件**:
- `blog/v0.4/11-ingress-guide.md`
- `blog/v0.4/12-ingress-controller.md`
- `blog/v0.4/13-istio-intro.md`
- `blog/v0.4/14-canary-deployment.md`

**博客内容**:

1. **博客 1: Ingress 完全指南** (2000+ 字)
   - Ingress 基础概念
   - Ingress vs Service
   - 配置示例
   - 最佳实践

2. **博客 2: Ingress Controller 实战** (2000+ 字)
   - Nginx Ingress Controller 介绍
   - 安装和配置
   - 实战案例
   - 性能优化

3. **博客 3: Istio 服务网格介绍** (2500+ 字)
   - 服务网格概念
   - Istio 架构
   - Istiod 和 Envoy
   - 核心功能

4. **博客 4: 金丝雀发布实战** (2500+ 字)
   - 金丝雀发布原理
   - VirtualService 配置
   - DestinationRule 配置
   - 完整演示

**验收标准**:
- [ ] 4 篇博客完成
- [ ] 每篇 2000+ 字
- [ ] 内容专业准确
- [ ] 代码示例正确
- [ ] 排版格式规范

---

### Task 12: 最终审查

**目标**: 质量检查和交付确认

**执行步骤**:

1. **代码审查**
   - 代码风格检查
   - 注释完整性
   - 错误处理

2. **配置审查**
   - 配置文件格式
   - 配置值正确性
   - 注释清晰度

3. **文档审查**
   - 文档完整性
   - 步骤清晰度
   - 格式规范性

4. **功能验证**
   - 所有功能正常
   - 所有测试通过
   - 没有遗留问题

**验收标准**:
- [ ] 所有代码审查通过
- [ ] 所有配置审查通过
- [ ] 所有文档审查通过
- [ ] 质量指标达标

---

## 📊 执行进度跟踪

### 执行顺序

```
Week 1:
  Day 1: Task 1 (环境准备) ✓
  Day 2-3: Task 2, 3, 5 (代码开发 + Istio) ✓
  Day 4-5: Task 4, 6, 7 (配置部署) ✓

Week 2:
  Day 1: Task 8 (流量验证) ✓
  Day 2: Task 9 (部署验证) ✓
  Day 3-5: Task 10, 11 (文档和博客) ✓

Week 3:
  Day 1: Task 12 (最终审查) ✓
```

### 并行执行机会

- **Task 2 + Task 3 + Task 5** 可并行 (2 小时)
- **Task 4 + Task 6 + Task 7** 可并行 (2 小时)
- **Task 10 + Task 11** 可并行 (5 小时)

---

## 🎯 交付物清单

### 代码交付物

- [ ] `src/handler/frontend.go` - 前端处理器
- [ ] `src/handler/version.go` - 版本接口
- [ ] `src/main.go` - 更新路由注册

### 配置交付物

- [ ] `k8s/v0.4/ingress/ingress.yaml`
- [ ] `k8s/v0.4/istio/virtual-service.yaml`
- [ ] `k8s/v0.4/istio/destination-rule.yaml`
- [ ] `k8s/v0.4/frontend/deployment.yaml`
- [ ] `k8s/v0.4/frontend/service.yaml`
- [ ] `k8s/v0.4/api/deployment-v1.yaml`
- [ ] `k8s/v0.4/api/deployment-v2.yaml`
- [ ] `k8s/v0.4/api/service.yaml`

### 脚本交付物

- [ ] `scripts/traffic-verify.sh` - 流量验证
- [ ] `scripts/verify-ingress.sh` - Ingress 验证
- [ ] `scripts/verify-istio.sh` - Istio 验证
- [ ] `scripts/canary-test.sh` - 金丝雀测试

### 文档交付物

- [ ] `docs/v0.4/DEPLOYMENT-GUIDE.md`
- [ ] `docs/v0.4/ARCHITECTURE.md`
- [ ] `docs/v0.4/TROUBLESHOOTING.md`

### 博客交付物

- [ ] `blog/v0.4/11-ingress-guide.md`
- [ ] `blog/v0.4/12-ingress-controller.md`
- [ ] `blog/v0.4/13-istio-intro.md`
- [ ] `blog/v0.4/14-canary-deployment.md`

---

## ✅ 执行总结

**状态**: ⏳ 等待开始

**下一步**: 
1. 确认 todolist
2. 开始 Task 1 环境准备
3. 按依赖顺序执行后续任务

**预计完成时间**: 2-3 周

---
