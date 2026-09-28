from fastapi.testclient import TestClient
from pydantic import ValidationError
import pytest

from app.main import app
from app.schemas import ReadingIn

client = TestClient(app)


def test_measurement_timestamp_requires_timezone():
    payload = {"nitrogen": 42, "phosphorus": 18, "potassium": 95,
        "unit": "mg/kg", "measured_at": "2026-09-27T10:00:00"}
    assert client.post("/v1/readings", json=payload).status_code == 422


def test_health_and_sample_reading():
    assert client.get("/health").json()["status"] == "ok"
    response = client.post("/v1/readings", json={"nitrogen": 42, "phosphorus": 18,
        "potassium": 95, "unit": "mg/kg", "source": "simulated",
        "sensor_id": "test-sensor"})
    assert response.status_code == 201
    assert response.json()["nitrogen"] == 42
    assert response.json()["unit"] == "mg/kg"
    assert response.json()["source"] == "simulated"
    assert response.json()["sensor_id"] == "test-sensor"
    assert response.json()["reading_id"]
    assert "measured_at" in response.json()
    assert "received_at" in response.json()
    reading_id = response.json()["reading_id"]
    assert client.get(f"/v1/readings/{reading_id}").json()["reading_id"] == reading_id
    listing = client.get("/v1/readings?limit=1").json()
    assert listing["total"] >= 1
    assert listing["items"][0]["reading_id"] == reading_id


def test_rejects_negative_and_unknown_units():
    base = {"nitrogen": 42, "phosphorus": 18, "potassium": 95, "unit": "mg/kg"}
    assert client.post("/v1/readings", json={**base, "nitrogen": -1}).status_code == 422
    assert client.post("/v1/readings", json={"nitrogen": 42, "phosphorus": 18,
        "potassium": 95}).status_code == 422
    assert client.post("/v1/readings", json={**base, "unit": "ppm?"}).status_code == 422
    assert client.post("/v1/readings", json={**base, "nitrogen": "42"}).status_code == 422
    assert client.post("/v1/readings", json={**base, "nitrogen": True}).status_code == 422
    malformed = client.post("/v1/readings", json={**base, "unexpected": True})
    assert malformed.status_code == 422
    assert malformed.json()["detail"] == "Request validation failed"
    assert malformed.json()["errors"]
    assert client.post("/v1/readings", content="{bad json",
        headers={"content-type": "application/json"}).status_code == 422


def test_tolerance_boundary_is_inclusive_and_reports_each_nutrient():
    reading = {"nitrogen": 42, "phosphorus": 18, "potassium": 95, "unit": "mg/kg"}
    response = client.post("/v1/validate", json={"measured": reading,
        "reference": {"nitrogen": 40, "phosphorus": 18, "potassium": 90, "unit": "mg/kg"},
        "tolerance_mg_kg": 5})
    assert response.status_code == 200
    assert response.json()["passed"] is True
    assert response.json()["nutrients"]["potassium"]["absolute_error"] == 5
    response = client.post("/v1/validate", json={"measured": reading,
        "reference": {"nitrogen": 40, "phosphorus": 18, "potassium": 90, "unit": "mg/kg"},
        "tolerance_mg_kg": 4.99})
    assert response.json()["passed"] is False


def test_tolerance_can_be_configured_per_nutrient():
    reading = {"nitrogen": 42, "phosphorus": 18, "potassium": 95, "unit": "mg/kg"}
    result = client.post("/v1/validate", json={
        "measured": reading,
        "reference": {"nitrogen": 40, "phosphorus": 18, "potassium": 90, "unit": "mg/kg"},
        "tolerances_mg_kg": {"nitrogen": 2, "phosphorus": 0, "potassium": 4},
    })
    assert result.status_code == 200
    assert result.json()["passed"] is False
    assert result.json()["nutrients"]["nitrogen"]["within_tolerance"] is True
    assert result.json()["nutrients"]["potassium"]["within_tolerance"] is False


