#!/bin/bash
#
# tests/runner.sh - Bash test harness for uservin
#

# Test state
TESTS_PASSED=0
TESTS_FAILED=0
TEST_NAME=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo -e "${RED}  ✗ FAILED${NC}: $TEST_NAME"
        echo "    Expected: '$expected'"
        echo "    Actual:   '$actual'"
        [[ -n "$message" ]] && echo "    Message:  $message"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"
    
    if eval "$condition"; then
        return 0
    else
        echo -e "${RED}  ✗ FAILED${NC}: $TEST_NAME"
        echo "    Condition '$condition' should be true"
        [[ -n "$message" ]] && echo "    Message:  $message"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-}"
    
    if ! eval "$condition"; then
        return 0
    else
        echo -e "${RED}  ✗ FAILED${NC}: $TEST_NAME"
        echo "    Condition '$condition' should be false"
        [[ -n "$message" ]] && echo "    Message:  $message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo -e "${RED}  ✗ FAILED${NC}: $TEST_NAME"
        echo "    Expected string containing: '$needle'"
        echo "    Got: '$haystack'"
        [[ -n "$message" ]] && echo "    Message:  $message"
        return 1
    fi
}

# Run a single test function
run_test() {
    local test_func="$1"
    TEST_NAME="$test_func"
    
    # Run test in subshell to isolate failures
    if ( $test_func ); then
        echo -e "${GREEN}  ✓${NC} $test_func"
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

# Run all tests in a file
run_test_file() {
    local test_file="$1"
    local module_name
    module_name=$(basename "$test_file" .sh)
    
    echo -e "\n${YELLOW}Running: $module_name${NC}"
    
    # Source the test file
    # shellcheck source=/dev/null
    source "$test_file"
    
    # Find and run all test functions
    local test_funcs
    test_funcs=$(grep -E "^test_[a-zA-Z_0-9]+\(\)" "$test_file" | sed 's/().*//')
    
    for func in $test_funcs; do
        run_test "$func"
    done
}

# Print summary
print_summary() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}Failed: $TESTS_FAILED${NC}"
        exit 0
    fi
}

# Main runner
main() {
    echo -e "${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     uservin Test Runner              ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"
    
    local test_dir
    test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [[ $# -gt 0 ]]; then
        # Run specific test files
        for file in "$@"; do
            if [[ -f "$file" ]]; then
                run_test_file "$file"
            elif [[ -f "$test_dir/$file" ]]; then
                run_test_file "$test_dir/$file"
            else
                echo -e "${RED}Test file not found: $file${NC}"
                exit 1
            fi
        done
    else
        # Run all test files
        for test_file in "$test_dir"/test_*.sh; do
            if [[ -f "$test_file" ]]; then
                run_test_file "$test_file"
            fi
        done
    fi
    
    print_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
