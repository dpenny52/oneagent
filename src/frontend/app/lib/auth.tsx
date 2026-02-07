"use client";

import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from "react";
import { api } from "./api";

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */
interface User {
  id: string;
  email: string;
}

interface AuthCtx {
  user: User | null;
  loading: boolean;
  login: (token: string) => void;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthCtx>({
  user: null,
  loading: true,
  login: () => {},
  logout: async () => {},
});

/* ------------------------------------------------------------------ */
/*  Provider                                                           */
/* ------------------------------------------------------------------ */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("auth_token");
    if (!token) {
      setLoading(false);
      return;
    }
    api.get<User>("/api/auth/me").then((res) => {
      if (res.ok) setUser(res.data);
      else localStorage.removeItem("auth_token");
      setLoading(false);
    });
  }, []);

  const login = useCallback((token: string) => {
    localStorage.setItem("auth_token", token);
    // Fetch user profile after storing token
    api.get<User>("/api/auth/me").then((res) => {
      if (res.ok) setUser(res.data);
    });
  }, []);

  const logout = useCallback(async () => {
    await api.del("/api/auth/logout");
    localStorage.removeItem("auth_token");
    setUser(null);
    window.location.href = "/login";
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
