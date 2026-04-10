import { apiClient } from "./api-client";
import type { AuthResponse } from "@/types/api";
import type { User } from "@/types/user";

export const authService = {
  async login(email: string, password: string): Promise<AuthResponse> {
    return apiClient.post<AuthResponse>("/auth/login", { email, password });
  },

  async register(
    email: string,
    password: string,
    nickname?: string,
  ): Promise<AuthResponse> {
    return apiClient.post<AuthResponse>("/auth/register", {
      email,
      password,
      nickname,
    });
  },

  async loginWithGoogle(token: string): Promise<AuthResponse> {
    return apiClient.post<AuthResponse>("/auth/google", { token });
  },

  async getProfile(): Promise<User> {
    return apiClient.get<User>("/auth/profile");
  },
};
