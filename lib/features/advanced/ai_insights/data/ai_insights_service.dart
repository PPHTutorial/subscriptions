import '../../../subscriptions/domain/subscription.dart';
import '../../../../core/config/app_config.dart';

/// Service for generating AI-powered insights about subscriptions
class AiInsightsService {
  /// Analyze subscriptions and generate insights
  Future<List<Insight>> generateInsights(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    // Waste prediction
    final wasteInsight = _predictWaste(subscriptions);
    if (wasteInsight != null) {
      insights.add(wasteInsight);
    }

    // Overlapping services detection
    final overlapInsights = _detectOverlappingServices(subscriptions);
    insights.addAll(overlapInsights);

    // Budget insights
    final budgetInsight = _analyzeBudget(subscriptions);
    if (budgetInsight != null) {
      insights.add(budgetInsight);
    }

    // Alternative suggestions
    final alternativeInsights = _suggestAlternatives(subscriptions);
    insights.addAll(alternativeInsights);

    // Usage recommendations
    final usageInsights = _recommendUsage(subscriptions);
    insights.addAll(usageInsights);

    return insights;
  }

  /// Predict subscription waste (unused or duplicate services)
  Insight? _predictWaste(List<Subscription> subscriptions) {
    // Calculate monthly spending
    double monthlySpend = 0;
    for (final sub in subscriptions) {
      final normalized = switch (sub.billingCycle) {
        BillingCycle.weekly => sub.cost * 4.3,
        BillingCycle.monthly => sub.cost,
        BillingCycle.quarterly => sub.cost / 3,
        BillingCycle.yearly => sub.cost / 12,
        BillingCycle.custom => sub.cost,
      };
      monthlySpend += normalized;
    }

    // Find inactive subscriptions (past due for 90+ days)
    final inactive = subscriptions.where((s) {
      if (!s.isPastDue) return false;
      final daysSinceRenewal = DateTime.now().difference(s.renewalDate).inDays;
      return daysSinceRenewal > 90;
    }).toList();

    if (inactive.isNotEmpty) {
      final totalWaste = inactive.fold<double>(
        0,
        (sum, s) =>
            sum +
            (switch (s.billingCycle) {
              BillingCycle.weekly => s.cost * 4.3,
              BillingCycle.monthly => s.cost,
              BillingCycle.quarterly => s.cost / 3,
              BillingCycle.yearly => s.cost / 12,
              BillingCycle.custom => s.cost,
            }),
      );

      return Insight(
        type: InsightType.waste,
        title: 'Potential Waste Detected',
        message:
            'You have ${inactive.length} subscription(s) that may be inactive. '
            'This could save you ${_formatCurrency(totalWaste)} per month.',
        severity: InsightSeverity.high,
        actionable: true,
        actionLabel: 'Review inactive subscriptions',
        subscriptions: inactive,
      );
    }

    return null;
  }

  /// Detect overlapping services (e.g., multiple streaming services)
  List<Insight> _detectOverlappingServices(List<Subscription> subscriptions) {
    final insights = <Insight>[];

    // Group by category
    final byCategory = <SubscriptionCategory, List<Subscription>>{};
    for (final sub in subscriptions) {
      byCategory.putIfAbsent(sub.category, () => []).add(sub);
    }

    // Check for overlaps in entertainment (streaming services)
    final entertainment = byCategory[SubscriptionCategory.entertainment] ?? [];
    if (entertainment.length > 2) {
      final monthlyCost = entertainment.fold<double>(
        0,
        (sum, s) =>
            sum +
            (switch (s.billingCycle) {
              BillingCycle.weekly => s.cost * 4.3,
              BillingCycle.monthly => s.cost,
              BillingCycle.quarterly => s.cost / 3,
              BillingCycle.yearly => s.cost / 12,
              BillingCycle.custom => s.cost,
            }),
      );

      insights.add(Insight(
        type: InsightType.overlap,
        title: 'Multiple Streaming Services',
        message: 'You have ${entertainment.length} streaming subscriptions. '
            'Consider consolidating to save ${_formatCurrency(monthlyCost * 0.3)} per month.',
        severity: InsightSeverity.medium,
        actionable: true,
        actionLabel: 'Review streaming services',
        subscriptions: entertainment,
      ));
    }

    // Check for productivity tool overlaps
    final productivity = byCategory[SubscriptionCategory.productivity] ?? [];
    if (productivity.length > 3) {
      insights.add(Insight(
        type: InsightType.overlap,
        title: 'Multiple Productivity Tools',
        message: 'You have ${productivity.length} productivity subscriptions. '
            'Some may have overlapping features.',
        severity: InsightSeverity.low,
        actionable: true,
        actionLabel: 'Review productivity tools',
        subscriptions: productivity,
      ));
    }

    return insights;
  }

