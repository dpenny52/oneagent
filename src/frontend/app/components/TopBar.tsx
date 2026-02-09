"use client";

import { useAuth } from "../lib/auth";
import { C } from "../lib/theme";
import { Logo } from "./Logo";

/**
 * Sticky top navigation bar used on authenticated pages.
 *
 * @param breadcrumbs - Optional breadcrumb segments rendered after the logo
 *   (e.g. [{ label: "Dashboard", href: "/dashboard" }, { label: "My Agent" }])
 */
export function TopBar({ breadcrumbs }: { breadcrumbs?: { label: string; href?: string }[] }) {
  const { user, logout } = useAuth();
  return (
    <nav
      style={{
        position: "sticky",
        top: 0,
        zIndex: 50,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "1rem 2rem",
        background: "rgba(6,14,18,0.7)",
        backdropFilter: "blur(20px)",
        WebkitBackdropFilter: "blur(20px)",
        borderBottom: `1px solid ${C.glow}10`,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
        <a href="/dashboard" style={{ display: "flex", alignItems: "center", textDecoration: "none" }}>
          <Logo size={32} />
        </a>
        {breadcrumbs?.map((bc, i) => (
          <span key={i} style={{ display: "contents" }}>
            <span style={{ color: C.faint }}>/</span>
            {bc.href ? (
              <a
                href={bc.href}
                style={{
                  fontFamily: "var(--font-dm), sans-serif",
                  fontSize: "0.9rem",
                  color: C.muted,
                  textDecoration: "none",
                }}
              >
                {bc.label}
              </a>
            ) : (
              <span
                style={{
                  fontFamily: "var(--font-dm), sans-serif",
                  fontSize: "0.9rem",
                  color: C.text,
                }}
              >
                {bc.label}
              </span>
            )}
          </span>
        ))}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
        <a
          href="/keys"
          style={{
            fontFamily: "var(--font-dm), sans-serif",
            fontSize: "0.85rem",
            color: C.muted,
            textDecoration: "none",
            transition: "color 0.2s",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.color = C.text)}
          onMouseLeave={(e) =>
            (e.currentTarget.style.color = "rgba(216,237,230,0.40)")
          }
        >
          Keys
        </a>
        <span
          style={{
            fontFamily: "var(--font-dm), sans-serif",
            fontSize: "0.82rem",
            color: C.faint,
          }}
        >
          {user?.email}
        </span>
        <button
          onClick={() => logout()}
          style={{
            padding: "0.4rem 0.9rem",
            borderRadius: 8,
            border: `1px solid ${C.faint}`,
            background: "transparent",
            color: C.muted,
            fontFamily: "var(--font-dm), sans-serif",
            fontSize: "0.8rem",
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
      </div>
    </nav>
  );
}
