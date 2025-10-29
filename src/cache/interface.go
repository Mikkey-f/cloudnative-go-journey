package cache

import "time"

// Cache 缓存接口定义
type Cache interface {
	Get(key string) (string, error)
	Set(key string, value string, ttl time.Duration) error
	Del(key string) error
	Exists(key string) (bool, error)
	Close() error
}
