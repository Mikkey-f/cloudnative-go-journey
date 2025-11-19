# v0.5 对齐文档 (ALIGNMENT)

> 从模糊需求到精确规范

**创建时间**: 2025-11-18  
**版本**: v0.5 - 配置管理版  
**状态**: 需求对齐中

---

## 📋 原始需求

### 来自项目计划文档

```markdown
### v0.5 - 配置管理版（Week 12-13，1-2周）

#### 学习目标
- 深入理解 ConfigMap 和 Secret
- 学会配置热更新
- 掌握环境区分（dev/staging/prod）
- 了解外部配置中心

#### 配置管理改进
// 使用 Viper 加载多种配置源
- 支持配置文件
- 支持环境变量覆盖
- 支持配置热更新（fsnotify）
- 配置验证和默认值

#### 多环境配置
k8s/v0.5/
├── base/                  # 基础配置
│   ├── deployment.yaml
│   └── service.yaml
├── overlays/
│   ├── dev/              # 开发环境
│   │   └── kustomization.yaml
│   ├── staging/          # 预发布环境
│   │   └── kustomization.yaml
│   └── prod/             # 生产环境
│       └── kustomization.yaml

#### 交付标准
- ✅ 多环境配置管理
- ✅ 配置热更新
- ✅ 敏感信息安全管理
- ✅ 配套 2 篇博客

#### 配套博客
15. 《K8s 配置管理最佳实践》
16. 《实现配置热更新：无需重启服务》
```

---

## 🔍 项目上下文分析

### 1. 现有项目结构

**技术栈**
```
- 语言: Go 1.23+
- 框架: Gin
- 依赖管理: go.mod
- 容器化: Docker
- 编排: Kubernetes
- 监控: Prometheus
- 缓存: Redis
- 服务网格: Istio (v0.4)
```

**当前配置方式**
```go
// src/backend/config/config.go
type Config struct {
    Port        int
    Environment string
    AppName     string
    Version     string
}

func Load() *Config {
    return &Config{
        Port:        getEnvAsInt("PORT", 8080),
        Environment: getEnv("ENVIRONMENT", "development"),
        AppName:     getEnv("APP_NAME", "cloudnative-go-api"),
        Version:     getEnv("VERSION", "v0.1.0"),
    }
}
```

**问题分析**
- ❌ 只支持环境变量，不支持配置文件
- ❌ 无法热更新，需要重启服务
- ❌ 配置散落在代码中（如 Redis 连接）
- ❌ 缺少配置验证
- ❌ 缺少多环境管理机制

### 2. 现有 K8s 配置

**当前部署结构**
```
k8s/
├── v0.1/  # 基础部署
├── v0.2/  # StatefulSet + DaemonSet
├── v0.3/  # HPA 弹性伸缩
└── v0.4/  # Ingress + Istio
```

**问题分析**
- ❌ 没有使用 ConfigMap 管理配置
- ❌ 没有使用 Secret 管理敏感信息
- ❌ 没有多环境区分（dev/staging/prod）
- ❌ 每个版本都是独立的 YAML，大量重复

### 3. 依赖关系分析

**现有依赖 (go.mod)**
```
github.com/gin-gonic/gin v1.9.1
github.com/prometheus/client_golang v1.18.0
github.com/redis/go-redis/v9 v9.3.0
```

**需要新增依赖**
```
github.com/spf13/viper        # 配置管理
github.com/fsnotify/fsnotify  # 文件监听（热更新）
gopkg.in/yaml.v3              # YAML 解析（已有）
```

---

## 🎯 需求理解

### 核心需求分解

#### 1. 配置管理改进（应用层）

**需求**: 使用 Viper 统一管理配置

**实现方案**
```go
// 1. 支持多种配置源
- 配置文件（config.yaml）
- 环境变量覆盖（ENV_VAR）
- 默认值（代码中定义）

// 2. 配置结构化
type AppConfig struct {
    Server   ServerConfig   `mapstructure:"server"`
    Database DatabaseConfig `mapstructure:"database"`
    Redis    RedisConfig    `mapstructure:"redis"`
    Log      LogConfig      `mapstructure:"log"`
    Features FeatureFlags   `mapstructure:"features"`
}

// 3. 配置热更新
- 使用 fsnotify 监听文件变化
- 自动重载配置
- 触发回调函数通知应用

// 4. 配置验证
- 必填字段检查
- 数据类型验证
- 范围校验
```

**配置文件示例**
```yaml
# config/config.yaml
server:
  port: 8080
  environment: development
  shutdown_timeout: 5s

database:
  host: localhost
  port: 5432
  name: mydb
  # 敏感信息通过环境变量覆盖
  # username: ${DB_USER}
  # password: ${DB_PASS}

redis:
  host: localhost
  port: 6379
  db: 0
  pool_size: 10

log:
  level: info
  format: json
  output: stdout

features:
  enable_cache: true
  enable_metrics: true
  enable_tracing: false
```

