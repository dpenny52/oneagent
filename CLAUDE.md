# OneAgent

A landing page gallery showcasing multiple design directions for **OneAgent** — a platform to deploy persistent AI agents that live in the cloud.

## Project Structure

```
oneagent/
  src/frontend/           # Next.js app (this is the actual project root for builds/dev)
    app/
      layout.tsx          # Root layout — bare HTML shell, no global providers
      page.tsx            # Home page — directory listing all designs with links
      globals.css         # Minimal global reset
      2/page.tsx          # Bioluminescent — organic glow, cyan/purple on dark navy
      5/page.tsx          # Art Deco — gold on black, geometric luxury, ornamental
      6/page.tsx          # Celestial Observatory — deep space, stellar gold, star maps
      7/page.tsx          # Noir Rose Gold — luxury dark minimalism, metallic accents
      8/page.tsx          # Deep Ocean Abyss — underwater bioluminescence, sonar rings
      9/page.tsx          # Volcanic Ember — obsidian forge, molten fissures, ember particles
      10/page.tsx         # Midnight Garden — moonlit botanicals, silver and emerald
      11/page.tsx         # (new design)
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

Every numbered page (`/2`, `/5`, `/6`, etc.) follows the same pattern:

1. **`"use client"`** directive at top — all pages are client components
2. **Imports**: `motion` from framer-motion, 2-3 Google Fonts, React hooks
3. **Google Fonts** initialized at module scope with `next/font/google`
4. **Color constants** defined as a palette object or individual constants
5. **Keyframe injection** via `useEffect` that creates a `<style>` element with an ID guard to prevent duplicates
6. **`useCountUp` hook** — custom hook using `IntersectionObserver` + `requestAnimationFrame` with eased animation for stat counters
7. **ALL styles are inline** `style={{}}` objects — no Tailwind utility classes, no CSS modules, no external stylesheets
8. **Framer Motion `whileInView`** for scroll-triggered entrance animations
9. **Single default export** function component

### Content Structure (consistent across all pages)

Each page presents the same product content with a unique aesthetic:

1. **Hero** — "OneAgent" title, tagline ("A living agent. Always awake. One click to life."), subtext about persistent AI, CTA button, scroll indicator
2. **Features** — 3 cards: "Instant Birth" (deploy <30s), "Persistent Memory" (knowledge graph), "Always Alive" (24/7 uptime)
3. **Lifecycle/Process** — Visualization of: Prompt → Spawn → Learn → Act → Remember → Evolve
4. **Stats** — 12,847 Agents, 99.99% Uptime, 28s Avg Deploy (animated counters)
5. **Final CTA** — Closing call-to-action with button
6. **Footer** — Copyright and minimal links

### Adding a New Design

1. Create `src/frontend/app/{N}/page.tsx` following the conventions above
2. Add an entry to the `designs` array in `src/frontend/app/page.tsx`

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
      repo.ex                  # Ecto Repo
      mailer.ex                # Swoosh mailer
    oneagent_web/
      controllers/
        user_registration_controller.ex   # POST /api/auth/register
        user_session_controller.ex        # POST /api/auth/login, magic-link, logout, me
        user_password_reset_controller.ex # POST /api/auth/forgot-password, reset-password
        user_confirmation_controller.ex   # POST /api/auth/confirm
        google_auth_controller.ex         # GET /api/auth/google, callback
        health_controller.ex              # GET /api/health
        auth_json.ex                      # JSON view for all auth responses
        fallback_controller.ex            # Centralized error rendering
      plugs/
        rate_limit.ex          # Hammer-based rate limiting (5 req/min on auth)
      user_auth.ex             # Bearer token auth plug
      router.ex                # API routes
      endpoint.ex              # CORS (Corsica), parsers, static
  config/
    config.exs                 # Base config (Hammer, Ueberauth, etc.)
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
| GET | `/api/health` | No | No |

---

## Design Philosophy

The user prefers **dark, atmospheric, luxurious** aesthetics with:
- Rich accent colors with glow/bloom effects
- Atmospheric visual elements (particles, orbs, gradients, SVG ornaments)
- Elegant typography pairing a distinctive display font with a refined body font
- Detailed Framer Motion animations (staggered reveals, continuous ambient motion)
- Glass/blur/transparency effects

Routes `/2` (Bioluminescent) and `/5` (Art Deco) are the original favorites that set the tone for all subsequent designs.
