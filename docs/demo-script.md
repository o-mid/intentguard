# Demo script

End-to-end path on the local compose stack. Target: under ~15 minutes with Foundry installed.

## Prerequisites

- Docker
- Foundry (`forge`, `cast`, `anvil` — Anvil also runs in compose)
- `curl` + `jq` (optional but handy)

## 1. Start the stack

```bash
cd deploy
docker compose up --build
```

Wait until API logs show it is listening. Postgres `:5432`, Anvil `:8545`, API `:8080`.

## 2. Deploy and seed mocks

From the repo root (host Foundry talking to compose Anvil):

```bash
./scripts/deploy-anvil.sh
./scripts/seed-anvil.sh
```

Confirm health:

```bash
curl -s localhost:8080/health | jq .
```

## 3. Register and login

```bash
curl -s -X POST localhost:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@wallet.test","password":"password123"}' | jq .

ACCESS=$(curl -s -X POST localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@wallet.test","password":"password123"}' | jq -r .access_token)
```

## 4. Happy path — swap

```bash
RESP=$(curl -s -X POST localhost:8080/intents \
  -H "Authorization: Bearer $ACCESS" \
  -H 'Content-Type: application/json' \
  -d '{"text":"swap 10 USDC"}')
echo "$RESP" | jq .
PLAN_ID=$(echo "$RESP" | jq -r .plan.id)
```

Expect plan status `awaiting_approval` with approve + swap steps.

```bash
curl -s -X POST "localhost:8080/plans/$PLAN_ID/steps/0/approve" \
  -H "Authorization: Bearer $ACCESS" | jq .
curl -s -X POST "localhost:8080/plans/$PLAN_ID/steps/1/approve" \
  -H "Authorization: Bearer $ACCESS" | jq .
curl -s "localhost:8080/plans/$PLAN_ID" \
  -H "Authorization: Bearer $ACCESS" | jq .
```

Expect step statuses `succeeded` and plan `completed`.

## 5. Reject path — policy

```bash
curl -s -X POST localhost:8080/intents \
  -H "Authorization: Bearer $ACCESS" \
  -H 'Content-Type: application/json' \
  -d '{"text":"swap 150 USDC"}' | jq .
```

Expect `rejected_policy` / `amount_over_cap`. No executable approve path.

## 6. Reject path — schema

```bash
curl -s -X POST localhost:8080/intents \
  -H "Authorization: Bearer $ACCESS" \
  -H 'Content-Type: application/json' \
  -d '{"text":"bridge funds somewhere"}' | jq .
```

Expect `rejected_schema`.

## 7. Flutter (optional)

```bash
cd apps/mobile
flutter run --dart-define=API_BASE=http://127.0.0.1:8080
```

Sign in → New intent → use chip `swap 10 USDC` → Approve steps → check History.

## Notes

- Compose sets `PLANNER_MODE=mock` (no LLM key).
- Anvil key defaults are local demo only — never point this stack at a real network.
- Eval fixtures: `cd services/api && go run ./cmd/evals -dir ../../evals/cases`
