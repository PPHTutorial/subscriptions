import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../responsive/responsive_helper.dart';
import 'feedback_service.dart';
import 'rating_service.dart';
import '../../features/subscriptions/application/subscription_controller.dart';
import '../../features/subscriptions/domain/subscription.dart';

class SubscriptionFeedbackDialog extends ConsumerStatefulWidget {
  const SubscriptionFeedbackDialog({super.key});

  @override
  ConsumerState<SubscriptionFeedbackDialog> createState() =>
      _SubscriptionFeedbackDialogState();
}

class _SubscriptionFeedbackDialogState
    extends ConsumerState<SubscriptionFeedbackDialog> {
  final _ratingService = RatingService();
  final _feedbackService = FeedbackService();
  int? _selectedExperience;
  final _commentsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _handleRateApp() async {
    setState(() => _isSubmitting = true);

    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await _ratingService.markAsRated();
      } else {
        // Fallback: Open store page
        await inAppReview.openStoreListing();
        await _ratingService.markAsRated();
      }
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleShareApp() async {
    setState(() => _isSubmitting = true);

    try {
      // Save feedback before sharing if available
      if (_selectedExperience != null) {
        await _feedbackService.saveFeedback(
          experience: _selectedExperience!,
          comments: _commentsController.text.trim().isEmpty
              ? null
              : _commentsController.text.trim(),
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName;
      final packageName = packageInfo.packageName;

      final shareText = '''
Check out $appName - the best way to track and manage your subscriptions! 

Track all your subscriptions, get reminders before renewals, and never miss a payment again.

Download now: https://play.google.com/store/apps/details?id=$packageName
      ''';

      await Share.share(shareText);
      await _ratingService.markAsShared();

      // Close dialog after sharing
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      // Save feedback if experience is selected
      if (_selectedExperience != null) {
        await _feedbackService.saveFeedback(
          experience: _selectedExperience!,
          comments: _commentsController.text.trim().isEmpty
              ? null
              : _commentsController.text.trim(),
        );
      }

      // Record that we've shown the prompt
      await _ratingService.recordPromptShown();
    } catch (e) {
      // Handle error silently - feedback saving is not critical
      print('Error saving feedback: $e');
    } finally {
      setState(() => _isSubmitting = false);

      // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subscriptionsAsync = ref.watch(subscriptionControllerProvider);

    final subscriptions = subscriptionsAsync.maybeWhen(
      data: (subs) => subs,
      orElse: () => <Subscription>[],
    );

    final activeSubscriptions = subscriptions.where((s) => !s.isPastDue).length;
    final trials = subscriptions.where((s) => s.isTrial).length;

    return Dialog(
      insetPadding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How\'s it going?',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          'We\'d love to hear from you!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(24)),
              Text(
                'How has your experience been managing your ${activeSubscriptions > 0 ? '$activeSubscriptions active subscription${activeSubscriptions > 1 ? 's' : ''}' : 'subscriptions'}${trials > 0 ? ' and $trials trial${trials > 1 ? 's' : ''}' : ''}?',
                style: theme.textTheme.bodyLarge,
              ),
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Text(
                'Your experience',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CompactExperienceOption(
                    value: 5,
                    icon: Icons.sentiment_very_satisfied_rounded,
                    color: Colors.green,
                    isSelected: _selectedExperience == 5,
                    onTap: () => setState(() => _selectedExperience = 5),
                  ),
                  _CompactExperienceOption(
                    value: 4,
                    icon: Icons.sentiment_satisfied_rounded,
                    color: Colors.lightGreen,
                    isSelected: _selectedExperience == 4,
                    onTap: () => setState(() => _selectedExperience = 4),
                  ),
                  _CompactExperienceOption(
                    value: 3,
                    icon: Icons.sentiment_neutral_rounded,
                    color: Colors.orange,
                    isSelected: _selectedExperience == 3,
                    onTap: () => setState(() => _selectedExperience = 3),
                  ),
                  _CompactExperienceOption(
                    value: 2,
                    icon: Icons.sentiment_dissatisfied_rounded,
                    color: Colors.deepOrange,
                    isSelected: _selectedExperience == 2,
                    onTap: () => setState(() => _selectedExperience = 2),
                  ),
                  _CompactExperienceOption(
                    value: 1,
                    icon: Icons.sentiment_very_dissatisfied_rounded,
                    color: Colors.red,
                    isSelected: _selectedExperience == 1,
                    onTap: () => setState(() => _selectedExperience = 1),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Text(
                'Any comments or suggestions?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(12)),
              TextField(
                controller: _commentsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(24)),
              FutureBuilder<bool>(
                future: _ratingService.hasCompletedRating(),
                builder: (context, snapshot) {
                  final hasCompleted = snapshot.data ?? false;

                  if (hasCompleted) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Done'),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Text(
                        'If you\'re enjoying the app, we\'d appreciate your support!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _handleRateApp,
                              icon: const Icon(Icons.star_rounded),
                              label: const Text('Rate'),
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(12)),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _handleShareApp,
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(12)),
                      /* SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          child: const Text('Maybe later'),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(8)),
                      TextButton(
                        onPressed: _isSubmitting ? null : _handleDecline,
                        child: Text(
                          'Don\'t ask again',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ), */
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactExperienceOption extends StatelessWidget {
  const _CompactExperienceOption({
    required this.value,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final int value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: _getLabel(value),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? color : colorScheme.onSurface.withOpacity(0.6),
            size: 28,
          ),
        ),
      ),
    );
  }

  String _getLabel(int value) {
    switch (value) {
      case 5:
        return 'Excellent';
      case 4:
        return 'Good';
      case 3:
        return 'Okay';
      case 2:
        return 'Could be better';
      case 1:
        return 'Poor';
      default:
        return '';
    }
  }
}
