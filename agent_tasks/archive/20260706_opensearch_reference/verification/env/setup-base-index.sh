#!/usr/bin/env bash
# ステップ3(scripted_upsert)用の共通土台インデックスを再作成し、サンプル投入まで行う。
# 現行 modules/fess-suggest/.../mappings-default.json + suggest.json を写経した定義。
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

os_delete_index "${IDX_BASE}"
echo "=== create ${IDX_BASE} ==="
os_curl -X PUT "${OS_URL}/${IDX_BASE}" --data-binary @base-index.json | tr ',' '\n' | grep -E 'acknowledged|error|reason' || true

echo "=== bulk load sample docs ==="
os_curl -X POST "${OS_URL}/${IDX_BASE}/_bulk" --data-binary @sample-docs.ndjson | tr ',' '\n' | grep -E '"errors"|"result"|"reason"' | head

os_refresh "${IDX_BASE}"
echo "=== count ==="
os_curl "${OS_URL}/${IDX_BASE}/_count"
echo
