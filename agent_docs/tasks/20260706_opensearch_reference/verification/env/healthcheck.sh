#!/usr/bin/env bash
# 【完了条件(DoD)の1コマンド確認】
# OpenSearch のバージョン・クラスタ health・knn プラグイン有効を1回で確認する。
# knn プラグインが見つからなければ非0で終了する。
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

echo "=== version (${OS_URL}) ==="
os_curl "${OS_URL}" | grep -E '"number"|"distribution"|"lucene_version"'

echo "=== cluster health ==="
os_curl "${OS_URL}/_cluster/health" | tr ',' '\n' | grep -E '"status"|"number_of_nodes"'

echo "=== knn plugin ==="
if os_curl "${OS_URL}/_cat/plugins?h=component" | grep -qi 'opensearch-knn'; then
  os_curl "${OS_URL}/_cat/plugins?v" | grep -Ei 'component|opensearch-knn|neural-search'
  echo "RESULT: knn 利用可能 (opensearch-knn プラグイン有効)"
else
  echo "RESULT: NG - opensearch-knn プラグインが見つかりません" >&2
  exit 1
fi
