---
name: flutter-apply-architecture-best-practices
description: Architects a Flutter application using the recommended layered approach (UI, Logic, Data). Use when structuring a new project or refactoring for scalability.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 20:11:20 GMT
---
# Architecting Flutter Applications

## Contents
- [Architectural Layers](#architectural-layers)
- [Project Structure](#project-structure)
- [Workflow: Implementing a New Feature](#workflow-implementing-a-new-feature)
- [Examples](#examples)

## Architectural Layers

Enforce strict Separation of Concerns by dividing the application into distinct layers. Never mix UI rendering with business logic or data fetching.

### UI Layer (Presentation)
Implement the MVVM (Model-View-ViewModel) pattern to manage UI state and logic.
*   **Views:** Write reusable, lean widgets. Restrict logic in Views to UI-specific operations (e.g., animations, layout constraints, simple routing). Pass all required data from the ViewModel.
*   **ViewModels:** Manage UI state and handle user interactions. Extend `ChangeNotifier` (or use `Listenable`) to expose state. Expose immutable state snapshots to the View. Inject Repositories into ViewModels via the constructor.

### Data Layer
Abstract external dependencies and APIs behind clear interfaces.
*   **Data Sources:** Directly interact with external services (e.g., REST APIs, SQLite, Supabase, Firebase, WebSockets). Handle serialization/deserialization here. Return typed DTOs (Data Transfer Objects) or primitives.
*   **Repositories:** Mediate between Data Sources and the rest of the application. Encapsulate business logic related to caching, sync, and offline-first strategies. Convert DTOs to domain Entities before returning them.

## Project Structure

Organize files by feature to encapsulate domain boundaries, rather than purely by layer.

```
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── errors/
│   ├── services/
│   └── utils/
├── models/
├── screens/
├── services/
└── widgets/
```
