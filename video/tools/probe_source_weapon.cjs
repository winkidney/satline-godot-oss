// Read source fragment inputs and light terms at a fixed weapon pixel, bypassing post-processing.
const fs = require('fs');
const path = require('path');
const {chromium} = require('playwright');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'artifact-rendering-study/source/saltline.original.html'));
const output = path.join(root, 'video/review/calibration/weapon/source-fragment.json');

(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist', '--disable-background-timer-throttling']});
  try {
    const page = await browser.newPage({viewport: {width: 1280, height: 720}}), errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (message.type() === 'error' && !message.text().includes('net::ERR_FAILED')) errors.push(message.text()); });
    await page.route('**/*', route => new URL(route.request().url()).pathname === '/saltline.original.html'
      ? route.fulfill({status: 200, contentType: 'text/html', body: html}) : route.abort());
    await page.goto('http://saltline-reference.invalid/saltline.original.html?q=high&shot=1&noaudio=1&dynres=0&step=1&dt=0.016666667&show=weapon&wgun=rifle&wpose=side');
    await page.waitForFunction(() => (window.__ready && window.__step === 0) || window.__fatal, null, {timeout: 180000});
    await page.evaluate(() => { window.__step = 297; });
    await page.waitForFunction(() => window.__step === 0, null, {timeout: 180000});
    const data = await page.evaluate(() => {
      const g = window.__G, T = g.THREE, renderer = g.renderer, x = 690, y = 480;
      const ray = new T.Raycaster(); ray.layers.mask = g.camera.layers.mask;
      ray.setFromCamera(new T.Vector2(x / 640 - 1, 1 - y / 360), g.camera);
      const hit = ray.intersectObjects(g.scene.children, true).find(item => {
        for (let object = item.object; object; object = object.parent) if (!object.visible) return false;
        return item.object.isMesh;
      });
      if (!hit || Array.isArray(hit.object.material) || hit.object.material.name !== 'pac9_polymer_tan')
        throw Error('Visible weapon probe did not hit the expected material');
      const original = hit.object.material, material = original.clone(), callback = original.onBeforeCompile;
      let uniforms;
      material.onBeforeCompile = shader => {
        callback(shader); uniforms = shader.uniforms; uniforms.uProbe = {value: 0};
        const needle = '#include <opaque_fragment>';
        if (!shader.fragmentShader.includes(needle) || !shader.fragmentShader.includes('float dOcc =')) throw Error('Source shader changed');
        shader.fragmentShader = 'uniform int uProbe;\n' + shader.fragmentShader.replace(needle, `
          if (uProbe == 0) gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
          if (uProbe == 1) gl_FragColor = vec4(diffuseColor.rgb, 1.0);
          if (uProbe == 2) gl_FragColor = vec4(normal * 0.5 + 0.5, 1.0);
          if (uProbe == 3) gl_FragColor = vec4(reflectedLight.directDiffuse * 0.25, 1.0);
          if (uProbe == 4) gl_FragColor = vec4(reflectedLight.indirectDiffuse * 0.25, 1.0);
          if (uProbe == 5) gl_FragColor = vec4(reflectedLight.directSpecular * 0.25, 1.0);
          if (uProbe == 6) gl_FragColor = vec4(reflectedLight.indirectSpecular * 0.25, 1.0);
          return;`);
      };
      material.customProgramCacheKey = () => 'saltline-weapon-fragment-probe-v1';
      hit.object.material = material;
      const target = new T.WebGLRenderTarget(1280, 720, {depthBuffer: true});
      const previousTarget = renderer.getRenderTarget(), previousTone = renderer.toneMapping;
      renderer.toneMapping = T.NoToneMapping; renderer.setRenderTarget(target);
      const pixels = {};
      for (const [mode, name] of ['marker', 'albedo_linear', 'normal_view_encoded', 'direct_diffuse_div4',
                                  'indirect_diffuse_div4', 'direct_specular_div4', 'indirect_specular_div4'].entries()) {
        if (uniforms) uniforms.uProbe.value = mode;
        renderer.render(g.scene, g.camera);
        if (!uniforms) throw Error('Source probe material did not compile');
        const sample = new Uint8Array(4);
        renderer.readRenderTargetPixels(target, x, 719 - y, 1, 1, sample);
        pixels[name] = Array.from(sample);
      }
      renderer.setRenderTarget(previousTarget); renderer.toneMapping = previousTone;
      hit.object.material = original; material.dispose(); target.dispose();
      if (pixels.marker[0] !== 255 || pixels.marker[1] !== 0 || pixels.marker[2] !== 255)
        throw Error('Target pixel did not render the instrumented material: ' + pixels.marker);
      return {pixel: [x, y], time: g.time.t, camera: g.camera.position.toArray(),
        light: {sun: g.render.sun.intensity, environment: g.scene.environmentIntensity},
        note: 'RGBA8 linear target before source post-processing; diffuse/specular terms divided by four.', pixels};
    });
    if (errors.length) throw Error(errors.join('\n'));
    fs.writeFileSync(output, JSON.stringify(data, null, 2) + '\n');
    console.log(JSON.stringify(data));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
