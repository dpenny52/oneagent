"use client";

import { useEffect } from "react";

/**
 * Core keyframes used across the bioluminescent theme.
 *
 * Each page passes a unique `id` so the <style> tag is not duplicated,
 * and an optional `extra` string for page-specific keyframes.
 */
export function useKeyframes(id: string, extra = "") {
  useEffect(() => {
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
      @keyframes pulseGlow {
        0%, 100% { box-shadow: 0 0 20px rgba(0,212,170,0.08); }
        50% { box-shadow: 0 0 40px rgba(0,212,170,0.15); }
      }
      ${extra}
    `;
    document.head.appendChild(s);
    return () => {
      const el = document.getElementById(id);
      if (el) el.remove();
    };
  }, [id, extra]);
}
