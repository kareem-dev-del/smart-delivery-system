import { useEffect, useMemo, useState } from "react";
import { formatDate, formatLabel } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";
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
  const { t, locale } = useLocale();
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
          <p className="eyebrow">{t("Network control / Audit log")}</p>
          <h1 className="page-title">{t("Audit Log")}</h1>
          <p className="page-description">{t("Administrative activity trail from the SmartDrop backend.")}</p>
        </div>

        <button className="icon-text-button" type="button" onClick={loadAuditLog}>
          <RefreshCw size={16} />
          {t("Refresh")}
        </button>
      </div>

      {loading && (
        <div className="scope-note">
          <FileClock size={15} />
          <span>{t("Loading audit log...")}</span>
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
              {t("Audit summary")}
            </h2>
            <p className="section-subtitle">
              {locale === "ar" ? `أعاد النظام ${count} حدثًا.` : `${count} event${count === 1 ? "" : "s"} returned by the API.`}
            </p>

            <div className="module-grid">
              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <FileClock size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{count}</span>
                </div>
                <h3 className="module-title">{t("Total events")}</h3>
                <p className="module-copy">
                  {t("Recorded administrative events visible to this account.")}
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <ShieldCheck size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{uniqueActors}</span>
                </div>
                <h3 className="module-title">{t("Actors")}</h3>
                <p className="module-copy">
                  {t("Users or system actors that performed events.")}
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <ClipboardList size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{uniqueActions}</span>
                </div>
                <h3 className="module-title">{t("Action types")}</h3>
                <p className="module-copy">
                  {t("Distinct event names returned by the audit API.")}
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <ClipboardList size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{orderEvents}</span>
                </div>
                <h3 className="module-title">{t("Order events")}</h3>
                <p className="module-copy">
                  {t("Audit events attached to order workflow operations.")}
                </p>
              </article>
            </div>
          </section>

          <section className="orders-table-panel" aria-labelledby="audit-table-heading">
            <h2 id="audit-table-heading" className="section-heading">
              {t("Event list")}
            </h2>
            <p className="section-subtitle">
              {t("Actor, action, target, metadata, and timestamp.")}
            </p>

            {entries.length === 0 ? (
              <div className="empty-panel">
                <ShieldCheck size={18} />
                <span>{t("No audit events found.")}</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>{t("Action")}</th>
                      <th>{t("Actor")}</th>
                      <th>{t("Target")}</th>
                      <th>{t("Metadata")}</th>
                      <th>{t("Created")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {entries.map((entry) => (
                      <tr key={entry.id}>
                        <td>
                          <span className="status-badge status-neutral">
                            {t(formatLabel(entry.action))}
                          </span>
                        </td>
                        <td>{entry.actor_username ?? t("System")}</td>
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
