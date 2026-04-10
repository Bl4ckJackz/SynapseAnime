# Web Frontend — Backend API Reference

Riferimento completo degli endpoint backend che il frontend web deve consumare.
Base URL: `http://localhost:3005` (variabile `NEXT_PUBLIC_API_URL`).

Rate limit globale: 60 richieste/minuto per IP.

---

## Autenticazione

Tutti gli endpoint marcati con **Auth** richiedono header `Authorization: Bearer <jwt_token>`.
Il token JWT si ottiene da login/register e va salvato in `localStorage`.
Se il backend risponde `401`, il client deve rimuovere il token e redirectare a `/login`.

### POST /auth/login
- **Auth:** No (usa LocalAuthGuard con email + password)
- **Throttle:** 5 req/min
- **Body:** `{ email: string, password: string }`
- **Response:** `{ accessToken: string, user: User }`

### POST /auth/register
- **Auth:** No
- **Throttle:** 3 req/min
- **Body:** `{ email: string, password: string (10+ chars, upper+lower+digit), nickname?: string (2-30 chars) }`
- **Response:** `{ accessToken: string, user: User }`

### POST /auth/google
- **Auth:** No
- **Throttle:** 5 req/min
- **Body:** `{ token: string }` (Google OAuth token)
- **Response:** `{ accessToken: string, user: User }`

### GET /auth/profile
- **Auth:** Si
- **Response:** `User` (con `preference` embedded)

---

## Anime

### GET /anime
- **Query:** `genre?, status?, search?, page? (default 1), limit? (default 20)`
- **Response:** `PaginatedResult<Anime>`

### GET /anime/genres
- **Response:** `string[]`

### GET /anime/new-releases
- **Query:** `limit? (default 10), page? (default 1)`
- **Response:** `PaginatedResult<Anime>`

### GET /anime/top-rated
- **Query:** `limit? (default 10), page? (default 1), filter?`
- **Response:** `PaginatedResult<Anime>`

### GET /anime/sources
- **Response:** `AnimeSource[]` — `{ id, name, description, isActive }`

### POST /anime/sources/:id/activate
- **Response:** `{ success: true, activeSource: string }`

### GET /anime/:id
- **Response:** `Anime` o 404

### GET /anime/:id/episodes
- **Response:** `Episode[]`

### Sorgenti AnimeUnity (`/anime/animeunity/...`)
| Endpoint | Risposta |
|----------|----------|
| `GET /anime/animeunity/search?q=` | `Anime[]` |
| `GET /anime/animeunity/trending` | `Anime[]` (max 10) |
| `GET /anime/animeunity/popular` | `Anime[]` (max 10) |
| `GET /anime/animeunity/details/:id` | `Anime` |
| `GET /anime/animeunity/episodes/:animeId` | `Episode[]` |
| `GET /anime/animeunity/episode/*` | `{ sources: [{ url, quality, isM3U8 }], download: null }` |

### Sorgenti HiAnime (`/anime/hianime/...`)
Stessa struttura di AnimeUnity: `search?q=`, `trending`, `popular`, `details/:id`, `episodes/:animeId`, `episode/*`.

---

## Jikan (Metadati MyAnimeList)

### Anime (`/jikan/anime/...`)
| Endpoint | Query | Risposta |
|----------|-------|----------|
| `GET /jikan/anime/top` | `page?, limit? (max 25), type? (tv\|movie\|ova\|special\|ona\|music), filter? (airing\|upcoming\|bypopularity\|favorite)` | Paginated anime |
| `GET /jikan/anime/new-releases` | `page?` | Paginated |
| `GET /jikan/anime/schedule` | `day?` | Schedule anime |
| `GET /jikan/anime/search` | `q?, page?, limit?, type?, status? (airing\|complete\|upcoming), genres?, order_by?, sort?, min_score?, max_score?, sfw?` | Paginated |
| `GET /jikan/anime/:id` | — | Anime details |
| `GET /jikan/anime/genres` | — | Genre list |
| `GET /jikan/anime/:id/episodes` | — | Episode list |

### Manga (`/jikan/manga/...`)
| Endpoint | Query | Risposta |
|----------|-------|----------|
| `GET /jikan/manga/search` | `q?, page?, limit?, type?, genres?` | Paginated manga |
| `GET /jikan/manga/top` | `page?, limit?, type?, filter?` | Top manga |
| `GET /jikan/manga/genres` | — | Genre list |
| `GET /jikan/manga/:malId` | — | Manga details |
| `GET /jikan/manga/:malId/full` | — | Full details con relazioni |
| `GET /jikan/manga/:malId/characters` | — | Characters |
| `GET /jikan/manga/:malId/statistics` | — | Statistics |
| `GET /jikan/manga/:malId/recommendations` | — | Recommended manga |

---

## MangaDex

