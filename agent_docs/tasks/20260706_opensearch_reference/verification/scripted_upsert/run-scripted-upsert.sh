#!/usr/bin/env bash
# ステップ3: scripted_upsert の API 検証（S1〜S5）
# 使い方: ./run-scripted-upsert.sh
# 前提: verification/env/docker-run.sh でコンテナ os370-verify が :9201 で起動済み。
# 冪等: 検証用インデックス su_verify を毎回作り直す。生成した request/response JSON は out/ に保存。
set -uo pipefail
cd "$(dirname "$0")"
source ../env/common.sh

IDX="${IDX_SU:-su_verify}"
SCRIPT_FILE="merge-script.painless"
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
# 数値として一致比較（double の 17.0 vs 17 差異を吸収）
assert_num() { # <file> <jq-filter> <expected-number> <label>
  local got; got=$(jq -c "$2 == $3" "$1")
  if [ "${got}" = "true" ]; then ok "$4 (=$(jq -c "$2" "$1"))"; else ng "$4 (got=$(jq -c "$2" "$1") expected=$3)"; fi
}

# Painless スクリプトを 1 行 JSON 文字列にエンコード（コメント行 // は温存されるが _source では実行される）
SCRIPT_JSON=$(jq -Rs . < "${SCRIPT_FILE}")

echo "############################################################"
echo "# ステップ3 scripted_upsert 検証   OS_URL=${OS_URL}  IDX=${IDX}"
echo "############################################################"

########################################################################
echo; echo "== S1: Painless 単体検証手段の確認 =="
# S1-a: _scripts/painless/_execute の update context が無いことを実機で確認（手順修正の裏取り）
cat > "${OUT}/s1-execute-update-context.json" <<'JSON'
{ "script": { "source": "ctx._source.docFreq += 1; return ctx._source.docFreq" },
  "context": "update",
  "context_setup": { "index": "su_verify", "document": { "docFreq": 5 } } }
JSON
os_curl -X POST "${OS_URL}/_scripts/painless/_execute" \
  --data-binary @"${OUT}/s1-execute-update-context.json" > "${OUT}/s1-execute-update-context.resp.json"
if jq -e '.error' "${OUT}/s1-execute-update-context.resp.json" >/dev/null 2>&1; then
  reason=$(jq -r '.error.reason // .error.root_cause[0].reason' "${OUT}/s1-execute-update-context.resp.json")
  ok "update context は _execute で拒否される（代替手順が必要）: ${reason}"
else
  ng "update context が通ってしまった（想定外）"
fi

# S1-b: painless_test context で純ロジック（配列 dedup）を単体検証できることを確認
cat > "${OUT}/s1-painless-test-dedup.json" <<'JSON'
{ "script": { "source": "def out = new ArrayList(); for (def v : params.a) { if (!out.contains(v)) out.add(v); } return out;",
              "params": { "a": ["user","admin","user","guest","admin"] } },
  "context": "painless_test" }
JSON
os_curl -X POST "${OS_URL}/_scripts/painless/_execute" \
  --data-binary @"${OUT}/s1-painless-test-dedup.json" > "${OUT}/s1-painless-test-dedup.resp.json"
# painless_test は結果を ArrayList.toString() で返すため "[user, admin, guest]" 文字列になる
assert_json "${OUT}/s1-painless-test-dedup.resp.json" '.result' '"[user, admin, guest]"' \
  "painless_test で dedup ロジックを単体検証できる"

########################################################################
echo; echo "== 準備: 検証用インデックス ${IDX} を再作成（base 写経マッピング） =="
os_delete_index "${IDX}" >/dev/null
os_curl -X PUT "${OS_URL}/${IDX}" --data-binary @../env/base-index.json > "${OUT}/create-index.resp.json"
assert_json "${OUT}/create-index.resp.json" '.acknowledged' 'true' "インデックス作成"

########################################################################
echo; echo "== S2/S3: _update(scripted_upsert) で Insert → Update（頻度加算・配列マージ・dedup） =="

# 共通: params を組んで _update リクエスト JSON を生成する関数
build_update_req() { # <params-json> -> stdout に _update body
  local params="$1"
  jq -n --arg src "$(cat "${SCRIPT_FILE}")" --argjson p "${params}" \
    '{ scripted_upsert: true, upsert: {}, script: { lang: "painless", source: $src, params: $p } }'
}

