# OneAgent

A platform to deploy persistent AI agents that live in the cloud, with a bioluminescent-themed landing page and full authenticated dashboard.

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

- **Agent invoke requires `llm_config_id`** — backend returns 422 "Agent has no LLM configuration assigned" if nil. Frontend gates chat on `has_llm_config`.
- **Tab-scoped data fetching** — useEffects that refetch on `tab` change will overwrite unsaved local state. Use a `loaded` flag to fetch only once.
- **Model options** — `MODEL_OPTIONS` map in both `dashboard/page.tsx` and `agents/[id]/page.tsx` defines provider→model lists. Keep in sync. Settings select includes a fallback option for non-matching existing model IDs.
- **Keys page placeholders** — Label and API key placeholders are provider-aware (Anthropic vs OpenAI).

### Dashboard Pages

Protected pages wrap content in `<Protected>` which checks `useAuth()` and redirects to `/login`.

Common layout pattern:
- **Top bar**: sticky nav with OneAgent logo → /dashboard, "Keys" link, user email, logout
- **Ambient orbs** + mesh gradient background (same bioluminescent aesthetic as landing)
- **Glass cards** via `glassCard()` helper (blur, translucent backgrounds, glow borders)

### Route Map

| Route | Auth | Description |
|-------|------|-------------|
| `/` | No | Landing page with auth-aware nav (Login/Register or Dashboard/Logout) |
| `/login` | No | Password + magic link login, inline forgot-password |
| `/register` | No | Email + password registration |
| `/reset-password?token=` | No | New password form (token from email) |
| `/dashboard` | Yes | Agent grid — create, open, delete agents |
| `/agents/[id]` | Yes | Agent detail — Chat, Settings, Permissions, Guide tabs |
| `/agents/[id]?tab=guide` | Yes | Opens agent detail directly on Guide tab |
| `/keys` | Yes | LLM API keys + tool credentials + Gmail OAuth management |

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

### Database Setup

PostgreSQL must be running. Dev config uses `dpenny` user with no password.

### Environment Variables

See `src/backend/.env.example` for full reference:
- `DATABASE_URL` — PostgreSQL connection string (prod)
- `SECRET_KEY_BASE` — Phoenix secret (prod; generate with `mix phx.gen.secret`)
- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` — Google OAuth credentials
- `CORS_ORIGIN` — Allowed origin (default: `http://localhost:3000`)
- `PORT` — HTTP port (default: `4000`)
- `PHX_HOST` — Production hostname

### WhatsApp Integration

Agents can receive and reply to WhatsApp messages via Meta's Cloud API.

**Flow:** WhatsApp message → Meta webhook POST → verify HMAC → find channel by phone_number_id → invoke agent (auto-starts process) → send reply via Cloud API.

**Key design decisions:**
- Webhook returns 200 immediately; message processing is async via `Task.Supervisor`
- One `whatsapp_channels` table maps a phone_number_id to an agent + credential
- WhatsApp credentials (access_token + app_secret) stored encrypted in the `credentials` table with `service: "whatsapp"`, `credential_type: "custom"`
- HMAC-SHA256 signature verification using raw body cached by `CacheRawBody` plug
- `verify_token` is auto-generated and only returned in the create response (needed for Meta dashboard setup)
- Agent processes auto-start on invoke — no manual start/stop needed
- Responses truncated to 4096 chars (WhatsApp limit)

**Setup:** Create a credential (WhatsApp access_token + app_secret), create an agent with LLM config, create a channel linking them, configure Meta's webhook dashboard with the callback URL and verify_token.

### Gmail Integration

Agents can read Gmail emails via OAuth2 and the Gmail API (`gmail.readonly` scope).

**Flow:** Frontend calls `GET /api/auth/gmail` (authenticated) → gets Google OAuth URL → user authorizes → Google redirects to `GET /api/auth/gmail/callback` → exchanges code for refresh_token → stores as credential (service: "gmail", type: "oauth_token") → redirects to `/keys?gmail_connected=true`.

