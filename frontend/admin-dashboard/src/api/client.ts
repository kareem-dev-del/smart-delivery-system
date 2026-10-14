const DEFAULT_API_BASE_URL = "http://127.0.0.1:8000";

export const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL || DEFAULT_API_BASE_URL
).replace(/\/$/, "");

type ApiMethod = "GET" | "POST" | "PATCH" | "PUT" | "DELETE";

interface ApiRequestOptions {
  accessToken: string;
  method?: ApiMethod;
  body?: unknown;
}

export class ApiRequestError extends Error {
  status: number;
  statusText: string;
  details: unknown;

  constructor(status: number, statusText: string, details: unknown) {
    super(`API request failed (${status} ${statusText}).`);
    this.name = "ApiRequestError";
    this.status = status;
    this.statusText = statusText;
    this.details = details;
  }
}

async function parseResponse(response: Response): Promise<unknown> {
  if (response.status === 204) {
    return null;
  }

  const contentType = response.headers.get("Content-Type") ?? "";

  if (contentType.includes("application/json")) {
    return response.json();
  }

  return response.text();
}

export async function apiRequest<T>(
  path: string,
  options: ApiRequestOptions,
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? "GET",
    headers: {
      Authorization: `Bearer ${options.accessToken}`,
      "Content-Type": "application/json",
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const parsedResponse = await parseResponse(response);

  if (!response.ok) {
    throw new ApiRequestError(
      response.status,
      response.statusText,
      parsedResponse,
    );
  }

  return parsedResponse as T;
}

export function apiGet<T>(path: string, accessToken: string): Promise<T> {
  return apiRequest<T>(path, {
    accessToken,
    method: "GET",
  });
}

export function apiPatch<T>(
  path: string,
  accessToken: string,
  body: unknown,
): Promise<T> {
  return apiRequest<T>(path, {
    accessToken,
    method: "PATCH",
    body,
  });
}