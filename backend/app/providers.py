"""Optional provider interfaces; no image model or expert vendor is configured."""
from __future__ import annotations

from typing import Literal, Protocol

from pydantic import BaseModel, ConfigDict, Field


class ImageObservation(BaseModel):
    label: str
    description: str
    confidence: float = Field(ge=0, le=1)


class ImageAnalysisResult(BaseModel):
    model_name: str
    observations: list[ImageObservation]
    uncertainty: str
    limitations: list[str]
    observation_type: Literal["visual_observation"] = "visual_observation"
    measures_npk: Literal[False] = False


class ImageAnalysisProvider(Protocol):
    async def analyze(self, image_bytes: bytes, media_type: str) -> ImageAnalysisResult: ...


class ExpertSupportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    farmer_id: str
    question: str = Field(min_length=3, max_length=2000)
    reading_id: str | None = None


class ExpertSupportReceipt(BaseModel):
    provider_request_id: str
    status: Literal["submitted", "unavailable"]
    message: str


class ExpertSupportProvider(Protocol):
    async def submit(self, request: ExpertSupportRequest) -> ExpertSupportReceipt: ...
