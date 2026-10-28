from datetime import date, datetime

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator


class MeetingCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=200)
    starts_at: AwareDatetime
    ends_at: AwareDatetime
    attendee_count: int = Field(ge=0)

    @model_validator(mode="after")
    def ends_after_starts(self) -> "MeetingCreate":
        if self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be strictly after starts_at")
        return self


class MeetingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    starts_at: datetime
    ends_at: datetime
    attendee_count: int
    agenda: dict | None = None
    ai_suggestion: dict | None = None

class AgendaItemIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    topic: str = Field(min_length=1, max_length=300)
    owner: str | None = Field(default=None, max_length=200)
    minutes: int | None = Field(default=None, ge=1, le=480)


class ActionItemIn(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    task: str = Field(min_length=1, max_length=300)
    owner: str | None = Field(default=None, max_length=200)
    due: date | None = None


class AgendaSave(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[AgendaItemIn] = Field(min_length=1, max_length=50)
    action_items: list[ActionItemIn] = Field(default_factory=list, max_length=50)
    # what the model suggested, plus model and prompt version; stored as is
    ai_suggestion: dict | None = None
