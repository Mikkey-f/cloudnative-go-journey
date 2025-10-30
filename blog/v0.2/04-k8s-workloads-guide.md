# 从零开始的云原生之旅（四）：K8s 工作负载完全指南

> 终于搞懂 Deployment、StatefulSet、DaemonSet、CronJob 的区别了！

## 📖 文章目录

- [前言](#前言)
- [一、为什么需要多种工作负载？](#一为什么需要多种工作负载)
  - [1.1 我在 v0.1 遇到的局限](#11-我在-v01-遇到的局限)
  - [1.2 真实场景的多样性](#12-真实场景的多样性)
- [二、K8s 的 4 种核心工作负载](#二k8s-的-4-种核心工作负载)
  - [2.1 快速对比](#21-快速对比一张表看懂)
  - [2.2 选择决策树](#22-选择决策树)
- [三、Deployment：无状态应用之王](#三deployment无状态应用之王)
  - [3.1 什么是"无状态"？](#31-什么是无状态)
  - [3.2 核心特性](#32-核心特性)
  - [3.3 适用场景](#33-适用场景)
- [四、StatefulSet：有状态应用的正确姿势](#四statefulset有状态应用的正确姿势)
  - [4.1 什么是"有状态"？](#41-什么是有状态)
  - [4.2 为什么需要 StatefulSet？](#42-为什么需要-statefulset)
  - [4.3 核心特性](#43-核心特性)
  - [4.4 与 Deployment 的关键区别](#44-与-deployment-的关键区别)
- [五、DaemonSet：每个节点都要有](#五daemonset每个节点都要有)
  - [5.1 什么场景需要？](#51-什么场景需要)
  - [5.2 核心特性](#52-核心特性)
  - [5.3 调度策略](#53-调度策略)
- [六、Job 和 CronJob：一次性任务和定时任务](#六job-和-cronjob一次性任务和定时任务)
  - [6.1 为什么不用系统 cron？](#61-为什么不用系统-cron)
  - [6.2 Job vs CronJob](#62-job-vs-cronjob)
  - [6.3 核心特性](#63-核心特性)
- [七、实战对比：部署 Redis 的三种方式](#七实战对比部署-redis-的三种方式)
  - [7.1 方式一：用 Deployment（不推荐）](#71-方式一用-deployment不推荐)
  - [7.2 方式二：用 StatefulSet（推荐）](#72-方式二用-statefulset推荐)
  - [7.3 对比总结](#73-对比总结)
- [八、选择工作负载的 5 个原则](#八选择工作负载的-5-个原则)
- [结语](#结语)

---

## 前言

大家好，我是一个正在学习云原生的 Go 开发者。

在 v0.1 中，我学会了用 **Deployment** 部署无状态的 API 服务，感觉很爽：
- ✅ 声明 2 个副本，K8s 自动维护
- ✅ 滚动更新，零停机发布
- ✅ Pod 挂了自动重启

**但很快我就遇到问题了：**

```
老板："我们要部署 Redis 做缓存"
我："好，用 Deployment 部署！"
老板："Redis 需要持久化数据，你这样会丢数据！"
我："啊？为啥？"

运维："每个节点都要跑日志采集器"
我："Deployment replicas: 3？"
运维："不是！是每个节点一个，新节点加入也要自动部署"
我："？？？"

产品："每天凌晨 3 点清理过期数据"
我："我写个脚本，crontab 定时执行？"
产品："服务器重启了咋办？而且要在 K8s 集群里执行"
我："......"
```

**我意识到：Deployment 不是万能的！**

于是我花了一周时间，系统学习了 K8s 的 4 种核心工作负载：
1. **Deployment** - 无状态应用
2. **StatefulSet** - 有状态应用
3. **DaemonSet** - 节点级守护进程
4. **Job/CronJob** - 批处理和定时任务

这篇文章记录我的学习过程，**重点不是罗列概念，而是：**
- ✅ 为什么需要这么多工作负载？
- ✅ 它们解决什么问题？
- ✅ 实际场景中怎么选？
- ✅ **我踩过的坑！**

---

## 一、为什么需要多种工作负载？

### 1.1 我在 v0.1 遇到的局限

v0.1 中，我用 Deployment 部署了一个 Go API：

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
        image: cloudnative-go-api:v0.1
```

**这个方案很适合我的 API，因为：**
- API 是**无状态**的（任何一个 Pod 都能处理请求）
- Pod 可以**随意删除重建**（不丢数据）
- **横向扩展**很简单（加副本就行）

**但当我想部署 Redis 时，问题来了：**

```
❌ Redis 需要持久化数据（RDB/AOF 文件）
❌ Deployment 的 Pod 重建后，数据会丢失！
❌ 多个 Redis Pod 之间需要固定的网络标识（主从复制）
❌ Deployment 的 Pod 名称是随机的（api-server-7f8d9c-abcde）
```

**我第一反应：挂载 Volume 不就行了？**

试了一下：

```yaml
spec:
  template:
    spec:
      containers:
      - name: redis
        image: redis:7.4
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}  # 临时目录
```

**结果：**
```
❌ emptyDir 是临时的，Pod 重建后数据还是丢了
❌ 换成 PV，但多个 Redis Pod 共享同一个 PV 会数据冲突！
❌ 即使每个 Pod 独立 PV，重建后 PV 也对应不上了
```

**我陷入了困境：Deployment 真的不适合有状态应用！**

---

### 1.2 真实场景的多样性

然后我调研了公司其他服务的需求：

| 服务类型 | 需求特点 | Deployment 能搞定吗？ |
|---------|---------|---------------------|
| **API 服务** | 无状态，可随意重启 | ✅ 完美 |
| **Redis/MySQL** | 有状态，需要持久化数据 | ❌ 数据会丢 |
| **日志采集器** | 每个节点必须有一个 | ❌ 不能保证每个节点 |
| **监控 Agent** | 所有节点都要安装 | ❌ 同上 |
| **数据清理任务** | 每天凌晨执行一次 | ❌ 不是常驻服务 |
| **数据导出任务** | 手动触发，跑完就退出 | ❌ 不需要一直运行 |

**我明白了：不同的应用模式，需要不同的部署方式！**

K8s 提供了 4 种工作负载，就是为了覆盖这些场景：

```
┌─────────────────────────────────────────────────────┐
│                K8s 工作负载全景图                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  📦 Deployment      → 无状态应用（API、Web 前端）  │
│  🗄️  StatefulSet     → 有状态应用（数据库、缓存）  │
│  🤖 DaemonSet       → 节点守护进程（日志、监控）   │
│  ⏰ Job/CronJob     → 批处理任务（备份、清理）     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**接下来，我逐个搞懂它们！**

---

## 二、K8s 的 4 种核心工作负载

### 2.1 快速对比（一张表看懂）

| 特性 | Deployment | StatefulSet | DaemonSet | Job/CronJob |
|-----|-----------|-------------|-----------|-------------|
| **用途** | 无状态应用 | 有状态应用 | 节点守护进程 | 批处理任务 |
| **Pod 名称** | 随机（`name-xxx`） | 有序（`name-0`, `name-1`） | 随机 | 随机 |
| **Pod 启动顺序** | 并行 | 顺序启动（`0→1→2`） | 并行 | 根据需求 |
| **网络标识** | 不固定 | 固定（`name-0.service`） | 不固定 | 不固定 |
| **存储** | 共享或临时 | 每个 Pod 独立 PVC | 通常 `hostPath` | 临时或共享 |
| **副本数** | 手动指定 | 手动指定 | 每个节点一个 | 不适用 |
| **扩缩容** | 随意 | 按序（`2→1→0`） | 跟随节点 | 不适用 |
| **更新策略** | 滚动更新 | 滚动更新（有序） | 滚动更新 | 重新创建 Job |
| **生命周期** | 长期运行 | 长期运行 | 长期运行 | 运行完退出 |
| **典型场景** | API、Web 前端 | 数据库、消息队列 | 日志采集、监控 | 备份、清理、训练 |

**我的理解：**
- **Deployment**：像外卖员，谁接单都行
- **StatefulSet**：像班级学生，有固定座位和学号
- **DaemonSet**：像路灯，每个路口都要有一个
- **CronJob**：像闹钟，时间到了就响一次

---

### 2.2 选择决策树

我整理了一个快速决策流程：

```
开始
  ↓
需要长期运行吗？
  ├─ 否 → 【Job/CronJob】
  │       ├─ 只跑一次 → Job
  │       └─ 定时执行 → CronJob
  │
  └─ 是 → 需要持久化数据吗？
          ├─ 否 → 【Deployment】
          │       （API、Web、代理等）
          │
          └─ 是 → 需要固定网络标识吗？
                  ├─ 否 → 【Deployment + PV】
                  │       （可以接受随机重启）
                  │
                  └─ 是 → 每个节点都要运行吗？
                          ├─ 是 → 【DaemonSet】
                          │       （日志采集、监控 Agent）
                          │
                          └─ 否 → 【StatefulSet】
                                  （数据库、缓存、消息队列）
```

**实战建议：**
- 90% 的无状态服务用 **Deployment**
- 数据库、缓存用 **StatefulSet**
- 日志、监控用 **DaemonSet**
- 定时任务用 **CronJob**

---

## 三、Deployment：无状态应用之王

### 3.1 什么是"无状态"？

**我的通俗理解：**

```
无状态 = 所有 Pod 都是"一样的"

比如外卖系统：
  - 客户点餐请求可以被任何配送员接单
  - 配送员 A 请假了，配送员 B 顶上
  - 客户不关心是谁送的，只要送到就行

对应到 API：
  - 任何一个 API Pod 都能处理请求
  - Pod 重启后，不影响业务
  - 删掉一个 Pod，另一个 Pod 接管流量
```

**技术定义：**
- Pod 不保存本地状态
- 所有状态保存在外部（数据库、缓存、对象存储）
- Pod 可以随意创建、删除、重启

---

### 3.2 核心特性

#### ① 自动维护副本数

```yaml
spec:
  replicas: 3
```

**K8s 会确保始终有 3 个 Pod 运行：**
- Pod 挂了？立即创建新的
- 手动删除 Pod？自动补上
- 节点宕机？在其他节点重建 Pod

**我的测试：**

```powershell
# 查看 Pod
kubectl get pods
# NAME                          READY   STATUS    RESTARTS   AGE
# api-server-7f8d9c-abcde       1/1     Running   0          5m
# api-server-7f8d9c-fghij       1/1     Running   0          5m
# api-server-7f8d9c-klmno       1/1     Running   0          5m

# 删掉一个 Pod
kubectl delete pod api-server-7f8d9c-abcde

# 立即查看，已经创建了新的 Pod
kubectl get pods
# NAME                          READY   STATUS    RESTARTS   AGE
# api-server-7f8d9c-fghij       1/1     Running   0          6m
# api-server-7f8d9c-klmno       1/1     Running   0          6m
# api-server-7f8d9c-pqrst       1/1     Running   0          3s  ← 新创建的
```

**太强了！K8s 自动保证 3 个副本！**

---

#### ② 滚动更新（零停机部署）

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # 最多 1 个 Pod 不可用
      maxSurge: 1        # 最多多创建 1 个 Pod
```

**更新流程：**

```
原有 3 个 Pod（v1.0）：
  [Pod-1] [Pod-2] [Pod-3]

更新镜像到 v1.1：
  第1步：创建 1 个 v1.1 Pod
    [Pod-1 v1.0] [Pod-2 v1.0] [Pod-3 v1.0] [Pod-4 v1.1] ← 多一个

  第2步：删除 1 个 v1.0 Pod
    [Pod-2 v1.0] [Pod-3 v1.0] [Pod-4 v1.1]

  第3步：再创建 1 个 v1.1 Pod
    [Pod-2 v1.0] [Pod-3 v1.0] [Pod-4 v1.1] [Pod-5 v1.1]

  第4步：删除 1 个 v1.0 Pod
    [Pod-3 v1.0] [Pod-4 v1.1] [Pod-5 v1.1]

  ...依此类推

最终：
  [Pod-4 v1.1] [Pod-5 v1.1] [Pod-6 v1.1]
```

**好处：**
- ✅ 始终有 Pod 在服务
- ✅ 用户无感知
- ✅ 发现问题可以随时回滚

---

#### ③ 快速扩缩容

```bash
# 扩容到 5 个副本
kubectl scale deployment api-server --replicas=5

# 缩容到 1 个副本
kubectl scale deployment api-server --replicas=1

# 自动扩缩容（HPA）
kubectl autoscale deployment api-server --min=2 --max=10 --cpu-percent=80
```

---

### 3.3 适用场景

**✅ 适合 Deployment：**
- Web 应用（前端、后端 API）
- 微服务（订单服务、用户服务）
- 无状态中间件（Nginx、API 网关）
- Serverless 函数

**❌ 不适合 Deployment：**
- 数据库（MySQL、PostgreSQL、MongoDB）
- 缓存（Redis、Memcached）
- 消息队列（Kafka、RabbitMQ）
- 分布式存储（Ceph、MinIO）

**为什么不适合？因为这些应用需要：**
- 固定的网络标识（主从复制、集群选举）
- 独立的持久化存储（每个实例存不同的数据）
- 有序的启动/停止（主节点先启动，从节点后启动）

**这就需要 StatefulSet！**

---

## 四、StatefulSet：有状态应用的正确姿势

### 4.1 什么是"有状态"？

**我的通俗理解：**

```
有状态 = 每个 Pod 都是"独特的"

比如班级座位：
  - 小明坐第 1 排第 2 座
  - 小红坐第 2 排第 3 座
  - 座位号是固定的，不能随便换

对应到 Redis：
  - redis-0 是主节点
  - redis-1 是从节点
  - redis-0 挂了，不能随便拿个 Pod 顶替，必须是原来的 redis-0
```

**技术定义：**
- 每个 Pod 有固定的名称（`name-0`, `name-1`, `name-2`）
- 每个 Pod 有固定的网络标识（`name-0.service`）
- 每个 Pod 有独立的持久化存储（PVC）
- Pod 重建后，名称、标识、存储都不变

---

### 4.2 为什么需要 StatefulSet？

我用 Deployment 部署 Redis 时遇到的问题：

**❌ 问题 1：Pod 名称不固定**

```bash
# Deployment 的 Pod 名称是随机的
kubectl get pods
# NAME                     READY   STATUS    RESTARTS   AGE
# redis-7f8d9c-abcde       1/1     Running   0          1m
# redis-7f8d9c-fghij       1/1     Running   0          1m

# Pod 重启后，名称变了！
# redis-7f8d9c-pqrst       1/1     Running   0          10s
```

**为什么这是问题？**

假设我配置了 Redis 主从：
- `redis-7f8d9c-abcde` 是主节点
- `redis-7f8d9c-fghij` 是从节点，配置了 `slaveof redis-7f8d9c-abcde`

**主节点重启后：**
- 名称变成 `redis-7f8d9c-pqrst`
- 从节点还在连接 `redis-7f8d9c-abcde`（已经不存在了）
- **主从复制断了！**

---

**❌ 问题 2：存储对应不上**

```yaml
# Deployment + PV
spec:
  template:
    spec:
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: redis-pvc  # 所有 Pod 共享一个 PVC
```

**问题：**
- 多个 Redis Pod 写同一个 PV → **数据冲突！**
- 给每个 Pod 分配独立 PVC？Pod 重建后对应不上

---

**✅ StatefulSet 的解决方案：**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis-service  # 必须指定 Headless Service
  replicas: 3
  template:
    spec:
      containers:
      - name: redis
        image: redis:7.4
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:  # 自动为每个 Pod 创建 PVC
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

**创建后：**

```bash
kubectl get pods
# NAME       READY   STATUS    RESTARTS   AGE
# redis-0    1/1     Running   0          1m  ← 固定名称
# redis-1    1/1     Running   0          1m
# redis-2    1/1     Running   0          1m

kubectl get pvc
# NAME           STATUS   VOLUME    CAPACITY   ACCESS MODES
# data-redis-0   Bound    pv-001    1Gi        RWO  ← 每个 Pod 独立 PVC
# data-redis-1   Bound    pv-002    1Gi        RWO
# data-redis-2   Bound    pv-003    1Gi        RWO
```

**Pod 重启后：**
- Pod 名称还是 `redis-0`
- PVC 还是 `data-redis-0`
- **数据不丢失！**

---

### 4.3 核心特性

#### ① 固定的 Pod 名称

```
Deployment：
  redis-7f8d9c-abcde  ← 随机后缀
  redis-7f8d9c-fghij
  redis-7f8d9c-klmno

StatefulSet：
  redis-0  ← 从 0 开始递增
  redis-1
  redis-2
```

**规则：**
- 名称格式：`$(statefulset-name)-$(ordinal)`
- Ordinal 从 0 开始
- Pod 删除重建后，名称不变

---

#### ② 固定的网络标识

**StatefulSet 必须配合 Headless Service 使用：**

```yaml
# Headless Service
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  clusterIP: None  # 这是关键！
  selector:
    app: redis
  ports:
  - port: 6379
```

**每个 Pod 有独立的 DNS 记录：**

```
redis-0.redis-service.default.svc.cluster.local
redis-1.redis-service.default.svc.cluster.local
redis-2.redis-service.default.svc.cluster.local
```

**好处：**

```go
// 应用可以直接通过固定域名访问特定 Pod
masterAddr := "redis-0.redis-service:6379"  // 永远是主节点
slaveAddr := "redis-1.redis-service:6379"   // 永远是从节点
```

---

#### ③ 独立的持久化存储

**volumeClaimTemplates 会自动：**
1. 为每个 Pod 创建独立的 PVC
2. PVC 名称：`$(volumeClaimTemplate-name)-$(pod-name)`
3. Pod 删除后，PVC 不删除（数据保留）
4. Pod 重建后，自动绑定原来的 PVC

**示例：**

```yaml
volumeClaimTemplates:
- metadata:
    name: data  # PVC 名称前缀
  spec:
    accessModes: [ "ReadWriteOnce" ]
    resources:
      requests:
        storage: 1Gi
```

**生成的 PVC：**
```
data-redis-0  →  绑定到 redis-0
data-redis-1  →  绑定到 redis-1
data-redis-2  →  绑定到 redis-2
```

---

#### ④ 有序部署和终止

**部署顺序：**

```
创建 3 个副本的 StatefulSet：

第1步：创建 redis-0，等待 Running
  [redis-0 Creating...]

第2步：redis-0 Ready 后，创建 redis-1
  [redis-0 Running] [redis-1 Creating...]

第3步：redis-1 Ready 后，创建 redis-2
  [redis-0 Running] [redis-1 Running] [redis-2 Creating...]

完成：
  [redis-0 Running] [redis-1 Running] [redis-2 Running]
```

**终止顺序（缩容）：**

```
从 3 个副本缩容到 1 个：

第1步：删除 redis-2
  [redis-0 Running] [redis-1 Running] [redis-2 Terminating]

第2步：redis-2 删除完成后，删除 redis-1
  [redis-0 Running] [redis-1 Terminating]

完成：
  [redis-0 Running]
```

**为什么要有序？**

假设 Redis 主从：
- `redis-0` 是主节点
- `redis-1` 和 `redis-2` 是从节点

**有序启动：**
- 先启动 `redis-0`（主节点）
- 再启动 `redis-1`、`redis-2`（从节点连接主节点）

**有序停止：**
- 先停止 `redis-2`、`redis-1`（从节点）
- 最后停止 `redis-0`（主节点）

**保证数据不丢失！**

---

### 4.4 与 Deployment 的关键区别

| 特性 | Deployment | StatefulSet |
|-----|-----------|-------------|
| **Pod 名称** | `name-随机` | `name-0`, `name-1`, ... |
| **Pod 标识** | 不固定 | 固定（DNS 记录） |
| **存储** | 共享或临时 | 每个 Pod 独立 PVC |
| **启动顺序** | 并行 | 顺序（0→1→2） |
| **停止顺序** | 并行 | 倒序（2→1→0） |
| **扩缩容** | 随意 | 有序 |
| **适用场景** | 无状态应用 | 有状态应用 |

**记忆口诀：**
```
Deployment = 随机的、一次性的、可替换的
StatefulSet = 固定的、有序的、不可替换的
```

---

## 五、DaemonSet：每个节点都要有

### 5.1 什么场景需要？

**我遇到的需求：**

运维："我们要在每个节点上部署日志采集器，收集 `/var/log/` 的日志"

**我的第一反应：用 Deployment？**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-collector
spec:
  replicas: 3  # 假设集群有 3 个节点
```

**运维："不对！如果集群扩容到 5 个节点呢？你要手动改 replicas？"**

**我："对哦！而且 Deployment 不保证每个节点都有一个 Pod！"**

```bash
# Deployment 可能把 3 个 Pod 都调度到同一个节点
kubectl get pods -o wide
# NAME                  NODE
# log-collector-xxx     node-1
# log-collector-yyy     node-1  ← 都在 node-1
# log-collector-zzz     node-1
```

**这就需要 DaemonSet！**

---

### 5.2 核心特性

#### ① 每个节点自动运行一个 Pod

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: collector
        image: log-collector:v1.0
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log  # 挂载宿主机的 /var/log
```

**创建后：**

```bash
kubectl get pods -o wide
# NAME                  NODE       READY   STATUS
# log-collector-aaa     node-1     1/1     Running
# log-collector-bbb     node-2     1/1     Running
# log-collector-ccc     node-3     1/1     Running

# 每个节点都有一个 Pod！
```

**集群扩容时：**

```bash
# 新加入一个 node-4
kubectl get nodes
# NAME     STATUS   AGE
# node-1   Ready    10d
# node-2   Ready    10d
# node-3   Ready    10d
# node-4   Ready    1m   ← 新节点

# DaemonSet 自动在 node-4 创建 Pod
kubectl get pods -o wide
# NAME                  NODE       READY   STATUS
# log-collector-aaa     node-1     1/1     Running
# log-collector-bbb     node-2     1/1     Running
# log-collector-ccc     node-3     1/1     Running
# log-collector-ddd     node-4     1/1     Running  ← 自动创建！
```

**太智能了！**

---

#### ② 节点下线，Pod 自动清理

```bash
# node-2 下线
kubectl drain node-2

# node-2 上的 Pod 自动删除
kubectl get pods -o wide
# NAME                  NODE       READY   STATUS
# log-collector-aaa     node-1     1/1     Running
# log-collector-ccc     node-3     1/1     Running
# log-collector-ddd     node-4     1/1     Running
```

---

#### ③ 访问宿主机资源

DaemonSet 常用 `hostPath` 访问宿主机资源：

```yaml
volumes:
- name: varlog
  hostPath:
    path: /var/log  # 宿主机的 /var/log

- name: docker-sock
  hostPath:
    path: /var/run/docker.sock  # 访问 Docker

- name: sys
  hostPath:
    path: /sys  # 访问系统信息
```

**典型场景：**
- **日志采集**：读取 `/var/log/`
- **监控 Agent**：读取 `/proc/`、`/sys/`
- **网络插件**：操作宿主机网络

---

### 5.3 调度策略

#### ① 默认：在所有节点运行

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  template:
    spec:
      containers:
      - name: collector
        image: log-collector:v1.0
```

**结果：每个节点都运行一个 Pod**

---

#### ② 通过 nodeSelector 限制节点

```yaml
spec:
  template:
    spec:
      nodeSelector:
        role: worker  # 只在有这个标签的节点运行
      containers:
      - name: collector
        image: log-collector:v1.0
```

**给节点打标签：**

```bash
# 给 node-1 和 node-2 打标签
kubectl label node node-1 role=worker
kubectl label node node-2 role=worker

# 只在 node-1 和 node-2 运行
kubectl get pods -o wide
# NAME                  NODE       READY   STATUS
# log-collector-aaa     node-1     1/1     Running
# log-collector-bbb     node-2     1/1     Running
```

---

#### ③ 通过 tolerations 在特殊节点运行

**K8s 的 Master 节点默认有污点（Taint），不允许 Pod 调度：**

```bash
kubectl describe node master | Select-String "Taints"
# Taints: node-role.kubernetes.io/control-plane:NoSchedule
```

**如果要在 Master 上也运行 DaemonSet：**

```yaml
spec:
  template:
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: collector
        image: log-collector:v1.0
```

**现在 Master 上也会运行 Pod！**

---

### 典型应用场景

| 场景 | 说明 | 示例 |
|-----|-----|-----|
| **日志采集** | 收集每个节点的日志 | Fluentd, Filebeat |
| **监控 Agent** | 监控节点性能 | Node Exporter, Datadog Agent |
| **网络插件** | 管理节点网络 | Calico, Flannel |
| **存储插件** | 管理节点存储 | Ceph, GlusterFS |
| **安全扫描** | 节点漏洞扫描 | Falco, Sysdig |

---

## 六、Job 和 CronJob：一次性任务和定时任务

### 6.1 为什么不用系统 cron？

**我遇到的需求：**

产品："每天凌晨 3 点清理 Redis 的过期键"

**我的第一反应：**

```bash
# 在服务器上配置 crontab
0 3 * * * /usr/local/bin/cleanup-redis.sh
```

**产品："不行！"**

**为什么不行？**

```
❌ 服务器重启后，cron 可能没启动
❌ 任务失败了，没有重试机制
❌ 没有日志，不知道任务有没有执行
❌ K8s 集群里的 Redis，外部脚本连不上（网络隔离）
❌ 多台服务器，每台都要配置 cron？
```

**K8s 的 CronJob 解决了这些问题！**

---

### 6.2 Job vs CronJob

| 特性 | Job | CronJob |
|-----|-----|---------|
| **执行时机** | 立即执行一次 | 定时执行 |
| **适用场景** | 数据迁移、批处理 | 备份、清理、报表 |
| **配置** | 简单 | 需要 cron 表达式 |
| **示例** | 数据导入 | 每天备份数据库 |

**简单说：**
- **Job**：跑一次就结束
- **CronJob**：定时重复跑

---

### 6.3 核心特性

#### Job 示例

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
      restartPolicy: OnFailure  # 失败自动重试
```

**执行流程：**

```bash
# 创建 Job
kubectl apply -f job.yaml

# 查看状态
kubectl get jobs
# NAME           COMPLETIONS   DURATION   AGE
# data-import    0/1           5s         5s

# 完成后
kubectl get jobs
# NAME           COMPLETIONS   DURATION   AGE
# data-import    1/1           30s        35s
```

**特点：**
- Pod 运行完后，状态是 `Completed`
- Pod 不会自动删除（可以查看日志）
- 失败自动重试（根据 `restartPolicy`）

---

#### CronJob 示例

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: redis-cleanup
spec:
  schedule: "0 3 * * *"  # 每天 3:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: redis-cleanup:v1.0
            env:
            - name: REDIS_HOST
              value: "redis-service:6379"
          restartPolicy: OnFailure
```

**Cron 表达式：**

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

```
0 3 * * *       # 每天 3:00
*/5 * * * *     # 每 5 分钟
0 */2 * * *     # 每 2 小时
0 0 * * 0       # 每周日 0:00
0 0 1 * *       # 每月 1 号 0:00
```

---

#### 查看执行历史

```bash
# 查看 CronJob
kubectl get cronjobs
# NAME            SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# redis-cleanup   0 3 * * *     False     0        12h             5d

# 查看历史 Job
kubectl get jobs
# NAME                       COMPLETIONS   DURATION   AGE
# redis-cleanup-28345670     1/1           45s        12h
# redis-cleanup-28345680     1/1           42s        36h
# redis-cleanup-28345690     1/1           48s        60h

# 查看 Pod 日志
kubectl logs redis-cleanup-28345670-xxxxx
```

---

#### 重要配置

```yaml
spec:
  schedule: "0 3 * * *"
  successfulJobsHistoryLimit: 3  # 保留 3 个成功的 Job
  failedJobsHistoryLimit: 1      # 保留 1 个失败的 Job
  concurrencyPolicy: Forbid       # 并发策略
```

**并发策略：**
- `Allow`：允许并发执行（默认）
- `Forbid`：禁止并发，上次未完成则跳过
- `Replace`：取消上次任务，启动新任务

**我的建议：**
- 数据库备份：用 `Forbid`（避免并发写入）
- 数据清理：用 `Allow`（清理多次也没事）
- 报表生成：用 `Replace`（只要最新的）

---

## 七、实战对比：部署 Redis 的三种方式

### 7.1 方式一：用 Deployment（不推荐）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: redis
        image: redis:7.4
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}  # 临时目录
```

**测试：**

```bash
# 写入数据
kubectl exec -it redis-xxx -- redis-cli SET test-key "hello"
# OK

# 读取数据
kubectl exec -it redis-xxx -- redis-cli GET test-key
# "hello"

# 删除 Pod（模拟重启）
kubectl delete pod redis-xxx

# 等待新 Pod 创建
kubectl get pods
# NAME          READY   STATUS    RESTARTS   AGE
# redis-yyy     1/1     Running   0          10s

# 尝试读取数据
kubectl exec -it redis-yyy -- redis-cli GET test-key
# (nil)  ← 数据丢了！
```

**问题：**
- ❌ `emptyDir` 是临时的，Pod 重建后数据丢失
- ❌ 即使用 PV，多副本共享 PV 会数据冲突

---

### 7.2 方式二：用 StatefulSet（推荐）

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  clusterIP: None  # Headless Service
  selector:
    app: redis
  ports:
  - port: 6379
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis-service
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.4
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

**测试：**

```bash
# 写入数据
kubectl exec -it redis-0 -- redis-cli SET test-key "hello"
# OK

# 读取数据
kubectl exec -it redis-0 -- redis-cli GET test-key
# "hello"

# 删除 Pod
kubectl delete pod redis-0

# 等待重建
kubectl get pods
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   1/1     Running   0          10s  ← 名称还是 redis-0

# 读取数据
kubectl exec -it redis-0 -- redis-cli GET test-key
# "hello"  ← 数据还在！
```

**好处：**
- ✅ Pod 名称固定（`redis-0`）
- ✅ PVC 自动绑定（`data-redis-0`）
- ✅ 数据持久化
- ✅ 可以配置主从复制

---

### 7.3 对比总结

| 特性 | Deployment + emptyDir | Deployment + PV | StatefulSet + PVC |
|-----|----------------------|----------------|------------------|
| **数据持久化** | ❌ | ⚠️ | ✅ |
| **多副本支持** | ❌ | ❌ | ✅ |
| **固定标识** | ❌ | ❌ | ✅ |
| **主从复制** | ❌ | ❌ | ✅ |
| **生产可用** | ❌ | ❌ | ✅ |

**结论：**
- 测试环境：可以用 `Deployment + emptyDir`（快速，不在乎数据）
- 开发环境：可以用 `Deployment + PV`（单副本）
- **生产环境：必须用 `StatefulSet`！**

---

## 八、选择工作负载的 5 个原则

### 原则 1：优先考虑应用的状态

```
无状态应用 → Deployment
有状态应用 → StatefulSet
```

**判断标准：**
- Pod 重启后，数据能丢吗？
  - 能丢 → Deployment
  - 不能丢 → StatefulSet

---

### 原则 2：考虑部署位置

```
特定节点 → nodeSelector / nodeAffinity
每个节点 → DaemonSet
```

**示例：**
- GPU 训练任务 → `nodeSelector: gpu=true`
- 日志采集 → DaemonSet

---

### 原则 3：考虑运行时长

```
长期运行 → Deployment / StatefulSet / DaemonSet
一次性任务 → Job
定时任务 → CronJob
```

---

### 原则 4：考虑网络需求

```
需要固定 DNS → StatefulSet + Headless Service
负载均衡 → Deployment + Service
```

---

### 原则 5：不确定时，先用 Deployment

**90% 的应用都是无状态的！**

如果不确定，先用 Deployment，遇到问题再考虑：
- 数据丢失？→ StatefulSet
- 需要每个节点？→ DaemonSet
- 定时执行？→ CronJob

---

## 结语

**这篇文章，我搞懂了：**

✅ **Deployment**：无状态应用的首选
  - 随机 Pod 名称
  - 快速扩缩容
  - 滚动更新
  - 适合 API、Web 前端

✅ **StatefulSet**：有状态应用的必选
  - 固定 Pod 名称（`name-0`）
  - 固定网络标识（DNS）
  - 独立持久化存储（PVC）
  - 适合数据库、缓存

✅ **DaemonSet**：节点级守护进程
  - 每个节点一个 Pod
  - 节点扩缩容自动适应
  - 可访问宿主机资源
  - 适合日志、监控

✅ **Job/CronJob**：批处理和定时任务
  - 运行完自动退出
  - 失败自动重试
  - 支持定时调度
  - 适合备份、清理

---

**最大的收获：**

> **不是所有应用都适合 Deployment！**  
> **选择合适的工作负载，就像选择合适的工具：**  
> **锤子修不了灯泡，用对工具才能事半功倍！**

---

**下一步（v0.2）：**

在下一篇文章中，我会**实战部署 Redis StatefulSet**，包括：
- ✅ 配置 Headless Service
- ✅ 创建 StatefulSet
- ✅ 配置持久化存储
- ✅ 验证数据持久化
- ✅ **我踩过的所有坑！**

敬请期待！

---

**如果这篇文章对你有帮助，欢迎点赞、收藏、分享！**

**有问题欢迎在评论区讨论！** 👇

