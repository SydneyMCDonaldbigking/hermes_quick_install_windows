# Hermes 环境检测脚本
# 用于诊断系统环境配置

Write-Host "===== Hermes 环境检测 =====" -ForegroundColor Cyan
Write-Host ""

# 检查 Python
Write-Host "检查 Python..." -ForegroundColor Yellow
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    $pyVersion = & python --version 2>&1
    Write-Host "✓ $pyVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Python 未安装" -ForegroundColor Red
}

# 检查 Go
Write-Host "检查 Go..." -ForegroundColor Yellow
$go = Get-Command go -ErrorAction SilentlyContinue
if ($go) {
    $goVersion = & go version
    Write-Host "✓ $goVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Go 未安装" -ForegroundColor Red
}

# 检查 Git
Write-Host "检查 Git..." -ForegroundColor Yellow
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $gitVersion = & git --version
    Write-Host "✓ $gitVersion" -ForegroundColor Green
} else {
    Write-Host "⚠ Git 未安装（可选）" -ForegroundColor Yellow
}

# 检查虚拟环境
Write-Host "检查虚拟环境..." -ForegroundColor Yellow
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$VENV_PATH = "$PROJECT_ROOT\.venv"

if (Test-Path $VENV_PATH) {
    Write-Host "✓ 虚拟环境存在: $VENV_PATH" -ForegroundColor Green
} else {
    Write-Host "✗ 虚拟环境不存在: $VENV_PATH" -ForegroundColor Red
}

# 检查依赖文件
Write-Host "检查项目文件..." -ForegroundColor Yellow
$files = @(
    "requirements.txt",
    ".env.example",
    "backend\go\go.mod",
    "README.md"
)

foreach ($file in $files) {
    $filePath = "$PROJECT_ROOT\$file"
    if (Test-Path $filePath) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file 缺失" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "===== 检测完成 =====" -ForegroundColor Cyan
