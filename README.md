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

Public auth routes are rate-limited to 5 requests/minute via Hammer. Authenticated routes require a `Bearer` token in the `Authorization` header.

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

## License

Private.
