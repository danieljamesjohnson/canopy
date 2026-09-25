# Open questions for the owner

Items an agent cannot settle. Nothing here blocks Phase 36's remaining waves.

---

## Q-01 — The real Google client ID is committed in `36-RESEARCH.md`. Rotate, scrub, or accept?

**Found 2026-09-25** by the orchestrator while spot-checking `36-04`'s CALAUTH-04 gates.
**Not** caused by `36-04` — it predates Phase 36 execution.

### What is true

- The live client ID from `.google-client-id` appears verbatim in **five places** in
  `.planning/phases/36-connect-google-calendar-without-hunting-for-a-url/36-RESEARCH.md`
  (around lines 30, 32, 648, 666, 832 — line 832 labels it `[VERIFIED: cat .google-client-id]`).
- It landed in commits `02e96f8` and `2742ec3` (the research pass, 2026-09-22/23).
- Those commits are **already pushed to `origin`**, and this repo is **public as a work sample**.
  The value is already out. Removing it now does not un-publish it.

### What this is NOT

**Not a CALAUTH-04 violation.** CALAUTH-04 says no client *secret* exists in the repository. For a
native iOS client Google issues no secret at all — that is the entire basis of D-36-01. No secret
exists, so none leaked. `36-04` verified this independently and its gates pass.

**Not a token-theft vector.** Without the PKCE code verifier an authorization code cannot be
exchanged. A public client ID is public by design in PKCE.

### What this IS

A contradiction of the project's own deliberate posture. CONTEXT decision 1 chose build-time
injection from a gitignored, mode-600 file *specifically* so the ID would not sit in the repo.
Committing it into research prose undoes that choice.

The residual real risk is **client impersonation**: a malicious app registering the same
`com.googleusercontent.apps.<id>` URI scheme can present a consent screen that looks like Canopy's.
This is a known, bounded risk class for native OAuth clients — not catastrophic, not nothing.

### The options

| | Action | Cost | What it actually changes |
|---|---|---|---|
| 1 | **Rotate** — delete the iOS OAuth client in Cloud Console, create a new one, overwrite `.google-client-id` | minutes | The only option that invalidates the exposed value. `36-04`'s wrapper reads the file, so no code changes |
| 2 | **Scrub the doc** — redact the five occurrences | minutes | Makes the posture consistent going forward. Cosmetic on its own: git history and `origin` still hold it |
| 3 | **Accept** — record in `36-DECISIONS.md` that a PKCE public client ID is not a secret | one paragraph | Nothing, but stops every future agent re-raising it |

**Recommendation: 1 + 2.** Rotation is the only step that changes the real exposure and it is cheap;
the scrub keeps the research trail honest about what it should not contain. Not urgent — do it before
any App Store distribution. Option 3 alone is defensible if you would rather not touch Cloud Console.

**Deliberately not pushed to your phone.** The exposure is three days old and already public, and
the right answer needs a considered call rather than a five-minute reaction.

---

## Q-02 — Every migration comment in `migrations.dart` rests on a premise that is now disproven

**Found 2026-09-25** during `36-01`, by a pre-existing test, then traced by the orchestrator through
the generated adapter and the migration history.

### The premise, and why it is false

`lib/data/database/migrations.dart` states, in the comments on `_migration2to3`, `_migration3to4`
and `_migration4to5`:

> All additive nullable/defaulted fields — Hive CE binary reader returns null/false/0 for missing
> fields in existing records. No data transformation needed.

**It does not return `false` or `0`.** For a *non-nullable* `bool` or `int` with no `defaultValue:`,
`hive_ce_generator` emits an unguarded cast — `fields[7] as bool`, `(fields[8] as num).toInt()` —
which throws `type 'Null' is not a subtype of type 'bool'` when the field is genuinely absent.
Nullable fields (`String?`, `int?`) are fine; non-nullable ones are not. `36-01` reproduced the crash
for real on a new field, and `defaultValue: false` fixed it.

**No migration in the file backfills anything.** Every one is a comment-only no-op resting on this.

### What is actually exposed, scoped honestly

Seven fields compile to unguarded casts: 0, 1, 2, 3 (`morningNotificationMinutes`,
`onboardingComplete`, `midDayNudgeEnabled`, `midDayNudgeMinutes`), 4
(`morningNotificationEnabled`), and 7, 8 (`eveningReminderEnabled`, `eveningReminderMinutes`).

But the *cast shape* being unsafe is not the same as being reachable:

- **Fields 0–3 shipped in the very first commit** (`17f0713`, `feat(01-02)`). Every record ever
  written contains them. **Unreachable.**
- **Field 4** arrived in phase 4 — exposed only to a record last written before phase 4.
- **Fields 7 and 8** arrived in phase 10 (`29f1040`) — exposed to any record last written before
  phase 10. **This is the realistic window, and it is exactly what `WINDOWS.md` entry 3 already
  names.** Entry 3 was correctly scoped.

Practical exposure is further limited because Hive rewrites a record in full on every `put`: once the
app has saved settings even once since phase 10, all fields are present. For a daily-use install the
risk is near nil. It is real for a fresh install of an old build, or a record never written since.

### Why it is still worth fixing

Not for the crash — for the comments. The next agent to add a non-nullable field to any Hive model
will read `migrations.dart`, believe "the reader returns false for missing fields", omit
`defaultValue:`, and reintroduce the same defect. `36-01`'s plan did exactly that, on exactly this
reasoning, and only a pre-existing test caught it. **The stale comment is the defect that keeps
reproducing.**

Also: no old-record test exercises fields 4/7/8, so the suite stays green regardless — the
"assertion that cannot fail" shape `CLAUDE.md` warns about.

**Not fixed** — out of Phase 36's scope, and it touches onboarding state. Worth a small dedicated
plan: add `defaultValue:` to fields 0–4, 7, 8; correct the false claim in all three migration
comments; and add one genuine pre-phase-10 old-record round-trip test that would have caught it.
