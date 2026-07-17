# Contracts

Foundry mocks for local IntentGuard demos: `MockERC20` and a fixed-rate `MockSwapRouter`.

```bash
forge test
anvil --chain-id 31337
./scripts/deploy-anvil.sh   # from repo root; writes deployments/anvil.json
./scripts/seed-anvil.sh     # mint MOCK_USDC / MOCK_ETH to Anvil account #0
```

Addresses in `deployments/anvil.json` match the first three CREATE deployments from Anvil account #0.
