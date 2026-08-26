#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter}"
APP_DIR="${APP_DIR:-formetas}"

echo ">>> Instalando Flutter ($FLUTTER_VERSION)..."
if [ ! -d "$FLUTTER_HOME/bin" ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
export CI=true

flutter config --enable-web --no-analytics
flutter precache --web
flutter --version

echo ">>> Build web do Formetas..."
cd "$APP_DIR"
flutter pub get
flutter build web --release --no-wasm-dry-run

echo ">>> Build concluido em $APP_DIR/build/web"
