# AMN

AMN is a Flutter safety and vehicle-assistance app. It includes emergency services, SOS support, emergency contacts, hospital and insurance screens, parking assistance, car status, driver status, profile management, Firebase authentication, and a voice assistant.

## Features

- Firebase email/password and Google sign-in authentication
- User profile and license image upload flow
- SOS and emergency services
- Emergency contacts, numbers, history, and first aid screens
- Hospital and insurance support
- Parking map and vehicle pairing screens
- Car status, driver status, and car control screens
- Voice assistant with speech recognition and spoken replies

## Requirements

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- Firebase project configuration

Check your Flutter setup:

```bash
flutter doctor
```

## Setup

Install dependencies:

```bash
flutter pub get
```

Configure Firebase for your own project before running the app:

```bash
flutterfire configure
```

This generates local Firebase configuration files such as:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

These files are ignored by Git in this repository so private project configuration is not uploaded accidentally. If you intentionally want to publish a demo Firebase configuration, remove those entries from `.gitignore` first.

## Run

Run on Android:

```bash
flutter run -d android
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run on a detected device:

```bash
flutter run
```

## Voice Assistant

The assistant uses:

- `speech_to_text` for listening to commands
- `flutter_tts` for spoken replies

Supported example commands:

- "Call emergency"
- "Open parking map"
- "Show car status"
- "Open hospital"
- "First aid tips"
- "Help"

Make sure microphone and speech recognition permissions are enabled on the device.

## Project Structure

```text
lib/
  main.dart
  screens/
  services/
  models/
  widgets/
images/
fonts/
android/
ios/
web/
```

## Before Uploading to GitHub

Do not upload generated or local files such as:

- `.dart_tool/`
- `build/`
- `android/local.properties`
- Firebase configuration files for private projects
- Android signing files such as `android/key.properties`

The `.gitignore` file is configured to keep these files out of Git.
