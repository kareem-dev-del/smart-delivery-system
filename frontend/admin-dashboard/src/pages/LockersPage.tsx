import { useEffect, useMemo, useState, type FormEvent } from "react";
import { formatDate, formatLabel } from "../lib/format";

import {
  AlertTriangle,
  Boxes,
  CirclePlus,
  Copy,
  MapPin,
  Monitor,
  Pencil,
  Plus,
  ShieldCheck,
  RefreshCw,
  Save,
  Wifi,
  X,
} from "lucide-react";

import {
  createLockerDrawer,
  createLockerStation,
  getLockerDevices,
  getLockerStationDetail,
  getLockerStations,
  provisionLockerDevice,
  updateLockerStation,
  updateDrawerMaintenanceStatus,
  updateLockerDeviceActivation,
  type Drawer,
  type LockerDevice,
  type LockerDeviceCredentials,
  type LockerStation,
  type LockerStationDetail,
  type LockerStationInput,
} from "../api/lockers";
import { useAuth } from "../auth/AuthProvider";

const EMPTY_STATION_FORM: LockerStationInput = {
  name: "",
  code: "",
  address: "",
  latitude: "",
  longitude: "",
  status: "offline",
};

export function LockersPage() {
  const { tokens } = useAuth();
  const [stations, setStations] = useState<LockerStation[]>([]);
  const [devices, setDevices] = useState<LockerDevice[]>([]);
  const [stationDetails, setStationDetails] = useState<LockerStationDetail[]>(
    [],
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [stationFormOpen, setStationFormOpen] = useState(false);
  const [editingStationId, setEditingStationId] = useState<number | null>(null);
  const [stationForm, setStationForm] = useState<LockerStationInput>(EMPTY_STATION_FORM);
  const [drawerStationId, setDrawerStationId] = useState<number | null>(null);
  const [drawerNumber, setDrawerNumber] = useState(1);
  const [drawerSize, setDrawerSize] = useState<Drawer["size"]>("small");
  const [provisionStationId, setProvisionStationId] = useState<number | null>(null);
  const [deviceCode, setDeviceCode] = useState("");
  const [deviceCredentials, setDeviceCredentials] = useState<LockerDeviceCredentials | null>(null);
  const [saving, setSaving] = useState(false);

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

      const detailData = await Promise.all(
        stationData.map((station) =>
          getLockerStationDetail(tokens.access, station.id),
        ),
      );

      setStations(stationData);
      setDevices(deviceData);
      setStationDetails(detailData);
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

  function openNewStationForm() {
    setEditingStationId(null);
    setStationForm(EMPTY_STATION_FORM);
    setStationFormOpen(true);
    setError(null);
  }

  function openEditStationForm(station: LockerStation) {
    setEditingStationId(station.id);
    setStationForm({
      name: station.name,
      code: station.code,
      address: station.address,
      latitude: station.latitude,
      longitude: station.longitude,
      status: station.status as LockerStationInput["status"],
    });
    setStationFormOpen(true);
    setError(null);
  }

  async function handleStationSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access) return;
    setSaving(true);
    setError(null);
    try {
      if (editingStationId === null) {
        await createLockerStation(tokens.access, stationForm);
        setNotice("Locker station created.");
      } else {
        await updateLockerStation(tokens.access, editingStationId, stationForm);
        setNotice("Locker station updated.");
      }
      setStationFormOpen(false);
      await loadLockers();
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not save the locker station.");
    } finally {
      setSaving(false);
    }
  }

  async function handleDrawerSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access || drawerStationId === null) return;
    setSaving(true);
    setError(null);
    try {
      await createLockerDrawer(tokens.access, drawerStationId, drawerNumber, drawerSize);
      setNotice("Drawer added to the locker station.");
      setDrawerStationId(null);
      await loadLockers();
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not add the drawer.");
    } finally {
      setSaving(false);
    }
  }

  async function handleProvisionSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!tokens?.access || provisionStationId === null) return;
    setSaving(true);
    setError(null);
    try {
      const credentials = await provisionLockerDevice(tokens.access, provisionStationId, deviceCode);
      setDeviceCredentials(credentials);
      setProvisionStationId(null);
      setDeviceCode("");
      setNotice("Device provisioned. Copy its initial password now; it is shown only once.");
      await loadLockers();
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : "Could not provision the locker device.");
    } finally {
      setSaving(false);
    }
  }

  async function copyDeviceCredentials() {
    if (!deviceCredentials) return;
    try {
      await navigator.clipboard.writeText(
        `Device: ${deviceCredentials.device_code}\nUsername: ${deviceCredentials.username}\nInitial password: ${deviceCredentials.initial_password}`,
      );
      setNotice("Device credentials copied.");
    } catch {
      setError("Clipboard access is unavailable. Copy the credentials manually before closing this panel.");
    }
  }

  function openDrawerForm(station: LockerStationDetail) {
    const nextNumber = station.drawers.reduce((maximum, drawer) => Math.max(maximum, drawer.number), 0) + 1;
    setDrawerStationId(station.id);
    setDrawerNumber(nextNumber);
    setDrawerSize("small");
    setError(null);
  }

  async function handleDeviceActivationToggle(device: LockerDevice) {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      return;
    }

    setError(null);

    try {
      const updatedDevice = await updateLockerDeviceActivation(
        tokens.access,
        device.id,
        !device.is_active,
      );

      setDevices((currentDevices) =>
        currentDevices.map((currentDevice) =>
          currentDevice.id === updatedDevice.id ? updatedDevice : currentDevice,
        ),
      );
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not update device activation.",
      );
    }
  }

  async function handleDrawerMaintenanceToggle(
    stationId: number,
    drawer: Drawer,
  ) {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      return;
    }

    const nextStatus =
      drawer.status === "out_of_service" ? "available" : "out_of_service";

    setError(null);

    try {
      const updatedDrawer = await updateDrawerMaintenanceStatus(
        tokens.access,
        drawer.id,
        nextStatus,
      );

      setStationDetails((currentDetails) =>
        currentDetails.map((stationDetail) =>
          stationDetail.id === stationId
            ? {
                ...stationDetail,
                drawers: stationDetail.drawers.map((currentDrawer) =>
                  currentDrawer.id === updatedDrawer.id
                    ? updatedDrawer
                    : currentDrawer,
                ),
              }
            : stationDetail,
        ),
      );

      setStations((currentStations) =>
        currentStations.map((station) => {
          if (station.id !== stationId) {
            return station;
          }

          const previousWasAvailable = drawer.status === "available";
          const nextIsAvailable = updatedDrawer.status === "available";

          let availableDrawersCount = station.available_drawers_count;

          if (previousWasAvailable && !nextIsAvailable) {
            availableDrawersCount -= 1;
          }

          if (!previousWasAvailable && nextIsAvailable) {
            availableDrawersCount += 1;
          }

          return {
            ...station,
            available_drawers_count: Math.max(availableDrawersCount, 0),
          };
        }),
      );
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not update drawer maintenance status.",
      );
    }
  }

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

        <div className="products-page-actions">
          <button className="icon-text-button" type="button" onClick={() => void loadLockers()}>
            <RefreshCw size={16} /> Refresh
          </button>
          <button className="primary-action-button" type="button" onClick={openNewStationForm}>
            <CirclePlus size={16} /> Add station
          </button>
        </div>
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

      {notice && (
        <div className="products-notice" role="status">
          <ShieldCheck size={16} /><span>{notice}</span>
        </div>
      )}

      {stationFormOpen && (
        <section className="locker-admin-form-panel" aria-labelledby="station-form-heading">
          <div className="product-form-heading">
            <div><p className="eyebrow">Network configuration</p><h2 id="station-form-heading">{editingStationId === null ? "Add locker station" : "Edit locker station"}</h2></div>
            <button className="icon-button" type="button" aria-label="Close station form" onClick={() => setStationFormOpen(false)}><X size={17} /></button>
          </div>
          <form className="product-form" onSubmit={handleStationSubmit}>
            <label className="product-form-field"><span>Station name</span><input required maxLength={255} value={stationForm.name} onChange={(event) => setStationForm({ ...stationForm, name: event.target.value })} /></label>
            <label className="product-form-field"><span>Station code</span><input required maxLength={50} value={stationForm.code} onChange={(event) => setStationForm({ ...stationForm, code: event.target.value.toUpperCase() })} /></label>
            <label className="product-form-field"><span>Status</span><select value={stationForm.status} onChange={(event) => setStationForm({ ...stationForm, status: event.target.value as LockerStationInput["status"] })}><option value="online">Online</option><option value="offline">Offline</option><option value="maintenance">Maintenance</option></select></label>
            <label className="product-form-field product-form-description"><span>Address</span><textarea required rows={2} value={stationForm.address} onChange={(event) => setStationForm({ ...stationForm, address: event.target.value })} /></label>
            <label className="product-form-field"><span>Latitude</span><input required type="number" step="0.000001" min="-90" max="90" value={stationForm.latitude} onChange={(event) => setStationForm({ ...stationForm, latitude: event.target.value })} /></label>
            <label className="product-form-field"><span>Longitude</span><input required type="number" step="0.000001" min="-180" max="180" value={stationForm.longitude} onChange={(event) => setStationForm({ ...stationForm, longitude: event.target.value })} /></label>
            <div className="product-form-actions"><button className="icon-text-button" type="button" onClick={() => setStationFormOpen(false)} disabled={saving}>Cancel</button><button className="primary-action-button" type="submit" disabled={saving}><Save size={15} />{saving ? "Saving..." : editingStationId === null ? "Create station" : "Save changes"}</button></div>
          </form>
        </section>
      )}

      {drawerStationId !== null && (
        <section className="locker-admin-form-panel" aria-labelledby="drawer-form-heading">
          <div className="product-form-heading"><div><p className="eyebrow">Capacity management</p><h2 id="drawer-form-heading">Add drawer to {stationDetails.find((station) => station.id === drawerStationId)?.name}</h2></div><button className="icon-button" type="button" aria-label="Close drawer form" onClick={() => setDrawerStationId(null)}><X size={17} /></button></div>
          <form className="product-form locker-compact-form" onSubmit={handleDrawerSubmit}>
            <label className="product-form-field"><span>Drawer number</span><input required type="number" min="1" step="1" value={drawerNumber} onChange={(event) => setDrawerNumber(Number(event.target.value))} /></label>
            <label className="product-form-field"><span>Drawer size</span><select value={drawerSize} onChange={(event) => setDrawerSize(event.target.value as Drawer["size"])}><option value="small">Small</option><option value="medium">Medium</option><option value="large">Large</option></select></label>
            <div className="product-form-actions"><button className="icon-text-button" type="button" onClick={() => setDrawerStationId(null)} disabled={saving}>Cancel</button><button className="primary-action-button" type="submit" disabled={saving}><Plus size={15} />{saving ? "Adding..." : "Add drawer"}</button></div>
          </form>
        </section>
      )}

      {provisionStationId !== null && (
        <section className="locker-admin-form-panel" aria-labelledby="provision-form-heading">
          <div className="product-form-heading"><div><p className="eyebrow">Device onboarding</p><h2 id="provision-form-heading">Provision device for {stations.find((station) => station.id === provisionStationId)?.name}</h2></div><button className="icon-button" type="button" aria-label="Close device form" onClick={() => setProvisionStationId(null)}><X size={17} /></button></div>
          <form className="product-form locker-compact-form" onSubmit={handleProvisionSubmit}>
            <label className="product-form-field"><span>Device code</span><input required maxLength={100} value={deviceCode} onChange={(event) => setDeviceCode(event.target.value.toUpperCase())} placeholder="e.g. MAADI-DEVICE-001" /></label>
            <div className="product-form-actions"><button className="icon-text-button" type="button" onClick={() => setProvisionStationId(null)} disabled={saving}>Cancel</button><button className="primary-action-button" type="submit" disabled={saving}><Monitor size={15} />{saving ? "Provisioning..." : "Provision device"}</button></div>
          </form>
        </section>
      )}

      {deviceCredentials && (
        <section className="device-credentials-panel" aria-labelledby="device-credentials-heading">
          <div><p className="eyebrow">Save these credentials</p><h2 id="device-credentials-heading">Device provisioned successfully</h2><p>The initial password is displayed once. Copy it and store it securely before closing this panel.</p></div>
          <dl><div><dt>Device</dt><dd>{deviceCredentials.device_code}</dd></div><div><dt>Username</dt><dd>{deviceCredentials.username}</dd></div><div><dt>Initial password</dt><dd className="mono-cell">{deviceCredentials.initial_password}</dd></div></dl>
          <div className="products-page-actions"><button className="primary-action-button" type="button" onClick={() => void copyDeviceCredentials()}><Copy size={15} />Copy credentials</button><button className="icon-text-button" type="button" onClick={() => setDeviceCredentials(null)}>Close</button></div>
        </section>
      )}

      {!loading && !error && (
        <div className="orders-page-shell">
          <section
            className="orders-summary-panel"
            aria-labelledby="locker-summary-heading"
          >
            <h2 id="locker-summary-heading" className="section-heading">
              Locker summary
            </h2>
            <p className="section-subtitle">
              {totals.stations} station{totals.stations === 1 ? "" : "s"} and{" "}
              {devices.length} device{devices.length === 1 ? "" : "s"} returned
              by the API.
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
                <p className="module-copy">
                  Locker locations managed by SmartDrop.
                </p>
              </article>

              <article className="metric-card metric-card-success">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Boxes size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">
                    {totals.availableDrawers}
                  </span>
                </div>
                <h3 className="module-title">Available drawers</h3>
                <p className="module-copy">
                  Drawers currently available for assignment.
                </p>
              </article>

              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Monitor size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.activeDevices}</span>
                </div>
                <h3 className="module-title">Active devices</h3>
                <p className="module-copy">
                  Registered locker devices marked active.
                </p>
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
                  <span className="metric-value">
                    {totals.unhealthyDevices}
                  </span>
                </div>
                <h3 className="module-title">Unhealthy devices</h3>
                <p className="module-copy">
                  Devices that are stale, inactive, or offline.
                </p>
              </article>
            </div>
          </section>

          <section
            className="orders-table-panel"
            aria-labelledby="stations-heading"
          >
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
              <div className="locker-station-grid">
                {stations.map((station) => {
                  const detail = stationDetails.find((item) => item.id === station.id);
                  const device = devices.find((item) => item.locker_station_id === station.id);
                  return (
                    <article className="locker-station-card" key={station.id}>
                      <div className="locker-station-card-top">
                        <span className="locker-station-mark"><Boxes size={21} /></span>
                        <span className={`status-badge status-${station.status}`}>{formatLabel(station.status)}</span>
                      </div>
                      <h3>{station.name}</h3>
                      <span className="mono-cell locker-station-code">{station.code}</span>
                      <p className="locker-station-address"><MapPin size={14} />{station.address}</p>
                      <div className="locker-station-facts">
                        <div><strong>{station.available_drawers_count}</strong><span>Available drawers</span></div>
                        <div><strong>{detail?.drawers.length ?? 0}</strong><span>Total capacity</span></div>
                      </div>
                      {device && <div className="locker-station-device"><Monitor size={14} /><span>{device.device_code}</span><span className={`status-badge status-${device.connection_status}`}>{formatLabel(device.connection_status)}</span></div>}
                      <div className="locker-row-actions">
                        <button className="product-edit-button" type="button" onClick={() => openEditStationForm(station)}><Pencil size={14} /> Edit station</button>
                        <button className="product-edit-button" type="button" onClick={() => { if (detail) openDrawerForm(detail); }} disabled={!detail}><Plus size={14} /> Add drawer</button>
                        {!device && <button className="product-edit-button" type="button" onClick={() => { setProvisionStationId(station.id); setDeviceCode(""); setDeviceCredentials(null); }}><Monitor size={14} /> Add device</button>}
                      </div>
                      <small className="locker-station-coordinates">{station.latitude}, {station.longitude}</small>
                    </article>
                  );
                })}
              </div>
            )}
          </section>

          <section
            className="orders-table-panel"
            aria-labelledby="drawers-heading"
          >
            <h2 id="drawers-heading" className="section-heading">
              Drawers
            </h2>
            <p className="section-subtitle">
              Drawer size, status, and maintenance controls by locker station.
            </p>

            {stationDetails.length === 0 ? (
              <div className="empty-panel">
                <Boxes size={18} />
                <span>No drawers found.</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Locker</th>
                      <th>Drawer</th>
                      <th>Size</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stationDetails.flatMap((stationDetail) =>
                      stationDetail.drawers.map((drawer) => (
                        <tr key={drawer.id}>
                          <td>{stationDetail.name}</td>
                          <td>{drawer.number}</td>
                          <td>{formatLabel(drawer.size)}</td>
                          <td>
                            <span
                              className={`status-badge status-${drawer.status}`}
                            >
                              {formatLabel(drawer.status)}
                            </span>
                          </td>
                          <td>
                            <button
                              className={`table-action-button ${
                                drawer.status === "out_of_service"
                                  ? "table-action-success"
                                  : "table-action-danger"
                              }`}
                              type="button"
                              onClick={() =>
                                handleDrawerMaintenanceToggle(
                                  stationDetail.id,
                                  drawer,
                                )
                              }
                            >
                              {drawer.status === "out_of_service"
                                ? "Mark available"
                                : "Mark out of service"}
                            </button>
                          </td>
                        </tr>
                      )),
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section
            className="orders-table-panel"
            aria-labelledby="devices-heading"
          >
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
                      <th>Action</th>
                      <th>Connection</th>
                      <th>Last heartbeat</th>
                      <th>Updated</th>
                    </tr>
                  </thead>
                  <tbody>
                    {devices.map((device) => (
                      <tr key={device.id}>
                        <td>
                          <span className="mono-cell">
                            {device.device_code}
                          </span>
                        </td>
                        <td>{device.locker_name}</td>
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
                          >
                            {device.is_active ? "Deactivate" : "Activate"}
                          </button>
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
