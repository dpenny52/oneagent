"use client";

import { motion } from "framer-motion";
import { C } from "../../lib/theme";

export function DeployButton({
  user,
  size = "default",
}: {
  user: { id: string; email: string } | null;
  size?: "default" | "large";
}) {
  const isLarge = size === "large";
  return (
    <motion.a
      href={user ? "/dashboard" : "/login"}
      whileHover={{
        scale: 1.04,
        boxShadow: `0 0 36px ${C.glow}44, 0 0 72px ${C.glow}18`,
      }}
      whileTap={{ scale: 0.97 }}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "0.6rem",
        padding: isLarge ? "1.1rem 2.4rem" : "1rem 2.2rem",
        borderRadius: 14,
        background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
        color: C.bg,
        fontFamily: "var(--font-dm)",
        fontSize: isLarge ? "1.05rem" : "1rem",
        fontWeight: 600,
        textDecoration: "none",
        cursor: "pointer",
        border: "none",
        letterSpacing: "0.01em",
        boxShadow: `0 0 24px ${C.glow}22`,
      }}
    >
      Deploy Your Agent
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 12h14M12 5l7 7-7 7" />
      </svg>
    </motion.a>
  );
}
