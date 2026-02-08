"use client";

import { motion, AnimatePresence } from "framer-motion";
import { Instrument_Serif, DM_Sans, Lora } from "next/font/google";
import { useEffect, useState, FormEvent } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api";
import { C, inputStyle, inputFocusCSS, buttonStyle, labelStyle } from "../lib/theme";

const instrumentSerif = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal", "italic"], variable: "--font-instrument" });
const dmSans = DM_Sans({ subsets: ["latin"], weight: ["300", "400", "500", "600"], variable: "--font-dm" });
const lora = Lora({ subsets: ["latin"], weight: ["400", "500"], style: ["normal", "italic"], variable: "--font-lora" });

function useKeyframes() {
  useEffect(() => {
    const id = "register-page-kf";
    if (document.getElementById(id)) return;
    const s = document.createElement("style");
    s.id = id;
    s.textContent = `
      @keyframes drift1 { 0%,100%{transform:translate(0,0) scale(1)} 25%{transform:translate(50px,-35px) scale(1.08)} 50%{transform:translate(-25px,45px) scale(0.95)} 75%{transform:translate(35px,20px) scale(1.04)} }
      @keyframes drift2 { 0%,100%{transform:translate(0,0) scale(1)} 25%{transform:translate(-40px,40px) scale(1.06)} 50%{transform:translate(30px,-25px) scale(0.93)} 75%{transform:translate(-15px,-50px) scale(1.02)} }
      @keyframes drift3 { 0%,100%{transform:translate(0,0) scale(1)} 33%{transform:translate(55px,15px) scale(1.1)} 66%{transform:translate(-35px,-40px) scale(0.92)} }
      @keyframes sporeFloat { 0%,100%{transform:translateY(0) translateX(0);opacity:.15} 25%{transform:translateY(-20px) translateX(8px);opacity:.7} 50%{transform:translateY(-35px) translateX(-5px);opacity:.4} 75%{transform:translateY(-15px) translateX(12px);opacity:.8} }
      @keyframes sporePulse { 0%,100%{box-shadow:0 0 3px 1px rgba(0,212,170,0.2)} 50%{box-shadow:0 0 10px 3px rgba(0,212,170,0.5)} }
      @keyframes meshShift { 0%{background-position:0% 50%,100% 50%,50% 0%} 25%{background-position:100% 0%,0% 100%,50% 50%} 50%{background-position:50% 100%,50% 0%,0% 50%} 75%{background-position:0% 0%,100% 100%,100% 50%} 100%{background-position:0% 50%,100% 50%,50% 0%} }
      @keyframes pulseGlow { 0%,100%{box-shadow:0 0 20px rgba(0,212,170,0.08)} 50%{box-shadow:0 0 40px rgba(0,212,170,0.15)} }
    `;
    document.head.appendChild(s);
    return () => { const el = document.getElementById(id); if (el) el.remove(); };
  }, []);
}

interface Spore { id: number; x: number; y: number; size: number; duration: number; delay: number; color: string; }

function generateSpores(count: number): Spore[] {
  const colors = [C.glow, C.phosphor, C.lavender, C.glow, C.phosphor];
  return Array.from({ length: count }, (_, i) => ({
    id: i, x: Math.random() * 100, y: Math.random() * 100, size: Math.random() * 3 + 1,
    duration: Math.random() * 7 + 4, delay: Math.random() * 6, color: colors[i % colors.length],
  }));
}

function Orb({ size, color, top, left, animation, duration, opacity = 0.2 }: { size: number; color: string; top: string; left: string; animation: string; duration: string; opacity?: number }) {
  return (
    <div style={{ position: "absolute", width: size, height: size, borderRadius: "50%", background: `radial-gradient(circle at 30% 30%, ${color}, transparent 70%)`, filter: `blur(${size * 0.4}px)`, opacity, top, left, animation: `${animation} ${duration} ease-in-out infinite`, pointerEvents: "none", willChange: "transform" }} />
  );
}

