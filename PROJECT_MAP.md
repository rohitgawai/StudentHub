# 🗺️ StudentHub Master Project Map & Quick Reference

Welcome to the **StudentHub** repository! This document serves as your single-point orientation guide to the entire codebase.

---

## 🧭 Repository Structure At a Glance

| Directory / File | Description | Documentation |
| :--- | :--- | :--- |
| **`lib/`** | Flutter Mobile Application source code (Android 64-bit). | [`lib/INFO.md`](file:///c:/Users/Rohit/StudentHub/lib/INFO.md) |
| **`admin_panel/`** | Standalone Flutter Web Admin Control Center hosted on Vercel. | [`admin_panel/INFO.md`](file:///c:/Users/Rohit/StudentHub/admin_panel/INFO.md) |
| **`supabase/`** | 21 PostgreSQL migrations & 7 Deno Serverless Edge Functions. | [`supabase/INFO.md`](file:///c:/Users/Rohit/StudentHub/supabase/INFO.md) |
| **`docs/project_journey/`** | Complete development history, all bug analyses, solutions, and future architecture guide. | [`docs/project_journey/JOURNEY_CHRONICLE.md`](file:///c:/Users/Rohit/StudentHub/docs/project_journey/JOURNEY_CHRONICLE.md) |
| **`tool/`** | CLI release automation & OTA publishing scripts. | [`tool/INFO.md`](file:///c:/Users/Rohit/StudentHub/tool/INFO.md) |
| **`android/`** | Native Android platform configuration & Gradle scripts. | Android SDK / Gradle 9 |
| **`pubspec.yaml`** | Mobile dependencies and app version definition (`1.4.2+35`). | Flutter package manifest |
| **`tsconfig.json`** | Root TypeScript configuration for Deno Edge Functions. | TypeScript Language Server |

---

## 📚 Complete Project Journey & Engineering Guides

* **📖 [Full Chronicle: Day 1 to Production](file:///c:/Users/Rohit/StudentHub/docs/project_journey/JOURNEY_CHRONICLE.md)**: The complete history of how StudentHub was planned, architected, and built across every phase.
* **🐞 [Master Bug Log & Solutions](file:///c:/Users/Rohit/StudentHub/docs/project_journey/BUGS_AND_SOLUTIONS.md)**: Deep dive into all technical hurdles (CORS, OTA updates, missing icons, password hijacking, APK sizing, TypeScript issues) with root causes and fixes.
* **🏗️ [Future Full-Stack Blueprint](file:///c:/Users/Rohit/StudentHub/docs/project_journey/FUTURE_BLUEPRINT_GUIDE.md)**: Strategic engineering rules and best practices for building scalable full-stack mobile + web + backend systems.

---

## ⚡ Quick Commands Cheatsheet

### 1. Build Split 64-bit Release APK:
```powershell
flutter build apk --release --split-per-abi --dart-define=PUSH_SECRET=studenthub-dev-push-secret
```
*Output*: `build\app\outputs\flutter-apk\StudentHub-v1.4.2-arm64-v8a-release.apk` (29.4 MB)

### 2. Deploy Web Admin Panel to Vercel:
```powershell
cd admin_panel
.\deploy.bat
```
*Live URL*: [https://studenthub-admin-panel.vercel.app](https://studenthub-admin-panel.vercel.app)

### 3. Deploy All Supabase Edge Functions:
```powershell
supabase functions deploy account-credentials --no-verify-jwt
supabase functions deploy admin-actions --no-verify-jwt
supabase functions deploy delete-post --no-verify-jwt
supabase functions deploy delete-user --no-verify-jwt
supabase functions deploy review-role-request --no-verify-jwt
supabase functions deploy send-push --no-verify-jwt
supabase functions deploy verify-admin --no-verify-jwt
```
