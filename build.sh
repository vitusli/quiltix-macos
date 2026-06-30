#!/usr/bin/env bash
set -euo pipefail

# quiltix-macos
# Reproducible macOS Apple Silicon build for QuiltiX + OpenUSD.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DIR="$ROOT_DIR/source"
DEPS_DIR="$ROOT_DIR/deps"
BUILD_DIR="$ROOT_DIR/build"

QX_REPO_URL="https://github.com/PrismPipeline/QuiltiX.git"
USD_REPO_URL="https://github.com/PixarAnimationStudios/OpenUSD.git"

# Pinned commits for reproducibility.
QX_COMMIT="c83f929b284b38d623fb0c9697b00a6d9606a5d8"
USD_COMMIT="3e3890068e17f0e31dc34f906f7f1fa1037dd7da"

QX_SRC_DIR="$SOURCE_DIR/QuiltiX"
USD_SRC_DIR="$DEPS_DIR/OpenUSD"

VENV_DIR="$BUILD_DIR/.venv311"
USD_INSTALL_DIR="$DEPS_DIR/openusd-26.05-py311-arm64"

SKIP_OPENUSD_BUILD=0
PYTHON_BIN="${QX_PYTHON_BIN:-}"

usage() {
  cat <<'EOF'
Usage: ./build.sh [options]

Options:
  --python <path>        Python 3.11 binary to use
  --skip-openusd-build   Skip OpenUSD build step
  -h, --help             Show this help

Environment:
  QX_PYTHON_BIN          Same as --python
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --python)
      PYTHON_BIN="$2"
      shift 2
      ;;
    --skip-openusd-build)
      SKIP_OPENUSD_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unknown argument: %s\n\n" "$1" >&2
      usage
      exit 2
      ;;
  esac
done

require_cmd() {
  local cmd="$1"
  local msg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf "Error: %s\n" "$msg" >&2
    exit 1
  fi
}

if [ "$(uname -s)" != "Darwin" ]; then
  printf "Error: this script supports macOS only.\n" >&2
  exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
  printf "Error: this script is intended for Apple Silicon (arm64).\n" >&2
  exit 1
fi

require_cmd git "git is required"
require_cmd cmake "cmake is required (install with: brew install cmake)"
require_cmd xcode-select "xcode-select is required (run: xcode-select --install)"

if [ -z "$PYTHON_BIN" ]; then
  if command -v python3.11 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.11)"
  elif [ -x "/opt/homebrew/bin/python3.11" ]; then
    PYTHON_BIN="/opt/homebrew/bin/python3.11"
  else
    printf "Error: Python 3.11 not found. Install with: brew install python@3.11\n" >&2
    exit 1
  fi
fi

if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 11) else 1)'; then
  printf "Error: selected python is not 3.11: %s\n" "$PYTHON_BIN" >&2
  exit 1
fi

mkdir -p "$SOURCE_DIR" "$DEPS_DIR" "$BUILD_DIR"

printf "==> Root:   %s\n" "$ROOT_DIR"
printf "==> Python: %s\n" "$PYTHON_BIN"

if [ ! -d "$QX_SRC_DIR/.git" ]; then
  git clone "$QX_REPO_URL" "$QX_SRC_DIR"
fi

if [ ! -d "$USD_SRC_DIR/.git" ]; then
  git clone "$USD_REPO_URL" "$USD_SRC_DIR"
fi

git -C "$QX_SRC_DIR" fetch --all --tags
git -C "$QX_SRC_DIR" checkout --detach "$QX_COMMIT"

git -C "$USD_SRC_DIR" fetch --all --tags
git -C "$USD_SRC_DIR" checkout --detach "$USD_COMMIT"

if [ ! -x "$VENV_DIR/bin/python" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
"$VENV_DIR/bin/pip" install "$QX_SRC_DIR"

if [ "$SKIP_OPENUSD_BUILD" -eq 0 ]; then
  PATH="$VENV_DIR/bin:$PATH" \
    "$VENV_DIR/bin/python" "$USD_SRC_DIR/build_scripts/build_usd.py" \
      --codesign-id - \
      --python \
      --usdview \
      --materialx \
      --no-tests \
      --no-examples \
      --no-tutorials \
      --build-target arm64 \
      "$USD_INSTALL_DIR"
fi

USD_PYTHONPATH="$USD_INSTALL_DIR/lib/python3.11/site-packages"
if [ ! -d "$USD_PYTHONPATH" ]; then
  printf "Error: OpenUSD Python path missing: %s\n" "$USD_PYTHONPATH" >&2
  exit 1
fi

PATH="$USD_INSTALL_DIR/bin:$PATH" \
PYTHONPATH="$USD_PYTHONPATH${PYTHONPATH:+:$PYTHONPATH}" \
  "$VENV_DIR/bin/python" -c "from pxr import Usd, Usdviewq; from pxr.Usdviewq.stageView import UsdImagingGL; print('USD', Usd.GetVersion())"

PATH="$USD_INSTALL_DIR/bin:$PATH" \
PYTHONPATH="$USD_PYTHONPATH${PYTHONPATH:+:$PYTHONPATH}" \
  "$VENV_DIR/bin/python" -c "from QuiltiX import quiltix; print('quiltix-import-ok')"

cat > "$BUILD_DIR/env.sh" <<EOF
export QX_ROOT="$ROOT_DIR"
export QX_VENV_PYTHON="$VENV_DIR/bin/python"
export QX_USD_ROOT="$USD_INSTALL_DIR"
export QX_USD_PYTHONPATH="$USD_PYTHONPATH"
export PATH="\$QX_USD_ROOT/bin:\$PATH"
export PYTHONPATH="\$QX_USD_PYTHONPATH:\${PYTHONPATH:-}"
EOF

cat > "$BUILD_DIR/run.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$BUILD_DIR/env.sh"
exec "\$QX_VENV_PYTHON" -m QuiltiX "\$@"
EOF
chmod +x "$BUILD_DIR/run.sh"

printf "\nBuild complete.\n"
printf "  Env file:      %s\n" "$BUILD_DIR/env.sh"
printf "  Launch script: %s\n" "$BUILD_DIR/run.sh"
printf "\nNext:\n"
printf "  source %s\n" "$BUILD_DIR/env.sh"
printf "  %s\n" "$BUILD_DIR/run.sh"
