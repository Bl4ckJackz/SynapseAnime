# Phase 1: Foundation & Auth — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up the project foundation with API client, TypeScript types, auth flows (email + Google), and a responsive app shell with dark theme.

**Architecture:** Next.js 16 App Router with route groups `(auth)` for public pages and `(main)` for authenticated pages. API client as a singleton class using `fetch`. Auth state managed via React Context with JWT stored in localStorage. Middleware protects `(main)` routes.

**Tech Stack:** Next.js 16, React 19, Tailwind CSS v4, TypeScript, next/font

---

## File Structure

```
web/
├── app/
│   ├── layout.tsx                  # Root layout: providers, fonts, metadata
│   ├── page.tsx                    # Redirect to /home
│   ├── (auth)/
│   │   ├── layout.tsx              # Centered card layout for auth pages
│   │   ├── login/page.tsx          # Login form
│   │   └── register/page.tsx       # Register form
│   └── (main)/
│       ├── layout.tsx              # App shell: navbar + sidebar + content
│       └── home/page.tsx           # Placeholder home (expanded in Phase 2)
├── components/
│   ├── layout/
│   │   ├── Navbar.tsx              # Top bar: logo, search, user menu
│   │   ├── Sidebar.tsx             # Left sidebar (lg+), collapsible
│   │   ├── MobileNav.tsx           # Bottom tab bar (xs-md)
│   │   └── UserMenu.tsx            # Avatar dropdown: profile, settings, logout
│   └── ui/
│       ├── Button.tsx              # Reusable button with variants
│       ├── Input.tsx               # Form input with label + error
│       ├── Skeleton.tsx            # Loading placeholder
│       └── Toast.tsx               # Notification toast
├── contexts/
│   └── AuthContext.tsx             # Auth state: user, token, login/logout
├── services/
│   └── api-client.ts              # HTTP client: get/post/put/delete + auth header
│   └── auth.service.ts            # Login, register, google, profile
├── types/
│   ├── api.ts                     # PaginatedResult, ApiError
│   ├── user.ts                    # User, UserPreference, enums
│   ├── anime.ts                   # Anime, Episode, AnimeSource, enums
│   ├── manga.ts                   # Manga, Chapter, enums
│   ├── movies-tv.ts               # Movie, TvShow, TvEpisode, CastMember
│   ├── download.ts                # Download, DownloadSettings, enums
│   ├── comment.ts                 # Comment
│   ├── news.ts                    # News
│   └── chat.ts                    # ChatMessage
├── lib/
│   └── utils.ts                   # cn() helper, formatDate, formatDuration
├── middleware.ts                   # Auth redirect middleware
└── styles/
    └── globals.css                 # Tailwind base + dark theme variables
```

---

### Task 1: Install Dependencies & Configure Tailwind Dark Theme

**Files:**
- Modify: `web/package.json`
- Modify: `web/app/globals.css`
- Modify: `web/next.config.ts`

- [ ] **Step 1: Install additional dependencies**

```bash
cd web
npm install clsx tailwind-merge
npm install -D @types/node
```

- [ ] **Step 2: Replace globals.css with dark theme base**

Replace `web/app/globals.css` with:

```css
@import "tailwindcss";

:root {
  --color-bg: #0a0a0a;
  --color-surface: #141414;
  --color-surface-hover: #1e1e1e;
  --color-border: #2a2a2a;
  --color-text: #e5e5e5;
  --color-text-muted: #a1a1a1;
  --color-primary: #14b8a6;
  --color-primary-hover: #0d9488;
  --color-danger: #ef4444;
  --color-success: #22c55e;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

html {
  color-scheme: dark;
}

body {
  background: var(--color-bg);
  color: var(--color-text);
  font-family: var(--font-geist-sans), system-ui, sans-serif;
}

/* Scrollbar styling */
::-webkit-scrollbar {
  width: 8px;
}
::-webkit-scrollbar-track {
  background: var(--color-bg);
}
::-webkit-scrollbar-thumb {
  background: var(--color-border);
  border-radius: 4px;
}
```

