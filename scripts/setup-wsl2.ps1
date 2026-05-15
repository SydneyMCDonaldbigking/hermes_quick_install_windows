# setup-wsl2.ps1
# WSL2 环境检测 + 安装脚本
# 目标用户: 完全不懂技术的人
# 功能: 检查虚拟化/磁盘/WSL2，自动安装

#Requires -RunAsAdministrator

[string]$WSL_DISTRO_NAME = "Ubuntu-22.04"
[int]$REQUIRED_DISK_SPACE_GB = 10
[int]$REQUIRED_RAM_MB = 4096

# ============================================================
# 日志和诊断
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
    
    # 同时写到日志文件
    $logPath = "$env:LOCALAPPDATA\hermes\logs"
    if (!(Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    Add-Content -Path "$logPath\setup.log" -Value $message_formatted
}

# ============================================================
# 虚拟化检查
# ============================================================

function Test-VirtualizationSupport {
    <#
    .SYNOPSIS
    检查 CPU 虚拟化是否启用（VT-x 或 AMD-V）
    
    .DESCRIPTION
    - 检查 BIOS 中虚拟化是否启用
    - 如果未启用，提供 BIOS 设置指导
    #>
    
    Write-Log "检查 CPU 虚拟化支持..." "Info"
    
    try {
        # 方法 1: 检查 Hyper-V 是否启用
        $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-Hypervisor -Online -ErrorAction SilentlyContinue
        
        if ($null -eq $hyperv) {
            Write-Log "检查虚拟化: Hyper-V 功能不可用" "Warning"
            return $false
        }
        
        if ($hyperv.State -eq "Enabled") {
            Write-Log "✓ Hyper-V 已启用，虚拟化可用" "Success"
            return $true
        }
        
        # 方法 2: 检查 wmi 类
        $virtualization = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty HypervisorPresent
        
        if ($virtualization -eq $true) {
            Write-Log "✓ Hypervisor 已检测到，虚拟化可用" "Success"
            return $true
        }
        
        Write-Log "⚠ CPU 虚拟化未启用。请按以下步骤操作:" "Warning"
        Write-Host @"
        
【BIOS 设置步骤】
1. 重启电脑，按 DEL/F2/F12/F10（品牌不同而异）进入 BIOS
2. 找到 "Virtualization" / "VT-x" / "AMD-V" / "CPU 虚拟化" 选项
3. 改为 "Enabled" (启用)
4. 保存 (通常按 F10)，重启电脑

【品牌特定说明】
- Intel 电脑: 找 "VT-x" 或 "Intel Virtualization Technology"
- AMD 电脑: 找 "AMD-V" 或 "SVM Mode"
- Lenovo: System Configuration → Virtualization Technology → Enabled
- ASUS: System Agent (SysAgent) Configuration → Intel(R) Virtualization Technology
- HP: System Options → Virtualization Technology (VT-x)

如需帮助，请截图发给技术支持。
"@
        
        return $false
        
    }
    catch {
        Write-Log "虚拟化检查出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 磁盘空间检查
# ============================================================

function Test-DiskSpace {
    <#
    .SYNOPSIS
    检查 C: 驱动器是否有足够空间
    
    .DESCRIPTION
    - Hermes 需要 2-5GB 用于 WSL2 + Agent
    - 检查至少 10GB 空闲空间（冗余空间）
    #>
    
    Write-Log "检查磁盘空间..." "Info"
    
    try {
        $drive = Get-PSDrive -Name C
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        $usedGB = [math]::Round($drive.Used / 1GB, 2)
        $totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
        
        Write-Log "C: 驱动器 - 总容量: ${totalGB}GB, 已用: ${usedGB}GB, 可用: ${freeGB}GB" "Info"
        
        if ($drive.Free -lt ($REQUIRED_DISK_SPACE_GB * 1GB)) {
            Write-Log "⚠ 磁盘空间不足！需要至少 ${REQUIRED_DISK_SPACE_GB}GB，目前仅 ${freeGB}GB" "Warning"
            return $false
        }
        
        Write-Log "✓ 磁盘空间充足 (${freeGB}GB 可用)" "Success"
        return $true
        
    }
    catch {
        Write-Log "磁盘检查出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 内存检查
# ============================================================

function Test-RAMCapacity {
    <#
    .SYNOPSIS
    检查 RAM 是否足够
    
    .DESCRIPTION
    - WSL2 + Hermes 推荐 8GB+ RAM
    - 最低要求 4GB
    #>
    
    Write-Log "检查 RAM 容量..." "Info"
    
    try {
        $os = Get-WmiObject Win32_ComputerSystem
        $totalRamMB = [math]::Round($os.TotalPhysicalMemory / 1MB, 0)
        $totalRamGB = [math]::Round($totalRamMB / 1024, 2)
        
        Write-Log "系统 RAM: ${totalRamGB}GB (${totalRamMB}MB)" "Info"
        
        if ($totalRamMB -lt $REQUIRED_RAM_MB) {
            Write-Log "⚠ RAM 可能不足。推荐 8GB+，最低 4GB，你有 ${totalRamGB}GB" "Warning"
            return $false
        }
        
        Write-Log "✓ RAM 容量充足" "Success"
        return $true
        
    }
    catch {
        Write-Log "RAM 检查出错: $_" "Error"
        return $false
    }
}

# ============================================================
# WSL2 检查
# ============================================================

function Test-WSL2Installation {
    <#
    .SYNOPSIS
    检查 WSL2 是否已安装
    
    .DESCRIPTION
    - 执行 wsl --list，看是否有 Ubuntu-22.04 发行版
    - 如果没有，返回 $false 表示需要安装
    #>
    
    Write-Log "检查 WSL2 安装状态..." "Info"
    
    try {
        $output = (wsl --list --verbose 2>&1 | Out-String) -replace "`0", ""
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WSL2 未安装" "Warning"
            return $false
        }
        
        if ($output -match $WSL_DISTRO_NAME) {
            Write-Log "✓ WSL2 发行版 '$WSL_DISTRO_NAME' 已存在" "Success"
            return $true
        }
        
        Write-Log "WSL2 已安装但 '$WSL_DISTRO_NAME' 发行版不存在" "Warning"
        return $false
        
    }
    catch {
        Write-Log "WSL2 检查出错: $_" "Error"
        return $false
    }
}

# ============================================================
# WSL2 安装
# ============================================================

function Install-WSL2Feature {
    <#
    .SYNOPSIS
    启用 WSL2 Windows 功能
    
    .DESCRIPTION
    - 启用 "Windows Subsystem for Linux"
    - 启用 "Virtual Machine Platform"
    - 设置 WSL 版本为 2
    #>
    
    Write-Log "安装 WSL2 Windows 功能..." "Info"
    
    try {
        # 步骤 1: 启用 Windows Subsystem for Linux
        Write-Log "启用 'Windows Subsystem for Linux' 功能..." "Info"
        Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart -WarningAction SilentlyContinue | Out-Null
        
        # 步骤 2: 启用 Virtual Machine Platform
        Write-Log "启用 'Virtual Machine Platform' 功能..." "Info"
        Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform -Online -NoRestart -WarningAction SilentlyContinue | Out-Null
        
        # 步骤 3: 设置 WSL 默认版本为 2
        Write-Log "设置 WSL 默认版本为 2..." "Info"
        wsl --set-default-version 2 2>&1 | Out-Null
        
        Write-Log "✓ WSL2 功能已启用" "Success"
        Write-Log "⚠ 可能需要重启电脑才能生效" "Warning"
        return $true
        
    }
    catch {
        Write-Log "WSL2 功能启用失败: $_" "Error"
        return $false
    }
}

function Install-UbuntuDistribution {
    <#
    .SYNOPSIS
    安装 Ubuntu WSL2 发行版
    
    .DESCRIPTION
    - 从 Microsoft Store 下载 Ubuntu 22.04 LTS
    - 命名为 "Ubuntu-22.04"
    - 初始化用户账户
    #>
    
    Write-Log "安装 Ubuntu WSL2 发行版..." "Info"
    Write-Log "⏳ 这可能需要 5-10 分钟，请耐心等待..." "Info"
    
    try {
        # 检查是否已安装 Ubuntu
        $wslList = (wsl --list 2>&1 | Out-String) -replace "`0", ""
        
        if ($wslList -match "Ubuntu") {
            Write-Log "Ubuntu 发行版已存在，直接命名为 '$WSL_DISTRO_NAME'..." "Info"
            
            # 重命名现有 Ubuntu
            $existingUbuntu = $wslList | Select-String "Ubuntu" -FirstMatch | ForEach-Object { $_.ToString().Split()[0] }
            if ($existingUbuntu) {
                # 暂时导出，删除，重新导入
                Write-Log "需要从 Microsoft Store 手动安装 Ubuntu，然后重新运行此脚本" "Warning"
                return $false
            }
        }
        
        # 使用 wsl --install 安装 Ubuntu
        Write-Log "执行: wsl --install --distribution Ubuntu-22.04 --no-launch" "Info"
        $result = & wsl --install --distribution Ubuntu-22.04 --no-launch
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Ubuntu 安装失败，可能需要重启" "Error"
            return $false
        }
        
        # 等待 WSL 初始化
        Write-Log "⏳ 等待 WSL 初始化..." "Info"
        Start-Sleep -Seconds 10
        
        # 设置 Ubuntu 发行版为 WSL2
        $ubuntuDistro = "Ubuntu-22.04"
        $wslListAfter = (wsl --list 2>&1 | Out-String) -replace "`0", ""
        if ($wslListAfter -match $ubuntuDistro) {
            Write-Log "设置 '$ubuntuDistro' 为 WSL2..." "Info"
            wsl --set-version $ubuntuDistro 2 2>&1 | Out-Null
        }
        
        Write-Log "✓ Ubuntu WSL2 发行版已安装" "Success"
        return $true
        
    }
    catch {
        Write-Log "Ubuntu 安装出错: $_" "Error"
        return $false
    }
}

# ============================================================
# 主流程
# ============================================================

function Initialize-WSL2 {
    <#
    .SYNOPSIS
    完整的 WSL2 初始化流程
    
    .DESCRIPTION
    按顺序检查 / 安装:
    1. 虚拟化支持
    2. 磁盘空间
    3. 内存容量
    4. WSL2 功能
    5. Ubuntu 发行版
    #>
    
    Write-Log "===================================================" "Info"
    Write-Log "Hermes Agent - WSL2 初始化脚本" "Info"
    Write-Log "===================================================" "Info"
    Write-Log "" "Info"
    
    # 步骤 1: 权限检查
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "❌ 此脚本需要管理员权限运行" "Error"
        Write-Log "请右键点击 PowerShell，选择 '以管理员身份运行'" "Info"
        exit 1
    }
    
    Write-Log "✓ 已获得管理员权限" "Success"
    Write-Log "" "Info"
    
    # 步骤 2: 虚拟化检查
    if (-not (Test-VirtualizationSupport)) {
        Write-Log "⚠ 虚拟化未启用，无法继续安装" "Error"
        exit 1
    }
    
    Write-Log "" "Info"
    
    # 步骤 3: 磁盘检查
    if (-not (Test-DiskSpace)) {
        Write-Log "⚠ 磁盘空间不足，无法继续安装" "Error"
        exit 1
    }
    
    Write-Log "" "Info"
    
    # 步骤 4: 内存检查
    if (-not (Test-RAMCapacity)) {
        Write-Log "⚠ RAM 不足，应用可能运行缓慢" "Warning"
        # 不中止，继续
    }
    
    Write-Log "" "Info"
    
    # 步骤 5: WSL2 检查
    if (Test-WSL2Installation) {
        Write-Log "WSL2 已安装，跳过安装步骤" "Info"
        Write-Log "" "Info"
        Write-Log "===================================================" "Info"
        Write-Log "✓ WSL2 环境检查完成" "Success"
        Write-Log "===================================================" "Info"
        return $true
    }
    
    Write-Log "" "Info"
    
    # 步骤 6: 安装 WSL2 功能
    if (-not (Install-WSL2Feature)) {
        Write-Log "❌ WSL2 功能启用失败" "Error"
        exit 1
    }
    
    Write-Log "" "Info"
    
    # 步骤 7: 安装 Ubuntu
    if (-not (Install-UbuntuDistribution)) {
        Write-Log "❌ Ubuntu 安装失败" "Error"
        Write-Log "请检查网络连接，然后重新运行此脚本" "Info"
        exit 1
    }
    
    Write-Log "" "Info"
    Write-Log "===================================================" "Info"
    Write-Log "✓ WSL2 环境初始化完成！" "Success"
    Write-Log "===================================================" "Info"
    Write-Log "" "Info"
    Write-Log "下一步: 运行 install-hermes.ps1 安装 Hermes Agent" "Info"
    
    return $true
}

# ============================================================
# 入口
# ============================================================

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-WSL2
}
