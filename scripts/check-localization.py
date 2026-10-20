#!/usr/bin/env python3
"""Check that literal SwiftUI copy has a Simplified Chinese translation."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STRINGS_FILE = ROOT / "WrapPin/Resources/zh-Hans.lproj/Localizable.strings"
APP_SHORTCUTS_FILE = ROOT / "WrapPin/Resources/zh-Hans.lproj/AppShortcuts.strings"
SWIFT_ROOT = ROOT / "WrapPin"
NATIVE_ROOT = ROOT / "Native/WrapPinPairingFFI"

STRINGS_KEY = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=')
LOCALIZED_CALLS = re.compile(
    r'(?:String\(localized:|NSLocalizedString\(|Text\(|Label\(|Button\(|Toggle\('
    r'|Section\(|LabeledContent\(|Picker\(|\.navigationTitle\(|\.alert\('
    r'|\.confirmationDialog\(|\.accessibilityLabel\(|\.accessibilityHint\('
    # App Intents metadata, dialogs and errors shown by Shortcuts and Siri.
    r'|LocalizedStringResource\(|LocalizedStringResource\s*=|IntentDescription\('
    r'|TypeDisplayRepresentation\(name:|@Parameter\(title:|shortTitle:|settingsRowLabel\()'
    r'\s*"((?:\\.|[^"\\])*)"'
)
# Parameter summaries are looked up with ${parameter} placeholders.
PARAMETER_SUMMARIES = re.compile(r'Summary\(\s*"((?:\\.|[^"\\])*)"')
# Siri phrases must name the app; they are localized in AppShortcuts.strings.
SHORTCUT_PHRASES = re.compile(r'"([^"\n]*\\\(\.applicationName\)[^"\n]*)"')
INTENT_PLACEHOLDER = re.compile(r'\\\(\\?\.\$?(\w+)\)')
# Rust user-facing messages: owned strings, coordinate validation and the
# location engine's structured errors.
NATIVE_MESSAGES = re.compile(
    r'"([^"\n]+)"\.to_string\(\)'
    r'|\bErr\(\s*"([^"\n]+)"\s*\)'
    r'|LocationError::(?:new|recoverable)\(\s*[\w:]+,\s*"([^"\n]+)"'
)


def load_keys() -> tuple[set[str], list[str]]:
    keys: list[str] = []
    for line in STRINGS_FILE.read_text(encoding="utf-8").splitlines():
        match = STRINGS_KEY.match(line)
        if match:
            keys.append(match.group(1))
    duplicates = sorted(key for key, count in Counter(keys).items() if count > 1)
    return set(keys), duplicates


def intent_key(literal: str) -> str:
    return INTENT_PLACEHOLDER.sub(lambda match: "${" + match.group(1) + "}", literal)


def load_app_shortcut_keys() -> set[str]:
    if not APP_SHORTCUTS_FILE.exists():
        return set()
    return {
        match.group(1)
        for line in APP_SHORTCUTS_FILE.read_text(encoding="utf-8").splitlines()
        if (match := STRINGS_KEY.match(line))
    }


def find_required_phrases() -> dict[str, set[str]]:
    phrases: dict[str, set[str]] = {}
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in SHORTCUT_PHRASES.finditer(text):
            phrases.setdefault(intent_key(match.group(1)), set()).add(str(path.relative_to(ROOT)))
    return phrases


def find_required_keys() -> dict[str, set[str]]:
    required: dict[str, set[str]] = {}
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in LOCALIZED_CALLS.finditer(text):
            key = match.group(1)
            if "\\(" in key:
                continue
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))
        for match in PARAMETER_SUMMARIES.finditer(text):
            key = intent_key(match.group(1))
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))

    for path in sorted(NATIVE_ROOT.rglob("*.rs")):
        text = path.read_text(encoding="utf-8")
        text = text.split("#[cfg(test)]")[0]
        for match in NATIVE_MESSAGES.finditer(text):
            key = next(group for group in match.groups() if group)
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))
    return required


def main() -> int:
    keys, duplicates = load_keys()
    required = find_required_keys()
    missing = sorted(set(required) - keys)
    required_phrases = find_required_phrases()
    missing_phrases = sorted(set(required_phrases) - load_app_shortcut_keys())

    if duplicates:
        print("Duplicate localization keys:")
        for key in duplicates:
            print(f"  {key}")

    if missing:
        print("Missing zh-Hans localization keys:")
        for key in missing:
            locations = ", ".join(sorted(required[key]))
            print(f"  {key} [{locations}]")

    if missing_phrases:
        print("Missing zh-Hans App Shortcuts phrases:")
        for phrase in missing_phrases:
            locations = ", ".join(sorted(required_phrases[phrase]))
            print(f"  {phrase} [{locations}]")

    if duplicates or missing or missing_phrases:
        return 1

    print(
        f"Localization check passed: {len(keys)} zh-Hans keys cover {len(required)} literal UI keys"
        f" and {len(required_phrases)} App Shortcuts phrases."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
