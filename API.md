# FastAPI contract

Base URL is `http://127.0.0.1:8000` for local development. Deploy behind HTTPS for real farmer data. JSON requests reject unknown fields. Concentrations currently use `mg/kg`; the analyzer protocol must confirm what its measurements represent before interpreting them.

## Health

`GET /health`

```json
{"status":"ok","service":"npk-analyzer-api"}
```

## Submit a reading

`POST /v1/readings` returns HTTP 201. Each nutrient must be a finite number from 0 to 100000, and unit must be `mg/kg`.

```json
{"nitrogen":42,"phosphorus":18,"potassium":95,"unit":"mg/kg"}
```

Example response:

```json
{"nitrogen":42,"phosphorus":18,"potassium":95,"unit":"mg/kg","received_at":"2026-09-27T10:00:00Z"}
```

Invalid input returns FastAPI HTTP 422 with field-level validation details. This endpoint validates and timestamps the readings; it does not calculate concentration from raw sensor signals or persist history.

## Compare against reference tolerance

`POST /v1/validate` compares each reported concentration to a reference and passes when absolute error is less than or equal to `tolerance_mg_kg`.

```json
{"measured":{"nitrogen":42,"phosphorus":18,"potassium":95},"reference":{"nitrogen":40,"phosphorus":18,"potassium":90},"tolerance_mg_kg":5}
```

The output includes per-nutrient measured value, reference, absolute error and `within_tolerance`, plus aggregate `passed`. This is a software comparison rule, not a claim about instrument accuracy.

## Fertilizer advice

`POST /v1/recommendations` accepts NPK and optional crop, region, soil-test method, soil pH, organic matter percentage, texture, crop stage, field area, prior fertilizer, and whether results came from a laboratory test. `backend/app/recommendations.py` contains the calibrated-rule interface; its verified rule registry is empty because the deployment region, sensor method and local calibration data are unknown. Until a source-backed rule matches the exact crop, region and test method, it returns no fertilizer quantities and lists missing information. A displayed NPK concentration alone cannot establish deficiency or excess.

## Agricultural assistant

`POST /v1/assistant` accepts `{ "question": "...", "language": "en", "reading": {"nitrogen":42,"phosphorus":18,"potassium":95}, "crop":"Rice" }`. Responses include `answer`, `sources`, `insufficient_information`, `answer_type` (`general_information`, `contextual`, or `insufficient_information`), and `context_used`. Retrieval uses the small, cited knowledge list in `backend/app/main.py`; generation is constrained to retrieved text and supplied farmer context. Source metadata comes from retrieval rather than model-generated citations. If no passage matches, the service returns an insufficient-information response without calling Ollama. If matching context exists but Ollama is unavailable, the service returns HTTP 503.

Set `OLLAMA_URL` (default `http://127.0.0.1:11434`) and `OLLAMA_MODEL` (default `llama3.2:1b`). Pull the model separately with `ollama pull llama3.2:1b`. Model answer quality and hardware speed have not been benchmarked. The small retrieval index is a starter knowledge base, not comprehensive local agronomy guidance.

## Actual validation status

Flutter adapter tests and Dart analysis were executed in the workspace. Backend pytest tests are present, but could not be executed in this environment because neither `python` nor `py` was runnable. Run `python -m pytest` from `backend/` in a Python 3.10+ environment before relying on the API.
