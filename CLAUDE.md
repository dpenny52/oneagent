# OneAgent

A platform to deploy persistent AI agents that live in the cloud, with a bioluminescent-themed landing page and full authenticated dashboard.

## Agent Teams for Larger Tasks

For any task beyond a trivial fix (more than a couple lines of code changed), use a team of agents:

- **Frontend dev** — implements UI changes (`src/frontend/`)
- **Backend dev** — implements API/schema changes (`src/backend/`)
- **Code reviewer** — reviews all changes for correctness, style, and adherence to project conventions
- **Security reviewer** — audits changes for vulnerabilities (injection, auth bypass, data leaks, etc.)
- **Tester** — verifies the feature end-to-end using Chrome MCP browser automation (see [TESTING.md](TESTING.md))

Spawn these as a team so frontend and backend work can proceed in parallel, with reviewers and tester running after implementation is complete.

## CI/CD

Pushing to `main` automatically runs tests and deploys to production (Fly.io). No manual deploy step needed.

## Frontend Commands

Run from the `src/frontend/` directory:

```bash
npm run dev      # Dev server (localhost:3000)
npm run build    # Production build
npm run lint     # ESLint
```

## Page Conventions

All pages are `"use client"` components with:

1. **Google Fonts** initialized at module scope (`Instrument_Serif`, `DM_Sans`, `Lora`)
2. **Keyframe injection** via `useEffect` with an ID guard to prevent duplicates
3. **ALL styles are inline** `style={{}}` objects — no Tailwind utility classes, no CSS modules
4. **Framer Motion** for animations (`motion`, `AnimatePresence`)
5. **Shared theme** from `app/lib/theme.ts` — color palette `C`, style helpers

### Common Pitfalls

- **Agent invoke requires `llm_config_id`** — backend returns 422 if nil. Frontend gates chat on `has_llm_config`.
- **Tab-scoped data fetching** — useEffects that refetch on `tab` change will overwrite unsaved local state. Use a `loaded` flag to fetch only once.
- **Model options** — `MODEL_OPTIONS` map in both `dashboard/page.tsx` and `agents/[id]/page.tsx` defines provider→model lists. Keep in sync.
- **Keys page placeholders** — Label and API key placeholders are provider-aware (Anthropic vs OpenAI).

### Dashboard Pages

Protected pages wrap content in `<Protected>` which checks `useAuth()` and redirects to `/login`.

Common layout pattern:
- **Top bar**: sticky nav with OneAgent logo → /dashboard, "Keys" link, user email, logout
- **Ambient orbs** + mesh gradient background (bioluminescent aesthetic)
- **Glass cards** via `glassCard()` helper (blur, translucent backgrounds, glow borders)

### Route Map

| Route | Auth | Description |
|-------|------|-------------|
| `/` | No | Landing page with auth-aware nav |
| `/login` | No | Password + magic link login, inline forgot-password |
| `/register` | No | Email + password registration |
| `/reset-password?token=` | No | New password form |
| `/dashboard` | Yes | Agent grid — create, open, delete agents |
| `/agents/[id]` | Yes | Agent detail — Chat, Settings, Permissions, Guide tabs |
| `/keys` | Yes | LLM API keys + tool credentials + Gmail OAuth + Google Calendar OAuth |

---

## Backend (Elixir/Phoenix API)

Run from the `src/backend/` directory:

```bash
mix deps.get        # Install dependencies
mix ecto.setup      # Create DB, run migrations, seed
mix ecto.migrate    # Run pending migrations
mix phx.server      # Start server (localhost:4000)
mix test            # Run test suite
```

PostgreSQL must be running. Dev config uses `dpenny` user with no password. See `src/backend/.env.example` for environment variables.

### Architecture Overview

- **11 tables**: agents, credentials, llm_configs, agent_buckets, agent_runs, agent_steps, agent_memories, agent_messages, agent_schedules, agent_goals, agent_goal_steps
- **Contexts**: `Agents` (CRUD + all agent-related data), `Credentials` (encrypted creds + LLM configs)
- **Runtime**: DynamicSupervisor + GenServer per agent, Registry for lookup. Processes auto-start on invoke.
- **LLM providers**: Anthropic + OpenAI via Req (behaviour pattern in `OneAgent.LLM`)
- **Encryption**: `cloak_ecto` AES-256-GCM (Vault in supervision tree)
- **Auth**: Bearer token (API tokens stored SHA-256 hashed), rate limiting via Hammer
- **Scheduling**: Oban with `ScheduleChecker` (every minute) + `ScheduledExecution` workers

### Agent Tools (14 total)

Tools registered in `OneAgent.Tools`, filtered by agent's active permission buckets. `nil` bucket = always available.

| Tool | Bucket | Description |
|------|--------|-------------|
| `http_request` | dynamic | HTTP requests with SSRF protection |
| `read_webpage` | web_access | Fetch and extract text from web pages |
| `send_email` | email | Send emails with validation |
| `check_email` | gmail | Read Gmail via OAuth2 (list/read actions) |
| `manage_calendar` | google_calendar | CRUD Google Calendar events via OAuth2 (list/create/update/delete/search) |
| `send_whatsapp` | whatsapp | Send outbound WhatsApp messages via Cloud API |
| `web_search` | web_search | Search web via Tavily API |
| `store_memory` | nil | Persist key-value memories |
| `recall_memory` | nil | Recall by key, FTS search, or list all |
| `list_schedules` | nil | List cron schedules |
| `manage_schedule` | nil | Create/update/delete schedules (dedup on create) |
| `manage_goal` | nil | Create/update/complete/pause/resume/abandon/delete goals |
| `manage_goal_step` | nil | Manage goal steps + step schedules |
| `list_goals` | nil | List goals with progress |

### Key Integrations

- **WhatsApp**: `whatsapp_channels` maps phone_number_id → agent + credential. Webhook is async (returns 200, processes via TaskSupervisor). HMAC-SHA256 verification via `CacheRawBody` plug. `send_whatsapp` tool enables proactive outbound messages (webhook-restricted to prevent prompt injection).
- **Gmail**: OAuth2 flow (`GET /api/auth/gmail` → Google → callback → store refresh_token). `check_email` tool refreshes token on each use.
- **Google Calendar**: OAuth2 flow (`GET /api/auth/calendar` → Google → callback → store refresh_token). `manage_calendar` tool supports list/create/update/delete/search events. Uses `calendar.events` scope. Webhook-restricted: mutations (create/update/delete) blocked from webhook-triggered runs, reads (list/search) allowed.
- **Web Search**: Tavily API, key in JSON body. Requires `web_search` bucket with api_key credential.
- **Goals**: Auto-create hourly review schedule. Steps can have linked cron schedules. Complete/abandon disables all associated schedules.

---

## Design Philosophy

Dark, atmospheric, luxurious aesthetics: rich accent colors with glow/bloom, particles/orbs/gradients, elegant typography (display + body fonts), Framer Motion animations, glass/blur/transparency effects.

---

## Browser Testing

See [TESTING.md](TESTING.md) for Chrome MCP browser testing scripts and tips.