- [ ] **Step 3: Update next.config.ts for image domains**

Replace `web/next.config.ts` with:

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "cdn.myanimelist.net" },
      { protocol: "https", hostname: "img.anili.st" },
      { protocol: "https", hostname: "uploads.mangadex.org" },
      { protocol: "https", hostname: "image.tmdb.org" },
      { protocol: "https", hostname: "s4.anilist.co" },
    ],
  },
};

export default nextConfig;
```

- [ ] **Step 4: Commit**

```bash
git add web/package.json web/package-lock.json web/app/globals.css web/next.config.ts
git commit -m "feat(web): configure dark theme, image domains, install deps"
```

---

### Task 2: Create TypeScript Type Definitions

**Files:**
- Create: `web/types/api.ts`
- Create: `web/types/user.ts`
- Create: `web/types/anime.ts`
- Create: `web/types/manga.ts`
- Create: `web/types/movies-tv.ts`
- Create: `web/types/download.ts`
- Create: `web/types/comment.ts`
- Create: `web/types/news.ts`
- Create: `web/types/chat.ts`

- [ ] **Step 1: Create `web/types/api.ts`**

```typescript
export interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface ApiError {
  statusCode: number;
  message: string;
  error?: string;
}

export interface AuthResponse {
  accessToken: string;
  user: import("./user").User;
}
```

- [ ] **Step 2: Create `web/types/user.ts`**

```typescript
export type SubscriptionTier = "free" | "premium";
export type SubscriptionStatus = "active" | "cancelled" | "expired";

export interface User {
  id: string;
  email: string;
  nickname?: string;
  avatarUrl?: string;
  googleId?: string;
  fcmToken?: string;
  subscriptionTier: SubscriptionTier;
  subscriptionStatus?: SubscriptionStatus;
  subscriptionExpiresAt?: string;
  readingList?: string[];
  preference?: UserPreference;
  createdAt: string;
}

export interface UserPreference {
  id: string;
  userId: string;
  preferredLanguages: string[];
  preferredGenres: string[];
}

export interface NotificationSettings {
  id: string;
  userId: string;
  globalEnabled: boolean;
  animeSettings: string; // JSON string
}
```

- [ ] **Step 3: Create `web/types/anime.ts`**

```typescript
export type AnimeStatus = "ongoing" | "completed" | "upcoming";

export interface Anime {
  id: string;
  malId?: number;
  title: string;
  titleEnglish?: string;
  titleJapanese?: string;
  description: string;
  synopsis?: string;
  coverUrl?: string;
  bannerImage?: string;
  trailerUrl?: string;
  genres: string[];
  studios?: string[];
  status: AnimeStatus;
  duration?: string;
  type?: string;
  releaseYear: number;
  rating: number;
  popularity: number;
  totalEpisodes: number;
  createdAt: string;
}

export interface Episode {
  id: string;
  animeId: string;
  number: number;
  title: string;
  duration: number;
  thumbnail?: string;
  streamUrl: string;
  source?: string;
}

export interface AnimeSource {
  id: string;
  name: string;
  description: string;
  isActive: boolean;
}

export interface ReleaseSchedule {
  id: string;
  animeId: string;
  episodeNumber: number;
  releaseDate: string;
  notified: boolean;
}
```

- [ ] **Step 4: Create `web/types/manga.ts`**

```typescript
export type MangaStatus = "ongoing" | "completed" | "hiatus" | "cancelled";

export interface Manga {
  id: string;
  mangadexId: string;
  title: string;
  altTitles?: Record<string, string>;
  description: string;
  authors: string[];
  artists: string[];
  genres: string[];
  tags: string[];
  status: MangaStatus;
  year?: number;
  coverImage?: string;
  rating: number;
  createdAt: string;
  updatedAt: string;
}

