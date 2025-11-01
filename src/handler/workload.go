package handler

import (
	"fmt"
	"math"
	"runtime"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// WorkloadHandler 综合负载接口
// 支持 CPU、内存、混合负载测试
func WorkloadHandler(c *gin.Context) {
	workloadType := c.DefaultQuery("type", "cpu")
	intensity := getIntParam(c, "intensity", 50)

	startTime := time.Now()
	var result interface{}

	switch workloadType {
	case "cpu":
		result = cpuWorkload(intensity)
	case "memory":
		result = memoryWorkload(intensity)
	case "mixed":
		cpuResult := cpuWorkload(intensity / 2)
		memResult := memoryWorkload(intensity / 2)
		result = gin.H{
			"cpu":    cpuResult,
			"memory": memResult,
		}
	default:
		c.JSON(400, gin.H{"error": "Invalid workload type. Use: cpu, memory, or mixed"})
		return
	}

	duration := time.Since(startTime)

	c.JSON(200, gin.H{
		"workload_type": workloadType,
		"intensity":     intensity,
		"duration_ms":   duration.Milliseconds(),
		"result":        result,
		"message":       "Workload completed successfully",
		"timestamp":     time.Now().Unix(),
	})
}

// CPUIntensiveHandler CPU 密集型接口
// 通过数学计算消耗 CPU 资源
func CPUIntensiveHandler(c *gin.Context) {
	iterations := getIntParam(c, "iterations", 10000000)

	startTime := time.Now()
	result := cpuWorkload(iterations / 1000000)
	duration := time.Since(startTime)

	// 获取当前 Goroutine 数量
	numGoroutines := runtime.NumGoroutine()

	c.JSON(200, gin.H{
		"result":      result,
		"iterations":  iterations,
		"duration_ms": duration.Milliseconds(),
		"goroutines":  numGoroutines,
		"cpu_cores":   runtime.NumCPU(),
		"message":     "CPU intensive task completed",
	})
}

// MemoryIntensiveHandler 内存密集型接口
// 分配并持有大量内存
func MemoryIntensiveHandler(c *gin.Context) {
	sizeMB := getIntParam(c, "size", 50)
	durationSec := getIntParam(c, "duration", 3)

	// 限制最大内存分配（防止 OOM）
	if sizeMB > 200 {
		c.JSON(400, gin.H{
			"error":   "Size too large",
			"max_mb":  200,
			"message": "请求的内存大小超过限制",
		})
		return
	}

	startTime := time.Now()

	// 分配内存
	data := make([]byte, sizeMB*1024*1024)

	// 填充数据（防止编译器优化掉）
	for i := range data {
		data[i] = byte(i % 256)
	}

	// 持有内存一段时间
	time.Sleep(time.Duration(durationSec) * time.Second)

	elapsed := time.Since(startTime)

	// 获取内存统计
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	c.JSON(200, gin.H{
		"allocated_mb": sizeMB,
		"duration_sec": durationSec,
		"actual_ms":    elapsed.Milliseconds(),
		"data_sample":  fmt.Sprintf("%v", data[:10]),
		"memory_stats": gin.H{
			"alloc_mb":       m.Alloc / 1024 / 1024,
			"total_alloc_mb": m.TotalAlloc / 1024 / 1024,
			"sys_mb":         m.Sys / 1024 / 1024,
			"num_gc":         m.NumGC,
		},
		"message": "Memory intensive task completed",
	})
}

// cpuWorkload 执行 CPU 密集型计算
func cpuWorkload(intensity int) float64 {
	result := 0.0
	iterations := intensity * 1000000

	for i := 0; i < iterations; i++ {
		// 多种数学运算增加 CPU 负载
		result += math.Sqrt(float64(i))
		result += math.Sin(float64(i))
		result += math.Cos(float64(i))
		result += math.Tan(float64(i))

		// 每 10000 次迭代做一次更复杂的计算
		if i%10000 == 0 {
			result += math.Pow(float64(i), 2)
			result += math.Log(float64(i + 1))
		}
	}

	return result
}

// memoryWorkload 执行内存密集型操作
func memoryWorkload(sizeMB int) int {
	// 限制最大分配
	if sizeMB > 200 {
		sizeMB = 200
	}

	data := make([][]byte, sizeMB)

	for i := 0; i < sizeMB; i++ {
		data[i] = make([]byte, 1024*1024)
		// 填充数据
		for j := range data[i] {
			data[i][j] = byte(j % 256)
		}
	}

	// 模拟对数据的使用
	sum := 0
	for _, chunk := range data {
		sum += int(chunk[0])
	}

	return sizeMB
}

// getIntParam 获取整数参数
func getIntParam(c *gin.Context, key string, defaultValue int) int {
	valueStr := c.DefaultQuery(key, strconv.Itoa(defaultValue))
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}
	// 确保值在合理范围内
	if value < 0 {
		return 0
	}
	if value > 1000 {
		return 1000
	}
	return value
}
