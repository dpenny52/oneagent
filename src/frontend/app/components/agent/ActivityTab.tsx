"use client";

import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { api } from "../../lib/api";
import { C, glassCard } from "../../lib/theme";
import type { AgentRun, AgentRunDetail, AgentStep } from "../../lib/types";

const LIMIT = 20;

function timeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = now - then;
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(dateStr).toLocaleDateString();
}

function formatDuration(startedAt: string | null, completedAt: string | null): string | null {
  if (!startedAt || !completedAt) return null;
  const ms = new Date(completedAt).getTime() - new Date(startedAt).getTime();
  if (ms < 1000) return `${ms}ms`;
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  const mins = Math.floor(secs / 60);
  const remSecs = secs % 60;
  return `${mins}m ${remSecs}s`;
}

function statusColor(status: string): string {
  switch (status) {
    case "completed": return C.glow;
    case "failed": return C.danger;
    case "running": return "#FFD166";
    default: return C.muted;
  }
}

function stepTypeLabel(stepType: string): { label: string; color: string } {
  switch (stepType) {
    case "llm_call": return { label: "LLM Call", color: C.lavender };
    case "tool_execution": return { label: "Tool", color: C.glow };
    case "error": return { label: "Error", color: C.danger };
    default: return { label: stepType, color: C.muted };
  }
}

