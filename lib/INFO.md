# 📱 StudentHub Mobile Application (`lib/`)

This directory contains the entire source code for the StudentHub Flutter mobile application.

---

## 📂 Directory Layout

```
lib/
├── config/             # App configuration, theme tokens, Supabase endpoints
│   ├── app_config.dart        # Global app settings (college name, branding)
│   └── supabase_config.dart   # Supabase URL, anon key, push secrets, function URLs
│
├── models/             # Immutable data models
│   ├── post_model.dart        # Feed posts, events, polls, media attachments
│   ├── user_model.dart        # User profile, roles (student, faculty, admin), badges
│   ├── notification_model.dart# Push & in-app notifications
│   ├── role_request_model.dart# Student role elevation requests
│   └── user_role.dart         # Role enums & hierarchy
│
├── screens/            # Application views & screen flows
│   ├── auth_screen.dart       # Login, Set Password, Enter Password, Reset Password
│   ├── feed_screen.dart       # Campus feed with search, category filtering, likes
│   ├── events_screen.dart     # Campus events, RSVP, QR ticketing
│   ├── discover_screen.dart   # Campus clubs, committees, academic directory
│   ├── profile_screen.dart    # User profile, appreciation count, role requests, logout
│   ├── notifications_screen.dart # Notification bell with category filters and clear-all
│   └── progressive_form_screen.dart # Multi-step onboarding form
│
├── services/           # Business logic, state management, and backend synchronization
│   ├── mock_data_service.dart # Primary state manager (ChangeNotifier): posts, profiles, sync
│   ├── local_store_service.dart # Local cache, device ID generation, offline store
│   ├── push_service.dart      # FCM token registration & push notification routing
│   └── update_service.dart    # Over-The-Air (OTA) version checks & in-app APK installer
│
└── widgets/            # Reusable UI components
    ├── post_card.dart         # Post card with media carousels, likes, comments
    ├── post_detail_modal.dart # Full-screen post modal for deep-linking
    ├── update_modal.dart      # Rich OTA update popup with download progress
    ├── mit_id_input_field.dart# Real-time student ID format validator
    └── custom_nav_bar.dart    # Sleek bottom navigation bar
```

---

## 🔑 Key Architecture Notes
* **State Management**: Uses `Provider` (`ChangeNotifier`) centralized in `MockDataService`.
* **Offline First**: All posts and notifications are stored locally via `LocalStoreService` and updated seamlessly via Supabase Realtime channels.
* **Security & Auth**: Never stores plaintext passwords. Connects to `account-credentials` Edge Function with hardware device ID tracking.
