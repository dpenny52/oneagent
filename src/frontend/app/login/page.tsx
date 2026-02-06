"use client";

import { motion, AnimatePresence } from "framer-motion";
import { Instrument_Serif, DM_Sans, Lora } from "next/font/google";
import { useEffect, useState, FormEvent } from "react";

/* ------------------------------------------------------------------ */
/*  Fonts                                                              */
/* ------------------------------------------------------------------ */
const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--font-instrument",
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
  variable: "--font-dm",
});

const lora = Lora({
  subsets: ["latin"],
  weight: ["400", "500"],
  style: ["normal", "italic"],
  variable: "--font-lora",
});

/* ------------------------------------------------------------------ */
/*  Palette                                                            */
/* ------------------------------------------------------------------ */
const C = {
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
};

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000";

/* ------------------------------------------------------------------ */
/*  Keyframe injection                                                 */
/* ------------------------------------------------------------------ */
function useKeyframes() {
  useEffect(() => {
    const id = "login-page-kf";
    if (document.getElementById(id)) return;
    const s = document.createElement("style");
    s.id = id;
    s.textContent = `
      @keyframes drift1 {
        0%, 100% { transform: translate(0, 0) scale(1); }
        25% { transform: translate(50px, -35px) scale(1.08); }
        50% { transform: translate(-25px, 45px) scale(0.95); }
        75% { transform: translate(35px, 20px) scale(1.04); }
      }
      @keyframes drift2 {
        0%, 100% { transform: translate(0, 0) scale(1); }
        25% { transform: translate(-40px, 40px) scale(1.06); }
        50% { transform: translate(30px, -25px) scale(0.93); }
        75% { transform: translate(-15px, -50px) scale(1.02); }
      }
      @keyframes drift3 {
        0%, 100% { transform: translate(0, 0) scale(1); }
        33% { transform: translate(55px, 15px) scale(1.1); }
        66% { transform: translate(-35px, -40px) scale(0.92); }
      }
      @keyframes sporeFloat {
        0%, 100% { transform: translateY(0) translateX(0); opacity: 0.15; }
        25% { transform: translateY(-20px) translateX(8px); opacity: 0.7; }
        50% { transform: translateY(-35px) translateX(-5px); opacity: 0.4; }
        75% { transform: translateY(-15px) translateX(12px); opacity: 0.8; }
      }
      @keyframes sporePulse {
        0%, 100% { box-shadow: 0 0 3px 1px rgba(0,212,170,0.2); }
        50% { box-shadow: 0 0 10px 3px rgba(0,212,170,0.5); }
      }
      @keyframes meshShift {
        0% { background-position: 0% 50%, 100% 50%, 50% 0%; }
        25% { background-position: 100% 0%, 0% 100%, 50% 50%; }
        50% { background-position: 50% 100%, 50% 0%, 0% 50%; }
        75% { background-position: 0% 0%, 100% 100%, 100% 50%; }
        100% { background-position: 0% 50%, 100% 50%, 50% 0%; }
      }
      @keyframes pulseGlow {
        0%, 100% { box-shadow: 0 0 20px rgba(0,212,170,0.08); }
        50% { box-shadow: 0 0 40px rgba(0,212,170,0.15); }
      }
    `;
    document.head.appendChild(s);
    return () => {
      const el = document.getElementById(id);
      if (el) el.remove();
    };
  }, []);
}

/* ------------------------------------------------------------------ */
/*  Spore particles                                                    */
/* ------------------------------------------------------------------ */
interface Spore {
  id: number;
  x: number;
  y: number;
  size: number;
  duration: number;
  delay: number;
  color: string;
}

function generateSpores(count: number): Spore[] {
  const colors = [C.glow, C.phosphor, C.lavender, C.glow, C.phosphor];
  return Array.from({ length: count }, (_, i) => ({
    id: i,
    x: Math.random() * 100,
    y: Math.random() * 100,
    size: Math.random() * 3 + 1,
    duration: Math.random() * 7 + 4,
    delay: Math.random() * 6,
    color: colors[i % colors.length],
  }));
}

/* ------------------------------------------------------------------ */
/*  Ambient orb                                                        */
/* ------------------------------------------------------------------ */
function Orb({
  size,
  color,
  top,
  left,
  animation,
  duration,
  opacity = 0.2,
}: {
  size: number;
  color: string;
  top: string;
  left: string;
  animation: string;
  duration: string;
  opacity?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: "50%",
        background: `radial-gradient(circle at 30% 30%, ${color}, transparent 70%)`,
        filter: `blur(${size * 0.4}px)`,
        opacity,
        top,
        left,
        animation: `${animation} ${duration} ease-in-out infinite`,
        pointerEvents: "none",
        willChange: "transform",
      }}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  Login mode type                                                    */
