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
  zhipu: [
    { id: "glm-5", label: "GLM-5" },
    { id: "glm-4.7", label: "GLM-4.7" },
    { id: "glm-4.7-flash", label: "GLM-4.7 Flash" },
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
  "whatsapp",
  "telegram",
  "polymarket",
  "evm",
] as const;

/* ------------------------------------------------------------------ */
/*  Bucket credential configuration                                    */
/* ------------------------------------------------------------------ */

export type BucketCredentialConfig =
  | { needsCredential: false; description: string }
  | {
      needsCredential: true;
      description: string;
      credentialType: string;
      service: string;
      isOAuth: boolean;
      required: boolean;
      valuePlaceholder: string;
      defaultName: string;
      serviceLabel: string;
    };

export const BUCKET_CONFIG: Record<(typeof BUCKET_NAMES)[number], BucketCredentialConfig> = {
  web_access: { needsCredential: false, description: "Allow HTTP requests and web browsing" },
  email: {
    needsCredential: true,
    description: "Allow sending emails",
    credentialType: "api_key",
    service: "resend",
    isOAuth: false,
    required: false,
    valuePlaceholder: "re_...",
    defaultName: "Resend API Key",
    serviceLabel: "Resend",
  },
  spending: { needsCredential: false, description: "Allow financial transactions" },
  communication: { needsCredential: false, description: "Allow messaging (WhatsApp, Slack, etc.)" },
  data_write: {
    needsCredential: true,
    description: "Allow writing/modifying external data",
    credentialType: "api_key",
    service: "",
    isOAuth: false,
    required: false,
    valuePlaceholder: "Your API key or token",
    defaultName: "Data Write Key",
    serviceLabel: "Generic",
  },
  gmail: {
    needsCredential: true,
    description: "Allow reading emails from connected Gmail account",
    credentialType: "oauth_token",
    service: "gmail",
    isOAuth: true,
    required: true,
    valuePlaceholder: "",
    defaultName: "Gmail",
    serviceLabel: "Gmail",
  },
  web_search: {
    needsCredential: true,
    description: "Allow searching the web for information (requires Tavily API key)",
    credentialType: "api_key",
    service: "tavily",
    isOAuth: false,
    required: true,
    valuePlaceholder: "tvly-...",
    defaultName: "Tavily API Key",
    serviceLabel: "Tavily",
  },
  google_calendar: {
    needsCredential: true,
    description: "Allow managing Google Calendar events (create, read, update, delete)",
    credentialType: "oauth_token",
    service: "google_calendar",
    isOAuth: true,
    required: true,
    valuePlaceholder: "",
    defaultName: "Google Calendar",
    serviceLabel: "Google Calendar",
  },
  whatsapp: {
    needsCredential: true,
    description: "Allow sending WhatsApp messages to phone numbers",
    credentialType: "custom",
    service: "whatsapp",
    isOAuth: false,
    required: true,
    valuePlaceholder: '{"access_token": "...", "phone_number_id": "..."}',
    defaultName: "WhatsApp Credential",
    serviceLabel: "WhatsApp",
  },
  telegram: {
    needsCredential: true,
    description: "Allow sending Telegram messages via bot",
    credentialType: "api_key",
    service: "telegram",
    isOAuth: false,
    required: true,
    valuePlaceholder: "123456:ABC-DEF...",
    defaultName: "Telegram Bot Token",
    serviceLabel: "Telegram",
  },
  polymarket: {
    needsCredential: true,
    description: "Allow trading on Polymarket prediction markets (buy/sell outcome tokens)",
    credentialType: "custom",
    service: "polymarket",
    isOAuth: false,
    required: false,
    valuePlaceholder: '{"private_key": "0x..."}',
    defaultName: "Polymarket Wallet",
    serviceLabel: "Polymarket",
  },
  evm: {
    needsCredential: true,
    description: "Allow EVM on-chain transactions (transfers, swaps, contract reads)",
    credentialType: "custom",
    service: "evm",
    isOAuth: false,
    required: false,
    valuePlaceholder: '{"private_key": "0x..."}',
    defaultName: "EVM Wallet",
    serviceLabel: "EVM",
  },
};
