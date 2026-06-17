#!/bin/bash
# Build DJDXStudio (release) and assemble "DJDX PEAK Studio.app".
# CLI-only; no Xcode project. See SWIFT_DEVTOOL_PLAN.md §4.1.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DJDX PEAK Studio"
BUILD_DIR=".build/release"
DIST_DIR=".build/dist"
APP="${DIST_DIR}/${APP_NAME}.app"

echo "› swift build -c release"
swift build -c release

echo "› assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "${BUILD_DIR}/DJDXStudio" "${APP}/Contents/MacOS/DJDXStudio"
cp "Resources/Info.plist" "${APP}/Contents/Info.plist"
[ -f "Resources/AppIcon.icns" ] && cp "Resources/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns" || true

echo "› ad-hoc codesign"
codesign --force --sign - "${APP}" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "✓ built ${APP}"
echo "  open \"${APP}\""
