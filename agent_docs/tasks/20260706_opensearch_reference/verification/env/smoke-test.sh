#!/usr/bin/env bash
# 検証環境のエンドツーエンド疎通テスト（ステップ2 DoD の実証）:
#  1) health + knn プラグイン
#  2) base index 作成 + サンプル投入 + keyword(prefix) 検索
#  3) knn index 作成 + サンプルベクトル投入 + kNN 検索（＋ roles フィルタ）
# いずれかで想定外があれば目視できるよう結果を出力する。
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

echo "############ 1. HEALTH & KNN ############"
./healthcheck.sh

echo; echo "############ 2. BASE INDEX (keyword) ############"
./setup-base-index.sh
echo "--- prefix 検索 text:opensearch* ---"
os_curl "${OS_URL}/${IDX_BASE}/_search" -d '{
  "size": 10,
  "query": { "prefix": { "text": "opensearch" } },
  "_source": ["text","queryFreq","roles"]
}' | tr '}' '}\n' | grep -E '"text"|"_id"|total' | head

echo; echo "############ 3. KNN INDEX (vector) ############"
./setup-knn-index.sh
echo "--- kNN 検索 (k=3) ---"
os_curl "${OS_URL}/${IDX_KNN}/_search" -d '{
  "size": 3,
  "query": { "knn": { "embedding": { "vector": [0.11, 0.20, 0.30, 0.41], "k": 3 } } },
  "_source": ["text","roles"]
}' | tr '}' '}\n' | grep -E '"text"|"_score"|total' | head

echo "--- kNN 検索 + roles フィルタ (roles=user, lucene engine) ---"
os_curl "${OS_URL}/${IDX_KNN}/_search" -d '{
  "size": 3,
  "query": { "knn": { "embedding": {
    "vector": [0.11, 0.20, 0.30, 0.41], "k": 3,
    "filter": { "term": { "roles": "user" } }
  } } },
  "_source": ["text","roles"]
}' | tr '}' '}\n' | grep -E '"text"|"_score"|total' | head

echo; echo "############ SMOKE TEST DONE ############"
