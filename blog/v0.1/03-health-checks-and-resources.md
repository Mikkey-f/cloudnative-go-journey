# 从零开始的云原生之旅（三）：健康检查差点把我坑死

> Pod 为什么疯狂重启？资源限制怎么设置？生产环境的血泪教训

## 文章目录

- 前言
- 一、健康检查：我踩过的坑
  - 1.1 什么是健康检查？
  - 1.2 Liveness vs Readiness（傻傻分不清楚）
  - 1.3 第一次配置（Pod 疯狂重启）
  - 1.4 参数调优过程
- 二、资源限制：一个 Pod 吃光所有内存
  - 2.1 为什么需要资源限制？
  - 2.2 Requests vs Limits（有啥区别？）
  - 2.3 怎么设置合理的值？
  - 2.4 我踩过的坑
- 三、生产级配置推荐
  - 3.1 健康检查最佳实践
  - 3.2 资源限制参考值
  - 3.3 调试技巧
- 四、实战验证
  - 4.1 模拟 Pod 故障
  - 4.2 观察自动恢复
- 结语

---

## 前言

上一篇把服务部署到 K8s 后，我以为大功告成了。

**结果第二天**：

```bash
kubectl get pods

# NAME                READY   STATUS             RESTARTS   AGE
# api-server-xxx      0/1     CrashLoopBackOff   17         10m
#                             ↑ 这是啥？        ↑ 重启 17 次！
```

**CrashLoopBackOff** = 容器不断崩溃 → 重启 → 崩溃 → 重启...

我人傻了：好好的服务怎么疯狂重启？

这篇文章记录我**排查问题的完整过程**，以及学到的**健康检查和资源限制**的知识。

---

## 一、健康检查：我踩过的坑

### 1.1 什么是健康检查？

**查资料后才知道**：

```
健康检查 = Kubernetes 的"心跳检测"

K8s 会定期问你的容器：
- "你还活着吗？"（Liveness Probe）
- "你准备好接收流量了吗？"（Readiness Probe）

如果你不回答，或者回答慢了：
→ K8s 认为你有问题
→ 采取行动（重启或摘除）
```

**类比**：
```
健康检查 = 公司考勤打卡

Liveness（存活）: 
  - 每天打卡证明你还活着
  - 不打卡 → 公司认为你旷工 → 开除（重启容器）

Readiness（就绪）:
  - 打卡后还要签到"我准备好工作了"
  - 没签到 → 暂时不给你分配工作（不发送流量）
  - 准备好了再签到 → 开始分配工作
```

---

### 1.2 Liveness vs Readiness（傻傻分不清楚）

我一开始分不清这两个，后来遇到了这个场景才恍然大悟：

#### **场景：应用启动慢**

我的 Go 应用启动流程：

```
t=0s   容器启动
t=2s   Go 程序开始运行
t=5s   连接数据库中...
t=8s   数据库连接成功
t=10s  应用完全就绪
```

**如果我这样配置**（错误）：

```yaml
livenessProbe:
  httpGet:
    path: /health
  initialDelaySeconds: 5  # 5 秒后开始检查
```

**会发生什么**？

```
t=5s  K8s 第一次检查 /health
      → 应用还在连数据库
      → 返回 503 或超时
      → Liveness 失败
      
t=5s  K8s: "容器挂了，重启！"
      → Pod 重启
      
t=0s  又从头开始...
t=5s  又检查 /health
      → 又失败
      → 又重启

无限循环！！！
```

**正确的做法**：

```yaml
# Liveness: 检查进程是否活着（宽松一点）
livenessProbe:
  httpGet:
    path: /health
  initialDelaySeconds: 15  # 15 秒（大于启动时间）
  failureThreshold: 3      # 失败 3 次才重启

# Readiness: 检查是否准备好（可以严格一点）
readinessProbe:
  httpGet:
    path: /ready
  initialDelaySeconds: 5   # 5 秒就可以开始检查
  failureThreshold: 3      # 失败了就不发流量，但不重启
```

**效果**：

```
t=5s   Readiness 检查 /ready
       → 还没准备好 → 返回 503
       → K8s: "好的，我先不发流量给你"  ✅

t=10s  Readiness 再次检查
       → 准备好了 → 返回 200
       → K8s: "可以发流量了"  ✅

t=15s  Liveness 第一次检查
       → 应用已经启动好了 → 返回 200  ✅

不会重启！完美！
```

**总结**：
```
Liveness（存活）:
  - 检查：进程是否还活着
  - 失败 → 重启容器
  - 场景：应用死锁、内存泄漏

Readiness（就绪）:
  - 检查：是否准备好接收流量
  - 失败 → 从 Service 摘除（不重启）
  - 场景：启动中、临时过载
```

