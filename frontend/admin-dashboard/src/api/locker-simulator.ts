import { API_BASE_URL, apiRequest } from "./client";

export interface LockerHeartbeat {
  device_code: string;
  locker_code: string;
  locker_status: string;
  last_heartbeat_at: string;
}

export interface OpenDrawerCommand {
  command: "open_drawer";
  drawer_number: number;
  order_public_id: string;
}

export interface DeviceActionResult {
  order_public_id: string;
  status: string;
  drawer_number: number;
  drawer_status: string;
  collected_at?: string;
}

export async function loginLockerDevice(
  username: string,
  password: string,
): Promise<string> {
  const response = await fetch(`${API_BASE_URL}/api/token/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password }),
  });
  const payload = (await response.json()) as {
    access?: string;
    detail?: string;
  };
  if (!response.ok || !payload.access) {
    throw new Error(payload.detail || "Device sign-in failed. Check its username and password.");
  }
  return payload.access;
}

function idempotencyHeaders(): Record<string, string> {
  return { "Idempotency-Key": crypto.randomUUID() };
}

export function sendLockerHeartbeat(accessToken: string) {
  return apiRequest<LockerHeartbeat>("/api/lockers/device/heartbeat/", {
    accessToken,
    method: "POST",
  });
}

export function simulatePackageDeposit(
  accessToken: string,
  publicId: string,
) {
  return apiRequest<{ public_id: string; status: string }>(
    `/api/orders/${publicId}/deposit/`,
    {
      accessToken,
      method: "POST",
      headers: idempotencyHeaders(),
    },
  );
}

export function authorizeSimulatedPickup(
  accessToken: string,
  token: string,
) {
  return apiRequest<OpenDrawerCommand>("/api/lockers/pickup-scan/", {
    accessToken,
    method: "POST",
    body: { token },
    headers: idempotencyHeaders(),
  });
}

export function confirmSimulatedCollection(
  accessToken: string,
  publicId: string,
) {
  return apiRequest<DeviceActionResult>(
    `/api/lockers/orders/${publicId}/confirm-collection/`,
    {
      accessToken,
      method: "POST",
      headers: idempotencyHeaders(),
    },
  );
}
