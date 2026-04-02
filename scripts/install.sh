#!/usr/bin/env bash
#
# OpenAnime - Installazione completa come servizi systemd su Debian/Ubuntu LXC.
#
# Uso:
#   sudo bash install.sh                     # installazione completa
#   sudo bash install.sh --skip-deps         # salta pacchetti di sistema
#   sudo bash install.sh --uninstall         # rimuove servizi
#   DB_PASSWORD=xxx JWT_SECRET=yyy sudo -E bash install.sh
#
set -euo pipefail

# ─── Configurazione ─────────────────────────────────────────────────────────
INSTALL_DIR="/opt/openanime"
DB_PASSWORD="${DB_PASSWORD:-openanime_2026}"
JWT_SECRET="${JWT_SECRET:-openanime-jwt-secret-change-me-in-production}"
SERVICE_USER="openanime"
LOG_DIR="/var/log/openanime"
NODE_MAJOR=20
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SKIP_DEPS=false
UNINSTALL=false

for arg in "$@"; do
    case $arg in
        --skip-deps)  SKIP_DEPS=true ;;
        --uninstall)  UNINSTALL=true ;;
    esac
done

# ─── Output ─────────────────────────────────────────────────────────────────
step()  { echo -e "\n\033[36m[*] $1\033[0m"; }
ok()    { echo -e "    \033[32mOK: $1\033[0m"; }
warn()  { echo -e "    \033[33mWARN: $1\033[0m"; }
err()   { echo -e "    \033[31mERROR: $1\033[0m"; exit 1; }

# ─── Root check ─────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || err "Eseguire come root: sudo bash install.sh"

SERVICES=("openanime-backend" "openanime-consumet" "openanime-mangahook")

# ─── Uninstall ───────────────────────────────────────────────────────────────
if $UNINSTALL; then
    step "Disinstallazione servizi OpenAnime..."
    for svc in "${SERVICES[@]}"; do
        if systemctl list-unit-files "$svc.service" &>/dev/null; then
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
            rm -f "/etc/systemd/system/$svc.service"
            ok "Rimosso $svc"
        else
            warn "$svc non trovato"
        fi
    done
    rm -f /etc/logrotate.d/openanime
    systemctl daemon-reload
    echo ""
    echo "Servizi rimossi. PostgreSQL e Redis NON sono stati toccati."
    echo "Per rimuovere i file:     rm -rf $INSTALL_DIR $LOG_DIR"
    echo "Per rimuovere l'utente:   userdel -r $SERVICE_USER"
    echo "Per rimuovere i pacchetti: apt purge postgresql redis-server -y"
    exit 0
fi

# ─── Detect ambiente ────────────────────────────────────────────────────────
IS_LXC=false
if grep -qa 'container=lxc' /proc/1/environ 2>/dev/null || \
   [ -f /run/container_type ] || \
   systemd-detect-virt -c &>/dev/null; then
    IS_LXC=true
fi

# ─── Dipendenze di sistema ──────────────────────────────────────────────────
if ! $SKIP_DEPS; then
    step "Installazione pacchetti di sistema..."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq \
        curl gnupg ca-certificates \
        postgresql postgresql-contrib \
        redis-server \
        build-essential python3 \
        rsync logrotate

    # Node.js via NodeSource (se mancante o troppo vecchio)
    NEED_NODE=false
    if ! command -v node &>/dev/null; then
        NEED_NODE=true
    else
        CURRENT_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
        [ "$CURRENT_MAJOR" -lt "$NODE_MAJOR" ] && NEED_NODE=true
    fi

    if $NEED_NODE; then
        step "Installazione Node.js $NODE_MAJOR via NodeSource..."
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
        apt-get install -y -qq nodejs
    fi
    ok "Node.js $(node -v)"

    # Aggiorna npm se troppo vecchio (Debian spesso ha npm 9.x)
    NPM_MAJOR=$(npm -v | cut -d. -f1)
    if [ "$NPM_MAJOR" -lt 10 ]; then
        echo "    Aggiornamento npm..."
        npm install -g npm@latest 2>&1 | tail -1
        hash -r
        ok "npm $(npm -v)"
    fi

    # Avvia servizi infrastruttura
    systemctl enable --now postgresql 2>/dev/null || true
    systemctl enable --now redis-server 2>/dev/null || true
    ok "PostgreSQL e Redis attivi"
