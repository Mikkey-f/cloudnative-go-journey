# 从零开始的云原生之旅（五）：用 StatefulSet 部署 Redis

> 终于搞懂了持久化存储！数据不会再丢了！

## 📖 文章目录

- [前言](#前言)
- [一、为什么 Redis 需要 StatefulSet？](#一为什么-redis-需要-statefulset)
  - [1.1 我用 Deployment 踩的坑](#11-我用-deployment-踩的坑)
  - [1.2 StatefulSet 的解决方案](#12-statefulset-的解决方案)
- [二、架构设计](#二架构设计)
  - [2.1 整体架构](#21-整体架构)
  - [2.2 核心组件](#22-核心组件)
  - [2.3 数据流](#23-数据流)
- [三、配置 Redis](#三配置-redis)
  - [3.1 Redis 配置文件详解](#31-redis-配置文件详解)
  - [3.2 创建 ConfigMap](#32-创建-configmap)
  - [3.3 我踩的坑：ConfigMap 语法错误](#33-我踩的坑configmap-语法错误)
- [四、创建 Headless Service](#四创建-headless-service)
  - [4.1 什么是 Headless Service？](#41-什么是-headless-service)
  - [4.2 Service 配置](#42-service-配置)
  - [4.3 DNS 解析原理](#43-dns-解析原理)
- [五、部署 StatefulSet](#五部署-statefulset)
  - [5.1 StatefulSet 配置详解](#51-statefulset-配置详解)
  - [5.2 关键配置解读](#52-关键配置解读)
  - [5.3 volumeClaimTemplates 详解](#53-volumeclaimtemplates-详解)
- [六、部署和验证](#六部署和验证)
  - [6.1 部署 Redis](#61-部署-redis)
  - [6.2 验证 Pod 状态](#62-验证-pod-状态)
  - [6.3 验证 PVC 绑定](#63-验证-pvc-绑定)
  - [6.4 验证 DNS 解析](#64-验证-dns-解析)
- [七、数据持久化测试](#七数据持久化测试)
  - [7.1 写入数据](#71-写入数据)
  - [7.2 删除 Pod（模拟故障）](#72-删除-pod模拟故障)
  - [7.3 验证数据是否保留](#73-验证数据是否保留)
  - [7.4 查看持久化文件](#74-查看持久化文件)
- [八、健康检查和资源管理](#八健康检查和资源管理)
  - [8.1 Liveness Probe（存活探针）](#81-liveness-probe存活探针)
  - [8.2 Readiness Probe（就绪探针）](#82-readiness-probe就绪探针)
  - [8.3 资源限制](#83-资源限制)
- [九、常见问题和排查](#九常见问题和排查)
  - [9.1 Pod 无法启动](#91-pod-无法启动)
  - [9.2 PVC Pending 状态](#92-pvc-pending-状态)
  - [9.3 Redis 连接失败](#93-redis-连接失败)
  - [9.4 数据丢失](#94-数据丢失)
- [十、扩展：从单机到主从](#十扩展从单机到主从)
  - [10.1 主从架构设计](#101-主从架构设计)
  - [10.2 配置调整](#102-配置调整)
- [结语](#结语)

---

## 前言

在上一篇文章中，我了解了 K8s 的 4 种工作负载。最大的收获是：

> **不是所有应用都适合 Deployment！**  
> **有状态应用（数据库、缓存）需要用 StatefulSet！**

这篇文章，我要**实战部署 Redis**，彻底搞懂：
- ✅ StatefulSet 怎么配置？
- ✅ 持久化存储怎么设置？
- ✅ Headless Service 是什么？
- ✅ 如何保证数据不丢失？
- ✅ **我踩过的所有坑！**

---

## 一、为什么 Redis 需要 StatefulSet？

### 1.1 我用 Deployment 踩的坑

最开始，我天真地用 Deployment 部署 Redis：

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
        image: redis:7-alpine
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}  # 临时存储
```

**我以为没问题，直到...：**

```bash
# 写入数据
kubectl exec -it redis-xxx -- redis-cli SET mykey "hello redis"
# OK

# 重启 Pod（模拟故障）
kubectl delete pod redis-xxx

# 尝试读取数据
kubectl exec -it redis-yyy -- redis-cli GET mykey
# (nil)  ← 数据丢了！！！
```

**我崩溃了：为什么数据会丢？**

---

**排查过程：**

```bash
# 查看 Volume
kubectl describe pod redis-xxx

# Volumes:
#   data:
#     Type:       EmptyDir (临时目录)
#     Medium:     
```

**原来 `emptyDir` 是临时的！**
- Pod 创建时，创建临时目录
- Pod 删除时，临时目录也删除
- 数据全丢了！

---

**第二次尝试：用 PersistentVolume**

```yaml
volumes:
- name: data
  persistentVolumeClaim:
    claimName: redis-pvc  # 手动创建的 PVC
```

**这次数据不丢了，但又遇到新问题：**

```
老板："我要部署 Redis 主从，实现高可用"
我："好，replicas: 2"

结果：
  ❌ 两个 Pod 共享同一个 PVC
  ❌ Redis 启动失败：数据目录已被占用
  ❌ 即使能启动，两个 Redis 写同一个文件，数据会乱
```

**我意识到：需要给每个 Pod 分配独立的 PVC！**

但 Deployment 做不到这一点！

---

### 1.2 StatefulSet 的解决方案

StatefulSet 提供了：

**① 固定的 Pod 名称**
```
Deployment：
  redis-7f8d9c-abcde  ← 随机后缀

StatefulSet：
  redis-0  ← 固定名称，重启后不变
```

**② 自动创建独立的 PVC**
```yaml
volumeClaimTemplates:  # 模板
- metadata:
    name: data
  spec:
    resources:
      requests:
        storage: 1Gi
```

**生成的 PVC：**
```
data-redis-0  →  绑定到 redis-0
data-redis-1  →  绑定到 redis-1  (如果有多副本)
```

**③ 固定的网络标识**
```
redis-0.redis-service.default.svc.cluster.local
```

**这样，Redis 就可以稳定运行了！**

---

## 二、架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────┐
│              K8s 集群                            │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │        Headless Service                   │  │
│  │      redis-service (ClusterIP: None)     │  │
│  │                                           │  │
│  │  DNS:                                     │  │
│  │  redis-0.redis-service → 10.1.2.3        │  │
│  └──────────────────────────────────────────┘  │
│                     │                           │
│                     ↓                           │
│  ┌──────────────────────────────────────────┐  │
│  │         StatefulSet: redis               │  │
│  │                                           │  │
│  │  ┌─────────────────────────────────┐     │  │
│  │  │          Pod: redis-0           │     │  │
│  │  │  ┌─────────────────────────┐    │     │  │
│  │  │  │   Container: redis      │    │     │  │
│  │  │  │   Image: redis:7-alpine │    │     │  │
│  │  │  │   Port: 6379            │    │     │  │
│  │  │  └─────────────────────────┘    │     │  │
│  │  │          │                       │     │  │
│  │  │          ↓ volumeMount          │     │  │
│  │  │  ┌─────────────────────────┐    │     │  │
│  │  │  │    Volume: redis-data   │    │     │  │
│  │  │  └─────────────────────────┘    │     │  │
│  │  └─────────────────────────────────┘     │  │
│  └──────────────────────────────────────────┘  │
│                     │                           │
│                     ↓ PVC                       │
│  ┌──────────────────────────────────────────┐  │
│  │      PVC: data-redis-0                   │  │
│  │      Storage: 1Gi                        │  │
│  └──────────────────────────────────────────┘  │
│                     │                           │
│                     ↓ PV                        │
│  ┌──────────────────────────────────────────┐  │
│  │      PersistentVolume                    │  │
│  │      (自动创建，StorageClass: standard)  │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

### 2.2 核心组件

| 组件 | 作用 | 关键配置 |
|-----|-----|---------|
| **ConfigMap** | 存储 Redis 配置文件 | `redis.conf` |
| **Headless Service** | 提供固定 DNS 解析 | `clusterIP: None` |
| **StatefulSet** | 管理 Redis Pod | `serviceName`, `volumeClaimTemplates` |
| **PVC** | 持久化数据请求 | 自动创建 |
| **PV** | 实际的存储卷 | 自动创建（Minikube）|

---

### 2.3 数据流

**① 写入数据：**
```
应用 → redis-service:6379 
     → DNS 解析 → redis-0 (10.1.2.3:6379)
     → Redis 写入内存
     → RDB/AOF 持久化到 /data
     → /data 挂载到 PVC: data-redis-0
     → 数据存储到 PV
```

**② Pod 重启：**
```
1. Pod redis-0 被删除
2. StatefulSet 立即重建 redis-0（名称不变）
3. 重新绑定 PVC: data-redis-0
4. Redis 启动，读取 /data 目录
5. 从 RDB/AOF 恢复数据
6. 数据完整！
```

---

## 三、配置 Redis

### 3.1 Redis 配置文件详解

Redis 需要一些自定义配置：

```conf
# 绑定所有网络接口（K8s 内部访问）
bind 0.0.0.0

# 端口
port 6379

# 内存限制（避免OOM）
maxmemory 128mb

# 内存淘汰策略
maxmemory-policy allkeys-lru  # 优先删除最少使用的key

# RDB 持久化（快照）
save 900 1      # 900秒内至少1个key变更，就保存快照
save 300 10     # 300秒内至少10个key变更
save 60 10000   # 60秒内至少10000个key变更

# 数据目录
dir /data

# AOF 持久化（追加日志）
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec  # 每秒同步一次

# 日志级别
loglevel notice

# 保护模式（关闭，K8s内部网络是安全的）
protected-mode no
```

**持久化策略对比：**

| 策略 | RDB | AOF |
|-----|-----|-----|
| **持久化方式** | 定期快照 | 追加日志 |
| **文件大小** | 小 | 大 |
| **恢复速度** | 快 | 慢 |
| **数据安全性** | 可能丢失最后几分钟 | 最多丢失1秒 |
| **推荐场景** | 对数据一致性要求不高 | 对数据安全要求高 |

**我的选择：RDB + AOF 双重保险！**

---

### 3.2 创建 ConfigMap

把配置文件保存到 K8s ConfigMap：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  labels:
    app: redis
    version: v0.2
data:
  redis.conf: |
    # Redis 配置文件
    bind 0.0.0.0
    port 6379
    maxmemory 128mb
    maxmemory-policy allkeys-lru
    
    # 持久化配置（RDB）
    # 格式：save <秒> <变更次数>
    # 900秒内至少1个key变更
    save 900 1
    # 300秒内至少10个key变更
    save 300 10
    # 60秒内至少10000个key变更
    save 60 10000
    
    dir /data
    appendonly yes
    appendfilename "appendonly.aof"
    appendfsync everysec
    loglevel notice
    protected-mode no
```

**关键点：**
- `data` 字段包含配置文件内容
- `|` 表示多行字符串
- 注释要单独一行（见下面的坑）

---

### 3.3 我踩的坑：ConfigMap 语法错误

**第一次部署：**

```yaml
data:
  redis.conf: |
    save 900 1  # 900秒内至少1个key变更  ← 注释写在行尾
```

**结果：Redis Pod 启动失败！**

```bash
kubectl logs redis-0
# *** FATAL CONFIG FILE ERROR ***
# Reading the configuration file, at line 16
# >>> 'save 900 1 # 900秒内至少1个key变更'
# Invalid save param
```

**原因：Redis 不支持行内注释（在某些版本）！**

**正确写法：**

```yaml
data:
  redis.conf: |
    # 900秒内至少1个key变更
    save 900 1
    # 300秒内至少10个key变更
    save 300 10
```

**教训：ConfigMap 中的配置文件，要遵循原软件的语法规则！**

---

## 四、创建 Headless Service

### 4.1 什么是 Headless Service？

**普通 Service：**
```
┌──────────────────────┐
│      Service         │
│  ClusterIP: 10.0.1.5 │  ← VIP（虚拟IP）
└──────────────────────┘
         │
         ↓ 负载均衡
    ┌────┴────┐
    │         │
┌───↓──┐  ┌──↓───┐
│ Pod1 │  │ Pod2 │
└──────┘  └──────┘
```

**请求流程：**
```
应用 → service:6379 (10.0.1.5)
     → kube-proxy 随机选择一个 Pod
     → Pod1 或 Pod2
```

---

**Headless Service：**
```
┌──────────────────────┐
│      Service         │
│  ClusterIP: None     │  ← 没有 VIP！
└──────────────────────┘
         │
         ↓ DNS 直接返回 Pod IP
    ┌────┴────┐
    │         │
┌───↓──┐  ┌──↓───┐
│ Pod1 │  │ Pod2 │
│ 10.1 │  │ 10.2 │
└──────┘  └──────┘
```

**请求流程：**
```
应用 → redis-0.service (DNS 查询)
     → DNS 返回 redis-0 的 IP (10.1.2.3)
     → 直接访问 redis-0
```

---

**为什么 StatefulSet 需要 Headless Service？**

假设 Redis 主从架构：
- `redis-0` 是主节点
- `redis-1` 是从节点

**从节点需要连接主节点：**

```bash
# 从节点配置
redis-cli --replica-of redis-0.redis-service 6379
```

**这需要：**
- ✅ 固定的主节点 DNS（`redis-0.redis-service`）
- ✅ DNS 直接解析到 redis-0 的 IP
- ✅ 不能负载均衡（必须连接特定的 Pod）

**普通 Service 做不到，Headless Service 可以！**

---

### 4.2 Service 配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  labels:
    app: redis
spec:
  # 关键：设置为 None
  clusterIP: None
  
  selector:
    app: redis
  
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
    protocol: TCP
```

**关键点：**
- `clusterIP: None` - 这是 Headless Service 的标志
- `selector: app=redis` - 选择 Redis Pod
- 不需要 `type`（默认是 ClusterIP，但设置为 None）

---

### 4.3 DNS 解析原理

**部署后，K8s 会自动创建 DNS 记录：**

**① Service 的 DNS：**
```
redis-service.default.svc.cluster.local
  ↓ 解析
所有 Pod 的 IP（多个A记录）
```

**② 每个 Pod 的 DNS：**
```
redis-0.redis-service.default.svc.cluster.local  → 10.1.2.3
redis-1.redis-service.default.svc.cluster.local  → 10.1.2.4
```

**测试 DNS：**

```bash
# 在集群内创建一个临时 Pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# 解析 Service DNS
nslookup redis-service.default.svc.cluster.local
# Name:    redis-service.default.svc.cluster.local
# Address: 10.1.2.3  ← Pod IP（不是 VIP）

# 解析 Pod DNS
nslookup redis-0.redis-service.default.svc.cluster.local
# Name:    redis-0.redis-service.default.svc.cluster.local
# Address: 10.1.2.3  ← redis-0 的 IP
```

**简写：**
- 同一命名空间内：`redis-service`
- 跨命名空间：`redis-service.default`
- 完整域名：`redis-service.default.svc.cluster.local`

---

## 五、部署 StatefulSet

### 5.1 StatefulSet 配置详解

完整配置：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  labels:
    app: redis
    version: v0.2
spec:
  # 必须指定 Headless Service
  serviceName: redis-service
  
  # 副本数
  replicas: 1
  
  # 选择器
  selector:
    matchLabels:
      app: redis
  
  # Pod 模板
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        
        # 启动命令：使用自定义配置
        command:
        - redis-server
        - /etc/redis/redis.conf
        
        ports:
        - containerPort: 6379
          name: redis
        
        # 资源限制
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        
        # 存活探针
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        
        # 就绪探针
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
        
        # 挂载卷
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /etc/redis
      
      # ConfigMap 卷
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  
  # 持久化卷声明模板（核心！）
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: 
      - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

---

### 5.2 关键配置解读

**① serviceName（必须！）**

```yaml
spec:
  serviceName: redis-service  # 必须指定，且必须是 Headless Service
```

**作用：**
- 生成 Pod 的 DNS 记录
- 格式：`$(pod-name).$(service-name).$(namespace).svc.cluster.local`

**如果不指定，Pod 没有固定 DNS！**

---

**② Pod 模板中的 volumes**

```yaml
volumes:
- name: redis-config
  configMap:
    name: redis-config  # 引用 ConfigMap
```

**作用：**
- 把 ConfigMap 挂载到 Pod
- Redis 启动时读取 `/etc/redis/redis.conf`

---

**③ command（覆盖镜像默认命令）**

```yaml
command:
- redis-server
- /etc/redis/redis.conf
```

**为什么需要？**

Redis 镜像默认启动命令：
```bash
redis-server  # 使用默认配置
```

我们需要：
```bash
redis-server /etc/redis/redis.conf  # 使用自定义配置
```

---

**④ 资源限制**

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

**为什么要限制？**
- **requests**：K8s 调度时，保证节点有这么多资源
- **limits**：Pod 最多使用这么多，超过会被限制（CPU）或杀死（内存）

**不限制的后果：**
- Redis 内存泄漏 → 占满节点内存 → 其他 Pod 被驱逐
- Redis 占满 CPU → 其他 Pod 卡顿

---

### 5.3 volumeClaimTemplates 详解

**这是 StatefulSet 最核心的配置！**

```yaml
volumeClaimTemplates:
- metadata:
    name: redis-data  # PVC 名称前缀
  spec:
    accessModes: 
    - ReadWriteOnce  # 单节点读写
    resources:
      requests:
        storage: 1Gi  # 存储大小
```

**StatefulSet 会自动：**

1. **为每个 Pod 创建 PVC**
```
redis-0 → PVC: data-redis-0 (1Gi)
redis-1 → PVC: data-redis-1 (1Gi)  (如果 replicas > 1)
```

2. **自动绑定 PV**
```
Minikube 自动创建 PV：
  pv-001 (1Gi) → data-redis-0
  pv-002 (1Gi) → data-redis-1
```

3. **Pod 重建后，重新绑定原 PVC**
```
redis-0 被删除
  ↓
StatefulSet 重建 redis-0
  ↓
自动绑定 data-redis-0（数据不丢！）
```

---

**accessModes 详解：**

| 模式 | 说明 | 适用场景 |
|-----|-----|---------|
| `ReadWriteOnce` (RWO) | 单节点读写 | 大多数应用（MySQL、Redis） |
| `ReadOnlyMany` (ROX) | 多节点只读 | 静态资源、配置文件 |
| `ReadWriteMany` (RWX) | 多节点读写 | 共享存储（需要特殊 StorageClass） |

**Redis 用 RWO：**
- 每个 Redis Pod 独立存储
- 不需要多节点同时写

---

**storageClassName（可选）：**

```yaml
volumeClaimTemplates:
- spec:
    storageClassName: fast-ssd  # 指定存储类
```

**Minikube 的默认 StorageClass：**
```bash
kubectl get storageclass
# NAME                 PROVISIONER
# standard (default)   k8s.io/minikube-hostpath
```

**不指定，就用默认的！**

---

## 六、部署和验证

### 6.1 部署 Redis

**① 创建 ConfigMap**

```bash
kubectl apply -f k8s/v0.2/redis/configmap.yaml
# configmap/redis-config created
```

**② 创建 Headless Service**

```bash
kubectl apply -f k8s/v0.2/redis/service.yaml
# service/redis-service created
```

**③ 创建 StatefulSet**

```bash
kubectl apply -f k8s/v0.2/redis/statefulset.yaml
# statefulset.apps/redis created
```

---

### 6.2 验证 Pod 状态

```bash
# 查看 Pod
kubectl get pods
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   0/1     Running   0          10s  ← 正在启动

# 等待 Ready
kubectl get pods -w  # 持续监控

# 最终状态
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   1/1     Running   0          1m
```

**如果长时间 Pending：**

```bash
# 查看详细信息
kubectl describe pod redis-0

# 常见原因：
# - PVC 创建失败
# - 镜像拉取失败
# - 资源不足
```

---

### 6.3 验证 PVC 绑定

```bash
# 查看 PVC
kubectl get pvc
# NAME             STATUS   VOLUME                  CAPACITY   ACCESS MODES   AGE
# data-redis-0     Bound    pvc-a1b2c3d4-...        1Gi        RWO            1m

# 查看 PV
kubectl get pv
# NAME                    CAPACITY   ACCESS MODES   STATUS   CLAIM                    
# pvc-a1b2c3d4-...        1Gi        RWO            Bound    default/data-redis-0
```

**关键点：**
- PVC 名称：`data-redis-0`（模板名 + Pod名）
- STATUS：`Bound`（绑定成功）
- PV 自动创建

---

### 6.4 验证 DNS 解析

```bash
# 方法1：在 redis-0 内部测试
kubectl exec -it redis-0 -- sh

# 安装 nslookup（如果没有）
apk add bind-tools

# 解析 Service DNS
nslookup redis-service
# Name:    redis-service.default.svc.cluster.local
# Address: 10.1.2.3

# 解析 Pod DNS
nslookup redis-0.redis-service
# Name:    redis-0.redis-service.default.svc.cluster.local
# Address: 10.1.2.3

exit
```

```bash
# 方法2：创建临时 Pod 测试
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# 测试连接
telnet redis-service 6379
# Connected to redis-service
```

**如果解析失败，检查：**
- Service 是否创建成功：`kubectl get svc redis-service`
- Pod 是否 Running：`kubectl get pods redis-0`
- CoreDNS 是否正常：`kubectl get pods -n kube-system`

---

## 七、数据持久化测试

**这是最关键的测试：验证数据不会丢失！**

### 7.1 写入数据

```bash
# 连接到 Redis
kubectl exec -it redis-0 -- redis-cli

# 写入一些数据
SET user:1001 "张三"
# OK

SET user:1002 "李四"
# OK

SET counter 100
# OK

INCR counter
# (integer) 101

# 查看所有 key
KEYS *
# 1) "counter"
# 2) "user:1002"
# 3) "user:1001"

# 退出
exit
```

---

### 7.2 删除 Pod（模拟故障）

```bash
# 删除 Pod
kubectl delete pod redis-0
# pod "redis-0" deleted

# 立即查看状态
kubectl get pods
# NAME      READY   STATUS        RESTARTS   AGE
# redis-0   1/1     Terminating   0          5m  ← 正在删除

# 等待重建
kubectl get pods -w
# NAME      READY   STATUS              RESTARTS   AGE
# redis-0   0/1     ContainerCreating   0          1s
# redis-0   1/1     Running             0          10s  ← 重建完成
```

**注意：名称还是 redis-0！**

---

### 7.3 验证数据是否保留

```bash
# 连接到新的 redis-0
kubectl exec -it redis-0 -- redis-cli

# 查看数据
GET user:1001
# "张三"  ← 数据还在！

GET user:1002
# "李四"

GET counter
# "101"

KEYS *
# 1) "counter"
# 2) "user:1002"
# 3) "user:1001"

# 所有数据都还在！！！
exit
```

**太激动了！数据真的保留了！**

---

### 7.4 查看持久化文件

```bash
# 进入 redis-0
kubectl exec -it redis-0 -- sh

# 查看数据目录
ls -lh /data
# total 8K
# -rw-r--r-- 1 redis redis  175 Oct 30 10:30 appendonly.aof  ← AOF 文件
# -rw-r--r-- 1 redis redis  123 Oct 30 10:25 dump.rdb        ← RDB 文件

# 查看 AOF 文件（部分内容）
cat /data/appendonly.aof
# *2
# $6
# SELECT
# $1
# 0
# *3
# $3
# SET
# $9
# user:1001
# $6
# 张三
# ...

# 查看 PVC 挂载
df -h /data
# Filesystem                Size      Used Available Use% Mounted on
# /dev/sda1                 1.0G      8.0K    1.0G   1% /data

exit
```

**数据确实持久化到 PV 了！**

---

## 八、健康检查和资源管理

### 8.1 Liveness Probe（存活探针）

**作用：检测容器是否存活，不存活则重启**

```yaml
livenessProbe:
  exec:
    command:
    - redis-cli
    - ping
  initialDelaySeconds: 30  # 启动后30秒开始检查
  periodSeconds: 10        # 每10秒检查一次
  timeoutSeconds: 5        # 超时5秒算失败
  failureThreshold: 3      # 失败3次才重启
```

**检测逻辑：**
```bash
# K8s 每10秒执行：
redis-cli ping
# PONG  ← 成功

# 如果返回值不是 PONG，或者超时 5 秒，算一次失败
# 连续失败 3 次 → 重启容器
```

**为什么要延迟 30 秒？**
- Redis 启动需要时间（加载 RDB/AOF）
- 太早检查会导致误杀

---

### 8.2 Readiness Probe（就绪探针）

**作用：检测容器是否就绪，未就绪则不转发流量**

```yaml
readinessProbe:
  exec:
    command:
    - redis-cli
    - ping
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

**与 Liveness 的区别：**

| 探针 | 失败后果 | 使用场景 |
|-----|---------|---------|
| Liveness | 重启容器 | 检测死锁、卡死 |
| Readiness | 移出 Service | 检测启动、依赖未就绪 |

**示例：**
```
Redis 启动中（加载 10GB 数据）：
  ├─ Liveness: PASS（进程存活）
  └─ Readiness: FAIL（还没加载完）
       → Service 不转发流量
       → 等待 Readiness PASS
       → 开始接收请求
```

---

### 8.3 资源限制

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

**requests vs limits：**

| 类型 | requests | limits |
|-----|---------|--------|
| **作用** | 调度依据 | 运行上限 |
| **CPU** | 保证 0.1 核 | 最多 0.2 核 |
| **内存** | 保证 128Mi | 最多 256Mi |
| **超过 limits** | CPU 被限流 | 内存被 OOM 杀死 |

**最佳实践：**
```yaml
# 生产环境
requests:
  memory: "512Mi"   # 保证基本运行
  cpu: "250m"
limits:
  memory: "1Gi"     # 允许峰值
  cpu: "500m"

# 开发环境
requests:
  memory: "128Mi"
  cpu: "100m"
limits:
  memory: "256Mi"
  cpu: "200m"
```

---

## 九、常见问题和排查

### 9.1 Pod 无法启动

**症状：**
```bash
kubectl get pods
# NAME      READY   STATUS             RESTARTS   AGE
# redis-0   0/1     CrashLoopBackOff   5          3m
```

**排查步骤：**

```bash
# 1. 查看日志
kubectl logs redis-0
# *** FATAL CONFIG FILE ERROR ***
# ...

# 2. 查看详细信息
kubectl describe pod redis-0
# Events:
#   Warning  Failed  Back-off restarting failed container

# 3. 进入容器（如果能进）
kubectl exec -it redis-0 -- sh
# 检查配置文件
cat /etc/redis/redis.conf
```

**常见原因：**
- ❌ ConfigMap 配置错误（语法错误）
- ❌ 权限不足（无法写入 /data）
- ❌ 端口被占用

---

### 9.2 PVC Pending 状态

**症状：**
```bash
kubectl get pvc
# NAME             STATUS    VOLUME   CAPACITY   ACCESS MODES   AGE
# data-redis-0     Pending                                      5m
```

**排查步骤：**

```bash
# 查看 PVC 详情
kubectl describe pvc data-redis-0
# Events:
#   Warning  ProvisioningFailed  no volume plugin matched

# 查看 StorageClass
kubectl get storageclass
# NAME       PROVISIONER
# (空的)  ← 没有默认 StorageClass！
```

**解决方案：**

```bash
# Minikube 启用默认存储
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

# 验证
kubectl get storageclass
# NAME                 PROVISIONER
# standard (default)   k8s.io/minikube-hostpath
```

---

### 9.3 Redis 连接失败

**症状：**
```bash
kubectl exec -it redis-0 -- redis-cli
# Could not connect to Redis at 127.0.0.1:6379: Connection refused
```

**排查步骤：**

```bash
# 1. 检查 Redis 进程
kubectl exec -it redis-0 -- sh
ps aux | grep redis
# 1 redis 0:00 redis-server 0.0.0.0:6379

# 2. 检查端口监听
netstat -tlnp | grep 6379
# tcp 0 0 0.0.0.0:6379 0.0.0.0:* LISTEN

# 3. 测试本地连接
redis-cli ping
# PONG  ← 本地连接正常

# 4. 检查配置
cat /etc/redis/redis.conf | grep bind
# bind 0.0.0.0  ← 应该是 0.0.0.0，不是 127.0.0.1
```

---

### 9.4 数据丢失

**症状：Pod 重启后，数据消失了**

**排查步骤：**

```bash
# 1. 检查 PVC 是否绑定
kubectl get pvc
# NAME             STATUS   VOLUME
# data-redis-0     Bound    pvc-xxx  ← 必须是 Bound

# 2. 检查持久化配置
kubectl exec -it redis-0 -- redis-cli CONFIG GET appendonly
# 1) "appendonly"
# 2) "yes"  ← 应该是 yes

# 3. 检查持久化文件
kubectl exec -it redis-0 -- ls -lh /data
# -rw-r--r-- 1 redis redis  175 Oct 30 10:30 appendonly.aof
# -rw-r--r-- 1 redis redis  123 Oct 30 10:25 dump.rdb

# 4. 检查 volumeMount
kubectl describe pod redis-0 | grep -A5 "Mounts:"
# Mounts:
#   /data from redis-data (rw)  ← 必须挂载到 /data
```

**常见原因：**
- ❌ PVC 没绑定（使用了 emptyDir）
- ❌ volumeMount 路径错误
- ❌ Redis 配置中 `dir` 路径错误

---

## 十、扩展：从单机到主从

### 10.1 主从架构设计

**当前：单机 Redis**
```
redis-0 (读写)
```

**目标：主从架构**
```
redis-0 (主节点，读写)
   │
   ├─ redis-1 (从节点，只读)
   └─ redis-2 (从节点，只读)
```

**好处：**
- ✅ 高可用（主节点挂了，从节点顶上）
- ✅ 读写分离（主节点写，从节点读）
- ✅ 数据备份（从节点实时备份）

---

### 10.2 配置调整

**① 修改 StatefulSet：**

```yaml
spec:
  replicas: 3  # 改为 3 个副本
```

**② 从节点配置（通过 Init Container）：**

```yaml
template:
  spec:
    initContainers:
    - name: init-redis
      image: redis:7-alpine
      command:
      - sh
      - -c
      - |
        if [ "$(hostname)" != "redis-0" ]; then
          # 如果不是 redis-0，配置为从节点
          echo "replicaof redis-0.redis-service 6379" >> /etc/redis/redis.conf
        fi
      volumeMounts:
      - name: redis-config
        mountPath: /etc/redis
```

**③ 部署：**

```bash
kubectl apply -f statefulset.yaml

# 查看 Pod
kubectl get pods
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   1/1     Running   0          2m  ← 主节点
# redis-1   1/1     Running   0          1m  ← 从节点
# redis-2   1/1     Running   0          30s ← 从节点
```

**④ 验证主从：**

```bash
# 在主节点写入
kubectl exec -it redis-0 -- redis-cli SET test "hello"

# 在从节点读取
kubectl exec -it redis-1 -- redis-cli GET test
# "hello"  ← 同步成功！
```

---

## 结语

**这篇文章，我学会了：**

✅ **为什么 Redis 需要 StatefulSet**
  - Deployment 无法保证数据持久化
  - StatefulSet 提供固定名称、固定存储、固定 DNS

✅ **Headless Service 的作用**
  - `clusterIP: None`
  - 提供固定的 Pod DNS 解析
  - 支持有状态应用的网络需求

✅ **volumeClaimTemplates 的原理**
  - 自动为每个 Pod 创建 PVC
  - Pod 重建后自动绑定原 PVC
  - 数据持久化到 PV

✅ **完整的部署流程**
  - ConfigMap → Service → StatefulSet
  - 数据持久化测试
  - 健康检查和资源限制

✅ **我踩过的坑**
  - ConfigMap 语法错误（行内注释）
  - PVC Pending（没有 StorageClass）
  - Redis 连接失败（bind 地址错误）

---

**最大的收获：**

> **StatefulSet 不是 Deployment 的高级版，而是解决不同问题的工具！**  
> **持久化存储 = volumeClaimTemplates + PVC + PV**  
> **固定标识 = Headless Service + 固定 Pod 名称**

---

**下一步（v0.2 继续）：**

在下一篇文章中，我会**实战部署 DaemonSet 日志采集器**，包括：
- ✅ DaemonSet 的完整配置
- ✅ 访问宿主机资源（hostPath）
- ✅ nodeSelector 和 tolerations
- ✅ 节点级服务的监控

敬请期待！

---

**如果这篇文章对你有帮助，欢迎点赞、收藏、分享！**

**有问题欢迎在评论区讨论！** 👇

