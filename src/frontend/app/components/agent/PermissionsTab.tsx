import { useState } from "react";
import { motion } from "framer-motion";
import { C, inputStyle, buttonStyle, labelStyle, glassCard } from "../../lib/theme";
import { BUCKET_NAMES, BUCKET_CONFIG } from "../../lib/models";
import type { Bucket, Credential } from "../../lib/types";
import { AddCredentialModal } from "./AddCredentialModal";

export function PermissionsTab({
  buckets,
  credentials,
  permLoading,
  permMsg,
  onToggleBucket,
  onSetBucketCredential,
  onSave,
  onCredentialCreated,
}: {
  buckets: Bucket[];
  credentials: Credential[];
  permLoading: boolean;
  permMsg: string;
  onToggleBucket: (name: string) => void;
  onSetBucketCredential: (name: string, credId: string) => void;
  onSave: () => void;
  onCredentialCreated?: (credential: Credential) => void;
}) {
  const selectStyle: React.CSSProperties = { ...inputStyle(), appearance: "none" as const, cursor: "pointer" };
  const [modalBucket, setModalBucket] = useState<string | null>(null);

  function handleToggle(name: string) {
    const bucket = buckets.find((b) => b.bucket === name);
    const wasActive = bucket && !bucket.revoked_at;
    onToggleBucket(name);

    // Auto-select first matching credential when toggling ON
    if (!wasActive) {
      const cfg = BUCKET_CONFIG[name as keyof typeof BUCKET_CONFIG];
      if (cfg.needsCredential && !cfg.isOAuth) {
        const match = credentials.find(
          (c) =>
            c.credential_type === cfg.credentialType &&
            (cfg.service === "" || c.service === cfg.service)
        );
        if (match) {
          onSetBucketCredential(name, match.id);
        }
      } else if (cfg.needsCredential && cfg.isOAuth) {
        const match = credentials.find((c) => c.service === cfg.service);
        if (match) {
          onSetBucketCredential(name, match.id);
        }
      }
    }
  }

  function handleCredCreated(bucketName: string, cred: Credential) {
    onCredentialCreated?.(cred);
    onSetBucketCredential(bucketName, cred.id);
    setModalBucket(null);
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
      {BUCKET_NAMES.map((name) => {
        const bucket = buckets.find((b) => b.bucket === name);
        const active = bucket && !bucket.revoked_at;
        const cfg = BUCKET_CONFIG[name];

        return (
          <div key={name} style={{ ...glassCard(), padding: "1.25rem", transition: "border-color 0.3s", borderColor: active ? `${C.glow}30` : undefined }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: active && cfg.needsCredential ? "1rem" : 0 }}>
              <div>
                <h3 style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.95rem", fontWeight: 500, color: "#fff", textTransform: "capitalize" }}>
                  {name.replace(/_/g, " ")}
                </h3>
                <p style={{ fontSize: "0.78rem", color: C.faint, marginTop: "0.2rem" }}>
                  {cfg.description}
                </p>
              </div>
              <button
                onClick={() => handleToggle(name)}
                style={{
                  width: 44,
                  height: 24,
                  borderRadius: 12,
                  border: "none",
                  background: active ? C.glow : "rgba(255,255,255,0.1)",
                  cursor: "pointer",
                  position: "relative",
                  transition: "background 0.3s",
                  flexShrink: 0,
                }}
              >
                <div style={{ width: 18, height: 18, borderRadius: "50%", background: "#fff", position: "absolute", top: 3, left: active ? 23 : 3, transition: "left 0.3s" }} />
              </button>
            </div>

            {/* ---- Credential UI when active ---- */}
            {active && cfg.needsCredential && cfg.isOAuth && (
              <OAuthStatus credentials={credentials} service={cfg.service} serviceLabel={cfg.serviceLabel} />
            )}

            {active && cfg.needsCredential && !cfg.isOAuth && (
              <StandardCredentialSelector
                bucketName={name}
                bucket={bucket}
                credentials={credentials}
                cfg={cfg}
                selectStyle={selectStyle}
                onSetCredential={(credId) => onSetBucketCredential(name, credId)}
                onAddClick={() => setModalBucket(name)}
              />
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

      {/* ---- Add Credential Modal ---- */}
      {modalBucket && (() => {
        const mcfg = BUCKET_CONFIG[modalBucket as keyof typeof BUCKET_CONFIG];
        if (!mcfg.needsCredential) return null;
        return (
          <AddCredentialModal
            service={mcfg.service}
            credentialType={mcfg.credentialType}
            defaultName={mcfg.defaultName}
            valuePlaceholder={mcfg.valuePlaceholder}
            serviceLabel={mcfg.serviceLabel}
            editableService={mcfg.service === ""}
            onCreated={(cred) => handleCredCreated(modalBucket, cred)}
            onClose={() => setModalBucket(null)}
          />
        );
      })()}
    </div>
  );
}

/* ---- OAuth connection status ---- */
function OAuthStatus({ credentials, service, serviceLabel }: { credentials: Credential[]; service: string; serviceLabel: string }) {
  const cred = credentials.find((c) => c.service === service);
  const connected = !!cred;

  return (
    <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
      <span style={{
        width: 8,
        height: 8,
        borderRadius: "50%",
        background: connected ? C.glow : "#E8A838",
        display: "inline-block",
        flexShrink: 0,
      }} />
      {connected ? (
        <span style={{ fontSize: "0.82rem", color: C.glow }}>Connected &mdash; {cred.name}</span>
      ) : (
        <span style={{ fontSize: "0.82rem", color: "#E8A838" }}>
          Not connected &mdash;{" "}
          <a href="/keys" style={{ color: C.glow, textDecoration: "underline", textUnderlineOffset: 2 }}>
            Connect {serviceLabel} on Keys page
          </a>
        </span>
      )}
    </div>
  );
}

/* ---- Standard credential dropdown + add button ---- */
function StandardCredentialSelector({
  bucketName,
  bucket,
  credentials,
  cfg,
  selectStyle,
  onSetCredential,
  onAddClick,
}: {
  bucketName: string;
  bucket: Bucket;
  credentials: Credential[];
  cfg: Extract<(typeof BUCKET_CONFIG)[keyof typeof BUCKET_CONFIG], { needsCredential: true }>;
  selectStyle: React.CSSProperties;
  onSetCredential: (credId: string) => void;
  onAddClick: () => void;
}) {
  const filtered = credentials.filter(
    (c) =>
      c.credential_type === cfg.credentialType &&
      (cfg.service === "" || c.service === cfg.service)
  );

  return (
    <div>
      <label style={labelStyle()}>
        Credential{!cfg.required && <span style={{ color: C.muted, fontWeight: 400 }}> (optional)</span>}
      </label>
      <div style={{ display: "flex", gap: "0.5rem", alignItems: "stretch" }}>
        <select
          value={bucket?.credential_id || ""}
          onChange={(e) => onSetCredential(e.target.value)}
          style={{ ...selectStyle, flex: 1 }}
        >
          <option value="">None</option>
          {filtered.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name} ({c.service || "generic"})
            </option>
          ))}
        </select>
        <button
          type="button"
          onClick={onAddClick}
          title="Add new credential"
          style={{
            width: 42,
            borderRadius: 12,
            border: `1px solid ${C.faint}`,
            background: "rgba(255,255,255,0.03)",
            color: C.glow,
            fontSize: "1.2rem",
            cursor: "pointer",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transition: "border-color 0.2s, background 0.2s",
            flexShrink: 0,
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.borderColor = `${C.glow}55`;
            e.currentTarget.style.background = "rgba(0,212,170,0.06)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.borderColor = C.faint;
            e.currentTarget.style.background = "rgba(255,255,255,0.03)";
          }}
        >
          +
        </button>
      </div>
    </div>
  );
}
