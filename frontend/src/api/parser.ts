import type { ParsedAgenda } from "@/types/meeting";

export interface ParseResult {
  agenda: ParsedAgenda;
  model: string;
  promptVersion: string;
}

export class ParserError extends Error {}

const PARSER_URL = import.meta.env.VITE_PARSER_URL as string | undefined;

const STATUS_MESSAGES: Record<number, string> = {
  400: "The request was not valid. Try different text.",
  401: "Your session expired. Sign in again and retry.",
  413: "The text is too long (limit 10,000 characters). Paste a shorter part.",
  422: "No agenda found in this text. You can enter it manually below.",
  429: "The service is busy. Wait a moment and try again.",
};

export async function parseAgenda(text: string, idToken: string, signal: AbortSignal): Promise<ParseResult> {
  if (!PARSER_URL) throw new ParserError("The parser is not configured. Enter the agenda manually.");

  let response: Response;
  try {
    response = await fetch(PARSER_URL, {
      method: "POST",
      signal,
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
      body: JSON.stringify({
        text,
        today: new Date().toLocaleDateString("en-CA"), // YYYY-MM-DD, local date
        tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
      }),
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === "AbortError") throw e;
    throw new ParserError("Could not reach the parser. Check your connection or enter the agenda manually.");
  }

  if (!response.ok) {
    throw new ParserError(
      STATUS_MESSAGES[response.status] ?? `The parser failed (${response.status}). Enter the agenda manually.`,
    );
  }

  const body = (await response.json()) as Partial<ParseResult> & {
    agenda?: ParsedAgenda;
    model?: string;
    prompt_version?: string;
  };
  const agenda = body.agenda ?? (body as unknown as ParsedAgenda);
  if (!Array.isArray(agenda.items)) throw new ParserError("Unexpected parser response. Enter the agenda manually.");

  return { agenda, model: body.model ?? "unknown", promptVersion: body.prompt_version ?? "unknown" };
}
