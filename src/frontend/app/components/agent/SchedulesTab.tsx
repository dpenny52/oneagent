import { motion } from "framer-motion";
import { C, inputStyle, labelStyle, glassCard } from "../../lib/theme";
import type { Schedule, Goal, GoalStep } from "../../lib/types";
import { applyFocus, removeFocus } from "../FocusHandlers";
import cronstrue from "cronstrue";

function cronToHuman(cron: string): string {
  try { return cronstrue.toString(cron, { use24HourTimeFormat: false }); }
  catch { return cron; }
}

export function SchedulesTab({
  goalGroups,
  standaloneSchedules,
  newCron,
  setNewCron,
  newMessage,
  setNewMessage,
  addingSchedule,
  scheduleError,
  onToggleSchedule,
  onDeleteSchedule,
  onAddSchedule,
}: {
  goalGroups: { goal: Goal; schedules: { schedule: Schedule; role: "review" | "step"; step?: GoalStep }[] }[];
  standaloneSchedules: Schedule[];
  newCron: string;
  setNewCron: (v: string) => void;
  newMessage: string;
  setNewMessage: (v: string) => void;
  addingSchedule: boolean;
  scheduleError: string;
  onToggleSchedule: (s: Schedule) => void;
  onDeleteSchedule: (id: string) => void;
  onAddSchedule: () => void;
}) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
      {/* Goal-grouped schedules */}
      {goalGroups.map(({ goal, schedules: goalSchedules }) => (
        <div key={goal.id} style={{ ...glassCard(), padding: "1.5rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", marginBottom: "1rem" }}>
            <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.1rem", color: "#fff", fontWeight: 400, margin: 0 }}>{goal.title}</h3>
            <span style={{
              fontSize: "0.68rem", padding: "0.2rem 0.5rem", borderRadius: 5, fontWeight: 500, letterSpacing: "0.04em", textTransform: "uppercase",
              background: goal.status === "active" ? "rgba(0,212,170,0.12)" : goal.status === "completed" ? "rgba(155,114,207,0.12)" : goal.status === "paused" ? "rgba(255,200,50,0.08)" : "rgba(255,107,107,0.08)",
              border: `1px solid ${goal.status === "active" ? `${C.glow}44` : goal.status === "completed" ? `${C.lavender}44` : goal.status === "paused" ? "rgba(255,200,50,0.3)" : `${C.danger}30`}`,
              color: goal.status === "active" ? C.glow : goal.status === "completed" ? C.lavender : goal.status === "paused" ? "#FFD166" : C.danger,
            }}>{goal.status}</span>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
            {goalSchedules.map(({ schedule: s, role, step }) => (
              <div key={s.id} style={{ display: "flex", alignItems: "center", gap: "0.75rem", padding: "0.7rem 1rem", borderRadius: 10, background: "rgba(255,255,255,0.03)", border: `1px solid ${s.enabled ? `${C.glow}20` : C.faint}` }}>
                <button onClick={() => onToggleSchedule(s)} style={{ width: 36, height: 20, borderRadius: 10, border: "none", background: s.enabled ? C.glow : "rgba(255,255,255,0.1)", cursor: "pointer", position: "relative", transition: "background 0.3s", flexShrink: 0 }}>
                  <div style={{ width: 14, height: 14, borderRadius: "50%", background: "#fff", position: "absolute", top: 3, left: s.enabled ? 19 : 3, transition: "left 0.3s" }} />
                </button>
                <span style={{ flexShrink: 0, display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
                  <span style={{ color: C.phosphor, fontSize: "0.82rem" }}>{cronToHuman(s.cron)}</span>
                  {cronToHuman(s.cron) !== s.cron && <code style={{ color: C.faint, fontSize: "0.62rem", marginTop: "-0.05rem" }}>{s.cron}</code>}
                </span>
                <span style={{
                  fontSize: "0.7rem", padding: "0.15rem 0.45rem", borderRadius: 4, fontWeight: 500, flexShrink: 0,
                  background: role === "review" ? "rgba(155,114,207,0.1)" : "rgba(0,212,170,0.08)",
                  border: `1px solid ${role === "review" ? `${C.lavender}30` : `${C.glow}25`}`,
                  color: role === "review" ? C.lavender : C.glow,
                }}>{role === "review" ? "Review" : step?.title || "Step"}</span>
                {s.last_run_at && <span style={{ fontSize: "0.72rem", color: C.faint, flexShrink: 0, marginLeft: "auto" }}>Last: {new Date(s.last_run_at).toLocaleString()}</span>}
              </div>
            ))}
          </div>
        </div>
      ))}

      {/* Standalone schedules */}
      <div style={{ ...glassCard(), padding: "1.5rem" }}>
        <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.1rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>Standalone Schedules</h3>
        {standaloneSchedules.length === 0 && (
          <p style={{ fontSize: "0.85rem", color: C.faint, marginBottom: 0 }}>No standalone schedules. Add one below or let the agent create goal-linked schedules.</p>
        )}
        {standaloneSchedules.length > 0 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
            {standaloneSchedules.map((s) => (
              <div key={s.id} style={{ display: "flex", alignItems: "center", gap: "0.75rem", padding: "0.7rem 1rem", borderRadius: 10, background: "rgba(255,255,255,0.03)", border: `1px solid ${s.enabled ? `${C.glow}20` : C.faint}` }}>
                <button onClick={() => onToggleSchedule(s)} style={{ width: 36, height: 20, borderRadius: 10, border: "none", background: s.enabled ? C.glow : "rgba(255,255,255,0.1)", cursor: "pointer", position: "relative", transition: "background 0.3s", flexShrink: 0 }}>
                  <div style={{ width: 14, height: 14, borderRadius: "50%", background: "#fff", position: "absolute", top: 3, left: s.enabled ? 19 : 3, transition: "left 0.3s" }} />
                </button>
                <span style={{ flexShrink: 0, display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
                  <span style={{ color: C.phosphor, fontSize: "0.82rem" }}>{cronToHuman(s.cron)}</span>
                  {cronToHuman(s.cron) !== s.cron && <code style={{ color: C.faint, fontSize: "0.62rem", marginTop: "-0.05rem" }}>{s.cron}</code>}
                </span>
                <span style={{ fontSize: "0.82rem", color: C.muted, flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{s.message || "(no message)"}</span>
                {s.last_run_at && <span style={{ fontSize: "0.72rem", color: C.faint, flexShrink: 0 }}>Last: {new Date(s.last_run_at).toLocaleString()}</span>}
                <button onClick={() => onDeleteSchedule(s.id)} style={{ padding: "0.2rem 0.5rem", borderRadius: 6, border: "1px solid rgba(255,107,107,0.2)", background: "rgba(255,107,107,0.05)", color: C.danger, fontSize: "0.75rem", cursor: "pointer" }}>{"\u2715"}</button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Add schedule */}
      <div style={{ ...glassCard(), padding: "1.5rem" }}>
        <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.1rem", color: "#fff", fontWeight: 400, marginBottom: "0.75rem" }}>Add Schedule</h3>
        <p style={{ fontSize: "0.82rem", color: C.muted, marginBottom: "1rem" }}>Create a standalone cron schedule. Requires an LLM Config to be assigned.</p>
        <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
          <div style={{ display: "flex", gap: "0.5rem", alignItems: "flex-end" }}>
            <div style={{ flex: 1 }}>
              <label style={labelStyle()}>Cron Expression</label>
              <input value={newCron} onChange={(e) => setNewCron(e.target.value)} placeholder="*/5 * * * *" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>
            <div style={{ flex: 2 }}>
              <label style={labelStyle()}>Message</label>
              <input value={newMessage} onChange={(e) => setNewMessage(e.target.value)} placeholder="Check for updates" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>
            <motion.button type="button" disabled={addingSchedule || !newCron.trim()} onClick={onAddSchedule} whileHover={addingSchedule ? {} : { scale: 1.03 }} whileTap={addingSchedule ? {} : { scale: 0.97 }} style={{ padding: "0.65rem 1.2rem", borderRadius: 12, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", fontWeight: 600, cursor: addingSchedule || !newCron.trim() ? "not-allowed" : "pointer", opacity: addingSchedule || !newCron.trim() ? 0.5 : 1, whiteSpace: "nowrap", flexShrink: 0 }}>
              {addingSchedule ? "..." : "+ Add"}
            </motion.button>
          </div>
          <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
            {[
              ["*/5 * * * *", "Every 5 min"],
              ["0 * * * *", "Hourly"],
              ["0 9 * * *", "Daily 9am"],
              ["0 9 * * 1", "Weekly Mon 9am"],
            ].map(([cron, label]) => (
              <button key={cron} type="button" onClick={() => setNewCron(cron)} style={{ padding: "0.25rem 0.6rem", borderRadius: 6, border: `1px solid ${C.faint}`, background: newCron === cron ? `${C.glow}15` : "transparent", color: newCron === cron ? C.glow : C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.75rem", cursor: "pointer" }}>
                {label}
              </button>
            ))}
          </div>
          {scheduleError && (
            <div style={{ fontSize: "0.82rem", color: C.danger }}>{scheduleError}</div>
          )}
        </div>
      </div>
    </div>
  );
}
