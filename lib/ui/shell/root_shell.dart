// ui/shell/root_shell.dart
//
// The app's root scaffold. An IndexedStack preserves each tab's scroll/state
// while the floating mini-player + nav dock are layered above the content
// (DESIGN.md → "Glass Layer floating above the content stack"). Screens add
// AppSpacing.bottomDock padding so nothing hides behind the dock.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../queue/queue_screen.dart';
import '../search/search_screen.dart';
import '../widgets/mini_player.dart';
import 'floating_nav_bar.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Built once and kept alive by the IndexedStack.
  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    QueueScreen(),
  ];

  void _onTap(int i) {
    // Tapping "Queue" while something plays could also open Now Playing;
    // we keep it as a full tab here for discoverability.
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          // Floating dock: mini-player stacked over the nav, both suspended
          // off the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MiniPlayer(),
                    const SizedBox(height: 10),
                    FloatingNavBar(currentIndex: _index, onTap: _onTap),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
