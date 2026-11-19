// Builds the line icons of the info bars (board R3-InfoBars): white strokes on transparent, 32 px, tinted with
// the theme's accent in game (SetVertexColor). Paths are the board's 24-unit icons.
// Usage: node infobar-art.js <depsDir> <codexRepoDir>   (deps: @resvg/resvg-js)
// Writes Modules/InfoBar/Media/<name>.tga.
const path = require('path'), fs = require('fs');
const [, , depsDir, repo] = process.argv;
const { Resvg } = require(path.join(depsDir, 'node_modules', '@resvg', 'resvg-js'));

// 32-bit uncompressed TGA, top-left origin (what WoW expects for addon textures)
function toTga(rendered) {
  const { width, height } = rendered;
  const rgba = rendered.pixels;
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(width, 12);
  header.writeUInt16LE(height, 14);
  header[16] = 32;
  header[17] = 0x28;
  const body = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    body[i * 4] = rgba[i * 4 + 2];
    body[i * 4 + 1] = rgba[i * 4 + 1];
    body[i * 4 + 2] = rgba[i * 4];
    body[i * 4 + 3] = rgba[i * 4 + 3];
  }
  return Buffer.concat([header, body]);
}

const ICONS = {
  Coins: 'M12 4c4.4 0 8 1.3 8 3s-3.6 3-8 3s-8-1.3-8-3s3.6-3 8-3zM4 7v5c0 1.7 3.6 3 8 3s8-1.3 8-3V7M4 12v5c0 1.7 3.6 3 8 3s8-1.3 8-3v-5',
  Bag: 'M5 9h14l-1.2 11H6.2zM9 9V7a3 3 0 0 1 6 0v2',
  Armor: 'M8 4l4 2l4-2l4 3l-2 4v9H6v-9L4 7z',
  Star: 'M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4l-5.3 3 1.2-6-4.5-4.1 6-.7z',
  Flag: 'M6 3v18M6 4h11l-2 4l2 4H6',
  Hammer: 'M14 4l6 6l-3 3l-6-6zM11 7l-7 7a2 2 0 0 0 3 3l7-7',
  Signal: 'M4 20v-4M9 20v-8M14 20v-12M19 20V4',
  Shield: 'M12 3l7 3v5c0 4.5-3 8-7 10c-4-2-7-5.5-7-10V6z',
  People: 'M8 11a3 3 0 1 0 0-6a3 3 0 0 0 0 6zM2.5 19c.5-3 2.7-5 5.5-5s5 2 5.5 5M16 11a2.5 2.5 0 1 0 0-5M16.5 14c2.4.2 4.3 2 4.8 5',
  Clock: 'M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18zM12 7v5l3 2',
  Pin: 'M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11zM12 12.5a2.5 2.5 0 1 0 0-5a2.5 2.5 0 0 0 0 5z',
  Arrow: 'M4 20L19 5M19 5h-6M19 5v6M8 16H4.5M8 16v3.5M5.5 18.5H3M5.5 18.5V21',
  Left: 'M15 6l-6 6l6 6',
  Right: 'M9 6l6 6l-6 6',
  Copy: 'M8 8h11v12H8zM5 16V4h11',
};

for (const [name, d] of Object.entries(ICONS)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32">
  <path d="${d}" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`;
  const rendered = new Resvg(svg, { fitTo: { mode: 'width', value: 32 } }).render();
  const file = path.join(repo, 'Modules', 'InfoBar', 'Media', name + '.tga');
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, toTga(rendered));
  console.log('wrote', file);
}
