import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/update_checker.dart';
import 'position_list_screen.dart';
import 'analysis_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final _pageController = PageController();

  static const _screens = [
    PositionListScreen(),
    AnalysisScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Web 端不需要升级检查（每次刷新都是最新）
    if (!kIsWeb) {
      // 延迟 2s 静默检查，避免阻塞首屏渲染
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        checkForUpdateWithDialog(context, ref, manual: false);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '持仓',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: '分析',
          ),
        ],
      ),
    );
  }
}
