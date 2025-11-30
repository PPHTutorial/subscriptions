import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../../subscriptions/domain/subscription.dart';
import 'ai_insights_service.dart';

/// Service for generating AI-powered insights using Microsoft MPNet or DistilBERT
///
/// Uses Hugging Face Inference API - no server setup required!
/// Just provide an API key (free tier available at https://huggingface.co/settings/tokens)
///
/// Models supported:
/// - Microsoft MPNet: 'sentence-transformers/all-mpnet-base-v2' (best for semantic similarity)
/// - DistilBERT: 'distilbert-base-uncased' (faster, good for classification)
///
/// Features:
/// - Category classification
/// - Semantic similarity (find similar subscriptions)
/// - Text analysis and insights generation
class NerInsightsService {
  final String? _apiKey; // Hugging Face API key (optional for public models)
  final String _modelName; // 'all-mpnet-base-v2' or 'distilbert-base-uncased'
  final bool _useNer;
  final AiInsightsService _fallbackService = AiInsightsService();
  final Duration _timeout = const Duration(seconds: 15);

  static const String _baseUrl = 'https://router.huggingface.co/models';

  NerInsightsService({
    String? apiKey,
    String modelName =
        'sentence-transformers/all-mpnet-base-v2', // MPNet by default
    bool useNer = true,
  })  : _apiKey = apiKey,
        _modelName = modelName,
        _useNer = useNer;