def test_tolerance_requires_exactly_one_tolerance_configuration():
    reading = {"nitrogen": 42, "phosphorus": 18, "potassium": 95, "unit": "mg/kg"}
    base = {"measured": reading, "reference": reading}
    assert client.post("/v1/validate", json=base).status_code == 422
    assert client.post("/v1/validate", json={**base, "tolerance_mg_kg": 1,
        "tolerances_mg_kg": {"nitrogen": 1, "phosphorus": 1, "potassium": 1}}).status_code == 422


def test_cors_allows_local_flutter_web_origin():
    response = client.options("/v1/readings", headers={
        "Origin": "http://localhost:5173",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "content-type",
    })
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


def test_reading_lookup_returns_clear_not_found():
    import uuid

    response = client.get(f"/v1/readings/{uuid.uuid4()}")
    assert response.status_code == 404
    assert response.json()["detail"] == "Reading not found"
    assert response.json()["error"]["code"] == "http_404"


def test_advice_does_not_invent_rates():
    response = client.post("/v1/recommendations", json={"nitrogen": 42,
        "phosphorus": 18, "potassium": 95, "unit": "mg/kg", "crop": "Rice"})
    assert response.status_code == 200
    result = response.json()
    assert result["fertilizer_quantities"] == []
    assert result["recommendation_status"] == "insufficient_local_calibration"
    assert result["additional_information_required"]


def test_assistant_returns_insufficient_when_no_retrieval_match():
    response = client.post("/v1/assistant", json={"question": "What moon phase is best?"})
    assert response.status_code == 200
    assert response.json()["insufficient_information"] is True
    assert response.json()["answer_type"] == "insufficient_information"
    assert response.json()["provider_status"] == "knowledge_fallback"


def test_tolerance_rejects_negative_or_non_finite_inputs():
    reading = {"nitrogen": 0, "phosphorus": 18, "potassium": 95, "unit": "mg/kg"}
    payload = {"measured": reading, "reference": reading, "tolerance_mg_kg": -1}
    assert client.post("/v1/validate", json=payload).status_code == 422
    with pytest.raises(ValidationError):
        ReadingIn(nitrogen=float("nan"), phosphorus=18, potassium=95, unit="mg/kg")


def test_assistant_uses_retrieved_sources_and_returns_context(monkeypatch):
    class FakeResponse:
        def raise_for_status(self):
            return None

        def json(self):
            return {"response": "Use local, calibrated soil-test guidance."}

    class FakeClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return None

        async def post(self, url, json):
            assert url.endswith("/api/generate")
            assert "Farmer reading" in json["prompt"]
            return FakeResponse()

    monkeypatch.setattr("app.routes.httpx.AsyncClient", FakeClient)
    response = client.post("/v1/assistant", json={
        "question": "How do soil test calibration and fertilizer guidance relate?",
        "reading": {"nitrogen": 42, "phosphorus": 18, "potassium": 95, "unit": "mg/kg"},
        "crop": "Rice",
        "recommendation": {
            "crop": "Rice", "fertilizer_quantities": [],
            "nutrient_status": {
                key: {"value": value, "status": "interpretation_unavailable", "note": "Needs local calibration."}
                for key, value in {"nitrogen": 42, "phosphorus": 18, "potassium": 95}.items()
            },
            "additional_information_required": ["soil-test method"],
            "advice": ["Do not apply a rate from this reading alone."],
            "recommendation_status": "insufficient_local_calibration", "sources": [],
        },
    })
    assert response.status_code == 200
    result = response.json()
    assert result["answer_type"] == "contextual"
    assert result["provider_status"] == "ollama_generated"
    assert result["context_used"] == ["farmer_reading", "selected_crop", "backend_recommendation"]
    assert result["sources"]
    assert result["insufficient_information"] is False


def test_assistant_returns_clear_503_when_ollama_is_unavailable(monkeypatch):
    import httpx

    class OfflineClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return None

        async def post(self, *args, **kwargs):
            raise httpx.ConnectError("offline")

    monkeypatch.setattr("app.routes.httpx.AsyncClient", OfflineClient)
    response = client.post("/v1/assistant", json={
        "question": "How does soil test calibration affect fertilizer rates?"})
    assert response.status_code == 503
    assert "Ollama" in response.json()["detail"]
