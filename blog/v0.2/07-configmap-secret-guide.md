# 从零开始的云原生之旅（七）：ConfigMap 和 Secret 配置管理

> 不要把配置写死在代码里！灵活配置才是王道！

## 📖 文章目录

- [前言](#前言)
- [一、为什么需要 ConfigMap 和 Secret？](#一为什么需要-configmap-和-secret)
  - [1.1 我以前的配置方式](#11-我以前的配置方式)
  - [1.2 遇到的问题](#12-遇到的问题)
  - [1.3 K8s 的解决方案](#13-k8s-的解决方案)
- [二、ConfigMap：管理配置数据](#二configmap管理配置数据)
  - [2.1 什么是 ConfigMap？](#21-什么是-configmap)
  - [2.2 创建 ConfigMap](#22-创建-configmap)
  - [2.3 使用 ConfigMap 的 4 种方式](#23-使用-configmap-的-4-种方式)
- [三、Secret：管理敏感数据](#三secret管理敏感数据)
  - [3.1 什么是 Secret？](#31-什么是-secret)
  - [3.2 创建 Secret](#32-创建-secret)
  - [3.3 使用 Secret](#33-使用-secret)
  - [3.4 Secret 的加密存储](#34-secret-的加密存储)
- [四、实战案例：API 服务配置](#四实战案例api-服务配置)
  - [4.1 配置需求分析](#41-配置需求分析)
  - [4.2 创建 ConfigMap](#42-创建-configmap)
  - [4.3 注入到 Deployment](#43-注入到-deployment)
  - [4.4 应用代码读取配置](#44-应用代码读取配置)
- [五、实战案例：CronJob 配置](#五实战案例cronjob-配置)
  - [5.1 定时任务需求](#51-定时任务需求)
  - [5.2 CronJob 配置详解](#52-cronjob-配置详解)
  - [5.3 调度表达式](#53-调度表达式)
  - [5.4 并发策略](#54-并发策略)
- [六、配置的动态更新](#六配置的动态更新)
  - [6.1 ConfigMap 更新](#61-configmap-更新)
  - [6.2 应用如何感知更新？](#62-应用如何感知更新)
  - [6.3 强制更新 Pod](#63-强制更新-pod)
- [七、最佳实践](#七最佳实践)
  - [7.1 配置分层](#71-配置分层)
  - [7.2 命名规范](#72-命名规范)
  - [7.3 版本管理](#73-版本管理)
  - [7.4 安全建议](#74-安全建议)
- [八、常见问题排查](#八常见问题排查)
  - [8.1 ConfigMap 不存在](#81-configmap-不存在)
  - [8.2 配置未生效](#82-配置未生效)
  - [8.3 Secret 解码失败](#83-secret-解码失败)
- [九、ConfigMap vs Secret vs 环境变量](#九configmap-vs-secret-vs-环境变量)
- [结语](#结语)

---

## 前言

在前面的文章中，我学会了部署各种工作负载：
- **Deployment**：无状态应用
- **StatefulSet**：有状态应用（Redis）
- **DaemonSet**：节点级服务（日志采集）

但我发现一个问题：**配置都写死在代码里！**

```go
// 写死的配置
const (
    RedisHost = "redis-service"
    RedisPort = 6379
    LogLevel  = "info"
)
```

**这样有什么问题？**
- ❌ 开发、测试、生产环境配置不同，需要重新编译
- ❌ 修改配置需要重新构建镜像
- ❌ 敏感信息（密码、Token）暴露在代码中

**这篇文章，我会学习 K8s 的配置管理方案：**
- ✅ **ConfigMap**：管理配置数据
- ✅ **Secret**：管理敏感数据
- ✅ **CronJob**：定时任务的配置
- ✅ 配置的动态更新
- ✅ 最佳实践

---

## 一、为什么需要 ConfigMap 和 Secret？

### 1.1 我以前的配置方式

**方式 1：写死在代码里**

```go
package config

const (
    RedisHost = "redis-service"
    RedisPort = 6379
    LogLevel  = "debug"  // 开发环境：debug，生产环境：info
    AppEnv    = "development"
)
```

**问题：**
- 换环境要改代码、重新编译
- 镜像和环境强绑定

---

**方式 2：读取配置文件**

```go
// 读取 config.yaml
cfg, _ := os.ReadFile("config.yaml")
```

```yaml
# config.yaml
redis:
  host: redis-service
  port: 6379
log_level: info
```

**问题：**
- 配置文件怎么放到容器里？
- 不同环境要维护不同的配置文件
- 修改配置要重新构建镜像

---

**方式 3：环境变量**

```go
redisHost := os.Getenv("REDIS_HOST")
redisPort := os.Getenv("REDIS_PORT")
```

```yaml
# Deployment
env:
- name: REDIS_HOST
  value: "redis-service"
- name: REDIS_PORT
  value: "6379"
```

**这个还不错，但：**
- 配置分散在多个 Deployment 中
- 修改配置要编辑所有 YAML 文件
- 敏感信息（密码）明文存储

---

### 1.2 遇到的问题

**场景：部署 3 个微服务，都要连 Redis**

```yaml
# service-a/deployment.yaml
env:
- name: REDIS_HOST
  value: "redis-service"  # 写死

# service-b/deployment.yaml
env:
- name: REDIS_HOST
  value: "redis-service"  # 又写了一遍

# service-c/deployment.yaml
env:
- name: REDIS_HOST
  value: "redis-service"  # 又又写了一遍
```

**Redis 地址改了，要改 3 个文件！**

---

**场景：数据库密码**

```yaml
env:
- name: DB_PASSWORD
  value: "mySecretPassword123"  # 明文！
```

**问题：**
- 密码明文存储在 YAML 文件中
- YAML 文件通常提交到 Git
- **密码泄露！**

---

### 1.3 K8s 的解决方案

**ConfigMap：管理配置数据**

```yaml
# 统一的配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-config
data:
  redis_host: "redis-service"
  redis_port: "6379"
```

**所有服务引用同一个 ConfigMap：**

```yaml
# service-a, service-b, service-c 都这样写
env:
- name: REDIS_HOST
  valueFrom:
    configMapKeyRef:
      name: common-config
      key: redis_host
```

**好处：**
- ✅ 配置集中管理
- ✅ 修改一次，所有服务生效
- ✅ 配置和代码分离

---

**Secret：管理敏感数据**

```yaml
# 创建 Secret
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: bXlTZWNyZXRQYXNzd29yZDEyMw==  # Base64 编码
```

**使用 Secret：**

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password  # 自动解码
```

**好处：**
- ✅ Base64 编码（虽然不是加密）
- ✅ RBAC 权限控制（谁能看 Secret）
- ✅ 可以启用加密存储

---

## 二、ConfigMap：管理配置数据

### 2.1 什么是 ConfigMap？

**ConfigMap = 键值对的集合**

```
┌───────────────────────────┐
│       ConfigMap           │
│                           │
│  key1: value1             │
│  key2: value2             │
│  config.json: { ... }     │
│  redis.conf: ...          │
│                           │
└───────────────────────────┘
```

**用途：**
- 应用配置（日志级别、数据库地址）
- 配置文件（`nginx.conf`, `redis.conf`）
- 命令行参数
- 环境变量

---

### 2.2 创建 ConfigMap

**方法 1：从字面量创建**

```bash
kubectl create configmap my-config \
  --from-literal=log_level=info \
  --from-literal=redis_host=redis-service
```

**查看：**

```bash
kubectl get configmap my-config -o yaml
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  log_level: info
  redis_host: redis-service
```

---

**方法 2：从文件创建**

```bash
# 从单个文件
kubectl create configmap redis-config --from-file=redis.conf

# 从目录（目录下所有文件）
kubectl create configmap app-config --from-file=./config/
```

**结果：**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    bind 0.0.0.0
    port 6379
    maxmemory 128mb
```

---

**方法 3：从 YAML 文件创建（推荐）**

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  labels:
    app: api
    version: v0.2
data:
  # 简单的键值对
  log_level: "info"
  app_env: "production"
  
  # Redis 配置
  redis_host: "redis-service"
  redis_port: "6379"
  
  # 缓存配置
  cache_ttl: "3600"
  
  # 特性开关
  enable_cache: "true"
  enable_metrics: "true"
```

```bash
kubectl apply -f configmap.yaml
```

---

### 2.3 使用 ConfigMap 的 4 种方式

#### ① 作为环境变量（单个键）

```yaml
spec:
  containers:
  - name: api
    image: my-api:v1.0
    env:
    - name: LOG_LEVEL  # 环境变量名
      valueFrom:
        configMapKeyRef:
          name: api-config  # ConfigMap 名称
          key: log_level    # ConfigMap 中的键
```

**Pod 内看到的：**
```bash
echo $LOG_LEVEL
# info
```

---

#### ② 作为环境变量（所有键）

```yaml
spec:
  containers:
  - name: api
    image: my-api:v1.0
    envFrom:
    - configMapRef:
        name: api-config  # 所有键都注入为环境变量
```

**Pod 内看到的：**
```bash
echo $log_level
# info

echo $redis_host
# redis-service

echo $cache_ttl
# 3600
```

**注意：键名会自动转换为环境变量格式（大写、下划线）**

---

#### ③ 作为文件挂载（单个文件）

```yaml
spec:
  containers:
  - name: redis
    image: redis:7-alpine
    volumeMounts:
    - name: config
      mountPath: /etc/redis/redis.conf
      subPath: redis.conf  # 只挂载一个文件
  
  volumes:
  - name: config
    configMap:
      name: redis-config
```

**Pod 内看到的：**
```bash
cat /etc/redis/redis.conf
# bind 0.0.0.0
# port 6379
# maxmemory 128mb
```

---

#### ④ 作为目录挂载（所有键）

```yaml
spec:
  containers:
  - name: app
    image: my-app:v1.0
    volumeMounts:
    - name: config
      mountPath: /etc/config  # 挂载为目录
  
  volumes:
  - name: config
    configMap:
      name: api-config
```

**Pod 内看到的：**
```bash
ls /etc/config/
# cache_ttl
# enable_cache
# log_level
# redis_host
# redis_port

cat /etc/config/log_level
# info
```

**每个键变成一个文件！**

---

## 三、Secret：管理敏感数据

### 3.1 什么是 Secret？

**Secret = 加密存储的键值对**

```
┌───────────────────────────┐
│         Secret            │
│                           │
│  username: YWRtaW4=       │  ← Base64 编码
│  password: cGFzc3dvcmQ=   │
│                           │
└───────────────────────────┘
```

**与 ConfigMap 的区别：**

| 特性 | ConfigMap | Secret |
|-----|-----------|--------|
| **用途** | 配置数据 | 敏感数据 |
| **存储** | 明文 | Base64 编码 |
| **大小限制** | 1MB | 1MB |
| **加密** | 不支持 | 可启用加密存储 |
| **权限控制** | 一般 | 更严格（RBAC）|

---

### 3.2 创建 Secret

**方法 1：从字面量创建**

```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=mySecretPassword123
```

**查看：**

```bash
kubectl get secret db-secret -o yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=  # Base64("admin")
  password: bXlTZWNyZXRQYXNzd29yZDEyMw==  # Base64("mySecretPassword123")
```

---

**方法 2：从文件创建**

```bash
# SSH 私钥
kubectl create secret generic ssh-key \
  --from-file=ssh-privatekey=~/.ssh/id_rsa

# TLS 证书
kubectl create secret tls tls-secret \
  --cert=path/to/tls.cert \
  --key=path/to/tls.key
```

---

**方法 3：从 YAML 创建（手动 Base64 编码）**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=  # echo -n "admin" | base64
  password: bXlTZWNyZXRQYXNzd29yZDEyMw==
```

**或使用 stringData（自动编码）：**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:  # 不需要手动 Base64
  username: admin
  password: mySecretPassword123
```

```bash
kubectl apply -f secret.yaml
```

---

### 3.3 使用 Secret

**使用方式和 ConfigMap 一样：**

**① 作为环境变量**

```yaml
env:
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: username

- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

---

**② 作为文件挂载**

```yaml
volumeMounts:
- name: db-creds
  mountPath: /etc/db-creds
  readOnly: true  # 只读，更安全

volumes:
- name: db-creds
  secret:
    secretName: db-secret
```

**Pod 内：**
```bash
ls /etc/db-creds/
# username
# password

cat /etc/db-creds/password
# mySecretPassword123  ← 自动解码
```

---

### 3.4 Secret 的加密存储

**默认情况：Secret 只是 Base64 编码，不是加密！**

```bash
# 任何人都可以解码
echo "YWRtaW4=" | base64 -d
# admin
```

**启用加密存储（推荐）：**

K8s 支持 **Encryption at Rest**（静态加密），配置后：
- Secret 在 etcd 中加密存储
- 只有 K8s API Server 能解密
- 即使攻击者拿到 etcd 备份，也无法读取 Secret

**配置方法（需要集群管理员权限）：**

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}  # 回退到不加密
```

**这是生产环境必须配置的！**

---

## 四、实战案例：API 服务配置

### 4.1 配置需求分析

**我的 API 服务需要：**
- Redis 地址和端口
- 日志级别
- 缓存 TTL
- 特性开关

**这些配置需要：**
- ✅ 不同环境不同值（开发/生产）
- ✅ 修改后不重新构建镜像
- ✅ 集中管理

---

### 4.2 创建 ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  labels:
    app: api
    version: v0.2
data:
  # 应用配置
  log_level: "info"
  app_env: "production"
  
  # Redis 配置
  redis_host: "redis-service"
  redis_port: "6379"
  
  # 缓存配置
  cache_ttl: "3600"  # 默认 1 小时
  
  # 性能配置
  max_connections: "100"
  
  # 特性开关
  enable_cache: "true"
  enable_metrics: "true"
```

```bash
kubectl apply -f k8s/v0.2/api/configmap.yaml
```

---

### 4.3 注入到 Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: api
        image: cloudnative-go-api:v0.2
        
        # 环境变量（从 ConfigMap 注入）
        env:
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: app_env
        
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: log_level
        
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: redis_host
        
        - name: REDIS_PORT
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: redis_port
        
        - name: CACHE_TTL
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: cache_ttl
```

---

### 4.4 应用代码读取配置

```go
package config

import (
    "os"
    "strconv"
)

type Config struct {
    AppEnv         string
    LogLevel       string
    RedisHost      string
    RedisPort      int
    CacheTTL       int
    EnableCache    bool
    EnableMetrics  bool
}

func LoadConfig() *Config {
    return &Config{
        AppEnv:        getEnv("APP_ENV", "development"),
        LogLevel:      getEnv("LOG_LEVEL", "debug"),
        RedisHost:     getEnv("REDIS_HOST", "localhost"),
        RedisPort:     getEnvInt("REDIS_PORT", 6379),
        CacheTTL:      getEnvInt("CACHE_TTL", 3600),
        EnableCache:   getEnvBool("ENABLE_CACHE", true),
        EnableMetrics: getEnvBool("ENABLE_METRICS", true),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intValue, err := strconv.Atoi(value); err == nil {
            return intValue
        }
    }
    return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
    if value := os.Getenv(key); value != "" {
        return value == "true"
    }
    return defaultValue
}
```

**使用：**

```go
func main() {
    cfg := config.LoadConfig()
    
    fmt.Printf("环境: %s\n", cfg.AppEnv)
    fmt.Printf("日志级别: %s\n", cfg.LogLevel)
    fmt.Printf("Redis: %s:%d\n", cfg.RedisHost, cfg.RedisPort)
}
```

---

## 五、实战案例：CronJob 配置

### 5.1 定时任务需求

**需求：每小时清理 Redis 的过期键**

**配置需求：**
- 调度时间（Cron 表达式）
- Redis 地址
- 任务超时时间
- 失败重试次数
- 历史记录保留数量

---

### 5.2 CronJob 配置详解

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
  labels:
    app: cleanup-job
spec:
  # Cron 调度表达式
  schedule: "0 * * * *"  # 每小时的第0分钟
  
  # 历史保留限制
  successfulJobsHistoryLimit: 3  # 保留 3 个成功的
  failedJobsHistoryLimit: 1      # 保留 1 个失败的
  
  # 并发策略
  concurrencyPolicy: Forbid  # 禁止并发
  
  # 启动截止时间
  startingDeadlineSeconds: 100  # 错过100秒就跳过
  
  # Job 模板
  jobTemplate:
    spec:
      # 完成后 1 小时删除 Pod
      ttlSecondsAfterFinished: 3600
      
      # 失败重试次数
      backoffLimit: 3
      
      # 任务超时时间（5分钟）
      activeDeadlineSeconds: 300
      
      template:
        spec:
          restartPolicy: OnFailure
          
          containers:
          - name: cleanup
            image: cleanup-job:v0.2
            
            env:
            # Redis 地址
            - name: REDIS_HOST
              value: "redis-service:6379"
            
            # Job 信息
            - name: JOB_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            
            resources:
              requests:
                memory: "64Mi"
                cpu: "50m"
              limits:
                memory: "128Mi"
                cpu: "100m"
```

---

### 5.3 调度表达式

**Cron 格式：**

```
 ┌───────────── 分钟 (0 - 59)
 │ ┌───────────── 小时 (0 - 23)
 │ │ ┌───────────── 日 (1 - 31)
 │ │ │ ┌───────────── 月 (1 - 12)
 │ │ │ │ ┌───────────── 星期 (0 - 6) (0 = 周日)
 │ │ │ │ │
 * * * * *
```

**常用示例：**

| 表达式 | 说明 | 场景 |
|-------|-----|-----|
| `*/5 * * * *` | 每 5 分钟 | 频繁清理 |
| `0 * * * *` | 每小时 | 常规清理 |
| `0 2 * * *` | 每天凌晨 2 点 | 数据库备份 |
| `0 0 * * 0` | 每周日凌晨 | 周报生成 |
| `0 0 1 * *` | 每月 1 号凌晨 | 月度统计 |
| `0 9-17 * * 1-5` | 工作日 9-17 点每小时 | 工作时间任务 |

---

### 5.4 并发策略

**concurrencyPolicy 控制并发行为：**

| 策略 | 说明 | 适用场景 |
|-----|-----|---------|
| `Allow` | 允许并发执行（默认） | 独立任务（日志归档） |
| `Forbid` | 禁止并发，跳过新任务 | 数据库备份（避免冲突） |
| `Replace` | 取消旧任务，启动新任务 | 实时报表（只要最新） |

**示例：数据库备份**

```yaml
spec:
  schedule: "0 2 * * *"  # 每天 2 点
  concurrencyPolicy: Forbid  # 如果上次备份还没完成，跳过
```

**为什么？**
- 备份任务耗时长（可能超过 1 天）
- 并发备份会导致数据库负载过高
- 同时备份会冲突（写同一个文件）

---

## 六、配置的动态更新

### 6.1 ConfigMap 更新

```bash
# 方法 1：编辑 ConfigMap
kubectl edit configmap api-config

# 方法 2：替换 ConfigMap
kubectl apply -f configmap.yaml

# 方法 3：打补丁
kubectl patch configmap api-config \
  -p '{"data":{"log_level":"debug"}}'
```

---

### 6.2 应用如何感知更新？

**① 环境变量方式：不会自动更新**

```yaml
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: api-config
      key: log_level
```

**更新 ConfigMap 后：**
```bash
# 修改 ConfigMap
kubectl patch configmap api-config -p '{"data":{"log_level":"debug"}}'

# Pod 内查看
kubectl exec -it api-server-xxx -- env | grep LOG_LEVEL
# LOG_LEVEL=info  ← 还是旧值！
```

**原因：环境变量在 Pod 启动时注入，不会动态更新！**

---

**② 文件挂载方式：会自动更新（有延迟）**

```yaml
volumeMounts:
- name: config
  mountPath: /etc/config

volumes:
- name: config
  configMap:
    name: api-config
```

**更新 ConfigMap 后：**
```bash
# 修改 ConfigMap
kubectl patch configmap api-config -p '{"data":{"log_level":"debug"}}'

# 等待 1-2 分钟
sleep 120

# Pod 内查看
kubectl exec -it api-server-xxx -- cat /etc/config/log_level
# debug  ← 新值！
```

**K8s 会自动同步，但有延迟（最多几分钟）**

---

### 6.3 强制更新 Pod

**如果希望立即生效：**

**方法 1：重启 Pod**

```bash
kubectl rollout restart deployment api-server
```

**方法 2：给 ConfigMap 添加版本号**

```yaml
# configmap-v2.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config-v2  # 新名称
data:
  log_level: "debug"
```

```yaml
# deployment.yaml
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: api-config-v2  # 引用新 ConfigMap
      key: log_level
```

```bash
kubectl apply -f configmap-v2.yaml
kubectl apply -f deployment.yaml  # 触发滚动更新
```

---

**方法 3：给 Deployment 添加 ConfigMap 的 Hash（自动触发更新）**

```bash
# 计算 ConfigMap 的 Hash
CONFIG_HASH=$(kubectl get configmap api-config -o json | md5sum | cut -d' ' -f1)

# 添加到 Deployment 的 annotations
kubectl patch deployment api-server -p \
  "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"configmap-hash\":\"$CONFIG_HASH\"}}}}}"
```

**每次 ConfigMap 改变，Hash 变化，触发滚动更新！**

---

## 七、最佳实践

### 7.1 配置分层

**不要把所有配置放在一个 ConfigMap：**

```yaml
# ❌ 不推荐：所有配置混在一起
apiVersion: v1
kind: ConfigMap
metadata:
  name: all-config
data:
  log_level: info
  redis_host: redis-service
  db_password: password123  # 敏感信息！
  nginx_conf: |
    ...
```

**✅ 推荐：分层管理**

```yaml
# 通用配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-config
data:
  log_level: info
  app_env: production

---
# Redis 配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis_host: redis-service
  redis_port: "6379"

---
# 敏感数据（Secret）
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
stringData:
  password: password123
```

---

### 7.2 命名规范

**推荐命名：**
```
<service>-<type>-<env>

示例：
  api-config-prod       # API 服务的生产配置
  api-config-dev        # API 服务的开发配置
  redis-config          # Redis 配置
  db-secret             # 数据库密钥
```

---

### 7.3 版本管理

**方案 1：在名称中包含版本**

```yaml
metadata:
  name: api-config-v2
```

**好处：**
- 可以同时存在多个版本
- 回滚简单（切换引用）

**坏处：**
- 要修改 Deployment 引用

---

**方案 2：在 ConfigMap 中记录版本**

```yaml
metadata:
  name: api-config
  labels:
    version: v2
data:
  version: "v2"
  log_level: info
```

**好处：**
- 不需要修改 Deployment
- 可以在应用中读取版本号

---

### 7.4 安全建议

**① Secret 不要提交到 Git**

```bash
# .gitignore
*-secret.yaml
secret*.yaml
```

**或使用加密工具（如 Sealed Secrets）**

---

**② 使用 RBAC 限制访问**

```yaml
# 只允许特定 ServiceAccount 读取 Secret
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-secret"]
  verbs: ["get"]
```

---

**③ 启用 Secret 加密存储**

```bash
# 生产环境必须启用！
# 配置 API Server 的 --encryption-provider-config
```

---

**④ 定期轮换密钥**

```bash
# 每季度更新一次数据库密码
kubectl create secret generic db-secret \
  --from-literal=password=newPassword123 \
  --dry-run=client -o yaml | kubectl apply -f -

# 重启 Pod 使其生效
kubectl rollout restart deployment api-server
```

---

## 八、常见问题排查

### 8.1 ConfigMap 不存在

**症状：**
```bash
kubectl get pods
# NAME                  READY   STATUS                 RESTARTS   AGE
# api-server-xxx        0/1     CreateContainerError   0          10s
```

**日志：**
```bash
kubectl describe pod api-server-xxx
# Events:
#   Warning  Failed  Error: configmap "api-config" not found
```

**解决：**
```bash
# 检查 ConfigMap 是否存在
kubectl get configmap api-config

# 如果不存在，创建它
kubectl apply -f configmap.yaml
```

---

### 8.2 配置未生效

**症状：修改了 ConfigMap，应用还是读取旧值**

**排查：**

```bash
# 1. 确认 ConfigMap 已更新
kubectl get configmap api-config -o yaml

# 2. 检查使用方式
kubectl get deployment api-server -o yaml | grep -A10 "env:"

# 3. 如果是环境变量方式，需要重启 Pod
kubectl rollout restart deployment api-server
```

---

### 8.3 Secret 解码失败

**症状：**
```bash
kubectl logs api-server-xxx
# Error: invalid character in password
```

**原因：Base64 编码错误**

```bash
# 检查 Secret
kubectl get secret db-secret -o yaml
# data:
#   password: bXlTZWNyZXRQYXNzd29yZDEyMw==

# 手动解码测试
echo "bXlTZWNyZXRQYXNzd29yZDEyMw==" | base64 -d
# mySecretPassword123
```

**如果解码失败，重新创建 Secret：**

```bash
kubectl delete secret db-secret

kubectl create secret generic db-secret \
  --from-literal=password=mySecretPassword123
```

---

## 九、ConfigMap vs Secret vs 环境变量

| 方式 | 优点 | 缺点 | 适用场景 |
|-----|-----|-----|---------|
| **ConfigMap** | 集中管理、易于更新、支持文件 | 明文存储 | 配置数据（非敏感） |
| **Secret** | 加密存储、权限控制 | 使用复杂 | 密码、Token、证书 |
| **环境变量** | 简单直接 | 分散管理、不能动态更新 | 简单配置、调试 |
| **文件** | 格式自由、支持复杂配置 | 需要挂载卷 | 配置文件（nginx.conf） |

**推荐组合：**
```yaml
# 简单配置 → 环境变量（从 ConfigMap）
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: api-config
      key: log_level

# 复杂配置 → 文件挂载（从 ConfigMap）
volumeMounts:
- name: nginx-config
  mountPath: /etc/nginx/nginx.conf
  subPath: nginx.conf

volumes:
- name: nginx-config
  configMap:
    name: nginx-config

# 敏感数据 → Secret
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

---

## 结语

**这篇文章，我学会了：**

✅ **ConfigMap：管理配置数据**
  - 创建 ConfigMap 的 3 种方法
  - 使用 ConfigMap 的 4 种方式
  - 配置集中管理、易于更新

✅ **Secret：管理敏感数据**
  - Base64 编码（不是加密）
  - 启用加密存储（生产必须）
  - RBAC 权限控制

✅ **CronJob：定时任务配置**
  - Cron 表达式
  - 并发策略（Allow/Forbid/Replace）
  - 历史记录管理

✅ **动态更新配置**
  - 环境变量不会自动更新（需重启）
  - 文件挂载会自动更新（有延迟）
  - 强制更新的 3 种方法

✅ **最佳实践**
  - 配置分层（不要混在一起）
  - 命名规范（service-type-env）
  - 版本管理（v1, v2）
  - 安全建议（加密、RBAC、轮换）

---

**最大的收获：**

> **不要把配置写死在代码里！**  
> **ConfigMap 管理配置，Secret 管理密钥！**  
> **配置和代码分离，才能灵活部署！**

---

**v0.2 完结！**

在 v0.2 中，我学会了：
1. **K8s 工作负载全景**：Deployment、StatefulSet、DaemonSet、CronJob
2. **StatefulSet 部署 Redis**：持久化存储、Headless Service
3. **DaemonSet 日志采集器**：节点级服务、访问宿主机
4. **ConfigMap 和 Secret**：配置管理、敏感数据

**下一步（v0.3 预告）：**

v0.3 将学习 **高级网络和存储**：
- Ingress（统一入口）
- NetworkPolicy（网络隔离）
- StorageClass（动态存储）
- 监控和日志（Prometheus + Grafana）

**敬请期待！**

---

**如果这篇文章对你有帮助，欢迎点赞、收藏、分享！**

**有问题欢迎在评论区讨论！** 👇

