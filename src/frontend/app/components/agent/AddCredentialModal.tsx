import { useState, FormEvent } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { api } from "../../lib/api";
import { C, inputStyle, buttonStyle, labelStyle, glassCard } from "../../lib/theme";
import { applyFocus, removeFocus } from "../FocusHandlers";
import type { Credential } from "../../lib/types";

export function AddCredentialModal({
  service,
  credentialType,
  defaultName,
  valuePlaceholder,
  serviceLabel,
  editableService,
  onCreated,
  onClose,
}: {
  service: string;
  credentialType: string;
  defaultName: string;
  valuePlaceholder: string;
  serviceLabel: string;
  editableService?: boolean;
  onCreated: (credential: Credential) => void;
  onClose: () => void;
}) {
  const [name, setName] = useState(defaultName);
  const [svc, setSvc] = useState(service);
  const [value, setValue] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const res = await api.post<Credential>("/api/credentials", {
      credential: { name, service: svc, credential_type: credentialType, value },
    });
    setLoading(false);
    if (res.ok) {
      onCreated(res.data);
    } else {
      setError(res.error);
    }
  }

  const badgeStyle: React.CSSProperties = {
    display: "inline-block",
    padding: "0.2rem 0.6rem",
    borderRadius: 6,
    background: "rgba(155,114,207,0.08)",
    border: `1px solid ${C.lavender}30`,
    fontSize: "0.75rem",
    fontWeight: 500,
    color: C.lavender,
  };

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={onClose}
        style={{
          position: "fixed",
          inset: 0,
          zIndex: 1000,
          background: "rgba(0,0,0,0.6)",
          backdropFilter: "blur(6px)",
          WebkitBackdropFilter: "blur(6px)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "1rem",
        }}
      >
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          transition={{ duration: 0.2 }}
          onClick={(e) => e.stopPropagation()}
          style={{
            ...glassCard(),
            width: "100%",
            maxWidth: 480,
            padding: "1.5rem",
            background: "rgba(6,14,18,0.95)",
            border: `1px solid ${C.glow}20`,
          }}
        >
          <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <h3 style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.95rem", fontWeight: 500, color: "#fff" }}>
                Add {serviceLabel} Credential
              </h3>
              <button type="button" onClick={onClose} style={{ background: "none", border: "none", color: C.muted, cursor: "pointer", fontSize: "1rem" }}>
                {"\u2715"}
              </button>
            </div>

            {error && (
              <div style={{ padding: "0.6rem 0.8rem", borderRadius: 8, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.82rem", color: C.danger }}>
                {error}
              </div>
            )}

            <div>
              <label style={labelStyle()}>Name</label>
              <input
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder={defaultName}
                style={inputStyle()}
                onFocus={applyFocus}
                onBlur={removeFocus}
              />
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
              <div>
                <label style={labelStyle()}>Service</label>
                {editableService ? (
                  <input
                    required
                    value={svc}
                    onChange={(e) => setSvc(e.target.value)}
                    placeholder="service name"
                    style={inputStyle()}
                    onFocus={applyFocus}
                    onBlur={removeFocus}
                  />
                ) : (
                  <div style={{ ...badgeStyle, marginTop: "0.2rem" }}>{serviceLabel}</div>
                )}
              </div>
              <div>
                <label style={labelStyle()}>Type</label>
                <div style={{ ...badgeStyle, marginTop: "0.2rem" }}>{credentialType}</div>
              </div>
            </div>

            <div>
              <label style={labelStyle()}>Value</label>
              <textarea
                required
                value={value}
                onChange={(e) => setValue(e.target.value)}
                placeholder={valuePlaceholder}
                rows={3}
                style={{ ...inputStyle(), resize: "vertical" as const }}
              />
            </div>

            <motion.button
              type="submit"
              disabled={loading}
              whileHover={loading ? {} : { scale: 1.02 }}
              whileTap={loading ? {} : { scale: 0.98 }}
              style={{ ...buttonStyle(loading), width: "auto", padding: "0.6rem 1.5rem", alignSelf: "flex-start" }}
            >
              {loading ? "Creating..." : "Create Credential"}
            </motion.button>
          </form>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}
