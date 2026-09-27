# NPK Analyzer farmer app and backend

This repository contains the Flutter farmer application and an optional FastAPI service. The app can keep farm, field, photo and soil-test history on-device. Backend calls provide schema-validated reading intake, a numerical tolerance check, conservative fertilizer-advice responses, and an Ollama-backed retrieval assistant.

## Requirements

- Flutter 3.24+ / Dart 3.3+
- Python 3.10+ and pip for the API
- Ollama is optional; the AI endpoint requires it to be running
- Android or iOS device for native BLE, GPS, speech and local database features

## Run the backend

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open `http://127.0.0.1:8000/docs` for the interactive API. On an Android emulator, use `http://10.0.2.2:8000`; on a physical device, use the computer's LAN address. Production deployments must use HTTPS. Set `OLLAMA_URL` and `OLLAMA_MODEL` when Ollama is not at its default local address/model. Pull the model separately with `ollama pull llama3.2:1b`.

## Run the Flutter app

```powershell
flutter pub get
flutter run --dart-define=NPK_API_URL=http://10.0.2.2:8000 --dart-define=NPK_SIMULATOR=true
```

The simulator emits a demonstration reading (N 42, P 18, K 95 mg/kg) and must not be treated as a field measurement. Omit `NPK_SIMULATOR=true` to disable fake sensor data. A production BLE adapter cannot be configured until the analyzer vendor supplies its service/characteristic UUIDs, command format, packet layout, units and measurement calibration. Backend calls can be disabled from the integration by omitting the backend service wiring in `lib/main.dart`.

## Test and analyze

```powershell
flutter analyze
flutter test
cd backend
python -m pip install -r requirements.txt
python -m pytest
```

In this workspace, the Flutter adapter tests passed (3 tests) and Dart analysis reported no issues. Backend pytest tests were added but not run because the available Windows `python` and `py` launchers could not execute. Do not treat the backend as runtime-verified until `python -m pytest` and API startup have been run in a Python 3.10+ environment.

## Data and limitations

Farm data and history currently remain in local SQLite. No authentication, cloud sync, account management, expert inbox, push reminders, or remote image analysis is implemented. Supabase is optional; see `supabase/schema.sql` for a starting schema, not a deployed integration. Photos are stored locally and are not NPK measurements. Fertilizer quantities remain empty until soil-test methods and crop/region calibration data are added and reviewed. Readings submitted to the API are echoed with a timestamp; the backend does not derive NPK from raw sensor electrical values because the hardware calibration is not specified.

See [API.md](API.md), [BLE.md](BLE.md) and [INTEGRATION.md](INTEGRATION.md) for contracts and component boundaries.
