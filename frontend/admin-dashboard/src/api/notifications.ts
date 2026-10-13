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

const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000"
).replace(/\/$/, "");

export async function getNotifications(
  accessToken: string,
): Promise<NotificationsResponse> {
  const response = await fetch(`${API_BASE_URL}/api/notifications/`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(
      `Notifications request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<NotificationsResponse>;
}