import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/calendar/calendar_event.dart';
import '../../data/calendar/calendar_source.dart';
import '../../data/calendar/calendar_source_factory.dart';
import '../../dev/dev_clock.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../services/calendar_sync_service.dart';
import '../../widgets/adaptive_form_modal.dart';

/// CAL-02 + CAL-04: shows the user exactly what their device (or subscribed
/// feed) exposes, remembers what they tick, and stays honest and usable when
/// the answer is "no access."
///
/// Branches by platform (D-35-12): mobile (iOS/Android) takes the device
/// permission path, desktop/web take the feed-URL path. There is no combined
/// multi-source picker and no fourth "calendar unavailable" screen — the
/// absence of configuration IS the not-connected CTA state on both branches
/// (35-UI-SPEC.md §5).
///
/// Permission is read live every time this screen is opened; no permission
/// result is ever persisted anywhere (D-35-10) — see [_isMobile]'s CTA-gated
/// flow below.
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
  const CalendarSettingsScreen({super.key, this.source});

  /// Test-only override. Production always builds via [defaultCalendarSource]
  /// from the current [SettingsNotifier.icsUrls].
  final CalendarSource? source;

  @override
  State<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
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

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  /// Null = "not yet requested" (the CTA state). Set only when the user taps
  /// "Allow calendar access" — never fired automatically, so opening this
  /// screen never surprises the user with a native OS prompt.
  Future<_MobileState>? _mobileFuture;

  /// Loaded once per set of configured feed URLs; reset to null after any
  /// add/remove so the next build re-fetches from the fresh configuration.
  Future<_DesktopState>? _desktopFuture;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  CalendarSource _resolveSource(SettingsNotifier settings) =>
      widget.source ?? defaultCalendarSource(icsUrls: settings.icsUrls);

  // ── Shared: sync + status ────────────────────────────────────────────

  /// Runs a real sync through [CommitmentsNotifier.syncFromCalendar],
  /// persists [SettingsNotifier.lastCalendarSyncAt] on success only, and
  /// surfaces the locked failure SnackBar on failure. Never throws — mirrors
  /// [CommitmentsNotifier.syncFromCalendar]'s own guarantee.
  Future<CalendarSyncResult> _syncAndReport(
    CalendarSource source,
    CommitmentsNotifier commitments,
    SettingsNotifier settings,
    ScaffoldMessengerState messenger,
  ) async {
    final result = await commitments.syncFromCalendar(source: source);
    if (result.failed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Calendar sync failed — showing your last-known calendars.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
        ),
      );
    } else {
      await settings.setLastCalendarSyncAt(result.syncedAt);
    }
    return result;
  }

  String _relativeTime(DateTime time) {
    final now = DevClock.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

  Widget _footer(BuildContext context, CalendarSyncResult? syncResult) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsNotifier>();
    final importedCount = context
        .watch<CommitmentsNotifier>()
        .blocks
        .where((b) => b.isFromCalendar)
        .length;
    final lastSync = syncResult?.syncedAt ?? settings.lastCalendarSyncAt;
    final statusText = lastSync == null
        ? 'Not synced yet'
        : 'Synced ${_relativeTime(lastSync)} — $importedCount '
              'commitment${importedCount == 1 ? '' : 's'} imported';
    final skipped = syncResult?.skipped ?? const <SkippedEvent>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (skipped.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InkWell(
                onTap: () => _showSkippedSheet(context, skipped),
                child: Text(
                  '${skipped.length} events not imported — tap for details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _syncNow(context),
              child: const Text('Sync now'),
            ),
          ),
        ],
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
      final commitments = context.read<CommitmentsNotifier>();
      final messenger = ScaffoldMessenger.of(context);
      final source = _resolveSource(settings);
      setState(() {
        _mobileFuture = _requestMobilePermission(
          source,
          commitments,
          settings,
          messenger,
        );
      });
    } else {
      setState(() => _desktopFuture = _loadDesktopState(context, settings.icsUrls));
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
              ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
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
    final messenger = ScaffoldMessenger.of(context);
    final source = _resolveSource(settings);
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
    final syncResult = await _syncAndReport(
      source,
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

  Widget _groupedCalendarList(
    BuildContext context,
    List<CalendarInfo> calendars,
    SettingsNotifier settings,
    CalendarSyncResult? syncResult,
  ) {
    final theme = Theme.of(context);
    final groups = <String, List<CalendarInfo>>{};
    for (final calendar in calendars) {
      groups.putIfAbsent(calendar.accountName ?? '', () => []).add(calendar);
    }
    final selected = settings.selectedCalendarIds.toSet();
    return ListView(
      children: [
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
          for (final calendar in entry.value)
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
        ],
        _footer(context, syncResult),
      ],
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final settings = context.watch<SettingsNotifier>();
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
            return _groupedCalendarList(
              context,
              state.calendars,
              settings,
              state.syncResult,
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
        for (final url in urls) CalendarInfo(id: url, name: url, isReadOnly: true),
      ];
    }
  }

  Future<_DesktopState> _loadDesktopState(
    BuildContext context,
    List<String> urls,
  ) async {
    final commitments = context.read<CommitmentsNotifier>();
    final settings = context.read<SettingsNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final source = widget.source ?? defaultCalendarSource(icsUrls: urls);
    final calendars = await _tryListCalendars(source, urls);
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
            child: Text('Remove', style: TextStyle(color: theme.colorScheme.error)),
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
                        onPressed: () => _removeFeed(
                          context,
                          calendar.id,
                          calendar.name,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _footer(context, state.syncResult),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Calendars')),
      body: _isMobile ? _buildMobileBody(context) : _buildDesktopBody(context),
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
