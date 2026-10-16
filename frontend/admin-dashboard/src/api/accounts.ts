import { apiGet } from "./client";

export interface AdminCourier {
  id: number;
  username: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  role: "courier";
}

export function getAdminCouriers(accessToken: string): Promise<AdminCourier[]> {
  return apiGet<AdminCourier[]>("/api/accounts/admin/couriers/", accessToken);
}
