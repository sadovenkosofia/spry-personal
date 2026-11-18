import type { Agenda, AiSuggestion, Meeting, MeetingCreate } from "@/types/meeting";

// Empty on S3/CloudFront (same origin). Set VITE_API_BASE when the frontend is served from another origin.
const API_BASE = (import.meta.env.VITE_API_BASE as string | undefined) ?? "";

interface ValidationError {
  msg: string;
}

interface ErrorBody {
  detail?: ValidationError[] | string;
}

async function errorMessage(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as ErrorBody | null;
    const detail = body?.detail;
    if (Array.isArray(detail) && detail.length > 0) {
      return detail.map((d) => d.msg).join("; ");
    }
  } catch {
    // fall through to the generic message
  }
  return `Request failed (${response.status})`;
}

export async function listMeetings(): Promise<Meeting[]> {
  const response = await fetch(`${API_BASE}/api/meetings`);
  if (!response.ok) throw new Error(await errorMessage(response));
  return (await response.json()) as Meeting[];
}

export async function createMeeting(input: MeetingCreate): Promise<Meeting> {
  const response = await fetch(`${API_BASE}/api/meetings`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!response.ok) throw new Error(await errorMessage(response));
  return (await response.json()) as Meeting;
}
export async function saveAgenda(id: number, agenda: Agenda, aiSuggestion: AiSuggestion | null): Promise<Meeting> {
  const response = await fetch(`${API_BASE}/api/meetings/${id}/agenda`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...agenda, ai_suggestion: aiSuggestion }),
  });
  if (!response.ok) throw new Error(await errorMessage(response));
  return (await response.json()) as Meeting;
}
