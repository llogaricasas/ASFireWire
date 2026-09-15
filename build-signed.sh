#!/usr/bin/env bash
#
# ASFireWire – signed Release build for a self-provisioned team.
#
# build.sh deliberately builds UNSIGNED (for the ad-hoc / SIP-off install path).
# This script is the opposite: it lets Xcode sign the app and the dext with the
# team / identity / provisioning profiles configured in project.yml
# (DEVELOPMENT_TEAM + "Apple Development"), so the resulting ASFW.app carries
# real, Apple-granted DriverKit entitlements and installs with SIP ENABLED.
#
# Usage:
#   ./build-signed.sh             # -> build/signed/ASFW.app
#   ./build-signed.sh --install   # ...and copy it to /Applications, then open it
#   ./build-signed.sh --no-bump   # keep CFBundleVersion unchanged
#
set -Eeuo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="${DERIVED:-./build/DerivedData}"
OUT_DIR="./build/signed"
INSTALL_DIR="${ASFW_INSTALL_DIR:-/Applications}"
INSTALL=false
NO_BUMP=false

for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=true;;
    --no-bump) NO_BUMP=true;;
    -h|--help) sed -n '2,16p' "$0"; exit 0;;
    *) echo "[ERROR] unknown arg: $arg" >&2; exit 1;;
  esac
done

log() { echo "[INFO] $*"; }
ok()  { echo "[OK] $*"; }
err() { echo "[ERROR] $*" >&2; }

command -v xcodegen  >/dev/null || { err "xcodegen not installed (brew install xcodegen)"; exit 127; }
command -v xcodebuild >/dev/null || { err "xcodebuild not found"; exit 127; }

log "Regenerating ASFW.xcodeproj from project.yml…"
xcodegen generate --quiet

if [[ -x ./bump.sh ]]; then
  if $NO_BUMP; then ./bump.sh refresh >/dev/null; else ./bump.sh build >/dev/null; fi
fi

log "Building ASFW (${CONFIGURATION}, signed)…"
xcodebuild \
  -project ASFW.xcodeproj \
  -scheme ASFW \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED}" \
  -destination "platform=macOS,arch=$(uname -m)" \
  -allowProvisioningUpdates \
  -quiet \
  build

APP="${DERIVED}/Build/Products/${CONFIGURATION}/ASFW.app"
[[ -d "$APP" ]] || { err "Build product not found: $APP"; exit 1; }
DEXT="$(find "$APP/Contents/Library/SystemExtensions" -maxdepth 1 -name '*.dext' -print -quit)"
[[ -n "$DEXT" ]] || { err "No .dext embedded in $APP"; exit 1; }
# OSSystemExtensionRequest resolves the dext as <CFBundleIdentifier>.dext, so
# the folder name and the identifier must agree or the app reports
# "Extension not found in App bundle".
DEXT_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEXT/Info.plist")"
[[ "$(basename "$DEXT")" == "$DEXT_ID.dext" ]] \
  || { err "dext folder $(basename "$DEXT") does not match CFBundleIdentifier $DEXT_ID"; exit 1; }

log "Verifying signatures and entitlements…"
codesign --verify --deep --strict "$APP"
for b in "$DEXT" "$APP"; do
  echo "--- $(basename "$b")"
  codesign -dv --entitlements - "$b" 2>&1 | grep -E 'Authority=|TeamIdentifier|Identifier=|com\.apple\.developer\.' || true
done
codesign -d --entitlements - --xml "$DEXT" 2>/dev/null | grep -q 'com.apple.developer.driverkit.transport.pci' \
  || { err "dext is missing DriverKit entitlements"; exit 1; }
if codesign -dv "$DEXT" 2>&1 | grep -q 'Signature=adhoc'; then
  err "dext is ad-hoc signed – Xcode did not use your team's identity"; exit 1
fi

rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"
ditto "$APP" "$OUT_DIR/ASFW.app"
ok "Signed bundle: $OUT_DIR/ASFW.app"

if $INSTALL; then
  DEST="$INSTALL_DIR/ASFW.app"
  if [[ -d "$DEST" ]]; then
    log "Replacing existing $DEST"
    rm -rf "$DEST" 2>/dev/null || sudo rm -rf "$DEST"
  fi
  ditto "$OUT_DIR/ASFW.app" "$DEST" 2>/dev/null || sudo ditto "$OUT_DIR/ASFW.app" "$DEST"
  ok "Installed to $DEST — opening it; use the app's Install button to activate the driver."
  open "$DEST"
else
  echo
  echo "Next: move $OUT_DIR/ASFW.app to /Applications (or re-run with --install),"
  echo "launch it and click Install. macOS will ask you to approve the extension in"
  echo "System Settings > General > Login Items & Extensions > Driver Extensions."
fi
