# manage-hermes.ps1
# Hermes Agent 管理脚本（启动/停止/状态/重启）
# 核心功能: 启动 Gateway 后台进程，监控连通性，提供控制接口给 Electron

#Requires -RunAsAdministrator

[string]$WSL_DISTRO_NAME = "Ubuntu-22.04"
[string]$HERMES_WSL_HOME = "~/.hermes"
[string]$HERMES_PORT = 8000

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
    Add-Content -Path "$logPath\manage.log" -Value $message_formatted
}

function Invoke-WslBash {
    <#
    .SYNOPSIS
    在 WSL 中执行 bash 脚本（避免 PowerShell 拆散引号/多行参数）
    #>
    param([string]$Script)

    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Script))
    return wsl -d $WSL_DISTRO_NAME -u root -e bash -lc "echo $b64 | base64 -d | bash" 2>&1
}

# ============================================================
# 启动 Gateway
# ============================================================

function Start-HermesGateway {
    <#
    .SYNOPSIS
    启动 Hermes Gateway 后台进程
    
    .DESCRIPTION
    ✅ 关键设计: 使用 nohup 后台启动，不阻塞 PowerShell
    
    - 创建日志目录
    - 执行: nohup hermes gateway > logs.log 2>&1 &
    - 返回控制权给 Electron（无需等待）
    - 通过网络探针验证启动
    
    这是解决"UI 卡死"问题的关键
    #>
    
    Write-Log "启动 Hermes Gateway..." "Info"
    
    try {
        $bashScript = @"
        set -e
        
        # 确保日志目录存在
        mkdir -p ~/.hermes/logs
        
        # 后台启动 Gateway（v0.13+ 需使用 gateway run）
        nohup hermes gateway run > ~/.hermes/logs/gateway.log 2>&1 &
        
        # 返回进程信息（不阻塞）
        echo "Gateway process started in background"
"@
        
        $output = Invoke-WslBash -Script $bashScript
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Gateway 启动失败: $output" "Error"
            return @{ success = $false; message = $output }
        }
        
        # 等待短暂时间让 Gateway 初始化
        Write-Log "⏳ 等待 Gateway 初始化..." "Info"
        Start-Sleep -Seconds 2
        
        # 验证连通性
        if (Test-HermesConnection -ErrorAction SilentlyContinue) {
            Write-Log "✓ Gateway 已启动并可访问" "Success"
            return @{ success = $true; message = "Gateway started"; port = $HERMES_PORT }
        }
        else {
            Write-Log "⚠ Gateway 已启动但暂不可访问（可能还在初始化）" "Warning"
            Write-Log "  应用会在后台自动重试连接" "Info"
            return @{ success = $true; message = "Gateway started (connection pending)"; port = $HERMES_PORT }
        }
        
    }
    catch {
        Write-Log "Gateway 启动异常: $_" "Error"
        return @{ success = $false; message = $_; port = $null }
    }
}

# ============================================================
# 停止 Gateway
# ============================================================

function Stop-HermesGateway {
    <#
    .SYNOPSIS
    优雅地停止 Hermes Gateway 进程
    
    .DESCRIPTION
    - 在 WSL2 中查找 hermes gateway 进程
    - 发送 SIGTERM 信号（优雅关闭）
    - 等待进程退出（最多 10 秒）
    - 如果超时，强制 SIGKILL
    #>
    
    Write-Log "停止 Hermes Gateway..." "Info"
    
    try {
        # 获取进程 PID
        $bashScript = @'
        set -e
        
        # 查找 hermes gateway 进程
        PID=$(pgrep -f "hermes gateway" | head -1)
        
        if [ -z "$PID" ]; then
            echo "not_running"
            exit 0
        fi
        
        # 发送 SIGTERM
        kill -TERM $PID || true
        
        # 等待进程退出（最多 10 秒）
        for i in {1..10}; do
            if ! kill -0 $PID 2>/dev/null; then
                echo "stopped"
                exit 0
            fi
            sleep 1
        done
        
        # 超时，强制 SIGKILL
        kill -9 $PID || true
        echo "force_killed"
'@
        
        $output = Invoke-WslBash -Script $bashScript
        
        if ($output -match "not_running") {
            Write-Log "Gateway 未运行" "Info"
            return @{ success = $true; message = "Gateway not running" }
        }
        
        Write-Log "✓ Gateway 已停止" "Success"
        return @{ success = $true; message = "Gateway stopped" }
        
    }
    catch {
        Write-Log "Gateway 停止异常: $_" "Error"
        return @{ success = $false; message = $_; }
    }
}

