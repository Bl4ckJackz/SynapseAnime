# OpenAnime - Nuove Implementazioni Proposte

> Queste funzionalita vanno oltre i fix dei bug e rappresentano miglioramenti significativi al progetto.

---

## 1. FUNZIONALITA DA IMPLEMENTARE (Priorita Alta)

### 1.1 Sistema di Notifiche Push Completo
**Stato attuale:** Firebase configurato ma non inizializzato nella mobile app, TODO in home_screen.dart
**Implementazione:**
- Inizializzare Firebase in `main.dart` con `Firebase.initializeApp()`
- Implementare `FirebaseMessaging.onMessage` per notifiche in-app
- Implementare `FirebaseMessaging.onBackgroundMessage` per notifiche background
- Creare widget di notifica in-app (snackbar/banner)
- Aggiungere badge counter sulla bottom nav bar
- Collegare con il backend scheduler per notifiche nuovi episodi

### 1.2 Offline Mode con Sincronizzazione
**Implementazione:**
- Usare `sqflite` o `isar` per cache locale di anime/manga metadata
- Sincronizzare watchlist e history quando torna online
- Mostrare indicatore di connessione nella UI
- Permettere browsing offline dei dati gia cachati
- Aggiungere queue di operazioni offline (es. aggiunta a watchlist)

### 1.3 Sistema di Ricerca Avanzata
**Stato attuale:** Ricerca base per titolo
**Implementazione:**
- Filtri multipli (genere, anno, stato, rating, tipo)
- Ricerca combinata anime + manga in una sola schermata
- Suggerimenti/autocompletamento durante la digitazione
- Cronologia ricerche recenti salvata localmente
- Ricerca vocale con `speech_to_text`

### 1.4 Player Video Migliorato
**Implementazione:**
- Picture-in-Picture (PiP) su Android/iOS
- Supporto casting (Chromecast/AirPlay) con `cast` package
- Selezione qualita video (720p, 1080p, etc.)
- Sottotitoli multipli con selezione lingua
- Skip intro/outro automatico (con timestamps dal backend)
- Gesture per volume/luminosita (swipe verticale)
- Doppio tap per avanzare/indietreggiare 10 secondi
- Mini-player persistente durante la navigazione

### 1.5 Sistema di Raccomandazioni Migliorato
**Stato attuale:** AI chat basico
**Implementazione:**
- Raccomandazioni "Because you watched X" sulla home
- Sezione "Trending questa settimana" basata su dati aggregati utenti
- Raccomandazioni per genere basate su history
- Collaborative filtering leggero (utenti simili)
- Carousel "Picks for you" personalizzato

---

## 2. FUNZIONALITA DA IMPLEMENTARE (Priorita Media)

### 2.1 Social Features
- **Profili pubblici:** pagina profilo con anime/manga preferiti
- **Attivita feed:** vedere cosa guardano gli amici
- **Liste condivise:** creare e condividere watchlist tematiche
- **Recensioni lunghe:** sistema di review con testo lungo + rating
- **Upvote/Downvote** sui commenti

### 2.2 Gestione Account Avanzata
- **Reset password** via email
- **Cambio email** con verifica
- **Eliminazione account** (GDPR compliance)
- **2FA** (Two-Factor Authentication)
- **Export dati** (watchlist, history in JSON/CSV)

### 2.3 Statistiche Utente
- Dashboard con:
  - Ore totali guardate
  - Anime/manga completati
  - Generi piu guardati (pie chart)
  - Streak di visione giornaliera
  - Progressione mensile
- Condivisione statistiche annuali (tipo Spotify Wrapped)

### 2.4 Widget e Quick Actions
- **Widget Android** per "Continue Watching"
- **Quick Actions iOS** (3D Touch) per accesso rapido
- **Dynamic Island** su iPhone 14+ per il player
- **Media notifications** con controlli di riproduzione

### 2.5 Modalita Lettura Manga Avanzata
- **Lettore verticale continuo** (webtoon-style)
- **Lettore doppia pagina** (stile tankobon)
- **Zoom pinch** con supporto gesture
- **Precaricamento pagine** successive
- **Filtro colore** (sepia, notturno, alto contrasto)
- **Bookmark pagine** specifiche

---

## 3. MIGLIORAMENTI INFRASTRUTTURALI

### 3.1 API Gateway e Documentazione
- Implementare Swagger/OpenAPI con `@nestjs/swagger`
- Aggiungere API versioning (`/api/v1/`)
- Health check endpoint (`/health`)
- Rate limiting granulare per endpoint

### 3.2 Monitoring e Logging
- Integrare Prometheus/Grafana per metriche
- Dashboard per monitorare:
  - Request/s per endpoint
  - Errori per tipo
  - Tempi di risposta p50/p95/p99
  - Utenti attivi
- Alerting per downtime e errori critici

### 3.3 CI/CD Pipeline
- GitHub Actions workflow:
  - Lint + type-check su ogni PR
  - Test automatici
  - Build Docker automatica
  - Deploy staging automatico
  - Build APK/AAB automatica
- Codeowners file per code review

### 3.4 Web App (Next.js)
**Stato attuale:** Landing page vuota
**Implementazione:**
- Browse anime/manga con la stessa API del mobile
- Player video web-based
- Autenticazione condivisa (JWT)
- Responsive design per desktop/tablet
- PWA con service worker per offline basico

---

## 4. ROADMAP SUGGERITA

```
Q1 2026 (Marzo-Maggio):
  - Notifiche push complete
  - Player video migliorato (PiP, gesture)
  - Ricerca avanzata con filtri
  - Swagger API docs
  - CI/CD pipeline

Q2 2026 (Giugno-Agosto):
  - Offline mode
  - Statistiche utente
  - Social features base (profili, liste condivise)
  - Web app MVP
  - Lettore manga avanzato

Q3 2026 (Settembre-Novembre):
  - Raccomandazioni AI avanzate
  - Widget e Quick Actions
  - Gestione account avanzata (2FA, GDPR)
  - Monitoring e alerting
  - Casting support

Q4 2026 (Dicembre-Febbraio):
  - Social features avanzate
  - Monetizzazione (Stripe attivazione)
  - Internazionalizzazione completa
  - Performance optimization
  - Beta pubblica
```
