#!/usr/bin/env bash
# =============================================================================
# update.sh - Smart update detection and management for SynapseAnime
# =============================================================================
# Provides: detect_update_mode(), merge_new_defaults(), scan_update_changes(),
# show_update_summary(), confirm_config_overwrite(), and helpers for detecting
# changes in git, npm deps, frontend/backend code, and config files.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# Update state
# ---------------------------------------------------------------------------
# Array of planned update actions (populated by scan_update_changes)
declare -a UPDATE_ACTIONS=()

# Hashes file for tracking dependency changes between updates
HASHES_FILE="${INSTALL_DIR:=/opt/openanime}/.deploy-hashes"

# ---------------------------------------------------------------------------
# detect_update_mode - Check if this is a fresh install or an update.
# ---------------------------------------------------------------------------
# Looks for existing deploy.conf and installed services.
# Sets globals: UPDATE_MODE, EXISTING_CONF
# Returns: 0 always
detect_update_mode() {
    UPDATE_MODE="false"
    EXISTING_CONF=""

    # Check for deploy.conf in standard locations
    local conf_locations=(
        "${INSTALL_DIR}/deploy.conf"
        "/root/.synapseanime-deploy.conf"
        "${INSTALL_DIR}/.deploy.conf"
    )

    for conf in "${conf_locations[@]}"; do
        if [[ -f "$conf" ]]; then
            EXISTING_CONF="$conf"
            UPDATE_MODE="true"
            log_info "Existing installation detected (config: $conf)"
            break
        fi
    done

    # Also check for systemd services as a fallback
    if [[ "$UPDATE_MODE" == "false" ]]; then
        if systemctl list-unit-files 2>/dev/null | grep -q "openanime-backend"; then
            UPDATE_MODE="true"
            log_info "Existing installation detected (systemd services found)"
        fi
    fi

    export UPDATE_MODE EXISTING_CONF

    if [[ "$UPDATE_MODE" == "true" ]]; then
        log_info "Running in UPDATE mode"
    else
        log_info "Running in FRESH INSTALL mode"
    fi
}

# ---------------------------------------------------------------------------
# merge_new_defaults - Load existing config, then apply new defaults.
# ---------------------------------------------------------------------------
# Sources the existing config first, then calls set_defaults() which only
# sets variables that are still empty (via ${VAR:-default} pattern).
# Globals used: EXISTING_CONF
# Globals set: all config variables
merge_new_defaults() {
    if [[ -z "$EXISTING_CONF" ]] || [[ ! -f "$EXISTING_CONF" ]]; then
        log_debug "No existing config to merge"
        return 0
    fi

    log_info "Merging existing configuration with new defaults..."

    # Source existing config first
    set +u
    # shellcheck source=/dev/null
    source "$EXISTING_CONF"
    set -u

    # set_defaults uses ${VAR:-default}, so existing values are preserved
    set_defaults

    log_ok "Configuration merged (existing values preserved, new defaults applied)"
}

# ---------------------------------------------------------------------------
# _check_git_updates - Check if git repo has updates available.
# ---------------------------------------------------------------------------
# Globals used: INSTALL_DIR, DEPLOY_SOURCE, GIT_BRANCH
# Sets: GIT_COMMITS_BEHIND (number of commits behind remote)
# Returns: 0 if updates available, 1 if up to date or not a git deploy
_check_git_updates() {
    GIT_COMMITS_BEHIND=0

    if [[ "${DEPLOY_SOURCE:-local}" != "git" ]]; then
        return 1
    fi

    local src_dir="${INSTALL_DIR}/_src"
    if [[ ! -d "${src_dir}/.git" ]]; then
        log_debug "No git repository found at ${src_dir}"
        return 1
    fi

    log_info "Checking for git updates..."

    # Fetch latest
    if ! git -C "$src_dir" fetch origin "${GIT_BRANCH:-main}" --quiet 2>/dev/null; then
        log_warn "Could not fetch from remote"
        return 1
    fi

    # Count commits behind
    GIT_COMMITS_BEHIND="$(git -C "$src_dir" rev-list HEAD..origin/"${GIT_BRANCH:-main}" --count 2>/dev/null || echo 0)"

    if [[ "$GIT_COMMITS_BEHIND" -gt 0 ]]; then
        log_info "Git: ${GIT_COMMITS_BEHIND} new commits available"
        return 0
    fi

    log_debug "Git: up to date"
    return 1
}

