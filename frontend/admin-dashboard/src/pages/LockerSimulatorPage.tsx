import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Activity, CheckCircle2, DoorOpen, LockKeyhole, RefreshCw, Wifi } from "lucide-react";

import { getAdminOrders, type AdminOrder } from "../api/orders";
import { ApiRequestError } from "../api/client";
import {
  authorizeSimulatedPickup,
  confirmSimulatedCollection,
  loginLockerDevice,
  sendLockerHeartbeat,
  simulatePackageDeposit,
  type LockerHeartbeat,
  type OpenDrawerCommand,
} from "../api/locker-simulator";
import { useAuth } from "../auth/AuthProvider";
import { useLocale } from "../i18n/LocaleProvider";

function errorMessage(error: unknown): string {
  if (error instanceof ApiRequestError) {
    if (typeof error.details === "string" && error.details.trim()) return error.details;
    if (error.details && typeof error.details === "object") {
      const values = Object.values(error.details as Record<string, unknown>)
        .flatMap((value) => Array.isArray(value) ? value : [value])
        .filter((value): value is string => typeof value === "string" && value.trim().length > 0);
      if (values.length) return values.join(" ");
    }
  }
  if (error instanceof Error) return error.message;
  return "The locker operation could not be completed.";
}

export function LockerSimulatorPage() {
  const { t } = useLocale();
  const { tokens } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [deviceToken, setDeviceToken] = useState<string | null>(null);
  const [heartbeat, setHeartbeat] = useState<LockerHeartbeat | null>(null);
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [selectedOrderId, setSelectedOrderId] = useState("");
  const [qrToken, setQrToken] = useState("");
  const [openCommand, setOpenCommand] = useState<OpenDrawerCommand | null>(null);
  const [working, setWorking] = useState(false);
  const [loadingOrders, setLoadingOrders] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activity, setActivity] = useState<string[]>([]);

  const selectedOrder = useMemo(
    () => orders.find((order) => order.public_id === selectedOrderId) ?? null,
    [orders, selectedOrderId],
  );
  const stationOrders = useMemo(
    () => orders.filter((order) => order.locker?.code === heartbeat?.locker_code),
    [orders, heartbeat?.locker_code],
  );

  async function refreshOrders() {
    if (!tokens?.access || !heartbeat) return;
    setLoadingOrders(true);
    setError(null);
    try {
      const [assigned, ready] = await Promise.all([
        getAdminOrders(tokens.access, { status: "assigned", pageSize: 100 }),
        getAdminOrders(tokens.access, { status: "ready_for_pickup", pageSize: 100 }),
      ]);
      const current = [...assigned.results, ...ready.results]
        .filter((order) => order.locker?.code === heartbeat.locker_code)
        .sort((a, b) => b.created_at.localeCompare(a.created_at));
      setOrders(current);
      setSelectedOrderId((previous) =>
        current.some((order) => order.public_id === previous)
          ? previous
          : current.find((order) => order.status === "assigned")?.public_id
            ?? current[0]?.public_id
            ?? "",
      );
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setLoadingOrders(false);
    }
  }

  useEffect(() => {
    void refreshOrders();
  }, [tokens?.access, heartbeat?.locker_code]);

  async function connectDevice(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setWorking(true);
    setError(null);
    try {
      const access = await loginLockerDevice(username.trim(), password);
      const live = await sendLockerHeartbeat(access);
      setDeviceToken(access);
      setHeartbeat(live);
      setPassword("");
      setOpenCommand(null);
      setActivity((items) => [`Connected to ${live.locker_code}; heartbeat accepted.`, ...items]);
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setWorking(false);
    }
  }

  async function refreshHeartbeat() {
    if (!deviceToken) return;
    setWorking(true);
    setError(null);
    try {
      const live = await sendLockerHeartbeat(deviceToken);
      setHeartbeat(live);
      setActivity((items) => [`Heartbeat accepted at ${new Date().toLocaleTimeString()}.`, ...items]);
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setWorking(false);
    }
  }

  async function depositPackage() {
    if (!deviceToken || !selectedOrder) return;
    setWorking(true);
    setError(null);
    setActivity((items) => [`Simulated drawer ${selectedOrder.assigned_drawer_number ?? "—"} opened for courier deposit.`, ...items]);
    try {
      await new Promise((resolve) => window.setTimeout(resolve, 650));
      await simulatePackageDeposit(deviceToken, selectedOrder.public_id);
      setActivity((items) => [`Courier closed the simulated drawer; backend marked the order ready for pickup.`, ...items]);
      await refreshOrders();
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setWorking(false);
    }
  }

  async function scanPickupQr() {
    if (!deviceToken || !qrToken.trim()) return;
    setWorking(true);
    setError(null);
    try {
      const command = await authorizeSimulatedPickup(deviceToken, qrToken.trim());
      setOpenCommand(command);
      setSelectedOrderId(command.order_public_id);
      setActivity((items) => [`Valid QR accepted. Simulated drawer ${command.drawer_number} opened.`, ...items]);
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setWorking(false);
    }
  }

  async function closeDrawerAndConfirm() {
    if (!deviceToken || !openCommand) return;
    setWorking(true);
    setError(null);
    try {
      await new Promise((resolve) => window.setTimeout(resolve, 650));
      await confirmSimulatedCollection(deviceToken, openCommand.order_public_id);
      setActivity((items) => [`Simulated drawer ${openCommand.drawer_number} closed; backend confirmed collection.`, ...items]);
      setOpenCommand(null);
      setQrToken("");
      await refreshOrders();
    } catch (caughtError) {
      setError(errorMessage(caughtError));
    } finally {
      setWorking(false);
    }
  }

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">{t("Competition demo / Hardware simulation")}</p>
          <h1 className="page-title">{t("Locker simulator")}</h1>
          <p className="page-description">{t("Exercise the real locker-device API with simulated drawer hardware. No physical locker is connected.")}</p>
        </div>
        {heartbeat && (
          <button className="icon-text-button" type="button" onClick={refreshHeartbeat} disabled={working}>
            <RefreshCw size={16} /> {t("Send heartbeat")}
          </button>
        )}
      </div>

      <div className="simulator-disclosure" role="note">
        <Activity size={17} />
        <span><strong>{t("Simulation mode")}</strong> — {t("Drawer opening and closing are visual simulation only. Order authorization, QR validation, and status changes are handled by the SmartDrop backend.")}</span>
      </div>

      {error && <div className="scope-note error-note" role="alert">{error}</div>}

      {!deviceToken ? (
        <section className="orders-table-panel simulator-login-panel">
          <h2 className="section-heading">{t("Connect a provisioned locker device")}</h2>
          <p className="section-subtitle">{t("Use the device username and initial password shown when the device was provisioned. The password is kept only until sign-in.")}</p>
          <form className="simulator-login-form" onSubmit={connectDevice}>
            <label>{t("Device username")}
              <input autoComplete="username" value={username} onChange={(event) => setUsername(event.target.value)} required />
            </label>
            <label>{t("Device password")}
              <input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} required />
            </label>
            <button className="primary-button" type="submit" disabled={working}>
              <Wifi size={16} /> {working ? t("Connecting...") : t("Connect simulator")}
            </button>
          </form>
        </section>
      ) : (
        <div className="simulator-layout">
          <section className="orders-table-panel simulator-main-panel">
            <div className="simulator-section-heading">
              <div>
                <h2 className="section-heading">{t("Locker device")}: {heartbeat?.device_code}</h2>
                <p className="section-subtitle">{t("Station")}: {heartbeat?.locker_code} · {t("Status")}: {t(heartbeat?.locker_status ?? "Unknown")}</p>
              </div>
              <span className="state-pill state-pill-active"><Wifi size={13} /> {t("Heartbeat received")}</span>
            </div>

            <label className="simulator-order-select">{t("Order assigned to this locker")}
              <select value={selectedOrderId} onChange={(event) => { setSelectedOrderId(event.target.value); setOpenCommand(null); }} disabled={loadingOrders || working}>
                <option value="">{loadingOrders ? t("Loading orders...") : t("Select an order")}</option>
                {stationOrders.map((order) => (
                  <option key={order.public_id} value={order.public_id}>
                    {order.public_id.slice(0, 8)} · {t(order.status === "assigned" ? "Assigned" : "Ready for pickup")} · {t("Drawer")} {order.assigned_drawer_number ?? "—"}
                  </option>
                ))}
              </select>
            </label>

            {!selectedOrder && <div className="empty-panel">{t("No assigned or pickup-ready orders are available for this locker.")}</div>}
            {selectedOrder && (
              <div className="simulator-order-card">
                <div className="simulator-order-top">
                  <div><span className="eyebrow">{t("Order")}</span><strong>{selectedOrder.public_id}</strong></div>
                  <span className={`status-badge status-${selectedOrder.status}`}>{t(selectedOrder.status === "assigned" ? "Assigned" : "Ready for pickup")}</span>
                </div>
                <div className="simulator-drawer-visual" aria-live="polite">
                  <div className={`simulator-drawer${openCommand ? " is-open" : ""}`}>
                    {openCommand ? <DoorOpen size={26} /> : <LockKeyhole size={24} />}
                    <span>{t("Drawer")} {openCommand?.drawer_number ?? selectedOrder.assigned_drawer_number ?? "—"}</span>
                    <small>{openCommand ? t("Open — simulated") : t("Closed")}</small>
                  </div>
                  <p>{t("The simulator shows the device command and waits for an explicit simulated door-close confirmation.")}</p>
                </div>

                {selectedOrder.status === "assigned" ? (
                  <button className="primary-button" type="button" onClick={depositPackage} disabled={working || !heartbeat || heartbeat.locker_status !== "online"}>
                    <DoorOpen size={16} /> {working ? t("Processing...") : t("Simulate courier deposit")}
                  </button>
                ) : openCommand ? (
                  <button className="primary-button" type="button" onClick={closeDrawerAndConfirm} disabled={working}>
                    <CheckCircle2 size={16} /> {working ? t("Confirming...") : t("Close drawer and confirm collection")}
                  </button>
                ) : (
                  <div className="simulator-qr-form">
                    <label>{t("Customer pickup QR token")}
                      <textarea value={qrToken} onChange={(event) => setQrToken(event.target.value)} rows={3} placeholder={t("Paste a one-time QR token from the customer app")} />
                    </label>
                    <button className="primary-button" type="button" onClick={scanPickupQr} disabled={working || !qrToken.trim() || !heartbeat || heartbeat.locker_status !== "online"}>
                      <LockKeyhole size={16} /> {working ? t("Checking QR...") : t("Scan QR in simulator")}
                    </button>
                  </div>
                )}
                {selectedOrder.status === "ready_for_pickup" && <p className="simulator-helper-text">{t("Generate the pickup QR in the customer app, then paste its token here. Invalid, expired, and wrong-locker tokens are rejected by the backend.")}</p>}
              </div>
            )}
            <button className="icon-text-button simulator-refresh-orders" type="button" onClick={() => void refreshOrders()} disabled={loadingOrders || working}>
              <RefreshCw size={14} /> {t("Refresh locker orders")}
            </button>
          </section>

          <aside className="orders-table-panel simulator-activity-panel">
            <h2 className="section-heading">{t("Simulation activity")}</h2>
            <p className="section-subtitle">{t("Latest commands and backend acknowledgements from this browser session.")}</p>
            {activity.length === 0 ? <div className="empty-panel">{t("Connect the device and send a heartbeat to begin.")}</div> : (
              <ol className="simulator-activity-list">
                {activity.slice(0, 8).map((item, index) => <li key={`${index}-${item}`}>{item}</li>)}
              </ol>
            )}
            <button className="icon-text-button" type="button" onClick={() => { setDeviceToken(null); setHeartbeat(null); setOrders([]); setActivity([]); setOpenCommand(null); }}>
              {t("Disconnect simulator")}
            </button>
          </aside>
        </div>
      )}
    </>
  );
}
