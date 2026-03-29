# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OpenAnime** — full-stack anime/manga streaming platform with four components:
- `backend/` — NestJS 11 API (TypeScript, TypeORM, port 3005)
- `mobile/` — Flutter app (Dart, Riverpod, GoRouter)
- `web/` — Next.js 16 app (React, Tailwind CSS, port 3001) — early scaffold
- `consumet-api/` — Fastify anime source aggregator (port 3004)

## Commands

### Full stack (from root)
```bash
npm install          # installs all subprojects (backend, consumet-api, web)
npm run dev          # starts backend + consumet + web concurrently
```

### Backend (`backend/`)
```bash
npm run start:dev    # dev with hot-reload (nest start --watch)
npm run build        # nest build → dist/
npm run start:prod   # node dist/main
npm run lint         # eslint --fix
npm run format       # prettier --write
npm run test         # jest
npm run test:watch   # jest --watch
npm run test:cov     # jest --coverage
npm run test:e2e     # jest --config ./test/jest-e2e.json
npm run seed         # ts-node src/seed/seed.ts
```

### Mobile (`mobile/`)
```bash
flutter pub get
flutter run                    # debug on connected device
flutter build apk              # Android release
flutter pub run build_runner build  # Riverpod code generation
```

### Docker (full stack with Postgres + Redis)
```bash
docker-compose up --build -d
```

## Architecture

### Backend module structure

`AppModule` (root) imports all feature modules. Each module follows NestJS conventions (module/controller/service/entity).

Key modules and their responsibilities:
- **AuthModule** — JWT auth (7d tokens), Google OAuth, bcrypt passwords. Guards: `JwtAuthGuard`. Decorator: `@CurrentUser()`.
- **AnimeModule** — anime search/metadata/streaming. Contains source manager pattern (`sources/source.manager.ts`) that abstracts AnimeUnity, HiAnime, and Consumet providers behind a unified interface.
- **MangaModule** — manga via MangaDex API (`mangadex-full-api` package) and MangaHook.
- **UsersModule** — profiles, watchlist, watch history, reading history. `HistoryGateway` uses WebSockets for real-time progress sync.
- **DownloadModule** — video download management with FFmpeg processing. `DownloadGateway` for real-time progress via WebSocket.
- **AiModule** — AI chatbot via Perplexity adapter.
- **JikanModule** — wrapper around Jikan v4 API for anime/manga metadata.
- **MonetizationModule** — Stripe subscriptions (FREE/PREMIUM tiers).
- **MoviesTvModule** — movies/TV shows (TMDB integration).
- **CommentsModule** — user comments on anime/manga.
- **CommonModule** — shared cache service.

### Database

- **Dev**: SQLite (`./anime_player.db`) — default when `DB_TYPE != postgres`
- **Prod**: PostgreSQL 16
- **ORM**: TypeORM 0.3 with `synchronize: true` in dev (auto-migration)
- **Entities**: auto-loaded via glob `src/**/*.entity{.ts,.js}`
- **Cache**: Redis 7 (Docker)

### Mobile app architecture

Clean Architecture with Riverpod for state management:
- `lib/core/` — router (GoRouter with 40+ routes), theme (Material Design 3 dark), constants (API endpoints + storage keys)
- `lib/data/` — `api_client.dart` (Dio HTTP client), repositories (AnimeWorld, Consumet, MangaDex, MoviesTv)
- `lib/domain/providers/` — 20+ Riverpod providers for reactive state
- `lib/features/` — feature-scoped code (auth, anime with dedicated repository)
- `lib/presentation/screens/` — 30+ screens
- `lib/presentation/widgets/` — reusable UI components including custom player controls

API base URLs are configured in `lib/core/constants.dart` via `EnvironmentConfig` enum (dev/staging/production). Tokens stored in `FlutterSecureStorage`.

Three video player implementations:
1. `PlayerScreen` — native `video_player` with gesture controls (swipe volume/brightness)
2. `SimplePlayerScreen` — alternative native player
3. `VidsrcPlayerScreen` — WebView-based for embed URLs

### Consumet API

Fastify wrapper around `@consumet/extensions` that normalizes multiple anime/manga sources into a unified REST API. Runs independently on port 3004.

## Environment Setup

Copy `backend/.env.example` to `backend/.env`. Required variables:
- `DB_TYPE` — `sqlite` (dev) or `postgres` (prod)
- `JWT_SECRET` — required for auth
- `CONSUMET_API_URL` — defaults to `http://localhost:3004`

Optional: `PERPLEXITY_API_KEY`, `STRIPE_SECRET_KEY`, `GOOGLE_CLIENT_ID`, `FIREBASE_*` vars.

## Conventions

- Backend uses NestJS module pattern: each feature has its own `*.module.ts`, `*.controller.ts`, `*.service.ts`, and `*.entity.ts` files
- DTOs use `class-validator` decorators with global `ValidationPipe` (whitelist + transform)
- Rate limiting: 60 requests per minute globally (ThrottlerModule)
- TypeScript target ES2023, module resolution `nodenext`, strict null checks enabled
- Mobile state is Riverpod-based — prefer providers over setState
- Mobile routing uses GoRouter — add new routes in `lib/core/router.dart`
- Project language: codebase in English, user-facing Italian strings with i18n support (IT/EN/JP)
