import { useEffect, useMemo, useState, type FormEvent } from "react";
import { formatDate, formatLabel } from "../lib/format";
import { Link, useParams } from "react-router-dom";
import {
  AlertTriangle,
  ArrowLeft,
  ClipboardList,
  Package,
  User,
  UserRoundPlus,
  Warehouse,
} from "lucide-react";

import { getAdminCouriers, type AdminCourier } from "../api/accounts";
import {
  assignCourierToOrder,
  getAdminOrder,
  type AdminOrder,
} from "../api/orders";
import { useAuth } from "../auth/AuthProvider";



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

function getCourierLabel(courier: AdminCourier): string {
  const fullName = `${courier.first_name} ${courier.last_name}`.trim();
  return fullName ? `${fullName} (@${courier.username})` : courier.username;
}

export function OrderDetailsPage() {
  const { publicId } = useParams();
  const { tokens } = useAuth();
  const [order, setOrder] = useState<AdminOrder | null>(null);
  const [couriers, setCouriers] = useState<AdminCourier[]>([]);
  const [selectedCourierId, setSelectedCourierId] = useState("");
  const [loading, setLoading] = useState(true);
  const [assigningCourier, setAssigningCourier] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [assignmentError, setAssignmentError] = useState<string | null>(null);
  const [assignmentNotice, setAssignmentNotice] = useState<string | null>(null);

  async function loadOrder() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

   if (!publicId) {
      setError("Missing order identifier.");
      setOrder(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const [orderData, courierData] = await Promise.all([
        getAdminOrder(tokens.access, publicId),
        getAdminCouriers(tokens.access),
      ]);
      setOrder(orderData);
      setCouriers(courierData);
      setSelectedCourierId(
        orderData.assigned_courier ? String(orderData.assigned_courier) : "",
      );
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

  const canAssignCourier = Boolean(
    order && ["awaiting_locker", "assigned", "expired"].includes(order.status),
  );

  async function handleCourierAssignment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!tokens?.access || !order || !selectedCourierId) {
      setAssignmentError("Select an active courier before saving.");
      return;
    }

    setAssigningCourier(true);
    setAssignmentError(null);
    setAssignmentNotice(null);

    try {
      const assignment = await assignCourierToOrder(
        tokens.access,
        order.public_id,
        Number(selectedCourierId),
      );

      setOrder((currentOrder) =>
        currentOrder
          ? {
              ...currentOrder,
              assigned_courier: assignment.courier_id,
              assigned_courier_username: assignment.courier_username,
              courier_assigned_at: assignment.courier_assigned_at,
            }
          : currentOrder,
      );
      setAssignmentNotice(`${assignment.courier_username} is now assigned.`);
    } catch (caughtError) {
      setAssignmentError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not assign the courier.",
      );
    } finally {
      setAssigningCourier(false);
    }
  }

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
                {formatLabel(order.status)}
              </span>
            </div>

            <div className="details-total">
              <span>Total</span>
              <strong>{order.total_amount}</strong>
            </div>
          </section>

          {canAssignCourier && (
            <section
              className="order-assignment-panel"
              aria-labelledby="courier-assignment-heading"
            >
              <div className="order-assignment-copy">
                <div className="detail-panel-heading">
                  <UserRoundPlus size={17} />
                  <h2 id="courier-assignment-heading">Courier assignment</h2>
                </div>
                <p>
                  Choose an active courier to take responsibility for this
                  order. The assignment is recorded in the audit trail.
                </p>
              </div>

              {couriers.length === 0 ? (
                <p className="assignment-message assignment-message-error">
                  No active couriers are available for assignment.
                </p>
              ) : (
                <form className="order-assignment-form" onSubmit={handleCourierAssignment}>
                  <label htmlFor="courier-id">Active courier</label>
                  <select
                    id="courier-id"
                    value={selectedCourierId}
                    onChange={(event) => setSelectedCourierId(event.target.value)}
                    disabled={assigningCourier}
                  >
                    <option value="">Select a courier</option>
                    {couriers.map((courier) => (
                      <option key={courier.id} value={courier.id}>
                        {getCourierLabel(courier)}
                      </option>
                    ))}
                  </select>
                  <button
                    className="assignment-submit"
                    type="submit"
                    disabled={assigningCourier || !selectedCourierId}
                  >
                    <UserRoundPlus size={15} />
                    {assigningCourier ? "Assigning..." : "Assign courier"}
                  </button>
                </form>
              )}

              {assignmentError && (
                <p className="assignment-message assignment-message-error" role="alert">
                  {assignmentError}
                </p>
              )}
              {assignmentNotice && (
                <p className="assignment-message assignment-message-success" role="status">
                  {assignmentNotice}
                </p>
              )}
            </section>
          )}

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
