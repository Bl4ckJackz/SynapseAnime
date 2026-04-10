"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from "react";
import { authService } from "@/services/auth.service";
import type { User } from "@/types/user";

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  isAuthenticated: boolean;
}

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  register: (
    email: string,
    password: string,
    nickname?: string,
  ) => Promise<void>;
  loginWithGoogle: (token: string) => Promise<void>;
  logout: () => void;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null,
    token: null,
    isLoading: true,
    isAuthenticated: false,
  });

  const setAuth = useCallback((token: string, user: User) => {
    localStorage.setItem("auth_token", token);
    setState({ user, token, isLoading: false, isAuthenticated: true });
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem("auth_token");
    setState({
      user: null,
      token: null,
      isLoading: false,
      isAuthenticated: false,
    });
  }, []);

  const login = useCallback(
    async (email: string, password: string) => {
      const res = await authService.login(email, password);
      setAuth(res.accessToken, res.user);
    },
    [setAuth],
  );

  const register = useCallback(
    async (email: string, password: string, nickname?: string) => {
      const res = await authService.register(email, password, nickname);
      setAuth(res.accessToken, res.user);
    },
    [setAuth],
  );

  const loginWithGoogle = useCallback(
    async (googleToken: string) => {
      const res = await authService.loginWithGoogle(googleToken);
      setAuth(res.accessToken, res.user);
    },
    [setAuth],
  );

  const refreshProfile = useCallback(async () => {
    try {
      const user = await authService.getProfile();
      setState((prev) => ({ ...prev, user }));
    } catch {
      logout();
    }
  }, [logout]);

  useEffect(() => {
    const token = localStorage.getItem("auth_token");
    if (token) {
      setState((prev) => ({ ...prev, token }));
      authService
        .getProfile()
        .then((user) =>
          setState({ user, token, isLoading: false, isAuthenticated: true }),
        )
        .catch(() => {
          localStorage.removeItem("auth_token");
          setState({
            user: null,
            token: null,
            isLoading: false,
            isAuthenticated: false,
          });
        });
    } else {
      setState((prev) => ({ ...prev, isLoading: false }));
    }
  }, []);

  return (
    <AuthContext.Provider
      value={{
        ...state,
        login,
        register,
        loginWithGoogle,
        logout,
        refreshProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
