# 更新日志

所有值得注意的项目变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [v0.1.0] - 2025-10-27

### 🎉 首次发布

**v0.1 - 基础版**：从零开始的云原生之旅第一站

### ✨ 新增功能

#### 应用服务
- Go HTTP API 服务（Gin 框架）
- 健康检查接口（`/health` 和 `/ready`）
- 业务接口（`/api/v1/hello` 和 `/api/v1/info`）
- Prometheus 指标暴露（`/metrics`）
- 日志中间件
- 指标收集中间件
- 配置管理（环境变量）
- 优雅关闭机制

#### Docker
- 多阶段 Dockerfile 构建
- 镜像大小优化（< 20MB）
- 静态编译（CGO_ENABLED=0）
- 非 root 用户运行
- Docker HEALTHCHECK 配置
- .dockerignore 构建优化

#### Kubernetes
- Deployment 配置（2 副本）
- Service 配置（NodePort 类型）
- Liveness Probe 配置
- Readiness Probe 配置
- 资源限制（CPU/Memory requests 和 limits）
- 环境变量注入

#### 文档
- 项目 README
- 快速开始指南（QUICKSTART.md）
- v0.1 学习目标（docs/v0.1/GOALS.md）
- K8s 基础知识速成（docs/v0.1/K8S-BASICS.md）
- 环境搭建指南（docs/v0.1/SETUP-ENVIRONMENT.md）
- 架构详解（docs/v0.1/ARCHITECTURE.md）
- 部署指南（k8s/v0.1/README.md）
- FAQ（docs/v0.1/FAQ.md）
- 故障排查指南（docs/v0.1/TROUBLESHOOTING.md）
- 完成总结（docs/v0.1/COMPLETION-SUMMARY.md）
- 最终验证报告（docs/v0.1/FINAL-VERIFICATION.md）

#### 博客
- 01 - Go 应用的云原生之旅（一）容器化
- 02 - K8s 部署你的第一个 Go 服务
- 03 - 云原生最佳实践：健康检查和资源限制

#### 脚本
- 环境检查脚本（PowerShell 和 Bash）
- v0.1 自动化部署脚本

### 📚 技术栈

- **语言**：Go 1.21+
- **框架**：Gin v1.9.1
- **监控**：Prometheus Client v1.18.0
- **容器**：Docker 24.x+
- **编排**：Kubernetes 1.28+ (Minikube)

### 🐛 已知问题

#### Windows 环境特殊性
- minikube service 需要创建隧道才能访问
- kubectl port-forward 不经过 Service 负载均衡
- 建议使用集群内测试验证负载均衡

#### Minikube 镜像加载
- 本地 Docker 镜像需要手动加载到 Minikube
- 使用 `minikube image load` 命令
- 或使用 `eval $(minikube docker-env)` 在 Minikube 环境中构建

### 📝 文档改进

- 增加了详细的架构图解
- 补充了网络流量路径说明
- 添加了 kubectl port-forward 和 Service 负载均衡的区别说明
- 完善了故障排查指南

---

## [v0.2.0] - 2025-10-30

### 🎉 v0.2 发布 - 编排升级版

**v0.2 - 编排升级版**：掌握 Kubernetes 四种核心工作负载

### ✨ 新增功能

#### 应用服务

**Redis 缓存服务（StatefulSet）**
- Redis 7.4 部署（StatefulSet 管理）
- 持久化存储（volumeClaimTemplates 自动创建 PVC）
- Headless Service（固定 DNS 解析）
- RDB + AOF 双重持久化
- 自定义 Redis 配置（ConfigMap）
- 健康检查配置（redis-cli ping）

**API 服务增强**
- Redis 缓存集成（go-redis/v9）
- 缓存测试接口（`/api/v1/cache/test`）
- 数据 CRUD 接口（`/api/v1/data`）
- 配置信息接口（`/api/v1/config`）
- 缓存统计接口（`/api/v1/cache/stats`）
- ConfigMap 配置注入

