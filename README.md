# IS Mixer 2026 - Information Sciences Mixer App

A Flutter-based web application built for the Information Sciences Mixer 2026. The app features a Mafia Quiz Game with role-based user management, session persistence, device locking, and anti-cheat mechanisms.

---

## 🛠 Features

* **Role-Based Authentication:**
  * **Mafia (Player):** Plays the interactive quiz game.
  * **Moderator:** Manages active players and reactivates accounts terminated due to anti-cheat triggers. Requires approval from SuperAdmin.
  * **SuperAdmin:** Approves newly registered Moderator accounts and manages full system access.
* **Anti-Cheat Integrity Guard:** Automatically detects tab switches (`visibilitychange`) or window focus loss (`blur`) during active play, terminating the player's session until a Moderator re-grants access.
* **Device & Session Locking:** Restricts single-device multi-accounting using `SharedPreferences`.
* **Real-time Firestore Backend:** Syncs user permissions, roles, and status changes instantly across devices.

---

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0 or higher)
* [Dart SDK](https://dart.dev/get-dart)
* Firebase account setup with Firestore enabled.


### 📁 Project Architecture

```text
lib/
├── models/
│   └── user_model.dart            # Data model for User entity & JSON serialization
├── screens/
│   ├── auth_screen.dart           # Login and role registration UI with TabView
│   └── dashboard_screen.dart      # Game dashboard, admin control panel & anti-cheat guards
├── services/
│   └── json_storage_service.dart  # Firestore operations, device locking, and session logic
└── main.dart                      # Main application entrypoint
```


### Quick Start

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/is_mixer.git](https://github.com/your-username/is_mixer.git)
   cd is_mixer
   flutter pub get
   flutter run -d chrome

   ```

---

## 🌿 Git & Development Workflow

We follow a structured branching strategy to maintain stability on main and dev.

### Branch Structure

**main**: Production branch (Protected via GitHub Ruleset).

**dev**: Staging/testing branch for QA validation before production release.

*feat/*: Feature branches created off dev (e.g., feat/admin-page).*Branching Guidelines for Developers
Branch off dev:

```
git checkout dev
git pull origin dev
git checkout -b feat/your-feature-name
```

**Commit changes using Conventional Commits:**

```
git add .
git commit -m "feat(auth): describe your changes clearly"
```

Push to your feature branch & create a Pull Request:

`git push origin feat/your-feature-name`Open a PR setting base: dev ← compare: feat/your-feature-name.

Once tested and verified on dev, a final PR will be submitted to `main` branch.
