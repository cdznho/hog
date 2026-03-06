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
- `Import insights` on an org lets you paste structured JSON for coverage heatmap rows and recommendations so each cycle can be compared against the previous one.
- `Import from report` accepts either a local HTML file path or a deployed report URL such as `https://headofgrowth.pro/mbrella`.

## Coverage JSON example

```json
[
  {
    "category": "Mobility Budget",
    "subcategory": "Legal Framework",
    "pillar_status": "Missing",
    "cluster_current": 0,
    "cluster_target": 5,
    "coverage": "Empty",
    "priority": "High"
  },
  {
    "category": "Mobility Budget",
    "subcategory": "Calculation & Pillars",
    "pillar_status": "Partial",
    "cluster_current": 2,
    "cluster_target": 5,
    "coverage": "Partial",
    "priority": "High"
  }
]
```

## Recommendations JSON example

```json
[
  {
    "title": "Publish legal framework pillar",
    "status": "Open",
    "priority": "High",
    "owner": "SEO"
  }
]
```
