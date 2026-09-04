# AI Child Guardian
### Intelligent Child Safety & Emergency Monitoring System Using Artificial Intelligence

**Sprint 1 — Day 1: Project Foundation**

Team: Sana Sharon (UI/UX) · Rishima (Backend/Firebase) · Chatherine (GPS/SOS)

---

## 1. What Day 1 Delivers

A **single Flutter app** with two modes selected at login — **Parent Mode**
and **Child Mode** — sharing one codebase, one Firebase project, and one
theme. Today's build includes:

- ✅ Flutter project structure (`screens/`, `widgets/`, `services/`, `models/`)
- ✅ Purple/lavender neumorphic UI (soft shadow cards, rounded buttons)
- ✅ Login + Sign Up screen (Firebase Authentication)
- ✅ Role Selection screen (Parent / Child) with a simple parent-child link code
- ✅ Parent Dashboard (Google Map + live child marker + SOS status)
- ✅ Child Dashboard (large SOS button + live GPS tracking)
- ✅ Cloud Firestore integration (`users`, `locations`, `sos_alerts`)
- ✅ GPS location updates every 10 seconds via `geolocator`

**Not included yet (Sprint 2):** AI-based routine learning / anomaly detection.

---

## 2. Folder Structure

```
ai_child_guardian/
├── lib/
│   ├── main.dart                     # App entry point, Firebase init, auth routing
│   ├── firebase_options.dart         # Placeholder — regenerate with flutterfire CLI
│   ├── models/
│   │   ├── user_model.dart           # AppUser: role, links, link code
│   │   ├── location_model.dart       # lat/lng/timestamp
│   │   └── sos_model.dart            # SOS alert document
│   ├── screens/
│   │   ├── login_screen.dart         # Login / Sign up
│   │   ├── role_selection_screen.dart# Choose Parent or Child + link code
│   │   ├── parent_dashboard_screen.dart  # Map + stats + SOS alerts
│   │   └── child_dashboard_screen.dart   # Big SOS button + GPS tracking
│   ├── widgets/
│   │   ├── custom_button.dart        # Reusable rounded purple button
│   │   ├── custom_card.dart          # Reusable neumorphic card + StatTile
│   │   └── bottom_nav_bar.dart       # Reusable bottom navigation bar
│   ├── services/
│   │   ├── auth_service.dart         # Firebase Auth wrapper
│   │   ├── firestore_service.dart    # Firestore read/write wrapper
│   │   └── location_service.dart     # Permission + 10s GPS timer
│   └── theme/
│       └── app_theme.dart            # Colors, fonts, neumorphic decorations
└── pubspec.yaml
```

---

## 3. Firestore Data Model

| Collection    | Document ID      | Fields                                                            |
|---------------|-------------------|--------------------------------------------------------------------|
| `users`       | `{uid}`           | `uid, name, email, role (parent/child), linkedUid, linkCode`       |
| `locations`   | `{childUid}`      | `childUid, latitude, longitude, timestamp` (overwritten every 10s) |
| `sos_alerts`  | auto-generated ID | `childUid, latitude, longitude, timestamp, status (active/resolved)` |

**Parent-child linking (simple Day-1 version):** when a user signs up as a
Parent, we generate a random 6-digit `linkCode` and save it on their profile.
The Child enters that code on their Role Selection screen; we look it up,
then store each other's `uid` under `linkedUid` on both profiles.

---

## 4. How the App Flow Works

```
LoginScreen
   ├── Sign Up → RoleSelectionScreen → (Parent) → ParentDashboardScreen
   │                                 → (Child)  → ChildDashboardScreen
   └── Login    → looks up saved role → correct Dashboard directly
```

- **Parent Dashboard**: listens to `locations/{childUid}` in real time and
  moves the Google Maps marker automatically. Also listens to
  `sos_alerts` where `status == active` to show an emergency banner.
- **Child Dashboard**: on open, requests location permission, then starts a
  `Timer.periodic` (every 10 seconds) that reads GPS and writes it to
  Firestore. The SOS button grabs one fresh GPS reading and writes a new
  document to `sos_alerts`.

---

## 5. Setup Instructions (for the team)

### Step 1 — Install Flutter dependencies
```bash
flutter pub get
```

### Step 2 — Connect Firebase (Rishima)
1. Create a project at https://console.firebase.google.com
2. Enable **Authentication → Email/Password**
3. Enable **Cloud Firestore** (start in test mode for Sprint 1)
4. Install the FlutterFire CLI and run:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-project-id>
   ```
   This regenerates `lib/firebase_options.dart` with real keys —
   **do not hand-edit that file**, always use the CLI.

### Step 3 — Google Maps API key (Chatherine)
- Android: add your key to `android/app/src/main/AndroidManifest.xml`
  inside a `<meta-data android:name="com.google.android.geo.API_KEY" .../>` tag.
- iOS: add your key in `ios/Runner/AppDelegate.swift`.
- Enable **Maps SDK for Android/iOS** in Google Cloud Console.

### Step 4 — Permissions
- **Android** (`android/app/src/main/AndroidManifest.xml`): add
  `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` permissions.
- **iOS** (`ios/Runner/Info.plist`): add `NSLocationWhenInUseUsageDescription`.

### Step 5 — Run the app
```bash
flutter run
```

---

## 6. Suggested Firestore Security Rules (test-mode starter)
```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
    match /locations/{childId} {
      allow read, write: if request.auth != null;
    }
    match /sos_alerts/{alertId} {
      allow read, write: if request.auth != null;
    }
  }
}
```
> These are permissive for development. Tighten them (e.g. only a child can
> write their own location, only a linked parent can read it) before
> production — a good task for a later sprint.

---

## 7. Team Responsibilities Recap (Day 1)

| Member | Module | Files |
|---|---|---|
| **Sana Sharon** | UI/UX Design | `theme/`, `widgets/`, `screens/login_screen.dart`, `screens/role_selection_screen.dart` |
| **Rishima** | Backend & Architecture | `services/auth_service.dart`, `services/firestore_service.dart`, `models/` |
| **Chatherine** | GPS & SOS | `services/location_service.dart`, SOS button in `child_dashboard_screen.dart`, Google Map in `parent_dashboard_screen.dart` |

---

## 8. Next Steps (Sprint 2 Preview)
- AI-based routine learning (detect unusual location patterns)
- Push notifications for SOS alerts (Firebase Cloud Messaging)
- Location history + geofencing (safe zones)
- Battery level & offline-last-seen tracking
- Tightened Firestore security rules
