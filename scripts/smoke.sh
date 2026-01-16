#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:3000}
CLAIM_ID=${CLAIM_ID:-CLM-1001}

red() { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }

check() {
  local path=$1
  if curl -fsS "${BASE_URL}${path}" >/dev/null; then
    green "OK ${path}"
  else
    red "FAIL ${path}" && exit 1
  fi
}

echo "Smoke testing Claim Status API at ${BASE_URL} with claim ${CLAIM_ID}"
check "/claims/${CLAIM_ID}"
curl -fsS -X POST "${BASE_URL}/claims/${CLAIM_ID}/summarize" >/dev/null && green "OK /claims/${CLAIM_ID}/summarize" || { red "FAIL summarize"; exit 1; }
