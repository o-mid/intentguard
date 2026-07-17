IntentGuard turns a natural-language DeFi intent into a schema-validated multi-step plan, requires per-step human approval, then executes against Foundry mocks on Anvil.

Layout: `apps/mobile` (Flutter), `services/api` (Go), `contracts` (Foundry), `packages/plan-schema`, `evals`, `deploy`, `docs`.

Planner defaults to `PLANNER_MODE=mock` (no API key). Set `PLANNER_MODE=llm` plus `LLM_API_KEY` for an OpenAI-compatible provider — see `services/api/README.md`.

See `services/api/README.md` and `contracts/README.md` to run locally.
