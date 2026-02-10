/** Model options by provider, shared across dashboard and agent detail pages. */
export const MODEL_OPTIONS: Record<string, { id: string; label: string }[]> = {
  anthropic: [
    { id: "claude-sonnet-4-5-20250929", label: "Claude Sonnet 4.5" },
    { id: "claude-haiku-4-5-20251001", label: "Claude Haiku 4.5" },
    { id: "claude-opus-4-6", label: "Claude Opus 4.6" },
  ],
  openai: [
    { id: "gpt-4o", label: "GPT-4o" },
    { id: "gpt-4o-mini", label: "GPT-4o Mini" },
    { id: "o3-mini", label: "o3-mini" },
  ],
};

export const BUCKET_NAMES = [
  "web_access",
  "email",
  "spending",
  "communication",
  "data_write",
  "gmail",
  "web_search",
  "google_calendar",
] as const;
