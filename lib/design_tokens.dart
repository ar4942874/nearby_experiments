import 'package:flutter/material.dart';

/// Design tokens for Nearby Connect.
/// Dart mirror of DESIGN.md (OpenDesign 9-section schema) — the single source
/// of truth for colors, spacing, typography, radius, and motion.
class AppTokens {
  AppTokens._();

  // 1. Color
  static const Color background = Color(0xFFF7F5F0);
  static const Color accent = Color(0xFF3A7D6E);
  static const Color text = Color(0xFF2D2D2D);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color tint = Color(0xFFE8F5F3);
  static const Color danger = Color(0xFFD64545);
  static const Color border = Color(0xFFE0E0E0);

  static Color accentWith(double opacity) => accent.withOpacity(opacity);
  static Color dangerWith(double opacity) => danger.withOpacity(opacity);

  // 1b. Game player aliases — 4-player color palette.
  // Player 0 (Top-Left): Emerald Teal — host
  // Player 1 (Top-Right): Crimson Coral
  // Player 2 (Bottom-Right): Royal Indigo
  // Player 3 (Bottom-Left): Warm Amber
  static const Color player0 = Color(0xFF3A7D6E);
  static const Color player1 = Color(0xFFE05A47);
  static const Color player2 = Color(0xFF4A6FA5);
  static const Color player3 = Color(0xFFD99B26);
  static const Color player0Tint = Color(0xFFE8F5F3);
  static const Color player1Tint = Color(0xFFFDEEEB);
  static const Color player2Tint = Color(0xFFEDF1F8);
  static const Color player3Tint = Color(0xFFFBF3E4);

  static Color playerColor(int p) {
    switch (p) {
      case 1:
        return player1;
      case 2:
        return player2;
      case 3:
        return player3;
      default:
        return player0;
    }
  }

  static Color playerTint(int p) {
    switch (p) {
      case 1:
        return player1Tint;
      case 2:
        return player2Tint;
      case 3:
        return player3Tint;
      default:
        return player0Tint;
    }
  }

  // 3. Spacing (4px grid)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // 5. Radius
  static const double radiusCard = 20;
  static const double radiusControl = 16;
  static const double radiusInput = 16;
  static const double radiusChatInput = 28;
  static const double radiusBubble = 20;
  static const double radiusIconBox = 14;
  static const double radiusBoard = 24;

  // 5. Borders & shadow
  static const BorderSide hairline = BorderSide(color: border, width: 1);
  static const Border cardBorder = Border.fromBorderSide(hairline);
  static final List<BoxShadow> cardShadow = [
    const BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  // 2. Typography
  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: text,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: text,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: text,
    letterSpacing: -0.2,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: text,
    height: 1.4,
  );

  static TextStyle muted(double size) => TextStyle(
        fontSize: size,
        color: Colors.grey.shade500,
      );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: Color(0xFF9E9E9E),
    letterSpacing: 0.2,
  );

  // 6. Motion
  static const Duration motion = Duration(milliseconds: 200);
  static const Duration motionSlow = Duration(milliseconds: 400);
  static const Duration motionPulse = Duration(milliseconds: 800);

  // Shared component builders
  static BoxDecoration cardDecoration({double radius = radiusCard, Color fill = surface}) =>
      BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: cardBorder,
      );

  static InputDecoration inputDecoration({String? hint, double radius = radiusInput}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      );
}
