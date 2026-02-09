"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { C } from "../../lib/theme";

export function FeatureCard({
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
  const [hovered, setHovered] = useState(false);

  // Both states must have the same shadow structure (outer, outer, inset)
  // so CSS can interpolate between them smoothly
  const restingShadow = `0 0 30px ${glowColor}05, 0 0 0px transparent, inset 0 0 30px ${glowColor}02`;
  const hoverShadow = `0 8px 40px ${glowColor}15, 0 0 60px ${glowColor}08, inset 0 0 30px ${glowColor}02`;

  return (
    <motion.div
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{ duration: 0.7, delay, ease: "easeOut" }}
      whileHover={{
        y: -4,
        transition: { duration: 0.4, ease: "easeOut" },
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        flex: "1 1 300px",
        maxWidth: 380,
        padding: "2.5rem 2rem",
        borderRadius: 24,
        background: "rgba(255,255,255,0.02)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        border: `1px solid ${glowColor}18`,
        boxShadow: hovered ? hoverShadow : restingShadow,
        transition: "box-shadow 0.4s ease-out",
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
