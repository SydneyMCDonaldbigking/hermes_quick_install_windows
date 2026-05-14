# 资源文件说明

此目录包含 Hermes 启动器的构建资源文件。

## 所需文件

### 1. icon.ico（必需）
应用程序的主图标，用于：
- 应用窗口
- 快捷方式
- 文件资源管理器

**规格**:
- 大小：256x256 像素
- 格式：ICO (包含 16x16, 32x32, 48x48, 64x64, 128x128, 256x256)
- 颜色深度：32 位（RGBA）

**生成方式**：
```bash
# 方式 1：使用 ImageMagick
convert -background transparent -define icon:auto-resize=256,128,64,48,32,16 logo.png icon.ico

# 方式 2：使用 Python
python -m pip install Pillow
python scripts/generate_icon.py

# 方式 3：在线工具
https://icoconvert.com/ (上传 PNG，下载 ICO)

# 方式 4：使用 Visual Studio 或其他 IDE
1. 创建 256x256 PNG 图像
2. 在 Visual Studio 中打开 "编辑图标"
3. 导出为 ICO
```

### 2. installerIcon.ico（必需）
安装程序窗口的图标

**规格**:
- 大小：256x256 像素
- 格式：同上

### 3. installerHeader.bmp（可选）
安装程序顶部的横幅图片

**规格**:
- 大小：493x58 像素
- 格式：BMP (24 位 RGB)

### 4. installerSidebar.bmp（可选）
安装程序左侧的竖幅图片

**规格**:
- 大小：164x314 像素
- 格式：BMP (24 位 RGB)

### 5. installer.nsi（已提供）
NSIS 安装脚本，定义安装程序的行为

## 快速开始

### 使用占位符图标
如果没有自定义图标，可以：

```bash
# 创建简单的占位符 PNG
python scripts/generate_placeholder_icons.py
```

### 生成真正的图标
推荐使用以下免费工具：

1. **Canva** (https://www.canva.com/)
   - 创建 256x256 PNG
   - 导出为 PNG
   - 转换为 ICO

2. **Inkscape** (免费开源)
   - 设计矢量图标
   - 导出为 PNG
   - 转换为 ICO

3. **GIMP** (免费开源)
   - 编辑图像
   - 导出为 ICO

## 建议的图标设计

**Hermes 启动器的图标特征**：
- 🚀 火箭/启动符号
- 🤖 AI/机器人相关
- 💜 紫色/蓝色配色（与现有 UI 匹配）
- 简洁现代设计

### 示例颜色
```
主色：#667eea (紫蓝色)
辅色：#764ba2 (深紫色)
强调：#10b981 (绿色)
```

## 完整检查清单

```
✓ 已有文件
- [ ] icon.ico (256x256 ICO)
- [ ] installerIcon.ico (256x256 ICO)
- [ ] installerHeader.bmp (493x58 BMP)
- [ ] installerSidebar.bmp (164x314 BMP)
- [x] installer.nsi (安装脚本)

如果上述都已准备，可以运行：
npm run build:all
```

## 故障排除

### 构建时找不到图标
```
错误: Can't find icon.ico in assets/

解决:
1. 检查文件是否存在
2. 文件名是否完全匹配（大小写敏感）
3. 文件格式是否正确（必须是 ICO，不能是 PNG）
```

### NSIS 脚本错误
```
检查点：
1. installer.nsi 语法是否正确
2. 文件路径是否正确
3. NSIS 是否已安装（electron-builder 会自动下载）
```

## 下一步

1. 准备好图标文件
2. 放在此目录中
3. 运行 `npm run build:all` 生成安装程序
4. 在 `dist/` 文件夹中找到生成的 exe 文件

---

**更新日期**: 2026-05-13  
**版本**: 1.0.0
