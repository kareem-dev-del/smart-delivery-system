import { useEffect, useMemo, useState } from "react";
import { formatDate, formatLabel } from "../lib/format";
import {
  AlertTriangle,
  ClipboardList,
  FileClock,
  RefreshCw,
  ShieldCheck,
} from "lucide-react";

import { getAuditLog, type AuditLogEntry } from "../api/audit";
import { useAuth } from "../auth/AuthProvider";



function formatMetadata(metadata: Record<string, unknown>): string {
  const entries = Object.entries(metadata);

  if (entries.length === 0) {
    return "-";
  }

  return entries
    .map(([key, value]) => `${formatLabel(key)}: ${String(value)}`)
    .join(" | ");
}

export function AuditLogPage() {
  const { tokens } = useAuth();
  const [entries, setEntries] = useState<AuditLogEntry[]>([]);
  const [count, setCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadAuditLog() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await getAuditLog(tokens.access);
      setEntries(data.results);
      setCount(data.count);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load audit log.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadAuditLog();
  }, [tokens?.access]);

  const uniqueActors = useMemo(() => {
    return new Set(entries.map((entry) => entry.actor_username ?? "System"))
      .size;
  }, [entries]);

  const uniqueActions = useMemo(() => {
    return new Set(entries.map((entry) => entry.action)).size;
  }, [entries]);

  const orderEvents = useMemo(() => {
    return entries.filter((entry) => entry.target_type === "order").length;
  }, [entries]);

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Audit log</p>
          <h1 className="page-title">Audit Log</h1>
          <p className="page-description">
            Administrative activity trail from the SmartDrop backend.
          </p>
        </div>

        <button className="icon-text-button" type="button" onClick={loadAuditLog}>
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {loading && (
        <div className="scope-note">
          <FileClock size={15} />
          <span>Loading audit log...</span>
        </div>
      )}

      {error && (
        <div className="scope-note error-note">
          <AlertTriangle size={15} />
          <span>{error}</span>
        </div>
      )}

      {!loading && !error && (
        <div className="orders-page-shell">
          <section
            className="orders-summary-panel"
            aria-labelledby="audit-summary-heading"
          >
            <h2 id="audit-summary-heading" className="section-heading">
              Audit summary
            </h2>
            <p className="section-subtitle">
              {count} event{count === 1 ? "" : "s"} returned by the API.
            </p>

            <div className="module-grid">
              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <FileClock size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{count}</span>
                </div>
                <h3 className="module-title">Total events</h3>
                <p className="module-copy">
                  Recorded administrative events visible to this account.
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <ShieldCheck size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{uniqueActors}</span>
                </div>
                <h3 className="module-title">Actors</h3>
                <p className="module-copy">
                  Users or system actors that performed events.
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <ClipboardList size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{uniqueActions}</span>
                </div>
                <h3 className="module-title">Action types</h3>
                <p className="module-copy">
                  Distinct event names returned by the audit API.
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <ClipboardList size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{orderEvents}</span>
                </div>
                <h3 className="module-title">Order events</h3>
                <p className="module-copy">
                  Audit events attached to order workflow operations.
                </p>
              </article>
            </div>
          </section>

          <section className="orders-table-panel" aria-labelledby="audit-table-heading">
            <h2 id="audit-table-heading" className="section-heading">
              Event list
            </h2>
            <p className="section-subtitle">
              Actor, action, target, metadata, and timestamp.
            </p>

            {entries.length === 0 ? (
              <div className="empty-panel">
                <ShieldCheck size={18} />
                <span>No audit events found.</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Action</th>
                      <th>Actor</th>
                      <th>Target</th>
                      <th>Metadata</th>
                      <th>Created</th>
                    </tr>
                  </thead>
                  <tbody>
                    {entries.map((entry) => (
                      <tr key={entry.id}>
                        <td>
                          <span className="status-badge status-neutral">
                            {formatLabel(entry.action)}
                          </span>
                        </td>
                        <td>{entry.actor_username ?? "System"}</td>
                        <td>
                          <span className="mono-cell">
                            {entry.target_type}:{entry.target_id.slice(0, 8)}
                          </span>
                        </td>
                        <td>
                          <span className="table-secondary-text">
                            {formatMetadata(entry.metadata)}
                          </span>
                        </td>
                        <td>{formatDate(entry.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      )}
    </>
  );
}