# Project Analysis Report

## 1. Current Architecture Overview

### Backend
- **Framework:** NestJS
- **Language:** TypeScript
- **Database:** SQLite (Development), TypeORM (ORM)
- **Authentication:** JWT, Passport (Local Strategy)
- **External Services:** Firebase (Notifications), Jikan (MAL API)
- **Structure:** Modular (Auth, Anime, Users, AI, Notifications)

### Mobile
- **Framework:** Flutter
- **State Management:** Riverpod
- **Routing:** GoRouter
- **Networking:** Dio
- **Video:** Video Player + Chewie
- **Architecture:** Clean Architecture (Data, Domain, Presentation)

## 2. Dependency Map

### Backend (`package.json`)
- **Core:** `@nestjs/core`, `@nestjs/common`, `rxjs`
- **Data:** `typeorm`, `sqlite3`, `pg` (installed but not currently used in `app.module.ts`)
- **Auth:** `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt`
- **API/Http:** `axios`, `@nestjs/axios`
- **Validation:** `class-validator`, `class-transformer`
- **Anime Data:** `jikan4.js`
- **Notifications:** `firebase-admin`

### Mobile (`pubspec.yaml`)
- **Core:** `flutter`, `flutter_riverpod`, `go_router`
- **UI:** `flutter_svg`, `shimmer`, `rive`, `lottie`
- **Media:** `video_player`, `chewie`, `cached_network_image`
- **Data:** `dio`, `shared_preferences`, `flutter_secure_storage`
- **Firebase:** `firebase_core`, `firebase_messaging`

## 3. Gap Analysis & Requirements Compatibility

### Missing Features (vs Requirements)
1.  **Manga Support:**
    -   **Backend:** No `Manga` module, entities, or services.
    -   **Mobile:** No Manga screens, providers, or reading logic.
2.  **Monetization & Subscriptions:**
    -   **Backend:** No `Subscription` or `Payment` modules. User entity lacks subscription fields.
    -   **Mobile:** No Subscription management screens or logic.
3.  **News System:**
    -   **Backend:** No `News` module.
    -   **Mobile:** No News feed or screens.
4.  **Advanced Streaming:**
    -   **Backend:** Basic streaming controller exists. Needs expansion for multi-quality, HLS, and external providers.
5.  **Database Schema:**
    -   Current `Anime` entity is basic. Needs expansion to match the detailed schema (Seasons, StreamingSources, etc.).
    -   Missing `Manga`, `Chapter`, `News`, `UserPreferences` entities.

### Technical Debt & Improvements
-   **Database:** Currently using SQLite for development. Should switch to PostgreSQL for production features (Sharding, Replication) as requested.
-   **Config:** Hardcoded SQLite path in `app.module.ts`. Should use `ConfigService` for all DB connection params.
-   **Testing:** Basic E2E tests exist. Need comprehensive Unit and Integration tests.

## 4. Implementation Plan

### Phase 2: Backend Implementation
1.  **Database Schema Update:**
    -   Update `Anime` entity.
    -   Create `Manga`, `Chapter`, `News`, `User` (extended) entities.
    -   Configure TypeORM for PostgreSQL.
2.  **Service Implementation:**
    -   **Anime Service:** Enhance with multi-source streaming and MAL sync.
    -   **Manga Service:** Implement MangaDex integration.
    -   **News Service:** Implement aggregation logic.
    -   **Subscription Service:** Implement Stripe/Payment logic.

### Phase 3: Frontend Implementation
1.  **UI Overhaul:** Implement Netflix-style Design System.
2.  **Manga Section:** Create Reader, Dashboard, and Details screens.
3.  **News Section:** Create News Feed and Article view.
4.  **Subscription:** Create Plan selection and Payment flow.

### Phase 4: Monetization
1.  **Ads:** Integrate AdMob/AdSense logic.
2.  **Premium Features:** Implement logic to gate content based on subscription status.

### Phase 5: Infrastructure
1.  **Caching:** Implement Redis.
2.  **CDN:** Configure Cloudflare/BunnyCDN.
3.  **Deployment:** Dockerize and set up CI/CD.
