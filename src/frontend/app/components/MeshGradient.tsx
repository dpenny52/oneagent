"use client";

import { C } from "../lib/theme";

/**
 * Animated mesh gradient background overlay.
 *
 * @param opacity - Overall overlay opacity (default 0.3)
 * @param threeGradients - Whether to use the three-gradient variant (default true).
 *   When false, only uses the glow + lavender gradients.
 */
export function MeshGradient({ opacity = 0.3, threeGradients = true }: { opacity?: number; threeGradients?: boolean }) {
  const bg = threeGradients
    ? `radial-gradient(ellipse 55% 45% at 20% 50%, ${C.glowDim} 0%, transparent 70%), radial-gradient(ellipse 45% 55% at 80% 30%, ${C.lavenderDim} 0%, transparent 70%), radial-gradient(ellipse 35% 35% at 50% 80%, ${C.forestDim} 0%, transparent 70%)`
    : `radial-gradient(ellipse 55% 45% at 20% 50%, ${C.glowDim} 0%, transparent 70%), radial-gradient(ellipse 45% 55% at 80% 30%, ${C.lavenderDim} 0%, transparent 70%)`;

  const bgSize = threeGradients
    ? "200% 200%, 200% 200%, 200% 200%"
    : "200% 200%, 200% 200%";

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 0,
        opacity,
        background: bg,
        backgroundSize: bgSize,
        animation: "meshShift 22s ease-in-out infinite",
        pointerEvents: "none",
      }}
    />
  );
}
