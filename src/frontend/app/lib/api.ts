/* ------------------------------------------------------------------ */
/*  Thin fetch wrapper for the backend API                             */
/* ------------------------------------------------------------------ */

const BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000";

export type ApiOk<T> = { ok: true; data: T };
export type ApiErr = { ok: false; error: string; status: number };
export type ApiResult<T> = ApiOk<T> | ApiErr;

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
): Promise<ApiResult<T>> {
  const token =
    typeof window !== "undefined" ? localStorage.getItem("auth_token") : null;

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  try {
    const res = await fetch(`${BASE}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });

    if (res.status === 401) {
      if (typeof window !== "undefined") {
        localStorage.removeItem("auth_token");
        window.location.href = "/login";
      }
      return { ok: false, error: "Unauthorized", status: 401 };
    }

    if (res.status === 204) {
      return { ok: true, data: null as T };
    }

    const json = await res.json();

    if (!res.ok) {
      return {
        ok: false,
        error: json.error || json.errors?.detail || "Request failed",
        status: res.status,
      };
    }

    // Unwrap Phoenix {data: ...} envelope
    return { ok: true, data: json.data !== undefined ? json.data : json };
  } catch {
    return { ok: false, error: "Unable to connect to the server.", status: 0 };
  }
}

export const api = {
  get: <T>(path: string) => request<T>("GET", path),
  post: <T>(path: string, body?: unknown) => request<T>("POST", path, body),
  put: <T>(path: string, body?: unknown) => request<T>("PUT", path, body),
  del: <T>(path: string) => request<T>("DELETE", path),
};
