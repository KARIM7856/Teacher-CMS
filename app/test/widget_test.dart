import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_cms_app/src/core/theme/app_theme.dart';
import 'package:teacher_cms_app/src/features/auth/presentation/sign_in_screen.dart';

void main() {
  testWidgets('Sign-in screen shows username + password fields (no sign-up)',
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
          home: const SignInScreen(),
        ),
      ),
    );

    // The username field label and the sign-in action are present…
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    // …and there is no account-creation entry point anywhere.
    expect(find.text('إنشاء حساب جديد'), findsNothing);
  });
}
