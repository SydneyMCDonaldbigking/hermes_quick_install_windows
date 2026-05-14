// chat.js
// 聊天客户端 - 与 Hermes Gateway 通信

const http = require('http');
const { URL } = require('url');

/**
 * 发送消息到 Hermes Gateway 并获取流式响应
 * @param {string} message 用户消息
 * @param {object} options 配置选项
 * @param {string} options.gatewayUrl Gateway URL (默认: http://127.0.0.1:8000)
 * @param {function} onChunk 流式回调 (data: string) => void
 * @param {function} onComplete 完成回调 () => void
 * @param {function} onError 错误回调 (error: Error) => void
 * @returns {Promise<string>} 完整响应内容
 */
async function sendMessage(message, { gatewayUrl = 'http://127.0.0.1:8000', onChunk, onComplete, onError } = {}) {
    try {
        // 检查输入
        if (!message || typeof message !== 'string') {
            throw new Error('消息不能为空');
        }

        message = message.trim();
        if (message.length === 0) {
            throw new Error('消息不能为空');
        }

        if (message.length > 10000) {
            throw new Error('消息过长（超过 10000 字符）');
        }

        // 构建请求
        const url = new URL(`${gatewayUrl}/api/chat`);
        const payload = JSON.stringify({ message });

        return new Promise((resolve, reject) => {
            // 使用 fetch API (Node 18+)
            if (typeof fetch !== 'undefined') {
                return fetchChat(url.toString(), payload, { onChunk, onComplete, onError })
                    .then(resolve)
                    .catch(reject);
            }

            // 降级方案：使用 http/https 模块
            return httpChat(url, payload, { onChunk, onComplete, onError })
                .then(resolve)
                .catch(reject);
        });
    } catch (error) {
        if (onError) {
            onError(error);
        }
        throw error;
    }
}

/**
 * 使用 fetch API 发送聊天请求
 */
async function fetchChat(url, payload, { onChunk, onComplete, onError }) {
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Hermes-Launcher/1.0'
            },
            body: payload,
            timeout: 30000
        });

        if (!response.ok) {
            throw new Error(`Gateway 返回错误: ${response.status} ${response.statusText}`);
        }

        // 处理流式响应
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let fullText = '';

        try {
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                const chunk = decoder.decode(value, { stream: true });
                fullText += chunk;

                if (onChunk) {
                    onChunk(chunk);
                }
            }
        } catch (streamError) {
            reader.cancel();
            throw streamError;
        }

        if (onComplete) {
            onComplete();
        }

        return fullText;
    } catch (error) {
        if (onError) {
            onError(error);
        }
        throw error;
    }
}

/**
 * 使用 http/https 模块发送聊天请求（Node.js 标准库）
 */
async function httpChat(url, payload, { onChunk, onComplete, onError }) {
    return new Promise((resolve, reject) => {
        const protocol = url.protocol === 'https:' ? require('https') : http;

        const options = {
            method: 'POST',
            hostname: url.hostname,
            port: url.port || (url.protocol === 'https:' ? 443 : 80),
            path: url.pathname + url.search,
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
                'User-Agent': 'Hermes-Launcher/1.0'
            },
            timeout: 30000
        };

        const req = protocol.request(options, (res) => {
            let fullText = '';

            // 检查状态码
            if (res.statusCode !== 200) {
                res.on('data', () => {}); // 清空缓冲区
                reject(new Error(`Gateway 返回错误: ${res.statusCode} ${res.statusMessage}`));
                return;
            }

            // 处理流式数据
            res.on('data', (chunk) => {
                const data = chunk.toString('utf-8');
                fullText += data;

                if (onChunk) {
                    onChunk(data);
                }
            });

            res.on('end', () => {
                if (onComplete) {
                    onComplete();
                }
                resolve(fullText);
            });

            res.on('error', (error) => {
                if (onError) {
                    onError(error);
                }
                reject(error);
            });
        });

        // 处理请求错误
        req.on('error', (error) => {
            if (onError) {
                onError(error);
            }
            reject(error);
        });

        // 处理超时
        req.on('timeout', () => {
            req.destroy();
            const error = new Error('请求超时（30 秒）');
            if (onError) {
                onError(error);
            }
            reject(error);
        });

        // 发送请求体
        req.write(payload);
        req.end();
    });
}

/**
 * 测试 Gateway 连接
 */
async function testConnection(gatewayUrl = 'http://127.0.0.1:8000') {
    try {
        const url = new URL(`${gatewayUrl}/api/health`);
        const protocol = url.protocol === 'https:' ? require('https') : http;

        return new Promise((resolve, reject) => {
            const options = {
                method: 'GET',
                hostname: url.hostname,
                port: url.port || 80,
                path: url.pathname + url.search,
                timeout: 5000
            };

            const req = protocol.request(options, (res) => {
                res.on('data', () => {});
                res.on('end', () => {
                    resolve(res.statusCode === 200);
                });
            });

            req.on('error', () => resolve(false));
            req.on('timeout', () => {
                req.destroy();
                resolve(false);
            });

            req.end();
        });
    } catch (error) {
        return false;
    }
}

module.exports = {
    sendMessage,
    testConnection
};
