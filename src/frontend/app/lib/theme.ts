/* ------------------------------------------------------------------ */
/*  Shared color palette & style helpers                               */
/* ------------------------------------------------------------------ */

export const C = {
  bg: "#060E12",
  glow: "#00D4AA",
  glowDim: "rgba(0,212,170,0.12)",
  forest: "#1B4D3E",
  forestDim: "rgba(27,77,62,0.15)",
  lavender: "#9B72CF",
  lavenderDim: "rgba(155,114,207,0.10)",
  phosphor: "#7FE5C0",
  text: "#D8EDE6",
  muted: "rgba(216,237,230,0.40)",
  faint: "rgba(216,237,230,0.18)",
  danger: "#FF6B6B",
} as const;

/* ---- Shared input style ---- */
export function inputStyle(): React.CSSProperties {
  return {
    width: "100%",
    padding: "0.85rem 1rem",
    borderRadius: 12,
    border: `1px solid ${C.faint}`,
    background: "rgba(255,255,255,0.03)",
    color: C.text,
    fontFamily: "var(--font-dm), sans-serif",
    fontSize: "0.95rem",
    fontWeight: 400,
    outline: "none",
    transition: "border-color 0.2s, box-shadow 0.2s",
  };
}

export const inputFocusCSS = `border-color: ${C.glow}55; box-shadow: 0 0 0 3px ${C.glow}12;`;

/* ---- Primary CTA button style ---- */
export function buttonStyle(loading = false): React.CSSProperties {
  return {
    width: "100%",
    padding: "0.9rem",
    borderRadius: 12,
    border: "none",
    background: loading
      ? C.forest
      : `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
    color: loading ? C.muted : C.bg,
    fontFamily: "var(--font-dm), sans-serif",
    fontSize: "0.95rem",
    fontWeight: 600,
    cursor: loading ? "not-allowed" : "pointer",
    letterSpacing: "0.01em",
    boxShadow: `0 0 20px ${C.glow}15`,
    transition: "background 0.3s",
  };
}

/* ---- Label style ---- */
export function labelStyle(): React.CSSProperties {
  return {
    display: "block",
    fontFamily: "var(--font-dm), sans-serif",
    fontSize: "0.8rem",
    fontWeight: 500,
    color: C.text,
    marginBottom: "0.4rem",
    letterSpacing: "0.03em",
  };
}

/* ---- Apply focus effect on an input element ---- */
export function applyInputFocus(e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) {
  const base = inputStyle();
  const cssStr = Object.entries(base)
    .map(([k, v]) => `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`)
    .join(";");
  e.currentTarget.setAttribute("style", `${cssStr}; ${inputFocusCSS}`);
}

export function removeInputFocus(e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) {
  Object.assign(e.currentTarget.style, inputStyle());
}

/* ---- Glass card style ---- */
export function glassCard(): React.CSSProperties {
  return {
    borderRadius: 24,
    background: "rgba(255,255,255,0.025)",
    backdropFilter: "blur(30px)",
    WebkitBackdropFilter: "blur(30px)",
    border: `1px solid ${C.glow}15`,
    boxShadow: `0 0 60px ${C.glow}06, inset 0 1px 0 ${C.glow}08`,
  };
}
