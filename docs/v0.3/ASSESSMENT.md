# v0.3 前置知识评估

> 评估你是否准备好开始 v0.3 开发

---

## 📋 评估说明

本评估帮助你了解是否已具备开始 v0.3 开发的知识基础。

**评分标准**：
- ✅ **掌握**：能独立完成，理解原理
- ⚠️ **了解**：有印象，需要查文档
- ❌ **不会**：完全陌生，需要学习

**建议**：
- 85%+ 以上 ✅：可以直接开始
- 70-84% 混合：边学边做
- 70% 以下：建议先补充基础

---

## 🎯 Part 1: Kubernetes 基础 (30%)

### 1.1 Pod 和 Deployment

**评估问题**：

1. [ ] 我能解释 Pod 和 Deployment 的区别
2. [ ] 我知道如何查看 Pod 状态和日志
3. [ ] 我理解 replicas 的作用
4. [ ] 我能手动扩缩 Deployment 副本数

**自测命令**：
```powershell
# 你能解释这些命令的作用吗？
kubectl get pods
kubectl scale deployment my-app --replicas=5
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**参考资料**：如果不确定，复习 v0.1 和 v0.2 文档

---

### 1.2 Service 和网络

**评估问题**：

1. [ ] 我理解 Service 的作用
2. [ ] 我知道 ClusterIP、NodePort 的区别
3. [ ] 我能解释 Service 如何路由到 Pod
4. [ ] 我知道如何测试 Service 连通性

**自测场景**：
```
场景：一个 Deployment 有 3 个 Pod，Service 指向它们
问题：
1. Service 如何知道要路由到哪些 Pod？
2. 如果一个 Pod 重启，Service 会受影响吗？
3. Service 的 DNS 名称是什么格式？

答案提示：
1. 通过 selector 匹配 labels
2. 不会，Service 自动更新 Endpoints
3. <service-name>.<namespace>.svc.cluster.local
```

---

### 1.3 资源管理

**评估问题**：

1. [ ] 我理解 requests 和 limits 的区别
2. [ ] 我知道 QoS 三个等级
3. [ ] 我能为应用设置合理的资源配置
4. [ ] 我理解资源配置对调度的影响

**自测题**：
```yaml
# 这个 Pod 是什么 QoS 等级？
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"

答案：Burstable（requests ≠ limits）

# 如果要改为 Guaranteed，应该怎么配置？
答案：requests = limits
```

**✅ 如果以上 12 项你都能做到，Part 1 通过**

---

## 📊 Part 2: 弹性伸缩理论 (25%)

### 2.1 HPA 基础概念

**评估问题**：

1. [ ] 我知道 HPA 是什么，有什么用
2. [ ] 我理解 HPA 的工作原理
3. [ ] 我知道 HPA 基于什么数据做决策
4. [ ] 我理解扩容和缩容的区别

**自测题**：
```
问题 1：HPA 全称是什么？做什么用的？
答案：HorizontalPodAutoscaler，水平自动扩缩 Pod 副本数

问题 2：HPA 多久检查一次指标？
答案：默认每 15 秒

问题 3：为什么缩容比扩容慢？
答案：防止频繁抖动，默认有 5 分钟稳定期
```

---

### 2.2 Metrics Server

**评估问题**：

1. [ ] 我知道 Metrics Server 的作用
2. [ ] 我理解 Metrics API 是什么
3. [ ] 我知道如何验证 Metrics Server 是否工作
4. [ ] 我理解数据采集有延迟

**自测命令**：
```powershell
# 这个命令是查看什么的？
kubectl top nodes
# 答案：查看节点的 CPU 和内存使用情况

# 这个命令的作用？
kubectl get apiservice v1beta1.metrics.k8s.io
# 答案：检查 Metrics API 是否可用

# 如果 kubectl top 报错 "Metrics API not available"，说明什么？
# 答案：Metrics Server 未安装或未正常工作
```

---

### 2.3 扩缩容算法

**评估问题**：

1. [ ] 我理解 HPA 如何计算期望副本数
2. [ ] 我知道什么是容忍度（Tolerance）
3. [ ] 我理解目标使用率的作用
4. [ ] 我能手动计算期望副本数

**自测计算**：
```
场景：
- 当前副本数：2
- CPU requests：100m（每个 Pod）
- 当前平均 CPU 使用：150m
- 目标使用率：70%

问题：HPA 会扩缩到几个副本？

计算过程：
1. 当前使用率 = 150m / 100m = 150%
2. 比例 = 150% / 70% = 2.14
3. 期望副本 = ceil(2 × 2.14) = ceil(4.28) = 5

