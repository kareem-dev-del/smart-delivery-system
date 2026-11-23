import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  ClipboardList,
  ExternalLink,
  LoaderCircle,
  Package,
  Route,
  RefreshCw,
  Search,
  SlidersHorizontal,
} from "lucide-react";

import { getDashboardSummary, type DashboardSummary } from "../api/dashboard";
import {
  applyCourierAssignmentPlan,
  getAdminOrders,
  getCourierAssignmentPlan,
  type AdminOrder,
  type CourierAssignmentPlan,
} from "../api/orders";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";
import { useLocale } from "../i18n/LocaleProvider";
import { StyledSelect } from "../components/StyledSelect";
import { useAutoRefresh } from "../hooks/use-auto-refresh";

const PAGE_SIZE = 20;
const orderStatuses = [
  "pending",
  "awaiting_locker",
  "assigned",
  "ready_for_pickup",
  "collected",
  "expired",
  "cancelled",
  "returned",
];

function countStatus(summary: DashboardSummary | null, status: string): number {
  return summary?.orders_by_status[status] ?? 0;
}

function getOrderItemsSummary(order: AdminOrder): string {
  if (order.items.length === 0) return document.documentElement.lang === "ar" ? "لا توجد منتجات" : "No items";
  return order.items.map((item) => `${item.quantity} × ${item.product_name}`).join(", ");
}

