# Canopy — Research Summary

**Synthesized:** 2026-02-24
**Inputs:** 01-time-management-domain.md, 02-flutter-technical-patterns.md, 03-ux-patterns.md, 04-competitive-landscape.md
**Consumed by:** Roadmap creation

---

## Executive Summary

Canopy occupies a genuinely unoccupied position: a rule-based, mood-adaptive, offline-first daily scheduler that closes the full loop from quarterly goal-setting through daily chunk execution to retrospective review. No existing app does all of this. AI schedulers (Motion, Reclaim) are expensive, opaque, and cloud-dependent. Visual planners (Structured, Tiimo) stop at day-level without goal hierarchy or energy modeling. The market gap is real and well-defined.

The core architecture is validated by domain research: 25-minute chunks are cognitively grounded, the three goal types map cleanly to distinct scheduling algorithms, and the mood-adaptive capacity model (5–14 discretionary chunks based on mood 1–5) is internally consistent. The scheduling algorithm is deterministic and rule-based — this is a deliberate choice that makes it auditable and trustworthy, which is the correct call for v1. The loop that needs to work first is: morning mood tap → schedule generation → chunk completion tracking. Everything else is enhancement.

The primary technical risks are the database choice (Isar's maintenance status is uncertain) and the state management transition (PROJECT.md specifies setState-only, but research is clear that this becomes a liability after the second screen). Both must be resolved before Phase 2 begins. The UX risk is setup tax: onboarding must yield a usable first schedule in under 90 seconds or Week 1 retention collapses. These are solvable problems with known patterns.

---

## Key Findings by Research Area

### 1. Technical Decisions (from 02-flutter-technical-patterns.md)

**Database: Decide before writing any persistence code.**

- **Isar** is the preferred choice — native query engine, type-safe queries, ACID transactions, cross-platform including Web. However, the original author announced a 4.0 Rust rewrite mid-2025 that was unreleased at research time. Maintenance status must be verified on pub.dev before adopting.
- **hive_ce** is the safe fallback — all-platform support (including Web via IndexedDB), API-compatible with Hive 2.x, weaker query story but acceptable for one-user data volume.
- **sqflite** is eliminated — no native Web support requires a dual persistence strategy. Not worth the complexity.
- **Decision rule:** Check Isar on pub.dev at project start. If pub score is high and commits are recent, use Isar. Otherwise, use hive_ce.

**State management: Plan to introduce Provider at Phase 2, not later.**

- setState is correct for Phase 1 (single screen, isolated state).
- The daily schedule and completion state will need to be accessible from multiple screens simultaneously. This is the trigger for Provider.
- Riverpod and Bloc are not appropriate — unnecessary complexity for a personal app.
- Three ChangeNotifiers cover the domain: GoalsNotifier (goals + commitments), ScheduleNotifier (today's schedule + chunk mutations), SettingsNotifier (preferences).

**Navigation: go_router from the start.**

- Canopy targets Web. MaterialApp named routes break Web URL navigation. go_router handles all six platforms, supports StatefulShellRoute for per-tab navigation stacks, and is Flutter-team maintained.
- Start with go_router stubs in Phase 1, even before multiple screens exist.

**Notifications: Notification-triggered generation, not background execution.**

- True background execution is unreliable across all six platforms (impossible on Web, restricted on iOS).
- v1 pattern: Schedule a daily local notification at the user's configured morning time. On tap, app opens and runs schedule generation synchronously on launch. Reliable everywhere.
- Use `flutter_local_notifications` + `timezone` package. Request iOS notification permission after the first successful check-in, not at launch.
- Web has no local notification support — use a persistent in-app banner as fallback.

**Schema highlights:**

- Embed ScheduledChunk list inside DailySchedule (one read = full day, no joins).
- Store break chunks (shortBreak, longBreak) with null goalId — enables full timeline reconstruction.
- CompletionLog is append-only (event sourcing lite) — never mutate historical logs.
- All times as UTC + "minutes from midnight" integers (eliminates DST complexity).
- Goals are soft-deleted (archived), never hard-deleted.

**Resolved:** No charting library until Phase 5. fl_chart is the Phase 5 recommendation.

---

### 2. Core Algorithm Decisions (from 01-time-management-domain.md)

**These are decided and consistent with PROJECT.md. No contradictions.**

**Capacity model (discretionary chunks by mood):**
```
Mood 1 (rough) →  5–6 chunks   | Long break every 3 chunks
Mood 2 (low)   →  7–8 chunks   | Long break every 3 chunks
Mood 3 (okay)  →  9–10 chunks  | Long break every 4 chunks
Mood 4 (good)  → 11–12 chunks  | Long break every 4 chunks
Mood 5 (great) → 13–14 chunks  | Long break every 4 chunks
Hard cap: 16 | Minimum: 3 | Buffer: schedule only 80% of discretionary capacity
```

**Allocation sequence (fixed, in order):**
1. Commitment blocks (always, mood-independent)
2. Habits (streak logic — due/overdue triggers scheduling)
3. Outcome goals (urgency = priority_weight × chunks_remaining / days_remaining)
4. Time-target goals (most behind weekly budget scheduled first)
5. Leave 20% of discretionary capacity unscheduled

**Mood 1–2 "just survive today" mode:** Commitment blocks fully scheduled. Discretionary reduced to habits only — no projects, no time-target goals unless critical. The app does not need to name this mode explicitly; just quietly produce a kinder schedule.

**Chunk is the primary currency.** Never show raw minutes in scheduling UI. "6-chunk day" is the user's vocabulary.

**Schedule generation must complete in under 1 second.** Pure Dart computation, no async, no API calls. This is entirely achievable for one user's data.

**Explainability requirement:** Every scheduled chunk has a one-line rationale. Rule-based is chosen precisely because it is auditable. If the user can't predict what the algorithm will do, they stop trusting it.

---

### 3. UX Decisions (from 03-ux-patterns.md)

**Onboarding: Three screens, under 90 seconds, first schedule generated immediately.**

- Screen 1: "What's the one thing you most want to make time for?" (seeds first goal)
- Screen 2: "Do you have a regular job or fixed commitment?" (defines commitment block or "none")
- Screen 3: "Is there anything you do every morning we should protect?" (seeds first habit — optional)
- Goal type taxonomy (time-target / outcome / habit) is NOT introduced during onboarding. Deferred to the "Add Goal" flow post-onboarding.
- Internal category labels never appear in the UI. Plain-language pickers only.
- Onboarding is skippable (personal tool). Skipping → sensible defaults → first schedule generated anyway.

**Daily schedule: Vertical card list, not a timeline.**

- No clock times shown unless a chunk has an explicit time anchor (commitment block).
- Cards: goal name (large/bold), left-edge color bar (4-6dp, goal color), duration label, status icon.
- Break cards: visually lighter. Short break cards are compact (~48dp). Long break cards match work card height.
- 3–4 chunks visible without scrolling on a standard phone.
- Completed chunks stay visible in a desaturated "done" state — do not remove them from view.
- Skipped chunks move to a collapsed "Skipped today" section at the bottom.

**Chunk completion interaction:**
- Mobile: Swipe right to complete. Swipe left to skip. Tap opens detail/edit sheet.
- Desktop/Web: Checkbox on hover. Drag handle always visible for reorder.
- Short breaks (5 min): auto-advance, no user action.
- Long breaks (25 min): dismissible early with a tap. No "complete" required for either break type.
- Reorder: Long-press drag (ReorderableListView).

**Mood check-in: Under 30 seconds. Feels like a greeting, not an assessment.**
- Five emoji tap targets (no numbers — numbers feel clinical). No pre-selection.
- Low/very-low only: one follow-up toggle "Want a lighter day?" (default: Yes).
- Good/great: skip straight to schedule. 8 seconds total.
- After generation: one-line acknowledgment closes the loop ("Lighter day — 6 Chunks across your top priorities").
- Streaks/scores not visible during check-in. No gamification on this screen.

**Progress indicators:**
- Top of schedule: horizontal progress bar ("4 of 9 Chunks"). Always above the fold.
- Tapping the bar expands per-goal breakdown sheet.
- Do not show composite "productivity score" or peer comparisons. Ever.

**Quarterly review: Data first, prompts second.**
- Section 1: Donut chart (time by goal), bar chart (chunks per week), top 3 goals by time — no interaction.
- Section 2: 3–5 guided questions, one per screen, tap-to-answer.
- Section 3: Confirm next-quarter priority changes derived from Section 2.
- Target: 3–5 minutes for full review. Data-only pass still provides value.
- Feels celebratory, not evaluative. Tone matters for 90-day retention.

**Six failure modes to design against (from domain research):**
1. Setup Tax — mitigated by 3-screen onboarding with immediate first schedule
2. Broken Promise — mitigated by frictionless skip/defer + non-judgmental tone
3. Guilt Machine — mitigated by calm language, completed items stay visible
4. Too Rigid — mitigated by goal pause, weekly budget resets clean (no rollover debt)
5. Too Clever — mitigated by explainable rules, manual override always available
6. Notification Fatigue — mitigated by one daily notification, optional mid-day nudges

---

### 4. Market Positioning (from 04-competitive-landscape.md)

**Canopy's unique position:** The only app that integrates goal-type-aware scheduling + mood-adaptive capacity + commitment blocks + quarterly review + local-first + no subscription. The differentiator is the full loop, not any single feature.

**Borrow from competitors:**
- Structured: Visual calm aesthetic, uncluttered day view
- Sunsama: Morning planning ritual as a deliberate product gesture
- Tiimo: End-of-chunk transition notification concept
- Toggl Track: Actual vs. intended allocation in retrospective
- Streaks: One-time purchase model validates no-subscription positioning
- Local-first movement: Easy data export from day one (JSON/CSV) as a trust signal

**Deliberately avoid:**
- Calendar sync (OAuth complexity, cloud dependency — v2 only)
- AI scheduling (rule-based is the value prop)
- Social/accountability features (moderation surface)
- Cloud storage or backend dashboard
- Unlimited custom goal types (the three-type constraint is the opinion)
- Server-side push notifications

**Positioning statement:** Canopy is the personal daily planner for people who have tried AI schedulers and found them opaque, expensive, and cloud-dependent — built offline-first, rule-based, and free.

---

## Validated Requirements (Cross-referenced with PROJECT.md)

The following PROJECT.md active requirements are fully supported by research and have no contradictions:

| Requirement | Research Support | Notes |
|---|---|---|
| Fixed commitment blocks, always scheduled regardless of mood | HIGH — domain + competitive research | Allocation sequence positions them first |
| Three goal types with distinct scheduling logic | HIGH — domain + competitive research | Algorithms specified per type |
| Daily chunk schedule (25-min sessions) | HIGH — all four files | Chunk as primary currency confirmed |
| Break structure: 5-min short / 25-min long, mood-adaptive cadence | HIGH — domain research | Cadence table fully specified |
| Morning mood check-in controls discretionary chunk count only | HIGH — domain + UX research | Commitment blocks mood-independent |
| Mood 1–2 triggers reduced "just survive today" schedule | HIGH — domain research | Habits-only discretionary in this mode |
| Chunk completion tracking | HIGH — UX research | Swipe gestures + CompletionLog schema |
| Quarterly review with data summary + guided reflection | HIGH — UX + competitive research | Data-first pattern specified |
| Rule-based scheduling (no AI API in v1) | HIGH — competitive + technical research | Auditability is the value prop |
| Local storage only in v1 | HIGH — all files | Schema + package selection support this |

**No contradictions found between research files and PROJECT.md active requirements.**

---

## Open Questions Requiring Resolution

Consolidated from all four research files. These must be resolved before or during the roadmap phase they affect.

### Before Phase 1 (Foundation)

**OQ-1: Isar vs hive_ce** [BLOCKER]
Check Isar on pub.dev at project start. If maintained and compatible with Dart ^3.10.3, use Isar. Otherwise hive_ce. Cannot defer — affects all schema code.

**OQ-2: Export format** [Phase 1]
JSON, CSV, or both? Export must be designed early; migrating format after users have data is painful. Recommendation: JSON-first for completeness, CSV for spreadsheet users. Decide before writing CompletionLog.

### Before Phase 2 (Goals & Commitments)

**OQ-3: Goal type mutual exclusivity**
Can a goal be both a habit and a time-target (e.g., exercise)? If yes, what are the allocation rules? If no, the UI must prevent it. Recommendation: enforce mutual exclusivity; the goal-type picker is a single-select.

**OQ-4: Dormant goal handling**
Goals with no activity for 3+ weeks — silently deprioritize in scheduling, or surface in weekly review? Recommendation: silently deprioritize in scheduling, surface with a gentle prompt at weekly review.

### Before Phase 3 (Daily Schedule)

**OQ-5: Ordered vs. unordered daily chunk list**
Should chunks be shown in a fixed priority order (Eat the Frog — hardest first) or in a flexible order the user can rearrange freely? Ordered is more rigid but clearer. Recommendation: default to priority order, with full reorder capability always available.

**OQ-6: Short break auto-advance mechanism**
Auto-advancing short breaks requires either a timer or detecting inactivity. A timer means the app must stay open/active. Recommendation for v1: short breaks auto-advance only if the user taps "Done" on the preceding work chunk; otherwise they remain as manual tap-to-dismiss. Eliminates timer dependency.

**OQ-7: "Just survive today" mode — named or silent?**
The reduced Mood 1–2 schedule — should the app explicitly label it (e.g., "Rest mode") or just quietly produce a lighter schedule? Recommendation: silent reduction for v1. The acknowledgment text after check-in ("Lighter day — X Chunks") communicates it without labeling.

**OQ-8: Recovery/wellness chunk sizing**
A 10-minute walk doesn't fit cleanly in a 25-minute chunk. Options: (a) treat it as a half-chunk with a 15-min remainder, (b) schedule it as a full 25-min chunk with the extra time as optional extension, (c) define a special "mini habit" type. Recommendation: Schedule as a full 25-min chunk for v1 with guidance that the remaining time is transition/bonus. Revisit in retrospective if users push back.

### Before Phase 4 (Chunk Tracking)

**OQ-9: Skipped chunks in quarterly review**
Count skipped chunks as "time not spent" on the goal (real signal) or exclude them? Recommendation: count as not done, surface in review explicitly. Make the tracking transparent.

**OQ-10: Mid-day nudge opt-in defaults**
Mid-day notifications correlate with both engagement and uninstall rates. Default to opt-in or opt-out? Recommendation: opt-in. Safer for a personal tool.

**OQ-11: Optimal notification time defaults**
Morning default: 7:30am. End-of-day: 9:00pm. These are reasonable defaults; validate against own schedule before shipping.

### Longer-term / v2

**OQ-12: Streak anxiety and rest days**
Long streaks for habit goals may produce anxiety. Consider a "planned rest day" that does not break the streak. Not blocking for v1.

**OQ-13: Quarterly review cadence configurability**
90 days may be too long for some goals. Consider making the review cadence configurable (monthly, quarterly). Not blocking for v1.

**OQ-14: Calendar sync design**
v2 scope. Design schema with eventual sync in mind — CommitmentBlock and DailySchedule structures are already compatible with calendar event import.

---

## Roadmap Implications

Research strongly suggests a six-phase structure. The ordering is driven by two constraints: (1) the user cannot see a schedule until goals and commitments exist, and (2) the algorithm cannot be validated until chunk tracking exists.

### Suggested Phase Structure

**Phase 1 — Foundation**
Database setup (Isar or hive_ce), repository interfaces, shared_preferences for settings, go_router stubs, UUID/intl, MultiProvider scaffold with empty notifiers. No visible features. Establishes the skeleton every subsequent phase builds on.
- Pitfall to avoid: Committing to sqflite or deferring the DB decision.
- Research flag: Needs live pub.dev verification for Isar before starting.

**Phase 2 — Goals and Commitments**
Goal CRUD (three types), CommitmentBlock CRUD, GoalsNotifier + CommitmentsNotifier. Migration framework established. Provider plumbed end-to-end.
- Delivers: User can define their goals and work schedule.
- Pitfall to avoid: Exposing goal type taxonomy vocabulary (time-target/outcome/habit) directly in UI.

**Phase 3 — Daily Schedule Generation**
Schedule generation algorithm (pure Dart), DailySchedule + ScheduledChunk entities with embedded break chunks, ScheduleNotifier, schedule display UI (vertical card list with mood check-in). The core product loop becomes usable for the first time.
- Delivers: The minimum viable product — morning mood → schedule.
- Pitfall to avoid: Timeline-style schedule UI (breaks the budget-not-blocking mental model). Clock times on non-commitment chunks.
- Research flag: Algorithm needs empirical calibration. Start using it daily immediately.

**Phase 4 — Chunk Tracking and Notifications**
Chunk completion (swipe gestures + platform-adaptive interactions), CompletionLog (append-only), end-of-day summary, morning notification via flutter_local_notifications + timezone. iOS permission strategy (request after first successful check-in).
- Delivers: Closing the daily loop. The app becomes a habit.
- Pitfall to avoid: Blocking the schedule screen behind check-in completion. Notification fatigue (one daily notification; mid-day as opt-in).

**Phase 5 — Quarterly Review and Retrospective**
CompletionLog aggregation, QuarterlySnapshot, data visualization (fl_chart), guided reflection flow, next-quarter priority adjustment. Export to JSON/CSV.
- Delivers: The long-horizon value prop. Differentiates Canopy from all day-level planners.
- Research flag: Quarterly review UX needs wireframing before implementation. Data-first pattern is clear, but question set needs iteration.

**Phase 6 — Cross-Platform Polish**
LayoutBuilder adaptive layouts for desktop/Web, hover states and visible drag handles on desktop, window_manager minimum size, go_router Web URL verification, Web notification fallback (in-app banner). Mouse/touch interaction parity.
- Delivers: Canopy is genuinely good on Windows and Web, not just functional.
- Pitfall to avoid: Treating desktop as an afterthought until too late to fix layout assumptions.

### Phases That Need Deeper Research Before Implementation

| Phase | Research Needed | Why |
|---|---|---|
| Phase 1 | Isar pub.dev status check | Determines entire persistence layer |
| Phase 3 | Algorithm calibration research | Chunk count thresholds per mood need empirical validation |
| Phase 5 | Quarterly review wireframes | Question set and chart types need design iteration |

### Phases With Well-Documented Patterns (Skip Research)

- Phase 2: Goal CRUD with Provider — standard Flutter patterns, no research needed
- Phase 4: flutter_local_notifications — package is well-documented, patterns are clear
- Phase 6: LayoutBuilder adaptive layouts — established patterns, no uncertainty

---

## Confidence Assessment

| Area | Confidence | Basis |
|---|---|---|
| Scheduling algorithm | HIGH | Domain research is internally consistent; all decisions align with PROJECT.md |
| Three goal types | HIGH | Competitive research confirms no competitor models this; domain research validates the algorithms |
| UX patterns (onboarding, check-in, schedule card) | MEDIUM-HIGH | Based on established UX research and published app patterns; not live-tested |
| Flutter package selection | MEDIUM | Isar status unverified; all other packages are established |
| Notification cross-platform behavior | MEDIUM | Platform analysis is accurate but package capabilities should be verified at implementation time |
| Competitive landscape | MEDIUM | Training data cutoff August 2025; pricing unverified |
| Algorithm thresholds (chunk counts per mood) | MEDIUM | Well-reasoned but empirical calibration needed post-launch |
| Quarterly review question set | LOW-MEDIUM | Design recommendation only; needs iteration against actual use |

**Overall research confidence: MEDIUM-HIGH**

The conceptual framework is solid. The execution details (package versions, algorithm thresholds, UX micro-interactions) will need refinement as the app is used. This is expected — the domain research itself recommends shipping the core loop and calibrating from real data.

---

## Key Constraints Carried Forward

These are non-negotiable constraints from PROJECT.md that roadmap phases must respect:

1. **No AI API calls in v1** — rule-based scheduling only
2. **Local storage only in v1** — no backend, no sync
3. **All six Flutter platforms supported** — database and notification choices must be cross-platform
4. **setState in Phase 1, Provider from Phase 2 onward** — state management transition is planned, not a violation of the constraint
5. **Personal tool first** — optimize for solo use; no social features, no multi-user data model

---

## Sources

- **01-time-management-domain.md** — Confidence: HIGH for core concepts, MEDIUM for algorithm specifics
- **02-flutter-technical-patterns.md** — Confidence: MEDIUM overall; all package versions require pub.dev verification at implementation time
- **03-ux-patterns.md** — Confidence: MEDIUM; based on established UX research and published app teardowns
- **04-competitive-landscape.md** — Confidence: MEDIUM; training data through August 2025; pricing unverified
- **PROJECT.md** — Source of truth for requirements; all research cross-referenced against active requirements

No contradictions were found between research files. All four files are consistent with PROJECT.md active requirements.
