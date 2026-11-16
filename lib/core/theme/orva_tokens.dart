import 'package:flutter/material.dart';

import 'orva_theme.dart';

/// Spacing scale used by the redesigned surfaces. Values follow a 4pt grid so
/// vertical rhythm stays predictable across screens.
abstract final class OrvaSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class OrvaRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;
}

abstract final class OrvaMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 220);

  /// Honours the platform "reduce motion" preference.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true
      ? Duration.zero
      : duration;
}

/// Semantic colors for time-blocking categories. Colors are assigned by meaning
/// first (work, study, training...) and by a stable hash only as a fallback, so
/// a category keeps its identity between days and views.
abstract final class OrvaCategoryPalette {
  static const List<Color> _fallback = [
    OrvaColors.information,
    OrvaColors.primary,
    OrvaColors.terracotta,
    OrvaColors.mustard,
    Color(0xFF7A9B76),
    Color(0xFF8B6B9E),
  ];

  static Color of(BuildContext context, String category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = category.trim().toLowerCase();
    final color = switch (key) {
      _
          when key.contains('trabalho') ||
              key.contains('est') && key.contains('ágio') =>
        OrvaColors.information,
      _
          when key.contains('exerc') ||
              key.contains('treino') ||
              key.contains('academia') =>
        OrvaColors.success,
      _
          when key.contains('estud') ||
              key.contains('aula') ||
              key.contains('faculdade') =>
        OrvaColors.primary,
      _ when key.contains('lazer') || key.contains('hobby') =>
        OrvaColors.terracotta,
      _ when key.contains('aliment') || key.contains('refei') =>
        OrvaColors.mustard,
      _ when key.contains('obriga') => Color(0xFF8B6B9E),
      _ when key.contains('rotina') => Color(0xFF7A9B76),
      '' => OrvaColors.tertiaryText,
      _ => _fallback[key.hashCode.abs() % _fallback.length],
    };
    return isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.18), color)
        : color;
  }

  static Color soft(BuildContext context, Color color) => color.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.13,
  );
}
