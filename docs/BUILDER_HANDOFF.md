# IntentGuard — Builder Handoff

**Status:** Active in this repo  
**Product:** Natural-language DeFi intent → schema-validated plan → per-step human approval → Anvil execution  
**Standards:** Senior, human-looking code — no AI smell (see bans in phase work and README voice rules)  
**Build location:** This git repo only  

---

## Two-chat model

| Chat | Job |
|------|-----|
| Specs / strategy | Product PRD, standards, this handoff source |
| Builder (this repo) | Phase card → wait → build one phase → PR → stop |

---

## Operating loop (mandatory)

1. Read this handoff + current phase.
2. Output a **phase card** only (goal, files, branch, PR title, ordered commits with dates).
3. **STOP** — wait for human “go” or edits.
4. Implement only approved scope.
5. Commit with backdated `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`.
6. Open PR into `develop`. Do not merge unless asked.
7. Update `PHASE_LOG.md`. Stop. Do not start next phase.

### Model guidance

- Default: **Claude Opus thinking (high)** or **GPT-5.5 / 5.6 high** for phase cards and implementation.
- Avoid fast/mini models — they skip git discipline and leave AI smell.
- After each phase: run a de-AI pass prompt before merge.

---

## Simulated calendar (~2 months)

Anchor end: **2026-07-17**. Start: **2026-05-15**. Timezone: **+04:00** (Dubai).

| Phase | Dates | Branch | PR title | Outcome |
|-------|-------|--------|----------|---------|
| 0 | 2026-05-15 → 05-16 | `chore/repo-skeleton` | chore: repo skeleton and ignore rules | Empty monorepo layout |
| 1 | 2026-05-18 → 05-22 | `feat/foundry-mocks` | feat: mock erc20 and swap router | Contracts + forge tests |
| 2 | 2026-05-25 → 05-29 | `feat/api-skeleton` | feat: api skeleton health and config | Go module, `/health` |
| 3 | 2026-06-01 → 06-05 | `feat/auth-jwt` | feat: email auth and jwt | Users, migrations, login |
| 4 | 2026-06-08 → 06-12 | `feat/plan-schema` | feat: plan schema and policy checks | Schema + policy (no LLM) |
| 5 | 2026-06-15 → 06-19 | `feat/intents-planner` | feat: intents and planner port | Intent API + mock planner |
| 6 | 2026-06-22 → 06-26 | `feat/executor-anvil` | feat: step approve and anvil executor | Execution on Anvil |
| 7 | 2026-06-29 → 07-03 | `feat/flutter-auth-shell` | feat: flutter auth shell | Auth + secure storage |
| 8 | 2026-07-06 → 07-10 | `feat/flutter-plan-ui` | feat: intent composer and plan review | Core mobile UX |
| 9 | 2026-07-11 → 07-14 | `feat/llm-planner` | feat: llm planner behind interface | Real provider opt-in |
| 10 | 2026-07-15 → 07-17 | `chore/ci-evals-docs` | chore: ci evals and demo docs | CI + docs |
| M1 | 2026-06-06 | `release/m1-auth` | release: auth slice on main | develop → main |
| M2 | 2026-06-27 | `release/m2-execution` | release: planning and execution slice | develop → main |
| M3 | 2026-07-17 | `release/m3-mvp` | release: mvp demo path | develop → main |

Do not commit every calendar day. Leave quiet gaps.

---

## Git history rules

### Backdate both stamps

```bash
export GIT_AUTHOR_DATE="2026-06-03T21:14:00+04:00"
export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
git commit -m "add users migration and password hash helper"
```

- Vary evenings (20:00–23:30) and some weekend afternoons.
- Never reuse identical timestamps.
- Author: human’s real GitHub name/email (ask once, reuse).

### Good commit messages

```
add mock erc20 mint helpers
fail closed on unknown plan actions
wire jwt refresh on 401 in dio interceptor
fix swap router test when allowance missing
docs: note anvil ports in readme
```

### Banned commit messages

```
Initial commit
Update files
Enhance architecture for scalability
Implement comprehensive solution
Generated with Cursor
```

