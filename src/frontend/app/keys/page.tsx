"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState, FormEvent } from "react";
import { api } from "../lib/api";
import { Protected } from "../lib/protected";
import { C, inputStyle, buttonStyle, labelStyle, glassCard } from "../lib/theme";
import type { LlmConfig, Credential } from "../lib/types";
import { fontVars } from "../components/fonts";
import { useKeyframes } from "../components/useKeyframes";
import { Orb } from "../components/Orb";
import { MeshGradient } from "../components/MeshGradient";
import { TopBar } from "../components/TopBar";
import { applyFocus, removeFocus } from "../components/FocusHandlers";

/* ================================================================== */
/*  Keys page content                                                  */
/* ================================================================== */
function KeysContent() {
  useKeyframes("keys-kf");

  // LLM configs state
  const [configs, setConfigs] = useState<LlmConfig[]>([]);
  const [showAddConfig, setShowAddConfig] = useState(false);
  const [editingConfig, setEditingConfig] = useState<string | null>(null);
  const [configForm, setConfigForm] = useState({ provider: "anthropic", label: "", api_key: "", is_default: false });
  const [configLoading, setConfigLoading] = useState(false);
  const [configError, setConfigError] = useState("");

  // Credentials state
  const [creds, setCreds] = useState<Credential[]>([]);
  const [showAddCred, setShowAddCred] = useState(false);
  const [editingCred, setEditingCred] = useState<string | null>(null);
  const [credForm, setCredForm] = useState({ name: "", service: "", credential_type: "api_key", value: "" });
  const [credLoading, setCredLoading] = useState(false);
  const [credError, setCredError] = useState("");

  // Gmail OAuth state
  const [gmailConnecting, setGmailConnecting] = useState(false);
  const [gmailMsg, setGmailMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Google Calendar OAuth state
  const [calendarConnecting, setCalendarConnecting] = useState(false);
  const [calendarMsg, setCalendarMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const [cr, lr] = await Promise.all([
        api.get<Credential[]>("/api/credentials"),
        api.get<LlmConfig[]>("/api/llm-configs"),
      ]);
      if (cr.ok) setCreds(cr.data);
      if (lr.ok) setConfigs(lr.data);
      setLoading(false);
    }
    load();
  }, []);

  // Check for Gmail OAuth redirect params
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("gmail_connected") === "true") {
      setGmailMsg({ type: "success", text: "Gmail connected successfully!" });
      // Refresh credentials to show the new Gmail credential
      api.get<Credential[]>("/api/credentials").then((r) => { if (r.ok) setCreds(r.data); });
      window.history.replaceState({}, "", "/keys");
    } else if (params.get("gmail_error")) {
      setGmailMsg({ type: "error", text: `Gmail connection failed: ${params.get("gmail_error")}` });
      window.history.replaceState({}, "", "/keys");
    }

    if (params.get("calendar_connected") === "true") {
      setCalendarMsg({ type: "success", text: "Google Calendar connected successfully!" });
      api.get<Credential[]>("/api/credentials").then((r) => { if (r.ok) setCreds(r.data); });
      window.history.replaceState({}, "", "/keys");
    } else if (params.get("calendar_error")) {
      setCalendarMsg({ type: "error", text: `Calendar connection failed: ${params.get("calendar_error")}` });
      window.history.replaceState({}, "", "/keys");
    }
  }, []);

  /* ---- LLM Config CRUD ---- */
  async function handleSaveConfig(e: FormEvent) {
    e.preventDefault();
    setConfigLoading(true);
    setConfigError("");
    if (editingConfig) {
      const body: Record<string, unknown> = { llm_config: { provider: configForm.provider, label: configForm.label, is_default: configForm.is_default } };
      if (configForm.api_key) (body.llm_config as Record<string, unknown>).api_key = configForm.api_key;
      const res = await api.put<LlmConfig>(`/api/llm-configs/${editingConfig}`, body);
      setConfigLoading(false);
      if (res.ok) {
        setConfigs((prev) => prev.map((c) => c.id === editingConfig ? res.data : c));
        resetConfigForm();
      } else setConfigError(res.error);
    } else {
      const res = await api.post<LlmConfig>("/api/llm-configs", { llm_config: configForm });
      setConfigLoading(false);
      if (res.ok) {
        setConfigs((prev) => [res.data, ...prev]);
        resetConfigForm();
      } else setConfigError(res.error);
    }
  }

  async function handleDeleteConfig(id: string) {
    const res = await api.del(`/api/llm-configs/${id}`);
    if (res.ok) setConfigs((prev) => prev.filter((c) => c.id !== id));
  }

  function startEditConfig(c: LlmConfig) {
    setEditingConfig(c.id);
    setConfigForm({ provider: c.provider, label: c.label, api_key: "", is_default: c.is_default });
    setShowAddConfig(true);
  }

  function resetConfigForm() {
    setShowAddConfig(false);
    setEditingConfig(null);
    setConfigForm({ provider: "anthropic", label: "", api_key: "", is_default: false });
    setConfigError("");
  }

  /* ---- Credential CRUD ---- */
  async function handleSaveCred(e: FormEvent) {
    e.preventDefault();
    setCredLoading(true);
    setCredError("");
    if (editingCred) {
      const body: Record<string, unknown> = { credential: { name: credForm.name, service: credForm.service, credential_type: credForm.credential_type } };
      if (credForm.value) (body.credential as Record<string, unknown>).value = credForm.value;
      const res = await api.put<Credential>(`/api/credentials/${editingCred}`, body);
      setCredLoading(false);
      if (res.ok) {
        setCreds((prev) => prev.map((c) => c.id === editingCred ? res.data : c));
        resetCredForm();
      } else setCredError(res.error);
    } else {
      const res = await api.post<Credential>("/api/credentials", { credential: credForm });
      setCredLoading(false);
      if (res.ok) {
        setCreds((prev) => [res.data, ...prev]);
        resetCredForm();
      } else setCredError(res.error);
    }
  }

  async function handleDeleteCred(id: string) {
    const res = await api.del(`/api/credentials/${id}`);
    if (res.ok) setCreds((prev) => prev.filter((c) => c.id !== id));
  }

  function startEditCred(c: Credential) {
    setEditingCred(c.id);
    setCredForm({ name: c.name, service: c.service, credential_type: c.credential_type, value: "" });
    setShowAddCred(true);
  }

  function resetCredForm() {
    setShowAddCred(false);
    setEditingCred(null);
    setCredForm({ name: "", service: "", credential_type: "api_key", value: "" });
    setCredError("");
  }

  /* ---- Gmail OAuth ---- */
  async function handleConnectGmail() {
    setGmailConnecting(true);
    setGmailMsg(null);
    const res = await api.get<{ url: string }>("/api/auth/gmail");
    if (res.ok && res.data.url) {
      window.location.href = res.data.url;
    } else {
      setGmailConnecting(false);
      setGmailMsg({ type: "error", text: res.ok ? "No OAuth URL returned" : (res as { error: string }).error || "Failed to start Gmail connection" });
    }
  }

  const gmailCred = creds.find((c) => c.service === "gmail");

  /* ---- Google Calendar OAuth ---- */
  async function handleConnectCalendar() {
    setCalendarConnecting(true);
    setCalendarMsg(null);
    const res = await api.get<{ url: string }>("/api/auth/calendar");
    if (res.ok && res.data.url) {
      window.location.href = res.data.url;
    } else {
      setCalendarConnecting(false);
      setCalendarMsg({ type: "error", text: res.ok ? "No OAuth URL returned" : (res as { error: string }).error || "Failed to start Calendar connection" });
    }
  }

  const calendarCred = creds.find((c) => c.service === "google_calendar");

  const selectStyle: React.CSSProperties = { ...inputStyle(), appearance: "none" as const, cursor: "pointer" };

  return (
    <div className={fontVars} style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "var(--font-dm), sans-serif", position: "relative" }}>
      <Orb size={400} color={C.glow} top="-5%" left="-8%" animation="drift1" duration="20s" opacity={0.06} />
      <Orb size={300} color={C.lavender} top="50%" left="85%" animation="drift2" duration="24s" opacity={0.05} />
      <MeshGradient opacity={0.15} threeGradients={false} />

      <TopBar breadcrumbs={[{ label: "Keys" }]} />

      <main style={{ position: "relative", zIndex: 2, maxWidth: 900, margin: "0 auto", padding: "2rem 1.5rem" }}>
        {loading && <div style={{ textAlign: "center", padding: "4rem 0", color: C.muted }}>Loading...</div>}

        {!loading && (
          <>
            {/* ==================== LLM API Keys ==================== */}
            <section style={{ marginBottom: "3rem" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem" }}>
                <div>
                  <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.6rem", color: "#fff", fontWeight: 400, marginBottom: "0.2rem" }}>LLM API Keys</h2>
                  <p style={{ fontFamily: "var(--font-lora), serif", fontStyle: "italic", fontSize: "0.85rem", color: C.muted }}>API keys for Anthropic, OpenAI, Zhipu, etc.</p>
                </div>
                <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={() => { resetConfigForm(); setShowAddConfig(true); }} style={{ padding: "0.6rem 1.2rem", borderRadius: 10, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: "pointer" }}>
                  + Add Key
                </motion.button>
              </div>

              {/* Add/Edit Config Form */}
              <AnimatePresence>
                {showAddConfig && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} style={{ overflow: "hidden", marginBottom: "1rem" }}>
                    <form onSubmit={handleSaveConfig} style={{ ...glassCard(), padding: "1.5rem", display: "flex", flexDirection: "column", gap: "1rem", background: "rgba(6,14,18,0.9)", border: `1px solid ${C.glow}20` }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                        <h3 style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.95rem", fontWeight: 500, color: "#fff" }}>{editingConfig ? "Edit" : "Add"} LLM Config</h3>
                        <button type="button" onClick={resetConfigForm} style={{ background: "none", border: "none", color: C.muted, cursor: "pointer", fontSize: "1rem" }}>{"\u2715"}</button>
                      </div>

                      {configError && <div style={{ padding: "0.6rem 0.8rem", borderRadius: 8, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.82rem", color: C.danger }}>{configError}</div>}

                      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                        <div>
                          <label style={labelStyle()}>Provider</label>
                          <select value={configForm.provider} onChange={(e) => setConfigForm((p) => ({ ...p, provider: e.target.value }))} style={selectStyle}>
                            <option value="anthropic">Anthropic</option>
                            <option value="openai">OpenAI</option>
                            <option value="zhipu">Zhipu (GLM)</option>
                          </select>
                        </div>
                        <div>
                          <label style={labelStyle()}>Label</label>
                          <input required value={configForm.label} onChange={(e) => setConfigForm((p) => ({ ...p, label: e.target.value }))} placeholder={configForm.provider === "openai" ? "My OpenAI Key" : configForm.provider === "zhipu" ? "My Zhipu Key" : "My Anthropic Key"} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                        </div>
                      </div>

                      <div>
                        <label style={labelStyle()}>API Key {editingConfig && "(leave blank to keep)"}</label>
                        <input type="password" required={!editingConfig} value={configForm.api_key} onChange={(e) => setConfigForm((p) => ({ ...p, api_key: e.target.value }))} placeholder={editingConfig ? "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022" : configForm.provider === "openai" ? "sk-..." : configForm.provider === "zhipu" ? "your-zhipu-api-key" : "sk-ant-..."} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                      </div>

                      <label style={{ display: "flex", alignItems: "center", gap: "0.5rem", cursor: "pointer" }}>
                        <input type="checkbox" checked={configForm.is_default} onChange={(e) => setConfigForm((p) => ({ ...p, is_default: e.target.checked }))} style={{ accentColor: C.glow }} />
                        <span style={{ fontSize: "0.85rem", color: C.text }}>Set as default</span>
                      </label>

                      <motion.button type="submit" disabled={configLoading} whileHover={configLoading ? {} : { scale: 1.02 }} whileTap={configLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(configLoading), width: "auto", padding: "0.6rem 1.5rem", alignSelf: "flex-start" }}>
                        {configLoading ? "Saving..." : editingConfig ? "Update" : "Add Key"}
                      </motion.button>
                    </form>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Config list */}
              {configs.length === 0 && !showAddConfig && (
                <div style={{ ...glassCard(), padding: "2rem", textAlign: "center" }}>
                  <p style={{ fontSize: "0.9rem", color: C.muted }}>No LLM keys configured yet.</p>
                </div>
              )}
              {configs.map((c) => (
                <div key={c.id} style={{ ...glassCard(), padding: "1rem 1.25rem", marginBottom: "0.5rem", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                    <span style={{ padding: "0.2rem 0.6rem", borderRadius: 6, background: "rgba(0,212,170,0.08)", border: `1px solid ${C.glow}30`, fontSize: "0.75rem", fontWeight: 500, color: C.glow, textTransform: "uppercase" }}>{c.provider}</span>
                    <span style={{ fontSize: "0.9rem", color: "#fff" }}>{c.label}</span>
                    {c.is_default && <span style={{ fontSize: "0.72rem", color: C.phosphor }}>{"\u2605"} Default</span>}
                  </div>
                  <div style={{ display: "flex", gap: "0.5rem" }}>
                    <button onClick={() => startEditConfig(c)} style={{ padding: "0.35rem 0.7rem", borderRadius: 6, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontSize: "0.78rem", cursor: "pointer" }}>Edit</button>
                    <button onClick={() => handleDeleteConfig(c.id)} style={{ padding: "0.35rem 0.7rem", borderRadius: 6, border: "1px solid rgba(255,107,107,0.2)", background: "rgba(255,107,107,0.05)", color: C.danger, fontSize: "0.78rem", cursor: "pointer" }}>{"\u2715"}</button>
                  </div>
                </div>
              ))}
            </section>

            {/* ==================== Gmail Access ==================== */}
            <section style={{ marginBottom: "3rem" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem" }}>
                <div>
                  <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.6rem", color: "#fff", fontWeight: 400, marginBottom: "0.2rem" }}>Gmail Access</h2>
                  <p style={{ fontFamily: "var(--font-lora), serif", fontStyle: "italic", fontSize: "0.85rem", color: C.muted }}>Connect your Gmail account to let agents read your emails</p>
                </div>
              </div>

              {gmailMsg && (
                <div style={{ padding: "0.7rem 1rem", borderRadius: 8, marginBottom: "1rem", background: gmailMsg.type === "success" ? "rgba(0,212,170,0.08)" : "rgba(255,107,107,0.08)", border: `1px solid ${gmailMsg.type === "success" ? C.glow + "30" : "rgba(255,107,107,0.2)"}`, fontSize: "0.85rem", color: gmailMsg.type === "success" ? C.glow : C.danger }}>
                  {gmailMsg.text}
                </div>
              )}

              <div style={{ ...glassCard(), padding: "1.5rem", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                  <span style={{ padding: "0.2rem 0.6rem", borderRadius: 6, background: "rgba(234,67,53,0.08)", border: "1px solid rgba(234,67,53,0.3)", fontSize: "0.75rem", fontWeight: 500, color: "#EA4335", textTransform: "uppercase" }}>Gmail</span>
                  {gmailCred ? (
                    <span style={{ fontSize: "0.9rem", color: C.glow }}>Connected</span>
                  ) : (
                    <span style={{ fontSize: "0.9rem", color: C.muted }}>Not connected</span>
                  )}
                </div>
                <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={handleConnectGmail} disabled={gmailConnecting} style={{ padding: "0.6rem 1.2rem", borderRadius: 10, border: "none", background: gmailConnecting ? "rgba(255,255,255,0.1)" : `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: gmailConnecting ? C.muted : C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: gmailConnecting ? "wait" : "pointer" }}>
                  {gmailConnecting ? "Connecting..." : gmailCred ? "Reconnect" : "Connect Gmail"}
                </motion.button>
              </div>
            </section>

            {/* ==================== Google Calendar Access ==================== */}
            <section style={{ marginBottom: "3rem" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem" }}>
                <div>
                  <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.6rem", color: "#fff", fontWeight: 400, marginBottom: "0.2rem" }}>Google Calendar</h2>
                  <p style={{ fontFamily: "var(--font-lora), serif", fontStyle: "italic", fontSize: "0.85rem", color: C.muted }}>Connect your Google Calendar to let agents manage your events</p>
                </div>
              </div>

              {calendarMsg && (
                <div style={{ padding: "0.7rem 1rem", borderRadius: 8, marginBottom: "1rem", background: calendarMsg.type === "success" ? "rgba(0,212,170,0.08)" : "rgba(255,107,107,0.08)", border: `1px solid ${calendarMsg.type === "success" ? C.glow + "30" : "rgba(255,107,107,0.2)"}`, fontSize: "0.85rem", color: calendarMsg.type === "success" ? C.glow : C.danger }}>
                  {calendarMsg.text}
                </div>
              )}

              <div style={{ ...glassCard(), padding: "1.5rem", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                  <span style={{ padding: "0.2rem 0.6rem", borderRadius: 6, background: "rgba(66,133,244,0.08)", border: "1px solid rgba(66,133,244,0.3)", fontSize: "0.75rem", fontWeight: 500, color: "#4285F4", textTransform: "uppercase" }}>Calendar</span>
                  {calendarCred ? (
                    <span style={{ fontSize: "0.9rem", color: C.glow }}>Connected</span>
                  ) : (
                    <span style={{ fontSize: "0.9rem", color: C.muted }}>Not connected</span>
                  )}
                </div>
                <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={handleConnectCalendar} disabled={calendarConnecting} style={{ padding: "0.6rem 1.2rem", borderRadius: 10, border: "none", background: calendarConnecting ? "rgba(255,255,255,0.1)" : `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: calendarConnecting ? C.muted : C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: calendarConnecting ? "wait" : "pointer" }}>
                  {calendarConnecting ? "Connecting..." : calendarCred ? "Reconnect" : "Connect Calendar"}
                </motion.button>
              </div>
            </section>

            {/* ==================== Tool Credentials ==================== */}
            <section>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem" }}>
                <div>
                  <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.6rem", color: "#fff", fontWeight: 400, marginBottom: "0.2rem" }}>Tool Credentials</h2>
                  <p style={{ fontFamily: "var(--font-lora), serif", fontStyle: "italic", fontSize: "0.85rem", color: C.muted }}>Credentials for external services (WhatsApp, Telegram, email, etc.)</p>
                </div>
                <motion.button whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={() => { resetCredForm(); setShowAddCred(true); }} style={{ padding: "0.6rem 1.2rem", borderRadius: 10, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: "pointer" }}>
                  + Add Credential
                </motion.button>
              </div>

              {/* Add/Edit Cred Form */}
              <AnimatePresence>
                {showAddCred && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} style={{ overflow: "hidden", marginBottom: "1rem" }}>
                    <form onSubmit={handleSaveCred} style={{ ...glassCard(), padding: "1.5rem", display: "flex", flexDirection: "column", gap: "1rem", background: "rgba(6,14,18,0.9)", border: `1px solid ${C.glow}20` }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                        <h3 style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.95rem", fontWeight: 500, color: "#fff" }}>{editingCred ? "Edit" : "Add"} Credential</h3>
                        <button type="button" onClick={resetCredForm} style={{ background: "none", border: "none", color: C.muted, cursor: "pointer", fontSize: "1rem" }}>{"\u2715"}</button>
                      </div>

                      {credError && <div style={{ padding: "0.6rem 0.8rem", borderRadius: 8, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.82rem", color: C.danger }}>{credError}</div>}

                      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                        <div>
                          <label style={labelStyle()}>Name</label>
                          <input required value={credForm.name} onChange={(e) => setCredForm((p) => ({ ...p, name: e.target.value }))} placeholder="My WhatsApp Key" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                        </div>
                        <div>
                          <label style={labelStyle()}>Service</label>
                          <input required value={credForm.service} onChange={(e) => setCredForm((p) => ({ ...p, service: e.target.value }))} placeholder="whatsapp" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
                        </div>
                      </div>

                      <div>
                        <label style={labelStyle()}>Type</label>
                        <select value={credForm.credential_type} onChange={(e) => setCredForm((p) => ({ ...p, credential_type: e.target.value }))} style={selectStyle}>
                          <option value="api_key">API Key</option>
                          <option value="oauth_token">OAuth Token</option>
                          <option value="basic_auth">Basic Auth</option>
                          <option value="custom">Custom (JSON)</option>
                        </select>
                      </div>

                      <div>
                        <label style={labelStyle()}>Value {editingCred && "(leave blank to keep)"}</label>
                        <textarea required={!editingCred} value={credForm.value} onChange={(e) => setCredForm((p) => ({ ...p, value: e.target.value }))} placeholder={credForm.credential_type === "custom" ? '{"access_token": "...", "app_secret": "..."}' : "Your API key or token"} rows={3} style={{ ...inputStyle(), resize: "vertical" as const }} />
                      </div>

                      <motion.button type="submit" disabled={credLoading} whileHover={credLoading ? {} : { scale: 1.02 }} whileTap={credLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(credLoading), width: "auto", padding: "0.6rem 1.5rem", alignSelf: "flex-start" }}>
                        {credLoading ? "Saving..." : editingCred ? "Update" : "Add Credential"}
                      </motion.button>
                    </form>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Cred list */}
              {creds.length === 0 && !showAddCred && (
                <div style={{ ...glassCard(), padding: "2rem", textAlign: "center" }}>
                  <p style={{ fontSize: "0.9rem", color: C.muted }}>No credentials configured yet.</p>
                </div>
              )}
              {creds.map((c) => (
                <div key={c.id} style={{ ...glassCard(), padding: "1rem 1.25rem", marginBottom: "0.5rem", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                    <span style={{ padding: "0.2rem 0.6rem", borderRadius: 6, background: "rgba(155,114,207,0.08)", border: `1px solid ${C.lavender}30`, fontSize: "0.75rem", fontWeight: 500, color: C.lavender, textTransform: "uppercase" }}>{c.service}</span>
                    <span style={{ fontSize: "0.9rem", color: "#fff" }}>{c.name}</span>
                    <span style={{ fontSize: "0.75rem", color: C.faint }}>{c.credential_type}</span>
                  </div>
                  <div style={{ display: "flex", gap: "0.5rem" }}>
                    <button onClick={() => startEditCred(c)} style={{ padding: "0.35rem 0.7rem", borderRadius: 6, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontSize: "0.78rem", cursor: "pointer" }}>Edit</button>
                    <button onClick={() => handleDeleteCred(c.id)} style={{ padding: "0.35rem 0.7rem", borderRadius: 6, border: "1px solid rgba(255,107,107,0.2)", background: "rgba(255,107,107,0.05)", color: C.danger, fontSize: "0.78rem", cursor: "pointer" }}>{"\u2715"}</button>
                  </div>
                </div>
              ))}
            </section>
          </>
        )}
      </main>
    </div>
  );
}

export default function KeysPage() {
  return (
    <Protected>
      <KeysContent />
    </Protected>
  );
}
