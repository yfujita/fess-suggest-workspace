#!/usr/bin/env bash
# ステップ4: knn（ベクトル検索）のマッピング・API 検証（K1〜K9）
# 使い方: ./run-knn.sh
# 前提: verification/env/docker-run.sh でコンテナ os370-verify が :9201 で起動済み（knn プラグイン有効）。
# 冪等: 検証用インデックス knnv_* / エイリアス / 検索パイプラインを毎回作り直す。
#       生成した request/response JSON は out/ に保存し、レポートのエビデンスとする。
set -uo pipefail
cd "$(dirname "$0")"
source ../env/common.sh

OUT="out"
rm -rf "${OUT}"; mkdir -p "${OUT}"   # 前回実行の成果物を掃除（冪等）

pass=0; fail=0
ok()   { echo "  [PASS] $1"; pass=$((pass+1)); }
ng()   { echo "  [FAIL] $1"; fail=$((fail+1)); }
# jq でフィールド値を取り出して期待値と比較（文字列一致）
assert_json() { # <file> <jq-filter> <expected> <label>
  local got; got=$(jq -c "$2" "$1")
  if [ "${got}" = "$3" ]; then ok "$4 (=${got})"; else ng "$4 (got=${got} expected=$3)"; fi
}
# レスポンス JSON のエラー木（reason/root_cause/failed_shards）全体を横断して部分一致するか
assert_err_contains() { # <file> <substr> <label>
  local reason; reason=$(jq -r '[.error.reason, (.error.root_cause[]?|.reason), (.error.failed_shards[]?|.reason.reason // .reason)] | map(select(.)) | join(" | ")' "$1")
  if [ -n "${reason}" ] && printf '%s' "${reason}" | grep -qF "$2"; then ok "$3 (reason=${reason})";
  else ng "$3 (reason=${reason:-<none>} / substr=$2)"; fi
}

# 検証で使うインデックス名（自己完結・冪等のため専用プレフィクス）
IDX_LUCENE="knnv_lucene"     # keyword + knn_vector(lucene/cosinesimil) 共存土台
IDX_FAISS="knnv_faiss"       # faiss/cosinesimil
IDX_DEFAULT="knnv_default"   # method 省略（既定 engine）
IDX_NOKNN="knnv_noknn"       # index.knn 未設定（既定 false）
IDX_V2="knnv_lucene_v2"      # reindex 先
ALIAS="knnv_suggest"
PIPE="knnv-hybrid-pipeline"

cleanup() {
  for i in "${IDX_LUCENE}" "${IDX_FAISS}" "${IDX_DEFAULT}" "${IDX_NOKNN}" "${IDX_V2}" \
           knnv_nmslib knnv_algoparam knnv_knnfalse_method; do
    os_curl -X DELETE "${OS_URL}/${i}" >/dev/null 2>&1
  done
  os_curl -X DELETE "${OS_URL}/_search/pipeline/${PIPE}" >/dev/null 2>&1
}
cleanup

echo "############################################################"
echo "# ステップ4 knn 検証   OS_URL=${OS_URL}"
echo "############################################################"

########################################################################
echo; echo "== 事前: knn プラグイン有効 =="
os_curl "${OS_URL}/_cat/plugins?format=json" > "${OUT}/plugins.json"
if jq -e '.[] | select(.component=="opensearch-knn")' "${OUT}/plugins.json" >/dev/null; then
  ok "opensearch-knn プラグイン有効 ($(jq -r '.[]|select(.component=="opensearch-knn")|.version' "${OUT}/plugins.json"))"
else
  ng "opensearch-knn プラグインが見つからない（Docker 版で起動しているか確認）"; echo "PASS=${pass} FAIL=${fail}"; exit 1
fi

