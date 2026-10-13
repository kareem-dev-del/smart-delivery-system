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

const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000"
).replace(/\/$/, "");

export async function getAuditLog(
  accessToken: string,
): Promise<AuditLogResponse> {
  const response = await fetch(`${API_BASE_URL}/api/audit/`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(
      `Audit log request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<AuditLogResponse>;
}