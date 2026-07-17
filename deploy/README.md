# Deploy

Local stack: Postgres, Anvil, API.

```bash
docker compose up --build
```

Then from the repo root (with Foundry):

```bash
./scripts/deploy-anvil.sh
./scripts/seed-anvil.sh
```

API listens on `:8080`. Anvil on `:8545`. See `services/api/README.md` for the approve demo.
