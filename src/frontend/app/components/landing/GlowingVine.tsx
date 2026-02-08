import { C } from "../../lib/theme";

export function GlowingVine({
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
