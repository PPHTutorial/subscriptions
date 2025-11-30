import 'package:ollama/ollama.dart';
import '../../../subscriptions/domain/subscription.dart';
import 'ai_insights_service.dart';

/// Service for generating AI-powered insights using Ollama
/// Uses the dart-ollama package for clean API integration
///
/// The dart-ollama package simplifies connection - no manual HTTP handling needed.
/// You can connect to:
/// - Local Ollama server: Ollama() (defaults to localhost:11434)
/// - Remote Ollama server: Ollama(baseUrl: Uri.parse('http://your-server:11434'))
/// - Cloud-hosted Ollama: Ollama(baseUrl: Uri.parse('https://your-cloud-instance'))
///
/// Note: An Ollama server must be running somewhere (local machine, remote server, or cloud)
class OllamaInsightsService {
  final Ollama _ollama;
  final String _modelName; // e.g., 'llama3.2', 'phi3', 'mistral', 'qwen2.5'
  final bool _useOllama;
  final AiInsightsService _fallbackService = AiInsightsService();

  OllamaInsightsService({
    String? baseUrl, // Optional: defaults to http://localhost:11434
    String modelName = 'llama3.2', // Small, fast model
    bool useOllama = true,
  })  : _ollama = baseUrl != null
            ? Ollama(baseUrl: Uri.parse(baseUrl))
            : Ollama(), // Uses default localhost:11434
        _modelName = modelName,
        _useOllama = useOllama;

  /// Check if Ollama server is available
  Future<bool> isOllamaAvailable() async {
    if (!_useOllama) return false;

    try {
      // Try a simple chat request to check if server is available
      final testResponse = _ollama.chat(
        [
          ChatMessage(role: 'user', content: 'test'),
        ],
        model: _modelName,
      );

      // Try to read first chunk with timeout
      await testResponse.timeout(const Duration(seconds: 2)).first;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate AI-powered insights using Ollama
  Future<List<Insight>> generateInsights(
      List<Subscription> subscriptions) async {
    // First, get rule-based insights for calculations
    final ruleBasedInsights =
        await _fallbackService.generateInsights(subscriptions);

    // If Ollama is not available, return rule-based insights
    if (!_useOllama || !await isOllamaAvailable()) {
      return ruleBasedInsights;
    }

    // Enhance insights with Ollama-generated natural language
    final enhancedInsights = <Insight>[];

    for (final insight in ruleBasedInsights) {
      try {
        final enhancedMessage = await _generateNaturalLanguageInsight(
          insight: insight,
          subscriptions: subscriptions,
        );

        enhancedInsights.add(Insight(
          type: insight.type,
          title: insight.title,
          message: enhancedMessage ?? insight.message,
          severity: insight.severity,
          actionable: insight.actionable,
          actionLabel: insight.actionLabel,
          subscriptions: insight.subscriptions,
        ));
      } catch (e) {
        // If Ollama fails, use original insight
        enhancedInsights.add(insight);
      }
    }

    // Generate additional AI-powered insights
    final aiInsights = await _generateAdditionalInsights(subscriptions);
    enhancedInsights.addAll(aiInsights);

    return enhancedInsights;
  }

  /// Generate natural language insight message using Ollama
  Future<String?> _generateNaturalLanguageInsight({
    required Insight insight,
    required List<Subscription> subscriptions,
  }) async {
    final prompt = _buildInsightPrompt(insight, subscriptions);

    try {
      // Use dart-ollama package's chat API
      final response = _ollama.chat(
        [
          ChatMessage(
            role: 'system',
            content:
                'You are a helpful financial advisor specializing in subscription management. Provide concise, actionable advice.',
          ),
          ChatMessage(
            role: 'user',
            content: prompt,
          ),
        ],
        model: _modelName,
      );

      // Collect the streamed response
      final buffer = StringBuffer();
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        buffer.write(chunk.message?.content ?? '');
      }

      final generatedText = buffer.toString().trim();
      return generatedText.isNotEmpty ? generatedText : null;
    } catch (e) {
      print('Ollama error: $e');
    }

    return null;
  }

  /// Build prompt for insight generation
  String _buildInsightPrompt(
      Insight insight, List<Subscription> subscriptions) {
    final subscriptionSummary = _formatSubscriptionsForPrompt(
      insight.subscriptions.isNotEmpty ? insight.subscriptions : subscriptions,
    );

    return '''
You are a financial advisor helping users manage their subscriptions.

Current insight type: ${insight.type.name}
Severity: ${insight.severity.name}
Title: ${insight.title}
Current message: ${insight.message}

Relevant subscriptions:
$subscriptionSummary

Generate a helpful, concise, and personalized insight message (max 2 sentences) that:
1. Explains the issue clearly
2. Provides actionable advice
3. Uses a friendly, conversational tone
4. Mentions specific subscription names and amounts when relevant

Only return the insight message, nothing else.
''';
  }

  /// Generate additional AI-powered insights beyond rule-based ones
  Future<List<Insight>> _generateAdditionalInsights(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    if (subscriptions.isEmpty) return insights;

    final prompt = _buildAnalysisPrompt(subscriptions);

    try {
      // Use dart-ollama package's chat API
      final response = _ollama.chat(
        [
          ChatMessage(
            role: 'system',
            content:
                'You are a financial analyst. Analyze subscription data and provide insights in the specified format.',
          ),
          ChatMessage(
            role: 'user',
            content: prompt,
          ),
        ],
        model: _modelName,
      );

      // Collect the streamed response
      final buffer = StringBuffer();
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        buffer.write(chunk.message?.content ?? '');
      }

      final generatedText = buffer.toString().trim();
      if (generatedText.isNotEmpty) {
        // Parse AI-generated insights (simple format)
        final parsedInsights = _parseAiInsights(generatedText, subscriptions);
        insights.addAll(parsedInsights);
      }
    } catch (e) {
      print('Ollama analysis error: $e');
    }

    return insights;
  }

