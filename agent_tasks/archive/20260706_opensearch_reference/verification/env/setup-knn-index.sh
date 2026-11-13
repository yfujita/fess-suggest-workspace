#!/usr/bin/env bash
# ステップ2/4 用の knn 疎通確認インデックスを再作成し、サンプルベクトルを投入する。
# engine=lucene（filter 適合・小規模向け・00-docs-research §3.2 の第一候補）。
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

os_delete_index "${IDX_KNN}"
echo "=== create ${IDX_KNN} (knn_vector, engine=lucene) ==="
os_curl -X PUT "${OS_URL}/${IDX_KNN}" --data-binary @knn-smoke-index.json | tr ',' '\n' | grep -E 'acknowledged|error|reason' || true

echo "=== bulk load sample vectors ==="
os_curl -X POST "${OS_URL}/${IDX_KNN}/_bulk" --data-binary @knn-sample-docs.ndjson | tr ',' '\n' | grep -E '"errors"|"reason"' | head

os_refresh "${IDX_KNN}"
echo "=== count ==="
os_curl "${OS_URL}/${IDX_KNN}/_count"
echo
