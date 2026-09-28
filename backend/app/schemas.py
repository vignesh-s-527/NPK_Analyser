"""Validated HTTP request and response models."""
from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class ReadingIn(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    nitrogen: float = Field(ge=0)
    phosphorus: float = Field(ge=0)
    potassium: float = Field(ge=0)
    # mg/kg is the only supported unit until the device protocol confirms others.
    unit: Literal["mg/kg"]
    measured_at: datetime | None = None
    sensor_id: str | None = Field(default=None, min_length=1, max_length=120)
    source: Literal["device", "simulated", "manual"] | None = None
    crop: str | None = Field(default=None, min_length=1, max_length=80)
    soil_ph: float | None = Field(default=None, ge=0, le=14)
    soil_texture: str | None = Field(default=None, max_length=80)
    region: str | None = Field(default=None, max_length=120)

    @field_validator("nitrogen", "phosphorus", "potassium", mode="before")
    @classmethod
    def require_json_numbers(cls, value: object) -> object:
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError("nutrient values must be JSON numbers")
        return value

    @field_validator("crop", "soil_texture", "region", "sensor_id")
    @classmethod
    def trim_optional(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("value must not be blank")
        return trimmed

    @field_validator("measured_at")
    @classmethod
    def require_timezone_for_measurement_time(cls, value: datetime | None) -> datetime | None:
        if value is not None and value.tzinfo is None:
            raise ValueError("measured_at must include a timezone")
        return value


class ReadingOut(BaseModel):
    reading_id: UUID
    nitrogen: float
    phosphorus: float
    potassium: float
    unit: str
    measured_at: datetime
    received_at: datetime
    sensor_id: str | None = None
    source: str | None = None
    crop: str | None = None
    soil_ph: float | None = None
    soil_texture: str | None = None
    region: str | None = None


class ReadingListOut(BaseModel):
    items: list[ReadingOut]
    total: int
    limit: int
    offset: int


class NutrientTolerances(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    nitrogen: float = Field(ge=0)
    phosphorus: float = Field(ge=0)
    potassium: float = Field(ge=0)

    @field_validator("nitrogen", "phosphorus", "potassium", mode="before")
    @classmethod
    def require_json_numbers(cls, value: object) -> object:
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError("tolerance values must be JSON numbers")
        return value


class ToleranceIn(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    measured: ReadingIn
    reference: ReadingIn
    tolerance_mg_kg: float | None = Field(default=None, ge=0)
    tolerances_mg_kg: NutrientTolerances | None = None

    @field_validator("tolerance_mg_kg", mode="before")
    @classmethod
    def require_numeric_tolerance(cls, value: object) -> object:
        if value is not None and (isinstance(value, bool) or not isinstance(value, (int, float))):
            raise ValueError("tolerance must be a JSON number")
        return value

    @model_validator(mode="after")
    def require_one_tolerance_form(self) -> ToleranceIn:
        if (self.tolerance_mg_kg is None) == (self.tolerances_mg_kg is None):
            raise ValueError("Provide exactly one of tolerance_mg_kg or tolerances_mg_kg")
        return self


class NutrientToleranceOut(BaseModel):
    measured: float
    reference: float
    absolute_error: float
    tolerance_mg_kg: float
    within_tolerance: bool


class ToleranceOut(BaseModel):
    passed: bool
    nutrients: dict[str, NutrientToleranceOut]


class RecommendationIn(ReadingIn):
    soil_test_method: str | None = Field(default=None, max_length=120)
    soil_organic_matter_percent: float | None = Field(default=None, ge=0, le=100)
    field_area_ha: float | None = Field(default=None, gt=0)
    crop_stage: str | None = Field(default=None, max_length=80)
    expected_yield: float | None = Field(default=None, gt=0)
    previous_fertilizer: str | None = Field(default=None, max_length=300)
    laboratory_test: bool = False


class NutrientStatus(BaseModel):
    value: float
    status: Literal[
        "reported", "interpretation_unavailable", "below_calibrated_range",
        "within_calibrated_range", "above_calibrated_range",
    ]
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
    recommendation: RecommendationOut | None = None

    @field_validator("question")
    @classmethod
    def trim_question(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 3:
            raise ValueError("question must contain at least 3 non-space characters")
        return value

    @field_validator("crop")
    @classmethod
    def trim_crop(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("crop must not be blank")
        return value


class AssistantOut(BaseModel):
    answer: str
    sources: list[str]
    insufficient_information: bool
    answer_type: Literal["general_information", "contextual", "insufficient_information"]
    context_used: list[str]
    provider_status: Literal["ollama_generated", "knowledge_fallback"]
