"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState, FormEvent } from "react";
import { C, inputStyle, buttonStyle, labelStyle } from "../lib/theme";
import { fontVars } from "../components/fonts";
import { useKeyframes } from "../components/useKeyframes";
import { Orb } from "../components/Orb";
import { MeshGradient } from "../components/MeshGradient";
import { applyFocus, removeFocus } from "../components/FocusHandlers";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000";

export default function ResetPasswordPage() {
  useKeyframes("reset-pw-kf");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const [token, setToken] = useState("");

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setToken(params.get("token") || "");
  }, []);

  async function handleReset(e: FormEvent) {
    e.preventDefault();
    if (password !== confirmPassword) { setError("Passwords do not match."); return; }
    if (password.length < 12) { setError("Password must be at least 12 characters."); return; }
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`${API_BASE}/api/auth/reset-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user: { token, password } }),
      });
      if (res.ok) {
        setSuccess(true);
        setTimeout(() => { window.location.href = "/login"; }, 2000);
      } else {
        const data = await res.json();
        setError(data.error || "Invalid or expired reset token.");
      }
    } catch {
      setError("Unable to connect to the server.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className={fontVars} style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "var(--font-dm), sans-serif", overflowX: "hidden", position: "relative", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
      <Orb size={400} color={C.glow} top="-10%" left="-8%" animation="drift1" duration="20s" opacity={0.12} />
      <Orb size={300} color={C.lavender} top="15%" left="70%" animation="drift2" duration="24s" opacity={0.1} />

      <MeshGradient />

      <motion.div initial={{ opacity: 0, y: 30, scale: 0.97 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={{ duration: 0.8 }} style={{ position: "relative", zIndex: 2, width: "100%", maxWidth: 420, padding: "2.5rem 2rem", margin: "2rem 1.5rem", borderRadius: 24, background: "rgba(255,255,255,0.025)", backdropFilter: "blur(30px)", WebkitBackdropFilter: "blur(30px)", border: `1px solid ${C.glow}15`, boxShadow: `0 0 60px ${C.glow}06, inset 0 1px 0 ${C.glow}08`, animation: "pulseGlow 4s ease-in-out infinite" }}>
        <motion.a href="/login" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }} style={{ display: "inline-flex", alignItems: "center", gap: "0.35rem", fontFamily: "var(--font-dm), sans-serif", fontSize: "0.78rem", color: C.muted, textDecoration: "none", marginBottom: "1.5rem", transition: "color 0.2s" }} onMouseEnter={(e) => (e.currentTarget.style.color = C.glow)} onMouseLeave={(e) => (e.currentTarget.style.color = "rgba(216,237,230,0.40)")}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7" /></svg>
          Back to login
        </motion.a>

        <motion.h1 initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.15 }} style={{ fontFamily: "var(--font-instrument), serif", fontSize: "2rem", fontWeight: 400, color: "#fff", marginBottom: "0.4rem", textShadow: `0 0 30px ${C.glow}20` }}>
          Reset password
        </motion.h1>
        <motion.p initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.25 }} style={{ fontFamily: "var(--font-lora), serif", fontSize: "0.92rem", fontStyle: "italic", color: C.muted, marginBottom: "2rem" }}>
          Enter your new password below
        </motion.p>

        <AnimatePresence>
          {error && (
            <motion.div initial={{ opacity: 0, height: 0, marginBottom: 0 }} animate={{ opacity: 1, height: "auto", marginBottom: 16 }} exit={{ opacity: 0, height: 0, marginBottom: 0 }} transition={{ duration: 0.25 }} style={{ padding: "0.7rem 1rem", borderRadius: 10, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.85rem", color: C.danger, fontFamily: "var(--font-dm), sans-serif", overflow: "hidden" }}>
              {error}
            </motion.div>
          )}
        </AnimatePresence>

        {success ? (
          <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} style={{ textAlign: "center", padding: "2rem 1rem" }}>
            <div style={{ width: 56, height: 56, borderRadius: "50%", background: C.glowDim, border: `1px solid ${C.glow}33`, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 1.25rem" }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={C.glow} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6L9 17l-5-5" /></svg>
            </div>
            <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.25rem", color: "#fff", marginBottom: "0.6rem" }}>Password updated</h3>
            <p style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.88rem", color: C.muted, lineHeight: 1.6 }}>Redirecting to login...</p>
          </motion.div>
        ) : (
          <motion.form initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.35 }} onSubmit={handleReset} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div>
              <label style={labelStyle()}>New Password</label>
              <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="At least 12 characters" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>
            <div>
              <label style={labelStyle()}>Confirm Password</label>
              <input type="password" required value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} placeholder="Repeat your password" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
            </div>
            <motion.button type="submit" disabled={loading || !token} whileHover={loading ? {} : { scale: 1.02, boxShadow: `0 0 30px ${C.glow}33` }} whileTap={loading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(loading), marginTop: "0.5rem" }}>
              {loading ? "Updating..." : "Update Password"}
            </motion.button>
          </motion.form>
        )}
      </motion.div>
    </div>
  );
}
