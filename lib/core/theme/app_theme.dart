import 'package:flutter/material.dart';

/// Tema único do aplicativo.
///
/// A paleta nasceu no Machine Monitor (azul-marinho + ciano) e foi estendida
/// com os tokens que a bancada TEX precisava (laranja de leitura, gradiente de
/// painel, LEDs, barra de alarme). Tudo deriva das mesmas cores-base, então as
/// duas áreas do app — monitoramento e TEX — têm a mesma identidade visual.
class AppTheme {
  AppTheme._();

  // ── Paleta base ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0D47A1);
  static const Color accent = Color(0xFF00BCD4);
  static const Color accentSoft = Color(0xFF48CAE4);

  static const Color surface = Color(0xFF0A1628);
  static const Color surfaceDeep = Color(0xFF050E1A);
  static const Color surfaceCard = Color(0xFF112240);
  static const Color surfaceElevated = Color(0xFF1A2F4A);

  static const Color textPrimary = Color(0xFFE8EDF5);
  static const Color textSecondary = Color(0xFF8BA3C7);
  static const Color textMuted = Color(0xFF6B8AAF);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF5252);
  static const Color border = Color(0xFF1E3A5F);

  // ── Tokens da bancada TEX (derivados da base) ────────────────────────────────
  /// Cor das leituras numéricas grandes (pressão, vazamento).
  static const Color readout = Color(0xFFFF9F1C);

  /// LED aceso / apagado nas telas de E-S e diagnóstico.
  static const Color ledOn = success;
  static const Color ledOff = Color(0xFF243B55);

  /// Barra de alarme no rodapé do console TEX.
  static const Color alarm = Color(0xFFD90429);

  // ── Gradientes reutilizáveis ─────────────────────────────────────────────────
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceCard, surface],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [surface, surfaceCard, surface],
  );

  // ── Métricas ─────────────────────────────────────────────────────────────────
  static const double radius = 14;
  static const double radiusSmall = 8;

  // ── Responsividade ───────────────────────────────────────────────────────────

  /// `true` para telas de tablet (largura ≥ 600 px).
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  /// Padding horizontal adaptativo das telas.
  static double hPad(BuildContext context) => isTablet(context) ? 32.0 : 16.0;

  /// Padding interno adaptativo dos cards.
  static double cardPad(BuildContext context) => isTablet(context) ? 24.0 : 16.0;

  // ── ThemeData ────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surfaceCard,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}
