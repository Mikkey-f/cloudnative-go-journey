# v0.4 执行 Todolist

> 快速参考 - 12 个原子任务执行清单

**总时间**: 18 小时  
**执行周期**: 2-3 周  
**状态**: 📋 准备开始

---

## 📋 快速检查清单

### Phase 1: 环境准备 (1 小时)

- [ ] **Task 1: 环境准备**
  - [ ] 启用 Nginx Ingress Controller: `minikube addons enable ingress`
  - [ ] 验证 Ingress: `kubectl get pods -n ingress-nginx`
  - [ ] 下载 Istio: `curl -L https://istio.io/downloadIstio | sh -`
  - [ ] 安装 Istio: `./bin/istioctl install --set profile=demo -y`
  - [ ] 启用自动注入: `kubectl label namespace default istio-injection=enabled`
  - [ ] 验证 Istio: `kubectl get pods -n istio-system`

---

### Phase 2: 代码开发 (2 小时，可并行)

- [ ] **Task 2: 前端服务开发** (1.5 小时)
  - [ ] 创建 `src/handler/frontend.go`
  - [ ] 实现 `FrontendHandler` 函数
  - [ ] 创建 HTML 页面
  - [ ] 在 `src/main.go` 注册路由
  - [ ] 本地测试: `go run src/main.go`
  - [ ] 单元测试通过

- [ ] **Task 3: API v2 开发** (1 小时)
  - [ ] 创建 `src/handler/version.go`
  - [ ] 实现 `/api/v1/version` 接口
  - [ ] 创建 `Dockerfile.v2`
  - [ ] 构建 Docker 镜像: `docker build -f Dockerfile.v2 -t api:v2 .`
  - [ ] 镜像大小 < 50MB

- [ ] **Task 5: Istio 安装验证** (0.5 小时)
  - [ ] 验证 Istiod: `kubectl get pods -n istio-system | grep istiod`
  - [ ] 验证 Envoy: `kubectl get pods -n istio-system | grep envoy`
  - [ ] 验证自动注入: `kubectl get namespace default --show-labels`
  - [ ] 部署测试 Pod 验证 Sidecar 注入

---

### Phase 3: 配置部署 (2 小时，可并行)

- [ ] **Task 4: Ingress 配置** (1.5 小时)
  - [ ] 创建目录: `mkdir -p k8s/v0.4/{ingress,istio,frontend,api}`
  - [ ] 创建 `k8s/v0.4/ingress/ingress.yaml`
  - [ ] 配置路由规则 (`/api` → api-service, `/` → frontend-service)
  - [ ] 应用配置: `kubectl apply -f k8s/v0.4/ingress/ingress.yaml`
  - [ ] 验证: `kubectl get ingress`

- [ ] **Task 6: VirtualService 配置** (1.5 小时)
  - [ ] 创建 `k8s/v0.4/istio/virtual-service.yaml`
  - [ ] 配置 90/10 流量分流
  - [ ] 配置超时和重试
  - [ ] 应用配置: `kubectl apply -f k8s/v0.4/istio/virtual-service.yaml`
  - [ ] 验证: `kubectl get virtualservices`

- [ ] **Task 7: DestinationRule 配置** (1.5 小时)
  - [ ] 创建 `k8s/v0.4/istio/destination-rule.yaml`
  - [ ] 定义 v1 和 v2 子集
  - [ ] 配置连接池和熔断
  - [ ] 应用配置: `kubectl apply -f k8s/v0.4/istio/destination-rule.yaml`
  - [ ] 验证: `kubectl get destinationrules`

---

### Phase 4: 验证和文档 (11 小时)

- [ ] **Task 8: 流量验证脚本** (1 小时)
  - [ ] 创建 `scripts/traffic-verify.sh`
  - [ ] 实现 100+ 个请求的流量统计
  - [ ] 验证 v1 比例在 85%-95%
  - [ ] 验证 v2 比例在 5%-15%
  - [ ] 脚本可执行: `chmod +x scripts/traffic-verify.sh`

- [ ] **Task 9: 部署验证** (1 小时)
  - [ ] 验证 Ingress: `curl http://app.local/`
  - [ ] 验证 API: `curl http://app.local/api/v1/version`
  - [ ] 验证 VirtualService: `kubectl get virtualservices`
  - [ ] 验证 DestinationRule: `kubectl get destinationrules`
  - [ ] 运行流量验证脚本: `bash scripts/traffic-verify.sh`
  - [ ] 所有 Pod 正常: `kubectl get pods`

- [ ] **Task 10: 文档编写** (2 小时)
  - [ ] 创建 `docs/v0.4/DEPLOYMENT-GUIDE.md`
    - [ ] 前置要求
    - [ ] 完整部署步骤
    - [ ] 故障排查
  - [ ] 创建 `docs/v0.4/ARCHITECTURE.md`
    - [ ] 系统架构图
    - [ ] 组件说明
    - [ ] 数据流向
  - [ ] 创建 `docs/v0.4/TROUBLESHOOTING.md`
    - [ ] 常见问题
    - [ ] 解决方案
    - [ ] 调试技巧

