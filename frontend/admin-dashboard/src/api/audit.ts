import { apiGet } from "./client";

export interface AuditLogEntry {
  id: number;
  actor: number | null;
  actor_username: string | null;
  action: string;
  target_type: string;
  target_id: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface AuditLogResponse {
  count: number;
  next: string | null;
  previous: string | null;
  results: AuditLogEntry[];
}

export function getAuditLog(accessToken: string): Promise<AuditLogResponse> {
  return apiGet<AuditLogResponse>("/api/audit/", accessToken);
}