// Bake source hand surface into an atlas; the runtime material remains Godot's built-in PBR.
const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');
const {chromium} = require('playwright');
const project = path.resolve(__dirname, '..');
const source = path.join(project, '../saltline-godot');
const output = path.join(project, 'assets/baked-arms');
const data = JSON.parse(fs.readFileSync(path.join(source, 'assets/prepared/scene.json')));
const nodes = Object.fromEntries(data.nodes.map(value => [value.id, value]));
const geometry = Object.fromEntries(data.geometries.map(value => [value.id, value]));
const shader = fs.readFileSync(path.join(source, 'shaders/arms.gdshader'), 'utf8');
const start = shader.indexOf('float aBand('), end = shader.indexOf('\n\nvarying vec3 v_view_pos;', start);
if (start < 0 || end < 0) throw Error('Source arm surface functions not found');
const functions = shader.slice(start, end);
fs.mkdirSync(output, {recursive: true});
function typed(filename, Type) {
  const bytes = fs.readFileSync(filename);
  return Array.from(new Type(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)));
}
(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist']});
  try {
    const page = await browser.newPage({acceptDownloads: true});
    for (const side of ['right', 'left']) {
      const mesh = nodes[data.modules.weapon.arms[side].mesh.$node];
      const item = geometry[mesh.geometry];
      const inputs = {};
      for (const name of ['position', 'normal', 'aRest', 'aHand'])
        inputs[name] = typed(path.join(source, 'assets/export', item.attributes[name].file), Float32Array);
      inputs.indices = typed(path.join(source, item.godot_index.replace(/^res:\/\//, '')), Int32Array);
      if (inputs.indices.length % 3 || inputs.indices.length / 3 > 128 * 128) throw Error('Arm atlas capacity exceeded');
      const result = await page.evaluate(({inputs, functions}) => {
        const size = 2048, cell = 16, cols = size / cell;
        const canvas = document.createElement('canvas'); canvas.width = size; canvas.height = size;
        const gl = canvas.getContext('webgl2', {antialias: false, preserveDrawingBuffer: true});
        if (!gl || gl.getParameter(gl.MAX_TEXTURE_SIZE) < size) throw Error('WebGL2 atlas size unavailable');
        function compile(type, code) {
          const s = gl.createShader(type); gl.shaderSource(s, code); gl.compileShader(s);
          if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw Error(gl.getShaderInfoLog(s));
          return s;
        }
        const vertex = `#version 300 es\nprecision highp float;in vec2 atlas;in vec3 position;in vec3 normal;in vec4 rest;in vec4 hand;out vec3 vp;out vec3 vn;out vec4 vr;out vec4 vh;void main(){vp=position;vn=normal;vr=rest;vh=hand;gl_Position=vec4(atlas*2.0-1.0,0.0,1.0);}`;
        const fragment = `#version 300 es\nprecision highp float;in vec3 vp;in vec3 vn;in vec4 vr;in vec4 vh;layout(location=0) out vec4 colorOut;layout(location=1) out vec4 normalOut;\n${functions}\nvec3 enc(vec3 c){return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));}\nvoid main(){vec3 px=dFdx(vp),py=dFdy(vp),ng=normalize(cross(px,py)),r1=cross(py,ng),r2=cross(ng,px);float gd=length(dFdx(vh.z)*r1+dFdy(vh.z)*r2)/max(abs(dot(px,r1)),1e-12);float rough,h,kind;vec3 c=armSurface(vh,vr,gd,rough,h,kind);c=armMicro(c,vh,vr,normalize(vn),kind,1.0,rough,h);vec3 n=normalize(vn),bumped=armBump(n,vp,h);vec3 t=normalize(px-n*dot(n,px)),b=normalize(py-n*dot(n,py)-t*dot(t,py));vec3 tangentN=normalize(vec3(dot(bumped,t),dot(bumped,b),dot(bumped,n)));colorOut=vec4(enc(clamp(c,0.0,1.0)),clamp(rough,0.0,1.0));normalOut=vec4(tangentN*0.5+0.5,1.0);}`;
        const program = gl.createProgram(); gl.attachShader(program, compile(gl.VERTEX_SHADER, vertex));
        gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragment)); gl.linkProgram(program);
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw Error(gl.getProgramInfoLog(program));
        gl.useProgram(program);
        const count = inputs.indices.length, atlas = new Float32Array(count * 2);
        const expanded = {position: new Float32Array(count * 3), normal: new Float32Array(count * 3),
          rest: new Float32Array(count * 4), hand: new Float32Array(count * 4)};
        for (let i = 0; i < count; i++) {
          const tri = Math.floor(i / 3), corner = i % 3, ix = inputs.indices[i];
          atlas[i*2] = ((tri % cols) * cell + (corner === 1 ? 14 : 2)) / size;
          atlas[i*2+1] = (Math.floor(tri / cols) * cell + (corner === 2 ? 14 : 2)) / size;
          for (const [name, sourceName, width] of [['position','position',3], ['normal','normal',3], ['rest','aRest',4], ['hand','aHand',4]])
            for (let k = 0; k < width; k++) expanded[name][i*width+k] = inputs[sourceName][ix*width+k];
        }
        for (const [name, values, width] of [['atlas', atlas, 2], ...Object.entries(expanded).map(([name, values]) => [name, values, name === 'rest' || name === 'hand' ? 4 : 3])]) {
          const buffer = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buffer); gl.bufferData(gl.ARRAY_BUFFER, values, gl.STATIC_DRAW);
          const loc = gl.getAttribLocation(program, name); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, width, gl.FLOAT, false, 0, 0);
        }
        const framebuffer = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
        for (let i = 0; i < 2; i++) {
          const texture = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, texture);
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, size, size, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
          gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0 + i, gl.TEXTURE_2D, texture, 0);
        }
        gl.drawBuffers([gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1]);
        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) throw Error('Incomplete atlas framebuffer');
        gl.viewport(0, 0, size, size); gl.clearColor(0,0,0,0); gl.clear(gl.COLOR_BUFFER_BIT); gl.disable(gl.CULL_FACE);
        gl.drawArrays(gl.TRIANGLES, 0, count); gl.finish();
        window.__armAtlas = [];
        for (let i = 0; i < 2; i++) {
          const pixels = new Uint8Array(size * size * 4); gl.readBuffer(gl.COLOR_ATTACHMENT0+i);
          gl.readPixels(0,0,size,size,gl.RGBA,gl.UNSIGNED_BYTE,pixels); window.__armAtlas.push(pixels);
        }
        if (gl.getError() !== gl.NO_ERROR) throw Error('Atlas readback failed');
        const debug = gl.getExtension('WEBGL_debug_renderer_info');
        return {triangles: count / 3, size, cell, renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : 'unavailable'};
      }, {inputs, functions});
      for (const [index, name] of [[0, 'color'], [1, 'normal']]) {
        const [download] = await Promise.all([page.waitForEvent('download'), page.evaluate(index => {
          const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([window.__armAtlas[index]]));
          a.download = 'atlas.raw'; a.click();
        }, index)]);
        await download.saveAs(path.join(output, item.id + '-' + name + '.raw'));
      }
      const process = spawnSync('python3', [path.join(project, 'tools/pad_arm_atlas.py'), item.id, String(result.triangles)], {encoding: 'utf8'});
      if (process.status !== 0) throw Error(process.stderr || 'Atlas padding failed');
      fs.writeFileSync(path.join(output, item.id + '-atlas.json'), JSON.stringify({...result, side,
        source: 'Offline source armSurface and armMicro bake; vertex UV seams and pose are approximate'}, null, 2) + '\n');
      console.log(side, result.triangles, 'triangles baked');
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
