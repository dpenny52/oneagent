# OneAgent

A platform to deploy persistent AI agents that live in the cloud, with a bioluminescent-themed landing page and full authenticated dashboard.

## Project Structure

```
oneagent/
  src/frontend/               # Next.js app (this is the actual project root for builds/dev)
    app/
      layout.tsx              # Root layout — wraps children in <Providers> (AuthProvider)
      page.tsx                # Landing page — bioluminescent theme, auth-aware nav bar
      globals.css             # Minimal global reset
      lib/
        theme.ts              # Shared color palette (C), style helpers (inputStyle, buttonStyle, etc.)
        api.ts                # Fetch wrapper — Bearer auth, {data:} unwrap, 401 redirect
        auth.tsx              # AuthProvider + useAuth() hook (token → GET /api/auth/me)
        protected.tsx         # Route guard component — redirects to /login if unauthenticated
        providers.tsx         # "use client" wrapper for AuthProvider (used in layout.tsx)
      login/page.tsx          # Login — password/magic-link tabs, inline forgot-password
      register/page.tsx       # Registration — email + password + confirm
      reset-password/page.tsx # Reset password — token from URL, new password form
      dashboard/page.tsx      # Agent list — grid cards, create modal, delete (protected)
      agents/[id]/page.tsx    # Agent detail — Chat, Settings, Permissions, Guide tabs (protected)
      keys/page.tsx           # LLM API keys + tool credentials CRUD (protected)
    package.json
    next.config.ts
    tsconfig.json
```

## Tech Stack

- **Next.js 16.1.6** with App Router (Turbopack)
- **React 19.2.3** / TypeScript 5
- **Framer Motion 12.33** for all animations
- **Tailwind CSS 4** is installed but NOT used in page components — all styling is inline
- Google Fonts loaded via `next/font/google`

## Commands

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
| `/keys` | Yes | LLM API keys + tool credentials management |

---

## Backend (Elixir/Phoenix API)

### Project Structure

```
src/backend/                   # Elixir/Phoenix API-only app
  lib/
    oneagent/
      accounts/                # Accounts context
        user.ex                # User schema (email, password, google_uid, etc.)
        user_token.ex          # Token schema (session, api-token, magic-link, confirm, reset)
        user_notifier.ex       # Email delivery functions
        scope.ex               # Caller scope struct
      accounts.ex              # Accounts context (registration, login, OAuth, tokens)
      agents/                  # Agent domain schemas
        agent.ex               # Agent schema (name, system_prompt, model, etc.)
        agent_bucket.ex        # Permission bucket schema
        agent_run.ex           # Execution run schema
        agent_step.ex          # Run step schema (LLM calls, tool executions)
        agent_memory.ex        # Persistent key-value memory schema
        agent_message.ex       # Chat history message schema (role, content, sequence)
        agent_schedule.ex      # Cron schedule schema (multiple per agent)
      agents.ex                # Agents context (CRUD, buckets, runs, steps, memory, messages, schedules)
      credentials/             # Credential domain schemas
        credential.ex          # Encrypted credential schema (AES-256-GCM)
        llm_config.ex          # LLM API key schema
      credentials.ex           # Credentials context (CRUD + decryption)
      tools/                   # Agent tools (LLM-callable)
        http_request.ex        # HTTP requests (dynamic bucket based on URL)
        read_webpage.ex        # Read webpage content (web_access bucket)
        send_email.ex          # Send email (email bucket)
        store_memory.ex        # Store key-value memory (no bucket)
        recall_memory.ex       # Recall stored memory (no bucket)
        list_schedules.ex      # List agent's cron schedules (no bucket)
        manage_schedule.ex     # Create/update/delete schedules (no bucket)
      runtime/                 # Agent runtime
        agent_process.ex       # GenServer per agent — agentic loop with chat history
        agent_supervisor.ex    # DynamicSupervisor for agent processes
      runtime.ex               # Runtime public API (invoke with auto-start)
      workers/                 # Oban background workers
        schedule_checker.ex    # Cron worker — finds enabled schedules due to run each minute
        scheduled_execution.ex # Per-schedule execution worker
      whatsapp/                # WhatsApp integration
        channel.ex             # Channel schema (phone_number_id → agent mapping)
        client.ex              # Cloud API client (HMAC verify, send/parse messages)
      whatsapp.ex              # WhatsApp context (scoped CRUD + unscoped webhook lookups)
      repo.ex                  # Ecto Repo
      vault.ex                 # Cloak vault for AES-256-GCM encryption
      mailer.ex                # Swoosh mailer
    oneagent_web/
      controllers/
        user_registration_controller.ex   # POST /api/auth/register
        user_session_controller.ex        # POST /api/auth/login, magic-link, logout, me
        user_password_reset_controller.ex # POST /api/auth/forgot-password, reset-password
        user_confirmation_controller.ex   # POST /api/auth/confirm
        google_auth_controller.ex         # GET /api/auth/google, callback
        health_controller.ex              # GET /api/health
        agent_controller.ex               # Agent CRUD + buckets + runs + memory + messages + schedules
        agent_json.ex                     # JSON views for agents, runs, buckets, messages
        credential_controller.ex          # CRUD /api/credentials
        credential_json.ex                # JSON view for credentials
        llm_config_controller.ex          # CRUD /api/llm-configs
        llm_config_json.ex                # JSON view for LLM configs
        auth_json.ex                      # JSON view for all auth responses
        fallback_controller.ex            # Centralized error rendering
        whatsapp_webhook_controller.ex    # GET/POST /api/webhooks/whatsapp
        whatsapp_channel_controller.ex    # CRUD /api/whatsapp-channels
        whatsapp_channel_json.ex          # JSON view for channels
      plugs/
        rate_limit.ex          # Hammer-based rate limiting (5 req/min on auth)
        cache_raw_body.ex      # Caches raw body for HMAC signature verification
      user_auth.ex             # Bearer token auth plug
      router.ex                # API routes
      endpoint.ex              # CORS (Corsica), parsers, static
  config/
    config.exs                 # Base config (Hammer, Ueberauth, Oban, etc.)
    dev.exs                    # Dev database config
    test.exs                   # Test config
    runtime.exs                # Runtime env vars (DATABASE_URL, SECRET_KEY_BASE, etc.)
  priv/repo/migrations/        # Ecto migrations
```