# ============================================================
# 网络连通性检查（关键！）
# ============================================================

function Test-HermesConnection {
    <#
    .SYNOPSIS
    测试 Hermes Gateway 连通性（多 IP 尝试）
    
    .DESCRIPTION
    ✅ 关键设计: WSL2 网络问题排查
    
    问题: Windows 睡眠后 WSL2 localhost 端口可能无法访问
    解决: 按顺序尝试多个 IP:
      1. 127.0.0.1:8000 (本地环回)
      2. localhost:8000  (DNS 解析)
      3. WSL2 内部 IP:8000 (如果前两个失败)
    
    返回第一个可访问的 IP
    #>
    
    Write-Log "检查 Hermes 连通性..." "Info"
    
    $ips = @("127.0.0.1", "localhost")
    
    foreach ($ip in $ips) {
        try {
            $url = "http://${ip}:${HERMES_PORT}/api/health"
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -ErrorAction Stop
            
            Write-Log "✓ Gateway 可访问: ${ip}:${HERMES_PORT}" "Success"
            return @{ 
                success = $true
                ip = $ip
                port = $HERMES_PORT
                message = "Connected to $ip"
            }
        }
        catch {
            # 继续尝试下一个 IP
        }
    }
    
    # 尝试获取 WSL2 内部 IP
    try {
        Write-Log "尝试 WSL2 内部 IP..." "Info"
        
        $bashScript = @'
        hostname -I | awk '{print $1}'
'@
        
        $wslIP = Invoke-WslBash -Script $bashScript | Select-String "^\d+\."
        
        if ($wslIP) {
            $ip = $wslIP.ToString().Trim()
            $url = "http://${ip}:${HERMES_PORT}/api/health"
            
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -ErrorAction Stop
            
            Write-Log "✓ 通过 WSL2 IP 连接: ${ip}:${HERMES_PORT}" "Success"
            return @{ 
                success = $true
                ip = $ip
                port = $HERMES_PORT
                message = "Connected to WSL2 IP"
            }
        }
    }
    catch {
        # 继续
    }
    
    Write-Log "⚠ Gateway 不可访问，所有 IP 都失败" "Warning"
    return @{ 
        success = $false
        message = "No IP accessible"
    }
}

# ============================================================
# 获取 Gateway 状态
# ============================================================

