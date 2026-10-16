import { apiGet } from "./client";

export interface OrderItem {
  product: number;
  product_name: string;
  product_size: string;
  unit_price: string;
  quantity: number;
  line_total: string;
}

export interface OrderLocker {
  id: number;
  name: string;
  code: string;
  address: string;
  latitude: string;
  longitude: string;
}

export interface AdminOrder {
  public_id: string;
  status: string;
  total_amount: string;
  locker: OrderLocker | null;
  courier_assigned_at: string | null;
  assigned_at: string | null;
  ready_for_pickup_at: string | null;
  delivery_deadline: string | null;
  collected_at: string | null;
  returned_at: string | null;
  cancelled_at: string | null;
  created_at: string;
  updated_at: string;
  items: OrderItem[];
  customer: number;
  customer_username: string;
  assigned_courier: number | null;
  assigned_courier_username: string | null;
  locker_station: number | null;
  assigned_drawer: number | null;
  assigned_drawer_number: number | null;
  pickup_opened_at: string | null;
  return_opened_at: string | null;
}

export interface AdminOrdersResponse {
  count: number;
  next: string | null;
  previous: string | null;
  results: AdminOrder[];
}

export function getAdminOrders(
  accessToken: string,
): Promise<AdminOrdersResponse> {
  return apiGet<AdminOrdersResponse>("/api/orders/admin/", accessToken);
}

export function getAdminOrder(
  accessToken: string,
  publicId: string,
): Promise<AdminOrder> {
  return apiGet<AdminOrder>(
    `/api/orders/${publicId}/`,
    accessToken,
  );
}