#### 2. K8s 配置管理（基础设施层）

**需求**: 使用 ConfigMap 和 Secret

**ConfigMap 用途**
- 应用配置文件（config.yaml）
- 非敏感环境变量
- 配置文件挂载

**Secret 用途**
- 数据库密码
- Redis 密码
- API Keys
- TLS 证书

**热更新支持**
```yaml
# ConfigMap 通过 Volume 挂载支持热更新
volumeMounts:
  - name: config-volume
    mountPath: /etc/config
    # 不使用 subPath，确保热更新生效
volumes:
  - name: config-volume
    configMap:
      name: app-config
```

#### 3. 多环境配置（Kustomize）

**需求**: 使用 Kustomize 管理 dev/staging/prod

**目录结构**
```
k8s/v0.5/
├── base/
│   ├── deployment.yaml       # 通用 Deployment
│   ├── service.yaml          # 通用 Service
│   ├── configmap.yaml        # 通用配置
│   ├── secret.yaml           # Secret 模板
│   └── kustomization.yaml    # 资源列表
│
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml      # 开发环境配置
    │   ├── configmap-patch.yaml    # 配置覆盖
    │   └── replica-patch.yaml      # 副本数：1
    │
    ├── staging/
    │   ├── kustomization.yaml      # 预发环境配置
    │   └── configmap-patch.yaml    # 配置覆盖
    │
    └── prod/
        ├── kustomization.yaml      # 生产环境配置
        ├── configmap-patch.yaml    # 配置覆盖
        └── replica-patch.yaml      # 副本数：3
```

**环境差异**
| 配置项 | Dev | Staging | Prod |
|--------|-----|---------|------|
| 副本数 | 1 | 2 | 3 |
| 日志级别 | debug | info | warn |
| 缓存开关 | true | true | true |
| 资源限制 | 小 | 中 | 大 |
| 镜像标签 | latest | staging | v1.x.x |

#### 4. 配置热更新

**需求**: 配置文件更新后无需重启 Pod

**实现机制**
```go
// 1. 监听配置文件变化
viper.WatchConfig()
viper.OnConfigChange(func(e fsnotify.Event) {
    log.Println("配置文件已更新:", e.Name)
    
    // 2. 重新加载配置
    if err := viper.ReadInConfig(); err != nil {
        log.Printf("配置重载失败: %v", err)
        return
    }
    
    // 3. 解析到结构体
    var newConfig AppConfig
    if err := viper.Unmarshal(&newConfig); err != nil {
        log.Printf("配置解析失败: %v", err)
        return
    }
    
    // 4. 验证新配置
    if err := validateConfig(&newConfig); err != nil {
        log.Printf("配置验证失败: %v", err)
        return
    }
    
    // 5. 应用新配置
    updateAppConfig(&newConfig)
    log.Println("配置已更新生效")
})
```

**K8s 层面支持**
- ConfigMap 更新 → kubelet 同步（60-120秒）
- Volume 挂载自动更新
- 应用通过 fsnotify 感知变化
- 应用重载配置（无需重启）

---

## 🔍 边界确认

### 包含的功能

✅ **应用层配置管理**
- Viper 加载多种配置源
- 配置热更新（fsnotify）
- 配置验证
- 结构化配置

✅ **K8s 配置管理**
- ConfigMap 管理非敏感配置
- Secret 管理敏感信息
- Volume 挂载配置文件

✅ **多环境管理**
- Kustomize base + overlays
- dev/staging/prod 三环境
- 环境差异配置

✅ **安全最佳实践**
- Secret 加密存储
- 环境变量覆盖敏感信息
- RBAC 权限控制

✅ **文档和博客**
- 完整部署指南
- 配置管理最佳实践
- 配置热更新实战

### 不包含的功能

❌ **外部配置中心**（下一版本）
- Consul
- etcd
- Apollo
- Nacos

❌ **动态配置中心**（下一版本）
- 配置灰度发布
- 配置回滚
- 配置审计

❌ **高级安全**（下一版本）
- Vault 集成
- etcd 加密
- Secret 轮转

❌ **配置管理 UI**（不在学习范围）
- 可视化配置编辑
- 配置对比

---

## ❓ 疑问澄清

### 智能决策（已自主决策）

#### Q1: 配置文件格式选择？
**决策**: YAML
**理由**:
- K8s 生态标准格式
- 支持注释
- 层级清晰
- Viper 原生支持

