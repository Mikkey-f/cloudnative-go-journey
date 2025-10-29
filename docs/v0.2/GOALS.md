# v0.2 学习目标和交付标准

> CloudNative Go Journey v0.2 - 编排升级版

---

## 📋 版本概述

**版本名称**：v0.2 - 编排升级版（Orchestration Upgrade）  
**预计时间**：2-3 周（业余时间，每周 10-15 小时）  
**前置要求**：完成 v0.1  
**难度等级**：⭐⭐⭐ 中级

---

## 🎯 学习目标

### 核心目标

通过 v0.2 版本，你将掌握：

1. **理解 Kubernetes 多种工作负载类型**
   - Deployment vs StatefulSet vs DaemonSet vs Job/CronJob
   - 每种类型的适用场景
   - 如何选择合适的工作负载类型

2. **掌握 StatefulSet 的使用**
   - 有状态应用的特点
   - 持久化存储（PVC/PV）
   - Headless Service
   - 稳定的网络标识

3. **理解 DaemonSet 的应用场景**
   - 每个节点运行一个 Pod
   - 日志采集、监控等场景
   - 节点选择器

4. **学会使用 ConfigMap 和 Secret**
   - 配置与代码分离
   - 环境变量注入
   - 文件挂载
   - 敏感信息管理

5. **掌握 Job 和 CronJob**
   - 批处理任务
   - 定时任务
   - 任务重试和失败处理

---

## 🛠️ 新增服务

### 1. API 服务（改进）

**基于 v0.1 改进：**
- ✅ 添加 Redis 缓存集成
- ✅ 添加配置文件支持（ConfigMap）
- ✅ 添加更多业务接口
- ✅ 添加缓存命中率监控

**新增接口：**
```
GET  /api/v1/cache/test     - 测试 Redis 缓存
GET  /api/v1/config         - 查看当前配置
POST /api/v1/data           - 写入数据
GET  /api/v1/data/:key      - 读取数据（带缓存）
```

### 2. Redis（StatefulSet）

**功能：**
- ✅ 单机 Redis 部署
- ✅ 持久化存储（PVC）
- ✅ Headless Service
- ✅ 配置文件挂载

**K8s 资源：**
- StatefulSet（1 副本）
- Service（Headless）
- PersistentVolumeClaim
- ConfigMap（Redis 配置）

### 3. 日志采集器（DaemonSet）

**功能：**
- ✅ 轻量级 Go 实现
- ✅ 收集节点日志
- ✅ 输出到标准输出（模拟）
- ✅ 每个节点部署一个

**技术细节：**
- 读取宿主机日志路径
- 简单的日志解析
- Prometheus 指标暴露

### 4. 数据清理任务（CronJob）

**功能：**
- ✅ 定时清理 Redis 过期数据
- ✅ 每小时执行一次
- ✅ 任务执行日志
- ✅ 失败重试

**K8s 配置：**
- CronJob 定时配置
- Job 历史保留
- 资源限制

---

## 📊 架构演进

### v0.1 架构（当前）

```
┌─────────────────┐
│  Minikube       │
│  ┌───────────┐  │
│  │ API Pod 1 │  │
│  │ API Pod 2 │  │
│  └───────────┘  │
│       ↑         │
│  ┌───────────┐  │
│  │  Service  │  │
│  └───────────┘  │
└─────────────────┘
```

### v0.2 架构（目标）

```
┌──────────────────────────────────────────┐
│  Minikube 集群                            │
│                                          │
│  ┌─────────────┐     ┌───────────────┐  │
│  │ API Pod 1   │────▶│ Redis Pod     │  │
│  │ API Pod 2   │     │ (StatefulSet) │  │
│  └─────────────┘     └───────────────┘  │
│         ↑                     ↑          │
│  ┌─────────────┐     ┌───────────────┐  │
│  │ API Service │     │ Redis Service │  │
│  │ (NodePort)  │     │ (Headless)    │  │
│  └─────────────┘     └───────────────┘  │
│                              ↑           │
│                     ┌────────────────┐   │
│                     │ PVC (持久化)   │   │
│                     └────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ 每个 Node 上的 DaemonSet        │   │
│  │  ┌───────────────────────────┐  │   │
│  │  │ Log Collector Pod         │  │   │
│  │  └───────────────────────────┘  │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ CronJob（定时执行）              │   │
│  │  ┌───────────────────────────┐  │   │
│  │  │ Cleanup Job (每小时)      │  │   │
│  │  └───────────────────────────┘  │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

---

## 📂 K8s 配置结构

```
k8s/v0.2/
├── api/
│   ├── deployment.yaml       # API Deployment
│   ├── service.yaml          # API Service
│   └── configmap.yaml        # 新增：配置文件
│
├── redis/
│   ├── statefulset.yaml      # 新增：StatefulSet
│   ├── service.yaml          # Headless Service
│   ├── pvc.yaml              # 持久化卷声明
│   └── configmap.yaml        # Redis 配置
│
├── log-collector/
│   └── daemonset.yaml        # 新增：DaemonSet
│
├── cleanup-job/
│   └── cronjob.yaml          # 新增：CronJob
│
└── README.md                 # 部署指南
```

---

## 📝 代码结构变化

### 新增代码

```
src/
├── cache/                    # 新增：缓存层
│   ├── redis.go             # Redis 客户端
│   └── cache.go             # 缓存接口
│
├── log-collector/           # 新增：日志采集器
│   └── main.go
│
├── cleanup-job/             # 新增：清理任务
│   └── main.go
│
└── handler/
    ├── cache.go             # 新增：缓存接口处理
    └── data.go              # 新增：数据接口处理
