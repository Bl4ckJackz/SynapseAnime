# SynapseAnime

> **La tua fonte illimitata di Anime.**
> Un'applicazione moderna e completa per lo streaming di anime, costruita con tecnologie all'avanguardia.

## Panoramica

**SynapseAnime** è una soluzione full-stack per la fruizione di contenuti anime. Il progetto è composto da:
- **Mobile App**: Un'applicazione Flutter fluida e reattiva per Android e iOS.
- **Web App**: Una moderna applicazione web in Next.js.
- **Backend**: API robusta in NestJS per la gestione utenti, progressi e metadati.
- **Consumet API**: Un wrapper personalizzato per l'aggregazione di fonti streaming.
- **MangaHook API**: Microservizio per fonti manga.

## Stack Tecnologico

| Area | Tecnologie Chiave |
|------|-------------------|
| **Frontend Mobile** | Flutter, Dart, Riverpod, GoRouter |
| **Frontend Web** | Next.js, React, Tailwind CSS |
| **Backend API** | NestJS, TypeScript, TypeORM |
| **Database** | PostgreSQL (Prod), SQLite (Local), Redis (Cache) |
| **Integrazioni** | Firebase (Notifiche), AnimeUnity/HiAnime (Sources), Jikan, MangaDex |
| **Deploy** | Systemd services su LXC Debian/Ubuntu |

## Installazione (LXC Debian/Ubuntu)

### Requisiti
- Container LXC Debian 12+ o Ubuntu 22.04+
- Accesso root

### Setup completo

```bash
git clone https://github.com/Bl4ckJackz/SynapseAnime.git
cd SynapseAnime
sudo bash scripts/install.sh
```

Lo script installa automaticamente tutte le dipendenze (PostgreSQL, Redis, Node.js 20), builda il progetto e registra 3 servizi systemd:

| Servizio | Porta | Descrizione |
|----------|-------|-------------|
| `openanime-backend` | 3005 | API principale (NestJS) |
| `openanime-consumet` | 3004 | Provider anime |
| `openanime-mangahook` | 5000 | Provider manga |

### Parametri opzionali

```bash
# Password e secret personalizzati
DB_PASSWORD="mypassword" JWT_SECRET="mysecret" sudo -E bash scripts/install.sh

# Salta installazione pacchetti di sistema (gia' presenti)
sudo bash scripts/install.sh --skip-deps
```

### Gestione servizi

```bash
# Stato
systemctl status openanime-backend

# Riavvia
sudo systemctl restart openanime-backend

# Log in tempo reale
journalctl -u openanime-backend -f

# Tutti i servizi
sudo systemctl restart openanime-{backend,consumet,mangahook}
```

### Aggiornamento

```bash
cd SynapseAnime
git pull origin main
sudo bash scripts/install.sh    # preserva .env esistente
```

### Disinstallazione

```bash
sudo bash scripts/install.sh --uninstall
```

## Sviluppo locale

```bash
# Installa dipendenze
npm install

# Avvia tutti i servizi in dev
npm run dev
# Backend: http://localhost:3005 | Consumet: http://localhost:3000 | Web: http://localhost:3000
```

Copia `backend/.env.example` in `backend/.env` per lo sviluppo locale (usa SQLite di default, nessun DB esterno necessario).

## Struttura della Repository

```
/
├── backend/          # Server API NestJS
├── mobile/           # Applicazione Flutter
├── web/              # Applicazione Next.js
├── consumet-api/     # Microservizio anime provider
├── mangahook-api/    # Microservizio manga provider
└── scripts/          # Script di installazione e deploy
```

## Configurazione opzionale

Dopo l'installazione, modifica `/opt/openanime/backend/.env` per abilitare:

| Variabile | Scopo |
|-----------|-------|
| `FIREBASE_*` | Push notifications |
| `STRIPE_*` | Pagamenti premium |
| `TMDB_API_KEY` | Catalogo movies/TV |
| `PERPLEXITY_API_KEY` | AI recommendations |
| `GOOGLE_CLIENT_ID` | Login Google OAuth |

---
*SynapseAnime Project © 2026*
