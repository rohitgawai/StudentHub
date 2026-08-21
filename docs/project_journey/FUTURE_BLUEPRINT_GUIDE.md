# 🏗️ Full-Stack App Blueprint & Future Engineering Guide

> **A strategic engineering playbook for building large-scale, production-ready full-stack applications with Flutter, Supabase/PostgreSQL, Edge Functions, and Web Admin Centers.**

---

## 🧭 1. Architecture Checklist (Before Writing Any Code)

Before writing the first widget or database table, follow this 5-tier architectural checklist:

```
┌────────────────────────────────────────────────────────┐
│ 1. Data Modeling & Security Boundaries (PostgreSQL/RLS)│
├────────────────────────────────────────────────────────┤
│ 2. Edge Function Trust Model & Secret Management       │
├────────────────────────────────────────────────────────┤
│ 3. Client State Layer & Offline Cache Contract         │
├────────────────────────────────────────────────────────┤
│ 4. Single-Session, Auth & Device Tracking Strategy     │
├────────────────────────────────────────────────────────┤
│ 5. OTA Release Pipeline & Versioning Semantics         │
└────────────────────────────────────────────────────────┘
```

---

## 🔐 2. Authentication & Device Session Architecture

### Best Practices:
1. **Never Trust Public Client Identity**:
   * Knowledge-based verification (name + email + phone) is vulnerable to classmate/colleague impersonation.
   * Store `created_device_id` on first registration. Require hardware match or admin override for self-service resets.
2. **Active Device Tracking**:
   * Store `active_device_id` on the server profile.
   * On every client sync/heartbeat, compare local `deviceId` with server `active_device_id`.
   * If they differ, trigger a graceful auto-logout with an in-app alert informing the student of a new login.
3. **Password Security**:
   * Store passwords only as bcrypt hashes in a protected table (`profile_credentials`) that has **zero public/anon RLS policies**.
   * Perform all verification through secure serverless Edge Functions guarded by a shared server secret (`PUSH_SECRET`).

---

## ⚡ 3. Supabase Backend & Serverless Edge Functions

### Rules for Edge Functions:
1. **Always Handle Preflight First**:
   ```typescript
   if (req.method === 'OPTIONS') {
     return new Response('ok', { headers: corsHeaders });
   }
   ```
2. **Use Pinned Specifiers for Remote Bundling**:
   * Good: `import { createClient } from 'jsr:@supabase/supabase-js@2.45.0'`
   * Bad: `import { createClient } from '@supabase/supabase-js'`
3. **Graceful CORS Fallback**:
   * Set `'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*'`.
4. **Defensive Parameter Validation**:
   * Sanitize strings (`.trim().toLowerCase()`), validate required fields, and enforce password length requirements server-side before executing queries.

---

## 📱 4. Flutter Mobile & Web Client Architecture

### 1. Separation of Concerns:
* **UI Layer (`lib/screens/`, `lib/widgets/`)**: Pure presentation, styling, and local animation controllers. Never perform direct database updates in widget callbacks.
* **State / Service Layer (`lib/services/`)**: Centralizes data fetching, cache invalidation, and listeners (`ChangeNotifier`).
* **Models (`lib/models/`)**: Immutable data models with `fromJson` and `copyWith` methods.

### 2. Dual-Channel Realtime Updates:
* Combine **Postgres Change Subscriptions** (for persistent DB rows) with **Supabase Realtime Broadcasts** (for instant zero-latency push messages across web and mobile).

### 3. OTA (Over-The-Air) App Updates:
* Increment `version:` in `pubspec.yaml` (`X.Y.Z+buildNumber`) and synchronize `currentVersionCode` in `UpdateService`.
* Add `WidgetsBindingObserver` on main navigation containers to check for updates on app resume.
* Build split 64-bit APKs (`--split-per-abi`) to keep package sizes under 30 MB.

---

## 🚀 5. Production Deployment Workflow

### 1. Mobile Release:
```powershell
# 1. Update version in pubspec.yaml (e.g. 1.4.2+35)
# 2. Update version in lib/services/update_service.dart
# 3. Build split release APKs:
flutter build apk --release --split-per-abi --dart-define=PUSH_SECRET=studenthub-dev-push-secret
```

### 2. Admin Panel Release (Vercel):
```powershell
cd admin_panel
flutter build web --release --no-tree-shake-icons --dart-define=PUSH_SECRET=studenthub-dev-push-secret
cd build\web
vercel link --yes --project web --scope akai11
vercel --prod --yes --scope akai11
vercel alias set web-pearl-one-86.vercel.app studenthub-admin-panel.vercel.app --scope akai11
```

### 3. Edge Functions Deployment:
```powershell
supabase functions deploy account-credentials --no-verify-jwt
supabase functions deploy admin-actions --no-verify-jwt
supabase functions deploy delete-post --no-verify-jwt
supabase functions deploy delete-user --no-verify-jwt
supabase functions deploy review-role-request --no-verify-jwt
supabase functions deploy send-push --no-verify-jwt
supabase functions deploy verify-admin --no-verify-jwt
```
