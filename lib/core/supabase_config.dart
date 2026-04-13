/// Supabase 配置
///
/// 注册并配置后，将下面两个值替换为你自己的：
/// - URL: 在 Supabase 控制台 Settings → API → Project URL
/// - anonKey: 在 Supabase 控制台 Settings → API → Project API Keys → anon public
class SupabaseConfig {
  static const String url = 'https://zbxpmrvwybqqwbruskqr.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpieHBtcnZ3eWJxcXdicnVza3FyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNDkxODQsImV4cCI6MjA5MTYyNTE4NH0.H8jaxIkBsA9dOLeY3PJJtfOm3FhTEsRegAJiRzkELnk';

  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
