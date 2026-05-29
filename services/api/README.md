# API

Go HTTP service for IntentGuard. Phase 2 exposes health only.

```bash
cd services/api
go test ./...
go run ./cmd/api
curl -s localhost:8080/health
```

`PORT` defaults to `8080`.
