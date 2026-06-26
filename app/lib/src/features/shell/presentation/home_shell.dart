import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievements/application/celebration_controller.dart';
import '../../browse/presentation/browse_tab.dart';
import '../../home/presentation/home_tab.dart';
import '../../playlists/presentation/playlists_tab.dart';
import '../../profile/presentation/profile_tab.dart';

/// The signed-in shell: a bottom navigation bar over four tabs, with the
/// achievement celebration overlay mounted above everything. An IndexedStack
/// keeps each tab's state alive while switching.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const List<Widget> _tabs = [
    HomeTab(),
    BrowseTab(),
    PlaylistsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Opening the signed-in app counts as activity (drives the streak) and
    // surfaces any achievement earned but not yet celebrated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(celebrationControllerProvider.notifier).claim();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The celebration overlay is mounted app-wide (see TeacherCmsApp.builder) so
    // it appears above pushed routes such as the post detail screen.
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'تصفّح',
          ),
          NavigationDestination(
            icon: Icon(Icons.featured_play_list_outlined),
            selectedIcon: Icon(Icons.featured_play_list_rounded),
            label: 'القوائم',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
