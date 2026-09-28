# FastAPI API contract

Local base URL: `http://127.0.0.1:8000`. Nutrients must be finite, nonnegative JSON numbers with a required `unit` of `mg/kg`. No upper concentration threshold is imposed because sensor calibration is unspecified. JSON requests reject unknown fields. The backend does not convert raw sensor signals into NPK values.

## `GET /health`

```json
{"status":"ok","service":"npk-analyzer-api"}
```

## `POST /v1/readings`

Accepts separate nitrogen, phosphorus, and potassium values. `measured_at` (timezone-aware ISO-8601), `sensor_id`, `source` (`device`, `simulated`, or `manual`), `crop`, `soil_ph`, `soil_texture`, and `region` are optional metadata.

```json
{"nitrogen":42,"phosphorus":18,"potassium":95,"unit":"mg/kg","measured_at":"2026-09-27T10:00:00Z","sensor_id":"demo-01","source":"simulated"}
```

Returns HTTP 201 with a `reading_id` UUID, `measured_at`, and server `received_at`. Optional crop and soil metadata is stored with the reading. If `measured_at` is omitted, receive time is used. Readings persist in a bounded SQLite database (1,000 latest rows by default). Set `NPK_DATABASE_PATH` to select its file. This local, single-user store has no account isolation and is not suitable for a multi-user public deployment.

## `GET /v1/readings` and `GET /v1/readings/{reading_id}`

The list route accepts `limit` (1–200, default 50) and `offset` (default 0) and returns `{ "items": [...], "total": 1, "limit": 50, "offset": 0 }`. A missing ID returns 404; a malformed UUID returns 422.

## `POST /v1/validate`

Measured and reference readings both require N, P, K and unit. Supply exactly one tolerance form. Common tolerance:

```json
{"measured":{"nitrogen":42,"phosphorus":18,"potassium":95,"unit":"mg/kg"},"reference":{"nitrogen":40,"phosphorus":18,"potassium":90,"unit":"mg/kg"},"tolerance_mg_kg":5}
```

Or per-nutrient tolerance:

```json
{"measured":{"nitrogen":42,"phosphorus":18,"potassium":95,"unit":"mg/kg"},"reference":{"nitrogen":40,"phosphorus":18,"potassium":90,"unit":"mg/kg"},"tolerances_mg_kg":{"nitrogen":2,"phosphorus":1,"potassium":4}}
```

Returns the absolute error, applied tolerance and inclusive pass flag for each nutrient, plus aggregate `passed`. It compares reported values; it does not certify sensor accuracy.

## `POST /v1/recommendations`

Requires NPK and unit. Optional fields: `crop`, `crop_stage`, `region`, `soil_test_method`, `soil_ph`, `soil_organic_matter_percent`, `soil_texture`, `field_area_ha`, `expected_yield`, `previous_fertilizer`, and `laboratory_test`.

`backend/app/recommendations.py` provides a source-backed rule interface. The verified registry is empty because deployment region, sensor calibration and local soil-test method are not specified. It returns `recommendation_status: "insufficient_local_calibration"`, empty fertilizer quantities, and missing information. No deficiency/excess diagnosis or rate is inferred from concentrations alone.

## `POST /v1/assistant`

Request fields: `question`, optional `language` (`en` or `ta`), optional `reading` (NPK plus unit), `crop`, and a previous `recommendation` response.

```json
{"question":"Why do fertilizer recommendations need local soil-test calibration?","language":"en","reading":{"nitrogen":42,"phosphorus":18,"potassium":95,"unit":"mg/kg"},"crop":"Rice"}
```

The response contains `answer`, `sources`, `insufficient_information`, `answer_type` (`general_information`, `contextual`, or `insufficient_information`), `context_used`, and `provider_status` (`ollama_generated` or `knowledge_fallback`). The small attributed index is in `backend/app/knowledge.py`. With no matching passage, the API returns an insufficient-information answer without calling Ollama. With a match but unavailable Ollama, it returns HTTP 503. Prompting asks the model to stay within retrieved facts and avoid unsupported rates/citations; this is not a technical guarantee against hallucination. Source metadata is selected by retrieval and returned separately. The English knowledge passages and Tamil generation have not been evaluated.

## Errors, CORS and configuration

Validation failures use HTTP 422 with stable `detail` and field-level `errors`, without echoing submitted values. HTTP errors include string `detail` and `error.code`/`error.message`. Unexpected failures return a generic HTTP 500 body; details remain server-side. Responses include `X-Request-ID`.

- `OLLAMA_URL` defaults to `http://127.0.0.1:11434`.
- `OLLAMA_MODEL` defaults to `llama3.2:1b`.
- `CORS_ORIGIN_REGEX` defaults to HTTP(S) localhost/loopback with optional port.
- `LOG_LEVEL` defaults to `INFO`.
- `NPK_DATABASE_PATH` defaults to `backend/data/readings.sqlite3`.

Native mobile HTTP clients do not enforce browser CORS. For production, use HTTPS, authentication, narrowly scoped CORS and persistent user-scoped storage. The local SQLite store is not multi-user safe.

`backend/app/providers.py` defines optional typed image-observation and expert-messaging protocols; no upload route, image model, or expert provider is active. The image response contract labels outputs as visual observations and fixes `measures_npk=false`. A future upload route must enforce streamed content-type and size limits.

Backend tests are in `backend/tests`. From `backend/`, install dependencies with `python -m pip install -r requirements.txt`, then run `python -m pytest`.
