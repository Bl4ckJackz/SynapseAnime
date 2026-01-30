# Comprehensive Architecture Analysis: Anime/Manga Streaming Platform with Monetization

## Executive Summary

This document provides a detailed analysis of the current anime/manga streaming platform architecture and outlines the implementation plan for advanced monetization features, including subscription tiers, ad integration, and premium content delivery.

## Current Architecture Overview

### Technology Stack
- **Backend**: NestJS (TypeScript)
- **Database**: PostgreSQL (with TypeORM)
- **Frontend**: Flutter (for mobile)
- **Authentication**: JWT-based with OAuth (Google)
- **Notifications**: Firebase Cloud Messaging
- **File Storage**: Local file system (for videos)

### Current Entity Relationships
- **User**: Core identity with subscription management
- **Anime/Manga**: Content entities with episodes/chapters
- **Watch History/Reading History**: User engagement tracking
- **Watchlist**: User preferences
- **User Preferences**: Personalization settings
- **Notification Settings**: Communication preferences

### Current Features
- User authentication (email/password, Google OAuth)
- Anime catalog browsing
- Video streaming capabilities
- Watch history tracking
- AI-powered recommendations
- Push notifications

## Enhanced Database Schema Design

### Updated User Entity with Monetization Features
```typescript
interface User {
  id: string;
  email: string;
  username: string;
  subscriptionTier: 'free' | 'premium';
  subscriptionStatus: 'active' | 'cancelled' | 'expired';
  subscriptionExpiresAt?: Date;
  stripeCustomerId?: string; // For payment processing
  watchlist: string[]; // anime IDs
  readinglist: string[]; // manga IDs
  watchHistory: WatchHistory[];
  readingHistory: ReadingHistory[];
  preferences: UserPreferences;
  createdAt: Date;
  updatedAt: Date;
}
```

### Anime Entity with Streaming Sources
```typescript
interface Anime {
  id: string;
  malId: number; // MyAnimeList ID
  title: string;
  titleEnglish?: string;
  titleJapanese?: string;
  synopsis: string;
  genres: string[];
  studios: string[];
  type: 'TV' | 'Movie' | 'OVA' | 'Special' | 'ONA';
  episodes: number;
  status: 'airing' | 'completed' | 'upcoming';
  aired: {
    from: Date;
    to?: Date;
  };
  rating: number;
  popularity: number;
  coverImage: string;
  bannerImage?: string;
  trailerUrl?: string;
  seasons?: Season[];
  streamingSources: StreamingSource[];
  createdAt: Date;
  updatedAt: Date;
}

interface Episode {
  id: string;
  animeId: string;
  number: number;
  title?: string;
  synopsis?: string;
  aired?: Date;
  thumbnailUrl?: string;
  streamingSources: StreamingSource[];
  duration?: number; // in seconds
}

interface StreamingSource {
  type: 'external' | 'internal' | 'direct_link';
  provider?: string; // e.g., 'gogoanime', 'internal-cdn'
  url: string;
  quality: '1080p' | '720p' | '480p' | '360p';
  language: 'sub' | 'dub';
  priority: number; // for fallback ordering
}
```

### Manga Entity with Chapter Management
```typescript
interface Manga {
  id: string;
  mangadexId: string;
  title: string;
  altTitles: Record<string, string>;
  description: string;
  authors: Author[];
  artists: Author[];
  genres: string[];
  tags: string[];
  status: 'ongoing' | 'completed' | 'hiatus' | 'cancelled';
  year: number;
  coverImage: string;
  rating: number;
  chapters: Chapter[];
  createdAt: Date;
  updatedAt: Date;
}

interface Chapter {
  id: string;
  mangaId: string;
  mangadexChapterId: string;
  number: number;
  title?: string;
  volume?: number;
  pages: number;
  language: string;
  scanlationGroup?: string;
  publishedAt: Date;
}
```

### News Aggregation Entity
```typescript
interface News {
  id: string;
  source: 'myanimelist' | 'anilist' | 'custom';
  sourceId?: string;
  title: string;
  content: string;
  excerpt: string;
  coverImage?: string;
  category: 'anime' | 'manga' | 'industry' | 'event';
  tags: string[];
  publishedAt: Date;
  externalUrl?: string;
}
```

## Backend Services Implementation

### 1. Anime Streaming Service
```typescript
class AnimeStreamingService {
  async getStreamingSources(animeId: string, episode: number): Promise<StreamingSource[]>;
  async uploadInternalSource(file: Buffer, metadata: object): Promise<string>;
  async validateDirectLink(url: string): Promise<boolean>;
  async getAvailableProviders(): Promise<string[]>;
}
```

