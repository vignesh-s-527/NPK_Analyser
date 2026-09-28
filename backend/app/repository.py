"""SQLite reading store for local development and single-user deployments."""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock
from typing import Iterator
from uuid import UUID, uuid4

from .config import get_settings
from .schemas import ReadingIn, ReadingOut


class SQLiteReadingRepository:
    """Bounded persistent store; use secured user-scoped storage for multi-user deployments."""

    def __init__(self, database_path: str | Path | None = None, *, max_records: int = 1000):
        if max_records < 1:
            raise ValueError("max_records must be positive")
        self.database_path = Path(database_path or get_settings().database_path).expanduser()
        self.max_records = max_records
        self._lock = Lock()
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        with self._session() as connection:
            connection.execute(
                """CREATE TABLE IF NOT EXISTS readings (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    reading_id TEXT NOT NULL UNIQUE,
                    nitrogen REAL NOT NULL,
                    phosphorus REAL NOT NULL,
                    potassium REAL NOT NULL,
                    unit TEXT NOT NULL,
                    measured_at TEXT NOT NULL,
                    received_at TEXT NOT NULL,
                    sensor_id TEXT,
                    source TEXT,
                    crop TEXT,
                    soil_ph REAL,
                    soil_texture TEXT,
                    region TEXT
                )"""
            )

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.database_path, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute("PRAGMA busy_timeout=10000")
        return connection

    @contextmanager
    def _session(self) -> Iterator[sqlite3.Connection]:
        connection = self._connect()
        try:
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    @staticmethod
    def _to_output(row: sqlite3.Row) -> ReadingOut:
        return ReadingOut(
            reading_id=UUID(row["reading_id"]),
            nitrogen=row["nitrogen"],
            phosphorus=row["phosphorus"],
            potassium=row["potassium"],
            unit=row["unit"],
            measured_at=datetime.fromisoformat(row["measured_at"]),
            received_at=datetime.fromisoformat(row["received_at"]),
            sensor_id=row["sensor_id"],
            source=row["source"],
            crop=row["crop"],
            soil_ph=row["soil_ph"],
            soil_texture=row["soil_texture"],
            region=row["region"],
        )

    def add(self, reading: ReadingIn) -> ReadingOut:
        received_at = datetime.now(timezone.utc)
        record = ReadingOut(
            reading_id=uuid4(),
            nitrogen=reading.nitrogen,
            phosphorus=reading.phosphorus,
            potassium=reading.potassium,
            unit=reading.unit,
            measured_at=reading.measured_at or received_at,
            received_at=received_at,
            sensor_id=reading.sensor_id,
            source=reading.source,
            crop=reading.crop,
            soil_ph=reading.soil_ph,
            soil_texture=reading.soil_texture,
            region=reading.region,
        )
        with self._lock, self._session() as connection:
            connection.execute(
                """INSERT INTO readings (
                    reading_id, nitrogen, phosphorus, potassium, unit, measured_at,
                    received_at, sensor_id, source, crop, soil_ph, soil_texture, region
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    str(record.reading_id), record.nitrogen, record.phosphorus,
                    record.potassium, record.unit, record.measured_at.isoformat(),
                    record.received_at.isoformat(), record.sensor_id, record.source,
                    record.crop, record.soil_ph, record.soil_texture, record.region,
                ),
            )
            # Nested SELECT avoids SQLite's restriction on modifying a table
            # selected from the same statement.
            connection.execute(
                """DELETE FROM readings WHERE sequence NOT IN (
                    SELECT sequence FROM (
                        SELECT sequence FROM readings ORDER BY sequence DESC LIMIT ?
                    )
                )""",
                (self.max_records,),
            )
        return record

    def list(self, *, limit: int = 50, offset: int = 0) -> tuple[list[ReadingOut], int]:
        with self._lock, self._session() as connection:
            total = connection.execute("SELECT COUNT(*) FROM readings").fetchone()[0]
            rows = connection.execute(
                "SELECT * FROM readings ORDER BY sequence DESC LIMIT ? OFFSET ?",
                (limit, offset),
            ).fetchall()
        return [self._to_output(row) for row in rows], total

    def get(self, reading_id: UUID) -> ReadingOut | None:
        with self._lock, self._session() as connection:
            row = connection.execute(
                "SELECT * FROM readings WHERE reading_id=?", (str(reading_id),)
            ).fetchone()
        return self._to_output(row) if row is not None else None


readings = SQLiteReadingRepository()
