#!/usr/bin/env bash
# =============================================================================
# nodejs.sh - Node.js installation for SynapseAnime
# =============================================================================
# Provides: install_nodejs() which installs Node.js 20 via NodeSource,
# upgrades npm if needed, and exports NODE_BIN / NPX_BIN paths.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# install_nodejs - Install Node.js 20 LTS and ensure npm is up to date.
# ---------------------------------------------------------------------------
# Globals used: DRY_RUN
# Globals set: NODE_BIN, NPX_BIN
# Side effects: installs Node.js 20 via NodeSource, upgrades npm
install_nodejs() {
    log_section "Node.js Runtime"

    local need_install=false
    local current_major=0

    if command -v node &>/dev/null; then
        current_major="$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)"
        if [[ "$current_major" -lt 20 ]]; then
            log_warn "Node.js v${current_major} found, but v20+ is required"
            need_install=true
        else
            log_ok "Node.js $(node -v) already installed"
        fi
    else
        log_info "Node.js not found"
        need_install=true
    fi

    if [[ "$need_install" == "true" ]]; then
        log_info "Installing Node.js 20 via NodeSource..."

        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "[DRY] Would install Node.js 20"
        else
            run_cmd "Downloading NodeSource setup script" \
                "curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh"
            run_cmd "Running NodeSource setup" \
                "bash /tmp/nodesource_setup.sh"
            run_cmd "Installing Node.js 20" \
                "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs"
            rm -f /tmp/nodesource_setup.sh
        fi
    fi

    # Upgrade npm if below 10
    if [[ "$DRY_RUN" != "true" ]] && command -v npm &>/dev/null; then
        local npm_major
        npm_major="$(npm -v 2>/dev/null | cut -d. -f1)"
        if [[ "$npm_major" -lt 10 ]]; then
            log_info "Upgrading npm (current: $(npm -v))..."
            run_cmd "Upgrading npm to latest" "npm install -g npm@latest"
        else
            log_ok "npm $(npm -v) is up to date"
        fi
    fi

    # Resolve and export paths
    NODE_BIN="$(command -v node 2>/dev/null || echo "/usr/bin/node")"
    NPX_BIN="$(command -v npx 2>/dev/null || echo "/usr/bin/npx")"
    export NODE_BIN NPX_BIN

    if [[ "$DRY_RUN" != "true" ]]; then
        log_ok "Node.js: $(node -v) | npm: $(npm -v)"
        log_debug "NODE_BIN=$NODE_BIN  NPX_BIN=$NPX_BIN"
    fi
}
