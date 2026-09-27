from fastapi.testclient import TestClient
from pydantic import ValidationError
import pytest

from app.main import ReadingIn, app

client = TestClient(app)


def test_health_and_sample_reading():
    assert client.get("/health").json()["status"] == "ok"
    response = client.post("/v1/readings", json={"nitrogen": 42, "phosphorus": 18,
        "potassium": 95, "unit": "mg/kg"})
    assert response.status_code == 201
    assert response.json()["nitrogen"] == 42
    assert response.json()["unit"] == "mg/kg"
    assert "received_at" in response.json()


def test_rejects_negative_and_unknown_units():
    base = {"nitrogen": 42, "phosphorus": 18, "potassium": 95}
    assert client.post("/v1/readings", json={**base, "nitrogen": -1}).status_code == 422
    assert client.post("/v1/readings", json={**base, "unit": "ppm?"}).status_code == 422
    assert client.post("/v1/readings", json={**base, "unexpected": True}).status_code == 422


def test_tolerance_boundary_is_inclusive_and_reports_each_nutrient():
    reading = {"nitrogen": 42, "phosphorus": 18, "potassium": 95}
    response = client.post("/v1/validate", json={"measured": reading,
        "reference": {"nitrogen": 40, "phosphorus": 18, "potassium": 90},
        "tolerance_mg_kg": 5})
    assert response.status_code == 200
    assert response.json()["passed"] is True
    assert response.json()["nutrients"]["potassium"]["absolute_error"] == 5
    response = client.post("/v1/validate", json={"measured": reading,
        "reference": {"nitrogen": 40, "phosphorus": 18, "potassium": 90},
        "tolerance_mg_kg": 4.99})
    assert response.json()["passed"] is False


def test_advice_does_not_invent_rates():
    response = client.post("/v1/recommendations", json={"nitrogen": 42,
        "phosphorus": 18, "potassium": 95, "crop": "Rice"})
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


def test_tolerance_rejects_negative_or_non_finite_inputs():
    reading = {"nitrogen": 0, "phosphorus": 18, "potassium": 95}
    payload = {"measured": reading, "reference": reading, "tolerance_mg_kg": -1}
    assert client.post("/v1/validate", json=payload).status_code == 422
    with pytest.raises(ValidationError):
        ReadingIn(nitrogen=float("nan"), phosphorus=18, potassium=95)


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

    monkeypatch.setattr("app.main.httpx.AsyncClient", FakeClient)
    response = client.post("/v1/assistant", json={
        "question": "How do soil test calibration and fertilizer guidance relate?",
        "reading": {"nitrogen": 42, "phosphorus": 18, "potassium": 95},
        "crop": "Rice",
    })
    assert response.status_code == 200
    result = response.json()
    assert result["answer_type"] == "contextual"
    assert result["context_used"] == ["farmer_reading", "selected_crop"]
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

    monkeypatch.setattr("app.main.httpx.AsyncClient", OfflineClient)
    response = client.post("/v1/assistant", json={
        "question": "How does soil test calibration affect fertilizer rates?"})
    assert response.status_code == 503
    assert "Ollama" in response.json()["detail"]
