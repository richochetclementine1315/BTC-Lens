#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# grader/grade_blocks.sh — Grade CLI output against block fixtures
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BLOCKS_DIR="$REPO_DIR/fixtures/blocks"

cd "$REPO_DIR"
source "$SCRIPT_DIR/lib/common.sh"

check_jq

# ---------------------------------------------------------------------------
# discover_block_pairs
#   Find matching blk*.dat / rev*.dat pairs by number suffix.
#   XOR key is shared: fixtures/blocks/xor.dat
# ---------------------------------------------------------------------------
discover_block_pairs() {
  local xor_file="$BLOCKS_DIR/xor.dat"
  if [[ ! -f "$xor_file" ]]; then
    echo -e "${RED}Error: xor.dat not found in $BLOCKS_DIR${NC}" >&2
    return 1
  fi

  BLOCK_PAIRS=()
  for blk in "$BLOCKS_DIR"/blk*.dat; do
    [[ -f "$blk" ]] || continue
    local num
    num=$(basename "$blk" .dat | sed 's/^blk//')
    local rev="$BLOCKS_DIR/rev${num}.dat"
    if [[ -f "$rev" ]]; then
      BLOCK_PAIRS+=("$blk|$rev|$xor_file")
    else
      echo -e "${YELLOW}Warning: No matching rev${num}.dat for $(basename "$blk")${NC}"
    fi
  done
}

