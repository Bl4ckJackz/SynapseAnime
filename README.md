# 🎬 OpenAnime

> **La tua fonte illimitata di Anime.**
> Un'applicazione moderna e completa per lo streaming di anime, costruita con tecnologie all'avanguardia.

![Anime Banner](https://via.placeholder.com/1200x300?text=OpenAnime+Project)

## 🌟 Panoramica

**OpenAnime** è una soluzione full-stack per la fruizione di contenuti anime. Il progetto è composto da:
- **Mobile App**: Un'applicazione Flutter fluida e reattiva per Android e iOS.
- **Web App**: Una moderna applicazione web in Next.js.
- **Backend**: API robusta in NestJS per la gestione utenti, progressi e metadati.
- **Consumet API**: Un wrapper personalizzato per l'aggregazione di fonti streaming.

## 🛠️ Stack Tecnologico

| Area | Tecnologie Chiave |
|------|-------------------|
| **Frontend Mobile** | [Flutter](https://flutter.dev), Dart, Riverpod (State Management), GoRouter |
| **Frontend Web** | [Next.js](https://nextjs.org), React, Tailwind CSS |
| **Backend API** | [NestJS](https://nestjs.com), TypeScript, TypeORM |
| **Database** | PostgreSQL (Prod), SQLite (Local), Redis (Cache) |
| **Integrazioni** | Firebase (Notifiche/Sync), AnimeUnity/AnimeWorld (Sources) |
| **DevOps** | Docker, Docker Compose |

## 🚀 Per Iniziare

### Installazione Rapida
Dalla root del progetto:
```bash
# Installa tutte le dipendenze (Backend, Web, Consumet)
npm install
```

### Avvio in Sviluppo (Locale)
Avvia Backend, Consumet API e Web App contemporaneamente:
```bash
npm run dev
```
- Web App: http://localhost:3001
- Backend: http://localhost:3010
- Consumet: http://localhost:3000

### 🐳 Deployment con Docker
Per avviare l'intero stack in container (incluso Postgres e Redis):

```bash
docker-compose up --build -d
```
Questo avvierà:
- Postgres (Database SQL)
- Redis (Cache)
- Backend (NestJS)
- Consumet API
- (Web App: da aggiungere al compose se necessario, di solito deployata su Vercel/Netlify)

## 📂 Struttura della Repository

```
/
├── backend/        # Server API NestJS (Logica di business, DB)
├── mobile/         # Applicazione Flutter (UI, Mobile)
├── web/            # Applicazione Next.js (UI, Web)
├── consumet-api/   # Microservizio per scraping
└── docker-compose.yml # Orchestrazione container
```

## 🤝 Contribuire

Il progetto è attualmente privato. Per modifiche e suggerimenti, contattare il team di sviluppo.

---
*OpenAnime Project © 2026*
