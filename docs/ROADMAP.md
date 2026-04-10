# Roadmap — Web Frontend

Questo documento traccia lo stato di avanzamento dello sviluppo del frontend web (Next.js).
I piani dettagliati di ogni fase sono in `docs/superpowers/plans/`.

## Stato delle Fasi

| Fase | Nome | Stato | Piano dettagliato |
|------|------|-------|-------------------|
| 1 | Foundation & Auth | **Parziale** | `2026-04-03-phase1-foundation-auth.md` |
| 2 | Anime Core | Da iniziare | `2026-04-03-phase2-anime-core.md` |
| 3 | Manga & Reading | Da iniziare | `2026-04-03-phase3-manga-reading.md` |
| 4 | Movies/TV & News | Da iniziare | `2026-04-03-phase4-movies-tv-news.md` |
| 5 | User & Social | Da iniziare | `2026-04-03-phase5-user-social.md` |
| 6 | Downloads, AI, Library & Premium | Da iniziare | `2026-04-03-phase6-downloads-ai-premium.md` |

### Dipendenze tra fasi

```
Phase 1 (Foundation & Auth)
├── Phase 2 (Anime Core)
│   └── Phase 5 (User & Social)
│       └── Phase 6 (Downloads, AI, Library & Premium)
├── Phase 3 (Manga & Reading)
└── Phase 4 (Movies/TV & News)
```

---

## Fase 1: Foundation & Auth — Dettaglio avanzamento

| Task | Stato | Note |
|------|-------|------|
| Configurazione Tailwind + dark theme (`globals.css`) | Fatto | CSS variables, scrollbar, dark mode |
| TypeScript type definitions (`types/`) | Fatto | 9 file: anime, manga, user, download, comment, news, chat, movies-tv, api |
| `next.config.ts` (image domains) | Fatto | MAL, AniList, MangaDex, TMDB |
| Dipendenze base (clsx, tailwind-merge) | Fatto | Installate in `package.json` |
| API Client (`services/api-client.ts`) | Da fare | |
| Auth Service (`services/auth.service.ts`) | Da fare | |
| Utility helpers (`lib/utils.ts`) | Da fare | cn(), formatDate, formatDuration |
| UI Primitives (Button, Input, Skeleton, Toast) | Da fare | |
| Auth Context (`contexts/AuthContext.tsx`) | Da fare | |
| Layout components (Navbar, Sidebar, MobileNav, UserMenu) | Da fare | |
| Auth pages (Login, Register) | Da fare | |
| Middleware di protezione route | Da fare | |
| Home page placeholder | Da fare | |

---

## Roadmap Cross-Platform

Queste feature sono trasversali e non ancora pianificate in dettaglio:

### i18n (Internazionalizzazione)
**Stato:** Da pianificare
- Libreria: `next-intl` per il web
- Lingue target: IT, EN
- Language switcher nelle impostazioni

### UI Optimization
**Stato:** Da pianificare (post Fase 2)
- Design system: standardizzare colori, tipografia, spaziature
- Micro-animazioni (hero transitions, button feedback)
- Skeleton loaders (componente già previsto in Fase 1)
- Schermate di errore user-friendly

### Watch History Sync
**Stato:** Backend implementato, frontend in Fase 2 + 5
- API endpoints per progressi: implementati nel backend (`POST /users/progress`, `GET /users/continue-watching`)
- Resume watching: previsto in Fase 2 (player) e Fase 5 (UI profilo)
- Auto-sync ogni 10 secondi durante la riproduzione: previsto in Fase 2
