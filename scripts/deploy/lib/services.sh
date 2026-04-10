#!/usr/bin/env bash
# =============================================================================
# services.sh - Systemd service management for SynapseAnime
# =============================================================================
# Provides: setup_services() which creates systemd unit files from templates,
# configures logrotate, reloads systemd, enables and starts all services.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# Service unit names
# ---------------------------------------------------------------------------
readonly SERVICES=(
    openanime-backend
    openanime-web
    openanime-consumet
    openanime-mangahook
)

# ---------------------------------------------------------------------------
# setup_services - Create, enable, and start all systemd services.
# ---------------------------------------------------------------------------
# Globals used: INSTALL_DIR, LOG_DIR, NODE_BIN, NPX_BIN, WEB_PORT,
#               API_PORT, CONSUMET_PORT, MANGAHOOK_PORT, ENABLE_LOGROTATE,
#               SCRIPT_DIR, DRY_RUN, SYSTEMD_AFTER
# Side effects: creates systemd units, logrotate config, starts services
setup_services() {
    log_section "Systemd Services"

    # Export all variables needed by templates
    export INSTALL_DIR LOG_DIR NODE_BIN NPX_BIN
    export WEB_PORT API_PORT CONSUMET_PORT MANGAHOOK_PORT
    export SYSTEMD_AFTER

    # Resolve NODE_BIN and NPX_BIN if not set
    NODE_BIN="${NODE_BIN:-$(command -v node 2>/dev/null || echo "/usr/bin/node")}"
    NPX_BIN="${NPX_BIN:-$(command -v npx 2>/dev/null || echo "/usr/bin/npx")}"
    export NODE_BIN NPX_BIN

    # Create log directory
    ensure_dir "$LOG_DIR" "openanime:openanime"

    # Render and install each service unit
    local template_dir="${SCRIPT_DIR}/configs/systemd"
    local unit_dir="/etc/systemd/system"

    for svc in "${SERVICES[@]}"; do
        local template="${template_dir}/${svc}.service"
        local target="${unit_dir}/${svc}.service"

        if [[ ! -f "$template" ]]; then
            log_fail "Service template not found: $template"
            return 1
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "[DRY] Would render $template -> $target"
            continue
        fi

        # Backup existing unit if present
        [[ -f "$target" ]] && backup_file "$target"

        template_render "$template" "$target"
        log_ok "Created systemd unit: $svc"
    done

    # Configure logrotate
    if [[ "$ENABLE_LOGROTATE" == "true" ]]; then
        _setup_logrotate
    else
        log_skip "Logrotate disabled"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would daemon-reload, enable, and start services"
        return 0
    fi

    # Reload systemd
    run_cmd "Reloading systemd daemon" "systemctl daemon-reload"

    # Enable and start services in order
    _enable_and_start_services

    log_ok "All services configured and started"
}

# ---------------------------------------------------------------------------
# _setup_logrotate - Install logrotate configuration from template.
# ---------------------------------------------------------------------------
# Globals used: LOG_DIR, SCRIPT_DIR, DRY_RUN
# Side effects: renders logrotate config to /etc/logrotate.d/openanime
_setup_logrotate() {
    local template="${SCRIPT_DIR}/configs/logrotate/openanime"
    local target="/etc/logrotate.d/openanime"

    if [[ ! -f "$template" ]]; then
        log_warn "Logrotate template not found: $template"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would render logrotate config"
        return 0
    fi

    export LOG_DIR
    template_render "$template" "$target"
    log_ok "Configured logrotate at $target"
}

# ---------------------------------------------------------------------------
# _enable_and_start_services - Enable and start each service in order.
# ---------------------------------------------------------------------------
# Start order: backend first (other services may depend on it), then web,
# then consumet and mangahook.
# Globals used: DRY_RUN
# Side effects: enables and starts systemd services
_enable_and_start_services() {
    local ordered_services=(
        openanime-consumet
        openanime-mangahook
        openanime-backend
        openanime-web
    )

    for svc in "${ordered_services[@]}"; do
        run_cmd "Enabling ${svc}" "systemctl enable ${svc}"
    done

    # Start in order with small delays for dependency readiness
    for svc in "${ordered_services[@]}"; do
        run_cmd "Starting ${svc}" "systemctl start ${svc}"

        # Give the service a moment to initialize
        sleep 2

        # Check if it's running
        if systemctl is-active --quiet "$svc"; then
            log_ok "${svc} is running"
        else
            log_warn "${svc} may not have started correctly"
            log_debug "Check: journalctl -u ${svc} --no-pager -n 20"
        fi
    done
}

# ---------------------------------------------------------------------------
# stop_all_services - Stop all SynapseAnime services (reverse order).
# ---------------------------------------------------------------------------
# Used by uninstall and update operations.
stop_all_services() {
    log_info "Stopping all SynapseAnime services..."

    local reverse_order=(
        openanime-web
        openanime-backend
        openanime-mangahook
        openanime-consumet
    )

    for svc in "${reverse_order[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            run_cmd "Stopping ${svc}" "systemctl stop ${svc}"
        else
            log_debug "${svc} is not running"
        fi
    done
}

# ---------------------------------------------------------------------------
# restart_service NAME - Restart a single service.
# ---------------------------------------------------------------------------
# Arguments:
#   NAME - systemd unit name (without .service)
restart_service() {
    local name="$1"
    run_cmd "Restarting ${name}" "systemctl restart ${name}"

    sleep 2
    if systemctl is-active --quiet "$name"; then
        log_ok "${name} restarted successfully"
    else
        log_warn "${name} may not have restarted correctly"
    fi
}

# ---------------------------------------------------------------------------
# restart_all_services - Restart all SynapseAnime services in order.
# ---------------------------------------------------------------------------
restart_all_services() {
    log_info "Restarting all SynapseAnime services..."

    stop_all_services
    _enable_and_start_services
}

# ---------------------------------------------------------------------------
# remove_services - Disable and remove all systemd units.
# ---------------------------------------------------------------------------
# Used by --uninstall.
remove_services() {
    log_info "Removing SynapseAnime systemd services..."

    for svc in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" 2>/dev/null || true
        fi
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            systemctl disable "$svc" 2>/dev/null || true
        fi
        rm -f "/etc/systemd/system/${svc}.service"
        log_debug "Removed ${svc}"
    done

    systemctl daemon-reload
    log_ok "All SynapseAnime services removed"

    # Remove logrotate config
    rm -f /etc/logrotate.d/openanime
}
