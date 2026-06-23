#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RPC_URL="${CHAIN_RPC_URL:-http://127.0.0.1:8545}"
# Anvil account #0 (local demo only)
PK="${EXECUTOR_PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
OUT="${ROOT}/contracts/deployments/anvil.json"

cd "${ROOT}/contracts"
forge script script/Deploy.s.sol:DeployMocks \
  --rpc-url "${RPC_URL}" \
  --private-key "${PK}" \
  --broadcast \
  -vv

# Resolve addresses from broadcast run for chain 31337
BROADCAST="$(ls -t broadcast/Deploy.s.sol/31337/run-latest.json | head -1)"
python3 - <<PY
import json, pathlib
raw = json.loads(pathlib.Path("${BROADCAST}").read_text())
txs = raw.get("transactions", [])
addrs = [t["contractAddress"] for t in txs if t.get("contractAddress")]
if len(addrs) < 3:
    raise SystemExit(f"expected 3 deployments, got {addrs}")
doc = {
    "chainId": 31337,
    "rpcUrl": "${RPC_URL}",
    "demoAccount": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "tokens": {
        "MOCK_USDC": addrs[0],
        "MOCK_ETH": addrs[1],
    },
    "MockSwapRouter": addrs[2],
}
pathlib.Path("${OUT}").write_text(json.dumps(doc, indent=2) + "\n")
print("wrote", "${OUT}")
print(json.dumps(doc, indent=2))
PY
