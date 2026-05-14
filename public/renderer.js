// renderer.js
// 前端逻辑和 IPC 通信

const { hermesAPI } = window;

// 应用状态
let appState = {
    running: false,
    connected: false,
    lastStatus: null,
    statusCheckInterval: null,
    autoCheckEnabled: true
};

// ============================================================
// 初始化
// ============================================================

document.addEventListener('DOMContentLoaded', async () => {
    console.log('应用已加载');
    
    // 初始化时间显示
    updateFooterTime();
    setInterval(updateFooterTime, 1000);
    
    // 初始状态检查
    await checkStatus();
    
    // 启动自动状态检查（每 5 秒）
    startAutoStatusCheck();
    
    // 监听来自主进程的状态更新
    hermesAPI.onStatusUpdate((status) => {
        updateStatusDisplay(status);
    });
});

// ============================================================
// 状态检查和更新
// ============================================================

/**
 * 检查并更新应用状态
 */
async function checkStatus() {
    try {
        showLoading(true);
        addMessage('正在检查状态...', 'info');
        
        const result = await hermesAPI.getStatus();
        
        if (result.success) {
            updateStatusDisplay(result);
            appState.lastStatus = result;
        } else {
            addMessage(`❌ 状态检查失败: ${result.error}`, 'error');
        }
    } catch (error) {
        addMessage(`❌ 异常: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

/**
 * 更新 UI 显示的状态信息
 */
function updateStatusDisplay(status) {
    // 运行状态
    appState.running = status.running === true;
    const runningText = appState.running ? '✓ 正在运行' : '✗ 未运行';
    document.getElementById('status-running').textContent = runningText;
    
    // 连接状态
    appState.connected = status.connection === 'connected';
    const connectionText = appState.connected ? '✓ 已连接' : '✗ 未连接';
    document.getElementById('status-connection').textContent = connectionText;
    
    // 访问地址
    if (appState.connected && status.ip && status.port) {
        document.getElementById('status-address').textContent = `http://${status.ip}:${status.port}`;
    } else {
        document.getElementById('status-address').textContent = '-';
    }
    
    // 内存占用
    if (status.memory_mb) {
        document.getElementById('status-memory').textContent = `${status.memory_mb.toFixed(1)} MB`;
    } else {
        document.getElementById('status-memory').textContent = '-';
    }
    
    // 运行时间
    if (status.uptime_seconds) {
        document.getElementById('status-uptime').textContent = formatUptime(status.uptime_seconds);
    } else {
        document.getElementById('status-uptime').textContent = '-';
    }
    
    // 进程 ID
    if (status.pid) {
        document.getElementById('status-pid').textContent = status.pid;
    } else {
        document.getElementById('status-pid').textContent = '-';
    }
    
    // 更新指示器颜色
    const indicator = document.getElementById('status-indicator');
    indicator.classList.remove('status-running', 'status-pending', 'status-stopped');
    
    if (appState.running && appState.connected) {
        indicator.classList.add('status-running');
        indicator.textContent = '✓ 正常运行';
        document.getElementById('footer-status').textContent = '✓ 正常运行';
    } else if (appState.running) {
        indicator.classList.add('status-pending');
        indicator.textContent = '⏳ 启动中...';
        document.getElementById('footer-status').textContent = '⏳ 启动中...';
    } else {
        indicator.classList.add('status-stopped');
        indicator.textContent = '✗ 已停止';
        document.getElementById('footer-status').textContent = '✗ 已停止';
    }
    
    // 更新按钮状态
    document.getElementById('btn-start').disabled = appState.running;
    document.getElementById('btn-stop').disabled = !appState.running;
    document.getElementById('btn-restart').disabled = !appState.running;
}

/**
 * 启动自动状态检查
 */
function startAutoStatusCheck() {
    // 每 5 秒检查一次
    appState.statusCheckInterval = setInterval(async () => {
        if (appState.autoCheckEnabled && appState.running) {
            try {
                const result = await hermesAPI.getStatus();
                if (result.success) {
                    updateStatusDisplay(result);
                }
            } catch (error) {
                console.error('自动状态检查失败:', error);
            }
        }
    }, 5000);
}

/**
 * 停止自动状态检查
 */
function stopAutoStatusCheck() {
    if (appState.statusCheckInterval) {
        clearInterval(appState.statusCheckInterval);
        appState.statusCheckInterval = null;
    }
}

// ============================================================
// 控制操作
// ============================================================

/**
 * 启动 Gateway
 */
async function handleStart() {
    try {
        showLoading(true);
        addMessage('正在启动 Gateway...', 'info');
        
        const result = await hermesAPI.start();
        
        if (result.success) {
            addMessage('✓ Gateway 已启动，正在初始化...', 'success');
            
            // 短暂延迟后检查状态
            setTimeout(() => {
                checkStatus();
            }, 2000);
        } else {
            addMessage(`❌ 启动失败: ${result.error || result.message}`, 'error');
        }
    } catch (error) {
        addMessage(`❌ 启动异常: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

/**
 * 停止 Gateway
 */
async function handleStop() {
    try {
        showLoading(true);
        addMessage('正在停止 Gateway...', 'info');
        
        const result = await hermesAPI.stop();
        
        if (result.success) {
            addMessage('✓ Gateway 已停止', 'success');
            await checkStatus();
        } else {
            addMessage(`❌ 停止失败: ${result.error}`, 'error');
        }
    } catch (error) {
        addMessage(`❌ 停止异常: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

/**
 * 重启 Gateway
 */
async function handleRestart() {
    try {
        showLoading(true);
        addMessage('正在重启 Gateway...', 'info');
        
        const result = await hermesAPI.restart();
        
        if (result.success) {
            addMessage('✓ Gateway 已重启', 'success');
            setTimeout(() => {
                checkStatus();
            }, 2000);
        } else {
            addMessage(`❌ 重启失败: ${result.error}`, 'error');
        }
    } catch (error) {
        addMessage(`❌ 重启异常: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

/**
 * 测试连接
 */
async function handleTest() {
    try {
        showLoading(true);
        addMessage('正在测试连接...', 'info');
        
        const result = await hermesAPI.testConnection();
        
        if (result.success) {
            addMessage(`✓ 连接成功: ${result.ip}:${result.port}`, 'success');
        } else {
            addMessage(`❌ 连接失败: 无法访问任何地址`, 'warning');
        }
    } catch (error) {
        addMessage(`❌ 测试异常: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

/**
 * 修复网络
 */
async function handleFixNetwork() {
    // 确认操作
    if (!confirm('修复网络将重启 WSL2 虚拟机，Gateway 会暂时中断。是否继续？')) {
        return;
    }
    
    try {
        showLoading(true);
        addMessage('正在重启 WSL2 网络...', 'warning');
        
        const result = await hermesAPI.restartNetwork();
        
        if (result.success) {
            addMessage('✓ 网络已重启，Gateway 将在几秒内重新连接', 'success');
            setTimeout(() => {
                checkStatus();
            }, 3000);
        } else {
            addMessage(`❌ 网络重启失败: ${result.error}`, 'error');
        }
    } catch (error) {
        addMessage(`❌ 异常: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

/**
 * 显示日志
 */
async function handleShowLogs() {
    try {
        showLoading(true);
        
        const result = await hermesAPI.getLogs();
        
        if (result.success) {
            showModal('Gateway 日志', `<pre>${escapeHtml(result.logs || '无日志')}</pre>`);
        } else {
            showModal('错误', `获取日志失败: ${result.error}`);
        }
    } catch (error) {
        showModal('错误', `异常: ${error.message}`);
    } finally {
        showLoading(false);
    }
}

/**
 * 打开设置
 */
async function handleSettings() {
    try {
        await hermesAPI.openSettings();
    } catch (error) {
        showModal('错误', `打开设置失败: ${error.message}`);
    }
}

// ============================================================
// UI 助手函数
// ============================================================

/**
 * 添加消息到输出面板
 */
function addMessage(message, level = 'info') {
    const output = document.getElementById('message-output');
    const p = document.createElement('p');
    p.className = `message ${level}`;
    p.textContent = message;
    output.appendChild(p);
    
    // 自动滚动到底部
    output.scrollTop = output.scrollHeight;
}

/**
 * 清空消息
 */
function clearMessages() {
    const output = document.getElementById('message-output');
    output.innerHTML = '';
}

/**
 * 显示/隐藏加载动画
 */
function showLoading(show) {
    const spinner = document.getElementById('loading-spinner');
    spinner.style.display = show ? 'block' : 'none';
}

/**
 * 显示模态框
 */
function showModal(title, content) {
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-body').innerHTML = content;
    document.getElementById('modal').style.display = 'flex';
}

/**
 * 关闭模态框
 */
function closeModal() {
    document.getElementById('modal').style.display = 'none';
}

/**
 * 格式化运行时间
 */
function formatUptime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
        return `${hours}h ${minutes}m`;
    } else if (minutes > 0) {
        return `${minutes}m ${secs}s`;
    } else {
        return `${secs}s`;
    }
}

/**
 * 更新底部时间
 */
function updateFooterTime() {
    const now = new Date();
    const time = now.toLocaleTimeString('zh-CN');
    document.getElementById('footer-time').textContent = time;
}

/**
 * HTML 转义
 */
function escapeHtml(unsafe) {
    return unsafe
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

// ============================================================
// 聊天功能
// ============================================================

let chatState = {
    isWaiting: false,
    gatewayConnected: false
};

/**
 * 处理聊天输入框回车键
 */
function handleChatKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        handleChatSend();
    }
}

/**
 * 处理发送消息
 */
async function handleChatSend() {
    const inputElement = document.getElementById('chat-input');
    const message = inputElement.value.trim();

    if (!message) {
        addMessage('请输入消息', 'warning');
        return;
    }

    if (chatState.isWaiting) {
        addMessage('正在等待上一条消息的回复...', 'warning');
        return;
    }

    // 显示用户消息
    addChatMessage(message, 'user');
    inputElement.value = '';
    inputElement.focus();

    chatState.isWaiting = true;
    const statusEl = document.getElementById('chat-status');
    statusEl.textContent = '⏳ 正在思考...';

    try {
        // 检查连接
        const connResult = await hermesAPI.testChatConnection();
        if (!connResult.success || !connResult.connected) {
            addChatMessage('❌ Gateway 离线，无法发送消息。请先启动 Gateway。', 'assistant');
            addMessage('聊天服务离线，请先启动 Gateway', 'error');
            return;
        }

        // 发送消息
        const response = await hermesAPI.sendMessage(message);

        if (response.success) {
            // 显示完整响应
            if (response.response) {
                addChatMessage(response.response, 'assistant');
            }
            addMessage('✓ 消息已发送', 'success');
        } else {
            const errorMsg = response.error || '未知错误';
            addChatMessage(`❌ 错误: ${errorMsg}`, 'assistant');
            addMessage(`发送失败: ${errorMsg}`, 'error');
        }
    } catch (error) {
        addChatMessage(`❌ 异常: ${error.message}`, 'assistant');
        addMessage(`异常: ${error.message}`, 'error');
    } finally {
        chatState.isWaiting = false;
        statusEl.textContent = '';
    }
}

/**
 * 添加聊天消息到聊天框
 */
function addChatMessage(text, sender = 'assistant') {
    const messagesContainer = document.getElementById('chat-messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = `chat-message ${sender}`;
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'chat-content';
    contentDiv.textContent = text;
    
    messageDiv.appendChild(contentDiv);
    messagesContainer.appendChild(messageDiv);
    
    // 自动滚到底部
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

/**
 * 清空聊天历史
 */
function clearChatMessages() {
    const messagesContainer = document.getElementById('chat-messages');
    messagesContainer.innerHTML = `<div class="chat-message assistant">
        <div class="chat-content">👋 聊天历史已清空</div>
    </div>`;
    addMessage('聊天历史已清空', 'info');
}

// ============================================================
// 页面卸载清理
// ============================================================

window.addEventListener('beforeunload', () => {
    stopAutoStatusCheck();
    hermesAPI.removeStatusUpdateListener();
});
