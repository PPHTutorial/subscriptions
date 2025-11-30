import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/ads/native_ad_widget.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../../../subscriptions/domain/subscription.dart';
import '../data/ai_insights_service.dart';
import 'insight_detail_screen.dart';

class AiInsightsScreen extends ConsumerWidget {
  const AiInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionControllerProvider);
    final insightsService = AiInsightsService();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('AI Insights'),
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(32)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.5),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    Text(
                      'No subscriptions yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(8)),
                    Text(
                      'Add some subscriptions to get AI-powered insights',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return FutureBuilder<List<Insight>>(
            future: insightsService.generateAiInsights(subscriptions),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final insights = snapshot.data ?? [];

              if (insights.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(32)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(16)),
                        Text(
                          'All good!',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(8)),
                        Text(
                          'No issues detected with your subscriptions',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
                children: [
                  Text(
                    'Insights',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(16)),
                  ...insights.asMap().entries.map((entry) {
                    final index = entry.key;
                    final insight = entry.value;
                    return Column(
                      children: [
                        _InsightCard(
                          insight: insight,
                          subscriptions: subscriptions,
                        ),
                        // Add native ad after every 3 insights
                        if ((index + 1) % 3 == 0 &&
                            index < insights.length - 1) ...[
                          SizedBox(height: ResponsiveHelper.spacing(12)),
                          const NativeAdWidget(),
                          SizedBox(height: ResponsiveHelper.spacing(12)),
                        ],
                      ],
                    );
                  }),
                  SizedBox(height: ResponsiveHelper.spacing(20)),
                  const BannerAdWidget(),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _InsightCard extends ConsumerWidget {
  const _InsightCard({
    required this.insight,
    required this.subscriptions,
  });

  final Insight insight;
  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color? color;
    IconData icon;

    switch (insight.severity) {
      case InsightSeverity.high:
        color = Theme.of(context).colorScheme.tertiary;
        icon = Icons.warning_rounded;
        break;
      case InsightSeverity.medium:
        color = Theme.of(context).colorScheme.primary;
        icon = Icons.info_rounded;
        break;
      case InsightSeverity.low:
        color = Theme.of(context).colorScheme.secondary;
        icon = Icons.lightbulb_rounded;
        break;
    }

    return Card(
color: Theme.of(context).colorScheme.surfaceContainer,
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: ResponsiveHelper.spacing(8)),
                Expanded(
                  child: Text(
                    insight.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Text(
              insight.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (insight.actionable && insight.actionLabel != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(12)),
              OutlinedButton(
                onPressed: () => _handleAction(context, ref),
                child: Text(insight.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref) {
    // Navigate to detailed insight screen for all actionable insights
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InsightDetailScreen(
          insight: insight,
          allSubscriptions: subscriptions,
        ),
      ),
    );
  }
}
