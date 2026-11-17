#!/usr/bin/env node
// Parse trusted-as-data JS with Prettier's Babel parser. No eval/import of the game.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const [input, babelPlugin, output] = process.argv.slice(2);
if (!input || !babelPlugin || !output) {
  console.error('Usage: node extract_shaders.cjs INPUT_JS PRETTIER_BABEL_PLUGIN OUTPUT_DIR');
  process.exit(2);
}
const source = fs.readFileSync(input, 'utf8');
const ast = require(path.resolve(babelPlugin)).parsers.babel.parse(source);
const records = [];
fs.mkdirSync(output, { recursive: true });
function visit(node, parent) {
  if (!node || typeof node !== 'object') return;
  if (node.type === 'TemplateLiteral' && node.loc.start.line >= 34630) {
    const interpolated = node.expressions.length > 0;
    const text = interpolated ? source.slice(node.start + 1, node.end - 1) : node.quasis.map(x => x.value.cooked).join('');
    if (text.length > 80 && /\b(?:uniform|varying|attribute|gl_FragColor|void\s+(?:main|surf)|vec[234]\s+\w+\s*\()/.test(text)) {
      const label = parent?.type === 'VariableDeclarator' ? parent.id?.name : 'fragment';
      const file = `${String(node.loc.start.line).padStart(5, '0')}-${label || 'fragment'}.glsl${interpolated ? '.template' : ''}`;
      fs.writeFileSync(path.join(output, file), text);
      records.push({file, source_line: node.loc.start.line, end_line: node.loc.end.line, interpolated,
        bytes: Buffer.byteLength(text), sha256: crypto.createHash('sha256').update(text).digest('hex')});
    }
  }
  for (const [key, value] of Object.entries(node)) {
    if (['loc', 'range', 'tokens', 'comments', 'errors'].includes(key)) continue;
    if (Array.isArray(value)) value.forEach(x => visit(x, node));
    else if (value && typeof value === 'object') visit(value, node);
  }
}
visit(ast, null);
fs.writeFileSync(path.join(output, 'index.json'), JSON.stringify({
  source: '../extracted/bundle-1.js',
  method: 'AST extraction of GLSL-like template literals after the Three.js library',
  limitations: 'Some files are patch fragments, not standalone shaders. .glsl.template preserves JavaScript interpolation without evaluating it. Ordinary strings are not extracted. No compile or render validation.',
  shaders: records
}, null, 2) + '\n');
console.log(JSON.stringify({extracted_fragments: records.length}));
