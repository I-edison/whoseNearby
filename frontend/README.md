# WhoseNearby — Flutter Frontend

Modern green & off-white artisan marketplace UI built with Flutter.

## Design system

- **Colors**: Primary green scale (`#1F5D42` → `#EFF6F1`), off-white paper, amber accent, danger red
- **Typography**: Space Grotesk (display), Inter (body), IBM Plex Mono (data/labels)
- **Radius**: 10 / 14 / 18 / 24 / pill
- **Components**: Primary/Secondary/Ghost buttons, chips, avatars, cards, PIN/OTP, numpad, segmented control, bottom nav, balance card

## Project structure

```
lib/
├── main.dart                 # App entry + routes
├── theme/app_theme.dart      # Colors, typography, ThemeData
├── widgets/app_widgets.dart  # Reusable UI components
└── screens/
    ├── onboarding/           # Splash, Login, Register, Role, OTP, Location
    ├── home/                 # Shell, Feed, Artisan detail, Search
    ├── chat/                 # Messages list, Negotiation chat
    ├── wallet/               # Wallet home, PIN setup, Confirm pay
    ├── job/                  # Confirm job, Rate, Notifications
    ├── profile/              # Profile
    ├── artisan/              # Artisan dashboard
    └── extra/                # Post a job
```

## Screens included

| Flow | Screens |
|------|---------|
| Onboarding | Splash → Login → Register → Role select → OTP → Location |
| Client home | Feed (grid), Search, Artisan detail |
| Chat | Messages list, Negotiation + offer card, Start job |
| Wallet | Balance + quick actions, PIN setup, Confirm & pay |
| Job | Confirm completion (code/QR), Rate modal |
| Profile | Personal info, Become artisan CTA, Logout |
| Artisan | Dashboard (earnings + incoming requests) |
| Extra | Post a job |

## Run

```bash
cd whosenearby_flutter
flutter pub get
flutter run
```

Requires Flutter 3.16+ and Dart 3.2+.

## Notes

- All screens use the shared design tokens from `AppColors` / `AppTheme`
- Navigation is named routes defined in `main.dart`
- Bottom nav lives in `HomeShell` (IndexedStack)
- No backend — pure UI reference implementation
