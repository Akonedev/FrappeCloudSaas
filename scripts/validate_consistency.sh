#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Validate NFR Consistency Across Documentation and Configuration
# =============================================================================
#
# This script cross-checks Non-Functional Requirements (NFR) values across:
# - specs/001-press-saas-platform/spec.md
# - specs/001-press-saas-platform/plan.md (if exists)
# - specs/001-press-saas-platform/tasks.md
# - docker/compose.yaml
#
# Validated metrics:
# - Boot time target (NFR-001): 2 minutes / 120 seconds
# - Site count target (NFR-002): 10+ sites
# - Port allocations: Must match across documents
#
# Exit codes:
# 0 - All checks passed
# 1 - Inconsistency detected
# 2 - File not found or parse error
#
# Addresses: CHK011
# =============================================================================

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Document paths
SPEC_FILE="$ROOT/specs/001-press-saas-platform/spec.md"
PLAN_FILE="$ROOT/specs/001-press-saas-platform/plan.md"
TASKS_FILE="$ROOT/specs/001-press-saas-platform/tasks.md"
COMPOSE_FILE="$ROOT/docker/compose.yaml"

# Expected NFR values
EXPECTED_BOOT_TIME_MINUTES=2
EXPECTED_BOOT_TIME_SECONDS=120
EXPECTED_SITE_COUNT=10
EXPECTED_PRESS_PORT=48543
EXPECTED_POSTGRES_PORT=48532
EXPECTED_REDIS_QUEUE_PORT=48511
EXPECTED_REDIS_CACHE_PORT=48579
EXPECTED_MINIO_API_PORT=48590
EXPECTED_MINIO_CONSOLE_PORT=48591
EXPECTED_KEYCLOAK_PORT=48595
EXPECTED_MANAGER_PORT=48550

# Tracking variables
ERRORS=()
WARNINGS=()

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    ERRORS+=("$1")
}

log_warning() {
    echo "[WARN] $1"
    WARNINGS+=("$1")
}

log_success() {
    echo "[OK] $1"
}

