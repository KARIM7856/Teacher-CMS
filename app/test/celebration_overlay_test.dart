import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_cms_app/src/core/theme/app_theme.dart';
import 'package:teacher_cms_app/src/features/achievements/application/celebration_controller.dart';
import 'package:teacher_cms_app/src/features/achievements/presentation/celebration_overlay.dart';
import 'package:teacher_cms_app/src/models/celebration_data.dart';

/// A controller pre-seeded with one celebration so the overlay has something to
/// show without hitting Supabase.
class _SeededCelebration extends CelebrationController {
  @override
  List<CelebrationData> build() => const [
        CelebrationData(
          code: 'first_view',
          title: 'الخطوة الأولى',
          message: 'شاهدت أول درس لك.',
          icon: 'star',
        ),
      ];
}

void main() {
  testWidgets('celebration overlay renders the unlocked achievement',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          celebrationControllerProvider.overrideWith(_SeededCelebration.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              // Force reduce-motion so no confetti/Lottie timers run in the test.
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const Scaffold(
                  body: Stack(children: [CelebrationOverlay()]),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الخطوة الأولى'), findsOneWidget);
    expect(find.text('شاهدت أول درس لك.'), findsOneWidget);
    expect(find.text('رائع!'), findsOneWidget);
  });
}
