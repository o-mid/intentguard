# API

Go HTTP service for IntentGuard. Auth: register/login/JWT + `/auth/me`.

## Env

| Var | Required | Default |
|-----|----------|---------|
| `DATABASE_URL` | yes | — |
| `JWT_SECRET` | yes | — |
| `PORT` | no | `8080` |
| `JWT_ACCESS_TTL` | no | `15m` |
| `JWT_REFRESH_TTL` | no | `168h` |
| `MIGRATIONS_PATH` | no | `migrations` |

## Postgres (local)

```bash
docker run --name intentguard-pg -e POSTGRES_USER=intentguard -e POSTGRES_PASSWORD=intentguard -e POSTGRES_DB=intentguard -p 5432:5432 -d postgres:16
```

## Run

```bash
export DATABASE_URL='postgres://intentguard:intentguard@localhost:5432/intentguard?sslmode=disable'
export JWT_SECRET='dev-only-change-me'
go test ./...
go run ./cmd/api
```

```bash
curl -s -X POST localhost:8080/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"alice@wallet.test","password":"password123"}'
curl -s -X POST localhost:8080/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"alice@wallet.test","password":"password123"}'
curl -s localhost:8080/auth/me -H "Authorization: Bearer $ACCESS_TOKEN"
```

## Intents (mock planner)

Authenticated `POST /intents` with `{"text":"..."}`. Example strings the mock planner understands:

- `swap 10 USDC` → approve + swap plan (`awaiting_approval`)
- `transfer 5 USDC` → allowlisted transfer
- `bridge funds somewhere` → `rejected_schema`
- `transfer to unknown wallet` → `rejected_policy`
- `swap 150 USDC` → `rejected_policy` (amount cap)

```bash
curl -s -X POST localhost:8080/intents -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' -d '{"text":"swap 10 USDC"}'
curl -s localhost:8080/plans/$PLAN_ID -H "Authorization: Bearer $ACCESS_TOKEN"
```
