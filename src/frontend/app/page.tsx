"use client";

import { motion } from "framer-motion";
import { Instrument_Serif, DM_Sans, Lora } from "next/font/google";
import { useEffect, useState } from "react";
import { useAuth } from "./lib/auth";

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
  pink: "#FF3D8E",
  pinkDim: "rgba(255,61,142,0.08)",
  phosphor: "#7FE5C0",
  text: "#D8EDE6",
  muted: "rgba(216,237,230,0.40)",
  faint: "rgba(216,237,230,0.18)",
};

/* ------------------------------------------------------------------ */
/*  Keyframe injection                                                 */
/* ------------------------------------------------------------------ */
function useKeyframes() {
  useEffect(() => {
    const id = "bioluminescent-garden-kf";
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
      @keyframes scrollLine {
        0%, 100% { transform: translateY(0); opacity: 0.6; }
        50% { transform: translateY(8px); opacity: 0.2; }
      }
      @keyframes vineGrow {
        from { stroke-dashoffset: 800; }
        to { stroke-dashoffset: 0; }
      }
      @keyframes nodeGlow {
        0%, 100% { opacity: 0.5; filter: drop-shadow(0 0 4px rgba(0,212,170,0.3)); }
        50% { opacity: 1; filter: drop-shadow(0 0 10px rgba(0,212,170,0.6)); }
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
/*  Spore particle data                                                */
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
/*  Bioluminescent vine SVG                                            */
/* ------------------------------------------------------------------ */
function GlowingVine({
  d,
  color = C.forest,
  glowColor = C.glow,
  width = "100%",
  height = "100%",
  viewBox = "0 0 800 600",
  opacity = 0.3,
}: {
  d: string;
  color?: string;
  glowColor?: string;
  width?: string;
  height?: string;
  viewBox?: string;
  opacity?: number;
}) {
  return (
    <svg
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width,
        height,
        pointerEvents: "none",
        overflow: "visible",
      }}
      viewBox={viewBox}
      fill="none"
      preserveAspectRatio="none"
    >
      <path
        d={d}
        stroke={glowColor}
        strokeWidth="2"
        strokeOpacity={0.08}
        fill="none"
        style={{ filter: `blur(8px)` }}
      />
      <path
        d={d}
        stroke={color}
        strokeWidth="1.5"
        strokeOpacity={opacity}
        fill="none"
      />
    </svg>
  );
}

/* ------------------------------------------------------------------ */
/*  Leaf ornament divider                                              */
/* ------------------------------------------------------------------ */
function LeafDivider({ color = C.glow }: { color?: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, scaleX: 0 }}
      whileInView={{ opacity: 1, scaleX: 1 }}
      viewport={{ once: true, amount: 0.5 }}
      transition={{ duration: 1, ease: "easeOut" }}
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 16,
        padding: "40px 0",
        transformOrigin: "center",
      }}
    >
      <div
        style={{
          flex: 1,
          maxWidth: 160,
          height: 1,
          background: `linear-gradient(90deg, transparent, ${color}44)`,
        }}
      />
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M12 2C10 2 8 5 8 9C8 13 10 18 12 21C14 18 16 13 16 9C16 5 14 2 12 2Z"
          fill={color}
          fillOpacity={0.3}
          stroke={color}
          strokeWidth="0.8"
          strokeOpacity={0.5}
        />
      </svg>
      <div
        style={{
          flex: 1,
          maxWidth: 160,
          height: 1,
          background: `linear-gradient(90deg, ${color}44, transparent)`,
        }}
      />
    </motion.div>
  );
}

