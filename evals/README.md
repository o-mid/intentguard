# Evals

YAML fixtures for mock-planner accept/reject gates (schema + policy).

```bash
cd services/api
go run ./cmd/evals -dir ../../evals/cases
```

| `expect` | Meaning |
|----------|---------|
| `accept` | Schema + policy pass |
| `reject_schema` | Plan fails JSON Schema |
| `reject_policy` | Schema ok; policy codes fail |
| `planner_error` | Mock planner cannot plan |
