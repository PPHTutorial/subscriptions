/// App configuration with API keys and feature flags
///
/// For production, these should be loaded from secure storage or environment variables
/// Never commit actual API keys to version control!
class AppConfig {
  // Vercel Proxy Server URL
  static const String vercelProxyUrl =
      'YOUR_VERCEL_PROXY_URL'; // e.g., https://your-app.vercel.app/api

  // Firebase Configuration
  static const String firebaseApiKey = 'YOUR_FIREBASE_API_KEY';
  static const String firebaseAppId = 'YOUR_FIREBASE_APP_ID';
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
  static const String firebaseMessagingSenderId =
      'YOUR_FIREBASE_MESSAGING_SENDER_ID';

  // Feature Flags
  static const bool enableEmailScanner = true;
  static const bool enableSmsScanner = true;
  static const bool enableReceiptUpload = true;
  static const bool enableCloudSync = true;
  static const bool enableAiInsights = true;

  // Check if API keys are configured
  static bool get isVercelProxyConfigured =>
      vercelProxyUrl != 'YOUR_VERCEL_PROXY_URL';

  static bool get isFirebaseConfigured =>
      firebaseApiKey != 'YOUR_FIREBASE_API_KEY' &&
      firebaseProjectId != 'YOUR_FIREBASE_PROJECT_ID';
}