#### Q2: 配置热更新的粒度？
**决策**: 部分配置支持热更新
**理由**:
- ✅ 日志级别 - 可热更新
- ✅ 功能开关 - 可热更新
- ✅ 超时时间 - 可热更新
- ❌ 端口号 - 不支持（需要重启）
- ❌ Redis 地址 - 不支持（需要重新连接）

**实现方案**:
```go
// 配置分类
type HotReloadableConfig struct {
    LogLevel    string
    Features    FeatureFlags
    Timeouts    TimeoutConfig
}

type StaticConfig struct {
    ServerPort  int
    RedisAddr   string
    DatabaseDSN string
}
```

#### Q3: Secret 如何管理？
**决策**: 本地开发用 .env，K8s 用 Secret
**理由**:
- 本地开发不提交 .env 到 Git
- K8s 使用 Secret 资源
- 支持环境变量覆盖

**安全实践**:
```yaml
# .gitignore
.env
.env.local
config/secret.yaml

# K8s Secret
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:  # 自动 base64 编码
  db-password: "changeme"
  redis-password: "changeme"
  api-key: "changeme"
```

#### Q4: 多环境如何切换？
**决策**: kubectl apply -k overlays/{env}
**理由**:
- Kustomize 原生支持
- 声明式管理
- 易于 CI/CD 集成

**使用示例**:
```bash
# 部署开发环境
kubectl apply -k k8s/v0.5/overlays/dev

# 部署生产环境
kubectl apply -k k8s/v0.5/overlays/prod
```

#### Q5: 配置验证的严格程度？
**决策**: 启动时严格验证，运行时宽松验证
**理由**:
- 启动时验证失败 → 退出（fail-fast）
- 运行时验证失败 → 记录日志，使用旧配置

**实现示例**:
```go
// 启动时验证
func LoadConfig() (*AppConfig, error) {
    var cfg AppConfig
    if err := viper.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("配置解析失败: %w", err)
    }
    
    if err := validateConfig(&cfg); err != nil {
        return nil, fmt.Errorf("配置验证失败: %w", err)
    }
    
    return &cfg, nil
}

// 运行时验证
func reloadConfig() {
    var newCfg AppConfig
    if err := viper.Unmarshal(&newCfg); err != nil {
        log.Printf("配置解析失败，保持当前配置: %v", err)
        return
    }
    
    if err := validateConfig(&newCfg); err != nil {
        log.Printf("配置验证失败，保持当前配置: %v", err)
        return
    }
    
    // 验证通过，更新配置
    updateConfig(&newCfg)
}
```

### 需要人工确认的问题

#### 🔴 需要确认 1: Viper 依赖版本
**问题**: Viper v1.x 还是 v2.x？
**背景**: 
- v1.18.2 是稳定版（当前最新）
- v2.x 在开发中，API 有变化

**建议**: 使用 v1.18.2（稳定且生态成熟）

**你的选择**: [ ] v1.18.2  [ ] v2.x  [ ] 其他 _____

---

#### 🟡 需要确认 2: 配置文件路径
**问题**: 配置文件放在哪里？
**选项**:
1. `/etc/config/config.yaml` - K8s ConfigMap 标准路径
2. `/app/config/config.yaml` - 应用目录
3. `./config/config.yaml` - 相对路径

**建议**: `/etc/config/config.yaml`（K8s 标准，便于 ConfigMap 挂载）

**你的选择**: [ ] 选项1  [ ] 选项2  [ ] 选项3  [ ] 其他 _____

---

#### 🟡 需要确认 3: 是否保留 v0.4 的 Istio 配置？
**问题**: v0.5 是否继续使用 Istio？
**影响**:
- 保留：需要维护 VirtualService 等配置
- 移除：简化配置，专注配置管理

**建议**: 保留（避免功能倒退，v0.5 是增量版本）

**你的选择**: [ ] 保留  [ ] 移除  [ ] 简化

---

#### 🟢 需要确认 4: 配置热更新的测试方式
**问题**: 如何验证配置热更新？
**选项**:
1. 手动修改 ConfigMap，观察日志
2. 编写自动化测试脚本
3. 提供验证接口（如 /config/reload）

**建议**: 1 + 3 组合（手动验证 + 接口验证）

**你的选择**: [ ] 选项1  [ ] 选项2  [ ] 选项3  [ ] 1+3  [ ] 其他 _____

---

## 📊 项目特性规范

### 代码规范

**Go 代码规范**
- 遵循现有代码风格
- 使用 `gofmt` 格式化
- 错误处理明确
- 日志输出结构化

**配置结构规范**
```go
// 使用 mapstructure tag
type Config struct {
    Field string `mapstructure:"field" validate:"required"`
}

// 使用 validate tag 进行验证
type ServerConfig struct {
    Port int `mapstructure:"port" validate:"required,min=1024,max=65535"`
    Host string `mapstructure:"host" validate:"required,hostname"`
}
```