---

### 1.3 第一次配置（Pod 疯狂重启）

回到我的问题：为什么 Pod 重启 17 次？

**查日志**：

```bash
kubectl logs api-server-xxx --previous  # 看上一次容器的日志

# 输出：
# 🚀 Server starting on :8080...
# [然后就没了]

kubectl describe pod api-server-xxx

# Events:
#   Warning  Unhealthy  Liveness probe failed: Get "http://10.244.0.5:8080/health": 
#                        context deadline exceeded (Client.Timeout exceeded)
```

**问题找到了**：健康检查超时！

**我的配置**（第一版，有问题）：

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5   # 只等 5 秒
  timeoutSeconds: 1        # 1 秒超时
  failureThreshold: 1      # 失败 1 次就重启
```

**为什么失败**？
```
我的应用启动需要 8 秒（加载配置、连接等）
但 K8s 5 秒就开始检查了
→ 应用还没起来
→ 检查超时
→ 1 次失败就重启
→ 又从头开始
→ 5 秒后又检查
→ 又失败
→ 又重启...

死循环！
```

---

### 1.4 参数调优过程

**调优过程**（试了 3 次）：

#### **第 2 版**（还是不行）：

```yaml
livenessProbe:
  initialDelaySeconds: 8  # 改成 8 秒
  timeoutSeconds: 2
  failureThreshold: 2
```

**结果**：偶尔还是会重启（网络抖动的时候）

---

#### **第 3 版**（终于稳定了）：

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10  # 宁可多等一会
  periodSeconds: 10        # 每 10 秒检查（不用太频繁）
  timeoutSeconds: 3        # 3 秒超时（网络抖动也能容忍）
  failureThreshold: 3      # 连续失败 3 次才重启

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5         # 可以频繁一点
  timeoutSeconds: 2
  failureThreshold: 3
```

**重新部署**：

```bash
kubectl apply -f k8s/v0.1/deployment.yaml
kubectl get pods -w  # 实时观察

# NAME                READY   STATUS    RESTARTS   AGE
# api-server-xxx      0/1     Running   0          5s
# api-server-xxx      1/1     Running   0          15s  ← 稳定了！
```

**教训**：
```
宁可参数宽松，不要太严格！
- initialDelaySeconds 要大于实际启动时间
- timeoutSeconds 至少 3 秒
- failureThreshold 至少 3 次
```

---

## 二、资源限制：一个 Pod 吃光所有内存

### 2.1 为什么需要资源限制？

**真实的教训**（朋友的生产事故）：

```
场景：某个 Pod 有内存泄漏

没有资源限制：
- 这个 Pod 越吃越多内存
- 5 分钟后吃到 8GB（节点只有 8GB）
- 其他 Pod 全部 OOMKilled
- 整个节点崩溃  ❌

有资源限制：
- Pod 达到 128MB 限制
- K8s 只杀死这一个 Pod
- 其他 Pod 正常运行
- 问题隔离  ✅
```

**结论**：资源限制 = 保护整个集群！

---

### 2.2 Requests vs Limits（有啥区别？）

配置文件里有两个东西，我一开始搞不懂：

```yaml
resources:
  requests:    # 这是啥？
    memory: "64Mi"
    cpu: "100m"
  limits:      # 这又是啥？
    memory: "128Mi"
    cpu: "200m"
```

**查资料后理解了**：

#### **Requests（请求）= 保底资源**

```
含义：K8s 调度时保证给你这么多资源

场景：
节点 A 有 4GB 内存

Pod 1: requests.memory = 1GB  ✅ 调度到节点 A
Pod 2: requests.memory = 2GB  ✅ 调度到节点 A
Pod 3: requests.memory = 1.5GB  ❌ 超了！调度到节点 B

总计：1+2+1.5 = 4.5GB > 4GB

K8s: "节点 A 资源不够了，Pod 3 去节点 B"
```

**图示**：
```
节点 A (4GB 内存)
├── Pod 1: requests 1GB  ← 占用保底 1GB
├── Pod 2: requests 2GB  ← 占用保底 2GB
└── Pod 3: requests 1.5GB ❌ 放不下了！

→ Pod 3 会 Pending（等待有资源的节点）
```

---

#### **Limits（限制）= 最大资源**

```
含义：Pod 最多能用这么多

CPU Limit：
- 超过限制 → CPU 限流（throttle）
- 进程变慢，但不会被杀

Memory Limit：
- 超过限制 → 被杀死（OOMKilled）
- Pod 重启

示例：
Pod 限制 128Mi 内存
实际用了 150Mi
→ K8s: "你超了，杀！"
→ Pod 被 kill，状态变成 OOMKilled
```

