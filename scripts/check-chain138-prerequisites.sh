#!/usr/bin/env bash
set -euo pipefail

RPC_URL="${RPC_URL:-${CHAIN138_RPC_URL:-https://rpc.d-bis.org}}"
ALLOW_FALLBACK="${CHAIN138_ALLOW_FALLBACK:-0}"

CREATE3_FACTORY="0xFa3e9a110E6975ec868E9ed72ac6034eE4255B64"
PERMIT2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
ROUTER="0xDec80E988F4baF43be69c13711453013c212feA8"
FALLBACK_CREATE3_FACTORY="0x486B2E145F486eFA0190a60259B5BB464BD6b22b"
FALLBACK_ROUTER="0xE7f51632381d0791eC5c05F5585e7b1bFf1de5F5"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 127
  fi
}

code_size() {
  local address="$1"
  local code
  code="$(cast code "$address" --rpc-url "$RPC_URL")"
  if [[ "$code" == "0x" ]]; then
    echo 0
  else
    echo $(((${#code} - 2) / 2))
  fi
}

check_required() {
  local label="$1"
  local address="$2"
  local size
  size="$(code_size "$address")"
  if [[ "$size" -eq 0 ]]; then
    echo "MISSING  $label $address"
    return 1
  fi
  echo "OK       $label $address code_size=$size"
}

check_optional() {
  local label="$1"
  local address="$2"
  local size
  size="$(code_size "$address")"
  if [[ "$size" -eq 0 ]]; then
    echo "PENDING  $label $address"
  else
    echo "OK       $label $address code_size=$size"
  fi
}

require_command cast

echo "Protocolink Chain 138 prerequisite check"
echo "RPC_URL=$RPC_URL"
echo "CHAIN138_ALLOW_FALLBACK=$ALLOW_FALLBACK"

missing=0
fallback_missing=0
check_required "CREATE3Factory" "$CREATE3_FACTORY" || missing=1
check_required "Permit2" "$PERMIT2" || missing=1
check_optional "Router" "$ROUTER"
check_required "Fallback CREATE3Factory" "$FALLBACK_CREATE3_FACTORY" || fallback_missing=1
check_required "Fallback Router" "$FALLBACK_ROUTER" || fallback_missing=1

if [[ "$missing" -ne 0 ]]; then
  echo
  if [[ "$ALLOW_FALLBACK" == "1" && "$fallback_missing" -eq 0 ]]; then
    echo "Canonical Chain 138 prerequisites are not ready, but fallback prerequisites are live."
    exit 0
  fi
  echo "Chain 138 prerequisites are not ready. Deploy missing required contracts before broadcasting DeployChain138."
  exit 1
fi
