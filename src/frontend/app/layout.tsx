import type { Metadata } from "next";
import { Providers } from "./lib/providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "OneAgent - Persistent AI Agents in One Click",
  description: "Stand up a persistent AI agent with one click. Always on, always working.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" style={{ background: "#060E12" }}>
      <body style={{ background: "#060E12", color: "#e0e0e0" }}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