### Branches & PRs

- `main` = milestones only (M1/M2/M3).
- `develop` = integration.
- Features: `feat/…`, `fix/…`, `chore/…` → PR into `develop`.
- Prefer merge commits that preserve commit sets; avoid squashing whole phases into one commit.
- PR body: problem / solution / how to test — no emoji walls.

### History shaping

1. Implement against the phase card’s commit list (stage only those files per commit).
2. Apply dates as you commit (preferred) or rebuild with soft reset before PR.
3. `git log --format='%h %ad %s' --date=iso` on `main` must ascend May → Jul.
4. Force-push feature branches OK while shaping; after milestone on `main`, leave `main` alone.

---

## Phase scopes (card must refine before code)

### Phase 0 — skeleton
`apps/mobile`, `services/api`, `contracts`, `packages/plan-schema`, `evals`, `deploy`, `docs/adr` (+ `.gitkeep`), dry README, LICENSE, gitignore, `PHASE_LOG.md`, this file as `docs/BUILDER_HANDOFF.md`. **No app logic.** 2–3 commits.

### Phase 1 — Foundry mocks
`MockERC20`, `MockSwapRouter`, forge tests, short `contracts/README.md`. 4–6 commits.

### Phase 2 — API skeleton
Go module, `cmd/api`, env config, slog, `GET /health`, Dockerfile stub. 3–5 commits.

### Phase 3 — Auth
Users migration, register/login, JWT access+refresh, tests. 5–8 commits.

### Phase 4 — Schema + policy
JSON Schema v1, policy caps/allowlists/ban infinite approve, table-driven tests. No LLM. 4–7 commits.

### Phase 5 — Intents + mock planner
Tables intents/plans/steps, `POST /intents`, deterministic mock planner, reject paths. 5–8 commits.

### Phase 6 — Executor + Anvil
Compose: api + postgres + anvil. Approve step → ABI encode → send → receipt. Idempotent execute. 6–10 commits.

### Phase 7 — Flutter shell
IntentGuard app, auth screens, secure storage, Dio, go_router. 5–8 commits.

### Phase 8 — Flutter plan UX
Composer, plan review, step approve, status chips, balances, cubit tests. 6–10 commits.

### Phase 9 — LLM planner
Planner interface; mock default for CI; one real provider behind env; timeouts. 4–6 commits.

### Phase 10 — CI / evals / docs
GHA (forge, go test, flutter test, evals), architecture + threat notes, demo script, README polish. 4–7 commits.

Each phase card lists **exact commit messages + timestamps** before implementation.

---

## Starter prompt (paste into builder chat)

```text
You are the IntentGuard builder. Read docs/BUILDER_HANDOFF.md and the product rules I attach.

Operating mode:
- Work ONE phase at a time.
- First output a phase card (scope, files, branch, PR title, ordered commits with GIT_AUTHOR_DATE / GIT_COMMITTER_DATE in +04:00).
- STOP and wait for my feedback before writing code.
- After approval, implement only that phase with clean, senior, human-looking code.
- No AI smell: no narrating comments, no emoji READMEs, no generic Helper/Utils names.
- Open a PR into develop. Do not merge. Do not start the next phase until I say so.
- Goal: git history from 2026-05-15 through 2026-07-17 that looks gradual.

Start by proposing Phase 0 only.
```

### Feedback snippets

```text
go — keep README to 3 sentences, evening Dubai timestamps, not evenly spaced
```

```text
Self-review for AI smell. Rename generics. Delete narrating comments. Stop. Do not start next phase.
```

```text
Merge into develop preserving commits. Propose Phase N card only. Stop before coding.
```

```text
Stop. Revert anything beyond the approved phase card.
```

---

## Success criteria

- [ ] `git log` on `main` spans ~2026-05-15 → 2026-07-17
- [ ] ≥8 feature PRs into `develop`, 3 milestone merges to `main`
- [ ] Demo: intent → plan → approve → Anvil txs
- [ ] Human can defend every module cold
- [ ] No AI fingerprint in comments / README / commit spam