fi

# Verifica finale Node.js
command -v node &>/dev/null || err "Node.js non trovato. Installa Node.js >= $NODE_MAJOR"
CURRENT_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
[ "$CURRENT_MAJOR" -ge "$NODE_MAJOR" ] || err "Richiesto Node.js >= $NODE_MAJOR, trovato $(node -v)"

# ─── Utente di sistema ──────────────────────────────────────────────────────
step "Configurazione utente di sistema..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" --create-home "$SERVICE_USER"
    ok "Utente '$SERVICE_USER' creato"
else
    ok "Utente '$SERVICE_USER' esiste"
fi

# ─── Database ────────────────────────────────────────────────────────────────
step "Configurazione database PostgreSQL..."

# Attendi che PostgreSQL sia pronto
for i in $(seq 1 10); do
    su - postgres -c "pg_isready" &>/dev/null && break
    sleep 1
done

su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='$SERVICE_USER'\"" | grep -q 1 || {
    su - postgres -c "psql -c \"CREATE ROLE $SERVICE_USER WITH LOGIN PASSWORD '$DB_PASSWORD';\""
    ok "Ruolo DB '$SERVICE_USER' creato"
}

su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname='anime_player'\"" | grep -q 1 || {
    su - postgres -c "psql -c \"CREATE DATABASE anime_player OWNER $SERVICE_USER;\""
    ok "Database 'anime_player' creato"
}
ok "Database pronto"

# ─── Copia sorgenti ─────────────────────────────────────────────────────────
step "Copia sorgenti in $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"

# Preserva .env se esiste gia' (aggiornamento)
PRESERVE_ENV=false
[ -f "$INSTALL_DIR/backend/.env" ] && PRESERVE_ENV=true

rsync -a --delete \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='mobile' \
    --exclude='temp_*' \
    --exclude='*.db' \
    --exclude='scripts/' \
    "$PROJECT_ROOT/" "$INSTALL_DIR/"
ok "Sorgenti copiati"

# ─── File .env ───────────────────────────────────────────────────────────────
if ! $PRESERVE_ENV; then
    step "Generazione backend/.env..."
    cat > "$INSTALL_DIR/backend/.env" <<ENVEOF
# OpenAnime - Configurazione Produzione
# Generato da install.sh il $(date '+%Y-%m-%d %H:%M')

# Database (PostgreSQL)
DB_TYPE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=$SERVICE_USER
DB_PASSWORD=$DB_PASSWORD
DB_DATABASE=anime_player

# JWT
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

# App
PORT=3005
NODE_ENV=production

# Servizi interni
CONSUMET_API_URL=http://127.0.0.1:3004
CONSUMET_PROVIDER=animeunity
MANGAHOOK_API_URL=http://127.0.0.1:5000/api

# Jikan (MyAnimeList)
JIKAN_API_URL=https://api.jikan.moe/v4
JIKAN_CACHE_TTL=86400

# MangaDex
MANGADEX_API_URL=https://api.mangadex.org
MANGADEX_CACHE_TTL=21600

# Firebase (compilare manualmente se necessario)
# FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
# FIREBASE_PROJECT_ID=
# FIREBASE_PRIVATE_KEY=
# FIREBASE_CLIENT_EMAIL=
# FIREBASE_DATABASE_URL=

# Stripe (opzionale)
# STRIPE_SECRET_KEY=
# STRIPE_PREMIUM_PRICE_ID=
# STRIPE_WEBHOOK_SECRET=

