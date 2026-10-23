import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { getCurrentUser, isAdminUser, isLoginResponse, isUser, postLogin, tokensFromResponse } from './api-client';
import type { AuthState, AuthTokens, User } from './types';

const STORAGE_KEY = 'smartdrop.auth.v1';
interface StoredAuth { tokens: AuthTokens }
interface AuthContextValue extends AuthState {
  ready: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  updateUser: (user: User) => void;
  replaceSession: (user: User, tokens: AuthTokens) => void;
}
const AuthContext = createContext<AuthContextValue | null>(null);

function readStoredAuth(): StoredAuth | null {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null') as Partial<StoredAuth> | null;
    if (parsed?.tokens && typeof parsed.tokens.access === 'string') {
      return { tokens: parsed.tokens };
    }
  } catch {
    localStorage.removeItem(STORAGE_KEY);
  }
  return null;
}

function persist(tokens: AuthTokens | null) {
  if (!tokens) {
    localStorage.removeItem(STORAGE_KEY);
    return;
  }
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ tokens }));
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>({ user: null, tokens: null, isAdmin: false });
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let active = true;
    const stored = readStoredAuth();
    if (!stored) {
      setReady(true);
      return () => { active = false; };
    }
    const hydrate = async () => {
      let user: User;
      try {
        user = await getCurrentUser(stored.tokens.access);
      } catch {
        persist(null);
        if (active) {
          setAuth({ user: null, tokens: null, isAdmin: false });
          setReady(true);
        }
        return;
      }
      if (active) {
        persist(stored.tokens);
        setAuth({ user, tokens: stored.tokens, isAdmin: isAdminUser(user) });
        setReady(true);
      }
    };
    void hydrate();
    return () => { active = false; };
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    const payload: unknown = await postLogin(username, password);
    if (!isLoginResponse(payload)) throw new Error('The sign-in response did not include an access token.');
    const tokens = tokensFromResponse(payload);
    const user = isUser(payload.user) ? payload.user : await getCurrentUser(tokens.access);
    persist(tokens);
    setAuth({ user, tokens, isAdmin: isAdminUser(user) });
  }, []);

  const logout = useCallback(() => {
    persist(null);
    setAuth({ user: null, tokens: null, isAdmin: false });
  }, []);

  const updateUser = useCallback((user: User) => {
    setAuth((current) => ({ ...current, user, isAdmin: isAdminUser(user) }));
  }, []);

  const replaceSession = useCallback((user: User, tokens: AuthTokens) => {
    persist(tokens);
    setAuth({ user, tokens, isAdmin: isAdminUser(user) });
  }, []);

  const value = useMemo(() => ({ ...auth, ready, login, logout, updateUser, replaceSession }), [auth, ready, login, logout, updateUser, replaceSession]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider.');
  return value;
}
