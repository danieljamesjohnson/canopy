import 'package:flutter/material.dart';

/// Dismissable banner shown on HomeScreen when the user is within the
/// quarterly review window (7 days before the 90-day mark, up to 30 days after).
///
/// Dismiss state is in-memory only — reappears on app restart until the review
/// window closes or the user completes a review.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({
    super.key,
    required this.onStart,
    required this.onDismiss,
  });

  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('review_banner'),
      onDismissed: (_) => onDismiss(),
      direction: DismissDirection.horizontal,
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Your quarterly review is ready',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onDismiss,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text(
                        "See how far you've come. Takes about 5 minutes.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: ElevatedButton(
                  onPressed: onStart,
                  child: const Text('Start review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
