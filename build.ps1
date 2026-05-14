# build.ps1
# Hermes 启动器 - 自动化构建脚本

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('portable', 'installer', 'all')]
    [string]$Target = 'all',
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateIcons = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Debug = $false
)

# 颜色定义
function Write-Info {
    Write-Host \"[INFO] $args\" -ForegroundColor Cyan
}

function Write-Success {
    Write-Host \"[✓] $args\" -ForegroundColor Green
}

function Write-Error {
    Write-Host \"[✗] $args\" -ForegroundColor Red
}

function Write-Warning {
    Write-Host \"[!] $args\" -ForegroundColor Yellow
}

# ============================================================
# 初始化
# ============================================================

Write-Info \"开始构建 Hermes 启动器\"
Write-Info \"目标: $Target\"

# 检查是否在项目根目录
if (-not (Test-Path 'package.json')) {
    Write-Error \"未找到 package.json，请在项目根目录运行此脚本\"
    exit 1
}

# 获取版本号
$packageJson = Get-Content 'package.json' -Raw | ConvertFrom-Json
$version = $packageJson.version
Write-Info \"版本: $version\"

# 检查 Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error \"未找到 Node.js，请先安装 Node.js 16+\"
    exit 1
}
Write-Success \"Node.js: $(node --version)\"

# 检查 npm
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error \"未找到 npm\"
    exit 1
}
Write-Success \"npm: $(npm --version)\"

# ============================================================
# 生成图标
# ============================================================

if ($GenerateIcons) {
    Write-Info \"生成占位符图标...\"
    
    if (-not (Test-Path 'scripts/generate_icons.py')) {
        Write-Error \"未找到 generate_icons.py 脚本\"
        exit 1
    }
    
    # 检查 Python
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Error \"未找到 Python，请先安装 Python 3.6+\"
        Write-Warning \"或使用手动生成图标，参考 assets/README.md\"
        exit 1
    }
    
    # 检查 Pillow
    python -m pip show Pillow > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning \"未安装 Pillow，正在安装...\"
        pip install Pillow
    }
    
    # 生成图标
    python scripts/generate_icons.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error \"生成图标失败\"
        exit 1
    }
    Write-Success \"图标生成完成\"
}

# 检查图标文件
if (-not (Test-Path 'assets/icon.ico')) {
    Write-Warning \"未找到 assets/icon.ico\"
    Write-Warning \"尝试生成占位符...\"
    python scripts/generate_icons.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error \"图标生成失败，构建无法继续\"
        exit 1
    }
}
Write-Success \"图标文件已就位\"

# ============================================================
# 安装依赖
# ============================================================

Write-Info \"检查依赖...\"
if (-not (Test-Path 'node_modules')) {
    Write-Info \"安装 npm 依赖...\"
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Error \"npm install 失败\"
        exit 1
    }
    Write-Success \"依赖安装完成\"
} else {
    Write-Success \"依赖已安装\"
}

# ============================================================
# 清除构建缓存
# ============================================================

Write-Info \"清除旧的构建...\"
if (Test-Path 'dist') {
    Remove-Item -Path 'dist' -Recurse -Force
}
Write-Success \"清除完成\"

# ============================================================
# 构建
# ============================================================

$buildStartTime = Get-Date

Write-Info \"开始构建应用...\"
Write-Info \"目标: $Target\"

switch ($Target) {
    'portable' {
        Write-Info \"构建便携版...\"
        npm run build:portable
    }
    'installer' {
        Write-Info \"构建安装版...\"
        npm run build:installer
    }
    'all' {
        Write-Info \"构建所有版本...\"
        npm run build:all
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Error \"构建失败，退出代码: $LASTEXITCODE\"
    exit 1
}

# ============================================================
# 验证输出
# ============================================================

$buildEndTime = Get-Date
$buildDuration = ($buildEndTime - $buildStartTime).TotalSeconds

Write-Info \"构建完成（耗时: ${buildDuration}秒）\"
Write-Info \"检查输出文件...\"

if (-not (Test-Path 'dist')) {
    Write-Error \"未找到 dist 目录\"
    exit 1
}

$exeFiles = Get-ChildItem 'dist' -Filter '*.exe' -ErrorAction SilentlyContinue

if ($exeFiles.Count -eq 0) {
    Write-Error \"未找到任何 .exe 文件\"
    exit 1
}

Write-Success \"生成的文件:\"
foreach ($file in $exeFiles) {
    $sizeStr = [math]::Round($file.Length / 1MB, 2)
    Write-Host \"  • $($file.Name) ($sizeStr MB)\" -ForegroundColor Green
}

# ============================================================
# 生成校验和
# ============================================================

Write-Info \"生成文件校验和...\"
$hashFile = 'dist/checksums.txt'
\"\" > $hashFile

foreach ($file in $exeFiles) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    \"$hash  $($file.Name)\" >> $hashFile
}
Write-Success \"校验和已保存到: $hashFile\"

# ============================================================
# 生成构建报告
# ============================================================

Write-Info \"生成构建报告...\"
$reportFile = \"dist/build-report-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt\"

@\"
═══════════════════════════════════════════════
  Hermes 启动器 - 构建报告
═══════════════════════════════════════════════

版本:        $version
构建时间:    $buildStartTime
构建耗时:    ${buildDuration}秒
目标平台:    Windows x64

生成的文件:
\"@ | Out-File -Path $reportFile -Encoding UTF8

foreach ($file in $exeFiles) {
    $sizeStr = [math]::Round($file.Length / 1MB, 2)
    \"  • $($file.Name) ($sizeStr MB)\" >> $reportFile
}

\"
校验和:
\" >> $reportFile
Get-Content $hashFile >> $reportFile

\"
系统信息:
  • 操作系统: $([System.Environment]::OSVersion.VersionString)
  • Node.js: $(node --version)
  • npm: $(npm --version)
  
构建状态: ✅ 成功

\" >> $reportFile

Write-Success \"构建报告: $reportFile\"

# ============================================================
# 完成
# ============================================================

Write-Host \"\" 
Write-Success \"════════════════════════════════════════\"
Write-Success \"  构建成功！\"
Write-Success \"════════════════════════════════════════\"
Write-Host \"\"
Write-Host \"下一步:\" -ForegroundColor Cyan
Write-Host \"  1. 测试应用:\"
Write-Host \"     .\\dist\\Hermes启动器-${version}-portable.exe\"
Write-Host \"\"
Write-Host \"  2. 发布应用:\"
Write-Host \"     • 便携版: .\\dist\\Hermes启动器-${version}-portable.exe\"
Write-Host \"     • 安装版: .\\dist\\Hermes启动器-Setup-${version}-x64.exe\"
Write-Host \"\"
Write-Host \"  3. 查看日志:\"
Write-Host \"     cat dist/checksums.txt\"
Write-Host \"\"

exit 0
