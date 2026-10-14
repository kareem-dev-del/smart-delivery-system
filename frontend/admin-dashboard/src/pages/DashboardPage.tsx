import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Bell,
  Boxes,
  CheckCircle2,
  ClipboardList,
  FileClock,
  Monitor,
  PackageCheck,
  RadioTower,
  ShieldCheck,
  Wifi,
} from "lucide-react";

import { getAuditLog, type AuditLogEntry } from "../api/audit";
import { getDashboardSummary, type DashboardSummary } from "../api/dashboard";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";

interface MetricCard {
  title: string;
  value: number;
  copy: string;
  tone: "neutral" | "success" | "warning" | "danger";
  icon: typeof ClipboardList;
}

function getCount(source: Record<string, number>, key: string): number {
  return source[key] ?? 0;
}

function buildMetricCards(summary: DashboardSummary): MetricCard[] {
  const activeOrders =
    getCount(summary.orders_by_status, "awaiting_locker") +
    getCount(summary.orders_by_status, "assigned") +
    getCount(summary.orders_by_status, "ready_for_pickup");

  return [
    {
      title: "Total orders",
      value: summary.totals.orders,
      copy: "All customer orders tracked by the platform.",
      tone: "neutral",
      icon: ClipboardList,
    },
    {
      title: "Active orders",
      value: activeOrders,
      copy: "Orders still moving through the locker workflow.",
      tone: activeOrders > 0 ? "warning" : "success",
      icon: PackageCheck,
    },
    {
      title: "Available drawers",
      value: getCount(summary.drawers_by_status, "available"),
      copy: "Drawers currently ready for assignment.",
      tone: "success",
      icon: Boxes,
    },
    {
      title: "Unhealthy devices",
      value: summary.action_required.unhealthy_devices,
      copy: "Devices that need operational review.",
      tone:
        summary.action_required.unhealthy_devices > 0 ? "warning" : "success",
      icon: Monitor,
    },
  ];
}

function getSystemHealth(summary: DashboardSummary): {
  label: string;
  copy: string;
  tone: "success" | "warning" | "danger";
} {
  const actionRequired =
    summary.action_required.awaiting_locker_orders +
    summary.action_required.expired_orders +
    summary.action_required.failed_notifications +
    summary.action_required.pending_notifications +
    summary.action_required.unhealthy_devices;

  if (summary.action_required.expired_orders > 0) {
    return {
      label: "Needs urgent review",
      copy: `${summary.action_required.expired_orders} expired order needs attention.`,
      tone: "danger",
    };
  }

  if (actionRequired > 0) {
    return {
      label: "Needs attention",
      copy: `${actionRequired} operational item${actionRequired === 1 ? "" : "s"} waiting.`,
      tone: "warning",
    };
  }

  return {
    label: "Healthy",
    copy: "No urgent operational actions right now.",
    tone: "success",
  };
}

