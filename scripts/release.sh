#!/usr/bin/env bash
# VlcRemote Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 2.7.5

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 2.7.5"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Starting release v$VERSION ==="

# 1. Clean and get dependencies
echo "[1/6] Cleaning and fetching dependencies..."
flutter clean
flutter pub get

# 2. Analyze and test (fail-fast: con `set -e` un fallimento qui ferma la release)
echo "[2/6] Running analysis and tests..."
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test

# 3. Build for each platform
# Ogni piattaforma viene compilata solo se il relativo SDK e' presente sulla
# macchina: prima la piu' piccola piattaforma mancante faceva fallire l'intera
# release. I salti sono elencati nel riepilogo finale.
BUILT=""

build_platform() {
  local label="$1"
  shift
  if "$@"; then
    BUILT="$BUILT $label"
  else
    echo ">>> $label: build fallito"
    return 1
  fi
}

echo "[3/6] Building Android (AAB)..."
build_platform "Android" flutter build appbundle --release || FAILED=1

if command -v xcodebuild >/dev/null 2>&1; then
  echo "[4/6] Building iOS..."
  build_platform "iOS" flutter build ios --release --no-pub || FAILED=1
else
  echo "[4/6] Building iOS... saltato: xcodebuild non disponibile (serve macOS)"
  SKIPPED="$SKIPPED iOS"
fi

if command -v cmake >/dev/null 2>&1; then
  echo "[5/6] Building Windows..."
  build_platform "Windows" flutter build windows --release || FAILED=1
else
  echo "[5/6] Building Windows... saltato: toolchain desktop non disponibile"
  SKIPPED="$SKIPPED Windows"
fi

echo "[6/6] Building Linux..."
build_platform "Linux" flutter build linux --release || FAILED=1

if [ -n "${SKIPPED:-}" ]; then
  echo "Saltate:$SKIPPED"
fi
if [ "${FAILED:-0}" = "1" ]; then
  echo "=== Release v$VERSION incompleta: una o piu' piattaforme hanno fallito ==="
  exit 1
fi

echo "=== Release v$VERSION complete! ==="
echo "Artifacts:$BUILT"
echo "  - build/app/outputs/bundle/release/app-release.aab"
echo "  - build/ios/iphoneos/Runner.app"
echo "  - build/windows/runner/Release/vlc_remote_flutter.exe"
echo "  - build/linux/x64/release/bundle/vlc_remote_flutter"
