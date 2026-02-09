# OneAgent

A platform to deploy persistent AI agents that live in the cloud. Describe your agent, click deploy, and it stays running — remembering context, executing tasks, and working on your behalf around the clock.

This repo contains the **Next.js frontend** and **Elixir/Phoenix API backend**.

## Tools & Integrations

Agents operate within permission buckets that control which tools they can use. Each bucket unlocks specific capabilities:

| Bucket | Tool | Description |
|--------|------|-------------|
| `web_access` | `read_webpage` | Fetch and read web page content |
| `web_access` / `data_write` | `http_request` | Make HTTP requests (GET uses web_access, POST/PUT/DELETE uses data_write) |
| `email` | `send_email` | Send emails via Resend API |
| `gmail` | `check_email` | Read Gmail inbox — list/search emails, read full messages (OAuth2) |
| `spending` | — | Reserved for financial transaction tools |
| `communication` | — | Reserved for messaging tools (WhatsApp, Slack) |
| `data_write` | — | Allow writing/modifying external data |
| *(always available)* | `store_memory` | Persist key-value data across conversations |
| *(always available)* | `recall_memory` | Retrieve stored memories |
| *(always available)* | `list_schedules` | View agent's cron schedules |
| *(always available)* | `manage_schedule` | Create, update, or delete cron schedules |

### Integrations

- **Gmail** — OAuth2 flow via `/keys` page. User connects their Google account, agent gets read-only access to their inbox via the `check_email` tool.
- **WhatsApp** — Agents receive and reply to WhatsApp messages via Meta's Cloud API. Configure a channel linking a phone number to an agent.
- **Cron Schedules** — Agents can have multiple cron schedules that fire automatically. Agents can also manage their own schedules via tools.

## Quick Start (Docker)

The easiest way to get running. Requires Docker and Docker Compose.

```bash
docker compose up -d          # Start app + Postgres containers
docker compose exec app bash  # Shell into the dev container

# Inside the container:
cd src/backend
mix deps.get
mix ecto.setup
mix phx.server &              # http://localhost:4001

cd /workspace/src/frontend
npm install
npm run dev                   # http://localhost:3001
```

Ports are mapped to **3001** (frontend) and **4001** (backend) on the host to avoid conflicts with local services.

## Quick Start (Local)

**Prerequisites:** Node.js 20+, Elixir 1.19+, PostgreSQL

```bash
# Backend
cd src/backend
mix deps.get
mix ecto.setup
mix phx.server          # http://localhost:4000

# Frontend (separate terminal)
cd src/frontend
npm install
npm run dev             # http://localhost:3000
```

## Project Structure

```
oneagent/
  src/
    frontend/            # Next.js 16 — landing pages, login, app UI
      app/
        page.tsx         # Landing page (bioluminescent design)
        login/page.tsx   # Login — email/password + magic link
        globals.css
    backend/             # Phoenix 1.8 — API-only, no HTML
      lib/
        oneagent/        # Business logic (Accounts context)
        oneagent_web/    # Controllers, router, auth plugs
      config/
      priv/repo/         # Ecto migrations
```

## Frontend

| | |
|---|---|
| **Framework** | Next.js 16.1.6, React 19, TypeScript 5 |
| **Animations** | Framer Motion 12.33 |
| **Styling** | All inline `style={{}}` — no Tailwind in components |
| **Fonts** | Google Fonts via `next/font/google` |

### Pages

- **`/`** — Landing page with bioluminescent aesthetic: floating spores, ambient orbs, glass-morphism cards, scroll-triggered animations
- **`/login`** — Auth page with password and magic link modes, connected to the backend API

### Commands

```bash
cd src/frontend
npm run dev        # Dev server with Turbopack
npm run build      # Production build
npm run lint       # ESLint
```

## Backend

