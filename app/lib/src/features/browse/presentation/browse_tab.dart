import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class BrowseTab extends StatelessWidget {
  const BrowseTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تصفّح')),
      body: const PlaceholderView(
        icon: Icons.explore_rounded,
        title: 'تصفّح المحتوى',
        message: 'التصنيفات والوسوم والبحث ستتوفّر هنا في المرحلة القادمة.',
      ),
    );
  }
}