```

---

## ✅ 交付标准

### 功能验收

#### 1. API 服务
- [ ] 能连接到 Redis
- [ ] 缓存读写正常
- [ ] 配置文件正确加载（ConfigMap）
- [ ] 新接口正常工作

#### 2. Redis
- [ ] StatefulSet 正常部署
- [ ] 数据持久化生效（重启后数据不丢失）
- [ ] Headless Service 能正确解析
- [ ] API 服务能连接 Redis

#### 3. 日志采集器
- [ ] DaemonSet 在所有节点部署
- [ ] 能读取节点信息
- [ ] 日志输出正常
- [ ] Prometheus 指标暴露

#### 4. 清理任务
- [ ] CronJob 定时执行
- [ ] 任务执行成功
- [ ] 日志记录完整
- [ ] 失败能自动重试

### 技术验收

- [ ] 所有 Pod 都处于 Running 状态
- [ ] 资源限制配置合理
- [ ] 健康检查配置正确
- [ ] 日志输出清晰
- [ ] Prometheus 指标完整

### 文档验收

- [ ] 完整的部署文档
- [ ] 详细的架构说明
- [ ] 故障排查指南
- [ ] 配套博客（3-4 篇）

---

## 📚 配套博客计划

### 博客 4：K8s 工作负载完全指南

**内容：**
- Deployment vs StatefulSet vs DaemonSet vs Job
- 每种类型的适用场景
- 如何选择合适的工作负载

### 博客 5：实战 - 用 StatefulSet 部署 Redis

**内容：**
- StatefulSet 详解
- 持久化存储配置
- Headless Service 原理
- Redis 部署实战

### 博客 6：DaemonSet 实战 - 日志采集器

**内容：**
- DaemonSet 原理
- Go 实现日志采集器
- 节点亲和性配置

### 博客 7：ConfigMap 和 Secret 最佳实践

**内容：**
- 配置管理进阶
- ConfigMap vs Secret
- 配置更新策略
- 最佳实践

---

## 🎓 学习检查清单

### 理论知识

- [ ] 理解 StatefulSet 和 Deployment 的区别
- [ ] 理解持久化存储（PV/PVC）的概念
- [ ] 理解 Headless Service 的作用
- [ ] 理解 DaemonSet 的调度机制
- [ ] 理解 Job 和 CronJob 的区别
- [ ] 理解 ConfigMap 和 Secret 的用途

### 实践技能

- [ ] 能编写 StatefulSet 配置
- [ ] 能配置持久化存储
- [ ] 能编写 DaemonSet 配置
- [ ] 能编写 CronJob 配置
- [ ] 能使用 ConfigMap 管理配置
- [ ] 能在 Go 中集成 Redis

### 调试能力

- [ ] 能排查 StatefulSet 部署问题
- [ ] 能查看持久化卷状态
- [ ] 能查看 Job 执行日志
- [ ] 能验证 ConfigMap 挂载

---

## 📊 知识覆盖评估

| 知识点 | v0.1 | v0.2 | 提升 |
|--------|------|------|------|
| K8s 工作负载 | 20% | 80% | +60% ⬆️ |
| 持久化存储 | 0% | 60% | +60% ⬆️ |
| 配置管理 | 20% | 70% | +50% ⬆️ |
| 定时任务 | 0% | 80% | +80% ⬆️ |
| 服务发现 | 30% | 50% | +20% ⬆️ |

**总体云原生能力：30% → 60%**

---

## ⏱️ 时间规划

### Week 1：理论学习 + 环境准备

**Day 1-2：理论学习**
- 学习 StatefulSet 概念
- 学习 DaemonSet 概念
- 学习 PV/PVC 概念
- 学习 ConfigMap/Secret

**Day 3-4：环境准备**
- 搭建本地 Redis 测试
- Go Redis 客户端集成
- 配置文件管理

**Day 5-7：API 改进**
- 添加 Redis 缓存层
- 新增业务接口
- 配置文件支持

### Week 2：K8s 配置 + 部署

**Day 8-10：Redis StatefulSet**
- 编写 StatefulSet 配置
- 配置持久化存储
- 部署和验证

**Day 11-12：DaemonSet 和 CronJob**
- 开发日志采集器
- 开发清理任务
- 编写 K8s 配置

**Day 13-14：集成测试**
- 完整部署测试
- 功能验证
- 性能测试

### Week 3：文档 + 博客

**Day 15-17：文档编写**
- 部署文档
- 架构文档
- FAQ 和故障排查

**Day 18-21：博客创作**
- 编写 4 篇配套博客
- 代码示例整理
- 项目总结

---

## 🚀 开始之前

### 前置检查

```bash
# 1. 确认 v0.1 完成
kubectl get all -n default

# 2. 确认环境正常
minikube status

# 3. 清理 v0.1（可选）
kubectl delete -f k8s/v0.1/

# 4. 检查存储支持
kubectl get storageclass
```

### 推荐学习资源

1. **StatefulSet 官方文档**
   - https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

2. **PV/PVC 官方文档**
   - https://kubernetes.io/docs/concepts/storage/persistent-volumes/

3. **DaemonSet 官方文档**
   - https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/

4. **ConfigMap 官方文档**
   - https://kubernetes.io/docs/concepts/configuration/configmap/

5. **Go Redis Client**
   - https://github.com/go-redis/redis

---

## 🎯 成功标准

完成 v0.2 后，你将能够：

✅ 独立部署有状态应用（Redis）  
✅ 理解和使用持久化存储  
✅ 使用多种 K8s 工作负载类型  
✅ 管理配置文件和敏感信息  
✅ 部署定时任务  
✅ 理解服务发现和网络  

**恭喜！你已经是一名合格的 K8s 应用开发者了！** 🎉

---

**准备好了吗？让我们开始 v0.2 的开发吧！** 🚀


