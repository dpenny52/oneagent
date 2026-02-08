"use client";

import { useState } from "react";
import { C } from "../../lib/theme";

export function CodeBlock({ code }: { code: string }) {
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