### Tech Stack

- **Elixir 1.19** / **Erlang/OTP 28**
- **Phoenix 1.8** (API-only, no HTML/LiveView)
- **Ecto** with **PostgreSQL** (binary UUIDs)
- **bcrypt_elixir** for password hashing
- **Ueberauth** + **ueberauth_google** for Google OAuth
- **Corsica** for CORS
- **Hammer** for rate limiting
- **Swoosh** for email delivery
- **Oban** for background job processing and scheduled agent execution
- **Crontab** for cron expression parsing
- **cloak_ecto** for AES-256-GCM field encryption

### Commands

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

### API Endpoints

| Method | Path | Auth | Rate Limited |
|--------|------|------|-------------|
| POST | `/api/auth/register` | No | Yes |
| POST | `/api/auth/login` | No | Yes |
| POST | `/api/auth/magic-link` | No | Yes |
| POST | `/api/auth/magic-link/verify` | No | Yes |
| GET | `/api/auth/google` | No | No |
| GET | `/api/auth/google/callback` | No | No |
| DELETE | `/api/auth/logout` | Bearer | No |
| GET | `/api/auth/me` | Bearer | No |
| PUT | `/api/auth/password` | Bearer | No |
| POST | `/api/auth/forgot-password` | No | Yes |
| POST | `/api/auth/reset-password` | No | Yes |
| POST | `/api/auth/confirm` | Bearer | No |
| POST | `/api/auth/confirm/:token` | No | Yes |
| CRUD | `/api/agents` | Bearer | No |
| POST | `/api/agents/:id/invoke` | Bearer | No |
| GET | `/api/agents/:id/buckets` | Bearer | No |
| PUT | `/api/agents/:id/buckets` | Bearer | No |
| GET | `/api/agents/:id/runs` | Bearer | No |
| GET | `/api/agents/:id/runs/:id` | Bearer | No |
| GET | `/api/agents/:id/memory` | Bearer | No |
| DELETE | `/api/agents/:id/memory` | Bearer | No |
| GET | `/api/agents/:id/messages` | Bearer | No |
| DELETE | `/api/agents/:id/messages` | Bearer | No |
| GET | `/api/agents/:id/schedules` | Bearer | No |
| POST | `/api/agents/:id/schedules` | Bearer | No |
| PUT | `/api/agents/:id/schedules/:id` | Bearer | No |
| DELETE | `/api/agents/:id/schedules/:id` | Bearer | No |
| CRUD | `/api/credentials` | Bearer | No |
| CRUD | `/api/llm-configs` | Bearer | No |
| CRUD | `/api/whatsapp-channels` | Bearer | No |
| GET | `/api/health` | No | No |
| GET | `/api/webhooks/whatsapp` | No | Yes (60/min) |
| POST | `/api/webhooks/whatsapp` | No | Yes (60/min) |
| GET | `/api/whatsapp-channels` | Bearer | No |
| POST | `/api/whatsapp-channels` | Bearer | No |
| GET | `/api/whatsapp-channels/:id` | Bearer | No |
| PUT | `/api/whatsapp-channels/:id` | Bearer | No |
| DELETE | `/api/whatsapp-channels/:id` | Bearer | No |

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

### Agent Tools

Tools are registered in `OneAgent.Tools` and exposed to the LLM filtered by the agent's active permission buckets. Tools with `bucket: nil` are always available.

**Available tools:** `http_request` (dynamic bucket), `read_webpage` (web_access), `send_email` (email), `store_memory` (nil), `recall_memory` (nil), `list_schedules` (nil), `manage_schedule` (nil).

**Schedule tools:** `list_schedules` returns all/enabled schedules. `manage_schedule` supports create/update/delete actions with dedup on create (same cron+message returns `already_exists`).

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
- Verify 5 bucket cards (web_access, email, spending, communication, data_write)
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
- Auth token is stored in localStorage — use `javascript_tool` to check: `localStorage.getItem("auth_token")`
- Rate limiting: auth routes are limited to 5 req/min — if you hit 429, wait 60 seconds