########################################################################
echo; echo "== K1: nmslib は 3.x で新規インデックス作成が拒否されるか =="
os_curl -X PUT "${OS_URL}/knnv_nmslib" -d '{
  "settings": { "index": { "knn": true } },
  "mappings": { "properties": { "emb": { "type": "knn_vector", "dimension": 4,
    "method": { "name": "hnsw", "engine": "nmslib", "space_type": "cosinesimil" } } } }
}' > "${OUT}/k1-nmslib.resp.json"
assert_json "${OUT}/k1-nmslib.resp.json" '.error.type' '"mapper_parsing_exception"' "K1 nmslib 作成はエラー型 mapper_parsing_exception"
assert_err_contains "${OUT}/k1-nmslib.resp.json" "cannot be used for new index creation" "K1 nmslib は新規作成不可（警告でなくブロック）"

########################################################################
echo; echo "== K8: index レベル knn パラメータ（3.0 で削除）は設定拒否される =="
os_curl -X PUT "${OS_URL}/knnv_algoparam" -d '{
  "settings": { "index": { "knn": true, "knn.algo_param.ef_construction": 128 } },
  "mappings": { "properties": { "emb": { "type": "knn_vector", "dimension": 4 } } }
}' > "${OUT}/k8-algoparam.resp.json"
assert_json "${OUT}/k8-algoparam.resp.json" '.error.type' '"settings_exception"' "K8 index.knn.algo_param.ef_construction は unknown setting"
assert_err_contains "${OUT}/k8-algoparam.resp.json" "unknown setting [index.knn.algo_param.ef_construction]" "K8 削除済み設定は拒否 → method オブジェクト方式のみ"

########################################################################
echo; echo "== K2/K3/K4: index.knn:true + method(lucene/cosinesimil) + keyword 共存 =="
cat > "${OUT}/k-lucene-index.json" <<'JSON'
{
  "settings": { "index": { "knn": true, "number_of_shards": 1, "number_of_replicas": 0, "refresh_interval": "10s" } },
  "mappings": { "properties": {
    "text":  { "type": "keyword" },
    "roles": { "type": "keyword" },
    "embedding": {
      "type": "knn_vector", "dimension": 4, "space_type": "cosinesimil",
      "method": { "name": "hnsw", "engine": "lucene", "parameters": { "ef_construction": 100, "m": 16 } }
    }
  } }
}
JSON
os_curl -X PUT "${OS_URL}/${IDX_LUCENE}" --data-binary @"${OUT}/k-lucene-index.json" > "${OUT}/k2-lucene-create.resp.json"
assert_json "${OUT}/k2-lucene-create.resp.json" '.acknowledged' 'true' "K2 lucene+cosinesimil マッピング作成"
# データ投入（keyword と knn_vector を同一 doc に共存）
os_curl -X POST "${OS_URL}/${IDX_LUCENE}/_bulk?refresh=true" --data-binary '{ "index": { "_id": "v1" } }
{ "text": "opensearch", "roles": ["guest","user"], "embedding": [0.10,0.20,0.30,0.40] }
{ "index": { "_id": "v2" } }
{ "text": "opensearch dashboards", "roles": ["user"], "embedding": [0.12,0.19,0.31,0.42] }
{ "index": { "_id": "v3" } }
{ "text": "検索エンジン", "roles": ["admin"], "embedding": [0.90,0.80,0.10,0.05] }
' > "${OUT}/k4-bulk.resp.json"
assert_json "${OUT}/k4-bulk.resp.json" '.errors' 'false' "K4 keyword+knn_vector 同一 doc の投入成功"
# K4: keyword 前方一致（prefix）と knn の両クエリが同一インデックスで成立
os_curl -X POST "${OS_URL}/${IDX_LUCENE}/_search" -d '{ "size":5, "query": { "prefix": { "text": "opensearch" } } }' > "${OUT}/k4-prefix.resp.json"
assert_json "${OUT}/k4-prefix.resp.json" '.hits.hits|map(._id)|sort' '["v1","v2"]' "K4 keyword prefix 検索が成立（v1/v2）"
os_curl -X POST "${OS_URL}/${IDX_LUCENE}/_search" -d '{ "size":5, "query": { "knn": { "embedding": { "vector": [0.11,0.20,0.30,0.41], "k": 3 } } } }' > "${OUT}/k3-knn.resp.json"
assert_json "${OUT}/k3-knn.resp.json" '.hits.hits|length' '3' "K3 index.knn:true で knn クエリ成立（3件）"
assert_json "${OUT}/k3-knn.resp.json" '.hits.hits[0]._id' '"v1"' "K3 最近傍が先頭（v1）"

