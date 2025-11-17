package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisCache Redis 缓存客户端
type RedisCache struct {
	Client *redis.Client
	Ctx    context.Context
}

// NewRedisCache 创建 Redis 缓存客户端
func NewRedisCache(addr string) (*RedisCache, error) {
	client := redis.NewClient(&redis.Options{
		Addr:         addr,
		Password:     "", // 无密码
		DB:           0,  // 默认数据库
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})

	ctx := context.Background()

	// 测试连接
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, err
	}

	return &RedisCache{
		Client: client,
		Ctx:    ctx,
	}, nil
}

// Get 获取缓存
func (r *RedisCache) Get(key string) (string, error) {
	return r.Client.Get(r.Ctx, key).Result()
}

// Set 设置缓存
func (r *RedisCache) Set(key string, value string, ttl time.Duration) error {
	return r.Client.Set(r.Ctx, key, value, ttl).Err()
}

// Del 删除缓存
func (r *RedisCache) Del(key string) error {
	return r.Client.Del(r.Ctx, key).Err()
}

// Exists 检查键是否存在
func (r *RedisCache) Exists(key string) (bool, error) {
	result, err := r.Client.Exists(r.Ctx, key).Result()
	return result > 0, err
}

// Close 关闭连接
func (r *RedisCache) Close() error {
	return r.Client.Close()
}

// Stats 获取统计信息
func (r *RedisCache) Stats() map[string]interface{} {
	stats := r.Client.PoolStats()
	return map[string]interface{}{
		"hits":        stats.Hits,
		"misses":      stats.Misses,
		"timeouts":    stats.Timeouts,
		"total_conns": stats.TotalConns,
		"idle_conns":  stats.IdleConns,
	}
}

// Ping 测试连接
func (r *RedisCache) Ping() error {
	return r.Client.Ping(r.Ctx).Err()
}
