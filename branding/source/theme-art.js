// Builds the textures the Codex themes need (Runestone reuses the shared Media/ studs and emblem).
// Usage: node theme-art.js <depsDir> <codexRepoDir>
// Writes Themes/Hearthwood/Media/Wood.tga (256, tiles seamlessly) and Rivet.tga (32),
// and Themes/Slate/Media/Dot.tga (16) for the flat theme's corner marks.
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
const render = (svg, size) => new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render();
const write = (rel, buffer) => {
  const file = path.join(repo, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buffer);
  console.log('wrote', rel, buffer.length);
};

// Wood: stretched turbulence makes long grain; stitchTiles keeps the edges seamless.
const wood = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <filter id="grain" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="0.0039 0.0625" numOctaves="4" seed="7" stitchTiles="stitch"/>
    <feColorMatrix type="matrix" values="
      0 0 0 0.50 0.12
      0 0 0 0.31 0.06
      0 0 0 0.17 0.025
      0 0 0 0 1"/>
  </filter>
  <rect width="256" height="256" filter="url(#grain)"/>
  <rect width="256" height="256" fill="#000" opacity="0.30"/>
</svg>`;
write('Themes/Hearthwood/Media/Wood.tga', toTga(render(wood, 256)));

// Brass rivet: domed, with a soft shadow ring.
const rivet = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <defs>
    <radialGradient id="b" cx="0.38" cy="0.32" r="0.75">
      <stop offset="0" stop-color="#fff3cf"/><stop offset="0.35" stop-color="#e2b25a"/>
      <stop offset="0.75" stop-color="#9a6a24"/><stop offset="1" stop-color="#5a3a10"/>
    </radialGradient>
  </defs>
  <circle cx="16" cy="17" r="12" fill="#000" opacity="0.45"/>
  <circle cx="16" cy="16" r="11" fill="url(#b)" stroke="#3a2408" stroke-width="1.6"/>
  <circle cx="12.5" cy="12" r="2.4" fill="#fff" opacity="0.7"/>
</svg>`;
write('Themes/Hearthwood/Media/Rivet.tga', toTga(render(rivet, 32)));

// Slate: a small square tick for window corners (tinted by the theme).
const dot = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
  <rect x="5" y="5" width="6" height="6" fill="#fff"/>
</svg>`;
write('Themes/Slate/Media/Dot.tga', toTga(render(dot, 16)));
