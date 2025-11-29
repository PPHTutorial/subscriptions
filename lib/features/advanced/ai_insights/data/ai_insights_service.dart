import '../../../subscriptions/domain/subscription.dart';
import '../../../../core/currency/currency_conversion_service.dart';
import 'insights_dataset.dart';
import 'ollama_insights_service.dart';

/// Service for generating AI-powered insights about subscriptions
class AiInsightsService {
  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  /// Analyze subscriptions and generate insights
  Future<List<Insight>> generateInsights(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    // Waste prediction
    final wasteInsight = await _predictWaste(subscriptions);
    if (wasteInsight != null) {
      insights.add(wasteInsight);
    }

    // Overlapping services detection
    final overlapInsights = await _detectOverlappingServices(subscriptions);
    insights.addAll(overlapInsights);

    // Budget insights
    final budgetInsight = await _analyzeBudget(subscriptions);
    if (budgetInsight != null) {
      insights.add(budgetInsight);
    }

    // Alternative suggestions
    final alternativeInsights = await _suggestAlternatives(subscriptions);
    insights.addAll(alternativeInsights);

    // Usage recommendations
    final usageInsights = await _recommendUsage(subscriptions);
    insights.addAll(usageInsights);

    return insights;
  }

  /// Predict subscription waste (unused or duplicate services)
  Future<Insight?> _predictWaste(List<Subscription> subscriptions) async {
    // Find inactive subscriptions (past due for 90+ days)
    final inactive = subscriptions.where((s) {
      if (!s.isPastDue) return false;
      final daysSinceRenewal = DateTime.now().difference(s.renewalDate).inDays;
      return daysSinceRenewal > 90;
    }).toList();

    if (inactive.isNotEmpty) {
      // Convert all costs to base currency before summing
      double totalWaste = 0;
      String fromCurrency = '';
      for (final sub in inactive) {
        final normalizedMonthly =
            _normalizeToMonthly(sub.cost, sub.billingCycle);
        final convertedCost = await _currencyService.convertToBase(
          amount: normalizedMonthly,
          fromCurrency: sub.currencyCode,
        );
        totalWaste += convertedCost;
        fromCurrency = sub.currencyCode;
      }

      final baseCurrency = await _currencyService.convertToBase(
        amount: totalWaste,
        fromCurrency: fromCurrency,
      );

      return Insight(
        type: InsightType.waste,
        title: 'Potential Waste Detected',
        message:
            'You have ${inactive.length} subscription(s) that may be inactive. '
            'This could save you ${_currencyService.formatCurrency(amount: totalWaste, currencyCode: fromCurrency)} per month.',
        severity: InsightSeverity.high,
        actionable: true,
        actionLabel: 'Review inactive subscriptions',
        subscriptions: inactive,
      );
    }

    return null;
  }

  /// Detect overlapping services using comprehensive dataset
  Future<List<Insight>> _detectOverlappingServices(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    // Check each overlapping group
    final groupMembers = <String, List<Subscription>>{};

    for (final sub in subscriptions) {
      final group = InsightsDataset.getOverlappingGroup(sub.serviceName);
      if (group != null) {
        groupMembers.putIfAbsent(group, () => []).add(sub);
      }
    }

    // Generate insights for each overlapping group
    for (final entry in groupMembers.entries) {
      final groupName = entry.key;
      final members = entry.value;

      if (members.length > 1) {
        // Convert all costs to base currency before summing
        double monthlyCost = 0;
        for (final sub in members) {
          final normalizedMonthly =
              _normalizeToMonthly(sub.cost, sub.billingCycle);
          final convertedCost = await _currencyService.convertToBase(
            amount: normalizedMonthly,
            fromCurrency: sub.currencyCode,
          );
          monthlyCost += convertedCost;
        }

        // Calculate potential savings (assuming keeping only one)
        final savings = monthlyCost * ((members.length - 1) / members.length);
        final baseCurrency = _currencyService.baseCurrency;

        final groupDisplayName = groupName
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');

        insights.add(Insight(
          type: InsightType.overlap,
          title: 'Multiple $groupDisplayName Subscriptions',
          message:
              'You have ${members.length} ${groupDisplayName.toLowerCase()} subscriptions. '
              'Consider consolidating to save ${_formatCurrency(savings)} $baseCurrency per month. '
              'Many services offer similar features.',
          severity: members.length > 3
              ? InsightSeverity.high
              : members.length > 2
                  ? InsightSeverity.medium
                  : InsightSeverity.low,
          actionable: true,
          actionLabel: 'Review ${groupDisplayName.toLowerCase()}',
          subscriptions: members,
        ));
      }
    }

    return insights;
  }

