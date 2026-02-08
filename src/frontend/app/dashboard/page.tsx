"use client";

import { motion, AnimatePresence } from "framer-motion";
import { Instrument_Serif, DM_Sans, Lora } from "next/font/google";
import { useEffect, useState, FormEvent } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api";
import { Protected } from "../lib/protected";
import { C, inputStyle, inputFocusCSS, buttonStyle, labelStyle, glassCard } from "../lib/theme";

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
  model_provider: string;
  model_id: string;
  llm_config_id: string | null;
  has_llm_config: boolean;
  inserted_at: string;
}

interface LlmConfig {
  id: string;
  provider: string;
  label: string;
  is_default: boolean;
}

/* ------------------------------------------------------------------ */
/*  Keyframes                                                          */
/* ------------------------------------------------------------------ */
function useKeyframes() {
  useEffect(() => {
    const id = "dashboard-kf";
    if (document.getElementById(id)) return;
    const s = document.createElement("style");
    s.id = id;
    s.textContent = `
      @keyframes drift1 { 0%,100%{transform:translate(0,0) scale(1)} 25%{transform:translate(50px,-35px) scale(1.08)} 50%{transform:translate(-25px,45px) scale(0.95)} 75%{transform:translate(35px,20px) scale(1.04)} }
      @keyframes drift2 { 0%,100%{transform:translate(0,0) scale(1)} 25%{transform:translate(-40px,40px) scale(1.06)} 50%{transform:translate(30px,-25px) scale(0.93)} 75%{transform:translate(-15px,-50px) scale(1.02)} }
      @keyframes meshShift { 0%{background-position:0% 50%,100% 50%,50% 0%} 25%{background-position:100% 0%,0% 100%,50% 50%} 50%{background-position:50% 100%,50% 0%,0% 50%} 75%{background-position:0% 0%,100% 100%,100% 50%} 100%{background-position:0% 50%,100% 50%,50% 0%} }
    `;
    document.head.appendChild(s);
    return () => { const el = document.getElementById(id); if (el) el.remove(); };
  }, []);
}

