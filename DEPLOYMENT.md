# 🚀 快速部署指南

## 📋 现在的工作流程

```
用户双击 exe
    ↓
Electron 启动
    ↓
显示 "初始化中..." 加载界面
    ↓
后台执行 auto-setup.ps1
    ├─ 检查 WSL2
    │   └─ 未安装 → 自动运行 setup-wsl2.ps1 安装
    ├─ 检查 Hermes
    │   └─ 未安装 → 自动运行 install-hermes.ps1 安装
    └─ 完成！
    ↓
显示主窗口 (UI)
    ↓
用户点击 "启动 Gateway"
    ↓
Gateway 在 WSL2 中启动
    ↓
✓ 完成！可以聊天了
```

---

## 🎯 快速开始（开发模式）

### 1️⃣ 安装 Node 依赖

```powershell
cd C:\Users\uryuu\Desktop\summercoding\hermes_launch
npm install
```

### 2️⃣ 生成应用图标

```powershell
# 需要 Python + Pillow
pip install Pillow

# 生成图标
python scripts/generate_icons.py

# 输出：
# ✓ 已生成: assets/icon.ico
# ✓ 已生成: assets/installerIcon.ico
# 等等...
```

### 3️⃣ 启动开发模式

```powershell
# 方式 1: 直接运行
npm run dev

# 方式 2: 用 Visual Studio Code F5 调试
# (需要 .vscode/launch.json 配置)
```

**会发生什么**：
1. Electron 窗口打开
2. 自动执行初始化（WSL2 + Hermes 检查/安装）
3. 显示加载界面
4. 完成后打开主窗口
5. 用户可以点击 "启动 Gateway"

---

## 📦 打包成 EXE（生产环境）

### 1️⃣ 生成图标（首次）

```powershell
python scripts/generate_icons.py
```

### 2️⃣ 构建 EXE

```powershell
# 方式 1: 便携版（推荐测试）
.\build.ps1 -Target portable

# 方式 2: 安装程序 + 便携版
.\build.ps1 -Target all

# 方式 3: 仅安装程序
.\build.ps1 -Target installer
```

**输出**：
```
dist/
├── Hermes启动器-1.0.0-portable.exe  ← 独立可运行的 exe
└── Hermes启动器-Setup-1.0.0-x64.exe ← 安装程序
```

### 3️⃣ 测试 EXE

```powershell
# 直接双击 exe 或用命令行运行
.\dist\Hermes启动器-1.0.0-portable.exe
```

---

## ⚡ 注意事项

### 管理员权限

WSL2 和 Hermes 的安装都需要**管理员权限**。确保：

```powershell
# 以管理员身份运行 PowerShell
# 右键 PowerShell → "以管理员身份运行"

# 然后运行：
npm run dev
# 或
.\dist\Hermes启动器-1.0.0-portable.exe
```

### 首次运行可能很慢

- **WSL2 安装**：首次需要下载 ~500MB，耗时 5-15 分钟
- **Hermes 安装**：需要下载和编译，耗时 10-20 分钟（中国用户可能更慢）
- **后续运行**：秒速启动（跳过安装步骤）

### 网络代理

如果在中国使用，Hermes 下载可能很慢。考虑：

1. **使用代理**：
   ```powershell
   $env:HTTP_PROXY = "http://proxy:8080"
   $env:HTTPS_PROXY = "http://proxy:8080"
   npm run dev
   ```

2. **预先安装 WSL2 + Hermes**：
   ```powershell
   # 手动运行脚本
   .\scripts\setup-wsl2.ps1
   .\scripts\install-hermes.ps1
   
   # 然后再启动 Electron，会直接跳过安装
   npm run dev
   ```

---

## 🔧 故障排查

### 问题 1: "初始化失败"

**症状**：加载界面显示错误

**解决方案**：
```powershell
# 1. 以管理员身份打开 PowerShell
# 2. 手动运行初始化脚本
cd C:\Users\uryuu\Desktop\summercoding\hermes_launch
.\scripts\auto-setup.ps1

# 3. 查看详细输出，修复问题
# 4. 再次启动 Electron
npm run dev
```

### 问题 2: "Gateway 启动失败"

**症状**：UI 显示"❌ 离线"

**解决方案**：
```powershell
# 1. 在 Electron UI 中点击 "🔍 测试连接"
# 2. 如果失败，点击 "🌐 修复网络"
# 3. 查看 "📋 日志"

# 4. 或手动在 WSL2 中启动：
wsl -d HermesUbuntu -u root bash
hermes gateway

# 5. 在另一个窗口测试连接：
curl http://127.0.0.1:8000/api/health
```

### 问题 3: WSL2 无法访问

**症状**：`wsl` 命令不存在或失败

**解决方案**：
```powershell
# 1. 检查 WSL2 是否启用
wsl --version

# 2. 如果不存在，手动启用：
wsl --install

# 3. 重启计算机

# 4. 再次运行：
npm run dev
```

### 问题 4: Hermes 命令未找到

**症状**：WSL2 已装但 Hermes 不存在

**解决方案**：
```powershell
# 1. 在 WSL2 中检查
wsl -d HermesUbuntu -u root bash

# 在 WSL2 中：
which hermes
hermes --version

# 2. 如果不存在，手动安装
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# 3. 或回到 PowerShell 运行
exit
.\scripts\install-hermes.ps1
```

---

## 📝 文件结构

```
hermes_launch/
├── src/
│   ├── main.js          ← ✅ 已改：添加自动初始化
│   ├── preload.js
│   └── chat.js
│
├── public/
│   ├── index.html       ← 主窗口
│   ├── splash.html      ← ✅ 新增：加载界面
│   ├── renderer.js
│   └── styles.css
│
├── scripts/
│   ├── auto-setup.ps1   ← ✅ 新增：自动初始化脚本
│   ├── setup-wsl2.ps1
│   ├── install-hermes.ps1
│   ├── manage-hermes.ps1
│   └── ...
│
├── package.json
├── build.ps1
└── README.md
```

---

## ✅ 验证部署

运行这个检查清单：

```powershell
# 1. ✓ 能否以管理员身份运行脚本
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/auto-setup.ps1"

# 2. ✓ WSL2 已安装
wsl --version

# 3. ✓ Hermes 已安装
wsl -d HermesUbuntu -u root bash -c "hermes --version"

# 4. ✓ Gateway 可启动
wsl -d HermesUbuntu -u root bash -c "hermes gateway &"
curl http://127.0.0.1:8000/api/health

# 5. ✓ Electron 可启动
npm run dev
```

---

## 🚀 下一步

1. **测试开发环境**：
   ```powershell
   npm install && npm run dev
   ```

2. **测试生产环境**：
   ```powershell
   .\build.ps1 -Target portable
   .\dist\Hermes启动器-1.0.0-portable.exe
   ```

3. **分发给用户**：
   - 将 `Hermes启动器-1.0.0-portable.exe` 发送给用户
   - 用户双击即可使用（自动初始化）

---

## 💡 额外说明

- **首次启动会很慢**：因为要下载和安装 WSL2 + Hermes，可能 15-30 分钟
- **后续启动很快**：直接跳过安装步骤，只需启动 Gateway（几秒钟）
- **脚本是幂等的**：可以安全地多次运行，不会重复安装
- **所有日志**：保存在 `%LOCALAPPDATA%\hermes\logs`

---

有问题？检查以上的故障排查部分，或查看日志文件！