**日志采集器（DaemonSet）**
- 每个节点自动部署日志采集器
- 模拟日志采集（每 10 秒一次）
- Prometheus 指标暴露（logs_collected_total）
- 节点信息注入（NODE_NAME 环境变量）
- 健康检查和信息接口

**清理任务（CronJob）**
- 定时清理 Redis 过期键（每小时执行）
- 双重清理策略（cache:* 和 temp:*）
- TTL 自动设置（无过期时间的键）
- 任务执行统计和日志
- 失败自动重试机制

#### Kubernetes 配置

**StatefulSet**
- Redis StatefulSet 配置
- volumeClaimTemplates（动态 PVC 创建）
- Headless Service（clusterIP: None）
- 有序部署和终止（OrderedReady）
- 滚动更新策略

**DaemonSet**
- 每个节点自动部署
- hostPath 挂载（访问宿主机日志）
- nodeSelector 节点选择
- tolerations 容忍污点
- 环境变量注入（fieldRef）

**CronJob**
- Cron 调度表达式（0 * * * *）
- 并发策略（Forbid 禁止并发）
- 历史记录限制（成功 3 个，失败 1 个）
- 超时控制（activeDeadlineSeconds）
- TTL 自动清理（ttlSecondsAfterFinished）

**ConfigMap & Secret**
- API 服务配置（api-config）
- Redis 服务配置（redis-config）
- 环境变量注入（configMapKeyRef）
- 文件挂载（volumeMounts）

#### 代码实现

**缓存模块**
- Cache 接口定义（`src/cache/interface.go`）
- RedisCache 实现（`src/cache/redis.go`）
- 连接池管理和统计
- 超时配置（DialTimeout, ReadTimeout, WriteTimeout）

**处理器**
- CacheHandler（缓存测试和配置）
- DataHandler（数据 CRUD 和统计）
- 键名前缀强制（cache:, temp:）

**日志采集器**
- 完整的 Go 实现（`src/log-collector/main.go`）
- Prometheus 指标采集
- HTTP 服务（健康检查、指标、信息）

**清理任务**
- 完整的 Go 实现（`src/cleanup-job/main.go`）
- Redis 键扫描和清理
- TTL 检查和设置
- 执行统计和日志

#### Docker

**多镜像支持**
- API 服务镜像（cloudnative-go-api:v0.2）
- 日志采集器镜像（log-collector:v0.2）
- 清理任务镜像（cleanup-job:v0.2）
- 所有镜像基于 Go 1.23-alpine

#### 文档

**v0.2 完整文档体系**
- 架构设计（docs/v0.2/ARCHITECTURE.md）
- 项目结构（docs/v0.2/PROJECT-STRUCTURE.md）
- 学习目标（docs/v0.2/GOALS.md）
- 知识评估（docs/v0.2/ASSESSMENT.md）
- 部署指南（k8s/v0.2/README.md）

**5 篇深度博客（总计 ~45000 字）**
- 第 4 篇：K8s 工作负载完全指南（~8000 字）
- 第 5 篇：StatefulSet 部署 Redis 实战（~10000 字）
- 第 6 篇：DaemonSet 日志采集器实战（~7000 字）
- 第 7 篇：ConfigMap 和 Secret 配置管理（~9000 字）
- 第 8 篇：CronJob 定时清理任务实战（~11000 字）

#### 脚本

**PowerShell 自动化脚本**
- v0.2 自动化部署脚本（scripts/deploy-v0.2.ps1）
- 环境检查、镜像构建、服务部署、验证测试一键完成

### 🔧 修复

- 修复 ConfigMap 中 Redis 配置的行内注释语法错误
- 修复 log-collector 中未使用的 startTime 变量
- 修复 cleanup-job 的 REDIS_HOST 环境变量（包含端口）
- 修复 API deployment 中 cache key 强制前缀逻辑

### 📝 文档改进

- 增加了 4 种工作负载对比表格和选择决策树
- 补充了 Headless Service 原理和 DNS 解析流程
- 添加了 volumeClaimTemplates 详细说明
- 完善了 CronJob 调度策略和并发控制
- 增加了完整的故障排查指南

