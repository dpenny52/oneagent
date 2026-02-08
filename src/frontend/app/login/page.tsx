"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState, FormEvent } from "react";
import { useAuth } from "../lib/auth";
import { C, inputStyle } from "../lib/theme";
import type { Spore } from "../lib/types";
import { fontVars } from "../components/fonts";
import { useKeyframes } from "../components/useKeyframes";
import { Orb } from "../components/Orb";
import { SporeField } from "../components/SporeField";
import { MeshGradient } from "../components/MeshGradient";
import { generateSpores } from "../components/generateSpores";
import { applyFocus, removeFocus } from "../components/FocusHandlers";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000";

/* ------------------------------------------------------------------ */
/*  Login mode type                                                    */
/* ------------------------------------------------------------------ */
type LoginMode = "password" | "magic-link";

/* ================================================================== */
/*  Main login page                                                    */
/* ================================================================== */
export default function LoginPage() {
  useKeyframes("login-page-kf");
  const { login: authLogin } = useAuth();
  const [spores, setSpores] = useState<Spore[]>([]);
  const [mode, setMode] = useState<LoginMode>("password");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [magicLinkSent, setMagicLinkSent] = useState(false);
  const [forgotMode, setForgotMode] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotSent, setForgotSent] = useState(false);

  useEffect(() => {
    setSpores(generateSpores(30));
  }, []);

  /* ---- Check for magic link token in URL ---- */
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const token = params.get("magic_token");
    if (token) {
      verifyMagicLink(token);
    }
  }, []);

  async function verifyMagicLink(token: string) {
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`${API_BASE}/api/auth/magic-link/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ token }),
      });
      const data = await res.json();
      if (res.ok && data.data?.user) {
        authLogin();
        window.location.href = "/dashboard";
      } else {
        setError(data.error || "Invalid or expired magic link.");
      }
    } catch {
      setError("Unable to connect to the server.");
    } finally {
      setLoading(false);
    }
  }

  async function handleForgotPassword(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`${API_BASE}/api/auth/forgot-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user: { email: forgotEmail } }),
      });
      if (res.ok) {
        setForgotSent(true);
      } else {
        // Always show success to avoid email enumeration
        setForgotSent(true);
      }
    } catch {
      setError("Unable to connect to the server.");
    } finally {
      setLoading(false);
    }
  }

  async function handlePasswordLogin(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`${API_BASE}/api/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ user: { email, password } }),
      });
      const data = await res.json();
      if (res.ok && data.data?.user) {
        authLogin();
        window.location.href = "/dashboard";
      } else {
        setError(data.error || "Invalid email or password.");
      }
    } catch {
      setError("Unable to connect to the server.");
    } finally {
      setLoading(false);
    }
  }

  async function handleMagicLink(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await fetch(`${API_BASE}/api/auth/magic-link`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user: { email } }),
      });
      if (res.ok) {
        setMagicLinkSent(true);
      } else {
        const data = await res.json();
        setError(data.error || "Something went wrong.");
      }
    } catch {
      setError("Unable to connect to the server.");
    } finally {
      setLoading(false);
    }
  }

  /* ---- Mode tab style ---- */
  function tabStyle(active: boolean): React.CSSProperties {
    return {
      flex: 1,
      padding: "0.65rem 0",
      borderRadius: 10,
      border: "none",
      cursor: "pointer",
      fontFamily: "var(--font-dm), sans-serif",
      fontSize: "0.85rem",
      fontWeight: active ? 500 : 400,
      color: active ? C.bg : C.muted,
      background: active
        ? `linear-gradient(135deg, ${C.glow}, ${C.forest})`
        : "transparent",
      transition: "all 0.25s ease",
      letterSpacing: "0.02em",
    };
  }

  return (
    <div
      className={fontVars}
      style={{
        minHeight: "100vh",
        background: C.bg,
        color: C.text,
        fontFamily: "var(--font-dm), sans-serif",
        overflowX: "hidden",
        position: "relative",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {/* ========== Ambient orbs ========== */}
      <Orb size={400} color={C.glow} top="-10%" left="-8%" animation="drift1" duration="20s" opacity={0.12} />
      <Orb size={300} color={C.lavender} top="15%" left="70%" animation="drift2" duration="24s" opacity={0.1} />
      <Orb size={250} color={C.phosphor} top="60%" left="-5%" animation="drift3" duration="26s" opacity={0.08} />
      <Orb size={350} color={C.forest} top="70%" left="65%" animation="drift1" duration="22s" opacity={0.12} />

      {/* ========== Floating spores ========== */}
      <SporeField spores={spores} />

      {/* ========== Mesh gradient ========== */}
      <MeshGradient />

      {/* ========== Login card ========== */}
      <motion.div
        initial={{ opacity: 0, y: 30, scale: 0.97 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        style={{
          position: "relative",
          zIndex: 2,
          width: "100%",
          maxWidth: 420,
          padding: "2.5rem 2rem",
          margin: "2rem 1.5rem",
          borderRadius: 24,
          background: "rgba(255,255,255,0.025)",
          backdropFilter: "blur(30px)",
          WebkitBackdropFilter: "blur(30px)",
          border: `1px solid ${C.glow}15`,
          boxShadow: `0 0 60px ${C.glow}06, inset 0 1px 0 ${C.glow}08`,
          animation: "pulseGlow 4s ease-in-out infinite",
        }}
      >
        {/* ---- Back link ---- */}
        <motion.a
          href="/"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3 }}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: "0.35rem",
            fontFamily: "var(--font-dm), sans-serif",
            fontSize: "0.78rem",
            color: C.muted,
            textDecoration: "none",
            marginBottom: "1.5rem",
            transition: "color 0.2s",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.color = C.glow)}
          onMouseLeave={(e) => (e.currentTarget.style.color = C.muted as string)}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Back
        </motion.a>

        {/* ---- Title ---- */}
        <motion.h1
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.15 }}
          style={{
            fontFamily: "var(--font-instrument), serif",
            fontSize: "2rem",
            fontWeight: 400,
            color: "#fff",
            marginBottom: "0.4rem",
            textShadow: `0 0 30px ${C.glow}20`,
            letterSpacing: "-0.01em",
          }}
        >
          Welcome back
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.25 }}
          style={{
            fontFamily: "var(--font-lora), serif",
            fontSize: "0.92rem",
            fontStyle: "italic",
            color: C.muted,
            marginBottom: "2rem",
          }}
        >
          Sign in to your agent
        </motion.p>

        {/* ---- Mode tabs ---- */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.35 }}
          style={{
            display: "flex",
            gap: 4,
            padding: 4,
            borderRadius: 12,
            background: "rgba(255,255,255,0.04)",
            marginBottom: "1.75rem",
          }}
        >
          <button
            type="button"
            onClick={() => { setMode("password"); setError(""); setMagicLinkSent(false); }}
            style={tabStyle(mode === "password")}
          >
            Password
          </button>
          <button
            type="button"
            onClick={() => { setMode("magic-link"); setError(""); setMagicLinkSent(false); }}
            style={tabStyle(mode === "magic-link")}
          >
            Magic Link
          </button>
        </motion.div>

        {/* ---- Error message ---- */}
        <AnimatePresence>
          {error && (
            <motion.div
              initial={{ opacity: 0, height: 0, marginBottom: 0 }}
              animate={{ opacity: 1, height: "auto", marginBottom: 16 }}
              exit={{ opacity: 0, height: 0, marginBottom: 0 }}
              transition={{ duration: 0.25 }}
              style={{
                padding: "0.7rem 1rem",
                borderRadius: 10,
                background: "rgba(255,107,107,0.08)",
                border: `1px solid rgba(255,107,107,0.2)`,
                fontSize: "0.85rem",
                color: C.danger,
                fontFamily: "var(--font-dm), sans-serif",
                overflow: "hidden",
              }}
            >
              {error}
            </motion.div>
          )}
        </AnimatePresence>

        {/* ---- Magic link sent success ---- */}
        <AnimatePresence>
          {magicLinkSent && (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{ duration: 0.3 }}
              style={{
                textAlign: "center",
                padding: "2rem 1rem",
              }}
            >
              <div
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: "50%",
                  background: `${C.glowDim}`,
                  border: `1px solid ${C.glow}33`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  margin: "0 auto 1.25rem",
                }}
              >
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={C.glow} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M22 2L11 13" />
                  <path d="M22 2L15 22L11 13L2 9L22 2Z" />
                </svg>
              </div>
              <h3
                style={{
                  fontFamily: "var(--font-instrument), serif",
                  fontSize: "1.25rem",
                  color: "#fff",
                  marginBottom: "0.6rem",
                }}
              >
                Check your email
              </h3>
              <p
                style={{
                  fontFamily: "var(--font-dm), sans-serif",
                  fontSize: "0.88rem",
                  color: C.muted,
                  lineHeight: 1.6,
                  marginBottom: "1.5rem",
                }}
              >
                We sent a magic link to <span style={{ color: C.phosphor }}>{email}</span>.
                Click the link in the email to sign in.
              </p>
              <button
                type="button"
                onClick={() => { setMagicLinkSent(false); setEmail(""); }}
                style={{
                  padding: "0.5rem 1.2rem",
                  borderRadius: 8,
                  border: `1px solid ${C.faint}`,
                  background: "transparent",
                  color: C.muted,
                  fontFamily: "var(--font-dm), sans-serif",
                  fontSize: "0.82rem",
                  cursor: "pointer",
                  transition: "border-color 0.2s, color 0.2s",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.borderColor = `${C.glow}55`;
                  e.currentTarget.style.color = C.text;
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = C.faint;
                  e.currentTarget.style.color = C.muted as string;
                }}
              >
                Try a different email
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ---- Forgot password inline ---- */}
        <AnimatePresence>
          {forgotMode && !forgotSent && (
            <motion.form
              key="forgot-form"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.3 }}
              onSubmit={handleForgotPassword}
              style={{ display: "flex", flexDirection: "column", gap: "1rem" }}
            >
              <p style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", color: C.muted, lineHeight: 1.6, marginBottom: "0.25rem" }}>
                Enter your email and we&apos;ll send you a link to reset your password.
              </p>
              <div>
                <label style={{ display: "block", fontFamily: "var(--font-dm), sans-serif", fontSize: "0.8rem", fontWeight: 500, color: C.text, marginBottom: "0.4rem", letterSpacing: "0.03em" }}>Email</label>
                <input type="email" required value={forgotEmail} onChange={(e) => setForgotEmail(e.target.value)} placeholder="you@example.com" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
              </div>
              <motion.button type="submit" disabled={loading} whileHover={loading ? {} : { scale: 1.02, boxShadow: `0 0 30px ${C.glow}33` }} whileTap={loading ? {} : { scale: 0.98 }} style={{ width: "100%", padding: "0.9rem", borderRadius: 12, border: "none", background: loading ? C.forest : `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: loading ? C.muted : C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.95rem", fontWeight: 600, cursor: loading ? "not-allowed" : "pointer", letterSpacing: "0.01em", boxShadow: `0 0 20px ${C.glow}15`, marginTop: "0.5rem", transition: "background 0.3s" }}>
                {loading ? "Sending..." : "Send Reset Link"}
              </motion.button>
              <button type="button" onClick={() => { setForgotMode(false); setError(""); }} style={{ background: "none", border: "none", fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", color: C.muted, cursor: "pointer", padding: "0.5rem 0", transition: "color 0.2s" }} onMouseEnter={(e) => (e.currentTarget.style.color = C.glow)} onMouseLeave={(e) => (e.currentTarget.style.color = "rgba(216,237,230,0.40)")}>
                Back to sign in
              </button>
            </motion.form>
          )}
          {forgotMode && forgotSent && (
            <motion.div key="forgot-sent" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.95 }} transition={{ duration: 0.3 }} style={{ textAlign: "center", padding: "2rem 1rem" }}>
              <div style={{ width: 56, height: 56, borderRadius: "50%", background: C.glowDim, border: `1px solid ${C.glow}33`, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 1.25rem" }}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={C.glow} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 2L11 13" /><path d="M22 2L15 22L11 13L2 9L22 2Z" /></svg>
              </div>
              <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.25rem", color: "#fff", marginBottom: "0.6rem" }}>Check your email</h3>
              <p style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.88rem", color: C.muted, lineHeight: 1.6, marginBottom: "1.5rem" }}>
                If an account exists for <span style={{ color: C.phosphor }}>{forgotEmail}</span>, we sent a password reset link.
              </p>
              <button type="button" onClick={() => { setForgotMode(false); setForgotSent(false); setForgotEmail(""); setError(""); }} style={{ padding: "0.5rem 1.2rem", borderRadius: 8, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.82rem", cursor: "pointer", transition: "border-color 0.2s, color 0.2s" }} onMouseEnter={(e) => { e.currentTarget.style.borderColor = `${C.glow}55`; e.currentTarget.style.color = C.text; }} onMouseLeave={(e) => { e.currentTarget.style.borderColor = C.faint; e.currentTarget.style.color = "rgba(216,237,230,0.40)"; }}>
                Back to sign in
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* ---- Forms ---- */}
        {!magicLinkSent && !forgotMode && (
          <AnimatePresence mode="wait">
            {mode === "password" ? (
              <motion.form
                key="password-form"
                initial={{ opacity: 0, x: -15 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 15 }}
                transition={{ duration: 0.25 }}
                onSubmit={handlePasswordLogin}
                style={{ display: "flex", flexDirection: "column", gap: "1rem" }}
              >
                {/* Email */}
                <div>
                  <label
                    style={{
                      display: "block",
                      fontFamily: "var(--font-dm), sans-serif",
                      fontSize: "0.8rem",
                      fontWeight: 500,
                      color: C.text,
                      marginBottom: "0.4rem",
                      letterSpacing: "0.03em",
                    }}
                  >
                    Email
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    style={inputStyle()}
                    onFocus={applyFocus}
                    onBlur={removeFocus}
                  />
                </div>

                {/* Password */}
                <div>
                  <label
                    style={{
                      display: "block",
                      fontFamily: "var(--font-dm), sans-serif",
                      fontSize: "0.8rem",
                      fontWeight: 500,
                      color: C.text,
                      marginBottom: "0.4rem",
                      letterSpacing: "0.03em",
                    }}
                  >
                    Password
                  </label>
                  <input
                    type="password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter your password"
                    style={inputStyle()}
                    onFocus={applyFocus}
                    onBlur={removeFocus}
                  />
                </div>

                {/* Forgot password link */}
                <div style={{ textAlign: "right", marginTop: "-0.4rem" }}>
                  <button
                    type="button"
                    onClick={() => { setForgotMode(true); setError(""); }}
                    style={{
                      background: "none",
                      border: "none",
                      fontFamily: "var(--font-dm), sans-serif",
                      fontSize: "0.78rem",
                      color: C.muted,
                      textDecoration: "none",
                      cursor: "pointer",
                      padding: 0,
                      transition: "color 0.2s",
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.color = C.glow)}
                    onMouseLeave={(e) => (e.currentTarget.style.color = "rgba(216,237,230,0.40)")}
                  >
                    Forgot password?
                  </button>
                </div>

                {/* Submit */}
                <motion.button
                  type="submit"
                  disabled={loading}
                  whileHover={loading ? {} : { scale: 1.02, boxShadow: `0 0 30px ${C.glow}33` }}
                  whileTap={loading ? {} : { scale: 0.98 }}
                  style={{
                    width: "100%",
                    padding: "0.9rem",
                    borderRadius: 12,
                    border: "none",
                    background: loading
                      ? `${C.forest}`
                      : `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
                    color: loading ? C.muted : C.bg,
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.95rem",
                    fontWeight: 600,
                    cursor: loading ? "not-allowed" : "pointer",
                    letterSpacing: "0.01em",
                    boxShadow: `0 0 20px ${C.glow}15`,
                    marginTop: "0.5rem",
                    transition: "background 0.3s",
                  }}
                >
                  {loading ? "Signing in..." : "Sign In"}
                </motion.button>
              </motion.form>
            ) : (
              <motion.form
                key="magic-link-form"
                initial={{ opacity: 0, x: 15 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -15 }}
                transition={{ duration: 0.25 }}
                onSubmit={handleMagicLink}
                style={{ display: "flex", flexDirection: "column", gap: "1rem" }}
              >
                <p
                  style={{
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.85rem",
                    color: C.muted,
                    lineHeight: 1.6,
                    marginBottom: "0.25rem",
                  }}
                >
                  Enter your email and we&apos;ll send you a link to sign in instantly — no password needed.
                </p>

                {/* Email */}
                <div>
                  <label
                    style={{
                      display: "block",
                      fontFamily: "var(--font-dm), sans-serif",
                      fontSize: "0.8rem",
                      fontWeight: 500,
                      color: C.text,
                      marginBottom: "0.4rem",
                      letterSpacing: "0.03em",
                    }}
                  >
                    Email
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    style={inputStyle()}
                    onFocus={applyFocus}
                    onBlur={removeFocus}
                  />
                </div>

                {/* Submit */}
                <motion.button
                  type="submit"
                  disabled={loading}
                  whileHover={loading ? {} : { scale: 1.02, boxShadow: `0 0 30px ${C.glow}33` }}
                  whileTap={loading ? {} : { scale: 0.98 }}
                  style={{
                    width: "100%",
                    padding: "0.9rem",
                    borderRadius: 12,
                    border: "none",
                    background: loading
                      ? `${C.forest}`
                      : `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
                    color: loading ? C.muted : C.bg,
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.95rem",
                    fontWeight: 600,
                    cursor: loading ? "not-allowed" : "pointer",
                    letterSpacing: "0.01em",
                    boxShadow: `0 0 20px ${C.glow}15`,
                    marginTop: "0.5rem",
                    transition: "background 0.3s",
                  }}
                >
                  {loading ? "Sending..." : "Send Magic Link"}
                </motion.button>
              </motion.form>
            )}
          </AnimatePresence>
        )}

        {/* ---- Divider ---- */}
        {!magicLinkSent && !forgotMode && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              margin: "1.75rem 0",
            }}
          >
            <div style={{ flex: 1, height: 1, background: C.faint }} />
            <span
              style={{
                fontFamily: "var(--font-dm), sans-serif",
                fontSize: "0.72rem",
                color: C.faint,
                letterSpacing: "0.1em",
                textTransform: "uppercase",
              }}
            >
              New here?
            </span>
            <div style={{ flex: 1, height: 1, background: C.faint }} />
          </motion.div>
        )}

        {/* ---- Register link ---- */}
        {!magicLinkSent && !forgotMode && (
          <motion.a
            href="/register"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.55 }}
            whileHover={{
              borderColor: `${C.glow}44`,
              boxShadow: `0 0 20px ${C.glow}10`,
            }}
            style={{
              display: "block",
              width: "100%",
              padding: "0.8rem",
              borderRadius: 12,
              border: `1px solid ${C.faint}`,
              background: "transparent",
              color: C.text,
              fontFamily: "var(--font-dm), sans-serif",
              fontSize: "0.9rem",
              fontWeight: 400,
              textAlign: "center",
              textDecoration: "none",
              cursor: "pointer",
              transition: "border-color 0.3s, box-shadow 0.3s",
            }}
          >
            Create an account
          </motion.a>
        )}
      </motion.div>

      {/* ---- Footer ---- */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1 }}
        style={{
          position: "relative",
          zIndex: 2,
          marginTop: "2rem",
          marginBottom: "2rem",
          fontFamily: "var(--font-dm), sans-serif",
          fontSize: "0.75rem",
          color: C.faint,
        }}
      >
        &copy; {new Date().getFullYear()} OneAgent
      </motion.p>
    </div>
  );
}
