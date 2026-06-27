import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/achievements/presentation/celebration_overlay.dart';
import 'features/shell/presentation/root_screen.dart';

/// Root widget. Arabic-first: the default locale is `ar` and the Material
/// localizations drive RTL layout across the whole app.
class TeacherCmsApp extends StatelessWidget {
  const TeacherCmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منصة المعلّم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Mount the celebration overlay above the navigator so achievement
      // celebrations appear over whatever screen the student is on.
      builder: (context, child) => Stack(
        textDirection: TextDirection.rtl,
        children: [
          if (child != null) child,
          const CelebrationOverlay(),
        ],
      ),
      home: const RootScreen(),
    );
  }
}
