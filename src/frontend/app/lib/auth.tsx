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
  login: () => void;
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
    // Cookie is sent automatically via credentials: 'include'
    api.get<User>("/api/auth/me").then((res) => {
      if (res.ok) setUser(res.data);
      setLoading(false);
    });
  }, []);

  const login = useCallback(() => {
    // Cookie was set by the backend response. Fetch user profile.
    api.get<User>("/api/auth/me").then((res) => {
      if (res.ok) setUser(res.data);
    });
  }, []);

  const logout = useCallback(async () => {
    await api.del("/api/auth/logout");
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