export interface Chapter {
  id: string;
  mangadexChapterId: string;
  number: number;
  title?: string;
  volume?: number;
  pages: number;
  language: string;
  scanlationGroup?: string;
  publishedAt: string;
  mangaId: string;
  createdAt: string;
}
```

- [ ] **Step 5: Create `web/types/movies-tv.ts`**

```typescript
export interface Movie {
  id: number;
  title: string;
  originalTitle?: string;
  overview?: string;
  posterPath?: string;
  backdropPath?: string;
  voteAverage: number;
  voteCount: number;
  releaseDate?: string;
  genreIds: number[];
  genres: string[];
  runtime?: number;
  tagline?: string;
  cast: CastMember[];
  similar: Movie[];
  imdbId?: string;
}

export interface TvShow {
  id: number;
  name: string;
  originalName?: string;
  overview?: string;
  posterPath?: string;
  backdropPath?: string;
  voteAverage: number;
  numberOfSeasons: number;
  numberOfEpisodes: number;
  genres: string[];
  firstAirDate?: string;
  cast: CastMember[];
  similar: TvShow[];
}

export interface TvEpisode {
  id: number;
  episodeNumber: number;
  seasonNumber: number;
  name: string;
  overview?: string;
  stillPath?: string;
  airDate?: string;
  runtime?: number;
  voteAverage: number;
}

export interface CastMember {
  name: string;
  character?: string;
  profilePath?: string;
}
```

- [ ] **Step 6: Create `web/types/download.ts`**

```typescript
export type DownloadStatus =
  | "pending"
  | "downloading"
  | "completed"
  | "failed"
  | "cancelled";

export interface Download {
  id: string;
  userId: string;
  animeId: string;
  animeName: string;
  episodeId: string;
  episodeNumber: number;
  episodeTitle?: string;
  status: DownloadStatus;
  progress: number;
  filePath?: string;
  fileName?: string;
  errorMessage?: string;
  streamUrl?: string;
  thumbnailPath?: string;
  thumbnailUrl?: string;
  source?: string;
  createdAt: string;
  completedAt?: string;
}

export interface DownloadSettings {
  id: string;
  userId: string;
  downloadPath?: string;
  useServerFolder: boolean;
  serverFolderPath?: string;
  updatedAt: string;
}
```

- [ ] **Step 7: Create `web/types/comment.ts`**

```typescript
import type { User } from "./user";

export interface Comment {
  id: string;
  userId: string;
  user?: User;
  text: string;
  rating?: number;
  animeId?: string;
  mangaId?: string;
  episodeId?: string;
  parentId?: string;
  replies?: Comment[];
  createdAt: string;
  updatedAt: string;
}

export interface RatingInfo {
  averageRating: number;
  totalRatings: number;
}
```

- [ ] **Step 8: Create `web/types/news.ts`**

```typescript
export type NewsSource = "myanimelist" | "anilist" | "custom";

export interface News {
  id: string;
  source: NewsSource;
  sourceId?: string;
  title: string;
  content: string;
  excerpt: string;
  coverImage?: string;
  category: string;
  tags: string[];
  publishedAt: string;
  externalUrl?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}
```

- [ ] **Step 9: Create `web/types/chat.ts`**

```typescript
import type { Anime } from "./anime";

export interface ChatMessage {
  id: string;
  content: string;
  isUser: boolean;
  timestamp: string;
  recommendations?: Anime[];
}

export interface AiRecommendationResponse {
  recommendations: Anime[];
  explanation: string;
}
```

- [ ] **Step 10: Commit**

```bash
git add web/types/
git commit -m "feat(web): add all TypeScript type definitions"
```

---

### Task 3: Create API Client

**Files:**
- Create: `web/services/api-client.ts`

- [ ] **Step 1: Create `web/services/api-client.ts`**

```typescript
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
}