**Key design decisions:**
- OAuth state is signed with `Phoenix.Token` (user_id, max_age 600s)
- Refresh token stored encrypted as `{"refresh_token": "..."}` in credentials table
- Token refresh happens on each `check_email` tool execution (no stored access_token)
- Client ID/secret from app config (`google_gmail_client_id`/`google_gmail_client_secret`), falls back to Google OAuth env vars
- Upserts: if Gmail credential already exists for user, updates it instead of creating duplicate
- `check_email` tool has two actions: `list` (search + metadata) and `read` (full message body, truncated to 10KB)
- Permission bucket: `gmail`; credential type: `oauth_token`

**Setup:** Enable Gmail API in Google Cloud Console, configure OAuth consent screen with `gmail.readonly` scope, create OAuth credentials with redirect URI `http://localhost:4000/api/auth/gmail/callback`, set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` env vars.

### Chat History

Agents persist conversation history in the `agent_messages` table. Each message has a role (`user`/`assistant`), content, and auto-incrementing sequence number.

**Key design decisions:**
- Only the user's original text and the assistant's final response are stored — intermediate tool-use turns within a run are NOT stored (they remain in `agent_steps` for audit)
- History is loaded before each LLM call, limited by `max_history_messages` (default 20, configurable 0–200)
- On error, the user message is still persisted so context isn't lost
- `GET /api/agents/:id/messages` returns recent messages; `DELETE /api/agents/:id/messages` clears all

### Scheduled Execution (Oban)

Agents support multiple cron schedules via the `agent_schedules` table. Each schedule has a cron expression, optional message, and enabled flag.

**Architecture:**
- **Oban** handles job processing with a Cron plugin
- **ScheduleChecker** — runs every minute, queries all enabled schedules (where agent has `llm_config_id`), filters by cron match, enqueues `ScheduledExecution` jobs per schedule
- **ScheduledExecution** — executes a single schedule's run with uniqueness (60s per schedule_id), uses `Runtime.invoke_agent/4` (auto-starts process), updates `last_run_at` on schedule

**Config:** Create schedules via `POST /api/agents/:id/schedules` with `{"schedule": {"cron": "*/5 * * * *", "message": "Check for updates"}}`. Agent must have an `llm_config_id` assigned. No manual start needed — schedules fire automatically.

### Goals & Plan Tracking

Agents can create structured goals with steps to track multi-step objectives proactively.

**Schema:**
- `agent_goals` table: id, agent_id, title, description, status (active/completed/paused/abandoned), priority, source_run_id, review_schedule_id, completed_at, due_date, metadata
- `agent_goal_steps` table: id, goal_id, title, description, status (pending/in_progress/completed/skipped), position, schedule_id, completed_at, result_notes

**Key design decisions:**
- Goals are internal to the agent — no permission bucket required, no API endpoints
- Each goal auto-creates an hourly review schedule (`0 * * * *`) linked via `review_schedule_id`
- Steps can have linked cron schedules via `schedule_id` for periodic execution
- `ScheduledExecution` enriches messages with goal context: step-linked schedules get step context, review schedules get review instructions
- Complete/abandon disables all associated schedules; delete removes them entirely
- Active goals (up to 10) appear in the system prompt with step progress and schedule info
- All goal/step tool responses include anti-loop `note` fields

### Agent Tools

Tools are registered in `OneAgent.Tools` and exposed to the LLM filtered by the agent's active permission buckets. Tools with `bucket: nil` are always available.

**Available tools (12 total):**
- `http_request` (dynamic bucket) — HTTP requests with SSRF protection
- `read_webpage` (web_access) — fetch and extract text from web pages
- `send_email` (email) — send emails with validation
- `check_email` (gmail) — read Gmail via OAuth2
- `web_search` (web_search) — search the web via Tavily API
- `store_memory` (nil) — persist key-value memories
- `recall_memory` (nil) — recall by key, keyword search, or list all
- `list_schedules` (nil) — list cron schedules
- `manage_schedule` (nil) — create/update/delete schedules
- `manage_goal` (nil) — create/update/complete/pause/resume/abandon/delete goals
- `manage_goal_step` (nil) — add/update/complete/skip/reorder/remove steps + manage step schedules
- `list_goals` (nil) — list goals with progress, or get single goal detail

**Schedule tools:** `list_schedules` returns all/enabled schedules. `manage_schedule` supports create/update/delete actions with dedup on create (same cron+message returns `already_exists`).

**Gmail tool:** `check_email` supports `list` (search with Gmail query syntax, optional `max_results`) and `read` (by `message_id`). Requires `gmail` bucket with an OAuth credential containing a refresh_token. Token refresh happens on each execute using app-level client_id/secret.

**Web search tool:** `web_search` POSTs to Tavily API with the API key in the JSON body. Params: query (required, max 2000 chars), max_results (default 5, max 10), search_depth (basic/advanced), include_domains, exclude_domains. Requires `web_search` bucket with a Tavily API key credential.

**Memory search:** `recall_memory` supports a `search` parameter for PostgreSQL full-text search (FTS) across keys, values, and memory types. Uses `websearch_to_tsquery` for Google-style syntax (quoted phrases, OR, -exclude). Priority order: key > search > list-all. The `agent_memories` table has a `search_ts` tsvector column with a GIN index, auto-populated by a BEFORE INSERT OR UPDATE trigger with weighted vectors (key=A, value=B, type=C).

**Goal tools:** Goals track multi-step objectives with auto-review schedules.
- `manage_goal` creates goals with inline steps (each step can have a cron schedule). Auto-creates an hourly review schedule linked via `review_schedule_id`.
- `manage_goal_step` manages individual steps: add (with optional cron), update, complete, skip, reorder, remove, add_schedule, remove_schedule.
- `list_goals` returns active goals by default with progress counts; `goal_id` param for single goal detail.
- Complete/abandon disables all associated schedules (review + step-linked). Delete removes schedules entirely.
- All tool responses include anti-loop `note` fields.

### Agentic Loop

`AgentProcess` runs a loop: LLM call → check for tool_use → execute tools → loop back with results → until text response.

**Key mitigations for smaller models (e.g. GPT-4o-mini):**
- **Repeated tool call detection:** If the LLM calls the same tools as the previous round, the second call is SKIPPED (not executed) and a nudge message is injected with the previous round's results, forcing a text response. This prevents wasted API calls, dedup confusion, and misleading error-based responses.
- **Empty content retry:** If the LLM returns empty text after tool use, a nudge with recent tool results is injected and the loop retries without tools.
- **Tool result notes:** `manage_schedule` results include a `note` field instructing the LLM to respond with text and not call the tool again.

---

## Design Philosophy

The user prefers **dark, atmospheric, luxurious** aesthetics with:
- Rich accent colors with glow/bloom effects
- Atmospheric visual elements (particles, orbs, gradients, SVG ornaments)
- Elegant typography pairing a distinctive display font with a refined body font
- Detailed Framer Motion animations (staggered reveals, continuous ambient motion)
- Glass/blur/transparency effects

Routes `/2` (Bioluminescent) and `/5` (Art Deco) are the original favorites that set the tone for all subsequent designs.

---

## Browser Testing

Use the Chrome MCP browser automation tools to test the dashboard UI. Both servers must be running first.

### Starting Servers

```bash
# Terminal 1: Backend (Phoenix)
cd src/backend && mix phx.server    # localhost:4000

