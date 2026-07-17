#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RPC_URL="${CHAIN_RPC_URL:-http://127.0.0.1:8545}"
PK="${EXECUTOR_PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
DEPLOYMENTS="${ROOT}/contracts/deployments/anvil.json"
DEMO="$(python3 -c 'import json; print(json.load(open("'"${DEPLOYMENTS}"'"))["demoAccount"])')"
USDC="$(python3 -c 'import json; print(json.load(open("'"${DEPLOYMENTS}"'"))["tokens"]["MOCK_USDC"])')"
ETH="$(python3 -c 'import json; print(json.load(open("'"${DEPLOYMENTS}"'"))["tokens"]["MOCK_ETH"])')"
ROUTER="$(python3 -c 'import json; print(json.load(open("'"${DEPLOYMENTS}"'"))["MockSwapRouter"])')"

# 1_000_000 MOCK_USDC and 1_000 MOCK_ETH to demo account; fund router with ETH liquidity.
AMOUNT_USDC=1000000000000000000000000
AMOUNT_ETH=1000000000000000000000
ROUTER_ETH=100000000000000000000000

cast send --rpc-url "${RPC_URL}" --private-key "${PK}" "${USDC}" "mint(address,uint256)" "${DEMO}" "${AMOUNT_USDC}"
cast send --rpc-url "${RPC_URL}" --private-key "${PK}" "${ETH}" "mint(address,uint256)" "${DEMO}" "${AMOUNT_ETH}"
cast send --rpc-url "${RPC_URL}" --private-key "${PK}" "${ETH}" "mint(address,uint256)" "${ROUTER}" "${ROUTER_ETH}"

echo "seeded demo=${DEMO}"
cast call --rpc-url "${RPC_URL}" "${USDC}" "balanceOf(address)(uint256)" "${DEMO}"
cast call --rpc-url "${RPC_URL}" "${ETH}" "balanceOf(address)(uint256)" "${DEMO}"
