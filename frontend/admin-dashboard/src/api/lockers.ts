import { apiGet, apiPatch, apiPost } from "./client";

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

export interface LockerStationInput {
  name: string;
  code: string;
  address: string;
  latitude: string;
  longitude: string;
  status: "online" | "offline" | "maintenance";
}

export interface LockerDeviceCredentials {
  device_id: number;
  locker_station_id: number;
  locker_code: string;
  device_code: string;
  username: string;
  initial_password: string;
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

export function createLockerStation(
  accessToken: string,
  station: LockerStationInput,
): Promise<LockerStationInput & { id: number }> {
  return apiPost<LockerStationInput & { id: number }>(
    "/api/lockers/admin/stations/",
    accessToken,
    station,
  );
}

export function updateLockerStation(
  accessToken: string,
  stationId: number,
  station: LockerStationInput,
): Promise<LockerStationInput & { id: number }> {
  return apiPatch<LockerStationInput & { id: number }>(
    `/api/lockers/admin/stations/${stationId}/`,
    accessToken,
    station,
  );
}

export function createLockerDrawer(
  accessToken: string,
  stationId: number,
  number: number,
  size: Drawer["size"],
): Promise<Drawer> {
  return apiPost<Drawer>(
    `/api/lockers/admin/stations/${stationId}/drawers/`,
    accessToken,
    { number, size },
  );
}

export function provisionLockerDevice(
  accessToken: string,
  stationId: number,
  deviceCode: string,
): Promise<LockerDeviceCredentials> {
  return apiPost<LockerDeviceCredentials>(
    `/api/lockers/admin/stations/${stationId}/device/`,
    accessToken,
    { device_code: deviceCode },
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
