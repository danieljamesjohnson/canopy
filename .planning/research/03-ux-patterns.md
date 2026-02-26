# UX Patterns Research: Canopy Time Budgeting App

**Researched:** 2026-02-24
**Confidence:** MEDIUM — based on established UX research, published app teardowns, and Pomodoro/habit-tracker literature. WebSearch unavailable; no live source verification this session.

---

## 1. Onboarding Patterns for Goal-Setting Apps

### Core Problem

Goal-setting onboarding has two failure modes that pull in opposite directions:

- **Too much upfront setup** — user abandons before seeing value. Common in apps like Todoist where goal hierarchies require significant configuration.
- **Too little context** — app generates a garbage first schedule, user loses trust immediately and churns.

For Canopy, trust is established the moment the first generated schedule feels reasonable. Onboarding must collect just enough signal to make that happen.

### Recommended Pattern: Progressive Commitment in Three Steps

**Step 1 — Single anchoring question (screen 1 of 3)**

Ask one high-signal question: "What's the one thing you most want to make time for?" This seeds the first goal without requiring the user to understand the three-goal-type taxonomy yet. Free text or a small set of example tiles (e.g., "A creative project", "My health", "Learning something new", "Time with people I care about") works well.

Rationale: Apps like Fabulous and Streaks both open with a single motivating anchor before any configuration. It creates buy-in before burden.

**Step 2 — Commitment blocks (screen 2 of 3)**

"Do you have a regular job or fixed commitment?" — allows the user to define their work/school window (e.g., "Mon–Fri, 9am–5pm"). This is mandatory context for schedule generation; without it the algorithm cannot know how much discretionary time exists. A "No fixed commitment" option must be available.

**Step 3 — One habit to anchor the schedule (screen 3 of 3)**

"Is there anything you do every morning that we should protect?" — e.g., exercise, meditation, journaling. A short preset list with "None" as a valid first-class option. This establishes at least one concrete Chunk for day one.

**Result:** Three screens, under 90 seconds, enough data to generate a first schedule. The user earns the schedule before they understand the full system.

### Deferred Disclosure: Goal Type Taxonomy

Introduce the three goal types (time-target, outcome-focused, habit) only when the user taps "Add Goal" after onboarding. At that point, show a picker with plain-language descriptions:

- "I want to spend more time on this" → time-target
- "I'm working toward a specific result" → outcome-focused
- "I want to do this regularly" → habit/routine

Never use the category labels (time-target, outcome-focused, habit) in the UI. They are internal taxonomy, not user vocabulary.

### Minimum Viable Goal Setup to Generate First Schedule

| Signal | Minimum Required | Collected Where |
|--------|-----------------|-----------------|
| At least one goal | 1 goal | Step 1 onboarding |
| Commitment block (or "none") | Required | Step 2 onboarding |
| At least one anchor habit | Optional but recommended | Step 3 onboarding |

With these three signals, the algorithm can fill remaining Chunks with the single seeded goal, which is better than an empty schedule.

---

## 2. Daily Schedule UX

### Displaying a List of 25-Minute Chunks

**Recommended: Vertical card list, not a timeline**

