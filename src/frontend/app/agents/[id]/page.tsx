"use client";

import { motion, AnimatePresence } from "framer-motion";
import { Instrument_Serif, DM_Sans, Lora } from "next/font/google";
import { useEffect, useState, useRef, FormEvent, useCallback } from "react";
import { useParams, useSearchParams } from "next/navigation";
import { useAuth } from "../../lib/auth";
import { api } from "../../lib/api";
import { Protected } from "../../lib/protected";
import { C, inputStyle, inputFocusCSS, buttonStyle, labelStyle, glassCard } from "../../lib/theme";

const instrumentSerif = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal", "italic"], variable: "--font-instrument" });
const dmSans = DM_Sans({ subsets: ["latin"], weight: ["300", "400", "500", "600"], variable: "--font-dm" });
const lora = Lora({ subsets: ["latin"], weight: ["400", "500"], style: ["normal", "italic"], variable: "--font-lora" });

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */
interface Agent {
  id: string;
  name: string;
  description: string | null;
  system_prompt: string;
  status: string;
  model_provider: string;
  model_id: string;
  model_config: Record<string, unknown>;
  trigger_type: string;
  trigger_config: Record<string, unknown>;
  max_steps_per_run: number;
  max_runs_per_day: number;
  max_history_messages: number;
  llm_config_id: string | null;
}

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  sequence: number;
  inserted_at: string;
}

interface Bucket {
  id: string;
  bucket: string;
  scope_config: Record<string, unknown> | null;
  credential_id: string | null;
  granted_at: string | null;
  revoked_at: string | null;
}

interface LlmConfig {
  id: string;
  provider: string;
  label: string;
  is_default: boolean;
}

interface Credential {
  id: string;
  name: string;
  service: string;
  credential_type: string;
}

type Tab = "chat" | "settings" | "permissions" | "guide";

/* ------------------------------------------------------------------ */
/*  Keyframes                                                          */
/* ------------------------------------------------------------------ */
function useKeyframes() {
  useEffect(() => {
    const id = "agent-detail-kf";
    if (document.getElementById(id)) return;
    const s = document.createElement("style");
    s.id = id;
    s.textContent = `
      @keyframes drift1 { 0%,100%{transform:translate(0,0) scale(1)} 25%{transform:translate(50px,-35px) scale(1.08)} 50%{transform:translate(-25px,45px) scale(0.95)} 75%{transform:translate(35px,20px) scale(1.04)} }
      @keyframes drift2 { 0%,100%{transform:translate(0,0) scale(1)} 25%{transform:translate(-40px,40px) scale(1.06)} 50%{transform:translate(30px,-25px) scale(0.93)} 75%{transform:translate(-15px,-50px) scale(1.02)} }
      @keyframes meshShift { 0%{background-position:0% 50%,100% 50%,50% 0%} 25%{background-position:100% 0%,0% 100%,50% 50%} 50%{background-position:50% 100%,50% 0%,0% 50%} 75%{background-position:0% 0%,100% 100%,100% 50%} 100%{background-position:0% 50%,100% 50%,50% 0%} }
      @keyframes typingDot { 0%,100%{opacity:0.3} 50%{opacity:1} }
    `;
    document.head.appendChild(s);
    return () => { const el = document.getElementById(id); if (el) el.remove(); };
  }, []);
}

function Orb({ size, color, top, left, animation, duration, opacity = 0.2 }: { size: number; color: string; top: string; left: string; animation: string; duration: string; opacity?: number }) {
  return <div style={{ position: "absolute", width: size, height: size, borderRadius: "50%", background: `radial-gradient(circle at 30% 30%, ${color}, transparent 70%)`, filter: `blur(${size * 0.4}px)`, opacity, top, left, animation: `${animation} ${duration} ease-in-out infinite`, pointerEvents: "none", willChange: "transform" }} />;
}

/* ------------------------------------------------------------------ */
/*  Status badge                                                       */
/* ------------------------------------------------------------------ */
function statusColor(status: string) {
  switch (status) {
    case "running": return { bg: "rgba(0,212,170,0.12)", border: `${C.glow}44`, text: C.glow };
    case "stopped": return { bg: "rgba(255,107,107,0.08)", border: "rgba(255,107,107,0.3)", text: C.danger };
    case "paused": return { bg: "rgba(255,200,50,0.08)", border: "rgba(255,200,50,0.3)", text: "#FFD166" };
    default: return { bg: "rgba(216,237,230,0.06)", border: C.faint, text: C.muted };
  }
}