# ---------------------------------------------------------------------------
# validate_block_schema <json> <filename>
#   Validates the schema of a block JSON output.
# ---------------------------------------------------------------------------
validate_block_schema() {
  local json="$1" name="$2"

  print_section "Top-level block fields"

  assert_field_equals_json "$json" ".ok" "true" "ok == true" || true
  assert_field_equals "$json" ".mode" "block" "mode == block" || true

  # block_header
  assert_field_type "$json" ".block_header" "object" "block_header is object" || true
  assert_field_type "$json" ".block_header.version" "number" "block_header.version is number" || true
  assert_field_matches "$json" ".block_header.prev_block_hash" "$HEX64_REGEX" "prev_block_hash is 64-char hex" || true
  assert_field_matches "$json" ".block_header.merkle_root" "$HEX64_REGEX" "merkle_root is 64-char hex" || true
  assert_field_type "$json" ".block_header.merkle_root_valid" "boolean" "merkle_root_valid is boolean" || true
  assert_field_type "$json" ".block_header.timestamp" "number" "timestamp is number" || true
  assert_field_type "$json" ".block_header.bits" "string" "bits is string" || true
  assert_field_type "$json" ".block_header.nonce" "number" "nonce is number" || true
  assert_field_matches "$json" ".block_header.block_hash" "$HEX64_REGEX" "block_hash is 64-char hex" || true

  # tx_count
  assert_field_type "$json" ".tx_count" "number" "tx_count is number" || true

  # coinbase
  assert_field_type "$json" ".coinbase" "object" "coinbase is object" || true
  assert_field_type "$json" ".coinbase.bip34_height" "number" "coinbase.bip34_height is number" || true
  assert_field_type "$json" ".coinbase.coinbase_script_hex" "string" "coinbase.coinbase_script_hex is string" || true
  assert_field_type "$json" ".coinbase.total_output_sats" "number" "coinbase.total_output_sats is number" || true

  # transactions
  assert_field_type "$json" ".transactions" "array" "transactions is array" || true

  # block_stats
  assert_field_type "$json" ".block_stats" "object" "block_stats is object" || true
  assert_field_type "$json" ".block_stats.total_fees_sats" "number" "block_stats.total_fees_sats is number" || true
  assert_field_type "$json" ".block_stats.total_weight" "number" "block_stats.total_weight is number" || true
  assert_field_type "$json" ".block_stats.avg_fee_rate_sat_vb" "number" "block_stats.avg_fee_rate_sat_vb is number" || true
  assert_field_type "$json" ".block_stats.script_type_summary" "object" "block_stats.script_type_summary is object" || true

  # Validate a sample of transactions[] entries if present
  local tx_count
  tx_count=$(echo "$json" | jq '.transactions | length' 2>/dev/null) || tx_count=0
  if [[ $tx_count -gt 0 ]]; then
    print_section "Sample transaction schema (transactions[0])"
    local tx0
    tx0=$(echo "$json" | jq '.transactions[0]' 2>/dev/null)
    if [[ -n "$tx0" && "$tx0" != "null" ]]; then
      assert_field_matches "$json" ".transactions[0].txid" "$HEX64_REGEX" "transactions[0].txid is 64-char hex" || true
      assert_field_type "$json" ".transactions[0].version" "number" "transactions[0].version is number" || true
      assert_field_type "$json" ".transactions[0].vin" "array" "transactions[0].vin is array" || true
      assert_field_type "$json" ".transactions[0].vout" "array" "transactions[0].vout is array" || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# validate_block_consistency <json> <filename>
#   Cross-field consistency checks for blocks.
# ---------------------------------------------------------------------------
validate_block_consistency() {
  local json="$1" name="$2"

  print_section "Cross-field consistency"

  # transactions length == tx_count
  local tx_count arr_len
  tx_count=$(echo "$json" | jq '.tx_count' 2>/dev/null) || tx_count="null"
  arr_len=$(echo "$json" | jq '.transactions | length' 2>/dev/null) || arr_len="null"
  if [[ "$tx_count" == "$arr_len" ]]; then
    print_pass "transactions length ($arr_len) == tx_count ($tx_count)"
  else
    print_fail "transactions length == tx_count" "tx_count=$tx_count, array length=$arr_len"
  fi

  # merkle_root_valid == true
  local mrv
  mrv=$(echo "$json" | jq -r '.block_header.merkle_root_valid' 2>/dev/null) || mrv="null"
  if [[ "$mrv" == "true" ]]; then
    print_pass "merkle_root_valid == true"
  else
    print_fail "merkle_root_valid == true" "Got: $mrv"
  fi

  # Sum of non-coinbase fee_sats ≈ block_stats.total_fees_sats
  local sum_fees total_fees
  sum_fees=$(echo "$json" | jq '
    [.transactions[1:][]?.fee_sats // 0] | add // 0
  ' 2>/dev/null) || sum_fees="null"
  total_fees=$(echo "$json" | jq '.block_stats.total_fees_sats' 2>/dev/null) || total_fees="null"
  if [[ "$sum_fees" != "null" && "$total_fees" != "null" ]]; then
    local diff
    diff=$(echo "$json" | jq --argjson sf "$sum_fees" --argjson tf "$total_fees" '
      ($sf - $tf) | fabs
    ' 2>/dev/null) || diff="999999"
    # Allow small tolerance for rounding
    local ok
    ok=$(echo "$json" | jq --argjson d "$diff" '$d < 2' 2>/dev/null) || ok="false"
    if [[ "$ok" == "true" ]]; then
      print_pass "sum(non-coinbase fees) ≈ total_fees_sats"
    else
      print_fail "sum(non-coinbase fees) ≈ total_fees_sats" "sum=$sum_fees, total_fees=$total_fees"
    fi
  else
    print_fail "Could not compute fee sum comparison"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
print_header "Block Grader"

if [[ ! -f "./cli.sh" ]]; then
  echo -e "${RED}Error: cli.sh not found in $(pwd)${NC}" >&2
  exit 1
fi

if [[ ! -x "./cli.sh" ]]; then
  echo -e "${RED}Error: cli.sh is not executable. Run: chmod +x cli.sh${NC}" >&2
  exit 1
fi

discover_block_pairs

if [[ ${#BLOCK_PAIRS[@]} -eq 0 ]]; then
  echo -e "${RED}No block pairs found in $BLOCKS_DIR${NC}" >&2
  exit 1
fi

echo "Found ${#BLOCK_PAIRS[@]} block pair(s)"

for pair in "${BLOCK_PAIRS[@]}"; do
  IFS='|' read -r blk_file rev_file xor_file <<< "$pair"
  blk_name=$(basename "$blk_file" .dat)
  print_header "Block: $blk_name"

  # Clean out/ before each run
  rm -rf out/
  mkdir -p out

  # Run cli.sh --block
  echo "  Running: ./cli.sh --block $blk_file $rev_file $xor_file"
  run_cli --block "$blk_file" "$rev_file" "$xor_file"

  # Check exit code
  if [[ $CLI_EXIT -ne 0 ]]; then
    print_fail "Exit code == 0" "Got exit code: $CLI_EXIT"
    if [[ -n "$CLI_STDERR" ]]; then
      echo -e "  ${YELLOW}stderr: ${CLI_STDERR:0:200}${NC}"
    fi
    continue
  else
    print_pass "Exit code == 0"
  fi

  # Check that out/ contains at least one .json file
  out_files=( out/*.json )
  if [[ ! -f "${out_files[0]:-}" ]]; then
    print_fail "out/ contains at least one .json file" "No JSON files found in out/"
    continue
  fi

  file_count=${#out_files[@]}
  print_pass "out/ contains $file_count block JSON file(s)"

  # Validate each output file
  for out_file in "${out_files[@]}"; do
    out_name=$(basename "$out_file" .json)
    print_section "Validating $out_name"

    block_json=$(cat "$out_file" 2>/dev/null)

    # Valid JSON?
    if ! is_valid_json "$block_json"; then
      print_fail "$out_name is valid JSON"
      continue
    else
      print_pass "$out_name is valid JSON"
    fi

    # Check ok == true
    block_ok=$(echo "$block_json" | jq -r '.ok' 2>/dev/null) || block_ok="null"
    if [[ "$block_ok" != "true" ]]; then
      print_fail "ok == true in $out_name" "Got: $block_ok"
      continue
    else
      print_pass "ok == true"
    fi

    # Schema
    validate_block_schema "$block_json" "$out_name"

    # Consistency
    validate_block_consistency "$block_json" "$out_name"
  done
done

print_summary

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