### 2. MyAnimeList Integration Service
```typescript
class MyAnimeListService {
  async syncAnimeData(malId: number): Promise<Anime>;
  async searchAnime(query: string): Promise<Anime[]>;
  async getSeasonalAnime(season: string, year: number): Promise<Anime[]>;
  async getTopAnime(limit: number): Promise<Anime[]>;
}
```

### 3. MangaDex Integration Service
```typescript
class MangaDexService {
  private api: MangaDexAPI;
  
  async searchManga(query: string, filters?: object): Promise<Manga[]>;
  async getMangaDetails(mangadexId: string): Promise<Manga>;
  async getChapters(mangadexId: string): Promise<Chapter[]>;
  async getChapterPages(chapterId: string): Promise<string[]>;
  async syncMangaData(mangadexId: string): Promise<void>;
}
```

### 4. News Aggregation Service
```typescript
class NewsService {
  async fetchLatestNews(sources: string[]): Promise<News[]>;
  async createNotification(userId: string, newsId: string): Promise<void>;
  async getUserNotifications(userId: string): Promise<Notification[]>;
  async markAsRead(notificationId: string): Promise<void>;
}
```

### 5. Subscription & Monetization Service
```typescript
class SubscriptionService {
  async createCheckoutSession(userId: string, plan: 'premium'): Promise<string>;
  async handleWebhook(event: object): Promise<void>;
  async cancelSubscription(userId: string): Promise<void>;
  async checkSubscriptionStatus(userId: string): Promise<boolean>;
}

class AdService {
  async getAdConfiguration(userTier: string): Promise<AdConfig>;
  async trackAdImpression(adId: string, userId: string): Promise<void>;
}
```

## Frontend Architecture (Netflix-Style UI)

### Routing Structure
```
/app
  /anime
    /[id]
      /watch/[episode]
  /manga
    /[id]
      /read/[chapter]
  /news
  /profile
  /subscription
```

### Key Components
- `<NetflixStyleHero />` - Banner carousel with trailers
- `<ContentRow />` - Horizontal scrolling content rows
- `<VideoPlayer />` - Custom video player with controls
- `<MangaReader />` - Custom manga reader component
- `<NotificationCenter />` - News and notification center

### Design System
- Color palette inspired by Netflix (dark theme with red accents)
- Responsive grid system
- Animated loading skeletons
- Touch-friendly navigation

## Monetization Strategy

### Feature Matrix
| Feature | Free Tier | Premium Tier |
|---------|-----------|--------------|
| Video Quality | Up to 720p | Up to 1080p |
| Ads | Present | None |
| Concurrent Streams | 1 | 4 |
| Offline Downloads | No | Yes |
| Manga Reader Ads | Present | None |
| Early Access | No | Yes |

### Payment Integration
- Stripe for subscription management
- PayPal as alternative payment method
- Monthly ($4.99) and annual ($49.99) plans
- 7-day free trial

## Technical Implementation Requirements

### Infrastructure
- CDN for asset delivery (Cloudflare)
- Redis for caching
- Video streaming optimization
- Service workers for offline capability

### Security
- JWT authentication with refresh tokens
- Rate limiting
- Content protection (DRM)
- Secure payment processing

### Performance
- Database indexing
- Query optimization
- Lazy loading
- Image optimization

## Development Roadmap

### Phase 1: Foundation
- [ ] Enhance user entity with subscription fields
- [ ] Implement subscription service
- [ ] Set up payment gateway integration

### Phase 2: Content Management
- [ ] Enhance anime/manga entities with streaming sources
- [ ] Implement content ingestion services
- [ ] Create news aggregation system

### Phase 3: Frontend Development
- [ ] Develop Netflix-style UI components
- [ ] Implement video player with quality selection
- [ ] Create manga reader with multiple view modes

### Phase 4: Monetization
- [ ] Implement ad insertion logic
- [ ] Create subscription management UI
- [ ] Add premium content indicators

### Phase 5: Testing & Deployment
- [ ] Unit and integration testing
- [ ] Performance optimization
- [ ] Security audit
- [ ] Production deployment

## Conclusion

The current architecture provides a solid foundation for building an anime/manga streaming platform with monetization features. The proposed enhancements will enable a dual-revenue model through subscriptions and advertising while maintaining a high-quality user experience.

The modular architecture allows for easy extension of features and integration with third-party services like MyAnimeList and MangaDex. The separation of concerns between the backend services and frontend components ensures scalability and maintainability.