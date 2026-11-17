#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SALTLINE_PROJECT_DIR="$PROJECT_DIR/saltline-godot"
SALTLINE_CACHE="$SALTLINE_PROJECT_DIR/.godot"
if [ ! -f "$SALTLINE_CACHE/global_script_class_cache.cfg" ] || [ ! -d "$SALTLINE_CACHE/imported" ]; then
 SALTLINE_EDITOR=${GODOT:-godot}
 if ! command -v "$SALTLINE_EDITOR" >/dev/null 2>&1; then
  echo "首次运行需要官方 Godot 4.7.2 编辑器来导入资源；请将 godot 加入 PATH，或通过 GODOT 指定其路径。" >&2
  exit 1
 fi
 SALTLINE_EDITOR_VERSION=$("$SALTLINE_EDITOR" --version) || exit 1
 case "$SALTLINE_EDITOR_VERSION" in
  4.7.2.stable.official.*) ;;
  *) echo "资源导入需要官方 Godot 4.7.2 编辑器；请通过 GODOT 指定正确的可执行文件。" >&2; exit 1 ;;
 esac
 echo "首次运行：使用官方 Godot 4.7.2 导入资源。"
 "$SALTLINE_EDITOR" --headless --editor --path "$SALTLINE_PROJECT_DIR" --import --quit || {
  echo "资源导入失败，请检查编辑器输出。" >&2
  exit 1
 }
 if [ ! -f "$SALTLINE_CACHE/global_script_class_cache.cfg" ] || [ ! -d "$SALTLINE_CACHE/imported" ]; then
  echo "资源导入未完成，请检查编辑器输出。" >&2
  exit 1
 fi
fi
exec "$PROJECT_DIR/saltline-godot/tools/run_native.sh" "$@"
