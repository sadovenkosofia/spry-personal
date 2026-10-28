import { useEffect, useRef, useState } from "react";
import { Loader2, Plus, Trash2 } from "lucide-react";
import { useAuth } from "react-oidc-context";

import { saveAgenda } from "@/api/meetings";
import { parseAgenda, ParserError } from "@/api/parser";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import type { AiSuggestion, Meeting } from "@/types/meeting";

// s.* is true while the value was filled by the model and the user has not touched it
interface ItemRow {
  topic: string;
  owner: string;
  minutes: string;
  s: { topic: boolean; owner: boolean; minutes: boolean };
}
interface ActionRow {
  task: string;
  owner: string;
  due: string;
  s: { task: boolean; owner: boolean; due: boolean };
}

const emptyItem = (): ItemRow => ({
  topic: "",
  owner: "",
  minutes: "",
  s: { topic: false, owner: false, minutes: false },
});
const emptyAction = (): ActionRow => ({
  task: "",
  owner: "",
  due: "",
  s: { task: false, owner: false, due: false },
});

function Badge() {
  return (
    <span className="ml-2 rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-800">suggested</span>
  );
}

function Labeled({ label, suggested, children }: { label: string; suggested: boolean; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1 text-xs text-muted-foreground">
      <span>
        {label}
        {suggested && <Badge />}
      </span>
      {children}
    </label>
  );
}