/* ------------------------------------------------------------------ */
type LoginMode = "password" | "magic-link";

/* ================================================================== */
/*  Main login page                                                    */
/* ================================================================== */
export default function LoginPage() {
  useKeyframes();
  const [spores, setSpores] = useState<Spore[]>([]);
  const [mode, setMode] = useState<LoginMode>("password");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [magicLinkSent, setMagicLinkSent] = useState(false);

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
        body: JSON.stringify({ token }),
      });
      const data = await res.json();
      if (res.ok && data.data?.token) {
        localStorage.setItem("auth_token", data.data.token);
        window.location.href = "/";
      } else {
        setError(data.error || "Invalid or expired magic link.");
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
        body: JSON.stringify({ user: { email, password } }),
      });
      const data = await res.json();
      if (res.ok && data.data?.token) {
        localStorage.setItem("auth_token", data.data.token);
        window.location.href = "/";
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

  /* ---- Shared input style ---- */
  const inputStyle: React.CSSProperties = {
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

  const inputFocusStyle = `border-color: ${C.glow}55; box-shadow: 0 0 0 3px ${C.glow}12;`;

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
      className={`${instrumentSerif.variable} ${dmSans.variable} ${lora.variable}`}
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
      <div
        style={{
          position: "fixed",
          inset: 0,
          pointerEvents: "none",
          zIndex: 1,
          overflow: "hidden",
        }}
      >
        {spores.map((sp) => (
          <div
            key={sp.id}
            style={{
              position: "absolute",
              left: `${sp.x}%`,
              top: `${sp.y}%`,
              width: sp.size,
              height: sp.size,
              borderRadius: "50%",
              backgroundColor: sp.color,
              animation: `sporeFloat ${sp.duration}s ease-in-out ${sp.delay}s infinite, sporePulse ${sp.duration * 0.6}s ease-in-out ${sp.delay}s infinite`,
            }}
          />
        ))}
      </div>

      {/* ========== Mesh gradient ========== */}
      <div
        style={{
          position: "fixed",
          inset: 0,
          zIndex: 0,
          opacity: 0.3,
          background: `
            radial-gradient(ellipse 55% 45% at 20% 50%, ${C.glowDim} 0%, transparent 70%),
            radial-gradient(ellipse 45% 55% at 80% 30%, ${C.lavenderDim} 0%, transparent 70%),
            radial-gradient(ellipse 35% 35% at 50% 80%, ${C.forestDim} 0%, transparent 70%)
          `,
          backgroundSize: "200% 200%, 200% 200%, 200% 200%",
          animation: "meshShift 22s ease-in-out infinite",
          pointerEvents: "none",
        }}
      />

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

        {/* ---- Forms ---- */}
        {!magicLinkSent && (
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
                    style={inputStyle}
                    onFocus={(e) => e.currentTarget.setAttribute("style", `${Object.entries(inputStyle).map(([k, v]) => `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`).join(";")}; ${inputFocusStyle}`)}
                    onBlur={(e) => {
                      Object.assign(e.currentTarget.style, inputStyle);
                    }}
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
                    style={inputStyle}
                    onFocus={(e) => e.currentTarget.setAttribute("style", `${Object.entries(inputStyle).map(([k, v]) => `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`).join(";")}; ${inputFocusStyle}`)}
                    onBlur={(e) => {
                      Object.assign(e.currentTarget.style, inputStyle);
                    }}
                  />
                </div>

                {/* Forgot password link */}
                <div style={{ textAlign: "right", marginTop: "-0.4rem" }}>
                  <a
                    href="/forgot-password"
                    style={{
                      fontFamily: "var(--font-dm), sans-serif",
                      fontSize: "0.78rem",
                      color: C.muted,
                      textDecoration: "none",
                      transition: "color 0.2s",
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.color = C.glow)}
                    onMouseLeave={(e) => (e.currentTarget.style.color = C.muted as string)}
                  >
                    Forgot password?
                  </a>
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
                    style={inputStyle}
                    onFocus={(e) => e.currentTarget.setAttribute("style", `${Object.entries(inputStyle).map(([k, v]) => `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`).join(";")}; ${inputFocusStyle}`)}
                    onBlur={(e) => {
                      Object.assign(e.currentTarget.style, inputStyle);
                    }}
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
        {!magicLinkSent && (
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
        {!magicLinkSent && (
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
