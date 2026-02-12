import { motion } from "framer-motion";
import { FormEvent } from "react";
import { C, inputStyle, buttonStyle, labelStyle, glassCard } from "../../lib/theme";
import { MODEL_OPTIONS } from "../../lib/models";
import type { AgentDetail as Agent, LlmConfig } from "../../lib/types";
import { applyFocus, removeFocus } from "../FocusHandlers";

export function SettingsTab({
  settingsForm,
  setSettingsForm,
  configs,
  settingsLoading,
  settingsMsg,
  onSave,
}: {
  settingsForm: Partial<Agent>;
  setSettingsForm: React.Dispatch<React.SetStateAction<Partial<Agent>>>;
  configs: LlmConfig[];
  settingsLoading: boolean;
  settingsMsg: string;
  onSave: (e: FormEvent) => void;
}) {
  const selectStyle: React.CSSProperties = { ...inputStyle(), appearance: "none" as const, cursor: "pointer" };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
      <form onSubmit={onSave} style={{ ...glassCard(), padding: "2rem", display: "flex", flexDirection: "column", gap: "1.25rem" }}>
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
              <select value={settingsForm.model_provider || "anthropic"} onChange={(e) => { const prov = e.target.value; setSettingsForm((p) => ({ ...p, model_provider: prov, model_id: MODEL_OPTIONS[prov]?.[0]?.id || p.model_id, llm_config_id: null })); }} style={selectStyle}>
                <option value="anthropic">Anthropic</option>
                <option value="openai">OpenAI</option>
                <option value="zhipu">Zhipu (GLM)</option>
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
                {configs.filter((c) => c.provider === (settingsForm.model_provider || "anthropic")).map((c) => <option key={c.id} value={c.id}>{c.label}{c.is_default ? " \u2605" : ""}</option>)}
              </select>
              <a href="/keys" style={{ padding: "0 1rem", borderRadius: 12, border: `1px solid ${C.glow}30`, background: "rgba(0,212,170,0.05)", color: C.glow, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", fontWeight: 500, textDecoration: "none", display: "flex", alignItems: "center", whiteSpace: "nowrap" }}>+ Add Key</a>
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "1rem", marginTop: "1rem" }}>
            <div>
              <label style={labelStyle()}>Max Steps Per Run</label>
              <input type="number" min={1} max={500} value={settingsForm.max_steps_per_run || 50} onChange={(e) => setSettingsForm((p) => ({ ...p, max_steps_per_run: parseInt(e.target.value) || 50 }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>
            <div>
              <label style={labelStyle()}>Max Runs Per Day</label>
              <input type="number" min={1} max={10000} value={settingsForm.max_runs_per_day || 100} onChange={(e) => setSettingsForm((p) => ({ ...p, max_runs_per_day: parseInt(e.target.value) || 100 }))} style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
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

        <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginTop: "0.5rem" }}>
          <motion.button type="submit" disabled={settingsLoading} whileHover={settingsLoading ? {} : { scale: 1.02 }} whileTap={settingsLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(settingsLoading), width: "auto", padding: "0.7rem 2rem" }}>
            {settingsLoading ? "Saving..." : "Save Settings"}
          </motion.button>
          {settingsMsg && <span style={{ fontSize: "0.85rem", color: settingsMsg.startsWith("Error") ? C.danger : C.glow }}>{settingsMsg}</span>}
        </div>
      </form>
    </div>
  );
}
