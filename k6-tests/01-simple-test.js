// ============================================
// k6 性能测试脚本 - 入门示例
// 测试目标: GET /api/v1/hello
// ============================================

// 1️⃣ 导入 k6 模块
import http from 'k6/http';
import { sleep, check } from 'k6';

// 2️⃣ 配置测试选项
export const options = {
  // 执行 10 次迭代
  iterations: 10,
};

// 3️⃣ 默认函数 - 测试逻辑（会被重复执行）
export default function () {
  // 发送 GET 请求
  const response = http.get('http://localhost:8080/api/v1/hello');
  
  // 打印响应状态码
  console.log(`Status: ${response.status}`);
  
  // 等待 1 秒（模拟真实用户思考时间）
  sleep(1);
}


