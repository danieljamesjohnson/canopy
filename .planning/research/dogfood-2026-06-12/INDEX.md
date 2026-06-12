# Dogfood walkthrough — 2026-06-12 (Dan, web debug build)

First real end-to-end drive of Canopy. Source of [[SEED-002-ui-basics-rework-dogfood]].
Dan's verdict: *"The basics just aren't here yet… quite a bit of rework on just the basics
of the UI."*

## Files
- `transcript.txt` — full narration (plain text, grep-able).
- `annotated.md` — transcript with inline frame refs (links resolve against `frames/`).
- `frames/` — 70 frames, one per speech segment, at full 1920×1080 (the Canopy app is the
  center panel; the rest is Dan's Windows desktop — ignore it).
- `key-frames-cropped/` — the 5 most important frames, **cropped to just the app window**
  and legible. Start here.

## Key frames (cropped) → what they prove

| Frame | Screen | What it shows |
|-------|--------|---------------|
| `0027_02m17s.jpg` | Add-goal sheet | Sheet is too tall — Priority label at the bottom edge, the selector + Save button are **below the fold**. "This UI isn't gonna work." |
| `0049_03m58s.jpg` | Check-in | Low-contrast amber wash; tiny **"Want a lighter day?" toggle** whose on/off state is unreadable; shows regardless of mood. |
| `0058_04m51s.jpg` | Home / "Up next" | Home card; Dan wants this to be the landing page and to read like the schedule (now/next + clock times). |
| `0061_05m10s.jpg` | Schedule (Today) | Commitments ("Work") show **real times** (9:00, 9:25…); discretionary goals (Vibe coding, Cleaning) show **"5x/week" instead of a time**. Colored left borders = priority. |
| `0071_05m55s.jpg` | Schedule (hover) | The per-row **circle** complete affordance; "Mark complete" only appears on hover — "really unclear UI for a human." |

See SEED-002 for the full grouped findings (A–F) and the likely files to touch.