function Orb({ size, color, top, left, animation, duration, opacity = 0.2 }: { size: number; color: string; top: string; left: string; animation: string; duration: string; opacity?: number }) {
  return <div style={{ position: "absolute", width: size, height: size, borderRadius: "50%", background: `radial-gradient(circle at 30% 30%, ${color}, transparent 70%)`, filter: `blur(${size * 0.4}px)`, opacity, top, left, animation: `${animation} ${duration} ease-in-out infinite`, pointerEvents: "none", willChange: "transform" }} />;
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
/*  Top bar component                                                  */
/* ------------------------------------------------------------------ */
function TopBar() {
  const { user, logout } = useAuth();
  return (
    <nav style={{ position: "sticky", top: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "1rem 2rem", background: "rgba(6,14,18,0.7)", backdropFilter: "blur(20px)", WebkitBackdropFilter: "blur(20px)", borderBottom: `1px solid ${C.glow}10` }}>
      <a href="/dashboard" style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.35rem", color: "#fff", textDecoration: "none", textShadow: `0 0 20px ${C.glow}30` }}>OneAgent</a>
      <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
        <a href="/keys" style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", color: C.muted, textDecoration: "none", transition: "color 0.2s" }} onMouseEnter={(e) => (e.currentTarget.style.color = C.text)} onMouseLeave={(e) => (e.currentTarget.style.color = "rgba(216,237,230,0.40)")}>Keys</a>
        <span style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", color: C.faint }}>{user?.email}</span>
        <button onClick={() => logout()} style={{ padding: "0.4rem 0.9rem", borderRadius: 8, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.8rem", cursor: "pointer", transition: "border-color 0.2s, color 0.2s" }} onMouseEnter={(e) => { e.currentTarget.style.borderColor = `${C.glow}55`; e.currentTarget.style.color = C.text; }} onMouseLeave={(e) => { e.currentTarget.style.borderColor = C.faint; e.currentTarget.style.color = "rgba(216,237,230,0.40)"; }}>
          Logout
        </button>
      </div>
    </nav>
  );
}

/* ================================================================== */
/*  Dashboard page                                                     */
/* ================================================================== */
function DashboardContent() {
  useKeyframes();
  const [agents, setAgents] = useState<Agent[]>([]);
  const [configs, setConfigs] = useState<LlmConfig[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [deleting, setDeleting] = useState<string | null>(null);

  // Create form state
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [modelProvider, setModelProvider] = useState("anthropic");
  const [modelId, setModelId] = useState("claude-sonnet-4-5-20250929");
  const [systemPrompt, setSystemPrompt] = useState("");
  const [llmConfigId, setLlmConfigId] = useState("");
  const [createLoading, setCreateLoading] = useState(false);
  const [createError, setCreateError] = useState("");

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    const [agentsRes, configsRes] = await Promise.all([
      api.get<Agent[]>("/api/agents"),
      api.get<LlmConfig[]>("/api/llm-configs"),
    ]);
    if (agentsRes.ok) setAgents(agentsRes.data);
    if (configsRes.ok) setConfigs(configsRes.data);
    setLoading(false);
  }

  async function handleCreate(e: FormEvent) {
    e.preventDefault();
    setCreateLoading(true);
    setCreateError("");
    const body: Record<string, unknown> = {
      agent: {
        name,
        description: description || null,
        model_provider: modelProvider,
        model_id: modelId,
        system_prompt: systemPrompt || "You are a helpful AI assistant.",
        llm_config_id: llmConfigId || null,
      },
    };
    const res = await api.post<Agent>("/api/agents", body);
    setCreateLoading(false);
    if (res.ok) {
      setAgents((prev) => [res.data, ...prev]);
      setShowCreate(false);
      resetForm();
    } else {
      setCreateError(res.error);
    }
  }

  function resetForm() {
    setName(""); setDescription(""); setModelProvider("anthropic"); setModelId("claude-sonnet-4-5-20250929"); setSystemPrompt(""); setLlmConfigId(""); setCreateError("");
  }

  async function handleDelete(id: string) {
    setDeleting(id);
    const res = await api.del(`/api/agents/${id}`);
    if (res.ok) setAgents((prev) => prev.filter((a) => a.id !== id));
    setDeleting(null);
  }

  const selectStyle: React.CSSProperties = { ...inputStyle(), appearance: "none" as const, cursor: "pointer" };

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

  return (
    <div className={`${instrumentSerif.variable} ${dmSans.variable} ${lora.variable}`} style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "var(--font-dm), sans-serif", position: "relative" }}>
      <Orb size={400} color={C.glow} top="-5%" left="-8%" animation="drift1" duration="20s" opacity={0.08} />
      <Orb size={300} color={C.lavender} top="30%" left="80%" animation="drift2" duration="24s" opacity={0.06} />
      <div style={{ position: "fixed", inset: 0, zIndex: 0, opacity: 0.2, background: `radial-gradient(ellipse 55% 45% at 20% 50%, ${C.glowDim} 0%, transparent 70%), radial-gradient(ellipse 45% 55% at 80% 30%, ${C.lavenderDim} 0%, transparent 70%)`, backgroundSize: "200% 200%, 200% 200%", animation: "meshShift 22s ease-in-out infinite", pointerEvents: "none" }} />

      <TopBar />

      <main style={{ position: "relative", zIndex: 2, maxWidth: 1100, margin: "0 auto", padding: "2rem 1.5rem" }}>
        {/* Header */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "2rem" }}>
          <div>
            <h1 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "2rem", fontWeight: 400, color: "#fff", marginBottom: "0.3rem", textShadow: `0 0 30px ${C.glow}15` }}>Your Agents</h1>
            <p style={{ fontFamily: "var(--font-lora), serif", fontStyle: "italic", fontSize: "0.9rem", color: C.muted }}>{agents.length} agent{agents.length !== 1 ? "s" : ""}</p>
          </div>
          <motion.button whileHover={{ scale: 1.03, boxShadow: `0 0 24px ${C.glow}33` }} whileTap={{ scale: 0.97 }} onClick={() => setShowCreate(true)} style={{ padding: "0.7rem 1.5rem", borderRadius: 12, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.9rem", fontWeight: 600, cursor: "pointer", boxShadow: `0 0 20px ${C.glow}15` }}>
            + Create Agent
          </motion.button>
        </div>

        {/* Loading */}
        {loading && (
          <div style={{ textAlign: "center", padding: "4rem 0", color: C.muted, fontSize: "0.9rem" }}>Loading agents...</div>
        )}

        {/* Empty state */}
        {!loading && agents.length === 0 && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} style={{ textAlign: "center", padding: "4rem 2rem", ...glassCard() }}>
            <p style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.4rem", color: "#fff", marginBottom: "0.6rem" }}>No agents yet</p>
            <p style={{ fontSize: "0.9rem", color: C.muted, marginBottom: "1.5rem" }}>Create your first agent to get started.</p>
            <button onClick={() => setShowCreate(true)} style={{ padding: "0.7rem 1.5rem", borderRadius: 12, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.9rem", fontWeight: 600, cursor: "pointer" }}>+ Create Agent</button>
          </motion.div>
        )}

        {/* Agent grid */}
        {!loading && agents.length > 0 && (
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: "1rem" }}>
            {agents.map((agent, i) => {
              return (
                <motion.div key={agent.id} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }} style={{ ...glassCard(), padding: "1.5rem", display: "flex", flexDirection: "column", gap: "0.75rem", transition: "border-color 0.3s, box-shadow 0.3s" }} onMouseEnter={(e) => { e.currentTarget.style.borderColor = `${C.glow}30`; e.currentTarget.style.boxShadow = `0 0 30px ${C.glow}10`; }} onMouseLeave={(e) => { e.currentTarget.style.borderColor = `${C.glow}15`; e.currentTarget.style.boxShadow = `0 0 60px ${C.glow}06, inset 0 1px 0 ${C.glow}08`; }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.15rem", color: "#fff", fontWeight: 400 }}>{agent.name}</h3>
                    <span style={{ fontSize: "0.72rem", padding: "0.25rem 0.6rem", borderRadius: 6, background: agent.has_llm_config ? "rgba(0,212,170,0.12)" : "rgba(255,200,50,0.08)", border: `1px solid ${agent.has_llm_config ? `${C.glow}44` : "rgba(255,200,50,0.3)"}`, color: agent.has_llm_config ? C.glow : "#FFD166", fontWeight: 500, letterSpacing: "0.05em" }}>{agent.has_llm_config ? "Ready" : "Needs Config"}</span>
                  </div>

                  {agent.description && (
                    <p style={{ fontSize: "0.85rem", color: C.muted, lineHeight: 1.5, overflow: "hidden", textOverflow: "ellipsis", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{agent.description}</p>
                  )}

                  <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", fontSize: "0.78rem", color: C.faint }}>
                    <span style={{ padding: "0.2rem 0.5rem", borderRadius: 4, background: "rgba(255,255,255,0.04)" }}>{agent.model_provider}</span>
                  </div>

                  <div style={{ display: "flex", gap: "0.5rem", marginTop: "auto", paddingTop: "0.5rem" }}>
                    <a href={`/agents/${agent.id}`} style={{ flex: 1, padding: "0.55rem", borderRadius: 8, border: `1px solid ${C.glow}30`, background: "rgba(0,212,170,0.05)", color: C.glow, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", fontWeight: 500, textAlign: "center", textDecoration: "none", cursor: "pointer", transition: "background 0.2s" }} onMouseEnter={(e) => (e.currentTarget.style.background = "rgba(0,212,170,0.12)")} onMouseLeave={(e) => (e.currentTarget.style.background = "rgba(0,212,170,0.05)")}>Open</a>
                    <a href={`/agents/${agent.id}?tab=guide`} style={{ padding: "0.55rem 0.75rem", borderRadius: 8, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", textAlign: "center", textDecoration: "none", cursor: "pointer", transition: "border-color 0.2s" }} onMouseEnter={(e) => (e.currentTarget.style.borderColor = `${C.glow}44`)} onMouseLeave={(e) => (e.currentTarget.style.borderColor = C.faint)}>?</a>
                    <button onClick={() => handleDelete(agent.id)} disabled={deleting === agent.id} style={{ padding: "0.55rem 0.75rem", borderRadius: 8, border: "1px solid rgba(255,107,107,0.2)", background: "rgba(255,107,107,0.05)", color: C.danger, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", cursor: "pointer", transition: "background 0.2s", opacity: deleting === agent.id ? 0.5 : 1 }} onMouseEnter={(e) => (e.currentTarget.style.background = "rgba(255,107,107,0.12)")} onMouseLeave={(e) => (e.currentTarget.style.background = "rgba(255,107,107,0.05)")}>
                      {deleting === agent.id ? "..." : "\u2715"}
                    </button>
                  </div>
                </motion.div>
              );
            })}
          </div>
        )}
      </main>

      {/* ========== Create Agent Modal ========== */}
      <AnimatePresence>
        {showCreate && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} style={{ position: "fixed", inset: 0, zIndex: 100, display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(0,0,0,0.6)", backdropFilter: "blur(8px)", padding: "1.5rem" }} onClick={(e) => { if (e.target === e.currentTarget) { setShowCreate(false); resetForm(); } }}>
            <motion.div initial={{ opacity: 0, y: 30, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 20, scale: 0.95 }} transition={{ duration: 0.3 }} style={{ width: "100%", maxWidth: 520, maxHeight: "85vh", overflowY: "auto", padding: "2rem", ...glassCard(), background: "rgba(6,14,18,0.95)", border: `1px solid ${C.glow}20` }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem" }}>
                <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.5rem", color: "#fff", fontWeight: 400 }}>Create Agent</h2>
                <button onClick={() => { setShowCreate(false); resetForm(); }} style={{ background: "none", border: "none", color: C.muted, cursor: "pointer", fontSize: "1.2rem" }}>{"\u2715"}</button>
              </div>

              <AnimatePresence>
                {createError && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} style={{ padding: "0.7rem 1rem", borderRadius: 10, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.85rem", color: C.danger, marginBottom: "1rem", overflow: "hidden" }}>
                    {createError}
                  </motion.div>
                )}
              </AnimatePresence>

              <form onSubmit={handleCreate} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
                <div>
                  <label style={labelStyle()}>Name *</label>
                  <input required value={name} onChange={(e) => setName(e.target.value)} placeholder="My Agent" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                </div>

                <div>
                  <label style={labelStyle()}>Description</label>
                  <input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="What does this agent do?" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                  <div>
                    <label style={labelStyle()}>Provider *</label>
                    <select value={modelProvider} onChange={(e) => { const prov = e.target.value; setModelProvider(prov); setModelId(MODEL_OPTIONS[prov]?.[0]?.id || ""); setLlmConfigId(""); }} style={selectStyle}>
                      <option value="anthropic">Anthropic</option>
                      <option value="openai">OpenAI</option>
                    </select>
                  </div>
                  <div>
                    <label style={labelStyle()}>Model *</label>
                    <select required value={modelId} onChange={(e) => setModelId(e.target.value)} style={selectStyle}>
                      {(MODEL_OPTIONS[modelProvider] || []).map((m) => <option key={m.id} value={m.id}>{m.label}</option>)}
                    </select>
                  </div>
                </div>

                <div>
                  <label style={labelStyle()}>LLM Config</label>
                  <select value={llmConfigId} onChange={(e) => setLlmConfigId(e.target.value)} style={selectStyle}>
                    <option value="">None (configure in Keys)</option>
                    {configs.filter((c) => c.provider === modelProvider).map((c) => (
                      <option key={c.id} value={c.id}>{c.label}{c.is_default ? " \u2605" : ""}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={labelStyle()}>System Prompt</label>
                  <textarea value={systemPrompt} onChange={(e) => setSystemPrompt(e.target.value)} placeholder="You are a helpful AI assistant." rows={4} style={{ ...inputStyle(), resize: "vertical" as const }} />
                </div>

                <motion.button type="submit" disabled={createLoading} whileHover={createLoading ? {} : { scale: 1.02, boxShadow: `0 0 30px ${C.glow}33` }} whileTap={createLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(createLoading), marginTop: "0.5rem" }}>
                  {createLoading ? "Creating..." : "Create Agent"}
                </motion.button>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function DashboardPage() {
  return (
    <Protected>
      <DashboardContent />
    </Protected>
  );
}
