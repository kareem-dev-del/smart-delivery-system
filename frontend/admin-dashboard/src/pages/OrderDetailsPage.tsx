import { useEffect, useMemo, useState, type FormEvent } from "react";
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
  assignOrderToDrawer,
  getAdminOrder,
  type AdminOrder,
} from "../api/orders";
import {
  getLockerStationDetail,
  getLockerStations,
  type LockerStation,
  type LockerStationDetail,
} from "../api/lockers";
import { useAuth } from "../auth/AuthProvider";
import { formatDate, formatLabel } from "../lib/format";

const DRAWER_SIZE_RANK: Record<string, number> = {
  small: 1,
  medium: 2,
  large: 3,
};

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
  const [lockers, setLockers] = useState<LockerStation[]>([]);

  const [selectedCourierId, setSelectedCourierId] = useState("");
  const [selectedLockerId, setSelectedLockerId] = useState("");
  const [selectedDrawerId, setSelectedDrawerId] = useState("");
  const [selectedLockerDetail, setSelectedLockerDetail] =
    useState<LockerStationDetail | null>(null);

  const [loading, setLoading] = useState(true);
  const [drawerLoading, setDrawerLoading] = useState(false);
  const [assigningCourier, setAssigningCourier] = useState(false);
  const [assigningDrawer, setAssigningDrawer] = useState(false);

  const [error, setError] = useState<string | null>(null);
  const [assignmentError, setAssignmentError] = useState<string | null>(null);
  const [assignmentNotice, setAssignmentNotice] = useState<string | null>(null);
  const [drawerAssignmentError, setDrawerAssignmentError] =
    useState<string | null>(null);
  const [drawerAssignmentNotice, setDrawerAssignmentNotice] =
    useState<string | null>(null);

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
      const [orderData, courierData, lockerData] = await Promise.all([
        getAdminOrder(tokens.access, publicId),
        getAdminCouriers(tokens.access),
        getLockerStations(tokens.access),
      ]);

      setOrder(orderData);
      setCouriers(courierData);
      setLockers(lockerData);
      setSelectedCourierId(
        orderData.assigned_courier
          ? String(orderData.assigned_courier)
          : "",
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

  useEffect(() => {
    const accessToken = tokens?.access;
    let cancelled = false;

    if (!accessToken || !selectedLockerId) {
      setSelectedLockerDetail(null);
      setDrawerLoading(false);
      return;
    }

    async function loadSelectedLocker(accessToken: string) {
      setDrawerLoading(true);
      setDrawerAssignmentError(null);

      try {
        const lockerDetail = await getLockerStationDetail(
          accessToken,
          Number(selectedLockerId),
        );

        if (!cancelled) {
          setSelectedLockerDetail(lockerDetail);
        }
      } catch (caughtError) {
        if (!cancelled) {
          setSelectedLockerDetail(null);
          setDrawerAssignmentError(
            caughtError instanceof Error
              ? caughtError.message
              : "Could not load locker drawers.",
          );
        }
      } finally {
        if (!cancelled) {
          setDrawerLoading(false);
        }
      }
    }

    void loadSelectedLocker(accessToken);

    return () => {
      cancelled = true;
    };
  }, [selectedLockerId, tokens?.access]);

  const totalItems = useMemo(
    () => order?.items.reduce((total, item) => total + item.quantity, 0) ?? 0,
    [order],
  );

  const onlineLockers = useMemo(
    () => lockers.filter((locker) => locker.status === "online"),
    [lockers],
  );

  const requiredDrawerSize = useMemo(() => {
    if (!order) return null;

    return order.items.reduce<string | null>((largestSize, item) => {
      if (!largestSize) return item.product_size;

      return (DRAWER_SIZE_RANK[item.product_size] ?? 0) >
        (DRAWER_SIZE_RANK[largestSize] ?? 0)
        ? item.product_size
        : largestSize;
    }, null);
  }, [order]);

  const compatibleDrawers = useMemo(() => {
    if (!selectedLockerDetail) return [];

    const requiredSizeRank = requiredDrawerSize
      ? DRAWER_SIZE_RANK[requiredDrawerSize] ?? 0
      : 0;

    return selectedLockerDetail.drawers.filter(
      (drawer) =>
        drawer.status === "available" &&
        (DRAWER_SIZE_RANK[drawer.size] ?? 0) >= requiredSizeRank,
    );
  }, [requiredDrawerSize, selectedLockerDetail]);

  const canAssignCourier = Boolean(
    order &&
      ["awaiting_locker", "assigned", "expired"].includes(order.status),
  );

  const canAssignDrawer = order?.status === "awaiting_locker";

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

  function handleLockerChange(lockerId: string) {
    setSelectedLockerId(lockerId);
    setSelectedDrawerId("");
    setDrawerAssignmentError(null);
    setDrawerAssignmentNotice(null);
  }

  async function handleDrawerAssignment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!tokens?.access || !order || !selectedLockerId || !selectedDrawerId) {
      setDrawerAssignmentError("Select a locker and compatible drawer first.");
      return;
    }

    setAssigningDrawer(true);
    setDrawerAssignmentError(null);
    setDrawerAssignmentNotice(null);

    try {
      const updatedOrder = await assignOrderToDrawer(
        tokens.access,
        order.public_id,
        Number(selectedLockerId),
        Number(selectedDrawerId),
      );

      setOrder(updatedOrder);
      setSelectedLockerId("");
      setSelectedDrawerId("");
      setSelectedLockerDetail(null);

      setDrawerAssignmentNotice(
        `Assigned to drawer ${updatedOrder.assigned_drawer_number} at ${
          updatedOrder.locker?.name ?? "the selected locker"
        }.`,
      );
    } catch (caughtError) {
      setDrawerAssignmentError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not assign the locker drawer.",
      );
    } finally {
      setAssigningDrawer(false);
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
                <form
                  className="order-assignment-form"
                  onSubmit={handleCourierAssignment}
                >
                  <label htmlFor="courier-id">Active courier</label>
                  <select
                    id="courier-id"
                    value={selectedCourierId}
                    onChange={(event) =>
                      setSelectedCourierId(event.target.value)
                    }
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
                <p
                  className="assignment-message assignment-message-error"
                  role="alert"
                >
                  {assignmentError}
                </p>
              )}

              {assignmentNotice && (
                <p
                  className="assignment-message assignment-message-success"
                  role="status"
                >
                  {assignmentNotice}
                </p>
              )}
            </section>
          )}

          {canAssignDrawer && (
            <section
              className="order-assignment-panel drawer-assignment-panel"
              aria-labelledby="drawer-assignment-heading"
            >
              <div className="order-assignment-copy">
                <div className="detail-panel-heading">
                  <Warehouse size={17} />
                  <h2 id="drawer-assignment-heading">Locker assignment</h2>
                </div>
                <p>
                  Reserve a compatible available drawer. The locker must be
                  online and the drawer must fit every item in this order.
                </p>
                {requiredDrawerSize && (
                  <div className="drawer-size-callout">
                    <span>Required drawer size</span>
                    <strong>{formatLabel(requiredDrawerSize)}</strong>
                  </div>
                )}
              </div>

              {onlineLockers.length === 0 ? (
                <p className="assignment-message assignment-message-error">
                  No online locker stations are available for assignment.
                </p>
              ) : (
                <form
                  className="drawer-assignment-form"
                  onSubmit={handleDrawerAssignment}
                >
                  <div className="assignment-field">
                    <label htmlFor="locker-station-id">Locker station</label>
                    <select
                      id="locker-station-id"
                      value={selectedLockerId}
                      onChange={(event) =>
                        handleLockerChange(event.target.value)
                      }
                      disabled={assigningDrawer}
                    >
                      <option value="">Select an online locker</option>
                      {onlineLockers.map((locker) => (
                        <option key={locker.id} value={locker.id}>
                          {locker.name} ({locker.available_drawers_count}{" "}
                          available)
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="assignment-field">
                    <label htmlFor="drawer-id">
                      Compatible drawer
                      {requiredDrawerSize
                        ? ` (${formatLabel(requiredDrawerSize)} or larger)`
                        : ""}
                    </label>
                    <select
                      id="drawer-id"
                      value={selectedDrawerId}
                      onChange={(event) =>
                        setSelectedDrawerId(event.target.value)
                      }
                      disabled={
                        assigningDrawer ||
                        drawerLoading ||
                        !selectedLockerId ||
                        compatibleDrawers.length === 0
                      }
                    >
                      <option value="">
                        {drawerLoading
                          ? "Loading drawers..."
                          : "Select an available drawer"}
                      </option>
                      {compatibleDrawers.map((drawer) => (
                        <option key={drawer.id} value={drawer.id}>
                          Drawer {drawer.number} ({formatLabel(drawer.size)})
                        </option>
                      ))}
                    </select>
                  </div>

                  <button
                    className="assignment-submit"
                    type="submit"
                    disabled={
                      assigningDrawer ||
                      drawerLoading ||
                      !selectedLockerId ||
                      !selectedDrawerId
                    }
                  >
                    <Warehouse size={15} />
                    {assigningDrawer ? "Assigning..." : "Reserve drawer"}
                  </button>
                </form>
              )}

              {selectedLockerId &&
                !drawerLoading &&
                compatibleDrawers.length === 0 && (
                  <p className="assignment-message assignment-message-error">
                    This locker has no available drawer large enough for the
                    order.
                  </p>
                )}

              {drawerAssignmentError && (
                <p
                  className="assignment-message assignment-message-error"
                  role="alert"
                >
                  {drawerAssignmentError}
                </p>
              )}
            </section>
          )}

          {drawerAssignmentNotice && (
            <div className="scope-note assignment-success-note" role="status">
              <Warehouse size={15} />
              <span>{drawerAssignmentNotice}</span>
            </div>
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
                <div
                  className="item-row"
                  key={`${item.product}-${item.product_name}`}
                >
                  <div>
                    <strong>{item.product_name}</strong>
                    <span>{formatLabel(item.product_size)}</span>
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
                <TimelineRow
                  label="Drawer assigned"
                  value={order.assigned_at}
                />
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