### 🎨 优化

- 更新 Go 版本到 1.23
- 更新 Docker 基础镜像到 golang:1.23-alpine
- 优化 Redis 配置（内存限制、淘汰策略）
- 优化日志输出格式（emoji 标识）
- 优化资源限制配置（requests/limits）

### 📚 技术栈更新

- **Go**: 1.23+（从 1.21 升级）
- **Redis**: 7.4
- **redis/go-redis**: v9.3.0
- **Prometheus**: 继续使用

### 🎓 学习成果

完成 v0.2 后，学习者将掌握：

**工作负载管理**
- ✅ Deployment：无状态应用部署
- ✅ StatefulSet：有状态应用部署（Redis）
- ✅ DaemonSet：节点级服务部署（日志采集）
- ✅ Job/CronJob：批处理和定时任务（数据清理）

**存储管理**
- ✅ PVC/PV：持久化存储
- ✅ volumeClaimTemplates：动态存储分配
- ✅ hostPath：访问宿主机资源

**网络管理**
- ✅ Headless Service：固定 DNS 解析
- ✅ Service DNS：集群内部服务发现

**配置管理**
- ✅ ConfigMap：配置数据管理
- ✅ Secret：敏感数据管理
- ✅ 环境变量注入：configMapKeyRef/fieldRef
- ✅ 文件挂载：volumeMounts

**高级特性**
- ✅ 滚动更新策略：RollingUpdate
- ✅ 并发控制：CronJob concurrencyPolicy
- ✅ 节点选择：nodeSelector/tolerations
- ✅ 资源限制：requests/limits

---

## [v0.3.0] - 2025-11-02

### 🎉 v0.3 发布 - 弹性伸缩版

**v0.3 - 弹性伸缩版**：掌握 Kubernetes HPA 自动扩缩容，达到生产级别性能标准

### ✨ 新增功能

#### 核心特性

**HorizontalPodAutoscaler (HPA)**
- HPA v2 API 配置（CPU + 内存双指标）
- 自动扩缩容（minReplicas: 2, maxReplicas: 10）
- 智能行为策略（快速扩容、保守缩容）
- CPU 利用率目标：70%
- 内存利用率目标：80%
- 稳定窗口配置（扩容 0 秒，缩容 300 秒）

**Metrics Server**
- Metrics Server 安装和配置
- 本地环境 TLS 跳过配置（--kubelet-insecure-tls）
- Metrics API 验证（/apis/metrics.k8s.io/v1beta1）
- kubectl top 支持（nodes 和 pods）

**负载测试接口**
- CPU 密集型接口（`/api/v1/workload/cpu`）
- 内存密集型接口（`/api/v1/workload/memory`）
- 混合负载接口（`/api/v1/workload`）
- 可配置强度参数（iterations、size、duration）

**性能测试**
- k6 压测脚本（9.5 分钟完整测试）
- 6 阶段测试流程（预热、增压、高峰、保持、降压、冷却）
- 自定义指标收集（cpu_requests、memory_requests）
- 性能阈值验证（P95 < 5s，错误率 < 20%）

#### 应用服务增强

**WorkloadHandler**
- CPU 密集型任务（数学计算：sqrt、sin、cos、tan）
- 内存密集型任务（内存分配和持有）
- 混合负载任务
- 实时性能统计（duration_ms、goroutines、memory_stats）

**资源配置优化**
- Memory requests: 128Mi（HPA 基准）
- Memory limits: 512Mi（4 倍突发，支持高负载）
- CPU requests: 100m（HPA 基准）
- CPU limits: 500m（5 倍突发）

**探针配置优化**
- Liveness Probe（timeoutSeconds: 10, failureThreshold: 5）
- Readiness Probe（timeoutSeconds: 10, failureThreshold: 6）
- Startup Probe（periodSeconds: 2, failureThreshold: 15）
- 适配高负载场景，避免误杀

#### Kubernetes 配置

