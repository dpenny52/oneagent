# OneAgent

A platform to deploy persistent AI agents that live in the cloud. Describe your agent, click deploy, and it stays running — remembering context, executing tasks, and working on your behalf around the clock.

This repo contains the **Next.js frontend** and **Elixir/Phoenix API backend**.

## Quick Start

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

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/auth/register` | Create account |
| `POST` | `/api/auth/login` | Email/password login |
| `POST` | `/api/auth/magic-link` | Request magic link email |
| `POST` | `/api/auth/magic-link/verify` | Verify magic link token |
| `GET` | `/api/auth/google` | Google OAuth redirect |
| `GET` | `/api/auth/google/callback` | Google OAuth callback |
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
| `POST` | `/api/agents/:id/start` | Start agent process |
| `POST` | `/api/agents/:id/stop` | Stop agent process |
| `POST` | `/api/agents/:id/invoke` | Send message to agent |
| `CRUD` | `/api/credentials` | Encrypted credential storage |
| `CRUD` | `/api/llm-configs` | LLM API key management |
| `CRUD` | `/api/whatsapp-channels` | WhatsApp channel config |
| `GET` | `/api/webhooks/whatsapp` | Meta webhook verification |
| `POST` | `/api/webhooks/whatsapp` | Incoming WhatsApp messages |

All agent/credential/channel routes require Bearer auth. Webhook routes are unauthenticated (verified via HMAC-SHA256) and rate-limited to 60 req/min.

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
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | - |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | - |
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

## License

Private.
