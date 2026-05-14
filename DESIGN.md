# Hermes Windows 一键启动器 - 项目设计文档

**项目代号**: hermes_launch  
**版本**: v0.1.0  
**更新日期**: 2026-05-13  
**目标用户**: 完全不懂 AI/编程的普通用户

---

## 📋 目录

1. [项目概述](#项目概述)
2. [技术栈](#技术栈)
3. [架构设计](#架构设计)
4. [功能清单](#功能清单)
5. [UI/UX 设计](#uiux-设计)
6. [后端实现](#后端实现)
7. [配置系统](#配置系统)
8. [实现进度](#实现进度)
9. [已解决问题](#已解决问题)
10. [下一步计划](#下一步计划)

---

## 项目概述

### 目标
创建一个 Windows 桌面应用，让非技术用户可以**一键启动** Hermes Agent（官方自主代理系统），并支持飞书和微信机器人配置。

### 核心价值主张
- ✅ **零配置**：下载 exe → 点击启动，无需理解技术概念
- ✅ **沙箱隔离**：Agent 运行在 WSL2 虚拟机中，完全与 Windows 系统分离
- ✅ **一键卸载**：删除应用 = 删除 WSL2 虚拟机，零污染
- ✅ **中文友好**：所有界面、提示、文档都是中文

### 用户场景
```
用户流程：
1. 下载 hermes_launcher.exe
2. 双击运行 → 自动检查/安装 WSL2
3. 点击 [启动 Agent]
4. (可选) 配置飞书/微信
5. 开始使用 Agent
```

---

## 技术栈

### 前端
| 组件 | 选择 | 原因 |
|------|------|------|
| 框架 | **Electron** | 零依赖，用户无需装 .NET/Python 运行时 |
| UI | HTML + CSS | 简单、可定制、易维护 |
| 逻辑 | Node.js (JavaScript) | Electron 原生，快速开发 |
| 打包 | electron-builder | 自动生成 exe 安装程序 |

### 后端
| 组件 | 选择 | 原因 |
|------|------|------|
| 脚本语言 | **PowerShell 5.1** | Windows 原生，无需额外依赖 |
| 版本管理 | git + WSL2 | 官方安装方式 |
| 虚拟化 | **WSL2** | 轻量级隔离，官方推荐 |

### 目标系统
- **操作系统**: Windows 10 21H2+ 或 Windows 11
- **WSL2**: 需要启用（安装程序自动检查）
- **Hermes Agent**: v0.13.0+（官方版本）

---

## 架构设计

### 总体架构

```
┌─────────────────────────────────────────────────────────┐
│                  Windows 本机                           │
│  ┌───────────────────────────────────────────────────┐ │
│  │ Hermes Launcher (Electron GUI)                   │ │
│  │ ┌─────────────────────────────────────────────┐ │ │
│  │ │ 主界面                                      │ │ │
│  │ │ - 启动/停止按钮                             │ │ │
│  │ │ - 状态显示                                  │ │ │
│  │ │ - 简单聊天框                                │ │ │
│  │ │ - 配置面板 (飞书/微信)                      │ │ │
│  │ └─────────────────────────────────────────────┘ │ │
│  │                    ↓                             │ │
│  │ ┌─────────────────────────────────────────────┐ │ │
│  │ │ PowerShell Scripts                          │ │ │
│  │ │ - WSL2 管理                                 │ │ │
│  │ │ - Hermes 启动/停止                          │ │ │
│  │ │ - 配置文件生成                              │ │ │
│  │ └─────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────┘ │
│                    ↓                                     │
│ ┌─────────────────────────────────────────────────────┐ │
│ │          WSL2 虚拟机 (Linux)                        │ │
│ │  ┌──────────────────────────────────────────────┐ │ │
│ │  │ Hermes Agent (官方)                          │ │ │
│ │  │ - Agent 核心逻辑                             │ │ │
│ │  │ - 持久化内存                                 │ │ │
│ │  │ - 技能系统                                   │ │ │
│ │  │ - Gateway (多平台支持)                       │ │ │
│ │  └──────────────────────────────────────────────┘ │ │
│ │                    ↓                              │ │
│ │  ┌──────────────────────────────────────────────┐ │ │
│ │  │ 外部服务                                     │ │ │
│ │  │ - 飞书 Bot (WebSocket/Webhook)               │ │ │
│ │  │ - 微信 Bot (QR 登录)                         │ │ │
│ │  │ - LLM API (OpenAI/OpenRouter/etc)            │ │ │
│ │  └──────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 数据流

```
用户输入 (Electron) 
  ↓
调用 PowerShell 脚本
  ↓
WSL2 中执行 hermes 命令
  ↓
Hermes Agent 处理
  ↓
返回结果给 Electron
  ↓
显示在 UI 上
```

---

## 功能清单

### MVP (第一版，必须有)

| ID | 功能 | 优先级 | 状态 | 说明 |
|----|------|--------|------|------|
| F1 | 启动/停止 Agent | P0 | ⏳ | 核心功能 |
| F2 | 实时状态显示 | P0 | ⏳ | 绿/灰 指示灯 |
| F3 | API 地址显示 | P0 | ⏳ | 复制按钮，方便集成 |
| F4 | 进度提示 | P0 | ⏳ | 启动时显示"正在启动..." |
| F5 | 简单聊天框 | P0 | ⏳ | 直接与 Agent 对话 |
| F6 | Web 界面快速入口 | P1 | ⏳ | [打开 Web 界面] 按钮 |
| F7 | 飞书一键配置 | P1 | ⏳ | 扫码 + 自动保存 |
| F8 | 微信一键配置 | P1 | ⏳ | QR 登录 + 自动保存 |
| F9 | 资源监控 | P1 | ⏳ | 内存/CPU 使用 |
| F10 | 卸载功能 | P1 | ⏳ | ⚠️ 必须有"导出数据"选项，防止用户丢失 Agent 记忆 |

### 第二版（稳定性）

| ID | 功能 | 优先级 | 说明 |
|----|------|--------|------|
| F11 | 自动故障恢复 | P2 | Agent 崩溃自动重启 |
| F12 | 关机保护 | P2 | 提示用户 Agent 在运行 |
| F13 | 日志导出 | P2 | 故障排查用 |
| F14 | 数据备份/恢复 | P2 | Agent 内存数据备份 |

### 第三版（Polish）

| ID | 功能 | 优先级 | 说明 |
|----|------|--------|------|
| F15 | 系统托盘 | P3 | 最小化到托盘 |
| F16 | 开机自启 | P3 | Windows 启动时运行 |
| F17 | 自动更新 | P3 | 检查并更新应用版本 |
| F18 | 完整 FAQ | P3 | 内置帮助中心 |

---

## 风险清单 & 深水区对策

### 1. 磁盘空间与下载预警 ⚠️

**问题**  
WSL2 + Hermes 环境 2-5GB，用户在国内网络环境下下载极慢，磁盘满导致失败。

**对策**
- ✅ 检查磁盘：安装前检查目标盘（默认 C 盘）是否有 ≥10GB 剩余空间
- ✅ 国内镜像：在 `install-hermes.ps1` 中自动配置清华/阿里源，加速 apt
- ✅ 进度提示：实时显示下载速度和剩余时间，防止用户关闭

**相关代码位置**  
`scripts/setup-wsl2.ps1` 的 `Check-DiskSpace` 函数

---

### 2. 权限请求的"惊吓"处理 👮

**问题**  
调用 `wsl --install` 或网络配置需要管理员权限，Electron 会弹多次 UAC 黑框，用户以为是病毒。

**对策**
- ✅ 启动检测：应用启动时检测权限，不足时引导"以管理员身份运行"
- ✅ 集中申请：使用 `sudo-prompt` 库，一次性申请权限，避免多次 UAC
- ✅ 清晰提示：弹窗明确说"需要管理员权限以配置虚拟机"

**相关库**  
`npm install sudo-prompt` 在 Electron 主进程中

---

### 3. "魔法"依赖 - LLM API 连接 🌐

**问题**  
用户没有科学上网，或代理配置不对，Agent 无法调用 OpenAI/OpenRouter。

**对策**
- ✅ 代理设置：在 [设置] 中增加 [网络代理] 选项，允许输入 `http://127.0.0.1:7890`
- ✅ 自动透传：PowerShell 脚本需要将 `http_proxy` 写入 WSL2 的 `.bashrc` 和 `.env`
- ✅ 检测测试：配置后自动测试"是否能连接到 OpenAI"

**环境变量透传**
```bash
# 在 WSL2 中添加代理配置
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export no_proxy=localhost,127.0.0.1
```

---

### 4. 微信配置的"非对称性"风险 ⚠️

**问题**  
微信"一键扫码"会占用该账号的机器人身份，用户个人微信账号会被锁定。

**对策**
- ✅ 明确告知：在配置页面大号警告"该账号将被作为机器人占用，建议使用小号或企业号"
- ✅ 账号提示：扫码前显示"请确认是否要使用该账号作为机器人"
- ✅ 恢复说明：卸载时提示如何恢复微信账号控制权

**UI 文案**
```
⚠️ 重要提示

选择的微信账号将被配置为机器人，可能导致：
- 账号在其他设备失效
- 自动回复所有消息
- 建议使用小号或企业微信

继续吗？ [确认] [取消]
```

---

### 5. WSL2 的"假死"与端口映射 🔧

**问题**  
WSL2 休眠后网络断开，或 localhost 映射失效，用户看不到 Agent 在运行。

**对策**
- ✅ 网络探针：在 `Get-HermesStatus` 中增加连接测试，尝试多个 IP 地址
- ✅ 自动恢复：如果连接失败，自动尝试重启网络或 WSL2
- ✅ 用户提示：显示"尝试重新连接..."，而不是直接显示"未运行"

**探针逻辑**
```powershell
function Test-HermesConnection {
    # 尝试 localhost
    $result = Test-NetConnection -ComputerName 127.0.0.1 -Port 8000 -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) { return $true }
    
    # 尝试 WSL2 内部 IP
    $wslIp = wsl hostname -I | Select-Object -First 1
    $result = Test-NetConnection -ComputerName $wslIp -Port 8000 -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) { return $true }
    
    return $false
}
```

---

### 6. 虚拟化平台未启用 🖥️

**问题**  
用户的 BIOS 没有开启虚拟化（Virtualization），或 Hyper-V 被禁用。

**对策**
- ✅ 启动检测：在 `setup-wsl2.ps1` 中检查 `VirtualMachinePlatform` 特性
- ✅ 自动启用：如果未启用，自动启用并提示"需要重启"
- ✅ BIOS 提示：如果硬件层面禁用，显示"需要在 BIOS 中启用 Virtualization"

**检查代码**
```powershell
function Check-VirtualizationEnabled {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform"
    if ($feature.State -ne "Enabled") {
        Write-Host "⚠ 虚拟化平台未启用，正在启用..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart
        Write-Host "⚠ 需要重启电脑以完成配置" -ForegroundColor Yellow
        return $false
    }
    return $true
}
```

---

## UI/UX 设计

### 主界面 (Main Window)

```
┌──────────────────────────────────────────┐
│ 🤖 Hermes Agent  [−] [□] [×]              │
├──────────────────────────────────────────┤
│                                          │
│         ⚫ 未启动                          │
│                                          │
│      [大启动按钮 450x80]                  │
│      ┌────────────────────────┐         │
│      │   🚀 启动 Agent        │         │
│      └────────────────────────┘         │
│                                          │
│  API 地址: http://127.0.0.1:8000         │
│  [复制] [打开 Web]                       │
│                                          │
│  进度: 已运行 2小时 18分                 │
│                                          │
│  ┌──────────────────────────────────┐  │
│  │ 💬 快速聊天                       │  │
│  │ [输入你的问题...]             [↵] │  │
│  │                                  │  │
│  │ Agent: 你好，我是 Hermes...     │  │
│  │                                  │  │
│  │ You: 帮我生成一个...             │  │
│  │ Agent: 好的，我来...             │  │
│  └──────────────────────────────────┘  │
│                                          │
│  [设置] [资源] [日志] [帮助]             │
└──────────────────────────────────────────┘
```

### 设置界面 (Settings)

```
⚙️ 基础设置

Agent 名字: [My Agent_________]

飞书配置:
  [ ] 已启用
  [配置飞书] [测试连接]

微信配置:
  [ ] 已启用
  [配置微信] [测试连接]

─────────────────────────

进阶设置 (展开):

资源限制:
  内存上限: [4GB]
  CPU限制: [无限]

自动更新:
  [✓] 启用自动更新
  [✓] 启用开机自启

[保存] [重置默认] [关闭]
```

### 飞书配置界面 (Feishu Setup)

```
📋 飞书配置向导

步骤 1/2: 创建飞书应用

推荐方式 (一键):
  [扫描二维码配置飞书]
  → 打开浏览器，用手机飞书扫码
  → 自动创建应用并保存 App ID/Secret

────────────────────────

或手动输入:
  App ID:     [cli_xxx____________]
  App Secret: [secret_xxx_________]

[下一步]
```

### 微信配置界面 (WeChat Setup)

```
📱 微信配置向导

步骤 1/1: 微信登录

一键登录:
  [用微信扫描登录]
  → 打开浏览器，扫描二维码
  → 手机上确认登录
  → 自动保存账号信息

────────────────────────

当前状态: ○ 未登录

访问控制:
  [ ] 仅允许特定用户使用
      [添加用户]

[保存并启动]
```

---

## 后端实现

### PowerShell 脚本架构

```
scripts/
├── setup-wsl2.ps1
│   ├── Check-WSL2Installed
│   ├── Install-WSL2
│   ├── Check-VirtualizationSupport
│   └── Verify-WSL2Status
│
├── install-hermes.ps1
│   ├── Initialize-HermesHome
│   ├── Install-HermesAgent (从 WSL2 的 ~/.hermes)
│   ├── Configure-ChinaMirrors
│   └── Configure-Proxy
│
├── manage-hermes.ps1
│   ├── Start-HermesAgent (后台启动)
│   ├── Stop-HermesAgent
│   ├── Get-HermesStatus (带网络探针)
│   ├── Restart-HermesNetwork
│   └── Uninstall-HermesAgent
│
├── config-feishu.ps1
│   ├── Generate-FeishuEnv
│   ├── Test-FeishuConnection
│   └── Update-FeishuConfig
│
└── config-weixin.ps1
    ├── Generate-WeixinEnv
    ├── Test-WeixinConnection
    └── Update-WeixinConfig
```

### ⚠️ 关键设计决策

#### WSL2 发行版统一命名
```powershell
# 全局常量 - 在所有脚本中使用
[string]$WSL_DISTRO_NAME = "HermesUbuntu"  # 统一使用此名称
[string]$HERMES_WSL_HOME = "~/.hermes"    # WSL2 内部路径（始终使用）
```

**规则**:
- ✅ 安装：`wsl --install -d HermesUbuntu`
- ✅ 启动：`wsl -d HermesUbuntu`
- ✅ 路径：始终用 Linux 路径 `~/.hermes`，不要用 Windows 路径

#### Windows 路径 ↔ WSL2 路径转换
```powershell
# Windows 路径转 WSL2 路径
function Convert-ToWSLPath {
    param([string]$WindowsPath)
    $wslPath = wsl wslpath "$WindowsPath" 2>/dev/null
    return $wslPath
}

# 示例
$windowsPath = "C:\Users\$env:USERNAME\AppData\Local\hermes"
$wslPath = Convert-ToWSLPath $windowsPath  # 返回 /mnt/c/Users/.../AppData/Local/hermes
# 但实际上，我们应该直接用 ~/.hermes（在 WSL2 内更简洁）
```

### 关键脚本逻辑（修正版）

#### setup-wsl2.ps1
```powershell
# 全局常量
[string]$WSL_DISTRO_NAME = "HermesUbuntu"

function Check-WSL2Installed {
    try {
        $output = wsl --list --verbose 2>$null
        return $output -match $WSL_DISTRO_NAME
    } catch {
        return $false
    }
}

function Install-WSL2 {
    Write-Host "检查 WSL2..." -ForegroundColor Yellow
    
    if (Check-WSL2Installed) {
        Write-Host "✓ WSL2 ($WSL_DISTRO_NAME) 已安装" -ForegroundColor Green
        return $true
    }
    
    Write-Host "⚠ WSL2 未安装，正在安装..." -ForegroundColor Yellow
    
    # 统一使用 HermesUbuntu 作为发行版名称
    wsl --install -d $WSL_DISTRO_NAME --web-download
    
    Write-Host "✓ WSL2 安装完成" -ForegroundColor Green
    Write-Host "⚠ 需要重启电脑以完成配置" -ForegroundColor Yellow
    return $false  # 需要重启
}

function Check-VirtualizationSupport {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" `
        -ErrorAction SilentlyContinue
    
    if ($feature.State -ne "Enabled") {
        Write-Host "⚠ Virtual Machine Platform 未启用，正在启用..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart
        Write-Host "⚠ 需要重启电脑以生效" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✓ 虚拟化支持已启用" -ForegroundColor Green
    return $true
}
```

#### manage-hermes.ps1
```powershell
# 全局常量
[string]$WSL_DISTRO_NAME = "HermesUbuntu"
[string]$HERMES_WSL_HOME = "~/.hermes"

function Start-HermesAgent {
    param(
        [switch]$Wait = $false  # 是否等待（调试用）
    )
    
    Write-Host "正在启动 Hermes Agent..." -ForegroundColor Yellow
    
    # ❌ 错误做法（会阻塞 UI）:
    # wsl -d $WSL_DISTRO_NAME -u root -e bash -c "cd $HERMES_WSL_HOME && hermes gateway"
    
    # ✅ 正确做法（后台启动，不阻塞）:
    # 使用 nohup 后台运行，输出到日志文件
    wsl -d $WSL_DISTRO_NAME -u root -e bash -lc @"
        mkdir -p ~/.hermes/logs
        cd ~/.hermes
        nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &
        echo "Agent 启动 PID: \$!"
"@
    
    Write-Host "✓ Hermes Agent 已在后台启动" -ForegroundColor Green
    Write-Host "   日志文件: ~/.hermes/logs/gateway.log" -ForegroundColor Gray
    
    # 等待 2 秒让 Agent 初始化
    Start-Sleep -Seconds 2
    
    # 验证是否真的启动成功
    if (Test-HermesConnection) {
        Write-Host "✓ Hermes Agent 连接测试成功" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠ Agent 进程已启动，但连接失败。请检查日志:" -ForegroundColor Yellow
        Write-Host "   wsl -d $WSL_DISTRO_NAME tail -50 ~/.hermes/logs/gateway.log" -ForegroundColor Gray
        return $false
    }
}

function Stop-HermesAgent {
    Write-Host "正在停止 Hermes Agent..." -ForegroundColor Yellow
    
    wsl -d $WSL_DISTRO_NAME -u root -e bash -lc @"
        pkill -f "hermes gateway" || true
        echo "Agent 进程已终止"
"@
    
    Start-Sleep -Seconds 1
    
    if (-not (Test-HermesConnection)) {
        Write-Host "✓ Hermes Agent 已停止" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠ Agent 进程仍在运行，尝试强制杀死..." -ForegroundColor Yellow
        wsl -d $WSL_DISTRO_NAME -u root -e bash -lc "pkill -9 -f 'hermes gateway'"
        return $true
    }
}

function Test-HermesConnection {
    # 网络探针：尝试多个连接方式
    $ips = @("127.0.0.1", "localhost")
    
    # 获取 WSL2 内部 IP
    try {
        $wslIp = (wsl -d $WSL_DISTRO_NAME hostname -I 2>/dev/null).Trim().Split()[0]
        if ($wslIp) {
            $ips += $wslIp
        }
    } catch {}
    
    foreach ($ip in $ips) {
        if ([string]::IsNullOrEmpty($ip)) { continue }
        
        try {
            $response = Invoke-WebRequest -Uri "http://${ip}:8000/health" `
                -TimeoutSec 2 -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                return $true
            }
        } catch {
            # 继续尝试下一个 IP
        }
    }
    
    return $false
}

function Get-HermesStatus {
    # 返回 JSON 格式的状态
    
    $running = Test-HermesConnection
    
    # 获取进程信息（在 WSL2 中）
    $psOutput = wsl -d $WSL_DISTRO_NAME ps aux 2>/dev/null | Select-String "hermes gateway"
    
    $status = @{
        running = $running
        process = if ($psOutput) { $true } else { $false }
        apiUrl = "http://127.0.0.1:8000"
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    return $status | ConvertTo-Json -Compress
}

function Restart-HermesAgent {
    Write-Host "正在重启 Hermes Agent..." -ForegroundColor Yellow
    
    Stop-HermesAgent
    Start-Sleep -Seconds 2
    Start-HermesAgent
}

function Restart-WSLNetwork {
    Write-Host "正在重启 WSL2 网络服务..." -ForegroundColor Yellow
    
    wsl --shutdown
    Write-Host "⚠ WSL2 已关闭，自动重启..."
    
    Start-Sleep -Seconds 3
    wsl -d $WSL_DISTRO_NAME hostname  # 触发重启
    
    Write-Host "✓ WSL2 网络已重启" -ForegroundColor Green
}

function Get-HermesLogs {
    param([int]$Lines = 50)
    
    Write-Host "获取最后 $Lines 行日志..." -ForegroundColor Yellow
    
    wsl -d $WSL_DISTRO_NAME tail -n $Lines ~/.hermes/logs/gateway.log 2>/dev/null
}
```

#### install-hermes.ps1
```powershell
[string]$WSL_DISTRO_NAME = "HermesUbuntu"
[string]$HERMES_WSL_HOME = "~/.hermes"

function Initialize-HermesHome {
    Write-Host "初始化 Hermes 主目录..." -ForegroundColor Yellow
    
    wsl -d $WSL_DISTRO_NAME mkdir -p ~/.hermes/logs
    
    Write-Host "✓ 目录结构已创建" -ForegroundColor Green
}

function Configure-ChinaMirrors {
    Write-Host "配置国内镜像源..." -ForegroundColor Yellow
    
    wsl -d $WSL_DISTRO_NAME -u root bash << 'EOF'
# 配置 Ubuntu 源 (清华)
cat > /etc/apt/sources.list << 'SOURCES'
deb https://mirrors.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb https://mirrors.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb https://mirrors.tsinghua.edu.cn/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
SOURCES

apt-get update -qq

# 配置 pip 镜像 (阿里)
mkdir -p ~/.config/pip
cat > ~/.config/pip/pip.conf << 'PIPCFG'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host = mirrors.aliyun.com
PIPCFG

echo "✓ 镜像源已配置"
EOF
    
    Write-Host "✓ 国内镜像源已配置" -ForegroundColor Green
}

function Install-HermesAgent {
    Write-Host "在 WSL2 中安装 Hermes Agent..." -ForegroundColor Yellow
    Write-Host "   这会花费 10-30 分钟，请耐心等待..." -ForegroundColor Gray
    
    wsl -d $WSL_DISTRO_NAME bash << 'EOF'
cd ~/.hermes
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

if [ $? -eq 0 ]; then
    echo "✓ Hermes Agent 安装完成"
else
    echo "✗ 安装失败，请检查网络连接和磁盘空间"
    exit 1
fi
EOF
    
    Write-Host "✓ Hermes Agent 安装完成" -ForegroundColor Green
}
```

---

## 配置系统

### 环境变量文件 (.env)

```bash
# ~/.hermes/.env (WSL2 中)

# 基础配置
HERMES_HOME=~/.hermes
HERMES_DEBUG=false
PYTHON_ENV=production

# 飞书配置
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=secret_xxx
FEISHU_DOMAIN=feishu
FEISHU_CONNECTION_MODE=websocket
FEISHU_ALLOWED_USERS=ou_xxx,ou_yyy

# 微信配置
WEIXIN_ACCOUNT_ID=your-account-id
WEIXIN_TOKEN=your-bot-token
WEIXIN_DM_POLICY=open

# LLM 配置
OPENAI_API_KEY=sk-xxx
OPENAI_MODEL=gpt-4
```

### 配置存储位置

| 位置 | 用途 | 权限 |
|------|------|------|
| `%LOCALAPPDATA%\hermes\` | WSL2 虚拟机和配置 | 用户 |
| `~/.hermes/.env` (WSL2) | 环境变量 | 用户 |
| `~/.hermes/config.yaml` (WSL2) | Hermes 主配置 | 用户 |

---

## 实现进度

### 已完成
- ✅ 项目目录结构设计
- ✅ 技术栈确定
- ✅ UI/UX 设计草图
- ✅ 官方 Hermes Agent 文档研究
- ✅ 飞书配置流程分析
- ✅ 微信配置流程分析

### 进行中
- 🔄 前端 Electron 应用搭建
- 🔄 PowerShell 脚本编写

### 待做
- ⏳ WSL2 管理脚本
- ⏳ Hermes 启动/停止脚本
- ⏳ 飞书配置脚本
- ⏳ 微信配置脚本
- ⏳ Electron 主窗口实现
- ⏳ 聊天框集成
- ⏳ 资源监控实现
- ⏳ exe 打包和发布

---

## 已解决问题

### 问题 1: Windows 上 Hermes 如何运行
**解决**: 使用 WSL2 虚拟机，完全隔离，一键卸载

### 问题 2: 用户不懂技术，怎么配置飞书/微信
**解决**: 集成一键配置界面，自动扫码和保存

### 问题 3: 如何与 Agent 交互
**解决**: 前端集成简单聊天框，无需打开浏览器

### 问题 4: PowerShell 路径转换错误 🔴 (已修正)

**原问题**:
```powershell
# ❌ 错误做法
[string]$HermesHome = "$env:LOCALAPPDATA\hermes"  # Windows 路径: C:\Users\...\AppData\Local\hermes
wsl -d UbuntuHermes -e bash -c "cd $HermesHome && hermes gateway"  # Linux 无法识别此路径
```

**解决方案**:
```powershell
# ✅ 正确做法
[string]$HERMES_WSL_HOME = "~/.hermes"  # 总是使用 Linux 路径
wsl -d HermesUbuntu -u root -e bash -lc "cd ~/.hermes && ..."
```

**关键规则**:
- 所有 WSL2 操作使用 Linux 路径 `~/.hermes`
- 不要混合 Windows 路径和 Linux 路径
- 如需转换，使用 `wsl wslpath "C:\..."`

### 问题 5: 长期运行进程导致 UI 卡死 🔴 (已修正)

**原问题**:
```powershell
# ❌ 错误做法（会阻塞 UI）
wsl -d UbuntuHermes bash -c "cd ~/.hermes && hermes gateway"
# hermes gateway 是持续运行进程，PowerShell 会一直等待，导致 UI 卡死
```

**解决方案**:
```powershell
# ✅ 正确做法（后台启动）
wsl -d HermesUbuntu -u root -e bash -lc @"
    mkdir -p ~/.hermes/logs
    nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &
"@
# 使用 nohup 后台运行，立即返回，不阻塞 UI
```

**关键点**:
- 使用 `nohup ... &` 后台运行
- 日志输出到文件 `> ~/.hermes/logs/gateway.log`
- 使用 `bash -lc` 而不是 `bash -c`（加载 shell 配置，支持 alias 等）

### 问题 6: WSL2 发行版名称混乱 🔴 (已修正)

**原问题**:
```powershell
# ❌ 不一致
install-hermes.ps1: wsl --install -d Ubuntu
manage-hermes.ps1:  wsl -d UbuntuHermes
# 两个脚本用的发行版不同，导致启动失败
```

**解决方案**:
```powershell
# ✅ 全局统一命名
[string]$WSL_DISTRO_NAME = "HermesUbuntu"

# 所有脚本统一使用此常量
wsl --install -d $WSL_DISTRO_NAME       # 安装
wsl -d $WSL_DISTRO_NAME ls /            # 执行命令
wsl --unregister $WSL_DISTRO_NAME       # 卸载
```

**规范**:
- 在每个脚本开头定义全局常量
- 所有 WSL2 操作引用该常量
- 避免硬编码发行版名称

---

## 下一步计划

### 第 1 周 (环境搭建 + 基础检查)
- [ ] 创建 Electron 项目框架 (`npm create electron-app hermes_launcher`)
- [ ] 实现权限检测 + sudo-prompt 集成
- [ ] 编写 setup-wsl2.ps1 (虚拟化检查 + 磁盘检查)
- [ ] 编写 install-hermes.ps1 (国内镜像源 + 后台下载)
- [ ] **关键**: 验证 WSL2 发行版名称统一 (`HermesUbuntu`)

### 第 2 周 (启动/停止 + 状态监控)
- [ ] 编写 manage-hermes.ps1 (后台启动 + 网络探针)
- [ ] 实现 Electron 主窗口 UI 框架
- [ ] 实现健康检查循环 (每 5 秒)
- [ ] 实现 [重启 Agent] / [重启网络] 按钮
- [ ] **关键**: 测试 UI 不卡死 (后台启动验证)

### 第 3 周 (配置系统)
- [ ] 编写 config-proxy.ps1 (代理配置 + 透传)
- [ ] Settings 页面：代理配置界面
- [ ] 编写 config-feishu.ps1
- [ ] 编写 config-weixin.ps1
- [ ] **关键**: 微信配置前显示大号警告框

### 第 4 周 (聊天框 + 资源监控)
- [ ] 实现简单聊天框 (与 Agent 8000 端口通信)
- [ ] 资源监控显示 (内存/CPU)
- [ ] 卸载功能 + 数据导出选项
- [ ] 整体集成测试

### 第 5 周+ (打包 + Polish)
- [ ] exe 打包 (electron-builder)
- [ ] 系统托盘支持
- [ ] 自动更新机制
- [ ] 最终测试和发布

---

## ⚠️ 最高优先级检查清单

这些内容**必须在开发中反复验证**，否则会导致应用完全无法使用：

- [ ] **WSL2 路径**: 所有 WSL 命令使用 Linux 路径 `~/.hermes`，不混合 Windows 路径
- [ ] **后台启动**: `hermes gateway` 使用 `nohup ... &` 后台运行，验证 UI 不卡死
- [ ] **发行版统一**: 全局变量 `$WSL_DISTRO_NAME = "HermesUbuntu"` 在所有脚本中使用
- [ ] **网络探针**: `Get-HermesStatus` 尝试多个 IP (127.0.0.1, localhost, WSL2 内部 IP)
- [ ] **日志输出**: 所有 WSL 命令的输出都重定向到 `~/.hermes/logs/`
- [ ] **错误处理**: 每个 PowerShell 函数都有 try-catch，返回明确的成功/失败标志

---

## 关键决策记录

### 为什么选 Electron？
- ✅ 零依赖：用户不需要装 .NET、Python、Java 运行时
- ✅ 快速开发：JavaScript/HTML/CSS，上手快
- ✅ 跨平台：虽然目前只做 Windows，但将来可扩展

### 为什么用 WSL2 而不是 Docker/Native Windows？
- ✅ 官方推荐：Hermes 官网明确说"Requires WSL2 on Windows"
- ✅ 完全隔离：系统和 Agent 数据完全分离
- ✅ 一键卸载：删除虚拟机 = 彻底删除 Agent
- ✅ 性能：比虚拟机更轻量，比 native 更稳定

### 为什么用 PowerShell 脚本？
- ✅ Windows 原生：无需额外依赖
- ✅ WSL2 集成：PowerShell 可以直接调用 `wsl` 命令
- ✅ 维护简单：用户可以看懂和修改脚本

---

## 联系方式和支持

**GitHub Issues**: [报告 bug](https://github.com/NousResearch/hermes-agent/issues)  
**Discord**: [加入社区](https://discord.gg/NousResearch)  
**官方文档**: [https://hermes-agent.nousresearch.com/](https://hermes-agent.nousresearch.com/)

---

*本文档每周更新，记录项目进度和决策。*
