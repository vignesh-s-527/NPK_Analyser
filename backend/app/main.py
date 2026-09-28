"""FastAPI app factory and cross-cutting middleware/exception handling."""
from __future__ import annotations

import logging
import time
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from .config import get_settings
from .routes import router

settings = get_settings()
logging.basicConfig(level=getattr(logging, settings.log_level, logging.INFO))
logger = logging.getLogger("npk_api")

app = FastAPI(
    title="NPK Analyzer API",
    version="1.1.0",
    description="Validated NPK reading intake and conservative agricultural advisory services",
)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Request-ID"],
    expose_headers=["X-Request-ID"],
)
app.include_router(router)


@app.middleware("http")
async def request_logging(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID") or str(uuid4())
    started = time.perf_counter()
    response = await call_next(request)
    elapsed_ms = (time.perf_counter() - started) * 1000
    response.headers["X-Request-ID"] = request_id
    logger.info("request id=%s method=%s path=%s status=%s elapsed_ms=%.1f",
                request_id, request.method, request.url.path, response.status_code, elapsed_ms)
    return response


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    errors = [
        {"field": ".".join(str(part) for part in error.get("loc", ()) if part != "body"),
         "code": error.get("type", "invalid_value"),
         "message": error.get("msg", "Invalid value")}
        for error in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={"detail": "Request validation failed", "errors": errors},
    )


@app.exception_handler(StarletteHTTPException)
async def http_error_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    message = exc.detail if isinstance(exc.detail, str) else "Request failed"
    return JSONResponse(
        status_code=exc.status_code,
        headers=exc.headers,
        content={"detail": message, "error": {"code": f"http_{exc.status_code}", "message": message}},
    )


@app.exception_handler(Exception)
async def unexpected_error_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled API exception path=%s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "error": {
            "code": "internal_error", "message": "The request could not be completed."}},
    )
