import { apiGet, apiPatch } from "./client";

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

export function getLockerStations(
  accessToken: string,
): Promise<LockerStation[]> {
  return apiGet<LockerStation[]>("/api/lockers/", accessToken);
}

export function getLockerStationDetail(
  accessToken: string,
  stationId: number,
): Promise<LockerStationDetail> {
  return apiGet<LockerStationDetail>(
    `/api/lockers/${stationId}/`,
    accessToken,
  );
}

export function getLockerDevices(
  accessToken: string,
): Promise<LockerDevice[]> {
  return apiGet<LockerDevice[]>("/api/lockers/admin/devices/", accessToken);
}

export function updateLockerDeviceActivation(
  accessToken: string,
  deviceId: number,
  isActive: boolean,
): Promise<LockerDevice> {
  return apiPatch<LockerDevice>(
    `/api/lockers/admin/devices/${deviceId}/activation/`,
    accessToken,
    { is_active: isActive },
  );
}

export function updateDrawerMaintenanceStatus(
  accessToken: string,
  drawerId: number,
  status: "available" | "out_of_service",
): Promise<Drawer> {
  return apiPatch<Drawer>(
    `/api/lockers/admin/drawers/${drawerId}/maintenance-status/`,
    accessToken,
    { status },
  );
}