import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Monitor,
  Power,
  RefreshCw,
  Wifi,
} from "lucide-react";

import { formatDate, formatLabel } from "../lib/format";
import {
  getLockerDevices,
  updateLockerDeviceActivation,
  type LockerDevice,
} from "../api/lockers";
import { useAuth } from "../auth/AuthProvider";

export function DevicesPage() {
  const { tokens } = useAuth();
  const [devices, setDevices] = useState<LockerDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [updatingDeviceId, setUpdatingDeviceId] = useState<number | null>(
    null,
  );
  const [error, setError] = useState<string | null>(null);

  async function loadDevices() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await getLockerDevices(tokens.access);
      setDevices(data);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load locker devices.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadDevices();
  }, [tokens?.access]);

  async function handleDeviceActivationToggle(device: LockerDevice) {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      return;
    }

    setUpdatingDeviceId(device.id);
    setError(null);

    try {
      const updatedDevice = await updateLockerDeviceActivation(
        tokens.access,
        device.id,
        !device.is_active,
      );

      setDevices((currentDevices) =>
        currentDevices.map((currentDevice) =>
          currentDevice.id === updatedDevice.id
            ? updatedDevice
            : currentDevice,
        ),
      );
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not update device activation.",
      );
    } finally {
      setUpdatingDeviceId(null);
    }
  }

  const totals = useMemo(() => {
    const active = devices.filter((device) => device.is_active).length;
    const online = devices.filter(
      (device) =>
        device.is_active && device.connection_status === "online",
    ).length;
    const requiresAttention = devices.filter(
      (device) =>
        !device.is_active || device.connection_status !== "online",
    ).length;

    return {
      total: devices.length,
      active,
      online,
      requiresAttention,
    };
  }, [devices]);

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Devices</p>
          <h1 className="page-title">Locker devices</h1>
          <p className="page-description">
            Monitor device connectivity and manage activation across the
            SmartDrop locker network.
          </p>
        </div>

        <button
          className="icon-text-button"
          type="button"
          onClick={loadDevices}
          disabled={loading}
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {loading && (
        <div className="scope-note">
          <Monitor size={15} />
          <span>Loading locker devices...</span>
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
          <section
            className="orders-summary-panel"
            aria-labelledby="devices-summary-heading"
          >
            <h2 id="devices-summary-heading" className="section-heading">
              Device health summary
            </h2>
            <p className="section-subtitle">
              Connectivity and activation state from the SmartDrop backend.
            </p>

            <div className="module-grid">
              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Monitor size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.total}</span>
                </div>
                <h3 className="module-title">Registered devices</h3>
                <p className="module-copy">
                  Locker devices registered on the platform.
                </p>
              </article>

              <article className="metric-card metric-card-success">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Power size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.active}</span>
                </div>
                <h3 className="module-title">Active devices</h3>
                <p className="module-copy">
                  Devices enabled to handle locker operations.
                </p>
              </article>

              <article
                className={`metric-card ${
                  totals.online > 0
                    ? "metric-card-success"
                    : "metric-card-warning"
                }`}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <Wifi size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.online}</span>
                </div>
                <h3 className="module-title">Online and active</h3>
                <p className="module-copy">
                  Devices currently available for live operations.
                </p>
              </article>

              <article
                className={`metric-card ${
                  totals.requiresAttention > 0
                    ? "metric-card-warning"
                    : "metric-card-success"
                }`}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <AlertTriangle size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">
                    {totals.requiresAttention}
                  </span>
                </div>
                <h3 className="module-title">Needs attention</h3>
                <p className="module-copy">
                  Inactive, stale, offline, or never-connected devices.
                </p>
              </article>
            </div>
          </section>

          <section
            className="orders-table-panel"
            aria-labelledby="devices-table-heading"
          >
            <h2 id="devices-table-heading" className="section-heading">
              Device registry
            </h2>
            <p className="section-subtitle">
              Activation controls and the latest connection signal for every
              locker device.
            </p>

            {devices.length === 0 ? (
              <div className="empty-panel">
                <Monitor size={18} />
                <span>No locker devices found.</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Device</th>
                      <th>Locker</th>
                      <th>Station</th>
                      <th>Active</th>
                      <th>Connection</th>
                      <th>Last heartbeat</th>
                      <th>Updated</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {devices.map((device) => {
                      const isUpdating = updatingDeviceId === device.id;

                      return (
                        <tr key={device.id}>
                          <td>
                            <span className="mono-cell">
                              {device.device_code}
                            </span>
                          </td>
                          <td>
                            <strong>{device.locker_name}</strong>
                            <span className="table-secondary-text">
                              {device.locker_code}
                            </span>
                          </td>
                          <td>
                            <span
                              className={`status-badge status-${device.locker_station_status}`}
                            >
                              {formatLabel(device.locker_station_status)}
                            </span>
                          </td>
                          <td>
                            <span
                              className={`state-pill ${
                                device.is_active
                                  ? "state-pill-active"
                                  : "state-pill-inactive"
                              }`}
                            >
                              {device.is_active ? "Active" : "Inactive"}
                            </span>
                          </td>
                          <td>
                            <span
                              className={`status-badge status-${device.connection_status}`}
                            >
                              {formatLabel(device.connection_status)}
                            </span>
                          </td>
                          <td>{formatDate(device.last_heartbeat_at)}</td>
                          <td>{formatDate(device.updated_at)}</td>
                          <td>
                            <button
                              className={`table-action-button ${
                                device.is_active
                                  ? "table-action-danger"
                                  : "table-action-success"
                              }`}
                              type="button"
                              onClick={() =>
                                handleDeviceActivationToggle(device)
                              }
                              disabled={isUpdating}
                            >
                              {isUpdating
                                ? "Saving..."
                                : device.is_active
                                  ? "Deactivate"
                                  : "Activate"}
                            </button>
                          </td>
                        </tr>
                      );
                    })}
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