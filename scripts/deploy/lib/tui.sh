#!/usr/bin/env bash
# =============================================================================
# tui.sh - Whiptail TUI wizard for SynapseAnime deploy system
# =============================================================================
# Provides: interactive configuration wizard using whiptail, config file
# save/load, default values, service status dashboard.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# _tui_detect_terminal - Detect terminal dimensions.
# ---------------------------------------------------------------------------
# Sets globals: TUI_ROWS, TUI_COLS
_tui_detect_terminal() {
    TUI_ROWS="$(tput lines 2>/dev/null || echo 24)"
    TUI_COLS="$(tput cols 2>/dev/null || echo 80)"
    # Cap for whiptail
    [[ "$TUI_ROWS" -gt 40 ]] && TUI_ROWS=40
    [[ "$TUI_COLS" -gt 100 ]] && TUI_COLS=100
}

# ---------------------------------------------------------------------------
# set_defaults - Set all configuration variables to their defaults.
# ---------------------------------------------------------------------------
# Called before TUI, config file load, or non-interactive mode.
# Globals set: all DEPLOY_* and service config vars
set_defaults() {
    # Source
    DEPLOY_SOURCE="${DEPLOY_SOURCE:-local}"
    GIT_REPO="${GIT_REPO:-}"
    GIT_BRANCH="${GIT_BRANCH:-main}"

    # Network
    DOMAIN="${DOMAIN:-synapseanime.local}"
    WEB_PORT="${WEB_PORT:-3000}"
    API_PORT="${API_PORT:-3005}"
    HTTP_PORT="${HTTP_PORT:-80}"

    # Database
    DB_NAME="${DB_NAME:-anime_player}"
    DB_USER="${DB_USER:-openanime}"
    DB_PASSWORD="${DB_PASSWORD:-}"
    DB_PORT="${DB_PORT:-5432}"
    DB_HOST="${DB_HOST:-localhost}"
    DB_EXTERNAL="${DB_EXTERNAL:-false}"

    # Redis
    REDIS_HOST="${REDIS_HOST:-localhost}"
    REDIS_PORT="${REDIS_PORT:-6379}"
    REDIS_PASSWORD="${REDIS_PASSWORD:-}"
    REDIS_EXTERNAL="${REDIS_EXTERNAL:-false}"

    # Auth / Security
    JWT_SECRET="${JWT_SECRET:-}"
    JWT_EXPIRES_IN="${JWT_EXPIRES_IN:-7d}"
    CORS_ORIGINS="${CORS_ORIGINS:-http://${DOMAIN}}"

    # Consumet / MangaHook
    CONSUMET_PORT="${CONSUMET_PORT:-3004}"
    MANGAHOOK_PORT="${MANGAHOOK_PORT:-5000}"

    # Paths
    INSTALL_DIR="${INSTALL_DIR:-/opt/openanime}"
    LOG_DIR="${LOG_DIR:-/var/log/openanime}"

    # Options
    ENABLE_LOGROTATE="${ENABLE_LOGROTATE:-true}"
    ENABLE_UFW="${ENABLE_UFW:-false}"
    NGINX_EXTERNAL="${NGINX_EXTERNAL:-false}"

    # Derived — use relative path by default so frontend works with any host
    # (behind reverse proxy, CDN, custom domain, etc.) without mixed content
    # issues. Override with a full URL only if the API is on a different origin.
    NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-/api}"

    # Node paths (resolved later)
    NODE_BIN="${NODE_BIN:-/usr/bin/node}"
    NPX_BIN="${NPX_BIN:-/usr/bin/npx}"

    # Systemd
    SYSTEMD_AFTER="${SYSTEMD_AFTER:-}"
}

# ---------------------------------------------------------------------------
# Whiptail wrapper helpers
# ---------------------------------------------------------------------------

# _whiptail_input TITLE TEXT DEFAULT - Prompt for text input.
# Sets _WT_RESULT. Returns 0 on OK, 1 on Cancel.
_whiptail_input() {
    local title="$1" text="$2" default="$3"
    _tui_detect_terminal
    _WT_RESULT=""
    if _WT_RESULT="$(whiptail --title "$title" --inputbox "$text" \
        "$((TUI_ROWS - 6))" "$((TUI_COLS - 10))" "$default" \
        3>&1 1>&2 2>&3)"; then
        return 0
    else
        _WT_RESULT=""
        return 1
    fi
}

