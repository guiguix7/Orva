// Development-only QA helper: captures the real Home preview through the
// Chrome DevTools Protocol at several viewports, including dark and empty
// states. Run with a headless Chrome exposing port 9222 and the preview served
// at BASE_URL. Not part of the shipped app.
import fs from 'node:fs';

const BASE = process.env.BASE_URL ?? 'http://127.0.0.1:8103/';
const OUT = process.env.OUT_DIR ?? 'screenshots/home-qa';

const targets = await (await fetch('http://127.0.0.1:9222/json/list')).json();
const page = targets.find((target) => target.type === 'page');
if (!page) throw new Error('No Chrome page target available on :9222');

const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve);
  socket.addEventListener('error', reject);
});

let nextId = 0;
const pending = new Map();
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const resolve = pending.get(message.id);
    pending.delete(message.id);
    resolve(message);
  }
});

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, (message) =>
      message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result),
    );
    socket.send(JSON.stringify({ id, method, params }));
  });
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitForCanvas() {
  for (let attempt = 0; attempt < 40; attempt++) {
    const result = await send('Runtime.evaluate', {
      expression:
        "(() => { const p = document.querySelector('flt-glass-pane'); return !!p; })()",
      returnByValue: true,
    });
    if (result.result?.value === true) return true;
    await wait(500);
  }
  return false;
}

async function capture(name, width, height, query = '') {
  await send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width < 600,
  });
  await send('Page.navigate', { url: `${BASE}${query}` });
  const ready = await waitForCanvas();
  if (!ready) console.warn(`canvas not detected for ${name}`);
  await wait(7000);
  const shot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });
  fs.writeFileSync(`${OUT}/${name}.png`, Buffer.from(shot.data, 'base64'));
  console.log(`saved ${name}.png (${width}x${height})`);
}

await send('Page.enable');
await send('Runtime.enable');

await capture('390-light', 390, 844);
await capture('430-light', 430, 932);
await capture('768-light', 768, 1024);
await capture('1440-light', 1440, 900);
await capture('390-dark', 390, 844, '?theme=dark');

// Fresh IndexedDB so the empty state is real, then reload without seeding.
await send('Runtime.evaluate', {
  expression:
    "(async () => { const dbs = await indexedDB.databases(); await Promise.all(dbs.map((info) => new Promise((resolve) => { const request = indexedDB.deleteDatabase(info.name); request.onsuccess = request.onerror = request.onblocked = () => resolve(); }))); return dbs.length; })()",
  awaitPromise: true,
  returnByValue: true,
});
await capture('390-empty', 390, 844, '?empty=1');

socket.close();
