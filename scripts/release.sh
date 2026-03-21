#!/bin/bash
set -euo pipefail

# ── Pre-flight checks ───────────────────────────────────────────────────

if [[ ! -f .env ]]; then
  echo "ERROR: .env file not found. Create it with your MAPBOX_PUBLIC_TOKEN."
  exit 1
fi

if ! command -v flutter &>/dev/null; then
  echo "ERROR: flutter not found in PATH."
  exit 1
fi

# ── Read version from pubspec.yaml ───────────────────────────────────────

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
DISPLAY_VERSION=$(echo "$VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$VERSION" | cut -d'+' -f2)

echo "==> Building Monyx $DISPLAY_VERSION ($BUILD_NUMBER)"
echo ""

# ── Lint ─────────────────────────────────────────────────────────────────

echo "==> Analyzing..."
flutter analyze --no-pub
echo ""

# ── Test ─────────────────────────────────────────────────────────────────

echo "==> Running tests..."
flutter test --no-pub
echo ""

# ── Build ────────────────────────────────────────────────────────────────

echo "==> Cleaning..."
flutter clean
flutter pub get

echo "==> Building IPA..."
flutter build ipa --release --dart-define-from-file=.env
echo ""

# ── Open archive ─────────────────────────────────────────────────────────

ARCHIVE="build/ios/archive/Runner.xcarchive"
if [[ -d "$ARCHIVE" ]]; then
  echo "==> Opening Xcode Organizer..."
  echo "    Distribute App → App Store Connect → Upload"
  open "$ARCHIVE"
else
  echo "ERROR: Archive not found at $ARCHIVE"
  exit 1
fi

echo ""
echo "✓ Monyx $DISPLAY_VERSION ($BUILD_NUMBER) ready to upload."