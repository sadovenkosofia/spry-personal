import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";

import { listMeetings } from "@/api/meetings";
import { AuthBar } from "@/auth/AuthBar";
import LoginPage from "@/auth/LoginPage";
import { MeetingList } from "@/components/MeetingList";
import { NewMeetingDialog } from "@/components/NewMeetingDialog";
import { Button } from "@/components/ui/button";
import type { Meeting } from "@/types/meeting";

function MeetingsPage() {
  const [meetings, setMeetings] = useState<Meeting[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  const load = useCallback(async () => {
    try {
      setMeetings(await listMeetings());
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load meetings");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Initial fetch on mount: state is set after the awaited request, not synchronously.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  return (
    <div className="min-h-screen bg-neutral-50">
      <main className="mx-auto max-w-2xl px-6 py-14">
        <header className="mb-8 flex items-end justify-between gap-4">
          <div>
            <h1 className="text-3xl font-semibold tracking-tight">Meetings</h1>
            {!loading && !error && (
              <p className="mt-1 text-sm text-muted-foreground">
                {meetings.length === 1 ? "1 meeting" : `${meetings.length} meetings`}
              </p>
            )}
          </div>
          <div className="flex items-center gap-3">
            <AuthBar />
            <Button onClick={() => setDialogOpen(true)}>
              <Plus className="size-4" />
              New meeting
            </Button>
          </div>
        </header>

        <MeetingList meetings={meetings} loading={loading} error={error} onNew={() => setDialogOpen(true)} />
      </main>
      <NewMeetingDialog open={dialogOpen} onOpenChange={setDialogOpen} onCreated={load} />
    </div>
  );
}

export default function App() {
  if (window.location.pathname.startsWith("/login")) return <LoginPage />;
  return <MeetingsPage />;
}
