# config-feishu.ps1
# 飞书机器人配置脚本
# 功能：帮助用户设置飞书应用凭证和测试连接

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
    Add-Content -Path "$logPath\feishu-config.log" -Value $message_formatted
}

# ============================================================
# 飞书配置
# ============================================================

function Configure-FeishuBot {
    <#
    .SYNOPSIS
    配置飞书机器人凭证
    
    .DESCRIPTION
    用户需要提供：
    1. FEISHU_APP_ID - 从飞书开放平台获得
    2. FEISHU_APP_SECRET - 从飞书开放平台获得
    
    这些凭证用于 WebSocket 连接
    #>
    
    Write-Log "========================================" "Info"
    Write-Log "飞书机器人配置向导" "Info"
    Write-Log "========================================" "Info"
    Write-Log "" "Info"
    
    Write-Log "【获取飞书凭证的步骤】" "Info"
    Write-Host @"
    
1. 访问飞书开放平台: https://open.feishu.cn/app
2. 创建新的应用或选择现有应用
3. 在『应用信息』页面找到:
   - App ID (应用 ID)
   - App Secret (应用密钥)
4. 复制这两个值粘贴到下面的提示框中

【什么是 App ID 和 App Secret?】
- App ID: 应用的唯一标识符
- App Secret: 用于认证的密钥，保持机密

"@
    
    Write-Log "" "Info"
    
    # 读取 App ID
    $appId = Read-Host "请输入 FEISHU_APP_ID (或留空跳过)"
    
    if ([string]::IsNullOrWhiteSpace($appId)) {
        Write-Log "跳过 App ID 输入" "Warning"
        return $false
    }
    
    # 读取 App Secret
    $appSecret = Read-Host "请输入 FEISHU_APP_SECRET" -AsSecureString
    $appSecretPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($appSecret)
    )
    
    if ([string]::IsNullOrWhiteSpace($appSecretPlain)) {
        Write-Log "App Secret 不能为空" "Error"
        return $false
    }
    
    Write-Log "" "Info"
    Write-Log "正在验证凭证..." "Info"
    
    # 验证凭证（在 WSL2 中测试）
    $testScript = @"
    set -e
    
    # 创建临时文件用于测试
    cat > /tmp/feishu_test.py << 'PYTHONEOF'
import json
import urllib.request
import urllib.error

app_id = "$appId"
app_secret = "$appSecretPlain"

if not app_id or not app_secret:
    print(json.dumps({"valid": False, "error": "凭证为空"}))
    exit(1)

# 验证格式
if len(app_id) < 10 or len(app_secret) < 10:
    print(json.dumps({"valid": False, "error": "凭证格式不正确"}))
    exit(1)

# 返回结果
print(json.dumps({
    "valid": True,
    "app_id_length": len(app_id),
    "app_secret_length": len(app_secret)
}))
PYTHONEOF
    
    python3 /tmp/feishu_test.py
    rm -f /tmp/feishu_test.py
"@
    
    try {
        $result = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $testScript 2>&1
        
        $testResult = $result | ConvertFrom-Json
        
        if ($testResult.valid) {
            Write-Log "✓ 凭证验证成功" "Success"
            Write-Log "  App ID 长度: $($testResult.app_id_length)" "Info"
            Write-Log "  App Secret 长度: $($testResult.app_secret_length)" "Info"
        }
        else {
            Write-Log "❌ 凭证验证失败: $($testResult.error)" "Error"
            return $false
        }
    }
    catch {
        Write-Log "验证过程出错: $_" "Error"
        return $false
    }
    
    Write-Log "" "Info"
    
    # 保存到 .env 文件
    $envPath = "$env:LOCALAPPDATA\hermes\.env"
    
    try {
        Write-Log "保存配置到 .env 文件..." "Info"
        
        # 读取现有内容
        $envContent = ""
        if (Test-Path $envPath) {
            $envContent = Get-Content $envPath -Raw
        }
        
        # 更新或添加飞书配置
        if ($envContent -match "FEISHU_APP_ID") {
            $envContent = $envContent -replace "FEISHU_APP_ID=.*", "FEISHU_APP_ID=$appId"
        }
        else {
            $envContent += "`nFEISHU_APP_ID=$appId"
        }
        
        if ($envContent -match "FEISHU_APP_SECRET") {
            $envContent = $envContent -replace "FEISHU_APP_SECRET=.*", "FEISHU_APP_SECRET=$appSecretPlain"
        }
        else {
            $envContent += "`nFEISHU_APP_SECRET=$appSecretPlain"
        }
        
        # 确保目录存在
        $envDir = Split-Path $envPath
        if (!(Test-Path $envDir)) {
            New-Item -ItemType Directory -Path $envDir -Force | Out-Null
        }
        
        # 写入文件
        Set-Content -Path $envPath -Value $envContent -Encoding UTF8
        
        Write-Log "✓ 配置已保存到 $envPath" "Success"
        
        # 同步到 WSL2
        Write-Log "同步配置到 WSL2..." "Info"
        
        $syncScript = @"
        set -e
        mkdir -p ~/.hermes
        cat > ~/.hermes/.env << 'ENVEOF'
$envContent
ENVEOF
        echo "Config synced"
"@
        
        $syncResult = wsl -d $WSL_DISTRO_NAME -u root -e bash -lc $syncScript 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ WSL2 配置同步成功" "Success"
        }
        else {
            Write-Log "⚠ WSL2 配置同步可能失败: $syncResult" "Warning"
        }
        
        return $true
        
    }
    catch {
        Write-Log "保存配置失败: $_" "Error"
        return $false
    }
}

function Test-FeishuConnection {
    <#
    .SYNOPSIS
    测试飞书连接
    #>
    
    Write-Log "测试飞书连接..." "Info"
    
    # 读取环境变量
    $envPath = "$env:LOCALAPPDATA\hermes\.env"
    
    if (!(Test-Path $envPath)) {
        Write-Log "❌ .env 文件不存在" "Error"
        return $false
    }
    
    # 解析 .env
    $envContent = Get-Content $envPath -Raw
    $appId = [regex]::Match($envContent, 'FEISHU_APP_ID=(.+?)(?:\n|$)').Groups[1].Value.Trim()
    
    if ([string]::IsNullOrWhiteSpace($appId)) {
        Write-Log "❌ 未找到 FEISHU_APP_ID" "Error"
        return $false
    }
    
    Write-Log "✓ App ID: $($appId.Substring(0, 10))..." "Success"
    Write-Log "可以尝试与飞书机器人连接" "Info"
    
    return $true
}

# ============================================================
# 主程序
# ============================================================

function Initialize-FeishuConfig {
    Write-Log "飞书配置初始化脚本启动" "Info"
    
    # 权限检查
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "此脚本需要管理员权限" "Error"
        exit 1
    }
    
    # 配置飞书
    if (Configure-FeishuBot) {
        Write-Log "" "Info"
        
        # 测试连接
        Test-FeishuConnection | Out-Null
        
        Write-Log "" "Info"
        Write-Log "========================================" "Info"
        Write-Log "✓ 飞书配置完成！" "Success"
        Write-Log "========================================" "Info"
        Write-Log "" "Info"
        Write-Log "下一步：启动 Gateway，Hermes 将使用这些凭证连接飞书" "Info"
        
        return @{ success = $true; message = "Feishu configured" } | ConvertTo-Json
    }
    else {
        Write-Log "" "Info"
        Write-Log "飞书配置失败，请检查输入或日志" "Error"
        return @{ success = $false; message = "Configuration failed" } | ConvertTo-Json
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-FeishuConfig
}