########################################################################
echo; echo "== K3(否定): index.knn 未設定だと knn クエリが失敗する =="
# method 無しの knn_vector は index.knn なしでも作成できる（が検索不可）
os_curl -X PUT "${OS_URL}/${IDX_NOKNN}" -d '{
  "mappings": { "properties": { "emb": { "type": "knn_vector", "dimension": 4 } } }
}' > "${OUT}/k3-noknn-create.resp.json"
assert_json "${OUT}/k3-noknn-create.resp.json" '.acknowledged' 'true' "K3 index.knn 未設定でも knn_vector(method無) は作成可"
os_curl -X POST "${OS_URL}/${IDX_NOKNN}/_doc/1?refresh=true" -d '{"emb":[0.1,0.2,0.3,0.4]}' >/dev/null
os_curl -X POST "${OS_URL}/${IDX_NOKNN}/_search" -d '{ "query": { "knn": { "emb": { "vector": [0.1,0.2,0.3,0.4], "k": 3 } } } }' > "${OUT}/k3-noknn-search.resp.json"
assert_err_contains "${OUT}/k3-noknn-search.resp.json" "not built for ANN search" "K3 index.knn 無しの knn クエリは失敗（ANN 未構築）"
# method パラメータ指定時は index.knn:true を強制される
os_curl -X PUT "${OS_URL}/knnv_knnfalse_method" -d '{
  "settings": { "index": { "knn": false } },
  "mappings": { "properties": { "emb": { "type": "knn_vector", "dimension": 4,
    "method": { "name": "hnsw", "engine": "lucene", "space_type": "cosinesimil" } } } }
}' > "${OUT}/k3-knnfalse-method.resp.json"
assert_err_contains "${OUT}/k3-knnfalse-method.resp.json" "Cannot set modelId or method parameters when index.knn setting is false" "K3 method 指定時は index.knn:true 必須"

########################################################################
echo; echo "== K2/K5: faiss(cosinesimil) 作成 + knn+filter が faiss/lucene で動作 =="
os_curl -X PUT "${OS_URL}/${IDX_FAISS}" -d '{
  "settings": { "index": { "knn": true, "number_of_shards": 1, "number_of_replicas": 0 } },
  "mappings": { "properties": {
    "roles": { "type": "keyword" },
    "embedding": { "type": "knn_vector", "dimension": 4, "space_type": "cosinesimil",
      "method": { "name": "hnsw", "engine": "faiss", "parameters": { "ef_construction": 100, "m": 16 } } }
  } }
}' > "${OUT}/k2-faiss-create.resp.json"
assert_json "${OUT}/k2-faiss-create.resp.json" '.acknowledged' 'true' "K2 faiss+cosinesimil マッピング作成"
os_curl -X POST "${OS_URL}/${IDX_FAISS}/_bulk?refresh=true" --data-binary '{ "index": { "_id": "1" } }
{ "roles": ["user"], "embedding": [0.10,0.20,0.30,0.40] }
{ "index": { "_id": "2" } }
{ "roles": ["admin"], "embedding": [0.11,0.19,0.31,0.42] }
' >/dev/null
# K5-faiss: filter=roles:user は id=1 のみ
os_curl -X POST "${OS_URL}/${IDX_FAISS}/_search" -d '{ "query": { "knn": { "embedding": { "vector": [0.10,0.20,0.30,0.40], "k": 3, "filter": { "term": { "roles": "user" } } } } } }' > "${OUT}/k5-faiss-filter.resp.json"
assert_json "${OUT}/k5-faiss-filter.resp.json" '.hits.hits|map(._id)|sort' '["1"]' "K5 faiss の knn+filter(roles:user) が絞り込み(id=1)"
# K5-lucene: knnv_lucene で filter=roles:user は v1/v2
os_curl -X POST "${OS_URL}/${IDX_LUCENE}/_search" -d '{ "query": { "knn": { "embedding": { "vector": [0.11,0.20,0.30,0.41], "k": 3, "filter": { "term": { "roles": "user" } } } } } }' > "${OUT}/k5-lucene-filter.resp.json"
assert_json "${OUT}/k5-lucene-filter.resp.json" '.hits.hits|map(._id)|sort' '["v1","v2"]' "K5 lucene の knn+filter(roles:user) が絞り込み(v1/v2)"

