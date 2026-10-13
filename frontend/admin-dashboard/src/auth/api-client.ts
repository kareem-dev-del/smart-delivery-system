import type { AuthTokens, LoginResponse, User } from './types';

const env = import.meta.env;
const API_BASE_URL = (env.VITE_API_BASE_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');
const LOGIN_PATH = env.VITE_AUTH_LOGIN_PATH || '/api/token/';
const CURRENT_USER_PATH = env.VITE_AUTH_CURRENT_USER_PATH || '/api/accounts/me/';

async function request<T>(path: string, init: RequestInit): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path.startsWith('/') ? path : `/${path}`}`, {
      ...init,
      headers: { 'Content-Type': 'application/json', ...init.headers },
    });
  } catch {
    throw new Error(`Unable to reach the authentication server at ${API_BASE_URL}. Check that the API is running and allows requests from this app.`);
  }

  if (!response.ok) {
    let detail = '';
    try {
      const payload = await response.json() as Record<string, unknown>;
      const message = payload.detail ?? payload.non_field_errors ?? payload.error;
      detail = Array.isArray(message) ? message.join(' ') : typeof message === 'string' ? message : '';
      if (!detail) {
        const fields = Object.entries(payload).filter(([, value]) => typeof value === 'string' || Array.isArray(value))
          .map(([key, value]) => `${key}: ${Array.isArray(value) ? value.join(' ') : value}`).join(' ');
        detail = fields;
      }
    } catch {
      // A non-JSON API error is still reported with its status below.
    }
    throw new Error(detail || `Authentication request failed (${response.status} ${response.statusText}).`);
  }
  return response.json() as Promise<T>;
}

export async function postLogin(username: string, password: string): Promise<LoginResponse> {
  return request<LoginResponse>(LOGIN_PATH, {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
}

export async function getCurrentUser(accessToken: string): Promise<User> {
  const user: unknown = await request<unknown>(CURRENT_USER_PATH, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!isUser(user)) {
    throw new Error('The current-user response did not include a valid username.');
  }
  return user;
}

export function tokensFromResponse(response: LoginResponse): AuthTokens {
  return { access: response.access, ...(response.refresh ? { refresh: response.refresh } : {}) };
}

export function isUser(value: unknown): value is User {
  return !!value && typeof value === 'object' && typeof (value as User).username === 'string';
}

export function isLoginResponse(value: unknown): value is LoginResponse {
  return !!value && typeof value === 'object' && typeof (value as LoginResponse).access === 'string';
}

export function isAdminUser(user: User | null): boolean {
  if (user?.is_staff === true || user?.is_superuser === true || user?.role?.toLowerCase() === 'admin') return true;
  return false;
}