- [ ] **Task 11: 博客创建** (3 小时)
  - [ ] 创建 `blog/v0.4/11-ingress-guide.md` (2000+ 字)
    - [ ] Ingress 基础概念
    - [ ] Ingress vs Service
    - [ ] 配置示例
    - [ ] 最佳实践
  - [ ] 创建 `blog/v0.4/12-ingress-controller.md` (2000+ 字)
    - [ ] Nginx Ingress Controller 介绍
    - [ ] 安装和配置
    - [ ] 实战案例
    - [ ] 性能优化
  - [ ] 创建 `blog/v0.4/13-istio-intro.md` (2500+ 字)
    - [ ] 服务网格概念
    - [ ] Istio 架构
    - [ ] Istiod 和 Envoy
    - [ ] 核心功能
  - [ ] 创建 `blog/v0.4/14-canary-deployment.md` (2500+ 字)
    - [ ] 金丝雀发布原理
    - [ ] VirtualService 配置
    - [ ] DestinationRule 配置
    - [ ] 完整演示

- [ ] **Task 12: 最终审查** (1 小时)
  - [ ] 代码审查
    - [ ] 代码风格检查
    - [ ] 注释完整性
    - [ ] 错误处理
  - [ ] 配置审查
    - [ ] 配置文件格式
    - [ ] 配置值正确性
    - [ ] 注释清晰度
  - [ ] 文档审查
    - [ ] 文档完整性
    - [ ] 步骤清晰度
    - [ ] 格式规范性
  - [ ] 功能验证
    - [ ] 所有功能正常
    - [ ] 所有测试通过
    - [ ] 没有遗留问题

---

## 📊 执行进度

### 周计划

**Week 1**:
- [ ] Day 1: Task 1 (环境准备) - 1 小时
- [ ] Day 2-3: Task 2, 3, 5 (代码开发 + Istio) - 2 小时
- [ ] Day 4-5: Task 4, 6, 7 (配置部署) - 2 小时

**Week 2**:
- [ ] Day 1: Task 8 (流量验证) - 1 小时
- [ ] Day 2: Task 9 (部署验证) - 1 小时
- [ ] Day 3-5: Task 10, 11 (文档和博客) - 5 小时

**Week 3**:
- [ ] Day 1: Task 12 (最终审查) - 1 小时

---

## 🎯 关键检查点

### 代码完成检查

- [ ] `src/handler/frontend.go` 存在且可编译
- [ ] `src/handler/version.go` 存在且可编译
- [ ] `src/main.go` 已更新路由注册
- [ ] 所有代码通过 `go build` 检查

### 配置完成检查

- [ ] `k8s/v0.4/ingress/ingress.yaml` 存在且格式正确
- [ ] `k8s/v0.4/istio/virtual-service.yaml` 存在且格式正确
- [ ] `k8s/v0.4/istio/destination-rule.yaml` 存在且格式正确
- [ ] 所有配置通过 `kubectl apply --dry-run` 检查

### 脚本完成检查

- [ ] `scripts/traffic-verify.sh` 存在且可执行
- [ ] 脚本输出正确的统计结果
- [ ] 脚本能正确验证流量分配

### 文档完成检查

- [ ] `docs/v0.4/DEPLOYMENT-GUIDE.md` 完整
- [ ] `docs/v0.4/ARCHITECTURE.md` 完整
- [ ] `docs/v0.4/TROUBLESHOOTING.md` 完整
- [ ] 所有文档格式规范

### 博客完成检查

- [ ] 4 篇博客都已创建
- [ ] 每篇博客 2000+ 字
- [ ] 包含代码示例和图表
- [ ] 排版格式规范

---

## 📁 文件清单

### 新增代码文件

```
src/handler/
├── frontend.go          ✓ 新增
└── version.go           ✓ 新增

src/
└── main.go              ✓ 更新（注册路由）
```

### 新增配置文件

```
k8s/v0.4/
├── ingress/
│   └── ingress.yaml     ✓ 新增
├── istio/
│   ├── virtual-service.yaml    ✓ 新增
│   └── destination-rule.yaml   ✓ 新增
├── frontend/
│   ├── deployment.yaml  ✓ 新增
│   └── service.yaml     ✓ 新增
└── api/
    ├── deployment-v1.yaml      ✓ 新增
    ├── deployment-v2.yaml      ✓ 新增
    └── service.yaml     ✓ 新增
```

### 新增脚本文件

```
scripts/
├── traffic-verify.sh    ✓ 新增
├── verify-ingress.sh    ✓ 新增
├── verify-istio.sh      ✓ 新增
└── canary-test.sh       ✓ 新增
```

### 新增文档文件

```
docs/v0.4/
├── DEPLOYMENT-GUIDE.md  ✓ 新增
├── ARCHITECTURE.md      ✓ 新增
└── TROUBLESHOOTING.md   ✓ 新增
```

### 新增博客文件

```
blog/v0.4/
├── 11-ingress-guide.md          ✓ 新增
├── 12-ingress-controller.md     ✓ 新增
├── 13-istio-intro.md            ✓ 新增
└── 14-canary-deployment.md      ✓ 新增
```

---

## ✅ 最终交付检查

- [ ] 所有 12 个任务完成
- [ ] 所有代码文件创建
- [ ] 所有配置文件创建
- [ ] 所有脚本文件创建
- [ ] 所有文档文件创建
- [ ] 所有博客文件创建
- [ ] 所有文件通过质量检查
- [ ] 项目可独立运行和演示

---

**准备好开始了吗？** 🚀

**下一步**: 开始 Task 1 - 环境准备

---
