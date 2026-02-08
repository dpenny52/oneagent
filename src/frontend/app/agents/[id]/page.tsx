"use client";

import { useEffect, useState, useMemo, FormEvent, useCallback } from "react";
import { useParams, useSearchParams } from "next/navigation";
import { api } from "../../lib/api";
import { Protected } from "../../lib/protected";
import { C } from "../../lib/theme";
import { BUCKET_NAMES } from "../../lib/models";
import type { AgentDetail as Agent, Schedule, Goal, GoalStep, Message, Bucket, LlmConfig, Credential, Tab } from "../../lib/types";
import { fontVars } from "../../components/fonts";
import { useKeyframes } from "../../components/useKeyframes";
import { Orb } from "../../components/Orb";
import { MeshGradient } from "../../components/MeshGradient";
import { TopBar } from "../../components/TopBar";
import { ChatTab } from "../../components/agent/ChatTab";
import { SettingsTab } from "../../components/agent/SettingsTab";
import { SchedulesTab } from "../../components/agent/SchedulesTab";
import { PermissionsTab } from "../../components/agent/PermissionsTab";
import { GuideTab } from "../../components/agent/GuideTab";

/* ================================================================== */
/*  Agent detail content                                               */
/* ================================================================== */
function AgentDetailContent() {
  useKeyframes("agent-detail-kf", `@keyframes typingDot { 0%,100%{opacity:0.3} 50%{opacity:1} }`);
  const params = useParams();
  const searchParams = useSearchParams();
  const agentId = params.id as string;
  const [agent, setAgent] = useState<Agent | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>((searchParams.get("tab") as Tab) || "chat");

  // Chat state
  const [messages, setMessages] = useState<Message[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [sending, setSending] = useState(false);

  // Settings state
  const [settingsForm, setSettingsForm] = useState<Partial<Agent>>({});
  const [configs, setConfigs] = useState<LlmConfig[]>([]);
  const [settingsLoading, setSaving] = useState(false);
  const [settingsMsg, setSettingsMsg] = useState("");

  // Schedules state
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [newCron, setNewCron] = useState("");
  const [newMessage, setNewMessage] = useState("");
  const [addingSchedule, setAddingSchedule] = useState(false);
  const [scheduleError, setScheduleError] = useState("");

  // Goals state
  const [goals, setGoals] = useState<Goal[]>([]);

  // Permissions state
  const [buckets, setBuckets] = useState<Bucket[]>([]);
  const [bucketsLoaded, setBucketsLoaded] = useState(false);
  const [credentials, setCredentials] = useState<Credential[]>([]);
  const [permLoading, setPermLoading] = useState(false);
  const [permMsg, setPermMsg] = useState("");

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
  }, [tab, agentId]);

  /* ---- Load schedules + goals when schedules tab (only first visit) ---- */
  useEffect(() => {
    if (tab === "schedules") {
      api.get<Schedule[]>(`/api/agents/${agentId}/schedules`).then((r) => { if (r.ok) setSchedules(r.data); });
      api.get<Goal[]>(`/api/agents/${agentId}/goals`).then((r) => { if (r.ok) setGoals(r.data); });
    }
  }, [tab, agentId]);

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

  /* ---- Schedule actions ---- */
  async function handleAddSchedule() {
    if (!newCron.trim()) return;
    setAddingSchedule(true);
    setScheduleError("");
    const res = await api.post<Schedule>(`/api/agents/${agentId}/schedules`, {
      schedule: { cron: newCron.trim(), message: newMessage.trim() || null },
    });
    setAddingSchedule(false);
    if (res.ok) {
      setSchedules((prev) => [...prev, res.data]);
      setNewCron("");
      setNewMessage("");
    } else {
      setScheduleError(res.error);
    }
  }

  async function handleDeleteSchedule(scheduleId: string) {
    const res = await api.del(`/api/agents/${agentId}/schedules/${scheduleId}`);
    if (res.ok) {
      setSchedules((prev) => prev.filter((s) => s.id !== scheduleId));
    }
  }

  async function handleToggleSchedule(schedule: Schedule) {
    const res = await api.put<Schedule>(`/api/agents/${agentId}/schedules/${schedule.id}`, {
      schedule: { enabled: !schedule.enabled },
    });
    if (res.ok) {
      setSchedules((prev) => prev.map((s) => s.id === schedule.id ? res.data : s));
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

  /* ---- Schedule grouping by goal ---- */
  const scheduleGoalMap = useMemo(() => {
    const map = new Map<string, { goal: Goal; role: "review" | "step"; step?: GoalStep }>();
    for (const goal of goals) {
      if (goal.review_schedule_id) {
        map.set(goal.review_schedule_id, { goal, role: "review" });
      }
      for (const step of goal.steps || []) {
        if (step.schedule_id) {
          map.set(step.schedule_id, { goal, role: "step", step });
        }
      }
    }
    return map;
  }, [goals]);

  const standaloneSchedules = useMemo(() =>
    schedules.filter((s) => !scheduleGoalMap.has(s.id)),
    [schedules, scheduleGoalMap]
  );

  const goalGroups = useMemo(() => {
    const groupMap = new Map<string, { goal: Goal; schedules: { schedule: Schedule; role: "review" | "step"; step?: GoalStep }[] }>();
    for (const s of schedules) {
      const entry = scheduleGoalMap.get(s.id);
      if (!entry) continue;
      if (!groupMap.has(entry.goal.id)) {
        groupMap.set(entry.goal.id, { goal: entry.goal, schedules: [] });
      }
      groupMap.get(entry.goal.id)!.schedules.push({ schedule: s, role: entry.role, step: entry.step });
    }
    return Array.from(groupMap.values());
  }, [schedules, scheduleGoalMap]);

  if (loading) {
    return <div style={{ minHeight: "100vh", background: C.bg, display: "flex", alignItems: "center", justifyContent: "center", color: C.muted }}>Loading...</div>;
  }

  if (!agent) {
    return <div style={{ minHeight: "100vh", background: C.bg, display: "flex", alignItems: "center", justifyContent: "center", color: C.danger }}>Agent not found</div>;
  }

  const canChat = agent.has_llm_config;
  const tabNames: Tab[] = ["chat", "schedules", "settings", "permissions", "guide"];
  function switchTab(t: Tab) { setTab(t); }

  return (
    <div className={fontVars} style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "var(--font-dm), sans-serif", position: "relative" }}>
      <Orb size={400} color={C.glow} top="-5%" left="-8%" animation="drift1" duration="20s" opacity={0.06} />
      <Orb size={300} color={C.lavender} top="40%" left="85%" animation="drift2" duration="24s" opacity={0.05} />
      <MeshGradient opacity={0.15} threeGradients={false} />

      <TopBar breadcrumbs={[{ label: "Dashboard", href: "/dashboard" }, { label: agent.name }]} />

      <main style={{ position: "relative", zIndex: 2, maxWidth: 900, margin: "0 auto", padding: "2rem 1.5rem" }}>
        {/* Agent header */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1.5rem", flexWrap: "wrap", gap: "1rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
            <a href="/dashboard" title="Back to Dashboard" style={{ display: "inline-flex", alignItems: "center", justifyContent: "center", width: 36, height: 36, borderRadius: 10, border: `1px solid ${C.faint}`, background: "rgba(255,255,255,0.04)", color: C.muted, textDecoration: "none", flexShrink: 0, transition: "all 0.2s" }} onMouseEnter={e => { e.currentTarget.style.background = "rgba(255,255,255,0.08)"; e.currentTarget.style.color = C.text; }} onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = C.muted; }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/></svg>
            </a>
            <h1 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.8rem", fontWeight: 400, color: "#fff" }}>{agent.name}</h1>
            <span style={{ fontSize: "0.72rem", padding: "0.25rem 0.6rem", borderRadius: 6, background: canChat ? "rgba(0,212,170,0.12)" : "rgba(255,200,50,0.08)", border: `1px solid ${canChat ? `${C.glow}44` : "rgba(255,200,50,0.3)"}`, color: canChat ? C.glow : "#FFD166", fontWeight: 500, letterSpacing: "0.05em" }}>{canChat ? "Ready" : "Needs LLM Config"}</span>
          </div>
        </div>

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
          <ChatTab canChat={canChat} messages={messages} chatInput={chatInput} setChatInput={setChatInput} sending={sending} onSend={handleSend} onClearHistory={handleClearHistory} />
        )}

        {/* ==================== SCHEDULES TAB ==================== */}
        {tab === "schedules" && (
          <SchedulesTab goalGroups={goalGroups} standaloneSchedules={standaloneSchedules} newCron={newCron} setNewCron={setNewCron} newMessage={newMessage} setNewMessage={setNewMessage} addingSchedule={addingSchedule} scheduleError={scheduleError} onToggleSchedule={handleToggleSchedule} onDeleteSchedule={handleDeleteSchedule} onAddSchedule={handleAddSchedule} />
        )}

        {/* ==================== SETTINGS TAB ==================== */}
        {tab === "settings" && (
          <SettingsTab settingsForm={settingsForm} setSettingsForm={setSettingsForm} configs={configs} settingsLoading={settingsLoading} settingsMsg={settingsMsg} onSave={handleSaveSettings} />
        )}

        {/* ==================== PERMISSIONS TAB ==================== */}
        {tab === "permissions" && (
          <PermissionsTab buckets={buckets} credentials={credentials} permLoading={permLoading} permMsg={permMsg} onToggleBucket={toggleBucket} onSetBucketCredential={setBucketCredential} onSave={handleSavePermissions} />
        )}

        {/* ==================== GUIDE TAB ==================== */}
        {tab === "guide" && <GuideTab agentId={agent.id} />}
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
