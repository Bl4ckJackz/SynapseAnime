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
Il server sarà attivo su `http://localhost:3000`.

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
API_URL=http://<IL_TUO_IP_LOCALE>:3000
```
*Nota: Se usi un emulatore Android, usa `10.0.2.2` invece di `localhost`.*

### 3. Avvio App
Collega un dispositivo o avvia un emulatore:
```bash
flutter run
```

---

## 🕷️ Consumet API (Wrapper)

Questo servizio funge da proxy per le fonti anime.

1. Naviga in `consumet-api`:
   ```bash
   cd consumet-api
   npm install
   ```
2. Avvia il servizio:
   ```bash
   npm run start
   ```
