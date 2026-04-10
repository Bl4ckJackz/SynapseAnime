#!/usr/bin/env bash
#
# SynapseAnime — Deploy & Management Script
#
# Interactive TUI for install, update, status, logs, backup, and uninstall.
# Requires: Debian 12+ / Ubuntu 22.04+, root access.
#
# Usage:
#   sudo bash install.sh              # Interactive TUI menu
#   sudo bash install.sh install      # Non-interactive full install
#   sudo bash install.sh update       # Smart update (only changed components)
#   sudo bash install.sh status       # Show service status dashboard
#   sudo bash install.sh logs [svc]   # Tail logs for a service
#   sudo bash install.sh backup       # Backup current installation
#   sudo bash install.sh rollback     # Restore last backup
#   sudo bash install.sh uninstall    # Remove all services
#
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
INSTALL_DIR="/opt/openanime"
BACKUP_DIR="/opt/openanime-backups"
DB_PASSWORD="${DB_PASSWORD:-openanime_2026}"
JWT_SECRET="${JWT_SECRET:-openanime-jwt-secret-change-me-in-production}"
SERVICE_USER="openanime"
LOG_DIR="/var/log/openanime"
NODE_MAJOR=20
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$INSTALL_DIR/.synapse-version"

declare -A SVC_PORTS=(
    [openanime-web]=3000
    [openanime-backend]=3005
    [openanime-consumet]=3004
    [openanime-mangahook]=5000
)
SERVICES=("openanime-web" "openanime-backend" "openanime-consumet" "openanime-mangahook")
SVC_LABELS=("Web Frontend" "Backend API" "Consumet API" "MangaHook API")

# ═══════════════════════════════════════════════════════════════════════════════
# Output helpers
# ═══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

step()    { echo -e "\n${CYAN}${BOLD}▸ $1${RESET}"; }
ok()      { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail()    { echo -e "  ${RED}✗${RESET} $1"; }
die()     { echo -e "\n${RED}${BOLD}Error:${RESET} $1" >&2; exit 1; }
spinner() {
    local pid=$1 msg=$2
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#chars}; i++ )); do
            printf "\r  ${CYAN}%s${RESET} %s" "${chars:$i:1}" "$msg"
            sleep 0.1
        done
    done
    printf "\r"
}

# ═══════════════════════════════════════════════════════════════════════════════
# TUI helpers (whiptail)
# ═══════════════════════════════════════════════════════════════════════════════
HAS_WHIPTAIL=false
command -v whiptail &>/dev/null && HAS_WHIPTAIL=true

tui_menu() {
    if ! $HAS_WHIPTAIL; then
        echo ""
        echo -e "${BOLD}SynapseAnime — Deploy Manager${RESET}"
        echo ""
        echo "  1) Install       Fresh installation"
        echo "  2) Update        Smart update (only changes)"
        echo "  3) Status        Service dashboard"
        echo "  4) Logs          View service logs"
        echo "  5) Backup        Backup current install"
        echo "  6) Rollback      Restore last backup"
        echo "  7) Restart       Restart services"
        echo "  8) Uninstall     Remove everything"
        echo "  9) Exit"
        echo ""
        read -rp "  Select [1-9]: " choice
        case $choice in
            1) do_install ;;
            2) do_update ;;
            3) do_status ;;
            4) do_logs_menu ;;
            5) do_backup ;;
            6) do_rollback ;;
            7) do_restart_menu ;;
            8) do_uninstall ;;
            9) exit 0 ;;
            *) warn "Invalid choice"; tui_menu ;;
        esac
        return
    fi

    local is_installed=false
    [ -d "$INSTALL_DIR/backend" ] && is_installed=true

    local menu_items=()
    if $is_installed; then
        menu_items+=(
            "update"    "  Smart Update — rebuild only changed components"
            "status"    "  Service Dashboard — health & resource usage"
            "logs"      "  View Logs — tail service output"
            "restart"   "  Restart Services — selective or all"
            "backup"    "  Backup — snapshot current installation"
            "rollback"  "  Rollback — restore previous backup"
            "install"   "  Reinstall — full clean install"
            "uninstall" "  Uninstall — remove all services & data"
        )
    else
        menu_items+=(
            "install"   "  Install — full fresh installation"
        )
    fi

    local choice
    choice=$(whiptail --title "SynapseAnime — Deploy Manager" \
        --menu "\nSelect an action:" 20 65 ${#menu_items[@]} \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3) || exit 0

    case $choice in
        install)   do_install ;;
        update)    do_update ;;
        status)    do_status; read -rp "Press Enter to continue..."; tui_menu ;;
        logs)      do_logs_menu ;;
        restart)   do_restart_menu ;;
        backup)    do_backup; read -rp "Press Enter to continue..."; tui_menu ;;
        rollback)  do_rollback ;;
        uninstall) do_uninstall ;;
    esac
}

