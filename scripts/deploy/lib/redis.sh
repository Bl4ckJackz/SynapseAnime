#!/usr/bin/env bash
# =============================================================================
# redis.sh - Redis installation and setup for SynapseAnime
# =============================================================================
# Provides: install_redis() which installs Redis, configures bind address
# and optional password, then enables the service.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# install_redis - Install and configure Redis for SynapseAnime.
# ---------------------------------------------------------------------------
# Globals used: REDIS_EXTERNAL, REDIS_HOST, REDIS_PORT, REDIS_PASSWORD, DRY_RUN
# Side effects: installs redis-server, modifies redis.conf, starts service
install_redis() {
    log_section "Redis Cache"

    # Skip if using external Redis
    if [[ "$REDIS_EXTERNAL" == "true" ]]; then
        log_skip "Using external Redis at ${REDIS_HOST}:${REDIS_PORT}"
        return 0
    fi

    # Install redis-server if not present
    if ! command -v redis-server &>/dev/null; then
        log_info "Installing Redis..."
        run_cmd "Installing redis-server" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq redis-server"
    else
        log_ok "Redis already installed"
    fi

    # Configure Redis
    local redis_conf="/etc/redis/redis.conf"
    if [[ -f "$redis_conf" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "[DRY] Would configure $redis_conf"
        else
            backup_file "$redis_conf"

            # Bind to localhost only
            sed -i 's/^bind .*/bind 127.0.0.1 ::1/' "$redis_conf"
            log_debug "Set Redis bind to 127.0.0.1"

            # Set port
            sed -i "s/^port .*/port ${REDIS_PORT}/" "$redis_conf"
            log_debug "Set Redis port to ${REDIS_PORT}"

            # Set password if provided
            if [[ -n "$REDIS_PASSWORD" ]]; then
                # Remove existing requirepass lines
                sed -i '/^requirepass /d' "$redis_conf"
                echo "requirepass ${REDIS_PASSWORD}" >> "$redis_conf"
                log_debug "Set Redis password"
            fi

            log_ok "Redis configured"
        fi
    else
        log_warn "Redis config not found at $redis_conf. Using defaults."
    fi

    # Enable and start service
    if [[ "$DRY_RUN" != "true" ]]; then
        run_cmd "Enabling and starting Redis" "systemctl enable --now redis-server"
        log_ok "Redis is running on port ${REDIS_PORT}"
    fi
}
