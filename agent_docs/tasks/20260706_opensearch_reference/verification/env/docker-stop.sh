#!/usr/bin/env bash
# 検証用コンテナの停止・削除。
# 引数 --keep で停止のみ（削除しない）。既定は停止＋削除。
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

if [ "${1:-}" = "--keep" ]; then
  docker stop "${OS_CONTAINER}" && echo "stopped (kept): ${OS_CONTAINER}"
else
  docker rm -f "${OS_CONTAINER}" && echo "removed: ${OS_CONTAINER}"
fi