# TMDB (opzionale, per movies/TV)
# TMDB_API_KEY=

# AI (opzionale)
# PERPLEXITY_API_KEY=

# Google OAuth (opzionale)
# GOOGLE_CLIENT_ID=
ENVEOF
    ok ".env backend creato"
else
    warn ".env backend esistente preservato (aggiornamento)"
fi

# .env MangaHook
cat > "$INSTALL_DIR/mangahook-api/server/.env" <<'MHEOF'
PORT=5000
NODE_ENV=production
MHEOF
ok ".env mangahook creato"

# ─── npm install + build ────────────────────────────────────────────────────
step "Installazione dipendenze npm..."

# Helper: usa npm ci se c'e' il lockfile, altrimenti npm install
# Mostra output completo in caso di errore
npm_safe_install() {
    local flags="$*"
    local logfile="/tmp/npm_install_$$.log"
    local cmd="install"
    [ -f "package-lock.json" ] && cmd="ci"

    if npm $cmd $flags 2>&1 | tee "$logfile" | tail -5; then
        rm -f "$logfile"
        return 0
    else
        echo ""
        err "npm $cmd fallito in $(pwd). Log completo:"
        cat "$logfile"
        rm -f "$logfile"
        exit 1
    fi
}

# Pulisci cache npm e node_modules vecchi per install pulita
npm cache clean --force 2>/dev/null || true
rm -rf "$INSTALL_DIR/consumet-api/node_modules"

# Consumet ha bisogno di ts-node (devDep), e non ha package-lock.json
cd "$INSTALL_DIR/consumet-api"
echo "    npm install in consumet-api..."
npm_safe_install --no-audit --no-fund

# MangaHook (solo production deps)
cd "$INSTALL_DIR/mangahook-api/server"
rm -rf node_modules
echo "    npm install in mangahook-api..."
npm_safe_install --omit=dev --no-audit --no-fund

# Backend: install completo (serve nest cli per build), poi build, poi prune
cd "$INSTALL_DIR/backend"
rm -rf node_modules dist
echo "    npm install in backend..."
npm_safe_install --no-audit --no-fund

step "Build backend NestJS..."
if ! npx nest build; then
    err "Build backend fallito!"
fi
ok "Backend compilato (dist/)"

# Rimuovi devDependencies dal backend dopo il build per risparmiare spazio
npm prune --omit=dev --no-audit --no-fund 2>&1 | tail -1
ok "devDependencies rimossi dal backend"

# ─── Permessi ────────────────────────────────────────────────────────────────
step "Impostazione permessi..."
mkdir -p "$LOG_DIR"
mkdir -p "$INSTALL_DIR/backend/video_library"
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
chmod 600 "$INSTALL_DIR/backend/.env"
chmod 600 "$INSTALL_DIR/mangahook-api/server/.env"
ok "Permessi impostati"

# ─── Logrotate ──────────────────────────────────────────────────────────────
step "Configurazione logrotate..."
cat > /etc/logrotate.d/openanime <<'LREOF'
/var/log/openanime/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su openanime openanime
}
LREOF
ok "Logrotate configurato (14 giorni, compressione)"

# ─── Creazione unit systemd ─────────────────────────────────────────────────
step "Creazione servizi systemd..."

NODE_BIN=$(command -v node)
NPX_BIN=$(command -v npx)

# --- openanime-backend ---
cat > /etc/systemd/system/openanime-backend.service <<EOF
[Unit]
Description=OpenAnime Backend API (NestJS)
Documentation=https://github.com/Bl4ckJackz/SynapseAnime
After=network.target postgresql.service redis-server.service
Requires=postgresql.service
Wants=redis-server.service openanime-consumet.service openanime-mangahook.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/backend
ExecStart=$NODE_BIN dist/src/main.js
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5

EnvironmentFile=$INSTALL_DIR/backend/.env

