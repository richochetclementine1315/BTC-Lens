#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# grader/grade_transactions.sh — Grade CLI output against transaction fixtures
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$REPO_DIR/fixtures/transactions"
EXPECTED_DIR="$SCRIPT_DIR/expected/transactions"

cd "$REPO_DIR"
source "$SCRIPT_DIR/lib/common.sh"

check_jq

# ---------------------------------------------------------------------------
# Input script type enum
# ---------------------------------------------------------------------------
VALID_INPUT_SCRIPT_TYPES="p2pkh p2sh-p2wpkh p2sh-p2wsh p2wpkh p2wsh p2tr_keypath p2tr_scriptpath unknown"

# ---------------------------------------------------------------------------
# Output script type enum
# ---------------------------------------------------------------------------
VALID_OUTPUT_SCRIPT_TYPES="p2pkh p2sh p2wpkh p2wsh p2tr op_return unknown"

# ---------------------------------------------------------------------------
# Warning code enum
# ---------------------------------------------------------------------------
VALID_WARNING_CODES="HIGH_FEE DUST_OUTPUT UNKNOWN_OUTPUT_SCRIPT RBF_SIGNALING"

# ---------------------------------------------------------------------------
# validate_tx_schema <json> <fixture_name>
#   Validates the schema of a transaction JSON output.
# ---------------------------------------------------------------------------
validate_tx_schema() {
  local json="$1" name="$2"

  print_section "Top-level fields"

  # Required top-level fields
  assert_field_equals_json "$json" ".ok" "true" "ok == true" || true
  assert_field_exists "$json" ".network" "network exists" || true
  assert_field_type "$json" ".segwit" "boolean" "segwit is boolean" || true
  assert_field_matches "$json" ".txid" "$HEX64_REGEX" "txid is 64-char hex" || true
  assert_field_type "$json" ".version" "number" "version is number" || true
  assert_field_type "$json" ".locktime" "number" "locktime is number" || true
  assert_field_type "$json" ".size_bytes" "number" "size_bytes is number" || true
  assert_field_type "$json" ".weight" "number" "weight is number" || true
  assert_field_type "$json" ".vbytes" "number" "vbytes is number" || true
  assert_field_type "$json" ".total_input_sats" "number" "total_input_sats is number" || true
  assert_field_type "$json" ".total_output_sats" "number" "total_output_sats is number" || true
  assert_field_type "$json" ".fee_sats" "number" "fee_sats is number" || true
  assert_field_type "$json" ".fee_rate_sat_vb" "number" "fee_rate_sat_vb is number" || true
  assert_field_type "$json" ".rbf_signaling" "boolean" "rbf_signaling is boolean" || true
  assert_field_in "$json" ".locktime_type" "none" "block_height" "unix_timestamp" -- "locktime_type is valid enum" || true
  assert_field_type "$json" ".locktime_value" "number" "locktime_value is number" || true
  assert_field_type "$json" ".vin" "array" "vin is array" || true
  assert_field_type "$json" ".vout" "array" "vout is array" || true
  assert_field_type "$json" ".warnings" "array" "warnings is array" || true

  # wtxid: depends on segwit
  local is_segwit
  is_segwit=$(echo "$json" | jq -r '.segwit' 2>/dev/null) || is_segwit="null"
  if [[ "$is_segwit" == "true" ]]; then
    assert_field_matches "$json" ".wtxid" "$HEX64_REGEX" "wtxid is 64-char hex (segwit)" || true
  elif [[ "$is_segwit" == "false" ]]; then
    assert_field_is_null "$json" ".wtxid" "wtxid is null (non-segwit)" || true
  fi

  # segwit_savings: depends on segwit
  if [[ "$is_segwit" == "true" ]]; then
    assert_field_type "$json" ".segwit_savings" "object" "segwit_savings is object (segwit)" || true
    assert_field_type "$json" ".segwit_savings.witness_bytes" "number" "segwit_savings.witness_bytes is number" || true
    assert_field_type "$json" ".segwit_savings.non_witness_bytes" "number" "segwit_savings.non_witness_bytes is number" || true
    assert_field_type "$json" ".segwit_savings.total_bytes" "number" "segwit_savings.total_bytes is number" || true
    assert_field_type "$json" ".segwit_savings.weight_actual" "number" "segwit_savings.weight_actual is number" || true
    assert_field_type "$json" ".segwit_savings.weight_if_legacy" "number" "segwit_savings.weight_if_legacy is number" || true
    assert_field_type "$json" ".segwit_savings.savings_pct" "number" "segwit_savings.savings_pct is number" || true
  elif [[ "$is_segwit" == "false" ]]; then
    assert_field_is_null "$json" ".segwit_savings" "segwit_savings is null (non-segwit)" || true
  fi

  # --- vin[] schema ---
  print_section "vin[] schema"
  local vin_count
  vin_count=$(echo "$json" | jq '.vin | length' 2>/dev/null) || vin_count=0
  for ((i = 0; i < vin_count; i++)); do
    local prefix="vin[$i]"
    assert_field_matches "$json" ".vin[$i].txid" "$HEX64_REGEX" "$prefix.txid is 64-char hex" || true
    assert_field_type "$json" ".vin[$i].vout" "number" "$prefix.vout is number" || true
    assert_field_type "$json" ".vin[$i].sequence" "number" "$prefix.sequence is number" || true
    assert_field_type "$json" ".vin[$i].script_sig_hex" "string" "$prefix.script_sig_hex is string" || true
    assert_field_type "$json" ".vin[$i].script_asm" "string" "$prefix.script_asm is string" || true
    assert_field_type "$json" ".vin[$i].witness" "array" "$prefix.witness is array" || true

    # script_type enum
    local vin_st
    vin_st=$(echo "$json" | jq -r ".vin[$i].script_type" 2>/dev/null) || vin_st=""
    local st_valid=false
    for st in $VALID_INPUT_SCRIPT_TYPES; do
      [[ "$vin_st" == "$st" ]] && st_valid=true
    done
    if $st_valid; then
      print_pass "$prefix.script_type '$vin_st' is valid"
    else
      print_fail "$prefix.script_type '$vin_st' is not a valid input script type"
    fi

    # address: string or null
    local addr_type
    addr_type=$(echo "$json" | jq -r ".vin[$i].address | type" 2>/dev/null) || addr_type="ERROR"
    if [[ "$addr_type" == "string" || "$addr_type" == "null" ]]; then
      print_pass "$prefix.address is string or null"
    else
      print_fail "$prefix.address should be string or null" "Got type: $addr_type"
    fi

    # prevout object
    assert_field_type "$json" ".vin[$i].prevout" "object" "$prefix.prevout is object" || true
    assert_field_type "$json" ".vin[$i].prevout.value_sats" "number" "$prefix.prevout.value_sats is number" || true
    assert_field_type "$json" ".vin[$i].prevout.script_pubkey_hex" "string" "$prefix.prevout.script_pubkey_hex is string" || true

    # relative_timelock
    assert_field_type "$json" ".vin[$i].relative_timelock" "object" "$prefix.relative_timelock is object" || true
    assert_field_type "$json" ".vin[$i].relative_timelock.enabled" "boolean" "$prefix.relative_timelock.enabled is boolean" || true
  done

  # --- vout[] schema ---
  print_section "vout[] schema"
  local vout_count
  vout_count=$(echo "$json" | jq '.vout | length' 2>/dev/null) || vout_count=0
  for ((i = 0; i < vout_count; i++)); do
    local prefix="vout[$i]"
    assert_field_equals_json "$json" ".vout[$i].n" "$i" "$prefix.n == $i" || true
    assert_field_type "$json" ".vout[$i].value_sats" "number" "$prefix.value_sats is number" || true
    assert_field_type "$json" ".vout[$i].script_pubkey_hex" "string" "$prefix.script_pubkey_hex is string" || true
    assert_field_type "$json" ".vout[$i].script_asm" "string" "$prefix.script_asm is string" || true

    # script_type enum
    local vout_st
    vout_st=$(echo "$json" | jq -r ".vout[$i].script_type" 2>/dev/null) || vout_st=""
    local st_valid=false
    for st in $VALID_OUTPUT_SCRIPT_TYPES; do
      [[ "$vout_st" == "$st" ]] && st_valid=true
    done
    if $st_valid; then
      print_pass "$prefix.script_type '$vout_st' is valid"
    else
      print_fail "$prefix.script_type '$vout_st' is not a valid output script type"
    fi

    # address: string or null
    local addr_type
    addr_type=$(echo "$json" | jq -r ".vout[$i].address | type" 2>/dev/null) || addr_type="ERROR"
    if [[ "$addr_type" == "string" || "$addr_type" == "null" ]]; then
      print_pass "$prefix.address is string or null"
    else
      print_fail "$prefix.address should be string or null" "Got type: $addr_type"
    fi

    # OP_RETURN extra fields
    if [[ "$vout_st" == "op_return" ]]; then
      assert_field_type "$json" ".vout[$i].op_return_data_hex" "string" "$prefix.op_return_data_hex is string" || true
      local utf8_type
      utf8_type=$(echo "$json" | jq -r ".vout[$i].op_return_data_utf8 | type" 2>/dev/null) || utf8_type="ERROR"
      if [[ "$utf8_type" == "string" || "$utf8_type" == "null" ]]; then
        print_pass "$prefix.op_return_data_utf8 is string or null"
      else
        print_fail "$prefix.op_return_data_utf8 should be string or null" "Got type: $utf8_type"
      fi
      assert_field_in "$json" ".vout[$i].op_return_protocol" "unknown" "omni" "opentimestamps" -- "$prefix.op_return_protocol is valid" || true
    fi
  done
}