########################################################################
echo; echo "== K3(既定 engine): method 省略でも作成・検索可（nmslib でない証拠に filter が効く） =="
os_curl -X PUT "${OS_URL}/${IDX_DEFAULT}" -d '{
  "settings": { "index": { "knn": true } },
  "mappings": { "properties": { "roles": {"type":"keyword"}, "emb": { "type": "knn_vector", "dimension": 4 } } }
}' > "${OUT}/k3-default-create.resp.json"
assert_json "${OUT}/k3-default-create.resp.json" '.acknowledged' 'true' "K3 method 省略で knn_vector 作成（既定 engine=faiss・docs）"
os_curl -X POST "${OS_URL}/${IDX_DEFAULT}/_doc/1?refresh=true" -d '{"roles":["user"],"emb":[0.1,0.2,0.3,0.4]}' >/dev/null
os_curl -X POST "${OS_URL}/${IDX_DEFAULT}/_search" -d '{ "query": { "knn": { "emb": { "vector": [0.1,0.2,0.3,0.4], "k": 3, "filter": { "term": { "roles": "user" } } } } } }' > "${OUT}/k3-default-search.resp.json"
assert_json "${OUT}/k3-default-search.resp.json" '.hits.hits|length' '1' "K3 既定 engine で knn+filter 成立（⇒ nmslib でない=faiss/lucene）"

########################################################################
echo; echo "== K6: hybrid クエリ + normalization-processor でスコア正規化・統合 =="
# 検索パイプライン（正規化 min_max / 結合 arithmetic_mean / weights 合計 1.0）
cat > "${OUT}/k6-pipeline.json" <<'JSON'
{
  "description": "hybrid keyword+vector normalization",
  "phase_results_processors": [
    { "normalization-processor": {
        "normalization": { "technique": "min_max" },
        "combination": { "technique": "arithmetic_mean", "parameters": { "weights": [0.3, 0.7] } }
    } }
  ]
}
JSON
os_curl -X PUT "${OS_URL}/_search/pipeline/${PIPE}" --data-binary @"${OUT}/k6-pipeline.json" > "${OUT}/k6-pipeline.resp.json"
assert_json "${OUT}/k6-pipeline.resp.json" '.acknowledged' 'true' "K6 normalization-processor パイプライン作成"
# hybrid: match(keyword) + knn（埋め込み未用意のため neural を生ベクトル knn に置換）
cat > "${OUT}/k6-hybrid-query.json" <<'JSON'
{
  "size": 5,
  "query": { "hybrid": { "queries": [
    { "match": { "text": { "query": "opensearch" } } },
    { "knn":   { "embedding": { "vector": [0.11, 0.20, 0.30, 0.41], "k": 3 } } }
  ] } }
}
JSON
# (a) パイプラインあり = 正規化・統合されたスコア（0..1）
os_curl -X POST "${OS_URL}/${IDX_LUCENE}/_search?search_pipeline=${PIPE}" --data-binary @"${OUT}/k6-hybrid-query.json" > "${OUT}/k6-hybrid-with-pipe.resp.json"
assert_json "${OUT}/k6-hybrid-with-pipe.resp.json" 'has("error")' 'false' "K6(a) hybrid+pipeline がエラー無く成立"
top=$(jq -c '.hits.hits[0]._score' "${OUT}/k6-hybrid-with-pipe.resp.json")
inrange=$(jq -c '[.hits.hits[]._score] | all(. >= 0 and . <= 1.0000001)' "${OUT}/k6-hybrid-with-pipe.resp.json")
uniqids=$(jq -c '[.hits.hits[]._id] | (length == (unique|length))' "${OUT}/k6-hybrid-with-pipe.resp.json")
if [ "${inrange}" = "true" ]; then ok "K6(a) 統合スコアが [0,1] に正規化（top=${top}）"; else ng "K6(a) スコアが [0,1] 外 (top=${top})"; fi
if [ "${uniqids}" = "true" ]; then ok "K6(a) hits の _id が重複しない（サブクエリ結果が統合されている）"; else ng "K6(a) _id が重複（統合されていない）"; fi
# (b) パイプライン無し = 正規化されず不正なスコア/重複（パイプライン必須の裏取り）
os_curl -X POST "${OS_URL}/${IDX_LUCENE}/_search" --data-binary @"${OUT}/k6-hybrid-query.json" > "${OUT}/k6-hybrid-no-pipe.resp.json"
neg_or_dup=$(jq -c '([.hits.hits[]._score] | any(. < 0)) or ([.hits.hits[]._id] | (length != (unique|length)))' "${OUT}/k6-hybrid-no-pipe.resp.json")
if [ "${neg_or_dup}" = "true" ]; then ok "K6(b) パイプライン無しは未正規化（負スコア/重複）→ normalization-processor 必須";
else ng "K6(b) パイプライン無しでも正常に見える（想定外）"; fi

