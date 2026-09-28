"""HTTP routes; schemas and domain services live in separate modules."""
from __future__ import annotations

import logging
import json

import httpx
from fastapi import APIRouter, HTTPException, Query

from .config import get_settings
from .knowledge import retrieve
from .recommendations import RecommendationContext, recommend as recommend_crop
from .repository import readings
from .schemas import (
    AssistantIn, AssistantOut, ReadingIn, ReadingListOut, ReadingOut,
    RecommendationIn, RecommendationOut, ToleranceIn, ToleranceOut,
)
from .validation import compare_readings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "npk-analyzer-api"}


@router.post("/v1/readings", response_model=ReadingOut, status_code=201)
def create_reading(reading: ReadingIn) -> ReadingOut:
    return readings.add(reading)


@router.get("/v1/readings", response_model=ReadingListOut)
def list_readings(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> ReadingListOut:
    items, total = readings.list(limit=limit, offset=offset)
    return ReadingListOut(items=items, total=total, limit=limit, offset=offset)


@router.get("/v1/readings/{reading_id}", response_model=ReadingOut)
def get_reading(reading_id: str) -> ReadingOut:
    from uuid import UUID
    try:
        identifier = UUID(reading_id)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="reading_id must be a UUID") from exc
    reading = readings.get(identifier)
    if reading is None:
        raise HTTPException(status_code=404, detail="Reading not found")
    return reading


@router.post("/v1/validate", response_model=ToleranceOut)
def validate_tolerance(request: ToleranceIn) -> ToleranceOut:
    return compare_readings(request)


@router.post("/v1/recommendations", response_model=RecommendationOut)
def recommend(request: RecommendationIn) -> RecommendationOut:
    result = recommend_crop(RecommendationContext(
        nitrogen=request.nitrogen,
        phosphorus=request.phosphorus,
        potassium=request.potassium,
        unit=request.unit,
        crop=request.crop,
        region=request.region,
        soil_test_method=request.soil_test_method,
        field_area_ha=request.field_area_ha,
        expected_yield=request.expected_yield,
        crop_stage=request.crop_stage,
        soil_ph=request.soil_ph,
        soil_organic_matter_percent=request.soil_organic_matter_percent,
        soil_texture=request.soil_texture,
        previous_fertilizer=request.previous_fertilizer,
        laboratory_test=request.laboratory_test,
    ))
    return RecommendationOut(
        crop=request.crop,
        fertilizer_quantities=result.fertilizer_quantities,
        nutrient_status=result.nutrient_status,
        additional_information_required=result.additional_information_required,
        advice=result.advice,
        recommendation_status=result.recommendation_status,
        sources=result.sources,
    )


@router.post("/v1/assistant", response_model=AssistantOut)
async def assistant(request: AssistantIn) -> AssistantOut:
    passages = retrieve(request.question)
    if not passages:
        return AssistantOut(
            answer=("I do not have enough verified information to answer that safely. "
                    "Please share a soil laboratory report (including its test method), crop, "
                    "location and soil conditions, or ask a local agricultural extension adviser."),
            sources=[], insufficient_information=True,
            answer_type="insufficient_information", context_used=[],
            provider_status="knowledge_fallback",
        )
    context = "\n".join(f"[{passage.title}] {passage.text}" for passage in passages)
    farmer_context = ""
    used_context: list[str] = []
    if request.reading:
        reading = request.reading
        farmer_context += (f" Farmer reading: N {reading.nitrogen}, P {reading.phosphorus}, "
                           f"K {reading.potassium} {reading.unit}.")
        used_context.append("farmer_reading")
    if request.crop:
        farmer_context += f" Selected crop: {request.crop}."
        used_context.append("selected_crop")
    if request.recommendation:
        farmer_context += " Backend recommendation response: " + json.dumps(
            request.recommendation.model_dump(mode="json"), ensure_ascii=False,
        )
        used_context.append("backend_recommendation")
    prompt = (
        f"Answer in {'Tamil' if request.language == 'ta' else 'English'}. "
        "Use only the retrieved facts and farmer context below. Treat a supplied backend "
        "recommendation as user-provided context; explain its status and fields without adding rates. "
        "If facts are insufficient, "
        "say what is missing. Do not invent diagnoses, thresholds, fertilizer rates, or citations. "
        "Do not put citations in the answer; source references are returned separately. "
        "Distinguish general facts from what can be said about the farmer's context.\n\n"
        f"Retrieved facts:\n{context}\n\nFarmer context:{farmer_context}\n"
        f"Question: {request.question}"
    )
    settings = get_settings()
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(45, connect=2)) as client:
            response = await client.post(
                f"{settings.ollama_url}/api/generate",
                json={"model": settings.ollama_model, "prompt": prompt, "stream": False,
                      "options": {"num_ctx": 2048, "temperature": 0.2}},
            )
            response.raise_for_status()
            answer = response.json().get("response", "").strip()
        if not answer:
            raise ValueError("Empty model response")
    except (httpx.HTTPError, ValueError, KeyError) as exc:
        logger.warning("Assistant generation unavailable (%s)", type(exc).__name__)
        raise HTTPException(
            status_code=503,
            detail="Agricultural assistant is unavailable. Start Ollama and pull the configured model.",
        ) from exc
    return AssistantOut(
        answer=answer,
        sources=[f"{passage.title} - {passage.url}" for passage in passages],
        insufficient_information=False,
        answer_type="contextual" if used_context else "general_information",
        context_used=used_context,
        provider_status="ollama_generated",
    )
