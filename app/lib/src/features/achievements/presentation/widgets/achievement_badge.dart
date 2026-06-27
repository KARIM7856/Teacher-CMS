import 'package:flutter/material.dart';

import '../achievement_visuals.dart';

/// A circular achievement badge, reused by the celebration overlay and the
/// achievements grid. Earned badges are colorful (optionally glowing); locked
/// badges are muted with a lock glyph.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.iconName,
    this.size = 96,
    this.earned = true,
    this.glow = false,
  });

  final String? iconName;
  final double size;
  final bool earned;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AchievementVisual visual = achievementVisual(iconName, scheme);
    final Color color = visual.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? null : scheme.surfaceContainerHighest,
        gradient: earned
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [color, Color.lerp(color, Colors.black, 0.18)!],
              )
            : null,
        boxShadow: earned && glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: size * 0.4,
                  spreadRadius: size * 0.06,
                ),
              ]
            : null,
      ),
      child: Icon(
        earned ? visual.icon : Icons.lock_rounded,
        size: size * 0.46,
        color: earned ? Colors.white : scheme.onSurfaceVariant,
      ),
    );
  }
}