/* ------------------------------------------------------------------ */
/*  Feature card                                                       */
/* ------------------------------------------------------------------ */
function FeatureCard({
  icon,
  title,
  description,
  glowColor,
  delay,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  glowColor: string;
  delay: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{ duration: 0.7, delay, ease: "easeOut" }}
      whileHover={{
        y: -4,
        boxShadow: `0 8px 40px ${glowColor}15, 0 0 60px ${glowColor}08`,
      }}
      style={{
        flex: "1 1 300px",
        maxWidth: 380,
        padding: "2.5rem 2rem",
        borderRadius: 24,
        background: "rgba(255,255,255,0.02)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        border: `1px solid ${glowColor}18`,
        boxShadow: `0 0 30px ${glowColor}05, inset 0 0 30px ${glowColor}02`,
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Glow accent */}
      <div
        style={{
          position: "absolute",
          top: -30,
          left: -30,
          width: 100,
          height: 100,
          borderRadius: "50%",
          background: `radial-gradient(circle, ${glowColor}12, transparent 70%)`,
          filter: "blur(25px)",
          pointerEvents: "none",
        }}
      />
      <div style={{ marginBottom: "1rem", position: "relative" }}>{icon}</div>
      <h3
        style={{
          fontFamily: "var(--font-instrument), serif",
          fontSize: "1.3rem",
          fontWeight: 400,
          color: "#fff",
          marginBottom: "0.75rem",
          letterSpacing: "-0.01em",
        }}
      >
        {title}
      </h3>
      <p
        style={{
          fontFamily: "var(--font-dm), sans-serif",
          fontSize: "0.92rem",
          lineHeight: 1.7,
          color: C.muted,
          fontWeight: 300,
        }}
      >
        {description}
      </p>
    </motion.div>
  );
}

/* ------------------------------------------------------------------ */
/*  Step card for "How it works"                                       */
/* ------------------------------------------------------------------ */
function StepCard({
  number,
  title,
  description,
  delay,
}: {
  number: string;
  title: string;
  description: string;
  delay: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{ duration: 0.7, delay, ease: "easeOut" }}
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: "1.5rem",
        padding: "2rem 0",
        borderBottom: `1px solid ${C.forestDim}`,
      }}
    >
      <div
        style={{
          fontFamily: "var(--font-instrument), serif",
          fontSize: "2.5rem",
          color: C.glow,
          opacity: 0.5,
          lineHeight: 1,
          minWidth: 60,
          textAlign: "center",
          textShadow: `0 0 20px ${C.glow}33`,
        }}
      >
        {number}
      </div>
      <div>
        <h3
          style={{
            fontFamily: "var(--font-instrument), serif",
            fontSize: "1.25rem",
            fontWeight: 400,
            color: "#fff",
            marginBottom: "0.5rem",
          }}
        >
          {title}
        </h3>
        <p
          style={{
            fontFamily: "var(--font-dm), sans-serif",
            fontSize: "0.95rem",
            lineHeight: 1.7,
            color: C.muted,
            fontWeight: 300,
          }}
        >
          {description}
        </p>
      </div>
    </motion.div>
  );
}