**HPA 配置文件**
- `k8s/v0.3/api/hpa.yaml`
- 双指标配置（CPU 70%，Memory 80%）
- Behavior 策略详细配置
- ScaleUp 策略（Percent: 100%, Pods: 2）
- ScaleDown 策略（Pods: 1, periodSeconds: 60）

**Deployment 更新**
- 资源配置优化（v0.2: 256Mi → v0.3: 512Mi）
- 探针超时优化（v0.2: 3s/5s → v0.3: 10s/10s）
- 失败阈值优化（v0.2: 3 → v0.3: 5/6）

#### 测试脚本

**k6 压测脚本**
- `k6-tests/hpa-test.js`（完整版）
- 混合负载场景（50% CPU + 50% 内存）
- 6 阶段测试（总时长 9.5 分钟）
- 最大并发：30 VUs
- 自定义指标和检查
- 生命周期钩子（setup、teardown）

#### 文档

**v0.3 完整文档体系**
- 总览（docs/v0.3/README.md）
- 学习目标（docs/v0.3/GOALS.md）
- 架构设计（docs/v0.3/ARCHITECTURE.md）
- 项目结构（docs/v0.3/PROJECT-STRUCTURE.md）
- 部署指南（docs/v0.3/DEPLOYMENT-GUIDE.md）
- 知识评估（docs/v0.3/ASSESSMENT.md）

**3 篇深度博客（总计 ~35000 字）**
- 第 9 篇：云原生的核心优势：自动弹性伸缩实战（~12000 字）
- 第 10 篇：HPA 完全指南：从原理到实践（~13000 字）
- 第 11 篇：压测实战：验证弹性伸缩效果（~10000 字）

**K8s 配置文档**
- `k8s/v0.3/README.md`
- HPA、Deployment、Service 配置说明
- 部署步骤和验证方法

#### 脚本

**PowerShell 自动化脚本**
- v0.3 自动化部署脚本（scripts/deploy-v0.3.ps1）
- Metrics Server 自动安装和验证
- 镜像构建、服务部署、HPA 配置一键完成

### 🔧 修复

**OOM 问题修复**
- 修复高负载下内存不足导致的 OOMKilled
- Memory limits 从 256Mi 提升到 512Mi
- 支持 30 并发请求的混合负载

**探针超时修复**
- 修复高负载下探针超时导致的 CrashLoopBackOff
- 增加 timeoutSeconds 从 3s/5s 到 10s
- 增加 failureThreshold 从 3 到 5/6

**Minikube Metrics Server 修复**
- 添加 --kubelet-insecure-tls 参数
- 解决本地环境 TLS 证书问题
- 确保 kubectl top 正常工作

### 📊 性能指标

#### 压测结果（生产级别）
- **总请求数**: 3186
- **成功率**: 100% ⭐⭐⭐⭐⭐
- **失败率**: 0% ⭐⭐⭐⭐⭐
- **P50 响应时间**: 48.86ms ⭐⭐⭐⭐⭐
- **P95 响应时间**: 983ms ⭐⭐⭐⭐⭐
- **P99 响应时间**: ~1.1s ⭐⭐⭐⭐⭐
- **吞吐量**: 5.58 req/s
- **检查通过率**: 100% (6370/6370)

#### HPA 表现
- **初始副本数**: 2
- **最大副本数**: 4
- **扩容延迟**: ~45 秒 ⭐⭐⭐⭐⭐
- **缩容延迟**: ~6 分钟（含 5 分钟稳定窗口）
- **Pod 重启次数**: 0 ⭐⭐⭐⭐⭐
- **OOMKilled 次数**: 0 ⭐⭐⭐⭐⭐

#### 资源使用
- **平均 CPU 使用**: 65%（理想范围）
- **峰值 CPU 使用**: 185m
- **平均内存使用**: 120Mi
- **峰值内存使用**: 180Mi

### 📝 文档改进