export function ActivityTab({ agentId }: { agentId: string }) {
  const [runs, setRuns] = useState<AgentRun[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [expandedRunId, setExpandedRunId] = useState<string | null>(null);
  const [expandedSteps, setExpandedSteps] = useState<AgentStep[]>([]);
  const [stepsLoading, setStepsLoading] = useState(false);
  const [statusFilter, setStatusFilter] = useState("all");
  const [triggerFilter, setTriggerFilter] = useState("all");

  const buildQuery = useCallback((offset: number) => {
    const params = new URLSearchParams();
    params.set("limit", String(LIMIT));
    params.set("offset", String(offset));
    if (statusFilter !== "all") params.set("status", statusFilter);
    if (triggerFilter !== "all") params.set("trigger", triggerFilter);
    return params.toString();
  }, [statusFilter, triggerFilter]);

  const loadRuns = useCallback(async () => {
    setLoading(true);
    const res = await api.get<AgentRun[]>(`/api/agents/${agentId}/runs?${buildQuery(0)}`);
    if (res.ok) {
      setRuns(res.data);
      setHasMore(res.data.length >= LIMIT);
    }
    setLoading(false);
  }, [agentId, buildQuery]);

  useEffect(() => {
    loadRuns();
  }, [loadRuns]);

  async function handleLoadMore() {
    setLoadingMore(true);
    const res = await api.get<AgentRun[]>(`/api/agents/${agentId}/runs?${buildQuery(runs.length)}`);
    if (res.ok) {
      setRuns((prev) => [...prev, ...res.data]);
      setHasMore(res.data.length >= LIMIT);
    }
    setLoadingMore(false);
  }

  async function handleToggleExpand(runId: string) {
    if (expandedRunId === runId) {
      setExpandedRunId(null);
      setExpandedSteps([]);
      return;
    }
    setExpandedRunId(runId);
    setStepsLoading(true);
    const res = await api.get<AgentRunDetail>(`/api/agents/${agentId}/runs/${runId}`);
    if (res.ok) {
      setExpandedSteps(res.data.steps || []);
    }
    setStepsLoading(false);
  }

  const selectStyle: React.CSSProperties = {
    padding: "0.45rem 0.7rem",
    borderRadius: 8,
    border: `1px solid ${C.faint}`,
    background: "rgba(255,255,255,0.03)",
    color: C.text,
    fontFamily: "var(--font-dm), sans-serif",
    fontSize: "0.8rem",
    outline: "none",
    cursor: "pointer",
    appearance: "none" as const,
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
      {/* Header + Filters */}
      <div style={{ ...glassCard(), padding: "1.25rem 1.5rem" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "0.75rem" }}>
          <h3 style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.1rem", color: "#fff", fontWeight: 400, margin: 0 }}>
            Run History
          </h3>
          <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              style={selectStyle}
            >
              <option value="all">All Status</option>
              <option value="completed">Completed</option>
              <option value="failed">Failed</option>
              <option value="running">Running</option>
              <option value="pending">Pending</option>
            </select>
            <select
              value={triggerFilter}
              onChange={(e) => setTriggerFilter(e.target.value)}
              style={selectStyle}
            >
              <option value="all">All Triggers</option>
              <option value="manual">Manual</option>
              <option value="scheduled">Scheduled</option>
              <option value="webhook">Webhook</option>
            </select>
          </div>
        </div>
      </div>

      {/* Loading */}
      {loading && (
        <div style={{ textAlign: "center", padding: "3rem 0", color: C.muted, fontSize: "0.9rem" }}>
          Loading runs...
        </div>
      )}

      {/* Empty state */}
      {!loading && runs.length === 0 && (
        <div style={{ ...glassCard(), padding: "3rem 2rem", textAlign: "center" }}>
          <p style={{ fontFamily: "var(--font-instrument), serif", fontSize: "1.2rem", color: "#fff", marginBottom: "0.4rem" }}>No runs yet</p>
          <p style={{ fontSize: "0.85rem", color: C.muted }}>This agent hasn&#39;t been invoked. Send a message in the Chat tab to get started.</p>
        </div>
      )}

      {/* Run list */}
      {!loading && runs.length > 0 && (
        <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
          {runs.map((run) => {
            const isExpanded = expandedRunId === run.id;
            const isRunning = run.status === "running";
            const duration = formatDuration(run.started_at, run.completed_at);

            return (
              <div key={run.id}>
                <motion.div
                  onClick={() => handleToggleExpand(run.id)}
                  style={{
                    ...glassCard(),
                    padding: "1rem 1.25rem",
                    cursor: "pointer",
                    borderColor: isExpanded ? `${C.glow}30` : undefined,
                    transition: "border-color 0.2s",
                  }}
                  whileHover={{ scale: 1.005 }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", flexWrap: "wrap" }}>
                    {/* Status dot */}
                    <span style={{
                      width: 8, height: 8, borderRadius: "50%", flexShrink: 0,
                      background: statusColor(run.status),
                      boxShadow: isRunning ? `0 0 8px ${statusColor(run.status)}` : "none",
                      animation: isRunning ? "pulse 2s ease-in-out infinite" : "none",
                    }} />

                    {/* Trigger badge */}
                    <span style={{
                      padding: "0.15rem 0.5rem", borderRadius: 5,
                      background: "rgba(255,255,255,0.04)",
                      border: `1px solid ${C.faint}`,
                      color: C.muted, fontSize: "0.72rem", fontWeight: 500,
                      letterSpacing: "0.03em", textTransform: "capitalize",
                    }}>
                      {run.trigger}
                    </span>

                    {/* Timestamp */}
                    <span style={{ fontSize: "0.8rem", color: C.muted }}>
                      {timeAgo(run.inserted_at)}
                    </span>

                    {/* Spacer */}
                    <span style={{ flex: 1 }} />

                    {/* Duration */}
                    {duration && (
                      <span style={{ fontSize: "0.75rem", color: C.faint }}>
                        {duration}
                      </span>
                    )}

                    {/* Tokens */}
                    {run.total_tokens_used != null && run.total_tokens_used > 0 && (
                      <span style={{ fontSize: "0.72rem", color: C.faint, padding: "0.1rem 0.4rem", borderRadius: 4, background: "rgba(255,255,255,0.04)" }}>
                        {run.total_tokens_used.toLocaleString()} tok
                      </span>
                    )}

                    {/* Steps count */}
                    {run.total_steps != null && run.total_steps > 0 && (
                      <span style={{ fontSize: "0.72rem", color: C.faint, padding: "0.1rem 0.4rem", borderRadius: 4, background: "rgba(255,255,255,0.04)" }}>
                        {run.total_steps} step{run.total_steps !== 1 ? "s" : ""}
                      </span>
                    )}

                    {/* Expand indicator */}
                    <span style={{
                      color: C.faint, fontSize: "0.75rem",
                      transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)",
                      transition: "transform 0.2s",
                    }}>
                      ▾
                    </span>
                  </div>

                  {/* Error message for failed runs */}
                  {run.status === "failed" && run.error_message && (
                    <div style={{
                      marginTop: "0.6rem", padding: "0.5rem 0.75rem", borderRadius: 8,
                      background: "rgba(255,107,107,0.06)", border: `1px solid ${C.danger}20`,
                      fontSize: "0.78rem", color: C.danger, lineHeight: 1.4,
                    }}>
                      {run.error_message}
                    </div>
                  )}
                </motion.div>

                {/* Expanded steps */}
                <AnimatePresence>
                  {isExpanded && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: "auto" }}
                      exit={{ opacity: 0, height: 0 }}
                      style={{ overflow: "hidden" }}
                    >
                      <div style={{
                        margin: "0.25rem 0 0.5rem 0",
                        padding: "1rem 1.25rem",
                        borderRadius: 16,
                        background: "rgba(255,255,255,0.015)",
                        border: `1px solid ${C.faint}`,
                      }}>
                        {stepsLoading && (
                          <div style={{ textAlign: "center", padding: "1.5rem 0", color: C.muted, fontSize: "0.85rem" }}>
                            Loading steps...
                          </div>
                        )}
                        {!stepsLoading && expandedSteps.length === 0 && (
                          <div style={{ textAlign: "center", padding: "1rem 0", color: C.faint, fontSize: "0.85rem" }}>
                            No steps recorded
                          </div>
                        )}
                        {!stepsLoading && expandedSteps.length > 0 && (
                          <div style={{ display: "flex", flexDirection: "column", gap: "0.4rem" }}>
                            {expandedSteps.map((step) => {
                              const typeInfo = stepTypeLabel(step.step_type);
                              return (
                                <div key={step.id} style={{
                                  display: "flex", alignItems: "center", gap: "0.6rem",
                                  padding: "0.6rem 0.75rem", borderRadius: 8,
                                  background: "rgba(255,255,255,0.025)",
                                  border: `1px solid ${step.status === "failed" ? `${C.danger}20` : "rgba(255,255,255,0.04)"}`,
                                }}>
                                  {/* Step number */}
                                  <span style={{
                                    fontSize: "0.7rem", color: C.faint, fontWeight: 600,
                                    width: 22, textAlign: "center", flexShrink: 0,
                                  }}>
                                    #{step.step_number}
                                  </span>

                                  {/* Status dot */}
                                  <span style={{
                                    width: 6, height: 6, borderRadius: "50%", flexShrink: 0,
                                    background: statusColor(step.status),
                                  }} />

                                  {/* Type badge */}
                                  <span style={{
                                    padding: "0.12rem 0.45rem", borderRadius: 4,
                                    background: `${typeInfo.color}12`,
                                    border: `1px solid ${typeInfo.color}30`,
                                    color: typeInfo.color, fontSize: "0.7rem", fontWeight: 500,
                                    flexShrink: 0,
                                  }}>
                                    {typeInfo.label}
                                  </span>

                                  {/* Tool ID */}
                                  {step.tool_id && (
                                    <span style={{
                                      padding: "0.1rem 0.4rem", borderRadius: 4,
                                      background: "rgba(0,212,170,0.08)",
                                      border: `1px solid ${C.glow}25`,
                                      color: C.phosphor, fontSize: "0.7rem", fontWeight: 500,
                                      flexShrink: 0,
                                    }}>
                                      {step.tool_id}
                                    </span>
                                  )}

                                  {/* Spacer */}
                                  <span style={{ flex: 1 }} />

                                  {/* Duration */}
                                  {step.duration_ms != null && (
                                    <span style={{ fontSize: "0.7rem", color: C.faint }}>
                                      {step.duration_ms < 1000 ? `${step.duration_ms}ms` : `${(step.duration_ms / 1000).toFixed(1)}s`}
                                    </span>
                                  )}

                                  {/* Tokens */}
                                  {step.tokens_used != null && step.tokens_used > 0 && (
                                    <span style={{ fontSize: "0.68rem", color: C.faint, padding: "0.05rem 0.3rem", borderRadius: 3, background: "rgba(255,255,255,0.04)" }}>
                                      {step.tokens_used.toLocaleString()} tok
                                    </span>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>
      )}

      {/* Load more */}
      {!loading && hasMore && (
        <div style={{ textAlign: "center", paddingTop: "0.5rem" }}>
          <motion.button
            onClick={handleLoadMore}
            disabled={loadingMore}
            whileHover={loadingMore ? {} : { scale: 1.03 }}
            whileTap={loadingMore ? {} : { scale: 0.97 }}
            style={{
              padding: "0.6rem 1.5rem", borderRadius: 10,
              border: `1px solid ${C.glow}30`,
              background: "rgba(0,212,170,0.05)",
              color: C.glow,
              fontFamily: "var(--font-dm), sans-serif",
              fontSize: "0.82rem", fontWeight: 500,
              cursor: loadingMore ? "not-allowed" : "pointer",
              opacity: loadingMore ? 0.6 : 1,
            }}
          >
            {loadingMore ? "Loading..." : "Load More"}
          </motion.button>
        </div>
      )}

      {/* Inject pulse animation for running status */}
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.4; }
        }
      `}</style>
    </div>
  );
}
