# Time Management Domain Research

**Project:** Canopy — Personal Time Budgeting App
**Researched:** 2026-02-24
**Overall Confidence:** HIGH for core concepts, MEDIUM for algorithm specifics

---

## 1. Core Time Management Concepts

### 1.1 Pomodoro / Chunk-Based Scheduling

The 25-minute unit sits just below the average attention-span inflection point (~30 min) where cognitive fatigue accelerates. "Chunks" as the atomic unit means:
- Any task can be expressed as N chunks (eliminates hour-estimation anxiety)
- Multiple completion signals per day (vs. one per multi-hour task)
- Density is immediately legible: "6-chunk day" is instantly understood

**Break structure (built into every schedule):**
- 5-minute short break after every chunk (shown explicitly in the schedule)
- Long break (1 full chunk = 25 min) after every 3 or 4 consecutive work chunks, depending on mood:
  - Mood 1–2 (rough/low): long break every **3 chunks**
  - Mood 3–5 (okay to great): long break every **4 chunks**
- Breaks appear as named items in the schedule (e.g. "☕ Short break", "🧘 Long break")

**Capacity bounds:** Chunk count refers to *work chunks only* — breaks are additional and automatic. A sustainable productive day: Mood 1: 5–6 work chunks, Mood 5: 13–14 work chunks. Hard cap: 16 work chunks. Minimum: 3.

### 1.2 Time Budgeting vs Time Blocking vs Time Tracking

| Concept | Question | Granularity | Feedback |
|---------|----------|-------------|----------|
| Tracking | Where did time go? | Retrospective | Weekly/monthly |
| Blocking | When exactly will I do X? | Hour-by-hour slots | Daily |
| **Budgeting** | How much time for X this week? | Budget envelopes | Weekly |

Canopy uses budgeting (intent) → blocking (execution via morning schedule). Anti-pattern: pure tracking without intent produces guilt, not change.

### 1.3 Bridging Goal-Setting and Daily Scheduling

The hierarchy:
```
Quarterly Goal → Weekly Time Budget → Daily Chunk Allocation → Completion Tracking
```
Each layer must be visible and connected. Users need to see "this chunk today serves my Q1 goal."

Key patterns: GTD Weekly Review feeds the budget; OKR scoring feeds the quarterly review; Covey Quadrant II work (important, not urgent) gets scheduled first.

### 1.4 Quarterly Review Design

- Quarterly cadence matches natural planning rhythms — long enough for habits to form, short enough to course-correct
- Score previous objectives (0.0–1.0), retrospect, set new objectives
- **Retention insight:** Users who complete quarterly reviews have dramatically higher 90-day retention. Build the review UX to feel celebratory, not evaluative.

---

## 2. Scheduling Algorithm Patterns

### 2.1 Schedule Structure

Every generated schedule interleaves work chunks and breaks automatically:
- **Work chunk**: 25 min focused session tied to a goal or commitment block
- **Short break**: 5 min, shown explicitly after every work chunk
- **Long break**: 25 min, shown after every 3 chunks (mood 1–2) or 4 chunks (mood 3–5)

Example sequence (mood 3, 4-chunk cadence):
```
[Work] → [5m break] → [Work] → [5m break] → [Work] → [5m break] → [Work] → [25m long break] → repeat
```

### 2.2 Fixed Commitment Blocks (v1)

Users define recurring time blocks for real-world obligations (full-time job, school, appointments). These are:
- Set once during onboarding (e.g. "Mon–Fri, 9am–5pm = Work")
- Always scheduled, regardless of mood — they represent unavoidable reality
- Chunked into 25-min work units + 5-min breaks within the block (the app shows this automatically)
- Displayed in the schedule at their actual times, visually distinct from discretionary goal chunks
- **Not subject to mood-based capacity limits** — discretionary chunk count is calculated *after* commitments are placed

**v2 consideration:** Calendar sync (Google Calendar, etc.) to read commitment blocks automatically and chunk them up.

### 2.3 Discretionary Capacity Model (mood-based)

The mood score controls how many *additional* discretionary chunks fill time outside commitment blocks:

```
mood 1 (rough) → 5–6 discretionary chunks
mood 2 (low)   → 7–8 discretionary chunks
mood 3 (okay)  → 9–10 discretionary chunks
mood 4 (good)  → 11–12 discretionary chunks
mood 5 (great) → 13–14 discretionary chunks

Hard cap: 16 | Minimum: 3
Buffer rule: Schedule only 80% of available discretionary time
```

