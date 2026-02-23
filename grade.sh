#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# grade.sh — Top-level grader runner
#
# Runs both the transaction grader and block grader, reports overall results.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRADER_DIR="$SCRIPT_DIR/grader"

# Colors
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  BOLD=''
  NC=''
fi

tx_pass=0
blk_pass=0
overall=0

echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}             Bitcoin Analyzer — Grading Suite                ${NC}"
echo -e "${BOLD}============================================================${NC}"

# --- Transaction grading ---
echo ""
echo -e "${BOLD}[1/2] Running transaction grader...${NC}"
echo ""

if "$GRADER_DIR/grade_transactions.sh"; then
  tx_pass=1
  echo -e "${GREEN}Transaction grader: PASSED${NC}"
else
  echo -e "${RED}Transaction grader: FAILED${NC}"
fi

# --- Block grading ---
echo ""
echo -e "${BOLD}[2/2] Running block grader...${NC}"
echo ""

if "$GRADER_DIR/grade_blocks.sh"; then
  blk_pass=1
  echo -e "${GREEN}Block grader: PASSED${NC}"
else
  echo -e "${RED}Block grader: FAILED${NC}"
fi

# --- Overall ---
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}                     Overall Results                        ${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

if [[ $tx_pass -eq 1 ]]; then
  echo -e "  Transactions: ${GREEN}PASS${NC}"
else
  echo -e "  Transactions: ${RED}FAIL${NC}"
fi

if [[ $blk_pass -eq 1 ]]; then
  echo -e "  Blocks:       ${GREEN}PASS${NC}"
else
  echo -e "  Blocks:       ${RED}FAIL${NC}"
fi

echo ""

if [[ $tx_pass -eq 1 && $blk_pass -eq 1 ]]; then
  echo -e "  ${GREEN}${BOLD}ALL GRADERS PASSED${NC}"
  echo ""
  exit 0
else
  echo -e "  ${RED}${BOLD}SOME GRADERS FAILED${NC}"
  echo ""
  exit 1
fi
