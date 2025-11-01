// ============================================
// k6 性能测试脚本 - 带检查和断言
// 测试目标: GET /api/v1/hello
// ============================================

import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
  iterations: 20,
};

export default function () {
  // 发送请求
  const response = http.get('http://localhost:8080/api/v1/hello?name=k6');
  
  // ✅ 添加检查（类似断言）
  const checkResult = check(response, {
    '✅ 状态码是 200': (r) => r.status === 200,
    '✅ 响应时间 < 500ms': (r) => r.timings.duration < 500,
    '✅ 响应包含 message': (r) => r.json('message') !== undefined,
    '✅ message 包含 k6': (r) => r.json('message').includes('k6'),
    '✅ 响应体大小 < 1KB': (r) => r.body.length < 1024,
  });
  
  // 打印响应（调试用）
  if (!checkResult) {
    console.log(`❌ 检查失败: ${response.status} ${response.body}`);
  }
  
  sleep(1);
}


