import { Clock, Users } from "lucide-react";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Meeting } from "@/types/meeting";

const dateFormat = new Intl.DateTimeFormat(undefined, {
  weekday: "short",
  month: "short",
  day: "numeric",
});
const timeFormat = new Intl.DateTimeFormat(undefined, {
  hour: "numeric",
  minute: "2-digit",
});

function formatRange(start: Date, end: Date): string {
  if (start.toDateString() === end.toDateString()) {
    return `${dateFormat.format(start)}, ${timeFormat.format(start)} – ${timeFormat.format(end)}`;
  }
  return `${dateFormat.format(start)}, ${timeFormat.format(start)} – ${dateFormat.format(end)}, ${timeFormat.format(end)}`;
}

export function MeetingCard({ meeting }: { meeting: Meeting }) {
  const start = new Date(meeting.starts_at);
  const end = new Date(meeting.ends_at);
  const attendees = meeting.attendee_count === 1 ? "1 attendee" : `${meeting.attendee_count} attendees`;

  return (
    <Card className="gap-3 py-5">
      <CardHeader>
        <CardTitle className="text-base break-words">{meeting.title}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-1.5 text-sm text-muted-foreground sm:flex-row sm:items-center sm:gap-6">
        <span className="flex items-center gap-2">
          <Clock className="size-4 shrink-0" />
          {formatRange(start, end)}
        </span>
        <span className="flex items-center gap-2">
          <Users className="size-4 shrink-0" />
          {attendees}
        </span>
      </CardContent>
    </Card>
  );
}
