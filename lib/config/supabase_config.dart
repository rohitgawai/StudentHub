/// Supabase project credentials.
///
/// The anon key is a public, RLS-protected credential by design (Supabase
/// best practice). Values can be overridden at build/run time with:
///   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pdcfjkqermynsmezsyyt.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkY2Zqa3Flcm15bnNtZXpzeXl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMzM3NTksImV4cCI6MjEwMTYwOTc1OX0._az6ftBTGqyFiP_IjdQqyCv_D_6gHHa1X36sTLoyOXI',
  );
}