### YAML 规范

**Kustomization 规范**
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# 资源列表
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

# 通用标签
commonLabels:
  app: cloudnative-go-api
  version: v0.5

# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# 引用 base
bases:
  - ../../base

# 名称前缀
namePrefix: dev-

# 副本数覆盖
replicas:
  - name: cloudnative-go-api
    count: 1

# ConfigMap 生成器
configMapGenerator:
  - name: app-config
    behavior: merge
    files:
      - config.yaml
    literals:
      - ENVIRONMENT=development
      - LOG_LEVEL=debug
```

### 目录规范

```
v0.5/
├── src/
│   └── backend/
│       ├── config/
│       │   ├── config.go           # 配置加载
│       │   ├── types.go            # 配置结构体
│       │   ├── validator.go        # 配置验证
│       │   └── watcher.go          # 热更新监听
│       └── main.go
│
├── k8s/v0.5/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret-template.yaml
│   │
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── prod/
│
├── config/
│   ├── config.yaml                 # 示例配置
│   ├── config.dev.yaml
│   ├── config.staging.yaml
│   ├── config.prod.yaml
│   └── .env.example
│
├── docs/v0.5/
│   ├── ALIGNMENT_v0.5.md           # 本文件
│   ├── CONSENSUS_v0.5.md
│   ├── DESIGN_v0.5.md
│   ├── TASK_v0.5.md
│   ├── DEPLOYMENT-GUIDE.md
│   └── CONFIG-MANAGEMENT.md
│
└── blog/v0.5/
    ├── 15-k8s-config-best-practices.md
    └── 16-config-hot-reload.md
```

---

## 🎯 技术约束

### 兼容性约束

✅ **向后兼容**
- 保留现有环境变量支持
- 不破坏现有部署
- 保留 v0.4 的 Istio 配置

✅ **依赖兼容**
- Go 1.23+
- Kubernetes 1.28+
- Docker 24.x+

### 性能约束

✅ **配置加载性能**
- 启动时配置加载 < 100ms
- 配置热更新延迟 < 200ms

✅ **资源消耗**
- fsnotify 监听开销可忽略
- ConfigMap 大小 < 1MB

### 安全约束

✅ **敏感信息保护**
- Secret 不提交到 Git
- .env 文件不提交
- Secret 使用 stringData（自动编码）

✅ **权限控制**
- ConfigMap 读权限
- Secret 读权限
- RBAC 最小权限原则

---

## 📝 对齐总结

### 核心理解

**v0.5 的本质**: 
从"硬编码配置"到"可管理、可热更新、多环境的配置体系"

**关键改进**:
1. **应用层**: Viper 统一配置管理
2. **基础设施层**: ConfigMap/Secret 管理配置
3. **多环境**: Kustomize 实现环境区分
4. **运维体验**: 配置热更新，无需重启

### 技术选型

| 组件 | 选型 | 理由 |
|------|------|------|
| 配置库 | Viper v1.18.2 | 功能完善、生态成熟 |
| 文件监听 | fsnotify | Viper 内置支持 |
| 多环境 | Kustomize | K8s 原生、声明式 |
| 配置格式 | YAML | K8s 标准、易读 |
| 验证库 | go-playground/validator | 功能强大、易用 |

### 交付清单

**代码交付物** (8 个文件)
- config/config.go
- config/types.go
- config/validator.go
- config/watcher.go
- handler/config.go
- config/config.yaml
- main.go (更新)
- go.mod (更新)

**K8s 交付物** (12+ 个文件)
- k8s/v0.5/base/* (5 个文件)
- k8s/v0.5/overlays/dev/* (3 个文件)
- k8s/v0.5/overlays/staging/* (3 个文件)
- k8s/v0.5/overlays/prod/* (3 个文件)

**文档交付物** (6 个文件)
- docs/v0.5/* (6 个 MD 文件)

**博客交付物** (2 篇)
- blog/v0.5/* (2 个 MD 文件)

**脚本交付物** (3 个)
- scripts/v0.5/deploy-env.sh
- scripts/v0.5/config-test.sh
- scripts/v0.5/hot-reload-test.sh

**总计**: 约 30+ 个文件

---

## ⏭️ 下一步

**状态**: ✅ 对齐完成（待人工确认 4 个问题）

**待确认**:
1. 🔴 Viper 版本选择
2. 🟡 配置文件路径
3. 🟡 是否保留 Istio
4. 🟢 热更新测试方式

**完成后进入**: **Consensus（共识阶段）**

---

*生成时间: 2025-11-18*
