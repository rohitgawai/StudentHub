# 💻 StudentHub Web Admin Control Center (`admin_panel/`)

This directory contains the standalone Flutter Web administration control panel hosted live on Vercel.

---

## 🌐 Live URL
* **Primary URL**: [https://studenthub-admin-panel.vercel.app](https://studenthub-admin-panel.vercel.app)
* **Vercel Project Scope**: `akai11/web`

---

## 📂 Directory Layout

```
admin_panel/
├── lib/
│   ├── config/
│   │   └── supabase_config.dart     # Backend URLs & Edge Function endpoints
│   ├── models/
│   │   ├── admin_user_model.dart    # User directory models & role definitions
│   │   └── role_request_model.dart  # Student role applications
│   ├── screens/
│   │   ├── admin_login_screen.dart     # Secure admin login with bcrypt verification
│   │   ├── admin_shell_screen.dart     # Master sidebar navigation shell
│   │   ├── admin_dashboard_screen.dart # Overview analytics (active users, posts, alerts)
│   │   ├── user_directory_screen.dart  # Manage students, assign roles, reset/wipe passwords
│   │   ├── role_requests_screen.dart   # Review, approve, or reject student role requests
│   │   ├── broadcast_announcement_screen.dart # Send campus-wide or branch-filtered alerts
│   │   ├── moderation_screen.dart      # Review flagged posts and moderate content
│   │   └── admin_releases_screen.dart  # Upload split APKs & trigger OTA broadcasts
│   ├── services/
│   │   └── admin_supabase_service.dart # Realtime presence, queries, and Edge Function caller
│   └── theme/
│       └── admin_theme.dart            # Premium dark glassmorphic design system tokens
│
├── web/
│   ├── index.html                      # Includes Google Fonts Material Icons fallback
│   └── vercel.json                     # Cache-busting and font CORS headers
│
└── deploy.bat                          # 1-Click automated build & Vercel deployment script
```

---

## 🚀 1-Click Deployment
To deploy any updates to the live Vercel production server:
```powershell
.\deploy.bat
```
*(Automatically builds Flutter Web with `--no-tree-shake-icons`, injects the shared secret, links Vercel, and aliases to `studenthub-admin-panel.vercel.app`).*
