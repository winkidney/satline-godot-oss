// Bake the source arm's static surface color at mesh vertices; runtime remains StandardMaterial3D.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {chromium} = require('playwright');
const project = path.resolve(__dirname, '..');
const source = path.join(project, '../saltline-godot');
const data = JSON.parse(fs.readFileSync(path.join(source, 'assets/prepared/scene.json')));
const nodes = Object.fromEntries(data.nodes.map(value => [value.id, value]));
const geometry = Object.fromEntries(data.geometries.map(value => [value.id, value]));
const shader = fs.readFileSync(path.join(source, 'shaders/arms.gdshader'), 'utf8');
const start = shader.indexOf('float aBand('), end = shader.indexOf('// sub-millimetre detail', start);
if (start < 0 || end < 0) throw Error('Source arm surface function not found');
const functions = shader.slice(start, end);
const output = path.join(project, 'assets/baked-arms');
fs.mkdirSync(output, {recursive: true});
function floats(filename) {
  const bytes = fs.readFileSync(path.join(source, 'assets/export', filename));
  return Array.from(new Float32Array(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)));
}
(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist']});
  const manifest = {};
  try {
    const page = await browser.newPage();
    for (const side of ['right', 'left']) {
      const mesh = nodes[data.modules.weapon.arms[side].mesh.$node];
      const item = geometry[mesh.geometry];
      const rest = floats(item.attributes.aRest.file), hand = floats(item.attributes.aHand.file);
      if (rest.length !== hand.length || rest.length !== item.attributes.position.count * 4) throw Error('Arm attribute count mismatch');
      const result = await page.evaluate(({rest, hand, functions}) => {
        const gl = document.createElement('canvas').getContext('webgl2');
        if (!gl) throw Error('WebGL2 is required to bake source arm colors');
        function compile(type, code) {
          const shader = gl.createShader(type); gl.shaderSource(shader, code); gl.compileShader(shader);
          if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw Error(gl.getShaderInfoLog(shader));
          return shader;
        }
        const vertex = `#version 300 es\nprecision highp float;\nin vec4 aRest; in vec4 aHand; out vec4 baked;\n${functions}\nvoid main(){float r,h,k;vec3 c=armSurface(aHand,aRest,100.0,r,h,k);baked=vec4(c,r);gl_Position=vec4(0.0);}`;
        const fragment = '#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1.0);}';
        const program = gl.createProgram(); gl.attachShader(program, compile(gl.VERTEX_SHADER, vertex));
        gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragment));
        gl.transformFeedbackVaryings(program, ['baked'], gl.INTERLEAVED_ATTRIBS); gl.linkProgram(program);
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw Error(gl.getProgramInfoLog(program));
        gl.useProgram(program);
        for (const [name, values] of [['aRest', rest], ['aHand', hand]]) {
          const buffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buffer); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(values), gl.STATIC_DRAW);
          const loc = gl.getAttribLocation(program, name); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 4, gl.FLOAT, false, 0, 0);
        }
        const result = new Float32Array(rest.length), feedback = gl.createBuffer();
        gl.bindBuffer(gl.TRANSFORM_FEEDBACK_BUFFER, feedback); gl.bufferData(gl.TRANSFORM_FEEDBACK_BUFFER, result.byteLength, gl.STREAM_READ);
        gl.bindBufferBase(gl.TRANSFORM_FEEDBACK_BUFFER, 0, feedback); gl.enable(gl.RASTERIZER_DISCARD);
        gl.beginTransformFeedback(gl.POINTS); gl.drawArrays(gl.POINTS, 0, rest.length / 4); gl.endTransformFeedback(); gl.finish();
        gl.getBufferSubData(gl.TRANSFORM_FEEDBACK_BUFFER, 0, result);
        if (gl.getError() !== gl.NO_ERROR || !Array.from(result).every(Number.isFinite)) throw Error('Invalid arm bake output');
        const debug = gl.getExtension('WEBGL_debug_renderer_info');
        return {values: Array.from(result), renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : 'unavailable'};
      }, {rest, hand, functions});
      const bytes = Buffer.alloc(result.values.length * 4);
      result.values.forEach((value, index) => bytes.writeFloatLE(value, index * 4));
      const filename = item.id + '.rgba32f';
      fs.writeFileSync(path.join(output, filename), bytes);
      manifest[item.id] = {file: filename, side, vertices: item.attributes.position.count,
        format: 'RGBA32F: linear RGB and roughness', source: 'armSurface at vertices; gD=100; no armMicro or wet beads',
        renderer: result.renderer, sha256: crypto.createHash('sha256').update(bytes).digest('hex')};
      console.log(side, item.attributes.position.count, 'vertices baked');
    }
    fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
