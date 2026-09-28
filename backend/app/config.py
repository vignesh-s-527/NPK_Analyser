"""Environment-backed settings; safe local defaults contain no secrets."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    ollama_url: str
    ollama_model: str
    cors_origin_regex: str
    log_level: str
    database_path: str


def get_settings() -> Settings:
    return Settings(
        ollama_url=(os.getenv("OLLAMA_URL") or "http://127.0.0.1:11434").rstrip("/"),
        ollama_model=os.getenv("OLLAMA_MODEL") or "llama3.2:1b",
        cors_origin_regex=os.getenv(
            "CORS_ORIGIN_REGEX", r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
        ),
        log_level=(os.getenv("LOG_LEVEL") or "INFO").upper(),
        database_path=os.getenv("NPK_DATABASE_PATH") or str(
            Path(__file__).resolve().parents[1] / "data" / "readings.sqlite3"
        ),
    )
