import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Bell,
  Boxes,
  CheckCircle2,
  ClipboardList,
  Info,
  Monitor,
  PackageCheck,
  RadioTower,
} from "lucide-react";

import { getDashboardSummary, type DashboardSummary } from "../api/dashboard";
import { useAuth } from "../auth/AuthProvider";
import { AdminBadge } from "../components/AppLayout";

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

function formatLabel(value: string): string {
  return value
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
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
      copy: "All customer orders currently tracked by the platform.",
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
      title: "Ready for pickup",
      value: getCount(summary.orders_by_status, "ready_for_pickup"),
      copy: "Orders waiting for customer collection.",
      tone: "neutral",
      icon: CheckCircle2,
    },
    {
      title: "Expired orders",
      value: getCount(summary.orders_by_status, "expired"),
      copy: "Orders that missed the pickup window.",
      tone: getCount(summary.orders_by_status, "expired") > 0 ? "danger" : "success",
      icon: AlertTriangle,
    },
    {
      title: "Locker stations",
      value: summary.totals.locker_stations,
      copy: "Physical locker locations managed by SmartDrop.",
      tone: "neutral",
      icon: Boxes,
    },
    {
      title: "Available drawers",
      value: getCount(summary.drawers_by_status, "available"),
      copy: "Drawers currently ready for assignment.",
      tone: "success",
      icon: PackageCheck,
    },
    {
      title: "Unhealthy devices",
      value: summary.action_required.unhealthy_devices,
      copy: "Devices that are stale, inactive, or have never connected.",
      tone:
        summary.action_required.unhealthy_devices > 0
          ? "warning"
          : "success",
      icon: Monitor,
    },
    {
      title: "Pending notifications",
      value: summary.action_required.pending_notifications,
      copy: "Notifications waiting for delivery processing.",
      tone:
        summary.action_required.pending_notifications > 0
          ? "warning"
          : "success",
      icon: Bell,
    },
  ];
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

export function DashboardPage() {
  const { tokens } = useAuth();
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function loadDashboardSummary() {
      if (!tokens?.access) {
        setError("Missing access token. Please sign in again.");
        setLoading(false);
        return;
      }

      setLoading(true);
      setError(null);

      try {
        const data = await getDashboardSummary(tokens.access);
        if (active) {
          setSummary(data);
        }
      } catch (caughtError) {
        if (active) {
          setError(
            caughtError instanceof Error
              ? caughtError.message
              : "Could not load dashboard summary.",
          );
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    void loadDashboardSummary();

    return () => {
      active = false;
    };
  }, [tokens?.access]);

  const metricCards = useMemo(
    () => (summary ? buildMetricCards(summary) : []),
    [summary],
  );

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Phase 2</p>
          <h1 className="page-title">Operations Dashboard</h1>
          <p className="page-description">
            Live operational summary from the SmartDrop backend.
          </p>
        </div>
        <AdminBadge />
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
        <>
          <section aria-labelledby="summary-heading">
            <div className="section-title-row">
              <div>
                <h2 id="summary-heading" className="section-heading">
                  Live operations summary
                </h2>
                <p className="section-subtitle">
                  Last generated at{" "}
                  {new Date(summary.generated_at).toLocaleString()}.
                </p>
              </div>
            </div>

            <div className="module-grid">
              {metricCards.map(({ title, value, copy, icon: Icon, tone }) => (
                <article
                  className={`metric-card metric-card-${tone}`}
                  key={title}
                  data-testid={`card-metric-${title
                    .toLowerCase()
                    .replace(/\s+/g, "-")}`}
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
            </div>
          </section>

          <section aria-labelledby="status-heading">
            <h2 id="status-heading" className="section-heading">
              Status breakdown
            </h2>
            <p className="section-subtitle">
              Counts grouped by backend status fields.
            </p>

            <div className="status-grid">
              <StatusList title="Orders" data={summary.orders_by_status} />
              <StatusList
                title="Locker stations"
                data={summary.locker_stations_by_status}
              />
              <StatusList title="Drawers" data={summary.drawers_by_status} />
              <StatusList
                title="Devices"
                data={summary.devices_by_connection_status}
              />
              <StatusList
                title="Notifications"
                data={summary.notifications_by_delivery_status}
              />
              <StatusList
                title="Action required"
                data={summary.action_required}
              />
            </div>
          </section>

          <div className="scope-note">
            <Info size={15} />
            <span>
              <strong>Phase 2 dashboard.</strong> This page is now connected to
              the backend dashboard summary endpoint.
            </span>
          </div>
        </>
      )}
    </>
  );
}