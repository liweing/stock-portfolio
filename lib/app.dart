import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';

class StockPortfolioApp extends StatelessWidget {
  const StockPortfolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '持仓助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }
}

/// 认证守卫：根据登录状态切换页面
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 如果 Supabase 没有配置，显示提示页
    if (!SupabaseConfig.isConfigured) {
      return const _NotConfiguredScreen();
    }

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (_) {
        final isLoggedIn = ref.watch(isLoggedInProvider);
        return isLoggedIn ? const HomeScreen() : const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('认证错误: $e')),
      ),
    );
  }
}

/// Supabase 未配置提示页
class _NotConfiguredScreen extends StatelessWidget {
  const _NotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off,
                    size: 64, color: Colors.orange.shade700),
                const SizedBox(height: 16),
                const Text(
                  'Supabase 尚未配置',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '请编辑 lib/core/supabase_config.dart\n'
                  '填入你的 Supabase URL 和 anon key',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
