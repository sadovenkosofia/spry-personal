from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import Meeting
from app.schemas import MeetingCreate, MeetingRead

router = APIRouter(prefix="/api/meetings")
SessionDep = Annotated[Session, Depends(get_session)]

@router.get("", response_model=list[MeetingRead])
def list_meetings(session: SessionDep) -> list[Meeting]:
    statement = select(Meeting).order_by(Meeting.starts_at, Meeting.id)
    return list(session.scalars(statement))


@router.post("", response_model=MeetingRead, status_code=201)
def create_meeting(payload: MeetingCreate, session: SessionDep) -> Meeting:
    meeting = Meeting(**payload.model_dump())
    session.add(meeting)
    session.commit()
    return meeting