########################################################################
echo; echo "== K9: reindex + エイリアス切替（二重エイリアス再構築 KEEP-02 親和性） =="
os_curl -X PUT "${OS_URL}/${IDX_V2}" --data-binary @"${OUT}/k-lucene-index.json" > "${OUT}/k9-v2-create.resp.json"
assert_json "${OUT}/k9-v2-create.resp.json" '.acknowledged' 'true' "K9 knn マッピングで v2 インデックス作成"
os_curl -X POST "${OS_URL}/_reindex" -d '{ "source": { "index": "'"${IDX_LUCENE}"'" }, "dest": { "index": "'"${IDX_V2}"'" } }' > "${OUT}/k9-reindex.resp.json"
assert_json "${OUT}/k9-reindex.resp.json" '.created' '3' "K9 reindex で knn_vector を含む3件を移送"
assert_json "${OUT}/k9-reindex.resp.json" '.failures|length' '0' "K9 reindex 失敗0件（knn フィールドが移行できる）"
os_refresh "${IDX_V2}"
os_curl -X POST "${OS_URL}/_aliases" -d '{ "actions": [ { "add": { "index": "'"${IDX_V2}"'", "alias": "'"${ALIAS}"'" } } ] }' > "${OUT}/k9-alias.resp.json"
assert_json "${OUT}/k9-alias.resp.json" '.acknowledged' 'true' "K9 エイリアス付与（原子的切替が可能）"
os_curl -X POST "${OS_URL}/${ALIAS}/_search" -d '{ "query": { "knn": { "embedding": { "vector": [0.11,0.20,0.30,0.41], "k": 3 } } } }' > "${OUT}/k9-alias-knn.resp.json"
assert_json "${OUT}/k9-alias-knn.resp.json" '.hits.hits|length' '3' "K9 エイリアス経由で knn クエリが成立（reindex 後も検索可）"

########################################################################
echo; echo "== K7: メモリ概算（公式式の転記・定量測定はスコープ外） =="
echo "  [INFO] HNSW full-precision メモリ概算 = 1.1 * (4 * dimension + 8 * m) bytes/vector"
echo "  [INFO] 例: dimension=768, m=16 → 1.1*(4*768+8*16)=1.1*3200=3520 bytes/vec ≈ 3.44KB/vec（doc数に線形）"
echo "  [INFO] byte/FP16・量子化(PQ/SQ)で係数低減。定量測定は後続タスク（負荷試験）。"

########################################################################
echo; echo "############################################################"
echo "# 結果: PASS=${pass}  FAIL=${fail}"
echo "############################################################"
[ "${fail}" -eq 0 ]
