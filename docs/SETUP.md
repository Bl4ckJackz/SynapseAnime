# 📖 Guida all'Installazione

## Prerequisiti

Assicurati di avere installato:
- **Node.js** (v18 o superiore)
- **Flutter SDK** (Ultima versione stabile)
- **Docker** (Per il database PostgreSQL)
- **Git**

---

## 🖥️ Backend (NestJS)

Il backend gestisce l'autenticazione, il database e la logica di business.

### 1. Configurazione Iniziale
Naviga nella cartella `backend`:
```bash
cd backend
npm install
```

### 2. Variabili d'Ambiente
Copia il file di esempio e configura le variabili necessarie:
```bash
cp .env.example .env
```
Modifica `.env` con i parametri del tuo database locale (se diversi dai default).

### 3. Avvio Database
Usa Docker per avviare un'istanza PostgreSQL rapida:
```bash
docker-compose up -d
```

### 4. Avvio Server
```bash
# Modalità sviluppo (con hot-reload)
npm run start:dev
```
Il server sarà attivo su `http://localhost:3005`.

---

## 📱 Mobile App (Flutter)

### 1. Configurazione
Naviga nella cartella `mobile`:
```bash
cd mobile
flutter pub get
```

### 2. Variabili d'Ambiente
Crea il file `.env` nella root di `mobile` (se richiesto dalla configurazione del progetto):
```text
API_URL=http://<IL_TUO_IP_LOCALE>:3005
```
*Nota: Se usi un emulatore Android, usa `10.0.2.2` invece di `localhost`. La porta del backend è `3005`.*

### 3. Avvio App
Collega un dispositivo o avvia un emulatore:
```bash
flutter run
```

---

## 🕷️ Consumet API (Wrapper)

Questo servizio funge da proxy per le fonti anime. Gira sulla porta **3004**.

1. Naviga in `consumet-api`:
   ```bash
   cd consumet-api
   npm install
   ```
2. Avvia il servizio:
   ```bash
   npm run start
   ```
Il servizio sarà attivo su `http://localhost:3004`.

---

## 🌐 Web App (Next.js)

1. Naviga in `web`:
   ```bash
   cd web
   npm install
   ```
2. Avvia il server di sviluppo:
   ```bash
   npm run dev
   ```
Il server sarà attivo su `http://localhost:3000`.

---

## Porte dei servizi

| Servizio | Porta |
|----------|-------|
| Web App (Next.js) | 3000 |
| Consumet API | 3004 |
| Backend (NestJS) | 3005 |
| MangaHook API | 5000 |

---

## Avvio rapido (tutti i servizi)

Dalla root del progetto:
```bash
npm install    # installa tutte le dipendenze (root + sub-projects)
npm run dev    # avvia backend, consumet e web in parallelo
```