StandardOutput=append:$LOG_DIR/backend.log
StandardError=append:$LOG_DIR/backend.error.log

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/backend/video_library $LOG_DIR
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

# --- openanime-consumet ---
cat > /etc/systemd/system/openanime-consumet.service <<EOF
[Unit]
Description=OpenAnime Consumet API (Anime Provider)
Documentation=https://github.com/Bl4ckJackz/SynapseAnime
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/consumet-api
ExecStart=$NPX_BIN ts-node src/main.ts
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5

Environment=NODE_ENV=production
Environment=PORT=3004

StandardOutput=append:$LOG_DIR/consumet.log
StandardError=append:$LOG_DIR/consumet.error.log

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

# --- openanime-mangahook ---
cat > /etc/systemd/system/openanime-mangahook.service <<EOF
[Unit]
Description=OpenAnime MangaHook API (Manga Provider)
Documentation=https://github.com/Bl4ckJackz/SynapseAnime
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/mangahook-api/server
ExecStart=$NODE_BIN app.js
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5

EnvironmentFile=$INSTALL_DIR/mangahook-api/server/.env

StandardOutput=append:$LOG_DIR/mangahook.log
StandardError=append:$LOG_DIR/mangahook.error.log

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
ok "Unit systemd create"

# ─── Abilita e avvia ────────────────────────────────────────────────────────
step "Avvio servizi..."

for svc in "${SERVICES[@]}"; do
    systemctl enable "$svc" --quiet
    systemctl start "$svc"
    ok "$svc abilitato e avviato"
    sleep 2
done

# ─── Verifica ────────────────────────────────────────────────────────────────
step "Verifica stato servizi (attesa 8s)..."
sleep 8

ALL_OK=true
echo ""
printf "    %-30s %-10s %s\n" "SERVIZIO" "STATO" "PORTA"
printf "    %-30s %-10s %s\n" "--------" "-----" "-----"

PORTS=("3005" "3004" "5000")
for i in "${!SERVICES[@]}"; do
    svc="${SERVICES[$i]}"
    port="${PORTS[$i]}"
    if systemctl is-active --quiet "$svc"; then
        printf "    \033[32m%-30s %-10s :%s\033[0m\n" "$svc" "active" "$port"
    else
        printf "    \033[31m%-30s %-10s :%s\033[0m\n" "$svc" "FAILED" "$port"
        ALL_OK=false
    fi
done

# ─── Riepilogo ───────────────────────────────────────────────────────────────
echo ""
echo "================================================================"
echo "  OpenAnime - Installazione completata!"
echo "================================================================"
echo ""
echo "  Directory:     $INSTALL_DIR"
echo "  Logs:          $LOG_DIR"
echo "  Config:        $INSTALL_DIR/backend/.env"
echo "  DB:            anime_player (PostgreSQL, user: $SERVICE_USER)"
echo ""
echo "  Endpoint:"
echo "    Backend:     http://<IP>:3005"
echo "    Consumet:    http://127.0.0.1:3004  (interno)"
echo "    MangaHook:   http://127.0.0.1:5000  (interno)"
echo ""
echo "  Gestione:"
echo "    systemctl {start|stop|restart|status} openanime-backend"
echo "    systemctl {start|stop|restart|status} openanime-consumet"
echo "    systemctl {start|stop|restart|status} openanime-mangahook"
echo "    journalctl -u openanime-backend -f"
echo "    tail -f $LOG_DIR/backend.log"
echo ""
echo "  Aggiornamento:"
echo "    1. git pull nella repo sorgente"
echo "    2. sudo bash install.sh    (preserva .env esistente)"
echo ""
echo "  Disinstallazione:"
echo "    sudo bash install.sh --uninstall"
echo ""

if ! $ALL_OK; then
    warn "Alcuni servizi non sono partiti. Controlla:"
    warn "  journalctl -u openanime-backend -n 50 --no-pager"
fi
