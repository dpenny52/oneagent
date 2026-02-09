"use client";

/**
 * OneAgent jellyfish logo (Flat Dome Cascade variant).
 * Loads from the static SVG asset in /public.
 */
export function Logo({ size = 32 }: { size?: number }) {
  return (
    <img
      src="/oneagent-logo.svg"
      alt="OneAgent"
      width={size}
      height={size}
      style={{ display: "block" }}
    />
  );
}
