// Exploratory stepper — click a sequence of semantic labels in the persistent
// profile, then dump the resulting semantics tree (deduped) and screenshot.
// Used to discover the morning check-in flow's labels one beat at a time.
//
// Usage: NODE_PATH=$(npm root -g) node step.cjs <url> <profile> <outPng> "Label A" "Label B" ...
const { chromium } = require('playwright');

const [url, profileDir, outPng, ...labels] = process.argv.slice(2);

async function semantics(page) {
  return page.evaluate(() => {
    const out = [];
    document.querySelectorAll('flt-semantics').forEach((el) => {
      const t = (el.getAttribute('aria-label') || el.textContent || '').trim();
      const r = el.getBoundingClientRect();
      if (t && r.width > 0 && r.height > 0) {
        out.push({
          t, role: el.getAttribute('role') || '',
          x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2),
          w: Math.round(r.width), h: Math.round(r.height),
        });
      }
    });
    return out;
  });
}

async function enableSemantics(page) {
  await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 120000 });
  await page.waitForTimeout(3500);
  await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) ph.click();
  });
  await page.waitForTimeout(2000);
}

(async () => {
  const ctx = await chromium.launchPersistentContext(profileDir, {
    headless: true,
    args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
    viewport: { width: 430, height: 930 },
    deviceScaleFactor: 1,
  });
  const page = ctx.pages()[0] || (await ctx.newPage());
  page.on('pageerror', (e) => console.error('[pageerror]', e.message));
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  await enableSemantics(page);

  for (const label of labels) {
    const nodes = await semantics(page);
    const hits = nodes.filter((n) => n.t === label).sort((a, b) => a.w * a.h - b.w * b.h);
    if (!hits.length) { console.error('[step] NOT FOUND:', label); break; }
    await page.mouse.click(hits[0].x, hits[0].y);
    console.error('[step] clicked', label, '@', hits[0].x, hits[0].y);
    await page.waitForTimeout(1400);
  }

  const nodes = await semantics(page);
  // Drop the giant concatenated ancestor nodes — only leaves are useful here.
  const leaves = nodes.filter((n) => n.h < 200);
  console.log(JSON.stringify(leaves, null, 1));
  await page.screenshot({ path: outPng });
  await ctx.close();
})().catch((e) => { console.error('FATAL', e); process.exit(1); });