  /// Check if Hugging Face API is available
  Future<bool> isNerAvailable() async {
    if (!_useNer) return false;

    try {
      // Test with a simple classification request
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$_modelName'),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'inputs': 'test',
            }),
          )
          .timeout(const Duration(seconds: 5));

      // 200 = success, 503 = model loading (still available)
      return response.statusCode == 200 || response.statusCode == 503;
    } catch (e) {
      return false;
    }
  }

  /// Generate AI-powered insights using MPNet/DistilBERT
  Future<List<Insight>> generateInsights(
      List<Subscription> subscriptions) async {
    // First, get rule-based insights for calculations
    final ruleBasedInsights =
        await _fallbackService.generateInsights(subscriptions);

    // If NER is not available, return rule-based insights
    if (!_useNer || !await isNerAvailable()) {
      return ruleBasedInsights;
    }

    // Enhance insights with NER-generated analysis
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
        // If NER fails, use original insight
        enhancedInsights.add(insight);
      }
    }

    // Generate additional NER-powered insights
    final nerInsights = await _generateAdditionalInsights(subscriptions);
    enhancedInsights.addAll(nerInsights);

    return enhancedInsights;
  }

  /// Generate natural language insight message using MPNet/DistilBERT
  Future<String?> _generateNaturalLanguageInsight({
    required Insight insight,
    required List<Subscription> subscriptions,
  }) async {
    // For now, return the original message
    // MPNet/DistilBERT are better for classification and similarity, not text generation
    // We can enhance this later with a text generation model if needed
    return null;
  }

  /// Generate additional NER-powered insights
  Future<List<Insight>> _generateAdditionalInsights(
      List<Subscription> subscriptions) async {
    final insights = <Insight>[];

    if (subscriptions.isEmpty) return insights;

    try {
      // Prepare subscription data for NER analysis
      final subscriptionData = subscriptions.map((s) {
        final normalized = switch (s.billingCycle) {
          BillingCycle.weekly => s.cost * 4.3,
          BillingCycle.monthly => s.cost,
          BillingCycle.quarterly => s.cost / 3,
          BillingCycle.halfYearly => s.cost / 6,
          BillingCycle.yearly => s.cost / 12,
          BillingCycle.custom => s.cost,
        };

        return {
          'service_name': s.serviceName,
          'cost': s.cost,
          'normalized_monthly_cost': normalized,
          'currency': s.currencyCode,
          'billing_cycle': s.billingCycle.name,
          'category': s.category.name,
          'renewal_date': s.renewalDate.toIso8601String(),
          'auto_renew': s.autoRenew,
        };
      }).toList();

      // Use Hugging Face Inference API for text classification
      // We'll analyze subscription descriptions and generate insights
      final subscriptionTexts = subscriptions.map((s) {
        return '${s.serviceName} ${s.category.name} ${s.billingCycle.name} subscription';
      }).toList();

      // Get embeddings for similarity analysis
      final embeddings = await _getEmbeddings(subscriptionTexts);

      // Analyze for duplicates and similarities
      final similarPairs = _findSimilarSubscriptions(subscriptions, embeddings);

      // Generate insights based on analysis

      // Insight: Similar/duplicate subscriptions
      if (similarPairs.isNotEmpty) {
        final similarNames =
            similarPairs.map((p) => '${p['sub1']} and ${p['sub2']}').join(', ');
        insights.add(Insight(
          type: InsightType.overlap,
          title: 'Similar Subscriptions Detected',
          message:
              'These subscriptions appear similar: $similarNames. Consider consolidating to save money.',
          severity: InsightSeverity.medium,
          actionable: true,
          subscriptions: [],
        ));
      }

      // Calculate total spending
      final totalMonthly = subscriptionData
          .map((s) => s['normalized_monthly_cost'] as double)
          .fold(0.0, (sum, cost) => sum + cost);

      // Insight: High spending
      if (totalMonthly > 100) {
        insights.add(Insight(
          type: InsightType.budget,
          title: 'High Monthly Spending',
          message:
              'You\'re spending \$${totalMonthly.toStringAsFixed(2)} per month on subscriptions. Review unused services to save money.',
          severity: InsightSeverity.medium,
          actionable: true,
          subscriptions: [],
        ));
      }
    } catch (e) {
      print('NER analysis error: $e');
    }

    return insights;
  }

  /// Get embeddings for text using MPNet/DistilBERT
  Future<List<List<double>>?> _getEmbeddings(List<String> texts) async {
    if (!_useNer) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$_modelName'),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'inputs': texts,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .map(
                  (e) => (e as List).map((v) => (v as num).toDouble()).toList())
              .toList();
        }
      } else if (response.statusCode == 503) {
        // Model is loading, wait a bit and retry
        await Future.delayed(const Duration(seconds: 2));
        return _getEmbeddings(texts);
      }
    } catch (e) {
      print('Embedding generation error: $e');
    }

    return null;
  }

  /// Find similar subscriptions using cosine similarity
  List<Map<String, dynamic>> _findSimilarSubscriptions(
    List<Subscription> subscriptions,
    List<List<double>>? embeddings,
  ) {
    final similarPairs = <Map<String, dynamic>>[];

    if (embeddings == null || embeddings.length != subscriptions.length) {
      return similarPairs;
    }

    // Calculate cosine similarity between all pairs
    for (int i = 0; i < subscriptions.length; i++) {
      for (int j = i + 1; j < subscriptions.length; j++) {
        final similarity = _cosineSimilarity(embeddings[i], embeddings[j]);

        // If similarity > 0.7, they're similar
        if (similarity > 0.7) {
          similarPairs.add({
            'sub1': subscriptions[i].serviceName,
            'sub2': subscriptions[j].serviceName,
            'similarity': similarity,
          });
        }
      }
    }

    return similarPairs;
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Classify text category using DistilBERT for text classification
  /// Uses a zero-shot classification model
  Future<String?> classifyCategory(String text, String? serviceName) async {
    if (!_useNer) return null;

    // Use zero-shot classification model
    const classificationModel = 'facebook/bart-large-mnli';
    final categories = [
      'streaming',
      'music',
      'productivity',
      'cloud storage',
      'software development',
      'design',
      'communication',
      'security',
      'finance',
      'news',
      'education',
      'health',
      'gaming',
      'shopping',
      'travel',
      'food',
      'social media',
      'telecom',
      'mobile money',
      'business',
      'marketing',
      'utilities',
      'other',
    ];

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$classificationModel'),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'inputs': '$serviceName $text',
              'parameters': {
                'candidate_labels': categories,
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('labels')) {
          final labels = data['labels'] as List;
          final scores = data['scores'] as List;
          if (labels.isNotEmpty && scores.isNotEmpty) {
            // Return the highest scoring category
            final maxScore =
                scores.reduce((a, b) => (a as num) > (b as num) ? a : b);
            final topIndex = scores.indexOf(maxScore);
            return labels[topIndex] as String?;
          }
        }
      } else if (response.statusCode == 503) {
        // Model loading, wait and retry
        await Future.delayed(const Duration(seconds: 2));
        return classifyCategory(text, serviceName);
      }
    } catch (e) {
      print('Category classification error: $e');
    }

    return null;
  }
}
