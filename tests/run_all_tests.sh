#!/bin/bash
# Press SaaS Platform - Complete Test Suite Runner
# Runs all tests: integration, e2e, security, and performance

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Press SaaS Platform - Complete Test Suite             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Track results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test script
run_test() {
    local test_name="$1"
    local test_script="$2"

    echo -e "\n${BLUE}▶ Running: ${test_name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if python3 "$test_script"; then
        echo -e "${GREEN}✓ ${test_name} PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ ${test_name} FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Pre-flight check
echo -e "${YELLOW}Pre-flight checks...${NC}"
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: podman not found${NC}"
    exit 1
fi

if ! podman ps | grep -q "fcs-press"; then
    echo -e "${RED}Error: Press SaaS containers not running${NC}"
    echo -e "${YELLOW}Run: podman compose up -d${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# Run test suites
echo -e "\n${BLUE}Starting test execution...${NC}\n"

# 1. Integration Tests
run_test "Integration Tests" "tests/integration/test_services.py" || true

# 2. End-to-End Tests
run_test "End-to-End Tests" "tests/e2e/test_http_access.py" || true

# 3. Security Tests
run_test "Security Tests" "tests/security/test_security.py" || true

# Final Summary
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    FINAL TEST REPORT                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "Total Test Suites:  ${TOTAL_TESTS}"
echo -e "${GREEN}Passed:            ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed:            ${FAILED_TESTS}${NC}"
echo -e ""

# Calculate percentage
if [ $TOTAL_TESTS -gt 0 ]; then
    PERCENTAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success Rate:       ${PERCENTAGE}%"
fi

echo -e ""

# Exit code based on results
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            🎉 ALL TESTS PASSED! 🎉                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║          ⚠ SOME TESTS FAILED - REVIEW REQUIRED ⚠          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
