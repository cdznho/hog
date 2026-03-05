---
name: flutter-senior-dev
description: Top-notch senior Flutter/Dart development workflows: architecture, feature implementation, bug fixes, refactors, performance profiling, testing, and release readiness. Use when working on Flutter apps/packages (Android/iOS/Web/Desktop), reviewing PRs, designing state management and navigation, debugging build_runner/codegen issues, improving app performance/jank, adding analytics/crash reporting, or setting up CI quality gates (format/analyze/test/build).
---

# Flutter Senior Dev

## Overview

Act like a senior Flutter engineer: gather constraints, propose an approach, implement clean changes with tests, and ship-quality polish (performance, accessibility, reliability).

## Default workflow (use this unless user says otherwise)

1. **Confirm context**: target platforms, Flutter channel/version, constraints (deadline, scope, risk tolerance), current state management, navigation, and backend contracts.
2. **Run a quick audit** (optional but recommended): use `scripts/flutter_project_audit.py` to spot common structural/tooling issues.
3. **Propose a plan**: 3–7 steps, with risks + testing strategy.
4. **Implement**: small diffs, avoid unrelated churn, keep public APIs stable unless asked.
5. **Quality gates**:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
   - If relevant: integration tests + golden tests + a debug/profile run.
6. **Hand-off**: summarize what changed, how to verify, and any follow-ups.

## Architecture & code standards (senior defaults)

- **Prefer feature-first structure** for apps: `lib/features/<feature>/{data,domain,presentation}`.
- **Keep UI dumb**: widgets render state; business logic lives in controllers/notifiers/use-cases.
- **State management**:
  - Default to **Riverpod** for new code unless the codebase standard is BLoC/Cubit.
  - For simple state: `ValueNotifier`/`ChangeNotifier` is fine, but keep it local.
- **Navigation**: prefer a single router (often `go_router`) with typed routes where possible; avoid scattering `Navigator.push` everywhere.
- **Dependencies**: minimize globals/singletons; use DI at boundaries.
- **Error handling**: model failures explicitly (domain errors), and map to UX + logging at the edge.
- **A11y**: semantics labels for tappables/images; adequate contrast; large tap targets.
- **i18n**: don’t hardcode user-facing strings; use `flutter_localizations`/`intl` patterns used by the app.

## Performance playbook (when user says “slow”, “janky”, “battery”, “stutters”)

1. Reproduce in **profile mode**; capture device + build details.
2. Use **Flutter DevTools**:
   - Performance (frame chart): look for raster vs UI thread bottlenecks.
   - Widget rebuild stats: identify hot widgets.
   - Memory tab: leaks / image cache growth.
3. Common fixes:
   - Reduce rebuild scope (split widgets, `const`, selectors like `ref.watch(provider.select(...))`).
   - Move heavy work off the UI thread (`compute`/isolates), batch IO.
   - Avoid expensive layouts in lists; use `ListView.builder`, `SliverList`, `RepaintBoundary` only where it helps.
   - Prefer cached images; size images correctly; avoid decoding huge images.

## Testing guidance (ship-quality expectation)

- **Unit tests** for pure logic (parsers, mappers, use-cases).
- **Widget tests** for UI logic (error/empty/loading states).
- **Integration tests** for end-to-end critical flows (auth, checkout, onboarding).
- Avoid flaky tests: control time, randomness, network, and animations.

## Build system & codegen (common senior fixes)

- When touching generated code, ensure the correct workflow is used:
  - `flutter pub get`
  - `dart run build_runner build --delete-conflicting-outputs` (or `watch`)
- If `build_runner` gets slow: reduce builders, fix broad `build.yaml`, avoid scanning large folders, and commit generated outputs only if the repo standard requires it.

## What to read / run from this skill

- **Project audit**: Run `python3 scripts/flutter_project_audit.py /path/to/flutter/project` to get quick signals about structure/tooling.
- **Detailed checklists**: Read `references/playbook.md` when planning architecture, refactors, CI, or release readiness.
- **PR review rubric**: Read `references/code-review.md` when asked to review Flutter/Dart code.
