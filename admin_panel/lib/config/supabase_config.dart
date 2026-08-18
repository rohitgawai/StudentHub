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

  static const String pushFunctionUrl = String.fromEnvironment(
    'PUSH_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/send-push',
  );

  static const String deleteFunctionUrl = String.fromEnvironment(
    'DELETE_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/delete-post',
  );

  static const String reviewRoleFunctionUrl = String.fromEnvironment(
    'REVIEW_ROLE_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/review-role-request',
  );

  static const String deleteUserFunctionUrl = String.fromEnvironment(
    'DELETE_USER_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/delete-user',
  );

  /// Server-side admin verification. The admin panel logs in with email +
  /// password; this function checks the bcrypt hash and the admin role.
  static const String verifyAdminFunctionUrl = String.fromEnvironment(
    'VERIFY_ADMIN_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/verify-admin',
  );

  /// Server-side admin actions (role grants, bans, student verification).
  /// Verified by the caller's admin role in `profiles` — never by the anon
  /// key alone.
  static const String adminActionsFunctionUrl = String.fromEnvironment(
    'ADMIN_ACTIONS_FUNCTION_URL',
    defaultValue:
        'https://pdcfjkqermynsmezsyyt.supabase.co/functions/v1/admin-actions',
  );

  /// Shared secret gate for edge functions. No default value on purpose —
  /// inject at build time with --dart-define=PUSH_SECRET=... so it never
  /// ships in source. Builds without it degrade (push features skipped).
  static const String pushSecret = String.fromEnvironment('PUSH_SECRET');
}