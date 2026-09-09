# News HITL Publisher - Mobile Application (Flutter)

A cross-platform mobile client built with **Flutter 3.x+**, **Bloc pattern**, and **Dio** for human-in-the-loop review, editing, and publishing of AI-rewritten news drafts.

---

## Features

- **Pending Review Inbox**: Pull-to-refresh list of all articles currently in `PENDING` state with thumbnail image, source badge, and timestamp.
- **Original vs AI Side-by-Side Comparison**: Tabbed interface allowing editorial staff to inspect raw scraped content against the LLM's suggested headlines and 2-paragraph summaries.
- **Inline Headline & Body Editor**: Modify title and body before dispatching to target platforms.
- **Multi-Platform Destination Toggles**: Selectively broadcast to **Telegram Channel** and/or **WordPress REST API** via interactive checkboxes.
- **Human Decision Triggers**:
  - **Approve & Publish**: Dispatches edited payload to n8n webhook and updates database status.
  - **Reject**: Prompts confirmation dialog, marks draft as `REJECTED`, and archives the item.
- **Cleartext HTTP Support**: Pre-configured in `AndroidManifest.xml` and `Info.plist` for instant VPS IP testing without domain or SSL restrictions.
- **Runtime Host Configuration**: Settings menu allows changing the n8n host IP/URL directly inside the app without rebuilding.

---

## Project Structure

```
mobile/
├── android/
│   └── app/src/main/AndroidManifest.xml   # usesCleartextTraffic="true" + INTERNET permission
├── ios/
│   └── Runner/Info.plist                  # NSAllowsArbitraryLoads = true
├── lib/
│   ├── core/
│   │   ├── constants/api_constants.dart   # Endpoints & default base URLs
│   │   ├── network/dio_client.dart        # Dio client with SharedPreferences base URL loader
│   │   └── theme/app_theme.dart           # Modern Material 3 Dark/Light themes
│   ├── models/
│   │   └── news_draft.dart                # NewsDraft model matching Postgres schema
│   ├── repositories/
│   │   └── news_repository.dart           # GET /news-pending and POST /news-action
│   ├── bloc/
│   │   ├── pending_news/                  # Pending list BLoC (load, refresh, remove item)
│   │   └── review_action/                 # Review action BLoC (approve, reject, feedback)
│   ├── ui/
│   │   ├── widgets/
│   │   │   ├── draft_card.dart            # List card item with image thumbnail & badges
│   │   │   └── platform_selector.dart     # Target platform checkboxes
│   │   └── screens/
│   │       ├── pending_news_screen.dart   # Main review inbox
│   │       ├── review_detail_screen.dart  # Edit & publish detail screen
│   │       └── settings_screen.dart       # Runtime VPS IP / URL editor
│   └── main.dart                          # App entry point
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Getting Started

### 1. Prerequisites
- Flutter SDK (v3.10.0 or higher)
- Android Studio / Xcode for emulators or devices

### 2. Install Dependencies
```bash
cd mobile
flutter pub get
```

### 3. Run the App
- **Android Emulator**:
  ```bash
  flutter run
  ```
  *(Default base URL `http://10.0.2.2:5678` automatically points to localhost:5678 of your development machine).*

- **Physical Device or Remote VPS**:
  Run the app and tap the **Settings icon (⚙️)** in the top right of the app bar. Enter your VPS IP (e.g. `http://<YOUR_VPS_IP>:5678`) and tap **Save & Apply**.