| Endpoint | Risposta |
|----------|----------|
| `GET /mangadex/health` | `{ service, status, timestamp }` |
| `GET /mangadex/image-proxy?url=` | Image buffer (proxy CORS) |
| `GET /mangadex/manga/search?q=` | `{ data: Manga[] }` |
| `GET /mangadex/manga/:id` | Manga details |
| `GET /mangadex/manga/:id/chapters?lang=en` | Chapter list |
| `GET /mangadex/chapter/:chapterId/pages` | `{ images: string[] }` |
| `GET /mangadex/manga/:id/sync` | `{ status, message }` |

---

## MangaHook

| Endpoint | Query | Risposta |
|----------|-------|----------|
| `GET /mangahook/manga` | `page?, type? (newest\|latest\|topview), category?, state? (Completed\|Ongoing)` | Paginated manga |
| `GET /mangahook/manga/search` | `q=, page?` | Manga list |
| `GET /mangahook/filters` | — | Available filters |
| `GET /mangahook/health` | — | `{ service, status, timestamp }` |
| `GET /mangahook/manga/:id` | — | Manga details |
| `GET /mangahook/manga/:mangaId/chapter/:chapterId` | — | Chapter pages |

---

## Streaming & Image Proxy

| Endpoint | Risposta |
|----------|----------|
| `GET /stream/local/:animeId/:filename` | StreamableFile (MP4) |
| `GET /stream/proxy-image?url=` | Proxied image (cache 24h) |

---

## Film e Serie TV (`/movies-tv/...`)

| Endpoint | Query | Risposta |
|----------|-------|----------|
| `GET /movies-tv/search` | `q=, type? (movie\|tv), page?, limit? (max 20)` | Paginated results |
| `GET /movies-tv/movies/trending` | `page?` | Trending movies |
| `GET /movies-tv/movies/popular` | `page?` | Popular movies |
| `GET /movies-tv/movies/genres` | — | Genre list |
| `GET /movies-tv/movies/:id` | — | Movie details |
| `GET /movies-tv/tv/trending` | `page?` | Trending TV |
| `GET /movies-tv/tv/popular` | `page?` | Popular TV |
| `GET /movies-tv/tv/genres` | — | Genre list |
| `GET /movies-tv/tv/:id` | — | TV show details |
| `GET /movies-tv/tv/:id/season/:season` | — | Season details |
| `GET /movies-tv/stream/movie/:tmdbId` | — | Stream URL (embed) |
| `GET /movies-tv/stream/tv/:tmdbId/:season/:episode` | — | Stream URL (embed) |

---

## Utenti (`/users/...`) — Auth richiesta

### Profilo e Preferenze
| Endpoint | Body/Query | Risposta |
|----------|-----------|----------|
| `GET /users/profile` | — | `User` (con `preference` embedded) |
| `PUT /users/profile` | `{ nickname?: string (2-30) }` | `User` aggiornato |
| `PUT /users/preferences` | `{ preferredLanguages?: string[], preferredGenres?: string[] }` | `UserPreference` |

> **Nota:** Non esiste `GET /users/preferences` separato — le preferenze sono embedded nella risposta profilo.

### Watchlist
| Endpoint | Risposta |
|----------|----------|
| `GET /users/watchlist` | `WatchlistItem[]` |
| `POST /users/watchlist/:animeId` | Aggiunto |
| `DELETE /users/watchlist/:animeId` | Rimosso |
| `GET /users/watchlist/:animeId/check` | `{ inWatchlist: boolean }` |
| `POST /users/watchlist/manga/:mangaId` | Aggiunto |
| `DELETE /users/watchlist/manga/:mangaId` | Rimosso |
| `GET /users/watchlist/manga/:mangaId/check` | `{ inWatchlist: boolean }` |

### Cronologia e Progressi
| Endpoint | Query | Risposta |
|----------|-------|----------|
| `GET /users/history` | `limit? (default 20)` | `WatchHistory[]` |
| `GET /users/continue-watching` | `limit? (default 10)` | `WatchHistory[]` (in progress) |
| `POST /users/progress` | Body: `{ episodeId, progressSeconds, source?, animeId?, animeTitle?, animeCover?, animeTotalEpisodes?, episodeNumber?, episodeTitle?, episodeThumbnail?, duration? }` | Progress |
| `GET /users/progress/:episodeId` | — | Progress per episodio |
| `GET /users/anime/:animeId/progress` | — | Progress per anime |

---

## Commenti (`/comments/...`)

| Endpoint | Auth | Body/Query | Risposta |
|----------|------|-----------|----------|
| `POST /comments` | Si | `{ text, rating? (1-5), animeId?, mangaId?, episodeId?, parentId? }` | `Comment` |
| `GET /comments/anime/:animeId` | No | `page?, limit? (default 20)` | `Comment[]` |
| `GET /comments/manga/:mangaId` | No | `page?, limit?` | `Comment[]` |
| `GET /comments/episode/:episodeId` | No | `page?, limit?` | `Comment[]` |
| `GET /comments/:target/:targetId/rating` | No | — | `{ averageRating, totalRatings }` |
| `GET /comments/:id` | No | — | `Comment` |
| `PUT /comments/:id` | Si (owner) | `{ text?, rating? }` | `Comment` |
| `DELETE /comments/:id` | Si (owner) | — | `{ message }` |

