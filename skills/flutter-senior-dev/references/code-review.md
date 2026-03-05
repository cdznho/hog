# Flutter/Dart PR review rubric (senior defaults)

## 1) Correctness

- Edge cases: loading/error/empty/offline/permissions handled?
- No crashes on null/empty states; exceptions are surfaced sensibly.
- Business logic is tested or easily testable.

## 2) Architecture & maintainability

- UI vs logic split is clear (widgets render; logic elsewhere).
- State management matches repo convention; avoids new patterns unless justified.
- Dependencies are injected at boundaries; no new hidden globals.
- Naming and folder placement match the module/feature structure.

## 3) Performance

- Avoid unnecessary rebuilds; small widget boundaries; `const` where appropriate.
- Lists are virtualized; no work per-frame in `build`.
- Expensive work moved off UI thread where appropriate.

## 4) UX & accessibility

- a11y: semantics labels, focus order, tap targets, contrast (as applicable).
- i18n: user-visible strings localized; no hardcoded text.
- Error messages are actionable; retry flows exist.

## 5) Tooling quality gates

- `dart format .` clean
- `flutter analyze` clean (or deviations explained)
- `flutter test` passes; new tests added for new behavior
- Codegen workflows documented if introduced

## 6) Security & privacy (if relevant)

- Secrets not committed; config handled via secure channels.
- PII handled carefully; logs don’t leak sensitive content.

