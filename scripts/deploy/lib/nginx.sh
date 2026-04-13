#!/usr/bin/env bash
# =============================================================================
# nginx.sh - Nginx reverse proxy setup for SynapseAnime
# =============================================================================
# Provides: install_nginx_proxy() which installs Nginx, renders the site
# config from template, enables the site, tests config, reloads, and
# optionally configures UFW firewall rules.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# install_nginx_proxy - Install and configure Nginx as reverse proxy.
# ---------------------------------------------------------------------------
# Globals used: NGINX_EXTERNAL, SCRIPT_DIR, DOMAIN, WEB_PORT, API_PORT,
#               HTTP_PORT, LOG_DIR, ENABLE_UFW, DRY_RUN
# Side effects: installs nginx, renders config, reloads, optional UFW rules
install_nginx_proxy() {
    log_section "Nginx Reverse Proxy"

    # Skip if external
    if [[ "$NGINX_EXTERNAL" == "true" ]]; then
        log_skip "Nginx managed externally"
        log_info "Configure your external Nginx to proxy:"
        log_info "  / -> http://127.0.0.1:${WEB_PORT}"
        log_info "  /api -> http://127.0.0.1:${API_PORT}"
        return 0
    fi

    # Install nginx if not present
    if ! command -v nginx &>/dev/null; then
        log_info "Installing Nginx..."
        run_cmd "Installing nginx" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx"
    else
        log_ok "Nginx already installed"
    fi

    # Render config from template
    local template="${SCRIPT_DIR}/configs/nginx/synapseanime.conf"
    local target="/etc/nginx/sites-available/synapseanime.conf"
    local enabled="/etc/nginx/sites-enabled/synapseanime.conf"

    if [[ ! -f "$template" ]]; then
        log_fail "Nginx template not found: $template"
        return 1
    fi

    # Export variables for envsubst
    export DOMAIN WEB_PORT API_PORT HTTP_PORT LOG_DIR

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would render $template -> $target"
    else
        # Backup existing config if present
        [[ -f "$target" ]] && backup_file "$target"

        # Whitelist only our vars — leave $host, $remote_addr etc. for nginx
        template_render "$template" "$target" '${DOMAIN} ${WEB_PORT} ${API_PORT} ${HTTP_PORT} ${LOG_DIR}'
        log_ok "Rendered Nginx config to $target"

        # Disable default site if present
        if [[ -L "/etc/nginx/sites-enabled/default" ]]; then
            rm -f "/etc/nginx/sites-enabled/default"
            log_debug "Disabled default Nginx site"
        fi

        # Enable site
        if [[ ! -L "$enabled" ]]; then
            ln -sf "$target" "$enabled"
            log_debug "Enabled synapseanime site"
        fi

        # Test configuration
        run_cmd "Testing Nginx configuration" "nginx -t 2>&1"

        # Reload Nginx
        run_cmd "Reloading Nginx" "systemctl reload nginx"

        log_ok "Nginx configured and reloaded"
    fi

    # UFW firewall rules
    _configure_ufw
}

# ---------------------------------------------------------------------------
# _configure_ufw - Optionally configure UFW firewall rules.
# ---------------------------------------------------------------------------
# Globals used: ENABLE_UFW, HTTP_PORT, DRY_RUN
# Side effects: adds UFW allow rules for HTTP, HTTPS, SSH
_configure_ufw() {
    if [[ "$ENABLE_UFW" != "true" ]]; then
        log_debug "UFW configuration skipped (ENABLE_UFW=false)"
        return 0
    fi

    if ! command -v ufw &>/dev/null; then
        log_warn "UFW not installed, skipping firewall configuration"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would configure UFW rules"
        return 0
    fi

    log_info "Configuring UFW firewall rules..."

    # Allow SSH first (safety)
    run_cmd "UFW: Allow SSH" "ufw allow ssh"
    run_cmd "UFW: Allow HTTP (${HTTP_PORT})" "ufw allow ${HTTP_PORT}/tcp"
    run_cmd "UFW: Allow HTTPS" "ufw allow 443/tcp"

    # Enable UFW if not already active
    if ! ufw status | grep -q "Status: active"; then
        run_cmd "Enabling UFW" "echo 'y' | ufw enable"
    fi

    log_ok "UFW configured: SSH, HTTP ($HTTP_PORT), HTTPS allowed"
}
