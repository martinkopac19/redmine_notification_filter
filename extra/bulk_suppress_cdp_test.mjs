/* Hromadná úprava: „Neposílat notifikace" vľavo pod poznámkou, „Soukromé poznámky" vpravo.
 * Odošle komentár dvom úlohám so zaškrtnutým políčkom a overí, že nevznikla notifikácia
 * (inapp_notifications) — a pre porovnanie raz bez neho. Komentáre ostanú v histórii úloh.
 *
 *   node extra/bulk_suppress_cdp_test.mjs <base> <login> <heslo> <id1,id2> [port] [snimka.png]
 * Počty notifikácií vypíše test ako JS volanie na /issues/<id>.json nevie — overuje ich volajúci
 * cez DB (pozri výstup „journals"), test vypíše id vytvorených záznamov.
 */
const [BASE, LOGIN, PASS, IDS, PORT = '9401', SHOT] = process.argv.slice(2);
if (!IDS) { console.error('pouzitie: node bulk_suppress_cdp_test.mjs <base> <login> <heslo> <id1,id2> [port] [snimka]'); process.exit(2); }
const list = await (await fetch('http://127.0.0.1:' + PORT + '/json')).json();
const ws = new WebSocket(list.find(t => t.type === 'page').webSocketDebuggerUrl);
let id = 0; const pending = new Map();
const send = (m, p = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method: m, params: p })); });
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); } };
await new Promise(r => { ws.onopen = r; });
const sleep = ms => new Promise(r => setTimeout(r, ms));
const ev = async expr => {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r?.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || 'JS error');
  return r?.result?.value;
};
async function waitFor(expr, label, ms = 20000) {
  const until = Date.now() + ms;
  for (;;) { try { if (await ev(expr)) return true; } catch (e) {} if (Date.now() > until) throw new Error('timeout: ' + label); await sleep(150); }
}
async function nav(url) { await send('Page.navigate', { url }); await waitFor('document.readyState === "complete"', 'nacitanie'); await sleep(1300); }
const OK = []; const BAD = [];
function check(label, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  (ok ? OK : BAD).push(label);
  console.log('  ' + label.padEnd(60) + (ok ? 'OK' : '!! ZLE (' + JSON.stringify(got) + ', cakalo sa ' + JSON.stringify(want) + ')'));
}

await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false });
await nav(BASE + '/login');
if (await ev('!!document.getElementById("username")')) {
  await ev(`document.getElementById('username').value=${JSON.stringify(LOGIN)};document.getElementById('password').value=${JSON.stringify(PASS)};document.querySelector('#login-form form').submit();true`);
  await sleep(2500);
}
const ids = IDS.split(',');
const bulkUrl = BASE + '/issues/bulk_edit?' + ids.map(i => 'ids[]=' + i).join('&');

async function layout() {
  return ev(`(function(){
    var box=document.getElementById('nf_suppress_mail'), priv=document.querySelector('input[name="issue[private_notes]"]');
    if(!box) return {box:false};
    var notes=document.getElementById('notes'), fs=notes.closest('fieldset');
    var b=box.getBoundingClientRect(), p=priv.getBoundingClientRect();
    return {box:true, inNotes: fs.contains(box), inForm: !!box.closest('form'), sameRow: Math.abs(b.top-p.top)<6,
      boxLeftOfPriv: b.left < p.left, privRight: p.left > fs.getBoundingClientRect().left + fs.offsetWidth/2,
      label: box.parentNode.textContent.trim()};})()`);
}

console.log('1) rozloženie');
await nav(bulkUrl);
const l = await layout();
check('políčko je v sekcii Poznámky a vo formulári', [l.box, l.inNotes, l.inForm], [true, true, true]);
check('je v jednom riadku so Súkromnými poznámkami', l.sameRow, true);
check('políčko vľavo, Súkromné poznámky vpravo', [l.boxLeftOfPriv, l.privRight], [true, true]);
console.log('  text: ' + l.label);
if (SHOT) {
  await ev(`document.getElementById('notes').closest('fieldset').scrollIntoView({block:'center'}), true`);
  await sleep(300);
  const s = await send('Page.captureScreenshot', { format: 'png' });
  (await import('node:fs')).writeFileSync(SHOT, Buffer.from(s.data, 'base64'));
}

console.log('2) kopírovanie políčko nemá');
await nav(bulkUrl + '&copy=1');
check('pri kopírovaní sa nezobrazí', (await layout()).box, false);

async function submit(mute, text) {
  await nav(bulkUrl);
  await ev(`(function(){var ta=document.getElementById('notes'); if(ta._reEditor) ta._reEditor.commands.setContent(${JSON.stringify(text)}, true); ta.value=${JSON.stringify(text)};
    document.getElementById('nf_suppress_mail').checked=${mute}; return true;})()`);
  await ev(`(function(){var f=document.getElementById('notes').closest('form'); f.querySelector('input[type=submit]').click(); return true;})()`);
  await sleep(3000);
}
const stamp = Date.now();
console.log('3) odoslanie so zaškrtnutým políčkom a bez neho');
await submit(true, 'BULK_MUTE_' + stamp);
await submit(false, 'BULK_NOTIFY_' + stamp);
console.log('  značka: ' + stamp);
await nav('about:blank');
console.log(`\n${OK.length} OK, ${BAD.length} ZLE`);
process.exit(BAD.length ? 1 : 0);
