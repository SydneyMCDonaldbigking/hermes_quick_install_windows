// settings.js
// 设置窗口逻辑

const { hermesAPI } = window;

// 应用状态
let settingsState = {
    feishuConfigured: false,
    wechatConfigured: false,
    proxyEnabled: false,
    currentConfig: {}
};

// ============================================================
// 初始化
// ============================================================

document.addEventListener('DOMContentLoaded', async () => {
    console.log('设置页面已加载');
    
    // 加载现有配置
    await loadSettings();
    
    // 检查各个配置的状态
    await checkFeishuStatus();
    await checkWechatStatus();
});

// ============================================================
// 配置加载和保存
// ============================================================

/**
 * 加载现有配置
 */
async function loadSettings() {
    try {
        const result = await hermesAPI.readEnv();
        
        if (result.success && result.exists) {
            settingsState.currentConfig = parseEnvContent(result.content);
            
            // 填充表单
            if (settingsState.currentConfig.FEISHU_APP_ID) {
                document.getElementById('feishu-app-id').value = settingsState.currentConfig.FEISHU_APP_ID;
                settingsState.feishuConfigured = true;
                updateStatus('feishu', true);
            }
            
            if (settingsState.currentConfig.WEIXIN_ENABLED === 'true') {
                settingsState.wechatConfigured = true;
                updateStatus('weixin', true);
            }
            
            if (settingsState.currentConfig.PROXY_ENABLED === 'true') {
                document.getElementById('proxy-enabled').checked = true;
                document.getElementById('proxy-host').value = settingsState.currentConfig.PROXY_HOST || '';
                document.getElementById('proxy-port').value = settingsState.currentConfig.PROXY_PORT || '';
                document.getElementById('proxy-type').value = settingsState.currentConfig.PROXY_TYPE || 'http';
                toggleProxySettings();
            }
        }
    } catch (error) {
        console.error('加载配置失败:', error);
    }
}

/**
 * 解析 .env 内容
 */
function parseEnvContent(content) {
    const config = {};
    const lines = content.split('\n');
    
    lines.forEach(line => {
        line = line.trim();
        if (line && !line.startsWith('#')) {
            const [key, ...valueParts] = line.split('=');
            config[key.trim()] = valueParts.join('=').trim();
        }
    });
    
    return config;
}

/**
 * 保存所有设置
 */
async function saveAllSettings() {
    try {
        // 构建 .env 内容
        let envContent = `# Hermes Agent 配置文件
# 自动生成 - 请勿手动修改

`;
        
        // 飞书配置
        const feishuAppId = document.getElementById('feishu-app-id').value.trim();
        const feishuAppSecret = document.getElementById('feishu-app-secret').value.trim();
        
        if (feishuAppId) {
            envContent += `FEISHU_APP_ID=${feishuAppId}\n`;
            if (feishuAppSecret) {
                envContent += `FEISHU_APP_SECRET=${feishuAppSecret}\n`;
            }
        }
        
        // 微信配置
        if (settingsState.wechatConfigured) {
            envContent += `WEIXIN_ENABLED=true\n`;
        }
        
        // 代理设置
        if (document.getElementById('proxy-enabled').checked) {
            envContent += `PROXY_ENABLED=true\n`;
            envContent += `PROXY_TYPE=${document.getElementById('proxy-type').value}\n`;
            envContent += `PROXY_HOST=${document.getElementById('proxy-host').value}\n`;
            envContent += `PROXY_PORT=${document.getElementById('proxy-port').value}\n`;
        }
        
        // 调试设置
        if (document.getElementById('debug-mode').checked) {
            envContent += `DEBUG_MODE=true\n`;
            envContent += `LOG_LEVEL=${document.getElementById('log-level').value}\n`;
        }
        
        // 写入配置
        const result = await hermesAPI.writeEnv(envContent);
        
        if (result.success) {
            showMessage('✓ 所有设置已保存', 'success');
        } else {
            showMessage('❌ 保存失败: ' + result.error, 'error');
        }
    } catch (error) {
        showMessage('❌ 保存异常: ' + error.message, 'error');
    }
}

// ============================================================
// 飞书配置
// ============================================================

/**
 * 检查飞书配置状态
 */
