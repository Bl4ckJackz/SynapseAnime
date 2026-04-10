#!/usr/bin/env bash
# =============================================================================
# install.sh - SynapseAnime Bare-Metal Installer (Orchestrator)
# =============================================================================
# Main entry point for the SynapseAnime deploy system.
# Sources all lib/ modules and drives the installation flow:
#   banner -> parse_args -> detect_update_mode -> config phase ->
#   preflight -> steps -> save_credentials -> smoke -> summary
#
# Usage: sudo bash install.sh [OPTIONS]
#   --conf FILE         Load config from file
#   --non-interactive   Use defaults, auto-generate secrets
#   --dry-run           Show what would be done without doing it
#   --skip STEP         Skip a step (repeatable)
#   --only STEP         Run only this step (repeatable)
#   --verbose           Enable debug logging
#   --no-color          Disable colored output
#   --uninstall         Remove SynapseAnime installation
#   --status            Show service status dashboard
#   --help              Show usage information
#
# Valid steps: database, redis, nodejs, backend, web, consumet, mangahook,
#              nginx, services, smoke
# =============================================================================

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
INSTALLER_VERSION="1.0"
VALID_STEPS="database redis nodejs backend web consumet mangahook nginx services smoke"
CREDENTIALS_FILE="/root/.synapseanime-credentials"
INSTALL_DIR="${INSTALL_DIR:-/opt/openanime}"

# ---------------------------------------------------------------------------
# Resolve script directory and source modules
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first (sets up logging, error trap, etc.)
source "${SCRIPT_DIR}/lib/common.sh"

# Source all other modules
source "${SCRIPT_DIR}/lib/checks.sh"
source "${SCRIPT_DIR}/lib/tui.sh"
source "${SCRIPT_DIR}/lib/database.sh"
source "${SCRIPT_DIR}/lib/redis.sh"
source "${SCRIPT_DIR}/lib/nodejs.sh"
source "${SCRIPT_DIR}/lib/backend.sh"
source "${SCRIPT_DIR}/lib/web.sh"
source "${SCRIPT_DIR}/lib/consumet.sh"
source "${SCRIPT_DIR}/lib/mangahook.sh"
source "${SCRIPT_DIR}/lib/nginx.sh"
source "${SCRIPT_DIR}/lib/services.sh"
source "${SCRIPT_DIR}/lib/update.sh"
source "${SCRIPT_DIR}/lib/smoke.sh"

# ---------------------------------------------------------------------------
# CLI state
# ---------------------------------------------------------------------------
CONF_FILE=""
NON_INTERACTIVE="false"
DRY_RUN="false"
VERBOSE="false"
NO_COLOR="false"
DO_UNINSTALL="false"
DO_STATUS="false"
declare -a SKIP_STEPS=()
declare -a ONLY_STEPS=()

# ---------------------------------------------------------------------------
# show_banner - Print ASCII art banner.
# ---------------------------------------------------------------------------
show_banner() {
    printf "${CYAN}"
    cat <<'BANNER'

  ╔═╗┬ ┬┌┐┌┌─┐┌─┐┌─┐┌─┐
  ╚═╗└┬┘│││├─┤├─┘└─┐├┤
  ╚═╝ ┴ ┘└┘┴ ┴┴  └─┘└─┘
  Bare-Metal Installer v1.0

BANNER
    printf "${RESET}"
}

