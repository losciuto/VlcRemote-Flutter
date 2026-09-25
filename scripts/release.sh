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

# 2. Analyze and test
echo "[2/6] Running analysis and tests..."
flutter analyze lib/ || echo "Warning: analysis issues found"
flutter test || echo "Warning: some tests failed"

# 3. Build for each platform
echo "[3/6] Building Android (AAB)..."
flutter build appbundle --release

echo "[4/6] Building iOS..."
flutter build ios --release --no-pub

echo "[5/6] Building Windows..."
flutter build windows --release

echo "[6/6] Building Linux..."
flutter build linux --release

echo "=== Release v$VERSION complete! ==="
echo "Artifacts:"
echo "  - build/app/outputs/bundle/release/app-release.aab"
echo "  - build/ios/iphoneos/Runner.app"
echo "  - build/windows/runner/Release/vlc_remote_flutter.exe"
echo "  - build/linux/x64/release/bundle/vlc_remote_flutter"