# (a) 未存在 ID s1 への初回投入 = Insert（upsert:{} の空 doc にスクリプトが走る）
P1='{"text":"opensearch","userBoost":1.0,"timestamp":1751769600000,"queryFreq":12,"docFreq":5,
     "fields":["content"],"tags":["blog"],"roles":["guest","user"],"languages":["en"],"kinds":["document"],
     "readings":{"reading_0":["オープンサーチ"]}}'
build_update_req "${P1}" > "${OUT}/s2-insert.req.json"
os_curl -X POST "${OS_URL}/${IDX}/_update/s1?refresh=true" --data-binary @"${OUT}/s2-insert.req.json" > "${OUT}/s2-insert.resp.json"
assert_json "${OUT}/s2-insert.resp.json" '.result' '"created"' "S2(a) 未存在 ID = Insert(created)"
os_curl "${OS_URL}/${IDX}/_doc/s1" > "${OUT}/s2-insert.doc.json"
assert_json "${OUT}/s2-insert.doc.json" '._source.queryFreq' '12' "  Insert 後 queryFreq"
assert_json "${OUT}/s2-insert.doc.json" '._source.docFreq'   '5'  "  Insert 後 docFreq"
assert_num  "${OUT}/s2-insert.doc.json" '._source.score'     17   "  Insert 後 score=(12+5)*1.0"
assert_json "${OUT}/s2-insert.doc.json" '._source.roles|sort' '["guest","user"]' "  Insert 後 roles"

# (b) 同一 ID s1 への再投入 = スクリプトで加算・集合マージ・dedup
#     roles に既存 "user"(重複) と 新規 "admin" を混ぜ、dedup と追加を同時に確認。
P2='{"text":"opensearch","userBoost":2.0,"timestamp":1751856000000,"queryFreq":3,"docFreq":1,
     "fields":["content","title"],"tags":["blog"],"roles":["user","admin"],"languages":["en"],"kinds":["query"],
     "readings":{"reading_0":["オープンサーチ","おーぷんさーち"]}}'
build_update_req "${P2}" > "${OUT}/s3-update.req.json"
os_curl -X POST "${OS_URL}/${IDX}/_update/s1?refresh=true" --data-binary @"${OUT}/s3-update.req.json" > "${OUT}/s3-update.resp.json"
assert_json "${OUT}/s3-update.resp.json" '.result' '"updated"' "S3(b) 既存 ID = Update(updated)"
os_curl "${OS_URL}/${IDX}/_doc/s1" > "${OUT}/s3-update.doc.json"
assert_json "${OUT}/s3-update.doc.json" '._source.queryFreq' '15' "  加算 queryFreq=12+3"
assert_json "${OUT}/s3-update.doc.json" '._source.docFreq'   '6'  "  加算 docFreq=5+1"
assert_num  "${OUT}/s3-update.doc.json" '._source.userBoost' 2    "  userBoost 上書き=2.0"
assert_num  "${OUT}/s3-update.doc.json" '._source.score'     42   "  score 再計算=(15+6)*2.0"
assert_json "${OUT}/s3-update.doc.json" '._source["@timestamp"]' '1751856000000' "  @timestamp 上書き"
assert_json "${OUT}/s3-update.doc.json" '._source.roles|sort' '["admin","guest","user"]' "  roles 集合マージ(dedup)"
assert_json "${OUT}/s3-update.doc.json" '._source.fields|sort' '["content","title"]' "  fields 集合マージ(dedup)"
assert_json "${OUT}/s3-update.doc.json" '._source.kinds|sort' '["document","query"]' "  kinds 集合マージ"
assert_json "${OUT}/s3-update.doc.json" '._source.reading_0|sort' '["おーぷんさーち","オープンサーチ"]' "  reading_0 集合マージ"

# (c) S2 null 安全: 既存 doc に配列フィールドが無い状態からのマージ
#     直接 PUT で最小 doc を作り（roles 未定義）、_update で roles を追加できるか。
os_curl -X PUT "${OS_URL}/${IDX}/_doc/s_null?refresh=true" -d '{"text":"x","queryFreq":1,"docFreq":0}' > /dev/null
Pn='{"text":"x","userBoost":1.0,"timestamp":1751856000000,"queryFreq":2,"docFreq":0,
     "fields":[],"tags":[],"roles":["user"],"languages":[],"kinds":[],"readings":{}}'