# ---------------------------------------------------------------------------
# show_help - Print usage information.
# ---------------------------------------------------------------------------
show_help() {
    cat <<HELP
SynapseAnime Bare-Metal Installer v${INSTALLER_VERSION}

Usage: sudo bash install.sh [OPTIONS]

Options:
  --conf FILE         Load configuration from file
  --non-interactive   Use defaults, auto-generate secrets (no TUI)
  --dry-run           Show what would be done without executing
  --skip STEP         Skip a step (can be repeated)
  --only STEP         Run only specified step(s) (can be repeated)
  --verbose           Enable debug logging
  --no-color          Disable colored output
  --uninstall         Remove SynapseAnime installation
  --status            Show service status dashboard
  --help              Show this help message

Valid steps:
  database    Install and configure PostgreSQL
  redis       Install and configure Redis
  nodejs      Install Node.js 20
  backend     Build and install NestJS backend
  web         Build and install Next.js frontend
  consumet    Install Consumet API
  mangahook   Install MangaHook API
  nginx       Configure Nginx reverse proxy
  services    Create and start systemd services
  smoke       Run smoke tests

Examples:
  sudo bash install.sh                          # Interactive install
  sudo bash install.sh --non-interactive        # Automated install with defaults
  sudo bash install.sh --conf deploy.conf       # Install from config file
  sudo bash install.sh --only backend --only web  # Rebuild only backend and web
  sudo bash install.sh --skip database --skip redis  # Skip DB and Redis
  sudo bash install.sh --dry-run --verbose      # Preview with debug output
  sudo bash install.sh --status                 # Check service status
  sudo bash install.sh --uninstall              # Remove installation

HELP
}

# ---------------------------------------------------------------------------
# parse_args - Parse command-line arguments.
# ---------------------------------------------------------------------------
# Sets: CONF_FILE, NON_INTERACTIVE, DRY_RUN, VERBOSE, NO_COLOR,
#       DO_UNINSTALL, DO_STATUS, SKIP_STEPS, ONLY_STEPS
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --conf)
                shift
                CONF_FILE="${1:-}"
                if [[ -z "$CONF_FILE" ]]; then
                    log_fail "--conf requires a file path"
                    exit 1
                fi
                ;;
            --non-interactive)
                NON_INTERACTIVE="true"
                ;;
            --dry-run)
                DRY_RUN="true"
                ;;
            --skip)
                shift
                local step="${1:-}"
                if [[ -z "$step" ]] || ! _valid_step "$step"; then
                    log_fail "--skip requires a valid step: $VALID_STEPS"
                    exit 1
                fi
                SKIP_STEPS+=("$step")
                ;;
            --only)
                shift
                local step="${1:-}"
                if [[ -z "$step" ]] || ! _valid_step "$step"; then
                    log_fail "--only requires a valid step: $VALID_STEPS"
                    exit 1
                fi
                ONLY_STEPS+=("$step")
                ;;
            --verbose)
                VERBOSE="true"
                ;;
            --no-color)
                NO_COLOR="true"
                _apply_no_color
                ;;
            --uninstall)
                DO_UNINSTALL="true"
                ;;
            --status)
                DO_STATUS="true"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_fail "Unknown option: $1"
                log_info "Run with --help for usage information"
                exit 1
                ;;
        esac
        shift
    done

    # Export flags for submodules
    export DRY_RUN VERBOSE NO_COLOR NON_INTERACTIVE
}

