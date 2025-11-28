import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service for making requests through Vercel proxy to hide API keys
class VercelProxyService {
  /// Make a request to the Vercel proxy server
  ///
  /// The proxy server handles:
  /// - Email API calls (Gmail/Outlook)
  /// - AI API calls (OpenAI/Anthropic)
  /// - Any other server-side operations
  static Future<Map<String, dynamic>> request({
    required String endpoint,
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (!AppConfig.isVercelProxyConfigured) {
      throw Exception('Vercel proxy URL not configured');
    }

    final url = Uri.parse('${AppConfig.vercelProxyUrl}/$endpoint');

    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: requestHeaders);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: requestHeaders);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Proxy request failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Request email scanning through proxy
  static Future<Map<String, dynamic>> scanEmails({
    required String provider, // 'gmail' or 'outlook'
    required String accessToken,
    int maxResults = 50,
    DateTime? since,
  }) async {
    return await request(
      endpoint: 'email/scan',
      method: 'POST',
      body: {
        'provider': provider,
        'accessToken': accessToken,
        'maxResults': maxResults,
        'since': since?.toIso8601String(),
      },
    );
  }

  /// Request AI insights through proxy
  static Future<Map<String, dynamic>> generateAiInsights({
    required List<Map<String, dynamic>> subscriptions,
  }) async {
    return await request(
      endpoint: 'ai/insights',
      method: 'POST',
      body: {
        'subscriptions': subscriptions,
      },
    );
  }

  /// Request OAuth token exchange through proxy
  static Future<Map<String, dynamic>> exchangeOAuthToken({
    required String provider,
    required String code,
    String? redirectUri,
  }) async {
    return await request(
      endpoint: 'auth/oauth',
      method: 'POST',
      body: {
        'provider': provider,
        'code': code,
        'redirectUri': redirectUri,
      },
    );
  }
}
