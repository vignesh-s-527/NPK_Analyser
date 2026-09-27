"""NPK analyzer API. Concentrations are reported by the analyzer; this API does not infer them."""
from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Literal

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from .recommendations import RecommendationContext, recommend as recommend_crop

app = FastAPI(title="NPK Analyzer API", version="1.0.0", description="Validated NPK readings and conservative advisory services")


class ReadingIn(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    nitrogen: float = Field(ge=0, le=100000)
    phosphorus: float = Field(ge=0, le=100000)
    potassium: float = Field(ge=0, le=100000)
    unit: Literal["mg/kg"] = "mg/kg"
    crop: str | None = Field(default=None, min_length=1, max_length=80)
    soil_ph: float | None = Field(default=None, ge=0, le=14)
    soil_texture: str | None = Field(default=None, max_length=80)
    region: str | None = Field(default=None, max_length=120)

    @field_validator("crop", "soil_texture", "region")
    @classmethod
    def trim_optional(cls, value: str | None) -> str | None:
        return value.strip() if value is not None else None


class ReadingOut(BaseModel):
    nitrogen: float
    phosphorus: float
    potassium: float
    unit: str
    received_at: datetime


class ToleranceIn(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    measured: ReadingIn
    reference: ReadingIn
    tolerance_mg_kg: float = Field(ge=0, le=100000)


class ToleranceOut(BaseModel):
    passed: bool
    tolerance_mg_kg: float
    nutrients: dict[str, dict[str, float | bool]]


class RecommendationIn(ReadingIn):
    soil_test_method: str | None = Field(default=None, max_length=120)
    soil_organic_matter_percent: float | None = Field(default=None, ge=0, le=100)
    field_area_ha: float | None = Field(default=None, gt=0, le=100000)
    crop_stage: str | None = Field(default=None, max_length=80)
    previous_fertilizer: str | None = Field(default=None, max_length=300)
    laboratory_test: bool = False


class NutrientStatus(BaseModel):
    value: float
    status: Literal["reported", "interpretation_unavailable", "below_calibrated_range", "within_calibrated_range", "above_calibrated_range"]
    note: str


class RecommendationOut(BaseModel):
    crop: str | None
    fertilizer_quantities: list[dict] = Field(default_factory=list)
    nutrient_status: dict[str, NutrientStatus]
    additional_information_required: list[str]
    advice: list[str]
    recommendation_status: Literal["available", "insufficient_local_calibration"]
    sources: list[str]


class AssistantIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    question: str = Field(min_length=3, max_length=1500)
    language: Literal["en", "ta"] = "en"
    reading: ReadingIn | None = None
    crop: str | None = Field(default=None, max_length=80)


class AssistantOut(BaseModel):
    answer: str
    sources: list[str]
    insufficient_information: bool
    answer_type: Literal["general_information", "contextual", "insufficient_information"]
    context_used: list[str]


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "npk-analyzer-api"}


@app.post("/v1/readings", response_model=ReadingOut, status_code=201)
def create_reading(reading: ReadingIn) -> ReadingOut:
    return ReadingOut(nitrogen=reading.nitrogen, phosphorus=reading.phosphorus,
                      potassium=reading.potassium, unit=reading.unit,
                      received_at=datetime.now(timezone.utc))


@app.post("/v1/validate", response_model=ToleranceOut)
def validate_tolerance(request: ToleranceIn) -> ToleranceOut:
    nutrients: dict[str, dict[str, float | bool]] = {}
    for name in ("nitrogen", "phosphorus", "potassium"):
        measured = getattr(request.measured, name)
        reference = getattr(request.reference, name)
        delta = abs(measured - reference)
        nutrients[name] = {"measured": measured, "reference": reference,
                           "absolute_error": delta,
                           "within_tolerance": delta <= request.tolerance_mg_kg}
    return ToleranceOut(passed=all(item["within_tolerance"] for item in nutrients.values()),
                        tolerance_mg_kg=request.tolerance_mg_kg, nutrients=nutrients)


@app.post("/v1/recommendations", response_model=RecommendationOut)
def recommend(request: RecommendationIn) -> RecommendationOut:
    """Use only a registered, exact crop/region/method calibration rule."""
    result = recommend_crop(RecommendationContext(
        nitrogen=request.nitrogen, phosphorus=request.phosphorus,
        potassium=request.potassium, unit=request.unit, crop=request.crop,
        region=request.region, soil_test_method=request.soil_test_method,
        field_area_ha=request.field_area_ha, soil_ph=request.soil_ph,
        soil_organic_matter_percent=request.soil_organic_matter_percent,
        soil_texture=request.soil_texture,
        previous_fertilizer=request.previous_fertilizer,
        laboratory_test=request.laboratory_test,
    ))
    return RecommendationOut(crop=request.crop,
        fertilizer_quantities=result.fertilizer_quantities,
        nutrient_status=result.nutrient_status,
        additional_information_required=result.additional_information_required,
        advice=result.advice,
        recommendation_status=result.recommendation_status,
        sources=result.sources)


KNOWLEDGE = [
    ("soil test fertilizer rate crop calibration test method extraction local", "Fertilizer rates should be based on standard soil tests and fertilizer guidelines correlated and calibrated for the local region and crop. Soil type, pH, precipitation, temperature, organic matter, rotation and parent material can affect nutrient availability.", "University of Minnesota Extension - Can soil health tests determine fertilizer needs", "https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/can-soil-health-tests-determine-fertilizer-needs"),
    ("fertilizer label nutrient concentration N P K phosphorus oxide potassium oxide rate", "Fertilizer labels list nutrient percentages. To calculate product amount, a valid soil-test and crop guideline must first establish nutrient need; divide nutrient amount needed by the nutrient fraction in the product. N-P-K label conventions may express phosphorus as P2O5 and potassium as K2O.", "University of Minnesota Extension - Interpreting soil tests for fruit and vegetable crops", "https://extension.umn.edu/agriculture/specialty-crops/interpreting-soil-tests-for-fruit-and-vegetable-crops"),
    ("soil sample laboratory pH organic matter test report", "A laboratory soil test helps determine soil nutrient levels, pH and organic matter and supports decisions about whether to apply nutrients or amendments. Follow the laboratory's sampling instructions and local recommendations.", "University of Minnesota Extension — Soil testing for lawns and gardens", "https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/soil-testing-for-lawns-and-gardens"),
]


def retrieve(question: str) -> list[tuple[str, str, str]]:
    tokens = {word.lower().strip(".,?!") for word in question.split() if len(word) > 2}
    ranked = sorted(((len(tokens & set(key.split())), text, title, url) for key, text, title, url in KNOWLEDGE), reverse=True)
    return [(text, title, url) for score, text, title, url in ranked[:2] if score >= 2]


@app.post("/v1/assistant", response_model=AssistantOut)
async def assistant(request: AssistantIn) -> AssistantOut:
    passages = retrieve(request.question)
    if not passages:
        return AssistantOut(answer="I do not have enough verified information to answer that safely. Please share a soil laboratory report (including its test method), crop, location and soil conditions, or ask a local agricultural extension adviser.", sources=[], insufficient_information=True, answer_type="insufficient_information", context_used=[])
    context = "\n".join(f"[{title}] {text}" for text, title, _ in passages)
    reading = request.reading
    farmer_context = (f" Farmer reading: N {reading.nitrogen}, P {reading.phosphorus}, K {reading.potassium} {reading.unit}." if reading else "")
    if request.crop:
        farmer_context += f" Selected crop: {request.crop}."
    prompt = ("Answer in " + ("Tamil" if request.language == "ta" else "English") +
              ". Use only the retrieved facts and farmer context below. If facts are insufficient, say what is missing. Do not invent diagnoses, thresholds, fertilizer rates, or citations. Do not put citations in the answer; source references are returned separately. Distinguish general facts from what can be said about the farmer's context.\n\nRetrieved facts:\n" + context +
              "\n\nFarmer context:" + farmer_context + "\nQuestion: " + request.question)
    ollama_url = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")
    model = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(45, connect=2)) as client:
            response = await client.post(f"{ollama_url}/api/generate", json={"model": model, "prompt": prompt, "stream": False, "options": {"num_ctx": 2048, "temperature": 0.2}})
            response.raise_for_status()
            answer = response.json().get("response", "").strip()
        if not answer:
            raise ValueError("Empty model response")
    except (httpx.HTTPError, ValueError, KeyError) as exc:
        raise HTTPException(status_code=503, detail="Agricultural assistant is unavailable. Start Ollama and pull the configured model.") from exc
    used_context = []
    if request.reading:
        used_context.append("farmer_reading")
    if request.crop:
        used_context.append("selected_crop")
    return AssistantOut(answer=answer,
        sources=[f"{title} - {url}" for _, title, url in passages],
        insufficient_information=False,
        answer_type="contextual" if used_context else "general_information",
        context_used=used_context)
