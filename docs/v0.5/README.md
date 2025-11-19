# v0.5 - 配置管理版

> 基于 Viper + ConfigMap/Secret + Kustomize 实现企业级配置管理

**版本**: v0.5  
**开发周期**: Week 12-13 (1-2周)  
**状态**: 审批通过，准备执行 ✅

---

## 📌 版本概述

v0.5 版本聚焦于**配置管理**，实现从简单环境变量到企业级配置管理系统的升级，支持多配置源、配置验证、热更新和多环境部署。

---

## 🎯 核心目标

### 学习目标

- ✅ 深入理解 ConfigMap 和 Secret
- ✅ 学会配置热更新机制
- ✅ 掌握环境区分 (dev/staging/prod)
- ✅ 了解配置管理最佳实践

### 技术目标

- **配置加载**: Viper 支持多种配置源（文件、环境变量、默认值）
- **配置验证**: 启动时和运行时的配置验证
- **配置热更新**: 基于 fsnotify 的配置热更新（无需重启）
- **多环境管理**: 使用 Kustomize 管理 dev/staging/prod 环境
- **安全管理**: 使用 K8s Secret 管理敏感信息

---

## 🏗️ 架构设计

### 系统架构

```
┌─────────────────────────────────────┐
│         Application Layer           │
├─────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐ │
│  │   Handler   │  │   Business   │ │
│  │   (Config   │  │    Logic     │ │
│  │    API)     │  │              │ │
│  └──────┬──────┘  └──────┬───────┘ │
│         │                │          │
├─────────┼────────────────┼──────────┤
│  ┌──────▼────────────────▼───────┐ │
│  │     Config Manager            │ │
│  │  - Load()                     │ │
│  │  - Watch()                    │ │
│  │  - Validate()                 │ │
│  │  - GetConfig()                │ │
│  └───────────────────────────────┘ │
├─────────────────────────────────────┤
│         Configuration Sources       │
├─────────────────────────────────────┤
│  Environment  ConfigMap  File  Def  │
│   Variables      (K8s)   (YAML)ault │
└─────────────────────────────────────┘
```

### 配置优先级

```
环境变量 > ConfigMap > 配置文件 > 默认值
```

### 核心组件

- **config.Manager**: 配置管理器
- **config.AppConfig**: 配置结构体
- **config.Validator**: 配置验证器
- **config.Watcher**: 热更新监听器
- **handler.ConfigHandler**: 配置 API 处理器

---

## 📦 主要功能

### 1. Viper 配置加载

```go
// 支持多种配置源
manager := config.NewManager()
manager.Load()  // 按优先级加载配置
```

**支持的配置源**:
- ✅ YAML 配置文件
- ✅ 环境变量覆盖
- ✅ 默认值设置
- ✅ K8s ConfigMap

### 2. 配置验证

```go
// 启动时验证（Fail-Fast）
if err := manager.Validate(); err != nil {
    log.Fatal("配置验证失败", err)
}

// 运行时验证（Fail-Safe）
if err := manager.ValidateRuntime(); err != nil {
    log.Warn("配置验证失败，保留旧配置", err)
}
```

### 3. 配置热更新

```go
// 自动监听配置变化
manager.Watch()

// 注册变更回调
manager.OnChange(func(cfg *AppConfig) {
    log.Info("配置已更新")
})
```

**热更新流程**:
1. fsnotify 监听文件变化
2. 自动重新加载配置
3. 验证新配置
4. 如果验证通过，应用新配置
5. 如果验证失败，保留旧配置

### 4. 配置管理 API

| 接口 | 方法 | 功能 |
|------|------|------|
| `/api/v1/config` | GET | 获取完整配置（脱敏） |
| `/api/v1/config/:field` | GET | 获取指定字段配置 |
| `/api/v1/config/reload` | POST | 手动触发配置重载 |
| `/api/v1/config/hot-reloadable` | GET | 获取可热更新字段列表 |

### 5. K8s 多环境配置

**目录结构**:
```
k8s/v0.5/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── secret-template.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   ├── config.yaml
    │   └── patches/
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── config.yaml
    │   └── patches/
    └── prod/
        ├── kustomization.yaml
        ├── config.yaml
        └── patches/
```

**环境差异**:

| 配置项 | Dev | Staging | Prod |
|-------|-----|---------|------|
| 副本数 | 1 | 2 | 3 |
| 日志级别 | debug | info | warn |
| 资源限制 | 小 | 中 | 大 |

---

## 🚀 快速开始

### 本地开发

```bash
# 1. 创建配置文件
cp config/config.example.yaml config/config.yaml

# 2. 创建 .env 文件
cp config/.env.example config/.env

# 3. 运行应用
go run src/backend/main.go
```

### K8s 部署

