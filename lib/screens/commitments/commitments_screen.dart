import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../widgets/adaptive_form_modal.dart';
import 'commitment_form_sheet.dart';

class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommitmentsNotifier>().loadBlocks(),
    );
  }

  void _openAddSheet(BuildContext context, [CommitmentBlock? block]) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final scheduleNotifier = context.read<ScheduleNotifier>();
    showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => CommitmentFormSheet(
        scrollController: scrollController,
        block: block,
        isDialog: isDesktop,
        // Re-anchor today's schedule so an added/edited event renders at its
        // current time immediately, without waiting for a mood re-check-in.
        onSaved: (saved) => scheduleNotifier.addEventToday(saved),
      ),
    );
  }

  /// Opens the read-only sheet for an imported commitment (D-35-14). Never
  /// `CommitmentFormSheet` — that stays reachable only for hand-entered rows
  /// via `_openAddSheet`. The sole interactive element besides dismissal is
  /// "Manage calendars", routing to the Calendars settings screen rather
  /// than into an edit form this row must not offer.
  void _openReadOnlySheet(BuildContext context, CommitmentBlock block) {
    showAdaptiveFormModal(
      context: context,
      builder: (_) => _ImportedCommitmentSheet(
        name: block.name,
        timeRange: _commitmentCardSubtitle(block),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CommitmentBlock block,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete commitment?'),
        content: Text(block.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep commitment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete commitment'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CommitmentsNotifier>().deleteBlock(block.id);
    }
  }

  String _formatDays(List<int> days) {
    final sorted = List<int>.from(days)..sort();
    if (sorted.length == 7) return 'Daily';
    if (sorted.length == 5 &&
        sorted.contains(1) &&
        sorted.contains(2) &&
        sorted.contains(3) &&
        sorted.contains(4) &&
        sorted.contains(5)) {
      return 'Mon–Fri';
    }
    const abbr = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return sorted.map((d) => abbr[d]).join(', ');
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final isPm = hour >= 12;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = isPm ? 'pm' : 'am';
    if (minute == 0) {
      return '$displayHour$period';
    }
    return '$displayHour:${minute.toString().padLeft(2, '0')}$period';
  }

  static const _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _commitmentCardSubtitle(CommitmentBlock block) {
    final when = block.date != null
        ? '${_monthAbbr[block.date!.month]} ${block.date!.day}'
        : _formatDays(block.daysOfWeek);
    return '$when · ${_formatTime(block.startMinutes)}–${_formatTime(block.endMinutes)}';
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return Colors.blueGrey;
    return Color(0xFF000000 | value);
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No commitments yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your regular jobs, classes, or appointments',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/calendars'),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Import from your calendar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commitments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Calendar settings',
            onPressed: () => context.push('/settings/calendars'),
          ),
        ],
      ),
      body: Consumer<CommitmentsNotifier>(
        builder: (ctx, notifier, _) {
          if (notifier.blocks.isEmpty) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _emptyState(),
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                itemCount: notifier.blocks.length,
                itemBuilder: (ctx, i) {
                  final block = notifier.blocks[i];
                  return _CommitmentRow(
                    block: block,
                    colorSwatch: _parseColor(block.color),
                    subtitle: _commitmentCardSubtitle(block),
                    onEdit: () => _openAddSheet(context, block),
                    onDelete: () => _confirmDelete(context, block),
                    onTapImported: () => _openReadOnlySheet(context, block),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add commitment'),
      ),
    );
  }
}

/// One row in the commitments list. On desktop the edit + delete icons fade in
/// on hover (opacity 0 -> 1, 120ms easeOut). On mobile the always-visible
/// delete IconButton is preserved (per PATTERNS.md cross-cutting landmine —
/// mobile users would otherwise lose delete access since pointer-only onHover
/// never fires on touch).
class _CommitmentRow extends StatefulWidget {
  const _CommitmentRow({
    required this.block,
    required this.colorSwatch,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    required this.onTapImported,
  });

  final CommitmentBlock block;
  final Color colorSwatch;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Tapped instead of [onEdit] when [block.isFromCalendar] is true — opens
  /// the read-only sheet rather than `CommitmentFormSheet` (D-35-14).
  final VoidCallback onTapImported;

  @override
  State<_CommitmentRow> createState() => _CommitmentRowState();
}

class _CommitmentRowState extends State<_CommitmentRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobileTouch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isImported = widget.block.isFromCalendar;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: isImported ? widget.onTapImported : widget.onEdit,
        onHover: (hovered) => setState(() => _hovered = hovered),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.colorSwatch,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Imported-source marker (D-35-11/D-35-14, UI-SPEC §3). Carries
              // meaning with no visible text, so a screen reader gets
              // nothing without the Semantics label.
              if (isImported) ...[
                Semantics(
                  label: 'Imported from your calendar',
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.block.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // An imported row offers no edit or delete affordance at all —
              // not even a disabled one. Editing belongs in the calendar
              // app, and a delete would be silently undone by the next
              // upsert-by-external-id sync (D-35-14). Nothing replaces the
              // trailing slot; leaving it empty keeps the row honest about
              // what's possible.
              if (!isImported)
                if (isMobileTouch)
                  // Mobile keeps the always-visible delete IconButton so
                  // delete access is never gated behind a hover that
                  // mobile pointer events can't trigger (cross-cutting
                  // landmine resolution).
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete commitment',
                    onPressed: widget.onDelete,
                  )
                else
                  // Desktop reveals edit + delete on hover.
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit commitment',
                          onPressed: _hovered ? widget.onEdit : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete commitment',
                          onPressed: _hovered ? widget.onDelete : null,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only sheet for an imported commitment (D-35-14, UI-SPEC §3
/// Copywriting Contract). No edit affordance anywhere in this sheet — the
/// only interactive element besides dismissal is "Manage calendars", which
/// routes to the Calendars settings screen rather than back into
/// `CommitmentFormSheet`.
class _ImportedCommitmentSheet extends StatelessWidget {
  const _ImportedCommitmentSheet({required this.name, required this.timeRange});

  final String name;
  final String timeRange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(timeRange, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(
            'This commitment comes from your calendar. To change it, edit '
            'the event in your calendar app — the update appears here after '
            'the next sync.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.pop();
                context.push('/settings/calendars');
              },
              child: const Text('Manage calendars'),
            ),
          ),
        ],
      ),
    );
  }
}
