#!/bin/bash
# Установка Flutter SDK и зависимостей для облачных сессий Claude Code,
# чтобы в каждой сессии работал `flutter analyze`.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.47.5"
FLUTTER_HOME="$HOME/flutter"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ] || ! grep -q "^$FLUTTER_VERSION" "$FLUTTER_HOME/version" 2>/dev/null; then
  rm -rf "$FLUTTER_HOME"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$HOME"
  git config --global --add safe.directory "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

flutter config --no-analytics >/dev/null
cd "$CLAUDE_PROJECT_DIR"
flutter pub get
