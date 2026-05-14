# config-weixin.ps1
# 微信机器人配置脚本
# 功能：帮助用户配置微信账号，显示大号警告

#Requires -RunAsAdministrator

[string]$WSL_DISTRO_NAME = "HermesUbuntu"
[string]$HERMES_WSL_HOME = "~/.hermes"

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
    Add-Content -Path "$logPath\weixin-config.log" -Value $message_formatted
}

# ============================================================
# 微信账号警告（关键！）
# ============================================================

function Show-WechatWarning {
    <#
    .SYNOPSIS
    显示关于微信账号使用的重要警告
    
    .DESCRIPTION
    这是第一个很多用户会犯的错误：
    
    扫码登录的微信账号将被锁定为"机器人身份"，无法用于个人聊天。
    这是 WeChat 的设计限制，无法绕过。
    #>
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                    ⚠️  重要警告  ⚠️                            ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "【微信账号将被锁定为机器人身份】" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "您将用来登录 Hermes 的微信账号会被微信官方识别为'机器人'账号。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "这意味着:" -ForegroundColor White
    Write-Host "  ❌ 无法用此账号进行正常的个人聊天" -ForegroundColor Red
    Write-Host "  ❌ 无法发送和接收个人消息" -ForegroundColor Red
    Write-Host "  ❌ 可能被微信限制或冻结" -ForegroundColor Red
    Write-Host "  ✓ 只能用来接收和发送 Hermes 相关的消息" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "【建议方案】" -ForegroundColor Cyan
    Write-Host "1. 使用一个专门的微信小号（不常用的账号）" -ForegroundColor Cyan
    Write-Host "2. 不要用主力微信账号" -ForegroundColor Cyan
    Write-Host "3. 做好心理准备账号可能被冻结" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "【恢复方式】" -ForegroundColor Yellow
    Write-Host "如果账号被冻结，需要：" -ForegroundColor Yellow
    Write-Host "  1. 等待 24-48 小时自动解冻" -ForegroundColor Yellow
    Write-Host "  2. 用其他设备登录此账号一次" -ForegroundColor Yellow
    Write-Host "  3. 联系微信客服申请解冻" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "【替代方案】" -ForegroundColor Green
    Write-Host "如果您不想冒险，建议使用飞书机器人代替。" -ForegroundColor Green
    Write-Host "飞书不需要扫码，配置更安全简单。" -ForegroundColor Green
    Write-Host ""
}

# ============================================================
# 微信配置流程
# ============================================================

