export interface LockerStation {
  id: number;
  name: string;
  code: string;
  address: string;
  latitude: string;
  longitude: string;
  status: string;
  available_drawers_count: number;
}

export interface Drawer {
  id: number;
  number: number;
  size: string;
  status: string;
}

export interface LockerStationDetail extends LockerStation {
  drawers: Drawer[];
}

export interface LockerDevice {
  id: number;
  locker_station_id: number;
  locker_name: string;
  locker_code: string;
  locker_station_status: string;
  device_code: string;
  is_active: boolean;
  last_heartbeat_at: string | null;
  connection_status: string;
  created_at: string;
  updated_at: string;
}

const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000"
).replace(/\/$/, "");

async function requestJson<T>(path: string, accessToken: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(
      `Lockers request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<T>;
}

export async function getLockerStations(
  accessToken: string,
): Promise<LockerStation[]> {
  return requestJson<LockerStation[]>("/api/lockers/", accessToken);
}

export async function getLockerStationDetail(
  accessToken: string,
  stationId: number,
): Promise<LockerStationDetail> {
  return requestJson<LockerStationDetail>(`/api/lockers/${stationId}/`, accessToken);
}

export async function getLockerDevices(
  accessToken: string,
): Promise<LockerDevice[]> {
  return requestJson<LockerDevice[]>("/api/lockers/admin/devices/", accessToken);
}

export async function updateLockerDeviceActivation(
  accessToken: string,
  deviceId: number,
  isActive: boolean,
): Promise<LockerDevice> {
  const response = await fetch(
    `${API_BASE_URL}/api/lockers/admin/devices/${deviceId}/activation/`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ is_active: isActive }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `Device activation request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<LockerDevice>;
}

export async function updateDrawerMaintenanceStatus(
  accessToken: string,
  drawerId: number,
  status: "available" | "out_of_service",
): Promise<Drawer> {
  const response = await fetch(
    `${API_BASE_URL}/api/lockers/admin/drawers/${drawerId}/maintenance-status/`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ status }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `Drawer maintenance request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<Drawer>;
}