答案：5 个副本
```

**✅ 如果以上 12 项你都能做到，Part 2 通过**

---

## 💻 Part 3: 实践操作 (30%)

### 3.1 kubectl 命令

**评估问题**：

1. [ ] 我能查看 Deployment 状态
2. [ ] 我能查看 HPA 状态
3. [ ] 我能查看 Pod 资源使用
4. [ ] 我能查看事件日志

**实际操作测试**：
```powershell
# 尝试执行这些命令，看是否理解输出

# 1. 查看所有 Deployment
kubectl get deployment

# 2. 查看 HPA（如果有）
kubectl get hpa

# 3. 查看资源使用
kubectl top pods

# 4. 查看详细信息
kubectl describe deployment <name>

# 5. 查看事件
kubectl get events --sort-by='.lastTimestamp'
```

**能力检查**：
- [ ] 我能从输出中看出 Pod 是否正常运行
- [ ] 我能判断资源使用是否合理
- [ ] 我能从事件中找到问题线索

---

### 3.2 Docker 操作

**评估问题**：

1. [ ] 我能构建 Docker 镜像
2. [ ] 我能查看本地镜像
3. [ ] 我能运行容器测试
4. [ ] 我理解 Dockerfile 的基本结构

**实际操作测试**：
```powershell
# 1. 构建镜像
docker build -t test:v1 .

# 2. 查看镜像
docker images

# 3. 运行容器
docker run -d -p 8080:8080 test:v1

# 4. 查看日志
docker logs <container-id>

# 5. 停止容器
docker stop <container-id>
```

---

### 3.3 配置文件编辑

**评估问题**：

1. [ ] 我能理解 YAML 格式
2. [ ] 我能修改 K8s 配置文件
3. [ ] 我知道如何应用配置更改
4. [ ] 我能识别配置错误

**自测题**：
```yaml
# 下面的配置有什么问题？
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  containers:  # ❌ 错误：containers 应该在 template.spec 下
  - name: app
    image: my-app:v1
```

**能力检查**：
- [ ] 我能发现上面的错误
- [ ] 我知道正确的结构应该是什么样
- [ ] 我能独立编写简单的 K8s 配置

**✅ 如果以上 12 项你都能做到，Part 3 通过**

---

## 🛠️ Part 4: 工具使用 (15%)

### 4.1 开发工具

**评估问题**：

1. [ ] 我会使用 PowerShell 或 Bash
2. [ ] 我会使用 Git 基本命令
3. [ ] 我会使用代码编辑器（VS Code/GoLand）
4. [ ] 我会查看和搜索文档

**实际操作**：
```powershell
# PowerShell 基础
cd path/to/project          # 切换目录
ls                          # 列出文件
cat file.txt                # 查看文件内容
Select-String "pattern"     # 搜索（类似 grep）

# Git 基础
git status                  # 查看状态
git add .                   # 添加更改
git commit -m "message"     # 提交
git log                     # 查看历史
```

---

### 4.2 压测工具（k6）

**评估问题**：

1. [ ] 我听说过 k6 或类似的压测工具
2. [ ] 我知道什么是 VU（虚拟用户）
3. [ ] 我知道什么是 RPS（每秒请求数）
4. [ ] 我能理解压测报告

**概念理解**：
```javascript
// 这段配置是什么意思？
stages: [
  { duration: '1m', target: 10 },
  { duration: '2m', target: 50 },
]

答案：
- 第1分钟：从0逐步增加到10个虚拟用户
- 第2分钟：从10逐步增加到50个虚拟用户
```

**如果不会 k6，不用担心**：Phase 4 会教你使用

**✅ 如果以上 8 项至少会 6 项，Part 4 通过**

---

## 🎓 综合评估

### 计算你的准备度

```
Part 1 (Kubernetes 基础): ___ / 12 × 30% = ___
Part 2 (弹性伸缩理论):   ___ / 12 × 25% = ___
Part 3 (实践操作):       ___ / 12 × 30% = ___
Part 4 (工具使用):       ___ / 8  × 15% = ___

总分: ___ %
```

### 评估结果

**85%+ 🌟 优秀 - 直接开始**
```
✅ 你已经具备了扎实的基础
✅ 可以直接开始 v0.3 开发
✅ 遇到问题查阅文档即可
```

**70-84% ⭐ 良好 - 边学边做**
```
✅ 你的基础不错
⚠️ 有些知识需要在实践中巩固
📚 建议边做边查阅相关文档
```

**60-69% ⚠️ 一般 - 补充学习**
```
⚠️ 基础知识有缺口
📚 建议先补充以下内容：
   - 重新部署 v0.2，加深理解
   - 阅读 Kubernetes 资源管理文档
   - 学习 kubectl 常用命令
