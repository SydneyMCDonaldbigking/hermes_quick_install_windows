// main.js
// Electron 主进程 - 负责窗口管理和 IPC 通信

const { app, BrowserWindow, Menu, ipcMain, dialog } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const os = require('os');
const fs = require('fs');
const { sendMessage, testConnection } = require('./chat');

// 全局变量
let mainWindow;
let trayWindow;
let settingsWindow;
let gatewayProcess = null;
let statusCheckInterval = null;

// ============================================================
// 窗口管理
// ============================================================

function createMainWindow() {
    mainWindow = new BrowserWindow({
        width: 800,
        height: 600,
        minWidth: 600,
        minHeight: 500,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: true,
            enableRemoteModule: false,
            nodeIntegration: false,
            sandbox: true
        },
        icon: path.join(__dirname, '../assets/icon.ico')
    });

    // 加载 HTML
    mainWindow.loadFile(path.join(__dirname, '../public/index.html'));

    // 开发者工具（仅开发模式）
    if (process.env.NODE_ENV === 'development') {
        mainWindow.webContents.openDevTools();
    }

    mainWindow.on('closed', () => {
        mainWindow = null;
    });

    return mainWindow;
}

function createTrayWindow() {
    trayWindow = new BrowserWindow({
        width: 400,
        height: 300,
        show: false,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: true,
            enableRemoteModule: false,
            nodeIntegration: false,
            sandbox: true
        }
    });

    trayWindow.loadFile(path.join(__dirname, '../public/tray.html'));

    trayWindow.on('blur', () => {
        if (trayWindow) {
            trayWindow.hide();
        }
    });

    return trayWindow;
}

function createSettingsWindow() {
    // 如果已经打开，就聚焦到窗口
    if (settingsWindow) {
        settingsWindow.focus();
        return settingsWindow;
    }

    settingsWindow = new BrowserWindow({
        width: 700,
        height: 900,
        minWidth: 500,
        minHeight: 600,
        parent: mainWindow,
        modal: true,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: true,
            enableRemoteModule: false,
            nodeIntegration: false,
            sandbox: true
        },
        icon: path.join(__dirname, '../assets/icon.ico')
    });

    settingsWindow.loadFile(path.join(__dirname, '../public/settings.html'));

    // 开发模式下打开开发者工具
    if (process.env.NODE_ENV === 'development') {
        settingsWindow.webContents.openDevTools();
    }

    settingsWindow.on('closed', () => {
        settingsWindow = null;
    });

    return settingsWindow;
}

// ============================================================
// PowerShell 脚本执行（关键！）
// ============================================================

/**
 * 执行 PowerShell 脚本
 * @param {string} scriptName - 脚本名称 (setup-wsl2, install-hermes, etc.)
 * @param {string} command - 脚本命令 (start, stop, status, etc.)
 * @returns {Promise<object>} 返回 JSON 结果
 */
function executePowerShellScript(scriptName, command = '') {
    return new Promise((resolve, reject) => {
        const scriptPath = path.join(__dirname, `../scripts/${scriptName}.ps1`);
        
        if (!fs.existsSync(scriptPath)) {
            reject(new Error(`脚本不存在: ${scriptPath}`));
            return;
        }

        // 构建 PowerShell 命令
        // 使用 -NoProfile 避免加载用户配置
        // 使用 -ExecutionPolicy Bypass 允许执行未签名脚本
        const psCommand = command 
            ? `powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" "${command}"`
            : `powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}"`;

        // 执行脚本
        const child = spawn('cmd.exe', ['/s', '/c', psCommand], {
            stdio: ['ignore', 'pipe', 'pipe'],
            encoding: 'utf-8',
            env: {
                ...process.env,
                // 设置代码页为 UTF-8
                CHCP: '65001'
            }
        });

        let stdout = '';
        let stderr = '';

        if (child.stdout) {
            child.stdout.on('data', (data) => {
                stdout += data.toString();
            });
        }

        if (child.stderr) {
            child.stderr.on('data', (data) => {
                stderr += data.toString();
            });
        }

        child.on('close', (code) => {
            // 尝试解析 JSON 输出
            let result;
            try {
                // 移除非 JSON 内容（如颜色代码、日志前缀）
                const jsonMatch = stdout.match(/\{[\s\S]*\}/);
                if (jsonMatch) {
                    result = JSON.parse(jsonMatch[0]);
                } else {
                    // 如果没有 JSON，返回纯文本
                    result = {
                        success: code === 0,
                        output: stdout.trim(),
                        error: stderr.trim(),
                        exitCode: code
                    };
                }
            } catch (e) {
                result = {
                    success: code === 0,
                    output: stdout.trim(),
                    error: stderr.trim() || e.message,
                    exitCode: code
                };
            }

            if (code === 0) {
                resolve(result);
            } else {
                reject(result);
            }
        });
    });
}

