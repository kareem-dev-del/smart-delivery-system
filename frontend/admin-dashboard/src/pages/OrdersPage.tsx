import { useEffect, useMemo, useState } from "react";
import { formatDate, formatLabel } from "../lib/format";
import { Link } from "react-router-dom";
import { AlertTriangle, ClipboardList, Package, RefreshCw } from "lucide-react";

import { getAdminOrders, type AdminOrder } from "../api/orders";
import { useAuth } from "../auth/AuthProvider";



function getOrderItemsSummary(order: AdminOrder): string {
  if (order.items.length === 0) return "No items";

  return order.items
    .map((item) => `${item.quantity}x ${item.product_name}`)
    .join(", ");
}

export function OrdersPage() {
  const { tokens } = useAuth();
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [count, setCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadOrders() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await getAdminOrders(tokens.access);
      setOrders(data.results);
      setCount(data.count);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load orders.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadOrders();
  }, [tokens?.access]);

  const statusCounts = useMemo(() => {
    return orders.reduce<Record<string, number>>((accumulator, order) => {
      accumulator[order.status] = (accumulator[order.status] ?? 0) + 1;
      return accumulator;
    }, {});
  }, [orders]);

  const orderMetrics = useMemo(() => {
  const inProgress =
    (statusCounts.pending ?? 0) +
    (statusCounts.awaiting_locker ?? 0) +
    (statusCounts.assigned ?? 0) +
    (statusCounts.ready_for_pickup ?? 0);

  const readyForPickup = statusCounts.ready_for_pickup ?? 0;
  const completed = statusCounts.collected ?? 0;
  const needsAction =
    (statusCounts.expired ?? 0) + (statusCounts.cancelled ?? 0);

  return {
    inProgress,
    readyForPickup,
    completed,
    needsAction,
  };
}, [statusCounts]);

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Orders</p>
          <h1 className="page-title">Orders</h1>
          <p className="page-description">
            Live admin order list from the SmartDrop backend.
          </p>
        </div>

        <button className="icon-text-button" type="button" onClick={loadOrders}>
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {loading && (
        <div className="scope-note">
          <ClipboardList size={15} />
          <span>Loading orders...</span>
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

          <section className="orders-command-panel">
            <div>
              <p className="eyebrow">Orders command</p>
              <h2>Order Operations</h2>
              <span>
                Live order workload, fulfillment state, and operational focus.
              </span>
            </div>

            <div className="orders-command-metrics">
              <div>
                <span>Total</span>
                <strong>{count}</strong>
              </div>
              <div>
                <span>In progress</span>
                <strong>{orderMetrics.inProgress}</strong>
              </div>
              <div>
                <span>Ready</span>
                <strong>{orderMetrics.readyForPickup}</strong>
              </div>
              <div>
                <span>Completed</span>
                <strong>{orderMetrics.completed}</strong>
              </div>
            </div>

            <div
              className={
                orderMetrics.needsAction > 0
                  ? "orders-focus orders-focus-warning"
                  : "orders-focus orders-focus-clear"
              }
            >
              <strong>
                {orderMetrics.needsAction > 0 ? "Needs review" : "All clear"}
              </strong>
              <span>
                {orderMetrics.needsAction > 0
                  ? `${orderMetrics.needsAction} order issue needs attention.`
                  : "No blocked or expired orders right now."}
              </span>
            </div>
          </section>
          <section
            className="orders-table-panel"
            aria-labelledby="orders-table-heading"
          >
            <h2 id="orders-table-heading" className="section-heading">
              Order list
            </h2>
            <p className="section-subtitle">
              Customer, courier, locker, drawer, and timeline details.
            </p>

            {orders.length === 0 ? (
              <div className="empty-panel">
                <Package size={18} />
                <span>No orders found.</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Order</th>
                      <th>Status</th>
                      <th>Customer</th>
                      <th>Courier</th>
                      <th>Locker</th>
                      <th>Drawer</th>
                      <th>Total</th>
                      <th>Created</th>
                      <th>Items</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map((order) => (
                      <tr key={order.public_id}>
                        <td>
                          <Link
                            className="order-link mono-cell"
                            to={`/orders/${order.public_id}`}
                          >
                            {order.public_id.slice(0, 8)}
                          </Link>
                        </td>
                        <td>
                          <span
                            className={`status-badge status-${order.status}`}
                          >
                            {formatLabel(order.status)}
                          </span>
                        </td>
                        <td>{order.customer_username}</td>
                        <td>{order.assigned_courier_username ?? "-"}</td>
                        <td>{order.locker?.name ?? "-"}</td>
                        <td>{order.assigned_drawer_number ?? "-"}</td>
                        <td>{order.total_amount}</td>
                        <td>{formatDate(order.created_at)}</td>
                        <td>{getOrderItemsSummary(order)}</td>
                        <td>
                          <Link className="table-action-link" to={`/orders/${order.public_id}`}>
                            Details
                          </Link>
                        </td>
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