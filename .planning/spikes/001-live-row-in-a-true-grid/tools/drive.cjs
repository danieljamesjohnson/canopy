// Spike 001 driver — onboards a persistent Chromium profile once, then parks it
// on the Today timeline at an exact simulated time and screenshots the result.
//
// Why a persistent profile: the app's data lives in IndexedDB (Hive) keyed by
// origin, so onboarding + schedule generation happen ONCE and every build
// variant served on the same port sees the identical day. That makes the
// variant screenshots genuinely comparable — same goals, same chunks, same
// clock — so any pixel difference is the variant, not the fixture.
//
// Why localStorage for the clock: DevClock persists its offset through
// SharedPreferences, which on web is localStorage['flutter.<key>'] (technique
// established in 26-08-SUMMARY.md). Writing it directly gives an exact target
// time instead of the debug UI's coarse +1h/-1h buttons.
//
// Usage:
//   NODE_PATH=$(npm root -g) node drive.cjs <url> <profileDir> <outPng> [opts]
//     --at=HH:MM        simulated wall-clock time to park at (local)
//     --scroll=N        scroll the timeline by N px before shooting
//     --full            full-page screenshot
//     --dump            print the semantics tree as JSON to stdout
const { chromium } = require('playwright');

const args = process.argv.slice(2);
const [url, profileDir, outPng] = args.filter((a) => !a.startsWith('--'));
const opt = (name, dflt) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : dflt;
};
const flag = (name) => args.includes(`--${name}`);

const AT = opt('at', null);
const SCROLL = parseInt(opt('scroll', '0'), 10);

async function semantics(page) {
  return page.evaluate(() => {
    const out = [];
    document.querySelectorAll('flt-semantics').forEach((el) => {
      const t = (el.getAttribute('aria-label') || el.textContent || '').trim();
      const r = el.getBoundingClientRect();
      if (t && r.width > 0 && r.height > 0) {
        out.push({
          t,
          role: el.getAttribute('role') || '',
          x: Math.round(r.x + r.width / 2),
          y: Math.round(r.y + r.height / 2),
          w: Math.round(r.width),
          h: Math.round(r.height),
        });
      }
    });
    return out;
  });
}

// Click by exact semantic label. Flutter's semantic nodes nest (the whole
// screen carries the concatenated text of its children), so match on an exact
// label and prefer the smallest box — that's the leaf that actually handles
// the tap.
async function clickLabel(page, label, { role = null } = {}) {
  const nodes = await semantics(page);
  const hits = nodes
    .filter((n) => n.t === label && (role === null || n.role === role))
    .sort((a, b) => a.w * a.h - b.w * b.h);
  if (!hits.length) return false;
  await page.mouse.click(hits[0].x, hits[0].y);
  await page.waitForTimeout(900);
  return true;
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

async function onboardIfNeeded(page) {
  let nodes = await semantics(page);
  const screenText = nodes.length ? nodes[0].t : '';
  if (!screenText.includes('What are your goals?')) return false;

  // Beat 1 — goals. Two goals so the generated day has more than one work
  // chunk, which is what makes the hour-grid spacing readable.
  await clickLabel(page, 'Exercise', { role: 'checkbox' });
  await clickLabel(page, 'Side project', { role: 'checkbox' });
  await clickLabel(page, 'Continue', { role: 'button' });

  // Beats 2-4 — take the shortest path through restoratives, energy, and the
  // fixed-commitment question; none of them affect hour geometry.
  for (let i = 0; i < 8; i++) {
    nodes = await semantics(page);
    const labels = new Set(nodes.map((n) => n.t));
    if (labels.has("I don't have a fixed commitment")) {
      await clickLabel(page, "I don't have a fixed commitment");
      continue;
    }
    if (labels.has('Continue')) {
      await clickLabel(page, 'Continue', { role: 'button' });
      continue;
    }
    if (labels.has('Skip')) {
      await clickLabel(page, 'Skip', { role: 'button' });
      continue;
    }
    break;
  }
  await page.waitForTimeout(3000);
  return true;
}

// The morning check-in is what actually generates the day. Without it the
// Today screen only offers "Start check-in" and there is no timeline to look
// at. Mood is fixed at "partly cloudy" so every variant gets the same chunk
// count.
async function checkInIfNeeded(page) {
  const nodes = await semantics(page);
  const labels = new Set(nodes.map((n) => n.t));
  if (!labels.has('Start check-in')) return false;
  await clickLabel(page, 'Start check-in');
  await clickLabel(page, '⛅');
  await clickLabel(page, "Let's go");
  await page.waitForTimeout(2500);
  console.error('[drive] check-in completed');
  return true;
}

// After a fresh check-in the day opens on a full-bleed "Tap or swipe up to
// begin" splash that carries no semantic label — tap the middle of the
// viewport to get past it to the timeline.
async function dismissSplash(page) {
  const isSplash = await page.evaluate(() => {
    const root = document.querySelector('flt-semantics');
    return !!root && /Tap or swipe up to begin/.test(root.textContent || '');
  });
  if (!isSplash) return false;
  await page.mouse.click(215, 465);
  await page.waitForTimeout(2000);
  console.error('[drive] splash dismissed');
  return true;
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

  const didOnboard = await onboardIfNeeded(page);
  if (didOnboard) console.error('[drive] onboarding completed');
  await checkInIfNeeded(page);
  await dismissSplash(page);

  if (AT) {
    const [h, m] = AT.split(':').map(Number);
    await page.evaluate(
      ({ h, m }) => {
        const now = new Date();
        const target = new Date(
          now.getFullYear(), now.getMonth(), now.getDate(), h, m, 0, 0,
        );
        const micros = (target.getTime() - now.getTime()) * 1000;
        window.localStorage.setItem(
          'flutter.dev_clock_offset_micros',
          JSON.stringify(micros),
        );
      },
      { h, m },
    );
    await page.reload({ waitUntil: 'load', timeout: 120000 });
    await enableSemantics(page);
    await dismissSplash(page);
    await page.waitForTimeout(2500);
  }

  if (SCROLL) {
    await page.mouse.move(215, 500);
    await page.mouse.wheel(0, SCROLL);
    await page.waitForTimeout(1500);
  }

  if (flag('dump')) {
    console.log(JSON.stringify(await semantics(page), null, 1));
  }

  await page.screenshot({ path: outPng, fullPage: flag('full') });
  console.error('[drive] wrote', outPng);
  await ctx.close();
})().catch((e) => { console.error('FATAL', e); process.exit(1); });
