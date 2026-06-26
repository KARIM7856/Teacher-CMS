import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/motion.dart';
import '../../../models/celebration_data.dart';
import '../application/celebration_controller.dart';
import 'widgets/achievement_badge.dart';

/// Mounted once over the signed-in shell. When an achievement is unlocked it
/// shows a full-screen celebration for the first queued item; dismissing it
/// advances to the next. Generic over [CelebrationData], so new achievements
/// need no changes here.
class CelebrationOverlay extends ConsumerWidget {
  const CelebrationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(celebrationControllerProvider);
    if (queue.isEmpty) return const SizedBox.shrink();

    final CelebrationData current = queue.first;
    return _CelebrationView(
      // A fresh key per achievement replays the entrance animation.
      key: ValueKey(current.code),
      data: current,
      onDismiss: () =>
          ref.read(celebrationControllerProvider.notifier).dismissCurrent(),
    );
  }
}

class _CelebrationView extends StatefulWidget {
  const _CelebrationView({super.key, required this.data, required this.onDismiss});

  final CelebrationData data;
  final VoidCallback onDismiss;

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final ConfettiController _confetti;

  late final Animation<double> _scrim;
  late final Animation<double> _badgeScale;
  late final Animation<double> _glow;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _messageFade;
  late final Animation<Offset> _messageSlide;
  late final Animation<double> _buttonFade;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confetti = ConfettiController(duration: const Duration(milliseconds: 1200));

    _scrim = CurvedAnimation(
        parent: _entrance, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _badgeScale = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut));
    _glow = CurvedAnimation(
        parent: _entrance, curve: const Interval(0.2, 0.7, curve: Curves.easeOut));
    _titleFade = CurvedAnimation(
        parent: _entrance, curve: const Interval(0.45, 0.8, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic)));
    _messageFade = CurvedAnimation(
        parent: _entrance, curve: const Interval(0.55, 0.9, curve: Curves.easeOut));
    _messageSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic)));
    _buttonFade = CurvedAnimation(
        parent: _entrance, curve: const Interval(0.7, 1.0, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (prefersReducedMotion(context)) {
      // Skip motion: show everything settled, with a gentle haptic only.
      _entrance.value = 1.0;
      HapticFeedback.selectionClick();
    } else {
      _entrance.forward();
      _confetti.play();
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool reduced = prefersReducedMotion(context);
    final CelebrationData data = widget.data;

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Dim, tap-absorbing backdrop (does not dismiss — the button does).
            FadeTransition(
              opacity: _scrim,
              child: const ModalBarrier(dismissible: false, color: Colors.black87),
            ),
            if (!reduced)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.06,
                  numberOfParticles: 18,
                  maxBlastForce: 22,
                  minBlastForce: 8,
                  gravity: 0.25,
                  shouldLoop: false,
                  colors: [
                    scheme.primary,
                    scheme.tertiary,
                    const Color(0xFFF6B73C),
                    Colors.white,
                  ],
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!reduced)
                            FadeTransition(
                              opacity: _glow,
                              child: Lottie.asset(
                                'assets/lottie/celebration.json',
                                width: 200,
                                height: 200,
                                repeat: true,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ScaleTransition(
                            scale: _badgeScale,
                            child: AchievementBadge(
                              iconName: data.icon,
                              size: 124,
                              glow: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    if (data.message != null && data.message!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SlideTransition(
                        position: _messageSlide,
                        child: FadeTransition(
                          opacity: _messageFade,
                          child: Text(
                            data.message!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FadeTransition(
                      opacity: _buttonFade,
                      child: FilledButton(
                        onPressed: widget.onDismiss,
                        child: const Text('رائع!'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
