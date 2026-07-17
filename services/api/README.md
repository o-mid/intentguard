# API

Go HTTP service for IntentGuard: auth, intents → plans, per-step approve against Anvil.

## Env

| Var | Required | Default |
|-----|----------|---------|
| `DATABASE_URL` | yes | — |
| `JWT_SECRET` | yes | — |
| `PORT` | no | `8080` |
| `JWT_ACCESS_TTL` | no | `15m` |
| `JWT_REFRESH_TTL` | no | `168h` |
| `MIGRATIONS_PATH` | no | `migrations` |
| `CHAIN_RPC_URL` | no | `http://127.0.0.1:8545` |
| `EXECUTOR_PRIVATE_KEY` | no | Anvil account #0 (local demo only) |
| `DEPLOYMENTS_PATH` | no | `../../contracts/deployments/anvil.json` |
| `PLANNER_MODE` | no | `mock` |
| `LLM_API_KEY` | if `PLANNER_MODE=llm` | — |
| `LLM_BASE_URL` | no | `https://api.openai.com/v1` |
| `LLM_MODEL` | no | `gpt-4o-mini` |

`EXECUTOR_PRIVATE_KEY` default is Anvil’s first unlocked key — never use on a real network.

### Planner modes

- `PLANNER_MODE=mock` (default, compose/CI): deterministic keyword fixtures, no network, no API key.
- `PLANNER_MODE=llm`: OpenAI-compatible chat completions. Set `LLM_API_KEY`. Optional `LLM_BASE_URL` / `LLM_MODEL` for other providers.

LLM output is still JSON-schema validated and policy-checked before any step can be approved. Timeouts and one retry surface as HTTP `503` / `planner_unavailable`. Model hex is never executed.

## Compose (API + Postgres + Anvil)

```bash
cd deploy
docker compose up --build
```

In another shell (Foundry installed):

```bash
./scripts/deploy-anvil.sh
./scripts/seed-anvil.sh
```

## Run API only

```bash
export DATABASE_URL='postgres://intentguard:intentguard@localhost:5432/intentguard?sslmode=disable'
export JWT_SECRET='dev-only-change-me'
export CHAIN_RPC_URL='http://127.0.0.1:8545'
export DEPLOYMENTS_PATH='../../contracts/deployments/anvil.json'
go test ./...
go run ./cmd/api
```

## Demo path

```bash
# register / login, then:
curl -s -X POST localhost:8080/intents -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' -d '{"text":"swap 10 USDC"}'
# approve steps 0 then 1
curl -s -X POST localhost:8080/plans/$PLAN_ID/steps/0/approve -H "Authorization: Bearer $ACCESS_TOKEN"
curl -s -X POST localhost:8080/plans/$PLAN_ID/steps/1/approve -H "Authorization: Bearer $ACCESS_TOKEN"
curl -s localhost:8080/health
```

## Intents (mock planner)

With `PLANNER_MODE=mock`:

- `swap 10 USDC` → approve + swap (`awaiting_approval`)
- `transfer 5 USDC` → allowlisted transfer
- `bridge funds somewhere` → `rejected_schema`
- `transfer to unknown wallet` → `rejected_policy`
- `swap 150 USDC` → `rejected_policy` (amount cap)

```bash
# optional: live planner against an OpenAI-compatible API
export PLANNER_MODE=llm
export LLM_API_KEY=sk-...
# export LLM_BASE_URL=https://api.openai.com/v1
# export LLM_MODEL=gpt-4o-mini
```