---

## Download (`/download/...`) — Auth richiesta

| Endpoint | Body/Query | Risposta |
|----------|-----------|----------|
| `GET /download/settings` | — | `DownloadSettings` |
| `PUT /download/settings` | `{ downloadPath?, useServerFolder?, serverFolderPath? }` | `DownloadSettings` |
| `GET /download/queue` | — | `Download[]` |
| `GET /download/history` | `limit? (default 50)` | `Download[]` |
| `DELETE /download/clear` | — | `{ message }` |
| `POST /download/episode/:animeId/:episodeId` | `source?` (query) | `{ message, download }` |
| `POST /download/season/:animeId/:season` | `source?, title?` (query) | `{ message, downloads }` |
| `POST /download/url` | `{ url, animeName, episodeNumber, episodeTitle? }` | `{ message, download }` |
| `DELETE /download/:id` | — | Cancel download |
| `DELETE /download/:id/file` | — | Delete file |

### WebSocket — Download Progress
- **Namespace:** `/downloads`
- **Auth:** JWT nel handshake (`auth.token`, `query.token`, o header `Authorization`)
- **Room:** Auto-join `user_{userId}`
- **Evento:** `download_progress` — oggetto `Download` con progresso

### WebSocket — History Updates
- **Namespace:** `/history`
- **Auth:** JWT nel handshake
- **Room:** Auto-join `user_{userId}`
- **Evento:** `history_updated` — fired quando la cronologia cambia

---

## AI (`/ai/...`)

| Endpoint | Auth | Body | Risposta |
|----------|------|------|----------|
| `POST /ai/recommend` | Si | `{ message: string }` | AI recommendation |
| `POST /ai/chat` | Si | `{ messages: [{ role, content }] }` | Chat response |
| `GET /ai/test` | No | — | Test response |

---

## News (`/news/...`)

| Endpoint | Auth | Query | Risposta |
|----------|------|-------|----------|
| `GET /news` | No | `sources?, category?, limit? (default 10, max 100), search?` | `News[]` |
| `GET /news/recent` | No | `limit?` | `News[]` |
| `GET /news/trending` | No | `limit? (default 5, max 50)` | `News[]` |
| `GET /news/category/:category` | No | `limit?` | `News[]` |
| `GET /news/search/:query` | No | `limit?` | `News[]` |
| `GET /news/tags/:tags` | No | `limit?` | `News[]` |
| `GET /news/:id` | No | — | `News` |
| `POST /news` | Si | `CreateNewsDto` | `News` |
| `PUT /news/:id` | Si | `CreateNewsDto` | `News` |
| `DELETE /news/:id` | Si | — | `News` |

---

## Ads (`/ads/...`) — Auth richiesta

| Endpoint | Body | Risposta |
|----------|------|----------|
| `GET /ads/config` | — | `{ adConfiguration: { userTier, config } }` |
| `GET /ads/for-user/:contentType` | — | `{ showAd, ad?, skipAllowed, skipAfter }` |
| `POST /ads/track-impression` | `{ adId, sessionId, durationWatched? }` | `{ success }` |
| `POST /ads/track-click/:impressionId` | — | `{ success }` |
| `GET /ads/performance/:adId` | — | Metrics |
| `POST /ads/create` | `{ title, content, advertiser, adType, targetAudience, startDate?, endDate? }` | `Ad` |

---

## Notifiche (`/notifications/...`) — Auth richiesta

| Endpoint | Body | Risposta |
|----------|------|----------|
| `GET /notifications/settings` | — | `NotificationSettings` |
| `PUT /notifications/settings` | `{ globalEnabled?, animeId?, animeEnabled? }` | `NotificationSettings` |
| `POST /notifications/register-token` | `{ fcmToken }` | `{ success }` |
| `DELETE /notifications/unregister-token` | — | `{ success }` |

---

## Libreria Locale (`/library/...`)

| Endpoint | Risposta |
|----------|----------|
| `GET /library/folders` | `Folder[]` |
| `GET /library/folder/:folderId` | Folder contents |
| `GET /library/folder/:folderId/videos` | `Video[]` |
| `GET /library/stream/:videoId/playlist.m3u8` | HLS playlist |
| `GET /library/stream/:videoId/segment/:segmentId.ts` | HLS segment |
| `GET /library/stream/:videoId/direct?start=` | Direct video stream |
| `POST /library/organize` | Organize response |

---

## Endpoint NON ancora implementati nel backend

Questi endpoint sono referenziati nei piani di fase ma **non hanno ancora controller/route nel backend**:

| Endpoint | Fase | Stato Backend |
|----------|------|---------------|
| `POST /monetization/checkout` | 6 | Solo servizio interno, nessun controller |
| `POST /monetization/cancel` | 6 | Solo servizio interno, nessun controller |
| `GET /users/profile/stats` | 5 | Non esiste — calcolare client-side |
| `GET /users/preferences` | 5 | Non esiste separato — embedded in profilo |
| `GET /users/reading-history` | 5 | Non verificato — potrebbe non esistere |
