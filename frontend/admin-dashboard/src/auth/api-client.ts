import { API_BASE_URL } from "../api/client";
import type { AuthTokens, LoginResponse, User } from "./types";

const env = import.meta.env;
const LOGIN_PATH = env.VITE_AUTH_LOGIN_PATH || "/api/token/";
const CURRENT_USER_PATH = env.VITE_AUTH_CURRENT_USER_PATH || "/api/accounts/me/";

function buildApiUrl(path: string): string {
  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}

function extractErrorMessage(payload: Record<string, unknown>): string {
  const message = payload.detail ?? payload.non_field_errors ?? payload.error;

  if (Array.isArray(message)) {
    return message.join(" ");
  }

  if (typeof message === "string") {
    return message;
  }

  return Object.entries(payload)
    .filter(([, value]) => typeof value === "string" || Array.isArray(value))
    .map(([key, value]) => {
      const fieldMessage = Array.isArray(value) ? value.join(" ") : value;
      return `${key}: ${fieldMessage}`;
    })
    .join(" ");
}

async function request<T>(path: string, init: RequestInit): Promise<T> {
  let response: Response;

  try {
    response = await fetch(buildApiUrl(path), {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...init.headers,
      },
    });
  } catch {
    throw new Error(
      `Unable to reach the authentication server at ${API_BASE_URL}. Check that the API is running and allows requests from this app.`,
    );
  }

  if (!response.ok) {
    let detail = "";

    try {
      const payload = (await response.json()) as Record<string, unknown>;
      detail = extractErrorMessage(payload);
    } catch {
      // A non-JSON API error is still reported with its status below.
    }

    throw new Error(
      detail ||
        `Authentication request failed (${response.status} ${response.statusText}).`,
    );
  }

  return response.json() as Promise<T>;
}

export async function postLogin(
  username: string,
  password: string,
): Promise<LoginResponse> {
  return request<LoginResponse>(LOGIN_PATH, {
    method: "POST",
    body: JSON.stringify({ username, password }),
  });
}

export async function getCurrentUser(accessToken: string): Promise<User> {
  const user = await request<unknown>(CURRENT_USER_PATH, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  if (!isUser(user)) {
    throw new Error("The current-user response did not include a valid username.");
  }

  return user;
}

export function tokensFromResponse(response: LoginResponse): AuthTokens {
  return {
    access: response.access,
    ...(response.refresh ? { refresh: response.refresh } : {}),
  };
}

export function isUser(value: unknown): value is User {
  return (
    !!value &&
    typeof value === "object" &&
    typeof (value as User).username === "string"
  );
}

export function isLoginResponse(value: unknown): value is LoginResponse {
  return (
    !!value &&
    typeof value === "object" &&
    typeof (value as LoginResponse).access === "string"
  );
}

export function isAdminUser(user: User | null): boolean {
  return (
    user?.is_staff === true ||
    user?.is_superuser === true ||
    user?.role?.toLowerCase() === "admin"
  );
}