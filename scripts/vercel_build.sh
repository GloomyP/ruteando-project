#!/usr/bin/env bash
set -euo pipefail

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_DIR="${VERCEL_FLUTTER_DIR:-$PWD/.flutter-sdk}"

if command -v flutter >/dev/null 2>&1; then
  echo "Using Flutter from PATH"
else
  if [ ! -d "$FLUTTER_DIR/bin" ]; then
    echo "Installing Flutter $FLUTTER_CHANNEL for Vercel build"
    rm -rf "$FLUTTER_DIR"
    git clone --depth 1 --branch "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi

  export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get

flutter build web \
  --release \
  --no-wasm-dry-run \
  --dart-define=SUPABASE_REST_URL="${SUPABASE_REST_URL:-https://zexfyjefmomuaoamwycw.supabase.co/rest/v1/}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_rrx6nMypqyFpVYw76O7rhg_zmj4Uj8o}"
