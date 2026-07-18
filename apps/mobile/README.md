# IntentGuard mobile

Flutter client for IntentGuard.

## Run (simulator / desktop)

```bash
flutter run --dart-define=API_BASE=http://127.0.0.1:8080
```

## Run (physical phone)

`127.0.0.1` is the phone itself. Point at your Mac’s LAN IP:

```bash
# on the Mac
ipconfig getifaddr en0

flutter run --dart-define=API_BASE=http://192.168.x.x:8080
```

Phone and Mac must be on the same Wi‑Fi. API must be up (`curl http://192.168.x.x:8080/health`).

Android emulator:

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2:8080
```