# Extract a value matching a pattern from a file
# Usage: extract_value "file" "pattern" "group_num"
extract_value() {
    local file="$1"
    local pattern="$2"
    local result

    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi

    result=$(grep -oP "$pattern" "$file" 2>/dev/null | head -1 || echo "")
    echo "$result"
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_boot_time() {
    log_info "Validating boot time targets (NFR-001)..."

    local spec_boot_time=""
    local tasks_boot_time=""
    local compose_healthcheck=""

    # Check spec.md for boot time reference
    if [[ -f "$SPEC_FILE" ]]; then
        # Look for "2 minutes" or "120 seconds" or "< 2 min"
        if grep -qiE "(2\s*minutes?|120\s*seconds?|<\s*2\s*min)" "$SPEC_FILE"; then
            spec_boot_time="2min"
            log_success "spec.md: Boot time target found (2 minutes)"
        else
            log_warning "spec.md: Boot time target not explicitly stated"
        fi
    else
        log_error "spec.md not found at $SPEC_FILE"
    fi

    # Check tasks.md for boot time reference
    if [[ -f "$TASKS_FILE" ]]; then
        if grep -qiE "(2\s*minutes?|120\s*seconds?|NFR-001)" "$TASKS_FILE"; then
            tasks_boot_time="2min"
            log_success "tasks.md: Boot time target referenced"
        else
            log_warning "tasks.md: Boot time target not found"
        fi
    else
        log_error "tasks.md not found at $TASKS_FILE"
    fi

    # Check compose.yaml healthcheck intervals
    if [[ -f "$COMPOSE_FILE" ]]; then
        # Healthcheck start_period should be reasonable (< 60s typically)
        local start_periods
        start_periods=$(grep -oP "start_period:\s*\K[0-9]+s?" "$COMPOSE_FILE" 2>/dev/null || echo "")
        if [[ -n "$start_periods" ]]; then
            log_success "compose.yaml: Healthcheck start_periods defined"
        else
            log_warning "compose.yaml: No explicit healthcheck start_periods found"
        fi
    fi
}

validate_site_count() {
    log_info "Validating site count targets (NFR-002)..."

    # Check spec.md
    if [[ -f "$SPEC_FILE" ]]; then
        if grep -qiE "(10\+?\s*sites?|at\s*least\s*10|10\s*simultaneous)" "$SPEC_FILE"; then
            log_success "spec.md: Site count target found (10+ sites)"
        else
            log_warning "spec.md: Site count target not explicitly stated"
        fi
    fi

    # Check tasks.md
    if [[ -f "$TASKS_FILE" ]]; then
        if grep -qiE "(10\+?\s*sites?|NFR-002|multi.?site)" "$TASKS_FILE"; then
            log_success "tasks.md: Site count requirement referenced"
        else
            log_warning "tasks.md: Site count not referenced"
        fi
    fi
}

validate_port_allocation() {
    log_info "Validating port allocations..."

    local compose_ports=""

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "compose.yaml not found at $COMPOSE_FILE"
        return
    fi

    # Extract published ports from compose file
    # Format: "HOST_PORT:CONTAINER_PORT" or just port definitions
    compose_ports=$(grep -oP '"\K[0-9]+(?=:[0-9]+")' "$COMPOSE_FILE" 2>/dev/null | sort -u || echo "")

    # Define expected port mappings
    declare -A EXPECTED_PORTS=(
        ["Press/Traefik HTTPS"]="$EXPECTED_PRESS_PORT"
        ["PostgreSQL"]="$EXPECTED_POSTGRES_PORT"
        ["Redis Queue"]="$EXPECTED_REDIS_QUEUE_PORT"
        ["Redis Cache"]="$EXPECTED_REDIS_CACHE_PORT"
        ["MinIO API"]="$EXPECTED_MINIO_API_PORT"
        ["MinIO Console"]="$EXPECTED_MINIO_CONSOLE_PORT"
        ["Keycloak"]="$EXPECTED_KEYCLOAK_PORT"
        ["Press Manager"]="$EXPECTED_MANAGER_PORT"
    )

    # Check spec.md port table
    if [[ -f "$SPEC_FILE" ]]; then
        for service in "${!EXPECTED_PORTS[@]}"; do
            local port="${EXPECTED_PORTS[$service]}"
            if grep -q "$port" "$SPEC_FILE"; then
                log_success "spec.md: Port $port ($service) documented"
            else
                log_warning "spec.md: Port $port ($service) not found in documentation"
            fi
        done
    fi

    # Check compose.yaml for expected ports
    log_info "Checking compose.yaml port definitions..."

    # Critical ports that MUST be present
    local critical_ports=("$EXPECTED_PRESS_PORT" "$EXPECTED_POSTGRES_PORT" "$EXPECTED_MINIO_API_PORT")
    for port in "${critical_ports[@]}"; do
        if grep -q "$port" "$COMPOSE_FILE"; then
            log_success "compose.yaml: Critical port $port defined"
        else
            log_error "compose.yaml: Critical port $port NOT found"
        fi
    done

    # Verify all ports are in allowed range (48510-49800)
    log_info "Verifying all ports in allowed range (48510-49800)..."
    local out_of_range=false
    while read -r port; do
        [[ -z "$port" ]] && continue
        if (( port < 48510 || port > 49800 )); then
            # Skip common internal ports (like 6379, 9000, etc.)
            if (( port < 1024 || port > 30000 )); then
                continue
            fi
            log_warning "Port $port may be outside allowed range (48510-49800)"
        fi
    done <<< "$compose_ports"
}

validate_container_prefix() {
    log_info "Validating container naming prefix (fcs-press-*)..."

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "compose.yaml not found"
        return
    fi

    # Check if container_name definitions use fcs-press- prefix
    local bad_names
    bad_names=$(grep -oP "container_name:\s*\K[^\s]+" "$COMPOSE_FILE" 2>/dev/null | grep -v "^fcs-press-" || echo "")

    if [[ -n "$bad_names" ]]; then
        log_error "Container names without fcs-press- prefix found: $bad_names"
    else
        log_success "All container names use fcs-press- prefix"
    fi
}

validate_document_references() {
    log_info "Validating cross-document references..."

    # Check that tasks.md references spec.md
    if [[ -f "$TASKS_FILE" ]]; then
        if grep -qi "spec.md\|specification" "$TASKS_FILE"; then
            log_success "tasks.md references specification documents"
        else
            log_warning "tasks.md does not explicitly reference spec.md"
        fi
    fi

    # Check that NFR identifiers are consistent
    local nfr_ids=("NFR-001" "NFR-002" "NFR-003" "NFR-004" "NFR-005")
    for nfr in "${nfr_ids[@]}"; do
        if [[ -f "$SPEC_FILE" ]] && grep -q "$nfr" "$SPEC_FILE"; then
            log_success "spec.md: $nfr defined"
        fi
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "=============================================="
    echo "NFR Consistency Validation"
    echo "=============================================="
    echo ""

    validate_boot_time
    echo ""

    validate_site_count
    echo ""

    validate_port_allocation
    echo ""

    validate_container_prefix
    echo ""

    validate_document_references
    echo ""

    echo "=============================================="
    echo "Summary"
    echo "=============================================="

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "Warnings (${#WARNINGS[@]}):"
        for w in "${WARNINGS[@]}"; do
            echo "  - $w"
        done
    fi

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo ""
        echo "Errors (${#ERRORS[@]}):"
        for e in "${ERRORS[@]}"; do
            echo "  - $e"
        done
        echo ""
        echo "VALIDATION FAILED: ${#ERRORS[@]} error(s) found"
        exit 1
    fi

    echo ""
    echo "VALIDATION PASSED: All consistency checks successful"
    exit 0
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
