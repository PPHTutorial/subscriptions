import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppColorScheme {
  purple,
  blue,
  green,
  pink,
  orange,
  teal,
  yellow,
  red,
  gray,
  brown,
  black,
  white,
}

class ThemeState {
  final Brightness brightness;
  final AppColorScheme colorScheme;

  ThemeState({
    required this.brightness,
    required this.colorScheme,
  });

  ThemeState copyWith({
    Brightness? brightness,
    AppColorScheme? colorScheme,
  }) {
    return ThemeState(
      brightness: brightness ?? this.brightness,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const _brightnessKey = 'theme_brightness';
  static const _colorSchemeKey = 'theme_color_scheme';

  ThemeNotifier()
      : super(ThemeState(
            brightness: Brightness.light, colorScheme: AppColorScheme.purple)) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final brightnessIndex = prefs.getInt(_brightnessKey) ?? 0;
    final colorSchemeIndex = prefs.getInt(_colorSchemeKey) ?? 0;

    state = ThemeState(
      brightness: brightnessIndex == 0 ? Brightness.light : Brightness.dark,
      colorScheme: AppColorScheme
          .values[colorSchemeIndex.clamp(0, AppColorScheme.values.length - 1)],
    );
  }

  Future<void> toggleBrightness() async {
    final newBrightness = state.brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    state = state.copyWith(brightness: newBrightness);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _brightnessKey, newBrightness == Brightness.light ? 0 : 1);
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(colorScheme: scheme);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorSchemeKey, scheme.index);
  }
}
