"""Weekly meetings report.

Plain Python, no AWS in here. The Lambda handler (Step 3) calls
build_weekly_report(week) and writes the bytes to S3 under report_key(week).
"""

import csv
import io
import re
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import Meeting

# "Week" means a calendar week in this timezone (same one the schedule uses).
REPORT_TZ = ZoneInfo("Europe/Kyiv")
TOP_N = 5

_WEEK_RE = re.compile(r"^(\d{4})-W(\d{2})$")


# --------------------------------------------------------------------------
# Week helpers (pure)
# --------------------------------------------------------------------------

def monday_of(week: str) -> date:
    """'2026-W40' -> date(2026, 9, 28). Raises ValueError on a bad week."""
    m = _WEEK_RE.match(week)
    if not m:
        raise ValueError(f"week must look like 2026-W40, got {week!r}")
    # fromisocalendar rejects W00, W54 and W53 in years that only have 52.
    return date.fromisocalendar(int(m[1]), int(m[2]), 1)


def format_week(d: date) -> str:
    year, number, _ = d.isocalendar()
    return f"{year}-W{number:02d}"


def shift_week(week: str, weeks: int) -> str:
    return format_week(monday_of(week) + timedelta(weeks=weeks))


def previous_week(today: date | None = None) -> str:
    """The ISO week before the one containing `today` (default: today in Kyiv).

    The handler uses this when the event carries no week.
    """
    today = today or datetime.now(REPORT_TZ).date()
    return format_week(today - timedelta(weeks=1))


def week_bounds(week: str) -> tuple[datetime, datetime]:
    """[start, end) of the week as aware datetimes, Monday 00:00 Kyiv time.

    Built from dates, not 'start + 7 days', so a week with a DST change
    is 167 or 169 hours long instead of being off by an hour.
    """
    monday = monday_of(week)
    start = datetime.combine(monday, time.min, tzinfo=REPORT_TZ)
    end = datetime.combine(monday + timedelta(weeks=1), time.min, tzinfo=REPORT_TZ)
    return start, end


def report_key(week: str) -> str:
    """Same week -> same key, so a re-run overwrites instead of duplicating."""
    monday_of(week)  # validate
    return f"reports/{week}.csv"


# --------------------------------------------------------------------------
# Aggregation and rendering (pure, no database)
# --------------------------------------------------------------------------

@dataclass(frozen=True)
class WeekStats:
    meetings: int
    hours: float


def duration(m: Meeting) -> timedelta:
    return m.ends_at - m.starts_at


def week_stats(rows: Sequence[Meeting]) -> WeekStats:
    total = sum((duration(m) for m in rows), timedelta())
    return WeekStats(meetings=len(rows), hours=total.total_seconds() / 3600)


def longest(rows: Sequence[Meeting], n: int = TOP_N) -> list[Meeting]:
    # Ties are broken by start time and id, so the output is deterministic.
    return sorted(rows, key=lambda m: (-duration(m), m.starts_at, m.id))[:n]


def _pct_change(current: float, previous: float) -> str:
    if previous == 0:
        return ""  # undefined, not "inf"
    return f"{(current - previous) / previous * 100:+.1f}%"


def _safe(text: str) -> str:
    # Titles are user input and this file is opened in Excel. A leading
    # = + - @ would be executed as a formula, so neutralise it.
    return "'" + text if text[:1] in ("=", "+", "-", "@") else text


def render_csv(
    week: str,
    current_rows: Sequence[Meeting],
    previous_rows: Sequence[Meeting],
) -> bytes:
    cur, prev = week_stats(current_rows), week_stats(previous_rows)
    prev_week = shift_week(week, -1)

    buf = io.StringIO()
    w = csv.writer(buf)

    w.writerow(["Weekly meetings report", week])
    w.writerow([])
    w.writerow(["metric", week, prev_week, "change", "change_pct"])
    w.writerow([
        "meetings", cur.meetings, prev.meetings,
        f"{cur.meetings - prev.meetings:+d}",
        _pct_change(cur.meetings, prev.meetings),
    ])
    w.writerow([
        "total_hours", f"{cur.hours:.2f}", f"{prev.hours:.2f}",
        f"{cur.hours - prev.hours:+.2f}",
        _pct_change(cur.hours, prev.hours),
    ])
    w.writerow([])
    w.writerow([f"Top {TOP_N} longest meetings"])
    w.writerow(["title", "starts_at", "duration_hours", "participants"])
    for m in longest(current_rows):
        w.writerow([
            _safe(m.title),
            m.starts_at.astimezone(REPORT_TZ).isoformat(timespec="minutes"),
            f"{duration(m).total_seconds() / 3600:.2f}",
            m.attendee_count,
        ])

    # No "generated at" line on purpose: same data in, same bytes out.
    # utf-8-sig adds a BOM so Excel shows Cyrillic titles correctly.
    return buf.getvalue().encode("utf-8-sig")


# --------------------------------------------------------------------------
# Database access (the only part that touches SQLAlchemy)
# --------------------------------------------------------------------------

def fetch_meetings(session: Session, week: str) -> list[Meeting]:
    """Meetings that START inside the week (Mon 00:00 to next Mon 00:00, Kyiv)."""
    start, end = week_bounds(week)
    stmt = (
        select(Meeting)
        .where(Meeting.starts_at >= start, Meeting.starts_at < end)
        .order_by(Meeting.starts_at, Meeting.id)
    )
    return list(session.scalars(stmt))


def build_weekly_report(week: str, session: Session | None = None) -> bytes:
    """Query the meetings of one ISO week (e.g. "2026-W40") and return the CSV.

    `session` is optional and only exists so tests can pass their own.
    """
    monday_of(week)  # fail fast on a bad week, before opening a connection
    if session is not None:
        return _build(week, session)
    with SessionLocal() as own_session:
        return _build(week, own_session)


def _build(week: str, session: Session) -> bytes:
    return render_csv(
        week,
        fetch_meetings(session, week),
        fetch_meetings(session, shift_week(week, -1)),
    )
