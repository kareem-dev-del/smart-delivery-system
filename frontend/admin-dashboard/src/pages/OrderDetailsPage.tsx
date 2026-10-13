import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  AlertTriangle,
  ArrowLeft,
  ClipboardList,
  Package,
  User,
  Warehouse,
} from "lucide-react";

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

function DetailRow({
  label,
  value,
}: {
  label: string;
  value: string | number | null | undefined;
}) {
  return (
    <div className="detail-row">
      <span>{label}</span>
      <strong>{value ?? "-"}</strong>
    </div>
  );
}

function TimelineRow({
  label,
  value,
}: {
  label: string;
  value: string | null;
}) {
  return (
    <div className="timeline-row">
      <span className={value ? "timeline-dot active" : "timeline-dot"} />
      <div>
        <strong>{label}</strong>
        <p>{formatDate(value)}</p>
      </div>
    </div>
  );
}

export function OrderDetailsPage() {
  const { publicId } = useParams();
  const { tokens } = useAuth();
  const [order, setOrder] = useState<AdminOrder | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadOrder() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await getAdminOrders(tokens.access);
      const matchedOrder =
        data.results.find((candidate) => candidate.public_id === publicId) ??
        null;

      if (!matchedOrder) {
        setError("Order was not found in the admin order list.");
        setOrder(null);
        return;
      }

      setOrder(matchedOrder);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load order details.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadOrder();
  }, [tokens?.access, publicId]);

  const totalItems = useMemo(() => {
    return order?.items.reduce((total, item) => total + item.quantity, 0) ?? 0;
  }, [order]);

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <Link className="back-link" to="/orders">
            <ArrowLeft size={15} />
            Back to orders
          </Link>
          <p className="eyebrow">Network control / Order details</p>
          <h1 className="page-title">Order details</h1>
          <p className="page-description">
            Full operational view for a single SmartDrop order.
          </p>
        </div>
      </div>

      {loading && (
        <div className="scope-note">
          <ClipboardList size={15} />
          <span>Loading order details...</span>
        </div>
      )}

      {error && (
        <div className="scope-note error-note">
          <AlertTriangle size={15} />
          <span>{error}</span>
        </div>
      )}

      {!loading && !error && order && (
        <>
          <section className="details-hero" aria-labelledby="order-heading">
            <div>
              <p className="eyebrow">Order</p>
              <h2 id="order-heading" className="details-title">
                {order.public_id}
              </h2>
              <span className={`status-badge status-${order.status}`}>
                {formatStatus(order.status)}
              </span>
            </div>

            <div className="details-total">
              <span>Total</span>
              <strong>{order.total_amount}</strong>
            </div>
          </section>

          <section className="details-grid" aria-label="Order details">
            <article className="detail-panel">
              <div className="detail-panel-heading">
                <User size={17} />
                <h3>People</h3>
              </div>
              <DetailRow label="Customer" value={order.customer_username} />
              <DetailRow
                label="Courier"
                value={order.assigned_courier_username}
              />
              <DetailRow label="Customer ID" value={order.customer} />
              <DetailRow label="Courier ID" value={order.assigned_courier} />
            </article>

            <article className="detail-panel">
              <div className="detail-panel-heading">
                <Warehouse size={17} />
                <h3>Locker</h3>
              </div>
              <DetailRow label="Locker" value={order.locker?.name} />
              <DetailRow label="Locker code" value={order.locker?.code} />
              <DetailRow label="Address" value={order.locker?.address} />
              <DetailRow label="Drawer" value={order.assigned_drawer_number} />
            </article>

            <article className="detail-panel">
              <div className="detail-panel-heading">
                <Package size={17} />
                <h3>Items</h3>
              </div>
              <DetailRow label="Total items" value={totalItems} />
              {order.items.map((item) => (
                <div className="item-row" key={`${item.product}-${item.product_name}`}>
                  <div>
                    <strong>{item.product_name}</strong>
                    <span>{item.product_size}</span>
                  </div>
                  <div>
                    <strong>{item.quantity}x</strong>
                    <span>{item.line_total}</span>
                  </div>
                </div>
              ))}
            </article>

            <article className="detail-panel">
              <div className="detail-panel-heading">
                <ClipboardList size={17} />
                <h3>Timeline</h3>
              </div>
              <div className="timeline-list">
                <TimelineRow label="Created" value={order.created_at} />
                <TimelineRow
                  label="Courier assigned"
                  value={order.courier_assigned_at}
                />
                <TimelineRow label="Drawer assigned" value={order.assigned_at} />
                <TimelineRow
                  label="Ready for pickup"
                  value={order.ready_for_pickup_at}
                />
                <TimelineRow
                  label="Pickup opened"
                  value={order.pickup_opened_at}
                />
                <TimelineRow label="Collected" value={order.collected_at} />
                <TimelineRow
                  label="Return opened"
                  value={order.return_opened_at}
                />
                <TimelineRow label="Returned" value={order.returned_at} />
                <TimelineRow label="Cancelled" value={order.cancelled_at} />
              </div>
            </article>
          </section>
        </>
      )}
    </>
  );
}