export const apiClient = new ApiClient(API_BASE_URL);
```

- [ ] **Step 2: Commit**

```bash
git add web/services/api-client.ts
git commit -m "feat(web): add API client with auth header injection"
```

---

### Task 4: Create Auth Service

**Files:**
- Create: `web/services/auth.service.ts`

- [ ] **Step 1: Create `web/services/auth.service.ts`**

```typescript
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
```

- [ ] **Step 2: Commit**

```bash
git add web/services/auth.service.ts
git commit -m "feat(web): add auth service"
```

---

### Task 5: Create Utility Helpers

**Files:**
- Create: `web/lib/utils.ts`

- [ ] **Step 1: Create `web/lib/utils.ts`**

```typescript
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - 3) + "...";
}
```

- [ ] **Step 2: Commit**

```bash
git add web/lib/utils.ts
git commit -m "feat(web): add utility helpers (cn, formatDate, formatDuration)"
```

---

### Task 6: Create UI Primitives

**Files:**
- Create: `web/components/ui/Button.tsx`
- Create: `web/components/ui/Input.tsx`
- Create: `web/components/ui/Skeleton.tsx`
- Create: `web/components/ui/Toast.tsx`

- [ ] **Step 1: Create `web/components/ui/Button.tsx`**

```tsx
import { cn } from "@/lib/utils";
import { type ButtonHTMLAttributes, forwardRef } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
type ButtonSize = "sm" | "md" | "lg";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
}

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    "bg-[var(--color-primary)] hover:bg-[var(--color-primary-hover)] text-white",
  secondary:
    "bg-[var(--color-surface)] hover:bg-[var(--color-surface-hover)] text-[var(--color-text)] border border-[var(--color-border)]",
  ghost:
    "bg-transparent hover:bg-[var(--color-surface-hover)] text-[var(--color-text)]",
  danger: "bg-[var(--color-danger)] hover:bg-red-600 text-white",
};

const sizeStyles: Record<ButtonSize, string> = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-4 py-2 text-sm",
  lg: "px-6 py-3 text-base",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "primary", size = "md", loading, disabled, children, ...props }, ref) => (
    <button
      ref={ref}
      className={cn(
        "inline-flex items-center justify-center rounded-lg font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)] disabled:opacity-50 disabled:pointer-events-none",
        variantStyles[variant],
        sizeStyles[size],
        className,
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading && (
        <svg
          className="mr-2 h-4 w-4 animate-spin"
          viewBox="0 0 24 24"
          fill="none"
        >
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
          />
        </svg>
      )}
      {children}
    </button>
  ),
);
Button.displayName = "Button";
```

- [ ] **Step 2: Create `web/components/ui/Input.tsx`**

```tsx
import { cn } from "@/lib/utils";
import { type InputHTMLAttributes, forwardRef } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, error, id, ...props }, ref) => (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label
          htmlFor={id}
          className="text-sm font-medium text-[var(--color-text-muted)]"
        >
          {label}
        </label>
      )}
      <input
        ref={ref}
        id={id}
        className={cn(
          "w-full rounded-lg border bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text)] placeholder:text-[var(--color-text-muted)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]",
          error
            ? "border-[var(--color-danger)]"
            : "border-[var(--color-border)]",
          className,
        )}
        {...props}
      />
      {error && (
        <p className="text-xs text-[var(--color-danger)]">{error}</p>
      )}
    </div>
  ),
);
Input.displayName = "Input";
```

- [ ] **Step 3: Create `web/components/ui/Skeleton.tsx`**

```tsx
import { cn } from "@/lib/utils";

interface SkeletonProps {
  className?: string;
}

export function Skeleton({ className }: SkeletonProps) {
  return (
    <div
      className={cn(
        "animate-pulse rounded-lg bg-[var(--color-surface-hover)]",
        className,
      )}
    />
  );
}
```

- [ ] **Step 4: Create `web/components/ui/Toast.tsx`**

```tsx
"use client";

import { cn } from "@/lib/utils";
import { useEffect, useState, useCallback, createContext, useContext } from "react";

