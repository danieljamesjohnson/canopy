/// The ONE place a calendar sync is run from UI code.
///
/// Two screens start syncs: check-in (`checkin_screen.dart`'s `_generate`,
/// the most frequent sync there is) and the Calendars screen
/// (`calendar_settings_screen.dart`'s `_syncAndReport`). Before this file each
/// repeated "sync, then on success write the last-sync time". Adding "and pass
/// the configured calendar set, and record the skipped list" to both would be
/// exactly the duplicated-definition shape WR-02 was raised about in this
/// phase: two callers computing "what the user configured" two ways is how a
/// prune deletes the wrong thing. Check-in also builds its source internally
/// and has no injection seam, so the honest place to prove what check-in
/// records is a function it calls.
///
/// **The configured set is a union** (see [configuredCalendarIdsFor]) because
/// every source stamps each event's `calendarId` with exactly one of two
/// strings: the ticked id (device: the raw EventKit id; Google: the
/// `google:`-prefixed id) or the feed URL (ICS). On iOS the factory ignores
/// `icsUrls`, and on desktop/web it ignores `selectedCalendarIds`, so the
/// union is conservative: it can only KEEP more imported blocks, never delete
/// one that a source was actually built from.
///
/// **Recording happens on success only.** A failed sync leaves the last-known
/// last-sync time and skipped list in place (D-35-13, WINDOWS entry 10), so
/// the disclosure the user last saw is never replaced by an empty one just
/// because the network was down.
///
/// Wiring this closes WINDOWS entries 10 (skipped-events banner survives
/// re-open and relaunch) and 11 (the selection prune actually runs).
library;

import '../data/calendar/calendar_source.dart';
import '../services/calendar_sync_service.dart';
import 'commitments_notifier.dart';
import 'settings_notifier.dart';

/// Everything the user has configured, as the strings sources stamp on events
/// as `calendarId`: `selectedCalendarIds ∪ icsUrls`. The single definition of
/// "what the user has configured" — handed to the selection prune.
Set<String> configuredCalendarIdsFor(SettingsNotifier settings) => {
  ...settings.selectedCalendarIds,
  ...settings.icsUrls,
};

/// Syncs [source] into [commitments] with the user's configured calendars
/// ([configuredCalendarIdsFor]) so stale imported blocks are pruned, and on
/// SUCCESS records the sync time and skipped list on [settings] in one save.
///
/// Never throws: any unexpected error (e.g. a repository fault while
/// reloading blocks, or while saving the disclosure) degrades to a
/// `failed: true` result, so check-in can always go on to generate a day from
/// last-known blocks (D-35-13).
Future<CalendarSyncResult> runCalendarSync({
  required CommitmentsNotifier commitments,
  required SettingsNotifier settings,
  required CalendarSource source,
}) async {
  try {
    final result = await commitments.syncFromCalendar(
      source: source,
      configuredCalendarIds: configuredCalendarIdsFor(settings),
    );
    if (!result.failed) {
      await settings.recordCalendarSyncSuccess(
        syncedAt: result.syncedAt,
        skipped: result.skipped,
      );
    }
    return result;
  } catch (_) {
    return CalendarSyncResult(
      imported: const [],
      skipped: const [],
      failed: true,
      syncedAt: DateTime.now(),
    );
  }
}
