import 'package:flutter/material.dart';

/// A Material icon + accent color for an achievement, derived from the server's
/// `icon` hint. Unknown hints fall back to a trophy, so new achievements added
/// server-side always render sensibly.
class AchievementVisual {
  const AchievementVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

AchievementVisual achievementVisual(String? iconName, ColorScheme scheme) {
  switch (iconName) {
    case 'star':
      return const AchievementVisual(Icons.star_rounded, Color(0xFFF6B73C));
    case 'fire':
      return const AchievementVisual(
          Icons.local_fire_department_rounded, Color(0xFFEF6C4D));
    case 'trophy':
      return const AchievementVisual(
          Icons.emoji_events_rounded, Color(0xFFE7A019));
    case 'school':
      return AchievementVisual(Icons.school_rounded, scheme.tertiary);
    default:
      return AchievementVisual(Icons.emoji_events_rounded, scheme.primary);
  }
}
