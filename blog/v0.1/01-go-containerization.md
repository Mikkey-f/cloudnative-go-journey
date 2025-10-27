
# 从零开始的云原生之旅（一）：把 Go 应用塞进 Docker

> 第一次容器化 Go 应用的完整记录 | 包含所有踩过的坑

## 文章目录

- 前言
- 一、为什么要容器化？
  - 1.1 我遇到的痛点
  - 1.2 容器化解决了什么
- 二、构建第一个 Go 微服务
  - 2.1 项目结构设计
  - 2.2 实现健康检查（给 K8s 用的）
  - 2.3 优雅关闭（避免请求丢失）
  - 2.4 Prometheus 监控（留个口子）
- 三、编写 Dockerfile
  - 3.1 第一版：直接构建（800MB 的怪物）
  - 3.2 第二版：多阶段构建（瘦身到 49.1MB）
  - 3.3 踩坑记录
- 四、构建和测试
  - 4.1 本地运行测试
  - 4.2 Docker 构建
  - 4.3 容器运行验证
- 五、优化技巧总结
- 结语

---

## 前言

大家好，我是一个正在学习云原生的 Go 开发者。

**我的背景**：
- 会写 Go 代码（做过几个小项目）
- 知道 Docker 是啥（用过 `docker run`、`docker ps` 这些命令）
- Kubernetes？听说过，但没用过

最近想系统学习云原生，决定从零开始做一个完整的项目。这篇文章记录我**第一次容器化 Go 应用**的完整过程，包括：
- 我怎么写的代码
- 我怎么优化镜像的（从 800MB 到 49.1MB）
- **我踩过的所有坑**（重点！）

如果你也是 Go 开发者，想学习容器化，这篇文章应该能帮到你。

---

## 一、为什么要容器化？

### 1.1 我遇到的痛点

之前我部署 Go 应用是这样的：

```
1. 在开发机器上：go build
2. scp 上传到服务器
3. ssh 登录服务器
4. 启动：nohup ./app &
5. 祈祷不要出问题...
```

**问题来了**：
```
❌ 开发环境能跑，服务器跑不起来（glibc 版本不一样）
❌ 换台服务器要重新配置环境
❌ 进程挂了，要手动重启
❌ 多个服务端口冲突
❌ 回滚？删除重新上传...
```

**简单说**：太麻烦了，还容易出错。

### 1.2 容器化解决了什么

听说 Docker 可以解决这些问题，我决定试试：

```
容器化后：
✅ 镜像包含所有依赖（环境一致）
✅ 一次构建，到处运行
✅ 容器挂了自动重启（配合 K8s）
✅ 版本管理简单（镜像 tag）
✅ 回滚？切换镜像版本就行
```

好，决定了，开始搞！

---

## 二、构建第一个 Go 微服务

### 2.1 项目结构设计

参考了几个开源项目，我设计了这样的结构：

```
cloudnative-go-journey/
├── src/
│   ├── main.go              # 入口文件
│   ├── config/              # 配置管理
│   │   └── config.go
│   ├── handler/             # 路由处理
│   │   ├── health.go        # 健康检查（K8s 会用到）
│   │   └── hello.go         # 业务接口
│   ├── middleware/          # 中间件
│   │   ├── logger.go        # 日志
│   │   └── metrics.go       # 监控指标收集
│   └── metrics/
│       └── prometheus.go    # Prometheus 配置
├── Dockerfile               # 重点！
└── go.mod
```

**为什么这么设计**？
- 按功能分包，后面代码多了好维护
- 把健康检查单独出来，K8s 要用
- Prometheus 监控，提前准备好

---

### 2.2 实现健康检查（给 K8s 用的）

这是我第一次听说"健康检查"这个概念。简单理解：

```
健康检查 = K8s 定期问你："服务还活着吗？"
你的程序要回答："活着！"（返回 200 OK）

如果你不回答，或者回答太慢：
→ K8s 认为你挂了
→ 重启你的容器
```

**代码实现** (`handler/health.go`)：

```go
package handler

import (
    "net/http"
    "time"
    "github.com/gin-gonic/gin"
)

var startTime = time.Now()

// HealthCheck - 告诉 K8s："我还活着"
func HealthCheck(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
        "status": "healthy",
        "uptime": time.Since(startTime).String(),
    })
}

// ReadinessCheck - 告诉 K8s："我准备好接收流量了"
func ReadinessCheck(c *gin.Context) {
    // 这里可以检查数据库连接、Redis 连接等
    // 如果依赖服务没准备好，返回 503
    c.JSON(http.StatusOK, gin.H{
        "status": "ready",
    })
}
```

