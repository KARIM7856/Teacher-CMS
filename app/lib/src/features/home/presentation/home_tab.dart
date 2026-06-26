import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية')),
      body: const PlaceholderView(
        icon: Icons.home_rounded,
        title: 'مرحبًا بك',
        message: 'ستظهر هنا آخر الدروس و«تابِع ما بدأته» قريبًا.',
      ),
    );
  }
}
