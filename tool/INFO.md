# 🛠️ CLI Automation & Release Tools (`tool/`)

This directory contains developer automation scripts for building and releasing StudentHub.

---

## 📂 Scripts & Utilities

### 1. `tool/release.dart`
An automated command-line tool that parses `pubspec.yaml`, builds release APKs, uploads them to Supabase Storage (`app_releases`), inserts release metadata into the `app_updates` table, and broadcasts update alerts to all active mobile devices.

#### Usage:
```powershell
# Standard Release
dart run tool/release.dart

# Custom Release Notes
dart run tool/release.dart --notes "Added event ticketing fixes and dark mode updates"

# Mandatory Force-Update Release
dart run tool/release.dart --mandatory --notes "Critical security release"
```
