export interface User {
  id?: string | number;
  username: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  is_staff?: boolean;
  is_superuser?: boolean;
  role?: string;
}

export interface AuthTokens {
  access: string;
  refresh?: string;
}

export interface LoginResponse extends AuthTokens {
  user?: User;
}

export interface AuthState {
  user: User | null;
  tokens: AuthTokens | null;
  isAdmin: boolean;
}
