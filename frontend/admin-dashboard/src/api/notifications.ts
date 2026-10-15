import { apiGet } from "./client";


export interface AdminNotification {
  id: number;
  notification_type: string;
  title: string;
  message: string;
  data: Record<string, unknown>;
  order_public_id: string | null;
  recipient: number;
  recipient_username: string;
  is_read: boolean;
  delivery_status: string;
  delivery_attempts: number;
  delivered_at: string | null;
  delivery_error: string;
  read_at: string | null;
  created_at: string;
}

export interface AdminNotificationsResponse {
  count: number;
  next: string | null;
  previous: string | null;
  results: AdminNotification[];
}

export function getAdminNotifications(
  accessToken: string,
): Promise<AdminNotificationsResponse> {
  return apiGet<AdminNotificationsResponse>(
    "/api/notifications/admin/",
    accessToken,
  );
}