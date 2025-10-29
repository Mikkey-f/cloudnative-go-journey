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
		Password:     "", // 无密码
		DB:           0,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})
	defer func(rdb *redis.Client) {
		err := rdb.Close()
		if err != nil {
			log.Fatalln(err)
		}
	}(rdb)

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

	log.Printf("✅ 清理完成")
	log.Printf("📊 统计信息:")
	log.Printf("   - 检查的键数: %d", cleaned["checked"])
	log.Printf("   - 删除的键数: %d", cleaned["deleted"])
	log.Printf("   - 无过期时间的键数: %d", cleaned["no_ttl"])
	log.Printf("   - 执行耗时: %v", cleaned["duration"])

	log.Println("🎉 任务执行成功，退出")
}

// cleanupExpiredKeys 清理过期键
func cleanupExpiredKeys(rdb *redis.Client, ctx context.Context) (map[string]interface{}, error) {
	startTime := time.Now()
	stats := map[string]interface{}{
		"checked": 0,
		"deleted": 0,
		"no_ttl":  0,
	}

	// 清理策略1: 删除以 cache: 开头的无 TTL 的键
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

		// 如果 TTL < 0，表示键不存在或没有过期时间
		if ttl == -2 {
			// -2: 键不存在（已经过期被删除）
			deletedCount++
			log.Printf("   [已过期] %s", key)
		} else if ttl == -1 {
			// -1: 键存在但没有设置过期时间
			// 这种情况下我们设置一个默认的过期时间（1小时）
			rdb.Expire(ctx, key, 1*time.Hour)
			noTTLCount++
			log.Printf("   [设置TTL] %s (设为1小时)", key)
		} else if ttl < 60*time.Second {
			// TTL < 1分钟，可以提前删除
			rdb.Del(ctx, key)
			deletedCount++
			log.Printf("   [删除] %s (TTL: %v)", key, ttl)
		}
	}

	// 清理策略2: 删除以 temp: 开头的所有键
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
