#!/usr/bin/env bash
#
# Build an UNSIGNED .ipa for sideloading via SideStore / AltStore.
# Run this on your Mac (Xcode + CocoaPods required, internet on for `pod install`).
#
#   ./scripts/build_sideload_ipa.sh
#   TTC_API_URL=https://staging.example.com/v2 ./scripts/build_sideload_ipa.sh   # override API
#
# SideStore re-signs the IPA on-device with your free Apple ID, so this build is
# intentionally NOT code-signed.
set -euo pipefail

API_URL="${TTC_API_URL:-https://v1api.thetripclub.com/v2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Locate the Flutter SDK (not always on PATH on this machine).
FLUTTER="$(command -v flutter || true)"
if [ -z "$FLUTTER" ]; then
  if [ -x "$ROOT/../flutter/bin/flutter" ]; then
    FLUTTER="$ROOT/../flutter/bin/flutter"
  else
    echo "❌ flutter not found. Add it to PATH or place the SDK at appdevelopment/flutter." >&2
    exit 1
  fi
fi
echo "==> Using Flutter: $FLUTTER"

# Prefer a native Homebrew CocoaPods over a broken RVM `pod`, for both the
# explicit `pod install` below and Flutter's own internal pod calls.
if [ -d /opt/homebrew/bin ]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

# RVM exports GEM_HOME/GEM_PATH pointing at its Ruby 3.0 gems, which leaks into
# Homebrew's self-contained CocoaPods (its own Ruby) and breaks gem resolution
# ("Could not find 'rexml'/'minitest'..."). Clear them for this build.
unset GEM_HOME GEM_PATH GEM_ROOT MY_RUBY_HOME RUBY_VERSION RUBYLIB RUBYOPT \
  BUNDLE_GEMFILE BUNDLE_PATH 2>/dev/null || true
# CocoaPods needs a UTF-8 locale.
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

POD="$(command -v pod || true)"
echo "==> Using CocoaPods: ${POD:-NOT FOUND}"
RUBY="$(command -v ruby || true)"
echo "==> Using Ruby: ${RUBY:-NOT FOUND}"

echo "==> flutter pub get"
"$FLUTTER" pub get

# Download the iOS engine artifacts (Flutter.xcframework) so the Podfile's
# post-install hook can find them during the manual `pod install` below.
echo "==> flutter precache --ios"
"$FLUTTER" precache --ios

echo "==> pod install (needs internet the first time)"
( cd ios && "${POD:-pod}" install )

echo "==> Building iOS release (unsigned) against: $API_URL"
"$FLUTTER" build ios --release --no-codesign \
  --dart-define=TTC_API_URL="$API_URL"

APP="build/ios/iphoneos/Runner.app"
if [ ! -d "$APP" ]; then
  echo "❌ Build failed: $APP not found." >&2
  exit 1
fi

OUT_DIR="build/ios"
OUT="$OUT_DIR/ttcadmin-sideload.ipa"
echo "==> Packaging $OUT"
rm -rf "$OUT_DIR/Payload" "$OUT"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
( cd "$OUT_DIR" && zip -qry "ttcadmin-sideload.ipa" Payload )
rm -rf "$OUT_DIR/Payload"

echo ""
echo "✅ Done:  $ROOT/$OUT"
echo "   AirDrop / Files-transfer this .ipa to your iPhone, then open it in"
echo "   SideStore → '+' → install. Keep the SideStore WireGuard VPN on to"
echo "   auto-refresh the 7-day signature."
