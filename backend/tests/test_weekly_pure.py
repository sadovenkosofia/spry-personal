"""Tests for the pure parts of weekly.py. No database needed.

Run from backend/:  DATABASE_URL=postgresql+psycopg://x pytest tests/
"""
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.reports.weekly import (
    previous_week, render_csv, report_key, shift_week, week_bounds,
)

UTC = timezone.utc


def meeting(id, title, start, hours, people):
    return SimpleNamespace(
        id=id, title=title, starts_at=start,
        ends_at=start + timedelta(hours=hours), attendee_count=people,
    )


def test_week_bounds_standard_week():
    start, end = week_bounds("2026-W40")  # Mon 28 Sep 2026, summer time (+03:00)
    assert start.astimezone(UTC) == datetime(2026, 9, 27, 21, 0, tzinfo=UTC)
    assert end - start == timedelta(days=7)


def test_week_bounds_dst_week_is_not_168_hours():
    # Kyiv leaves summer time on Sun 25 Oct 2026: that week has 169 hours.
    start, end = week_bounds("2026-W43")
    assert end.astimezone(UTC) - start.astimezone(UTC) == timedelta(hours=169)


def test_year_boundary_and_week_53():
    assert shift_week("2026-W01", -1) == "2025-W52"
    assert shift_week("2026-W01", -1) != "2025-W53"
    assert shift_week("2026-W53", 1) == "2027-W01"  # 2026 has 53 ISO weeks


@pytest.mark.parametrize("bad", ["2026-40", "2026-W00", "2026-W54", "2025-W53", "x", ""])
def test_bad_weeks_rejected(bad):
    with pytest.raises(ValueError):
        report_key(bad)


def test_previous_week_from_monday_morning():
    assert previous_week(date(2026, 10, 5)) == "2026-W40"  # Monday of W41


def test_report_key_is_stable():
    assert report_key("2026-W40") == "reports/2026-W40.csv"


def test_csv_content_and_determinism():
    d = datetime(2026, 9, 29, 10, 0, tzinfo=UTC)
    cur = [meeting(i, f"m{i}", d + timedelta(hours=i), i, i) for i in range(1, 8)]
    cur.append(meeting(99, "=HYPERLINK(evil)", d, 8, 3))
    prev = [meeting(100, "old", d - timedelta(days=7), 2, 4)]

    a = render_csv("2026-W40", cur, prev)
    b = render_csv("2026-W40", cur, prev)
    assert a == b  # idempotent bytes

    text = a.decode("utf-8-sig")
    assert "meetings,8,1,+7,+700.0%" in text
    assert "'=HYPERLINK(evil)" in text           # formula neutralised
    assert text.count("\r\n") == 8 + 5           # 8 header/summary lines + 5 top rows
    assert "m1," not in text.split("Top 5")[1]   # shortest meetings are dropped


def test_no_previous_week_does_not_divide_by_zero():
    d = datetime(2026, 9, 29, 10, 0, tzinfo=UTC)
    text = render_csv("2026-W40", [meeting(1, "a", d, 1, 2)], []).decode("utf-8-sig")
    assert "meetings,1,0,+1," in text
