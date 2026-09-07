# 🛠️ CLI Automation & Release Tools (`tool/`)

This directory contains developer automation scripts for building and releasing StudentHub.

---

## 📂 Scripts & Utilities

### 1. `tool/release.dart`
An automated command-line tool that parses `pubspec.yaml`, automatically synchronizes `lib/services/update_service.dart`, builds release APKs, uploads them to Supabase Storage (`app_releases`), registers release metadata in `app_updates`, and broadcasts update alerts & push notifications.

#### Usage:
```powershell
# Standard Release (automatically syncs update_service.dart with pubspec.yaml)
dart run tool/release.dart --notes "Release notes here"

# Auto-bump version (simultaneously bumps pubspec.yaml AND update_service.dart)
dart run tool/release.dart --bump --notes "Bug fixes and improvements"

# Specific Version
dart run tool/release.dart --version 1.4.4+37 --notes "Feature update"

# Mandatory Force-Update Release
dart run tool/release.dart --mandatory --notes "Critical security release"
```