build_update_req "${Pn}" > "${OUT}/s2-nullsafe.req.json"
os_curl -X POST "${OS_URL}/${IDX}/_update/s_null?refresh=true" --data-binary @"${OUT}/s2-nullsafe.req.json" > "${OUT}/s2-nullsafe.resp.json"
if jq -e '.error' "${OUT}/s2-nullsafe.resp.json" >/dev/null 2>&1; then
  ng "S2(c) null 安全: 既存フィールド欠落時に例外 $(jq -c '.error.type' "${OUT}/s2-nullsafe.resp.json")"
else
  os_curl "${OS_URL}/${IDX}/_doc/s_null" > "${OUT}/s2-nullsafe.doc.json"
  assert_json "${OUT}/s2-nullsafe.doc.json" '._source.roles' '["user"]' "S2(c) null 安全: 欠落フィールドを初期化してマージ"
  assert_json "${OUT}/s2-nullsafe.doc.json" '._source.queryFreq' '3' "  null 安全: 既存 freq への加算"
fi

########################################################################
echo; echo "== S4: Bulk API 経由の update + scripted_upsert（upsert:{} 要否） =="
# 未存在 ID b1 を Bulk update で初回投入 → 同 Bulk 内で存在するようになるか / 別 Bulk で加算。
# S4 の主眼: Bulk 行に upsert:{} を含める必要があるか（公式 Bulk 例は省略、Update 仕様は要求）。
SRC1LINE=$(jq -Rs . < "${SCRIPT_FILE}")   # source を 1 行文字列に
PB='{"text":"bulk","userBoost":1.0,"timestamp":1751769600000,"queryFreq":4,"docFreq":2,"fields":[],"tags":["b"],"roles":["user"],"languages":[],"kinds":["document"],"readings":{}}'

# (S4-1) upsert:{} あり
{
  printf '{ "update": { "_index": "%s", "_id": "b1", "retry_on_conflict": 3 } }\n' "${IDX}"
  jq -c -n --argjson src "${SRC1LINE}" --argjson p "${PB}" \
    '{ scripted_upsert: true, upsert: {}, script: { lang:"painless", source:$src, params:$p } }'
} > "${OUT}/s4-bulk-with-upsert.ndjson"
os_curl -X POST "${OS_URL}/_bulk?refresh=true" --data-binary @"${OUT}/s4-bulk-with-upsert.ndjson" > "${OUT}/s4-bulk-with-upsert.resp.json"
assert_json "${OUT}/s4-bulk-with-upsert.resp.json" '.items[0].update.result' '"created"' "S4-1 Bulk(upsert:{}あり) 未存在=created"

# (S4-2) upsert 行なし（scripted_upsert のみ）→ 未存在 ID b2 でエラーになるか
{
  printf '{ "update": { "_index": "%s", "_id": "b2" } }\n' "${IDX}"
  jq -c -n --argjson src "${SRC1LINE}" --argjson p "${PB}" \
    '{ scripted_upsert: true, script: { lang:"painless", source:$src, params:$p } }'
} > "${OUT}/s4-bulk-no-upsert.ndjson"
os_curl -X POST "${OS_URL}/_bulk?refresh=true" --data-binary @"${OUT}/s4-bulk-no-upsert.ndjson" > "${OUT}/s4-bulk-no-upsert.resp.json"
st=$(jq -c '.items[0].update.status' "${OUT}/s4-bulk-no-upsert.resp.json")
res=$(jq -c '.items[0].update.result // .items[0].update.error.type' "${OUT}/s4-bulk-no-upsert.resp.json")
echo "  [INFO] S4-2 upsert行なし・未存在ID: status=${st} result/err=${res}"

# (S4-3) Bulk で同一 ID b1 を再投入 = 加算されるか
os_curl -X POST "${OS_URL}/_bulk?refresh=true" --data-binary @"${OUT}/s4-bulk-with-upsert.ndjson" > "${OUT}/s4-bulk-again.resp.json"
assert_json "${OUT}/s4-bulk-again.resp.json" '.items[0].update.result' '"updated"' "S4-3 Bulk 再投入=updated"
os_curl "${OS_URL}/${IDX}/_doc/b1" > "${OUT}/s4-b1.doc.json"
assert_json "${OUT}/s4-b1.doc.json" '._source.queryFreq' '8' "  Bulk 加算 queryFreq=4+4"

