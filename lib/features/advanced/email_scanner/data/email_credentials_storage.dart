import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../domain/email_provider.dart';

/// Service for storing and retrieving email credentials
class EmailCredentialsStorage {
  static const String _credentialsKey = 'email_credentials';

  /// Save credentials for a provider
  static Future<void> saveCredentials({
    required EmailProvider provider,
    required String email,
    required String password,
    String? customImapServer,
    int? customImapPort,
    bool? useSsl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final credentials = {
      'provider': provider.name,
      'email': email,
      'password': password,
      'customImapServer': customImapServer,
      'customImapPort': customImapPort,
      'useSsl': useSsl,
    };
    await prefs.setString(
        '${_credentialsKey}_${provider.name}', jsonEncode(credentials));
  }

  /// Get saved credentials for a provider
  static Future<Map<String, dynamic>?> getCredentials(
      EmailProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('${_credentialsKey}_${provider.name}');
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Check if credentials exist for a provider
  static Future<bool> hasCredentials(EmailProvider provider) async {
    final credentials = await getCredentials(provider);
    return credentials != null &&
        credentials['email'] != null &&
        credentials['password'] != null;
  }

  /// Delete credentials for a provider
  static Future<void> deleteCredentials(EmailProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_credentialsKey}_${provider.name}');
  }
}
