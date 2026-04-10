# Architettura del Progetto

SynapseAnime segue un'architettura **Client-Server** moderna, separando la logica di presentazione (Web, Mobile) dalla logica di business (Backend) e dall'aggregazione dati (Consumet, MangaHook).

## Componenti Principali

### 1. Web App (Frontend)
- **Framework**: Next.js 16 (App Router) + React 19 + TypeScript
- **Styling**: Tailwind CSS v4, tema dark con CSS custom properties
- **Routing**: App Router con route groups `(auth)` (pagine pubbliche) e `(main)` (pagine autenticate)
- **State Management**: React Context (AuthContext, SourceContext, SocketContext)
- **Autenticazione**: JWT in localStorage, middleware Next.js per protezione route
- **Video**: HTML5 `<video>` + hls.js per streaming HLS/m3u8
- **Real-time**: Socket.IO client per progress download
- **Porta**: 3000

**Struttura prevista:**
```
web/
├── app/
│   ├── (auth)/          # Login, Register (layout centrato)
│   └── (main)/          # Pagine autenticate (app shell: navbar + sidebar)
│       ├── home/
│       ├── anime/
│       ├── manga/
│       ├── movies-tv/
│       ├── news/
│       ├── downloads/
│       ├── chat/
│       ├── library/
│       ├── profile/
│       ├── settings/
│       └── subscribe/
├── components/
│   ├── layout/          # Navbar, Sidebar, MobileNav, UserMenu
│   └── ui/              # Button, Input, Skeleton, Toast (primitives)
├── contexts/            # AuthContext, SourceContext, SocketContext
├── services/            # API client, servizi per dominio
├── types/               # Interfacce TypeScript per tutti i domain model
└── lib/                 # Utility (cn, formatDate, formatDuration)
```

### 2. Mobile App (Frontend)
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod. Gestisce lo stato globale in modo reattivo e sicuro.
- **Routing**: GoRouter per deep linking e navigazione avanzata.
- **HTTP**: Dio per le chiamate API.
- **Video**: video_player + webview_flutter per playback.
- **Notifiche**: Firebase Push Notifications.
- **Real-time**: Socket.IO client per progress download.

**Struttura:**
```
mobile/
├── lib/
│   ├── data/            # Repository e sorgenti dati (API client)
│   ├── domain/          # Modelli e logica di business pura
│   └── presentation/    # Widget, Schermate e State Notifiers
```

### 3. Backend API
- **Framework**: NestJS (Node.js/TypeScript)
- **Struttura**: Modulare (Controller → Service → Repository)
- **Database**: TypeORM con supporto dual-driver (PostgreSQL in produzione, SQLite in locale)
- **Entità**: Centralizzate in `backend/src/entities/` (auto-discovered via glob)
- **Autenticazione**: JWT + Passport (strategia locale + JWT), Google OAuth opzionale
- **Real-time**: WebSocket gateway per download progress e history updates
- **Rate Limiting**: Throttler globale 60 req/min
- **Porta**: 3005

**Moduli principali:**
| Modulo | Responsabilità |
|--------|---------------|
| `auth/` | JWT, Passport (local + JWT), Google OAuth |
| `anime/` | Logica anime + sistema sorgenti pluggabile (Jikan, AnimeUnity, HiAnime, DB, File) |
| `manga/`, `mangahook/` | Manga via MangaDex API e MangaHook |
| `jikan/` | Metadati MyAnimeList via Jikan v4 (anime + manga) |
| `movies-tv/` | Film/Serie TV via TMDB |
| `ai/` | Raccomandazioni AI (adapter pattern: Perplexity + mock) |
| `comments/` | Commenti e rating su anime/manga/episodi |
| `download/` | Download video con ffmpeg, WebSocket per progresso |
| `library/` | Browser libreria locale, streaming HLS dei file |
| `monetization/` | Abbonamenti e pagamenti Stripe |
| `notifications/` | Push notifications Firebase |
| `users/` | Profilo, preferenze, watchlist, cronologia, progressi |
| `common/` | Cache, circuit breaker, rate limiter |

### 4. Consumet API (Data Source)
- **Ruolo**: Aggrega fonti streaming anime (AnimeUnity, HiAnime, ecc.)
- **Framework**: Fastify + @consumet/extensions + aniwatch
- **Porta**: 3004

### 5. MangaHook API (Data Source)
- **Ruolo**: Provider alternativo per fonti manga
- **Server**: `mangahook-api/server/`
- **Porta**: 5000

## Flusso dei Dati

### Ricerca e Streaming Anime
```
Web/Mobile → Backend (:3005) → Consumet API (:3004) → Source (AnimeUnity, HiAnime, ecc.)
                              → Jikan v4 (metadati MAL)
```
Il Backend arricchisce i dati con informazioni dal DB locale (watchlist, progressi) prima di rispondere.

### Lettura Manga
```
Web/Mobile → Backend (:3005) → MangaDex API (metadati + pagine)
                              → MangaHook (:5000) (fonte alternativa)
                              → Jikan v4 (metadati MAL)
```

### Film e Serie TV
```
Web/Mobile → Backend (:3005) → TMDB API (metadati, cast, simili)
                              → vidsrc (URL streaming embed)
```

### Download con progresso real-time
```
Web/Mobile ←WebSocket→ Backend (:3005)
                         ↓
                      ffmpeg (transcoding/download)
                         ↓
                      video_library/ (file salvati)
```

### Autenticazione
```
Client → POST /auth/login (email+password) → Backend → JWT token
Client → POST /auth/google (Google token) → Backend → JWT token
Client → Authorization: Bearer <token> → tutte le API protette
```

## Porte dei Servizi

| Servizio | Porta | Direzione |
|----------|-------|-----------|
| Web App (Next.js) | 3000 | `NEXT_PUBLIC_API_URL` → Backend |
| Consumet API | 3004 | Chiamato dal Backend via `CONSUMET_API_URL` |
| Backend (NestJS) | 3005 | API centrale, WebSocket |
| MangaHook API | 5000 | Chiamato dal Backend via `MANGAHOOK_API_URL` |
