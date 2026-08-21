# ☁️ Supabase Backend & Cloud Edge Functions (`supabase/`)

This directory contains the database schema migrations, Row Level Security (RLS) rules, and Deno Cloud Edge Functions for the StudentHub ecosystem.

---

## 📂 Directory Layout

```
supabase/
├── migrations/         # 21 Sequential PostgreSQL schema migration scripts
│   ├── 20260808180000_push_log.sql              # FCM push notification dispatch logging
│   ├── 20260809000000_profiles.sql              # User profiles, verification, MIT IDs
│   ├── 20260809000001_role_requests.sql         # Role application workflow
│   ├── 20260809000002_device_tokens.sql         # Device token registry for push
│   ├── 20260809020000_form_submissions.sql      # Student onboarding submissions
│   ├── 20260809030000_posts_missing_columns.sql # Media attachments & post fields
│   ├── 20260810000000_user_auth_and_academic_info.sql # Academic credentials
│   ├── 20260810120000_admin_broadcasts.sql      # Campus announcements
│   ├── 20260810130000_reported_posts.sql        # Content moderation queue
│   ├── 20260818000000_guard_profiles_roles.sql  # RLS protection against role tampering
│   ├── 20260818010000_harden_anon_policies.sql  # Zero-trust RLS hardening
│   ├── 20260819000000_seed_admin_account.sql    # Admin credentials seeding
│   ├── 20260819010000_profile_appreciations.sql # Like/appreciation triggers
│   ├── 20260820120000_app_updates.sql           # OTA releases table & storage bucket
│   └── 20260821140000_notifications_cleared.sql # Server-persisted cleared notification timestamp
│
├── functions/          # 7 Production Deno Serverless Edge Functions
│   ├── account-credentials/   # Bcrypt password hashing, verification, hardware reset
│   ├── admin-actions/         # Role assignment, student verification, bans
│   ├── delete-post/           # Secure post deletion with author check
│   ├── delete-user/           # User deletion and cascade cleanup
│   ├── review-role-request/   # Role request review + applicant push alert
│   ├── send-push/             # FCM HTTP v1 multi-device push notification engine
│   ├── verify-admin/          # Secure admin login verification
│   ├── deno.d.ts              # Global TypeScript declarations for IDE & Deno
│   └── deno.json              # Deno runtime compiler & linter options
│
└── config.toml         # Supabase CLI project configuration
```

---

## 🚀 Edge Functions Deployment Commands

To deploy all functions live to Supabase:
```powershell
supabase functions deploy account-credentials --no-verify-jwt
supabase functions deploy admin-actions --no-verify-jwt
supabase functions deploy delete-post --no-verify-jwt
supabase functions deploy delete-user --no-verify-jwt
supabase functions deploy review-role-request --no-verify-jwt
supabase functions deploy send-push --no-verify-jwt
supabase functions deploy verify-admin --no-verify-jwt
```

To apply new database migrations:
```powershell
supabase db push
```