function WorkflowStep({
  label,
  value,
}: {
  label: string;
  value: number;
}) {
  return (
    <div className={`workflow-step ${value > 0 ? "workflow-step-active" : ""}`}>
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function StatusList({
  title,
  data,
}: {
  title: string;
  data: Record<string, number>;
}) {
  return (
    <article className="status-panel">
      <h3 className="status-panel-title">{title}</h3>
      <div className="status-list">
        {Object.entries(data).map(([key, value]) => (
          <div className="status-row" key={key}>
            <span>{formatLabel(key)}</span>
            <strong>{value}</strong>
          </div>
        ))}
      </div>
    </article>
  );
}

function ActivityItem({ entry }: { entry: AuditLogEntry }) {
  return (
    <div className="activity-item">
      <div className="activity-icon">
        <FileClock size={15} />
      </div>
      <div>
        <strong>{formatLabel(entry.action)}</strong>
        <p>
          {entry.actor_username ?? "System"} on {entry.target_type}{" "}
          <span className="mono-cell">{entry.target_id.slice(0, 8)}</span>
        </p>
        <span>{formatDate(entry.created_at)}</span>
      </div>
    </div>
  );
}


function ActionRequiredRow({
  label,
  value,
}: {
  label: string;
  value: number;
}) {
  return (
    <div className={value > 0 ? "action-row action-row-warning" : "action-row"}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export function DashboardPage() {
  const { tokens } = useAuth();
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [activity, setActivity] = useState<AuditLogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadDashboard() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const [summaryData, auditData] = await Promise.all([
        getDashboardSummary(tokens.access),
        getAuditLog(tokens.access),
      ]);

      setSummary(summaryData);
      setActivity(auditData.results.slice(0, 5));
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load dashboard.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadDashboard();
  }, [tokens?.access]);

  const metricCards = useMemo(
    () => (summary ? buildMetricCards(summary) : []),
    [summary],
  );

  const health = useMemo(
    () => (summary ? getSystemHealth(summary) : null),
    [summary],
  );

  return (
    <>
      <div className="dashboard-intro dashboard-hero">
        <div>
          <p className="eyebrow">Network control / Command center</p>
          <h1 className="page-title">Operations Dashboard</h1>
          <p className="page-description">
            Live SmartDrop control center for orders, lockers, devices, and
            operational actions.
          </p>
        </div>

        {health && (
          <div className={`health-card health-card-${health.tone}`}>
            <ShieldCheck size={18} />
            <div>
              <strong>{health.label}</strong>
              <span>{health.copy}</span>
            </div>
          </div>
        )}
      </div>

      {loading && (
        <div className="scope-note">
          <RadioTower size={15} />
          <span>Loading live operational data...</span>
        </div>
      )}

      {error && (
        <div className="scope-note error-note">
          <AlertTriangle size={15} />
          <span>{error}</span>
        </div>
      )}

      {!loading && !error && summary && (
        <div className="dashboard-control-grid">
          <section className="ops-pulse-panel">
            <div className="ops-pulse-item">
              <Wifi size={17} />
              <div>
                <span>Stations online</span>
                <strong>
                  {getCount(summary.locker_stations_by_status, "online")}
                </strong>
              </div>
            </div>

            <div className="ops-pulse-item">
              <Monitor size={17} />
              <div>
                <span>Unhealthy devices</span>
                <strong>{summary.action_required.unhealthy_devices}</strong>
              </div>
            </div>

            <div className="ops-pulse-item">
              <Bell size={17} />
              <div>
                <span>Pending notifications</span>
                <strong>{summary.action_required.pending_notifications}</strong>
              </div>
            </div>

            <div className="ops-pulse-item">
              <AlertTriangle size={17} />
              <div>
                <span>Expired orders</span>
                <strong>{summary.action_required.expired_orders}</strong>
              </div>
            </div>
          </section>

          <section className="module-grid dashboard-metrics">
            {metricCards.map(({ title, value, copy, icon: Icon, tone }) => (
              <article
                className={`metric-card metric-card-${tone}`}
                key={title}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <Icon size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{value}</span>
                </div>
                <h3 className="module-title">{title}</h3>
                <p className="module-copy">{copy}</p>
              </article>
            ))}
          </section>

         <section className="dashboard-bottom-grid">
            <div className="dashboard-stack">
              <article className="orders-summary-panel">
                <h2 className="section-heading">Order workflow</h2>
                <p className="section-subtitle">
                  Current order movement through the locker lifecycle.
                </p>

                <div className="workflow-strip">
                  <WorkflowStep
                    label="Pending"
                    value={getCount(summary.orders_by_status, "pending")}
                  />
                  <WorkflowStep
                    label="Awaiting locker"
                    value={getCount(summary.orders_by_status, "awaiting_locker")}
                  />
                  <WorkflowStep
                    label="Assigned"
                    value={getCount(summary.orders_by_status, "assigned")}
                  />
                  <WorkflowStep
                    label="Ready"
                    value={getCount(summary.orders_by_status, "ready_for_pickup")}
                  />
                  <WorkflowStep
                    label="Collected"
                    value={getCount(summary.orders_by_status, "collected")}
                  />
                </div>
              </article>

              <article className="orders-summary-panel">
                <h2 className="section-heading">Locker network health</h2>
                <p className="section-subtitle">
                  Stations, drawers, and devices grouped by backend status.
                </p>

                <div className="status-grid dashboard-status-grid">
                  <StatusList
                    title="Stations"
                    data={summary.locker_stations_by_status}
                  />
                  <StatusList title="Drawers" data={summary.drawers_by_status} />
                  <StatusList
                    title="Devices"
                    data={summary.devices_by_connection_status}
                  />
                </div>
              </article>
            </div>

            <div className="dashboard-stack">
              <article className="orders-summary-panel">
                <h2 className="section-heading">Action required</h2>
                <p className="section-subtitle">
                  Operational items that may need an admin decision.
                </p>

                <div className="action-list">
                  <ActionRequiredRow
                    label="Awaiting locker assignment"
                    value={summary.action_required.awaiting_locker_orders}
                  />
                  <ActionRequiredRow
                    label="Expired orders"
                    value={summary.action_required.expired_orders}
                  />
                  <ActionRequiredRow
                    label="Failed notifications"
                    value={summary.action_required.failed_notifications}
                  />
                  <ActionRequiredRow
                    label="Pending notifications"
                    value={summary.action_required.pending_notifications}
                  />
                  <ActionRequiredRow
                    label="Unhealthy devices"
                    value={summary.action_required.unhealthy_devices}
                  />
                </div>
              </article>

              <article className="orders-summary-panel">
                <h2 className="section-heading">Recent activity</h2>
                <p className="section-subtitle">
                  Latest admin actions from the audit trail.
                </p>

                {activity.length === 0 ? (
                  <div className="empty-panel compact-empty">
                    <CheckCircle2 size={18} />
                    <span>No recent activity found.</span>
                  </div>
                ) : (
                  <div className="activity-list">
                    {activity.map((entry) => (
                      <ActivityItem entry={entry} key={entry.id} />
                    ))}
                  </div>
                )}
              </article>
            </div>
          </section>
        </div>
      )}
    </>
  );
}