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

  /// FCM push: endpoint of the "send-push" Edge Function that broadcasts a new
  /// post to every registered device. Override with --dart-define if the
  /// function is hosted on a different Supabase project.
  static const String pushFunctionUrl = String.fromEnvironment(
    'PUSH_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/send-push',
  );

  /// Server-side post deletion. The function verifies the caller is the post's
  /// author (or an admin, for moderation) before deleting, so deletions survive
  /// refreshes across devices.
  static const String deleteFunctionUrl = String.fromEnvironment(
    'DELETE_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/delete-post',
  );

  /// Server-side role application review. The function verifies the caller is
  /// an admin, updates the request status, and seeds the granted role into the
  /// applicant's `profiles` row so every device picks it up via sync.
  static const String reviewRoleFunctionUrl = String.fromEnvironment(
    'REVIEW_ROLE_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/review-role-request',
  );

  /// Shared secret gate for the send-push function. Must equal the
  /// `PUSH_SECRET` secret set on the deployed Edge Function:
  ///   supabase secrets set PUSH_SECRET=...
  static const String pushSecret = String.fromEnvironment(
    'PUSH_SECRET',
    defaultValue: 'studenthub-dev-push-secret',
  );
}