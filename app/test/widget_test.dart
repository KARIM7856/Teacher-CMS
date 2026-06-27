import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_cms_app/src/core/theme/app_theme.dart';
import 'package:teacher_cms_app/src/features/auth/presentation/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen shows the app name and auth actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const WelcomeScreen(),
        ),
      ),
    );

    expect(find.text('منصة المعلّم'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('لديّ حساب — تسجيل الدخول'), findsOneWidget);
  });
}
