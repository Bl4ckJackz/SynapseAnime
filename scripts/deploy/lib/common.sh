#!/usr/bin/env bash
# =============================================================================
# common.sh - Core utilities for SynapseAnime deploy system
# =============================================================================
# Provides: logging, error handling, run_cmd, password generation, template
# rendering, file backup, confirmation dialogs, and other shared helpers.
# Sourced by install.sh before all other lib/ modules.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Script directory resolution
# ---------------------------------------------------------------------------
# Resolve the absolute path of the deploy root (parent of lib/).
# Globals: SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Global flags (may be overridden by install.sh after parsing CLI args)
# ---------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
NO_COLOR="${NO_COLOR:-false}"

# ---------------------------------------------------------------------------
# Log file
# ---------------------------------------------------------------------------
LOG_DIR="${LOG_DIR:-/var/log/openanime}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/install.log}"

# ---------------------------------------------------------------------------
# Color constants
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# _apply_no_color - Disable all color constants.
# Called when --no-color is set.
_apply_no_color() {
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    RESET=''
}

# Apply immediately if NO_COLOR was inherited from environment
[[ "$NO_COLOR" == "true" ]] && _apply_no_color

# ---------------------------------------------------------------------------
# Strip Windows carriage returns from all sourced scripts
# ---------------------------------------------------------------------------
_strip_cr() {
    local f
    for f in "$SCRIPT_DIR"/lib/*.sh "$SCRIPT_DIR"/install.sh; do
        [[ -f "$f" ]] && sed -i 's/\r$//' "$f" 2>/dev/null || true
    done
}
_strip_cr

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

# _log_to_file MSG - Append a line to LOG_FILE with ANSI codes stripped.
_log_to_file() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    # Strip ANSI escape sequences
    local clean
    clean="$(printf '%s' "$msg" | sed 's/\x1b\[[0-9;]*m//g')"
    { printf '[%s] %s\n' "$ts" "$clean" >> "$LOG_FILE"; } 2>/dev/null || true
}

# log_info MSG - Informational message (blue arrow).
log_info() {
    local msg="$1"
    printf "${BLUE}  -> ${RESET}%s\n" "$msg"
    _log_to_file "[INFO] $msg"
}

# log_ok MSG - Success message (green check).
log_ok() {
    local msg="$1"
    printf "${GREEN}  [OK] ${RESET}%s\n" "$msg"
    _log_to_file "[OK] $msg"
}

# log_warn MSG - Warning message (yellow exclamation).
log_warn() {
    local msg="$1"
    printf "${YELLOW}  [!] ${RESET}%s\n" "$msg" >&2
    _log_to_file "[WARN] $msg"
}

# log_fail MSG - Error/failure message (red X).
log_fail() {
    local msg="$1"
    printf "${RED}  [FAIL] ${RESET}%s\n" "$msg" >&2
    _log_to_file "[FAIL] $msg"
}

# log_skip MSG - Skipped step message (cyan dash).
log_skip() {
    local msg="$1"
    printf "${CYAN}  [SKIP] ${RESET}%s\n" "$msg"
    _log_to_file "[SKIP] $msg"
}

# log_debug MSG - Debug message, only shown when VERBOSE=true.
log_debug() {
    local msg="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        printf "${CYAN}  [DBG] ${RESET}%s\n" "$msg"
    fi
    _log_to_file "[DEBUG] $msg"
}

# log_section TITLE - Section header with decorative line.
log_section() {
    local title="$1"
    printf "\n${BOLD}${BLUE}=== %s ===${RESET}\n\n" "$title"
    _log_to_file "=== $title ==="
}

# ---------------------------------------------------------------------------
# Error trap
# ---------------------------------------------------------------------------

# _error_trap - Called on ERR signal; prints line number and failed command.
# Globals: BASH_LINENO, BASH_COMMAND
_error_trap() {
    local line="${BASH_LINENO[0]:-unknown}"
    local cmd="${BASH_COMMAND:-unknown}"
    log_fail "Command failed at line $line: $cmd"
    log_fail "See $LOG_FILE for details."
}
trap '_error_trap' ERR

# ---------------------------------------------------------------------------
# run_cmd DESCRIPTION COMMAND [ARGS...]
# ---------------------------------------------------------------------------
# Executes a command with a spinner, logging output to LOG_FILE.
# On failure, prints the last 5 lines of captured output.
# In DRY_RUN mode, prints command without executing.
#
# Arguments:
#   DESCRIPTION - Human-readable label for the operation
#   COMMAND     - The command to execute (remaining args)
#
# Returns: exit code of the command
run_cmd() {
    local desc="$1"; shift
    local cmd_str="$*"

    if [[ "$DRY_RUN" == "true" ]]; then
        printf "${CYAN}  [DRY] ${RESET}%s: %s\n" "$desc" "$cmd_str"
        _log_to_file "[DRY] $desc: $cmd_str"
        return 0
    fi

    printf "${BLUE}  -> ${RESET}%s ..." "$desc"
    _log_to_file "[RUN] $desc: $cmd_str"

    local tmp_out
    tmp_out="$(mktemp)"

    # Run command, redirect stdin from /dev/null to prevent interactive prompts
    local rc=0
    ( eval "$cmd_str" ) < /dev/null > "$tmp_out" 2>&1 || rc=$?

    # Log captured output
    { cat "$tmp_out" >> "$LOG_FILE"; } 2>/dev/null || true

    if [[ $rc -eq 0 ]]; then
        printf " ${GREEN}done${RESET}\n"
        _log_to_file "[OK] $desc completed"
    else
        printf " ${RED}FAILED (exit $rc)${RESET}\n"
        _log_to_file "[FAIL] $desc failed with exit $rc"
        log_fail "Last 5 lines of output:"
        tail -n 5 "$tmp_out" | while IFS= read -r line; do
            printf "       %s\n" "$line" >&2
        done
    fi

    rm -f "$tmp_out"
    return $rc
}

# ---------------------------------------------------------------------------
# guard_installed CMD - Check that a command is available on PATH.
# ---------------------------------------------------------------------------
# Arguments:
#   CMD - command name to look up
# Returns: 0 if found, 1 if not (with log_fail message)
guard_installed() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_fail "Required command not found: $cmd"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# gen_password [LENGTH] - Generate a random alphanumeric password.
# ---------------------------------------------------------------------------
# Arguments:
#   LENGTH - password length (default: 32)
# Globals: none
# Outputs: password string to stdout
gen_password() {
    local len="${1:-32}"
    openssl rand -base64 "$((len * 3 / 4 + 1))" 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c "$len"
}

# ---------------------------------------------------------------------------
# require_root - Exit with error if not running as root.
# ---------------------------------------------------------------------------
require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_fail "This script must be run as root (or with sudo)."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# ensure_dir PATH [OWNER] - Create directory if missing, optionally chown.
# ---------------------------------------------------------------------------
# Arguments:
#   PATH  - directory path to create
#   OWNER - optional owner:group (e.g. "openanime:openanime")
ensure_dir() {
    local dir="$1"
    local owner="${2:-}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] ensure_dir $dir ${owner:+(owner: $owner)}"
        return 0
    fi

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi

    if [[ -n "$owner" ]]; then
        chown "$owner" "$dir"
    fi
}

# ---------------------------------------------------------------------------
# backup_file PATH - Create a timestamped .bak copy of a file.
# ---------------------------------------------------------------------------
# Arguments:
#   PATH - file to back up
# Returns: 0 on success, 1 if source doesn't exist
backup_file() {
    local src="$1"
    if [[ ! -f "$src" ]]; then
        log_debug "backup_file: $src does not exist, nothing to back up"
        return 1
    fi

    local ts
    ts="$(date '+%Y%m%d_%H%M%S')"
    local bak="${src}.bak.${ts}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would back up $src -> $bak"
        return 0
    fi

    cp -a "$src" "$bak"
    log_debug "Backed up $src -> $bak"
    return 0
}

# ---------------------------------------------------------------------------
# template_render TEMPLATE OUTPUT [VARS] - Render a template file using envsubst.
# ---------------------------------------------------------------------------
# The template should use ${VAR} notation. If VARS is provided (space-separated
# list like '${DOMAIN} ${PORT}'), only those vars are substituted — other $vars
# are left literal (important for nginx $host, $remote_addr, etc.).
# Without VARS: all exported shell variables are substituted.
#
# Arguments:
#   TEMPLATE - path to the template file
#   OUTPUT   - path to write the rendered result
#   VARS     - (optional) whitelist of variables to substitute
template_render() {
    local template="$1"
    local output="$2"
    local vars="${3:-}"

    if [[ ! -f "$template" ]]; then
        log_fail "Template not found: $template"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] template_render $template -> $output"
        return 0
    fi

    if [[ -n "$vars" ]]; then
        envsubst "$vars" < "$template" > "$output"
    else
        envsubst < "$template" > "$output"
    fi
    log_debug "Rendered template $template -> $output"
}

# ---------------------------------------------------------------------------
# confirm_action MSG - Ask user for yes/no confirmation.
# ---------------------------------------------------------------------------
# Uses whiptail if available, falls back to read prompt.
#
# Arguments:
#   MSG - question to display
# Returns: 0 if confirmed, 1 if declined
confirm_action() {
    local msg="$1"

    # Non-interactive mode always confirms
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        log_debug "Auto-confirmed (non-interactive): $msg"
        return 0
    fi

    if command -v whiptail &>/dev/null; then
        if whiptail --yesno "$msg" 12 60 3>&1 1>&2 2>&3; then
            return 0
        else
            return 1
        fi
    else
        printf "${BOLD}%s [y/N]: ${RESET}" "$msg"
        local answer
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# is_update_mode - Check if we are running in update mode.
# ---------------------------------------------------------------------------
# Returns: 0 if UPDATE_MODE=true, 1 otherwise
is_update_mode() {
    [[ "${UPDATE_MODE:-false}" == "true" ]]
}

# ---------------------------------------------------------------------------
# service_is_active NAME - Check if a systemd service is running.
# ---------------------------------------------------------------------------
# Arguments:
#   NAME - systemd unit name
# Returns: 0 if active, 1 otherwise
service_is_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Export key variables so envsubst and subshells can see them
# ---------------------------------------------------------------------------
export DRY_RUN VERBOSE NO_COLOR LOG_DIR LOG_FILE SCRIPT_DIR
