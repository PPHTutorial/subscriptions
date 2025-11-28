import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/ai_insights_service.dart';

class AiInsightsScreen extends ConsumerWidget {
  const AiInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionControllerProvider);
    final insightsService = AiInsightsService();

    return Scaffold(
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
            future: insightsService.generateInsights(subscriptions),
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
                  ...insights.map((insight) => _InsightCard(insight: insight)),
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
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
                onPressed: () {
                  // TODO: Navigate to relevant screen
                },
                child: Text(insight.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
