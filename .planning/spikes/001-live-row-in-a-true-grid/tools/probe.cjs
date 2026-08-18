// Probe: load the served debug build in a persistent profile, turn on Flutter's
// semantics tree, and dump every semantic node's text so we can see which screen
// the profile is sitting on (onboarding beat vs. the Today timeline).
//
// Usage: NODE_PATH=$(npm root -g) node probe.cjs <url> <profileDir> [outPng]
const { chromium } = require('playwright');

(async () => {
  const [url, profileDir, outPng] = process.argv.slice(2);
  const ctx = await chromium.launchPersistentContext(profileDir, {
    headless: true,
    args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
    viewport: { width: 430, height: 930 },
    deviceScaleFactor: 1,
  });
  const page = ctx.pages()[0] || (await ctx.newPage());
  page.on('console', (m) => console.error('[console]', m.type(), m.text()));
  page.on('pageerror', (e) => console.error('[pageerror]', e.message));

  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  // Flutter web boots asynchronously; wait for the canvas host element.
  await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 120000 });
  await page.waitForTimeout(4000);

  // Flutter renders to canvas — no DOM text — until the semantics tree is on.
  // The hidden placeholder button is the documented way to switch it on.
  const enabled = await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (!ph) return 'no-placeholder';
    ph.click();
    return 'clicked';
  });
  console.error('[semantics]', enabled);
  await page.waitForTimeout(2500);

  const nodes = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll('flt-semantics').forEach((el) => {
      const t = (el.getAttribute('aria-label') || el.textContent || '').trim();
      const r = el.getBoundingClientRect();
      if (t) out.push({ t, x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), role: el.getAttribute('role') || '' });
    });
    return out;
  });
  console.log(JSON.stringify(nodes, null, 1));

  if (outPng) await page.screenshot({ path: outPng, fullPage: false });
  await ctx.close();
})().catch((e) => { console.error('FATAL', e); process.exit(1); });
