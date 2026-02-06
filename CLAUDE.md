# OneAgent

A landing page gallery showcasing multiple design directions for **OneAgent** — a platform to deploy persistent AI agents that live in the cloud.

## Project Structure

```
oneagent/
  src/frontend/           # Next.js app (this is the actual project root for builds/dev)
    app/
      layout.tsx          # Root layout — bare HTML shell, no global providers
      page.tsx            # Home page — directory listing all designs with links
      globals.css         # Minimal global reset
      2/page.tsx          # Bioluminescent — organic glow, cyan/purple on dark navy
      5/page.tsx          # Art Deco — gold on black, geometric luxury, ornamental
      6/page.tsx          # Celestial Observatory — deep space, stellar gold, star maps
      7/page.tsx          # Noir Rose Gold — luxury dark minimalism, metallic accents
      8/page.tsx          # Deep Ocean Abyss — underwater bioluminescence, sonar rings
      9/page.tsx          # Volcanic Ember — obsidian forge, molten fissures, ember particles
      10/page.tsx         # Midnight Garden — moonlit botanicals, silver and emerald
      11/page.tsx         # (new design)
    package.json
    next.config.ts
    tsconfig.json
```

## Tech Stack

- **Next.js 16.1.6** with App Router (Turbopack)
- **React 19.2.3** / TypeScript 5
- **Framer Motion 12.33** for all animations
- **Tailwind CSS 4** is installed but NOT used in page components — all styling is inline
- Google Fonts loaded via `next/font/google`

## Commands

Run from the `src/frontend/` directory:

```bash
npm run dev      # Dev server (localhost:3000)
npm run build    # Production build
npm run lint     # ESLint
```

## Page Conventions

Every numbered page (`/2`, `/5`, `/6`, etc.) follows the same pattern:

1. **`"use client"`** directive at top — all pages are client components
2. **Imports**: `motion` from framer-motion, 2-3 Google Fonts, React hooks
3. **Google Fonts** initialized at module scope with `next/font/google`
4. **Color constants** defined as a palette object or individual constants
5. **Keyframe injection** via `useEffect` that creates a `<style>` element with an ID guard to prevent duplicates
6. **`useCountUp` hook** — custom hook using `IntersectionObserver` + `requestAnimationFrame` with eased animation for stat counters
7. **ALL styles are inline** `style={{}}` objects — no Tailwind utility classes, no CSS modules, no external stylesheets
8. **Framer Motion `whileInView`** for scroll-triggered entrance animations
9. **Single default export** function component

### Content Structure (consistent across all pages)

Each page presents the same product content with a unique aesthetic:

1. **Hero** — "OneAgent" title, tagline ("A living agent. Always awake. One click to life."), subtext about persistent AI, CTA button, scroll indicator
2. **Features** — 3 cards: "Instant Birth" (deploy <30s), "Persistent Memory" (knowledge graph), "Always Alive" (24/7 uptime)
3. **Lifecycle/Process** — Visualization of: Prompt → Spawn → Learn → Act → Remember → Evolve
4. **Stats** — 12,847 Agents, 99.99% Uptime, 28s Avg Deploy (animated counters)
5. **Final CTA** — Closing call-to-action with button
6. **Footer** — Copyright and minimal links

### Adding a New Design

1. Create `src/frontend/app/{N}/page.tsx` following the conventions above
2. Add an entry to the `designs` array in `src/frontend/app/page.tsx`

## Design Philosophy

The user prefers **dark, atmospheric, luxurious** aesthetics with:
- Rich accent colors with glow/bloom effects
- Atmospheric visual elements (particles, orbs, gradients, SVG ornaments)
- Elegant typography pairing a distinctive display font with a refined body font
- Detailed Framer Motion animations (staggered reveals, continuous ambient motion)
- Glass/blur/transparency effects

Routes `/2` (Bioluminescent) and `/5` (Art Deco) are the original favorites that set the tone for all subsequent designs.
