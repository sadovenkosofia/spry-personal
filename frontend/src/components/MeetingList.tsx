import { Plus } from "lucide-react";

import { MeetingCard } from "@/components/MeetingCard";
import { Button } from "@/components/ui/button";
import type { Meeting } from "@/types/meeting";

interface MeetingListProps {
  meetings: Meeting[];
  loading: boolean;
  error: string | null;
  onNew: () => void;
}

export function MeetingList({ meetings, loading, error, onNew }: MeetingListProps) {
  if (error) return <p className="text-sm text-destructive">{error}</p>;
  if (loading) return <p className="text-sm text-muted-foreground">Loading…</p>;

  if (meetings.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-xl border border-dashed py-16 text-center">
        <p className="text-sm text-muted-foreground">No meetings yet.</p>
        <Button variant="outline" onClick={onNew}>
          <Plus className="size-4" />
          Add your first meeting
        </Button>
      </div>
    );
  }

  return (
    <ul className="grid gap-3">
      {meetings.map((meeting) => (
        <li key={meeting.id}>
          <MeetingCard meeting={meeting} />
        </li>
      ))}
    </ul>
  );
}