tui_confirm() {
    local msg="$1"
    if $HAS_WHIPTAIL; then
        whiptail --yesno "$msg" 10 60 3>&1 1>&2 2>&3
    else
        read -rp "  $msg [y/N]: " yn
        [[ "$yn" =~ ^[Yy] ]]
    fi
}

tui_checklist() {
    local title="$1"; shift
    if $HAS_WHIPTAIL; then
        whiptail --title "$title" --checklist "\nSelect services:" 15 60 4 "$@" \
            3>&1 1>&2 2>&3
    else
        # Fallback: return all
        local result=""
        while [ $# -gt 0 ]; do result+="$1 "; shift 3; done
        echo "$result"
    fi
}

tui_progress() {
    local msg="$1" pct="$2"
    if $HAS_WHIPTAIL; then
        echo "$pct"
    else
        printf "\r  [%-20s] %3d%% %s" "$(printf '#%.0s' $(seq 1 $((pct/5))))" "$pct" "$msg"
        [ "$pct" -eq 100 ] && echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Core functions
# ═══════════════════════════════════════════════════════════════════════════════

check_root() {
    [ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash install.sh"
}

detect_env() {
    IS_LXC=false
    if grep -qa 'container=lxc' /proc/1/environ 2>/dev/null || \
       [ -f /run/container_type ] || \
       systemd-detect-virt -c &>/dev/null 2>&1; then
        IS_LXC=true
    fi
}

npm_install() {
    local dir="$1"; shift
    cd "$dir"
    npm install "$@" --no-audit --no-fund 2>&1 | tail -3
}

get_source_hash() {
    # Hash of source files to detect changes (excludes node_modules, .next, dist)
    local dir="$1"
    find "$dir" -type f \
        -not -path '*/node_modules/*' \
        -not -path '*/.next/*' \
        -not -path '*/dist/*' \
        -not -name '*.db' \
        -not -name '.env' \
        -newer "$VERSION_FILE" 2>/dev/null | wc -l
}

health_check() {
    local port="$1" max_wait="${2:-15}"
    for ((i=1; i<=max_wait; i++)); do
        if curl -sf -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port" 2>/dev/null | grep -qE '^[23]'; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# System dependencies
# ═══════════════════════════════════════════════════════════════════════════════

install_deps() {
    step "Installing system dependencies"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq

    local pkgs=(curl gnupg ca-certificates postgresql postgresql-contrib
                redis-server build-essential python3 rsync logrotate)

    apt-get install -y -qq "${pkgs[@]}"
    ok "System packages installed"

    # Node.js
    local need_node=false
    if ! command -v node &>/dev/null; then
        need_node=true
    else
        local cur
        cur=$(node -v | sed 's/v//' | cut -d. -f1)
        [ "$cur" -lt "$NODE_MAJOR" ] && need_node=true
    fi

    if $need_node; then
        step "Installing Node.js $NODE_MAJOR"
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
        apt-get install -y -qq nodejs
    fi
    ok "Node.js $(node -v)"

    # npm upgrade
    local npm_major
    npm_major=$(npm -v | cut -d. -f1)
    if [ "$npm_major" -lt 10 ]; then
        npm install -g npm@latest 2>&1 | tail -1
        hash -r
    fi
    ok "npm $(npm -v)"

    systemctl enable --now postgresql 2>/dev/null || true
    systemctl enable --now redis-server 2>/dev/null || true
    ok "PostgreSQL & Redis running"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Database setup
# ═══════════════════════════════════════════════════════════════════════════════

setup_db() {
    step "Configuring PostgreSQL"
    for i in $(seq 1 10); do
        su - postgres -c "pg_isready" &>/dev/null && break
        sleep 1
    done

    su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='$SERVICE_USER'\"" | grep -q 1 || {
        su - postgres -c "psql -c \"CREATE ROLE $SERVICE_USER WITH LOGIN PASSWORD '$DB_PASSWORD';\""
        ok "DB role '$SERVICE_USER' created"
    }
    su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname='anime_player'\"" | grep -q 1 || {
        su - postgres -c "psql -c \"CREATE DATABASE anime_player OWNER $SERVICE_USER;\""
        ok "Database 'anime_player' created"
    }
    ok "Database ready"
}

# ═══════════════════════════════════════════════════════════════════════════════
# User & permissions
# ═══════════════════════════════════════════════════════════════════════════════

setup_user() {
    step "System user"
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --shell /usr/sbin/nologin --home-dir "$INSTALL_DIR" --create-home "$SERVICE_USER"
        ok "User '$SERVICE_USER' created"
    else
        ok "User '$SERVICE_USER' exists"
    fi
}

apply_permissions() {
    step "Setting permissions"
    mkdir -p "$LOG_DIR" "$INSTALL_DIR/backend/video_library"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    for f in "$INSTALL_DIR/backend/.env" "$INSTALL_DIR/mangahook-api/server/.env" "$INSTALL_DIR/web/.env"; do
        [ -f "$f" ] && chmod 600 "$f"
    done
    ok "Permissions set"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Source copy & env
# ═══════════════════════════════════════════════════════════════════════════════

copy_sources() {
    step "Syncing sources to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    rsync -a --delete \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='mobile' \
        --exclude='temp_*' \
        --exclude='*.db' \
        --exclude='scripts/' \
        --exclude='.env' \
        --exclude='video_library/' \
        --exclude='.next/' \
        --exclude='dist/' \
        "$PROJECT_ROOT/" "$INSTALL_DIR/"
    ok "Sources synced"
}

generate_env() {
    local preserve_backend=false preserve_web=false
    [ -f "$INSTALL_DIR/backend/.env" ] && preserve_backend=true
    [ -f "$INSTALL_DIR/web/.env" ] && preserve_web=true

    if ! $preserve_backend; then
        step "Generating backend .env"
        cat > "$INSTALL_DIR/backend/.env" <<ENVEOF
# SynapseAnime — Production Config
# Generated $(date '+%Y-%m-%d %H:%M')

DB_TYPE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=$SERVICE_USER
DB_PASSWORD=$DB_PASSWORD
DB_DATABASE=anime_player

JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

PORT=3005
NODE_ENV=production

CONSUMET_API_URL=http://127.0.0.1:3004
CONSUMET_PROVIDER=animeunity
MANGAHOOK_API_URL=http://127.0.0.1:5000/api

JIKAN_API_URL=https://api.jikan.moe/v4
JIKAN_CACHE_TTL=86400
MANGADEX_API_URL=https://api.mangadex.org
MANGADEX_CACHE_TTL=21600

CORS_ORIGINS=http://127.0.0.1:3000,http://localhost:3000

# Optional — uncomment and fill:
# TMDB_API_KEY=
# PERPLEXITY_API_KEY=
# STRIPE_SECRET_KEY=
# GOOGLE_CLIENT_ID=
# FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
ENVEOF
        ok "Backend .env created"
    else
        warn "Backend .env preserved (update)"
    fi

    cat > "$INSTALL_DIR/mangahook-api/server/.env" <<'EOF'
PORT=5000
NODE_ENV=production
EOF
    ok "MangaHook .env created"

    if ! $preserve_web; then
        cat > "$INSTALL_DIR/web/.env" <<WEBEOF
PORT=3000
NODE_ENV=production
NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-http://127.0.0.1:3005}
WEBEOF
        ok "Web .env created"
    else
        warn "Web .env preserved (update)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Build components
# ═══════════════════════════════════════════════════════════════════════════════

build_backend() {
    step "Building Backend (NestJS)"
    cd "$INSTALL_DIR/backend"
    rm -rf node_modules dist
    npm_install "$INSTALL_DIR/backend"
    npx nest build || die "Backend build failed"
    npm prune --omit=dev --no-audit --no-fund 2>&1 | tail -1
    ok "Backend compiled"
}

build_web() {
    step "Building Web Frontend (Next.js)"
    cd "$INSTALL_DIR/web"
    rm -rf node_modules .next
    npm_install "$INSTALL_DIR/web"
    NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-http://127.0.0.1:3005}" npx next build || die "Web build failed"
    # Don't prune devDeps — next start needs typescript to transpile next.config.ts
    ok "Frontend compiled"
}

build_consumet() {
    step "Installing Consumet API"
    cd "$INSTALL_DIR/consumet-api"
    rm -rf node_modules
    npm_install "$INSTALL_DIR/consumet-api"
    ok "Consumet ready"
}

build_mangahook() {
    step "Installing MangaHook API"
    cd "$INSTALL_DIR/mangahook-api/server"
    rm -rf node_modules
    npm_install "$INSTALL_DIR/mangahook-api/server" --omit=dev
    ok "MangaHook ready"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Systemd services
# ═══════════════════════════════════════════════════════════════════════════════

create_systemd_units() {
    step "Creating systemd services"

    local NODE_BIN NPX_BIN
    NODE_BIN=$(command -v node)
    NPX_BIN=$(command -v npx)

    # Backend
    cat > /etc/systemd/system/openanime-backend.service <<EOF
[Unit]
Description=SynapseAnime Backend API (NestJS)
After=network.target postgresql.service redis-server.service
Requires=postgresql.service
Wants=redis-server.service openanime-consumet.service openanime-mangahook.service
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/backend
ExecStart=$NODE_BIN dist/src/main.js
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/backend/.env
StandardOutput=append:$LOG_DIR/backend.log
StandardError=append:$LOG_DIR/backend.error.log
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/backend/video_library $LOG_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # Consumet
    cat > /etc/systemd/system/openanime-consumet.service <<EOF
[Unit]
Description=SynapseAnime Consumet API (Anime Provider)
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/consumet-api
ExecStart=$NPX_BIN ts-node src/main.ts
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3004
StandardOutput=append:$LOG_DIR/consumet.log
StandardError=append:$LOG_DIR/consumet.error.log
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # MangaHook
    cat > /etc/systemd/system/openanime-mangahook.service <<EOF
[Unit]
Description=SynapseAnime MangaHook API (Manga Provider)
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/mangahook-api/server
ExecStart=$NODE_BIN app.js
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/mangahook-api/server/.env
StandardOutput=append:$LOG_DIR/mangahook.log
StandardError=append:$LOG_DIR/mangahook.error.log
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # Web Frontend
    cat > /etc/systemd/system/openanime-web.service <<EOF
[Unit]
Description=SynapseAnime Web Frontend (Next.js)
After=network.target openanime-backend.service
Wants=openanime-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/web
ExecStart=$NODE_BIN node_modules/.bin/next start -p 3000
Environment=HOME=$INSTALL_DIR
Restart=always
RestartSec=5
EnvironmentFile=$INSTALL_DIR/web/.env
StandardOutput=append:$LOG_DIR/web.log
StandardError=append:$LOG_DIR/web.error.log
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$LOG_DIR $INSTALL_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    ok "Systemd units created"
}

setup_logrotate() {
    cat > /etc/logrotate.d/openanime <<'EOF'
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
EOF
    ok "Logrotate configured (14 days)"
}

start_services() {
    step "Starting services"
    for svc in "${SERVICES[@]}"; do
        systemctl enable "$svc" --quiet 2>/dev/null || true
        systemctl restart "$svc"
        ok "$svc started"
        sleep 2
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# Status dashboard
# ═══════════════════════════════════════════════════════════════════════════════

do_status() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║           SynapseAnime — Service Dashboard                  ║${RESET}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf "${BOLD}║ %-22s │ %-8s │ %-6s │ %-8s ║${RESET}\n" "Service" "Status" "Port" "HTTP"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"

    for i in "${!SERVICES[@]}"; do
        local svc="${SERVICES[$i]}"
        local label="${SVC_LABELS[$i]}"
        local port="${SVC_PORTS[$svc]}"

        # Systemd status
        local status_color status_text
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            status_color="$GREEN"
            status_text="active"
        elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            status_color="$YELLOW"
            status_text="stopped"
        else
            status_color="$DIM"
            status_text="n/a"
        fi

        # HTTP health check (try / first, then service-specific paths)
        local http_color http_text http_ok=false
        for path in "/" "/api" "/home"; do
            if curl -sf -o /dev/null --max-time 3 "http://127.0.0.1:$port$path" 2>/dev/null; then
                http_ok=true
                break
            fi
        done
        if $http_ok; then
            http_color="$GREEN"
            http_text="OK"
        else
            http_color="$RED"
            http_text="DOWN"
        fi

        printf "║ %-22s │ ${status_color}%-8s${RESET} │ :%-5s │ ${http_color}%-8s${RESET} ║\n" \
            "$label" "$status_text" "$port" "$http_text"
    done

    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"

    # Disk & memory
    local disk_used
    disk_used=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1 || echo "n/a")
    local log_size
    log_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1 || echo "n/a")
    local mem_free
    mem_free=$(free -h 2>/dev/null | awk '/Mem:/ {print $7}' || echo "n/a")

    printf "║ Install: %-14s Logs: %-12s Mem free: %-7s ║\n" "$disk_used" "$log_size" "$mem_free"

    # Version
    local ver="unknown"
    [ -f "$VERSION_FILE" ] && ver=$(cat "$VERSION_FILE")
    local uptime_info
    uptime_info=$(systemctl show openanime-backend --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2 || echo "n/a")

    printf "║ Version: %-14s Since: %-27s ║\n" "$ver" "$uptime_info"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# Backup & Rollback
# ═══════════════════════════════════════════════════════════════════════════════

do_backup() {
    step "Creating backup"
    [ -d "$INSTALL_DIR" ] || die "Nothing to backup — not installed"

    mkdir -p "$BACKUP_DIR"
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/backup_$ts"

    # Backup env files and dist/build artifacts (not node_modules)
    mkdir -p "$backup_path"
    for f in "$INSTALL_DIR/backend/.env" "$INSTALL_DIR/web/.env" "$INSTALL_DIR/mangahook-api/server/.env"; do
        [ -f "$f" ] && cp "$f" "$backup_path/$(echo "$f" | sed 's|/|__|g')"
    done
    [ -d "$INSTALL_DIR/backend/dist" ] && cp -a "$INSTALL_DIR/backend/dist" "$backup_path/backend_dist"
    [ -d "$INSTALL_DIR/web/.next" ] && cp -a "$INSTALL_DIR/web/.next" "$backup_path/web_next"

    # Record version
    [ -f "$VERSION_FILE" ] && cp "$VERSION_FILE" "$backup_path/.synapse-version"
    echo "$ts" > "$backup_path/.backup-timestamp"

    ok "Backup created: $backup_path"

    # Keep only last 5 backups
    local count
    count=$(ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | wc -l)
    if [ "$count" -gt 5 ]; then
        ls -1d "$BACKUP_DIR"/backup_* | head -n -5 | xargs rm -rf
        ok "Old backups pruned (keeping last 5)"
    fi
}

do_rollback() {
    step "Rollback"
    local latest
    latest=$(ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | tail -1)
    [ -z "$latest" ] && die "No backups found in $BACKUP_DIR"

    local ts
    ts=$(cat "$latest/.backup-timestamp" 2>/dev/null || basename "$latest")
    echo "  Latest backup: $ts"

    if ! tui_confirm "Restore this backup? Services will be stopped."; then
        echo "  Cancelled."
        return
    fi

    step "Stopping services"
    for svc in "${SERVICES[@]}"; do
        systemctl stop "$svc" 2>/dev/null || true
    done

    # Restore env files
    for f in "$latest"/*__*; do
        [ -f "$f" ] || continue
        local orig
        orig=$(basename "$f" | sed 's|__|/|g')
        cp "$f" "$orig"
        ok "Restored $orig"
    done

    # Restore builds
    if [ -d "$latest/backend_dist" ]; then
        rm -rf "$INSTALL_DIR/backend/dist"
        cp -a "$latest/backend_dist" "$INSTALL_DIR/backend/dist"
        ok "Restored backend dist/"
    fi
    if [ -d "$latest/web_next" ]; then
        rm -rf "$INSTALL_DIR/web/.next"
        cp -a "$latest/web_next" "$INSTALL_DIR/web/.next"
        ok "Restored web .next/"
    fi

    apply_permissions
    start_services
    ok "Rollback complete"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Install (fresh)
# ═══════════════════════════════════════════════════════════════════════════════

do_install() {
    step "Full Installation"

    if [ -d "$INSTALL_DIR/backend/dist" ]; then
        if ! tui_confirm "SynapseAnime is already installed. Reinstall? (envs preserved)"; then
            return
        fi
    fi

    install_deps
    setup_user
    setup_db
    copy_sources
    generate_env

    if $HAS_WHIPTAIL; then
        {
            tui_progress "Building Consumet..." 10
            build_consumet >/dev/null 2>&1
            tui_progress "Building MangaHook..." 25
            build_mangahook >/dev/null 2>&1
            tui_progress "Building Backend..." 40
            build_backend >/dev/null 2>&1
            tui_progress "Building Web Frontend..." 65
            build_web >/dev/null 2>&1
            tui_progress "Configuring services..." 90
            apply_permissions
            create_systemd_units
            setup_logrotate
            tui_progress "Starting services..." 95
            start_services >/dev/null 2>&1
            tui_progress "Done" 100
        } | whiptail --title "Building SynapseAnime" --gauge "\nInstalling..." 10 60 0
    else
        build_consumet
        build_mangahook
        build_backend
        build_web
        apply_permissions
        create_systemd_units
        setup_logrotate
        start_services
    fi

    # Save version
    local ver
    ver=$(cd "$PROJECT_ROOT" && git describe --tags --always 2>/dev/null || echo "$(date '+%Y%m%d')")
    echo "$ver" > "$VERSION_FILE"
    chown "$SERVICE_USER:$SERVICE_USER" "$VERSION_FILE"

    echo ""
    do_status
    print_summary
}

# ═══════════════════════════════════════════════════════════════════════════════
# Smart Update
# ═══════════════════════════════════════════════════════════════════════════════

do_update() {
    step "Smart Update"
    [ -d "$INSTALL_DIR/backend" ] || die "Not installed. Run install first."

    # Backup before update
    do_backup

    # Stop services
    step "Stopping services"
    for svc in "${SERVICES[@]}"; do
        systemctl stop "$svc" 2>/dev/null || true
    done

    # Sync new sources
    copy_sources

    # Detect what changed
    touch -d "2000-01-01" "$VERSION_FILE" 2>/dev/null || touch "$VERSION_FILE"

    local changed_backend changed_web changed_consumet changed_mangahook
    changed_backend=$(find "$INSTALL_DIR/backend/src" -newer "$VERSION_FILE" 2>/dev/null | head -1)
    changed_web=$(find "$INSTALL_DIR/web/app" "$INSTALL_DIR/web/components" "$INSTALL_DIR/web/services" \
        "$INSTALL_DIR/web/contexts" "$INSTALL_DIR/web/types" "$INSTALL_DIR/web/lib" \
        -newer "$VERSION_FILE" 2>/dev/null | head -1)
    changed_consumet=$(find "$INSTALL_DIR/consumet-api/src" -newer "$VERSION_FILE" 2>/dev/null | head -1)
    changed_mangahook=$(find "$INSTALL_DIR/mangahook-api/server" -name "*.js" -newer "$VERSION_FILE" 2>/dev/null | head -1)

    local rebuilt=0

    if [ -n "$changed_backend" ] || [ ! -d "$INSTALL_DIR/backend/dist" ]; then
        build_backend
        rebuilt=$((rebuilt+1))
    else
        ok "Backend unchanged — skipped"
    fi

    if [ -n "$changed_web" ] || [ ! -d "$INSTALL_DIR/web/.next" ]; then
        build_web
        rebuilt=$((rebuilt+1))
    else
        ok "Web Frontend unchanged — skipped"
    fi

    if [ -n "$changed_consumet" ] || [ ! -d "$INSTALL_DIR/consumet-api/node_modules" ]; then
        build_consumet
        rebuilt=$((rebuilt+1))
    else
        ok "Consumet unchanged — skipped"
    fi

    if [ -n "$changed_mangahook" ] || [ ! -d "$INSTALL_DIR/mangahook-api/server/node_modules" ]; then
        build_mangahook
        rebuilt=$((rebuilt+1))
    else
        ok "MangaHook unchanged — skipped"
    fi

    apply_permissions
    create_systemd_units

    # Save version
    local ver
    ver=$(cd "$PROJECT_ROOT" && git describe --tags --always 2>/dev/null || echo "$(date '+%Y%m%d')")
    echo "$ver" > "$VERSION_FILE"
    chown "$SERVICE_USER:$SERVICE_USER" "$VERSION_FILE"

    start_services

    echo ""
    ok "Update complete — $rebuilt component(s) rebuilt"
    sleep 5
    do_status
}

# ═══════════════════════════════════════════════════════════════════════════════
# Logs
# ═══════════════════════════════════════════════════════════════════════════════

do_logs_menu() {
    local choice
    if $HAS_WHIPTAIL; then
        choice=$(whiptail --title "View Logs" --menu "\nSelect service:" 14 50 5 \
            "web"       "Web Frontend" \
            "backend"   "Backend API" \
            "consumet"  "Consumet API" \
            "mangahook" "MangaHook API" \
            "all"       "All services (journalctl)" \
            3>&1 1>&2 2>&3) || return
    else
        echo ""
        echo "  1) Web        2) Backend    3) Consumet"
        echo "  4) MangaHook  5) All"
        read -rp "  Select: " n
        case $n in
            1) choice=web ;; 2) choice=backend ;; 3) choice=consumet ;;
            4) choice=mangahook ;; 5) choice=all ;; *) return ;;
        esac
    fi

    echo -e "\n${DIM}Press Ctrl+C to stop${RESET}\n"
    if [ "$choice" = "all" ]; then
        journalctl -u 'openanime-*' -f --no-pager
    else
        tail -f "$LOG_DIR/$choice.log" "$LOG_DIR/$choice.error.log" 2>/dev/null || \
            journalctl -u "openanime-$choice" -f --no-pager
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Restart
# ═══════════════════════════════════════════════════════════════════════════════

do_restart_menu() {
    local selected
    if $HAS_WHIPTAIL; then
        selected=$(tui_checklist "Restart Services" \
            "openanime-web"       "Web Frontend"   ON \
            "openanime-backend"   "Backend API"    ON \
            "openanime-consumet"  "Consumet API"   ON \
            "openanime-mangahook" "MangaHook API"  ON \
        ) || return
    else
        selected="${SERVICES[*]}"
    fi

    for svc in $selected; do
        svc=$(echo "$svc" | tr -d '"')
        systemctl restart "$svc"
        ok "Restarted $svc"
    done

    sleep 3
    do_status
}

# ═══════════════════════════════════════════════════════════════════════════════
# Uninstall
# ═══════════════════════════════════════════════════════════════════════════════

do_uninstall() {
    if ! tui_confirm "Remove ALL SynapseAnime services and data?"; then
        echo "  Cancelled."
        return
    fi

    step "Uninstalling SynapseAnime"
    for svc in "${SERVICES[@]}"; do
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "/etc/systemd/system/$svc.service"
        ok "Removed $svc"
    done
    rm -f /etc/logrotate.d/openanime
    systemctl daemon-reload

    if tui_confirm "Also delete install directory ($INSTALL_DIR)?"; then
        rm -rf "$INSTALL_DIR"
        ok "Install directory removed"
    fi

    if tui_confirm "Also delete backups ($BACKUP_DIR)?"; then
        rm -rf "$BACKUP_DIR"
        ok "Backups removed"
    fi

    if tui_confirm "Also delete logs ($LOG_DIR)?"; then
        rm -rf "$LOG_DIR"
        ok "Logs removed"
    fi

    echo ""
    ok "Uninstall complete"
    echo "  PostgreSQL and Redis were NOT removed."
    echo "  To remove: apt purge postgresql redis-server -y"
    echo "  To remove user: userdel -r $SERVICE_USER"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

print_summary() {
    echo ""
    echo -e "${BOLD}Installation complete!${RESET}"
    echo ""
    echo "  Endpoints:"
    echo "    Web App:     http://<IP>:3000"
    echo "    Backend API: http://<IP>:3005"
    echo ""
    echo "  Config:  $INSTALL_DIR/backend/.env"
    echo "  Logs:    $LOG_DIR/"
    echo ""
    echo "  Management:"
    echo "    sudo bash install.sh          # TUI menu"
    echo "    sudo bash install.sh status   # Dashboard"
    echo "    sudo bash install.sh update   # Smart update"
    echo "    sudo bash install.sh logs     # View logs"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

check_root
detect_env

case "${1:-}" in
    install)   do_install ;;
    update)    do_update ;;
    status)    do_status ;;
    logs)      shift; do_logs_menu ;;
    backup)    do_backup ;;
    rollback)  do_rollback ;;
    restart)   do_restart_menu ;;
    uninstall) do_uninstall ;;
    --uninstall) do_uninstall ;;  # backwards compat
    --skip-deps) install_deps() { ok "Deps skipped (--skip-deps)"; }; do_install ;;
    "")        tui_menu ;;
    *)         die "Unknown command: $1. Use: install|update|status|logs|backup|rollback|restart|uninstall" ;;
esac
