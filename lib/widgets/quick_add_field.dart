import 'package:flutter/material.dart';

/// A sticky, frictionless multi-add text field. Type a name and press Enter to
/// add an item; the field clears and keeps focus so a whole slate goes in with
/// type-Enter-type-Enter. Also accepts a pasted, newline-separated list — each
/// line becomes an item, whether or not the paste ends in a newline.
///
/// Extracted from the Goals screen so onboarding (goals AND restoratives) can
/// reuse the exact same drop-free entry behavior. Persistence is delegated to
/// [onSubmit], which returns how many items actually saved so partial failures
/// can be surfaced without losing the user's input.
class QuickAddField extends StatefulWidget {
  const QuickAddField({
    super.key,
    required this.onSubmit,
    required this.hintText,
    this.helperText,
    this.autofocus = false,
    this.multiAddNoun = 'items',
    this.addTooltip = 'Add',
  });

  /// Persists the given names; returns how many were actually created. Must not
  /// throw — report the honest saved count instead so the unsaved tail can be
  /// restored to the field.
  final Future<int> Function(List<String> names) onSubmit;

  /// Placeholder shown when the field is empty.
  final String hintText;

  /// Optional helper line under the field.
  final String? helperText;

  final bool autofocus;

  /// Plural noun for the "Added N ..." confirmation on a multi-add.
  final String multiAddNoun;

  final String addTooltip;

  @override
  State<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<QuickAddField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // Drop-free entry: completed names are queued and a single worker drains the
  // queue serially. A prior save being in-flight must NEVER cause an already-
  // stripped line to be lost — so we queue instead of guarding-and-bailing.
  // This holds even when items are entered faster than each save.
  final List<String> _queue = [];
  bool _draining = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Queue [names] for saving and ensure the drain worker is running. Blank
  /// names are skipped. Never drops, regardless of in-flight saves.
  void _enqueue(Iterable<String> names) {
    _queue.addAll(names.map((n) => n.trim()).where((n) => n.isNotEmpty));
    _drain();
  }

  /// Serially persist everything in the queue, then keep focus for the next
  /// item. Reentrancy-guarded by [_draining]; anything enqueued mid-drain is
  /// picked up by the loop before it exits, so no entry is ever dropped.
  ///
  /// [_draining] is reset in a `finally` so a save failure can NEVER wedge the
  /// worker permanently (which would silently drop every later item). If a
  /// batch only partially persists, the unsaved tail is put back into the field
  /// and the failure is surfaced — the user never loses what they typed.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    var totalAdded = 0;
    var saveFailed = false;
    try {
      while (_queue.isNotEmpty) {
        final batch = List<String>.from(_queue);
        _queue.clear();
        final added = await widget.onSubmit(batch);
        totalAdded += added;
        if (added < batch.length) {
          // Persistence failed partway — restore the tail that didn't land so
          // the user can retry, and stop draining.
          _restoreToField(batch.sublist(added));
          saveFailed = true;
          break;
        }
      }
    } finally {
      _draining = false;
    }
    if (!mounted) return;
    // Keep the keyboard up and the cursor ready for the next item.
    _focusNode.requestFocus();
    if (saveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check and try again.')),
      );
    } else if (totalAdded > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $totalAdded ${widget.multiAddNoun}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Puts unsaved names back into the field (ahead of any in-progress text) so
  /// a failed write is recoverable — the user just retries.
  void _restoreToField(List<String> names) {
    final existing = _controller.text;
    final restored = existing.isEmpty
        ? names.join('\n')
        : '${names.join('\n')}\n$existing';
    _controller.value = TextEditingValue(
      text: restored,
      selection: TextSelection.collapsed(offset: restored.length),
    );
  }

  /// The field is multi-line so a pasted newline-separated slate survives (a
  /// single-line field silently strips newlines and collapses the paste into
  /// one item).
  ///
  /// Any newline in the incoming value means at least one line is complete, so
  /// we queue EVERY non-empty line and clear the field. This covers all three
  /// entry shapes with one rule:
  ///  - type-then-Enter  → "Run\n"      → adds "Run"
  ///  - paste WITH a trailing newline   → adds every line
  ///  - paste WITHOUT a trailing newline (copying lines from notes — the common
  ///    case) → the final line is committed too, not stranded in the field.
  /// While typing a single item the only newline that ever appears is the
  /// terminal Enter (nothing follows it), so this is identical to committing
  /// per-Enter for that flow — it just also captures a paste's last line.
  void _onChanged(String value) {
    if (!value.contains('\n')) return; // still typing the current line
    // Clear WITHOUT re-triggering onChanged (programmatic edits don't re-fire).
    _controller.clear();
    _enqueue(value.split('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      // Multi-line so pasted newlines survive; grows a little, then scrolls.
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      onChanged: _onChanged,
      // Fallback commit path (e.g. desktop "Done" that doesn't insert a
      // newline): flush whatever is in the field and clear it.
      onSubmitted: (value) {
        _controller.clear();
        _enqueue(value.split('\n'));
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.add),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          tooltip: widget.addTooltip,
          icon: const Icon(Icons.subdirectory_arrow_left),
          onPressed: () {
            final text = _controller.text;
            _controller.clear();
            _enqueue(text.split('\n'));
          },
        ),
        helperText: widget.helperText,
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