# Terminal 2: Frontend (Next.js)
cd src/frontend && npm run dev      # localhost:3000
```

### Test Account

Register a test user via curl or through the UI:

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"user": {"email": "test@oneagent.dev", "password": "testpassword123"}}'
```

Credentials: `test@oneagent.dev` / `testpassword123`

### Test Script

Run through these flows using the Chrome MCP tools (`tabs_context_mcp`, `navigate`, `find`, `computer`, `read_page`, etc.):

#### 1. Landing Page Nav
- Navigate to `http://localhost:3000/`
- Verify nav bar shows "Login" and "Register" buttons (unauthenticated)
- Click "Login" → verify redirect to `/login`

#### 2. Registration
- Navigate to `http://localhost:3000/register`
- Fill email, password (12+ chars), confirm password
- Submit → verify redirect to `/dashboard`
- Verify nav now shows "Dashboard" and "Logout"

#### 3. Login
- Logout first, then navigate to `/login`
- Enter test credentials → submit
- Verify redirect to `/dashboard`
- Test "Forgot password?" link shows inline email form

#### 4. Dashboard — Agent CRUD
- On `/dashboard`, verify "Your Agents" heading, "Create Agent" button
- Click "Create Agent" → fill modal (name, provider, model_id, system prompt)
- Submit → verify new agent card appears in grid
- Verify card shows name, model provider, readiness indicator (Ready/Needs Config)
- Click "Open" → verify redirect to `/agents/[id]`
- Go back, click delete (✕) → verify agent removed

