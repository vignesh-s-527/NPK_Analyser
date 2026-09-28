"""Isolate API tests from the developer's local readings database."""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

_TEST_DATA = Path(tempfile.mkdtemp(prefix="npk-backend-tests-"))
os.environ["NPK_DATABASE_PATH"] = str(_TEST_DATA / "readings.sqlite3")
