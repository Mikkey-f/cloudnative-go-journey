# v0.2 技能评估和学习路径

> 评估当前能力，规划学习路径

---

## 📊 技能评估检查表

### 1. v0.1 已掌握技能 ✅

基于你已经完成 v0.1，你应该已经掌握：

#### Go 编程
- [x] Go 基础语法
- [x] Gin 框架使用
- [x] HTTP 服务开发
- [x] 结构化日志
- [x] Prometheus 指标集成
- [x] 环境变量配置

#### Docker
- [x] Dockerfile 编写
- [x] 多阶段构建
- [x] 镜像构建和优化
- [x] 容器运行和调试
- [x] Docker 基础命令

#### Kubernetes 基础
- [x] Pod 概念
- [x] Deployment 资源
- [x] Service (NodePort)
- [x] kubectl 基础命令
- [x] 健康检查配置
- [x] 资源限制配置

---

## 🎓 v0.2 需要学习的新技能

### 2. 必须学习的核心概念

#### 2.1 StatefulSet（重要 ⭐⭐⭐⭐⭐）

**概念理解：**
```
StatefulSet 是什么？
- 管理有状态应用的工作负载
- 提供稳定的网络标识
- 提供稳定的持久化存储
- 有序部署、扩缩容、更新

与 Deployment 的区别：
┌──────────────┬──────────────┬───────────────┐
│   特性       │  Deployment  │  StatefulSet  │
├──────────────┼──────────────┼───────────────┤
│ Pod 名称     │ 随机         │ 固定 (redis-0)│
│ 网络标识     │ 不稳定       │ 稳定          │
│ 存储         │ 共享/临时    │ 独立持久化    │
│ 部署顺序     │ 并行         │ 有序          │
│ 适用场景     │ 无状态应用   │ 有状态应用    │
└──────────────┴──────────────┴───────────────┘
```