**简单记忆**：
```
Requests = 最少给我这么多（调度依据）
Limits   = 最多让我用这么多（硬限制）
```

---

### 2.3 怎么设置合理的值？

**我的方法**（先跑起来，再观察）：

```bash
# 1. 先不设资源限制，部署
kubectl apply -f deployment.yaml

# 2. 启用监控
minikube addons enable metrics-server

# 3. 等 1-2 分钟，查看实际使用
kubectl top pods

# 输出：
# NAME                CPU(cores)   MEMORY(bytes)
# api-server-xxx      52m          48Mi
# api-server-yyy      51m          47Mi

# 实际使用：CPU 50m，内存 48Mi
```

**设置策略**：
```
requests = 实际使用 * 1.5-2
limits   = requests * 2-3

我的配置：
requests:
  cpu: 100m      # 50m * 2
  memory: 64Mi   # 48Mi * 1.5
limits:
  cpu: 200m      # 100m * 2
  memory: 128Mi  # 64Mi * 2
```

---

### 2.4 我踩过的坑

#### 坑 1：内存限制设太小

**我的错误尝试**：

```yaml
resources:
  limits:
    memory: "32Mi"  # 想着节省资源
```

**结果**：

```bash
kubectl get pods
# NAME                READY   STATUS      RESTARTS   AGE
# api-server-xxx      0/1     OOMKilled   5          2m

kubectl describe pod api-server-xxx
# Last State:     Terminated
#   Reason:       OOMKilled
#   Exit Code:    137  ← 137 = 被 OOM 杀死
```

**问题**：Go 程序启动就需要 40-50Mi 内存，32Mi 根本不够！

**教训**：不要为了"节省"设太小的限制，先观察实际使用！

---

#### 坑 2：只设 Limits 不设 Requests

**我的错误**：

```yaml
resources:
  limits:
    memory: "128Mi"
  # 没写 requests
```

**结果**：K8s 自动设置 `requests = limits`
```
相当于：
requests.memory: 128Mi
limits.memory:   128Mi

问题：
- 节点有 4GB 内存
- 但只能调度 4GB / 128Mi = 31 个 Pod
- 实际上每个 Pod 只用 50Mi
- 浪费了一半资源！
```

**教训**：requests 和 limits 都要设，而且 `requests < limits`！

---

#### 坑 3：健康检查等待时间太短

**我的第一版**（导致疯狂重启）：

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5   # 太短了！
  periodSeconds: 5
  timeoutSeconds: 1        # 1 秒超时太严格
  failureThreshold: 1      # 失败 1 次就重启
```

**问题**：
```
应用启动需要 8 秒
但 5 秒就开始检查
→ 应用还没起来
→ 检查失败
→ 1 次失败就重启
→ 又重启，又失败，又重启...

RESTARTS: 17  ← 就是这么来的！
```

**修复后**：

```yaml
livenessProbe:
  initialDelaySeconds: 10  # 改成 10 秒
  timeoutSeconds: 3        # 3 秒超时
  failureThreshold: 3      # 3 次失败才重启
```

**重新部署**：

```bash
kubectl apply -f deployment.yaml
kubectl get pods -w

# api-server-xxx      0/1     Running   0          5s
# api-server-xxx      1/1     Running   0          15s  ← 稳定了！不再重启！
```

**终于不重启了**！💯

---

## 三、生产级配置推荐

经过无数次调试，我总结了一套配置：

### 3.1 健康检查最佳实践

```yaml
containers:
- name: api
  image: cloudnative-go-api:v0.1
  
  # Liveness - 宽松配置
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 10   # 根据应用实际启动时间
    periodSeconds: 10         # 10 秒检查一次够了
    timeoutSeconds: 3         # 3 秒超时
    failureThreshold: 3       # 连续失败 3 次
  
  # Readiness - 可以严格一点
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5          # 更频繁检查就绪状态
    timeoutSeconds: 2
    failureThreshold: 3
```

**参数含义**：
```
initialDelaySeconds: 容器启动后等多久开始检查
periodSeconds:       多久检查一次
timeoutSeconds:      多久没响应算超时
failureThreshold:    连续失败几次才算失败
```

---

### 3.2 资源限制参考值

**不同类型应用的推荐配置**：

| 应用类型 | CPU Requests | CPU Limits | Memory Requests | Memory Limits |
|---------|-------------|-----------|----------------|--------------|
| **简单 API**（我的） | 100m | 200m | 64Mi | 128Mi |
| **计算密集**（图像处理） | 500m | 1000m | 128Mi | 256Mi |
| **内存密集**（缓存） | 100m | 200m | 256Mi | 512Mi |

**单位说明**：
```
CPU:
1     = 1 核
500m  = 0.5 核
100m  = 0.1 核

