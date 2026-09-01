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
//
//   Interaction (Phase 33). These are ADDITIVE — an invocation using none of
//   them behaves exactly as before. They run AFTER the clock is set and BEFORE
//   --scroll/--dump/screenshot, and they execute in COMMAND-LINE ORDER, so a
//   tap/type sequence reads left to right:
//     --tap=<label>         click the semantic node with that exact label
//     --tapbig=<label>      ...but pick the LARGEST match, not the smallest
//     --tap=~<label>        ...contains match (list rows carry the whole row's text)
//     --tap=<label>*        ...prefix match (Flutter concatenates subtitle text
//                           into a control's label, so the title is the stable part)
//     --tap=<label>@<role>  ...restricted to that ARIA role (e.g. @button)
//     --type=<text>         type into whatever currently has focus
//     --key=<Key>           press a key (e.g. Enter, Tab, Escape)
//     --tapxy=<x>,<y>       tap raw coordinates (last resort — no semantic text)
//     --wheel=<x>,<y>,<dy>  scroll dy px with the pointer over (x,y)
//     --wait=<ms>           pause
//   Why order matters and why they are not collected per-flag: seeding a
//   fixture is a sequence ("open Goals, tap the goal, type a budget, save"),
//   and a per-flag bucket would silently reorder it.
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
// `biggest` picks the LARGEST matching node instead of the smallest. Needed
// where one label is carried by two real controls: on the Goals screen both the
// quick-add's 40x40 "+" and the 124x56 extended FAB are `button` + "Add goal",
// and smallest-wins silently hits the "+" (submitting an empty field, a no-op
// that looks like a successful tap).
// A trailing `*` on the label switches to prefix matching. Flutter concatenates
// a node's descendant text into its label, so a control whose visible title has
// a subtitle under it carries BOTH — the add-kind fork's doors are labelled
// "Something to make time for\nGets a type, a weekly budget and a priority.
// Canopy schedules it." Requiring callers to reproduce that verbatim makes
// scripts break on any copy edit; a prefix is the stable part.
async function clickLabel(page, label, { role = null, biggest = false } = {}) {
  const nodes = await semantics(page);
  const prefix = label.endsWith('*');
  // A leading `~` matches any node CONTAINING the text. Needed for list rows,
  // whose label is the whole row concatenated and begins with the drag handle's
  // "Drag to reorder" rather than with anything identifying.
  const contains = label.startsWith('~');
  const want = prefix ? label.slice(0, -1) : contains ? label.slice(1) : label;
  const match = (t) => contains ? t.includes(want) : prefix ? t.startsWith(want) : t === want;
  const hits = nodes
    .filter((n) => match(n.t) && (role === null || n.role === role))
    .sort((a, b) => a.w * a.h - b.w * b.h);
  if (!hits.length) return false;
  let pick = biggest ? hits[hits.length - 1] : hits[0];

  // A semantic node reports real coordinates even when it is scrolled out of
  // the viewport, so tapping it "succeeds" and does nothing. Measured on this
  // build (Phase 33): six Complete/Skip taps all reported a hit and only the
  // two above the fold actually resolved a chunk. Scroll it into view and
  // re-resolve before tapping — and if it still will not come into view, fail
  // rather than pretend.
  const vh = page.viewportSize().height;
  if (pick.y < 0 || pick.y > vh - 8) {
    await page.mouse.move(215, Math.round(vh / 2));
    await page.mouse.wheel(0, pick.y - Math.round(vh / 2));
    await page.waitForTimeout(1200);
    const again = (await semantics(page))
      .filter((n) => match(n.t) && (role === null || n.role === role))
      .sort((a, b) => a.w * a.h - b.w * b.h);
    if (!again.length) return false;
    pick = biggest ? again[again.length - 1] : again[0];
    if (pick.y < 0 || pick.y > vh - 8) return false;
  }

  await tapAt(page, pick.x, pick.y);
  await page.waitForTimeout(900);
  return true;
}

// A pointer sequence with a real dwell between down and up, NOT `mouse.click`.
// Measured on this build (Phase 33): `page.mouse.click()` on the Goals
// quick-add field leaves `document.activeElement` at BODY and Flutter never
// creates its editing element, so a following `keyboard.type` goes nowhere and
// the step silently does nothing. The same coordinates with a ~120ms hold focus
// the field's TEXTAREA every time — Flutter's tap recognizer wants the dwell.
// Note the editing element is a TEXTAREA, not an INPUT; query for both.
async function tapAt(page, x, y) {
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.waitForTimeout(120);
  await page.mouse.up();
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

  // Interaction sequence, in command-line order. Anything that is not one of
  // these four verbs is left alone, so existing flags are unaffected.
  for (const a of args) {
    const m = /^--(tapxy|tapbig|tap|type|key|wait|wheel)=(.*)$/.exec(a);
    if (!m) continue;
    const [, verb, raw] = m;
    if (verb === 'wheel') {
      // Scroll a specific region — a bottom sheet's submit button sits below
      // the fold, and a semantic node whose y is outside the viewport still
      // reports coordinates, so tapping it silently does nothing.
      const [wx, wy, dy] = raw.split(',').map(Number);
      await page.mouse.move(wx, wy);
      await page.mouse.wheel(0, dy);
      await page.waitForTimeout(1200);
      console.error(`[drive] wheel ${wx},${wy} dy=${dy}`);
    } else if (verb === 'tapxy') {
      // Last resort for a control that carries no semantic text at all — the
      // goal form's "Goal name" TextField is one. Prefer a label whenever there
      // is one; coordinates rot the moment the layout moves.
      const [cx, cy] = raw.split(',').map(Number);
      await tapAt(page, cx, cy);
      await page.waitForTimeout(900);
      console.error(`[drive] tapxy ${cx},${cy}`);
    } else if (verb === 'tap' || verb === 'tapbig') {
      const at = raw.lastIndexOf('@');
      const label = at > 0 ? raw.slice(0, at) : raw;
      const role = at > 0 ? raw.slice(at + 1) : null;
      const biggest = verb === 'tapbig';
      const ok = await clickLabel(page, label, { role, biggest });
      console.error(`[drive] ${verb} ${JSON.stringify(label)}${role ? '@' + role : ''} -> ${ok ? 'hit' : 'MISS'}`);
      // A miss is fatal: a seeding script that silently skips a step produces a
      // fixture nobody can reproduce, and the screenshots would then be judged
      // against a state that was never actually reached.
      if (!ok) { console.error('FATAL: no semantic node matched'); process.exit(2); }
    } else if (verb === 'type') {
      // Fail loudly rather than typing into the void — see tapAt's note. A
      // --type that lands nowhere is the failure mode that makes a seeded
      // fixture unreproducible, so assert focus before sending keys.
      const focused = await page.evaluate(
        () => document.activeElement && /^(INPUT|TEXTAREA)$/.test(document.activeElement.tagName),
      );
      if (!focused) {
        console.error('FATAL: --type with no focused editing element; tap the field first');
        process.exit(3);
      }
      await page.keyboard.type(raw, { delay: 25 });
      await page.waitForTimeout(400);
      console.error(`[drive] type ${JSON.stringify(raw)}`);
    } else if (verb === 'key') {
      await page.keyboard.press(raw);
      await page.waitForTimeout(700);
      console.error(`[drive] key ${raw}`);
    } else {
      await page.waitForTimeout(parseInt(raw, 10) || 0);
    }
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
