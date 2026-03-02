import 'package:flutter/material.dart';

enum AppThemePalette {
  candySky,
  sunsetPop,
  mintForest,
  oceanBreeze,
}

extension AppThemePaletteX on AppThemePalette {
  String get key {
    switch (this) {
      case AppThemePalette.candySky:
        return 'candy_sky';
      case AppThemePalette.sunsetPop:
        return 'sunset_pop';
      case AppThemePalette.mintForest:
        return 'mint_forest';
      case AppThemePalette.oceanBreeze:
        return 'ocean_breeze';
    }
  }

  String get label {
    switch (this) {
      case AppThemePalette.candySky:
        return 'Candy Sky';
      case AppThemePalette.sunsetPop:
        return 'Sunset Pop';
      case AppThemePalette.mintForest:
        return 'Mint Forest';
      case AppThemePalette.oceanBreeze:
        return 'Ocean Breeze';
    }
  }

  String get description {
    switch (this) {
      case AppThemePalette.candySky:
        return 'Pastel mavi-pembe klasik SketchMind tonu.';
      case AppThemePalette.sunsetPop:
        return 'Sicak turuncu-mercan tonlar ve enerjik kontrast.';
      case AppThemePalette.mintForest:
        return 'Doga hissi veren yesil-nane dengesi.';
      case AppThemePalette.oceanBreeze:
        return 'Ferah mavi-turkuaz ve temiz beyaz tonlar.';
    }
  }

  static AppThemePalette fromKey(String? key) {
    switch (key) {
      case 'sunset_pop':
        return AppThemePalette.sunsetPop;
      case 'mint_forest':
        return AppThemePalette.mintForest;
      case 'ocean_breeze':
        return AppThemePalette.oceanBreeze;
      case 'candy_sky':
      default:
        return AppThemePalette.candySky;
    }
  }
}

class PlayfulPalette {
  static AppThemePalette _activeTheme = AppThemePalette.candySky;

