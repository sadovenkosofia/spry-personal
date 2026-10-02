export interface Meeting {
  id: number;
  title: string;
  starts_at: string;
  ends_at: string;
  attendee_count: number;
}

export interface MeetingCreate {
  title: string;
  starts_at: string;
  ends_at: string;
  attendee_count: number;
}
