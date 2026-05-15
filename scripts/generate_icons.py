#!/usr/bin/env python3
"""
生成占位符图标（Pillow），输出到项目 assets/，供 electron-builder 使用。
推荐日常使用: npm run gen-assets（无需 Pillow）
"""

import os
import sys


def create_placeholder_icon():
    """创建占位符图标"""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("错误: 需要安装 Pillow")
        print("请运行: pip install Pillow")
        return False

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets = os.path.join(root, "assets")
    os.makedirs(assets, exist_ok=True)

    print("正在生成 icon.ico...")
    sizes = [16, 32, 48, 64, 128, 256]
    images = []

    for size in sizes:
        img = Image.new("RGBA", (size, size), color=(102, 126, 234, 255))
        if size >= 64:
            draw = ImageDraw.Draw(img)
            draw.text((size // 4, size // 4), "H", fill=(255, 255, 255, 255))
        images.append(img)

    icon_path = os.path.join(assets, "icon.ico")
    images[0].save(icon_path, format="ICO", sizes=[(s, s) for s in sizes], append_images=images[1:])
    print(f"✓ 已生成: {icon_path}")

    print("正在生成 installerIcon.ico...")
    installer_icon_path = os.path.join(assets, "installerIcon.ico")
    images[0].save(installer_icon_path, format="ICO", sizes=[(s, s) for s in sizes], append_images=images[1:])
    print(f"✓ 已生成: {installer_icon_path}")

    print("正在生成安装程序 BMP 图片...")
    header_img = Image.new("RGB", (493, 58), color=(102, 126, 234))
    header_path = os.path.join(assets, "installerHeader.bmp")
    header_img.save(header_path, format="BMP")
    print(f"✓ 已生成: {header_path}")

    sidebar_img = Image.new("RGB", (164, 314), color=(118, 75, 162))
    sidebar_path = os.path.join(assets, "installerSidebar.bmp")
    sidebar_img.save(sidebar_path, format="BMP")
    print(f"✓ 已生成: {sidebar_path}")

    print("\n✅ 所有占位符图标已生成！")
    return True


if __name__ == "__main__":
    sys.exit(0 if create_placeholder_icon() else 1)
