import type { ApiError } from "@/types/api";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:3005";

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  private getToken(): string | null {
    if (typeof window === "undefined") return null;
    return localStorage.getItem("auth_token");
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
    params?: Record<string, string | number | undefined>,
  ): Promise<T> {
    const url = new URL(`${this.baseUrl}${path}`);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) {
          url.searchParams.set(key, String(value));
        }
      });
    }

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };

    const token = this.getToken();
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    const res = await fetch(url.toString(), {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!res.ok) {
      const error: ApiError = await res.json().catch(() => ({
        statusCode: res.status,
        message: res.statusText,
      }));

      if (res.status === 401 && typeof window !== "undefined") {
        localStorage.removeItem("auth_token");
        window.location.href = "/login";
      }

      throw error;
    }

    if (res.status === 204) return undefined as T;
    return res.json();
  }

  get<T>(path: string, params?: Record<string, string | number | undefined>) {
    return this.request<T>("GET", path, undefined, params);
  }

  post<T>(path: string, body?: unknown) {
    return this.request<T>("POST", path, body);
  }

  put<T>(path: string, body?: unknown) {
    return this.request<T>("PUT", path, body);
  }

  delete<T>(path: string) {
    return this.request<T>("DELETE", path);
  }

  patch<T>(path: string, body?: unknown) {
    return this.request<T>("PATCH", path, body);
  }
}

export const apiClient = new ApiClient(API_BASE_URL);