/* ------------------------------------------------------------------ */
/*  Focus helpers                                                      */
/* ------------------------------------------------------------------ */
function applyFocus(e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) {
  const base = inputStyle();
  const cssStr = Object.entries(base).map(([k, v]) => `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`).join(";");
  e.currentTarget.setAttribute("style", `${cssStr}; ${inputFocusCSS}`);
}
function removeFocus(e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) {
  Object.assign(e.currentTarget.style, inputStyle());
}

/* ------------------------------------------------------------------ */
/*  Copyable code block                                                */
/* ------------------------------------------------------------------ */
function CodeBlock({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div style={{ position: "relative", marginBottom: "1rem" }}>
      <pre style={{ padding: "1rem", borderRadius: 10, background: "rgba(0,0,0,0.3)", border: `1px solid ${C.faint}`, color: C.phosphor, fontSize: "0.8rem", fontFamily: "monospace", overflowX: "auto", whiteSpace: "pre-wrap", wordBreak: "break-all", lineHeight: 1.5 }}>{code}</pre>
      <button onClick={() => { navigator.clipboard.writeText(code); setCopied(true); setTimeout(() => setCopied(false), 1500); }} style={{ position: "absolute", top: 8, right: 8, padding: "0.3rem 0.6rem", borderRadius: 6, border: `1px solid ${C.faint}`, background: "rgba(6,14,18,0.8)", color: copied ? C.glow : C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.7rem", cursor: "pointer" }}>
        {copied ? "Copied!" : "Copy"}
      </button>
    </div>
  );
}

/* ================================================================== */
/*  Agent detail content                                               */
/* ================================================================== */
function AgentDetailContent() {
  useKeyframes();
  const params = useParams();
  const searchParams = useSearchParams();
  const agentId = params.id as string;
  const { logout } = useAuth();

  const [agent, setAgent] = useState<Agent | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>((searchParams.get("tab") as Tab) || "chat");

  // Chat state
  const [messages, setMessages] = useState<Message[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [sending, setSending] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  // Settings state
  const [settingsForm, setSettingsForm] = useState<Partial<Agent>>({});
  const [configs, setConfigs] = useState<LlmConfig[]>([]);
  const [settingsLoading, setSaving] = useState(false);
  const [settingsMsg, setSettingsMsg] = useState("");

  // Lifecycle state
  const [lifecycleError, setLifecycleError] = useState("");

  // Permissions state
  const [buckets, setBuckets] = useState<Bucket[]>([]);
  const [bucketsLoaded, setBucketsLoaded] = useState(false);
  const [credentials, setCredentials] = useState<Credential[]>([]);
  const [permLoading, setPermLoading] = useState(false);
  const [permMsg, setPermMsg] = useState("");

  const BUCKET_NAMES = ["web_access", "email", "spending", "communication", "data_write"];

  const MODEL_OPTIONS: Record<string, { id: string; label: string }[]> = {
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

  /* ---- Load agent ---- */
  useEffect(() => {
    async function load() {
      const res = await api.get<Agent>(`/api/agents/${agentId}`);
      if (res.ok) {
        setAgent(res.data);
        setSettingsForm(res.data);
      }
      setLoading(false);
    }
    load();
  }, [agentId]);

  /* ---- Load messages when chat tab ---- */
  const loadMessages = useCallback(async () => {
    const res = await api.get<Message[]>(`/api/agents/${agentId}/messages`);
    if (res.ok) setMessages(res.data);
  }, [agentId]);

  useEffect(() => {
    if (tab === "chat") loadMessages();
  }, [tab, loadMessages]);

  /* ---- Load buckets + credentials when permissions tab (only first visit) ---- */
  useEffect(() => {
    if (tab === "permissions" && !bucketsLoaded) {
      api.get<Bucket[]>(`/api/agents/${agentId}/buckets`).then((r) => { if (r.ok) { setBuckets(r.data); setBucketsLoaded(true); } });
      api.get<Credential[]>("/api/credentials").then((r) => { if (r.ok) setCredentials(r.data); });
    }
  }, [tab, agentId, bucketsLoaded]);

  /* ---- Load configs when settings tab ---- */
  useEffect(() => {
    if (tab === "settings") {
      api.get<LlmConfig[]>("/api/llm-configs").then((r) => { if (r.ok) setConfigs(r.data); });
    }
  }, [tab]);

  /* ---- Scroll to bottom on new messages ---- */
  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, sending]);

  /* ---- Chat actions ---- */
  async function handleSend(e?: FormEvent) {
    e?.preventDefault();
    if (!chatInput.trim() || sending) return;
    const text = chatInput.trim();
    setChatInput("");
    // Optimistic user message
    setMessages((prev) => [...prev, { id: `temp-${Date.now()}`, role: "user", content: text, sequence: 0, inserted_at: new Date().toISOString() }]);
    setSending(true);
    const res = await api.post<{ response: string }>(`/api/agents/${agentId}/invoke`, { message: text });
    setSending(false);
    if (res.ok) {
      await loadMessages();
    } else {
      setMessages((prev) => [...prev, { id: `err-${Date.now()}`, role: "assistant", content: `Error: ${res.error}`, sequence: 0, inserted_at: new Date().toISOString() }]);
    }
  }

  async function handleClearHistory() {
    await api.del(`/api/agents/${agentId}/messages`);
    setMessages([]);
  }

  /* ---- Agent lifecycle ---- */
  async function handleStart() {
    setLifecycleError("");
    const res = await api.post<Agent>(`/api/agents/${agentId}/start`);
    if (res.ok) setAgent(res.data);
    else setLifecycleError(res.error || "Failed to start agent");
  }
  async function handleStop() {
    setLifecycleError("");
    const res = await api.post<Agent>(`/api/agents/${agentId}/stop`);
    if (res.ok) setAgent(res.data);
    else setLifecycleError(res.error || "Failed to stop agent");
  }

  /* ---- Settings save ---- */
  async function handleSaveSettings(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setSettingsMsg("");
    const body: Record<string, unknown> = { agent: settingsForm };
    const res = await api.put<Agent>(`/api/agents/${agentId}`, body);
    setSaving(false);
    if (res.ok) {
      setAgent(res.data);
      setSettingsForm(res.data);
      setSettingsMsg("Saved!");
      setTimeout(() => setSettingsMsg(""), 2000);
    } else {
      setSettingsMsg(`Error: ${res.error}`);
    }
  }

  /* ---- Permissions save ---- */
  async function handleSavePermissions() {
    setPermLoading(true);
    setPermMsg("");
    const payload = BUCKET_NAMES.map((name) => {
      const existing = buckets.find((b) => b.bucket === name);
      if (existing && !existing.revoked_at) {
        return { bucket: name, scope_config: existing.scope_config, credential_id: existing.credential_id };
      }
      return null;
    }).filter(Boolean);
    const res = await api.put<Bucket[]>(`/api/agents/${agentId}/buckets`, { buckets: payload });
    setPermLoading(false);
    if (res.ok) {
      setBuckets(res.data);
      setPermMsg("Saved!");
      setTimeout(() => setPermMsg(""), 2000);
    } else {
      setPermMsg(`Error: ${res.error}`);
    }
  }

  function toggleBucket(name: string) {
    setBuckets((prev) => {
      const existing = prev.find((b) => b.bucket === name);
      if (existing && !existing.revoked_at) {
        // Revoke
        return prev.map((b) => b.bucket === name ? { ...b, revoked_at: new Date().toISOString() } : b);
      } else if (existing) {
        // Re-grant
        return prev.map((b) => b.bucket === name ? { ...b, revoked_at: null } : b);
      } else {
        // Add new
        return [...prev, { id: `new-${name}`, bucket: name, scope_config: null, credential_id: null, granted_at: new Date().toISOString(), revoked_at: null }];
      }
    });
  }

  function setBucketCredential(name: string, credId: string) {
    setBuckets((prev) =>
      prev.map((b) => b.bucket === name ? { ...b, credential_id: credId || null } : b)
    );
  }

  if (loading) {
    return <div style={{ minHeight: "100vh", background: C.bg, display: "flex", alignItems: "center", justifyContent: "center", color: C.muted }}>Loading...</div>;
  }

  if (!agent) {
    return <div style={{ minHeight: "100vh", background: C.bg, display: "flex", alignItems: "center", justifyContent: "center", color: C.danger }}>Agent not found</div>;
  }

  const sc = statusColor(agent.status);
  const selectStyle: React.CSSProperties = { ...inputStyle(), appearance: "none" as const, cursor: "pointer" };
  const tabNames: Tab[] = ["chat", "settings", "permissions", "guide"];
  function switchTab(t: Tab) { setTab(t); setLifecycleError(""); }

  return (
    <div className={`${instrumentSerif.variable} ${dmSans.variable} ${lora.variable}`} style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "var(--font-dm), sans-serif", position: "relative" }}>
      <Orb size={400} color={C.glow} top="-5%" left="-8%" animation="drift1" duration="20s" opacity={0.06} />
      <Orb size={300} color={C.lavender} top="40%" left="85%" animation="drift2" duration="24s" opacity={0.05} />
      <div style={{ position: "fixed", inset: 0, zIndex: 0, opacity: 0.15, background: `radial-gradient(ellipse 55% 45% at 20% 50%, ${C.glowDim} 0%, transparent 70%), radial-gradient(ellipse 45% 55% at 80% 30%, ${C.lavenderDim} 0%, transparent 70%)`, backgroundSize: "200% 200%, 200% 200%", animation: "meshShift 22s ease-in-out infinite", pointerEvents: "none" }} />

      {/* Nav */}
      <nav style={{ position: "sticky", top: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "1rem 2rem", background: "rgba(6,14,18,0.7)", backdropFilter: "blur(20px)", WebkitBackdropFilter: "blur(20px)", borderBottom: `1px solid ${C.glow}10` }}>
        <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
          <a href="/dashboard" style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.35rem", color: "#fff", textDecoration: "none", textShadow: `0 0 20px ${C.glow}30` }}>OneAgent</a>
          <span style={{ color: C.faint }}>/</span>
          <a href="/dashboard" style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.9rem", color: C.muted, textDecoration: "none" }}>Dashboard</a>
          <span style={{ color: C.faint }}>/</span>
          <span style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.9rem", color: C.text }}>{agent.name}</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
          <a href="/keys" style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", color: C.muted, textDecoration: "none" }}>Keys</a>
          <button onClick={() => logout()} style={{ padding: "0.4rem 0.9rem", borderRadius: 8, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.8rem", cursor: "pointer" }}>Logout</button>
        </div>
      </nav>

      <main style={{ position: "relative", zIndex: 2, maxWidth: 900, margin: "0 auto", padding: "2rem 1.5rem" }}>
        {/* Agent header */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem", flexWrap: "wrap", gap: "1rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
            <a href="/dashboard" title="Back to Dashboard" style={{ display: "inline-flex", alignItems: "center", justifyContent: "center", width: 36, height: 36, borderRadius: 10, border: `1px solid ${C.faint}`, background: "rgba(255,255,255,0.04)", color: C.muted, textDecoration: "none", flexShrink: 0, transition: "all 0.2s" }} onMouseEnter={e => { e.currentTarget.style.background = "rgba(255,255,255,0.08)"; e.currentTarget.style.color = C.text; }} onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = C.muted; }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/></svg>
            </a>
            <h1 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.8rem", fontWeight: 400, color: "#fff" }}>{agent.name}</h1>
            <span style={{ fontSize: "0.72rem", padding: "0.25rem 0.6rem", borderRadius: 6, background: sc.bg, border: `1px solid ${sc.border}`, color: sc.text, fontWeight: 500, textTransform: "uppercase", letterSpacing: "0.05em" }}>{agent.status}</span>
          </div>
          <div style={{ display: "flex", gap: "0.5rem" }}>
            {(agent.status !== "running") && (
              <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={handleStart} style={{ padding: "0.5rem 1.2rem", borderRadius: 10, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: "pointer" }}>Start</motion.button>
            )}
            {agent.status === "running" && (
              <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={handleStop} style={{ padding: "0.5rem 1.2rem", borderRadius: 10, border: "1px solid rgba(255,107,107,0.3)", background: "rgba(255,107,107,0.08)", color: C.danger, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 500, cursor: "pointer" }}>Stop</motion.button>
            )}
          </div>
        </div>

        {lifecycleError && (
          <div style={{ padding: "0.8rem 1rem", borderRadius: 10, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.85rem", color: C.danger, marginBottom: "1rem" }}>
            {lifecycleError}
          </div>
        )}

        {/* Tabs */}
        <div style={{ display: "flex", gap: 4, padding: 4, borderRadius: 12, background: "rgba(255,255,255,0.04)", marginBottom: "1.5rem" }}>
          {tabNames.map((t) => (
            <button key={t} onClick={() => switchTab(t)} style={{ flex: 1, padding: "0.6rem 0", borderRadius: 10, border: "none", cursor: "pointer", fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: tab === t ? 500 : 400, color: tab === t ? C.bg : C.muted, background: tab === t ? `linear-gradient(135deg, ${C.glow}, ${C.forest})` : "transparent", transition: "all 0.25s", letterSpacing: "0.02em", textTransform: "capitalize" }}>
              {t}
            </button>
          ))}
        </div>

        {/* ==================== CHAT TAB ==================== */}
        {tab === "chat" && (
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            {agent.status !== "running" && (
              <div style={{ padding: "0.8rem 1rem", borderRadius: 10, background: "rgba(255,200,50,0.06)", border: "1px solid rgba(255,200,50,0.2)", fontSize: "0.85rem", color: "#FFD166" }}>
                Start the agent to begin chatting.
              </div>
            )}

            {/* Messages */}
            <div style={{ ...glassCard(), padding: "1.5rem", minHeight: 350, maxHeight: 500, overflowY: "auto", display: "flex", flexDirection: "column", gap: "1rem" }}>
              {messages.length === 0 && !sending && (
                <div style={{ textAlign: "center", padding: "3rem 1rem", color: C.faint, fontSize: "0.9rem" }}>No messages yet. Send a message to start.</div>
              )}
              {messages.map((msg) => (
                <div key={msg.id} style={{ display: "flex", justifyContent: msg.role === "user" ? "flex-end" : "flex-start" }}>
                  <div style={{ maxWidth: "75%", padding: "0.8rem 1rem", borderRadius: 14, background: msg.role === "user" ? `rgba(0,212,170,0.08)` : "rgba(155,114,207,0.06)", border: `1px solid ${msg.role === "user" ? `${C.glow}25` : `${C.lavender}20`}`, fontSize: "0.88rem", lineHeight: 1.6, color: C.text, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
                    {msg.content}
                  </div>
                </div>
              ))}
              {sending && (
                <div style={{ display: "flex", justifyContent: "flex-start" }}>
                  <div style={{ padding: "0.8rem 1.2rem", borderRadius: 14, background: "rgba(155,114,207,0.06)", border: `1px solid ${C.lavender}20`, display: "flex", gap: 6 }}>
                    {[0, 1, 2].map((i) => (
                      <div key={i} style={{ width: 7, height: 7, borderRadius: "50%", background: C.lavender, animation: `typingDot 1.2s ease-in-out ${i * 0.2}s infinite` }} />
                    ))}
                  </div>
                </div>
              )}
              <div ref={chatEndRef} />
            </div>

            {/* Input */}
            <form onSubmit={handleSend} style={{ display: "flex", gap: "0.5rem" }}>
              <textarea value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSend(); } }} placeholder={agent.status === "running" ? "Type a message... (Enter to send)" : "Start agent to chat"} disabled={agent.status !== "running"} rows={2} style={{ ...inputStyle(), flex: 1, resize: "none" as const, opacity: agent.status !== "running" ? 0.5 : 1 }} />
              <motion.button type="submit" disabled={sending || agent.status !== "running"} whileHover={sending ? {} : { scale: 1.03 }} whileTap={sending ? {} : { scale: 0.97 }} style={{ padding: "0 1.5rem", borderRadius: 12, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: sending || agent.status !== "running" ? "not-allowed" : "pointer", opacity: sending || agent.status !== "running" ? 0.5 : 1, alignSelf: "stretch" }}>
                Send
              </motion.button>
            </form>

            {messages.length > 0 && (
              <button onClick={handleClearHistory} style={{ alignSelf: "flex-end", padding: "0.4rem 0.8rem", borderRadius: 8, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.78rem", cursor: "pointer" }}>
                Clear History
              </button>
            )}
          </div>
        )}

        {/* ==================== SETTINGS TAB ==================== */}
        {tab === "settings" && (
          <form onSubmit={handleSaveSettings} style={{ ...glassCard(), padding: "2rem", display: "flex", flexDirection: "column", gap: "1.25rem" }}>
            <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.2rem", color: "#fff", fontWeight: 400, marginBottom: "0.25rem" }}>Basic</h2>
            <div>
              <label style={labelStyle()}>Name</label>
              <input value={settingsForm.name || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, name: e.target.value }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>
            <div>
              <label style={labelStyle()}>Description</label>
              <input value={settingsForm.description || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, description: e.target.value }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>

            <div style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "1.25rem", marginTop: "0.5rem" }}>
              <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.2rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>Model</h2>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={labelStyle()}>Provider</label>
                  <select value={settingsForm.model_provider || "anthropic"} onChange={(e) => { const prov = e.target.value; setSettingsForm((p) => ({ ...p, model_provider: prov, model_id: MODEL_OPTIONS[prov]?.[0]?.id || p.model_id })); }} style={selectStyle}>
                    <option value="anthropic">Anthropic</option>
                    <option value="openai">OpenAI</option>
                  </select>
                </div>
                <div>
                  <label style={labelStyle()}>Model</label>
                  <select value={settingsForm.model_id || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, model_id: e.target.value }))} style={selectStyle}>
                    {(MODEL_OPTIONS[settingsForm.model_provider || "anthropic"] || []).map((m) => <option key={m.id} value={m.id}>{m.label}</option>)}
                    {settingsForm.model_id && !(MODEL_OPTIONS[settingsForm.model_provider || "anthropic"] || []).some((m) => m.id === settingsForm.model_id) && (
                      <option value={settingsForm.model_id}>{settingsForm.model_id}</option>
                    )}
                  </select>
                </div>
              </div>
              <div style={{ marginTop: "1rem" }}>
                <label style={labelStyle()}>LLM Config</label>
                <div style={{ display: "flex", gap: "0.5rem", alignItems: "stretch" }}>
                  <select value={settingsForm.llm_config_id || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, llm_config_id: e.target.value || null }))} style={{ ...selectStyle, flex: 1 }}>
                    <option value="">None</option>
                    {configs.map((c) => <option key={c.id} value={c.id}>{c.label} ({c.provider}){c.is_default ? " \u2605" : ""}</option>)}
                  </select>
                  <a href="/keys" style={{ padding: "0 1rem", borderRadius: 12, border: `1px solid ${C.glow}30`, background: "rgba(0,212,170,0.05)", color: C.glow, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", fontWeight: 500, textDecoration: "none", display: "flex", alignItems: "center", whiteSpace: "nowrap" }}>+ Add Key</a>
                </div>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem", marginTop: "1rem" }}>
                <div>
                  <label style={labelStyle()}>Max Steps Per Run</label>
                  <input type="number" min={1} max={500} value={settingsForm.max_steps_per_run || 50} onChange={(e) => setSettingsForm((p) => ({ ...p, max_steps_per_run: parseInt(e.target.value) || 50 }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                </div>
                <div>
                  <label style={labelStyle()}>Max History Messages</label>
                  <input type="number" min={0} max={200} value={settingsForm.max_history_messages ?? 20} onChange={(e) => setSettingsForm((p) => ({ ...p, max_history_messages: parseInt(e.target.value) || 0 }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                </div>
              </div>
            </div>

            <div style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "1.25rem", marginTop: "0.5rem" }}>
              <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.2rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>System Prompt</h2>
              <textarea value={settingsForm.system_prompt || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, system_prompt: e.target.value }))} rows={6} style={{ ...inputStyle(), resize: "vertical" as const }} />
            </div>

            <div style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "1.25rem", marginTop: "0.5rem" }}>
              <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.2rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>Trigger</h2>
              <div>
                <label style={labelStyle()}>Trigger Type</label>
                <select value={settingsForm.trigger_type || "on_demand"} onChange={(e) => setSettingsForm((p) => ({ ...p, trigger_type: e.target.value }))} style={selectStyle}>
                  <option value="on_demand">On Demand</option>
                  <option value="scheduled">Scheduled</option>
                  <option value="webhook">Webhook</option>
                  <option value="continuous">Continuous</option>
                </select>
              </div>

              {settingsForm.trigger_type === "scheduled" && (
                <div style={{ marginTop: "1rem", display: "flex", flexDirection: "column", gap: "1rem" }}>
                  <div>
                    <label style={labelStyle()}>Cron Expression</label>
                    <input value={(settingsForm.trigger_config as Record<string, string>)?.cron || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, trigger_config: { ...(p.trigger_config as Record<string, string>), cron: e.target.value } }))} placeholder="*/5 * * * *" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                    <div style={{ display: "flex", gap: "0.5rem", marginTop: "0.5rem", flexWrap: "wrap" }}>
                      {[
                        ["*/5 * * * *", "Every 5 min"],
                        ["0 * * * *", "Hourly"],
                        ["0 9 * * *", "Daily 9am"],
                        ["0 9 * * 1", "Weekly Mon 9am"],
                      ].map(([cron, label]) => (
                        <button key={cron} type="button" onClick={() => setSettingsForm((p) => ({ ...p, trigger_config: { ...(p.trigger_config as Record<string, string>), cron } }))} style={{ padding: "0.25rem 0.6rem", borderRadius: 6, border: `1px solid ${C.faint}`, background: (settingsForm.trigger_config as Record<string, string>)?.cron === cron ? `${C.glow}15` : "transparent", color: (settingsForm.trigger_config as Record<string, string>)?.cron === cron ? C.glow : C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.75rem", cursor: "pointer" }}>
                          {label}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <label style={labelStyle()}>Scheduled Message</label>
                    <textarea value={(settingsForm.trigger_config as Record<string, string>)?.message || ""} onChange={(e) => setSettingsForm((p) => ({ ...p, trigger_config: { ...(p.trigger_config as Record<string, string>), message: e.target.value } }))} placeholder="Check for updates" rows={2} style={{ ...inputStyle(), resize: "vertical" as const }} />
                  </div>
                  <div>
                    <label style={labelStyle()}>Max Runs Per Day</label>
                    <input type="number" min={1} max={10000} value={settingsForm.max_runs_per_day || 100} onChange={(e) => setSettingsForm((p) => ({ ...p, max_runs_per_day: parseInt(e.target.value) || 100 }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                  </div>
                </div>
              )}
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginTop: "0.5rem" }}>
              <motion.button type="submit" disabled={settingsLoading} whileHover={settingsLoading ? {} : { scale: 1.02 }} whileTap={settingsLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(settingsLoading), width: "auto", padding: "0.7rem 2rem" }}>
                {settingsLoading ? "Saving..." : "Save Settings"}
              </motion.button>
              {settingsMsg && <span style={{ fontSize: "0.85rem", color: settingsMsg.startsWith("Error") ? C.danger : C.glow }}>{settingsMsg}</span>}
            </div>
          </form>
        )}

        {/* ==================== PERMISSIONS TAB ==================== */}
        {tab === "permissions" && (
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            {BUCKET_NAMES.map((name) => {
              const bucket = buckets.find((b) => b.bucket === name);
              const active = bucket && !bucket.revoked_at;
              return (
                <div key={name} style={{ ...glassCard(), padding: "1.25rem", transition: "border-color 0.3s", borderColor: active ? `${C.glow}30` : undefined }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: active ? "1rem" : 0 }}>
                    <div>
                      <h3 style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.95rem", fontWeight: 500, color: "#fff", textTransform: "capitalize" }}>{name.replace(/_/g, " ")}</h3>
                      <p style={{ fontSize: "0.78rem", color: C.faint, marginTop: "0.2rem" }}>
                        {name === "web_access" && "Allow HTTP requests and web browsing"}
                        {name === "email" && "Allow sending emails"}
                        {name === "spending" && "Allow financial transactions"}
                        {name === "communication" && "Allow messaging (WhatsApp, Slack, etc.)"}
                        {name === "data_write" && "Allow writing/modifying external data"}
                      </p>
                    </div>
                    <button onClick={() => toggleBucket(name)} style={{ width: 44, height: 24, borderRadius: 12, border: "none", background: active ? C.glow : "rgba(255,255,255,0.1)", cursor: "pointer", position: "relative", transition: "background 0.3s" }}>
                      <div style={{ width: 18, height: 18, borderRadius: "50%", background: "#fff", position: "absolute", top: 3, left: active ? 23 : 3, transition: "left 0.3s" }} />
                    </button>
                  </div>
                  {active && (
                    <div>
                      <label style={labelStyle()}>Credential</label>
                      <select value={bucket?.credential_id || ""} onChange={(e) => setBucketCredential(name, e.target.value)} style={selectStyle}>
                        <option value="">None</option>
                        {credentials.map((c) => <option key={c.id} value={c.id}>{c.name} ({c.service})</option>)}
                      </select>
                    </div>
                  )}
                </div>
              );
            })}
            <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginTop: "0.5rem" }}>
              <motion.button onClick={handleSavePermissions} disabled={permLoading} whileHover={permLoading ? {} : { scale: 1.02 }} whileTap={permLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(permLoading), width: "auto", padding: "0.7rem 2rem" }}>
                {permLoading ? "Saving..." : "Save Permissions"}
              </motion.button>
              {permMsg && <span style={{ fontSize: "0.85rem", color: permMsg.startsWith("Error") ? C.danger : C.glow }}>{permMsg}</span>}
            </div>
          </div>
        )}

        {/* ==================== GUIDE TAB ==================== */}
        {tab === "guide" && (
          <div style={{ ...glassCard(), padding: "2rem", display: "flex", flexDirection: "column", gap: "2rem" }}>
            {/* API Access */}
            <section>
              <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.3rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>API Access</h2>
              <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Agent ID:</p>
              <CodeBlock code={agent.id} />
              <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Invoke the agent:</p>
              <CodeBlock code={`curl -X POST http://localhost:4000/api/agents/${agent.id}/invoke \\\n  -H 'Content-Type: application/json' \\\n  -H 'Authorization: Bearer YOUR_TOKEN' \\\n  -d '{"message": "Hello agent"}'`} />
              <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Get messages:</p>
              <CodeBlock code={`curl http://localhost:4000/api/agents/${agent.id}/messages \\\n  -H 'Authorization: Bearer YOUR_TOKEN'`} />
              <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Get runs:</p>
              <CodeBlock code={`curl http://localhost:4000/api/agents/${agent.id}/runs \\\n  -H 'Authorization: Bearer YOUR_TOKEN'`} />
            </section>

            {/* WhatsApp */}
            <section style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "2rem" }}>
              <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.3rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>WhatsApp Setup</h2>
              <ol style={{ fontSize: "0.88rem", color: C.text, lineHeight: 1.8, paddingLeft: "1.25rem" }}>
                <li style={{ marginBottom: "0.5rem" }}>Go to <a href="/keys" style={{ color: C.glow, textDecoration: "none" }}>Keys</a> and create a credential with service &quot;whatsapp&quot; containing your <code style={{ color: C.phosphor }}>access_token</code> and <code style={{ color: C.phosphor }}>app_secret</code></li>
                <li style={{ marginBottom: "0.5rem" }}>Create a WhatsApp channel linking this agent to your phone_number_id and credential</li>
                <li style={{ marginBottom: "0.5rem" }}>In your Meta developer dashboard, set the webhook callback URL to:<br /><code style={{ color: C.phosphor }}>https://YOUR_DOMAIN/api/webhooks/whatsapp</code></li>
                <li style={{ marginBottom: "0.5rem" }}>Use the <code style={{ color: C.phosphor }}>verify_token</code> from the channel create response to complete webhook verification</li>
                <li>Start the agent and send a WhatsApp message to test</li>
              </ol>
            </section>

            {/* Scheduling */}
            <section style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "2rem" }}>
              <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.3rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>Scheduling</h2>
              {agent.trigger_type === "scheduled" ? (
                <div>
                  <p style={{ fontSize: "0.88rem", color: C.text, marginBottom: "0.5rem" }}>Current schedule: <code style={{ color: C.phosphor }}>{(agent.trigger_config as Record<string, string>)?.cron || "not set"}</code></p>
                  <p style={{ fontSize: "0.88rem", color: C.text, marginBottom: "1rem" }}>Message: <code style={{ color: C.phosphor }}>{(agent.trigger_config as Record<string, string>)?.message || "none"}</code></p>
                </div>
              ) : (
                <p style={{ fontSize: "0.88rem", color: C.muted, marginBottom: "1rem" }}>This agent is not scheduled. Change trigger type to &quot;scheduled&quot; in Settings.</p>
              )}
              <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Common cron patterns:</p>
              <div style={{ display: "grid", gridTemplateColumns: "auto 1fr", gap: "0.3rem 1.5rem", fontSize: "0.82rem" }}>
                <code style={{ color: C.phosphor }}>*/5 * * * *</code><span style={{ color: C.faint }}>Every 5 minutes</span>
                <code style={{ color: C.phosphor }}>0 * * * *</code><span style={{ color: C.faint }}>Every hour</span>
                <code style={{ color: C.phosphor }}>0 9 * * *</code><span style={{ color: C.faint }}>Daily at 9:00 AM</span>
                <code style={{ color: C.phosphor }}>0 9 * * 1</code><span style={{ color: C.faint }}>Every Monday at 9:00 AM</span>
                <code style={{ color: C.phosphor }}>0 0 1 * *</code><span style={{ color: C.faint }}>First of every month</span>
              </div>
            </section>
          </div>
        )}
      </main>
    </div>
  );
}

export default function AgentDetailPage() {
  return (
    <Protected>
      <AgentDetailContent />
    </Protected>
  );
}
