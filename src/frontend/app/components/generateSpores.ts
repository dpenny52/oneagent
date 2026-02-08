import { C } from "../lib/theme";
import type { Spore } from "../lib/types";

const SPORE_COLORS = [C.glow, C.phosphor, C.lavender, C.glow, C.phosphor];

export function generateSpores(count: number): Spore[] {
  return Array.from({ length: count }, (_, i) => ({
    id: i,
    x: Math.random() * 100,
    y: Math.random() * 100,
    size: Math.random() * 3 + 1,
    duration: Math.random() * 7 + 4,
    delay: Math.random() * 6,
    color: SPORE_COLORS[i % SPORE_COLORS.length],
  }));
}