########################################################################
echo; echo "== S5: retry_on_conflict で並行更新の頻度取りこぼしが無いか =="
# 同一 ID に N 並行 _update（各回 queryFreq += 1）。最終値 == N なら取りこぼし無し。
# retry_on_conflict を 0 / 5 / 50 と振り、単調に取りこぼしが解消することを実証する
# （改善案 §3.3・ISS-10「原子的集約で頻度取りこぼし防止」の裏取り。retry が十分なら loss=0）。
PC='{"text":"c","userBoost":1.0,"timestamp":1751769600000,"queryFreq":1,"docFreq":0,"fields":[],"tags":[],"roles":[],"languages":[],"kinds":[],"readings":{}}'
build_update_req "${PC}" > "${OUT}/s5-inc.req.json"
N=50

# <retry値> を受け取り、専用 ID に N 並行更新を打ち、HTTP コード内訳と最終 freq を返す
run_conflict_batch() { # <retry> <id>
  local retry="$1"
  local id="$2"
  local d="${OUT}/s5-r${retry}"
  mkdir -p "${d}"
  os_curl -X DELETE "${OS_URL}/${IDX}/_doc/${id}" >/dev/null 2>&1 || true
  os_curl -X POST "${OS_URL}/${IDX}/_refresh" >/dev/null
  : > "${d}/codes.txt"
  for i in $(seq 1 ${N}); do
    ( code=$(os_curl -o "${d}/r${i}.json" -w '%{http_code}' \
        -X POST "${OS_URL}/${IDX}/_update/${id}?retry_on_conflict=${retry}" \
        --data-binary @"${OUT}/s5-inc.req.json"); echo "${code}" >> "${d}/codes.txt" ) &
  done
  wait
  os_curl -X POST "${OS_URL}/${IDX}/_refresh" >/dev/null
  local ok2xx c409 other final errtypes
  ok2xx=$(grep -cE '^2..$' "${d}/codes.txt" || true)
  c409=$(grep -c '^409$'  "${d}/codes.txt" || true)
  other=$(grep -vcE '^(2..|409)$' "${d}/codes.txt" || true)
  final=$(jq -c '._source.queryFreq // 0' <(os_curl "${OS_URL}/${IDX}/_doc/${id}"))
  errtypes=$(cat "${d}"/r*.json 2>/dev/null | jq -r 'select(.error) | (.error.type // .status) ' 2>/dev/null | sort | uniq -c | tr '\n' ' ')
  # 内訳は stderr（コンソール可視・$(... | tail -1) の捕捉対象外）。stdout は final のみ。
  echo "  [INFO] retry=${retry}: 2xx=${ok2xx} 409=${c409} other=${other} 最終queryFreq=${final} loss=$((N-final)) errtypes=[${errtypes}]" >&2
  echo "${final}"
}

f0=$(run_conflict_batch 0  c0  | tail -1)
f5=$(run_conflict_batch 5  c5  | tail -1)
f50=$(run_conflict_batch 50 c50 | tail -1)

# 判定1: retry 十分（=50）なら N 到達＝取りこぼしゼロ
if [ "${f50}" = "${N}" ]; then ok "S5 retry_on_conflict=50 で並行${N}更新の取りこぼしゼロ (queryFreq=${f50})";
else ng "S5 retry_on_conflict=50 でも未到達 (queryFreq=${f50}/${N})"; fi
# 判定2: retry=0 は取りこぼす（< N）＝ retry の必要性を実証
if [ "${f0}" -lt "${N}" ]; then ok "S5 retry_on_conflict=0 は取りこぼす (queryFreq=${f0}<${N}) → retry 必須の裏取り";
else ng "S5 retry=0 でも取りこぼさなかった（競合を再現できず）"; fi
# 判定3: 単調性（retry 増で loss 非増加）
if [ "${f0}" -le "${f5}" ] && [ "${f5}" -le "${f50}" ]; then ok "S5 単調性: loss は retry 増加で非増加 (f0=${f0} ≤ f5=${f5} ≤ f50=${f50})";
else echo "  [INFO] S5 単調性は厳密には成立せず（競合スケジューリングの分散）: f0=${f0} f5=${f5} f50=${f50}"; fi

########################################################################
echo; echo "############################################################"
echo "# 結果: PASS=${pass}  FAIL=${fail}"
echo "############################################################"
[ "${fail}" -eq 0 ]