/* ================================================================== */
/*  Main page                                                          */
/* ================================================================== */
export default function BioluminescentGardenPage() {
  useKeyframes();
  const { user, loading: authLoading, logout } = useAuth();
  const [spores, setSpores] = useState<Spore[]>([]);

  useEffect(() => {
    setSpores(generateSpores(45));
  }, []);

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
      }}
    >
      {/* ========== Fixed nav bar ========== */}
      <motion.nav
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.1 }}
        style={{
          position: "fixed",
          top: 0,
          left: 0,
          right: 0,
          zIndex: 50,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "1rem 2rem",
          background: "rgba(6,14,18,0.6)",
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          borderBottom: `1px solid ${C.glow}10`,
        }}
      >
        <a
          href="/"
          style={{
            fontFamily: "var(--font-instrument), serif",
            fontSize: "1.35rem",
            color: "#fff",
            textDecoration: "none",
            textShadow: `0 0 20px ${C.glow}30`,
          }}
        >
          OneAgent
        </a>
        <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
          {!authLoading && (
            user ? (
              <>
                <a
                  href="/dashboard"
                  style={{
                    padding: "0.5rem 1.2rem",
                    borderRadius: 10,
                    background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
                    color: C.bg,
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.85rem",
                    fontWeight: 600,
                    textDecoration: "none",
                    transition: "box-shadow 0.2s",
                  }}
                >
                  Dashboard
                </a>
                <button
                  onClick={() => logout()}
                  style={{
                    padding: "0.5rem 1rem",
                    borderRadius: 10,
                    border: `1px solid ${C.faint}`,
                    background: "transparent",
                    color: C.muted,
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.85rem",
                    cursor: "pointer",
                    transition: "border-color 0.2s, color 0.2s",
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderColor = `${C.glow}55`;
                    e.currentTarget.style.color = C.text;
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderColor = C.faint;
                    e.currentTarget.style.color = "rgba(216,237,230,0.40)";
                  }}
                >
                  Logout
                </button>
              </>
            ) : (
              <>
                <a
                  href="/login"
                  style={{
                    padding: "0.5rem 1rem",
                    borderRadius: 10,
                    border: `1px solid ${C.faint}`,
                    background: "transparent",
                    color: C.text,
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.85rem",
                    textDecoration: "none",
                    transition: "border-color 0.2s",
                  }}
                >
                  Login
                </a>
                <a
                  href="/register"
                  style={{
                    padding: "0.5rem 1.2rem",
                    borderRadius: 10,
                    background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
                    color: C.bg,
                    fontFamily: "var(--font-dm), sans-serif",
                    fontSize: "0.85rem",
                    fontWeight: 600,
                    textDecoration: "none",
                  }}
                >
                  Register
                </a>
              </>
            )
          )}
        </div>
      </motion.nav>

      {/* ========== Ambient orbs ========== */}
      <Orb size={450} color={C.glow} top="-8%" left="-6%" animation="drift1" duration="20s" opacity={0.14} />
      <Orb size={320} color={C.lavender} top="12%" left="68%" animation="drift2" duration="24s" opacity={0.12} />
      <Orb size={260} color={C.phosphor} top="50%" left="-4%" animation="drift3" duration="26s" opacity={0.1} />
      <Orb size={380} color={C.forest} top="65%" left="60%" animation="drift1" duration="22s" opacity={0.15} />
      <Orb size={200} color={C.glow} top="35%" left="42%" animation="drift2" duration="30s" opacity={0.08} />
      <Orb size={280} color={C.lavender} top="85%" left="15%" animation="drift3" duration="25s" opacity={0.1} />

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

      {/* ========== Background vines ========== */}
      <GlowingVine
        d="M40 0 Q30 100, 45 200 Q55 300, 35 400 Q25 500, 45 600"
        opacity={0.2}
      />
      <GlowingVine
        d="M760 0 Q770 120, 755 240 Q745 360, 765 480 Q775 560, 758 600"
        glowColor={C.lavender}
        opacity={0.15}
      />

      {/* ========== Mesh gradient ========== */}
      <div
        style={{
          position: "fixed",
          inset: 0,
          zIndex: 0,
          opacity: 0.35,
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

      {/* ========== HERO ========== */}
      <section
        style={{
          position: "relative",
          minHeight: "100vh",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          textAlign: "center",
          padding: "6rem 1.5rem 4rem",
          zIndex: 2,
        }}
      >
        {/* Badge */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: "0.5rem",
            padding: "0.4rem 1.1rem",
            borderRadius: 100,
            background: `${C.glowDim}`,
            border: `1px solid ${C.glow}33`,
            marginBottom: "2.5rem",
            fontSize: "0.78rem",
            fontWeight: 500,
            color: C.glow,
            letterSpacing: "0.04em",
            fontFamily: "var(--font-dm)",
          }}
        >
          <span
            style={{
              width: 6,
              height: 6,
              borderRadius: "50%",
              background: C.glow,
              boxShadow: `0 0 8px ${C.glow}`,
              display: "inline-block",
            }}
          />
          Personal AI Agents
        </motion.div>

        {/* Title */}
        <motion.h1
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1, delay: 0.4 }}
          style={{
            fontFamily: "var(--font-instrument), serif",
            fontSize: "clamp(3.2rem, 9vw, 7.5rem)",
            fontWeight: 400,
            color: "#fff",
            lineHeight: 1.05,
            marginBottom: "1.5rem",
            textShadow: `0 0 50px ${C.glow}30, 0 0 100px ${C.glow}10`,
            letterSpacing: "-0.02em",
          }}
        >
          OneAgent
        </motion.h1>

        {/* Tagline */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.7 }}
          style={{
            fontFamily: "var(--font-lora), serif",
            fontSize: "clamp(1.1rem, 2.4vw, 1.55rem)",
            fontWeight: 400,
            fontStyle: "italic",
            color: "rgba(255,255,255,0.6)",
            maxWidth: 520,
            lineHeight: 1.5,
            marginBottom: "1.2rem",
          }}
        >
          Stand up a persistent personal agent with one click.
        </motion.p>

        {/* Subtext */}
        <motion.p
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.9 }}
          style={{
            fontFamily: "var(--font-dm)",
            fontSize: "1rem",
            fontWeight: 300,
            color: C.muted,
            maxWidth: 460,
            lineHeight: 1.65,
            marginBottom: "3rem",
          }}
        >
          Your agent lives in the cloud. It stays running, remembers your
          context, and works on your behalf — even when you&apos;re not there.
        </motion.p>

        {/* CTA */}
        <motion.a
          href={user ? "/dashboard" : "/login"}
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, delay: 1.1, ease: "easeOut" }}
          whileHover={{
            scale: 1.04,
            boxShadow: `0 0 36px ${C.glow}44, 0 0 72px ${C.glow}18`,
          }}
          whileTap={{ scale: 0.97 }}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: "0.6rem",
            padding: "1rem 2.2rem",
            borderRadius: 14,
            background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
            color: C.bg,
            fontFamily: "var(--font-dm)",
            fontSize: "1rem",
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

        {/* Scroll indicator */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 2, duration: 1 }}
          style={{
            position: "absolute",
            bottom: "2.5rem",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: "0.4rem",
          }}
        >
          <span
            style={{
              fontSize: "0.7rem",
              fontFamily: "var(--font-lora)",
              color: C.faint,
              letterSpacing: "0.15em",
              textTransform: "uppercase",
            }}
          >
            Scroll
          </span>
          <div
            style={{
              width: 1,
              height: 26,
              background: `linear-gradient(to bottom, ${C.glow}55, transparent)`,
              borderRadius: 2,
              animation: "scrollLine 2s ease-in-out infinite",
            }}
          />
        </motion.div>
      </section>

      {/* ========== DIVIDER ========== */}
      <LeafDivider color={C.glow} />

      {/* ========== WHAT IS ONEAGENT ========== */}
      <section
        style={{
          position: "relative",
          zIndex: 2,
          padding: "2rem 1.5rem 5rem",
          maxWidth: 700,
          margin: "0 auto",
          textAlign: "center",
        }}
      >
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.8 }}
        >
          <span
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "0.75rem",
              fontWeight: 500,
              color: C.lavender,
              letterSpacing: "0.18em",
              textTransform: "uppercase",
              display: "block",
              marginBottom: "1rem",
            }}
          >
            What is OneAgent
          </span>
          <h2
            style={{
              fontFamily: "var(--font-instrument), serif",
              fontSize: "clamp(1.8rem, 4.5vw, 2.8rem)",
              fontWeight: 400,
              color: "#fff",
              lineHeight: 1.2,
              marginBottom: "1.5rem",
            }}
          >
            An AI agent that actually{" "}
            <span style={{ color: C.glow, fontStyle: "italic" }}>stays on</span>
          </h2>
          <p
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "1.05rem",
              fontWeight: 300,
              color: C.muted,
              lineHeight: 1.75,
              marginBottom: "1.5rem",
            }}
          >
            Most AI interactions are ephemeral — you chat, you close the tab,
            and the context is gone. OneAgent is different. It deploys a
            persistent agent to the cloud that keeps running after you walk
            away. It retains your conversation history, holds onto the tasks
            you&apos;ve given it, and continues working autonomously.
          </p>
          <p
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "1.05rem",
              fontWeight: 300,
              color: C.muted,
              lineHeight: 1.75,
            }}
          >
            Think of it as your own personal AI that lives somewhere,
            persistently, and is always ready when you come back.
          </p>
        </motion.div>
      </section>

      {/* ========== DIVIDER ========== */}
      <LeafDivider color={C.phosphor} />

      {/* ========== CAPABILITIES ========== */}
      <section
        style={{
          position: "relative",
          zIndex: 2,
          padding: "2rem 1.5rem 5rem",
          maxWidth: 1200,
          margin: "0 auto",
        }}
      >
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.7 }}
          style={{ textAlign: "center", marginBottom: "3.5rem" }}
        >
          <span
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "0.75rem",
              fontWeight: 500,
              color: C.phosphor,
              letterSpacing: "0.18em",
              textTransform: "uppercase",
              display: "block",
              marginBottom: "1rem",
            }}
          >
            Capabilities
          </span>
          <h2
            style={{
              fontFamily: "var(--font-instrument), serif",
              fontSize: "clamp(1.8rem, 4.5vw, 2.8rem)",
              fontWeight: 400,
              color: "#fff",
              lineHeight: 1.2,
            }}
          >
            What your agent can do
          </h2>
        </motion.div>

        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            gap: "1.5rem",
            justifyContent: "center",
          }}
        >
          <FeatureCard
            icon={
              <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                <circle cx="20" cy="20" r="14" stroke={C.glow} strokeWidth="1.5" strokeOpacity={0.4} />
                <circle cx="20" cy="20" r="6" fill={C.glow} fillOpacity={0.15} />
                <circle cx="20" cy="20" r="2.5" fill={C.glow} fillOpacity={0.6} />
                <path d="M20 6V10M20 30V34M6 20H10M30 20H34" stroke={C.glow} strokeWidth="1" strokeOpacity={0.3} />
              </svg>
            }
            title="One-click deploy"
            description="Describe what you want your agent to do, hit deploy, and it's live in the cloud. No infrastructure to set up, no containers to manage. It just works."
            glowColor={C.glow}
            delay={0}
          />
          <FeatureCard
            icon={
              <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                <path d="M20 8C15 8 10 12 10 18C10 24 15 32 20 36C25 32 30 24 30 18C30 12 25 8 20 8Z" fill={C.lavender} fillOpacity={0.12} stroke={C.lavender} strokeWidth="1.2" strokeOpacity={0.5} />
                <path d="M20 24C17 22 14 20 14 18" stroke={C.lavender} strokeWidth="0.8" strokeOpacity={0.5} fill="none" />
                <path d="M20 24C23 22 26 20 26 18" stroke={C.lavender} strokeWidth="0.8" strokeOpacity={0.5} fill="none" />
                <circle cx="20" cy="14" r="3" fill={C.lavender} fillOpacity={0.3} />
              </svg>
            }
            title="Persistent memory"
            description="Your agent remembers everything across sessions. It builds context over time so you don't have to repeat yourself. Pick up right where you left off."
            glowColor={C.lavender}
            delay={0.15}
          />
          <FeatureCard
            icon={
              <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
                <circle cx="20" cy="20" r="13" stroke={C.phosphor} strokeWidth="1.2" strokeOpacity={0.4} fill="none" />
                <circle cx="20" cy="20" r="8" stroke={C.phosphor} strokeWidth="0.8" strokeOpacity={0.25} fill="none" />
                <circle cx="20" cy="20" r="3" fill={C.phosphor} fillOpacity={0.2} />
                <circle cx="20" cy="20" r="1.5" fill={C.phosphor} fillOpacity={0.5} />
                <path d="M20 7V4M20 36V33M7 20H4M36 20H33" stroke={C.phosphor} strokeWidth="0.8" strokeOpacity={0.25} />
              </svg>
            }
            title="Always running"
            description="Your agent doesn't shut down when you close your browser. It stays alive in the cloud, running continuously, so it can monitor, respond, and act on your behalf around the clock."
            glowColor={C.phosphor}
            delay={0.3}
          />
        </div>
      </section>

      {/* ========== DIVIDER ========== */}
      <LeafDivider color={C.lavender} />

      {/* ========== HOW IT WORKS ========== */}
      <section
        style={{
          position: "relative",
          zIndex: 2,
          padding: "2rem 1.5rem 5rem",
          maxWidth: 680,
          margin: "0 auto",
        }}
      >
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.7 }}
          style={{ textAlign: "center", marginBottom: "2.5rem" }}
        >
          <span
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "0.75rem",
              fontWeight: 500,
              color: C.glow,
              letterSpacing: "0.18em",
              textTransform: "uppercase",
              display: "block",
              marginBottom: "1rem",
            }}
          >
            How it works
          </span>
          <h2
            style={{
              fontFamily: "var(--font-instrument), serif",
              fontSize: "clamp(1.8rem, 4.5vw, 2.8rem)",
              fontWeight: 400,
              color: "#fff",
              lineHeight: 1.2,
            }}
          >
            Three steps. That&apos;s it.
          </h2>
        </motion.div>

        <StepCard
          number="01"
          title="Describe your agent"
          description="Tell us what you want your agent to do. Give it a role, a set of instructions, or just a plain-English description of the tasks it should handle."
          delay={0}
        />
        <StepCard
          number="02"
          title="Click deploy"
          description="One button. Your agent is provisioned in the cloud and starts running immediately. No setup, no configuration, no waiting."
          delay={0.15}
        />
        <StepCard
          number="03"
          title="It lives"
          description="Your agent is now persistent. It stays running, retains context between conversations, and works autonomously. Come back anytime — it'll be there."
          delay={0.3}
        />
      </section>

      {/* ========== DIVIDER ========== */}
      <LeafDivider color={C.phosphor} />

      {/* ========== WHY PERSISTENT ========== */}
      <section
        style={{
          position: "relative",
          zIndex: 2,
          padding: "2rem 1.5rem 5rem",
          maxWidth: 700,
          margin: "0 auto",
          textAlign: "center",
        }}
      >
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.8 }}
        >
          <h2
            style={{
              fontFamily: "var(--font-instrument), serif",
              fontSize: "clamp(1.8rem, 4.5vw, 2.6rem)",
              fontWeight: 400,
              color: "#fff",
              lineHeight: 1.3,
              marginBottom: "1.5rem",
            }}
          >
            AI that doesn&apos;t{" "}
            <span style={{ color: C.lavender, fontStyle: "italic" }}>
              disappear
            </span>{" "}
            when you close the tab
          </h2>
          <p
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "1.05rem",
              fontWeight: 300,
              color: C.muted,
              lineHeight: 1.75,
              marginBottom: "1.2rem",
            }}
          >
            Every conversation you&apos;ve had with an AI chatbot vanishes the
            moment the session ends. The context resets. The work it was doing
            stops. You start over every time.
          </p>
          <p
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "1.05rem",
              fontWeight: 300,
              color: C.muted,
              lineHeight: 1.75,
            }}
          >
            OneAgent changes that. Your agent persists. It keeps your context,
            holds your tasks, and stays running in the background. It&apos;s
            your own AI — always there, always ready.
          </p>
        </motion.div>
      </section>

      {/* ========== FINAL CTA ========== */}
      <section
        style={{
          position: "relative",
          zIndex: 2,
          padding: "5rem 1.5rem 7rem",
          textAlign: "center",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: "50%",
            left: "50%",
            transform: "translate(-50%, -50%)",
            width: 500,
            height: 500,
            borderRadius: "50%",
            background: `radial-gradient(circle, ${C.glow}08, transparent 70%)`,
            filter: "blur(50px)",
            pointerEvents: "none",
          }}
        />

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.8 }}
        >
          {/* Small leaf ornament */}
          <svg
            width="32"
            height="32"
            viewBox="0 0 24 24"
            fill="none"
            style={{ margin: "0 auto 1.5rem", display: "block", opacity: 0.4 }}
          >
            <path
              d="M12 2C10 2 8 5 8 9C8 13 10 18 12 21C14 18 16 13 16 9C16 5 14 2 12 2Z"
              fill={C.glow}
              fillOpacity={0.4}
              stroke={C.glow}
              strokeWidth="0.8"
            />
          </svg>

          <h2
            style={{
              fontFamily: "var(--font-instrument), serif",
              fontSize: "clamp(2rem, 5vw, 3.2rem)",
              fontWeight: 400,
              color: "#fff",
              lineHeight: 1.15,
              marginBottom: "1rem",
              textShadow: `0 0 30px ${C.glow}18`,
            }}
          >
            Ready to get started?
          </h2>
          <p
            style={{
              fontFamily: "var(--font-dm)",
              fontSize: "1rem",
              fontWeight: 300,
              color: C.muted,
              maxWidth: 400,
              margin: "0 auto 2.5rem",
              lineHeight: 1.6,
            }}
          >
            Deploy your own persistent AI agent in under a minute.
          </p>

          <motion.a
            href="#"
            whileHover={{
              scale: 1.04,
              boxShadow: `0 0 36px ${C.glow}44, 0 0 72px ${C.glow}18`,
            }}
            whileTap={{ scale: 0.97 }}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: "0.6rem",
              padding: "1.1rem 2.4rem",
              borderRadius: 14,
              background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`,
              color: C.bg,
              fontFamily: "var(--font-dm)",
              fontSize: "1.05rem",
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
        </motion.div>
      </section>

      {/* ========== FOOTER ========== */}
      <footer
        style={{
          position: "relative",
          zIndex: 2,
          borderTop: `1px solid ${C.forestDim}`,
          padding: "2.5rem 1.5rem",
          textAlign: "center",
        }}
      >
        <p
          style={{
            fontFamily: "var(--font-dm)",
            fontSize: "0.8rem",
            color: C.faint,
            fontWeight: 300,
          }}
        >
          &copy; {new Date().getFullYear()} OneAgent
        </p>
      </footer>
    </div>
  );
}