interface ToastItem {
  id: string;
  message: string;
  type: "success" | "error" | "info";
}

interface ToastContextType {
  toast: (message: string, type?: ToastItem["type"]) => void;
}

const ToastContext = createContext<ToastContextType>({ toast: () => {} });

export function useToast() {
  return useContext(ToastContext);
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const toast = useCallback((message: string, type: ToastItem["type"] = "info") => {
    const id = crypto.randomUUID();
    setToasts((prev) => [...prev, { id, message, type }]);
  }, []);

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2">
        {toasts.map((t) => (
          <ToastMessage key={t.id} item={t} onDismiss={dismiss} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

function ToastMessage({
  item,
  onDismiss,
}: {
  item: ToastItem;
  onDismiss: (id: string) => void;
}) {
  useEffect(() => {
    const timer = setTimeout(() => onDismiss(item.id), 4000);
    return () => clearTimeout(timer);
  }, [item.id, onDismiss]);

  const colors = {
    success: "border-[var(--color-success)] bg-[var(--color-success)]/10",
    error: "border-[var(--color-danger)] bg-[var(--color-danger)]/10",
    info: "border-[var(--color-primary)] bg-[var(--color-primary)]/10",
  };

  return (
    <div
      className={cn(
        "rounded-lg border px-4 py-3 text-sm text-[var(--color-text)] shadow-lg animate-in slide-in-from-right",
        colors[item.type],
      )}
    >
      {item.message}
    </div>
  );
}
```

- [ ] **Step 5: Commit**

```bash
git add web/components/ui/
git commit -m "feat(web): add UI primitives (Button, Input, Skeleton, Toast)"
```

---

### Task 7: Create Auth Context

**Files:**
- Create: `web/contexts/AuthContext.tsx`

- [ ] **Step 1: Create `web/contexts/AuthContext.tsx`**

```tsx
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
  register: (email: string, password: string, nickname?: string) => Promise<void>;
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
    setState({ user: null, token: null, isLoading: false, isAuthenticated: false });
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
    if (!token) {
      setState((prev) => ({ ...prev, isLoading: false }));
      return;
    }
    setState((prev) => ({ ...prev, token }));
    authService
      .getProfile()
      .then((user) => {
        setState({ user, token, isLoading: false, isAuthenticated: true });
      })
      .catch(() => {
        localStorage.removeItem("auth_token");
        setState({ user: null, token: null, isLoading: false, isAuthenticated: false });
      });
  }, []);

  return (
    <AuthContext.Provider
      value={{ ...state, login, register, loginWithGoogle, logout, refreshProfile }}
    >
      {children}
    </AuthContext.Provider>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add web/contexts/AuthContext.tsx
git commit -m "feat(web): add AuthContext with login/register/google/logout"
```

---

### Task 8: Create Auth Middleware

**Files:**
- Create: `web/middleware.ts`

- [ ] **Step 1: Create `web/middleware.ts`**

Note: Next.js middleware runs on the edge and cannot access localStorage. We handle client-side redirects in the `(main)/layout.tsx` instead. The middleware handles server-side protection for direct URL access.

```typescript
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const publicPaths = ["/login", "/register", "/"];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Allow public paths and static files
  if (
    publicPaths.includes(pathname) ||
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.includes(".")
  ) {
    return NextResponse.next();
  }

  // Auth check is handled client-side via AuthContext
  // Middleware just ensures the route structure works
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

- [ ] **Step 2: Commit**

```bash
git add web/middleware.ts
git commit -m "feat(web): add Next.js middleware"
```

---

### Task 9: Create Layout Components (Navbar, Sidebar, MobileNav)

**Files:**
- Create: `web/components/layout/Navbar.tsx`
- Create: `web/components/layout/Sidebar.tsx`
- Create: `web/components/layout/MobileNav.tsx`
- Create: `web/components/layout/UserMenu.tsx`

- [ ] **Step 1: Create `web/components/layout/Navbar.tsx`**

```tsx
"use client";

import Link from "next/link";
import { useAuth } from "@/contexts/AuthContext";
import { UserMenu } from "./UserMenu";

export function Navbar() {
  const { user } = useAuth();

  return (
    <header className="sticky top-0 z-40 flex h-14 items-center justify-between border-b border-[var(--color-border)] bg-[var(--color-bg)]/80 px-4 backdrop-blur-md lg:px-6">
      <Link href="/home" className="flex items-center gap-2">
        <span className="text-lg font-bold text-[var(--color-primary)]">
          SynapseAnime
        </span>
      </Link>

      <div className="hidden md:flex flex-1 max-w-md mx-4">
        <Link
          href="/search"
          className="flex w-full items-center rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1.5 text-sm text-[var(--color-text-muted)] hover:border-[var(--color-primary)] transition-colors"
        >
          Search anime, manga, movies...
        </Link>
      </div>

      <div className="flex items-center gap-3">
        {user && <UserMenu user={user} />}
      </div>
    </header>
  );
}
```

- [ ] **Step 2: Create `web/components/layout/UserMenu.tsx`**

```tsx
"use client";

import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { useAuth } from "@/contexts/AuthContext";
import type { User } from "@/types/user";

export function UserMenu({ user }: { user: User }) {
  const { logout } = useAuth();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex h-8 w-8 items-center justify-center rounded-full bg-[var(--color-primary)] text-sm font-bold text-white"
      >
        {(user.nickname || user.email)[0].toUpperCase()}
      </button>

      {open && (
        <div className="absolute right-0 top-10 w-48 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] py-1 shadow-xl">
          <div className="px-3 py-2 text-sm border-b border-[var(--color-border)]">
            <p className="font-medium truncate">{user.nickname || "User"}</p>
            <p className="text-xs text-[var(--color-text-muted)] truncate">
              {user.email}
            </p>
          </div>
          <Link
            href="/profile"
            onClick={() => setOpen(false)}
            className="block px-3 py-2 text-sm hover:bg-[var(--color-surface-hover)]"
          >
            Profile
          </Link>
          <Link
            href="/settings"
            onClick={() => setOpen(false)}
            className="block px-3 py-2 text-sm hover:bg-[var(--color-surface-hover)]"
          >
            Settings
          </Link>
          <button
            onClick={() => {
              logout();
              setOpen(false);
            }}
            className="block w-full px-3 py-2 text-left text-sm text-[var(--color-danger)] hover:bg-[var(--color-surface-hover)]"
          >
            Logout
          </button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 3: Create `web/components/layout/Sidebar.tsx`**

```tsx
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const navItems = [
  { href: "/home", label: "Home", icon: "H" },
  { href: "/anime", label: "Anime", icon: "A" },
  { href: "/manga", label: "Manga", icon: "M" },
  { href: "/movies-tv", label: "Movies & TV", icon: "T" },
  { href: "/calendar", label: "Calendar", icon: "C" },
  { href: "/news", label: "News", icon: "N" },
  { href: "/chat", label: "AI Chat", icon: "I" },
  { href: "/watchlist", label: "Watchlist", icon: "W" },
  { href: "/history", label: "History", icon: "Y" },
  { href: "/downloads", label: "Downloads", icon: "D" },
  { href: "/library", label: "Library", icon: "L" },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="hidden lg:flex flex-col w-56 shrink-0 border-r border-[var(--color-border)] bg-[var(--color-bg)] h-[calc(100vh-3.5rem)] sticky top-14 overflow-y-auto">
      <nav className="flex flex-col gap-0.5 p-3">
        {navItems.map((item) => {
          const active =
            pathname === item.href || pathname.startsWith(item.href + "/");
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                active
                  ? "bg-[var(--color-primary)]/10 text-[var(--color-primary)] font-medium"
                  : "text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]",
              )}
            >
              <span className="flex h-5 w-5 items-center justify-center text-xs font-bold">
                {item.icon}
              </span>
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
```

- [ ] **Step 4: Create `web/components/layout/MobileNav.tsx`**

```tsx
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const mobileItems = [
  { href: "/home", label: "Home", icon: "H" },
  { href: "/anime", label: "Anime", icon: "A" },
  { href: "/manga", label: "Manga", icon: "M" },
  { href: "/search", label: "Search", icon: "S" },
  { href: "/profile", label: "Profile", icon: "P" },
];

export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 flex items-center justify-around border-t border-[var(--color-border)] bg-[var(--color-bg)]/95 backdrop-blur-md py-2 lg:hidden">
      {mobileItems.map((item) => {
        const active =
          pathname === item.href || pathname.startsWith(item.href + "/");
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex flex-col items-center gap-0.5 text-xs transition-colors",
              active
                ? "text-[var(--color-primary)]"
                : "text-[var(--color-text-muted)]",
            )}
          >
            <span className="text-base font-bold">{item.icon}</span>
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
```

- [ ] **Step 5: Commit**

```bash
git add web/components/layout/
git commit -m "feat(web): add Navbar, Sidebar, MobileNav, UserMenu"
```

---

### Task 10: Create App Layouts and Route Structure

**Files:**
- Modify: `web/app/layout.tsx`
- Modify: `web/app/page.tsx`
- Create: `web/app/(auth)/layout.tsx`
- Create: `web/app/(auth)/login/page.tsx`
- Create: `web/app/(auth)/register/page.tsx`
- Create: `web/app/(main)/layout.tsx`
- Create: `web/app/(main)/home/page.tsx`

- [ ] **Step 1: Replace `web/app/layout.tsx` (root layout with providers)**

```tsx
import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { AuthProvider } from "@/contexts/AuthContext";
import { ToastProvider } from "@/components/ui/Toast";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "SynapseAnime",
  description: "Your unlimited source of Anime, Manga, Movies & TV",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        <AuthProvider>
          <ToastProvider>{children}</ToastProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
```

- [ ] **Step 2: Replace `web/app/page.tsx` (redirect to /home)**

```tsx
import { redirect } from "next/navigation";

export default function RootPage() {
  redirect("/home");
}
```

- [ ] **Step 3: Create `web/app/(auth)/layout.tsx`**

```tsx
export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-md">{children}</div>
    </div>
  );
}
```

- [ ] **Step 4: Create `web/app/(auth)/login/page.tsx`**

```tsx
"use client";

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/components/ui/Toast";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const { toast } = useToast();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(email, password);
      router.push("/home");
    } catch (err: unknown) {
      const message =
        err && typeof err === "object" && "message" in err
          ? String(err.message)
          : "Login failed";
      setError(message);
      toast(message, "error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-8">
      <h1 className="mb-2 text-2xl font-bold">Welcome back</h1>
      <p className="mb-6 text-sm text-[var(--color-text-muted)]">
        Sign in to your SynapseAnime account
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          id="email"
          label="Email"
          type="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <Input
          id="password"
          label="Password"
          type="password"
          placeholder="Your password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />

        {error && (
          <p className="text-sm text-[var(--color-danger)]">{error}</p>
        )}

        <Button type="submit" loading={loading} className="mt-2">
          Sign In
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-[var(--color-text-muted)]">
        Don&apos;t have an account?{" "}
        <Link
          href="/register"
          className="font-medium text-[var(--color-primary)] hover:underline"
        >
          Create one
        </Link>
      </p>
    </div>
  );
}
```

- [ ] **Step 5: Create `web/app/(auth)/register/page.tsx`**

```tsx
"use client";

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";
import { useToast } from "@/components/ui/Toast";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";

export default function RegisterPage() {
  const router = useRouter();
  const { register } = useAuth();
  const { toast } = useToast();
  const [nickname, setNickname] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (nickname && (nickname.length < 2 || nickname.length > 30)) {
      e.nickname = "Nickname must be 2-30 characters";
    }
    if (!email) e.email = "Email is required";
    if (password.length < 10) {
      e.password = "Password must be at least 10 characters";
    } else if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(password)) {
      e.password =
        "Must include uppercase, lowercase, and a number";
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!validate()) return;
    setLoading(true);
    try {
      await register(email, password, nickname || undefined);
      router.push("/home");
    } catch (err: unknown) {
      const message =
        err && typeof err === "object" && "message" in err
          ? String(err.message)
          : "Registration failed";
      toast(message, "error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-8">
      <h1 className="mb-2 text-2xl font-bold">Create account</h1>
      <p className="mb-6 text-sm text-[var(--color-text-muted)]">
        Join SynapseAnime for unlimited streaming
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          id="nickname"
          label="Nickname (optional)"
          placeholder="Your display name"
          value={nickname}
          onChange={(e) => setNickname(e.target.value)}
          error={errors.nickname}
        />
        <Input
          id="email"
          label="Email"
          type="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          error={errors.email}
          required
        />
        <Input
          id="password"
          label="Password"
          type="password"
          placeholder="Min 10 chars, uppercase + lowercase + number"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={errors.password}
          required
        />

        <Button type="submit" loading={loading} className="mt-2">
          Create Account
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-[var(--color-text-muted)]">
        Already have an account?{" "}
        <Link
          href="/login"
          className="font-medium text-[var(--color-primary)] hover:underline"
        >
          Sign in
        </Link>
      </p>
    </div>
  );
}
```

- [ ] **Step 6: Create `web/app/(main)/layout.tsx`**

```tsx
"use client";

import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { Navbar } from "@/components/layout/Navbar";
import { Sidebar } from "@/components/layout/Sidebar";
import { MobileNav } from "@/components/layout/MobileNav";
import { Skeleton } from "@/components/ui/Skeleton";

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.replace("/login");
    }
  }, [isLoading, isAuthenticated, router]);

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Skeleton className="h-12 w-48" />
      </div>
    );
  }

  if (!isAuthenticated) return null;

  return (
    <div className="min-h-screen">
      <Navbar />
      <div className="flex">
        <Sidebar />
        <main className="flex-1 min-h-[calc(100vh-3.5rem)] pb-16 lg:pb-0">
          {children}
        </main>
      </div>
      <MobileNav />
    </div>
  );
}
```

- [ ] **Step 7: Create `web/app/(main)/home/page.tsx` (placeholder)**

```tsx
export default function HomePage() {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold">Home</h1>
      <p className="mt-2 text-[var(--color-text-muted)]">
        Welcome to SynapseAnime. Content coming soon.
      </p>
    </div>
  );
}
```

- [ ] **Step 8: Verify it compiles**

```bash
cd web && npm run build
```

Expected: Build succeeds with no errors.

- [ ] **Step 9: Commit**

```bash
git add web/app/ web/components/ web/contexts/ web/services/ web/types/ web/lib/ web/middleware.ts
git commit -m "feat(web): complete Phase 1 — auth flow, app shell, responsive layout"
```

---

### Task 11: Manual Smoke Test

- [ ] **Step 1: Start dev server**

```bash
cd web && npm run dev
```

- [ ] **Step 2: Verify routes**

1. `http://localhost:3000` — should redirect to `/home`, then redirect to `/login` (not authenticated)
2. `/login` — login form renders, dark theme
3. `/register` — register form renders, validation works
4. After login with valid backend credentials → redirects to `/home`
5. `/home` — navbar visible, sidebar visible on desktop (lg+), bottom nav on mobile
6. User menu shows nickname/email, logout works

- [ ] **Step 3: Verify responsive layout**

1. **Desktop (1280px+)**: Sidebar visible, no bottom nav
2. **Tablet (768px)**: Sidebar hidden, bottom nav visible
3. **Mobile (375px)**: Full width, bottom nav visible, search hidden from navbar
