import { useEffect, useMemo, useState } from "react";
import { formatDate, formatLabel } from "../lib/format";
import { useAuth } from "../auth/AuthProvider";
import {
  AlertTriangle,
  Bell,
  CheckCircle2,
  Mail,
  RefreshCw,
} from "lucide-react";

import {
  getAdminNotifications,
  type AdminNotification,
} from "../api/notifications";



function getOrderId(notification: AdminNotification): string {
  return notification.order_public_id ?? "-";
}

export function NotificationsPage() {
  const { tokens } = useAuth();
  const [notifications, setNotifications] = useState<AdminNotification[]>([]);
  const [count, setCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadNotifications() {
    if (!tokens?.access) {
      setError("Missing access token. Please sign in again.");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data = await getAdminNotifications(tokens.access);
      setNotifications(data.results);
      setCount(data.count);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Could not load notifications.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadNotifications();
  }, [tokens?.access]);

  const totals = useMemo(() => {
    const unread = notifications.filter(
      (notification) => !notification.is_read,
    ).length;
    const pending = notifications.filter(
      (notification) => notification.delivery_status === "pending",
    ).length;
    const failed = notifications.filter(
      (notification) => notification.delivery_status === "failed",
    ).length;

    return {
      unread,
      pending,
      failed,
    };
  }, [notifications]);

  return (
    <>
      <div className="dashboard-intro">
        <div>
          <p className="eyebrow">Network control / Notifications</p>
          <h1 className="page-title">Notifications</h1>
          <p className="page-description">
            Platform-wide delivery monitoring for all SmartDrop recipients.
          </p>
        </div>

        <button
          className="icon-text-button"
          type="button"
          onClick={loadNotifications}
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {loading && (
        <div className="scope-note">
          <Bell size={15} />
          <span>Loading notifications...</span>
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
            aria-labelledby="notifications-summary-heading"
          >
            <h2 id="notifications-summary-heading" className="section-heading">
              Notification summary
            </h2>
            <p className="section-subtitle">
              {count} notification{count === 1 ? "" : "s"} returned by the API.
            </p>

            <div className="module-grid">
              <article className="metric-card metric-card-neutral">
                <div className="module-card-top">
                  <div className="module-icon">
                    <Bell size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{count}</span>
                </div>
                <h3 className="module-title">Total notifications</h3>
                <p className="module-copy">
                  Notifications created across the SmartDrop platform.
                </p>
              </article>

              <article
                className={`metric-card ${
                  totals.unread > 0 ? "metric-card-warning" : "metric-card-success"
                }`}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <Mail size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.unread}</span>
                </div>
                <h3 className="module-title">Unread</h3>
                <p className="module-copy">
                  Notifications still waiting to be read.
                </p>
              </article>

              <article
                className={`metric-card ${
                  totals.pending > 0
                    ? "metric-card-warning"
                    : "metric-card-success"
                }`}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <RefreshCw size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.pending}</span>
                </div>
                <h3 className="module-title">Pending delivery</h3>
                <p className="module-copy">
                  Notifications waiting for email delivery processing.
                </p>
              </article>

              <article
                className={`metric-card ${
                  totals.failed > 0 ? "metric-card-danger" : "metric-card-success"
                }`}
              >
                <div className="module-card-top">
                  <div className="module-icon">
                    <AlertTriangle size={17} strokeWidth={1.8} />
                  </div>
                  <span className="metric-value">{totals.failed}</span>
                </div>
                <h3 className="module-title">Failed delivery</h3>
                <p className="module-copy">
                  Notifications that could not be delivered by email.
                </p>
              </article>
            </div>
          </section>

          <section
            className="orders-table-panel"
            aria-labelledby="notifications-table-heading"
          >
            <h2 id="notifications-table-heading" className="section-heading">
              Notification list
            </h2>
            <p className="section-subtitle">
              Type, message, delivery status, and read state.
            </p>

            {notifications.length === 0 ? (
              <div className="empty-panel">
                <CheckCircle2 size={18} />
                <span>No platform notifications found.</span>
              </div>
            ) : (
              <div className="table-shell">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Notification</th>
                      <th>Recipient</th>
                      <th>Type</th>
                      <th>Order</th>
                      <th>Read</th>
                      <th>Delivery</th>
                      <th>Attempts</th>
                      <th>Created</th>
                      <th>Delivered</th>
                    </tr>
                  </thead>
                  <tbody>
                    {notifications.map((notification) => (
                      <tr key={notification.id}>
                        <td>
                          <strong>{notification.title}</strong>
                          <span className="table-secondary-text">
                            {notification.message}
                          </span>
                        </td>

                        <td>
                            <strong>{notification.recipient_username}</strong>
                            <span className="table-secondary-text">
                              Recipient ID {notification.recipient}
                            </span>
                          </td>
                        <td>{formatLabel(notification.notification_type)}</td>
                        <td>
                          <span className="mono-cell">
                            {getOrderId(notification).slice(0, 8)}
                          </span>
                        </td>
                        <td>{notification.is_read ? "Yes" : "No"}</td>
                        <td>
                          <span
                            className={`status-badge status-${notification.delivery_status}`}
                          >
                            {formatLabel(notification.delivery_status)}
                          </span>
                        </td>
                        <td>{notification.delivery_attempts}</td>
                        <td>{formatDate(notification.created_at)}</td>
                        <td>{formatDate(notification.delivered_at)}</td>
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