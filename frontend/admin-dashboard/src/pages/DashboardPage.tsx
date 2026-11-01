import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowRight,
  ArrowUpRight,
  Bell,
  Boxes,
  CheckCircle2,
  ClipboardList,
  FileClock,
  Monitor,
  Package,
  PackageCheck,
  PackagePlus,
  RadioTower,
  RotateCw,
  ShieldCheck,
  Wifi,
} from "lucide-react";
import { Link } from "react-router-dom";

import { getAuditLog, type AuditLogEntry } from "../api/audit";
import { getDashboardSummary, type DashboardSummary } from "../api/dashboard";
import { getAdminNotifications, type AdminNotification } from "../api/notifications";
import { getAdminOrders, type AdminOrder } from "../api/orders";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";

const statusColors: Record<string, string> = {
  pending: "#f59e0b",
  awaiting_locker: "#f97316",
  assigned: "#3978f6",
  ready_for_pickup: "#14b8a6",
  collected: "#10a66a",
  expired: "#ef4444",
  cancelled: "#94a3b8",
  returned: "#8b5cf6",
  online: "#10a66a",
  offline: "#ef4444",
  maintenance: "#f59e0b",
  available: "#10a66a",
  reserved: "#3978f6",
  occupied: "#8b5cf6",
  out_of_service: "#ef4444",
  return_pending: "#f59e0b",
  stale: "#f59e0b",
  never_connected: "#ef4444",
  inactive: "#94a3b8",
};

function getCount(source: Record<string, number>, key: string): number {
  return source[key] ?? 0;
}

function useGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

function getSystemHealth(summary: DashboardSummary) {
  const critical =
    summary.action_required.expired_orders +
    summary.action_required.failed_notifications;
  const attention =
    critical +
    summary.action_required.awaiting_locker_orders +
    summary.action_required.pending_notifications +
    summary.action_required.unhealthy_devices;

  if (critical > 0) {
    return {
      label: "Needs attention",
      copy: `${critical} critical operational item${critical === 1 ? "" : "s"} to review.`,
      tone: "danger",
    } as const;
  }
  if (attention > 0) {
    return {
      label: "System online",
      copy: `${attention} operational item${attention === 1 ? "" : "s"} waiting.`,
      tone: "warning",
    } as const;
  }
  return {
    label: "System online",
    copy: "All monitored services are running smoothly.",
    tone: "success",
  } as const;
}

function MetricCard({
  title,
  value,
  hint,
  icon: Icon,
  tone,
}: {
  title: string;
  value: number;
  hint: string;
  icon: typeof ClipboardList;
  tone: string;
}) {
  return (
    <article className={`dashboard-stat dashboard-stat-${tone}`}>
      <div className="dashboard-stat-icon"><Icon size={18} /></div>
      <div className="dashboard-stat-content">
        <span>{title}</span>
        <strong>{value}</strong>
        <small>{hint}</small>
      </div>
    </article>
  );
}

function StatusDonut({
  title,
  data,
  centerLabel,
}: {
  title: string;
  data: Record<string, number>;
  centerLabel: string;
}) {
  const { t } = useLocale();
  const chartData = Object.entries(data).map(([key, value]) => ({
    name: t(formatLabel(key)),
    key,
    value,
  }));
  const populated = chartData.filter((item) => item.value > 0);
  const total = chartData.reduce((sum, item) => sum + item.value, 0);
  let stop = 0;
  const gradient = populated.map((item) => {
    const end = stop + (item.value / Math.max(1, total)) * 100;
    const segment = `${statusColors[item.key] ?? "#64748b"} ${stop}% ${end}%`;
    stop = end;
    return segment;
  }).join(", ");

  return (
    <article className="dashboard-panel dashboard-donut-panel">
      <div className="dashboard-panel-title-row">
        <h2>{title}</h2>
      </div>
      <div className="dashboard-donut-content">
        <div className="dashboard-donut-chart">
          {total > 0 ? (
            <>
              <div className="dashboard-donut-graphic" style={{ backgroundImage: `conic-gradient(${gradient})` }} />
              <div className="dashboard-donut-center" aria-hidden="true">
                <strong>{total}</strong>
                <span>{centerLabel}</span>
              </div>
            </>
          ) : (
            <div className="dashboard-donut-empty"><span>0</span></div>
          )}
        </div>
        <div className="dashboard-legend">
          {chartData.map((item) => (
            <div className="dashboard-legend-row" key={item.key}>
              <span className="dashboard-legend-label">
                <i style={{ backgroundColor: statusColors[item.key] ?? "#64748b" }} />
                {item.name}
              </span>
              <strong>{item.value}</strong>
            </div>
          ))}
          {total === 0 && <p className="dashboard-chart-empty">{t("No records yet")}</p>}
        </div>
      </div>
    </article>
  );
}