function applyFocus(e: React.FocusEvent<HTMLInputElement>) {
  const base = inputStyle();
  const cssStr = Object.entries(base).map(([k, v]) => `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`).join(";");
  e.currentTarget.setAttribute("style", `${cssStr}; ${inputFocusCSS}`);
}
function removeFocus(e: React.FocusEvent<HTMLInputElement>) {
  Object.assign(e.currentTarget.style, inputStyle());
}

export default function RegisterPage() {
  useKeyframes();
  const { login } = useAuth();
  const [spores, setSpores] = useState<Spore[]>([]);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => { setSpores(generateSpores(30)); }, []);

  async function handleRegister(e: FormEvent) {
    e.preventDefault();
    if (password !== confirmPassword) { setError("Passwords do not match."); return; }
    if (password.length < 12) { setError("Password must be at least 12 characters."); return; }
    setLoading(true);
    setError("");
    const res = await api.post<{ user: { id: string; email: string } }>("/api/auth/register", { user: { email, password } });
    setLoading(false);
    if (res.ok) {
      login();
      window.location.href = "/dashboard";
    } else {
      if (res.status === 403) {
        setError("Registration is currently invite-only. Please contact the administrator.");
      } else {
        setError(res.error);
      }
    }
  }

  return (
    <div className={`${instrumentSerif.variable} ${dmSans.variable} ${lora.variable}`} style={{ minHeight: "100vh", background: C.bg, color: C.text, fontFamily: "var(--font-dm), sans-serif", overflowX: "hidden", position: "relative", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
      <Orb size={400} color={C.glow} top="-10%" left="-8%" animation="drift1" duration="20s" opacity={0.12} />
      <Orb size={300} color={C.lavender} top="15%" left="70%" animation="drift2" duration="24s" opacity={0.1} />
      <Orb size={250} color={C.phosphor} top="60%" left="-5%" animation="drift3" duration="26s" opacity={0.08} />
      <Orb size={350} color={C.forest} top="70%" left="65%" animation="drift1" duration="22s" opacity={0.12} />

      {/* Floating spores */}
      <div style={{ position: "fixed", inset: 0, pointerEvents: "none", zIndex: 1, overflow: "hidden" }}>
        {spores.map((sp) => (
          <div key={sp.id} style={{ position: "absolute", left: `${sp.x}%`, top: `${sp.y}%`, width: sp.size, height: sp.size, borderRadius: "50%", backgroundColor: sp.color, animation: `sporeFloat ${sp.duration}s ease-in-out ${sp.delay}s infinite, sporePulse ${sp.duration * 0.6}s ease-in-out ${sp.delay}s infinite` }} />
        ))}
      </div>

      {/* Mesh gradient */}
      <div style={{ position: "fixed", inset: 0, zIndex: 0, opacity: 0.3, background: `radial-gradient(ellipse 55% 45% at 20% 50%, ${C.glowDim} 0%, transparent 70%), radial-gradient(ellipse 45% 55% at 80% 30%, ${C.lavenderDim} 0%, transparent 70%), radial-gradient(ellipse 35% 35% at 50% 80%, ${C.forestDim} 0%, transparent 70%)`, backgroundSize: "200% 200%, 200% 200%, 200% 200%", animation: "meshShift 22s ease-in-out infinite", pointerEvents: "none" }} />

      {/* Register card */}
      <motion.div initial={{ opacity: 0, y: 30, scale: 0.97 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={{ duration: 0.8, ease: "easeOut" }} style={{ position: "relative", zIndex: 2, width: "100%", maxWidth: 420, padding: "2.5rem 2rem", margin: "2rem 1.5rem", borderRadius: 24, background: "rgba(255,255,255,0.025)", backdropFilter: "blur(30px)", WebkitBackdropFilter: "blur(30px)", border: `1px solid ${C.glow}15`, boxShadow: `0 0 60px ${C.glow}06, inset 0 1px 0 ${C.glow}08`, animation: "pulseGlow 4s ease-in-out infinite" }}>
        {/* Back */}
        <motion.a href="/" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }} style={{ display: "inline-flex", alignItems: "center", gap: "0.35rem", fontFamily: "var(--font-dm), sans-serif", fontSize: "0.78rem", color: C.muted, textDecoration: "none", marginBottom: "1.5rem", transition: "color 0.2s" }} onMouseEnter={(e) => (e.currentTarget.style.color = C.glow)} onMouseLeave={(e) => (e.currentTarget.style.color = "rgba(216,237,230,0.40)")}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5M12 19l-7-7 7-7" /></svg>
          Back
        </motion.a>

        <motion.h1 initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.15 }} style={{ fontFamily: "var(--font-instrument), serif", fontSize: "2rem", fontWeight: 400, color: "#fff", marginBottom: "0.4rem", textShadow: `0 0 30px ${C.glow}20`, letterSpacing: "-0.01em" }}>
          Create account
        </motion.h1>
        <motion.p initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.25 }} style={{ fontFamily: "var(--font-lora), serif", fontSize: "0.92rem", fontStyle: "italic", color: C.muted, marginBottom: "2rem" }}>
          Start building your agents
        </motion.p>

        {/* Error */}
        <AnimatePresence>
          {error && (
            <motion.div initial={{ opacity: 0, height: 0, marginBottom: 0 }} animate={{ opacity: 1, height: "auto", marginBottom: 16 }} exit={{ opacity: 0, height: 0, marginBottom: 0 }} transition={{ duration: 0.25 }} style={{ padding: "0.7rem 1rem", borderRadius: 10, background: "rgba(255,107,107,0.08)", border: "1px solid rgba(255,107,107,0.2)", fontSize: "0.85rem", color: C.danger, fontFamily: "var(--font-dm), sans-serif", overflow: "hidden" }}>
              {error}
            </motion.div>
          )}
        </AnimatePresence>

        {/* Form */}
        <motion.form initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.35 }} onSubmit={handleRegister} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
          <div>
            <label style={labelStyle()}>Email</label>
            <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
          </div>
          <div>
            <label style={labelStyle()}>Password</label>
            <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="At least 12 characters" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
          </div>
          <div>
            <label style={labelStyle()}>Confirm Password</label>
            <input type="password" required value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} placeholder="Repeat your password" style={inputStyle()} onFocus={applyFocus} onBlur={removeFocus} />
          </div>
          <motion.button type="submit" disabled={loading} whileHover={loading ? {} : { scale: 1.02, boxShadow: `0 0 30px ${C.glow}33` }} whileTap={loading ? {} : { scale: 0.98 }} style={{ ...buttonStyle(loading), marginTop: "0.5rem" }}>
            {loading ? "Creating account..." : "Create Account"}
          </motion.button>
        </motion.form>

        {/* Divider */}
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }} style={{ display: "flex", alignItems: "center", gap: 12, margin: "1.75rem 0" }}>
          <div style={{ flex: 1, height: 1, background: C.faint }} />
          <span style={{ fontFamily: "var(--font-dm), sans-serif", fontSize: "0.72rem", color: C.faint, letterSpacing: "0.1em", textTransform: "uppercase" }}>Already have an account?</span>
          <div style={{ flex: 1, height: 1, background: C.faint }} />
        </motion.div>

        {/* Login link */}
        <motion.a href="/login" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.55 }} whileHover={{ borderColor: `${C.glow}44`, boxShadow: `0 0 20px ${C.glow}10` }} style={{ display: "block", width: "100%", padding: "0.8rem", borderRadius: 12, border: `1px solid ${C.faint}`, background: "transparent", color: C.text, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.9rem", fontWeight: 400, textAlign: "center", textDecoration: "none", cursor: "pointer", transition: "border-color 0.3s, box-shadow 0.3s" }}>
          Sign in instead
        </motion.a>
      </motion.div>

      <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 1 }} style={{ position: "relative", zIndex: 2, marginTop: "2rem", marginBottom: "2rem", fontFamily: "var(--font-dm), sans-serif", fontSize: "0.75rem", color: C.faint }}>
        &copy; {new Date().getFullYear()} OneAgent
      </motion.p>
    </div>
  );
}