# _whiptail_password TITLE TEXT - Prompt for password input (masked).
# Sets _WT_RESULT. Returns 0 on OK, 1 on Cancel.
_whiptail_password() {
    local title="$1" text="$2"
    _tui_detect_terminal
    _WT_RESULT=""
    if _WT_RESULT="$(whiptail --title "$title" --passwordbox "$text" \
        "$((TUI_ROWS - 6))" "$((TUI_COLS - 10))" \
        3>&1 1>&2 2>&3)"; then
        return 0
    else
        _WT_RESULT=""
        return 1
    fi
}

# _whiptail_menu TITLE TEXT ITEMS... - Display a menu.
# ITEMS are tag/description pairs.
# Sets _WT_RESULT. Returns 0 on OK, 1 on Cancel.
_whiptail_menu() {
    local title="$1" text="$2"
    shift 2
    _tui_detect_terminal
    local items=("$@")
    local count=$(( ${#items[@]} / 2 ))
    _WT_RESULT=""
    if _WT_RESULT="$(whiptail --title "$title" --menu "$text" \
        "$((TUI_ROWS - 4))" "$((TUI_COLS - 10))" "$count" \
        "${items[@]}" \
        3>&1 1>&2 2>&3)"; then
        return 0
    else
        _WT_RESULT=""
        return 1
    fi
}

# ---------------------------------------------------------------------------
# TUI Screens
# ---------------------------------------------------------------------------

# _tui_welcome - Welcome screen with overview.
_tui_welcome() {
    _tui_detect_terminal
    whiptail --title "SynapseAnime Installer" --msgbox \
"Welcome to the SynapseAnime Bare-Metal Installer.

This wizard will guide you through configuring:
  - Deploy source (local files or git repository)
  - Network settings (domain, ports)
  - PostgreSQL database
  - Redis cache
  - Nginx reverse proxy
  - Security settings (JWT, CORS)
  - Additional options

Press OK to continue." \
        "$((TUI_ROWS - 4))" "$((TUI_COLS - 10))"
}

# _tui_source - Choose deploy source.
# Sets: DEPLOY_SOURCE, GIT_REPO, GIT_BRANCH
_tui_source() {
    _whiptail_menu "Deploy Source" \
        "Where should the application files come from?" \
        "local" "Use files from current directory" \
        "git"   "Clone from a Git repository" || return 1
    DEPLOY_SOURCE="$_WT_RESULT"

    if [[ "$DEPLOY_SOURCE" == "git" ]]; then
        _whiptail_input "Git Repository" \
            "Enter the Git repository URL:" "$GIT_REPO" || return 1
        GIT_REPO="$_WT_RESULT"
        _whiptail_input "Git Branch" \
            "Enter the branch to deploy:" "$GIT_BRANCH" || return 1
        GIT_BRANCH="$_WT_RESULT"
    fi
}

# _tui_network - Configure domain and ports.
# Sets: DOMAIN, WEB_PORT, API_PORT
_tui_network() {
    _whiptail_input "Domain / Hostname" \
        "Enter the domain name or hostname for this server:" \
        "$DOMAIN" || return 1
    DOMAIN="$_WT_RESULT"

    _whiptail_input "Web Port" \
        "Port for the Next.js web frontend:" "$WEB_PORT" || return 1
    WEB_PORT="$_WT_RESULT"

    _whiptail_input "API Port" \
        "Port for the NestJS backend API:" "$API_PORT" || return 1
    API_PORT="$_WT_RESULT"

    # Recalculate derived values
    CORS_ORIGINS="http://${DOMAIN}"
    NEXT_PUBLIC_API_URL="http://${DOMAIN}/api"
}

# _tui_postgresql - Configure PostgreSQL settings.
# Sets: DB_EXTERNAL, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT, DB_HOST
_tui_postgresql() {
    _whiptail_menu "PostgreSQL" \
        "How should PostgreSQL be provided?" \
        "local"    "Install locally (recommended)" \
        "external" "Use an existing external server" || return 1

    if [[ "$_WT_RESULT" == "external" ]]; then
        DB_EXTERNAL="true"
        _whiptail_input "PostgreSQL — Host" \
            "External PostgreSQL hostname or IP:" "$DB_HOST" || return 1
        DB_HOST="$_WT_RESULT"
        _whiptail_input "PostgreSQL — Port" \
            "External PostgreSQL port:" "$DB_PORT" || return 1
        DB_PORT="$_WT_RESULT"
    else
        DB_EXTERNAL="false"
        DB_HOST="localhost"
    fi

    _whiptail_input "Database Name" \
        "PostgreSQL database name:" "$DB_NAME" || return 1
    DB_NAME="$_WT_RESULT"

    _whiptail_input "Database User" \
        "PostgreSQL user:" "$DB_USER" || return 1
    DB_USER="$_WT_RESULT"

    # Password: OK with empty (auto-generate), so ignore cancel
    _whiptail_password "Database Password" \
        "PostgreSQL password (leave empty to auto-generate):" || true
    DB_PASSWORD="$_WT_RESULT"

    if [[ "$DB_EXTERNAL" == "false" ]]; then
        _whiptail_input "Database Port" \
            "PostgreSQL local port:" "$DB_PORT" || return 1
        DB_PORT="$_WT_RESULT"
    fi
}

# _tui_redis - Configure Redis settings.
# Sets: REDIS_EXTERNAL, REDIS_HOST, REDIS_PORT, REDIS_PASSWORD
_tui_redis() {
    _whiptail_menu "Redis" \
        "How should Redis be provided?" \
        "local"    "Install locally (recommended)" \
        "external" "Use an existing external server" || return 1

    if [[ "$_WT_RESULT" == "external" ]]; then
        REDIS_EXTERNAL="true"
        _whiptail_input "Redis — Host" \
            "External Redis hostname or IP:" "$REDIS_HOST" || return 1
        REDIS_HOST="$_WT_RESULT"
    else
        REDIS_EXTERNAL="false"
        REDIS_HOST="localhost"
    fi

    _whiptail_input "Redis Port" \
        "Redis port:" "$REDIS_PORT" || return 1
    REDIS_PORT="$_WT_RESULT"

    _whiptail_password "Redis Password" \
        "Redis password (leave empty for none):" || true
    REDIS_PASSWORD="$_WT_RESULT"
}

# _tui_nginx - Configure Nginx proxy.
# Sets: NGINX_EXTERNAL, HTTP_PORT
_tui_nginx() {
    _whiptail_menu "Nginx Reverse Proxy" \
        "How should the reverse proxy be provided?" \
        "local"    "Install Nginx locally (recommended)" \
        "external" "I manage my own proxy (Nginx/Caddy/Traefik)" || return 1

    if [[ "$_WT_RESULT" == "external" ]]; then
        NGINX_EXTERNAL="true"
        _tui_detect_terminal
        whiptail --title "Nginx — External Proxy" --msgbox \
"Configure your reverse proxy to point to:

  Web frontend:  http://127.0.0.1:${WEB_PORT}
  Backend API:   http://127.0.0.1:${API_PORT}
  WebSocket:     http://127.0.0.1:${API_PORT}/downloads
                 (requires Upgrade + Connection headers)

The installer will skip Nginx installation." \
            16 65 3>&1 1>&2 2>&3
    else
        NGINX_EXTERNAL="false"
        _whiptail_input "Nginx — HTTP Port" \
            "Port for Nginx to listen on:" "$HTTP_PORT" || return 1
        HTTP_PORT="$_WT_RESULT"
    fi
}

# _tui_security - Configure JWT and CORS.
# Sets: JWT_SECRET, JWT_EXPIRES_IN, CORS_ORIGINS
_tui_security() {
    _whiptail_password "JWT Secret" \
        "JWT secret key (leave empty to auto-generate):" || true
    JWT_SECRET="$_WT_RESULT"

    _whiptail_input "JWT Expiration" \
        "JWT token expiration (e.g., 7d, 24h):" "$JWT_EXPIRES_IN" || return 1
    JWT_EXPIRES_IN="$_WT_RESULT"

    _whiptail_input "CORS Origins" \
        "Allowed CORS origins (comma-separated):" "$CORS_ORIGINS" || return 1
    CORS_ORIGINS="$_WT_RESULT"
}

# _tui_options - Additional options (logrotate, UFW, ports).
# Sets: CONSUMET_PORT, MANGAHOOK_PORT, INSTALL_DIR, ENABLE_LOGROTATE, ENABLE_UFW
_tui_options() {
    _whiptail_input "Consumet API Port" \
        "Port for the Consumet API:" "$CONSUMET_PORT" || return 1
    CONSUMET_PORT="$_WT_RESULT"

    _whiptail_input "MangaHook API Port" \
        "Port for the MangaHook API:" "$MANGAHOOK_PORT" || return 1
    MANGAHOOK_PORT="$_WT_RESULT"

    _whiptail_input "Install Directory" \
        "Where to install SynapseAnime:" "$INSTALL_DIR" || return 1
    INSTALL_DIR="$_WT_RESULT"

    # Optional components checklist — use _WT_RESULT pattern
    _tui_detect_terminal
    _WT_RESULT=""
    if _WT_RESULT="$(whiptail --title "Additional Options" --checklist \
        "Select additional features (space to toggle):" \
        14 65 2 \
        "logrotate" "Log rotation (daily, 14 days, compress)" ON \
        "ufw"       "UFW firewall rules (HTTP, API, SSH)"     OFF \
        3>&1 1>&2 2>&3)"; then
        : # OK
    else
        return 1
    fi

    ENABLE_LOGROTATE="false"
    ENABLE_UFW="false"
    [[ "$_WT_RESULT" == *logrotate* ]] && ENABLE_LOGROTATE="true"
    [[ "$_WT_RESULT" == *ufw* ]] && ENABLE_UFW="true"
    return 0
}

# _tui_summary - Display a summary of all settings for confirmation.
# Returns: 0 if user confirms, 1 if user cancels
_tui_summary() {
    _tui_detect_terminal

    # Mask passwords
    local db_pw_display="(auto-generate)"
    [[ -n "$DB_PASSWORD" ]] && db_pw_display="********"
    local redis_pw_display="(none)"
    [[ -n "$REDIS_PASSWORD" ]] && redis_pw_display="********"
    local jwt_display="(auto-generate)"
    [[ -n "$JWT_SECRET" ]] && jwt_display="********"

    # Build external/local labels outside the whiptail call to avoid subshell issues
    local pg_label="local (:$DB_PORT)"
    [[ "$DB_EXTERNAL" == "true" ]] && pg_label="external ($DB_HOST:$DB_PORT)"
    local redis_label="local (:$REDIS_PORT)"
    [[ "$REDIS_EXTERNAL" == "true" ]] && redis_label="external ($REDIS_HOST:$REDIS_PORT)"
    local nginx_label="local (:$HTTP_PORT)"
    [[ "$NGINX_EXTERNAL" == "true" ]] && nginx_label="external (user-managed)"

    if whiptail --title "Configuration Summary" --yesno \
"Please review your configuration:

  Source:     $DEPLOY_SOURCE ${GIT_REPO:+(${GIT_REPO}@${GIT_BRANCH})}
  Domain:     $DOMAIN
  Install:    $INSTALL_DIR

  Web port:       $WEB_PORT
  API port:       $API_PORT
  Consumet port:  $CONSUMET_PORT
  MangaHook port: $MANGAHOOK_PORT

  Database:  ${DB_HOST}:${DB_PORT}/${DB_NAME} (user: $DB_USER)
  DB Pass:   $db_pw_display
  Redis:     ${REDIS_HOST}:${REDIS_PORT} (pass: $redis_pw_display)

  JWT:       $jwt_display (expires: $JWT_EXPIRES_IN)
  CORS:      $CORS_ORIGINS

  PostgreSQL: $pg_label
  Redis:      $redis_label
  Nginx:      $nginx_label

  Logrotate: $ENABLE_LOGROTATE
  UFW:       $ENABLE_UFW

Proceed with installation?" \
        "$((TUI_ROWS - 2))" "$((TUI_COLS - 6))" 3>&1 1>&2 2>&3; then
        return 0
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# run_tui_wizard - Run all TUI screens in sequence.
# ---------------------------------------------------------------------------
# Supports back navigation: if a screen returns 1 (Cancel), go to previous.
# Globals: all config variables
run_tui_wizard() {
    log_section "Configuration Wizard"

    if ! command -v whiptail &>/dev/null; then
        log_fail "whiptail is not installed. Run preflight checks first or use --non-interactive."
        exit 1
    fi

    local screens=(
        _tui_welcome
        _tui_source
        _tui_network
        _tui_postgresql
        _tui_redis
        _tui_nginx
        _tui_security
        _tui_options
        _tui_summary
    )

    local idx=0
    local total=${#screens[@]}

    # Disable set -e for the wizard loop — TUI screens rely on non-zero
    # exit codes for Cancel/back navigation, which is incompatible with -e
    set +e

    while [[ $idx -lt $total ]]; do
        local screen="${screens[$idx]}"

        "$screen"
        local rc=$?

        if [[ $rc -eq 0 ]]; then
            idx=$((idx + 1))
        else
            # Cancel pressed — go back one screen (minimum 0)
            if [[ $idx -gt 0 ]]; then
                idx=$((idx - 1))
                log_debug "Back to screen $idx"
            else
                log_warn "Installation cancelled by user."
                set -e
                exit 0
            fi
        fi
    done

    # Re-enable strict mode
    set -e

    # Auto-generate secrets if left empty
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD="$(gen_password 32)"
        log_info "Auto-generated database password"
    fi
    if [[ -z "$JWT_SECRET" ]]; then
        JWT_SECRET="$(gen_password 48)"
        log_info "Auto-generated JWT secret"
    fi

    log_ok "Configuration complete"
}

# ---------------------------------------------------------------------------
# save_deploy_conf FILE - Save all config variables to a key=value file.
# ---------------------------------------------------------------------------
# Arguments:
#   FILE - path to write the config file
save_deploy_conf() {
    local file="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would save deploy config to $file"
        return 0
    fi

    cat > "$file" <<CONF
# SynapseAnime Deploy Configuration
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# ------------------------------------------

# Source
DEPLOY_SOURCE="${DEPLOY_SOURCE}"
GIT_REPO="${GIT_REPO}"
GIT_BRANCH="${GIT_BRANCH}"

# Network
DOMAIN="${DOMAIN}"
WEB_PORT="${WEB_PORT}"
API_PORT="${API_PORT}"
HTTP_PORT="${HTTP_PORT}"

# Database
DB_EXTERNAL="${DB_EXTERNAL}"
DB_HOST="${DB_HOST}"
DB_PORT="${DB_PORT}"
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"

# Redis
REDIS_EXTERNAL="${REDIS_EXTERNAL}"
REDIS_HOST="${REDIS_HOST}"
REDIS_PORT="${REDIS_PORT}"
REDIS_PASSWORD="${REDIS_PASSWORD}"

# Auth / Security
JWT_SECRET="${JWT_SECRET}"
JWT_EXPIRES_IN="${JWT_EXPIRES_IN}"
CORS_ORIGINS="${CORS_ORIGINS}"

# Services
CONSUMET_PORT="${CONSUMET_PORT}"
MANGAHOOK_PORT="${MANGAHOOK_PORT}"

# Paths
INSTALL_DIR="${INSTALL_DIR}"
LOG_DIR="${LOG_DIR}"

# Nginx
NGINX_EXTERNAL="${NGINX_EXTERNAL}"

# Options
ENABLE_LOGROTATE="${ENABLE_LOGROTATE}"
ENABLE_UFW="${ENABLE_UFW}"

# Derived
NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL}"
NODE_BIN="${NODE_BIN}"
NPX_BIN="${NPX_BIN}"
CONF

    chmod 600 "$file"
    log_ok "Saved configuration to $file"
}

# ---------------------------------------------------------------------------
# load_deploy_conf FILE - Load config variables from a key=value file.
# ---------------------------------------------------------------------------
# Arguments:
#   FILE - path to the config file
load_deploy_conf() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_fail "Config file not found: $file"
        return 1
    fi

    log_info "Loading configuration from $file"

    # Source the file (all vars are simple key=value assignments)
    set +u
    # shellcheck source=/dev/null
    source "$file"
    set -u

    log_ok "Loaded configuration from $file"
}

# ---------------------------------------------------------------------------
# show_service_status - Display a dashboard of service statuses.
# ---------------------------------------------------------------------------
# Shows systemd status, HTTP health checks, disk and memory usage.
show_service_status() {
    local line="─"
    local hline
    hline="$(printf '%0.s─' {1..60})"

    printf "\n"
    printf "  ┌%s┐\n" "$hline"
    printf "  │ %-58s │\n" "SynapseAnime Service Dashboard"
    printf "  ├%s┤\n" "$hline"

    # Systemd services
    local services=(
        "openanime-backend:Backend API (NestJS):${API_PORT:-3005}"
        "openanime-web:Web Frontend (Next.js):${WEB_PORT:-3000}"
        "openanime-consumet:Consumet API:${CONSUMET_PORT:-3004}"
        "openanime-mangahook:MangaHook API:${MANGAHOOK_PORT:-5000}"
        "postgresql:PostgreSQL:${DB_PORT:-5432}"
        "redis-server:Redis:${REDIS_PORT:-6379}"
        "nginx:Nginx:${HTTP_PORT:-80}"
    )

    printf "  │ %-30s %-12s %-12s │\n" "SERVICE" "STATUS" "HEALTH"
    printf "  │ %s │\n" "$(printf '%0.s─' {1..58})"

    for entry in "${services[@]}"; do
        IFS=: read -r svc_name svc_label svc_port <<< "$entry"

        # Systemd status
        local status="unknown"
        local status_color=""
        if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
            status="running"
            status_color="${GREEN}"
        elif systemctl is-enabled --quiet "$svc_name" 2>/dev/null; then
            status="stopped"
            status_color="${RED}"
        else
            status="n/a"
            status_color="${CYAN}"
        fi

        # HTTP health check for app services
        local health="-"
        case "$svc_name" in
            openanime-backend)
                if curl -sf --connect-timeout 3 "http://127.0.0.1:${svc_port}/" &>/dev/null; then
                    health="${GREEN}ok${RESET}"
                elif [[ "$status" == "running" ]]; then
                    health="${YELLOW}?${RESET}"
                fi
                ;;
            openanime-web)
                if curl -sf --connect-timeout 3 "http://127.0.0.1:${svc_port}/" &>/dev/null; then
                    health="${GREEN}ok${RESET}"
                elif [[ "$status" == "running" ]]; then
                    health="${YELLOW}?${RESET}"
                fi
                ;;
            openanime-consumet)
                if curl -sf --connect-timeout 3 "http://127.0.0.1:${svc_port}/" &>/dev/null; then
                    health="${GREEN}ok${RESET}"
                elif [[ "$status" == "running" ]]; then
                    health="${YELLOW}?${RESET}"
                fi
                ;;
            openanime-mangahook)
                if curl -sf --connect-timeout 3 "http://127.0.0.1:${svc_port}/api/home" &>/dev/null; then
                    health="${GREEN}ok${RESET}"
                elif [[ "$status" == "running" ]]; then
                    health="${YELLOW}?${RESET}"
                fi
                ;;
        esac

        printf "  │ %-30s ${status_color}%-12s${RESET} %-12b │\n" \
            "$svc_label" "$status" "$health"
    done

    printf "  ├%s┤\n" "$hline"

    # Disk usage
    local disk_info
    disk_info="$(df -h "${INSTALL_DIR:-/opt/openanime}" 2>/dev/null | tail -1 | awk '{print $3"/"$2" ("$5" used)"}')"
    printf "  │ %-20s %-36s │\n" "Disk:" "${disk_info:-unknown}"

    # Memory
    local mem_info
    mem_info="$(free -h 2>/dev/null | awk '/^Mem:/{print $3"/"$2" used"}')"
    printf "  │ %-20s %-36s │\n" "Memory:" "${mem_info:-unknown}"

    # Uptime
    local uptime_info
    uptime_info="$(uptime -p 2>/dev/null || uptime | sed 's/.*up/up/')"
    printf "  │ %-20s %-36s │\n" "Uptime:" "${uptime_info:-unknown}"

    printf "  └%s┘\n\n" "$hline"
}
