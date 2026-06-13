# Phase 1: Foundation - Context

**Gathered:** 2026-02-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the project skeleton: persistence layer (database package selection, entity schemas, repository interfaces, migration runner), navigation routing (go_router with stub screens), and state management scaffolding (Provider/ChangeNotifier). No user-visible features. Every subsequent phase builds on this layer without revisiting these architectural decisions.

</domain>

<decisions>
## Implementation Decisions

### Database Package Selection
- The phase researcher must check pub.dev at the start of Phase 1 to verify Isar's current maintenance status (pub.dev score, recent commits, Dart ^3.10.3 compatibility)
- **Decision rule:** Use Isar if pub.dev confirms it is actively maintained; fall back to hive_ce if maintenance is uncertain or the score is low
- If both are equally viable, Claude's discretion — no strong user preference between them
- sqflite is eliminated regardless (no native Web support)

### Repository Interface Scope
- Define interfaces for **all 6 entities from day one**: Goal, CommitmentBlock, DailySchedule (with embedded ScheduledChunk list), CompletionLog, QuarterlySnapshot, AppSettings
- Implementations in Phase 1 are stubs only — no business logic, just the interface contracts
- This prevents rework when Phases 2–5 arrive and need these interfaces to already exist

### Migration Runner
- Use **simple version integer + sequential runner pattern**: store a schema version number, and on every app launch run any un-run migrations in ascending order
- Established in Phase 1 so it's available for every schema change that follows
- No need to have actual migrations to run in Phase 1 — just the runner infrastructure

### Claude's Discretion
- If Isar and hive_ce are equally well-maintained, choose whichever the researcher considers the better long-term fit for a Flutter app targeting all 6 platforms
- App shell appearance (placeholder colors, typography) — use a sensible default for now, no strong preference expressed
- Navigation structure (bottom nav vs drawer) — Claude decides based on mobile-first productivity app conventions

</decisions>

<specifics>
## Specific Ideas

- No specific requirements beyond what's in ROADMAP.md — open to standard approaches for the infrastructure layer

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-24*