# ---------------------------------------------------------------------------
# _valid_step NAME - Check if a step name is valid.
# ---------------------------------------------------------------------------
# Returns: 0 if valid, 1 if not
_valid_step() {
    local name="$1"
    for valid in $VALID_STEPS; do
        [[ "$valid" == "$name" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# _should_run_step NAME - Check if a step should be executed.
# ---------------------------------------------------------------------------
# Considers --skip and --only flags.
# Returns: 0 if should run, 1 if should skip
_should_run_step() {
    local name="$1"

    # If --only is specified, only run those steps
    if [[ ${#ONLY_STEPS[@]} -gt 0 ]]; then
        for only in "${ONLY_STEPS[@]}"; do
            [[ "$only" == "$name" ]] && return 0
        done
        return 1
    fi

    # Check --skip
    for skip in "${SKIP_STEPS[@]}"; do
        [[ "$skip" == "$name" ]] && return 1
    done

    return 0
}

# ---------------------------------------------------------------------------
# do_uninstall - Remove SynapseAnime installation.
# ---------------------------------------------------------------------------
do_uninstall() {
    log_section "Uninstall SynapseAnime"

    if ! confirm_action "This will remove SynapseAnime and all its data. Continue?"; then
        log_info "Uninstall cancelled."
        exit 0
    fi

    # Stop and remove services
    remove_services

    # Remove nginx config
    rm -f /etc/nginx/sites-enabled/synapseanime.conf
    rm -f /etc/nginx/sites-available/synapseanime.conf
    systemctl reload nginx 2>/dev/null || true

    # Remove logrotate
    rm -f /etc/logrotate.d/openanime

    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        if confirm_action "Remove installation directory ${INSTALL_DIR}?"; then
            rm -rf "$INSTALL_DIR"
            log_ok "Removed $INSTALL_DIR"
        fi
    fi

    # Remove log directory
    if [[ -d "${LOG_DIR:-/var/log/openanime}" ]]; then
        rm -rf "${LOG_DIR:-/var/log/openanime}"
        log_ok "Removed log directory"
    fi

    # Remove credentials file
    rm -f "$CREDENTIALS_FILE"

    # Remove system user
    if id -u openanime &>/dev/null; then
        if confirm_action "Remove system user 'openanime'?"; then
            userdel openanime 2>/dev/null || true
            log_ok "Removed system user 'openanime'"
        fi
    fi

    log_ok "SynapseAnime has been uninstalled"
}

# ---------------------------------------------------------------------------
# save_credentials - Write credentials to secure file.
# ---------------------------------------------------------------------------
# Saves database and JWT credentials to CREDENTIALS_FILE with 600 perms.
save_credentials() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would save credentials to $CREDENTIALS_FILE"
        return 0
    fi

    cat > "$CREDENTIALS_FILE" <<CREDS
# SynapseAnime Credentials
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# WARNING: Keep this file secure!

DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
REDIS_PASSWORD=${REDIS_PASSWORD}
CREDS

    chmod 600 "$CREDENTIALS_FILE"
    log_ok "Credentials saved to $CREDENTIALS_FILE (mode 600)"
}

# ---------------------------------------------------------------------------
# show_summary - Print installation summary.
# ---------------------------------------------------------------------------
show_summary() {
    local elapsed=""
    if [[ -n "${START_EPOCH:-}" ]]; then
        local end_epoch
        end_epoch="$(date +%s)"
        local secs=$((end_epoch - START_EPOCH))
        elapsed="$(printf '%dm %ds' $((secs / 60)) $((secs % 60)))"
    fi

    printf "\n"
    log_section "Installation Complete"

    printf "${GREEN}"
    cat <<'DONE'
  ╔═══════════════════════════════════════════╗
  ║   SynapseAnime is ready!                  ║
  ╚═══════════════════════════════════════════╝
DONE
    printf "${RESET}\n"

    log_info "Domain:       ${DOMAIN}"
    log_info "Install dir:  ${INSTALL_DIR}"
    log_info "Log dir:      ${LOG_DIR}"
    log_info "Credentials:  ${CREDENTIALS_FILE}"
    [[ -n "$elapsed" ]] && log_info "Duration:     ${elapsed}"

    printf "\n"
    log_info "Services:"
    log_info "  Backend API:  http://127.0.0.1:${API_PORT}"
    log_info "  Web Frontend: http://127.0.0.1:${WEB_PORT}"
    log_info "  Consumet API: http://127.0.0.1:${CONSUMET_PORT}"
    log_info "  MangaHook:    http://127.0.0.1:${MANGAHOOK_PORT}"

    if [[ "$NGINX_EXTERNAL" != "true" ]]; then
        log_info "  Nginx:        http://${DOMAIN}"
    fi

    printf "\n"
    log_info "Manage services:"
    log_info "  sudo systemctl status openanime-backend"
    log_info "  sudo systemctl restart openanime-web"
    log_info "  sudo bash ${SCRIPT_DIR}/install.sh --status"
    printf "\n"
}

# ---------------------------------------------------------------------------
# Main execution flow
# ---------------------------------------------------------------------------
main() {
    # Record start time
    local START_EPOCH
    START_EPOCH="$(date +%s)"

    # Strip Windows CR from all scripts
    _strip_cr 2>/dev/null || true

    # Banner
    show_banner

    # Parse arguments
    parse_args "$@"

    # Handle --status
    if [[ "$DO_STATUS" == "true" ]]; then
        set_defaults
        # Try to load existing config for port info
        for conf in "${INSTALL_DIR}/deploy.conf" "/root/.synapseanime-deploy.conf"; do
            [[ -f "$conf" ]] && load_deploy_conf "$conf" && break
        done
        show_service_status
        exit 0
    fi

    # Handle --uninstall
    if [[ "$DO_UNINSTALL" == "true" ]]; then
        set_defaults
        do_uninstall
        exit 0
    fi

    # Set defaults first
    set_defaults

    # Detect update mode
    detect_update_mode

    # Configuration phase
    if [[ -n "$CONF_FILE" ]]; then
        # Load from config file
        load_deploy_conf "$CONF_FILE"
    elif [[ "$UPDATE_MODE" == "true" ]] && [[ -n "$EXISTING_CONF" ]]; then
        # Update mode: merge existing config with new defaults
        merge_new_defaults
    elif [[ "$NON_INTERACTIVE" == "true" ]]; then
        # Non-interactive: auto-generate secrets
        DB_PASSWORD="$(gen_password 32)"
        JWT_SECRET="$(gen_password 48)"
        log_ok "Using default configuration with auto-generated secrets"
    else
        # Interactive TUI wizard
        run_tui_wizard
    fi

    # Export all config vars for envsubst
    export DOMAIN WEB_PORT API_PORT HTTP_PORT
    export DB_EXTERNAL DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
    export REDIS_EXTERNAL REDIS_HOST REDIS_PORT REDIS_PASSWORD
    export JWT_SECRET JWT_EXPIRES_IN CORS_ORIGINS
    export CONSUMET_PORT MANGAHOOK_PORT
    export INSTALL_DIR LOG_DIR
    export NGINX_EXTERNAL ENABLE_LOGROTATE ENABLE_UFW
    export NEXT_PUBLIC_API_URL NODE_BIN NPX_BIN SYSTEMD_AFTER
    export DEPLOY_SOURCE GIT_REPO GIT_BRANCH

    # Pre-flight checks (always run unless --only is set)
    if [[ ${#ONLY_STEPS[@]} -eq 0 ]]; then
        run_preflight
    fi

    # Update mode: scan for changes
    if [[ "$UPDATE_MODE" == "true" ]]; then
        scan_update_changes
        if [[ ${#UPDATE_ACTIONS[@]} -eq 0 ]] && [[ ${#ONLY_STEPS[@]} -eq 0 ]]; then
            log_ok "Nothing to update."
            show_service_status
            exit 0
        fi
        show_update_summary || { log_info "Update cancelled."; exit 0; }
    fi

    # Installation steps
    if _should_run_step "nodejs"; then
        install_nodejs
    else
        log_skip "Node.js installation"
        # Still resolve paths
        NODE_BIN="$(command -v node 2>/dev/null || echo "/usr/bin/node")"
        NPX_BIN="$(command -v npx 2>/dev/null || echo "/usr/bin/npx")"
        export NODE_BIN NPX_BIN
    fi

    if _should_run_step "database"; then
        install_database
    else
        log_skip "Database setup"
    fi

    if _should_run_step "redis"; then
        install_redis
    else
        log_skip "Redis setup"
    fi

    if _should_run_step "backend"; then
        install_backend
    else
        log_skip "Backend installation"
    fi

    if _should_run_step "web"; then
        install_web
    else
        log_skip "Web frontend installation"
    fi

    if _should_run_step "consumet"; then
        install_consumet
    else
        log_skip "Consumet API installation"
    fi

    if _should_run_step "mangahook"; then
        install_mangahook
    else
        log_skip "MangaHook API installation"
    fi

    if _should_run_step "nginx"; then
        install_nginx_proxy
    else
        log_skip "Nginx configuration"
    fi

    if _should_run_step "services"; then
        setup_services
    else
        log_skip "Service setup"
    fi

    # Save credentials
    save_credentials

    # Save deploy config
    save_deploy_conf "${INSTALL_DIR}/deploy.conf"

    # Save hashes for future update detection
    save_hashes

    # Smoke tests
    if _should_run_step "smoke"; then
        run_smoke_tests || true  # Don't fail install on smoke test failure
    else
        log_skip "Smoke tests"
    fi

    # Summary
    show_summary
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
main "$@"
