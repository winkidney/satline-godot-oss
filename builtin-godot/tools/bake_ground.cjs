// Bake one source ground state for comparison using only built-in materials at runtime.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {chromium} = require('playwright');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'artifact-rendering-study/source/saltline.original.html'));
const output = path.join(root, 'builtin-godot/assets/baked-ground');
fs.mkdirSync(output, {recursive: true});

(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist', '--disable-background-timer-throttling']});
  try {
    const page = await browser.newPage({viewport: {width: 1280, height: 720}, acceptDownloads: true});
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error' && !message.text().includes('net::ERR_FAILED')) errors.push(message.text());
    });
    await page.route('**/*', route => new URL(route.request().url()).pathname === '/saltline.original.html'
      ? route.fulfill({status: 200, contentType: 'text/html', body: html}) : route.abort());
    await page.goto('http://saltline-reference.invalid/saltline.original.html?q=high&shot=1&noaudio=1&dynres=0&step=1&dt=0.016666667&show=ground');
    await page.waitForFunction(() => (window.__ready && window.__step === 0) || window.__fatal, null, {timeout: 180000});
    await page.evaluate(() => { window.__step = 297; });
    await page.waitForFunction(() => window.__step === 0, null, {timeout: 180000});
    const metadata = await page.evaluate(() => {
      const g = window.__G, T = g.THREE, apron = g.scene.getObjectByName('apron');
      if (!T || !apron || apron.material.name !== 'apron_wet' || window.__fatal || window.__errors.length)
        throw Error('Expected source apron material and a healthy game');
      const renderer = g.renderer, original = apron.material;
      const bake = original.clone(), callback = original.onBeforeCompile;
      const eye = g.camera.position.clone();
      let compiled = false, sourceUniforms;
      bake.onBeforeCompile = shader => {
        callback(shader);
        sourceUniforms = shader.uniforms;
        shader.uniforms.uBakeMode = {value: 0};
        shader.uniforms.uBakeEye = {value: eye};
        const needle = '#include <opaque_fragment>';
        if (!shader.fragmentShader.includes(needle) || !shader.fragmentShader.includes('gRough = rough;'))
          throw Error('Source ground shader changed');
        shader.fragmentShader = 'uniform int uBakeMode; uniform vec3 uBakeEye;\n' + shader.fragmentShader
          .replaceAll('cameraPosition - vGWorld', 'uBakeEye - vGWorld')
          .replace(needle, `
            if (uBakeMode == 0) {
              vec3 c = clamp(diffuseColor.rgb, 0.0, 1.0);
              vec3 srgb = mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
                              step(vec3(0.0031308), c));
              gl_FragColor = vec4(srgb, clamp(gRough, 0.0, 1.0));
            } else {
              vec3 n = normalize(vec3(-gNxz.x, 1.0, -gNxz.y));
              gl_FragColor = vec4(vec3(n.x, -n.z, n.y) * 0.5 + 0.5, 1.0);
            }
            return;`);
        compiled = true;
      };
      bake.customProgramCacheKey = () => 'saltline-ground-offline-bake-v1';
      const scene = new T.Scene(), mesh = apron.clone();
      mesh.material = bake;
      mesh.matrixAutoUpdate = false;
      mesh.matrix.copy(apron.matrixWorld);
      scene.add(mesh);
      // World x [-16, 30], z [-32, 40]; image origin is the lower-left readback pixel.
      const camera = new T.OrthographicCamera(-23, 23, 36, -36, 0.1, 200);
      camera.position.set(7, 100, 4); camera.up.set(0, 0, -1); camera.lookAt(7, 0, 4);
      const target = new T.WebGLRenderTarget(2048, 2048, {depthBuffer: true});
      const previousTarget = renderer.getRenderTarget(), previousTone = renderer.toneMapping;
      renderer.toneMapping = T.NoToneMapping;
      renderer.setRenderTarget(target);
      window.__groundAtlas = [];
      for (let mode = 0; mode < 2; mode++) {
        if (compiled) sourceUniforms.uBakeMode.value = mode;
        renderer.render(scene, camera);
        if (!compiled) throw Error('Ground material did not compile');
        const pixels = new Uint8Array(2048 * 2048 * 4);
        renderer.readRenderTargetPixels(target, 0, 0, 2048, 2048, pixels);
        window.__groundAtlas.push(pixels);
      }
      renderer.setRenderTarget(previousTarget); renderer.toneMapping = previousTone;
      target.dispose(); bake.dispose();
      return {size: [2048, 2048], x: [-16, 30], z: [-32, 40], time: g.time.t,
        eye: eye.toArray(), wet: sourceUniforms.uWetG.value, rain: sourceUniforms.uRain.value,
        source: 'Source apron albedo, roughness and normals baked offline; view distance and time are fixed'};
    });
    if (errors.length) throw Error('Browser errors: ' + errors.join('\n'));
    for (const [index, name] of [[0, 'color-roughness'], [1, 'normal']]) {
      const [download] = await Promise.all([page.waitForEvent('download'), page.evaluate(index => {
        const link = document.createElement('a');
        link.href = URL.createObjectURL(new Blob([window.__groundAtlas[index]])); link.download = 'ground.raw'; link.click();
      }, index)]);
      const destination = path.join(output, name + '.rgba8');
      await download.saveAs(destination);
      const bytes = fs.readFileSync(destination);
      if (bytes.length !== 2048 * 2048 * 4 || !bytes.some(value => value !== 0)) throw Error('Invalid ground readback');
      metadata[name + '_sha256'] = crypto.createHash('sha256').update(bytes).digest('hex');
      if (name === 'color-roughness') {
        const roughness = Buffer.alloc(2048 * 2048);
        // The native reflection model needs a higher floor than the source planar reflection.
        for (let i = 0; i < roughness.length; i++) roughness[i] = Math.max(51, bytes[i * 4 + 3]);
        fs.writeFileSync(path.join(output, 'roughness.r8'), roughness);
        metadata.roughness_floor_rgb8 = 51;
        metadata.roughness_sha256 = crypto.createHash('sha256').update(roughness).digest('hex');
      }
    }
    metadata.html_sha256 = crypto.createHash('sha256').update(html).digest('hex');
    fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(metadata, null, 2) + '\n');
    console.log(JSON.stringify(metadata));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
