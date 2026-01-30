# 🏗️ Architettura del Progetto

OpenAnime segue un'architettura **Client-Server** moderna, separando chiaramente la logica di presentazione (Mobile) dalla logica di business (Backend) e dall'aggregazione dati (Consumet).

## 🧩 Componenti Principali

### 1. Mobile App (Frontend)
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod. Gestisce lo stato globale in modo reattivo e sicuro.
- **Routing**: GoRouter per una gestione profonda della navigazione e deep linking.
- **Vantaggi**: Codice unico per Android e iOS, UI fluida a 60/120fps.

### 2. Backend API
- **Framework**: NestJS (Node.js/TypeScript).
- **Struttura**: Modulare (Controller, Service, Module).
- **Database**: PostgreSQL con TypeORM.
- **Ruolo**:
  - Gestione Utenti (Auth JWT).
  - Gestione Watch History (sincronizzazione progressi).
  - Proxy verso Consumet per metadati (titoli, immagini).

### 3. Consumet API (Data Source)
- **Ruolo**: Abstrae le differenze tra i vari siti di anime (AnimeUnity, AnimeSaturn, ecc.).
- **Funzionamento**: Espone endpoint unificati che fanno scraping o chiamate API verso i fornitori originali.

## 🔄 Flusso dei Dati

1. **Ricerca Anime**:
   `Mobile` -> `Backend` -> `Consumet` -> `Source (es. AnimeWorld)`
   *Il Backend fa da cache o arricchisce i dati prima di rispondere al mobile.*

2. **Streaming Video**:
   Il Mobile ottiene l'URL del flusso video tramite le API e lo riproduce nativamente (ExoPlayer/AVPlayer).

3. **Autenticazione**:
   JWT Tokens scambiati tra Mobile e Backend per sessioni sicure.

## 📂 Struttura Cartelle (Convenzioni)

### Backend
- `src/modules/`: Moduli funzionali (es. `auth`, `anime`, `user`).
- `src/common/`: Utility condivise, guardie, intercettori.

### Mobile
- `lib/data/`: Repository e sorgenti dati (API client).
- `lib/domain/`: Modelli e logica di business pura.
- `lib/presentation/`: Widget, Schermate e State Notifiers.
