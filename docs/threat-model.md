# Threat model (MVP)

Scope: local demo stack (Flutter → Go API → Postgres → Anvil mocks). Not a mainnet custody system.

## Assets

| Asset | Why it matters |
|-------|----------------|
| User JWT session | Access to that user’s intents/plans |
| Plan step payloads | What gets ABI-encoded and sent |
| Executor private key | Signs Anvil txs (demo key only) |
| Policy config | Spend caps, allowlists |

## Threats and controls

| Threat | Control |
|--------|---------|
| Prompt injection → evil calldata | Schema allowlist of actions/fields; executor encodes from stored structured steps, never raw model hex |
| Infinite / unbounded approve | Schema + policy reject (`unlimited`, over-cap amounts) |
| Transfer to attacker address | Recipient allowlist (`bad_recipient`) |
| Silent auto-execution | Per-step human approve required; no agent loop |
| Skip ahead in step order | Executor enforces prior steps succeeded |
| Replay / double-submit step | Step status machine + idempotent succeed short-circuit |
| Planner outage / garbage JSON | Timeout + one retry → `planner_unavailable`; unusable output does not execute |
| Policy bypass via client | Caps and allowlists enforced server-side |
| Key theft from repo/demo | Document Anvil account #0 as local-only; never use on real networks |
| Cross-user plan access | Plans loaded by id scoped to authenticated user |

## Explicit non-goals (out of scope)

- Mainnet, real DEX liquidity, MEV, bridges
- Custodial key management / MPC
- Production LLM cost controls or multi-tenant isolation beyond JWT + Postgres row ownership
- Treating the model as a trusted planner

## Residual risk

A compromised API process or leaked Anvil key can move demo tokens on the local chain. Treat compose credentials and `EXECUTOR_PRIVATE_KEY` as disposable local secrets.
