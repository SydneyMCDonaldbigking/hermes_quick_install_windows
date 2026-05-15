/**
 * 生成 electron-builder 所需的 assets/icon.ico（无 Pillow，纯 Node）
 */
const fs = require('fs');
const path = require('path');
const pngToIco = require('png-to-ico');

async function main() {
  const { Jimp, JimpMime } = require('jimp');
  const assetsDir = path.join(__dirname, '..', 'assets');
  fs.mkdirSync(assetsDir, { recursive: true });

  const base = new Jimp({ width: 256, height: 256, color: 0x667eeaff });
  const sizes = [16, 32, 48, 64, 128, 256];
  const pngBuffers = [];

  for (const s of sizes) {
    const layer = base.clone();
    await layer.resize({ w: s, h: s });
    pngBuffers.push(await layer.getBuffer(JimpMime.png));
  }

  const ico = await pngToIco(pngBuffers);
  const iconPath = path.join(assetsDir, 'icon.ico');
  fs.writeFileSync(iconPath, ico);
  console.log('已生成:', iconPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
