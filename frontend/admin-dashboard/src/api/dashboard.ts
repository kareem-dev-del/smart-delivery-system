export interface DashboardSummary {
  generated_at: string;
  totals: {
    orders: number;
    locker_stations: number;
    drawers: number;
    locker_devices: number;
    notifications: number;
  };
  orders_by_status: Record<string, number>;
  locker_stations_by_status: Record<string, number>;
  drawers_by_status: Record<string, number>;
  devices_by_connection_status: Record<string, number>;
  notifications_by_delivery_status: Record<string, number>;
  action_required: {
    awaiting_locker_orders: number;
    expired_orders: number;
    failed_notifications: number;
    pending_notifications: number;
    unhealthy_devices: number;
  };
}

const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000"
).replace(/\/$/, "");

export async function getDashboardSummary(
  accessToken: string,
): Promise<DashboardSummary> {
  const response = await fetch(`${API_BASE_URL}/api/lockers/admin/dashboard/`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(
      `Dashboard request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<DashboardSummary>;
}