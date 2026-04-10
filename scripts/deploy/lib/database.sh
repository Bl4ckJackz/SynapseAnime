#!/usr/bin/env bash
# =============================================================================
# database.sh - PostgreSQL installation and setup for SynapseAnime
# =============================================================================
# Provides: install_database() which installs PostgreSQL 16 (unless external),
# creates the application role and database, and configures local access.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# install_database - Install and configure PostgreSQL for SynapseAnime.
# ---------------------------------------------------------------------------
# Globals used: DB_EXTERNAL, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD,
#               DRY_RUN, OS_CODENAME
# Side effects: installs PostgreSQL 16, creates role/db, modifies pg_hba.conf
install_database() {
    log_section "PostgreSQL Database"

    # Skip if using external database
    if [[ "$DB_EXTERNAL" == "true" ]]; then
        log_skip "Using external PostgreSQL at ${DB_HOST}:${DB_PORT}"
        log_info "Ensure database '${DB_NAME}' and user '${DB_USER}' exist on the external server."
        return 0
    fi

    # Install PostgreSQL 16 if not present
    if ! command -v psql &>/dev/null || ! psql --version 2>/dev/null | grep -q "16"; then
        log_info "Installing PostgreSQL 16..."

        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "[DRY] Would install PostgreSQL 16"
        else
            # Add PostgreSQL APT repository
            run_cmd "Adding PostgreSQL APT repository" \
                "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg"

            echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt ${OS_CODENAME}-pgdg main" \
                > /etc/apt/sources.list.d/pgdg.list

            run_cmd "Updating package lists" "apt-get update -qq"
            run_cmd "Installing PostgreSQL 16" \
                "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq postgresql-16"
        fi
    else
        log_ok "PostgreSQL 16 already installed"
    fi

    # Ensure service is running
    if [[ "$DRY_RUN" != "true" ]]; then
        run_cmd "Starting PostgreSQL service" "systemctl enable --now postgresql"

        # Wait for PostgreSQL to be ready (up to 30 seconds)
        log_info "Waiting for PostgreSQL to become ready..."
        local attempts=0
        local max_attempts=30
        while ! pg_isready -q -h localhost -p "$DB_PORT" 2>/dev/null; do
            attempts=$((attempts + 1))
            if [[ $attempts -ge $max_attempts ]]; then
                log_fail "PostgreSQL did not become ready within ${max_attempts}s"
                return 1
            fi
            sleep 1
        done
        log_ok "PostgreSQL is ready"
    fi

    # Create role if it doesn't exist
    log_info "Configuring database role '${DB_USER}'..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would create role $DB_USER and database $DB_NAME"
    else
        local role_exists
        role_exists="$(su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'\"" 2>/dev/null || echo "")"

        if [[ "$role_exists" != "1" ]]; then
            su - postgres -c "psql -c \"CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';\"" 2>/dev/null
            log_ok "Created database role '${DB_USER}'"
        else
            # Update password on existing role
            su - postgres -c "psql -c \"ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';\"" 2>/dev/null
            log_ok "Updated password for existing role '${DB_USER}'"
        fi

        # Create database if it doesn't exist
        local db_exists
        db_exists="$(su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'\"" 2>/dev/null || echo "")"

        if [[ "$db_exists" != "1" ]]; then
            su - postgres -c "psql -c \"CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};\"" 2>/dev/null
            log_ok "Created database '${DB_NAME}'"
        else
            log_ok "Database '${DB_NAME}' already exists"
        fi
    fi

    # Configure pg_hba.conf for local MD5 access
    _configure_pg_hba
}

# ---------------------------------------------------------------------------
# _configure_pg_hba - Ensure pg_hba.conf allows local password auth.
# ---------------------------------------------------------------------------
# Adds a line for the DB_USER to connect to DB_NAME via md5.
# Globals used: DB_USER, DB_NAME, DRY_RUN
# Side effects: may modify pg_hba.conf and restart PostgreSQL
_configure_pg_hba() {
    local pg_hba
    pg_hba="$(find /etc/postgresql -name pg_hba.conf -path "*/16/*" 2>/dev/null | head -1)"

    if [[ -z "$pg_hba" ]]; then
        log_warn "Could not locate pg_hba.conf for PostgreSQL 16"
        return 0
    fi

    local hba_entry="local   ${DB_NAME}   ${DB_USER}   md5"
    local host_entry="host    ${DB_NAME}   ${DB_USER}   127.0.0.1/32   md5"

    if grep -qF "$DB_USER" "$pg_hba" 2>/dev/null; then
        log_ok "pg_hba.conf already contains entry for '${DB_USER}'"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would add $DB_USER entries to $pg_hba"
        return 0
    fi

    log_info "Configuring pg_hba.conf for '${DB_USER}'..."
    backup_file "$pg_hba"

    # Insert before the first "local all all" line
    {
        echo "# SynapseAnime application access"
        echo "$hba_entry"
        echo "$host_entry"
    } | sed -i "/^local\s\+all\s\+all/i # --- inserted by SynapseAnime installer ---" "$pg_hba" 2>/dev/null || true

    # Append if sed insertion didn't work (fallback)
    if ! grep -qF "$DB_USER" "$pg_hba" 2>/dev/null; then
        printf '\n# SynapseAnime application access\n%s\n%s\n' "$hba_entry" "$host_entry" >> "$pg_hba"
    fi

    run_cmd "Restarting PostgreSQL (pg_hba.conf changed)" "systemctl restart postgresql"
    log_ok "pg_hba.conf configured for '${DB_USER}'"
}
