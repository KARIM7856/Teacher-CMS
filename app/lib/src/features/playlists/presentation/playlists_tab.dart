import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_view.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('القوائم')),
      body: const PlaceholderView(
        icon: Icons.featured_play_list_rounded,
        title: 'قوائم التشغيل',
        message: 'ستظهر هنا قوائم التشغيل المرتّبة من معلّمك.',
      ),
    );
  }
}
