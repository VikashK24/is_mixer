import 'package:flutter/material.dart';

/// Colours of the noir "mafia" look: a dark room, gold trim, crimson accents
/// and cream paper for the information cards.
class NoirColors {
  static const Color ink = Color(0xFF0B0B10);
  static const Color panel = Color(0xFF15151D);
  static const Color crimson = Color(0xFFB3202B);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0xFFE9D8A6);
  static const Color cream = Color(0xFFF1E9D6);
  static const Color paper = Color(0xFFF6F0E2);
  static const Color paperInk = Color(0xFF2A2118);
  static const Color muted = Color(0xFFA39E94);
}

const List<String> _serifFallback = ['Georgia', 'Times New Roman', 'serif'];

/// Serif display style used for titles (no font package needed).
TextStyle noirHeading({
  double size = 32,
  Color color = NoirColors.cream,
  double spacing = 1.5,
}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: _serifFallback,
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: spacing,
    color: color,
    height: 1.15,
  );
}

ThemeData buildNoirTheme() {
  // A warm gold-brown seed gives the default cards and dialogs a parchment
  // tint, so every existing card reads as a paper dossier on a dark table.
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF8A6A2B));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NoirColors.ink,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NoirColors.crimson,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

/// Dark, moody page background with a faint "venetian blind" light.
class NoirBackground extends StatelessWidget {
  final Widget child;

  const NoirBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.35,
          colors: [Color(0xFF2B1018), Color(0xFF13090E), NoirColors.ink],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _BlindsPainter())),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _BlindsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.022);
    const bandHeight = 46.0;
    const gap = 46.0;
    const slant = 220.0;
    for (double y = -slant; y < size.height; y += bandHeight + gap) {
      final path = Path()
        ..moveTo(0, y + slant)
        ..lineTo(size.width, y)
        ..lineTo(size.width, y + bandHeight)
        ..lineTo(0, y + slant + bandHeight)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cream paper card with a gold edge, used for the About and People pages.
class DossierCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsets padding;

  const DossierCard({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NoirColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NoirColors.gold.withOpacity(0.6)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: NoirColors.crimson, size: 26),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: noirHeading(
                      size: 24,
                      color: NoirColors.paperInk,
                      spacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              width: 56,
              color: NoirColors.gold,
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Centered page heading with a small eyebrow line and gold rule.
class PageTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const PageTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: NoirColors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: noirHeading(size: 42)),
        const SizedBox(height: 14),
        Container(height: 2, width: 90, color: NoirColors.gold),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NoirColors.muted,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}