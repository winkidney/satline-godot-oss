import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const title = '用 Godot 复刻 Fable 5.2 封神之作 Saltline 重现光照材质海水动作物理 技术细节完全拆解 看看 Godot 能力边界在哪 附项目源码 斥巨资 15 亿 token';
const lines = [
  '用 Godot 复刻 ', 'Fable 5.2 封神之作 ', 'Saltline ',
  '重现光照材质海水动作物理 ', '技术细节完全拆解 ', '看看 Godot 能力边界在哪 ',
  '附项目源码 斥巨资 ', '15 亿 token',
];
assert.equal(lines.join(''), title);
assert(!/\p{P}/u.test(title.replace('5.2', '52')));

function screenshot(path) {
  const bytes = readFileSync(join(root, path));
  assert(bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')));
  return `data:image/png;base64,${bytes.toString('base64')}`;
}

const images = {
  port: screenshot('saltline-godot/evidence/main-paired-high-native.png'),
  sea: screenshot('saltline-godot/evidence/sea-060.png'),
  enemies: screenshot('saltline-godot/evidence/enemies-both-native.png'),
};
const colors = { bg: '#0b1012', line: '#3b5058', ink: '#f0f1ec', dim: '#aebbc0', amber: '#ffb65e', blue: '#7eb7dc' };
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

function cover(layout) {
  const { width, height, left, right, imageWidth, mainHeight, line1, line2, hero, body, bottom, tokenX, tokenWidth } = layout;
  assert.equal(height, 1080);
  assert(right > left + 700 && right + imageWidth <= width - 45);
  const imageTop = 68;
  const imageBottom = 982;
  const split = (imageWidth - 12) / 2;
  const smallY = imageTop + mainHeight + 12;
  const smallHeight = imageBottom - smallY;
  assert(smallHeight > 0);
  const imagePanel = (id, x, y, w, h, src, zoom = false) => `
    <clipPath id="${id}"><rect x="${x}" y="${y}" width="${w}" height="${h}"/></clipPath>
    ${zoom
      ? `<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="280 130 700 400" preserveAspectRatio="xMidYMid slice"><image width="1280" height="720" href="${src}"/></svg>`
      : `<image x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="xMidYMid slice" clip-path="url(#${id})" href="${src}"/>`}`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    <style>
      text { font-family: 'Noto Sans CJK SC', sans-serif; font-weight: 900; }
    </style>
    <rect width="${width}" height="${height}" fill="${colors.bg}"/>
    <path d="M0 0H15V1080H0Z" fill="${colors.amber}"/>
    <text x="${left}" y="88" font-size="25" fill="${colors.dim}" letter-spacing="2">SALTLINE　GODOT 复刻</text>
    <rect x="${left}" y="105" width="78" height="7" fill="${colors.amber}"/>
    <text x="${left}" y="220" font-size="${line1}" fill="${colors.ink}">用 <tspan fill="${colors.blue}">Godot</tspan> 复刻</text>
    <text x="${left}" y="318" font-size="${line2}" fill="${colors.ink}">${escape(lines[1].trim())}</text>
    <text x="${left + 4}" y="474" font-size="${hero}" fill="#5c4025">${escape(lines[2])}</text>
    <text x="${left}" y="469" font-size="${hero}" fill="${colors.amber}">${escape(lines[2])}</text>
    <path d="M${left} 503H${right - 68}" stroke="${colors.line}" stroke-width="3"/>
    <text x="${left}" y="580" font-size="${body}" fill="${colors.ink}">${escape(lines[3])}</text>
    <text x="${left}" y="657" font-size="${body + 3}" fill="${colors.ink}">${escape(lines[4])}</text>
    <text x="${left}" y="734" font-size="${body - 1}" fill="${colors.ink}">${escape(lines[5])}</text>
    <text x="${left}" y="855" font-size="${bottom}" fill="${colors.ink}">${escape(lines[6].trim())}</text>
    <rect x="${tokenX}" y="800" width="${tokenWidth}" height="77" fill="${colors.amber}"/>
    <text x="${tokenX + 18}" y="855" font-size="${bottom + 4}" fill="${colors.bg}">${escape(lines[7])}</text>
    <text x="${left}" y="982" font-size="24" fill="${colors.dim}" letter-spacing="1">光照　材质　海水　动作</text>
    ${imagePanel('port', right, imageTop, imageWidth, mainHeight, images.port)}
    ${imagePanel('sea', right, smallY, split, smallHeight, images.sea)}
    ${imagePanel('enemy', right + split + 12, smallY, split, smallHeight, images.enemies, true)}
  </svg>`;
  return svg;
}

const layouts = [
  { name: '16x9', width: 1920, height: 1080, left: 76, right: 960, imageWidth: 887, mainHeight: 640, line1: 98, line2: 68, hero: 162, body: 57, bottom: 45, tokenX: 540, tokenWidth: 372 },
  { name: '4x3', width: 1440, height: 1080, left: 60, right: 814, imageWidth: 568, mainHeight: 640, line1: 85, line2: 62, hero: 148, body: 51, bottom: 39, tokenX: 450, tokenWidth: 346 },
];

mkdirSync(join(here, 'source'), { recursive: true });
for (const layout of layouts) {
  const svgPath = join(here, 'source', `saltline-cover-mg-${layout.name}.svg`);
  const pngPath = join(here, `saltline-cover-mg-${layout.name}.png`);
  writeFileSync(svgPath, cover(layout));
  execFileSync('magick', [svgPath, '-strip', pngPath], { stdio: 'inherit' });
  console.log(`${layout.name}: ${layout.width}x${layout.height} -> ${pngPath}`);
}
