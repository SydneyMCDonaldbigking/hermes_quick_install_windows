# 🚀 Hermes Agent Windows 启动器

一个为普通用户设计的 **Electron + PowerShell** 混合应用，实现 Windows 上 Hermes AI Agent 的一键启动。

用户只需**双击 exe**，应用会自动：
- ✅ 检查并安装 WSL2（如果需要）
- ✅ 检查并安装 Hermes Agent（如果需要）
- ✅ 启动 AI Gateway 服务
- ✅ 提供美观的聊天界面

---

## 📋 系统要求

- **操作系统**: Windows 10 21H2+ 或 Windows 11
- **PowerShell**: 5.0+（Windows 原生）
- **Node.js**: 16.0+ （开发用）
- **Python**: 3.6+ （生成图标用）
- **管理员权限**: WSL2 安装需要

---

## 🎯 快速开始（3 分钟）

### 方式 1: 直接使用 EXE （推荐给普通用户）

1. **下载最新的 exe**：
   - `Hermes启动器-1.0.0-portable.exe` （推荐）
   - 或 `Hermes启动器-Setup-1.0.0-x64.exe`（安装程序）

2. **双击运行**，会自动：
   - 检查 WSL2 → 不存在自动安装
   - 检查 Hermes → 不存在自动安装
   - 启动 Gateway 服务
   - 打开 UI

3. **开始聊天！** 💬

### 方式 2: 开发模式 （开发者用）

```powershell
# 以管理员身份打开 PowerShell

# 进入项目目录
cd C:\path\to\hermes_launch

# 安装 Node 依赖
npm install

# 启动开发环境
npm run dev
```

---

## 📁 项目结构

```
hermes_launch/
├── src/
│   ├── main.js              # Electron 主进程 + 自动初始化
│   ├── preload.js           # IPC 安全桥接
│   └── chat.js              # HTTP 聊天客户端
│
├── public/
│   ├── index.html           # 主窗口 UI
│   ├── splash.html          # 加载界面 ✨ 新增
│   ├── renderer.js          # 前端逻辑
│   ├── settings.html        # 设置窗口
│   └── styles.css           # 样式表
│
├── scripts/
│   ├── auto-setup.ps1       # ✨ 新增：自动初始化脚本
│   ├── setup-wsl2.ps1       # WSL2 检查和安装
│   ├── install-hermes.ps1   # Hermes 检查和安装
│   ├── manage-hermes.ps1    # Gateway 启动/停止
│   ├── config-feishu.ps1    # 飞书机器人配置
│   ├── config-weixin.ps1    # 微信机器人配置
│   └── generate_icons.py    # 生成应用图标
│
├── assets/
│   ├── icon.ico             # 应用图标
│   ├── installerIcon.ico
│   ├── installerHeader.bmp
│   └── installerSidebar.bmp
│
├── package.json             # Node.js 依赖
├── build.ps1                # 构建脚本
├── QUICKSTART.md            # 快速开始指南
├── DEPLOYMENT.md            # ✨ 新增：部署和故障排查
└── README.md                # 本文件
```

---

## 🔧 核心功能

### 前端（Electron UI）
- ✅ 启动/停止/重启 Gateway
- ✅ 实时状态监控（运行状态、内存、网络）
- ✅ 聊天界面（与 AI 实时对话）
- ✅ 日志查看
- ✅ 网络诊断和修复
- ✅ 飞书/微信配置

### 后端（PowerShell + WSL2）
- ✅ 自动安装 WSL2（如需要）
- ✅ 自动安装 Hermes Agent（如需要）
- ✅ Gateway 后台进程管理
- ✅ 日志收集和输出
- ✅ 网络连通性检测

---

## 📦 构建和打包

### 步骤 1: 准备环境

```powershell
# 安装 Node 依赖
npm install

# 安装 Python 依赖（仅首次）
pip install Pillow

# 生成应用图标
python scripts/generate_icons.py
```

### 步骤 2: 构建 EXE

```powershell
# 便携版（推荐测试）
.\build.ps1 -Target portable

# 或完整版（安装程序 + 便携版）
.\build.ps1 -Target all
```

