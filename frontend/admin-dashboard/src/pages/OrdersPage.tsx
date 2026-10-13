import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, ClipboardList, Package, RefreshCw } from "lucide-react";

import { getAdminOrders, type AdminOrder } from "../api/orders";
import { useAuth } from "../auth/AuthProvider";

function formatStatus(status: string): string {
  return status
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function formatDate(value: string | null): string {
  if (!value) return "-";
  return new Date(value).toLocaleString();
}

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
        <>
          <section aria-labelledby="orders-summary-heading">
            <h2 id="orders-summary-heading" className="section-heading">
              Order summary
            </h2>
            <p className="section-subtitle">
              {count} total order{count === 1 ? "" : "s"} returned by the API.
            </p>

            <div className="status-grid compact-status-grid">
              {Object.entries(statusCounts).map(([status, value]) => (
                <article className="status-panel" key={status}>
                  <h3 className="status-panel-title">{formatStatus(status)}</h3>
                  <div className="metric-value">{value}</div>
                </article>
              ))}
            </div>
          </section>

          <section aria-labelledby="orders-table-heading">
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
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map((order) => (
                      <tr key={order.public_id}>
                        <td>
                          <span className="mono-cell">
                            {order.public_id.slice(0, 8)}
                          </span>
                        </td>
                        <td>
                          <span className={`status-badge status-${order.status}`}>
                            {formatStatus(order.status)}
                          </span>
                        </td>
                        <td>{order.customer_username}</td>
                        <td>{order.assigned_courier_username ?? "-"}</td>
                        <td>{order.locker?.name ?? "-"}</td>
                        <td>{order.assigned_drawer_number ?? "-"}</td>
                        <td>{order.total_amount}</td>
                        <td>{formatDate(order.created_at)}</td>
                        <td>{getOrderItemsSummary(order)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </>
      )}
    </>
  );
}