**学习资源：**
- 📖 [官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- 🎥 YouTube 搜索 "Kubernetes StatefulSet Tutorial"
- 📝 推荐阅读：[StatefulSet 最佳实践](https://kubernetes.io/docs/tutorials/stateful-application/)

**动手练习：**
```bash
# 1. 查看 StatefulSet
kubectl get statefulsets

# 2. 查看 StatefulSet 创建的 Pod
kubectl get pods -l app=redis

# 3. 查看 StatefulSet 详情
kubectl describe statefulset redis

# 4. 扩缩容
kubectl scale statefulset redis --replicas=3
```

**预计学习时间：** 2-3 小时

---

#### 2.2 持久化存储 PV/PVC（重要 ⭐⭐⭐⭐⭐）

**概念理解：**
```
存储架构三层：
1. StorageClass (存储类)
   - 定义存储类型
   - 自动创建 PV

2. PV (Persistent Volume 持久卷)
   - 实际的存储资源
   - 由管理员或 StorageClass 创建

3. PVC (Persistent Volume Claim 持久卷声明)
   - 用户对存储的请求
   - 绑定到 PV

关系：
StorageClass ──(动态创建)──▶ PV ──(绑定)──▶ PVC ──(挂载)──▶ Pod
```

**AccessModes（访问模式）：**
```
RWO (ReadWriteOnce)  - 单节点读写
ROX (ReadOnlyMany)   - 多节点只读
RWX (ReadWriteMany)  - 多节点读写

Redis 使用 RWO 即可
```

**学习资源：**
- 📖 [官方文档](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- 🎥 [Persistent Volumes 解释视频](https://www.youtube.com/results?search_query=kubernetes+persistent+volumes)

**动手练习：**
```bash
# 1. 查看 StorageClass
kubectl get storageclass

# 2. 查看 PV
kubectl get pv

# 3. 查看 PVC
kubectl get pvc

# 4. 查看 PVC 详情
kubectl describe pvc redis-data-redis-0

# 5. 查看 PVC 挂载
kubectl describe pod redis-0 | grep -A 5 Volumes
```

**预计学习时间：** 2-3 小时

---

#### 2.3 DaemonSet（重要 ⭐⭐⭐⭐）

**概念理解：**
```
DaemonSet 是什么？
- 确保每个节点运行一个 Pod
- 新节点加入自动部署
- 节点移除自动清理

典型应用场景：
✅ 日志收集（Fluentd, Logstash）
✅ 监控代理（Node Exporter, cAdvisor）
✅ 网络插件（Calico, Flannel）
✅ 存储插件（Ceph）
```

**学习资源：**
- 📖 [官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

**动手练习：**
```bash
# 1. 查看 DaemonSet
kubectl get daemonsets

# 2. 查看 DaemonSet 创建的 Pod
kubectl get pods -l app=log-collector -o wide

# 3. 验证每个节点都有
kubectl get nodes
kubectl get pods -o wide | grep log-collector
```

**预计学习时间：** 1-2 小时

---

#### 2.4 Job 和 CronJob（重要 ⭐⭐⭐⭐）

**概念理解：**
```
Job:
- 一次性任务
- 保证任务成功完成
- 完成后 Pod 保留（可查看日志）

CronJob:
- 定时任务
- 按计划创建 Job
- 基于 Cron 表达式
```

**Cron 表达式速查：**
```
格式: 分 时 日 月 周
      * * * * *

示例:
"0 * * * *"      # 每小时
"*/15 * * * *"   # 每 15 分钟
"0 2 * * *"      # 每天凌晨 2 点
"0 0 * * 0"      # 每周日凌晨
"0 0 1 * *"      # 每月 1 号凌晨
```

**学习资源：**
- 📖 [Job 文档](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- 📖 [CronJob 文档](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- 🔧 [Crontab Guru](https://crontab.guru/) - Cron 表达式在线工具

**动手练习：**
```bash
# 1. 查看 CronJob
kubectl get cronjobs

# 2. 查看 CronJob 创建的 Job
kubectl get jobs

# 3. 手动触发 CronJob
kubectl create job --from=cronjob/cleanup-job manual-cleanup

# 4. 查看 Job 日志
kubectl logs -l job-name=cleanup-job-xxx
```

**预计学习时间：** 1-2 小时

---

#### 2.5 ConfigMap 和 Secret（重要 ⭐⭐⭐⭐⭐）

**概念理解：**
```
ConfigMap:
- 存储非敏感配置
- 明文存储
- 配置文件、环境变量

Secret:
- 存储敏感信息
- Base64 编码（不是加密）
- 密码、Token、证书

注入方式：
1. 环境变量
2. 文件挂载
3. 命令行参数
```

**学习资源：**
- 📖 [ConfigMap 文档](https://kubernetes.io/docs/concepts/configuration/configmap/)
- 📖 [Secret 文档](https://kubernetes.io/docs/concepts/configuration/secret/)

**动手练习：**
```bash
# 1. 创建 ConfigMap（命令行）
kubectl create configmap my-config --from-literal=key1=value1

# 2. 查看 ConfigMap
kubectl get configmap
kubectl describe configmap api-config

# 3. 创建 Secret
kubectl create secret generic my-secret --from-literal=password=abc123

# 4. 查看 Secret
kubectl get secret
kubectl describe secret my-secret
```

**预计学习时间：** 2 小时

---

#### 2.6 Headless Service（重要 ⭐⭐⭐）

**概念理解：**
```
普通 Service vs Headless Service:

普通 Service:
- 有 ClusterIP
- DNS 返回 VIP
- 负载均衡到多个 Pod

Headless Service:
- ClusterIP: None
- DNS 直接返回 Pod IP
- 用于 StatefulSet 稳定网络标识

DNS 解析：
redis-0.redis-service.default.svc.cluster.local
^       ^             ^       ^
Pod名   Service名     命名空间  域名
```

**学习资源：**
- 📖 [官方文档](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)

**预计学习时间：** 1 小时

---

### 3. 技术栈学习

#### 3.1 Go Redis 客户端（必须 ⭐⭐⭐⭐⭐）

**推荐库：** `github.com/go-redis/redis/v8`

**快速入门：**
```go
import "github.com/go-redis/redis/v8"

// 创建客户端
rdb := redis.NewClient(&redis.Options{
    Addr:     "localhost:6379",
    Password: "", // 无密码
    DB:       0,  // 默认数据库
})

// 基础操作
ctx := context.Background()

// SET
rdb.Set(ctx, "key", "value", 0)

// GET
val, err := rdb.Get(ctx, "key").Result()

// DEL
rdb.Del(ctx, "key")

// EXPIRE
rdb.Expire(ctx, "key", 1*time.Hour)
```

**学习资源：**
- 📖 [go-redis 文档](https://redis.uptrace.dev/)
- 📖 [Redis 命令参考](https://redis.io/commands)

**预计学习时间：** 2-3 小时

---

#### 3.2 Redis 基础（推荐 ⭐⭐⭐⭐）

**核心概念：**
```
数据类型:
- String (字符串)
- Hash (哈希)
- List (列表)
- Set (集合)
- Sorted Set (有序集合)

常用命令:
SET key value
GET key
DEL key
EXISTS key
EXPIRE key seconds
TTL key
KEYS pattern
```

**学习资源：**
- 📖 [Redis 官方教程](https://redis.io/docs/getting-started/)
- 🎥 [Redis Crash Course](https://www.youtube.com/results?search_query=redis+crash+course)

**预计学习时间：** 2-3 小时（如果已了解可跳过）

---

## 📅 学习路径规划

### Week 1：理论学习 + 本地实验

#### Day 1-2：K8s 工作负载学习（6-8 小时）
```
✅ StatefulSet 概念和文档阅读
✅ DaemonSet 概念和文档阅读
✅ Job/CronJob 概念和文档阅读
✅ 观看相关视频教程
```

#### Day 3-4：存储和配置学习（4-6 小时）
```
✅ PV/PVC 概念和文档阅读
✅ StorageClass 了解
✅ ConfigMap 和 Secret 学习
✅ Headless Service 理解
```

#### Day 5-7：Go + Redis 学习（4-6 小时）
```
✅ go-redis 库学习
✅ 本地安装 Redis
✅ 编写简单的 Go + Redis 示例
✅ 测试缓存功能
```

**Week 1 总结：完成所有理论学习，具备开始编码的知识基础**

---

### Week 2-3：实战开发

#### Day 8-10：API 服务改进
```
✅ 集成 Redis 客户端
✅ 实现缓存层
✅ 添加新接口
✅ 本地测试
```

#### Day 11-14：K8s 资源编写
```
✅ 编写 StatefulSet 配置（Redis）
✅ 编写 DaemonSet 配置（日志采集器）
✅ 编写 CronJob 配置（清理任务）
✅ 编写 ConfigMap 配置
```

#### Day 15-17：部署和测试
```
✅ 部署到 Minikube
✅ 功能测试
✅ 问题排查
✅ 优化调整
```

#### Day 18-21：文档和博客
```
✅ 编写部署文档
✅ 编写 FAQ
✅ 创作 4 篇博客
✅ 项目总结
```

---

## 🔧 环境准备检查

### 软件版本要求

```bash
# 1. Go 版本
go version
# 要求: go1.21 或更高

# 2. Docker 版本
docker --version
# 要求: 24.0 或更高

# 3. Kubernetes 版本
kubectl version --client
# 要求: 1.28 或更高

# 4. Minikube 版本
minikube version
# 要求: v1.31 或更高
```

### 本地 Redis 安装（用于开发测试）

**方式 1：Docker 运行（推荐）**
```bash
docker run --name redis-dev -d -p 6379:6379 redis:7-alpine
```

**方式 2：Windows 安装**
```powershell
# 使用 Chocolatey
choco install redis-64

# 或下载 Redis for Windows
# https://github.com/microsoftarchive/redis/releases
```

**验证安装：**
```bash
# 测试连接
docker exec -it redis-dev redis-cli ping
# 输出: PONG
```

---

## 📊 技能评估表

完成学习后，你应该能够回答：

### StatefulSet
- [ ] StatefulSet 和 Deployment 的主要区别是什么？
- [ ] 什么场景下应该使用 StatefulSet？
- [ ] StatefulSet 的 Pod 名称规则是什么？

### 持久化存储
- [ ] PV 和 PVC 的关系是什么？
- [ ] AccessModes 有哪些类型？
- [ ] 如何验证数据持久化生效？

### DaemonSet
- [ ] DaemonSet 的典型应用场景有哪些？
- [ ] 如何确保 DaemonSet 只部署到特定节点？

### CronJob
- [ ] Cron 表达式 `0 */2 * * *` 表示什么？
- [ ] Job 失败后如何重试？

### ConfigMap
- [ ] ConfigMap 和 Secret 的区别？
- [ ] ConfigMap 如何注入到 Pod？

如果你能回答这些问题，说明你已经准备好开始编码了！✅

---

## 🎯 准备状态自查

### 开始 v0.2 前确认：

- [ ] 我已完成 v0.1 的所有内容
- [ ] 我理解了 v0.1 的核心概念
- [ ] 我阅读了 v0.2 的学习目标
- [ ] 我理解了 v0.2 的架构设计
- [ ] 我完成了核心概念的学习（或有学习计划）
- [ ] 我的开发环境已准备好
- [ ] 我有 2-3 周的学习时间
- [ ] 我准备好迎接新挑战了！🔥

---

## 💪 学习建议

### 学习策略

1. **理论 + 实践结合**
   - 不要只看文档，一定要动手
   - 边学边做笔记
   - 遇到问题及时查阅

2. **由简到繁**
   - 先理解单个概念
   - 再组合使用
   - 最后系统集成

3. **及时总结**
   - 每天学习后写总结
   - 记录遇到的问题
   - 整理学习笔记

4. **不要畏难**
   - 新概念多是正常的
   - 学习曲线会逐渐平缓
   - 坚持就能掌握

---

## 📚 推荐资源汇总

### 官方文档
- [Kubernetes 文档（中文）](https://kubernetes.io/zh-cn/docs/)
- [Go-Redis 文档](https://redis.uptrace.dev/)
- [Redis 官方文档](https://redis.io/docs/)

### 在线课程
- [Kubernetes Basics - Killercoda](https://killercoda.com/kubernetes)
- [Kubernetes 中文社区](https://www.kubernetes.org.cn/)

### 书籍推荐
- 《Kubernetes 权威指南》
- 《Kubernetes 实战》
- 《Redis 设计与实现》

### YouTube 频道
- TechWorld with Nana
- That DevOps Guy
- KodeKloud

---

## ✅ 评估完成

如果你已经完成了这份评估，那么你已经：

✅ 了解了 v0.2 需要学习的所有核心概念  
✅ 明确了学习路径和时间规划  
✅ 准备好了开发环境  
✅ 知道了学习资源在哪里找  

**现在可以进入下一步：Architect（架构设计细化）和 Activate（开始编码）！** 🚀

---

**评估完成时间：** ________  
**评估结果：** ⬜ 需要补充学习  ⬜ 准备就绪


