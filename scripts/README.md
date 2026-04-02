# OpenAnime - Installazione come System Service

Script per installare OpenAnime come servizi systemd su container **LXC Debian/Ubuntu**, senza Docker.

## Cosa viene installato

| Componente | Porta | Servizio systemd |
|------------|-------|-------------------|
| PostgreSQL | 5432 | `postgresql` |
| Redis | 6379 | `redis-server` |
| Backend (NestJS) | 3005 | `openanime-backend` |
| Consumet API | 3004 | `openanime-consumet` |
| MangaHook API | 5000 | `openanime-mangahook` |

## Installazione

```bash
# Clona la repo nel container LXC
git clone https://github.com/Bl4ckJackz/SynapseAnime.git
cd SynapseAnime

# Installazione completa (come root)
sudo bash scripts/install.sh
```

### Parametri opzionali

```bash
# Password e secret personalizzati
DB_PASSWORD="mypassword" JWT_SECRET="mysecret" sudo -E bash scripts/install.sh

# Salta installazione pacchetti (PostgreSQL, Redis, Node.js gia' presenti)
sudo bash scripts/install.sh --skip-deps
```

Lo script:
1. Installa PostgreSQL, Redis, Node.js 20 (via NodeSource) e build tools
2. Crea utente di sistema `openanime` (nologin)
3. Crea database `anime_player` e ruolo PostgreSQL
4. Copia sorgenti in `/opt/openanime/`
5. Genera `/opt/openanime/backend/.env` con URL localhost
6. Installa dipendenze npm e builda il backend NestJS
7. Registra 3 servizi systemd con hardening e auto-restart
8. Configura logrotate (14 giorni, compressione)

## Gestione servizi

```bash
# Stato
systemctl status openanime-backend
systemctl status openanime-consumet
systemctl status openanime-mangahook

# Avvia / ferma / riavvia
sudo systemctl restart openanime-backend

# Log in tempo reale
journalctl -u openanime-backend -f

# Log file
tail -f /var/log/openanime/backend.log

# Log tutti i servizi
journalctl -u 'openanime-*' --since "1 hour ago"
```

## Aggiornamento

```bash
cd /path/to/SynapseAnime
git pull origin main
sudo bash scripts/install.sh    # preserva .env esistente
```

## Disinstallazione

```bash
sudo bash scripts/install.sh --uninstall

# Rimuovere anche i dati:
sudo rm -rf /opt/openanime /var/log/openanime
sudo userdel -r openanime
sudo apt purge postgresql redis-server -y
```

## Struttura post-installazione

```
/opt/openanime/
  backend/
    dist/              # build NestJS compilato
    .env               # configurazione (chmod 600)
    video_library/     # download video
  consumet-api/        # anime provider (ts-node)
  mangahook-api/
    server/            # manga provider (node)
      .env

/var/log/openanime/
  backend.log          # stdout backend
  backend.error.log    # stderr backend
  consumet.log
  mangahook.log
```

## Configurazione post-installazione

Modifica `/opt/openanime/backend/.env` per aggiungere le chiavi API opzionali:

| Variabile | Scopo |
|-----------|-------|
| `FIREBASE_*` | Push notifications |
| `STRIPE_*` | Pagamenti premium |
| `TMDB_API_KEY` | Catalogo movies/TV |
| `PERPLEXITY_API_KEY` | AI recommendations |
| `GOOGLE_CLIENT_ID` | Login Google OAuth |

Dopo la modifica:
```bash
sudo systemctl restart openanime-backend
```

## Note LXC

- I servizi systemd includono hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`)
- Alcune direttive di hardening (`ProtectKernelTunables`, `ProtectControlGroups`) potrebbero non funzionare in container non privilegiati: systemd le ignora automaticamente
- Il backend ascolta su `0.0.0.0:3005`, i servizi interni (Consumet, MangaHook) su `127.0.0.1`
- Per esporre il backend fuori dal container, configurare il port forwarding nell'host LXC o un reverse proxy (nginx/caddy)