function Configure-WechatBot {
    <#
    .SYNOPSIS
    配置微信机器人
    
    .DESCRIPTION
    1. 显示警告
    2. 要求确认理解
    3. 获取二维码或手动配置
    4. 测试连接
    #>
    
    Write-Log "========================================" "Info"
    Write-Log "微信机器人配置向导" "Info"
    Write-Log "========================================" "Info"
    Write-Log "" "Info"
    
    # 第 1 步：显示警告
    Show-WechatWarning
    
    # 第 2 步：要求确认
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  请确认您理解上述风险并决定继续                              ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    $confirmation = Read-Host "我理解风险，准备使用微信小号 (请输入 'yes' 继续，或按 Enter 取消)"
    
    if ($confirmation -ne "yes") {
        Write-Log "用户取消了微信配置" "Warning"
        return $false
    }
    
    Write-Log "" "Info"
    Write-Log "【微信登录步骤】" "Info"
    Write-Host @"
    
1. 打开你的微信应用
2. 用这个微信号的二维码登录（下面的二维码或网页）
3. 扫描后会看到确认提示
4. 点击确认完成登录

【登录地址】
    
"@
    
    # 第 3 步：生成二维码（或提供登录链接）
    Write-Log "生成二维码..." "Info"
    
    $qrScript = @"
    set -e
    
    # 检查 Hermes 是否已安装
    if ! command -v hermes &> /dev/null; then
        echo "hermes_not_installed"
        exit 0
    fi
    
    # 启动登录流程
    # 这会生成一个 QR 码 URL
    timeout 30 hermes weixin login --qr-terminal 2>&1 || echo "timeout"
"@
    
    try {
        $result = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $qrScript 2>&1
        
        if ($result -match "hermes_not_installed") {
            Write-Log "⚠ Hermes 未安装，请先运行 install-hermes.ps1" "Warning"
            return $false
        }
        
        # 显示二维码
        if ($result -match "http") {
            Write-Host "请访问此链接扫描二维码:" -ForegroundColor Green
            Write-Host $result -ForegroundColor Cyan
        }
        else {
            Write-Host "✓ 二维码已生成" -ForegroundColor Green
        }
    }
    catch {
        Write-Log "生成二维码失败: $_" "Error"
        # 继续，提供手动输入选项
    }
    
    Write-Host ""
    
    # 第 4 步：确认登录完成
    $loginConfirm = Read-Host "请在微信中扫描并确认登录。完成后按 Enter 继续"
    
    # 第 5 步：验证配置
    Write-Log "验证微信配置..." "Info"
    
    $verifyScript = @"
    set -e
    
    # 检查微信登录状态
    WEIXIN_CONFIG=~/.hermes/weixin.json
    
    if [ -f "\$WEIXIN_CONFIG" ]; then
        echo "login_success"
    else
        echo "login_failed"
    fi
"@
    
    try {
        $verifyResult = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $verifyScript 2>&1
        
        if ($verifyResult -match "login_success") {
            Write-Log "✓ 微信登录成功" "Success"
            
            # 保存配置标记
            $envPath = "$env:LOCALAPPDATA\hermes\.env"
            
            if (!(Test-Path (Split-Path $envPath))) {
                New-Item -ItemType Directory -Path (Split-Path $envPath) -Force | Out-Null
            }
            
            # 更新 .env
            $envContent = if (Test-Path $envPath) { Get-Content $envPath -Raw } else { "" }
            
            if ($envContent -match "WEIXIN_ENABLED") {
                $envContent = $envContent -replace "WEIXIN_ENABLED=.*", "WEIXIN_ENABLED=true"
            }
            else {
                $envContent += "`nWEXIN_ENABLED=true"
            }
            
            Set-Content -Path $envPath -Value $envContent -Encoding UTF8
            
            Write-Log "✓ 配置已保存" "Success"
            return $true
        }
        else {
            Write-Log "❌ 微信登录失败，请重试" "Error"
            return $false
        }
    }
    catch {
        Write-Log "验证失败: $_" "Error"
        return $false
    }
}

function Show-AccountWarning {
    <#
    .SYNOPSIS
    显示账号被冻结时的恢复指南
    #>
    
    Write-Host ""
    Write-Host "【如果微信账号被冻结】" -ForegroundColor Red
    Write-Host ""
    Write-Host "这通常发生在：" -ForegroundColor Yellow
    Write-Host "  • 扫码登录后的 24-48 小时内" -ForegroundColor Yellow
    Write-Host "  • 多次尝试登录失败后" -ForegroundColor Yellow
    Write-Host "  • 频繁的自动化操作" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "解冻步骤：" -ForegroundColor Cyan
    Write-Host "  1. 用手机微信打开此链接: https://weixin.qq.com/cgi-bin/readtemplate?t=safe/index" -ForegroundColor Cyan
    Write-Host "  2. 点击'继续使用'完成身份验证" -ForegroundColor Cyan
    Write-Host "  3. 解冻成功后，重新尝试配置" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# 主程序
# ============================================================

function Initialize-WechatConfig {
    Write-Log "微信配置初始化脚本启动" "Info"
    
    # 权限检查
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "此脚本需要管理员权限" "Error"
        exit 1
    }
    
    # 配置微信
    if (Configure-WechatBot) {
        Write-Log "" "Info"
        
        Show-AccountWarning
        
        Write-Log "" "Info"
        Write-Log "========================================" "Info"
        Write-Log "✓ 微信配置完成！" "Success"
        Write-Log "========================================" "Info"
        Write-Log "" "Info"
        Write-Log "下一步：启动 Gateway，Hermes 将通过微信与您通信" "Info"
        
        return @{ success = $true; message = "WeChat configured" } | ConvertTo-Json
    }
    else {
        Write-Log "" "Info"
        Write-Log "微信配置失败或被取消" "Warning"
        Show-AccountWarning
        return @{ success = $false; message = "Configuration cancelled or failed" } | ConvertTo-Json
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-WechatConfig
}
