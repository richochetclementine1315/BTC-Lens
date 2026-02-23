#!/usr/bin/env bash
###############################################################################
# grader/lib/common.sh — Shared utilities for grader scripts
#
# Source this file from grade_transactions.sh and grade_blocks.sh:
#   source "$(dirname "$0")/lib/common.sh"
###############################################################################

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BOLD=''
  NC=''
fi

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ---------------------------------------------------------------------------
# Printing helpers
# ---------------------------------------------------------------------------
print_header() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_section() {
  echo -e "  ${BOLD}--- $1 ---${NC}"
}

print_pass() {
  echo -e "  ${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
  echo -e "  ${RED}FAIL${NC} $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "       ${RED}$2${NC}"
  fi
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_skip() {
  echo -e "  ${YELLOW}SKIP${NC} $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

print_summary() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  Summary${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}PASS: $PASS_COUNT${NC}"
  echo -e "  ${RED}FAIL: $FAIL_COUNT${NC}"
  if [[ $SKIP_COUNT -gt 0 ]]; then
    echo -e "  ${YELLOW}SKIP: $SKIP_COUNT${NC}"
  fi
  echo ""
  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}ALL CHECKS PASSED${NC}"
  else
    echo -e "  ${RED}${BOLD}$FAIL_COUNT CHECK(S) FAILED${NC}"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# check_jq — Verify jq is installed
# ---------------------------------------------------------------------------
check_jq() {
  if ! command -v jq &>/dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}" >&2
    echo "" >&2
    echo "Install jq:" >&2
    echo "  macOS:   brew install jq" >&2
    echo "  Ubuntu:  sudo apt-get install jq" >&2
    echo "  Arch:    sudo pacman -S jq" >&2
    echo "  Windows: choco install jq" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Timeout wrapper
#
# Uses `timeout` (Linux/coreutils) or `gtimeout` (macOS/Homebrew) if
# available; falls back to a background-process-with-kill approach.
#
# Usage: run_with_timeout <seconds> <command> [args...]
# Returns the command's exit code, or 124 on timeout.
# ---------------------------------------------------------------------------
run_with_timeout() {
  local secs="$1"; shift

  if command -v timeout &>/dev/null; then
    timeout "$secs" "$@"
    return $?
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$secs" "$@"
    return $?
  else
    # Fallback: background + kill
    "$@" &
    local pid=$!
    (
      sleep "$secs"
      kill "$pid" 2>/dev/null
    ) &
    local watcher=$!
    wait "$pid" 2>/dev/null
    local rc=$?
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null
    if ! kill -0 "$pid" 2>/dev/null; then
      return $rc
    else
      return 124
    fi
  fi
}

# ---------------------------------------------------------------------------
# run_cli <args...>
#
# Runs ./cli.sh with a 60-second timeout.
# Sets globals: CLI_STDOUT, CLI_STDERR, CLI_EXIT
# ---------------------------------------------------------------------------
CLI_STDOUT=""
CLI_STDERR=""
CLI_EXIT=0

run_cli() {
  local tmpout tmperr
  tmpout=$(mktemp)
  tmperr=$(mktemp)

  set +e
  run_with_timeout 60 ./cli.sh "$@" >"$tmpout" 2>"$tmperr"
  CLI_EXIT=$?
  set -e

  CLI_STDOUT=$(cat "$tmpout")
  CLI_STDERR=$(cat "$tmperr")
  rm -f "$tmpout" "$tmperr"

  if [[ $CLI_EXIT -eq 124 ]]; then
    CLI_STDERR="TIMEOUT: cli.sh did not finish within 60 seconds"
  fi
}

# ---------------------------------------------------------------------------
# JSON assertion helpers
#
# All assertions take the JSON string as the first argument, then a jq path,
# then type-specific expected values. They call print_pass or print_fail.
# ---------------------------------------------------------------------------

# assert_field_exists <json> <jq_path> [label]
#   Checks that the field exists and is not null.
assert_field_exists() {
  local json="$1" path="$2" label="${3:-$2 exists}"
  local val
  val=$(echo "$json" | jq -r "$path // \"__NULL__\"" 2>/dev/null) || val="__ERROR__"
  if [[ "$val" == "__NULL__" || "$val" == "__ERROR__" ]]; then
    print_fail "$label" "Field $path is missing or null"
    return 1
  else
    print_pass "$label"
    return 0
  fi
}

# assert_field_equals <json> <jq_path> <expected> [label]
#   Checks exact equality (as raw jq output).
assert_field_equals() {
  local json="$1" path="$2" expected="$3" label="${4:-$2 == $3}"
  local actual
  actual=$(echo "$json" | jq -r "$path" 2>/dev/null) || actual="__ERROR__"
  if [[ "$actual" == "$expected" ]]; then
    print_pass "$label"
    return 0
  else
    print_fail "$label" "Expected: $expected, Got: $actual"
    return 1
  fi
}

# assert_field_equals_json <json> <jq_path> <expected_json> [label]
#   Checks equality using jq comparison (handles types correctly).
assert_field_equals_json() {
  local json="$1" path="$2" expected="$3" label="${4:-$2 == $3}"
  local result
  result=$(echo "$json" | jq --argjson exp "$expected" "($path) == \$exp" 2>/dev/null) || result="false"
  if [[ "$result" == "true" ]]; then
    print_pass "$label"
    return 0
  else
    local actual
    actual=$(echo "$json" | jq "$path" 2>/dev/null) || actual="ERROR"
    print_fail "$label" "Expected: $expected, Got: $actual"
    return 1
  fi
}

# assert_field_type <json> <jq_path> <type> [label]
#   Checks the JSON type: string, number, boolean, array, object, null
assert_field_type() {
  local json="$1" path="$2" expected_type="$3" label="${4:-$2 is $3}"
  local actual_type
  actual_type=$(echo "$json" | jq -r "$path | type" 2>/dev/null) || actual_type="ERROR"
  if [[ "$actual_type" == "$expected_type" ]]; then
    print_pass "$label"
    return 0
  else
    print_fail "$label" "Expected type: $expected_type, Got: $actual_type"
    return 1
  fi
}

# assert_field_matches <json> <jq_path> <regex> [label]
#   Checks that the string value matches a regex.
assert_field_matches() {
  local json="$1" path="$2" regex="$3" label="${4:-$2 matches $3}"
  local val
  val=$(echo "$json" | jq -r "$path" 2>/dev/null) || val=""
  if [[ "$val" =~ $regex ]]; then
    print_pass "$label"
    return 0
  else
    print_fail "$label" "Value '$val' does not match regex: $regex"
    return 1
  fi
}

# assert_field_approx <json> <jq_path> <expected> <tolerance> [label]
#   Checks that numeric value is within ±tolerance of expected.
assert_field_approx() {
  local json="$1" path="$2" expected="$3" tolerance="$4" label="${5:-$2 ≈ $3 ±$4}"
  local actual
  actual=$(echo "$json" | jq "$path" 2>/dev/null) || actual="null"
  if [[ "$actual" == "null" ]]; then
    print_fail "$label" "Field $path is null or missing"
    return 1
  fi
  local ok
  ok=$(echo "$json" | jq --argjson exp "$expected" --argjson tol "$tolerance" \
    "(($path) - \$exp) | fabs < \$tol" 2>/dev/null) || ok="false"
  if [[ "$ok" == "true" ]]; then
    print_pass "$label"
    return 0
  else
    print_fail "$label" "Expected ≈$expected (±$tolerance), Got: $actual"
    return 1
  fi
}

# assert_field_is_null <json> <jq_path> [label]
assert_field_is_null() {
  local json="$1" path="$2" label="${3:-$2 is null}"
  local actual_type
  actual_type=$(echo "$json" | jq -r "$path | type" 2>/dev/null) || actual_type="ERROR"
  if [[ "$actual_type" == "null" ]]; then
    print_pass "$label"
    return 0
  else
    print_fail "$label" "Expected null, got type: $actual_type"
    return 1
  fi
}

# assert_array_length <json> <jq_path> <expected_length> [label]
assert_array_length() {
  local json="$1" path="$2" expected="$3" label="${4:-$2 length == $3}"
  local actual
  actual=$(echo "$json" | jq "$path | length" 2>/dev/null) || actual="ERROR"
  if [[ "$actual" == "$expected" ]]; then
    print_pass "$label"
    return 0
  else
    print_fail "$label" "Expected length: $expected, Got: $actual"
    return 1
  fi
}

# assert_field_in <json> <jq_path> <val1> <val2> ... [-- label]
#   Checks that the value is one of the listed values.
assert_field_in() {
  local json="$1" path="$2"
  shift 2
  local values=()
  local label=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
      shift
      label="$1"
      break
    fi
    values+=("$1")
    shift
  done
  local actual
  actual=$(echo "$json" | jq -r "$path" 2>/dev/null) || actual="__ERROR__"
  [[ -z "$label" ]] && label="$path in {$(IFS=,; echo "${values[*]}")}"
  for v in "${values[@]}"; do
    if [[ "$actual" == "$v" ]]; then
      print_pass "$label"
      return 0
    fi
  done
  print_fail "$label" "Value '$actual' not in allowed set"
  return 1
}

# is_valid_json <string>
#   Returns 0 if the string is valid JSON, 1 otherwise.
is_valid_json() {
  echo "$1" | jq empty 2>/dev/null
}

# hex64_regex — matches a 64-character lowercase hex string
HEX64_REGEX='^[0-9a-f]{64}$'
