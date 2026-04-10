#!/usr/bin/env bash
# =============================================================================
# smoke.sh - Post-install smoke tests for SynapseAnime
# =============================================================================
# Provides: run_smoke_tests() which checks HTTP health of each service,
# validates expected responses, and reports pass/fail per service.
# Sourced by install.sh after common.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# Smoke test configuration
# ---------------------------------------------------------------------------
SMOKE_TIMEOUT=10         # seconds per HTTP request
SMOKE_STARTUP_WAIT=5     # seconds to wait before first check
SMOKE_RETRIES=3          # number of retries per service
SMOKE_RETRY_DELAY=3      # seconds between retries

# ---------------------------------------------------------------------------
# _smoke_check URL EXPECT_PATTERN LABEL - Test a single endpoint.
# ---------------------------------------------------------------------------
# Arguments:
#   URL            - full URL to request
#   EXPECT_PATTERN - grep pattern expected in response body
#   LABEL          - human-readable label for reporting
# Returns: 0 if passed, 1 if failed
_smoke_check() {
    local url="$1"
    local pattern="$2"
    local label="$3"

    local attempt=0
    while [[ $attempt -lt $SMOKE_RETRIES ]]; do
        attempt=$((attempt + 1))

        local response
        local http_code
        response="$(curl -sf --connect-timeout "$SMOKE_TIMEOUT" --max-time "$SMOKE_TIMEOUT" -w "\n%{http_code}" "$url" 2>/dev/null || echo "")"

        if [[ -z "$response" ]]; then
            if [[ $attempt -lt $SMOKE_RETRIES ]]; then
                log_debug "Smoke: $label attempt $attempt - no response, retrying in ${SMOKE_RETRY_DELAY}s..."
                sleep "$SMOKE_RETRY_DELAY"
                continue
            fi
            log_fail "Smoke: $label - no response from $url"
            return 1
        fi

        http_code="$(echo "$response" | tail -1)"
        local body
        body="$(echo "$response" | sed '$d')"

        # Check HTTP status
        if [[ "$http_code" -ge 200 ]] && [[ "$http_code" -lt 400 ]]; then
            # Check response body pattern
            if [[ -n "$pattern" ]]; then
                if echo "$body" | grep -qi "$pattern"; then
                    log_ok "Smoke: $label - HTTP $http_code, pattern matched"
                    return 0
                else
                    if [[ $attempt -lt $SMOKE_RETRIES ]]; then
                        sleep "$SMOKE_RETRY_DELAY"
                        continue
                    fi
                    log_warn "Smoke: $label - HTTP $http_code, but pattern '$pattern' not found"
                    return 1
                fi
            else
                log_ok "Smoke: $label - HTTP $http_code"
                return 0
            fi
        else
            if [[ $attempt -lt $SMOKE_RETRIES ]]; then
                log_debug "Smoke: $label attempt $attempt - HTTP $http_code, retrying..."
                sleep "$SMOKE_RETRY_DELAY"
                continue
            fi
            log_fail "Smoke: $label - HTTP $http_code"
            return 1
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# run_smoke_tests - Run smoke tests against all services.
# ---------------------------------------------------------------------------
# Globals used: API_PORT, WEB_PORT, CONSUMET_PORT, MANGAHOOK_PORT, DRY_RUN
# Returns: 0 if all pass, 1 if any fail
run_smoke_tests() {
    log_section "Smoke Tests"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "[DRY] Would run smoke tests"
        return 0
    fi

    # Give services a moment to fully start
    log_info "Waiting ${SMOKE_STARTUP_WAIT}s for services to stabilize..."
    sleep "$SMOKE_STARTUP_WAIT"

    local passed=0
    local failed=0
    local total=4

    # Backend API - should return "Hello World"
    if _smoke_check "http://127.0.0.1:${API_PORT}/" "Hello World" "Backend API (:${API_PORT})"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    # Web frontend - should return HTML
    if _smoke_check "http://127.0.0.1:${WEB_PORT}/" "<html\|<!DOCTYPE\|__next" "Web Frontend (:${WEB_PORT})"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    # Consumet API
    if _smoke_check "http://127.0.0.1:${CONSUMET_PORT}/" "" "Consumet API (:${CONSUMET_PORT})"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    # MangaHook API
    if _smoke_check "http://127.0.0.1:${MANGAHOOK_PORT}/api/home" "" "MangaHook API (:${MANGAHOOK_PORT})"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    # Summary
    printf "\n"
    if [[ $failed -eq 0 ]]; then
        log_ok "Smoke tests: ${passed}/${total} passed"
        return 0
    else
        log_warn "Smoke tests: ${passed}/${total} passed, ${failed}/${total} failed"
        log_info "Check logs for details: ${LOG_DIR}/"
        log_info "Debug with: journalctl -u openanime-<service> --no-pager -n 50"
        return 1
    fi
}
