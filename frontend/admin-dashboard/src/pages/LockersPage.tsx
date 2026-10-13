import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Boxes,
  MapPin,
  Monitor,
  RefreshCw,
  Wifi,
} from "lucide-react";

import {
  getLockerDevices,
  getLockerStations,
  type LockerDevice,
  type LockerStation,
} from "../api/lockers";
import { useAuth } from "../auth/AuthProvider";

function formatLabel(value: string): string {
  return value
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function formatDate(value: string | null): string {
  if (!value) return "-";
  return new Date(value).toLocaleString();
}

export function LockersPage() {
  const { tokens } = useAuth();
  const [stations, setStations] = useState<LockerStation[]>([]);
  const [devices, setDevices] = useState<LockerDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadLockers() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const [stationData, deviceData] = await Promise.all([
        getLockerStations(tokens.access),
        getLockerDevices(tokens.access),
      ]);

      setStations(stationData);
      setDevices(deviceData);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load lockers.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadLockers();
  }, [tokens?.access]);

  const totals = useMemo(() => {
    const availableDrawers = stations.reduce(
      (total, station) => total + station.available_drawers_count,
      0,
    );

    const activeDevices = devices.filter((device) => device.is_active).length;
    const unhealthyDevices = devices.filter(
      (device) => device.connection_status !== "online",
    ).length;

    return {
      stations: stations.length,
      availableDrawers,
      activeDevices,
      unhealthyDevices,
    };
  }, [stations, devices]);

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Lockers</p>
          <h1 className="page-title">Lockers</h1>
          <p className="page-description">
            Live locker stations and device status from the SmartDrop backend.
          </p>
        </div>

        <button className="icon-text-button" type="button" onClick={loadLockers}>
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {loading && (
        <div className="scope-note">
          <Boxes size={15} />
          <span>Loading lockers...</span>
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
          <section className="orders-summary-panel" aria-labelledby="locker-summary-heading">
            <h2 id="locker-summary-heading" className="section-heading">
              Locker summary
            </h2>
            <p className="section-subtitle">
              {totals.stations} station{totals.stations === 1 ? "" : "s"} and{" "}
              {devices.length} device{devices.length === 1 ? "" : "s"} returned by the API.
            </p>

            <div className="module-grid">
              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <MapPin size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.stations}</span>
                </div>
                <h3 className="module-title">Stations</h3>
                <p className="module-copy">Locker locations managed by SmartDrop.</p>
              </article>

              <article className="metric-card metric-card-success">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Boxes size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.availableDrawers}</span>
                </div>
                <h3 className="module-title">Available drawers</h3>
                <p className="module-copy">Drawers currently available for assignment.</p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Monitor size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.activeDevices}</span>
                </div>
                <h3 className="module-title">Active devices</h3>
                <p className="module-copy">Registered locker devices marked active.</p>
              </article>

              <article
                className={`metric-card ${
                  totals.unhealthyDevices > 0
                    ? "metric-card-warning"
                    : "metric-card-success"
                }`}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <Wifi size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.unhealthyDevices}</span>
                </div>
                <h3 className="module-title">Unhealthy devices</h3>
                <p className="module-copy">Devices that are stale, inactive, or offline.</p>
              </article>
            </div>
          </section>

          <section className="orders-table-panel" aria-labelledby="stations-heading">
            <h2 id="stations-heading" className="section-heading">
              Locker stations
            </h2>
            <p className="section-subtitle">
              Physical locker locations and available drawer capacity.
            </p>

            {stations.length === 0 ? (
              <div className="empty-panel">
                <Boxes size={18} />
                <span>No locker stations found.</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Station</th>
                      <th>Code</th>
                      <th>Status</th>
                      <th>Available drawers</th>
                      <th>Address</th>
                      <th>Coordinates</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stations.map((station) => (
                      <tr key={station.id}>
                        <td>{station.name}</td>
                        <td>
                          <span className="mono-cell">{station.code}</span>
                        </td>
                        <td>
                          <span className={`status-badge status-${station.status}`}>
                            {formatLabel(station.status)}
                          </span>
                        </td>
                        <td>{station.available_drawers_count}</td>
                        <td>{station.address}</td>
                        <td>
                          <span className="mono-cell">
                            {station.latitude}, {station.longitude}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section className="orders-table-panel" aria-labelledby="devices-heading">
            <h2 id="devices-heading" className="section-heading">
              Locker devices
            </h2>
            <p className="section-subtitle">
              Device activation and connection status across the network.
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
                      <th>Active</th>
                      <th>Connection</th>
                      <th>Last heartbeat</th>
                      <th>Updated</th>
                    </tr>
                  </thead>
                  <tbody>
                    {devices.map((device) => (
                      <tr key={device.id}>
                        <td>
                          <span className="mono-cell">{device.device_code}</span>
                        </td>
                        <td>{device.locker_name}</td>
                        <td>{device.is_active ? "Yes" : "No"}</td>
                        <td>
                          <span
                            className={`status-badge status-${device.connection_status}`}
                          >
                            {formatLabel(device.connection_status)}
                          </span>
                        </td>
                        <td>{formatDate(device.last_heartbeat_at)}</td>
                        <td>{formatDate(device.updated_at)}</td>
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