/// Shared validation for a commitment's time window.
///
/// A scheduled chunk is 25 minutes, so a window shorter than that (including an
/// inverted overnight window like 10pm–6am, where end < start) materializes
/// zero chunks and would silently never appear on the schedule. Any surface
/// that creates a [CommitmentBlock] — the dedicated form AND onboarding — must
/// reject such a window rather than persist a commitment that quietly vanishes.
const int kMinCommitmentWindowMinutes = 25;

/// True when [startMinutes]→[endMinutes] is too short to hold a single chunk
/// (or is inverted). Both are minutes-from-midnight.
bool commitmentWindowTooShort(int startMinutes, int endMinutes) =>
    endMinutes - startMinutes < kMinCommitmentWindowMinutes;
