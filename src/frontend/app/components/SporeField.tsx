"use client";

import type { Spore } from "../lib/types";

/** Renders floating spore particles over a fixed overlay. */
export function SporeField({ spores }: { spores: Spore[] }) {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        pointerEvents: "none",
        zIndex: 1,
        overflow: "hidden",
        willChange: "transform",
        transform: "translateZ(0)",
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
            animation: `sporeFloat ${sp.duration}s ease-in-out ${sp.delay}s infinite`,
            willChange: "transform, opacity",
          }}
        />
      ))}
    </div>
  );
}
