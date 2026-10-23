import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  ClipboardList,
  ExternalLink,
  Package,
  RefreshCw,
  Search,
  SlidersHorizontal,
} from "lucide-react";

import { getDashboardSummary, type DashboardSummary } from "../api/dashboard";
import { getAdminOrders, type AdminOrder } from "../api/orders";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";

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
  if (order.items.length === 0) return "No items";
  return order.items.map((item) => `${item.quantity} × ${item.product_name}`).join(", ");
}

export function OrdersPage() {
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

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 280);
    return () => window.clearTimeout(timer);
  }, [searchInput]);

  async function loadOrders() {
    if (!tokens?.access) {
      setError("Your session has expired. Sign in again to load orders.");
      setLoading(false);
      return;
    }
    setLoading(true);
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
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadOrders();
  }, [tokens?.access, statusFilter, search, page]);

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
          <p className="eyebrow">Network control / Orders</p>
          <h1 className="page-title">Orders</h1>
          <p className="page-description">Monitor every order moving through the SmartDrop network.</p>
        </div>
        <button className="orders-refresh-button" type="button" onClick={() => void loadOrders()} disabled={loading}>
          <RefreshCw size={15} className={loading ? "spin" : undefined} />
          Refresh
        </button>
      </header>

      {error && (
        <div className="scope-note error-note" role="alert">
          <AlertTriangle size={16} /><span>{error}</span>
          <button type="button" onClick={() => void loadOrders()}>Try again</button>
        </div>
      )}

      <section className="orders-command-panel" aria-label="Order summary">
        <div className="orders-command-intro">
          <span className="orders-command-icon"><ClipboardList size={18} /></span>
          <div>
            <p className="eyebrow">Orders command</p>
            <h2>Order operations</h2>
            <span>Current workload and fulfillment status.</span>
          </div>
        </div>

        <div className="orders-command-metrics">
          <div><span>Total orders</span><strong>{metrics.total}</strong></div>
          <div><span>In progress</span><strong>{metrics.inProgress}</strong></div>
          <div><span>Ready for pickup</span><strong>{metrics.ready}</strong></div>
          <div><span>Collected</span><strong>{metrics.completed}</strong></div>
        </div>

        <div className={`orders-focus ${metrics.needsReview > 0 ? "orders-focus-warning" : "orders-focus-clear"}`}>
          <strong>{metrics.needsReview > 0 ? "Needs review" : "All clear"}</strong>
          <span>{metrics.needsReview > 0 ? `${metrics.needsReview} cancelled or expired orders.` : "No expired or cancelled orders right now."}</span>
        </div>
      </section>

      <section className="orders-table-panel" aria-labelledby="orders-table-heading">
        <div className="orders-list-heading">
          <div>
            <h2 id="orders-table-heading">Order list</h2>
            <p>Search and filter the complete order register.</p>
          </div>
          <span className="orders-result-count">{count} total</span>
        </div>

        <div className="orders-toolbar">
          <label className="orders-search-field">
            <Search size={16} />
            <input
              type="search"
              value={searchInput}
              onChange={(event) => setSearchInput(event.target.value)}
              placeholder="Search order, customer, courier, locker..."
              aria-label="Search orders"
            />
          </label>
          <label className="orders-status-filter">
            <SlidersHorizontal size={15} />
            <select
              value={statusFilter}
              onChange={(event) => { setStatusFilter(event.target.value); setPage(1); }}
              aria-label="Filter by order status"
            >
              <option value="">All statuses</option>
              {orderStatuses.map((status) => <option value={status} key={status}>{formatLabel(status)}</option>)}
            </select>
          </label>
        </div>

        {loading ? (
          <div className="orders-empty-state"><RefreshCw size={18} className="spin" /><span>Loading orders...</span></div>
        ) : orders.length === 0 ? (
          <div className="orders-empty-state">
            <span className="orders-empty-icon"><Package size={19} /></span>
            <strong>{search || statusFilter ? "No matching orders" : "No orders yet"}</strong>
            <span>{search || statusFilter ? "Try another search or clear the status filter." : "Customer orders will appear here when they are created."}</span>
          </div>
        ) : (
          <div className="orders-table-scroll">
            <table className="orders-data-table">
              <thead>
                <tr><th>Order</th><th>Status</th><th>Customer</th><th>Courier</th><th>Locker / drawer</th><th>Total</th><th>Created</th><th aria-label="Actions" /></tr>
              </thead>
              <tbody>
                {orders.map((order) => (
                  <tr key={order.public_id}>
                    <td>
                      <Link className="orders-id-link" to={`/orders/${order.public_id}`}>#{order.public_id.slice(0, 8)}</Link>
                      <span className="orders-item-summary">{getOrderItemsSummary(order)}</span>
                    </td>
                    <td><span className={`orders-status-chip status-${order.status}`}>{formatLabel(order.status)}</span></td>
                    <td>{order.customer_username}</td>
                    <td>{order.assigned_courier_username ?? <span className="orders-unassigned">Unassigned</span>}</td>
                    <td>
                      <span className="orders-locker-name">{order.locker?.name ?? "Not assigned"}</span>
                      {order.assigned_drawer_number !== null && <span className="orders-item-summary">Drawer {order.assigned_drawer_number}</span>}
                    </td>
                    <td className="orders-total-cell">{order.total_amount}</td>
                    <td>{formatDate(order.created_at)}</td>
                    <td><Link className="orders-open-link" to={`/orders/${order.public_id}`} aria-label={`Open order ${order.public_id}`}><ExternalLink size={15} /></Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <footer className="orders-table-footer">
          <span>{count ? `Showing ${firstItem}–${lastItem} of ${count}` : "Showing 0 orders"}</span>
          <div className="orders-pagination">
            <button type="button" onClick={() => setPage((current) => Math.max(1, current - 1))} disabled={!hasPrevious || loading} aria-label="Previous page"><ArrowLeft size={15} /></button>
            <span>Page {page}</span>
            <button type="button" onClick={() => setPage((current) => current + 1)} disabled={!hasNext || loading} aria-label="Next page"><ArrowRight size={15} /></button>
          </div>
        </footer>
      </section>
    </div>
  );
}
