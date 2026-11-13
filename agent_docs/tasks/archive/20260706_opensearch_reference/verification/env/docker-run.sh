#!/usr/bin/env bash
# OpenSearch 3.7.0 を単一ノード・security 無効の最小構成で起動する。
# 開発/技術検証専用（本番設定ではない）。
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

docker rm -f "${OS_CONTAINER}" 2>/dev/null || true

docker run -d --name "${OS_CONTAINER}" \
  -p "${OS_PORT}:9200" \
  -e "discovery.type=single-node" \
  -e "DISABLE_SECURITY_PLUGIN=true" \
  -e "DISABLE_INSTALL_DEMO_CONFIG=true" \
  -e "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g" \
  "${OS_IMAGE}"

echo "コンテナ起動待ち (${OS_URL}) ..."
until curl -s "${OS_URL}" >/dev/null 2>&1; do sleep 1; done
echo "OpenSearch 応答確認:"
os_curl "${OS_URL}" | grep -E '"number"|"distribution"' || true
echo "起動完了。ヘルスチェックは ./healthcheck.sh を実行。"