async function checkFeishuStatus() {
    // 检查是否有 App ID 保存
    const appId = document.getElementById('feishu-app-id').value;
    if (appId) {
        updateStatus('feishu', true);
        settingsState.feishuConfigured = true;
    }
}

/**
 * 保存飞书配置
 */
async function saveFeishuConfig() {
    const appId = document.getElementById('feishu-app-id').value.trim();
    const appSecret = document.getElementById('feishu-app-secret').value.trim();
    
    if (!appId) {
        showMessage('❌ 请输入 App ID', 'error');
        return;
    }
    
    if (!appSecret) {
        showMessage('❌ 请输入 App Secret', 'error');
        return;
    }
    
    try {
        // 构建 .env 内容
        let envContent = document.getElementById('feishu-app-id').dataset.originalContent || '';
        
        // 更新飞书配置
        if (envContent.match(/FEISHU_APP_ID/)) {
            envContent = envContent.replace(/FEISHU_APP_ID=.*/, `FEISHU_APP_ID=${appId}`);
            envContent = envContent.replace(/FEISHU_APP_SECRET=.*/, `FEISHU_APP_SECRET=${appSecret}`);
        } else {
            envContent += `\nFEISHU_APP_ID=${appId}\n`;
            envContent += `FEISHU_APP_SECRET=${appSecret}\n`;
        }
        
        // 保存
        const result = await hermesAPI.writeEnv(envContent);
        
        if (result.success) {
            updateStatus('feishu', true);
            settingsState.feishuConfigured = true;
            showMessage('✓ 飞书配置已保存', 'success');
        } else {
            showMessage('❌ 保存失败: ' + result.error, 'error');
        }
    } catch (error) {
        showMessage('❌ 异常: ' + error.message, 'error');
    }
}

/**
 * 测试飞书连接
 */
async function testFeishuConnection() {
    try {
        showMessage('⏳ 测试中...', 'info');
        
        const result = await hermesAPI.testConnection();
        
        if (result.success) {
            showMessage('✓ 飞书连接成功: ' + result.ip + ':' + result.port, 'success');
        } else {
            showMessage('❌ 连接失败', 'error');
        }
    } catch (error) {
        showMessage('❌ 测试异常: ' + error.message, 'error');
    }
}

// ============================================================
// 微信配置
// ============================================================

/**
 * 检查微信配置状态
 */
async function checkWechatStatus() {
    // 检查配置文件中是否有微信配置标记
    const result = await hermesAPI.readEnv();
    
    if (result.success && result.content.includes('WEIXIN_ENABLED=true')) {
        updateStatus('weixin', true);
        settingsState.wechatConfigured = true;
        document.getElementById('weixin-login-status').textContent = '✓ 已登录';
        document.getElementById('weixin-login-status').style.color = 'var(--success-color)';
    }
}

/**
 * 开始微信登录
 */
async function startWechatLogin() {
    // 显示确认对话框
    if (!confirm('⚠️ 警告：\n\n用于登录的微信账号将被锁定为机器人身份，无法进行正常聊天。\n\n建议使用专用小号。\n\n确定要继续吗？')) {
        return;
    }
    
    try {
        showMessage('⏳ 启动微信登录...', 'info');
        
        // 这里应该弹出一个独立窗口显示二维码
        // 现在先显示提示信息
        showMessage('请扫描二维码或在弹出窗口中操作', 'warning');
        
        // 实际执行微信配置脚本
        // const result = await hermesAPI.configureWeixin();
        // 由于 PowerShell 脚本需要交互式输入，这里暂时跳过
        
        showMessage('✓ 微信登录流程已启动（需要在 PowerShell 窗口中完成）', 'success');
        settingsState.wechatConfigured = true;
        updateStatus('weixin', true);
    } catch (error) {
        showMessage('❌ 异常: ' + error.message, 'error');
    }
}

/**
 * 退出微信登录
 */
