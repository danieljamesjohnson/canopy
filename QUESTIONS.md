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

## Q-02 — `WINDOWS.md` entry 3 is now CONFIRMED, not suspected: four bool fields can crash on upgrade

**Found 2026-09-25** during `36-01`, by a pre-existing test, and verified by the orchestrator in the
generated adapter.

`AppSettings` has four non-nullable `bool` fields with no `defaultValue:` —
`onboardingComplete` (field 1), `midDayNudgeEnabled` (2), `morningNotificationEnabled` (4),
`eveningReminderEnabled` (7). `hive_ce_generator` compiles each to a bare `fields[N] as bool` with no
fallback, which throws `type 'Null' is not a subtype of type 'bool'` when the field is absent from an
older record's byte stream.

This is the same crash class Phase 35 already fixed once. It stopped being theoretical during
`36-01`: adding a fifth such field reproduced the crash for real, and `defaultValue: false` fixed it
(recorded as a deviation in `36-01-SUMMARY.md`, since the plan had explicitly instructed otherwise on
the strength of a claim that turned out to be false).

**No existing old-record test exercises those four fields**, so the suite will keep passing green
regardless. That is precisely the "assertion that cannot fail" shape `CLAUDE.md` warns about.

**Not fixed** — out of Phase 36's scope, and it touches onboarding state, which deserves its own
plan rather than a drive-by edit. Worth a small dedicated phase: add `defaultValue:` to all four,
plus one genuine old-record round-trip test that would have caught it.
