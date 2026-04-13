import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/auth_repository.dart';

/// Supabase 客户端
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// 认证 Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// 当前认证状态（监听 Supabase 的登录状态变化）
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// 当前用户（便捷访问）
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // 触发刷新
  return ref.watch(authRepositoryProvider).currentUser;
});

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
