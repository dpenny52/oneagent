"use client";

export function Orb({
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
