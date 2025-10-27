# ========================================
# Stage 1: 构建阶段
# ========================================
FROM golang:1.21-alpine AS builder

# 安装必要的工具
RUN apk add --no-cache git

# 设置工作目录
WORKDIR /app

# 复制 go.mod 和 go.sum（利用 Docker 缓存）
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY src/ ./src/

# 编译（静态链接，减小镜像体积）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o /app/api ./src/main.go

# ========================================
# Stage 2: 运行阶段
# ========================================
FROM alpine:latest

# 安装 ca-certificates（HTTPS 请求需要）
RUN apk --no-cache add ca-certificates

# 创建非 root 用户
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/api .

# 更改所有者
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# 启动应用
ENTRYPOINT ["./api"]
