import { C, glassCard } from "../../lib/theme";
import { CodeBlock } from "./CodeBlock";

export function GuideTab({ agentId }: { agentId: string }) {
  return (
    <div style={{ ...glassCard(), padding: "2rem", display: "flex", flexDirection: "column", gap: "2rem" }}>
      {/* API Access */}
      <section>
        <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.3rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>API Access</h2>
        <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Agent ID:</p>
        <CodeBlock code={agentId} />
        <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Invoke the agent:</p>
        <CodeBlock code={`curl -X POST http://localhost:4000/api/agents/${agentId}/invoke \\\n  -H 'Content-Type: application/json' \\\n  -H 'Authorization: Bearer YOUR_TOKEN' \\\n  -d '{"message": "Hello agent"}'`} />
        <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Get messages:</p>
        <CodeBlock code={`curl http://localhost:4000/api/agents/${agentId}/messages \\\n  -H 'Authorization: Bearer YOUR_TOKEN'`} />
        <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Get runs:</p>
        <CodeBlock code={`curl http://localhost:4000/api/agents/${agentId}/runs \\\n  -H 'Authorization: Bearer YOUR_TOKEN'`} />
      </section>

      {/* WhatsApp */}
      <section style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "2rem" }}>
        <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.3rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>WhatsApp Setup</h2>
        <ol style={{ fontSize: "0.88rem", color: C.text, lineHeight: 1.8, paddingLeft: "1.25rem" }}>
          <li style={{ marginBottom: "0.5rem" }}>Go to <a href="/keys" style={{ color: C.glow, textDecoration: "none" }}>Keys</a> and create a credential with service &quot;whatsapp&quot; containing your <code style={{ color: C.phosphor }}>access_token</code> and <code style={{ color: C.phosphor }}>app_secret</code></li>
          <li style={{ marginBottom: "0.5rem" }}>Create a WhatsApp channel linking this agent to your phone_number_id and credential</li>
          <li style={{ marginBottom: "0.5rem" }}>In your Meta developer dashboard, set the webhook callback URL to:<br /><code style={{ color: C.phosphor }}>https://YOUR_DOMAIN/api/webhooks/whatsapp</code></li>
          <li style={{ marginBottom: "0.5rem" }}>Use the <code style={{ color: C.phosphor }}>verify_token</code> from the channel create response to complete webhook verification</li>
          <li>Send a WhatsApp message to test (agent auto-starts when needed)</li>
        </ol>
      </section>

      {/* Scheduling */}
      <section style={{ borderTop: `1px solid ${C.faint}`, paddingTop: "2rem" }}>
        <h2 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.3rem", color: "#fff", fontWeight: 400, marginBottom: "1rem" }}>Scheduling</h2>
        <p style={{ fontSize: "0.88rem", color: C.muted, marginBottom: "1rem" }}>Add schedules in the Schedules tab. Each schedule has its own cron expression and message. The agent will auto-start when a schedule fires.</p>
        <p style={{ fontSize: "0.85rem", color: C.muted, marginBottom: "0.75rem" }}>Common cron patterns:</p>
        <div style={{ display: "grid", gridTemplateColumns: "auto 1fr", gap: "0.3rem 1.5rem", fontSize: "0.82rem" }}>
          <code style={{ color: C.phosphor }}>*/5 * * * *</code><span style={{ color: C.faint }}>Every 5 minutes</span>
          <code style={{ color: C.phosphor }}>0 * * * *</code><span style={{ color: C.faint }}>Every hour</span>
          <code style={{ color: C.phosphor }}>0 9 * * *</code><span style={{ color: C.faint }}>Daily at 9:00 AM</span>
          <code style={{ color: C.phosphor }}>0 9 * * 1</code><span style={{ color: C.faint }}>Every Monday at 9:00 AM</span>
          <code style={{ color: C.phosphor }}>0 0 1 * *</code><span style={{ color: C.faint }}>First of every month</span>
        </div>
      </section>
    </div>
  );
}
