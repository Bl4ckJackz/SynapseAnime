# Consumet API Sources Documentation

This document outlines the available sources in the Consumet API and their usage patterns.
**Important:** Parameter styles (Path vs Query) vary by provider. Please consult the table below for specific usage.

## Base URL
The Consumet API runs at `http://localhost:3004`. All routes are prefixed with the category name.

## 1. Anime Providers (`/anime/...`)
| Provider | Search URL | Info URL | Watch URL |
| :--- | :--- | :--- | :--- |
| **AnimeUnity** | `/:query` | `/info?id={id}&page={page}` | `/watch/{episodeId}` |
| **AnimeKai** | `/:query?page={page}` | `/info?id={id}` | `/watch/{episodeId}?server={server}&dub={dub}` |
| **HiAnime** | `/:query?page={page}` | `/info?id={id}` | `/watch/{episodeId}?server={server}&category={sub/dub}` |
| **AnimePahe** | `/:query` | `/info?id={id}` | `/watch/{episodeId}` |
| **AnimeSaturn**| `/:query` | `/info?id={id}` | `/watch?episodeId={episodeId}` |
| **GogoAnime** | `/:query` | `/info/{id}` | `/watch/{episodeId}` |
| **Zoro** | `/:query` | `/info?id={id}` | `/watch?episodeId={episodeId}` |
| **KickAssAnime**| `/:query` | `/info?id={id}` | `/watch/:episodeId` |

*Note: `{id}` refers to the specific anime ID returned in search results. `{episodeId}` is found in the Info response.*

---

## 2. Manga Providers (`/manga/...`)
| Provider | Search URL | Info URL | Read URL |
| :--- | :--- | :--- | :--- |
| **Comick** (Local) | `/:query` | `/info/{id}` | `/read/{chapterId}` |
| **MangaDex** | `/:query` | `/info/{id}` | `/read/{chapterId}` |
| **MangaHere** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **MangaKakalot** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **MangaPill** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **MangaReader** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **WeebCentral** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **AsuraScans** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **MangaWorld** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **MangaKatana** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |
| **MangaSee** | `/:query` | `/info?id={id}` | `/read?chapterId={chapterId}` |

**Key Difference:**
- **Path Param Style** (e.g., `/info/one-piece`): Comick, MangaDex.
- **Query Param Style** (e.g., `/info?id=one-piece`): Most other manga providers (MangaHere, MangaKakalot, etc.).

---

## 3. Movies & TV (`/movies/...`)
| Provider | Search URL | Info URL | Watch URL |
| :--- | :--- | :--- | :--- |
| **FlixHQ** | `/:query` | `/info?id={id}` | `/watch?episodeId={episodeId}&mediaId={mediaId}` |
| **Dramacool** | `/:query` | `/info?id={id}` | `/watch?episodeId={episodeId}&mediaId={mediaId}` |
| **Goku** | `/:query` | `/info?id={id}` | `/watch?episodeId={episodeId}&mediaId={mediaId}` |

---

## Response Objects

### Search Response
```json
{
  "currentPage": 1,
  "hasNextPage": true,
  "results": [
    {
      "id": "anime-id-123",
      "title": "Anime Title",
      "image": "https://example.com/cover.jpg",
      "url": "https://provider.com/anime/123",
      "releaseDate": "2023"
    }
  ]
}
```

### Info Response (Anime)
```json
{
  "id": "anime-id-123",
  "title": "Full Anime Title",
  "episodes": [
    {
      "id": "ep-1",
      "number": 1,
      "title": "Episode 1"
    }
  ]
}
```

### Source Response
```json
{
  "headers": { "Referer": "..." },
  "sources": [
    {
      "url": "https://stream.url/playlist.m3u8",
      "quality": "auto",
      "isM3U8": true
    }
  ]
}
```
