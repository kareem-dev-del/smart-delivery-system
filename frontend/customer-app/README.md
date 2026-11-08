# SmartDrop Mobile App

The Flutter app provides customer shopping and ordering flows and a courier workspace. Customer and courier behavior is selected from the authenticated account role; both use the Django REST API.

## Features

- Customer registration, sign-in, product browsing, cart, checkout, and order history
- Locker station selection and order tracking
- Courier shift status, assigned delivery and return lists, locker details, and directions
- Periodic refresh of customer orders, order tracking, and courier assignments while their screens are open
- BLoC state management with API clients, services, repositories, and typed models

## Requirements

- Flutter SDK
- Android SDK and a connected Android device or emulator
- A running SmartDrop backend

## Run on an Android emulator

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Run on a physical Android device over USB

With ADB available and the device connected:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The API URL can also point to a deployed HTTPS backend when building a release. Do not ship a production build with a development or local-network URL.

## Project structure

```text
lib/
  core/          app configuration, routing, networking, and theme
  cubits/        BLoC state and event-driven UI state
  models/        typed API and domain models
  repositories/  data access abstractions
  services/      API and platform integrations
  views/         screens and reusable widgets
```

See the repository [README](../../README.md) for the full system overview and backend setup.