function OrderOverview({ summary }: { summary: DashboardSummary }) {
  const { t } = useLocale();
  const rows = [
    { key: "collected", label: t("Collected") },
    { key: "ready_for_pickup", label: t("Ready for pickup") },
    { key: "assigned", label: t("Assigned") },
    { key: "awaiting_locker", label: t("Awaiting locker") },
    { key: "pending", label: t("Pending") },
    { key: "expired", label: t("Expired") },
  ].map((item) => ({ ...item, value: getCount(summary.orders_by_status, item.key) }));
  const max = Math.max(1, ...rows.map((row) => row.value));

  return (
    <article className="dashboard-panel dashboard-overview-panel">
      <div className="dashboard-panel-title-row">
        <div>
          <h2>{t("Orders overview")}</h2>
          <p>{t("Current order distribution across the delivery workflow.")}</p>
        </div>
        <Link to="/orders" className="dashboard-view-link">{t("View all")} <ArrowRight size={14} /></Link>
      </div>
      <div className="dashboard-overview-bars">
        {rows.map((row) => (
          <div className="dashboard-overview-row" key={row.key}>
            <span>{row.label}</span>
            <div className="dashboard-overview-track">
              <i
                style={{
                  width: `${row.value === 0 ? 0 : Math.max(5, (row.value / max) * 100)}%`,
                  backgroundColor: statusColors[row.key],
                }}
              />
            </div>
            <strong>{row.value}</strong>
          </div>
        ))}
      </div>
      <p className="dashboard-chart-footnote">{t("Live totals from the backend; historical daily trends are not available yet.")}</p>
    </article>
  );
}

function QuickActions() {
  const { t } = useLocale();
  const actions = [
    { label: t("Add product"), to: "/products", icon: PackagePlus, primary: true },
    { label: t("Add locker station"), to: "/lockers", icon: Boxes },
    { label: t("Review devices"), to: "/devices", icon: Monitor },
    { label: t("View all orders"), to: "/orders", icon: Package },
  ];

  return (
    <article className="dashboard-panel dashboard-quick-panel">
      <div className="dashboard-panel-title-row"><h2>{t("Quick actions")}</h2></div>
      <div className="dashboard-quick-list">
        {actions.map(({ label, to, icon: Icon, primary }) => (
          <Link key={to} to={to} className={`dashboard-quick-link${primary ? " is-primary" : ""}`}>
            <Icon size={15} />
            <span>{label}</span>
            <ArrowUpRight size={14} />
          </Link>
        ))}
      </div>
    </article>
  );
}

function ActivityItem({ entry }: { entry: AuditLogEntry }) {
  const { t } = useLocale();
  return (
    <div className="dashboard-feed-item">
      <div className="dashboard-feed-icon"><FileClock size={15} /></div>
      <div className="dashboard-feed-copy">
        <strong>{t(formatLabel(entry.action))}</strong>
        <span>{entry.actor_username ?? t("System")} · {entry.target_type} {entry.target_id.slice(0, 8)}</span>
        <small>{formatDate(entry.created_at)}</small>
      </div>
    </div>
  );
}

