#!/usr/bin/env bash
# =============================================================================
# checks.sh - Pre-flight checks for SynapseAnime deploy system
# =============================================================================
# Provides: OS detection, root check, disk space, internet, systemd checks,
# prerequisite package installation, and the run_preflight orchestrator.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# check_os - Detect operating system and validate supported version.
# ---------------------------------------------------------------------------
# Sets globals: OS_ID, OS_VERSION, OS_CODENAME
# Supported: Debian 12+, Ubuntu 22.04+
# Returns: 0 if supported, exits 1 if not
check_os() {
    log_info "Detecting operating system..."

    if [[ ! -f /etc/os-release ]]; then
        log_fail "Cannot detect OS: /etc/os-release not found"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-0}"
    OS_CODENAME="${VERSION_CODENAME:-unknown}"

    export OS_ID OS_VERSION OS_CODENAME

    case "$OS_ID" in
        debian)
            local major="${OS_VERSION%%.*}"
            if [[ "$major" -lt 12 ]]; then
                log_fail "Debian $OS_VERSION is not supported. Requires Debian 12 (Bookworm) or later."
                exit 1
            fi
            log_ok "Detected Debian $OS_VERSION ($OS_CODENAME)"
            ;;
        ubuntu)
            # Compare as integer: 22.04 -> 2204
            local ver_int
            ver_int="$(echo "$OS_VERSION" | tr -d '.')"
            if [[ "$ver_int" -lt 2204 ]]; then
                log_fail "Ubuntu $OS_VERSION is not supported. Requires Ubuntu 22.04 or later."
                exit 1
            fi
            log_ok "Detected Ubuntu $OS_VERSION ($OS_CODENAME)"
            ;;
        *)
            log_fail "Unsupported OS: $OS_ID $OS_VERSION. Only Debian 12+ and Ubuntu 22.04+ are supported."
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# check_root - Verify running as root.
# ---------------------------------------------------------------------------
# Returns: 0 if root, exits 1 if not
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_fail "This installer must be run as root (or with sudo)."
        exit 1
    fi
    log_ok "Running as root"
}

# ---------------------------------------------------------------------------
# check_disk_space - Ensure at least 2 GB of free disk space.
# ---------------------------------------------------------------------------
# Checks the partition containing INSTALL_DIR (or / as fallback).
# Returns: 0 if sufficient, exits 1 if not
check_disk_space() {
    local target="${INSTALL_DIR:-/opt/openanime}"
    local check_path="$target"

    # Walk up to find an existing mount point
    while [[ ! -d "$check_path" ]] && [[ "$check_path" != "/" ]]; do
        check_path="$(dirname "$check_path")"
    done

    local avail_kb
    avail_kb="$(df --output=avail "$check_path" 2>/dev/null | tail -1 | tr -d ' ')"

    if [[ -z "$avail_kb" ]]; then
        log_warn "Could not determine available disk space. Continuing anyway."
        return 0
    fi

    local required_kb=$((2 * 1024 * 1024))  # 2 GB in KB
    if [[ "$avail_kb" -lt "$required_kb" ]]; then
        local avail_mb=$((avail_kb / 1024))
        log_fail "Insufficient disk space: ${avail_mb}MB available, 2048MB required."
        exit 1
    fi

    local avail_gb=$((avail_kb / 1024 / 1024))
    log_ok "Disk space: ${avail_gb}GB available"
}

# ---------------------------------------------------------------------------
# check_internet - Verify network connectivity.
# ---------------------------------------------------------------------------
# Tries to reach deb.debian.org; falls back to google.com.
# Returns: 0 if reachable, exits 1 if not
check_internet() {
    log_info "Checking internet connectivity..."

    if curl -sfL --connect-timeout 10 --max-time 15 https://deb.debian.org/ -o /dev/null 2>/dev/null; then
        log_ok "Internet connectivity verified (deb.debian.org)"
        return 0
    fi

    if curl -sfL --connect-timeout 10 --max-time 15 https://google.com/ -o /dev/null 2>/dev/null; then
        log_ok "Internet connectivity verified (google.com)"
        return 0
    fi

    log_fail "No internet connectivity. Cannot reach deb.debian.org or google.com."
    exit 1
}

# ---------------------------------------------------------------------------
# check_systemd - Verify systemd is PID 1.
# ---------------------------------------------------------------------------
# Returns: 0 if systemd, exits 1 if not
check_systemd() {
    if [[ "$(cat /proc/1/comm 2>/dev/null)" != "systemd" ]]; then
        log_fail "systemd is required but not running as PID 1."
        log_fail "This installer requires a systemd-based Linux distribution."
        exit 1
    fi
    log_ok "systemd detected as init system"
}

# ---------------------------------------------------------------------------
# install_prerequisites - Install required system packages.
# ---------------------------------------------------------------------------
# Packages: gnupg, curl, git, rsync, ca-certificates, build-essential, python3,
#           lsb-release, software-properties-common, whiptail
# Globals: DRY_RUN
install_prerequisites() {
    log_info "Installing prerequisite packages..."

    local packages=(
        gnupg
        curl
        git
        rsync
        ca-certificates
        build-essential
        python3
        lsb-release
        software-properties-common
        whiptail
    )

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] apt-get install ${packages[*]}"
        return 0
    fi

    run_cmd "Updating package lists" "apt-get update -qq"

    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_ok "All prerequisite packages already installed"
        return 0
    fi

    run_cmd "Installing packages: ${to_install[*]}" \
        "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ${to_install[*]}"

    log_ok "Prerequisite packages installed"
}

# ---------------------------------------------------------------------------
# run_preflight - Orchestrate all pre-flight checks in order.
# ---------------------------------------------------------------------------
# Runs: check_root, check_os, check_systemd, check_disk_space,
#       check_internet, install_prerequisites
run_preflight() {
    log_section "Pre-flight Checks"

    check_root
    check_os
    check_systemd
    check_disk_space
    check_internet
    install_prerequisites

    # Ensure log directory exists
    ensure_dir "$LOG_DIR"
    touch "$LOG_FILE" 2>/dev/null || true

    log_ok "All pre-flight checks passed"
}
