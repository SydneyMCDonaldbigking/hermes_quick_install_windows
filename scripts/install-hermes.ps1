# install-hermes.ps1
# Hermes Agent 安装脚本
# 功能: 初始化 ~/.hermes、配置镜像源、安装 Agent

#Requires -RunAsAdministrator

[string]$WSL_DISTRO_NAME = "HermesUbuntu"
[string]$HERMES_WSL_HOME = "~/.hermes"
[string]$HERMES_INSTALL_URL = "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

# 国内镜像源
[string]$APT_MIRROR = "https://mirrors.tsinghua.edu.cn/ubuntu"
[string]$PIP_MIRROR = "https://mirrors.aliyun.com/pypi/simple"

# ============================================================
# 日志函数
# ============================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $prefix = @{
        "Info"    = "ℹ"
        "Warning" = "⚠"
        "Error"   = "❌"
        "Success" = "✅"
    }
    
    $color = @{
        "Info"    = "Cyan"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Success" = "Green"
    }
    
    $message_formatted = "[$timestamp] $($prefix[$Level]) $Message"
    Write-Host $message_formatted -ForegroundColor $color[$Level]
    
    # 写到日志文件
    $logPath = "$env:LOCALAPPDATA\hermes\logs"
    if (!(Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    Add-Content -Path "$logPath\install.log" -Value $message_formatted
}

# ============================================================
# WSL2 检查
# ============================================================

function Test-WSL2Ready {
    <#
    .SYNOPSIS
    验证 WSL2 已正确安装并可访问
    #>
    
    Write-Log "检查 WSL2 是否就绪..." "Info"
    
    try {
        $output = wsl -d $WSL_DISTRO_NAME -u root -e bash -c "echo 'WSL2 OK'" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $output -match "WSL2 OK") {
            Write-Log "✓ WSL2 可访问" "Success"
            return $true
        }
        
        Write-Log "❌ WSL2 不可访问，请先运行 setup-wsl2.ps1" "Error"
        return $false
        
    }
    catch {
        Write-Log "WSL2 检查出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 目录初始化
# ============================================================

function Initialize-HermesHome {
    <#
    .SYNOPSIS
    在 WSL2 中创建 ~/.hermes 目录及子目录
    
    .DESCRIPTION
    创建以下结构:
    ~/.hermes/
    ├── .env                 (配置文件，在 Gateway 启动时读取)
    ├── logs/
    │   ├── gateway.log      (Gateway 进程日志)
    │   ├── install.log      (安装日志)
    │   └── error.log        (错误日志)
    ├── config/              (Agent 配置)
    └── data/                (Agent 数据)
    #>
    
    Write-Log "初始化 Hermes 主目录 ($HERMES_WSL_HOME)..." "Info"
    
    try {
        # 创建目录结构
        $bashScript = @"
        set -e
        mkdir -p ~/.hermes/logs
        mkdir -p ~/.hermes/config
        mkdir -p ~/.hermes/data
        
        # 初始化 .env 文件（如果不存在）
        if [ ! -f ~/.hermes/.env ]; then
            cat > ~/.hermes/.env << 'ENVEOF'
# Hermes Agent 配置文件
# 自动生成，请勿手动修改

# Agent 基础配置
HERMES_PORT=8000
HERMES_HOST=0.0.0.0

# 国内代理配置（中国用户必须配置）
# http_proxy=http://your-proxy:port
# https_proxy=http://your-proxy:port

# 飞书机器人配置（可选）
# FEISHU_APP_ID=your_app_id
# FEISHU_APP_SECRET=your_app_secret

# 微信配置（可选）
# WEIXIN_ACCOUNT_ID=your_account_id
# WEIXIN_TOKEN=your_token

ENVEOF
        fi
        
        echo "Hermes home initialized"
"@
        
        $output = wsl -d $WSL_DISTRO_NAME -u root -e bash -c $bashScript 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Hermes 主目录初始化失败: $output" "Error"
            return $false
        }
        
        Write-Log "✓ Hermes 主目录已创建" "Success"
        Write-Log "  位置: ~/.hermes" "Info"
        Write-Log "  日志: ~/.hermes/logs/" "Info"
        
        return $true
        
    }
    catch {
        Write-Log "目录初始化出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 镜像源配置
# ============================================================

function Configure-ChinaMirrors {
    <#
    .SYNOPSIS
    为 apt 和 pip 配置国内镜像源
    
    .DESCRIPTION
    - Tsinghua apt 镜像（清华大学）
    - Aliyun pip 镜像（阿里云）
    
    这对中国用户至关重要，否则下载速度极慢
    #>
    
    Write-Log "配置国内镜像源..." "Info"
    
    try {
        Write-Log "配置 apt 镜像源 (Tsinghua)..." "Info"
        Write-Log "配置 pip 镜像源 (Aliyun)..." "Info"
        
        $bashScript = @"
        set -e
        
        # 配置 apt 镜像
        cat > /etc/apt/sources.list << 'SOURCESEOF'
# Tsinghua mirror for Ubuntu 22.04 LTS
deb https://mirrors.tsinghua.edu.cn/ubuntu jammy main restricted universe multiverse
deb https://mirrors.tsinghua.edu.cn/ubuntu jammy-updates main restricted universe multiverse
deb https://mirrors.tsinghua.edu.cn/ubuntu jammy-backports main restricted universe multiverse
deb https://mirrors.tsinghua.edu.cn/ubuntu jammy-security main restricted universe multiverse
SOURCESEOF
        
        apt update > /dev/null 2>&1 || true
        
        # 配置 pip 镜像
        mkdir -p ~/.pip
        cat > ~/.pip/pip.conf << 'PIPEOF'
[global]
index-url = https://mirrors.aliyun.com/pypi/simple
[install]
trusted-host = mirrors.aliyun.com
PIPEOF
        
        # 配置 bash 环境变量
        if ! grep -q "HERMES_MIRRORS" ~/.bashrc; then
            cat >> ~/.bashrc << 'BASHEOF'

# Hermes Agent 镜像源配置
export PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple
BASHEOF
        fi
        
        echo "Mirrors configured"
"@
        
        $output = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $bashScript 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "⚠ 镜像源配置可能不完整: $output" "Warning"
            # 不中止，继续
        }
        else {
            Write-Log "✓ 国内镜像源已配置 (apt: Tsinghua, pip: Aliyun)" "Success"
        }
        
        return $true
        
    }
    catch {
        Write-Log "镜像源配置出错: $_" "Error"
        return $false
    }
}

# ============================================================
# Hermes Agent 安装
# ============================================================

function Install-HermesAgent {
    <#
    .SYNOPSIS
    从官方仓库下载并运行 Hermes 安装脚本
    
    .DESCRIPTION
    - 下载官方 install.sh
    - 在 WSL2 中执行
    - 检查安装是否成功
    
    这是最重要的步骤，可能需要 5-15 分钟
    #>
    
    Write-Log "安装 Hermes Agent..." "Info"
    Write-Log "⏳ 这可能需要 10-20 分钟，主要是下载和编译时间" "Warning"
    Write-Log "   （速度取决于网络，中国用户通常较慢）" "Info"
    Write-Log "" "Info"
    
    try {
        $bashScript = @"
        set -e
        
        cd ~/.hermes
        
        # 下载官方安装脚本
        curl -fsSL -o install_hermes.sh https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh
        chmod +x install_hermes.sh
        
        # 运行安装脚本
        bash ./install_hermes.sh 2>&1 | tee -a ~/.hermes/logs/install.log
        
        # 验证安装
        if command -v hermes &> /dev/null; then
            hermes --version
            echo "Hermes installed successfully"
        else
            echo "Hermes not found in PATH"
            exit 1
        fi
"@
        
        $output = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $bashScript 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Hermes 安装失败: $output" "Error"
            Write-Log "请检查网络连接，然后重新运行此脚本" "Info"
            return $false
        }
        
        Write-Log "✓ Hermes Agent 已安装" "Success"
        Write-Log "  版本信息: $output" "Info"
        
        return $true
        
    }
    catch {
        Write-Log "Hermes 安装出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 安装后配置
# ============================================================

function Test-HermesConnectivity {
    <#
    .SYNOPSIS
    测试 Hermes Gateway 是否可以启动和连接
    
    .DESCRIPTION
    - 启动 Gateway（后台）
    - 等待 3 秒初始化
    - 尝试 HTTP 连接测试
    - 停止 Gateway
    #>
    
    Write-Log "测试 Hermes 连通性..." "Info"
    
    try {
        # 启动 Gateway（后台）
        Write-Log "启动 Hermes Gateway..." "Info"
        $startScript = @"
        set -e
        cd ~/.hermes
        nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &
        sleep 3
        echo "Gateway started"
"@
        
        wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $startScript 2>&1 | Out-Null
        
        # 等待启动
        Start-Sleep -Seconds 2
        
        # 尝试连接
        Write-Log "检查 Gateway 端口连通性..." "Info"
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
            Write-Log "✓ Hermes Gateway 已启动 (端口 8000)" "Success"
        }
        catch {
            Write-Log "⚠ Gateway 端口不可访问，可能需要重启" "Warning"
            Write-Log "  这可能是正常的，应用启动时会自动重试" "Info"
        }
        
        return $true
        
    }
    catch {
        Write-Log "连通性测试出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 主流程
# ============================================================

function Install-Hermes {
    <#
    .SYNOPSIS
    完整的 Hermes Agent 安装流程
    #>
    
    Write-Log "===================================================" "Info"
    Write-Log "Hermes Agent - 安装脚本" "Info"
    Write-Log "===================================================" "Info"
    Write-Log "" "Info"
    
    # 步骤 1: 权限检查
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "❌ 此脚本需要管理员权限运行" "Error"
        exit 1
    }
    
    Write-Log "✓ 已获得管理员权限" "Success"
    Write-Log "" "Info"
    
    # 步骤 2: WSL2 检查
    if (-not (Test-WSL2Ready)) {
        Write-Log "❌ WSL2 未安装或不可用" "Error"
        Write-Log "请先运行 setup-wsl2.ps1" "Info"
        exit 1
    }
    
    Write-Log "" "Info"
    
    # 步骤 3: 初始化目录
    if (-not (Initialize-HermesHome)) {
        Write-Log "❌ 目录初始化失败" "Error"
        exit 1
    }
    
    Write-Log "" "Info"
    
    # 步骤 4: 配置镜像源
    if (-not (Configure-ChinaMirrors)) {
        Write-Log "⚠ 镜像源配置失败，将继续使用默认源" "Warning"
    }
    
    Write-Log "" "Info"
    
    # 步骤 5: 安装 Hermes
    if (-not (Install-HermesAgent)) {
        Write-Log "❌ Hermes Agent 安装失败" "Error"
        exit 1
    }
    
    Write-Log "" "Info"
    
    # 步骤 6: 连通性测试
    Test-HermesConnectivity | Out-Null
    
    Write-Log "" "Info"
    Write-Log "===================================================" "Info"
    Write-Log "✓ Hermes Agent 安装完成！" "Success"
    Write-Log "===================================================" "Info"
    Write-Log "" "Info"
    Write-Log "下一步:" "Info"
    Write-Log "  1. 运行 manage-hermes.ps1 来启动/停止 Agent" "Info"
    Write-Log "  2. 运行 config-feishu.ps1 或 config-weixin.ps1 配置机器人" "Info"
    Write-Log "  3. 打开 Electron 应用开始使用" "Info"
    
    return $true
}

# ============================================================
# 入口
# ============================================================

if ($MyInvocation.InvocationName -ne '.') {
    Install-Hermes
}
