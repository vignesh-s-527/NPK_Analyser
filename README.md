# Portable NPK soil analyzer

This repository contains a Flutter farmer application and a local FastAPI backend foundation. The backend accepts reported NPK readings, compares them against reference tolerances, provides a guarded fertilizer-advice contract, and offers an Ollama-backed assistant grounded in a small cited knowledge index.

## Backend setup (Python 3.10+)

From PowerShell:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pytest
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open `http://127.0.0.1:8000/docs`. An Android emulator can reach the host at `http://10.0.2.2:8000`; a physical device needs the computer's LAN address and firewall access. For real deployments use HTTPS, authentication, persistent storage, and restricted CORS settings. The current CORS default accepts local browser development origins only.

Optional assistant setup:

```powershell
ollama pull llama3.2:1b
$env:OLLAMA_URL = 'http://127.0.0.1:11434'
$env:OLLAMA_MODEL = 'llama3.2:1b'
```

`backend/.env.example` lists placeholder configuration values. The app reads environment variables directly and does not load `.env` files on its own. A development container can be built from `backend/` with `docker build -t npk-analyzer-api .`; mount `/data` persistently to retain SQLite readings. The API has no authentication, so do not expose it publicly without an authenticated HTTPS service and user-scoped storage.

`OLLAMA_URL`, `OLLAMA_MODEL`, `CORS_ORIGIN_REGEX`, and `LOG_LEVEL` are read from the environment. The assistant returns HTTP 503 when retrieval finds material but the configured Ollama service cannot answer. Model speed and answer quality have not been benchmarked.

## Flutter app

The Flutter app is local-first: farms, fields, crop selections, photos and soil-test history use SQLite on the device. It starts in clearly labelled simulator mode for development. The simulator values are synthetic and do not represent analyzer measurements. Disable it with `--dart-define=NPK_SIMULATOR=false` when a real, vendor-documented BLE adapter is supplied.

The API client is wired into soil reading submission, fertilizer advice and the agricultural assistant. Configure the API base address with `--dart-define=NPK_API_URL=...`; the default `http://10.0.2.2:8000` is for an Android emulator. A physical phone must use the computer's reachable LAN address during local development. The debug Android manifest permits cleartext traffic for that local setup only; release builds should use HTTPS.

Run the mobile app from the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=NPK_API_URL=http://10.0.2.2:8000
```

## Limits and data handling

- Supported unit is `mg/kg`; no raw electrical sensor conversion is implemented.
- Backend readings persist in a bounded local SQLite database at `backend/data/readings.sqlite3` by default. Set `NPK_DATABASE_PATH` to choose another file. The store has no account or user isolation and is not suitable for a multi-user public deployment.
- Flutter readings remain available offline. Failed backend submissions stay in the local history marked unsynced, with a manual retry action.
- The calibrated recommendation registry is empty. Recommendations remain unavailable until region, crop, soil-test method and measurement calibration are validated.
- Supabase is a schema draft only. There is no cloud sync, authentication or active RLS configuration.
- No image classifier or expert messaging provider is configured. Flutter photo storage does not determine NPK.

## Tests

Backend tests are in `backend/tests`; run `python -m pip install -r requirements.txt` and then `python -m pytest -v` from `backend/`. Flutter tests and static analysis run from the repository root with `flutter test` and `flutter analyze`.

See [API.md](API.md) for endpoint contracts and [INTEGRATION.md](INTEGRATION.md) for component status and integration assumptions.

## Local farming tools

Farmer-entered farming calendar tasks and terrace gardening checklist/preferences are stored in the device SQLite database. Calendar reminders are local notifications; there is no push provider or task synchronization. The “Crops in demand” screen reports demand data as unavailable until a market feed is configured. Expert support currently shows the backend requirements and does not display demo farmer requests. See [INTEGRATION.md](INTEGRATION.md) for limitations.
