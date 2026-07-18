# IntentGuard

Natural-language DeFi intent → schema-validated multi-step plan → per-step human approval → execute against Foundry mocks on Anvil.

The planner (mock or LLM) is **untrusted**. Nothing hits the chain without JSON Schema validation, a server-side policy engine, and an explicit human Approve per step. The executor never runs raw model hex — it ABI-encodes stored step JSON only.

Tag: [`v0.1.0`](https://github.com/o-mid/intentguard/releases/tag/v0.1.0) (MVP demo path on `main`).

---

## How it works

1. **Compose** — User submits an intent string (e.g. `swap 10 USDC`) from Flutter or `curl`.
2. **Plan** — `Planner` returns a versioned Plan JSON (`approve` / `swap` / `transfer` steps).
3. **Gate** — API validates against Plan Schema v1, then runs policy (spend cap, allowlists, max steps, slippage).
4. **Review** — On pass, plan is `awaiting_approval`. User sees decoded step summaries and Approves or Rejects.
5. **Execute** — Each approved step is encoded and sent to Anvil; status + tx hash persist. Steps run in order.
6. **Reject paths** — Schema/policy failures never become executable; user Reject cancels the plan.

```text
Intent text
    → Planner (mock | llm)
    → JSON Schema
    → Policy engine
    → Human Approve (per step)
    → ABI encode + Anvil tx
```

Mock fixtures for demos:

| Intent | Result |
|--------|--------|
| `swap 10 USDC` | accept → approve + swap |
| `transfer 5 USDC` | accept → allowlisted transfer |
| `swap 150 USDC` | `rejected_policy` (`amount_over_cap`) |
| `bridge funds somewhere` | `rejected_schema` |
| `transfer to unknown wallet` | `rejected_policy` (`bad_recipient`) |
| `infinite approve MOCK_USDC` | `rejected_schema` |

---

## Architecture

```mermaid
flowchart LR
  user[User]
  flutter[FlutterApp]
  api[GoAPI]
  planner[Planner]
  pg[(Postgres)]
  anvil[Anvil]
  mocks[MockContracts]

  user --> flutter
  flutter -->|JWT| api
  api --> pg
  api --> planner
  api -->|eth_send| anvil
  anvil --> mocks
```

```mermaid
stateDiagram-v2
  [*] --> Planning
  Planning --> RejectedSchema: schema_fail
  Planning --> RejectedPolicy: policy_fail
  Planning --> AwaitingApproval: valid
  AwaitingApproval --> Executing: approve_step
  Executing --> AwaitingApproval: more_steps
  Executing --> Completed: all_ok
  Executing --> Failed: revert
  AwaitingApproval --> Cancelled: reject_plan
```

More detail: [`docs/architecture.md`](docs/architecture.md) · threats: [`docs/threat-model.md`](docs/threat-model.md) · demo script: [`docs/demo-script.md`](docs/demo-script.md).

### Trust boundaries

| Zone | Trust |
|------|-------|
| Planner / LLM output | Untrusted |
| Flutter client | Untrusted (server scopes by user + plan id) |
| Schema + policy + executor | Trusted compute |
| Anvil private key | Local demo only — never use on a real network |
| Mock contracts | Trusted fixtures you control |

---

## Tech stack

| Layer | Choice |
|-------|--------|
| Mobile | Flutter 3.38+, Dart 3.10+, Bloc/Cubit, GetIt, go_router, Dio, flutter_secure_storage |
| API | Go 1.26, `net/http`, Postgres (pgx), JWT (access + refresh), slog |
| Schema | JSON Schema v1 in `packages/plan-schema` + Go validate |
| Chain | Foundry (forge/anvil), Solidity 0.8.24 mocks |
| Planner | Interface + `MockPlanner` default; optional OpenAI-compatible `LLMPlanner` |
| Infra | Docker Compose (API + Postgres 16 + Anvil) |
| CI | GitHub Actions: `forge test`, `go test`, `flutter test`, eval runner |

---

## Repository layout

```text
apps/mobile/           Flutter client — auth, composer, plan review, history, balances
services/api/          Go HTTP API — auth, intents, planner, policy, executor
packages/plan-schema/  Plan JSON Schema + Go Parse/Validate
contracts/             MockERC20, MockSwapRouter, Foundry tests, deployments/
evals/                 YAML accept/reject fixtures (≥12) + runner via cmd/evals
deploy/                docker-compose.yml
scripts/               deploy-anvil.sh, seed-anvil.sh
docs/                  architecture, threat-model, demo-script
.github/workflows/     ci.yml
```

### Components

| Component | Responsibility |
|-----------|----------------|
| **Flutter app** | Register/login, secure token storage, intent chips, step cards, Approve/Reject, history |
| **Auth** | Email/password, bcrypt, JWT access + refresh, `/auth/me` |
| **Intents service** | Persist intent → call planner → schema → policy → store plan/steps |
| **Planner** | `Plan(ctx, text) → Plan`; `PLANNER_MODE=mock\|llm` |
| **Policy** | Caps, allowlisted recipients/spenders/tokens, max steps, slippage, no infinite approve |
| **Executor** | Ordered step approve, ABI encode, send tx, idempotent succeed |
| **Contracts** | Local ERC-20 + fixed-rate swap router for demos |
| **Evals** | CI gate: intent → expect `accept` / `reject_schema` / `reject_policy` / `planner_error` |

---

## Prerequisites

- Docker
- Foundry (`forge`, `cast`) for deploy/seed against compose Anvil
- Go 1.26+ (API tests / local run)
- Flutter 3.38.6+ (mobile; SDK `^3.10.7`)
- `curl` + `jq` optional for the API demo

---

## Build and run

### 1. Full stack (recommended)

```bash
git clone https://github.com/o-mid/intentguard.git
cd intentguard
git checkout v0.1.0   # or main

cd deploy && docker compose up --build
```

In another shell from the **repo root** (Foundry on the host → compose Anvil):

```bash
./scripts/deploy-anvil.sh
./scripts/seed-anvil.sh
curl -s localhost:8080/health
```

- API: `http://127.0.0.1:8080`
- Anvil: `http://127.0.0.1:8545`
- Postgres: `localhost:5432` (user/pass/db `intentguard`)

Compose sets `PLANNER_MODE=mock` (no API key).

### 2. API only (dev)

```bash
export DATABASE_URL='postgres://intentguard:intentguard@localhost:5432/intentguard?sslmode=disable'
export JWT_SECRET='dev-only-change-me'
export CHAIN_RPC_URL='http://127.0.0.1:8545'
export DEPLOYMENTS_PATH='../../contracts/deployments/anvil.json'
cd services/api
go test ./...
go run ./cmd/api
```

### 3. Mobile

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8080
# Android emulator:
# flutter run --dart-define=API_BASE=http://10.0.2.2:8080
```

### 4. Contracts

```bash
cd contracts
forge test
```

### 5. Evals

```bash
cd services/api
go run ./cmd/evals -dir ../../evals/cases
```

---

## Environment (API)

| Var | Required | Default / notes |
|-----|----------|-----------------|
| `DATABASE_URL` | yes | Postgres DSN |
| `JWT_SECRET` | yes | HS signing secret |
| `PORT` | no | `8080` |
| `PLANNER_MODE` | no | `mock` (CI/compose); `llm` needs key |
| `LLM_API_KEY` | if llm | — |
| `LLM_BASE_URL` | no | `https://api.openai.com/v1` |
| `LLM_MODEL` | no | `gpt-4o-mini` |
| `CHAIN_RPC_URL` | no | `http://127.0.0.1:8545` |
| `EXECUTOR_PRIVATE_KEY` | no | Anvil account #0 — **local demo only** |
| `DEPLOYMENTS_PATH` | no | `contracts/deployments/anvil.json` |
| `MIGRATIONS_PATH` | no | `migrations` |

See [`services/api/README.md`](services/api/README.md).

---

## Quick API demo

```bash
# register / login
curl -s -X POST localhost:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@wallet.test","password":"password123"}'

ACCESS=$(curl -s -X POST localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@wallet.test","password":"password123"}' | jq -r .access_token)

# happy path
RESP=$(curl -s -X POST localhost:8080/intents \
  -H "Authorization: Bearer $ACCESS" \
  -H 'Content-Type: application/json' \
  -d '{"text":"swap 10 USDC"}')
PLAN_ID=$(echo "$RESP" | jq -r .plan.id)

curl -s -X POST "localhost:8080/plans/$PLAN_ID/steps/0/approve" -H "Authorization: Bearer $ACCESS"
curl -s -X POST "localhost:8080/plans/$PLAN_ID/steps/1/approve" -H "Authorization: Bearer $ACCESS"
curl -s "localhost:8080/plans/$PLAN_ID" -H "Authorization: Bearer $ACCESS" | jq .

# policy reject (no execute path)
curl -s -X POST localhost:8080/intents \
  -H "Authorization: Bearer $ACCESS" \
  -H 'Content-Type: application/json' \
  -d '{"text":"swap 150 USDC"}' | jq .
```

Full walkthrough: [`docs/demo-script.md`](docs/demo-script.md).

---

## Tests / CI

```bash
cd contracts && forge test
cd packages/plan-schema && go test ./...
cd services/api && go test ./...
cd services/api && go run ./cmd/evals -dir ../../evals/cases
cd apps/mobile && flutter test
```

GitHub Actions runs the same gates on PRs (`.github/workflows/ci.yml`).

---

## Branches

- `develop` — integration line for day-to-day work
- `main` — milestone snapshots only (M1 auth, M2 execution, M3 MVP). Prefer `main` / `v0.1.0` for demos.

---

## Design notes

- Actions v1: `approve`, `swap`, `transfer` only.
- Policy enforced server-side (not only in the prompt).
- Per-step human approval required; no autonomous agent loop.
- Idempotent step execution; prior steps must succeed before the next.
- This is a **local architecture demo**, not a mainnet wallet or custodial product.
