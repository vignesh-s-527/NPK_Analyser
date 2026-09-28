# Flutter and backend integration

## Current application behavior

The Flutter app starts with these components connected through `FarmerServices`:

- A clearly labelled simulated analyzer for development. Set `NPK_SIMULATOR=false` to turn it off. No physical BLE protocol is implemented.
- A FastAPI client for posting readings, requesting fertilizer advice and asking the agricultural assistant.
- Local SQLite storage for farms, fields, crops and soil-test history. A reading is saved locally before its backend request. If the request fails, it remains marked as unsynced in history and can be retried there.
- An English/Tamil application language selector and localized application copy.

The simulator emits synthetic values only, tagged `simulated` in local storage and in the API request. They are not device readings and are not calibrated soil results.

## Run the backend

From PowerShell:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pytest -v
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The backend uses SQLite at `backend/data/readings.sqlite3` by default. Set `NPK_DATABASE_PATH` before starting it to use a different file. It stores the latest 1,000 readings. This is single-user local storage; it does not provide accounts, authorization or cloud sync.

For a container image, build from `backend/` with `docker build -t npk-analyzer-api .`, then run it with a persistent volume such as `docker run --rm -p 8000:8000 -v npk-data:/data npk-analyzer-api`. `backend/.env.example` lists placeholder environment settings; the app reads environment variables and does not automatically load a `.env` file. The container has no authentication, so keep it behind an authenticated HTTPS service before any public deployment.

## Run the Flutter app

From the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=NPK_API_URL=http://10.0.2.2:8000
```

`NPK_API_URL` is compiled into the app:

- **Android emulator:** `http://10.0.2.2:8000`
- **Physical Android device on the same network:** `http://<computer-LAN-IP>:8000`
- **Deployed backend:** use its HTTPS URL.

The debug Android manifest allows cleartext traffic for local development. Release builds should use HTTPS. The API client has request timeouts and returns readable connection and validation errors. Soil readings remain in local history when the backend cannot be reached; use **Retry backend sync** in a reading's history menu after the connection is restored.

## Backend services

- **Readings:** `POST /v1/readings`, `GET /v1/readings`, and `GET /v1/readings/{reading_id}`. The API's SQLite store persists them locally.
- **Fertilizer advice:** `POST /v1/recommendations`. The adapter displays the backend status, missing information, general safety advice and sources. No calibrated fertilizer rate is configured, so it must not show product quantities or diagnose deficiency from these readings.
- **Agricultural assistant:** `POST /v1/assistant`. The app sends the question, selected language and latest local reading when available. The UI identifies model-generated answers and the insufficient-information fallback. A matching knowledge passage requires the configured Ollama service; without it the backend returns HTTP 503.

Set `OLLAMA_URL`, `OLLAMA_MODEL`, `CORS_ORIGIN_REGEX`, `LOG_LEVEL`, and `NPK_DATABASE_PATH` in the backend environment as needed. Never put provider credentials in Flutter or commit them to the repository.

## Device and other providers still needed

The `NpkDeviceService` interface and simulator establish the Flutter connection seam. Replacing the simulator with a real adapter requires the analyzer vendor's BLE service and characteristic UUIDs, commands, packet format, unit definition, error behavior and validated calibration procedures. N, P and K have separate measurement paths; nitrogen uses a gas sensor. No UUID, packet structure or calibration conversion is invented here.

The weather, crop-profit estimates, farming calendar, reminders, expert messaging, authentication and remote image analysis do not have active provider implementations. Farm photos are stored locally; they do not determine nutrient values. The Supabase SQL file is a draft and is not connected; enable row-level security and add owner-scoped policies before using it.

## Validation and deployment limits

Run backend tests from `backend/` and Flutter analysis/tests from the repository root. Physical BLE behavior, production authentication, deployment, and agronomic calibration still require external device specifications and validation. Do not expose the local API publicly without HTTPS, authentication, user-scoped storage and a security review.
