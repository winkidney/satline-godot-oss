// Isolate the source render showcase's sun and environment without changing its assets.
const fs = require('fs');
const path = require('path');
const {chromium} = require('playwright');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'artifact-rendering-study/source/saltline.original.html'));
const output = path.join(root, 'video/review/calibration/ablation');
fs.mkdirSync(output, {recursive: true});
const cases = {full: [9, 2], sun: [9, 0], ibl: [0, 2]};
const scene = process.argv.find(value => value.startsWith('--scene='))?.slice(8) || 'render';
if (!['render', 'weapon'].includes(scene)) throw Error('Unsupported ablation scene');
const selected = process.argv.find(value => value.startsWith('--case='))?.slice(7);
const exposure = Number(process.argv.find(value => value.startsWith('--exposure='))?.slice(11) || 1);
const noAo = process.argv.includes('--no-ao');
if ((selected && !Object.hasOwn(cases, selected)) || !Number.isFinite(exposure) || exposure <= 0) throw Error('Invalid ablation settings');
(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist']});
  try {
    for (const [name, values] of Object.entries(cases)) {
      if (selected && name !== selected) continue;
      const page = await browser.newPage({viewport: {width: 1280, height: 720}});
      try {
        await page.route('**/*', route => new URL(route.request().url()).pathname === '/saltline.original.html'
          ? route.fulfill({status: 200, contentType: 'text/html', body: html}) : route.abort());
        const options = scene === 'weapon' ? '&wgun=rifle&wpose=side' : '';
        await page.goto('http://saltline-reference.invalid/saltline.original.html?q=high&shot=1&noaudio=1&dynres=0&show=' + scene + options);
        await page.waitForFunction(() => window.__ready || window.__fatal, null, {timeout: 180000});
        await page.addStyleTag({content: '#ui,#boot{display:none!important}'});
        await page.evaluate(([sun, environment, exposure, noAo]) => {
          const g = window.__G;
          g.render.autoExposure = false; g.render.exposure = exposure;
          g.render.sun.intensity = sun; g.scene.environmentIntensity = environment;
          if (noAo) g.quality.ao = false;
        }, [...values, exposure, noAo]);
        await page.waitForTimeout(5000);
        const state = await page.evaluate(() => {
          const g = window.__G;
          return {sun: g.render.sun.intensity, environment: g.scene.environmentIntensity,
            auto_exposure: g.render.autoExposure, exposure: g.render.exposure, ao: g.quality.ao, time: g.time, errors: window.__errors};
        });
        if (state.sun !== values[0] || state.environment !== values[1] || state.auto_exposure || (noAo && state.ao) || state.errors.length)
          throw Error(name + ': isolation did not persist');
        const prefix = 'source-' + (scene === 'render' ? '' : scene + '-') + name + (exposure === 1 ? '' : '-exp-' + String(exposure)) + (noAo ? '-no-ao' : '');
        await page.screenshot({path: path.join(output, prefix + '.png')});
        fs.writeFileSync(path.join(output, prefix + '.json'), JSON.stringify(state, null, 2) + '\n');
        console.log(name, JSON.stringify({sun: state.sun, environment: state.environment, exposure: state.exposure}));
      } finally { await page.close(); }
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
