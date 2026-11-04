import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/calendar/calendar_event.dart';
import '../../data/calendar/calendar_overlap.dart';
import '../../data/calendar/calendar_source.dart';
import '../../data/calendar/calendar_source_factory.dart';
import '../../data/calendar/device_calendar_source.dart';
import '../../data/calendar/google_auth_client.dart';
import '../../data/calendar/google_calendar_source.dart';
import '../../dev/dev_clock.dart';
import '../../providers/calendar_sync_runner.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../services/calendar_sync_service.dart';
import '../../widgets/adaptive_form_modal.dart';

/// CAL-02 + CAL-04: shows the user exactly what their device (or subscribed
/// feed) exposes, remembers what they tick, and stays honest and usable when
/// the answer is "no access."
///
/// Branches by platform: iOS takes the device permission path; Android,
/// desktop, and web all take the feed-URL path (D-35-12 originally routed
/// Android through the device branch too, but D-35-15 moved it here — see
/// [_isMobile] and `device_calendar_source.dart`'s class doc comment for why).
/// There is no combined multi-source picker and no fourth "calendar
/// unavailable" screen — the absence of configuration IS the not-connected
/// CTA state on both branches (35-UI-SPEC.md §5).
///
/// Permission is read live every time this screen is opened; no permission
/// result is ever persisted anywhere (D-35-10). On open, a device source that
/// can read its status without prompting ([CalendarPermissionReader]) is
/// asked for it, and an already-granted permission restores the calendar list
/// directly (WINDOWS entry 12) — that read can never show an OS prompt, so
/// opening the screen still never surprises the user with one. The OS prompt
/// is only ever raised by the user tapping "Allow calendar access" (see
/// [_startMobileFlow]), which is also what a source that cannot read its
/// status keeps doing.
///
/// **CORS on the web build.** A Flutter **web** build fetching a third-party
/// `.ics` URL is subject to the browser's cross-origin rules, and most
/// public calendar feeds (Google, Outlook, etc.) do not send permissive CORS
/// headers. A perfectly valid feed URL can therefore fail to load in the
/// browser build while working fine on desktop or mobile — this is a browser
/// policy, not a bug in this screen and not a bad URL, and there is no
/// in-app fix without a proxy this app does not have. The locked failure
/// copy in [_syncAndReport] already covers it; documented here so the next
/// reader does not re-diagnose it (Task 3, 35-04-PLAN.md). 35-06's UAT
/// sidesteps it by serving a fixture feed from the same origin as the app.
class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key, this.source, this.googleSource});

  /// Test-only override. Production always builds via [defaultCalendarSource]
  /// from the current [SettingsNotifier.icsUrls]. On iOS this is the DEVICE
  /// source specifically (see [_resolveDeviceSource]) — never the composite
  /// [defaultCalendarSource] builds when a Google client is supplied, since a
  /// composite's own `requestPermission()` always answers `notApplicable`,
  /// which would break this screen's device-permission gating.
  final CalendarSource? source;

  /// Test-only override for the Google section specifically (Plan 36-06),
  /// mirroring [source] but scoped to the Google side of the picker —
  /// D-36-03 renders Google and device as two independent, always-present
  /// sections rather than one combined source. Production builds a real
  /// [GoogleCalendarSource] backed by a [GoogleAuthClient] whose token store
  /// is the current [SettingsNotifier] (it already implements
  /// [GoogleTokenStore]).
  final CalendarSource? googleSource;

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

