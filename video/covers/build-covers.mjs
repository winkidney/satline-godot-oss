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
  const split = (imageWidth - 16) / 2;
  const smallY = 720;
  const label = (x, y, text) => `<text x="${x}" y="${y}" class="label">${escape(text)}</text>`;
  const imagePanel = (id, x, y, w, h, src, name, number, zoom = false) => `
    <clipPath id="${id}"><rect x="${x}" y="${y}" width="${w}" height="${h - 41}"/></clipPath>
    <rect x="${x - 3}" y="${y - 3}" width="${w + 6}" height="${h + 6}" fill="${colors.line}"/>
    ${zoom
      ? `<svg x="${x}" y="${y}" width="${w}" height="${h - 41}" viewBox="280 130 700 400" preserveAspectRatio="xMidYMid slice"><image width="1280" height="720" href="${src}"/></svg>`
      : `<image x="${x}" y="${y}" width="${w}" height="${h - 41}" preserveAspectRatio="xMidYMid slice" clip-path="url(#${id})" href="${src}"/>`}
    <rect x="${x}" y="${y + h - 41}" width="${w}" height="41" fill="${colors.bg}"/>
    ${label(x + 15, y + h - 13, name)}
    <text x="${x + w - 14}" y="${y + h - 13}" class="label" text-anchor="end" fill="${colors.amber}">${number}</text>`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    <style>
      text { font-family: 'Noto Sans CJK SC', sans-serif; font-weight: 900; }
      .label { font-size: 22px; fill: ${colors.ink}; letter-spacing: 1px; }
    </style>
    <rect width="${width}" height="${height}" fill="${colors.bg}"/>
    <path d="M0 0H15V1080H0Z" fill="${colors.amber}"/>
    <path d="M${right - 6} 40H${width - 45}V47H${right - 6}Z" fill="${colors.blue}"/>
    <path d="M${right - 4} 986H${width - 45}V990H${right - 4}Z" fill="${colors.line}"/>
    <path d="M${right + imageWidth - 168} 55h26l-12 16h-26z m38 0h26l-12 16h-26z m38 0h26l-12 16h-26z m38 0h26l-12 16h-26z" fill="${colors.amber}"/>
    <g stroke="${colors.line}" stroke-width="2" fill="none" opacity=".62">
      <path d="M${right + 35} 85H${right + imageWidth - 34} M${right + 35} 96H${right + 100}"/>
      <path d="M${right + 25} 956H${right + imageWidth - 25} M${right + 25} 946V966 M${right + imageWidth - 25} 946V966"/>
      <circle cx="${right + 28}" cy="85" r="4"/><circle cx="${right + imageWidth - 28}" cy="85" r="4"/>
    </g>
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
    ${imagePanel('port', right, 142, imageWidth, mainHeight, images.port, '集装箱　地面倒影', '01')}
    ${imagePanel('sea', right, smallY, split, 213, images.sea, '海水', '02')}
    ${imagePanel('enemy', right + split + 16, smallY, split, 213, images.enemies, '机械敌人', '03', true)}
  </svg>`;
  return svg;
}

const layouts = [
  { name: '16x9', width: 1920, height: 1080, left: 76, right: 960, imageWidth: 887, mainHeight: 550, line1: 98, line2: 68, hero: 162, body: 57, bottom: 45, tokenX: 540, tokenWidth: 372 },
  { name: '4x3', width: 1440, height: 1080, left: 60, right: 814, imageWidth: 568, mainHeight: 550, line1: 85, line2: 62, hero: 148, body: 51, bottom: 39, tokenX: 450, tokenWidth: 346 },
];

mkdirSync(join(here, 'source'), { recursive: true });
for (const layout of layouts) {
  const svgPath = join(here, 'source', `saltline-cover-mg-${layout.name}.svg`);
  const pngPath = join(here, `saltline-cover-mg-${layout.name}.png`);
  writeFileSync(svgPath, cover(layout));
  execFileSync('magick', [svgPath, '-strip', pngPath], { stdio: 'inherit' });
  console.log(`${layout.name}: ${layout.width}x${layout.height} -> ${pngPath}`);
}
