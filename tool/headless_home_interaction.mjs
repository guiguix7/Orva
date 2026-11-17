// Development-only QA helper: drives the real Home through Chrome DevTools
// Protocol using Flutter's semantics tree, then captures the resulting screen.
// Requires headless Chrome on :9222 and the preview at BASE_URL.
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
const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, (message) =>
      message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result),
    );
    socket.send(JSON.stringify({ id, method, params }));
  });
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function evaluate(expression) {
  const result = await send('Runtime.evaluate', {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  return result.result?.value;
}

async function enableSemantics() {
  await evaluate(
    "(() => { const ph = document.querySelector('flt-semantics-placeholder'); if (ph) ph.click(); return !!ph; })()",
  );
  await wait(1200);
}

async function semanticsText() {
  return evaluate(
    "(() => { const host = document.querySelector('flt-semantics-host'); return host ? (host.innerText || '') : ''; })()",
  );
}

async function openHome() {
  await send('Emulation.setDeviceMetricsOverride', {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
  });
  await send('Page.navigate', { url: BASE });
  await wait(7000);
  await enableSemantics();
}

async function clickSemantics(label) {
  const candidates = await evaluate(`(() => {
    const host = document.querySelector('flt-semantics-host');
    if (!host) return [];
    return [...host.querySelectorAll('flt-semantics')]
      .filter((n) => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).includes(${JSON.stringify(label)}))
      .map((n) => {
        const r = n.getBoundingClientRect();
        return { label: (n.getAttribute('aria-label') || '').slice(0, 60), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
      })
      .filter((c) => c.w > 0 && c.h > 0);
  })()`);
  const target = (candidates ?? [])
    .slice()
    .sort((a, b) => a.w * a.h - b.w * b.h)[0];
  if (!target) return { clicked: false, reason: 'not-found', candidates: candidates?.length ?? 0 };
  const x = target.x + target.w / 2;
  const y = target.y + target.h / 2;
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  return { clicked: true, ...target, candidates: candidates.length };
}

async function shot(name) {
  const png = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.writeFileSync(`${OUT}/${name}.png`, Buffer.from(png.data, 'base64'));
  console.log(`saved ${name}.png`);
}

await send('Page.enable');
await send('Runtime.enable');

await openHome();
console.log('home text:', (await semanticsText()).slice(0, 220).replaceAll('\n', ' | '));

console.log('agenda click:', JSON.stringify(await clickSemantics('Agenda')));
await wait(3000);
await shot('390-agenda-open');
const calendarText = await semanticsText();
console.log('calendar reached:', calendarText.includes('Calendário'), '| day selector:', calendarText.includes('Dia'));

await openHome();
console.log('task click:', JSON.stringify(await clickSemantics('Tarefa')));
await wait(1500);
await shot('390-task-dialog');
const dialogText = await semanticsText();
console.log('task dialog reached:', dialogText.includes('Adicionar tarefa de hoje'));

await openHome();
console.log('block click:', JSON.stringify(await clickSemantics('Bloco')));
await wait(1500);
await shot('390-block-dialog');
console.log(
  'routine editor reached:',
  (await semanticsText()).includes('Novo bloco de rotina'),
);

await openHome();
console.log('execution click:', JSON.stringify(await clickSemantics('Registro')));
await wait(1500);
await shot('390-execution-dialog');
console.log(
  'execution editor reached:',
  (await semanticsText()).includes('Registrar execução manual'),
);

await openHome();
console.log('habit click:', JSON.stringify(await clickSemantics('Hábito')));
await wait(1500);
await shot('390-habit-sheet');
console.log(
  'habit sheet reached:',
  (await semanticsText()).includes('Registrar hábito'),
);

socket.close();
