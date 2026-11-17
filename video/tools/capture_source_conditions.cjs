// Capture camera, source light and exposure alongside a reproducible showcase reference.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {chromium} = require('playwright');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'artifact-rendering-study/source/saltline.original.html'));
const output = path.join(root, 'video/review/calibration/source');
fs.mkdirSync(output, {recursive: true});
const cases = {mats: {}, props: {}, render: {}, ground: {}, level: {}, backdrop: {bshow: 'all'},
  enemies: {eshow: 'both', efreeze: '1'}, weapon: {wgun: 'rifle', wpose: 'side'}, hands: {hview: 'palm', hpose: 'open'}, fx: {}};
const selected = process.argv.find(arg => arg.startsWith('--scene='))?.slice(8);
if (selected && !Object.hasOwn(cases, selected)) throw Error('Unknown source scene');
(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist', '--disable-background-timer-throttling']});
  try {
    for (const [scene, options] of Object.entries(cases)) {
      if (selected && scene !== selected) continue;
      const page = await browser.newPage({viewport: {width: 1280, height: 720}});
      try {
        await page.route('**/*', route => new URL(route.request().url()).pathname === '/saltline.original.html'
          ? route.fulfill({status: 200, contentType: 'text/html', body: html}) : route.abort());
        const query = new URLSearchParams({q: 'high', shot: '1', noaudio: '1', dynres: '0', show: scene, ...options});
        await page.goto('http://saltline-reference.invalid/saltline.original.html?' + query);
        await page.waitForFunction(() => window.__ready || window.__fatal, null, {timeout: 180000});
        await page.addStyleTag({content: '#ui,#boot{display:none!important}'});
        await page.waitForTimeout(5000);
        const data = await page.evaluate(() => {
          const g = window.__G, sun = g.scene.getObjectByName('sun'), stats = window.__stats();
          const canvas = document.querySelector('canvas'), gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
          const debug = gl && gl.getExtension('WEBGL_debug_renderer_info');
          const probes = [];
          if (g.showcase === 'weapon') {
            const ray = new g.THREE.Raycaster();
            ray.layers.mask = g.camera.layers.mask;
            for (const [x, y] of [[690, 480], [690, 510], [700, 450]]) {
              ray.setFromCamera(new g.THREE.Vector2(x / 640 - 1, 1 - y / 360), g.camera);
              const hit = ray.intersectObjects(g.scene.children, true).find(item => {
                for (let object = item.object; object; object = object.parent) if (!object.visible) return false;
                return item.object.isMesh;
              });
              const material = hit && (Array.isArray(hit.object.material) ? hit.object.material[hit.face.materialIndex] : hit.object.material);
              let attributes;
              if (hit?.face) {
                const geometry = hit.object.geometry, indices = [hit.face.a, hit.face.b, hit.face.c];
                const positions = indices.map(i => new g.THREE.Vector3().fromBufferAttribute(geometry.attributes.position, i));
                const bary = g.THREE.Triangle.getBarycoord(hit.object.worldToLocal(hit.point.clone()), ...positions, new g.THREE.Vector3());
                attributes = Object.fromEntries(['color', 'aSurf'].filter(key => geometry.attributes[key]).map(key => {
                  const attr = geometry.attributes[key];
                  return [key, Array.from({length: attr.itemSize}, (_, component) => indices.reduce((sum, index, j) =>
                    sum + attr.getComponent(index, component) * bary.getComponent(j), 0))];
                }));
              }
              probes.push({pixel: [x, y], object: hit?.object.name, material: material?.name,
                color: material?.color?.toArray(), roughness: material?.roughness, metalness: material?.metalness,
                normal: hit?.face.normal.clone().transformDirection(hit.object.matrixWorld).toArray(), attributes});
            }
          }
          return {time: g.time, camera: {position: g.camera.position.toArray(), quaternion: g.camera.quaternion.toArray(), fov: g.camera.fov},
            sun: {position: sun.position.toArray(), target: sun.target.position.toArray(), direction: g.render.sunDir.toArray(),
              color: sun.color.toArray(), intensity: sun.intensity}, environment_intensity: g.scene.environmentIntensity,
            exposure: g.render.exposure, auto_exposure: g.render.autoExposure, adapt: stats.adapt,
            actors: g.enemies?.list?.map(actor => ({type: actor.type, position: actor.pos.toArray(), yaw: actor.yaw})) || [],
            probes,
            renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : 'unavailable', fatal: window.__fatal, errors: window.__errors};
        });
        if (data.fatal || data.errors.length) throw Error(scene + ': source reported an error');
        await page.screenshot({path: path.join(output, scene + '.png')});
        fs.writeFileSync(path.join(output, scene + '.json'), JSON.stringify({scene, query: query.toString(),
          html_sha256: crypto.createHash('sha256').update(html).digest('hex'), ...data}, null, 2) + '\n');
        console.log(scene, 'adapt', data.adapt?.auto, 'frame', data.time.frame);
      } finally { await page.close(); }
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
