import { apiGet } from "./client";

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

export function getDashboardSummary(
  accessToken: string,
): Promise<DashboardSummary> {
  return apiGet<DashboardSummary>(
    "/api/lockers/admin/dashboard/",
    accessToken,
  );
}