  /// Build prompt for comprehensive subscription analysis
  String _buildAnalysisPrompt(List<Subscription> subscriptions) {
    final subscriptionData = _formatSubscriptionsForPrompt(subscriptions);

    // Calculate key metrics
    double monthlySpend = 0;
    final byCategory = <SubscriptionCategory, int>{};
    for (final sub in subscriptions) {
      final normalized = switch (sub.billingCycle) {
        BillingCycle.weekly => sub.cost * 4.3,
        BillingCycle.monthly => sub.cost,
        BillingCycle.quarterly => sub.cost / 3,
        BillingCycle.yearly => sub.cost / 12,
        BillingCycle.custom => sub.cost,
        // TODO: Handle this case.
        BillingCycle.halfYearly => sub.cost / 6,
      };
      monthlySpend += normalized;
      byCategory[sub.category] = (byCategory[sub.category] ?? 0) + 1;
    }

    return '''
Analyze these subscriptions and provide 1-2 additional insights:

Subscriptions:
$subscriptionData

Monthly spending: \$${monthlySpend.toStringAsFixed(2)}
Categories: ${byCategory.entries.map((e) => '${e.key.name}: ${e.value}').join(', ')}

Provide insights in this format (one per line):
INSIGHT_TYPE|SEVERITY|TITLE|MESSAGE

Where:
- INSIGHT_TYPE: waste, overlap, budget, alternative, usage, or custom
- SEVERITY: low, medium, or high
- TITLE: Short title (max 5 words)
- MESSAGE: Insight message (max 2 sentences)

Focus on:
1. Hidden costs or unexpected spending patterns
2. Opportunities to save money
3. Usage optimization suggestions
4. Subscription consolidation opportunities

Only return insights in the specified format, nothing else.
''';
  }

  /// Format subscriptions for prompt
  String _formatSubscriptionsForPrompt(List<Subscription> subscriptions) {
    if (subscriptions.isEmpty) return 'No subscriptions';

    final buffer = StringBuffer();
    for (final sub in subscriptions) {
      final monthlyCost = switch (sub.billingCycle) {
        BillingCycle.weekly => sub.cost * 4.3,
        BillingCycle.monthly => sub.cost,
        BillingCycle.quarterly => sub.cost / 3,
        BillingCycle.halfYearly => sub.cost / 6,
        BillingCycle.yearly => sub.cost / 12,
        BillingCycle.custom => sub.cost,
      };

      buffer.writeln(
        '- ${sub.serviceName}: \$${monthlyCost.toStringAsFixed(2)}/month '
        '(${sub.billingCycle.name}, ${sub.category.name})',
      );
    }

    return buffer.toString();
  }

  /// Parse AI-generated insights from text
  List<Insight> _parseAiInsights(
      String text, List<Subscription> subscriptions) {
    final insights = <Insight>[];
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    for (final line in lines) {
      if (!line.contains('|')) continue;

      try {
        final parts = line.split('|');
        if (parts.length < 4) continue;

        final typeStr = parts[0].trim().toLowerCase();
        final severityStr = parts[1].trim().toLowerCase();
        final title = parts[2].trim();
        final message = parts[3].trim();

        // Map type
        InsightType? type;
        try {
          type = InsightType.values.firstWhere(
            (t) => t.name.toLowerCase() == typeStr,
          );
        } catch (e) {
          type = InsightType.usage; // Default
        }

        // Map severity
        InsightSeverity? severity;
        try {
          severity = InsightSeverity.values.firstWhere(
            (s) => s.name.toLowerCase() == severityStr,
          );
        } catch (e) {
          severity = InsightSeverity.low; // Default
        }

        insights.add(Insight(
          type: type,
          title: title,
          message: message,
          severity: severity,
          actionable: true,
          subscriptions: [],
        ));
      } catch (e) {
        // Skip invalid lines
        continue;
      }
    }

    return insights;
  }
}