- 增加了 HPA 工作原理和计算公式详解
- 补充了 Metrics Server 架构和数据流图
- 添加了完整的 k6 压测教程
- 完善了资源配置和探针优化最佳实践
- 增加了问题诊断和解决方案（OOM、CrashLoopBackOff）
- 添加了与行业标准的对比分析

### 🎨 优化

**资源配置优化**
- Memory limits: 256Mi → 512Mi（翻倍）
- CPU limits: 300m → 500m（提高 67%）
- 更合理的突发比例（CPU 5x, Memory 4x）

**探针配置优化**
- Readiness timeout: 3s → 10s
- Liveness timeout: 5s → 10s
- Failure threshold: 3 → 5/6
- Period seconds: 5s/10s → 10s/15s

**HPA 策略优化**
- 快速扩容（0 秒稳定窗口，可翻倍）
- 保守缩容（300 秒稳定窗口，每次 -1）
- 双指标监控（CPU 70%, Memory 80%）

### 📚 技术栈更新

**新增组件**
- **Metrics Server**: Latest (资源指标收集)
- **k6**: v0.48.0 (负载测试)
- **HPA**: autoscaling/v2 (自动扩缩容)

**继续使用**
- **Go**: 1.23+
- **Redis**: 7.4
- **Kubernetes**: 1.28+

### 🎓 学习成果

完成 v0.3 后，学习者将掌握：

**弹性伸缩**
- ✅ HPA 原理和计算公式
- ✅ HPA 配置和调优
- ✅ Metrics Server 安装和验证
- ✅ 资源管理（requests/limits）的深入理解

**性能测试**
- ✅ k6 压测工具使用
- ✅ 压测脚本编写（多阶段、混合负载）
- ✅ 性能指标分析（P50/P95/P99）
- ✅ 系统稳定性验证

**问题诊断**
- ✅ OOMKilled 问题诊断和解决
- ✅ CrashLoopBackOff 根因分析
- ✅ 探针配置优化技巧
- ✅ 资源配置调优方法

**最佳实践**
- ✅ 生产级资源配置
- ✅ 探针配置策略
- ✅ HPA 行为策略设计
- ✅ 性能测试方法论

### 🏆 亮点

1. **达到生产级别性能标准**
   - 100% 请求成功率
   - P95 响应时间 < 1s
   - 0 次 Pod 崩溃
   - 超越行业标准

2. **完整的 HPA 实战**
   - 从原理到实践
   - 包含所有踩坑过程
   - 详细的优化历程

3. **专业的性能测试**
   - k6 完整测试流程
   - 9.5 分钟全场景覆盖
   - 详细的指标分析

4. **深度的技术文档**
   - 3 篇博客共 ~35000 字
   - 完整的配置说明
   - 详细的问题排查指南

---

## [未来版本] - 计划中

### v0.4 - 服务治理版
- Ingress Controller
- Istio 服务网格基础
- 金丝雀发布

### v0.4 - 服务治理版
- Ingress Controller
- Istio 服务网格基础
- 金丝雀发布

### v0.5 - 配置管理版
- Kustomize 多环境配置
- 配置热更新

### v0.6 - 可观测性版
- Prometheus + Grafana
- Loki 日志聚合
- Jaeger 链路追踪

### v0.7 - CI/CD 版
- GitHub Actions
- ArgoCD GitOps

### v1.0 - 完整版
- 微服务架构
- Istio 完整功能

### v1.5 - 边缘计算 AI 版
- 云边协同
- 边缘 AI 推理

---

## 🔗 相关链接

- **项目地址**：https://github.com/yourname/cloudnative-go-journey
- **完整规划**：[cloudnative-go-journey-plan.md](cloudnative-go-journey-plan.md)
- **博客系列**：[blog/v0.1/](blog/v0.1/)

---

## 🤝 贡献者

感谢所有为这个项目做出贡献的开发者！

---

**格式说明**：
- `✨ 新增功能`：Added
- `🔧 修复`：Fixed
- `📝 文档`：Documentation
- `🎨 优化`：Changed
- `🗑️ 删除`：Removed
- `⚠️ 废弃`：Deprecated
- `🔒 安全`：Security