// ============================================================
// IPC 处理器 - PowerShell 脚本调用
// ============================================================

// 启动 Gateway
ipcMain.handle('hermes:start', async (event) => {
    try {
        const result = await executePowerShellScript('manage-hermes', 'start');
        
        // 启动后台状态检查
        if (!statusCheckInterval) {
            statusCheckInterval = setInterval(async () => {
                try {
                    const status = await executePowerShellScript('manage-hermes', 'status');
                    // 广播状态给所有窗口
                    if (mainWindow) {
                        mainWindow.webContents.send('hermes:status-update', status);
                    }
                } catch (error) {
                    console.error('状态检查失败:', error);
                }
            }, 5000); // 每 5 秒检查一次
        }
        
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 停止 Gateway
ipcMain.handle('hermes:stop', async (event) => {
    try {
        // 停止状态检查
        if (statusCheckInterval) {
            clearInterval(statusCheckInterval);
            statusCheckInterval = null;
        }
        
        const result = await executePowerShellScript('manage-hermes', 'stop');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 重启 Gateway
ipcMain.handle('hermes:restart', async (event) => {
    try {
        const result = await executePowerShellScript('manage-hermes', 'restart');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 获取 Gateway 状态
ipcMain.handle('hermes:status', async (event) => {
    try {
        const result = await executePowerShellScript('manage-hermes', 'status');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 测试连通性
ipcMain.handle('hermes:test-connection', async (event) => {
    try {
        const result = await executePowerShellScript('manage-hermes', 'test-connection');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 重启 WSL2 网络
ipcMain.handle('hermes:restart-network', async (event) => {
    try {
        const result = await executePowerShellScript('manage-hermes', 'restart-network');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 获取日志
ipcMain.handle('hermes:get-logs', async (event) => {
    try {
        const result = await executePowerShellScript('manage-hermes', 'logs');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// ============================================================
// IPC 处理器 - 窗口管理
// ============================================================

// 打开设置窗口
ipcMain.handle('window:open-settings', async (event) => {
    try {
        createSettingsWindow();
        return { success: true };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// ============================================================
// IPC 处理器 - 配置管理
// ============================================================

// 获取 .env 文件内容
ipcMain.handle('config:read-env', async (event) => {
    try {
        const envPath = path.join(os.homedir(), 'AppData', 'Local', 'hermes', '.env');
        
        if (!fs.existsSync(envPath)) {
            return {
                success: true,
                content: '',
                exists: false
            };
        }
        
        const content = fs.readFileSync(envPath, 'utf-8');
        return {
            success: true,
            content,
            exists: true
        };
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
});

// 保存 .env 文件
ipcMain.handle('config:write-env', async (event, content) => {
    try {
        const envDir = path.join(os.homedir(), 'AppData', 'Local', 'hermes');
        const envPath = path.join(envDir, '.env');
        
        // 确保目录存在
        if (!fs.existsSync(envDir)) {
            fs.mkdirSync(envDir, { recursive: true });
        }
        
        fs.writeFileSync(envPath, content, 'utf-8');
        return { success: true };
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
});

// ============================================================
// IPC 处理器 - 飞书配置
// ============================================================

// 配置飞书机器人
ipcMain.handle('config:feishu', async (event) => {
    try {
        const result = await executePowerShellScript('config-feishu');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 测试飞书连接
ipcMain.handle('config:feishu-test', async (event) => {
    try {
        const result = await executePowerShellScript('config-feishu', 'test');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// ============================================================
// IPC 处理器 - 微信配置
// ============================================================

// 配置微信机器人
ipcMain.handle('config:weixin', async (event) => {
    try {
        const result = await executePowerShellScript('config-weixin');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 测试微信连接
ipcMain.handle('config:weixin-test', async (event) => {
    try {
        const result = await executePowerShellScript('config-weixin', 'test');
        return { success: true, ...result };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// ============================================================
// IPC 处理器 - 聊天功能
// ============================================================

// 发送消息到 Gateway
ipcMain.handle('chat:send-message', async (event, message) => {
    try {
        if (!message || message.trim().length === 0) {
            return { success: false, error: '消息不能为空' };
        }

        // 尝试多个地址
        const gatewayUrls = [
            'http://127.0.0.1:8000',
            'http://localhost:8000',
            'http://172.17.0.1:8000' // WSL2 内部 IP
        ];

        let lastError = null;
        let fullResponse = '';

        for (const url of gatewayUrls) {
            try {
                // 流式接收响应
                fullResponse = await sendMessage(message, {
                    gatewayUrl: url,
                    onChunk: (chunk) => {
                        // 发送流式数据给渲染进程
                        if (mainWindow && mainWindow.webContents) {
                            mainWindow.webContents.send('chat:message-chunk', chunk);
                        }
                    },
                    onComplete: () => {
                        // 消息完成
                    }
                });
                
                // 成功则返回
                return {
                    success: true,
                    response: fullResponse,
                    gatewayUrl: url
                };
            } catch (error) {
                lastError = error;
                continue; // 尝试下一个 URL
            }
        }

        // 所有 URL 都失败了
        return {
            success: false,
            error: `无法连接到 Gateway: ${lastError?.message || '连接失败'}`
        };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// 测试 Gateway 连接
ipcMain.handle('chat:test-connection', async (event) => {
    try {
        const urls = [
            'http://127.0.0.1:8000',
            'http://localhost:8000',
            'http://172.17.0.1:8000'
        ];

        for (const url of urls) {
            const connected = await testConnection(url);
            if (connected) {
                return {
                    success: true,
                    connected: true,
                    gatewayUrl: url,
                    message: `已连接到 ${url}`
                };
            }
        }

        return {
            success: true,
            connected: false,
            message: '无法连接到 Gateway，请确保已启动'
        };
    } catch (error) {
        return { success: false, error: error.toString() };
    }
});

// ============================================================
// 应用启动和关闭
// ============================================================

app.on('ready', () => {
    createMainWindow();
    
    // 创建菜单
    const template = [
        {
            label: '文件',
            submenu: [
                {
                    label: '退出',
                    accelerator: 'CmdOrCtrl+Q',
                    click: () => {
                        app.quit();
                    }
                }
            ]
        },
        {
            label: '帮助',
            submenu: [
                {
                    label: '关于',
                    click: () => {
                        dialog.showMessageBox(mainWindow, {
                            type: 'info',
                            title: '关于 Hermes 启动器',
                            message: 'Hermes Agent Windows 一键启动器',
                            detail: `版本: 0.1.0\n作者: Hermes Team\nElectron: ${process.versions.electron}`
                        });
                    }
                }
            ]
        }
    ];
    
    Menu.setApplicationMenu(Menu.buildFromTemplate(template));
});

app.on('window-all-closed', () => {
    // 清理定时器
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
    }
    
    // 在 macOS 上，应用通常在用户明确退出前保持活跃
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    // 在 macOS 上，用户点击 dock 图标时重新创建窗口
    if (mainWindow === null) {
        createMainWindow();
    }
});

// ============================================================
// 错误处理
// ============================================================

process.on('uncaughtException', (error) => {
    console.error('未捕获的异常:', error);
    dialog.showErrorBox('应用错误', '应用遇到了一个错误。请查看日志文件。');
});

// 记录启动信息
console.log('Hermes 启动器启动');
console.log('Electron 版本:', process.versions.electron);
console.log('Node 版本:', process.versions.node);
console.log('应用路径:', app.getAppPath());