function AgendaEditor({ meeting, onClose, onSaved }: { meeting: Meeting; onClose: () => void; onSaved: () => void }) {
  const auth = useAuth();
  const abortRef = useRef<AbortController | null>(null);

  const [text, setText] = useState("");
  const [parsing, setParsing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [suggestion, setSuggestion] = useState<AiSuggestion | null>(meeting.ai_suggestion);
  const [detected, setDetected] = useState<string | null>(null);
  const [items, setItems] = useState<ItemRow[]>(() =>
    meeting.agenda
      ? meeting.agenda.items.map((i) => ({
          ...emptyItem(),
          topic: i.topic,
          owner: i.owner ?? "",
          minutes: i.minutes ? String(i.minutes) : "",
        }))
      : [],
  );
  const [actions, setActions] = useState<ActionRow[]>(() =>
    meeting.agenda
      ? meeting.agenda.action_items.map((a) => ({
          ...emptyAction(),
          task: a.task,
          owner: a.owner ?? "",
          due: a.due ?? "",
        }))
      : [],
  );

  useEffect(() => () => abortRef.current?.abort(), []);

  async function onParse() {
    const idToken = auth.user?.id_token;
    if (!idToken) {
      setError("You are not signed in. Sign in and try again.");
      return;
    }
    const controller = new AbortController();
    abortRef.current = controller;
    setParsing(true);
    setError(null);
    try {
      const result = await parseAgenda(text, idToken, controller.signal);
      const a = result.agenda;
      setSuggestion({ agenda: a, model: result.model, prompt_version: result.promptVersion });
      setItems(
        a.items.map((i) => ({
          topic: i.topic,
          owner: i.owner ?? "",
          minutes: i.minutes ? String(i.minutes) : "",
          s: { topic: !!i.topic, owner: !!i.owner, minutes: !!i.minutes },
        })),
      );
      setActions(
        (a.action_items ?? []).map((x) => ({
          task: x.task,
          owner: x.owner ?? "",
          due: x.due ?? "",
          s: { task: !!x.task, owner: !!x.owner, due: !!x.due },
        })),
      );
      const parts = [a.title, a.starts_at, a.duration_minutes ? `${a.duration_minutes} min` : null].filter(Boolean);
      setDetected(parts.length ? parts.join(" · ") : null);
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") return;
      setError(e instanceof ParserError ? e.message : "Something went wrong. Enter the agenda manually.");
    } finally {
      setParsing(false);
    }
  }

  function onCancel() {
    abortRef.current?.abort();
  }

  function patchItem(index: number, field: "topic" | "owner" | "minutes", value: string) {
    setItems((rows) => rows.map((r, i) => (i === index ? { ...r, [field]: value, s: { ...r.s, [field]: false } } : r)));
  }

  function patchAction(index: number, field: "task" | "owner" | "due", value: string) {
    setActions((rows) =>
      rows.map((r, i) => (i === index ? { ...r, [field]: value, s: { ...r.s, [field]: false } } : r)),
    );
  }

  async function onSave() {
    const cleanItems = items
      .filter((r) => r.topic.trim())
      .map((r) => ({
        topic: r.topic.trim(),
        owner: r.owner.trim() || null,
        minutes: r.minutes.trim() ? Number.parseInt(r.minutes, 10) : null,
      }));
    if (cleanItems.length === 0) {
      setError("Add at least one agenda item.");
      return;
    }
    const cleanActions = actions
      .filter((r) => r.task.trim())
      .map((r) => ({ task: r.task.trim(), owner: r.owner.trim() || null, due: r.due || null }));

    setSaving(true);
    setError(null);
    try {
      await saveAgenda(meeting.id, { items: cleanItems, action_items: cleanActions }, suggestion);
      onSaved();
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save the agenda");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-2">
        <textarea
          className="min-h-32 w-full rounded-md border bg-transparent px-3 py-2 text-sm"
          placeholder="Paste an email, chat message or notes with the agenda…"
          value={text}
          onChange={(e) => setText(e.target.value)}
          disabled={parsing}
        />
        <div className="flex items-center gap-2">
          <Button onClick={() => void onParse()} disabled={parsing || !text.trim()}>
            {parsing && <Loader2 className="size-4 animate-spin" />}
            {parsing ? "Parsing…" : "Parse"}
          </Button>
          {parsing && (
            <>
              <Button variant="outline" onClick={onCancel}>
                Cancel
              </Button>
              <span className="text-xs text-muted-foreground">Reading your text, this can take a few seconds…</span>
            </>
          )}
        </div>
      </div>

      {error && <p className="text-sm text-destructive">{error}</p>}
      {detected && <p className="text-xs text-muted-foreground">Detected: {detected}</p>}

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium">Agenda items</h3>
        {items.map((row, i) => (
          <div key={i} className="grid grid-cols-[1fr_8rem_5rem_auto] items-end gap-2">
            <Labeled label="Topic" suggested={row.s.topic}>
              <Input value={row.topic} onChange={(e) => patchItem(i, "topic", e.target.value)} />
            </Labeled>
            <Labeled label="Owner" suggested={row.s.owner}>
              <Input value={row.owner} onChange={(e) => patchItem(i, "owner", e.target.value)} />
            </Labeled>
            <Labeled label="Min" suggested={row.s.minutes}>
              <Input
                type="number"
                min={1}
                max={480}
                value={row.minutes}
                onChange={(e) => patchItem(i, "minutes", e.target.value)}
              />
            </Labeled>
            <Button
              variant="outline"
              aria-label="Remove item"
              onClick={() => setItems((r) => r.filter((_, k) => k !== i))}
            >
              <Trash2 className="size-4" />
            </Button>
          </div>
        ))}
        <div>
          <Button variant="outline" onClick={() => setItems((r) => [...r, emptyItem()])}>
            <Plus className="size-4" />
            Add item
          </Button>
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium">Action items</h3>
        {actions.map((row, i) => (
          <div key={i} className="grid grid-cols-[1fr_8rem_9rem_auto] items-end gap-2">
            <Labeled label="Task" suggested={row.s.task}>
              <Input value={row.task} onChange={(e) => patchAction(i, "task", e.target.value)} />
            </Labeled>
            <Labeled label="Owner" suggested={row.s.owner}>
              <Input value={row.owner} onChange={(e) => patchAction(i, "owner", e.target.value)} />
            </Labeled>
            <Labeled label="Due" suggested={row.s.due}>
              <Input type="date" value={row.due} onChange={(e) => patchAction(i, "due", e.target.value)} />
            </Labeled>
            <Button
              variant="outline"
              aria-label="Remove action item"
              onClick={() => setActions((r) => r.filter((_, k) => k !== i))}
            >
              <Trash2 className="size-4" />
            </Button>
          </div>
        ))}
        <div>
          <Button variant="outline" onClick={() => setActions((r) => [...r, emptyAction()])}>
            <Plus className="size-4" />
            Add action item
          </Button>
        </div>
      </section>

      <div className="flex justify-end gap-2">
        <Button variant="outline" onClick={onClose}>
          Close
        </Button>
        <Button onClick={() => void onSave()} disabled={saving || parsing}>
          {saving ? "Saving…" : "Save agenda"}
        </Button>
      </div>
    </div>
  );
}

interface AgendaDialogProps {
  meeting: Meeting;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSaved: () => void;
}

export function AgendaDialog({ meeting, open, onOpenChange, onSaved }: AgendaDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle>Paste an agenda</DialogTitle>
          <DialogDescription>
            Paste text and let the model fill the form, or enter the agenda by hand. Check every field before saving.
          </DialogDescription>
        </DialogHeader>
        <AgendaEditor meeting={meeting} onClose={() => onOpenChange(false)} onSaved={onSaved} />
      </DialogContent>
    </Dialog>
  );
}
