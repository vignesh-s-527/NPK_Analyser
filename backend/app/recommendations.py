"""Extension point for soil-test rules calibrated to a crop, region and method.

There are deliberately no bundled rate tables: the project does not specify a
deployment region or a calibrated analyzer/soil-test method. Adding a rule
requires a primary regional source and validation evidence.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class RecommendationContext:
    nitrogen: float
    phosphorus: float
    potassium: float
    unit: str
    crop: str | None
    region: str | None
    soil_test_method: str | None
    field_area_ha: float | None
    expected_yield: float | None
    crop_stage: str | None
    soil_ph: float | None
    soil_organic_matter_percent: float | None
    soil_texture: str | None
    previous_fertilizer: str | None
    laboratory_test: bool


@dataclass(frozen=True)
class RecommendationResult:
    fertilizer_quantities: list[dict]
    nutrient_status: dict[str, dict]
    additional_information_required: list[str]
    advice: list[str]
    recommendation_status: str
    sources: list[str]


class CalibratedRecommendationRule(Protocol):
    """Rules must check exact crop, region and test method before advising."""

    def supports(self, context: RecommendationContext) -> bool: ...

    def evaluate(self, context: RecommendationContext) -> RecommendationResult: ...


# Populate only with reviewed, source-backed local calibration rules.
VERIFIED_RULES: tuple[CalibratedRecommendationRule, ...] = ()


def recommend(
    context: RecommendationContext,
    rules: tuple[CalibratedRecommendationRule, ...] = VERIFIED_RULES,
) -> RecommendationResult:
    for rule in rules:
        if (context.laboratory_test and context.crop and context.region
                and context.soil_test_method and rule.supports(context)):
            return rule.evaluate(context)

    missing = ["validated local crop and soil-test calibration"]
    if not context.crop:
        missing.append("target crop and expected yield")
    if not context.region:
        missing.append("growing region")
    if not context.soil_test_method:
        missing.append("soil-test method")
    if not context.laboratory_test:
        missing.append("validated laboratory soil-test result")
    if context.soil_ph is None:
        missing.append("soil pH")
    if context.soil_organic_matter_percent is None:
        missing.append("soil organic matter")
    if not context.soil_texture:
        missing.append("soil texture")
    if context.field_area_ha is None:
        missing.append("field area")
    if context.expected_yield is None:
        missing.append("expected yield")
    if not context.previous_fertilizer:
        missing.append("nutrient credits from prior fertilizer, manure and residues")
    nutrients = {
        name: {
            "value": value,
            "status": "interpretation_unavailable",
            "note": "A concentration alone cannot establish deficiency or excess without the test method and local crop calibration.",
        }
        for name, value in {
            "nitrogen": context.nitrogen,
            "phosphorus": context.phosphorus,
            "potassium": context.potassium,
        }.items()
    }
    return RecommendationResult(
        fertilizer_quantities=[],
        nutrient_status=nutrients,
        additional_information_required=missing,
        advice=[
            "Do not apply a fertilizer rate from this reading alone.",
            "Use a locally calibrated soil laboratory report and crop-specific regional guidance.",
            "If a laboratory report flags a nutrient as excessive, avoid adding that nutrient until a qualified local adviser reviews it.",
        ],
        recommendation_status="insufficient_local_calibration",
        sources=[
            "https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/can-soil-health-tests-determine-fertilizer-needs",
            "https://www.fao.org/4/ar118e/ar118e.pdf",
        ],
    )
