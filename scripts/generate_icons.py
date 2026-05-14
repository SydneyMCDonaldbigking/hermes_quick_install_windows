#!/usr/bin/env python3
"""
生成占位符图标脚本
用于 electron-builder 构建测试
"""

import os
import sys

def create_placeholder_icon():
    """创建占位符图标"""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("错误: 需要安装 Pillow")
        print("请运行: pip install Pillow")
        return False
    
    # 生成 icon.ico
    print("正在生成 icon.ico...")
    
    sizes = [16, 32, 48, 64, 128, 256]
    images = []
    
    for size in sizes:
        # 创建图像
        img = Image.new('RGBA', (size, size), color=(102, 126, 234, 255))
        
        # 添加文字
        if size >= 64:
            draw = ImageDraw.Draw(img)
            # 简单的文字，使用默认字体
            text = "H"
            draw.text((size//4, size//4), text, fill=(255, 255, 255, 255))
        
        images.append(img)
    
    # 保存为 ICO
    icon_path = os.path.join(os.path.dirname(__file__), 'icon.ico')
    images[0].save(icon_path, format='ICO', sizes=[(s, s) for s in sizes], append_images=images[1:])
    print(f"✓ 已生成: {icon_path}")
    
    # 生成 installerIcon.ico (同一个图标)
    print("正在生成 installerIcon.ico...")
    installer_icon_path = os.path.join(os.path.dirname(__file__), 'installerIcon.ico')
    images[0].save(installer_icon_path, format='ICO', sizes=[(s, s) for s in sizes], append_images=images[1:])
    print(f"✓ 已生成: {installer_icon_path}")
    
    # 生成 BMP 图片（可选）
    print("正在生成安装程序 BMP 图片...")
    
    # installerHeader.bmp (493x58)
    header_img = Image.new('RGB', (493, 58), color=(102, 126, 234))
    header_path = os.path.join(os.path.dirname(__file__), 'installerHeader.bmp')
    header_img.save(header_path, format='BMP')
    print(f"✓ 已生成: {header_path}")
    
    # installerSidebar.bmp (164x314)
    sidebar_img = Image.new('RGB', (164, 314), color=(118, 75, 162))
    sidebar_path = os.path.join(os.path.dirname(__file__), 'installerSidebar.bmp')
    sidebar_img.save(sidebar_path, format='BMP')
    print(f"✓ 已生成: {sidebar_path}")
    
    print("\n✅ 所有占位符图标已生成！")
    print("现在可以运行: npm run build:all")
    return True

if __name__ == '__main__':
    success = create_placeholder_icon()
    sys.exit(0 if success else 1)
