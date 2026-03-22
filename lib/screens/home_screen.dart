import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/title_bar.dart';
import 'image_screen.dart';
import 'video_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Column(
        children: [
          const TitleBar(),
          Container(height: 1, color: AppTheme.border),
          Expanded(
            child: Row(
              children: [
                const AppSidebar(),
                Container(width: 1, color: AppTheme.border),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return Consumer<AppState>(builder: (_, s, __) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: switch (s.tab) {
          0 => const ImageScreen(key: ValueKey('img')),
          1 => const VideoScreen(key: ValueKey('vid')),
          2 => const DashboardScreen(key: ValueKey('dash')),
          _ => const ImageScreen(key: ValueKey('img')),
        },
      );
    });
  }
}
