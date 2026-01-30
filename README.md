# Anime AI Player

App mobile completa per Android/iOS con catalogo anime (mockato), player video, chat AI per raccomandazioni e notifiche push.

## 🏗️ Stack Tecnologico

| Componente | Tecnologia |
|------------|------------|
| **Mobile** | Flutter (Dart) + Riverpod + go_router |
| **Backend** | NestJS (TypeScript) + TypeORM |
| **Database** | PostgreSQL |
| **Push Notifications** | Firebase Cloud Messaging |

## 📁 Struttura Repository

```
player/
├── backend/          # NestJS API
├── mobile/           # Flutter app
└── docs/             # Documentazione
```

## 🚀 Quick Start

### Prerequisiti
- Node.js 18+
- Flutter SDK 3.x
- Docker (per PostgreSQL)
- Firebase project (per notifiche)

### Backend

```bash
cd backend
cp .env.example .env        # Configura variabili
docker-compose up -d        # Avvia PostgreSQL
npm install
npm run migration:run       # Applica migrations
npm run seed                # Popola dati demo
npm run start:dev           # Avvia server (http://localhost:3000)
```

### Mobile

```bash
cd mobile
cp .env.example .env        # Configura API URL
flutter pub get
flutter run                 # Avvia su device/emulatore
```

## 📖 API Endpoints

| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| POST | `/auth/register` | Registrazione utente |
| POST | `/auth/login` | Login utente |
| GET | `/anime` | Lista anime (filtri: genre, status, search) |
| GET | `/anime/:id` | Dettaglio anime |
| GET | `/anime/:id/episodes` | Lista episodi |
| POST | `/ai/recommend` | Chat AI recommendations |

## ⚠️ Nota Legale

Questo progetto utilizza **esclusivamente dati mockati/fittizi** per il catalogo anime.
Nessun scraping o integrazione con servizi di streaming reali.
L'architettura è predisposta per future integrazioni con fonti legali/licenziate.

## 📄 License

MIT
