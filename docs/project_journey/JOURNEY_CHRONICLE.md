# 🌟 StudentHub: The Complete Development Chronicle (Day 1 to Production)

> **The definitive story, architecture breakdown, and engineering retrospective of building StudentHub — from an initial campus concept to an enterprise-grade full-stack ecosystem.**

---

## 📖 Table of Contents
1. [The Vision & Initial Concept](#1-the-vision--initial-concept)
2. [Chapter 1: UI Foundation & MVVM Architecture](#chapter-1-ui-foundation--mvvm-architecture)
3. [Chapter 2: Supabase Database, RLS & Offline-First Engine](#chapter-2-supabase-database-rls--offline-first-engine)
4. [Chapter 3: Realtime Engine, FCM Push & Cloud Edge Functions](#chapter-3-realtime-engine-fcm-push--cloud-edge-functions)
5. [Chapter 4: The Web Admin Control Center on Vercel](#chapter-4-the-web-admin-control-center-on-vercel)
6. [Chapter 5: Password Security, Single-Session & Device Binding](#chapter-5-password-security-single-session--device-binding)
7. [Chapter 6: OTA In-App Updates, Impeller & 64-Bit Split Packaging](#chapter-6-ota-in-app-updates-impeller--64-bit-split-packaging)
8. [Complete System Topology](#complete-system-topology)

---

## 1. The Vision & Initial Concept

StudentHub was conceived as a **unified digital campus operating system** to solve the fragmentation of college life — bringing together:
* **Campus Feed**: Academic notices, student posts, media attachments, and real-time appreciation/likes.
* **Events Hub**: RSVP management, countdowns, and instant QR-ticket generation.
* **Academic Directory & Discover**: Club discovery, department listings, and role applications.
* **Over-The-Air Independence**: Fast OTA APK updates directly to student phones without waiting for third-party app store approval.
* **Institutional Governance**: A dedicated, real-time Web Admin Control Center for faculty and college administrators.

---

## Chapter 1: UI Foundation & MVVM Architecture

### 1. Design System & Theme Engine
* Built a sleek, glassmorphic design language supporting both **Light Mode** and **High-Contrast Dark Mode** (`#121212` background, `#1E1E1E` elevated surfaces, `#3B82F6` electric blue accents).
* Engineered interactive micro-animations (heart pulse, like counters, smooth sheet transitions).

### 2. State & Data Layer Architecture
* Adopted the **MVVM (Model-View-ViewModel)** pattern with `Provider` (`ChangeNotifier`).
* **`MockDataService`**: Central coordinator for posts, comments, notifications, role requests, and live presence.
* **`LocalStoreService`**: Robust offline-first caching layer utilizing `SharedPreferences` to ensure instantaneous cold starts even without internet connectivity.

### 3. Progressive Onboarding & MIT ID Validation
* Created a multi-step onboarding wizard (`ProgressiveFormScreen`) with real-time student ID format validation (`MitIdInputField`), branch selectors, and graduation year pickers.

---

## Chapter 2: Supabase Database, RLS & Offline-First Engine

### 1. PostgreSQL Schema & Migrations (21 Migrations)
Structured a relational database with strict data constraints:
* **`profiles`**: User metadata, verified badges, active roles array (`student`, `faculty`, `club_lead`, `admin`), `active_device_id`, `notifications_cleared_at`.
* **`posts`**: Campus posts and events with author linkage, media arrays, category tags, and like counters.
* **`role_requests`**: Student elevation applications with approval status, expiration timestamps, and admin review notes.
* **`device_tokens`**: FCM push notification tokens indexed by `user_id` and `device_id`.
* **`broadcasts`**: Official admin announcements tagged by branch and year.
* **`profile_credentials`**: Zero-RLS protected vault for bcrypt-hashed passwords and hardware device IDs.

### 2. Row Level Security (RLS) Hardening
* Configured fine-grained policies allowing public reads for authenticated campus users while locking write/delete actions strictly to the row author or verified admins.
* Created server-side database triggers to automatically synchronize appreciation counts and prevent role tampering.

---

## Chapter 3: Realtime Engine, FCM Push & Cloud Edge Functions

### 1. Realtime Sync via Supabase Websockets
* Implemented `supabase_realtime` channels subscribing to Postgres inserts, updates, and deletes for posts, profile role changes, and admin broadcasts.
* Engineered a dual-channel sync model: persistent database row listening + instant broadcast message channels (`app_updates_realtime`).

### 2. Firebase Cloud Messaging (FCM HTTP v1)
* Transitioned from deprecated legacy FCM protocols to the modern **Google OAuth2 Service Account HTTP v1 API**.
* Deployed **7 Deno Cloud Edge Functions**:
  1. `account-credentials`: Server-side bcrypt hashing, login verification, hardware-bound resets.
  2. `send-push`: Multi-device push dispatch, branch/year target filtering, dead-token pruning.
  3. `review-role-request`: Role approval logic + instant push dispatch to the applicant.
  4. `admin-actions`: Assign roles, verify students, ban/unban bad actors.
  5. `delete-user`: Cascade user deletion and cleanup.
  6. `delete-post`: Safe post moderation and author verification.
  7. `verify-admin`: Secure admin panel sign-in verification.

---

## Chapter 4: The Web Admin Control Center on Vercel

### 1. Architecture & Standalone Repository (`admin_panel/`)
* Created an independent Flutter Web application specifically tailored for desktop screens.
* Deployed live to **Vercel** with continuous deployment and custom domain alias:
  👉 **`https://studenthub-admin-panel.vercel.app`**

### 2. Core Administration Capabilities:
* **User Directory**: View all registered students, verify MIT IDs, assign custom roles, and execute remote password resets or password wipes.
* **Role Requests Hub**: Review pending applications for Faculty or Club Lead with single-click approval and automated push notifications.
* **Broadcast Announcement Center**: Send urgent push alerts targeted to specific branches (CSE, IT, ECE) or graduation years (1st, 2nd, 3rd, 4th Year).
* **App Release Manager**: Upload new APK binaries directly to Supabase Storage and broadcast OTA update prompts to all mobile devices.

---

## Chapter 5: Password Security, Single-Session & Device Binding

### 1. The Password Protection Rollout
* Upgraded user accounts with mandatory bcrypt-hashed passwords.
* Forced legacy un-passworded accounts back to a modern setup screen upon next login.

### 2. Single-Session Enforcement (Anti-Account Sharing)
* Integrated real-time `active_device_id` rotation on the server.
* When an account logs in on Device B, Device A's background sync detects the mismatch and automatically terminates the session with an in-app security alert:
  > *"🚨 Security Alert: Someone logged into your account from another device. Previous session terminated for safety."*

### 3. Primary Device Hardware Binding (Anti-Hijacking)
* Prevented rogue classmate account takeovers by locking self-service password resets to the user's primary registered device (`created_device_id`).
* Provided College Admins with a web-based reset override for students who genuinely lost or upgraded their phone.

---

## Chapter 6: OTA In-App Updates, Impeller & 64-Bit Split Packaging

### 1. Over-The-Air Self-Updating Pipeline
* Implemented `UpdateService` with an in-app bottom sheet (`UpdateModal`) that displays version tags, release notes, and download progress.
* Created a native Android Method Channel (`student_hub/installer`) using `FileProvider` to launch the Android package installer directly.

### 2. 64-Bit ABI Optimization (`arm64-v8a`)
* Replaced bloated 83.8 MB universal APKs with lean **29.4 MB 64-bit split APKs** (`--split-per-abi`), reducing bandwidth and installation time by 65%.
* Validated full compatibility with Android's modern Impeller rendering engine.

---

## 🗺️ Complete System Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          STUDENTHUB ECOSYSTEM                               │
├──────────────────────────────────────┬──────────────────────────────────────┤
│       MOBILE APP (v1.4.2+35)         │       WEB ADMIN (Vercel Prod)        │
│  • Flutter Android (arm64-v8a)       │  • Flutter Web (Desktop UI)          │
│  • Dark Glassmorphism                │  • User Management & Verification    │
│  • Offline-First Cache Layer         │  • Remote Password Reset / Wipe      │
│  • Hardware-Locked Password Reset    │  • Branch/Year Filtered Broadcasts   │
│  • In-App OTA APK Installer          │  • APK Upload & OTA Release Dispatch │
├──────────────────────────────────────┴──────────────────────────────────────┤
│                   SUPABASE POSTGRESQL & REALTIME CLOUD                      │
│  • 21 Schema Migrations & Zero-Trust RLS Policies                           │
│  • Realtime Broadcast & Postgres Replication Channels                       │
│  • `app_releases` Public Storage Bucket                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                     7 DENO CLOUD EDGE FUNCTIONS                             │
│  • `account-credentials`  • `send-push`             • `review-role-request` │
│  • `admin-actions`        • `delete-user`           • `delete-post`         │
│  • `verify-admin`                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```
