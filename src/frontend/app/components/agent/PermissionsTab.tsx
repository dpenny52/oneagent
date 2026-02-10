import { motion } from "framer-motion";
import { C, inputStyle, buttonStyle, labelStyle, glassCard } from "../../lib/theme";
import { BUCKET_NAMES } from "../../lib/models";
import type { Bucket, Credential } from "../../lib/types";

export function PermissionsTab({
  buckets,
  credentials,
  permLoading,
  permMsg,
  onToggleBucket,
  onSetBucketCredential,
  onSave,
}: {
  buckets: Bucket[];
  credentials: Credential[];
  permLoading: boolean;
  permMsg: string;
  onToggleBucket: (name: string) => void;
  onSetBucketCredential: (name: string, credId: string) => void;
  onSave: () => void;
}) {
  const selectStyle: React.CSSProperties = { ...inputStyle(), appearance: "none" as const, cursor: "pointer" };

  return (
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
                  {name === "gmail" && "Allow reading emails from connected Gmail account"}
                  {name === "web_search" && "Allow searching the web for information (requires Tavily API key)"}
                  {name === "google_calendar" && "Allow managing Google Calendar events (create, read, update, delete)"}
                  {name === "whatsapp" && "Allow sending WhatsApp messages to phone numbers"}
                </p>
              </div>
              <button onClick={() => onToggleBucket(name)} style={{ width: 44, height: 24, borderRadius: 12, border: "none", background: active ? C.glow : "rgba(255,255,255,0.1)", cursor: "pointer", position: "relative", transition: "background 0.3s" }}>
                <div style={{ width: 18, height: 18, borderRadius: "50%", background: "#fff", position: "absolute", top: 3, left: active ? 23 : 3, transition: "left 0.3s" }} />
              </button>
            </div>
            {active && (
              <div>
                <label style={labelStyle()}>Credential</label>
                <select value={bucket?.credential_id || ""} onChange={(e) => onSetBucketCredential(name, e.target.value)} style={selectStyle}>
                  <option value="">None</option>
                  {credentials.map((c) => <option key={c.id} value={c.id}>{c.name} ({c.service})</option>)}
                </select>
              </div>
            )}
          </div>
        );
      })}
      <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginTop: "0.5rem" }}>
        <motion.button onClick={onSave} disabled={permLoading} whileHover={permLoading ? {} : { scale: 1.02 }} whileTap={permLoading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(permLoading), width: "auto", padding: "0.7rem 2rem" }}>
          {permLoading ? "Saving..." : "Save Permissions"}
        </motion.button>
        {permMsg && <span style={{ fontSize: "0.85rem", color: permMsg.startsWith("Error") ? C.danger : C.glow }}>{permMsg}</span>}
      </div>
    </div>
  );
}