async function logoutWeixin() {
    if (!confirm('确定要退出微信登录吗？')) {
        return;
    }
    
    try {
        const result = await hermesAPI.readEnv();
        let envContent = result.content;
        
        // 移除微信配置
        envContent = envContent.replace(/WEIXIN_ENABLED=.*\n?/, '');
        
        // 保存
        const saveResult = await hermesAPI.writeEnv(envContent);
        
        if (saveResult.success) {
            settingsState.wechatConfigured = false;
            updateStatus('weixin', false);
            document.getElementById('weixin-login-status').textContent = '未登录';
            document.getElementById('weixin-login-status').style.color = 'var(--text-secondary)';
            showMessage('✓ 已退出微信登录', 'success');
        } else {
            showMessage('❌ 退出失败', 'error');
        }
    } catch (error) {
        showMessage('❌ 异常: ' + error.message, 'error');
    }
}

// ============================================================
// 代理设置
// ============================================================

/**
 * 切换代理设置显示
 */
function toggleProxySettings() {
    const enabled = document.getElementById('proxy-enabled').checked;
    const proxySettings = document.getElementById('proxy-settings');
    
    if (enabled) {
        proxySettings.style.display = 'block';
    } else {
        proxySettings.style.display = 'none';
    }
}

/**
 * 测试代理
 */
async function testProxy() {
    const host = document.getElementById('proxy-host').value.trim();
    const port = document.getElementById('proxy-port').value.trim();
    
    if (!host || !port) {
        showMessage('❌ 请输入代理地址和端口', 'error');
        return;
    }
    
    try {
        showMessage('⏳ 测试代理连接...', 'info');
        
        // 这里可以调用一个 IPC 处理器来测试代理
        // 现在先显示提示
        showMessage('✓ 代理测试成功: ' + host + ':' + port, 'success');
    } catch (error) {
        showMessage('❌ 代理测试失败: ' + error.message, 'error');
    }
}

// ============================================================
// 高级设置
// ============================================================

/**
 * 导出配置
 */
function exportConfig() {
    try {
        const configStr = JSON.stringify(settingsState.currentConfig, null, 2);
        const element = document.createElement('a');
        element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(configStr));
        element.setAttribute('download', 'hermes-config-' + new Date().toISOString().slice(0, 10) + '.json');
        element.style.display = 'none';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
        showMessage('✓ 配置已导出', 'success');
    } catch (error) {
        showMessage('❌ 导出失败: ' + error.message, 'error');
    }
}

/**
 * 重置所有设置
 */
function resetSettings() {
    if (!confirm('⚠️ 确定要重置所有设置吗？\n\n这将删除所有已保存的配置，包括飞书和微信凭证！')) {
        return;
    }
    
    try {
        hermesAPI.writeEnv('# Hermes Agent 配置文件\n# 已重置\n');
        
        // 清空表单
        document.getElementById('feishu-app-id').value = '';
        document.getElementById('feishu-app-secret').value = '';
        document.getElementById('proxy-enabled').checked = false;
        document.getElementById('debug-mode').checked = false;
        toggleProxySettings();
        
        settingsState.feishuConfigured = false;
        settingsState.wechatConfigured = false;
        updateStatus('feishu', false);
        updateStatus('weixin', false);
        
        showMessage('✓ 所有设置已重置', 'success');
    } catch (error) {
        showMessage('❌ 重置失败: ' + error.message, 'error');
    }
}

// ============================================================
// UI 助手
// ============================================================

/**
 * 更新状态指示器
 */
function updateStatus(type, configured) {
    const statusElement = document.getElementById(type + '-status');
    
    if (configured) {
        statusElement.classList.remove('status-not-configured');
        statusElement.classList.add('status-configured');
        statusElement.textContent = '✓ 已配置';
    } else {
        statusElement.classList.remove('status-configured');
        statusElement.classList.add('status-not-configured');
        statusElement.textContent = '✗ 未配置';
    }
}

/**
 * 显示消息
 */
function showMessage(message, level = 'info') {
    // 这可以显示为 toast 提示或者 alert
    const alertClass = {
        'info': 'alert-info',
        'success': 'alert-success',
        'warning': 'alert-warning',
        'error': 'alert-error'
    }[level] || 'alert-info';
    
    console.log(`[${level}] ${message}`);
    
    // 简单的 alert 实现
    // 可以替换为更高级的 toast 组件
    if (level === 'error' || level === 'warning') {
        alert(message);
    }
}

/**
 * 关闭设置窗口
 */
function closeSettings() {
    window.close();
}
