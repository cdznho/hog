# Growth Memory UI (Flutter)

Polished local UI for the PRD in `prd.md`: orgs → cycles → snapshots → artifacts (reports).

## Run

Prereqs: Flutter installed.

```bash
cd apps/growth_memory_ui
flutter pub get
flutter run -d macos   # or -d chrome
```

## Notes

- Desktop builds use SQLite at the path shown in Settings.
- Web builds use an in-memory store (no persistence).
- `Run pack (beta)` calls `run_pack llm-seo ...` via `Process.start`; install the CLI runner on your PATH for it to work, then it will auto-attach a detected report path when available.

