import { apiGet, apiPost } from "./client";

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

export interface CourierAssignment {
  order_public_id: string;
  courier_id: number;
  courier_username: string;
  courier_assigned_at: string;
}

export function getAdminOrders(
  accessToken: string,
  filters: { status?: string; search?: string; page?: number; pageSize?: number } = {},
): Promise<AdminOrdersResponse> {
  const query = new URLSearchParams();
  if (filters.status) query.set("status", filters.status);
  if (filters.search?.trim()) query.set("search", filters.search.trim());
  if (filters.page && filters.page > 1) query.set("page", String(filters.page));
  if (filters.pageSize) query.set("page_size", String(filters.pageSize));
  const suffix = query.size > 0 ? `?${query.toString()}` : "";
  return apiGet<AdminOrdersResponse>(`/api/orders/admin/${suffix}`, accessToken);
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

export function assignCourierToOrder(
  accessToken: string,
  publicId: string,
  courierId: number,
): Promise<CourierAssignment> {
  return apiPost<CourierAssignment>(
    `/api/orders/${publicId}/assign-courier/`,
    accessToken,
    { courier_id: courierId },
  );
}

export function assignOrderToDrawer(
  accessToken: string,
  publicId: string,
  lockerStationId: number,
  drawerId: number,
): Promise<AdminOrder> {
  return apiPost<AdminOrder>(
    `/api/orders/${publicId}/assign/`,
    accessToken,
    {
      locker_station_id: lockerStationId,
      drawer_id: drawerId,
    },
  );
}
