import { apiGet } from "./client";

export interface NotificationItem {
  id: number;
  notification_type: string;
  title: string;
  message: string;
  data: Record<string, unknown>;
  order_public_id: string | null;
  is_read: boolean;
  delivery_status: string;
  delivery_attempts: number;
  delivered_at: string | null;
  delivery_error: string;
  read_at: string | null;
  created_at: string;
}

export interface NotificationsResponse {
  count: number;
  next: string | null;
  previous: string | null;
  results: NotificationItem[];
}

export function getNotifications(
  accessToken: string,
): Promise<NotificationsResponse> {
  return apiGet<NotificationsResponse>("/api/notifications/", accessToken);
}