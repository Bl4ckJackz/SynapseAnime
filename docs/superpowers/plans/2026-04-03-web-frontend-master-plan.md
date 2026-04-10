# SynapseAnime Web Frontend — Master Implementation Plan

> This document decomposes the full web frontend into 6 independently-deliverable phases.
> Each phase has its own detailed plan file. Phases must be executed in order — each builds on the previous.
>
> **API Reference:** See `docs/WEB_API_REFERENCE.md` for the consolidated backend endpoint reference.

## Phase Overview

| Phase | Name | Status | Scope | Depends On |
|-------|------|--------|-------|------------|
| 1 | Foundation & Auth | **Partial** — types + theme done, services/components pending | Project setup, API client, types, auth flow, app shell layout | — |
| 2 | Anime Core | Not started | Home page, anime browse/detail/search, video player, watch progress | Phase 1 |
| 3 | Manga & Reading | Not started | Manga browse/detail, chapter reader (3 modes), reading progress | Phase 1 |
| 4 | Movies/TV & News | Not started | TMDB movies/TV browse/detail/streaming, news section, calendar | Phase 1 |
| 5 | User & Social | Not started | Profile, watchlist, history, comments/ratings, settings, notifications | Phase 2 |
| 6 | Downloads, AI, Library & Premium | Not started | Download manager + WebSocket, AI chat, local library, Stripe subscription | Phase 5 |

## Phase 1: Foundation & Auth
**Plan:** `2026-04-03-phase1-foundation-auth.md`
**Deliverable:** Working login/register/Google OAuth, authenticated app shell with responsive navbar/sidebar, dark theme, API client, all TypeScript types, auth middleware.
**Progress:**
- [x] Task 1: Dark theme CSS variables (`globals.css`)
- [x] Task 2: TypeScript type definitions (9 files in `types/`)
- [x] Dependencies: `clsx`, `tailwind-merge` installed
- [x] `next.config.ts` image domains configured
- [ ] Task 3: API client (`services/api-client.ts`)
- [ ] Task 4: Auth service (`services/auth.service.ts`)
- [ ] Task 5: Utility helpers (`lib/utils.ts`)
- [ ] Task 6: UI primitives (Button, Input, Skeleton, Toast)
- [ ] Task 7: Auth context
- [ ] Task 8: Layout components (Navbar, Sidebar, MobileNav, UserMenu)
- [ ] Task 9: Auth pages (Login, Register)
- [ ] Task 10: Middleware + Home placeholder

## Phase 2: Anime Core
**Plan:** `2026-04-03-phase2-anime-core.md`
**Deliverable:** Home page with featured carousel + 6 category sections, anime list/detail pages, video player with HLS support, episode progress tracking, source switching, airing calendar.

## Phase 3: Manga & Reading
**Plan:** `2026-04-03-phase3-manga-reading.md`
**Deliverable:** Manga home with browse categories, manga detail page, full chapter reader with vertical/horizontal/webtoon modes, chapter navigation, reading progress.

## Phase 4: Movies/TV & News
**Plan:** `2026-04-03-phase4-movies-tv-news.md`
**Deliverable:** Movies/TV browse and detail pages, stream URL resolution, news feed with categories/search, airing calendar page.

## Phase 5: User & Social
**Plan:** `2026-04-03-phase5-user-social.md`
**Deliverable:** Profile page with stats, watchlist management (anime + manga), watch/reading history, comment threads with ratings, settings page, notification preferences.

## Phase 6: Downloads, AI, Library & Premium
**Plan:** `2026-04-03-phase6-downloads-ai-premium.md`
**Deliverable:** Download manager with real-time WebSocket progress, AI chat + recommendations, local library browser, Stripe subscription checkout, backup sync.

---

## Backend Gaps

These backend changes are needed before certain frontend features can be implemented:

| Gap | Needed By | Description |
|-----|-----------|-------------|
| Monetization controller | Phase 6 | `MonetizationModule` has services but no REST endpoints. Need `POST /monetization/checkout` and `POST /monetization/cancel`. |
| User stats endpoint | Phase 5 | No `/users/profile/stats` — either add backend endpoint or compute client-side from history. |
| Reading history endpoint | Phase 5 | `/users/reading-history` not verified in backend — may need to be added. |

---

## Last updated
2026-04-10 — Documentation reviewed and aligned with actual backend API surface. See `docs/WEB_API_REFERENCE.md`.
