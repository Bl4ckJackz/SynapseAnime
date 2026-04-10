#!/usr/bin/env bash
# ============================================================================
# install.sh — Wrapper that delegates to the modular deploy system
# ============================================================================
# For backwards compatibility. The actual installer lives in deploy/install.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec bash "${SCRIPT_DIR}/deploy/install.sh" "$@"