  /// Analyze budget and spending patterns
  Future<Insight?> _analyzeBudget(List<Subscription> subscriptions) async {
    double monthlySpend = 0;

    // Convert all subscriptions to base currency before summing
    for (final sub in subscriptions) {
      // Normalize to monthly first
      final normalizedMonthly = _normalizeToMonthly(sub.cost, sub.billingCycle);

      // Convert to base currency
      final convertedCost = await _currencyService.convertToBase(
        amount: normalizedMonthly,
        fromCurrency: sub.currencyCode,
      );

      monthlySpend += convertedCost;
    }

    final yearlySpend = monthlySpend * 12;
    final baseCurrency = _currencyService.baseCurrency;

    // Threshold in base currency (e.g., $100 USD or equivalent)
    if (monthlySpend > 100) {
      return Insight(
        type: InsightType.budget,
        title: 'High Monthly Spending',
        message:
            'You\'re spending ${_formatCurrency(monthlySpend)} $baseCurrency per month on subscriptions. '
            'That\'s ${_formatCurrency(yearlySpend)} $baseCurrency per year. Consider reviewing your subscriptions.',
        severity: InsightSeverity.medium,
        actionable: true,
        actionLabel: 'View budget breakdown',
        subscriptions: [],
      );
    }

    return null;
  }

  /// Suggest cheaper alternatives using comprehensive dataset
  Future<List<Insight>> _suggestAlternatives(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    for (final sub in subscriptions) {
      final alternatives =
          InsightsDataset.getAlternativesForService(sub.serviceName);

      if (alternatives.isNotEmpty) {
        // Find best alternative (highest savings)
        final bestAlternative = alternatives.reduce(
          (a, b) => a.savings > b.savings ? a : b,
        );

        // Normalize to monthly and convert to base currency
        final normalizedCost = _normalizeToMonthly(sub.cost, sub.billingCycle);
        final convertedCost = await _currencyService.convertToBase(
          amount: normalizedCost,
          fromCurrency: sub.currencyCode,
        );
        final savingsAmount = await _currencyService.convertToBase(
          amount: convertedCost * bestAlternative.savings,
          fromCurrency: sub.currencyCode,
        );
        final baseCurrency = _currencyService.baseCurrency;

        insights.add(Insight(
          type: InsightType.alternative,
          title: 'Alternative Available: ${bestAlternative.name}',
          message:
              'Consider ${bestAlternative.name} as an alternative to ${sub.serviceName}. '
              '${bestAlternative.reason}. '
              'Could save up to ${_formatCurrency(savingsAmount)} $baseCurrency per month.',
          severity: bestAlternative.savings > 0.5
              ? InsightSeverity.medium
              : InsightSeverity.low,
          actionable: true,
          actionLabel: 'View alternatives',
          subscriptions: [sub],
        ));
      }
    }

    return insights;
  }

  /// Recommend usage optimization
  Future<List<Insight>> _recommendUsage(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    // Find expensive subscriptions (convert to base currency first)
    final expensive = <Subscription>[];
    for (final sub in subscriptions) {
      // Normalize to monthly first
      final normalizedMonthly = _normalizeToMonthly(sub.cost, sub.billingCycle);

      // Convert to base currency before comparison
      final convertedCost = await _currencyService.convertToBase(
        amount: normalizedMonthly,
        fromCurrency: sub.currencyCode,
      );

      // Check if expensive (threshold in base currency)
      if (convertedCost > 20) {
        expensive.add(sub);
      }
    }

    if (expensive.isNotEmpty) {
      final baseCurrency = await _currencyService.convertToBase(
        amount: 20,
        fromCurrency: 'USD',
      );
      insights.add(Insight(
        type: InsightType.usage,
        title: 'Optimize High-Value Subscriptions',
        message:
            'You have ${expensive.length} subscription(s) costing more than ${_formatCurrency(baseCurrency)}/month. '
            'Make sure you\'re getting value from these services.',
        severity: InsightSeverity.low,
        actionable: true,
        actionLabel: 'Review high-value subscriptions',
        subscriptions: expensive,
      ));
    }

    return insights;
  }

  /// Normalize cost to monthly
  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.weekly => cost * 4.3,
      BillingCycle.monthly => cost,
      BillingCycle.quarterly => cost / 3,
      BillingCycle.yearly => cost / 12,
      BillingCycle.custom => cost,
    };
  }

  String _formatCurrency(double amount) {
    // Use the currency service to format with proper symbol for base currency
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }

  /// Generate AI-powered insights using Ollama (optional)
  ///
  /// Can be enhanced to use Ollama for natural language generation
  /// Falls back to rule-based insights if Ollama is unavailable
  ///
  /// For production: Ollama server must be deployed to cloud or provided by user
  /// Default behavior: Uses rule-based insights (works offline, no server needed)
  Future<List<Insight>> generateAiInsights(
    List<Subscription> subscriptions, {
    bool enableOllama = false,
    String? ollamaServerUrl,
  }) async {
    // Default: Use rule-based insights (works offline, no server needed)
    // This ensures the app works perfectly for all app store users

    // Optionally enhance with Ollama if enabled and server URL provided
    if (enableOllama && ollamaServerUrl != null) {
      try {
        final ollamaService = OllamaInsightsService(
          baseUrl: ollamaServerUrl,
          useOllama: true,
        );
        if (await ollamaService.isOllamaAvailable()) {
          return await ollamaService.generateInsights(subscriptions);
        }
      } catch (e) {
        // Fall back to rule-based insights
        print('Ollama not available, using rule-based insights: $e');
      }
    }

    // Use rule-based insights (default - works for all users)
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