function LatestOrders({ orders }: { orders: AdminOrder[] }) {
  const { t } = useLocale();
  return (
    <article className="dashboard-panel dashboard-latest-orders">
      <div className="dashboard-panel-title-row">
        <div><h2>{t("Latest orders")}</h2><p>{t("Most recently created orders from the network.")}</p></div>
        <Link to="/orders" className="dashboard-view-link">{t("View all")} <ArrowRight size={14} /></Link>
      </div>
      {orders.length === 0 ? (
        <div className="dashboard-empty"><Package size={17} /><span>{t("No orders yet. New customer orders will appear here.")}</span></div>
      ) : (
        <div className="dashboard-table-wrap">
          <table className="dashboard-table">
            <thead><tr><th>{t("Order ID")}</th><th>{t("Customer")}</th><th>{t("Total")}</th><th>{t("Status")}</th><th>{t("Created")}</th><th /></tr></thead>
            <tbody>
              {orders.slice(0, 5).map((order) => (
                <tr key={order.public_id}>
                  <td><Link to={`/orders/${order.public_id}`} className="dashboard-order-id">#{order.public_id.slice(0, 12)}</Link></td>
                  <td>{order.customer_username}</td>
                  <td>{order.total_amount}</td>
                  <td><span className={`dashboard-status-pill status-${order.status}`}>{t(formatLabel(order.status))}</span></td>
                  <td>{formatDate(order.created_at)}</td>
                  <td><Link to={`/orders/${order.public_id}`} className="dashboard-row-action">{t("View")}</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </article>
  );
}

function RecentNotifications({ notifications }: { notifications: AdminNotification[] }) {
  const { t } = useLocale();
  return (
    <article className="dashboard-panel dashboard-feed-panel">
      <div className="dashboard-panel-title-row">
        <div><h2>{t("Recent notifications")}</h2><p>{t("Latest messages created by the system.")}</p></div>
        <Link to="/notifications" className="dashboard-view-link">{t("View all")} <ArrowRight size={14} /></Link>
      </div>
      {notifications.length === 0 ? (
        <div className="dashboard-empty"><Bell size={17} /><span>{t("No notifications have been generated.")}</span></div>
      ) : (
        <div className="dashboard-feed-list">
          {notifications.slice(0, 5).map((notification) => (
            <div className="dashboard-feed-item" key={notification.id}>
              <div className={`dashboard-feed-icon notification-${notification.delivery_status}`}><Bell size={15} /></div>
              <div className="dashboard-feed-copy">
                <strong>{notification.title}</strong>
                <span>{notification.recipient_username} · {t(formatLabel(notification.delivery_status))}</span>
                <small>{formatDate(notification.created_at)}</small>
              </div>
            </div>
          ))}
        </div>
      )}
    </article>
  );
}

export function DashboardPage() {
  const { t, locale } = useLocale();
  const { tokens, user } = useAuth();
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [activity, setActivity] = useState<AuditLogEntry[]>([]);
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [notifications, setNotifications] = useState<AdminNotification[]>([]);
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
      const [summaryData, auditData, ordersData, notificationsData] = await Promise.all([
        getDashboardSummary(tokens.access),
        getAuditLog(tokens.access),
        getAdminOrders(tokens.access),
        getAdminNotifications(tokens.access),
      ]);
      setSummary(summaryData);
      setActivity(auditData.results.slice(0, 5));
      setOrders(ordersData.results.slice(0, 5));
      setNotifications(notificationsData.results.slice(0, 5));
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not load dashboard.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadDashboard();
  }, [tokens?.access]);

  const health = useMemo(() => summary ? getSystemHealth(summary) : null, [summary]);
  const activeOrders = summary
    ? getCount(summary.orders_by_status, "pending") +
      getCount(summary.orders_by_status, "awaiting_locker") +
      getCount(summary.orders_by_status, "assigned") +
      getCount(summary.orders_by_status, "ready_for_pickup")
    : 0;
  const displayName = user?.first_name || user?.username || "Admin";
  const greeting = useGreeting();
  const attentionCount = summary
    ? summary.action_required.expired_orders + summary.action_required.failed_notifications +
      summary.action_required.awaiting_locker_orders + summary.action_required.pending_notifications +
      summary.action_required.unhealthy_devices
    : 0;
  const criticalCount = summary
    ? summary.action_required.expired_orders + summary.action_required.failed_notifications
    : 0;
  const healthCopy = !health
    ? t("Loading system checks...")
    : locale === "ar"
      ? criticalCount > 0
        ? `هناك ${criticalCount} عناصر تشغيلية حرجة تحتاج إلى مراجعة.`
        : attentionCount > 0
          ? `هناك ${attentionCount} عناصر تشغيلية في الانتظار.`
          : t("All monitored services are running smoothly.")
      : health.copy;
  const dateLabel = new Date().toLocaleDateString(locale === "ar" ? "ar-EG" : "en-US", {
    month: "short", day: "numeric", year: "numeric",
  });

  return (
    <div className="dashboard-page">
      <header className="dashboard-welcome">
        <div>
          <p className="eyebrow">{t("Network control / Command center")}</p>
          <h1>{t(greeting)}, {displayName}!</h1>
          <p>{t("Here's what's happening across your delivery network.")}</p>
        </div>
        <div className="dashboard-welcome-right">
          <div className="dashboard-date"><span>{dateLabel}</span><small>{t("Live overview")}</small></div>
          <div className={`dashboard-system-status dashboard-system-${health?.tone ?? "success"}`}>
            <i />
            <div><strong>{t(health?.label ?? "Connecting")}</strong><span>{healthCopy}</span></div>
            <RadioTower size={19} />
          </div>
          <button className="dashboard-refresh" type="button" onClick={() => void loadDashboard()} disabled={loading} aria-label={t("Refresh dashboard")}>
            <RotateCw size={15} className={loading ? "spin" : undefined} />
          </button>
        </div>
      </header>

      {loading && <div className="dashboard-loading"><RadioTower size={15} /> {t("Loading live operational data...")}</div>}
      {error && <div className="scope-note error-note"><AlertTriangle size={15} /><span>{error}</span><button type="button" onClick={() => void loadDashboard()}>{t("Try again")}</button></div>}

      {!loading && !error && summary && (
        <>
          <section className="dashboard-stats-grid" aria-label={t("Key operational metrics")}>
            <MetricCard title={t("Total orders")} value={summary.totals.orders} hint={t("All customer orders")} icon={Package} tone="blue" />
            <MetricCard title={t("Collected")} value={getCount(summary.orders_by_status, "collected")} hint={t("Completed pickups")} icon={PackageCheck} tone="green" />
            <MetricCard title={t("In progress")} value={activeOrders} hint={t("Moving through fulfillment")} icon={Boxes} tone="amber" />
            <MetricCard title={t("Pending")} value={getCount(summary.orders_by_status, "pending")} hint={t("Awaiting processing")} icon={ClipboardList} tone="red" />
            <MetricCard title={t("Failed notifications")} value={summary.action_required.failed_notifications} hint={t("Delivery needs review")} icon={Bell} tone="violet" />
          </section>

          <section className="dashboard-overview-grid">
            <OrderOverview summary={summary} />
            <StatusDonut title={t("Order status")} data={summary.orders_by_status} centerLabel={t("Orders")} />
            <QuickActions />
          </section>

          <section className="dashboard-lower-grid">
            <div className="dashboard-main-column">
              <div className="dashboard-network-grid">
                <StatusDonut title={t("Locker stations")} data={summary.locker_stations_by_status} centerLabel={t("Stations")} />
                <StatusDonut title={t("Drawer status")} data={summary.drawers_by_status} centerLabel={t("Drawers")} />
                <StatusDonut title={t("Device status")} data={summary.devices_by_connection_status} centerLabel={t("Devices")} />
              </div>
              <LatestOrders orders={orders} />
            </div>
            <div className="dashboard-side-column">
              <article className="dashboard-panel dashboard-feed-panel">
                <div className="dashboard-panel-title-row">
                  <div><h2>{t("Recent activity")}</h2><p>{t("Latest admin actions from the audit trail.")}</p></div>
                  <Link to="/audit-log" className="dashboard-view-link">{t("View all")} <ArrowRight size={14} /></Link>
                </div>
                {activity.length === 0 ? (
                  <div className="dashboard-empty"><CheckCircle2 size={17} /><span>{t("No admin activity recorded yet.")}</span></div>
                ) : (
                  <div className="dashboard-feed-list">{activity.map((entry) => <ActivityItem entry={entry} key={entry.id} />)}</div>
                )}
              </article>
              <RecentNotifications notifications={notifications} />
            </div>
          </section>
          <p className="dashboard-updated dashboard-footer-updated">{t("Summary generated")} {formatDate(summary.generated_at)}. <button type="button" onClick={() => void loadDashboard()}>{t("Refresh data")}</button></p>
        </>
      )}
    </div>
  );
}
