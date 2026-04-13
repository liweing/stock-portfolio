import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// 当前登录用户
  User? get currentUser => _client.auth.currentUser;

  /// 是否已登录
  bool get isLoggedIn => currentUser != null;

  /// 监听登录状态变化
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// 邮箱密码登录
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// 邮箱密码注册
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// 退出登录
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 重置密码（发送重置邮件）
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