```bash
# Dev 环境
kubectl apply -k k8s/v0.5/overlays/dev

# Staging 环境
kubectl apply -k k8s/v0.5/overlays/staging

# Prod 环境
kubectl apply -k k8s/v0.5/overlays/prod
```

### 验证配置

```bash
# 查看配置
curl http://localhost:8080/api/v1/config

# 测试热更新
kubectl edit configmap api-config -n default
# 等待 120 秒后验证
curl http://localhost:8080/api/v1/config
```

---

## 📚 文档结构

### 规划文档

| 文档 | 说明 | 状态 |
|------|------|------|
| `ALIGNMENT_v0.5.md` | 对齐阶段 - 需求分析 | ✅ |
| `CONSENSUS_v0.5.md` | 共识阶段 - 技术方案 | ✅ |
| `DESIGN_v0.5.md` | 架构阶段 - 系统设计 | ✅ |
| `TASK_v0.5.md` | 任务分解 - 10个原子任务 | ✅ |
| `APPROVE_v0.5.md` | 审批阶段 - 全面审查 | ✅ |

### 执行文档

| 文档 | 说明 | 状态 |
|------|------|------|
| `AUTOMATE_v0.5.md` | 执行计划 - 任务追踪 | ⏳ |
| `DEPLOYMENT-GUIDE.md` | 部署指南 | ⏳ |
| `CONFIG-MANAGEMENT.md` | 配置管理指南 | ⏳ |

### 评估文档

| 文档 | 说明 | 状态 |
|------|------|------|
| `ASSESSMENT_v0.5.md` | 验收和质量评估 | ⏳ |
| `COMPLETION-SUMMARY.md` | 项目完成总结 | ⏳ |

---

## 🛠️ 技术栈

### 核心依赖

| 组件 | 版本 | 用途 |
|------|------|------|
| **Viper** | v1.18.2 | 配置管理 |
| **fsnotify** | v1.7.0 | 文件监听 |
| **validator** | v10.16.0 | 配置验证 |
| **Kustomize** | kubectl 内置 | 多环境管理 |

### 基础设施

- **Kubernetes**: v1.28+
- **Go**: 1.21+
- **Docker**: 20.10+

---

## 📊 项目进度

### 已完成 ✅

- [x] Align - 需求对齐
- [x] Consensus - 技术方案确认
- [x] Architect - 系统架构设计
- [x] Atomize - 任务分解
- [x] Approve - 方案审批

### 进行中 🚧

- [ ] Automate - 代码实现（10个任务）

### 待开始 📝

- [ ] Assess - 验收评估

---

## 🎯 验收标准

### 功能验收

- [ ] Viper 成功加载配置文件
- [ ] 环境变量可以覆盖配置
- [ ] 配置验证正常工作（启动时 + 运行时）
- [ ] 配置热更新生效（120秒内）
- [ ] ConfigMap 正确挂载到 Pod
- [ ] Secret 正确注入环境变量
- [ ] 三个环境可以独立部署
- [ ] 配置 API 正常工作

### 质量验收

- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] K8s 配置验证通过
- [ ] 热更新测试通过
- [ ] 代码符合 Go 规范

### 文档验收

- [ ] 部署指南完整
- [ ] 配置管理指南清晰
- [ ] API 文档完整
- [ ] 博客文章专业

---

## 📖 配套博客

1. **《K8s 配置管理最佳实践》**
   - ConfigMap vs Secret
   - Volume 挂载 vs 环境变量
   - Kustomize 多环境管理
   - 实战案例

2. **《实现配置热更新：无需重启服务》**
   - 配置热更新原理
   - Viper + fsnotify 实现
   - K8s ConfigMap 同步机制
   - 实战演示

---

## 🔗 相关资源

### 参考文档

- [Viper 官方文档](https://github.com/spf13/viper)
- [Kustomize 官方文档](https://kustomize.io/)
- [K8s ConfigMap 文档](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [K8s Secret 文档](https://kubernetes.io/docs/concepts/configuration/secret/)

### 项目链接

- **上一版本**: [v0.4 - Ingress 和服务网格](../v0.4/)
- **下一版本**: v0.6 - 日志和监控（规划中）

---

## 📝 更新日志

### 2025-11-18

- ✅ 完成需求对齐 (ALIGNMENT)
- ✅ 完成技术方案确认 (CONSENSUS)
- ✅ 完成系统架构设计 (DESIGN)
- ✅ 完成任务分解 (TASK)
- ✅ 完成方案审批 (APPROVE)
- 🚧 开始代码实现 (AUTOMATE)

---

## 👥 贡献者

- **架构设计**: Cascade (AI Architect)
- **开发执行**: Mikkey

---

*最后更新: 2025-11-18*
