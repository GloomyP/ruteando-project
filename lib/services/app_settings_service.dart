import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.notificacionesInternasActivas,
  });

  final ThemeMode themeMode;
  final bool notificacionesInternasActivas;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    bool? notificacionesInternasActivas,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      notificacionesInternasActivas:
          notificacionesInternasActivas ?? this.notificacionesInternasActivas,
    );
  }
}

class AppSettingsService extends ValueNotifier<AppSettingsState> {
  AppSettingsService()
    : super(
        const AppSettingsState(
          themeMode: ThemeMode.light,
          notificacionesInternasActivas: true,
        ),
      );

  static const _themeModeKey = 'app_settings_theme_mode';
  static const _notificacionesKey =
      'app_settings_notificaciones_internas_activas';

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = switch (prefs.getString(_themeModeKey)) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    value = AppSettingsState(
      themeMode: themeMode,
      notificacionesInternasActivas: prefs.getBool(_notificacionesKey) ?? true,
    );
  }

  Future<void> cambiarTema(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    value = value.copyWith(themeMode: themeMode);
  }

  Future<void> cambiarNotificacionesInternas(bool activas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificacionesKey, activas);
    value = value.copyWith(notificacionesInternasActivas: activas);
  }
}

final appSettingsService = AppSettingsService();
