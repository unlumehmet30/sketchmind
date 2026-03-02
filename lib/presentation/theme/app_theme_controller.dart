import 'package:flutter/material.dart';

import '../../data/services/local_user_service.dart';
import 'playful_theme.dart';

class AppThemeController extends ValueNotifier<AppThemePalette> {
  AppThemeController._internal()
      : _localUserService = LocalUserService(),
        super(AppThemePalette.candySky) {
    PlayfulPalette.setTheme(value);
  }

  static final AppThemeController instance = AppThemeController._internal();

  final LocalUserService _localUserService;

  Future<void> loadFromStorage() async {
    final storedKey = await _localUserService.getAppThemePalette();
    final palette = AppThemePaletteX.fromKey(storedKey);
    PlayfulPalette.setTheme(palette);
    if (value != palette) {
      value = palette;
      return;
    }
    notifyListeners();
  }

  Future<void> setThemePalette(AppThemePalette palette) async {
    if (value == palette) return;
    PlayfulPalette.setTheme(palette);
    value = palette;
    await _localUserService.setAppThemePalette(palette.key);
  }
}