#### 5. Agent Detail — Chat Tab
- Open an agent → verify on Chat tab by default
- If no LLM config, verify banner "Configure an LLM API key to start chatting"
- With LLM config: type a message, press Enter → verify optimistic user bubble appears
- Verify typing indicator (3 dots) shows while waiting
- Verify assistant response appears (or error if no LLM key configured)
- Click "Clear History" → verify messages cleared

#### 6. Agent Detail — Settings Tab
- Click "Settings" tab
- Verify form pre-populated with agent data (name, description, model, prompt, etc.)
- Change a field (e.g. description) → click "Save Settings"
- Verify "Saved!" message appears
- In Schedules section: click "+ Add Schedule" → enter cron + message → save
- Verify new schedule appears in list. Click a cron preset → verify input updates
- Toggle schedule enabled/disabled. Delete a schedule.

#### 7. Agent Detail — Permissions Tab
- Click "Permissions" tab
- Verify 7 bucket cards (web_access, email, spending, communication, data_write, gmail, web_search)
- Toggle one on → verify toggle turns green, credential dropdown appears
- Click "Save Permissions"

#### 8. Agent Detail — Guide Tab
- Click "Guide" tab (or navigate to `/agents/[id]?tab=guide`)
- Verify API Access section with agent ID and curl examples
- Verify copy buttons work (click "Copy" → changes to "Copied!")
- Verify WhatsApp Setup section with numbered steps
- Verify Scheduling section with cron patterns table

#### 9. Keys Page
- Navigate to `/keys`
- **LLM API Keys**: Click "+ Add Key" → fill provider, label, API key → submit
- Verify new key appears in list with provider badge
- Click "Edit" → verify form pre-fills (api_key blank) → update label → save
- Click delete (✕) → verify removed
- **Tool Credentials**: Click "+ Add Credential" → fill name, service, type, value → submit
- Verify credential appears with service badge
- Test edit and delete

#### 10. Auth Protection
- Logout via nav button
- Try navigating directly to `/dashboard` → verify redirect to `/login`
- Try `/agents/some-id` → verify redirect to `/login`
- Try `/keys` → verify redirect to `/login`

### Tips for Chrome MCP Testing

- Call `tabs_context_mcp` first to get/create a tab
- Use `find` to locate elements by text (e.g., `find("Create Agent button")`)
- Use `form_input` with `ref` from `read_page` to fill inputs
- Use `computer` with `action: "screenshot"` to visually verify state
- Use `get_page_text` to quickly check page content
- Auth token is stored in an httpOnly cookie (`_oneagent_token`) — not accessible via JavaScript (by design)
- Rate limiting: auth routes are limited to 5 req/min — if you hit 429, wait 60 seconds