# ---------------------------------------------------------------------------
# _check_npm_deps SERVICE_NAME PACKAGE_JSON_PATH - Check for npm changes.
# ---------------------------------------------------------------------------
# Compares md5 hash of package.json against saved hash.
# Arguments:
#   SERVICE_NAME      - label (backend, web, consumet, mangahook)
#   PACKAGE_JSON_PATH - path to the package.json file
# Returns: 0 if changed, 1 if unchanged
_check_npm_deps() {
    local name="$1"
    local pkg_json="$2"

    if [[ ! -f "$pkg_json" ]]; then
        log_debug "No package.json at $pkg_json"
        return 1
    fi

    local current_hash
    current_hash="$(md5sum "$pkg_json" 2>/dev/null | awk '{print $1}')"

    local saved_hash=""
    if [[ -f "$HASHES_FILE" ]]; then
        saved_hash="$(grep "^${name}_pkg=" "$HASHES_FILE" 2>/dev/null | cut -d= -f2)"
    fi

    if [[ "$current_hash" != "$saved_hash" ]]; then
        log_debug "npm deps changed for $name (hash: $saved_hash -> $current_hash)"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# _check_frontend_changes - Check if web frontend source has changed.
# ---------------------------------------------------------------------------
# Compares combined hash of key directories (app, components, lib, public).
# Globals used: INSTALL_DIR
# Returns: 0 if changed, 1 if unchanged
_check_frontend_changes() {
    local web_src
    if [[ "${DEPLOY_SOURCE:-local}" == "git" ]]; then
        web_src="${INSTALL_DIR}/_src/web"
    else
        web_src="$(cd "$SCRIPT_DIR/../.." && pwd)/web"
    fi

    local dirs_to_check=(app components lib public styles src)
    local hash_input=""

    for dir in "${dirs_to_check[@]}"; do
        if [[ -d "${web_src}/${dir}" ]]; then
            hash_input+="$(find "${web_src}/${dir}" -type f -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.css' 2>/dev/null | sort | xargs md5sum 2>/dev/null)"
        fi
    done

    local current_hash
    current_hash="$(echo "$hash_input" | md5sum | awk '{print $1}')"

    local saved_hash=""
    if [[ -f "$HASHES_FILE" ]]; then
        saved_hash="$(grep "^web_src=" "$HASHES_FILE" 2>/dev/null | cut -d= -f2)"
    fi

    if [[ "$current_hash" != "$saved_hash" ]]; then
        log_debug "Frontend source changed"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# _check_backend_changes - Check if backend source has changed.
# ---------------------------------------------------------------------------
# Compares combined hash of backend/src directory.
# Globals used: INSTALL_DIR, SCRIPT_DIR, DEPLOY_SOURCE
# Returns: 0 if changed, 1 if unchanged
_check_backend_changes() {
    local backend_src
    if [[ "${DEPLOY_SOURCE:-local}" == "git" ]]; then
        backend_src="${INSTALL_DIR}/_src/backend/src"
    else
        backend_src="$(cd "$SCRIPT_DIR/../.." && pwd)/backend/src"
    fi

    if [[ ! -d "$backend_src" ]]; then
        return 1
    fi

    local current_hash
    current_hash="$(find "$backend_src" -type f -name '*.ts' 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}')"

    local saved_hash=""
    if [[ -f "$HASHES_FILE" ]]; then
        saved_hash="$(grep "^backend_src=" "$HASHES_FILE" 2>/dev/null | cut -d= -f2)"
    fi

    if [[ "$current_hash" != "$saved_hash" ]]; then
        log_debug "Backend source changed"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# _check_config_files - Check if systemd/nginx configs need updating.
# ---------------------------------------------------------------------------
# Compares rendered templates against installed configs.
# Returns: 0 if changed, 1 if unchanged
_check_config_files() {
    local changes=false

    # Check systemd units
    local template_dir="${SCRIPT_DIR}/configs/systemd"
    for svc in openanime-backend openanime-web openanime-consumet openanime-mangahook; do
        local installed="/etc/systemd/system/${svc}.service"
        local template="${template_dir}/${svc}.service"

        if [[ -f "$installed" ]] && [[ -f "$template" ]]; then
            local rendered
            rendered="$(envsubst < "$template" 2>/dev/null)"
            local current
            current="$(cat "$installed" 2>/dev/null)"

            if [[ "$rendered" != "$current" ]]; then
                log_debug "Systemd unit changed: $svc"
                changes=true
            fi
        fi
    done

    # Check nginx config
    local nginx_installed="/etc/nginx/sites-available/synapseanime.conf"
    local nginx_template="${SCRIPT_DIR}/configs/nginx/synapseanime.conf"
    if [[ -f "$nginx_installed" ]] && [[ -f "$nginx_template" ]]; then
        local rendered
        rendered="$(envsubst < "$nginx_template" 2>/dev/null)"
        local current
        current="$(cat "$nginx_installed" 2>/dev/null)"

        if [[ "$rendered" != "$current" ]]; then
            log_debug "Nginx config changed"
            changes=true
        fi
    fi

    [[ "$changes" == "true" ]]
}

# ---------------------------------------------------------------------------
# scan_update_changes - Populate UPDATE_ACTIONS with needed changes.
# ---------------------------------------------------------------------------
# Runs all _check_* functions and builds an array of actions.
# Globals set: UPDATE_ACTIONS
scan_update_changes() {
    log_section "Scanning for Changes"
    UPDATE_ACTIONS=()

    # Git updates
    if _check_git_updates; then
        UPDATE_ACTIONS+=("git_pull:Pull ${GIT_COMMITS_BEHIND} new commits from remote")
    fi

    # NPM dependency changes
    local src_root
    if [[ "${DEPLOY_SOURCE:-local}" == "git" ]]; then
        src_root="${INSTALL_DIR}/_src"
    else
        src_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
    fi

    if _check_npm_deps "backend" "${src_root}/backend/package.json"; then
        UPDATE_ACTIONS+=("npm_backend:Reinstall backend dependencies")
    fi
    if _check_npm_deps "web" "${src_root}/web/package.json"; then
        UPDATE_ACTIONS+=("npm_web:Reinstall web dependencies")
    fi
    if _check_npm_deps "consumet" "${src_root}/consumet-api/package.json"; then
        UPDATE_ACTIONS+=("npm_consumet:Reinstall Consumet dependencies")
    fi
    if _check_npm_deps "mangahook" "${src_root}/mangahook-api/server/package.json"; then
        UPDATE_ACTIONS+=("npm_mangahook:Reinstall MangaHook dependencies")
    fi

    # Source code changes
    if _check_frontend_changes; then
        UPDATE_ACTIONS+=("build_web:Rebuild Next.js frontend")
    fi
    if _check_backend_changes; then
        UPDATE_ACTIONS+=("build_backend:Rebuild NestJS backend")
    fi

    # Config changes
    if _check_config_files; then
        UPDATE_ACTIONS+=("update_configs:Update systemd/nginx configuration files")
    fi

    if [[ ${#UPDATE_ACTIONS[@]} -eq 0 ]]; then
        log_ok "No changes detected - installation is up to date"
    else
        log_info "Found ${#UPDATE_ACTIONS[@]} update action(s)"
    fi
}

# ---------------------------------------------------------------------------
# show_update_summary - Display planned update actions for confirmation.
# ---------------------------------------------------------------------------
# Uses whiptail if available, otherwise logs to console.
# Globals used: UPDATE_ACTIONS, NON_INTERACTIVE
# Returns: 0 if confirmed, 1 if declined
show_update_summary() {
    if [[ ${#UPDATE_ACTIONS[@]} -eq 0 ]]; then
        return 0
    fi

    local summary="The following updates will be applied:\n\n"
    local idx=1
    for action in "${UPDATE_ACTIONS[@]}"; do
        local desc="${action#*:}"
        summary+="  ${idx}. ${desc}\n"
        idx=$((idx + 1))
    done
    summary+="\nServices will be restarted as needed."

    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        log_info "Update actions (non-interactive, proceeding):"
        for action in "${UPDATE_ACTIONS[@]}"; do
            log_info "  - ${action#*:}"
        done
        return 0
    fi

    if command -v whiptail &>/dev/null; then
        _tui_detect_terminal
        if whiptail --title "Update Summary" --yesno "$(printf '%b' "$summary")" \
            "$((TUI_ROWS - 4))" "$((TUI_COLS - 10))" 3>&1 1>&2 2>&3; then
            return 0
        else
            return 1
        fi
    else
        printf '%b\n' "$summary"
        confirm_action "Proceed with update?"
    fi
}

# ---------------------------------------------------------------------------
# confirm_config_overwrite FILE - Diff, show changes, ask, backup + write.
# ---------------------------------------------------------------------------
# For use when an existing config file needs to be updated.
# Arguments:
#   FILE - the config file path
# Globals used: NON_INTERACTIVE, DRY_RUN
# Returns: 0 if overwritten (or auto-confirmed), 1 if user declined
confirm_config_overwrite() {
    local file="$1"
    local new_content="${2:-}"

    if [[ ! -f "$file" ]]; then
        # No existing file, just write
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would check overwrite for $file"
        return 0
    fi

    # Show diff
    local diff_output
    if [[ -n "$new_content" ]]; then
        diff_output="$(echo "$new_content" | diff -u "$file" - 2>/dev/null || true)"
    fi

    if [[ -z "$diff_output" ]]; then
        log_debug "No changes detected for $file"
        return 1
    fi

    log_info "Changes detected in $file:"
    echo "$diff_output" | head -30

    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        log_info "Auto-overwriting $file (non-interactive mode)"
        backup_file "$file"
        return 0
    fi

    if confirm_action "Overwrite $file? (backup will be created)"; then
        backup_file "$file"
        return 0
    else
        log_skip "Keeping existing $file"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# save_hashes - Save current file hashes for future update detection.
# ---------------------------------------------------------------------------
# Called after a successful install/update to record the current state.
# Globals used: INSTALL_DIR, SCRIPT_DIR, DEPLOY_SOURCE, HASHES_FILE
save_hashes() {
    local src_root
    if [[ "${DEPLOY_SOURCE:-local}" == "git" ]]; then
        src_root="${INSTALL_DIR}/_src"
    else
        src_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would save deploy hashes to $HASHES_FILE"
        return 0
    fi

    {
        # Package.json hashes
        for svc_path in "backend:backend/package.json" "web:web/package.json" "consumet:consumet-api/package.json" "mangahook:mangahook-api/server/package.json"; do
            local name="${svc_path%%:*}"
            local path="${svc_path#*:}"
            if [[ -f "${src_root}/${path}" ]]; then
                echo "${name}_pkg=$(md5sum "${src_root}/${path}" | awk '{print $1}')"
            fi
        done

        # Source hashes
        if [[ -d "${src_root}/backend/src" ]]; then
            echo "backend_src=$(find "${src_root}/backend/src" -type f -name '*.ts' 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}')"
        fi

        local web_hash_input=""
        for dir in app components lib public styles src; do
            if [[ -d "${src_root}/web/${dir}" ]]; then
                web_hash_input+="$(find "${src_root}/web/${dir}" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.css' \) 2>/dev/null | sort | xargs md5sum 2>/dev/null)"
            fi
        done
        echo "web_src=$(echo "$web_hash_input" | md5sum | awk '{print $1}')"

    } > "$HASHES_FILE"

    chmod 600 "$HASHES_FILE"
    log_debug "Saved deploy hashes to $HASHES_FILE"
}
