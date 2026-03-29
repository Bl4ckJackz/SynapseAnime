# OpenAnime - Analisi Problemi e Piano Implementazioni

> Documento generato il 01/03/2026 - Analisi completa del progetto

---

## INDICE

1. [Problemi Critici di Sicurezza](#1-problemi-critici-di-sicurezza)
2. [Problemi Backend](#2-problemi-backend)
3. [Problemi Mobile App](#3-problemi-mobile-app)
4. [Problemi Architetturali](#4-problemi-architetturali)
5. [Piano Implementazioni](#5-piano-implementazioni)
6. [Roadmap Prioritizzata](#6-roadmap-prioritizzata)

---

## 1. PROBLEMI CRITICI DI SICUREZZA

### 1.1 Secrets esposti nel repository
- **File:** `backend/.env` - API keys (Perplexity, Firebase private key, JWT secret) hardcoded
- **Rischio:** Compromissione totale del sistema se il repo diventa pubblico
- **Fix:** Usare secret manager, mai committare `.env` reale, solo `.env.example`

### 1.2 CORS aperto a tutti gli origin
- **File:** `backend/src/main.ts` (linea 11-12) e `download.gateway.ts` (linea 14-16)
- `origin: '*'` con `credentials: true` e' una misconfiguration pericolosa
- **Fix:** Specificare origin espliciti da variabile d'ambiente

### 1.3 JWT Secret con fallback hardcoded
- **File:** `backend/src/auth/jwt.strategy.ts` (linea 21)
- Fallback a `'defaultSecret'` se la variabile d'ambiente manca
- **Fix:** Lanciare errore se `JWT_SECRET` non configurato

### 1.4 Stripe placeholder key
- **File:** `backend/src/services/subscription.service.ts` (linea 33)
- Fallback a `'sk_test_placeholder'`
- **Fix:** Fail-fast con errore se manca la key

### 1.5 Log di dati sensibili
- **File:** `backend/src/main.ts` (linea 19-25) - Log di TUTTI i request body (password incluse)
- **File:** `mobile/lib/data/api_client.dart` (linea 37-41) - Log dei token Bearer
- **Fix:** Sanitizzare i log, rimuovere stampa di credenziali

### 1.6 Nessun rate limiting sugli endpoint auth
- Login/register senza protezione brute force
- **Fix:** Implementare `@nestjs/throttler` o rate limiter custom

### 1.7 Nessun Helmet (security headers)
- Mancano CSP, X-Frame-Options, HSTS, etc.
- **Fix:** `npm install @nestjs/helmet` e abilitarlo in `main.ts`

---

## 2. PROBLEMI BACKEND

### 2.1 Database e ORM

| Problema | File | Gravita |
|----------|------|---------|
| `synchronize: true` sempre attivo | `app.module.ts:59` | ALTA |
| Repository duplicato (Episode iniettato 2 volte) | `users.service.ts:27-29` | MEDIA |
| Entity duplicate nel modulo (WatchHistory, Episode) | `users.module.ts:25-27` | MEDIA |
| Query unbounded (`find()` senza limit) | `ai.service.ts:56` | ALTA |
| Cache in-memory senza limite di dimensione | `cache.service.ts` | MEDIA |
| Watch history con magic number (20) hardcoded | `users.service.ts:105` | BASSA |

### 2.2 Validazione Input

| Problema | File | Gravita |
|----------|------|---------|
| `register()` accetta `@Body() body: any` | `auth.controller.ts:23-26` | ALTA |
| `createNews()` senza DTO | `news.controller.ts:61` | MEDIA |
| `createAd()` con `targetingCriteria?: any` | `ad.controller.ts:113-120` | MEDIA |
| Download URL non validato | `download.controller.ts:115-123` | ALTA |
| Update profile senza DTO | `users.controller.ts:33` | MEDIA |
| Download settings senza validazione | `download.service.ts:147-154` | MEDIA |

### 2.3 File System e Download

| Problema | File | Gravita |
|----------|------|---------|
| URL di download non validati (no HTTP/S check) | `download.service.ts:336-380` | ALTA |
| `sanitizeFileName` non previene `..` traversal | `download.service.ts:807-813` | ALTA |
| Progress salvato su DB ogni 5% (20 write per download) | `download.service.ts:680` | MEDIA |
| Errori di eliminazione file silenziosi | `download.service.ts:452` | BASSA |

### 2.4 Logging e Error Handling

| Problema | File | Gravita |
|----------|------|---------|
| 128+ istanze di `console.log` nel codice | Tutto il backend | MEDIA |
| Errori silenziati con catch vuoti | `anime.service.ts:73` | MEDIA |
| Password minima solo 6 caratteri | `register.dto.ts:8` | MEDIA |
| Nessun API versioning (/v1/, /v2/) | Tutti i controller | BASSA |
| Route ordering ambiguo (`:id` vs parametri specifici) | `news.controller.ts` | BASSA |

### 2.5 Test Coverage

- Solo **6 file .spec.ts** e **2 e2e test** su 133+ file TypeScript
- Coverage stimata < 10%
- Nessun test per: auth flow, download flow, comments, user management

---

## 3. PROBLEMI MOBILE APP

### 3.1 Configurazione Critica

| Problema | File | Gravita |
|----------|------|---------|
| URL `localhost` hardcoded (non funziona su device fisici) | `constants.dart:14-15` | CRITICA |
| Nessun sistema di environment (dev/staging/prod) | - | ALTA |
| Firebase non inizializzato in `main.dart` | `main.dart` | ALTA |
| `debugLogDiagnostics: true` nel router | `router.dart:61` | BASSA |

### 3.2 Null Safety e Type Safety

| Problema | File | Gravita |
|----------|------|---------|
| Force unwrap (`!`) senza null check | `anime_repository.dart:265-269` | ALTA |
| Force unwrap sui path parameters | `router.dart:113-115`, `player_screen.dart:113` | ALTA |
| Cast unsafe (`as String`) senza validazione | `user_repository.dart:156-170` | MEDIA |
| `Map.from()` senza type check | `player_screen.dart:138-141` | MEDIA |

### 3.3 Performance

| Problema | File | Gravita |
|----------|------|---------|
| `AnimeCard` guarda l'intero `watchHistoryProvider` | `anime_card.dart:113-119` | ALTA |
| Timer di progress ogni 5 sec con network call | `player_screen.dart:282-299` | ALTA |
| Nessun caching/memoization dei risultati | Provider vari | MEDIA |
| Socket senza timeout su connect | `socket_service.dart:18-47` | MEDIA |

### 3.4 Codice e Architettura

| Problema | File | Gravita |
|----------|------|---------|
| `getAllEpisodes()` - 199 righe, logica annidata | `anime_repository.dart:244-443` | ALTA |
| `getChapters()` - scoring con magic numbers | `manga_repository.dart:232-380` | MEDIA |
| Repository `anime_repository.dart` DUPLICATO | `data/` e `features/anime/data/` | ALTA |
| Pattern misti (StateNotifier vs FutureProvider) | Provider vari | MEDIA |
| 150+ statement `print()`/`debugPrint()` | Tutto il codebase | MEDIA |
| 5 TODO non implementati | Home, manga, player, library | BASSA |

### 3.5 Dipendenze

| Problema | Dettaglio | Gravita |
|----------|-----------|---------|
| Librerie HTTP duplicate | Sia `dio` che `http` incluse | BASSA |
| Dipendenze inutilizzate | `liquid_swipe`, `cristalyse` (solo demo) | BASSA |
| `socket_io_client` + HTTP polling duplicato | Meccanismo ridondante | MEDIA |
| Nessun version pinning con upper bound | `pubspec.yaml` | BASSA |

### 3.6 Internazionalizzazione

- Locali dichiarate (it, en, ja) ma nessun file ARB
- Stringhe hardcoded in italiano/inglese nel codice
- Nessuna implementazione i18n reale

### 3.7 Nessun Test

- Zero file di test nella mobile app
- Logica complessa nei repository completamente non testata
- State management non testato

---

## 4. PROBLEMI ARCHITETTURALI

### 4.1 Mancanza di Environment Configuration
- Backend usa `.env` senza validazione schema
- Mobile ha URL hardcoded senza distinzione dev/prod
- Nessun sistema centralizzato di configurazione

### 4.2 Logging Inconsistente
- Backend: mix di `console.log` e NestJS `Logger`
- Mobile: `print()` e `debugPrint()` ovunque
- Nessun framework di logging strutturato

### 4.3 Error Handling Non Standardizzato
- Backend: catch vuoti, errori silenziati, eccezioni generiche
- Mobile: `e.toString()` esposto all'UI, string matching per error code

### 4.4 Separazione Layer Incompleta
- Mobile: repository duplicati tra `data/` e `features/`
- Backend: servizi sparsi tra `services/`, moduli specifici, e `common/`
- API client usato direttamente nei provider senza repository in alcuni casi

---

## 5. PIANO IMPLEMENTAZIONI

### FASE 1: Sicurezza e Stabilita (Priorita CRITICA)

#### 1.1 Hardening Sicurezza Backend
```
Effort: 2-3 giorni
Files coinvolti: main.ts, auth/*, .env, jwt.strategy.ts
```
- [ ] Rimuovere tutti i secrets dal `.env` committato, creare `.env.example`
- [ ] Configurare CORS con origin specifici da env variable
- [ ] Aggiungere Helmet per security headers
- [ ] Rimuovere fallback `'defaultSecret'` da JWT strategy (fail-fast)
- [ ] Implementare `@nestjs/throttler` sugli endpoint auth (5 req/min login, 3 req/min register)
- [ ] Aumentare password minima a 10 caratteri con validazione complessita
- [ ] Aggiungere validazione schema con Joi per ConfigModule
- [ ] Rimuovere log di request body e credenziali da `main.ts`

#### 1.2 Validazione Input Completa
```
Effort: 2 giorni
Files coinvolti: tutti i controller
```
- [ ] Usare `RegisterDto` con `@UsePipes(ValidationPipe)` in `auth.controller.ts`
- [ ] Creare `CreateDownloadDto` con validazione URL
- [ ] Creare `CreateNewsDto`, `UpdateProfileDto`
- [ ] Aggiungere `ValidationPipe` globale in `main.ts`
- [ ] Fixare sanitizzazione filename per prevenire path traversal (`..`)

#### 1.3 Fix Configurazione Mobile
```
Effort: 1 giorno
Files coinvolti: constants.dart, main.dart, pubspec.yaml
```
- [ ] Implementare sistema di environment config (dev/staging/prod)
- [ ] Sostituire URL localhost con configurazione dinamica
- [ ] Inizializzare Firebase in `main.dart`
- [ ] Rimuovere `debugLogDiagnostics: true` dalla produzione

---

### FASE 2: Qualita del Codice (Priorita ALTA)

#### 2.1 Cleanup Logging
```
Effort: 1-2 giorni
Files coinvolti: tutto il codebase
```
- [ ] Backend: sostituire tutti i `console.log` con `Logger` di NestJS
- [ ] Mobile: sostituire tutti i `print()` con package `logger` o wrapper con `kDebugMode`
- [ ] Rimuovere log di dati sensibili (token, password, headers)
- [ ] Implementare logging strutturato con livelli (info, warn, error, debug)

#### 2.2 Fix Null Safety Mobile
```
Effort: 1-2 giorni
Files coinvolti: repositories, providers, router
```
- [ ] Sostituire tutti i force unwrap (`!`) con null-safe operators (`?.`, `??`)
- [ ] Aggiungere null check prima di tutti i cast (`as Type`)
- [ ] Validare path parameters nel router prima dell'uso
- [ ] Implementare JSON parsing type-safe

#### 2.3 Fix Database Issues
```
Effort: 0.5 giorni
Files coinvolti: app.module.ts, users.module.ts, users.service.ts
```
- [ ] Rendere `synchronize` dipendente dall'environment (`!== 'production'`)
- [ ] Rimuovere injection duplicata di `Episode` in `users.service.ts`
- [ ] Rimuovere entity duplicate in `users.module.ts`
- [ ] Aggiungere limit alla query in `ai.service.ts` (`find()` -> `find({ take: 100 })`)

#### 2.4 Refactoring Codice Complesso
```
Effort: 2-3 giorni
Files coinvolti: anime_repository.dart, manga_repository.dart
```
- [ ] Spezzare `getAllEpisodes()` (199 righe) in funzioni piu piccole e testabili
- [ ] Estrarre magic numbers in costanti nominate nel scoring di `getChapters()`
- [ ] Rimuovere il repository `anime_repository.dart` duplicato (consolidare in uno solo)
- [ ] Standardizzare pattern dei provider (scegliere tra StateNotifier e AsyncNotifier)

---

### FASE 3: Performance e Funzionalita (Priorita MEDIA)

#### 3.1 Ottimizzazione Performance Mobile
```
Effort: 2 giorni
```
- [ ] Usare `ref.watch(provider.select(...))` in `AnimeCard` per evitare rebuild completi
- [ ] Implementare debouncing sul timer di progress del player (da 5s a 15-30s)
- [ ] Aggiungere timeout alla connessione socket
- [ ] Implementare caching locale per dati anime/manga frequenti
- [ ] Rimuovere dipendenze inutilizzate (`liquid_swipe`, libreria `http` duplicata)

#### 3.2 Ottimizzazione Performance Backend
```
Effort: 1-2 giorni
```
- [ ] Aggiungere LRU cache con dimensione massima a `CacheService`
- [ ] Ridurre frequenza salvataggio progress download (da 5% a 15-20%)
- [ ] Ottimizzare query commenti per evitare N+1 (lazy loading relazioni annidate)
- [ ] Aggiungere indici database per query frequenti

#### 3.3 Implementare Internazionalizzazione
```
Effort: 2-3 giorni
```
- [ ] Creare file ARB per italiano, inglese, giapponese
- [ ] Estrarre tutte le stringhe hardcoded
- [ ] Implementare `flutter_localizations` correttamente
- [ ] Aggiungere selector lingua nelle impostazioni

#### 3.4 Completare Features Non Finite
```
Effort: 2-3 giorni
```
- [ ] Implementare sistema notifiche push (TODO in `home_screen.dart`)
- [ ] Persistere "currently watching" su backend (TODO in `currently_watching_screen.dart`)
- [ ] Navigazione al player da libreria locale (TODO in `local_library_screen.dart`)
- [ ] Filtro per genere nella home manga (TODO in `manga_home_screen.dart`)
- [ ] Completare `consumet_repository.dart` (attualmente vuoto)

---

### FASE 4: Testing e Documentazione (Priorita MEDIA-ALTA)

#### 4.1 Test Backend
```
Effort: 3-5 giorni
```
- [ ] Test unitari per `AuthService` (register, login, JWT, Google OAuth)
- [ ] Test unitari per `DownloadService` (queue, progress, cleanup)
- [ ] Test unitari per `CommentsService` (CRUD, autorizzazione)
- [ ] Test unitari per `UsersService` (profilo, history, preferenze)
- [ ] Test e2e per i flussi principali (auth flow, download flow)
- [ ] Configurare coverage minima al 60%

#### 4.2 Test Mobile
```
Effort: 3-5 giorni
```
- [ ] Test unitari per `AnimeRepository` (logica episodi, scoring)
- [ ] Test unitari per `MangaRepository` (logica capitoli, scoring)
- [ ] Test per i provider Riverpod (auth, download, watch history)
- [ ] Widget test per schermate principali
- [ ] Test di integrazione per flussi critici

#### 4.3 CI/CD Pipeline
```
Effort: 1-2 giorni
```
- [ ] Configurare GitHub Actions per lint + test su ogni PR
- [ ] Build automatica Docker per il backend
- [ ] Build automatica APK/IPA per la mobile app
- [ ] Deploy automatico su staging

---

### FASE 5: Miglioramenti Avanzati (Priorita BASSA)

#### 5.1 API Versioning
- [ ] Aggiungere prefisso `/api/v1/` a tutti gli endpoint
- [ ] Documentare API con Swagger/OpenAPI (`@nestjs/swagger`)

#### 5.2 Monitoring e Observability
- [ ] Implementare health check endpoint
- [ ] Aggiungere metriche Prometheus
- [ ] Configurare alerting per errori critici

#### 5.3 Web App
- [ ] La web app (Next.js) e' attualmente una landing page vuota
- [ ] Implementare le funzionalita core (browse, search, player)
- [ ] Condividere tipi/interfacce con il backend

#### 5.4 Miglioramenti UX Mobile
- [ ] Implementare SSL pinning per sicurezza HTTPS
- [ ] Aggiungere offline mode con sincronizzazione
- [ ] Implementare deep linking completo
- [ ] Aggiungere animazioni di transizione tra schermate

---

## 6. ROADMAP PRIORITIZZATA

```
SPRINT 1 (Settimana 1-2): Sicurezza
├── Fase 1.1: Hardening sicurezza backend
├── Fase 1.2: Validazione input
└── Fase 1.3: Fix configurazione mobile

SPRINT 2 (Settimana 3-4): Qualita
├── Fase 2.1: Cleanup logging
├── Fase 2.2: Fix null safety
├── Fase 2.3: Fix database
└── Fase 2.4: Refactoring codice complesso

SPRINT 3 (Settimana 5-6): Performance
├── Fase 3.1: Ottimizzazione mobile
├── Fase 3.2: Ottimizzazione backend
└── Fase 3.4: Completare features

SPRINT 4 (Settimana 7-8): Testing
├── Fase 4.1: Test backend
├── Fase 4.2: Test mobile
└── Fase 4.3: CI/CD

SPRINT 5 (Settimana 9+): Avanzato
├── Fase 3.3: Internazionalizzazione
├── Fase 5.1: API versioning
├── Fase 5.2: Monitoring
└── Fase 5.3-5.4: Web app e UX
```

---

## STATISTICHE RIEPILOGO

| Categoria | Problemi Trovati | Critico | Alto | Medio | Basso |
|-----------|-----------------|---------|------|-------|-------|
| Sicurezza | 7 | 4 | 3 | - | - |
| Backend - DB/ORM | 6 | - | 2 | 3 | 1 |
| Backend - Validazione | 6 | - | 2 | 4 | - |
| Backend - File System | 4 | - | 2 | 1 | 1 |
| Backend - Logging | 5 | - | - | 3 | 2 |
| Backend - Testing | 1 | - | 1 | - | - |
| Mobile - Config | 4 | 1 | 1 | - | 2 |
| Mobile - Null Safety | 4 | - | 2 | 2 | - |
| Mobile - Performance | 4 | - | 2 | 2 | - |
| Mobile - Architettura | 6 | - | 2 | 2 | 2 |
| Mobile - Testing | 1 | - | 1 | - | - |
| Architetturali | 4 | - | - | 4 | - |
| **TOTALE** | **52** | **5** | **18** | **21** | **8** |

---

> **Nota:** Questo documento dovrebbe essere aggiornato man mano che i problemi vengono risolti.
> Spuntare le checkbox completate e aggiungere nuove problematiche se scoperte.
