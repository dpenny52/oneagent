import type { Metadata } from "next";
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
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