**注册路由** (`main.go`)：

```go
router.GET("/health", handler.HealthCheck)
router.GET("/ready", handler.ReadinessCheck)
```

**测试一下**：
```bash
go run src/main.go

# 另开终端
curl http://localhost:8080/health
# 输出: {"status":"healthy","uptime":"5s"}
```

✅ 可以！

---

### 2.3 优雅关闭（避免请求丢失）

这个概念我一开始也不懂。后来查资料才明白：

```
没有优雅关闭：
Ctrl+C → 程序立即退出 → 正在处理的请求全部失败 ❌

有优雅关闭：
Ctrl+C → 停止接收新请求 → 等待现有请求完成 → 退出 ✅
```

**在 K8s 环境特别重要**：
```
K8s 滚动更新流程：
1. 启动新版本 Pod
2. 给旧版本发 SIGTERM 信号（让它退出）
3. 等待 30 秒
4. 如果还没退，强制 kill（SIGKILL）

如果你没有优雅关闭：
→ 收到 SIGTERM，程序直接退出
→ 正在处理的请求全部失败
→ 用户收到 502 错误 ❌
```

**代码实现** (`main.go` 核心部分)：

```go
func main() {
    // 创建 HTTP 服务器
    srv := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }

    // 用 goroutine 启动服务器（不阻塞）
    go func() {
        log.Println("🚀 Server starting on :8080...")
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            log.Fatalf("Server failed: %v", err)
        }
    }()

    // 优雅关闭的核心代码
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit  // 阻塞在这里，等待信号

    log.Println("🛑 Shutting down...")

    // 给 5 秒时间处理完现有请求
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatalf("Shutdown failed: %v", err)
    }

    log.Println("✅ Server exited cleanly")
}
```

**测试一下**：
```bash
go run src/main.go
# 等一会
# 按 Ctrl+C

# 输出：
# 🛑 Shutting down...
# ✅ Server exited cleanly
```

✅ 优雅退出成功！

---

### 2.4 Prometheus 监控（留个口子）

虽然现在不用监控，但提前加上：

```go
// metrics/prometheus.go
var (
    // 请求计数器
    RequestCounter = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "api_requests_total",
            Help: "Total API requests",
        },
        []string{"method", "endpoint", "status"},
    )
)

// middleware/metrics.go  
func Metrics() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()  // 处理请求
        
        // 记录耗时和状态
        duration := time.Since(start).Seconds()
        status := strconv.Itoa(c.Writer.Status())
        RequestCounter.WithLabelValues(c.Request.Method, c.Request.URL.Path, status).Inc()
    }
}
```

访问 `/metrics` 可以看到统计数据：
```
api_requests_total{method="GET",endpoint="/health",status="200"} 5
```

---

## 三、编写 Dockerfile

### 3.1 第一版：直接构建（800MB 的怪物）

我的第一版 Dockerfile（错误示范）：

```dockerfile
FROM golang:1.21

WORKDIR /app
COPY . .
RUN go build -o api ./src/main.go

EXPOSE 8080
CMD ["./api"]
```

**构建并查看大小**：
```bash
docker build -t my-api:v1 .
docker images my-api:v1

# REPOSITORY   TAG    SIZE
# my-api       v1     842MB  ← 卧槽，800 多 MB！
```

**问题**：
```
golang:1.21 基础镜像 = 800MB+
你的程序 = 10MB
总计 = 810MB

而且：
- 包含了完整的 Go 编译环境（根本用不到）
- 包含了 git、gcc 等工具（也用不到）
```

这要是部署到生产，网络传输得多久？不行，得优化！

---

### 3.2 第二版：多阶段构建（瘦身到 49MB）

查了资料，发现 Docker 有个"多阶段构建"的技巧：

```
思路：
阶段 1：用完整的 Go 环境编译代码 → 生成二进制文件
阶段 2：用最小的镜像 + 二进制文件 → 最终镜像

就像：
编译 → 工厂（需要各种工具）
运行 → 家里（只需要成品）
```

**优化后的 Dockerfile**：

