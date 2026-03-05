# Flutter senior playbook (quick checklists)

Use this as a compact reference when planning work. Keep changes aligned with the existing codebase conventions.

## New feature checklist

- Clarify UX states: loading, empty, error, offline, retry, permissions.
- Define data contract (DTOs) vs domain model mapping.
- Pick state approach consistent with the codebase (Riverpod/BLoC/Cubit/etc.).
- Add analytics/crash logs at boundaries (not inside pure domain logic).
- Write tests for critical paths (unit/widget; integration if it’s a core flow).
- Validate a11y (semantics, focus, tap targets) and i18n.

## Refactor checklist (safe refactors)

- Identify public APIs and avoid breaking changes unless requested.
- Refactor in small steps; keep behavior identical; add characterization tests first when needed.
- Keep diffs surgical: avoid renames/reformatting across unrelated files.
- Add/adjust tests to match the new boundaries.

## Performance checklist

- Reproduce in profile mode; capture device + OS + Flutter version.
- Confirm whether bottleneck is UI thread vs raster thread.
- Reduce rebuild scope: split widgets, `const`, selectors (`select(...)`), memoization.
- Avoid heavy layouts in scrolling lists; prefer builders + slivers.
- Fix image issues: decode size, caching, avoid huge source images.
- Move heavy parsing/compute off the UI thread (isolates/`compute`).

## Build/codegen checklist

- Standard workflow:
  - `flutter pub get`
  - `dart run build_runner build --delete-conflicting-outputs`
- If codegen is flaky:
  - delete conflicting outputs
  - ensure builder versions are compatible
  - avoid custom builders that scan large directories

## Release readiness checklist

- Increment version properly; document breaking changes.
- Verify flavors/env config (`--dart-define` or build-time config) and secrets handling.
- Ensure signing configs exist (Android keystore / iOS provisioning).
- Validate crash reporting, analytics, and privacy requirements.
- Smoke test on real devices for each target platform.

