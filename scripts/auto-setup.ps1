# auto-setup.ps1
# 自动初始化脚本 - 检查并安装 WSL2 + Hermes
# 这是一个幂等脚本，可以安全地重复运行

#Requires -RunAsAdministrator

[string]$WSL_DISTRO_NAME = "Ubuntu-22.04"

# ============================================================
# 颜色输出
# ============================================================

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Error", "Warning")]
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Info"    = "Cyan"
        "Success" = "Green"
        "Error"   = "Red"
        "Warning" = "Yellow"
    }
    
    $icons = @{
        "Info"    = "ℹ"
        "Success" = "✓"
        "Error"   = "✗"
        "Warning" = "⚠"
    }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $($icons[$Type]) $Message" -ForegroundColor $colors[$Type]
}

# ============================================================
# 返回 JSON 格式的结果
# ============================================================

function Return-Result {
    param(
        [bool]$Success,
        [string]$Status,
        [string]$Message = ""
    )
    
    $result = @{
        success = $Success
        status  = $Status
        message = $Message
        timestamp = (Get-Date -Format "o")
    }
    
    Write-Output (ConvertTo-Json $result -Compress)
}

# ============================================================
# 检查 WSL2 是否已安装
# ============================================================

function Test-WSL2Installed {
    Write-Status "检查 WSL2 安装状态..." "Info"
    
    try {
        # 方法 1: 检查 wsl 命令
        $wsl = Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wsl) {
            Write-Status "WSL2 未安装" "Warning"
            return $false
        }
        
        # 方法 2: 检查是否有 Ubuntu-22.04 发行版
        # wsl --list 在部分环境下输出 UTF-16，需去掉空字符再匹配
        $distros = (wsl --list --quiet 2>&1 | Out-String) -replace "`0", ""
        if ($distros -match $WSL_DISTRO_NAME) {
            Write-Status "✓ WSL2 已安装 ($WSL_DISTRO_NAME)" "Success"
            return $true
        }
        
        Write-Status "WSL2 已安装但缺少 $WSL_DISTRO_NAME 发行版" "Warning"
        return $false
    }
    catch {
        Write-Status "检查 WSL2 出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 检查 Hermes 是否已安装
# ============================================================

function Test-HermesInstalled {
    Write-Status "检查 Hermes 安装状态..." "Info"
    
    try {
        if (-not (Test-WSL2Installed)) {
            Write-Status "WSL2 未就绪，跳过 Hermes 检查" "Warning"
            return $false
        }
        
        # 在 WSL2 中检查 hermes 命令是否存在
        $output = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc "command -v hermes 2>&1" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $output -match "hermes") {
            Write-Status "✓ Hermes 已安装" "Success"
            return $true
        }
        
        Write-Status "Hermes 未安装" "Warning"
        return $false
    }
    catch {
        Write-Status "检查 Hermes 出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 执行 PowerShell 脚本（from main.ps1）
# ============================================================

function Execute-Script {
    param(
        [string]$ScriptName,
        [string]$Command = ""
    )
    
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $fullPath = Join-Path $scriptPath "$ScriptName.ps1"
    
    if (-not (Test-Path $fullPath)) {
        Write-Status "脚本不存在: $fullPath" "Error"
        return $false
    }
    
    Write-Status "执行脚本: $ScriptName" "Info"
    
    try {
        $psCommand = if ($Command) {
            "powershell -NoProfile -ExecutionPolicy Bypass -File `"$fullPath`" `"$Command`""
        }
        else {
            "powershell -NoProfile -ExecutionPolicy Bypass -File `"$fullPath`""
        }
        
        & cmd.exe /s /c $psCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✓ $ScriptName 执行成功" "Success"
            return $true
        }
        else {
            Write-Status "❌ $ScriptName 执行失败 (代码: $LASTEXITCODE)" "Error"
            return $false
        }
    }
    catch {
        Write-Status "执行脚本出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 主初始化流程
# ============================================================

function Initialize-Hermes {
    Write-Status "开始 Hermes 自动初始化..." "Info"
    Write-Host ""
    
    # 步骤 1: 检查和安装 WSL2
    if (-not (Test-WSL2Installed)) {
        Write-Status "开始安装 WSL2..." "Warning"
        
        if (-not (Execute-Script "setup-wsl2")) {
            Return-Result $false "wsl2_setup_failed" "WSL2 安装失败"
            exit 1
        }
        
        # 重新检查
        Start-Sleep -Seconds 3
        if (-not (Test-WSL2Installed)) {
            Return-Result $false "wsl2_setup_failed" "WSL2 安装后仍未就绪"
            exit 1
        }
    }
    
    Write-Status "✓ WSL2 已就绪" "Success"
    Write-Host ""
    
    # 步骤 2: 检查和安装 Hermes
    if (-not (Test-HermesInstalled)) {
        Write-Status "开始安装 Hermes Agent..." "Warning"
        
        if (-not (Execute-Script "install-hermes")) {
            Return-Result $false "hermes_setup_failed" "Hermes 安装失败"
            exit 1
        }
        
        # 重新检查
        Start-Sleep -Seconds 3
        if (-not (Test-HermesInstalled)) {
            Return-Result $false "hermes_setup_failed" "Hermes 安装后未找到"
            exit 1
        }
    }
    
    Write-Status "✓ Hermes 已就绪" "Success"
    Write-Host ""
    
    # 完成
    Write-Status "================================================" "Info"
    Write-Status "✓ 初始化完成！所有组件已准备就绪" "Success"
    Write-Status "================================================" "Info"
    Write-Host ""
    
    Return-Result $true "ready" "初始化完成，所有组件已安装"
}

# ============================================================
# 执行
# ============================================================

Initialize-Hermes
