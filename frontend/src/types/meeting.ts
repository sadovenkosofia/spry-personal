export interface AgendaItem {
  topic: string;
  owner: string | null;
  minutes: number | null;
}

export interface ActionItem {
  task: string;
  owner: string | null;
  due: string | null;
}

export interface Agenda {
  items: AgendaItem[];
  action_items: ActionItem[];
}

export interface ParsedAgenda {
  is_agenda: boolean;
  title: string | null;
  starts_at: string | null;
  duration_minutes: number | null;
  items: AgendaItem[];
  action_items: ActionItem[];
  language: string;
}

export interface AiSuggestion {
  agenda: ParsedAgenda;
  model: string;
  prompt_version: string;
}

export interface Meeting {
  id: number;
  title: string;
  starts_at: string;
  ends_at: string;
  attendee_count: number;
  agenda: Agenda | null;
  ai_suggestion: AiSuggestion | null;
}

export interface MeetingCreate {
  title: string;
  starts_at: string;
  ends_at: string;
  attendee_count: number;
}
