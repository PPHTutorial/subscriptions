import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to save and manage user feedback
class FeedbackService {
  static const String _feedbackListKey = 'user_feedback_list';
  static const String _lastFeedbackDateKey = 'last_feedback_date';

  /// Save user feedback
  Future<void> saveFeedback({
    required int experience,
    String? comments,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing feedback list
    final feedbackListJson = prefs.getStringList(_feedbackListKey) ?? [];
    final feedbackList = feedbackListJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();

    // Create new feedback entry
    final feedback = {
      'experience': experience,
      'comments': comments ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add to list
    feedbackList.add(feedback);

    // Save back to SharedPreferences
    final updatedList = feedbackList.map((f) => jsonEncode(f)).toList();
    await prefs.setStringList(_feedbackListKey, updatedList);
    await prefs.setString(
        _lastFeedbackDateKey, DateTime.now().toIso8601String());
  }

  /// Get all feedback entries
  Future<List<Map<String, dynamic>>> getAllFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final feedbackListJson = prefs.getStringList(_feedbackListKey) ?? [];

    return feedbackListJson
        .map((json) => Map<String, dynamic>.from(jsonDecode(json)))
        .toList();
  }

  /// Get last feedback date
  Future<DateTime?> getLastFeedbackDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_lastFeedbackDateKey);
    if (dateStr == null) return null;
    return DateTime.parse(dateStr);
  }

  /// Clear all feedback (for testing)
  Future<void> clearAllFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedbackListKey);
    await prefs.remove(_lastFeedbackDateKey);
  }
}
