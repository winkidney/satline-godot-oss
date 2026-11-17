// Record the source canvas at its normal timestep; each case is captured separately.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {chromium} = require('playwright');

const cases = {
  mats: {}, props: {}, render: {}, ground: {}, level: {},
  backdrop: {bshow: 'all'}, enemies: {eshow: 'both'},
  weapon: {wgun: 'rifle', wpose: 'side'},
  hands: {hview: 'palm', hpose: 'open'}, fx: {},
};
const scene = process.argv[2];
const seconds = Number(process.argv[3] || 10);
const freeze = process.argv.includes('--freeze');
if (!Object.hasOwn(cases, scene) || !Number.isFinite(seconds) || seconds < 1 || seconds > 60) {
  throw Error('Usage: node record_showcase_original.cjs SCENE [SECONDS]');
}
if (freeze && scene !== 'enemies') throw Error('Frozen capture is only defined for the enemy showcase');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'artifact-rendering-study/source/saltline.original.html'));
const out = path.join(root, 'video/recordings/showcases', freeze ? 'original-frozen' : 'original');
fs.mkdirSync(out, {recursive: true});
const query = new URLSearchParams({q: 'high', shot: '1', noaudio: '1', dynres: '0', show: scene, ...cases[scene], ...(freeze ? {efreeze: '1'} : {})});

(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/google-chrome', headless: false,
    args: ['--no-sandbox', '--use-angle=gl', '--ignore-gpu-blocklist', '--disable-background-timer-throttling']});
  try {
    const page = await browser.newPage({viewport: {width: 1920, height: 1080}, acceptDownloads: true});
    await page.route('**/*', route => new URL(route.request().url()).pathname === '/saltline.original.html'
      ? route.fulfill({status: 200, contentType: 'text/html', body: html}) : route.abort());
    await page.goto('http://saltline-reference.invalid/saltline.original.html?' + query);
    await page.waitForFunction(() => window.__ready || window.__fatal, null, {timeout: 180000});
    const fatal = await page.evaluate(() => window.__fatal);
    if (fatal) throw Error('Source failed to initialize: ' + fatal);
    await page.addStyleTag({content: '#ui,#boot{display:none!important}'});
    await page.waitForTimeout(2000);
    await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      const stream = canvas.captureStream(60);
      const recorder = new MediaRecorder(stream, {mimeType: 'video/webm;codecs=vp8', videoBitsPerSecond: 16000000});
      const chunks = [];
      recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
      recorder.start(1000);
      window.__filmCapture = {recorder, chunks, stream, started: performance.now(), frames: window.__frames};
    });
    await page.waitForTimeout(seconds * 1000);
    const stats = await page.evaluate(() => {
      const capture = window.__filmCapture;
      const canvas = document.querySelector('canvas');
      const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
      const debug = gl && gl.getExtension('WEBGL_debug_renderer_info');
      return {seconds: (performance.now() - capture.started) / 1000, frames: window.__frames - capture.frames,
        renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : 'unavailable',
        canvas: [canvas.width, canvas.height], fatal: window.__fatal, errors: window.__errors};
    });
    const [download] = await Promise.all([page.waitForEvent('download'), page.evaluate(async () => {
      const capture = window.__filmCapture;
      await new Promise(resolve => { capture.recorder.onstop = resolve; capture.recorder.stop(); });
      const link = document.createElement('a');
      link.href = URL.createObjectURL(new Blob(capture.chunks, {type: 'video/webm'}));
      link.download = 'capture.webm'; link.click();
      capture.stream.getTracks().forEach(track => track.stop());
    })]);
    await download.saveAs(path.join(out, scene + '.webm'));
    fs.writeFileSync(path.join(out, scene + '.json'), JSON.stringify({scene, query: query.toString(),
      source_sha256: crypto.createHash('sha256').update(html).digest('hex'), ...stats}, null, 2) + '\n');
    if (stats.fatal || stats.errors.length) throw Error('Source reported errors; inspect the capture report');
    console.log(JSON.stringify({scene, ...stats}));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
