# 🐞 Master Bug Log & Engineering Solutions

This document details every major technical hurdle, bug, and architectural edge case encountered during the development of StudentHub, along with the **Root Cause**, **Implemented Solution**, and **How It Could Have Been Avoided**.

---

## 📋 Table of Contents
1. [Security: Account Takeover via Password Reset](#1-security-account-takeover-via-password-reset)
2. [Notification Flooding on Fresh App Install](#2-notification-flooding-on-fresh-app-install)
3. [Flutter Web Admin Panel: Missing Icons (Box Glyphs)](#3-flutter-web-admin-panel-missing-icons-box-glyphs)
4. [CORS & Preflight (OPTIONS) Failures on Web Admin](#4-cors--preflight-options-failures-on-web-admin)
5. [OTA Update Pop-up Not Firing in Realtime](#5-ota-update-pop-up-not-firing-in-realtime)
6. [TypeScript Linter Errors in Supabase Edge Functions](#6-typescript-linter-errors-in-supabase-edge-functions)
7. [Supabase Bundler Failures on Bare NPM/JSR Imports](#7-supabase-bundler-failures-on-bare-npmjsr-imports)
8. [APK Size Bloat (80MB vs 29MB) & ABI Compatibility](#8-apk-size-bloat-80mb-vs-29mb--abi-compatibility)

---

## 1. Security: Account Takeover via Password Reset

* **The Problem**: If a classmate knew another student's registered email or phone number, they could open the login screen on their own device, hit "Forgot Password", enter a new password, and hijack the victim's account.
* **Root Cause**: The original password reset function only required knowledge of public credentials (email/phone) and did not verify the caller's hardware session.
* **Implemented Solution**:
  1. Stored the `created_device_id` in `profile_credentials` when the user originally sets their password.
  2. Enforced hardware check in `account-credentials` Edge Function: `if (createdDeviceId && createdDeviceId !== deviceId) { return 403; }`.
  3. Added an **Admin Password Reset** feature in the Web Admin Panel for legitimate users who lost their original phone.
* **Lesson & Prevention**: Never build self-service password reset using only knowledge-based credentials without 2FA (OTP) or primary device possession verification.

---

## 2. Notification Flooding on Fresh App Install

* **The Problem**: When a student reinstalled the app or logged in on a new phone, 50+ historical broadcasts from weeks ago suddenly flooded the notification bell as unread.
* **Root Cause**: The `_notificationsClearedAt` timestamp was stored exclusively in device `SharedPreferences`. A fresh install had no local timestamp and fetched all rows with `limit(50)`.
* **Implemented Solution**:
  1. Created a database migration adding `notifications_cleared_at TIMESTAMPTZ` to the Supabase `profiles` table.
  2. Updated `clearAllNotifications()` to synchronize the cleared timestamp to the user's Supabase profile.
  3. Restricted broadcast fetch to `limit(5)` with a default fallback cutoff of 48 hours.
* **Lesson & Prevention**: User-action state (like cleared notifications, read receipts, and preferences) must always be synced to the backend user profile, never left purely in local device storage.

---

## 3. Flutter Web Admin Panel: Missing Icons (Box Glyphs)

* **The Problem**: Icons on the Vercel-hosted Admin Panel rendered as blank boxes (`⌧`).
* **Root Cause**: Flutter Web's font tree-shaker pruned the Material Icons font during release compilation, and browser service workers cached the older fontless bundle.
* **Implemented Solution**:
  1. Added `--no-tree-shake-icons` flag to the web release build command.
  2. Added Google Fonts Material Icons and Material Symbols `<link>` stylesheets in `web/index.html` as an infallible browser fallback.
  3. Configured `vercel.json` with strict cache-busting headers for HTML/JS and long-term immutable caching for fonts.
* **Lesson & Prevention**: For Flutter Web production releases with dynamic icon usage, always disable font tree-shaking (`--no-tree-shake-icons`) or declare fallback web font stylesheets in `index.html`.

---

## 4. CORS & Preflight (OPTIONS) Failures on Web Admin

* **The Problem**: Admin actions (role changes, bans, password resets) failed from the browser with `CORS policy: No 'Access-Control-Allow-Origin' header present`.
* **Root Cause**: 
  1. The browser sends an HTTP `OPTIONS` preflight request before every POST request from a web domain.
  2. The Edge Functions evaluated `X-Push-Secret` before checking `req.method === 'OPTIONS'`, rejecting the preflight with 401.
  3. `ALLOWED_ORIGIN` defaulted to a placeholder (`https://your-domain.com`).
* **Implemented Solution**:
  1. Handled `req.method === 'OPTIONS'` at the top of every Edge Function:
     ```typescript
     if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
     ```
  2. Set `'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*'`.
* **Lesson & Prevention**: When building serverless endpoints consumed by web clients, always handle preflight `OPTIONS` before any authentication or secret validation.

---

## 5. OTA Update Pop-up Not Firing in Realtime

* **The Problem**: Publishing an update from the Admin Panel did not trigger the in-app update popup on active mobile devices.
* **Root Cause**:
  1. The app compared `publishedCode > currentCode`. Publishing a release with the same version code as the running app evaluated to `false`.
  2. Mobile background/foreground transitions didn't re-poll the release endpoint.
* **Implemented Solution**:
  1. Enabled dual listener: Postgres Change replication + Supabase Realtime Broadcast (`app_updates_realtime`).
  2. Added `WidgetsBindingObserver` in `HomeScreen` to automatically check for updates on app resume.
  3. Bumped app versions strictly (`pubspec.yaml` + `UpdateService`).
* **Lesson & Prevention**: Real-time OTA systems need both websocket push broadcasts and lifecycle pull checks (on launch and resume) to guarantee delivery.

---

## 6. TypeScript Linter Errors in Supabase Edge Functions

* **The Problem**: The IDE showed errors like `Cannot find name 'Deno'` and `Cannot find module 'jsr:@supabase/supabase-js'`.
* **Root Cause**: VS Code's TypeScript language server evaluated Edge Function files using standard Node.js rules instead of Deno.
* **Implemented Solution**:
  1. Created `supabase/functions/deno.d.ts` defining ambient declarations for `Deno`, `jsr:*`, and `npm:*`.
  2. Added workspace root `tsconfig.json` including all functions.
  3. Added `/// <reference path="../deno.d.ts" />` to each function entry point.
* **Lesson & Prevention**: In monorepos containing both Flutter/Dart and Deno/TypeScript, always provide dedicated `deno.d.ts` and `tsconfig.json` at the root.

---

## 7. Supabase Bundler Failures on Bare NPM/JSR Imports

* **The Problem**: `supabase functions deploy` failed with `Relative import path "@supabase/supabase-js" not prefixed with / or ./ or ../`.
* **Root Cause**: Bare imports (e.g. `import from '@supabase/supabase-js'`) without a bundler import map are rejected by the Supabase remote build runner.
* **Implemented Solution**: Used pinned JSR and npm specifiers:
  ```typescript
  import { createClient } from 'jsr:@supabase/supabase-js@2.45.0';
  import bcrypt from 'npm:bcryptjs@2.4.3';
  ```
* **Lesson & Prevention**: Always use explicit pinned URL/protocol specifiers (`jsr:...` and `npm:...`) in Supabase Edge Functions for zero-dependency remote bundling.

---

## 8. APK Size Bloat (80MB vs 29MB) & ABI Compatibility

* **The Problem**: Default `flutter build apk` produced an 83.8 MB monolithic APK containing binaries for 3 different processor architectures (x86_64, armv7, arm64).
* **Root Cause**: Universal APK packaging bundles all native C++ libraries for 32-bit and 64-bit platforms into a single file.
* **Implemented Solution**: Built split per-ABI release APKs:
  ```powershell
  flutter build apk --release --split-per-abi --dart-define=PUSH_SECRET=...
  ```
  Result: **29.4 MB 64-bit APK (`arm64-v8a`)**, reducing download size by **65%**.
* **Lesson & Prevention**: Always distribute split APKs (or Android App Bundles `.aab`) for production deployment.
