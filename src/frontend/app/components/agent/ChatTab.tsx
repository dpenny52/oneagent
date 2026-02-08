import { motion } from "framer-motion";
import { useRef, useEffect, FormEvent } from "react";
import { C, inputStyle, glassCard } from "../../lib/theme";
import type { Message } from "../../lib/types";

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

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, sending]);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
      {!canChat && (
        <div style={{ padding: "0.8rem 1rem", borderRadius: 10, background: "rgba(255,200,50,0.06)", border: "1px solid rgba(255,200,50,0.2)", fontSize: "0.85rem", color: "#FFD166" }}>
          Assign an LLM configuration in Settings to start chatting. <a href="/keys" style={{ color: C.glow, textDecoration: "underline" }}>Add a key</a>
        </div>
      )}

      {/* Messages */}
      <div style={{ ...glassCard(), padding: "1.5rem", minHeight: 350, maxHeight: 500, overflowY: "auto", display: "flex", flexDirection: "column", gap: "1rem" }}>
        {messages.length === 0 && !sending && (
          <div style={{ textAlign: "center", padding: "3rem 1rem", color: C.faint, fontSize: "0.9rem" }}>No messages yet. Send a message to start.</div>
        )}
        {messages.map((msg) => (
          <div key={msg.id} style={{ display: "flex", justifyContent: msg.role === "user" ? "flex-end" : "flex-start" }}>
            <div style={{ maxWidth: "75%", padding: "0.8rem 1rem", borderRadius: 14, background: msg.role === "user" ? `rgba(0,212,170,0.08)` : "rgba(155,114,207,0.06)", border: `1px solid ${msg.role === "user" ? `${C.glow}25` : `${C.lavender}20`}`, fontSize: "0.88rem", lineHeight: 1.6, color: C.text, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
              {msg.content}
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
