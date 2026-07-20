# Demo captures

## Latest

- Recording: [`recordings/latest.mp4`](recordings/latest.mp4)
- Screenshots: [`recordings/latest-screenshots/`](recordings/latest-screenshots)

## Re-record

```bash
cd deploy && docker compose up --build -d
cd .. && ./scripts/deploy-anvil.sh && ./scripts/seed-anvil.sh
./scripts/record_demo_walkthrough.sh
```

Requires iOS Simulator + API on `http://127.0.0.1:8080`.