```

**< 60% ❌ 不足 - 系统学习**
```
❌ 建议先完成以下准备：
   1. 完整学习 v0.1 和 v0.2
   2. 练习 kubectl 基本操作
   3. 理解 Kubernetes 核心概念
   4. 阅读官方文档基础部分
```

---

## 📚 针对性学习建议

### 如果 Part 1 薄弱（Kubernetes 基础）

**学习资源**：
```
1. 回顾 v0.1 和 v0.2 文档
2. Kubernetes 官方教程：
   https://kubernetes.io/zh-cn/docs/tutorials/
3. 实践练习：
   - 部署一个简单应用
   - 手动扩缩副本
   - 查看 Pod 日志和状态
```

**建议时间**：3-5 天

---

### 如果 Part 2 薄弱（弹性伸缩理论）

**学习资源**：
```
1. 阅读本项目的以下文档：
   - docs/v0.3/ARCHITECTURE.md
   - Kubernetes HPA 官方文档
2. 观看视频教程（搜索 "Kubernetes HPA"）
3. 理解关键概念：
   - Metrics Server 架构
   - HPA 算法
   - 扩缩容策略
```

**建议时间**：2-3 天

---

### 如果 Part 3 薄弱（实践操作）

**练习建议**：
```
1. 每天练习 kubectl 命令：
   kubectl get/describe/logs/top
2. 练习 Docker 基本操作
3. 尝试修改 K8s 配置文件
4. 多看错误信息，学习排查
```

**建议时间**：持续练习，1-2 周

---

### 如果 Part 4 薄弱（工具使用）

**不用担心**：
```
✅ 工具使用可以边做边学
✅ v0.3 会详细教你使用 k6
✅ 命令行操作多练就会了
```

**建议**：直接开始，遇到不会的查文档

---

## 🎯 准备行动计划

### 如果你已经准备好（≥85%）

**立即开始**：
```
✅ 阅读 DEPLOYMENT-GUIDE.md
✅ 开始 Phase 1：环境准备
✅ 按照 6 个阶段逐步完成
```

---

### 如果需要补充学习（70-84%）

**1周准备计划**：
```
Day 1-2: 
  - 复习 v0.2
  - 练习 kubectl 命令
  - 理解资源管理

Day 3-4:
  - 学习 HPA 原理
  - 阅读 ARCHITECTURE.md
  - 理解 Metrics Server

Day 5:
  - 安装 Metrics Server
  - 验证环境

Day 6-7:
  - 开始 v0.3 Phase 1
  - 边学边做
```

---

### 如果基础不足（<70%）

**2-3周准备计划**：
```
Week 1: 补充基础
  - 完整学习 v0.1
  - 完整学习 v0.2
  - 练习基本操作

Week 2: 深入理解
  - Kubernetes 核心概念
  - 资源管理
  - 网络和服务

Week 3: 准备 v0.3
  - 学习 HPA 理论
  - 准备环境
  - 开始实践
```

---

## ✅ 最终检查清单

在开始 v0.3 之前，确保：

### 环境准备
- [ ] Kubernetes 集群运行正常
- [ ] kubectl 命令能正常使用
- [ ] Docker 能正常构建镜像
- [ ] 有代码编辑器（VS Code/GoLand）
- [ ] 有终端工具（PowerShell/iTerm）

### 知识准备
- [ ] 理解 Deployment 和 Pod
- [ ] 理解 resources requests/limits
- [ ] 了解 HPA 基本概念
- [ ] 知道如何查看 Pod 状态
- [ ] 知道如何查看日志

### 心理准备
- [ ] 有充足的学习时间（预计 2 周）
- [ ] 遇到问题会查文档和搜索
- [ ] 愿意多次尝试和调试
- [ ] 有耐心完成 6 个阶段

---

## 💪 鼓励的话

**无论你当前的水平如何：**

- 🌟 **高分者**：相信你的基础，大胆开始！
- ⭐ **中等者**：边学边做是最好的方式！
- ⚠️ **初学者**：不要气馁，每个人都是这样过来的！

**记住**：
```
✅ 学习是一个过程，不要急于求成
✅ 遇到困难很正常，重要的是解决它
✅ 每完成一个阶段，你都在进步
✅ 实践是最好的老师
```

---

## 📞 获取帮助

如果在评估或学习过程中遇到问题：

1. **查阅文档**：docs/v0.3/ 目录下的所有文档
2. **搜索问题**：善用 Google 和 Stack Overflow
3. **官方文档**：Kubernetes 官方中文文档
4. **社区讨论**：加入 Kubernetes 中文社区

---

**准备好了吗？让我们开始 v0.3 的云原生之旅！** 🚀

📖 **下一步**: 阅读 [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) 开始实战

