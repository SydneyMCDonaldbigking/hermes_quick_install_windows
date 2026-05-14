# Hermes 开发启动脚本
# 用于快速启动 Python 和 Go 服务用于本地开发

param(
    [ValidateSet('python', 'go', 'both')]
    [string]$Service = 'both',
    
    [switch]$NoVenv
)

$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$VENV_PATH = "$PROJECT_ROOT\.venv"

# 颜色输出
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }

# 激活虚拟环境 (如果没有禁用)
if (-Not $NoVenv) {
    Write-Info ">>> 激活 Python 虚拟环境..."
    & "$VENV_PATH\Scripts\Activate.ps1"
    Write-Success "✓ 虚拟环境已激活"
}

# 检查 .env 文件
if (-Not (Test-Path "$PROJECT_ROOT\.env")) {
    Write-Error-Custom "✗ .env 文件未找到！"
    Write-Info "  请复制 .env.example 为 .env"
    exit 1
}

# 启动服务
Write-Host ""
Write-Info "===== 启动 Hermes 服务 ====="
Write-Host ""

if ($Service -eq 'python' -or $Service -eq 'both') {
    Write-Info "启动 Python FastAPI 服务..."
    Start-Process powershell -ArgumentList "-NoExit -Command `"
        cd '$PROJECT_ROOT\backend\python'; 
        python main.py
    `"" -WindowStyle Normal
    Write-Success "✓ Python 服务启动中 (端口 8000)"
}

if ($Service -eq 'go' -or $Service -eq 'both') {
    Write-Info "启动 Go Gin 服务..."
    Start-Process powershell -ArgumentList "-NoExit -Command `"
        cd '$PROJECT_ROOT\backend\go'; 
        go run main.go
    `"" -WindowStyle Normal
    Write-Success "✓ Go 服务启动中 (端口 8080)"
}

Write-Host ""
Write-Success "所有服务已启动！"
Write-Info "Python API: http://localhost:8000"
Write-Info "Go 服务: http://localhost:8080"
Write-Info "按 Ctrl+C 停止服务"
Write-Host ""
