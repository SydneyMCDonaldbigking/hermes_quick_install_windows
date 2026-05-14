// preload.js
// IPC 安全桥接 - 在隔离上下文中运行
// 这个文件限制了渲染进程能做的事情，保证安全

const { contextBridge, ipcRenderer } = require('electron');

// ============================================================
// 暴露给渲染进程的 API
// ============================================================

contextBridge.exposeInMainWorld('hermesAPI', {
    // ============================================================
    // Gateway 控制
    // ============================================================
    
    /**
     * 启动 Gateway
     * @returns {Promise<object>} { success, message, port, ... }
     */
    start: () => ipcRenderer.invoke('hermes:start'),
    
    /**
     * 停止 Gateway
     * @returns {Promise<object>}
     */
    stop: () => ipcRenderer.invoke('hermes:stop'),
    
    /**
     * 重启 Gateway
     * @returns {Promise<object>}
     */
    restart: () => ipcRenderer.invoke('hermes:restart'),
    
    /**
     * 获取 Gateway 状态
     * @returns {Promise<object>} { running, connection, ip, port, memory_mb, uptime_seconds, ... }
     */
    getStatus: () => ipcRenderer.invoke('hermes:status'),
    
    /**
     * 测试网络连通性
     * @returns {Promise<object>} { success, ip, port, message }
     */
    testConnection: () => ipcRenderer.invoke('hermes:test-connection'),
    
    /**
     * 重启 WSL2 网络（网络故障时）
     * @returns {Promise<object>}
     */
    restartNetwork: () => ipcRenderer.invoke('hermes:restart-network'),
    
    /**
     * 获取 Gateway 日志
     * @returns {Promise<object>} { success, logs }
     */
    getLogs: () => ipcRenderer.invoke('hermes:get-logs'),
    
    // ============================================================
    // 事件监听
    // ============================================================
    
    /**
     * 监听 Gateway 状态更新
     * @param {function} callback - 回调函数
     */
    onStatusUpdate: (callback) => {
        ipcRenderer.on('hermes:status-update', (event, status) => {
            callback(status);
        });
    },
    
    /**
     * 移除状态更新监听
     */
    removeStatusUpdateListener: () => {
        ipcRenderer.removeAllListeners('hermes:status-update');
    },
    
    // ============================================================
    // 配置管理
    // ============================================================
    
    /**
     * 读取 .env 配置文件
     * @returns {Promise<object>} { success, content, exists }
     */
    readEnv: () => ipcRenderer.invoke('config:read-env'),
    
    /**
     * 保存 .env 配置文件
     * @param {string} content - 配置文件内容
     * @returns {Promise<object>} { success }
     */
    writeEnv: (content) => ipcRenderer.invoke('config:write-env', content),
    
    // ============================================================
    // 飞书配置
    // ============================================================
    
    /**
     * 配置飞书机器人
     * @returns {Promise<object>}
     */
    configureFeishu: () => ipcRenderer.invoke('config:feishu'),
    
    /**
     * 测试飞书连接
     * @returns {Promise<object>}
     */
    testFeishuConnection: () => ipcRenderer.invoke('config:feishu-test'),
    
    // ============================================================
    // 微信配置
    // ============================================================
    
    /**
     * 配置微信机器人
     * @returns {Promise<object>}
     */
    configureWeixin: () => ipcRenderer.invoke('config:weixin'),
    
    /**
     * 测试微信连接
     * @returns {Promise<object>}
     */
    testWechatConnection: () => ipcRenderer.invoke('config:weixin-test'),
    
    // ============================================================
    // 窗口管理
    // ============================================================
    
    /**
     * 打开设置窗口
     * @returns {Promise<object>}
     */
    openSettings: () => ipcRenderer.invoke('window:open-settings'),
    
    // ============================================================
    // 系统信息
    // ============================================================
    
    /**
     * 获取应用版本
     * @returns {string}
     */
    getAppVersion: () => {
        // 从 package.json 读取
        return '0.1.0';
    },
    
    /**
     * 获取应用路径
     * @returns {string}
     */
    getAppPath: () => {
        return process.env.ELECTRON_APP_PATH || '/';
    },
    
    // ============================================================
    // 聊天功能
    // ============================================================
    
    /**
     * 发送消息到 Gateway
     * @param {string} message - 用户消息
     * @returns {Promise<object>} { success, response, error }
     */
    sendMessage: (message) => ipcRenderer.invoke('chat:send-message', message),
    
    /**
     * 测试 Gateway 连接
     * @returns {Promise<object>} { success, connected, message }
     */
    testChatConnection: () => ipcRenderer.invoke('chat:test-connection'),
    
    /**
     * 监听聊天消息流
     * @param {function} callback - 流式数据回调
     */
    onMessageChunk: (callback) => {
        ipcRenderer.on('chat:message-chunk', (event, chunk) => {
            callback(chunk);
        });
    }
});

console.log('Preload 脚本已加载，暴露了 hermesAPI');
