# Farmer module integration

This repository contains the Flutter source and dependency manifest. Flutter/Dart must be installed. Generate the standard mobile platform folders once, then fetch packages and run on a connected device:

```sh
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

Configure Android and iOS BLE, location, photo library, microphone, and speech recognition permissions in the generated platform manifests (`AndroidManifest.xml` and `ios/Runner/Info.plist`). Flutter and Dart were unavailable in the implementation environment, so the app could not be analyzed or run there.

## Person 2 service seams

- Implement services from `lib/services/contracts.dart` and inject them through `NpkApp(services: FarmerServices(...))`. The bundle accepts NPK device, weather, crop recommendation, AI assistant, calendar, reminders, and expert dashboard implementations.
- Emit only final test events to the farmer UI. Do not expose live readings or encode a device protocol here; connect the implementation to the device protocol specification.
- Calendar events are passed to the optional reminder service for scheduling. Crop recommendations receive the selected language and latest saved NPK result when available. AI responses can include source references; the UI does not fabricate answers.
- Persist farms, fields, devices, crop selections, and successful tests using `LocalStore`. Failed test events must not be inserted. Ask before saving each successful test. Keep history scoped to fields and cascade field/farm removal into their tests.
- Add localized strings for Tamil and English and persist selected language in `profile.language`. Complete the first-launch tutorial and field/farm CRUD flows as features are wired.

## Packages

`sqflite` and `path` (local SQLite and paths), `flutter_blue_plus` (BLE adapter implementation), `image_picker` and `path_provider` (compressed photo selection and app-private storage), `geolocator` (GPS), `speech_to_text` and `flutter_tts` (assistant voice), and `flutter_local_notifications` (calendar reminder implementation).

The database schema is versioned in `lib/data/local_store.dart`; add a version bump and `onUpgrade` migration whenever the schema changes. Farm and field deletion removes associated photos and test history. No accounts, cloud storage, or sync are included.

## Integration status

Farm and field details, optional farmer name, crop selections, successful test history, notes and favorites use local SQLite. Photos are compressed on import, stored in app-private storage, and removed with their farm or field. Farm locations can be entered manually or captured with GPS. Saved device names can be added on discovery and removed in Profile; each connection remains manual. The app wiring accepts backend service implementations and expert dashboard routing through `FarmerServices`. Navigation and main page headings switch between English and Tamil; secondary dialogs and detailed screen copy still need complete translation. Voice input and spoken responses are wired to platform speech plugins and the selected language. Person 2 still needs to supply BLE, weather, recommendation, AI, calendar and reminder implementations plus platform permissions and validated agronomic classifications.
