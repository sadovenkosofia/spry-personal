import { useState, type FormEvent } from "react";

import { createMeeting } from "@/api/meetings";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface MeetingFormProps {
  onCreated: () => void;
}

export function MeetingForm({ onCreated }: MeetingFormProps) {
  const [title, setTitle] = useState("");
  const [startsAt, setStartsAt] = useState("");
  const [endsAt, setEndsAt] = useState("");
  const [attendeeCount, setAttendeeCount] = useState("0");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await createMeeting({
        title,
        starts_at: new Date(startsAt).toISOString(),
        ends_at: new Date(endsAt).toISOString(),
        attendee_count: Number(attendeeCount),
      });
      setTitle("");
      setStartsAt("");
      setEndsAt("");
      setAttendeeCount("0");
      onCreated();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="grid gap-4">
      <div className="grid gap-2">
        <Label htmlFor="title">Title</Label>
        <Input id="title" value={title} maxLength={200} required onChange={(e) => setTitle(e.target.value)} />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="grid gap-2">
          <Label htmlFor="starts_at">Starts</Label>
          <Input
            id="starts_at"
            type="datetime-local"
            value={startsAt}
            required
            onChange={(e) => setStartsAt(e.target.value)}
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="ends_at">Ends</Label>
          <Input
            id="ends_at"
            type="datetime-local"
            value={endsAt}
            required
            onChange={(e) => setEndsAt(e.target.value)}
          />
        </div>
      </div>
      <div className="grid gap-2">
        <Label htmlFor="attendee_count">Attendees</Label>
        <Input
          id="attendee_count"
          type="number"
          min={0}
          step={1}
          value={attendeeCount}
          required
          onChange={(e) => setAttendeeCount(e.target.value)}
        />
      </div>
      {error && <p className="text-sm text-destructive">{error}</p>}
      <div className="flex justify-end">
        <Button type="submit" disabled={submitting}>
          {submitting ? "Adding…" : "Add meeting"}
        </Button>
      </div>
    </form>
  );
}
