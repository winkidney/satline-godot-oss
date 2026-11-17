#!/bin/sh
set -eu
SALTLINE_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SALTLINE_ENGINE_BIN="$SALTLINE_PROJECT_DIR/engine/godot"
if [ ! -x "$SALTLINE_ENGINE_BIN" ]; then
 SALTLINE_ENGINE_BIN="$SALTLINE_PROJECT_DIR/engine/.build/godot-ed1daf0bf/bin/godot.linuxbsd.template_debug.x86_64"
fi
if [ ! -x "$SALTLINE_ENGINE_BIN" ]; then
 echo "Build the isolated engine first: python3 $SALTLINE_PROJECT_DIR/engine/build_engine.py" >&2
 exit 1
fi
exec "$SALTLINE_ENGINE_BIN" --path "$SALTLINE_PROJECT_DIR" "$@"