```dockerfile
# ==================== 阶段 1：编译阶段 ====================
FROM golang:1.21-alpine AS builder
# alpine 版本只有 150MB，比标准版小多了

WORKDIR /app

# 先复制依赖文件（技巧：利用 Docker 缓存）
COPY go.mod go.sum ./
RUN go mod download

# 再复制源代码
COPY src/ ./src/

# 编译（重点在这些参数）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o /app/api ./src/main.go

# ==================== 阶段 2：运行阶段 ====================
FROM alpine:latest
# alpine 只有 5MB！

# 安装 CA 证书（HTTPS 需要）
RUN apk --no-cache add ca-certificates

# 创建普通用户（安全最佳实践：不用 root）
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# 关键：只复制二进制文件，不要其他东西
COPY --from=builder /app/api .

# 给文件设置所有者
RUN chown -R appuser:appuser /app

# 切换到普通用户运行（不用 root）
USER appuser

EXPOSE 8080
ENTRYPOINT ["./api"]
```

**再次构建**：
```bash
docker build -t my-api:v2 .
docker images my-api:v2

# REPOSITORY   TAG    SIZE
# my-api       v2     49.1MB  ← 成功！从 842MB → 49.1MB
```

**效果对比**：
```
第一版：842MB
第二版：49.1MB
```

---

### 3.3 踩坑记录

#### 坑 1：忘记设置 CGO_ENABLED=0

**我的错误**：
```dockerfile
RUN go build -o /app/api ./src/main.go
```

**构建成功，但运行时报错**：
```bash
docker run my-api:v2

# 错误：
standard_init_linux.go:228: exec user process caused: no such file or directory
```

**懵了**：文件明明存在啊，为什么说找不到？

**查了半天才知道**：
```
原因：
- 默认 CGO_ENABLED=1，编译出的二进制依赖 glibc（GNU C 库）
- alpine 用的是 musl libc（轻量级 C 库）
- 两个不兼容！
- 虽然二进制文件存在，但依赖库找不到

解决：
CGO_ENABLED=0  ← 完全静态编译，不依赖任何库
```

**验证是否静态编译**：
```bash
docker run -it --entrypoint sh my-api:v2
ldd /app/api

# 输出：
# not a dynamic executable  ← 说明是静态编译，OK!
```

**教训**：alpine 镜像必须用 `CGO_ENABLED=0`！

---

#### 坑 2：端口被占用

**现象**：
```bash
go run src/main.go

# 报错：
Failed to start server: listen tcp :8080: bind: Only one usage of each socket address...
```

**原因**：我之前运行的进程没关，还占着 8080 端口。

**解决（Windows）**：
```powershell
# 查找谁占用了 8080
netstat -ano | findstr :8080

# 输出：
# TCP    0.0.0.0:8080    0.0.0.0:0    LISTENING    12345
#                                                    ↑ PID

# 杀死进程
taskkill /F /PID 12345
```

**教训**：跑新程序前，先检查端口！

---

#### 坑 3：Docker 缓存让我怀疑人生

**场景**：
```
1. 我修改了 main.go 的代码
2. docker build -t my-api:v2 .
3. docker run my-api:v2
4. 运行的还是旧代码！！！
```

**为什么**？Docker 的分层缓存机制：
```
Dockerfile:
COPY . .           ← 复制所有文件
RUN go build       ← 编译

如果文件内容没变 → 使用缓存层 → 不重新编译 → 运行旧代码
```

**解决方法 1**：强制重新构建
```bash
docker build --no-cache -t my-api:v2 .
```

**解决方法 2**：优化 Dockerfile（推荐）
```dockerfile
# 先复制依赖文件（很少变）
COPY go.mod go.sum ./
RUN go mod download      ← 这一层会被缓存

# 再复制源代码（经常变）
COPY src/ ./src/
RUN go build             ← 只有这一层重新构建

# 好处：依赖没变时，只重新编译代码，快 10 倍！
```

**教训**：理解 Docker 缓存机制，合理安排 COPY 顺序！

---

#### 坑 4：-ldflags="-w -s" 是啥？

查资料时看到这个参数，试了一下：

```bash
# 不加参数
go build -o api1 ./src/main.go
ls -lh api1
# -rwxr-xr-x  1 user  staff   20M  api1  ← 20MB

# 加参数
go build -ldflags="-w -s" -o api2 ./src/main.go
ls -lh api2
```

