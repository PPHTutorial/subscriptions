import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app rating and sharing prompts
class RatingService {
  static const String _hasRatedKey = 'app_has_rated';
  static const String _hasSharedKey = 'app_has_shared';
  static const String _lastPromptDateKey = 'app_rating_last_prompt_date';
  static const String _promptCountKey = 'app_rating_prompt_count';
  static const String _hasDeclinedKey = 'app_rating_has_declined';

  // Minimum days between prompts (if user hasn't rated/shared)
  static const int _minDaysBetweenPrompts = 7;
  // Maximum number of times to prompt before giving up
  static const int _maxPromptAttempts = 5;

  /// Check if user has already rated the app
  Future<bool> hasRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasRatedKey) ?? false;
  }

  /// Check if user has already shared the app
  Future<bool> hasShared() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSharedKey) ?? false;
  }

  /// Check if user has both rated and shared
  Future<bool> hasCompletedRating() async {
    final hasRatedValue = await hasRated();
    final hasSharedValue = await hasShared();
    return hasRatedValue && hasSharedValue;
  }

  /// Mark app as rated
  Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  /// Mark app as shared
  Future<void> markAsShared() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSharedKey, true);
  }

  /// Check if we should show the rating prompt
  /// Returns true if:
  /// - User hasn't rated/shared yet
  /// - Enough days have passed since last prompt
  /// - We haven't exceeded max attempts
  /// - User hasn't permanently declined
  Future<bool> shouldShowPrompt() async {
    // If user has already rated and shared, don't show
    if (await hasCompletedRating()) {
      return false;
    }

    // If user has declined permanently, don't show
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hasDeclinedKey) ?? false) {
      return false;
    }

    // Check prompt count
    final promptCount = prefs.getInt(_promptCountKey) ?? 0;
    if (promptCount >= _maxPromptAttempts) {
      return false;
    }

    // Check if enough days have passed since last prompt
    final lastPromptStr = prefs.getString(_lastPromptDateKey);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.parse(lastPromptStr);
      final daysSinceLastPrompt = DateTime.now().difference(lastPrompt).inDays;
      if (daysSinceLastPrompt < _minDaysBetweenPrompts) {
        return false;
      }
    }

    return true;
  }

  /// Record that we've shown the prompt
  Future<void> recordPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_promptCountKey) ?? 0;
    await prefs.setInt(_promptCountKey, currentCount + 1);
    await prefs.setString(_lastPromptDateKey, DateTime.now().toIso8601String());
  }

  /// Mark that user has declined (permanently)
  Future<void> markAsDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasDeclinedKey, true);
  }

  /// Reset all rating data (for testing)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasRatedKey);
    await prefs.remove(_hasSharedKey);
    await prefs.remove(_lastPromptDateKey);
    await prefs.remove(_promptCountKey);
    await prefs.remove(_hasDeclinedKey);
  }
}
