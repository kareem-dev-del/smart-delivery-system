import { apiGet, apiPatch, apiPost } from "./client";
import type { LoginResponse, User } from "../auth/types";

export interface AdminCourier {
  id: number;
  username: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  role: "courier";
  is_active: boolean;
  is_on_shift: boolean;
  shift_updated_at: string | null;
  active_order_count: number;
  dispatch_status: "inactive" | "off_shift" | "busy" | "available";
}

export function getAdminCouriers(accessToken: string): Promise<AdminCourier[]> {
  return apiGet<AdminCourier[]>("/api/accounts/admin/couriers/", accessToken);
}

export type ManagedAccountRole = "customer" | "courier" | "admin";

export interface ManagedAccount extends Omit<AdminCourier, "role" | "dispatch_status"> {
  role: ManagedAccountRole;
  is_active: boolean;
  dispatch_status: AdminCourier["dispatch_status"] | "not_applicable";
}

export interface ManagedAccountInput {
  username: string;
  password: string;
  password_confirm: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  role: ManagedAccountRole;
}

export function getManagedAccounts(accessToken: string): Promise<ManagedAccount[]> {
  return apiGet<ManagedAccount[]>("/api/accounts/admin/users/", accessToken);
}

export function createManagedAccount(
  accessToken: string,
  account: ManagedAccountInput,
): Promise<ManagedAccount> {
  return apiPost<ManagedAccount>("/api/accounts/admin/users/", accessToken, account);
}

export function updateManagedAccountStatus(
  accessToken: string,
  userId: number,
  isActive: boolean,
): Promise<ManagedAccount> {
  return apiPatch<ManagedAccount>(
    `/api/accounts/admin/users/${userId}/status/`,
    accessToken,
    { is_active: isActive },
  );
}

export function updateCourierShift(
  accessToken: string,
  userId: number,
  isOnShift: boolean,
): Promise<ManagedAccount> {
  return apiPatch<ManagedAccount>(
    `/api/accounts/admin/couriers/${userId}/shift/`,
    accessToken,
    { is_on_shift: isOnShift },
  );
}

export interface AccountProfile extends User {
  id: number;
  username: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  role: string;
}

export interface AccountProfileInput {
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
}

export interface ChangePasswordInput {
  current_password: string;
  new_password: string;
  new_password_confirm: string;
}

export function getMyAccount(accessToken: string): Promise<AccountProfile> {
  return apiGet<AccountProfile>("/api/accounts/me/", accessToken);
}

export function updateMyAccount(
  accessToken: string,
  profile: Partial<AccountProfileInput>,
): Promise<AccountProfile> {
  return apiPatch<AccountProfile>("/api/accounts/me/", accessToken, profile);
}

export function changeMyPassword(
  accessToken: string,
  password: ChangePasswordInput,
): Promise<LoginResponse & { user: AccountProfile }> {
  return apiPost<LoginResponse & { user: AccountProfile }>(
    "/api/accounts/change-password/",
    accessToken,
    password,
  );
}
