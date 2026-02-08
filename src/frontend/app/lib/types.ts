/* ------------------------------------------------------------------ */
/*  Shared TypeScript types                                            */
/* ------------------------------------------------------------------ */

export interface Agent {
  id: string;
  name: string;
  description: string | null;
  model_provider: string;
  model_id: string;
  llm_config_id: string | null;
  has_llm_config: boolean;
  inserted_at: string;
}

/** Extended agent with full settings fields (used on agent detail page) */
export interface AgentDetail extends Agent {
  system_prompt: string;
  model_config: Record<string, unknown>;
  max_steps_per_run: number;
  max_runs_per_day: number;
  max_history_messages: number;
}

export interface LlmConfig {
  id: string;
  provider: string;
  label: string;
  is_default: boolean;
  inserted_at?: string;
}

export interface Credential {
  id: string;
  name: string;
  service: string;
  credential_type: string;
  inserted_at?: string;
}

export interface Schedule {
  id: string;
  cron: string;
  message: string | null;
  enabled: boolean;
  last_run_at: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface GoalStep {
  id: string;
  title: string;
  description: string | null;
  status: string;
  position: number;
  schedule_id: string | null;
  result_notes: string | null;
  completed_at: string | null;
}

export interface Goal {
  id: string;
  title: string;
  description: string | null;
  status: string;
  priority: number;
  due_date: string | null;
  review_schedule_id: string | null;
  completed_at: string | null;
  steps: GoalStep[];
  inserted_at: string;
  updated_at: string;
}

export interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  sequence: number;
  source?: string;
  inserted_at: string;
}

export interface Bucket {
  id: string;
  bucket: string;
  scope_config: Record<string, unknown> | null;
  credential_id: string | null;
  granted_at: string | null;
  revoked_at: string | null;
}

export interface Spore {
  id: number;
  x: number;
  y: number;
  size: number;
  duration: number;
  delay: number;
  color: string;
}

export type Tab = "chat" | "schedules" | "settings" | "permissions" | "guide";