内存:
128Mi = 128 MiB = 134,217,728 字节
1Gi   = 1 GiB = 1,073,741,824 字节
```

---

### 3.3 调试技巧

#### **技巧 1：查看健康检查状态**

```bash
kubectl describe pod <pod-name> | grep -A 5 Liveness
kubectl describe pod <pod-name> | grep -A 5 Readiness

# 看是否有 "Unhealthy" 或 "failed"
```

---

#### **技巧 2：手动测试健康检查端点**

```bash
# 方法 1：port-forward
kubectl port-forward pod/<pod-name> 8080:8080
curl http://localhost:8080/health
curl http://localhost:8080/ready

# 方法 2：在 Pod 内测试
kubectl exec -it <pod-name> -- sh
wget -O- http://localhost:8080/health
```

---

#### **技巧 3：查看资源使用**

```bash
# 实时查看
kubectl top pods

# 输出：
# NAME                CPU(cores)   MEMORY(bytes)
# api-server-xxx      52m          48Mi

# 如果 CPU 或内存接近 limits，说明需要调整
```

---

## 四、实战验证

### 4.1 模拟 Pod 故障

```bash
# 手动删除一个 Pod
kubectl delete pod api-server-xxx

# 实时观察
kubectl get pods -w

# 输出：
# api-server-xxx      1/1     Terminating   0          5m   ← 正在终止
# api-server-zzz      0/1     Pending       0          0s   ← 新 Pod 创建
# api-server-zzz      0/1     ContainerCreating  0     2s
# api-server-zzz      1/1     Running            0     10s  ← 自动恢复！
```

**此时服务依然可以访问**（因为还有另一个 Pod）：

```bash
# 测试
curl http://localhost:8080/health
# 正常返回  ✅

# 说明：单个 Pod 故障不影响服务！
```

---

### 4.2 观察自动恢复

**模拟应用崩溃**（在 Pod 内杀死进程）：

```bash
# 进入 Pod
kubectl exec -it api-server-xxx -- sh

# 杀死进程
kill 1  # PID 1 是主进程

# 退出 Pod
exit

# 观察
kubectl get pods

# NAME                READY   STATUS    RESTARTS   AGE
# api-server-xxx      1/1     Running   1          5m
#                                       ↑ RESTARTS 加 1，自动重启了！
```

**K8s 检测到进程退出 → Liveness 失败 → 自动重启 ✅**

---

## 结语

经过这轮折腾，我深刻理解了：

**健康检查**：
- Liveness 和 Readiness 不一样，别搞混
- 参数宁可宽松，不要太严格
- initialDelaySeconds 要大于启动时间
- failureThreshold 至少 3

**资源限制**：
- 必须设置（保护集群）
- 先观察实际使用，再设置
- requests < limits
- 不要设太小（会 OOMKilled）

**调试技巧**：
- kubectl describe 看 Events
- kubectl logs 看日志
- kubectl logs --previous 看上一次的日志
- kubectl top 看资源使用

**思维转变**：
```
Docker 思维：
- 我的容器，我说了算

K8s 思维：
- 多租户环境，要考虑他人
- 资源限制是必须的
- 健康检查是必须的
- 应用要有自愈能力
```

至此，v0.1 基础版全部完成！从 Go 代码到 Docker 镜像，再到 K8s 部署，完整的云原生之旅第一站圆满结束。

下一步我会学习：
- v0.2：StatefulSet（有状态应用）
- DaemonSet（每个节点一个）
- ConfigMap（配置管理）

敬请期待！

---

**本文完整代码**：https://github.com/yourname/cloudnative-go-journey

今天的分享到这里就结束啦！如果觉得文章对你有帮助，可以：
- ⭐ 给项目点个 Star
- 💬 评论区聊聊你踩过的坑
- 📤 分享给正在学 K8s 的朋友

**你遇到过 CrashLoopBackOff 吗？怎么排查的？欢迎评论！**

---

**作者**：一个被健康检查坑过的学习者  
**日期**：2025-10-27  
**系列**：CloudNative Go Journey v0.1

上一篇：[《从零开始的云原生之旅（二）：第一次部署到 K8s》](02-kubernetes-deployment.md)  
下一篇：v0.2 编排升级版（规划中）