| | |
|---|---|
| **Framework** | Phoenix 1.8 (API-only) |
| **Language** | Elixir 1.19 / Erlang OTP 28 |
| **Database** | PostgreSQL with binary UUIDs |
| **Auth** | Bearer tokens (SHA-256 hashed), bcrypt passwords |
| **Jobs** | Oban (scheduled agent execution, cron sweeper) |
| **Encryption** | cloak_ecto (AES-256-GCM for credentials) |

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/auth/register` | Create account |
| `POST` | `/api/auth/login` | Email/password login |
| `POST` | `/api/auth/magic-link` | Request magic link email |
| `POST` | `/api/auth/magic-link/verify` | Verify magic link token |
| `GET` | `/api/auth/google` | Google OAuth redirect |
| `GET` | `/api/auth/google/callback` | Google OAuth callback |
| `GET` | `/api/auth/gmail` | Gmail OAuth initiate (requires auth) |
| `GET` | `/api/auth/gmail/callback` | Gmail OAuth callback |
| `DELETE` | `/api/auth/logout` | Revoke token |
| `GET` | `/api/auth/me` | Current user |
| `PUT` | `/api/auth/password` | Change password |
| `POST` | `/api/auth/forgot-password` | Request password reset |
| `POST` | `/api/auth/reset-password` | Reset password |
| `POST` | `/api/auth/confirm/:token` | Confirm email |
| `GET` | `/api/health` | Health check |

#### Agent & Credential Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `CRUD` | `/api/agents` | Agent management |
| `POST` | `/api/agents/:id/invoke` | Send message to agent |
| `GET/PUT` | `/api/agents/:id/buckets` | Permission bucket management |
| `GET` | `/api/agents/:id/runs` | List execution runs |
| `GET` | `/api/agents/:id/runs/:id` | Run details with steps |
| `GET` | `/api/agents/:id/memory` | Agent persistent memory |
| `DELETE` | `/api/agents/:id/memory` | Clear agent memory |
| `GET` | `/api/agents/:id/messages` | Chat history |
| `DELETE` | `/api/agents/:id/messages` | Clear chat history |
| `CRUD` | `/api/agents/:id/schedules` | Cron schedule management |
| `CRUD` | `/api/credentials` | Encrypted credential storage |
| `CRUD` | `/api/llm-configs` | LLM API key management |
| `CRUD` | `/api/whatsapp-channels` | WhatsApp channel config |
| `GET` | `/api/webhooks/whatsapp` | Meta webhook verification |
| `POST` | `/api/webhooks/whatsapp` | Incoming WhatsApp messages |

All agent/credential/channel routes require Bearer auth. Webhook routes are unauthenticated (verified via HMAC-SHA256) and rate-limited to 60 req/min.

### Key Features

- **Chat History** — Conversation messages persist across runs in `agent_messages`. Agents recall prior context (configurable limit via `max_history_messages`, default 20). View with `GET /api/agents/:id/messages`, clear with `DELETE`.
- **Scheduled Execution** — Agents support multiple cron schedules that fire automatically via Oban. A sweeper checks every minute and enqueues per-schedule execution jobs with deduplication. Agents can also manage their own schedules via tools.
- **Permission Buckets** — Agents operate within granted permission buckets (web_access, email, spending, communication, data_write, gmail) that control which tools they can use.
- **Gmail Integration** — OAuth2 flow connects a user's Gmail account. Agents with the `gmail` bucket can list, search, and read emails.
- **User Isolation** — All agent/credential/channel queries are scoped to the authenticated user. Users can only see and manage their own resources.

### Commands

```bash
cd src/backend
mix deps.get         # Install dependencies
mix ecto.setup       # Create DB + migrate + seed
mix phx.server       # Start on http://localhost:4000
mix test             # Run test suite
```

## Environment Variables

The backend reads these at runtime (see `src/backend/.env.example`):

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | local dev DB |
| `SECRET_KEY_BASE` | Phoenix signing secret | dev default |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID (also used for Gmail) | - |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret (also used for Gmail) | - |
| `GOOGLE_GMAIL_CLIENT_ID` | Gmail-specific OAuth client ID (optional, falls back to above) | - |
| `GOOGLE_GMAIL_CLIENT_SECRET` | Gmail-specific OAuth client secret (optional, falls back to above) | - |
| `CORS_ORIGIN` | Allowed frontend origin | `http://localhost:3000` |
| `PORT` | HTTP port | `4000` |

The frontend uses:

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_API_URL` | Backend API base URL | `http://localhost:4000` |

## Credentials Setup

All secrets are stored **encrypted in the database** (AES-256-GCM via `cloak_ecto`), not in environment variables or config files. Use the API to create them after registering a user.

### 1. LLM API Key

Stored in the `llm_configs` table. Required for agents to call an LLM.

```bash
curl -X POST http://localhost:4000/api/llm-configs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"llm_config": {
    "provider": "anthropic",
    "api_key": "sk-ant-...",
    "label": "My Anthropic Key",
    "is_default": true
  }}'
```

| Field | Description |
|-------|-------------|
| `provider` | `"anthropic"` or `"openai"` |
| `api_key` | Your API key (encrypted at rest, never exposed via API) |
| `label` | Display name |
| `is_default` | Use as default for new agents |

Then assign it to an agent: `PUT /api/agents/:id` with `{"agent": {"llm_config_id": "..."}}`

### 2. WhatsApp Credentials

Stored in the `credentials` table as an encrypted JSON blob. Required for WhatsApp integration.

```bash
curl -X POST http://localhost:4000/api/credentials \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"credential": {
    "name": "WhatsApp Cloud API",
    "service": "whatsapp",
    "credential_type": "custom",
    "value": "{\"access_token\": \"EAA...\", \"app_secret\": \"...\"}",
    "metadata": {"phone_number_id": "123456", "waba_id": "789"}
  }}'
```

| Field | Where to find it |
|-------|-----------------|
| `access_token` | Meta Developer Dashboard > WhatsApp > API Setup |
| `app_secret` | Meta Developer Dashboard > App Settings > Basic |
| `phone_number_id` | Meta Developer Dashboard > WhatsApp > API Setup (numeric ID) |

### 3. WhatsApp Channel

Links a WhatsApp phone number to an agent and its credentials.

```bash
curl -X POST http://localhost:4000/api/whatsapp-channels \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"channel": {
    "agent_id": "...",
    "credential_id": "...",
    "phone_number_id": "123456",
    "display_phone_number": "+1 555 000 1234"
  }}'
```

The response includes a `verify_token` (only shown once). Use it to configure the webhook in Meta's dashboard:

| Meta Dashboard Field | Value |
|---------------------|-------|
| **Callback URL** | `https://your-domain.com/api/webhooks/whatsapp` |
| **Verify token** | The `verify_token` from the create response |
| **Webhook fields** | Subscribe to `messages` |

For local development, use [ngrok](https://ngrok.com) to expose `localhost:4000`.

### 4. Gmail (OAuth2)

Gmail credentials are created automatically via the OAuth flow — no manual API calls needed.

1. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` env vars
2. Enable the Gmail API in your Google Cloud project
3. Add `http://localhost:4000/api/auth/gmail/callback` as an authorized redirect URI
4. Add yourself as a test user in the OAuth consent screen (while app is in testing mode)
5. Click "Connect Gmail" on the `/keys` page in the UI
6. Grant the `gmail` permission bucket to your agent and assign the Gmail credential

The agent can then use the `check_email` tool to list and read your emails.

## License

Private.