  /// Analyze budget and spending patterns
  Insight? _analyzeBudget(List<Subscription> subscriptions) {
    double monthlySpend = 0;
    for (final sub in subscriptions) {
      final normalized = switch (sub.billingCycle) {
        BillingCycle.weekly => sub.cost * 4.3,
        BillingCycle.monthly => sub.cost,
        BillingCycle.quarterly => sub.cost / 3,
        BillingCycle.yearly => sub.cost / 12,
        BillingCycle.custom => sub.cost,
      };
      monthlySpend += normalized;
    }

    final yearlySpend = monthlySpend * 12;

    if (monthlySpend > 100) {
      return Insight(
        type: InsightType.budget,
        title: 'High Monthly Spending',
        message:
            'You\'re spending ${_formatCurrency(monthlySpend)} per month on subscriptions. '
            'That\'s ${_formatCurrency(yearlySpend)} per year. Consider reviewing your subscriptions.',
        severity: InsightSeverity.medium,
        actionable: true,
        actionLabel: 'View budget breakdown',
        subscriptions: [],
      );
    }

    return null;
  }

  /// Suggest cheaper alternatives
  List<Insight> _suggestAlternatives(List<Subscription> subscriptions) {
    final insights = <Insight>[];

    // Known alternatives mapping
    final alternatives = {
      'Netflix': ['Disney+', 'Hulu', 'Amazon Prime'],
      'Spotify': ['Apple Music', 'YouTube Music'],
      'Adobe Creative Cloud': ['Affinity Suite', 'Canva Pro'],
      'Microsoft Office 365': ['Google Workspace', 'LibreOffice'],
    };

    for (final sub in subscriptions) {
      final serviceName = sub.serviceName.toLowerCase();
      final alternativeServices = alternatives.entries.firstWhere(
        (entry) => serviceName.contains(entry.key.toLowerCase()),
        orElse: () => const MapEntry('', []),
      );

      if (alternativeServices.value.isNotEmpty) {
        insights.add(Insight(
          type: InsightType.alternative,
          title: 'Cheaper Alternative Available',
          message:
              'Consider ${alternativeServices.value.first} as an alternative to ${sub.serviceName}. '
              'Could save up to ${_formatCurrency(sub.cost * 0.3)} per month.',
          severity: InsightSeverity.low,
          actionable: true,
          actionLabel: 'View alternatives',
          subscriptions: [sub],
        ));
      }
    }

    return insights;
  }

  /// Recommend usage optimization
  List<Insight> _recommendUsage(List<Subscription> subscriptions) {
    final insights = <Insight>[];

    // Find expensive subscriptions
    final expensive = subscriptions.where((s) {
      final normalized = switch (s.billingCycle) {
        BillingCycle.weekly => s.cost * 4.3,
        BillingCycle.monthly => s.cost,
        BillingCycle.quarterly => s.cost / 3,
        BillingCycle.yearly => s.cost / 12,
        BillingCycle.custom => s.cost,
      };
      return normalized > 20;
    }).toList();

    if (expensive.isNotEmpty) {
      insights.add(Insight(
        type: InsightType.usage,
        title: 'Optimize High-Value Subscriptions',
        message:
            'You have ${expensive.length} subscription(s) costing more than ${_formatCurrency(20)}/month. '
            'Make sure you\'re getting value from these services.',
        severity: InsightSeverity.low,
        actionable: true,
        actionLabel: 'Review high-value subscriptions',
        subscriptions: expensive,
      ));
    }

    return insights;
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Generate AI-powered insights using Vercel proxy (optional)
  ///
  /// Can be enhanced to use Vercel proxy for OpenAI/Anthropic integration
  /// For now, uses local logic for insights
  Future<List<Insight>> generateAiInsights(
      List<Subscription> subscriptions) async {
    // Always use local insights for now
    // Can be enhanced to use Vercel proxy for OpenAI/Anthropic integration
    return generateInsights(subscriptions);
  }
}

enum InsightType {
  waste,
  overlap,
  budget,
  alternative,
  usage,
}

enum InsightSeverity {
  low,
  medium,
  high,
}

class Insight {
  Insight({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.actionable = false,
    this.actionLabel,
    this.subscriptions = const [],
  });

  final InsightType type;
  final String title;
  final String message;
  final InsightSeverity severity;
  final bool actionable;
  final String? actionLabel;
  final List<Subscription> subscriptions;
}
