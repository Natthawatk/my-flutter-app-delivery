# My Delivery App - Flutter

Flutter mobile application for delivery service with real-time tracking.

## Features

- 📱 User registration and authentication
- 📦 Create and track deliveries
- 🚚 Rider dashboard with job management
- 🗺️ Real-time GPS tracking with Longdo Map
- 📸 Photo capture for delivery proof
- 📍 Address management

## Tech Stack

- **Flutter** 3.27.1
- **Dart** ^3.8.1
- **Backend API:** https://my-node-app-lvf0.onrender.com

## Dependencies

- `http` - API communication
- `shared_preferences` - Local storage
- `image_picker` - Camera integration
- `geolocator` - GPS location
- `webview_flutter` - Map integration

## Getting Started

### Prerequisites

- Flutter SDK 3.27.1 or higher
- Android Studio / Xcode
- Android SDK / iOS SDK

### Installation

1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/my-delivery-app-flutter.git
cd my-delivery-app-flutter
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

### Build APK

```bash
flutter build apk --release
```

APK will be available at: `build/app/outputs/flutter-apk/app-release.apk`

## GitHub Actions

This project includes automated APK building via GitHub Actions.

- **Automatic build:** Triggers on push to `main` branch
- **Manual build:** Go to Actions tab → "Build Flutter APK" → Run workflow
- **Download APK:** Check Artifacts section after build completes

## API Configuration

API endpoint is configured in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'https://my-node-app-lvf0.onrender.com/api';
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screen/                   # All screens
│   ├── login.dart
│   ├── register_user.dart
│   ├── user_dashboard.dart
│   ├── rider_dashboard.dart
│   ├── deliveries.dart
│   ├── new_delivery.dart
│   ├── track_package.dart
│   └── ...
├── services/
│   └── api_service.dart      # API communication
└── widgets/                  # Reusable widgets
    ├── custom_bottom_nav.dart
    ├── rider_bottom_nav.dart
    └── longdo_map.dart

```

## License

MIT License

## Author

Natthawat K.