**Hybrid floor rule:** On mood 1–2 days, a "just survive today" mode is triggered — commitment blocks are still fully scheduled, but discretionary chunks are reduced to the bare minimum (habits only, no projects or time-target goals unless critical). The user sees a smaller, kinder schedule for the discretionary portion.

### 2.4 Four Goal Type Algorithms

**Time-Target Goals** (weekly hour budgets):
```
daily_allocation = budget_remaining / days_remaining_in_week
if ahead of budget → skip
if behind → schedule min(2, ceil(deficit))
```

**Outcome Goals** (deadline + priority):
```
urgency = priority_weight × (chunks_remaining / days_remaining)
priority_weight: critical=3.0, high=2.0, medium=1.0, low=0.5
```

**Habit Goals** (streak-based):
```
if days_since_last >= target_interval → schedule (high priority)
if days_since_last >= target_interval × 1.5 → schedule (critical, chain at risk)
```

### 2.5 Allocation Sequence

1. Fixed commitment blocks placed first (always, unaffected by mood)
2. Habits (require consistency over volume)
3. Outcome goals by urgency score
4. Time-target goals by budget deficit (most behind = first)
5. Leave 20% of discretionary capacity unscheduled (buffer)

### 2.6 Scheduling Heuristics

- **MoSCoW filter** before allocation: Must / Should / Could / Won't today
- **Eat the Frog ordering:** Hardest chunk first in daily sequence
- **Weighted round-robin** for equal-priority goals to prevent monopolization
- **Explainability requirement:** Every chunk should have a one-line rationale

---

## 3. Validation Signals

### 3.1 Six Failure Modes

1. **Setup Tax** — requiring full configuration before first schedule → abandon Week 1. Fix: ship default goals, generate first schedule with just mood input.
2. **Broken Promise** — schedule diverges from reality with no recovery path → abandon Week 2–4. Fix: frictionless skip/defer, non-judgmental tone.
3. **Guilt Machine** — prominent incomplete items, failure-focused dashboard → abandon Week 3–8. Fix: celebrate completions, let misses fade quietly.
4. **Too Rigid** — sick days / travel break cascading schedule → expert abandonment. Fix: goal pause, weekly budget reset (no rollover debt).
5. **Too Clever** — users can't predict or understand the schedule → distrust. Fix: explainable rules, manual override always available.
6. **Notification Fatigue** — too many nudges → silenced → habit breaks. Fix: one daily notification, morning check-in completable in <60 seconds.

### 3.2 Minimal Viable Scheduling Loop

```
Morning (2 min): mood tap → review schedule → optional 1-2 swaps → lock
During day: open chunk → mark complete
Evening (1 min, optional): see "5 of 7 done" summary
Weekly (5 min): budget vs actual → adjust next week
```

Everything else is enhancement. This loop, executed reliably, outperforms 90% of competitors.

### 3.3 Key Metrics

**Daily (users see):** Completion rate (target >70%), streak, habit streaks
**Weekly:** Budget utilization per goal, goal progress vs deadline
**What NOT to show:** Total hours tracked (surveillance feel), composite "productivity score" (gameable), peer comparison (productivity is personal)

---

## 4. Critical Implementation Decisions

1. Chunk count = primary currency. Never show minutes in scheduling UI.
2. Schedule generation must be <1 second. Local-only computation is fast enough.
3. The algorithm must be explainable. Rule-based is correct for v1 precisely because it is auditable.
4. Completion UX deserves as much attention as the algorithm.
5. Mood 1 days are load-bearing. A rough-day schedule that feels kind retains users.
6. Weekly budget resets clean. No rollover debt. Deficits inform the next week's review, not auto-reschedule.

---

## 5. Open Questions

1. Exact chunk count thresholds per mood level — validate empirically with completion rate data
2. Dormant goal handling (no activity 3+ weeks) — silently deprioritize or surface in review?
3. Long streaks producing anxiety — consider "rest day" that doesn't break streak
4. Goal type overlap (exercise as habit + time-target + outcome) — need mutual exclusivity rules
5. Ordered vs unordered daily chunk list — ordered is more rigid but clearer
6. Optimal notification time default — 7–8am generally recommended for productivity apps
7. How to handle commitment blocks with internal structure (e.g. a job that already has meetings, lunch, deep work time) — v1 treats the whole block as uniform chunks; v2 calendar sync would resolve this
8. Do short breaks (5 min) need to be marked complete, or do they auto-advance? Marking them feels like overhead; auto-advancing requires a timer
9. "Just survive today" mode (mood 1–2) — should the app explicitly name this mode, or just quietly reduce the schedule?