A timeline (like Google Calendar's day view) looks natural but creates layout problems when Chunks don't have fixed start times — which is the case here, since Canopy is about budget allocation, not clock-based scheduling. Users should feel free to do Chunk 3 before Chunk 2 if their morning goes differently than planned.

Use a vertical scrolling list of cards. Each card contains:

- Goal name (primary label, large text)
- Goal category color or icon (scannable at a glance)
- Duration label ("25 min" for work chunks, "5 min" for short breaks, "25 min" for long breaks)
- Completion state (uncompleted / completed / skipped)

Breaks appear as distinct, visually lighter cards between work chunk cards. Short breaks (5 min) can be more compact; long breaks (25 min) match the height of work chunk cards.

Order by priority but make reordering of work chunks easy. Do NOT show clock times unless a Chunk has an explicit time anchor (e.g., a commitment block).

**Card density:** Aim for 3-4 Chunks visible without scrolling on a standard phone screen (approximately 375px wide, safe area ~700px tall). Work chunk card height ~80-90dp; short break card height ~48dp.

**Visual hierarchy within a work chunk card:**

```
[ Color bar ] [ Goal name — large, bold          ] [ Status icon ]
              [ Category label — small, muted     ]
              [ "25 min"                           ]
```

The color bar on the left edge (4-6dp wide) is the fastest way to visually group by goal category when scanning quickly. Break cards use a neutral gray color bar.

### Chunk Completion Interaction

**Decision required — three viable options with different tradeoffs:**

| Interaction | Pros | Cons | Best for |
|-------------|------|------|----------|
| Tap card to toggle complete | Fastest (1 tap), familiar from todo apps | Accidental completes likely; no confirmation | High-velocity, desktop or tablet |
| Swipe right to complete | Physical gesture feels satisfying, low accident rate | Not obvious without discovery, accessibility concern | Mobile, gamified feel |
| Checkbox on card | Explicit, familiar, no accident risk | Extra tap target to find, feels like a todo list | Users who prefer explicit action |

**Recommendation: Swipe right to complete, with tap-to-open fallback**

The swipe gesture matches the physical gesture of "pushing something away as done." Apps like Todoist, Habitica, and Apple Reminders all support swipe gestures on list items, making it a learned interaction for mobile users. Tapping the card opens a detail/edit view, which prevents accidental completes.

Add a visual affordance on first use: a brief animation showing the swipe direction on the first Chunk of the first schedule.

**For non-mobile platforms (Windows, Web, macOS):** Show a checkbox on hover. The swipe gesture does not translate to pointer devices.

**Breaks:** Short breaks auto-advance (no user action needed). Long breaks can be dismissed early with a tap. Neither should require the user to "complete" them as a required action.

### Reordering and Skipping Chunks Mid-Day

**Reorder: Long-press drag**

Long-press to enter reorder mode on a card, then drag to new position. This is the Flutter `ReorderableListView` interaction. Keep the drag handle visually subtle (three horizontal lines on the right edge, only visible while in reorder mode) to avoid cluttering the normal view.

**Skip a Chunk: Swipe left**

Swipe left (opposite of complete) reveals a "Skip" action. Skipped Chunks move to a "Skipped today" collapsed section at the bottom of the list, not permanently deleted. This matters for end-of-day review — the user can see what they skipped, and patterns emerge over time.

**Add an unplanned Chunk mid-day:**

A floating action button (FAB) or bottom-sheet trigger labeled "Add Chunk" allows adding an ad-hoc session.

**Decision flag:** Should skipped Chunks count against the user in the quarterly review? Recommendation: yes, they count as "time not spent" on the goal. Make this visible so it doesn't feel like hidden tracking.

### Visual Progress Indicators

**Top of schedule screen: Day progress bar**

A horizontal progress bar showing:
- Work chunks completed / total work chunks for today
- Fraction label ("4 of 9")

Keep this above the fold. Progress breeds progress (the "endowed progress effect" — Nunes & Drèze 2006).

**Per-goal category breakdown (accessible from progress bar tap):**

Tapping the progress bar expands a breakdown sheet:
- Goal A: 2/3 Chunks done
- Goal B: 1/2 Chunks done
- Habit: 1/1 done

**Completed Chunks:** Do NOT remove them from view. Show them in a "Completed" section with a checked/desaturated state. Seeing the done pile is motivating.

---

## 3. Mood/Energy Check-In UX

### Design Goal: Under 30 Seconds, No Friction

The check-in shapes the day's schedule. If users skip it or find it aversive, the personalization premise breaks down. Make it feel like a greeting, not an assessment.

### Recommended Pattern: Emoji Scale with One Conditional Follow-Up

**Screen 1 — Energy level (5-point emoji scale)**

Five circular tap targets in a horizontal row:

```
😴    😑    🙂    😊    ⚡
Very   Low  Okay  Good  Great
tired
```

Label each with a single plain-English word below the emoji (not numbers — numbers feel clinical). Pre-select nothing; require a deliberate tap.

**Screen 2 (conditional, only shown for low/very-low energy) — One optional question**

"Want a lighter day?" — Yes / No toggle. Default: Yes. This is the only additional screen for low-energy days. It maps directly to the scheduling algorithm: reduce discretionary Chunk count, de-prioritize high-effort goals, use 3-chunk cadence for long breaks.

For medium/high energy, skip this screen and proceed straight to the schedule.

**Total interaction time:**
- Good/great day: 1 tap + continue = ~8 seconds
- Low energy day: 1 tap + 1 toggle + continue = ~15 seconds

### Anti-Patterns to Avoid

- **Multi-axis mood scales** (energy + mood + focus + stress): Every additional axis adds 10-15 seconds and increases the perception of being interrogated. For v1, energy alone is sufficient.
- **Open-text "How are you feeling today?"**: Requires keyboard, destroys the <30-second target.
- **Journaling prompts in the check-in**: Journaling is a separate feature. Don't conflate it with schedule calibration.
- **Gamification visible during check-in**: Showing streaks during check-in reframes it as performance measurement. Keep scores off this screen.

### Closing the Loop

After schedule generation, show a one-line acknowledgment referencing the check-in: "Lighter day — 6 Chunks across your top priorities." This makes the connection between check-in and schedule explicit and reinforces the habit.

---

## 4. Periodic Review UX

### The Homework Problem

Apps with periodic reviews report low engagement unless the review is data-led and takes under 5 minutes. Reviews that begin with open-ended prompts see high abandonment. Reviews that begin with data visualization see higher completion.

Rule: **show the user what happened before asking them to reflect on it.**

### Recommended Pattern: Data First, Prompts Second

**Section 1 — Time spent summary (no interaction required)**

1. **Donut chart: Time by goal category this quarter** — where time actually went
2. **Bar chart: Chunks completed per week** — consistency trends, high weeks vs low weeks
3. **Top 3 goals by time spent** — simple ranked list: "Side project: 42 hrs, Health: 31 hrs, Reading: 8 hrs"

All visualizations on a single scrollable screen. Do not paginate. The user should see the full picture before being asked any questions.

**Section 2 — Guided reflection (3-5 questions, one per screen)**

1. "Which of these goals felt most meaningful this quarter?" — tap one goal
2. "Was there a goal you wanted to spend more time on but didn't?" — tap goal or "Not really"
3. "How would you describe your energy this quarter overall?" — same 5-emoji scale as morning check-in (reuse the pattern for familiarity)
4. "Any goal you want to drop or pause?" — optional, tap-to-select
5. "Any new goal you want to add?" — optional, preset tiles or text field

**Section 3 — Next quarter setup**

Surface changes indicated in Section 2 for confirmation: "You said you want more time on [goal]. Move it up in priority?" Then regenerate default schedule weights.

Total time target: 3-5 minutes for a full review. A user who only looks at the data and skips reflection still gets value.

### Chart Library Recommendation for Flutter

- **`fl_chart`** (pub.dev) — recommended for v1. Most popular Flutter charting library, supports pie/donut and bar charts, actively maintained, no licensing concerns.
- `syncfusion_flutter_charts` — more comprehensive but has licensing cost (free for community use on personal apps, but adds dependency complexity).
- Custom `CustomPainter` — maximum control, zero dependencies, significant implementation effort. Not recommended for v1.

---

## 5. Notification and Habit Loop Design

### The Behavioral Loop: Cue → Routine → Reward

- **Cue**: Morning notification → opens app
- **Routine**: Check-in (30 sec) → review generated schedule
- **Reward**: A plan that reflects how you feel + visual progress as day progresses

Every notification design decision should reinforce this loop, not disrupt it.

### Morning Trigger

**Timing:** User-configurable, defaulting to 7:30am.

**Notification content:** Avoid generic messages. Use direct, functional language:
- "Good morning. How's your energy today?"
- "Your schedule is ready to build."
- Do NOT use guilt language ("You haven't checked in yet", "Don't break your streak")

**On notification tap:** Deep-link directly to the mood check-in screen, not the app home screen. Every extra tap is a potential abandonment point.

**Flutter implementation:** `flutter_local_notifications` for scheduled local notifications. Works across Android, iOS, Windows, and macOS. On iOS, request `UNUserNotificationCenter` permission after the first successful check-in (not at first launch) — wait until the user has seen value before asking for permission.

### Mid-Day Nudges

**Make mid-day nudges opt-in, not opt-out.** Mid-day reminders correlate with both engagement upticks and increased uninstall rates. Given Canopy is a personal tool, the developer knows their own preferences — but design the feature as opt-in so it's safe to share.

When opt-in, two patterns:

1. **Time-based nudge**: "It's 2pm — you have 4 Chunks left today." Factual, no judgment.
2. **Inactivity nudge**: Triggered when the user hasn't completed a Chunk in N hours (configurable, default 2 hours). "Haven't done a Chunk in a while — want to pick one?"

Both nudges deep-link directly to the schedule screen.

**Avoid:** Progress comparisons to other days, urgency language, notifications during likely focus hours (consider avoiding 10am-12pm and 2pm-4pm by default).

### End-of-Day Summary

**Timing:** 9pm default, user-configurable. Only trigger if the user has at least one completed Chunk that day (no summary for zero-activity days — it adds guilt with no signal).

**Content pattern:**

```
Today: 6 of 9 Chunks
Side project ████░░  4 Chunks
Health       ██░░░░  1 Chunk
Habit        ██████  1 Chunk

3 Chunks skipped.
```

Simple, text-based, no interaction required. Optionally tappable to open app for quick post-day reflection (optional, never required).

**Web platform caveat:** The browser notification API does not support reliable background delivery. For Web, use a persistent in-app banner ("Have you checked in today?") as the fallback trigger instead of a system notification.

---

## 6. Cross-Cutting Design Principles

### Calm Technology

Apply the Calm Technology principles (Weiser & Brown) throughout:

1. **Inform without demanding attention** — notifications are dismissible with no penalty, progress indicators are ambient, reviews are pull-not-push.
2. **No streaks on the main screen** — streak counters are motivating for some users and anxiety-inducing for others. If tracked, put them in a stats area, not on the schedule screen.
3. **Skipping a day is not a failure state** — regenerate a fresh schedule each morning with no reference to yesterday's incompleteness unless the user requests it.
4. **Neutral language throughout** — avoid "you're crushing it" and "you failed" alike. Prefer factual: "6 Chunks completed, 3 skipped."

### Platform-Adaptive Interaction

| Pattern | Mobile | Desktop/Web |
|---------|--------|-------------|
| Chunk completion | Swipe right | Checkbox on hover |
| Reorder | Long-press drag | Drag handle always visible |
| Check-in | Full-screen flow | Modal or centered card |
| Notifications | OS push via `flutter_local_notifications` | System tray (Windows/macOS) or in-app banner (Web) |

---

## 7. Decisions That Still Need Resolution

**Decision 1: Chunk completion gesture**
Swipe-right-to-complete (recommended) vs tap-checkbox. Swipe is more satisfying on mobile but requires discovery. Checkbox is immediately obvious. Given this is a personal tool, swipe is acceptable. If ever shared with others, default to checkbox.

**Decision 2: Skipped Chunks in quarterly data**
Count skipped Chunks as "not done" in the quarterly review, or exclude them? Recommendation: count them (real signal about goal commitment), but make this explicit in the UI.

**Decision 3: Morning check-in blocking vs optional**
Should the schedule screen be accessible without completing the check-in? Recommendation: not blocking. Show a persistent banner "Check in to personalize today's schedule" if skipped, but don't gate access.

**Decision 4: Progress visualization style**
Horizontal progress bar (linear, familiar) vs circular ring (more visually distinct, used by Apple Watch/Streaks). Recommend linear bar for v1; ring is a cosmetic upgrade.

**Decision 5: Onboarding skip option**
Should onboarding be skippable entirely? For a personal tool: yes, with sensible defaults. For any future shared version: no, the first schedule quality depends on it.

**Decision 6: Break interaction**
Short breaks (5 min) auto-advance; long breaks (25 min) dismissible early. Neither requires a "complete" action. This needs validation — auto-advancing may feel like the app is driving.

---

## Sources and Confidence Notes

All findings are based on Claude's training knowledge through August 2025 and established UX/behavioral research. WebSearch was unavailable during this research session.

**HIGH confidence:** Endowed progress effect, sub-30-second check-in design, behavioral loop framework, swipe gesture as established mobile interaction.

**MEDIUM confidence:** `fl_chart` as recommended charting library — verify current pub.dev status at implementation time. `flutter_local_notifications` cross-platform support — verify Windows/macOS support at implementation time.

**LOW confidence / needs validation:** Default notification times (7:30am, 9pm) — common defaults, should be calibrated to actual habits. Quarterly review question set — design recommendation only.
