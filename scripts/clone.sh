#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/../modules"

clone_or_pull() {
  local repo_url="$1"
  local dest_dir="$2"

  if [ -d "$dest_dir/.git" ]; then
    echo "Updating $dest_dir ..."
    git -C "$dest_dir" pull
  else
    echo "Cloning $repo_url into $dest_dir ..."
    git clone "$repo_url" "$dest_dir"
  fi
}

clone_or_pull "https://github.com/codelibs/fess-suggest.git" "$MODULES_DIR/fess-suggest"
clone_or_pull "https://github.com/codelibs/fess.git" "$MODULES_DIR/fess"

echo ""
echo "=== Cloned versions ==="
echo "[fess-suggest] commit: $(git -C "$MODULES_DIR/fess-suggest" rev-parse HEAD)"
echo "[fess]         commit: $(git -C "$MODULES_DIR/fess" rev-parse HEAD)"