export function OrdersPage() {
  const { t, locale } = useLocale();
  const { tokens } = useAuth();
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [count, setCount] = useState(0);
  const [hasNext, setHasNext] = useState(false);
  const [hasPrevious, setHasPrevious] = useState(false);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [assignmentPlan, setAssignmentPlan] = useState<CourierAssignmentPlan | null>(null);
  const [planLoading, setPlanLoading] = useState(false);
  const [planApplying, setPlanApplying] = useState(false);
  const [planMessage, setPlanMessage] = useState<string | null>(null);

  async function previewCourierPlan() {
    if (!tokens?.access) return;
    setPlanLoading(true);
    setPlanMessage(null);
    try {
      setAssignmentPlan(await getCourierAssignmentPlan(tokens.access));
    } catch (caughtError) {
      setPlanMessage(caughtError instanceof Error ? caughtError.message : t("Could not create assignment plan."));
    } finally {
      setPlanLoading(false);
    }
  }

  async function confirmCourierPlan() {
    if (!tokens?.access || !assignmentPlan) return;
    setPlanApplying(true);
    setPlanMessage(null);
    try {
      const result = await applyCourierAssignmentPlan(
        tokens.access,
        assignmentPlan.assignments.map(({ order_public_id, courier_id }) => ({ order_public_id, courier_id })),
      );
      setAssignmentPlan(null);
      setPlanMessage(`${t("Assigned orders")}: ${result.applied_count}`);
      await loadOrders(true);
    } catch (caughtError) {
      setPlanMessage(caughtError instanceof Error ? caughtError.message : t("Could not apply assignment plan."));
    } finally {
      setPlanApplying(false);
    }
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 280);
    return () => window.clearTimeout(timer);
  }, [searchInput]);

  async function loadOrders(silent = false) {
    if (!tokens?.access) {
      setError("Your session has expired. Sign in again to load orders.");
      setLoading(false);
      return;
    }
    if (!silent) setLoading(true);
    setError(null);
    try {
      const [orderData, summaryData] = await Promise.all([
        getAdminOrders(tokens.access, {
          status: statusFilter || undefined,
          search,
          page,
          pageSize: PAGE_SIZE,
        }),
        getDashboardSummary(tokens.access),
      ]);
      setOrders(orderData.results);
      setCount(orderData.count);
      setHasNext(Boolean(orderData.next));
      setHasPrevious(Boolean(orderData.previous));
      setSummary(summaryData);
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not load orders.");
    } finally {
      if (!silent) setLoading(false);
    }
  }

  useEffect(() => {
    void loadOrders();
  }, [tokens?.access, statusFilter, search, page]);

  useAutoRefresh(() => loadOrders(true), 15_000, Boolean(tokens?.access));

  const metrics = useMemo(() => {
    const inProgress = ["pending", "awaiting_locker", "assigned", "ready_for_pickup"]
      .reduce((total, status) => total + countStatus(summary, status), 0);
    const needsReview = countStatus(summary, "expired") + countStatus(summary, "cancelled");
    return {
      total: summary?.totals.orders ?? count,
      inProgress,
      ready: countStatus(summary, "ready_for_pickup"),
      completed: countStatus(summary, "collected"),
      needsReview,
    };
  }, [summary, count]);

  const firstItem = count === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const lastItem = Math.min(page * PAGE_SIZE, count);

  return (
    <div className="orders-workspace">
      <header className="orders-page-heading">
        <div>
          <p className="eyebrow">{t("Network control / Orders")}</p>
          <h1 className="page-title">{t("Orders")}</h1>
          <p className="page-description">{t("Monitor every order moving through the SmartDrop network.")}</p>
        </div>
        <div className="orders-heading-actions">
          <button className="orders-plan-button" type="button" onClick={() => void previewCourierPlan()} disabled={planLoading || !tokens?.access}>
            {planLoading ? <LoaderCircle size={15} className="spin" /> : <Route size={15} />}
            {t("Plan courier assignments")}
          </button>
          <button className="orders-refresh-button" type="button" onClick={() => void loadOrders()} disabled={loading}>
            <RefreshCw size={15} className={loading ? "spin" : undefined} />
            {t("Refresh")}
          </button>
        </div>
      </header>

      {planMessage && <div className="scope-note" role="status">{planMessage}</div>}

      {error && (
        <div className="scope-note error-note" role="alert">
          <AlertTriangle size={16} /><span>{error}</span>
          <button type="button" onClick={() => void loadOrders()}>{t("Try again")}</button>
        </div>
      )}

      <section className="orders-command-panel" aria-label={t("Order summary")}>
        <div className="orders-command-intro">
          <span className="orders-command-icon"><ClipboardList size={18} /></span>
          <div>
            <p className="eyebrow">{t("Orders command")}</p>
            <h2>{t("Order operations")}</h2>
            <span>{t("Current workload and fulfillment status.")}</span>
          </div>
        </div>

        <div className="orders-command-metrics">
          <div><span>{t("Total orders")}</span><strong>{metrics.total}</strong></div>
          <div><span>{t("In progress")}</span><strong>{metrics.inProgress}</strong></div>
          <div><span>{t("Ready for pickup")}</span><strong>{metrics.ready}</strong></div>
          <div><span>{t("Collected")}</span><strong>{metrics.completed}</strong></div>
        </div>

        <div className={`orders-focus ${metrics.needsReview > 0 ? "orders-focus-warning" : "orders-focus-clear"}`}>
          <strong>{t(metrics.needsReview > 0 ? "Needs review" : "All clear")}</strong>
          <span>{metrics.needsReview > 0 ? (locale === "ar" ? `${metrics.needsReview} طلبات ملغاة أو منتهية.` : `${metrics.needsReview} cancelled or expired orders.`) : t("No expired or cancelled orders right now.")}</span>
        </div>
      </section>

      <section className="orders-table-panel" aria-labelledby="orders-table-heading">
        <div className="orders-list-heading">
          <div>
            <h2 id="orders-table-heading">{t("Order list")}</h2>
            <p>{t("Search and filter the complete order register.")}</p>
          </div>
          <span className="orders-result-count">{locale === "ar" ? `${count} طلب` : `${count} total`}</span>
        </div>

        <div className="orders-toolbar">
          <label className="orders-search-field">
            <Search size={16} />
            <input
              type="search"
              value={searchInput}
              onChange={(event) => setSearchInput(event.target.value)}
              placeholder={t("Search order, customer, courier, locker...")}
              aria-label={t("Search orders")}
            />
          </label>
          <div className="orders-status-filter">
            <SlidersHorizontal size={15} />
            <StyledSelect
              className="orders-status-select-control"
              value={statusFilter}
              onChange={(value) => { setStatusFilter(value); setPage(1); }}
              ariaLabel={t("Filter by order status")}
              options={[
                { value: "", label: t("All statuses") },
                ...orderStatuses.map((status) => ({ value: status, label: t(formatLabel(status)) })),
              ]}
            />
          </div>
        </div>

        {loading ? (
          <div className="orders-empty-state"><RefreshCw size={18} className="spin" /><span>{t("Loading orders...")}</span></div>
        ) : orders.length === 0 ? (
          <div className="orders-empty-state">
            <span className="orders-empty-icon"><Package size={19} /></span>
            <strong>{t(search || statusFilter ? "No matching orders" : "No orders yet")}</strong>
            <span>{t(search || statusFilter ? "Try another search or clear the status filter." : "Customer orders will appear here when they are created.")}</span>
          </div>
        ) : (
          <div className="orders-table-scroll">
            <table className="orders-data-table">
              <thead>
                <tr><th>{t("Order")}</th><th>{t("Status")}</th><th>{t("Customer")}</th><th>{t("Courier")}</th><th>{t("Locker / drawer")}</th><th>{t("Total")}</th><th>{t("Created")}</th><th aria-label={t("Actions")} /></tr>
              </thead>
              <tbody>
                {orders.map((order) => (
                  <tr key={order.public_id}>
                    <td>
                      <Link className="orders-id-link" to={`/orders/${order.public_id}`}>#{order.public_id.slice(0, 8)}</Link>
                      <span className="orders-item-summary">{getOrderItemsSummary(order)}</span>
                    </td>
                    <td><span className={`orders-status-chip status-${order.status}`}>{t(formatLabel(order.status))}</span></td>
                    <td>{order.customer_username}</td>
                    <td>{order.assigned_courier_username ?? <span className="orders-unassigned">{t("Unassigned")}</span>}</td>
                    <td>
                      <span className="orders-locker-name">{order.locker?.name ?? t("Not assigned")}</span>
                      {order.assigned_drawer_number !== null && <span className="orders-item-summary">{t("Drawer")} {order.assigned_drawer_number}</span>}
                    </td>
                    <td className="orders-total-cell">{order.total_amount}</td>
                    <td>{formatDate(order.created_at)}</td>
                    <td><Link className="orders-open-link" to={`/orders/${order.public_id}`} aria-label={`${t("Open order")} ${order.public_id}`}><ExternalLink size={15} /></Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <footer className="orders-table-footer">
          <span>{count ? (locale === "ar" ? `عرض ${firstItem}–${lastItem} من ${count}` : `Showing ${firstItem}–${lastItem} of ${count}`) : t("Showing 0 orders")}</span>
          <div className="orders-pagination">
            <button type="button" onClick={() => setPage((current) => Math.max(1, current - 1))} disabled={!hasPrevious || loading} aria-label={t("Previous page")}><ArrowLeft size={15} /></button>
            <span>{t("Page")} {page}</span>
            <button type="button" onClick={() => setPage((current) => current + 1)} disabled={!hasNext || loading} aria-label={t("Next page")}><ArrowRight size={15} /></button>
          </div>
        </footer>
      </section>

      {assignmentPlan && (
        <div className="courier-plan-overlay" onMouseDown={(event) => { if (event.target === event.currentTarget && !planApplying) setAssignmentPlan(null); }}>
          <section className="courier-plan-dialog" role="dialog" aria-modal="true" aria-labelledby="courier-plan-title">
            <header>
              <div><p className="eyebrow">{t("Operations research")}</p><h2 id="courier-plan-title">{t("Courier assignment plan")}</h2></div>
              <button type="button" onClick={() => setAssignmentPlan(null)} disabled={planApplying} aria-label={t("Close")}>×</button>
            </header>
            <p className="courier-plan-explainer">{t("The plan assigns as many eligible orders as possible, then minimizes total straight-line distance. Review it before confirming.")}</p>
            <div className="courier-plan-metrics">
              <div><span>{t("Orders considered")}</span><strong>{assignmentPlan.orders_considered}</strong></div>
              <div><span>{t("Available couriers")}</span><strong>{assignmentPlan.couriers_available}</strong></div>
              <div><span>{t("Proposed assignments")}</span><strong>{assignmentPlan.assignment_count}</strong></div>
              <div><span>{t("Approx. total distance")}</span><strong>{assignmentPlan.total_distance_km} km</strong></div>
            </div>
            {assignmentPlan.orders_deferred > 0 && <p className="courier-plan-deferred" role="status">{assignmentPlan.orders_deferred} {t("Additional orders deferred beyond the 100-order planning limit")}</p>}
            <div className="courier-plan-list">
              {assignmentPlan.assignments.map((item) => (
                <article key={item.order_public_id}>
                  <div><strong>#{item.order_public_id.slice(0, 8)} · {item.customer_username}</strong><span>{t("Locker")}: {item.locker_code}</span></div>
                  <div><strong>{item.courier_username}</strong><span>{item.distance_km} km · {t("Location updated")}: {formatDate(item.location_updated_at)}</span></div>
                </article>
              ))}
              {assignmentPlan.unassigned_orders.map((item) => (
                <article className="courier-plan-unassigned" key={item.order_public_id}>
                  <div><strong>#{item.order_public_id.slice(0, 8)}</strong><span>{t(item.reason)}</span></div>
                  <strong>{t("Not assigned")}</strong>
                </article>
              ))}
              {assignmentPlan.assignment_count === 0 && <p>{t("No eligible order and courier pairs were found.")}</p>}
            </div>
            <footer>
              <span>{t("Straight-line distance is an estimate, not road travel distance or an ETA.")}</span>
              <button type="button" className="orders-refresh-button" onClick={() => setAssignmentPlan(null)} disabled={planApplying}>{t("Cancel")}</button>
              <button type="button" className="orders-plan-button" onClick={() => void confirmCourierPlan()} disabled={planApplying || assignmentPlan.assignment_count === 0}>
                {planApplying && <LoaderCircle size={15} className="spin" />}{planApplying ? t("Applying...") : t("Confirm assignments")}
              </button>
            </footer>
          </section>
        </div>
      )}
    </div>
  );
}