# ---------------------------------------------------------------------------
# validate_tx_consistency <json> <fixture_name>
#   Cross-field consistency checks.
# ---------------------------------------------------------------------------
validate_tx_consistency() {
  local json="$1" name="$2"

  print_section "Cross-field consistency"

  # fee_sats == total_input_sats - total_output_sats
  local fee_check
  fee_check=$(echo "$json" | jq '
    .fee_sats == (.total_input_sats - .total_output_sats)
  ' 2>/dev/null) || fee_check="false"
  if [[ "$fee_check" == "true" ]]; then
    print_pass "fee_sats == total_input - total_output"
  else
    local fee actual_diff
    fee=$(echo "$json" | jq '.fee_sats' 2>/dev/null)
    actual_diff=$(echo "$json" | jq '.total_input_sats - .total_output_sats' 2>/dev/null)
    print_fail "fee_sats == total_input - total_output" "fee_sats=$fee, diff=$actual_diff"
  fi

  # fee_rate_sat_vb ≈ fee_sats / vbytes (±0.02)
  local fee_rate_check
  fee_rate_check=$(echo "$json" | jq '
    if .vbytes == 0 then false
    else ((.fee_rate_sat_vb - (.fee_sats / .vbytes)) | fabs) < 0.02
    end
  ' 2>/dev/null) || fee_rate_check="false"
  if [[ "$fee_rate_check" == "true" ]]; then
    print_pass "fee_rate ≈ fee_sats / vbytes (±0.02)"
  else
    local fr fs vb
    fr=$(echo "$json" | jq '.fee_rate_sat_vb' 2>/dev/null)
    fs=$(echo "$json" | jq '.fee_sats' 2>/dev/null)
    vb=$(echo "$json" | jq '.vbytes' 2>/dev/null)
    print_fail "fee_rate ≈ fee_sats / vbytes (±0.02)" "fee_rate=$fr, fee=$fs, vbytes=$vb"
  fi

  # vbytes ≈ ceil(weight / 4) (±1)
  local vbytes_check
  vbytes_check=$(echo "$json" | jq '
    ((.vbytes - ((.weight + 3) / 4 | floor)) | fabs) <= 1
  ' 2>/dev/null) || vbytes_check="false"
  if [[ "$vbytes_check" == "true" ]]; then
    print_pass "vbytes ≈ ceil(weight / 4) (±1)"
  else
    local vb w
    vb=$(echo "$json" | jq '.vbytes' 2>/dev/null)
    w=$(echo "$json" | jq '.weight' 2>/dev/null)
    print_fail "vbytes ≈ ceil(weight / 4) (±1)" "vbytes=$vb, weight=$w, expected≈$(echo "$json" | jq '((.weight + 3) / 4 | floor)' 2>/dev/null)"
  fi

  # segwit_savings consistency
  local is_segwit
  is_segwit=$(echo "$json" | jq -r '.segwit' 2>/dev/null) || is_segwit="null"

  if [[ "$is_segwit" == "true" ]]; then
    # segwit_savings.total_bytes == size_bytes
    local total_bytes_check
    total_bytes_check=$(echo "$json" | jq '
      .segwit_savings.total_bytes == .size_bytes
    ' 2>/dev/null) || total_bytes_check="false"
    if [[ "$total_bytes_check" == "true" ]]; then
      print_pass "segwit_savings.total_bytes == size_bytes"
    else
      print_fail "segwit_savings.total_bytes == size_bytes" \
        "total_bytes=$(echo "$json" | jq '.segwit_savings.total_bytes' 2>/dev/null), size_bytes=$(echo "$json" | jq '.size_bytes' 2>/dev/null)"
    fi

    # segwit_savings.weight_actual == weight
    local weight_check
    weight_check=$(echo "$json" | jq '
      .segwit_savings.weight_actual == .weight
    ' 2>/dev/null) || weight_check="false"
    if [[ "$weight_check" == "true" ]]; then
      print_pass "segwit_savings.weight_actual == weight"
    else
      print_fail "segwit_savings.weight_actual == weight" \
        "weight_actual=$(echo "$json" | jq '.segwit_savings.weight_actual' 2>/dev/null), weight=$(echo "$json" | jq '.weight' 2>/dev/null)"
    fi
  fi

  # Warning consistency checks
  print_section "Warning consistency"

  local rbf
  rbf=$(echo "$json" | jq -r '.rbf_signaling' 2>/dev/null) || rbf="null"
  local has_rbf_warning
  has_rbf_warning=$(echo "$json" | jq '[.warnings[]?.code] | any(. == "RBF_SIGNALING")' 2>/dev/null) || has_rbf_warning="false"
  if [[ "$rbf" == "true" ]]; then
    if [[ "$has_rbf_warning" == "true" ]]; then
      print_pass "RBF_SIGNALING warning present when rbf_signaling=true"
    else
      print_fail "RBF_SIGNALING warning missing" "rbf_signaling=true but no RBF_SIGNALING warning"
    fi
  else
    if [[ "$has_rbf_warning" == "false" ]]; then
      print_pass "No RBF_SIGNALING warning when rbf_signaling=false"
    else
      print_fail "Unexpected RBF_SIGNALING warning" "rbf_signaling=false but RBF_SIGNALING warning present"
    fi
  fi

  # HIGH_FEE check
  local high_fee_expected
  high_fee_expected=$(echo "$json" | jq '
    (.fee_sats > 1000000) or (.fee_rate_sat_vb > 200)
  ' 2>/dev/null) || high_fee_expected="false"
  local has_high_fee
  has_high_fee=$(echo "$json" | jq '[.warnings[]?.code] | any(. == "HIGH_FEE")' 2>/dev/null) || has_high_fee="false"
  if [[ "$high_fee_expected" == "true" ]]; then
    if [[ "$has_high_fee" == "true" ]]; then
      print_pass "HIGH_FEE warning present when fee is high"
    else
      print_fail "HIGH_FEE warning missing" "Fee conditions met but no HIGH_FEE warning"
    fi
  else
    if [[ "$has_high_fee" == "false" ]]; then
      print_pass "No HIGH_FEE warning (fee is normal)"
    else
      print_fail "Unexpected HIGH_FEE warning" "Fee conditions not met but HIGH_FEE present"
    fi
  fi

  # DUST_OUTPUT check
  local dust_expected
  dust_expected=$(echo "$json" | jq '
    [.vout[] | select(.script_type != "op_return" and .value_sats < 546)] | length > 0
  ' 2>/dev/null) || dust_expected="false"
  local has_dust
  has_dust=$(echo "$json" | jq '[.warnings[]?.code] | any(. == "DUST_OUTPUT")' 2>/dev/null) || has_dust="false"
  if [[ "$dust_expected" == "true" ]]; then
    if [[ "$has_dust" == "true" ]]; then
      print_pass "DUST_OUTPUT warning present for dust outputs"
    else
      print_fail "DUST_OUTPUT warning missing" "Dust outputs found but no DUST_OUTPUT warning"
    fi
  else
    if [[ "$has_dust" == "false" ]]; then
      print_pass "No DUST_OUTPUT warning (no dust outputs)"
    else
      print_fail "Unexpected DUST_OUTPUT warning" "No dust outputs but DUST_OUTPUT present"
    fi
  fi

  # UNKNOWN_OUTPUT_SCRIPT check
  local unknown_expected
  unknown_expected=$(echo "$json" | jq '
    [.vout[] | select(.script_type == "unknown")] | length > 0
  ' 2>/dev/null) || unknown_expected="false"
  local has_unknown
  has_unknown=$(echo "$json" | jq '[.warnings[]?.code] | any(. == "UNKNOWN_OUTPUT_SCRIPT")' 2>/dev/null) || has_unknown="false"
  if [[ "$unknown_expected" == "true" ]]; then
    if [[ "$has_unknown" == "true" ]]; then
      print_pass "UNKNOWN_OUTPUT_SCRIPT warning present"
    else
      print_fail "UNKNOWN_OUTPUT_SCRIPT warning missing"
    fi
  else
    if [[ "$has_unknown" == "false" ]]; then
      print_pass "No UNKNOWN_OUTPUT_SCRIPT warning"
    else
      print_fail "Unexpected UNKNOWN_OUTPUT_SCRIPT warning"
    fi
  fi
}

# ---------------------------------------------------------------------------
# compare_expected <json> <fixture_name>
#   Compares against partial expected output (if file exists).
# ---------------------------------------------------------------------------
compare_expected() {
  local json="$1" name="$2"
  local expected_file="$EXPECTED_DIR/${name}.json"

  if [[ ! -f "$expected_file" ]]; then
    print_skip "No expected file for $name"
    return 0
  fi

  print_section "Expected value comparison ($name)"

  local expected
  expected=$(cat "$expected_file")

  # Compare each key present in the expected file
  local keys
  keys=$(echo "$expected" | jq -r 'keys[]' 2>/dev/null) || return 0

  for key in $keys; do
    local exp_val act_val

    case "$key" in
      vout_script_types)
        # Compare as sorted arrays
        local exp_sorted act_sorted
        exp_sorted=$(echo "$expected" | jq -S '.vout_script_types | sort')
        act_sorted=$(echo "$json" | jq -S '[.vout[].script_type] | sort')
        if [[ "$exp_sorted" == "$act_sorted" ]]; then
          print_pass "vout_script_types match"
        else
          print_fail "vout_script_types mismatch" "Expected: $exp_sorted, Got: $act_sorted"
        fi
        ;;
      vin_count)
        exp_val=$(echo "$expected" | jq '.vin_count')
        act_val=$(echo "$json" | jq '.vin | length')
        if [[ "$exp_val" == "$act_val" ]]; then
          print_pass "vin count == $exp_val"
        else
          print_fail "vin count" "Expected: $exp_val, Got: $act_val"
        fi
        ;;
      vout_count)
        exp_val=$(echo "$expected" | jq '.vout_count')
        act_val=$(echo "$json" | jq '.vout | length')
        if [[ "$exp_val" == "$act_val" ]]; then
          print_pass "vout count == $exp_val"
        else
          print_fail "vout count" "Expected: $exp_val, Got: $act_val"
        fi
        ;;
      fee_rate_sat_vb)
        # Numeric tolerance ±0.01
        assert_field_approx "$json" ".$key" "$(echo "$expected" | jq ".$key")" "0.02" "$key matches expected (±0.02)" || true
        ;;
      ok|network|segwit|txid|wtxid|version|locktime|fee_sats|total_input_sats|total_output_sats|rbf_signaling|locktime_type|size_bytes|weight|vbytes)
        exp_val=$(echo "$expected" | jq ".$key")
        act_val=$(echo "$json" | jq ".$key")
        if [[ "$exp_val" == "$act_val" ]]; then
          print_pass "$key == $exp_val"
        else
          print_fail "$key" "Expected: $exp_val, Got: $act_val"
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
print_header "Transaction Grader"

if [[ ! -f "./cli.sh" ]]; then
  echo -e "${RED}Error: cli.sh not found in $(pwd)${NC}" >&2
  exit 1
fi

if [[ ! -x "./cli.sh" ]]; then
  echo -e "${RED}Error: cli.sh is not executable. Run: chmod +x cli.sh${NC}" >&2
  exit 1
fi

# Collect fixtures
fixtures=()
for f in "$FIXTURES_DIR"/*.json; do
  [[ -f "$f" ]] && fixtures+=("$f")
done

if [[ ${#fixtures[@]} -eq 0 ]]; then
  echo -e "${RED}No fixtures found in $FIXTURES_DIR${NC}" >&2
  exit 1
fi

echo "Found ${#fixtures[@]} transaction fixture(s)"

for fixture in "${fixtures[@]}"; do
  fixture_name=$(basename "$fixture" .json)
  print_header "Fixture: $fixture_name"

  # Run cli.sh
  echo "  Running: ./cli.sh $fixture"
  run_cli "$fixture"

  # Check exit code
  if [[ $CLI_EXIT -ne 0 ]]; then
    print_fail "Exit code == 0" "Got exit code: $CLI_EXIT"
    if [[ -n "$CLI_STDERR" ]]; then
      echo -e "  ${YELLOW}stderr: ${CLI_STDERR:0:200}${NC}"
    fi
    # Try to parse stdout anyway for partial credit
    if [[ -z "$CLI_STDOUT" ]]; then
      echo -e "  ${YELLOW}No stdout output — skipping further checks for this fixture${NC}"
      continue
    fi
  else
    print_pass "Exit code == 0"
  fi

  # Check valid JSON
  if ! is_valid_json "$CLI_STDOUT"; then
    print_fail "stdout is valid JSON"
    echo -e "  ${YELLOW}stdout (first 200 chars): ${CLI_STDOUT:0:200}${NC}"
    continue
  else
    print_pass "stdout is valid JSON"
  fi

  # Check ok == true
  local_ok=$(echo "$CLI_STDOUT" | jq -r '.ok' 2>/dev/null) || local_ok="null"
  if [[ "$local_ok" != "true" ]]; then
    print_fail "ok == true" "Got: $local_ok"
    err_msg=$(echo "$CLI_STDOUT" | jq -r '.error.message // "none"' 2>/dev/null)
    echo -e "  ${YELLOW}Error message: $err_msg${NC}"
    continue
  else
    print_pass "ok == true"
  fi

  # Schema validation
  validate_tx_schema "$CLI_STDOUT" "$fixture_name"

  # Cross-field consistency
  validate_tx_consistency "$CLI_STDOUT" "$fixture_name"

  # Expected value comparison
  compare_expected "$CLI_STDOUT" "$fixture_name"
done

print_summary

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