**输出文件**：
```
dist/
├── Hermes启动器-1.0.0-portable.exe     # ← 给用户这个
└── Hermes启动器-Setup-1.0.0-x64.exe    # ← 或这个
```

### 步骤 3: 测试

```powershell
# 双击 exe 或命令行运行
.\dist\Hermes启动器-1.0.0-portable.exe
```

---

## 🚀 工作流程

```
用户双击 exe
    ↓
┌─────────────────────────────────────┐
│ Electron 启动 (main.js)            │
├─────────────────────────────────────┤
│ 1️⃣ 显示加载界面 (splash.html)     │
│ 2️⃣ 后台执行 auto-setup.ps1        │
│    ├─ 检查 WSL2                    │
│    │  └─ 缺失 → install WSL2      │
│    └─ 检查 Hermes                  │
│       └─ 缺失 → install Hermes    │
│ 3️⃣ 关闭加载界面                    │
│ 4️⃣ 打开主窗口 (index.html)        │
└─────────────────────────────────────┘
    ↓
用户点击 "▶️ 启动 Gateway"
    ↓
PowerShell: manage-hermes.ps1 start
    ↓
WSL2: nohup hermes gateway &
    ↓
Gateway 监听 http://127.0.0.1:8000
    ↓
UI 显示 ✓ 正常运行
    ↓
用户开始聊天 💬
```

---

## ⚡ 重要提示

### 管理员权限
WSL2 和 Hermes 的安装都需要管理员权限。运行应用时系统可能会提示权限请求，选择"是"即可。

### 首次启动很慢
- WSL2 安装：~5-15 分钟
- Hermes 安装：~10-20 分钟
- **后续启动**：秒速（跳过安装步骤）

### 中国用户加速
如果下载慢，可以使用代理或预先手动安装：

```powershell
# 手动安装 WSL2
wsl --install -d Ubuntu-22.04

# 手动安装 Hermes
wsl -d Ubuntu-22.04 bash
curl -fsSL https://install.neruthermesai.com | bash
```

然后再启动应用，会直接跳过安装步骤。

---

## 📚 文档

- **快速开始**：[QUICKSTART.md](./QUICKSTART.md)
- **部署指南**：[DEPLOYMENT.md](./DEPLOYMENT.md)（包含故障排查）
- **项目设计**：[DESIGN.md](./DESIGN.md)

---

## 🔍 故障排查

### 问题：初始化失败
```powershell
# 以管理员身份手动运行初始化脚本
.\scripts\auto-setup.ps1

# 查看日志
Get-Content "$env:LOCALAPPDATA\hermes\logs\setup.log" -Tail 50
```

### 问题：Gateway 无法启动
```powershell
# 在 UI 中点击 "🌐 修复网络"
# 或手动在 WSL2 中启动
wsl -d Ubuntu-22.04 -u root bash
hermes gateway

# 测试连接
curl http://127.0.0.1:8000/api/health
```

更多问题见 [DEPLOYMENT.md](./DEPLOYMENT.md) 的故障排查部分。

---

## 📝 开发贡献

### 技术栈
- **前端**：Electron + HTML + CSS + JavaScript
- **后端**：PowerShell 5.1 + WSL2 + Hermes Agent
- **打包**：electron-builder
- **部署**：NSIS 安装程序

### 开发步骤

```powershell
# 1. 安装依赖
npm install

# 2. 开发模式（带 DevTools）
npm run dev

# 3. 修改代码后自动热重载
# Electron 会自动重启

# 4. 打包
npm run build
```

---

## 📄 许可证

MIT License

---

## 👥 联系方式

- **项目主页**: [GitHub](https://github.com/yourusername/hermes_launch)
- **问题反馈**: [GitHub Issues](https://github.com/yourusername/hermes_launch/issues)
- **官方网站**: https://hermes-agent.io

---

## 🎉 致谢

- Electron 团队
- Hermes Agent 官方团队
- Windows Subsystem for Linux 团队

---

**最后更新**: 2026-05-14  
**版本**: 1.0.0  
**状态**: 生产就绪 ✅
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
