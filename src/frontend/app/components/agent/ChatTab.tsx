import { motion } from "framer-motion";
import { useRef, useEffect, useState, FormEvent } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { C, inputStyle, glassCard } from "../../lib/theme";
import type { Message } from "../../lib/types";

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      onClick={() => { navigator.clipboard.writeText(text); setCopied(true); setTimeout(() => setCopied(false), 1500); }}
      style={{ position: "absolute", top: 8, right: 8, padding: "0.25rem 0.5rem", borderRadius: 6, border: `1px solid ${C.faint}`, background: "rgba(6,14,18,0.8)", color: copied ? C.glow : C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.7rem", cursor: "pointer" }}
    >
      {copied ? "Copied!" : "Copy"}
    </button>
  );
}

function MessageContent({ content, role }: { content: string; role: string }) {
  if (role === "user") {
    return <span style={{ whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{content}</span>;
  }

  return (
    <div className="md-content">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          p: ({ children }) => <p style={{ margin: "0.4em 0" }}>{children}</p>,
          strong: ({ children }) => <strong style={{ color: C.text, fontWeight: 600 }}>{children}</strong>,
          em: ({ children }) => <em style={{ color: C.phosphor }}>{children}</em>,
          a: ({ href, children }) => <a href={href} target="_blank" rel="noopener noreferrer" style={{ color: C.glow, textDecoration: "underline" }}>{children}</a>,
          ul: ({ children }) => <ul style={{ margin: "0.4em 0", paddingLeft: "1.4em" }}>{children}</ul>,
          ol: ({ children }) => <ol style={{ margin: "0.4em 0", paddingLeft: "1.4em" }}>{children}</ol>,
          li: ({ children }) => <li style={{ margin: "0.2em 0" }}>{children}</li>,
          h1: ({ children }) => <h1 style={{ fontSize: "1.15em", fontWeight: 700, color: C.text, margin: "0.6em 0 0.3em" }}>{children}</h1>,
          h2: ({ children }) => <h2 style={{ fontSize: "1.05em", fontWeight: 600, color: C.text, margin: "0.5em 0 0.2em" }}>{children}</h2>,
          h3: ({ children }) => <h3 style={{ fontSize: "0.95em", fontWeight: 600, color: C.phosphor, margin: "0.4em 0 0.2em" }}>{children}</h3>,
          blockquote: ({ children }) => (
            <blockquote style={{ margin: "0.5em 0", padding: "0.3em 0.8em", borderLeft: `3px solid ${C.lavender}60`, color: C.muted, background: "rgba(155,114,207,0.04)", borderRadius: "0 6px 6px 0" }}>
              {children}
            </blockquote>
          ),
          hr: () => <hr style={{ border: "none", borderTop: `1px solid ${C.faint}`, margin: "0.6em 0" }} />,
          table: ({ children }) => (
            <div style={{ overflowX: "auto", margin: "0.5em 0" }}>
              <table style={{ borderCollapse: "collapse", fontSize: "0.85em", width: "100%" }}>{children}</table>
            </div>
          ),
          th: ({ children }) => <th style={{ padding: "0.4em 0.6em", borderBottom: `1px solid ${C.faint}`, textAlign: "left", color: C.phosphor, fontWeight: 600 }}>{children}</th>,
          td: ({ children }) => <td style={{ padding: "0.4em 0.6em", borderBottom: `1px solid ${C.faint}15`, color: C.text }}>{children}</td>,
          pre: ({ children }) => {
            const extractText = (node: unknown): string => {
              if (typeof node === "string") return node;
              if (Array.isArray(node)) return node.map(extractText).join("");
              if (node && typeof node === "object" && "props" in node) return extractText((node as { props: { children?: unknown } }).props.children);
              return "";
            };
            const text = extractText(children).replace(/\n$/, "");
            return (
              <div style={{ position: "relative", margin: "0.5em 0" }}>
                <pre style={{ padding: "1rem", borderRadius: 10, background: "rgba(0,0,0,0.3)", border: `1px solid ${C.faint}`, color: C.phosphor, fontSize: "0.82em", fontFamily: "monospace", overflowX: "auto", whiteSpace: "pre-wrap", wordBreak: "break-all", lineHeight: 1.5 }}>
                  <code>{text}</code>
                </pre>
                <CopyButton text={text} />
              </div>
            );
          },
          code: ({ children }) => (
            <code style={{ padding: "0.15em 0.35em", borderRadius: 5, background: "rgba(0,0,0,0.25)", color: C.phosphor, fontSize: "0.9em", fontFamily: "monospace" }}>
              {children}
            </code>
          ),
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
}

export function ChatTab({
  canChat,
  messages,
  chatInput,
  setChatInput,
  sending,
  onSend,
  onClearHistory,
}: {
  canChat: boolean;
  messages: Message[];
  chatInput: string;
  setChatInput: (v: string) => void;
  sending: boolean;
  onSend: (e?: FormEvent) => void;
  onClearHistory: () => void;
}) {
  const chatEndRef = useRef<HTMLDivElement>(null);
  const chatContainerRef = useRef<HTMLDivElement>(null);
  const prevMessageCountRef = useRef(messages.length);
  const userSentRef = useRef(false);

  // Scroll to bottom when tab first opens
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "instant" });
  }, []);

  // Track when user sends a message (sending transitions from false → true)
  useEffect(() => {
    if (sending) userSentRef.current = true;
  }, [sending]);

  useEffect(() => {
    const container = chatContainerRef.current;
    if (!container) return;

    const isNewMessage = messages.length > prevMessageCountRef.current;
    const wasUserSend = userSentRef.current;
    prevMessageCountRef.current = messages.length;

    // Auto-scroll only if: user just sent a message, OR user was already near the bottom
    if (wasUserSend) {
      userSentRef.current = false;
      chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    } else if (isNewMessage) {
      const threshold = 80;
      const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < threshold;
      if (isNearBottom) chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, sending]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
      {!canChat && (
        <div style={{ padding: "0.8rem 1rem", borderRadius: 10, background: "rgba(255,200,50,0.06)", border: "1px solid rgba(255,200,50,0.2)", fontSize: "0.85rem", color: "#FFD166" }}>
          Assign an LLM configuration in Settings to start chatting. <a href="/keys" style={{ color: C.glow, textDecoration: "underline" }}>Add a key</a>
        </div>
      )}

      {/* Messages */}
      <div ref={chatContainerRef} style={{ ...glassCard(), padding: "1.5rem", minHeight: 350, maxHeight: 500, overflowY: "auto", display: "flex", flexDirection: "column", gap: "1rem" }}>
        {messages.length === 0 && !sending && (
          <div style={{ textAlign: "center", padding: "3rem 1rem", color: C.faint, fontSize: "0.9rem" }}>No messages yet. Send a message to start.</div>
        )}
        {messages.map((msg) => (
          <div key={msg.id} style={{ display: "flex", justifyContent: msg.role === "user" ? "flex-end" : "flex-start" }}>
            <div style={{ maxWidth: "75%", padding: "0.8rem 1rem", borderRadius: 14, background: msg.role === "user" ? `rgba(0,212,170,0.08)` : "rgba(155,114,207,0.06)", border: `1px solid ${msg.role === "user" ? `${C.glow}25` : `${C.lavender}20`}`, fontSize: "0.88rem", lineHeight: 1.6, color: C.text, wordBreak: "break-word" }}>
              <MessageContent content={msg.content} role={msg.role} />
              {msg.source === "scheduled" && msg.role === "assistant" && (
                <div style={{ marginTop: 6, fontSize: "0.7rem", color: C.muted, opacity: 0.7, fontStyle: "italic" }}>scheduled run</div>
              )}
            </div>
          </div>
        ))}
        {sending && (
          <div style={{ display: "flex", justifyContent: "flex-start" }}>
            <div style={{ padding: "0.8rem 1.2rem", borderRadius: 14, background: "rgba(155,114,207,0.06)", border: `1px solid ${C.lavender}20`, display: "flex", gap: 6 }}>
              {[0, 1, 2].map((i) => (
                <div key={i} style={{ width: 7, height: 7, borderRadius: "50%", background: C.lavender, animation: `typingDot 1.2s ease-in-out ${i * 0.2}s infinite` }} />
              ))}
            </div>
          </div>
        )}
        <div ref={chatEndRef} />
      </div>

      {/* Input */}
      <form onSubmit={onSend} style={{ display: "flex", gap: "0.5rem" }}>
        <textarea value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); onSend(); } }} placeholder={canChat ? "Type a message... (Enter to send)" : "Configure LLM to chat"} disabled={!canChat} rows={2} style={{ ...inputStyle(), flex: 1, resize: "none" as const, opacity: !canChat ? 0.5 : 1 }} />
        <motion.button type="submit" disabled={sending || !canChat} whileHover={sending ? {} : { scale: 1.03 }} whileTap={sending ? {} : { scale: 0.97 }} style={{ padding: "0 1.5rem", borderRadius: 12, border: "none", background: `linear-gradient(135deg, ${C.glow}, ${C.forest})`, color: C.bg, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.85rem", fontWeight: 600, cursor: sending || !canChat ? "not-allowed" : "pointer", opacity: sending || !canChat ? 0.5 : 1, alignSelf: "stretch" }}>
          Send
        </motion.button>
      </form>

      {messages.length > 0 && (
        <button onClick={onClearHistory} style={{ alignSelf: "flex-end", padding: "0.4rem 0.8rem", borderRadius: 8, border: `1px solid ${C.faint}`, background: "transparent", color: C.muted, fontFamily: "var(--font-dm), sans-serif", fontSize: "0.78rem", cursor: "pointer" }}>
          Clear History
        </button>
      )}
    </div>
  );
}
