import 'package:flutter/material.dart';

/// A full-page card presenting a single reflection question with tappable
/// suggestion chips and an "Other..." text field toggle.
///
/// On chip tap or field submit, [onAnswered] is called with the selected/typed
/// answer text. The card itself does not advance the PageView — the parent
/// [ReflectionSection] handles navigation after [onAnswered] fires.
class ReflectionQuestionCard extends StatefulWidget {
  const ReflectionQuestionCard({
    super.key,
    required this.question,
    required this.suggestedAnswers,
    required this.onAnswered,
  });

  final String question;
  final List<String> suggestedAnswers;
  final ValueChanged<String> onAnswered;

  @override
  State<ReflectionQuestionCard> createState() => _ReflectionQuestionCardState();
}

class _ReflectionQuestionCardState extends State<ReflectionQuestionCard> {
  bool _showTextField = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitOther() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAnswered(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.question, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),

            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.suggestedAnswers
                  .map(
                    (answer) => ActionChip(
                      label: Text(answer),
                      onPressed: () => widget.onAnswered(answer),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            // "Other..." toggle
            if (!_showTextField)
              TextButton(
                onPressed: () => setState(() => _showTextField = true),
                child: const Text('Other...'),
              )
            else ...[
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Type your answer',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submitOther(),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submitOther,
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