  static final Map<AppThemePalette, _PaletteSpec> _presets =
      <AppThemePalette, _PaletteSpec>{
    AppThemePalette.candySky: const _PaletteSpec(
      sky: Color(0xFF86C4FF),
      mint: Color(0xFFA8D3FF),
      sunshine: Color(0xFFFFC7E6),
      coral: Color(0xFFFFA8D6),
      grape: Color(0xFFA592FF),
      cloud: Color(0xFFF9F7FF),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF243550),
      appBackground: LinearGradient(
        colors: [Color(0xFFEAF4FF), Color(0xFFF4EEFF), Color(0xFFFFEEF7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      storiesBackground: LinearGradient(
        colors: [Color(0xFFEAF3FF), Color(0xFFF8F2FF), Color(0xFFFFF1F9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      gamesBackground: LinearGradient(
        colors: [Color(0xFFEFF2FF), Color(0xFFF7F0FF), Color(0xFFFDEFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      learningBackground: LinearGradient(
        colors: [Color(0xFFF0F4FF), Color(0xFFF7EEFF), Color(0xFFFFEEF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      preview: [Color(0xFF86C4FF), Color(0xFFFFA8D6), Color(0xFFA592FF)],
    ),
    AppThemePalette.sunsetPop: const _PaletteSpec(
      sky: Color(0xFFFF9A62),
      mint: Color(0xFFFFC08A),
      sunshine: Color(0xFFFFE39E),
      coral: Color(0xFFFF7E6A),
      grape: Color(0xFFDA6FB6),
      cloud: Color(0xFFFFF6EE),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF3A2B34),
      appBackground: LinearGradient(
        colors: [Color(0xFFFFF0E4), Color(0xFFFFF4E8), Color(0xFFFFE9EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      storiesBackground: LinearGradient(
        colors: [Color(0xFFFFF3E8), Color(0xFFFFF1E3), Color(0xFFFFE8ED)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      gamesBackground: LinearGradient(
        colors: [Color(0xFFFFF4EA), Color(0xFFFFEFE4), Color(0xFFFFE6F0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      learningBackground: LinearGradient(
        colors: [Color(0xFFFFF6EE), Color(0xFFFFF2E8), Color(0xFFFFEBF4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      preview: [Color(0xFFFF9A62), Color(0xFFFF7E6A), Color(0xFFDA6FB6)],
    ),
    AppThemePalette.mintForest: const _PaletteSpec(
      sky: Color(0xFF5BBF8D),
      mint: Color(0xFF86D2A6),
      sunshine: Color(0xFFD4F2C8),
      coral: Color(0xFF54C2A2),
      grape: Color(0xFF6EBB8E),
      cloud: Color(0xFFF3FBF6),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF1F3C33),
      appBackground: LinearGradient(
        colors: [Color(0xFFE8F8EE), Color(0xFFF0FBF2), Color(0xFFEAF7F3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      storiesBackground: LinearGradient(
        colors: [Color(0xFFE9F9F0), Color(0xFFF0FBF3), Color(0xFFE8F5EE)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      gamesBackground: LinearGradient(
        colors: [Color(0xFFE8F8EF), Color(0xFFEFFAF4), Color(0xFFE6F4EF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      learningBackground: LinearGradient(
        colors: [Color(0xFFEAF8F0), Color(0xFFF1FBF4), Color(0xFFE7F4EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      preview: [Color(0xFF5BBF8D), Color(0xFF54C2A2), Color(0xFF86D2A6)],
    ),
    AppThemePalette.oceanBreeze: const _PaletteSpec(
      sky: Color(0xFF4EA9FF),
      mint: Color(0xFF74C6F7),
      sunshine: Color(0xFFAEE7F9),
      coral: Color(0xFF47C2D7),
      grape: Color(0xFF4F8DE6),
      cloud: Color(0xFFF3FAFF),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF1D3552),
      appBackground: LinearGradient(
        colors: [Color(0xFFEAF6FF), Color(0xFFEFF9FF), Color(0xFFE8F7FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      storiesBackground: LinearGradient(
        colors: [Color(0xFFEAF6FF), Color(0xFFEFF9FF), Color(0xFFE6F4FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      gamesBackground: LinearGradient(
        colors: [Color(0xFFE9F5FF), Color(0xFFEDF8FF), Color(0xFFE5F1FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      learningBackground: LinearGradient(
        colors: [Color(0xFFECF7FF), Color(0xFFF0FAFF), Color(0xFFE7F4FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      preview: [Color(0xFF4EA9FF), Color(0xFF47C2D7), Color(0xFF4F8DE6)],
    ),
  };

  static _PaletteSpec get _spec => _presets[_activeTheme]!;
  static _PaletteSpec _specFor(AppThemePalette palette) => _presets[palette]!;

  static AppThemePalette get activeTheme => _activeTheme;

  static void setTheme(AppThemePalette palette) {
    _activeTheme = palette;
  }

  static Color get sky => _spec.sky;
  static Color get mint => _spec.mint;
  static Color get sunshine => _spec.sunshine;
  static Color get coral => _spec.coral;
  static Color get grape => _spec.grape;
  static Color get cloud => _spec.cloud;
  static Color get card => _spec.card;
  static Color get ink => _spec.ink;

  static LinearGradient get appBackground => _spec.appBackground;
  static LinearGradient get storiesBackground => _spec.storiesBackground;
  static LinearGradient get gamesBackground => _spec.gamesBackground;
  static LinearGradient get learningBackground => _spec.learningBackground;

  static List<Color> previewColors(AppThemePalette palette) {
    return _specFor(palette).preview;
  }

  static LinearGradient tabBackground(int tabIndex) {
    if (tabIndex == 1) return gamesBackground;
    if (tabIndex == 2) return learningBackground;
    return storiesBackground;
  }
}

class _PaletteSpec {
  const _PaletteSpec({
    required this.sky,
    required this.mint,
    required this.sunshine,
    required this.coral,
    required this.grape,
    required this.cloud,
    required this.card,
    required this.ink,
    required this.appBackground,
    required this.storiesBackground,
    required this.gamesBackground,
    required this.learningBackground,
    required this.preview,
  });

  final Color sky;
  final Color mint;
  final Color sunshine;
  final Color coral;
  final Color grape;
  final Color cloud;
  final Color card;
  final Color ink;
  final LinearGradient appBackground;
  final LinearGradient storiesBackground;
  final LinearGradient gamesBackground;
  final LinearGradient learningBackground;
  final List<Color> preview;
}
