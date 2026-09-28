from datetime import datetime, timezone

from app.repository import SQLiteReadingRepository
from app.schemas import ReadingIn


def test_reading_metadata_survives_repository_restart(tmp_path):
    database = tmp_path / "readings.sqlite3"
    first_run = SQLiteReadingRepository(database)
    reading = ReadingIn(
        nitrogen=42,
        phosphorus=18,
        potassium=95,
        unit="mg/kg",
        measured_at=datetime(2026, 9, 27, 10, tzinfo=timezone.utc),
        sensor_id="demo-01",
        source="simulated",
        crop="Rice",
        soil_ph=6.2,
        soil_texture="loam",
        region="test region",
    )
    saved = first_run.add(reading)

    after_restart = SQLiteReadingRepository(database)
    loaded = after_restart.get(saved.reading_id)
    page, total = after_restart.list()

    assert loaded == saved
    assert total == 1
    assert page == [saved]
    assert loaded.source == "simulated"
    assert loaded.region == "test region"


def test_reading_repository_keeps_only_configured_number_of_records(tmp_path):
    repository = SQLiteReadingRepository(tmp_path / "bounded.sqlite3", max_records=2)
    for value in (1, 2, 3):
        repository.add(ReadingIn(
            nitrogen=value, phosphorus=value, potassium=value, unit="mg/kg"
        ))

    page, total = repository.list()

    assert total == 2
    assert [reading.nitrogen for reading in page] == [3, 2]


def test_reading_repository_paginates_newest_first(tmp_path):
    repository = SQLiteReadingRepository(tmp_path / "paged.sqlite3")
    for value in (1, 2, 3):
        repository.add(ReadingIn(
            nitrogen=value, phosphorus=value, potassium=value, unit="mg/kg"
        ))

    page, total = repository.list(limit=1, offset=1)

    assert total == 3
    assert page[0].nitrogen == 2
