import 'package:flutter/material.dart';

import '../../../data/models/goal.dart';
import '../widgets/reflection_question_card.dart';

/// Section 2 of the quarterly review: 5 reflection questions presented
/// one per page via a nested [PageView].
///
/// Questions auto-advance on answer tap. After the last answer,
/// [onComplete] is called with all 5 recorded answers.
class ReflectionSection extends StatefulWidget {
  const ReflectionSection({
    super.key,
    required this.goals,
    required this.goalChunkTotals,
    required this.completionRates,
    required this.onComplete,
  });

  final List<Goal> goals;

  /// Completed chunk counts per goalId (for data-driven suggestions).
  final Map<String, int> goalChunkTotals;

  /// Completion rates per goalId (for archive/energy questions).
  final Map<String, double> completionRates;

  /// Called with all 5 answers once the last question is answered.
  final ValueChanged<List<String>> onComplete;

  @override
  State<ReflectionSection> createState() => _ReflectionSectionState();
}

class _ReflectionSectionState extends State<ReflectionSection> {
  final _controller = PageController();
  final _answers = <String>[];
  int _currentQuestion = 0;

  static const int _totalQuestions = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnswered(String answer) {
    _answers.add(answer);
    if (_currentQuestion < _totalQuestions - 1) {
      setState(() => _currentQuestion++);
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete(List.unmodifiable(_answers));
    }
  }

  List<String> _buildSuggestions(int questionIndex) {
    final goals = widget.goals;
    final totals = widget.goalChunkTotals;
    final rates = widget.completionRates;

    switch (questionIndex) {
      case 0:
        // Top 3 by completion rate
        final sorted = goals.toList()
          ..sort((a, b) =>
              (rates[b.id] ?? 0.0).compareTo(rates[a.id] ?? 0.0));
        return sorted.take(3).map((g) => g.name).toList();

      case 1:
        // Top 3 by absolute chunks completed
        final sorted = goals.toList()
          ..sort((a, b) =>
              (totals[b.id] ?? 0).compareTo(totals[a.id] ?? 0));
        return sorted.take(3).map((g) => g.name).toList();

      case 2:
        // Bottom 3 by completion rate (only goals with >=1 chunk)
        final withData = goals.where((g) => (totals[g.id] ?? 0) >= 1).toList()
          ..sort((a, b) =>
              (rates[a.id] ?? 0.0).compareTo(rates[b.id] ?? 0.0));
        return withData.take(3).map((g) => g.name).toList();

      case 3:
        // All active goals
        return goals.map((g) => g.name).toList();

      case 4:
        // Goals with <=20% completion rate + "Nothing — keep them all"
        final underperforming = goals
            .where((g) => (rates[g.id] ?? 0.0) <= 0.20)
            .map((g) => g.name)
            .toList();
        return [
          ...underperforming,
          'Nothing \u2014 keep them all',
        ];

      default:
        return [];
    }
  }

  static const List<String> _questions = [
    'Which goal gave you the most energy this quarter?',
    'What are you most proud of from the last 90 days?',
    'Which goal felt harder to show up for?',
    'Is there a goal you want to give more focus next quarter?',
    'Anything you want to let go of for now?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Section heading
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            'A few questions',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // Step dots
        _StepDots(
          currentPage: _currentQuestion,
          totalPages: _totalQuestions,
        ),

        // Question PageView
        Expanded(
          child: PageView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalQuestions,
            itemBuilder: (context, index) => ReflectionQuestionCard(
              key: ValueKey(index),
              question: _questions[index],
              suggestedAnswers: _buildSuggestions(index),
              onAnswered: _onAnswered,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step dots — matches OnboardingScreen._StepDots pattern
// ---------------------------------------------------------------------------

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (i) {
          final isActive = i == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color:
                  isActive ? colorScheme.primary : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
