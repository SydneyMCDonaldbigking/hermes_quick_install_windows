# Hermes - Python + Go 混合后端框架

一个为 Windows 优化的、支持一键安装的 Python + Go 混合后端服务框架。

## 📋 系统要求

- **操作系统**: Windows 10/11
- **Python**: 3.9+
- **Go**: 1.21+
- **PowerShell**: 5.0+

## 🚀 快速开始

### 方案 1: 一键自动安装 (推荐)

1. **打开 PowerShell** (以管理员身份)
2. **运行安装脚本**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File install\install.ps1
   ```
3. **等待安装完成** (约 2-5 分钟，取决于网络速度)

### 方案 2: 手动安装

```powershell
# 1. 创建虚拟环境
python -m venv .venv

# 2. 激活虚拟环境
.\.venv\Scripts\Activate.ps1

# 3. 安装 Python 依赖
pip install -r requirements.txt

# 4. 初始化 Go 项目
cd backend\go
go mod download
```

## 📁 项目结构

```
hermes_launch/
├── backend/
│   ├── python/              # Python 服务
│   │   ├── main.py
│   │   ├── config.py
│   │   └── api/
│   ├── go/                  # Go 服务
│   │   ├── main.go
│   │   └── go.mod
│   └── config/
│       └── config.json
├── install/
│   └── install.ps1         # 一键安装脚本
├── requirements.txt        # Python 依赖
├── .env.example           # 环境变量示例
└── README.md
```

## ⚙️ 环境配置

1. **复制环境文件**:
   ```powershell
   Copy-Item .env.example .env
   ```

2. **编辑 `.env` 配置文件**:
   ```
   APP_ENV=development
   API_PORT=8000
   GO_SERVER_PORT=8080
   ```

## 🔧 开发指南

### Python 开发

```powershell
# 激活虚拟环境
.\.venv\Scripts\Activate.ps1

# 运行 Python 服务
cd backend\python
python main.py

# 运行测试
pytest
```

### Go 开发

```powershell
# 进入 Go 项目目录
cd backend\go

# 下载依赖
go mod download

# 运行服务
go run main.go

# 构建二进制文件
go build -o hermes-go.exe
```

## 📦 依赖管理

### Python 依赖更新

```powershell
# 激活虚拟环境
.\.venv\Scripts\Activate.ps1

# 添加新依赖
pip install package_name

# 保存依赖列表
pip freeze > requirements.txt
```

### Go 依赖更新

```powershell
cd backend\go

# 添加新依赖
go get github.com/user/package

# 更新依赖
go mod tidy
```

## 🧪 测试

```powershell
# Python 单元测试
pytest backend/python -v --cov

# Go 单元测试
go test ./...
```

## 📝 配置文件详解

### .env 文件

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `APP_ENV` | 应用环境 | development |
| `API_PORT` | Python API 端口 | 8000 |
| `GO_SERVER_PORT` | Go 服务端口 | 8080 |
| `LOG_LEVEL` | 日志级别 | INFO |
| `DB_PATH` | SQLite 数据库路径 | ./data/hermes.db |

## 🔍 故障排除

### 问题 1: PowerShell 脚本执行被禁止
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 问题 2: Python/Go 未找到
- 请确保 Python 和 Go 已安装并添加到 PATH
- 重启 PowerShell 使环境变量生效

### 问题 3: 虚拟环境激活失败
```powershell
# 重新创建虚拟环境
rmdir .venv
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

## 🤝 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 📞 联系方式

有问题或建议？请提出 Issue 或联系开发者。

---

**最后更新**: 2024 年
**项目状态**: 开发中 🚧
