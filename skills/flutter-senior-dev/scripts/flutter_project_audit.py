#!/usr/bin/env python3
"""
Quick Flutter/Dart project audit.

Goal: produce high-signal, low-noise checks without requiring Flutter/Dart installed.

Usage:
  python3 scripts/flutter_project_audit.py /path/to/project
  python3 scripts/flutter_project_audit.py . --json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DEPENDENCY_SECTION_RE = re.compile(r"^(dependencies|dev_dependencies|dependency_overrides)\s*:\s*$")
YAML_KV_RE = re.compile(r"^([A-Za-z0-9_]+)\s*:\s*(.*)\s*$")


@dataclass(frozen=True)
class Finding:
    level: str  # info|warn|error
    code: str
    message: str
    file: str | None = None


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None


def detect_flutter_project(root: Path) -> tuple[Path | None, list[Finding]]:
    findings: list[Finding] = []

    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        findings.append(
            Finding(
                level="error",
                code="pubspec.missing",
                message="No pubspec.yaml found. Provide the Flutter/Dart project root.",
            )
        )
        return None, findings

    findings.append(
        Finding(level="info", code="pubspec.found", message="Found pubspec.yaml.", file=str(pubspec))
    )

    # Heuristic: Flutter projects usually have android/ios, and pubspec has `flutter:`.
    pubspec_text = read_text(pubspec) or ""
    has_flutter_block = bool(re.search(r"^flutter\s*:\s*$", pubspec_text, re.MULTILINE))
    if has_flutter_block:
        findings.append(
            Finding(level="info", code="flutter.block", message="pubspec.yaml contains a `flutter:` section.")
        )
    else:
        findings.append(
            Finding(
                level="warn",
                code="flutter.block.missing",
                message="pubspec.yaml has no `flutter:` section (may be a pure Dart package).",
            )
        )

    for platform_dir in ("android", "ios", "web", "macos", "windows", "linux"):
        if (root / platform_dir).exists():
            findings.append(
                Finding(level="info", code=f"platform.{platform_dir}", message=f"Platform folder present: {platform_dir}/")
            )

    return pubspec, findings


def parse_dependencies(pubspec_text: str) -> dict[str, list[str]]:
    deps: dict[str, list[str]] = {"dependencies": [], "dev_dependencies": [], "dependency_overrides": []}
    current: str | None = None

    for raw_line in pubspec_text.splitlines():
        line = raw_line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue

        section_match = DEPENDENCY_SECTION_RE.match(line.strip())
        if section_match:
            current = section_match.group(1)
            continue

        if current and line.startswith("  "):
            kv = YAML_KV_RE.match(line.strip())
            if kv:
                deps[current].append(kv.group(1))
            continue

        # Stop if indentation resets.
        current = None

    for key in deps:
        deps[key] = sorted(set(deps[key]))

    return deps


def audit_structure(root: Path) -> Iterable[Finding]:
    lib_dir = root / "lib"
    if not lib_dir.exists():
        yield Finding(level="warn", code="lib.missing", message="No lib/ directory found (unexpected for Flutter app).")
        return

    yield Finding(level="info", code="lib.found", message="Found lib/ directory.")

    common_top = ["features", "core", "app", "shared", "l10n"]
    present = [d for d in common_top if (lib_dir / d).exists()]
    if present:
        yield Finding(
            level="info",
            code="lib.structure",
            message=f"Top-level lib/ folders present: {', '.join(present)}.",
        )
    else:
        yield Finding(
            level="warn",
            code="lib.structure.unknown",
            message="No common lib/ structure folders found (features/core/app/shared). If the app is growing, consider feature-first + core/shared split.",
        )

    for bad_dir in ("lib/generated", "lib/gen"):
        if (root / bad_dir).exists():
            yield Finding(
                level="warn",
                code="generated.in.lib",
                message=f"Generated code found at {bad_dir}/. Prefer keeping generated code alongside sources or under a dedicated generated/ folder excluded from manual edits, following repo conventions.",
            )


def audit_tooling(root: Path, deps: dict[str, list[str]]) -> Iterable[Finding]:
    analysis_options = root / "analysis_options.yaml"
    if analysis_options.exists():
        yield Finding(level="info", code="analysis_options.found", message="Found analysis_options.yaml.")
    else:
        yield Finding(
            level="warn",
            code="analysis_options.missing",
            message="No analysis_options.yaml found. Add one to enforce consistent lints (e.g., flutter_lints or custom rules).",
        )

    if deps["dependency_overrides"]:
        yield Finding(
            level="warn",
            code="dependency_overrides.present",
            message=f"dependency_overrides present: {', '.join(deps['dependency_overrides'])}. Avoid in production; document why and remove ASAP.",
            file=str(root / "pubspec.yaml"),
        )

    if "build_runner" in deps["dev_dependencies"]:
        yield Finding(
            level="info",
            code="build_runner.present",
            message="build_runner present (codegen workflows likely).",
        )
    else:
        # Only suggest if codegen packages exist.
        codegen_indicators = {"freezed", "json_serializable", "hive_generator", "injectable_generator", "riverpod_generator"}
        used_codegen = sorted(codegen_indicators.intersection(set(deps["dependencies"] + deps["dev_dependencies"])))
        if used_codegen:
            yield Finding(
                level="warn",
                code="build_runner.missing",
                message=f"Codegen package(s) present ({', '.join(used_codegen)}) but build_runner missing in dev_dependencies.",
                file=str(root / "pubspec.yaml"),
            )

    if "flutter_lints" in deps["dev_dependencies"]:
        yield Finding(level="info", code="flutter_lints.present", message="flutter_lints present.")

    if (root / "melos.yaml").exists():
        yield Finding(level="info", code="melos.present", message="melos.yaml present (monorepo).")


def recommend_commands(is_flutter_project: bool) -> list[str]:
    if not is_flutter_project:
        return ["dart format .", "dart analyze", "dart test"]
    return [
        "dart format .",
        "flutter analyze",
        "flutter test",
        "dart run build_runner build --delete-conflicting-outputs  # if codegen is used",
        "flutter run --profile  # for performance issues",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Quick Flutter/Dart project audit (no Flutter required).")
    parser.add_argument("project_root", nargs="?", default=".", help="Path to the Flutter/Dart project root")
    parser.add_argument("--json", action="store_true", help="Output machine-readable JSON")
    args = parser.parse_args()

    root = Path(os.path.expanduser(args.project_root)).resolve()
    pubspec_path, findings = detect_flutter_project(root)
    if pubspec_path is None:
        return print_output(findings, commands=[], as_json=args.json)

    pubspec_text = read_text(pubspec_path) or ""
    deps = parse_dependencies(pubspec_text)
    is_flutter_project = bool(re.search(r"^flutter\s*:\s*$", pubspec_text, re.MULTILINE)) or (root / "android").exists() or (root / "ios").exists()

    findings.extend(audit_structure(root))
    findings.extend(audit_tooling(root, deps))

    commands = recommend_commands(is_flutter_project)
    return print_output(findings, commands=commands, as_json=args.json, deps=deps)


def print_output(
    findings: list[Finding],
    commands: list[str],
    *,
    as_json: bool,
    deps: dict[str, list[str]] | None = None,
) -> int:
    exit_code = 0
    if any(f.level == "error" for f in findings):
        exit_code = 2
    elif any(f.level == "warn" for f in findings):
        exit_code = 1

    if as_json:
        payload = {
            "exit_code": exit_code,
            "findings": [f.__dict__ for f in findings],
            "commands": commands,
        }
        if deps is not None:
            payload["dependencies"] = deps
        print(json.dumps(payload, indent=2))
        return exit_code

    def bucket(level: str) -> list[Finding]:
        return [f for f in findings if f.level == level]

    for level, header in (("error", "ERRORS"), ("warn", "WARNINGS"), ("info", "INFO")):
        items = bucket(level)
        if not items:
            continue
        print(f"\n{header}")
        for f in items:
            loc = f" ({f.file})" if f.file else ""
            print(f"- [{f.code}]{loc} {f.message}")

    if deps is not None:
        print("\nDEPENDENCIES (top-level names only)")
        for key in ("dependencies", "dev_dependencies", "dependency_overrides"):
            names = deps.get(key, [])
            if names:
                print(f"- {key}: {', '.join(names)}")

    if commands:
        print("\nRECOMMENDED COMMANDS")
        for cmd in commands:
            print(f"- {cmd}")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

