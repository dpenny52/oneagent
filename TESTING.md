# Browser Testing

Use the Chrome MCP browser automation tools to test the dashboard UI. Both servers must be running first.

## Starting Servers

```bash
# Terminal 1: Backend (Phoenix)
cd src/backend && mix phx.server    # localhost:4000

# Terminal 2: Frontend (Next.js)
cd src/frontend && npm run dev      # localhost:3000
```

## Test Account

Register a test user via curl or through the UI:

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"user": {"email": "test@oneagent.dev", "password": "testpassword123"}}'
```

Credentials: `test@oneagent.dev` / `testpassword123`

## Test Script

Run through these flows using the Chrome MCP tools (`tabs_context_mcp`, `navigate`, `find`, `computer`, `read_page`, etc.):

### 1. Landing Page Nav
- Navigate to `http://localhost:3000/`
- Verify nav bar shows "Login" and "Register" buttons (unauthenticated)
- Click "Login" → verify redirect to `/login`

### 2. Registration
- Navigate to `http://localhost:3000/register`
- Fill email, password (12+ chars), confirm password
- Submit → verify redirect to `/dashboard`
- Verify nav now shows "Dashboard" and "Logout"

### 3. Login
- Logout first, then navigate to `/login`
- Enter test credentials → submit
- Verify redirect to `/dashboard`
- Test "Forgot password?" link shows inline email form

### 4. Dashboard — Agent CRUD
- On `/dashboard`, verify "Your Agents" heading, "Create Agent" button
- Click "Create Agent" → fill modal (name, provider, model_id, system prompt)
- Submit → verify new agent card appears in grid
- Verify card shows name, model provider, readiness indicator (Ready/Needs Config)
- Click "Open" → verify redirect to `/agents/[id]`
- Go back, click delete (✕) → verify agent removed

### 5. Agent Detail — Chat Tab
- Open an agent → verify on Chat tab by default
- If no LLM config, verify banner "Configure an LLM API key to start chatting"
- With LLM config: type a message, press Enter → verify optimistic user bubble appears
- Verify typing indicator (3 dots) shows while waiting
- Verify assistant response appears (or error if no LLM key configured)
- Click "Clear History" → verify messages cleared

### 6. Agent Detail — Settings Tab
- Click "Settings" tab
- Verify form pre-populated with agent data (name, description, model, prompt, etc.)
- Change a field (e.g. description) → click "Save Settings"
- Verify "Saved!" message appears
- In Schedules section: click "+ Add Schedule" → enter cron + message → save
- Verify new schedule appears in list. Click a cron preset → verify input updates
- Toggle schedule enabled/disabled. Delete a schedule.

### 7. Agent Detail — Permissions Tab
- Click "Permissions" tab
- Verify 7 bucket cards (web_access, email, spending, communication, data_write, gmail, web_search)
- Toggle one on → verify toggle turns green, credential dropdown appears
- Click "Save Permissions"

### 8. Agent Detail — Guide Tab
- Click "Guide" tab (or navigate to `/agents/[id]?tab=guide`)
- Verify API Access section with agent ID and curl examples
- Verify copy buttons work (click "Copy" → changes to "Copied!")
- Verify WhatsApp Setup section with numbered steps
- Verify Scheduling section with cron patterns table

### 9. Keys Page
- Navigate to `/keys`
- **LLM API Keys**: Click "+ Add Key" → fill provider, label, API key → submit
- Verify new key appears in list with provider badge
- Click "Edit" → verify form pre-fills (api_key blank) → update label → save
- Click delete (✕) → verify removed
- **Tool Credentials**: Click "+ Add Credential" → fill name, service, type, value → submit
- Verify credential appears with service badge
- Test edit and delete

### 10. Auth Protection
- Logout via nav button
- Try navigating directly to `/dashboard` → verify redirect to `/login`
- Try `/agents/some-id` → verify redirect to `/login`
- Try `/keys` → verify redirect to `/login`

## Tips for Chrome MCP Testing

- Call `tabs_context_mcp` first to get/create a tab
- Use `find` to locate elements by text (e.g., `find("Create Agent button")`)
- Use `form_input` with `ref` from `read_page` to fill inputs
- Use `computer` with `action: "screenshot"` to visually verify state
- Use `get_page_text` to quickly check page content
- Auth token is stored in an httpOnly cookie (`_oneagent_token`) — not accessible via JavaScript (by design)
- Rate limiting: auth routes are limited to 5 req/min — if you hit 429, wait 60 seconds