**什么原理**？
```
-w: 去掉 DWARF 调试信息
-s: 去掉符号表

简单说：去掉调试用的东西，程序小了，但不能 debug 了

生产环境：用 -w -s（不需要 debug）
开发环境：不用（方便 debug）
```

**效果**：减小 65% 的体积！

---

## 四、构建和测试

### 4.1 本地运行测试

```bash
# 先确保代码能跑
go run src/main.go

# 测试接口（另开终端）
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/hello?name=Docker

# 看到返回就 OK
```

---

### 4.2 Docker 构建

```bash
# 构建镜像
docker build -t cloudnative-go-api:v0.1 .

# 观察构建过程
[+] Building 45.2s (15/15) FINISHED
 => [builder 1/6] FROM golang:1.21-alpine      # 阶段 1
 => [builder 4/6] RUN go mod download
 => [builder 6/6] RUN CGO_ENABLED=0 go build...
 => [stage-1 2/4] RUN apk add ca-certificates  # 阶段 2  
 => [stage-1 4/4] COPY --from=builder /app/api .
 => exporting to image
 => => writing image sha256:abc123...
```

**看到 2 个阶段**：
- `[builder ...]` - 编译阶段（用完就扔）
- `[stage-1 ...]` - 运行阶段（最终镜像）

---

### 4.3 容器运行验证

```bash
# 运行容器
docker run -d -p 8080:8080 --name api-test cloudnative-go-api:v0.1

# 等 2 秒让容器启动
sleep 2

# 测试
curl http://localhost:8080/health
# 输出: {"status":"healthy","uptime":"2s"}

curl http://localhost:8080/api/v1/hello
# 输出: {"message":"Hello, CloudNative!",...}

# 查看日志
docker logs api-test
# 看到：
# 🚀 Server starting on :8080...
# [GET] /health 172.17.0.1 | Status: 200 | Latency: 500µs

# 停止并删除测试容器
docker stop api-test
docker rm api-test
```

✅ 所有测试通过！

---

## 五、优化技巧总结

经过这次实践，我总结了几个关键点：

### 1. 多阶段构建是必须的

```
单阶段：842MB  ❌
多阶段：49.1MB   ✅

节省 98% 空间！
```

### 2. CGO_ENABLED=0 很重要

```
alpine 镜像必须用静态编译
否则运行时找不到 glibc
```

### 3. 先复制 go.mod，后复制代码

```dockerfile
# 好的顺序：
COPY go.mod go.sum ./
RUN go mod download        ← 依赖层（缓存）
COPY src/ ./src/
RUN go build               ← 代码层（经常变）

# 坏的顺序：
COPY . .                   ← 全部复制
RUN go mod download        ← 每次都重新下载依赖
RUN go build

修改代码时：
好的顺序 → 只重新编译，快 10 倍
坏的顺序 → 重新下载依赖 + 编译，很慢
```


### 4. 用 appuser 而不是 root

```
root 运行 → 容器被攻破 = 拿到 root 权限 ❌
普通用户 → 容器被攻破 = 只有普通权限 ✅

安全第一！
```

---

## 结语

第一次容器化 Go 应用，踩了不少坑，但收获很大：

**技术收获**：
- ✅ 学会了多阶段构建
- ✅ 理解了静态编译的重要性
- ✅ 掌握了 Docker 缓存优化
- ✅ 实现了优雅关闭

**思维转变**：
```
之前：写完代码就完事
现在：要考虑容器化、监控、健康检查...

云原生 = 不只是写代码，还要考虑运维！
```

下一篇我会分享**如何把这个容器部署到 Kubernetes**，会遇到更多有趣的坑：
- 镜像怎么加载到 Minikube？
- Pod 一直 ImagePullBackOff 怎么办？
- 负载均衡为什么看不到效果？

敬请期待！

---

**本文完整代码**：[我的仓库](https://github.com/Mikkey-f/cloudnative-go-journey)

今天的分享到这里就结束啦！如果觉得文章对你有帮助，欢迎：
- ⭐ 给项目点个 Star
- 💬 评论区聊聊你踩过的坑
- 📤 分享给正在学云原生的朋友

你在容器化时遇到过什么问题？欢迎评论区讨论！

---

**作者**：Mikkeyf
**日期**：2025-10-27  
**系列**：CloudNative Go Journey v0.1

下一篇：[《从零开始的云原生之旅（二）：第一次部署到 K8s》](02-kubernetes-deployment.md)
