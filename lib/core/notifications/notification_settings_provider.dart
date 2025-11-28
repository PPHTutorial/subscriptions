import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  final bool enabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool showBadge;

  NotificationSettings({
    this.enabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.showBadge = true,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? showBadge,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      showBadge: showBadge ?? this.showBadge,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'showBadge': showBadge,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      soundEnabled: json['soundEnabled'] ?? true,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
      showBadge: json['showBadge'] ?? true,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(NotificationSettings()) {
    _loadSettings();
  }

  static const String _prefsKey = 'notification_settings';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        // Simple JSON parsing for boolean values
        final enabled = prefs.getBool('${_prefsKey}_enabled') ?? true;
        final soundEnabled = prefs.getBool('${_prefsKey}_soundEnabled') ?? true;
        final vibrationEnabled =
            prefs.getBool('${_prefsKey}_vibrationEnabled') ?? true;
        final showBadge = prefs.getBool('${_prefsKey}_showBadge') ?? true;

        state = NotificationSettings(
          enabled: enabled,
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
          showBadge: showBadge,
        );
      } catch (e) {
        // Use defaults if parsing fails
        state = NotificationSettings();
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefsKey}_enabled', state.enabled);
    await prefs.setBool('${_prefsKey}_soundEnabled', state.soundEnabled);
    await prefs.setBool(
        '${_prefsKey}_vibrationEnabled', state.vibrationEnabled);
    await prefs.setBool('${_prefsKey}_showBadge', state.showBadge);
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _saveSettings();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    state = state.copyWith(vibrationEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setShowBadge(bool enabled) async {
    state = state.copyWith(showBadge: enabled);
    await _saveSettings();
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);