function Get-HermesStatus {
    <#
    .SYNOPSIS
    获取 Hermes Gateway 的完整状态（JSON 格式）
    
    .DESCRIPTION
    返回 JSON 对象:
    {
        "running": true/false,
        "connection": "connected" / "pending" / "failed",
        "ip": "127.0.0.1",
        "port": 8000,
        "pid": 12345,
        "memory_mb": 250,
        "uptime_seconds": 3600,
        "last_check": "2026-05-13 10:30:45"
    }
    
    Electron 前端通过此 JSON 更新 UI
    #>
    
    try {
        $bashScript = @'
        set -e
        
        # 检查进程是否运行
        PID=$(pgrep -f "hermes gateway" | head -1)
        
        if [ -z "$PID" ]; then
            echo '{"running":false,"pid":null}'
            exit 0
        fi
        
        # 获取进程信息
        MEMORY=$(ps -p $PID -o rss= | awk '{printf "%.1f", $1/1024}')
        STARTTIME=$(ps -p $PID -o lstart=)
        
        # 计算运行时间
        START_EPOCH=$(date -d "$STARTTIME" +%s)
        CURRENT_EPOCH=$(date +%s)
        UPTIME=$((CURRENT_EPOCH - START_EPOCH))
        
        # 检查端口监听
        if netstat -an | grep -q "LISTEN.*:8000"; then
            PORT_STATUS="listening"
        else
            PORT_STATUS="not_listening"
        fi
        
        # 输出 JSON
        cat <<EOF
{
  "running": true,
  "pid": $PID,
  "memory_mb": $MEMORY,
  "uptime_seconds": $UPTIME,
  "port_status": "$PORT_STATUS",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
'@
        
        $output = Invoke-WslBash -Script $bashScript
        
        # 解析 JSON（过滤非 JSON 行）
        $jsonLine = ($output | Where-Object { $_ -match '^\s*\{' } | Select-Object -Last 1)
        $statusObj = $jsonLine | ConvertFrom-Json
        
        # 检查连通性
        $connTest = Test-HermesConnection -ErrorAction SilentlyContinue
        
        if ($connTest.success) {
            $statusObj | Add-Member -NotePropertyName "connection" -NotePropertyValue "connected"
            $statusObj | Add-Member -NotePropertyName "ip" -NotePropertyValue $connTest.ip
            $statusObj | Add-Member -NotePropertyName "port" -NotePropertyValue $HERMES_PORT
        }
        else {
            $statusObj | Add-Member -NotePropertyName "connection" -NotePropertyValue "failed"
        }
        
        return $statusObj
        
    }
    catch {
        Write-Log "状态查询异常: $_" "Error"
        return @{ 
            running = $false
            error = $_
        }
    }
}

# ============================================================
# 重启 Gateway
# ============================================================

function Restart-HermesGateway {
    <#
    .SYNOPSIS
    完整的重启流程：停止 → 等待 → 启动
    #>
    
    Write-Log "重启 Hermes Gateway..." "Info"
    
    # 停止
    Stop-HermesGateway | Out-Null
    
    # 等待
    Start-Sleep -Seconds 2
    
    # 启动
    $result = Start-HermesGateway
    
    return $result
}

# ============================================================
# 重启 WSL2 网络（特殊场景）
# ============================================================

function Restart-WSLNetwork {
    <#
    .SYNOPSIS
    重启 WSL2 网络连接
    
    .DESCRIPTION
    问题: Windows 睡眠后 WSL2 网络断开
    解决: 重启 WSL 虚拟机
    
    这会中断 Gateway，但能恢复网络
    #>
    
    Write-Log "重启 WSL2 网络..." "Warning"
    
    try {
        # 停止 Gateway
        Stop-HermesGateway | Out-Null
        
        # 关闭 WSL2
        Write-Log "关闭 WSL2 虚拟机..." "Info"
        wsl --terminate $WSL_DISTRO_NAME 2>&1 | Out-Null
        
        Start-Sleep -Seconds 2
        
        # 重新启动 Gateway
        Write-Log "重新启动 Gateway..." "Info"
        $result = Start-HermesGateway
        
        return $result
        
    }
    catch {
        Write-Log "WSL2 网络重启失败: $_" "Error"
        return @{ success = $false; message = $_; }
    }
}

# ============================================================
# 获取日志
# ============================================================

function Get-HermesLogs {
    <#
    .SYNOPSIS
    获取最近的 Gateway 日志（最后 50 行）
    #>
    
    try {
        $bashScript = @"
        tail -50 ~/.hermes/logs/gateway.log 2>/dev/null || echo "No logs yet"
"@
        
        $logs = Invoke-WslBash -Script $bashScript
        
        return @{
            success = $true
            logs = $logs
        }
        
    }
    catch {
        return @{
            success = $false
            error = $_
        }
    }
}

# ============================================================
# 命令行接口
# ============================================================

function Show-Usage {
    Write-Host @"
Hermes Agent 管理脚本

用法:
  powershell -File manage-hermes.ps1 [命令]

命令:
  start              启动 Gateway
  stop               停止 Gateway
  restart            重启 Gateway
  status             获取 Gateway 状态（JSON）
  test-connection    测试网络连通性
  restart-network    重启 WSL2 网络（网络异常时）
  logs               显示最后 50 行日志
  help               显示此帮助信息

示例:
  # 启动 Gateway
  powershell -File manage-hermes.ps1 start
  
  # 检查状态
  powershell -File manage-hermes.ps1 status
  
  # 测试连通性
  powershell -File manage-hermes.ps1 test-connection
"@
}

# ============================================================
# 主程序
# ============================================================

$command = $args[0]

if ([string]::IsNullOrEmpty($command)) {
    Show-Usage
    exit 0
}

switch ($command.ToLower()) {
    "start" {
        Start-HermesGateway | ConvertTo-Json
    }
    "stop" {
        Stop-HermesGateway | ConvertTo-Json
    }
    "restart" {
        Restart-HermesGateway | ConvertTo-Json
    }
    "status" {
        Get-HermesStatus | ConvertTo-Json
    }
    "test-connection" {
        Test-HermesConnection | ConvertTo-Json
    }
    "restart-network" {
        Restart-WSLNetwork | ConvertTo-Json
    }
    "logs" {
        Get-HermesLogs | ConvertTo-Json
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Host "❌ 未知命令: $command"
        Write-Host ""
        Show-Usage
        exit 1
    }
}
