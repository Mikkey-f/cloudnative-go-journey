# 从零开始的云原生之旅（八）：CronJob 实战定时清理任务

> 定时任务不用 crontab 了，交给 K8s 管理！

## 📖 文章目录

- [前言](#前言)
- [一、为什么需要 CronJob？](#一为什么需要-cronjob)
  - [1.1 传统 crontab 的问题](#11-传统-crontab-的问题)
  - [1.2 K8s CronJob 的优势](#12-k8s-cronjob-的优势)
- [二、Job vs CronJob](#二job-vs-cronjob)
  - [2.1 Job：一次性任务](#21-job一次性任务)
  - [2.2 CronJob：定时任务](#22-cronjob定时任务)
  - [2.3 如何选择？](#23-如何选择)
- [三、清理任务需求分析](#三清理任务需求分析)
  - [3.1 业务场景](#31-业务场景)
  - [3.2 清理策略](#32-清理策略)
  - [3.3 技术方案](#33-技术方案)
- [四、编写清理任务代码](#四编写清理任务代码)
  - [4.1 代码结构](#41-代码结构)
  - [4.2 核心逻辑实现](#42-核心逻辑实现)
  - [4.3 清理策略实现](#43-清理策略实现)
- [五、配置 CronJob](#五配置-cronjob)
  - [5.1 基础配置](#51-基础配置)
  - [5.2 调度表达式](#52-调度表达式)
  - [5.3 并发策略](#53-并发策略)
  - [5.4 历史记录管理](#54-历史记录管理)
  - [5.5 超时和重试](#55-超时和重试)
- [六、构建和部署](#六构建和部署)
  - [6.1 编写 Dockerfile](#61-编写-dockerfile)
  - [6.2 构建镜像](#62-构建镜像)
  - [6.3 部署 CronJob](#63-部署-cronjob)
- [七、测试和验证](#七测试和验证)
  - [7.1 手动触发 Job](#71-手动触发-job)
  - [7.2 查看执行日志](#72-查看执行日志)
  - [7.3 验证清理效果](#73-验证清理效果)
  - [7.4 查看执行历史](#74-查看执行历史)
- [八、失败处理和重试](#八失败处理和重试)
  - [8.1 模拟失败场景](#81-模拟失败场景)
  - [8.2 观察重试机制](#82-观察重试机制)
  - [8.3 失败告警](#83-失败告警)
- [九、调度策略实战](#九调度策略实战)
  - [9.1 常用调度表达式](#91-常用调度表达式)
  - [9.2 时区问题](#92-时区问题)
  - [9.3 错过调度时间](#93-错过调度时间)
- [十、并发策略深度解析](#十并发策略深度解析)
  - [10.1 Allow：允许并发](#101-allow允许并发)
  - [10.2 Forbid：禁止并发](#102-forbid禁止并发)
  - [10.3 Replace：替换旧任务](#103-replace替换旧任务)
- [十一、生产环境优化](#十一生产环境优化)
  - [11.1 资源限制](#111-资源限制)
  - [11.2 日志收集](#112-日志收集)
  - [11.3 监控告警](#113-监控告警)
  - [11.4 清理策略优化](#114-清理策略优化)
- [十二、常见问题排查](#十二常见问题排查)
- [结语](#结语)

---

## 前言

在前面的文章中，我学会了部署各种工作负载：
- **Deployment**：长期运行的无状态服务
- **StatefulSet**：长期运行的有状态服务
- **DaemonSet**：节点级守护进程

但这次遇到了新需求：

> **产品："Redis 里的临时数据越来越多，要定时清理！"**  
> **我："好，写个脚本，crontab 定时执行？"**  
> **产品："不行！要在 K8s 里管理，统一监控告警！"**

这篇文章，我会**从零实现一个定时清理任务**，完整掌握 K8s 的 CronJob！

---

## 一、为什么需要 CronJob？

### 1.1 传统 crontab 的问题

**我以前的做法：**

```bash
# 在服务器上配置 crontab
crontab -e

# 每小时执行清理脚本
0 * * * * /usr/local/bin/cleanup-redis.sh
```

**看起来没问题，但...：**

---

**❌ 问题 1：无法访问 K8s 内部服务**

```bash
#!/bin/bash
# cleanup-redis.sh

# 尝试连接 Redis
redis-cli -h redis-service -p 6379 KEYS "temp:*"
# Error: Could not resolve hostname redis-service
```

**原因：**
- 脚本运行在宿主机上
- `redis-service` 是 K8s 内部 DNS
- 宿主机无法解析

**解决方案：**
- 配置 hosts 文件？太麻烦
- 用 NodePort 暴露 Redis？不安全
- **用 K8s CronJob！** ✅

---

**❌ 问题 2：服务器重启，cron 丢失**

```bash
# 服务器重启
sudo reboot

# crontab 消失了？
crontab -l
# no crontab for root
```

**原因：某些系统配置不持久化**

---

**❌ 问题 3：没有执行日志**

```bash
# 任务执行了吗？
# 没有日志，不知道！

# 任务失败了？
# 不知道，没有告警！
```

---

**❌ 问题 4：多台服务器，配置麻烦**

```
服务器 A: crontab -e
服务器 B: crontab -e  ← 要在每台配置
服务器 C: crontab -e
```

---

### 1.2 K8s CronJob 的优势

**✅ 解决方案：K8s CronJob**

| 特性 | crontab | K8s CronJob |
|-----|---------|-------------|
| **访问 K8s 服务** | ❌ 需要配置 | ✅ 原生支持 |
| **高可用** | ❌ 单点故障 | ✅ K8s 自动调度 |
| **日志** | ❌ 需要手动配置 | ✅ 自动收集 |
| **监控** | ❌ 需要自己实现 | ✅ K8s 原生支持 |
| **重试** | ❌ 失败就失败了 | ✅ 自动重试 |
| **历史记录** | ❌ 没有 | ✅ 保留最近 N 次 |
| **配置管理** | ❌ 分散在多台机器 | ✅ 统一 YAML 管理 |

---

## 二、Job vs CronJob

### 2.1 Job：一次性任务

**Job = 运行一次就结束**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-import
spec:
  template:
    spec:
      containers:
      - name: importer
        image: data-importer:v1.0
        command: ["python", "import.py"]
      restartPolicy: OnFailure
```

**特点：**
- 立即执行
- 运行完退出
- 失败自动重试

**适用场景：**
- 数据库迁移
- 一次性数据导入
- 手动触发的任务

---

### 2.2 CronJob：定时任务

**CronJob = 定时触发 Job**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
spec:
  schedule: "0 * * * *"  # 每小时
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: cleanup-job:v1.0
          restartPolicy: OnFailure
```

**特点：**
- 按时间表执行
- 自动创建 Job
- 支持并发控制

**适用场景：**
- 定时清理数据
- 定时备份数据库
- 定时生成报表
- 定时健康检查

---

### 2.3 如何选择？

```
需要定时执行吗？
  ├─ 否 → 【Job】
  │       - 数据迁移
  │       - 一次性导入
  │
  └─ 是 → 【CronJob】
          - 定时清理
          - 定时备份
          - 定时报表
```

---

## 三、清理任务需求分析

### 3.1 业务场景

**我的 API 服务会产生两类数据：**

1. **缓存数据**（`cache:*`）
   - 用户请求的缓存结果
   - 设置了 TTL（过期时间）
   - 但有些键可能忘记设置 TTL

2. **临时数据**（`temp:*`）
   - 测试时创建的临时键
   - 不需要长期保存

**问题：**
- Redis 内存占用越来越高
- 过期键没有及时清理
- 临时键堆积

---

### 3.2 清理策略

**策略 1：清理 `cache:*` 键**
- 检查 TTL
- 如果 TTL = -1（永不过期），设置为 1 小时
- 如果 TTL < 1 分钟，提前删除

**策略 2：清理 `temp:*` 键**
- 无条件删除所有 `temp:*` 键

---

### 3.3 技术方案

```
┌─────────────────────────────────────────────────┐
│          CronJob: cleanup-job                   │
│                                                 │
│  每小时触发一次（0 * * * *）                     │
│                                                 │
│  ┌───────────────────────────────────────┐    │
│  │        Job: cleanup-job-28345670      │    │
│  │                                        │    │
│  │  ┌──────────────────────────────┐     │    │
│  │  │   Pod: cleanup-job-xxx       │     │    │
│  │  │                               │     │    │
│  │  │  1. 连接 Redis                │     │    │
│  │  │  2. 扫描 cache:* 键           │     │    │
│  │  │  3. 处理无 TTL 的键           │     │    │
│  │  │  4. 删除 temp:* 键            │     │    │
│  │  │  5. 输出统计信息              │     │    │
│  │  │  6. 退出（状态：Completed）   │     │    │
│  │  └──────────────────────────────┘     │    │
│  └───────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 四、编写清理任务代码

### 4.1 代码结构

```
src/cleanup-job/
└── main.go
```

**依赖：**
```go
import (
    "github.com/redis/go-redis/v9"  // Redis 客户端
)
```

---

### 4.2 核心逻辑实现

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "time"

    "github.com/redis/go-redis/v9"
)

func main() {
    log.Println("🧹 Redis 清理任务开始执行...")
    log.Printf("⏰ 执行时间: %s", time.Now().Format("2006-01-02 15:04:05"))

    // 获取 Redis 连接信息
    redisHost := os.Getenv("REDIS_HOST")
    if redisHost == "" {
        redisHost = "redis-service:6379"
    }

    log.Printf("🔗 连接到 Redis: %s", redisHost)

    // 创建 Redis 客户端
    rdb := redis.NewClient(&redis.Options{
        Addr:         redisHost,
        Password:     "",
        DB:           0,
        DialTimeout:  5 * time.Second,
        ReadTimeout:  3 * time.Second,
        WriteTimeout: 3 * time.Second,
    })
    defer rdb.Close()

    ctx := context.Background()

    // 测试连接
    if err := rdb.Ping(ctx).Err(); err != nil {
        log.Fatalf("❌ 无法连接到 Redis: %v", err)
    }

    log.Println("✅ Redis 连接成功")

    // 执行清理任务
    cleaned, err := cleanupExpiredKeys(rdb, ctx)
    if err != nil {
        log.Fatalf("❌ 清理任务失败: %v", err)
    }

    // 输出统计
    log.Printf("✅ 清理完成")
    log.Printf("📊 统计信息:")
    log.Printf("   - 检查的键数: %d", cleaned["checked"])
    log.Printf("   - 删除的键数: %d", cleaned["deleted"])
    log.Printf("   - 无过期时间的键数: %d", cleaned["no_ttl"])
    log.Printf("   - 执行耗时: %v", cleaned["duration"])

    log.Println("🎉 任务执行成功，退出")
}
```

**关键点：**
- ✅ 从环境变量读取 Redis 地址
- ✅ 测试连接（快速失败）
- ✅ 输出详细日志（K8s 会收集）
- ✅ 任务完成后退出（状态码 0 = 成功）

---

### 4.3 清理策略实现

```go
func cleanupExpiredKeys(rdb *redis.Client, ctx context.Context) (map[string]interface{}, error) {
    startTime := time.Now()
    stats := map[string]interface{}{
        "checked": 0,
        "deleted": 0,
        "no_ttl":  0,
    }

    // 策略 1: 处理 cache:* 键
    log.Println("🔍 扫描 cache:* 键...")
    keys, err := rdb.Keys(ctx, "cache:*").Result()
    if err != nil {
        return stats, fmt.Errorf("获取键列表失败: %w", err)
    }

    log.Printf("📝 找到 %d 个 cache:* 键", len(keys))
    stats["checked"] = len(keys)

    deletedCount := 0
    noTTLCount := 0

    for _, key := range keys {
        // 获取 TTL
        ttl := rdb.TTL(ctx, key).Val()

        if ttl == -2 {
            // -2: 键不存在（已过期）
            deletedCount++
            log.Printf("   [已过期] %s", key)
        } else if ttl == -1 {
            // -1: 键存在但没有过期时间
            // 设置默认过期时间（1小时）
            rdb.Expire(ctx, key, 1*time.Hour)
            noTTLCount++
            log.Printf("   [设置TTL] %s (设为1小时)", key)
        } else if ttl < 60*time.Second {
            // TTL < 1分钟，提前删除
            rdb.Del(ctx, key)
            deletedCount++
            log.Printf("   [删除] %s (TTL: %v)", key, ttl)
        }
    }

    // 策略 2: 删除所有 temp:* 键
    log.Println("🔍 扫描 temp:* 键...")
    tempKeys, err := rdb.Keys(ctx, "temp:*").Result()
    if err != nil {
        log.Printf("⚠️  警告: 获取 temp:* 键失败: %v", err)
    } else {
        log.Printf("📝 找到 %d 个 temp:* 键", len(tempKeys))
        if len(tempKeys) > 0 {
            deleted, err := rdb.Del(ctx, tempKeys...).Result()
            if err != nil {
                log.Printf("⚠️  警告: 删除 temp:* 键失败: %v", err)
            } else {
                deletedCount += int(deleted)
                log.Printf("   删除了 %d 个临时键", deleted)
            }
        }
    }

    stats["deleted"] = deletedCount
    stats["no_ttl"] = noTTLCount
    stats["duration"] = time.Since(startTime)

    return stats, nil
}
```

**TTL 状态码：**
- **-2**：键不存在
- **-1**：键存在，但没有过期时间
- **> 0**：剩余过期时间（秒）

---

## 五、配置 CronJob

### 5.1 基础配置

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
  labels:
    app: cleanup-job
    version: v0.2
spec:
  # 调度表达式
  schedule: "0 * * * *"  # 每小时的第0分钟
  
  # Job 模板
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure  # 失败自动重试
          
          containers:
          - name: cleanup
            image: cleanup-job:v0.2
            
            env:
            - name: REDIS_HOST
              value: "redis-service:6379"
```

---

### 5.2 调度表达式

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

```yaml
# 每 5 分钟
schedule: "*/5 * * * *"

# 每小时
schedule: "0 * * * *"

# 每天凌晨 2 点
schedule: "0 2 * * *"

# 每周日凌晨
schedule: "0 0 * * 0"

# 每月 1 号凌晨
schedule: "0 0 1 * *"

# 工作日 9-17 点每小时
schedule: "0 9-17 * * 1-5"

# 每 15 分钟（工作时间）
schedule: "*/15 9-18 * * 1-5"
```

---

### 5.3 并发策略

```yaml
spec:
  concurrencyPolicy: Forbid  # 禁止并发
```

**三种策略：**

| 策略 | 行为 | 适用场景 |
|-----|-----|---------|
| `Allow` | 允许并发执行 | 独立任务（日志归档） |
| `Forbid` | 禁止并发，跳过新任务 | 数据库备份 |
| `Replace` | 取消旧任务，启动新任务 | 实时报表 |

**我的选择：`Forbid`**

**为什么？**
- 清理任务操作同一个 Redis
- 并发清理可能导致冲突
- 如果上次任务还没完成，说明数据量太大，应该跳过

---

### 5.4 历史记录管理

```yaml
spec:
  successfulJobsHistoryLimit: 3  # 保留 3 个成功的 Job
  failedJobsHistoryLimit: 1      # 保留 1 个失败的 Job
```

**为什么要限制？**
- Job 对象会占用 etcd 存储
- 太多历史记录影响性能
- 保留最近几次就够了

**生产建议：**
- 成功的：保留 3-5 个（看趋势）
- 失败的：保留 1-3 个（排查问题）

---

### 5.5 超时和重试

```yaml
spec:
  jobTemplate:
    spec:
      # 完成后 1 小时删除 Pod
      ttlSecondsAfterFinished: 3600
      
      # 失败重试 3 次
      backoffLimit: 3
      
      # 任务超时 5 分钟
      activeDeadlineSeconds: 300
```

**参数说明：**

| 参数 | 说明 | 推荐值 |
|-----|-----|-------|
| `ttlSecondsAfterFinished` | 完成后多久删除 Pod | 3600（1小时） |
| `backoffLimit` | 失败重试次数 | 3 |
| `activeDeadlineSeconds` | 任务超时时间 | 300（5分钟） |

---

## 六、构建和部署

### 6.1 编写 Dockerfile

```dockerfile
# 构建阶段
FROM golang:1.23-alpine AS builder

WORKDIR /build

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源码
COPY src/cleanup-job/ ./

# 构建
RUN CGO_ENABLED=0 GOOS=linux go build -o cleanup-job main.go

# 运行阶段
FROM alpine:latest

WORKDIR /app

# 复制二进制文件
COPY --from=builder /build/cleanup-job .

# 运行
CMD ["./cleanup-job"]
```

---

### 6.2 构建镜像

```bash
# 切换到 Minikube 的 Docker 环境
minikube docker-env | Invoke-Expression

# 构建镜像
docker build -f Dockerfile.cleanup-job -t cleanup-job:v0.2 .

# 验证镜像
docker images | Select-String "cleanup-job"
# REPOSITORY     TAG    IMAGE ID      CREATED        SIZE
# cleanup-job    v0.2   abc123def     5 seconds ago  15MB
```

---

### 6.3 部署 CronJob

```bash
# 部署
kubectl apply -f k8s/v0.2/cleanup-job/cronjob.yaml
# cronjob.batch/cleanup-job created

# 查看 CronJob
kubectl get cronjobs
# NAME          SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# cleanup-job   0 * * * *     False     0        <none>          10s
```

**字段说明：**
- `SCHEDULE`：调度表达式
- `SUSPEND`：是否暂停
- `ACTIVE`：当前活跃的 Job 数
- `LAST SCHEDULE`：上次调度时间

---

## 七、测试和验证

### 7.1 手动触发 Job

**不想等 1 小时，手动触发：**

```bash
# 方法：从 CronJob 创建一个 Job
kubectl create job cleanup-manual-001 --from=cronjob/cleanup-job

# 查看 Job
kubectl get jobs
# NAME                  COMPLETIONS   DURATION   AGE
# cleanup-manual-001    0/1           5s         5s
```

---

### 7.2 查看执行日志

```bash
# 查看 Pod
kubectl get pods -l job-name=cleanup-manual-001
# NAME                        READY   STATUS    RESTARTS   AGE
# cleanup-manual-001-xxxxx    1/1     Running   0          10s

# 查看日志
kubectl logs cleanup-manual-001-xxxxx

# 输出：
# 🧹 Redis 清理任务开始执行...
# ⏰ 执行时间: 2025-10-30 15:30:00
# 🔗 连接到 Redis: redis-service:6379
# ✅ Redis 连接成功
# 🔍 扫描 cache:* 键...
# 📝 找到 3 个 cache:* 键
#    [设置TTL] cache:user:1001 (设为1小时)
#    [删除] cache:user:1002 (TTL: 30s)
# 🔍 扫描 temp:* 键...
# 📝 找到 2 个 temp:* 键
#    删除了 2 个临时键
# ✅ 清理完成
# 📊 统计信息:
#    - 检查的键数: 3
#    - 删除的键数: 3
#    - 无过期时间的键数: 1
#    - 执行耗时: 125ms
# 🎉 任务执行成功，退出
```

---

### 7.3 验证清理效果

```bash
# 进入 Redis
kubectl exec -it redis-0 -- redis-cli

# 查看所有键
KEYS *
# 1) "cache:user:1001"  ← temp:* 键被删除了

# 查看 TTL
TTL cache:user:1001
# (integer) 3598  ← 设置了 1 小时的 TTL

# 退出
exit
```

---

### 7.4 查看执行历史

```bash
# 查看所有 Job
kubectl get jobs -l app=cleanup-job
# NAME                       COMPLETIONS   DURATION   AGE
# cleanup-job-28345670       1/1           15s        2h
# cleanup-job-28345680       1/1           12s        1h
# cleanup-job-28345690       1/1           18s        10m

# 查看详细信息
kubectl describe cronjob cleanup-job

# 输出：
# Name:         cleanup-job
# Schedule:     0 * * * *
# Successful Job History Limit:  3
# Failed Job History Limit:      1
# Last Schedule Time:  2025-10-30 15:00:00
# Active Jobs:         0
# Events:
#   Normal  SuccessfulCreate  10m  cronjob-controller  Created job cleanup-job-28345690
#   Normal  SuccessfulCreate  1h   cronjob-controller  Created job cleanup-job-28345680
```

---

## 八、失败处理和重试

### 8.1 模拟失败场景

**修改 Redis 地址（故意写错）：**

```bash
kubectl edit cronjob cleanup-job

# 修改：
env:
- name: REDIS_HOST
  value: "redis-service-wrong:6379"  # ← 故意写错

# 保存退出

# 手动触发
kubectl create job cleanup-failed-001 --from=cronjob/cleanup-job
```

---

### 8.2 观察重试机制

```bash
# 查看 Pod 状态
kubectl get pods -l job-name=cleanup-failed-001 -w

# 输出：
# NAME                        READY   STATUS              RESTARTS   AGE
# cleanup-failed-001-xxxxx    0/1     ContainerCreating   0          5s
# cleanup-failed-001-xxxxx    0/1     Error               0          10s  ← 第1次失败
# cleanup-failed-001-xxxxx    0/1     Error               1          20s  ← 第2次失败（重启）
# cleanup-failed-001-xxxxx    0/1     Error               2          40s  ← 第3次失败
# cleanup-failed-001-xxxxx    0/1     Error               3          80s  ← 第4次失败
# cleanup-failed-001-xxxxx    0/1     BackoffLimitExceeded 3         100s ← 达到重试上限
```

**重试间隔：**
- 第 1 次失败：立即重试
- 第 2 次失败：等 10 秒
- 第 3 次失败：等 20 秒
- 第 4 次失败：等 40 秒
- **指数退避**（Exponential Backoff）

---

**查看失败日志：**

```bash
kubectl logs cleanup-failed-001-xxxxx

# 输出：
# 🧹 Redis 清理任务开始执行...
# ⏰ 执行时间: 2025-10-30 15:40:00
# 🔗 连接到 Redis: redis-service-wrong:6379
# ❌ 无法连接到 Redis: dial tcp: lookup redis-service-wrong: no such host
```

---

### 8.3 失败告警

**生产环境建议：**

1. **监控 Job 状态**
```bash
# Prometheus 指标
kube_job_status_failed{job="cleanup-job"} > 0
```

2. **配置告警**
```yaml
# Prometheus AlertManager
- alert: CronJobFailed
  expr: kube_job_status_failed{job="cleanup-job"} > 0
  annotations:
    summary: "Cleanup job failed"
    description: "Job {{ $labels.job }} failed"
```

3. **邮件/短信/Slack 通知**

---

## 九、调度策略实战

### 9.1 常用调度表达式

**测试调度表达式：**

```bash
# 查看下次执行时间
kubectl get cronjob cleanup-job -o yaml | grep schedule
# schedule: 0 * * * *

# 计算下次执行时间（手动）
# 当前时间：15:45
# 调度表达式：0 * * * *（每小时的第0分钟）
# 下次执行：16:00
```

---

**实用调度示例：**

```yaml
# 每 5 分钟（高频清理）
schedule: "*/5 * * * *"

# 每小时（常规清理）
schedule: "0 * * * *"

# 每天凌晨 2 点（数据库备份）
schedule: "0 2 * * *"

# 每周日凌晨 3 点（周报）
schedule: "0 3 * * 0"

# 每月 1 号凌晨 4 点（月度统计）
schedule: "0 4 1 * *"

# 工作日 9-18 点每小时（工作时间清理）
schedule: "0 9-18 * * 1-5"

# 每 30 分钟（工作日）
schedule: "*/30 * * * 1-5"
```

---

### 9.2 时区问题

**默认使用 UTC 时区：**

```bash
# 查看 CronJob 的时区
kubectl get cronjob cleanup-job -o yaml | grep timeZone
# (空) ← 默认 UTC
```

**如果想用本地时区（K8s 1.25+）：**

```yaml
spec:
  schedule: "0 2 * * *"  # 本地时间凌晨 2 点
  timeZone: "Asia/Shanghai"  # 设置时区
```

**注意：**
- K8s 1.25 以下不支持 `timeZone`
- 需要自己计算时差（北京时间 = UTC + 8）

**示例（没有 timeZone 支持）：**

```yaml
# 北京时间凌晨 2 点 = UTC 时间 18:00（前一天）
schedule: "0 18 * * *"  # UTC 18:00
```

---

### 9.3 错过调度时间

**场景：K8s 集群重启，错过了调度时间**

```yaml
spec:
  startingDeadlineSeconds: 100  # 截止时间 100 秒
```

**行为：**
- 调度时间：15:00:00
- 实际启动：15:01:50（晚了 110 秒）
- 超过 100 秒 → **跳过这次执行**

**设置建议：**
- 高频任务（每 5 分钟）：`startingDeadlineSeconds: 60`
- 低频任务（每天一次）：`startingDeadlineSeconds: 3600`
- 不设置：永远不跳过（会补执行）

---

## 十、并发策略深度解析

### 10.1 Allow：允许并发

```yaml
spec:
  concurrencyPolicy: Allow
```

**行为：**

```
时间线：
15:00 → Job-001 开始执行（耗时 70 分钟）
16:00 → Job-002 开始执行（Job-001 还在运行）← 并发！
17:00 → Job-003 开始执行（Job-001 还在运行）← 并发！
```

**查看：**

```bash
kubectl get jobs
# NAME                       COMPLETIONS   DURATION   AGE
# cleanup-job-28345670       0/1           70m        70m  ← 还在运行
# cleanup-job-28345680       0/1           10m        10m  ← 并发运行
# cleanup-job-28345690       0/1           1s         1s   ← 又启动了一个
```

**适用场景：**
- 独立任务（日志归档）
- 任务之间不冲突
- 可以并发执行

---

### 10.2 Forbid：禁止并发

```yaml
spec:
  concurrencyPolicy: Forbid  # 我们用的这个
```

**行为：**

```
时间线：
15:00 → Job-001 开始执行（耗时 70 分钟）
16:00 → Job-002 被跳过（Job-001 还在运行）← 跳过！
17:00 → Job-003 被跳过（Job-001 还在运行）← 跳过！
17:10 → Job-001 完成
18:00 → Job-004 正常执行
```

**查看：**

```bash
kubectl get events --sort-by='.lastTimestamp' | grep cleanup

# 输出：
# 15:00:00  Normal  SuccessfulCreate  Created job cleanup-job-001
# 16:00:00  Warning FailedCreate      Cannot create job (previous job still running)
# 17:00:00  Warning FailedCreate      Cannot create job (previous job still running)
# 18:00:00  Normal  SuccessfulCreate  Created job cleanup-job-004
```

**适用场景：**
- **数据库备份**（避免冲突）
- **数据清理**（操作同一数据源）
- 任务耗时不稳定

---

### 10.3 Replace：替换旧任务

```yaml
spec:
  concurrencyPolicy: Replace
```

**行为：**

```
时间线：
15:00 → Job-001 开始执行（耗时 70 分钟）
16:00 → Job-001 被取消，Job-002 开始执行 ← 替换！
17:00 → Job-002 被取消，Job-003 开始执行 ← 又替换！
```

**查看：**

```bash
kubectl get jobs
# NAME                       COMPLETIONS   DURATION   AGE
# cleanup-job-001            0/1           Failed     70m  ← 被取消
# cleanup-job-002            0/1           Failed     10m  ← 被取消
# cleanup-job-003            0/1           Running    1s   ← 当前运行
```

**适用场景：**
- **实时报表**（只要最新的）
- 任务可以中断
- 旧任务结果无意义

---

## 十一、生产环境优化

### 11.1 资源限制

```yaml
resources:
  requests:
    memory: "64Mi"   # 保证 64Mi
    cpu: "50m"       # 保证 0.05 核
  limits:
    memory: "128Mi"  # 最多 128Mi
    cpu: "100m"      # 最多 0.1 核
```

**为什么要限制？**
- 防止任务占用过多资源
- 保证其他服务的资源
- 清理任务不应该消耗太多资源

---

### 11.2 日志收集

**K8s 会自动收集 Pod 日志：**

```bash
# 查看最近的日志
kubectl logs -l app=cleanup-job --tail=100

# 查看指定 Job 的日志
kubectl logs -l job-name=cleanup-job-28345670
```

**生产建议：**
- 使用 **Fluentd/Filebeat** 收集日志
- 发送到 **ElasticSearch/Loki**
- 配置 **Kibana/Grafana** 查看

---

### 11.3 监控告警

**关键指标：**

```yaml
# Job 成功次数
kube_job_status_succeeded{job="cleanup-job"}

# Job 失败次数
kube_job_status_failed{job="cleanup-job"}

# Job 执行时长
kube_job_status_completion_time - kube_job_status_start_time
```

**告警规则：**

```yaml
# 连续失败 3 次
- alert: CleanupJobFailedMultipleTimes
  expr: |
    sum(increase(kube_job_status_failed{job="cleanup-job"}[3h])) > 3
  annotations:
    summary: "Cleanup job failed 3 times in 3 hours"

# 任务执行时间过长
- alert: CleanupJobTooSlow
  expr: |
    kube_job_status_completion_time - kube_job_status_start_time > 600
  annotations:
    summary: "Cleanup job took more than 10 minutes"
```

---

### 11.4 清理策略优化

**当前问题：`KEYS` 命令会阻塞 Redis**

```go
// ❌ 生产环境不推荐
keys, err := rdb.Keys(ctx, "cache:*").Result()
```

**优化：使用 `SCAN` 命令**

```go
// ✅ 生产环境推荐
func scanKeys(rdb *redis.Client, ctx context.Context, pattern string) ([]string, error) {
    var keys []string
    var cursor uint64
    
    for {
        // SCAN 每次返回一批键
        var scanKeys []string
        var err error
        
        scanKeys, cursor, err = rdb.Scan(ctx, cursor, pattern, 100).Result()
        if err != nil {
            return nil, err
        }
        
        keys = append(keys, scanKeys...)
        
        // cursor = 0 表示扫描完成
        if cursor == 0 {
            break
        }
    }
    
    return keys, nil
}
```

**好处：**
- ✅ 不阻塞 Redis
- ✅ 渐进式扫描
- ✅ 对生产环境友好

---

## 十二、常见问题排查

### 问题 1：CronJob 没有执行

**症状：**
```bash
kubectl get cronjobs
# NAME          SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# cleanup-job   0 * * * *     False     0        <none>          1h
```

**LAST SCHEDULE 一直是 `<none>`**

**排查：**

```bash
# 1. 检查 CronJob 状态
kubectl describe cronjob cleanup-job

# 2. 查看事件
kubectl get events --sort-by='.lastTimestamp' | grep cleanup

# 3. 检查调度表达式
kubectl get cronjob cleanup-job -o yaml | grep schedule
```

**常见原因：**
- ❌ 调度表达式错误
- ❌ CronJob 被暂停（`suspend: true`）
- ❌ K8s 控制器异常

---

### 问题 2：Job 一直失败

**症状：**
```bash
kubectl get jobs
# NAME                       COMPLETIONS   DURATION   AGE
# cleanup-job-28345670       0/1           5m         5m
```

**COMPLETIONS 一直是 `0/1`**

**排查：**

```bash
# 查看 Pod 状态
kubectl get pods -l job-name=cleanup-job-28345670
# NAME                        READY   STATUS    RESTARTS   AGE
# cleanup-job-28345670-xxx    0/1     Error     3          5m

# 查看日志
kubectl logs cleanup-job-28345670-xxx

# 查看详细信息
kubectl describe pod cleanup-job-28345670-xxx
```

**常见原因：**
- ❌ Redis 连接失败（地址错误）
- ❌ 镜像拉取失败
- ❌ 资源限制过小（OOM）
- ❌ 代码逻辑错误

---

### 问题 3：任务超时

**症状：**
```bash
kubectl get pods -l job-name=cleanup-job-28345670
# NAME                        READY   STATUS    RESTARTS   AGE
# cleanup-job-28345670-xxx    0/1     DeadlineExceeded   0  5m
```

**原因：超过 `activeDeadlineSeconds`**

**解决：**

```yaml
spec:
  jobTemplate:
    spec:
      activeDeadlineSeconds: 600  # 增加到 10 分钟
```

---

## 结语

**这篇文章，我学会了：**

✅ **CronJob 的核心概念**
  - 定时触发 Job
  - 调度表达式（Cron 格式）
  - 并发策略（Allow/Forbid/Replace）

✅ **完整的实战流程**
  - 编写清理任务代码
  - 配置 CronJob
  - 构建镜像和部署
  - 测试和验证

✅ **失败处理和重试**
  - 自动重试机制（指数退避）
  - 失败日志查看
  - 监控和告警

✅ **生产环境优化**
  - 资源限制
  - 日志收集
  - 监控告警
  - 清理策略优化（SCAN）

---

**最大的收获：**

> **不要再用 crontab 了！**  
> **K8s CronJob 提供了更强大的功能：**  
> **自动重试、日志收集、监控告警、统一管理！**

---

**v0.2 全部完成！**

在 v0.2 中，我完整掌握了 K8s 的 4 种工作负载：
1. ✅ **Deployment**：无状态应用
2. ✅ **StatefulSet**：有状态应用（Redis）
3. ✅ **DaemonSet**：节点级服务（日志采集）
4. ✅ **CronJob**：定时任务（数据清理）

**下一步（v0.3）：**

v0.3 将学习**高级网络和监控**：
- Ingress（统一入口）
- NetworkPolicy（网络隔离）
- Prometheus + Grafana（完整监控）
- HPA（水平自动扩缩容）

**敬请期待！**

---

**如果这篇文章对你有帮助，欢迎点赞、收藏、分享！**

**有问题欢迎在评论区讨论！** 👇