/// Puts a device calendar list into one deterministic order: by account name
/// (case-insensitive, calendars with no account first), then calendar name
/// (case-insensitive), then id. Returns a NEW list; [calendars] is never
/// mutated.
///
/// WINDOWS entry 14 (36-16), mechanism A: a tick landed on the wrong calendar
/// on the owner's iPhone. `device_calendar_plus_ios-0.7.0`'s
/// `CalendarService.swift` (lines 12-55) iterates `eventStore.calendars(for:
/// .event)` and appends in that order with no sort, Apple documents no order
/// for that call, and nothing between the plugin and `_calendarRows` sorted —
/// so a re-fetch could put every row somewhere else under a finger aimed at
/// the previous layout.
///
/// Applied to the DEVICE section only: Google's API returns a stable order the
/// user already recognises (primary calendar first), and EventKit documents
/// none.
List<CalendarInfo> sortCalendarsForPicker(List<CalendarInfo> calendars) {
  int byText(String a, String b) {
    final c = a.toLowerCase().compareTo(b.toLowerCase());
    return c != 0 ? c : a.compareTo(b);
  }

  final sorted = List<CalendarInfo>.of(calendars);
  sorted.sort((a, b) {
    final aAccount = a.accountName ?? '';
    final bAccount = b.accountName ?? '';
    // No account sorts first (empty string), ahead of any named account.
    if (aAccount.isEmpty != bAccount.isEmpty) return aAccount.isEmpty ? -1 : 1;
    final account = byText(aAccount, bAccount);
    if (account != 0) return account;
    final name = byText(a.name, b.name);
    if (name != 0) return name;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

/// The outcome of the mobile permission flow, once the user has tapped
/// "Allow calendar access" (or a prior grant resolves instantly).
class _MobileState {
  const _MobileState({
    required this.permission,
    required this.calendars,
    this.syncResult,
  });

  final CalendarPermissionState permission;
  final List<CalendarInfo> calendars;
  final CalendarSyncResult? syncResult;
}

/// The outcome of loading the desktop/web ICS feed list.
class _DesktopState {
  const _DesktopState({required this.calendars, this.syncResult});

  final List<CalendarInfo> calendars;
  final CalendarSyncResult? syncResult;
}

/// The outcome of the Google section's own flow (Plan 36-06) — independent
/// of [_MobileState], since D-36-03 renders Google and device as two
/// separate, always-present sections rather than one combined state.
/// `connected: false` covers BOTH "never connected" and "the user cancelled
/// the consent sheet" — [GoogleCalendarSource.requestPermission] already
/// maps a cancellation onto [CalendarPermissionState.notDetermined]
/// precisely so this state needs no separate "cancelled" case. A genuine
/// sign-in FAILURE also lands on `connected: false`, but [_connectGoogle]
/// announces it with a SnackBar first, so the user can tell it from a
/// cancellation (WINDOWS entry 4).
///
/// [loadFailed] (WR-05) is the fourth case: sign-in is valid and stored,
/// but listing the calendars failed. It renders "Connected, but couldn't
/// load your calendars." with a retry that lists again — never the Connect
/// CTA, which would force a needless second consent.
class _GoogleState {
  const _GoogleState({required this.connected, this.calendars = const []})
    : loadFailed = false;

  /// Connected, token stored, but `listCalendars()` threw (WR-05).
  const _GoogleState.loadFailed()
    : connected = true,
      calendars = const [],
      loadFailed = true;

  final bool connected;
  final List<CalendarInfo> calendars;
  final bool loadFailed;
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  /// Null = "nothing resolved yet" (the CTA state). Set either when the user
  /// taps "Allow calendar access" ([_startMobileFlow], the only path that can
  /// raise the OS prompt) or, on first build, by [_restoreDeviceSection] when
  /// the device source is a [CalendarPermissionReader] — a read that can
  /// never prompt, which is what keeps "opening this screen never surprises
  /// the user with a native OS prompt" true (WINDOWS entry 12).
  Future<_MobileState>? _mobileFuture;

  /// True while a mobile "Sync now" is running (WINDOWS entry 13).
  bool _syncing = false;

  /// This screen's OWN SnackBar host (WINDOWS entry 17, fourth round —
  /// owner on hardware 2026-11-04: the popup "covers the sync" button).
  /// The app has one ScaffoldMessenger at MaterialApp, and a messenger shows
  /// SnackBars on the OUTERMOST Scaffold it serves — here the app shell's
  /// (lib/widgets/responsive_shell.dart), whose bottom edge is the
  /// Today/Goals/Settings bar, BELOW this screen's pinned footer. So the
  /// popup rose over "Sync now" no matter where the footer was pinned. A
  /// messenger of our own makes THIS Scaffold the outermost one it serves,
  /// so the popup slides up above the pinned footer instead.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  ScaffoldMessengerState get _messenger =>
      _messengerKey.currentState ?? ScaffoldMessenger.of(context);

  /// True from the moment "Sync now" is pressed until the success popup has
  /// gone (owner 2026-11-04: the footer line "says the exact same thing as
  /// the popup so maybe it should disappear and reappear after you press
  /// the button"). The footer status line is hidden meanwhile, then plays
  /// its entrance once the popup closes.
  bool _statusHidden = false;

  /// True once the device section has resolved to granted, by restore or by
  /// an explicit grant — so the shared footer (and its "Sync now") shows
  /// even before any sync has ever run (35-UI-SPEC §2: footer whenever at
  /// least one source is configured).
  bool _deviceGranted = false;

  /// Loaded once per set of configured feed URLs; reset to null after any
  /// add/remove so the next build re-fetches from the fresh configuration.
  Future<_DesktopState>? _desktopFuture;

  /// Null = "not connected yet" (the Google CTA state) — set either when
  /// the user taps "Connect Google Calendar" ([_connectGoogle]) or, on
  /// first build, when [SettingsNotifier.googleConnected] is already true
  /// from a prior session ([_loadGoogleCalendars]) — mirroring
  /// [_mobileFuture]'s own lazy, `??=`-in-build pattern. Reset to null on
  /// Disconnect. [SettingsNotifier.reconnectNeeded] is still checked FIRST
  /// and directly from persisted state, regardless of this field
  /// (CALAUTH-03, Task 2) — a dead token wins before this field is ever
  /// consulted.
  Future<_GoogleState>? _googleFuture;

  /// Every calendar the Google section has most recently listed, kept
  /// alongside [_deviceCalendars] purely so Task 3's overlap detector can
  /// see BOTH sources' full calendar lists together regardless of which
  /// section's own future last resolved.
  List<CalendarInfo> _googleCalendars = const [];
  List<CalendarInfo> _deviceCalendars = const [];

  // iOS-only as of D-35-15 (35-05, 35-DECISIONS.md): Android's calendar
  // source moved from the device plugin to IcsCalendarSource, the same
  // feed-URL mechanism desktop/web already use, so Android now takes the
  // desktop branch below rather than this permission-CTA branch. Was
  // `Platform.iOS || Platform.android` under the original D-35-12 plan;
  // narrowed to iOS-only when D-35-15 reversed which mechanism Android
  // uses (device_calendar_plus cannot be scoped read-only on Android — see
  // device_calendar_source.dart's class doc comment for the full reason).
  bool get _isMobile => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// The DEVICE source specifically — used for the device section's own
  /// `requestPermission()`/`listCalendars()`. Deliberately NOT the factory's
  /// composite: [CompositeCalendarSource.requestPermission] always answers
  /// `notApplicable` (permission is a per-child concept), which would break
  /// this gate if used here instead.
  CalendarSource _resolveDeviceSource(SettingsNotifier settings) =>
      widget.source ?? DeviceCalendarSource();

  /// Google-prefixed ids from the persisted selection — the exact filter
  /// [GoogleCalendarSource] needs at construction time, since
  /// `CalendarSyncService.sync()` always calls `listEvents` with an EMPTY
  /// `calendarIds` argument, so the constructor-time list is the only place
  /// this can ever take effect (WINDOWS.md entry 5).
  List<String> _googleSelectedIds(SettingsNotifier settings) =>
      filterGoogleCalendarIds(settings.selectedCalendarIds);

  /// The non-Google ids from the persisted selection — the exact complement
  /// of [_googleSelectedIds], and the device half [DeviceCalendarSource]
  /// needs at construction time for the same reason (WINDOWS.md entry 7,
  /// CAL-02, gap plan 36-08). Deliberately paired with [_googleSelectedIds]
  /// so the two read as the pair they are.
  List<String> _deviceSelectedIds(SettingsNotifier settings) =>
      filterDeviceCalendarIds(settings.selectedCalendarIds);

  /// The Google source specifically — used for the Google section's own
  /// connect/list/disconnect flow.
  CalendarSource _resolveGoogleSource(SettingsNotifier settings) =>
      widget.googleSource ??
      GoogleCalendarSource(
        authClient: GoogleAuthClient(store: settings),
        calendarIds: _googleSelectedIds(settings),
      );

  /// The FULL composite (Google + device) — used ONLY to actually sync
  /// events into commitments (Task 1: "the sync... sees the composite").
  /// Never used for `requestPermission()`/`listCalendars()` — see
  /// [_resolveDeviceSource]'s own doc comment for why.
  CalendarSource _resolveSyncSource(SettingsNotifier settings) =>
      widget.source ??
      defaultCalendarSource(
        icsUrls: settings.icsUrls,
        googleAuth: GoogleAuthClient(store: settings),
        googleCalendarIds: _googleSelectedIds(settings),
        deviceCalendarIds: _deviceSelectedIds(settings),
      );

  // ── Shared: sync + status ────────────────────────────────────────────

  /// Runs a real sync through [runCalendarSync] — the same function check-in
  /// uses — which passes the user's configured calendars to the prune and, on
  /// success only, records the sync time AND the skipped list on
  /// [SettingsNotifier] (WINDOWS entries 10 and 11). Surfaces the locked
  /// failure SnackBar on failure. Never throws — [runCalendarSync] guarantees
  /// it.
  ///
  /// Nothing about the result is kept on this State: the footer and the
  /// skipped-events banner read [SettingsNotifier], which is what survives the
  /// screen being left and re-entered, and the app being relaunched.
  Future<CalendarSyncResult> _syncAndReport(
    CalendarSource source,
    CommitmentsNotifier commitments,
    SettingsNotifier settings,
    ScaffoldMessengerState messenger,
  ) async {
    final result = await runCalendarSync(
      commitments: commitments,
      settings: settings,
      source: source,
      schedule: _schedule,
    );
    if (result.failed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Calendar sync failed — showing your last-known calendars.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
    return result;
  }

  /// Today's schedule, so a sync from this screen also updates today's
  /// timeline (WINDOWS entry 16). Null when no [ScheduleNotifier] is provided
  /// above this screen (several widget tests pump it without one).
  ScheduleNotifier? _schedule;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _schedule = Provider.of<ScheduleNotifier>(context, listen: false);
    } on ProviderNotFoundException {
      _schedule = null;
    }
  }

  /// "just now" inside the first minute ("that was clearer" — owner,
  /// 2026-11-03), then a clock time: "at 8:37 AM" today, "Nov 2 at 8:37 AM"
  /// on an earlier day (WINDOWS entry 17).
  String _syncTimeLabel(DateTime time) {
    final now = DevClock.now();
    if (now.difference(time).inMinutes < 1) return 'just now';
    final local = time.toLocal();
    final clock = DateFormat.jm().format(local);
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay
        ? 'at $clock'
        : '${DateFormat.MMMd().format(local)} at $clock';
  }

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.blueGrey;
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return Colors.blueGrey;
    return Color(0xFF000000 | value);
  }

  void _showSkippedSheet(BuildContext context, List<SkippedEvent> skipped) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final event in skipped)
              ListTile(
                title: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(event.reason.label),
              ),
          ],
        ),
      ),
    );
  }

  /// The ONE builder of the "Sync status (fresh)" sentence. Changed by the
  /// owner on 2026-11-03 from 35-UI-SPEC's relative "Synced just now" to a
  /// clock time ("Synced at 8:37 AM — …"), WINDOWS entry 17.
  String _statusText(DateTime syncedAt, int importedCount) =>
      'Synced ${_syncTimeLabel(syncedAt)} — $importedCount '
      'commitment${importedCount == 1 ? '' : 's'} imported';

  Widget _footer(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsNotifier>();
    final importedCount = context
        .watch<CommitmentsNotifier>()
        .blocks
        .where((b) => b.isFromCalendar)
        .length;
    // Reads ONLY the persisted success-only time. A failed attempt's
    // `syncedAt` must never surface here, or a failed sync would render as
    // a fresh just-now sync (WINDOWS entry 13).
    final lastSync = settings.lastCalendarSyncAt;
    final statusText = lastSync == null
        ? 'Not synced yet'
        : _statusText(lastSync, importedCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // WINDOWS entry 17, fourth round (owner 2026-11-04: "the
          // animation is too subtle" and the line repeats the popup). The
          // line is hidden from "Sync now" until the popup closes (see
          // [_statusHidden]); then the fresh line rises in from below and
          // lands highlighted in the primary colour, which fades back to
          // the normal muted text over ~1.6s. The hidden state keeps the
          // line's height so the button below never jumps.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _statusHidden
                ? Text(
                    ' ',
                    key: const ValueKey('status-hidden'),
                    style: theme.textTheme.bodySmall,
                  )
                : TweenAnimationBuilder<double>(
                    key: ValueKey(lastSync),
                    tween: Tween(begin: lastSync == null ? 0.0 : 1.0, end: 0.0),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeIn,
                    builder: (context, highlight, _) => Container(
                      key: const ValueKey('sync-status-line'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.transparent,
                          theme.colorScheme.primaryContainer,
                          highlight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Color.lerp(
                            theme.colorScheme.onSurfaceVariant,
                            theme.colorScheme.onPrimaryContainer,
                            highlight,
                          ),
                          fontWeight: highlight > 0.5
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            // While a mobile sync runs, the button disables and carries a
            // spinner beside the unchanged label — the UI-SPEC's own
            // "Requesting (in flight)" idiom of a spinner with no copy.
            child: _syncing
                ? TextButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: const Text('Sync now'),
                  )
                : TextButton(
                    onPressed: () => _syncNow(context),
                    child: const Text('Sync now'),
                  ),
          ),
        ],
      ),
    );
  }

  /// The skipped-events disclosure, promoted to the TOP of the screen
  /// (WINDOWS entry 10) rather than buried under both calendar sections.
  /// Reads [SettingsNotifier.lastCalendarSyncSkipped] — the persisted list
  /// the last SUCCESSFUL sync recorded through [runCalendarSync] — not a
  /// parameter, since this is called unconditionally as the first child of
  /// both bodies, before either section's own state exists.
  ///
  /// WINDOWS entry 10 was reopened on 2026-11-02: this used to read this
  /// screen's in-memory sync result, which is born empty every time the
  /// screen opens, so the disclosure vanished the moment the owner left
  /// Settings -> Calendars and came back (and after every relaunch) until a
  /// sync happened to run again. A failed sync leaves the persisted list, and
  /// so the banner, as the last successful sync left it.
  ///
  /// This is load-bearing, not cosmetic (D-36-05): once an all-day event is
  /// always skipped rather than imported (Task 1), this disclosure is the
  /// ONLY channel through which the user ever learns a calendar entry (e.g.
  /// a real `Vacation`) was not imported. Shipping the skip without this
  /// promotion would trade six visible fake blocks for one invisible
  /// omission — which is why both land in the same plan.
  ///
  /// The string itself is unchanged, locked copy (35-UI-SPEC.md) — this
  /// method changes placement and weight only.
  Widget _skippedBanner(BuildContext context) {
    final skipped = context.watch<SettingsNotifier>().lastCalendarSyncSkipped;
    if (skipped.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        // Deliberately a neutral surface tone, never the error role — a
        // skipped event (e.g. an all-day entry under D-36-05) is a normal
        // outcome, not a fault. Same reasoning as _deniedCard's own comment
        // (UI-SPEC Color contract, CAL-04).
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSkippedSheet(context, skipped),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    // Locked copy (35-UI-SPEC.md Copywriting Contract) —
                    // unchanged character for character; only placement and
                    // weight moved.
                    '${skipped.length} events not imported — tap for details',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Manual re-trigger (Task 3) — a settings screen that shows sync status
  /// and offers no way to refresh it can only ever tell you it is stale.
  /// Reuses the same state-loading methods the initial open already runs
  /// through, so there is exactly one sync code path per branch, not two.
  void _syncNow(BuildContext context) {
    final settings = context.read<SettingsNotifier>();
    if (_isMobile) {
      unawaited(_syncInPlace(context, settings));
    } else {
      setState(
        () => _desktopFuture = _loadDesktopState(context, settings.icsUrls),
      );
    }
  }

  /// The mobile "Sync now" (WINDOWS entry 13): syncs IN PLACE. It never
  /// touches [_mobileFuture], never calls `requestPermission()` and never
  /// re-lists calendars — the rows the user is looking at stay put. The
  /// button shows it is working ([_syncing]) and, on success, a SnackBar
  /// carries the same locked sentence the footer shows; on failure
  /// [_syncAndReport] has already shown the locked failure SnackBar.
  ///
  /// The desktop/web "Sync now" is deliberately NOT changed: it already
  /// replaces the body with a spinner while it reloads, and no defect was
  /// reported there.
  Future<void> _syncInPlace(
    BuildContext context,
    SettingsNotifier settings,
  ) async {
    if (_syncing) return;
    final commitments = context.read<CommitmentsNotifier>();
    final messenger = _messenger;
    setState(() {
      _syncing = true;
      _statusHidden = true;
    });
    var popupShown = false;
    try {
      final result = await _syncAndReport(
        _resolveSyncSource(settings),
        commitments,
        settings,
        messenger,
      );
      // WINDOWS entry 17, third round (owner 2026-11-03: "the popup was
      // better — clearer"): the success SnackBar is back. It no longer
      // covers "Sync now" because, on mobile, the footer is the Scaffold's
      // bottomNavigationBar and a SnackBar always slides up ABOVE that.
      if (!result.failed && mounted) {
        final importedCount = commitments.blocks
            .where((b) => b.isFromCalendar)
            .length;
        popupShown = true;
        messenger
            .showSnackBar(
              SnackBar(
                content: Text(_statusText(result.syncedAt, importedCount)),
                duration: const Duration(seconds: 3),
              ),
            )
            .closed
            .then((_) {
              if (mounted) setState(() => _statusHidden = false);
            });
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          // No success popup (the sync failed): nothing will close, so
          // bring the line straight back — it still reads the last
          // SUCCESSFUL sync, never the failed attempt (WINDOWS entry 13).
          if (!popupShown) _statusHidden = false;
        });
      }
    }
  }

  Widget _ctaCard({
    required BuildContext context,
    required String headline,
    required String body,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 32),
              Text(
                headline,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile branch ────────────────────────────────────────────────────

  void _startMobileFlow(BuildContext context) {
    final settings = context.read<SettingsNotifier>();
    final commitments = context.read<CommitmentsNotifier>();
    final messenger = _messenger;
    final source = _resolveDeviceSource(settings);
    setState(() {
      _mobileFuture = _requestMobilePermission(
        source,
        commitments,
        settings,
        messenger,
      );
    });
  }

  Future<_MobileState> _requestMobilePermission(
    CalendarSource source,
    CommitmentsNotifier commitments,
    SettingsNotifier settings,
    ScaffoldMessengerState messenger,
  ) async {
    final permission = await source.requestPermission();
    if (permission != CalendarPermissionState.granted) {
      return _MobileState(permission: permission, calendars: const []);
    }
    final calendars = await source.listCalendars();
    if (mounted) {
      setState(() {
        _deviceCalendars = calendars;
        _deviceGranted = true;
      });
    }
    // Sync via the FULL composite (Task 1: "the sync... sees the
    // composite"), not the device-only [source] above — on iOS this also
    // imports a signed-in Google account's events, if one exists.
    final syncResult = await _syncAndReport(
      _resolveSyncSource(settings),
      commitments,
      settings,
      messenger,
    );
    return _MobileState(
      permission: permission,
      calendars: calendars,
      syncResult: syncResult,
    );
  }

  /// Restores the device section on screen re-open WITHOUT ever prompting —
  /// the fix for WINDOWS entry 12 and the device twin of
  /// [_loadGoogleCalendars]. Reads the current status through
  /// [CalendarPermissionReader.currentPermission]; when granted, lists
  /// calendars and nothing else. Never calls `requestPermission()` and never
  /// syncs (opening a settings screen must not rewrite the schedule).
  ///
  /// Any throw folds to `notDetermined` — the CTA, i.e. the behaviour before
  /// this fix — rather than a new state with new copy.
  Future<_MobileState> _restoreDeviceSection(
    CalendarSource source,
    CalendarPermissionReader reader,
  ) async {
    try {
      final permission = await reader.currentPermission();
      if (permission != CalendarPermissionState.granted) {
        return _MobileState(permission: permission, calendars: const []);
      }
      final calendars = await source.listCalendars();
      if (mounted) {
        setState(() {
          _deviceCalendars = calendars;
          _deviceGranted = true;
        });
      }
      return _MobileState(permission: permission, calendars: calendars);
    } catch (_) {
      return const _MobileState(
        permission: CalendarPermissionState.notDetermined,
        calendars: [],
      );
    }
  }

  void _toggleCalendar(SettingsNotifier settings, String id, bool value) {
    final current = List<String>.of(settings.selectedCalendarIds);
    if (value) {
      if (!current.contains(id)) current.add(id);
    } else {
      current.remove(id);
    }
    settings.setSelectedCalendarIds(current);
  }

  Widget _emptyCalendarsState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No calendars found on this device.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Add an account in your phone's Settings app, or subscribe "
                "by a calendar's URL below.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deniedCard(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            // Deliberately a neutral surface tone, never the error role — a
            // denied permission is a normal state, not a fault (UI-SPEC
            // Color contract, CAL-04).
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Calendar access is off',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Canopy can't see your device calendars, so it won't "
                    "know about events you haven't entered yourself. "
                    'Everything else still works — add commitments by hand '
                    'on the Commitments screen. You can turn access back on '
                    'any time.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    // Deep-linking into OS Settings needs a plugin this
                    // screen does not import — 35-05's DeviceCalendarSource
                    // plan lands the real device permission flow, and with
                    // it, the actual OS settings hand-off. This button is
                    // real and reachable now; wiring the jump is 35-05's job.
                    onPressed: () {},
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Renders one calendar per row, grouped by account — shared by BOTH
  /// sections (D-36-03: Google's own list flows through the SAME machinery
  /// the device list uses). Unlike the pre-36-06 version of this method,
  /// this does NOT wrap in a `ListView` or append [_footer] — Task 1 needs
  /// exactly one shared footer for the whole combined body, not one per
  /// section, so the caller (the combined [_buildMobileBody]) owns both.
  ///
  /// [allCalendars] is the FULL calendar list from BOTH sources (not just
  /// [calendars], which is this call's own section) — Task 3's overlap
  /// detector needs to see both sides to find a cross-source pair
  /// regardless of which section is rendering a given row.
  List<Widget> _calendarRows(
    BuildContext context,
    List<CalendarInfo> calendars,
    SettingsNotifier settings, {
    required List<CalendarInfo> allCalendars,
  }) {
    final theme = Theme.of(context);
    final groups = <String, List<CalendarInfo>>{};
    for (final calendar in calendars) {
      groups.putIfAbsent(calendar.accountName ?? '', () => []).add(calendar);
    }
    final selected = settings.selectedCalendarIds.toSet();
    // D-36-03's REQUIRED mitigation (Task 3): disclose a same-calendar
    // double-tick across sources at the moment of ticking — never merge,
    // never filter, never drop either side (T-36-25). This function only
    // ever ADDS an advisory note; it must never change what [calendars] or
    // [selected] contains.
    final overlaps = detectSelectedCalendarOverlaps(
      calendars: allCalendars,
      selectedIds: selected,
    );
    final overlappingIds = <String>{
      for (final overlap in overlaps) overlap.google.id,
      for (final overlap in overlaps) overlap.device.id,
    };
    return [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            entry.key.isEmpty ? 'This device' : entry.key,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final calendar in entry.value) ...[
          CheckboxListTile(
            secondary: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _parseColor(calendar.colorHex),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              calendar.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: selected.contains(calendar.id),
            onChanged: (checked) =>
                _toggleCalendar(settings, calendar.id, checked ?? false),
          ),
          if (overlappingIds.contains(calendar.id))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'These may be the same calendar — events could '
                      'appear twice.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    ];
  }

  // ── Google branch (Plan 36-06, D-36-03) ─────────────────────────────────

  Widget _googleCtaCard(BuildContext context, SettingsNotifier settings) =>
      _ctaCard(
        context: context,
        headline: 'Connect your Google Calendar',
        body:
            'Sign in once and Canopy reads your Google calendars directly '
            '— no links to find, nothing to paste. Canopy asks Google for '
            'read-only access, so it can never change anything in your '
            'calendar.',
        buttonLabel: 'Connect Google Calendar',
        onPressed: () => _startGoogleConnect(context, settings),
      );

  /// CALAUTH-03: the login has expired and the screen says so at the exact
  /// spot the Google calendar list would otherwise be — the list cannot be
  /// fetched anyway, since the token that would fetch it is the dead one.
  /// Structure copied verbatim from [_deniedCard]: neutral surface, outline
  /// border, one action. The ICON alone renders in [ColorScheme.error] —
  /// see 36-06-PLAN.md's objective for why this is consistent with (not an
  /// exception to) 35-UI-SPEC's "error is for a genuine failure" rule: a
  /// dead refresh token is a real operation that really failed, unlike
  /// [_deniedCard]'s denied permission, which is a user's normal choice.
  Widget _googleReconnectCard(BuildContext context, SettingsNotifier settings) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Google sign-in expired',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Canopy can't read your Google calendar until you sign "
                    'in again, so what it shows you may be out of date. '
                    'Everything else still works — your other calendars '
                    'and anything you added by hand are unaffected.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _startGoogleConnect(context, settings),
                    child: const Text('Reconnect Google Calendar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startGoogleConnect(BuildContext context, SettingsNotifier settings) {
    final commitments = context.read<CommitmentsNotifier>();
    final messenger = _messenger;
    setState(() {
      _googleFuture = _connectGoogle(settings, commitments, messenger);
    });
  }

  Future<_GoogleState> _connectGoogle(
    SettingsNotifier settings,
    CommitmentsNotifier commitments,
    ScaffoldMessengerState messenger,
  ) async {
    final source = _resolveGoogleSource(settings);
    // WINDOWS entry 4: connect has THREE outcomes and this screen keeps all
    // three apart. GoogleCalendarSource.requestPermission() answers granted
    // (connected) or notDetermined (cancelled — a state, not an error) and
    // THROWS for a genuine failure (GoogleAuthException: the consent flow
    // itself failed, or returned no token). The throw is caught here, on its
    // own, so a failed sign-in says so instead of looking exactly like the
    // user backing out. No `enum GoogleConnectOutcome` is introduced: the
    // CalendarSource interface fixes requestPermission()'s return type, so
    // a failure has to cross that boundary as a throw whatever connect()
    // returns, and the screen would see the same three signals it sees now.
    final CalendarPermissionState permission;
    try {
      permission = await source.requestPermission();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't connect to Google. Please try again."),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
        ),
      );
      return const _GoogleState(connected: false);
    }
    try {
      if (permission != CalendarPermissionState.granted) {
        // Cancelled — GoogleCalendarSource.requestPermission() already maps
        // a cancellation onto notDetermined precisely so this reads
        // identically to "not connected": no error card, no SnackBar.
        return const _GoogleState(connected: false);
      }
      final calendars = await source.listCalendars();
      if (mounted) setState(() => _googleCalendars = calendars);
      await _syncAndReport(
        _resolveSyncSource(settings),
        commitments,
        settings,
        messenger,
      );
      return _GoogleState(connected: true, calendars: calendars);
    } catch (_) {
      // Sign-in SUCCEEDED; a failure here is listCalendars() (a
      // GoogleSourceException) after a valid token was stored. WR-05: NOT a
      // failed sign-in, and NOT "not connected" either — show the
      // load-failed card, whose retry lists again without re-consent.
      // (_syncAndReport never throws.)
      return const _GoogleState.loadFailed();
    }
  }

  /// Restores the connected Google section on screen re-open, for a
  /// [SettingsNotifier.googleConnected] account, WITHOUT ever launching
  /// Google's consent sheet — the fix for WINDOWS entry 6. Lists calendars
  /// only; never calls `requestPermission()`.
  ///
  /// On any throw, returns [_GoogleState.loadFailed] (WR-05, copy approved
  /// by the owner 2026-11-03): the token is still valid, so the screen
  /// offers "Try again" — which calls this method again — rather than the
  /// Connect CTA and a needless full re-consent. Also the retry target.
  Future<_GoogleState> _loadGoogleCalendars(SettingsNotifier settings) async {
    final source = _resolveGoogleSource(settings);
    try {
      final calendars = await source.listCalendars();
      if (mounted) setState(() => _googleCalendars = calendars);
      return _GoogleState(connected: true, calendars: calendars);
    } catch (_) {
      return const _GoogleState.loadFailed();
    }
  }

  /// WR-05: signed in, but the calendar list could not be fetched. The retry
  /// lists again ([_loadGoogleCalendars]) — it never calls
  /// `requestPermission()`, so it never re-launches Google's consent sheet.
  /// Disconnect stays reachable so this card is never a dead end.
  Widget _googleLoadFailedCard(
    BuildContext context,
    SettingsNotifier settings,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                "Connected, but couldn't load your calendars. Try again.",
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {
                  _googleFuture = _loadGoogleCalendars(settings);
                }),
                child: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _disconnectGoogle(context, settings),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleConnectedSection(
    BuildContext context,
    SettingsNotifier settings,
    List<CalendarInfo> calendars,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Google',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ..._calendarRows(
          context,
          calendars,
          settings,
          allCalendars: [..._googleCalendars, ..._deviceCalendars],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _disconnectGoogle(context, settings),
              child: const Text('Disconnect'),
            ),
          ),
        ),
      ],
    );
  }

  /// `_removeFeed`'s existing `AlertDialog` shape (see that method below),
  /// but with copy that says what Disconnect actually does — see
  /// 36-06-PLAN.md's objective for why this does NOT copy the ICS dialog's
  /// "will disappear the next time you sync" sentence.
  ///
  /// That sentence was untrue when this was written (`sync()` only ever
  /// upserted) and is TRUE for the ICS dialog now that the selection prune
  /// runs (WINDOWS entry 11, wired by [runCalendarSync]). It is still
  /// deliberately absent here, because it would still be untrue for Google:
  /// Disconnect clears the token but leaves the `google:` ids in
  /// [SettingsNotifier.selectedCalendarIds], so they stay configured (the
  /// selection prune keeps them) and the Google child fails without a token
  /// (the event prune never touches a calendar whose source did not answer).
  /// Imported Google commitments therefore stay on the schedule, exactly as
  /// the dialog below promises. There is no in-app way to remove them until
  /// the user reconnects and unticks the calendars (36-17 logs this).
  Future<void> _disconnectGoogle(
    BuildContext context,
    SettingsNotifier settings,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Canopy will stop reading your Google calendars. Commitments '
          'already imported stay on your schedule until you remove them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Disconnect',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await GoogleAuthClient(store: settings).disconnect();
    if (!mounted) return;
    setState(() {
      _googleFuture = null;
      _googleCalendars = const [];
    });
  }

  Widget _buildGoogleSection(BuildContext context, SettingsNotifier settings) {
    // CALAUTH-03 (Task 2): checked FIRST, from persisted state only (D-35-10)
    // — a dead refresh token must never be silently overwritten by a fresh
    // "not connected" render.
    if (settings.reconnectNeeded) {
      return _googleReconnectCard(context, settings);
    }
    // WINDOWS entry 6 (Task 2): a valid stored token restores the
    // connected view on re-open — by listing calendars only, never by
    // re-launching consent. The in-build `??=` idiom mirrors
    // `_buildDesktopBody`'s own `_desktopFuture ??= ...` precedent.
    if (_googleFuture == null && settings.googleConnected) {
      _googleFuture = _loadGoogleCalendars(settings);
    }
    if (_googleFuture == null) {
      return _googleCtaCard(context, settings);
    }
    return FutureBuilder<_GoogleState>(
      future: _googleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Connecting — the spinner replaces the CARD only. The device
          // section (rendered separately, always present) stays visible
          // and usable underneath.
          return const Center(child: CircularProgressIndicator());
        }
        final state = snapshot.data!;
        if (!state.connected) {
          return _googleCtaCard(context, settings);
        }
        if (state.loadFailed) {
          return _googleLoadFailedCard(context, settings);
        }
        return _googleConnectedSection(context, settings, state.calendars);
      },
    );
  }

  // ── Device branch ────────────────────────────────────────────────────

  Widget _buildDeviceSection(BuildContext context, SettingsNotifier settings) {
    // WINDOWS entry 12: a source that can read its permission status without
    // prompting is asked for it on first build, so an already-granted
    // permission shows the list instead of the CTA. A runtime `is` check, not
    // a static type — a source without the capability keeps the CTA flow.
    if (_mobileFuture == null) {
      final source = _resolveDeviceSource(settings);
      if (source is CalendarPermissionReader) {
        // `CalendarPermissionReader` is unrelated to `CalendarSource`, so the
        // `is` check does not promote `source` — the cast is the capability
        // hand-off, safe because the check just passed.
        _mobileFuture = _restoreDeviceSection(
          source,
          source as CalendarPermissionReader,
        );
      }
    }
    if (_mobileFuture == null) {
      return _ctaCard(
        context: context,
        headline: 'See your calendars here',
        body:
            'Canopy can show every calendar your phone already has — '
            "Google, iCloud, Outlook, anything you've added at the OS "
            'level. Nothing is created or changed; commitments are only '
            'ever read.',
        buttonLabel: 'Allow calendar access',
        onPressed: () => _startMobileFlow(context),
      );
    }
    return FutureBuilder<_MobileState>(
      future: _mobileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final state = snapshot.data!;
        switch (state.permission) {
          case CalendarPermissionState.granted:
            if (state.calendars.isEmpty) {
              return _emptyCalendarsState(context);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _calendarRows(
                context,
                // WINDOWS entry 14: one call here covers the restore path
                // and the first-grant path — both end in this builder.
                sortCalendarsForPicker(state.calendars),
                settings,
                allCalendars: [..._googleCalendars, ..._deviceCalendars],
              ),
            );
          case CalendarPermissionState.denied:
          case CalendarPermissionState.restricted:
            return _deniedCard(context);
          case CalendarPermissionState.notDetermined:
          case CalendarPermissionState.notApplicable:
            // Defensive fallback — e.g. a still-Null mobile source ahead of
            // 35-05, or a genuine OS edge case. Re-offer the CTA rather than
            // a dead screen.
            return _ctaCard(
              context: context,
              headline: 'See your calendars here',
              body:
                  'Canopy can show every calendar your phone already has — '
                  "Google, iCloud, Outlook, anything you've added at the OS "
                  'level. Nothing is created or changed; commitments are '
                  'only ever read.',
              buttonLabel: 'Allow calendar access',
              onPressed: () => _startMobileFlow(context),
            );
        }
      },
    );
  }

  // ── Combined body (D-36-03: both sources on one screen, Task 1) ───────

  Widget _buildMobileBody(BuildContext context) {
    final settings = context.watch<SettingsNotifier>();
    // The footer is NOT in this list: it is the Scaffold's
    // bottomNavigationBar (see build) — WINDOWS entry 17.
    return ListView(
      children: [
        _skippedBanner(context),
        // WINDOWS entry 14 (36-16), mechanism B: content available locally
        // renders ABOVE content that loads over the network, so nothing that
        // finishes later can move rows the user can already see. The device
        // list restores from the local store almost at once; the Google list
        // arrives over the network at an arbitrary moment. Google used to be
        // first (36-06, an implementation choice, not a ruling — D-36-03 only
        // says both sources coexist), which pushed the device rows down by
        // the whole Google list when it landed. Reversible: swap these two.
        _buildDeviceSection(context, settings),
        const Divider(indent: 16, endIndent: 16),
        _buildGoogleSection(context, settings),
      ],
    );
  }

  // ── Desktop/web branch ───────────────────────────────────────────────

  Future<List<CalendarInfo>> _tryListCalendars(
    CalendarSource source,
    List<String> urls,
  ) async {
    try {
      return await source.listCalendars();
    } catch (_) {
      // Best-effort display only — fall back to the URL itself as the name.
      // The real error surfaces via the sync SnackBar, not here.
      return [
        for (final url in urls)
          CalendarInfo(id: url, name: url, isReadOnly: true),
      ];
    }
  }

  Future<_DesktopState> _loadDesktopState(
    BuildContext context,
    List<String> urls,
  ) async {
    final commitments = context.read<CommitmentsNotifier>();
    final settings = context.read<SettingsNotifier>();
    final source = widget.source ?? defaultCalendarSource(icsUrls: urls);
    final calendars = await _tryListCalendars(source, urls);
    // Resolved AFTER the first await, not before: this load starts during
    // the very first build, before this screen's own ScaffoldMessenger has
    // mounted, so `_messenger` would fall back to the app's messenger and
    // the failure SnackBar would land on a Scaffold that never shows it.
    final messenger = _messenger;
    final syncResult = await _syncAndReport(
      source,
      commitments,
      settings,
      messenger,
    );
    return _DesktopState(calendars: calendars, syncResult: syncResult);
  }

  Future<void> _openAddFeedForm(BuildContext context) async {
    final settings = context.read<SettingsNotifier>();
    await showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: _AddFeedForm(
          onSubmit: (url) async {
            if (!url.startsWith('https://')) return false;
            try {
              final testSource = defaultCalendarSource(icsUrls: [url]);
              await testSource.listCalendars();
            } catch (_) {
              return false;
            }
            await settings.addIcsUrl(url);
            return true;
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _desktopFuture = null);
  }

  Future<void> _removeFeed(
    BuildContext context,
    String url,
    String displayName,
  ) async {
    final theme = Theme.of(context);
    // Pre-capture before the await gap (app-wide idiom) so we never reach
    // through BuildContext after showDialog resolves.
    final settings = context.read<SettingsNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this calendar?'),
        content: Text(
          '$displayName. Commitments already imported from it will '
          'disappear the next time you sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await settings.removeIcsUrl(url);
    if (!mounted) return;
    setState(() => _desktopFuture = null);
  }

  Widget _buildDesktopBody(BuildContext context) {
    final settings = context.watch<SettingsNotifier>();
    if (settings.icsUrls.isEmpty) {
      return _ctaCard(
        context: context,
        headline: 'Subscribe to a calendar',
        body:
            'Canopy can follow a calendar by its subscription link (.ics) '
            '— from Google, Outlook, or anywhere else that offers one. '
            'Nothing is written back; only read.',
        buttonLabel: 'Add calendar URL',
        onPressed: () => _openAddFeedForm(context),
      );
    }
    _desktopFuture ??= _loadDesktopState(context, settings.icsUrls);
    return FutureBuilder<_DesktopState>(
      future: _desktopFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final state = snapshot.data!;
        return Column(
          children: [
            _skippedBanner(context),
            Expanded(
              child: ListView(
                children: [
                  for (final calendar in state.calendars)
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(
                        calendar.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove calendar',
                        onPressed: () =>
                            _removeFeed(context, calendar.id, calendar.name),
                      ),
                    ),
                ],
              ),
            ),
            _footer(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => _openAddFeedForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add calendar URL'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsNotifier>();
    // Reads nothing in-memory about the last ATTEMPT: a failed first sync
    // must still leave the user a "Sync now" to retry with. The device
    // section having resolved to granted (restore or an explicit grant) is
    // set BEFORE any sync runs, so a failed first sync still shows the footer.
    final showMobileFooter =
        _isMobile &&
        (_deviceGranted ||
            settings.googleConnected ||
            settings.lastCalendarSyncAt != null);
    return ScaffoldMessenger(
      key: _messengerKey,
      child: _scaffold(context, showMobileFooter),
    );
  }

  Widget _scaffold(BuildContext context, bool showMobileFooter) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendars')),
      body: _isMobile ? _buildMobileBody(context) : _buildDesktopBody(context),
      // Pinned, not the last list item (WINDOWS entry 17): a SnackBar slides
      // up ABOVE a bottomNavigationBar, so the "Synced …" popup can never
      // cover "Sync now" again.
      bottomNavigationBar: showMobileFooter
          ? SafeArea(top: false, child: _footer(context))
          : null,
    );
  }
}

/// The desktop/web "Add calendar URL" form. Validates by actually attempting
/// a fetch+parse through [onSubmit] before closing — a failure sets the
/// field's errorText to the locked copy and the URL is NOT saved.
class _AddFeedForm extends StatefulWidget {
  const _AddFeedForm({required this.onSubmit});

  /// Returns true on success (already persisted by the caller), false on a
  /// validation/fetch failure.
  final Future<bool> Function(String url) onSubmit;

  @override
  State<_AddFeedForm> createState() => _AddFeedFormState();
}

class _AddFeedFormState extends State<_AddFeedForm> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _controller.text.trim();
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final ok = await widget.onSubmit(url);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _errorText = "Couldn't read that calendar. Check the URL and try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Subscribe to a calendar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Calendar URL (.ics)',
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add calendar URL'),
          ),
        ],
      ),
    );
  }
}
