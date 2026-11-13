# 0003 `scripted_upsert` の API 検証（ステップ3）

> タスク: `20260706_opensearch_reference` ステップ3（作業プラン `0001-work-plan.md` §ステップ3）。
> 実施日: 2026-07-06。凡例は改善案/00-docs-research に準拠（**[事実]** 実機/一次情報で確認 / **[提案]** 本メモの判断 / **[要確認]** 後続で確定）。
> 目的: 「ドキュメント未存在時=Insert / 存在時=Painless スクリプトで Update（頻度加算・属性マージ）」が意図通り動作し、現行の Get-then-update（`SuggestIndexWriter`）を `scripted_upsert` で置換できるかを実機で確定する。

---

## 1. 実施サマリ（結論）

- **[事実] `scripted_upsert` で Insert/Update の両系統・頻度加算・配列集合マージ（dedup）・null 安全・並行競合回避まで、現行 `SuggestItemSerializer#toUpdatedSource` のマージ規則を Painless スクリプト1本で再現できることを実機確認した。** 検証スクリプト `verification/scripted_upsert/run-scripted-upsert.sh` の全26アサーションが green（PASS=26 / FAIL=0）。→ 現行 Get-then-update を置換可能。**改善案 MIG-15 第2段・ISS-10「原子的集約」の裏取り成立。**
- **[事実] 検証環境**: ステップ2の Docker OpenSearch 3.7.0（`os370-verify` / `http://localhost:9201`）。検証用インデックス `su_verify`（ステップ2 の `base-index.json` = 現行 `mappings-default.json` 写経）を毎回作り直して実行（冪等）。
- **採用する `scripted_upsert` 仕様の骨子**（レポート §scripted_upsert に転記する確定事項）:
  - Update / Bulk とも `scripted_upsert: true` ＋ **`upsert: {}`（空 doc）必須** ＋ `script`（Painless）。**`upsert` 行を省くと未存在 ID は `document_missing_exception`(404) で落ちる**（[事実] S4-2）。
  - 並行更新の頻度取りこぼしは **`retry_on_conflict` で回避**（Update=クエリパラメータ / Bulk=action メタ）。retry が不足すると `version_conflict_engine_exception`(409) で取りこぼす（[事実] S5）。
  - 配列の集合マージ（dedup）は **Painless 内 `contains`+`add`** で実現（現行 `concatValues` と同一戦略）。
- **[提案] スクリプトは stored script 化を推奨**（§6 複雑度評価）。本体は約40行だが、頻度加算・スカラー上書き・固定/動的フィールドの集合マージに分解でき、`params` 契約さえ守れば呼び出し側は薄い。

## 2. 検証手順の確定（S1: Painless 単体検証手段）

作業プラン ステップ3-2 は「`_scripts/painless/_execute` の `context:"update"` ＋ `context_setup.document` でスクリプト単体検証」を想定していたが、00-docs-research §4-S1 の通り **`_execute` に `update` context は無い**。実機で裏取りした:

- **[事実] S1-a**: `_scripts/painless/_execute` に `context: "update"` ＋ `context_setup.document` を投げると **`x_content_parse_exception` / `failed to parse field [context_setup]`** で拒否される。→ プラン 3-2 の単体検証手順は**そのままでは実施不可**。
- **[事実] S1-b（代替1）**: `context: "painless_test"` は純ロジック（例: 配列 dedup ループ）の単体検証に使える。返り値は `ArrayList.toString()` 形式の文字列（`"[user, admin, guest]"`）で返る点に留意。→ **型・ロジックの early check には有効だが、`ctx._source` を伴う update ロジックそのものは検証できない**。
- **[提案] 採用手順（代替2・本命）**: **使い捨てインデックス `su_verify` ＋ 実 `_update`(scripted_upsert)** で `_source` を突き合わせる（最も忠実）。以降の S2〜S5 はこの手順で実施した。純 Painless 断片の early check のみ `painless_test` を併用。

## 3. 写経したマージ規則（`toUpdatedSource` → Painless）

写経元: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/entity/SuggestItemSerializer.java:142-185`。Painless 実体は `verification/scripted_upsert/merge-script.painless`。

| 項目 | 現行 Java（toUpdatedSource） | Painless 再現 | 検証 |
|---|---|---|---|
| `queryFreq` / `docFreq` | `newValue + Long.parseLong(existing)`（null時=new） | `((Number) ctx._source.f).longValue()` で加算、null時は params 値のみ | S2/S3 [事実] |
| `text` | 上書き | `ctx._source.text = params.text` | S3 [事実] |
| `userBoost` | 上書き | 同上 | S3 [事実] |
| `@timestamp` | epoch_millis へ上書き | `ctx._source['@timestamp'] = params.timestamp` | S3 [事実] |
| `score` | `(queryFreq+docFreq) * userBoost` を**再計算** | 同式で再計算 | S2/S3 [事実] |
| `fields/tags/roles/languages/kinds` | `concatValues`（`contains`+`add` で dedup） | 同戦略のループ | S3 [事実] |
| `reading_*`（動的） | 各 `reading_i` を集合マージ | `params.readings`(Map) を走査し同戦略 | S3 [事実] |
| （欠落フィールド） | 既存が List でなければ new をそのまま | `ctx._source[f] == null` なら `new ArrayList()` で初期化 | S2-c null 安全 [事実] |

> 注記（[要確認]・後続 MIG-02）: `score` は改善案で **死蔵フィールド（廃止候補）**。本検証は現行 `toUpdatedSource` を忠実に写経したため score 再計算行を残している。ステップ5/6 で score を廃止する場合は当該行を削除する（スクリプトはさらに単純化する）。

### 実機結果の要点 [事実]

- **S2(a) Insert**: 未存在 ID `s1` へ `scripted_upsert:true`＋`upsert:{}` → `result:"created"`。`queryFreq=12 / docFreq=5 / score=17.0 / roles=[guest,user]`。空 doc にスクリプトが走り正しく構築。
- **S3(b) Update**: 同 ID 再投入（`queryFreq+=3, docFreq+=1, userBoost=2.0`、roles に既存 `user`(重複)＋新規 `admin`）→ `result:"updated"`。`queryFreq=15 / docFreq=6 / userBoost=2.0 / score=42.0=(15+6)*2.0 / @timestamp 上書き / roles=[admin,guest,user]（dedup 済）/ fields=[content,title] / kinds=[document,query] / reading_0 集合マージ`。
- **S2(c) null 安全**: `roles` 未定義の最小 doc に対し `_update` で `roles:["user"]` を投入 → 例外なく `roles=[user]` に初期化・マージ、既存 `queryFreq` への加算も成立。→ **フィールド欠落時の NPE/型エラーは発生しない**。

## 4. dedup 方針の決定（S3）

- **[提案・決定] keyword 配列の重複排除は Painless 内 `contains`+`add`** を採用（現行 `SuggestItemSerializer#concatValues` と同一戦略で移植コストが最小・意味が保存される）。small〜中規模の tags/roles では実用上問題なし。
- **[要確認] 大量要素時のコスト**: `contains` は O(n) 線形走査のため、1フィールドが数百要素規模になると O(n^2)。fess-suggest の roles/tags/languages は通常小さい想定だが、**呼び出し側（将来の SuggestIndexWriter）が params を渡す前に new 値を dedup 済みにしておく**と Painless 側の走査対象が減る（現行 `getSource`/`toJson` も `distinct()` 済み配列を出す設計と整合）。定量評価は負荷試験（後続タスク）。

## 5. Bulk 経由の検証（S4: `upsert:{}` 要否）

- **[事実] Bulk `update` アクション＋`scripted_upsert:true`＋`upsert:{}` で未存在 ID = `created`**（`status:201`）。再投入で `updated`＋加算（`queryFreq 4→8`）。→ Update API と同一挙動。
- **[事実・重要] `upsert` 行を省くと未存在 ID は落ちる**: `scripted_upsert:true` のみ（`upsert` 無し）で未存在 ID に Bulk update → `status:404 / document_missing_exception`。→ **00-docs-research §4-S4 の疑問（公式 Bulk 例は upsert 省略）に決着**: **Bulk でも本文行に `upsert:{}` を明示必須**。
- 採用する Bulk NDJSON 形（[事実] 実機成功形）:
  ```
  { "update": { "_index": "<idx>", "_id": "<id>", "retry_on_conflict": 3 } }
  { "scripted_upsert": true, "upsert": {}, "script": { "lang":"painless", "source":"<merge-script>", "params": {...} } }
  ```

## 6. 並行競合の検証（S5: `retry_on_conflict`）

同一 ID に **50 並行 `_update`**（各回 `queryFreq += 1`）を打ち、`retry_on_conflict` を 0 / 5 / 50 と振って最終 `queryFreq`（==成功数）を比較。1ノード・1シャード環境。代表実行値:

| retry_on_conflict | 2xx 成功 | 409 衝突 | loss（取りこぼし） | 最終 queryFreq |
|---:|---:|---:|---:|---:|
| 0  | 29 | 21（`version_conflict_engine_exception`）| 21 | 29 |
| 5  | 34 | 16 | 16 | 34 |
| 50 | 50 | 0  | **0** | **50** |

- **[事実] retry が十分なら取りこぼしゼロ**: `retry_on_conflict=50` で 50 並行更新でも loss=0（`queryFreq==50`）。→ **read-modify-write 競合を `scripted_upsert`＋`retry_on_conflict` で吸収でき、改善案 §3.3 / ISS-10「原子的集約で頻度取りこぼし防止」の裏取りが成立**。
- **[事実] retry=0 は取りこぼす**: 競合分（上例 21件）が 409 で失われ、その分 `queryFreq` が不足。loss は 409 件数と一致（成功数=最終値の内部整合も確認）。→ **retry_on_conflict は必須**。
- **[提案] retry 値の指針**: 「同一 ID への同時更新見込み数」に対して余裕を持たせる。上例のような極端な同時多重（50並行/同一ID）は実運用では稀だが、bulk バッチ内で同一テキストが重複し得る fess-suggest では **`retry_on_conflict` を 3〜5 程度**から始め、競合ログ（409）を監視して調整。**呼び出し側で bulk 投入前に同一 ID をアプリ側で事前集約（頻度をまとめてから1回 update）すると競合自体を減らせる**（[要確認] 実装時の設計判断）。

## 7. 複雑度・保守性の評価（改善案「script 複雑化ゆえ慎重」への回答）

- **[事実] 本体規模**: マージスクリプトは約40行。頻度加算 / スカラー上書き / score 再計算 / 固定フィールド集合マージ / 動的 `reading_*` 集合マージ の5ブロックに素直に分解でき、各ブロックは現行 Java の対応メソッドと1:1対応（可読性は保てる）。
- **[提案] stored script 化を推奨**: `_scripts/<id>` に登録し、update/bulk からは `script: { id, params }` で参照する形。利点=(1) リクエストごとにスクリプト本文を送らないため bulk ペイロードが軽い、(2) スクリプト改版を一箇所で管理（既存の二重エイリアス再構築 KEEP-02 とも相性可）、(3) params 契約が呼び出し側の唯一の関心事になり結合が薄い。欠点=登録/バージョン管理の運用が要る。→ **採否の最終判断はユーザー**（改善案の慎重論点）。本タスクは「inline でも stored でも同一挙動」を確認済み（スクリプト本文は同じ）。
- **[提案] params 契約（呼び出し側 = 将来の SuggestIndexWriter が組み立てる）**:
  `text`(String), `userBoost`(double), `timestamp`(long/epoch_millis), `queryFreq`/`docFreq`(long), `fields`/`tags`/`roles`/`languages`/`kinds`(String[]), `readings`(Map<String,String[]>: `"reading_0"->[...]`)。

## 8. 成果物（再現可能な検証資産）

`verification/scripted_upsert/` に配置:

- `merge-script.painless` — 採用するマージスクリプト本体（写経元 `toUpdatedSource`、レポート転記元）。
- `run-scripted-upsert.sh` — S1〜S5 を一括実行し26アサーションを判定する冪等スクリプト（`out/` に request/response JSON を保存）。前提: ステップ2の `os370-verify`(:9201) 起動済み。
- `out/` — 生成した request/response（`s1-*` 〜 `s5-*`）。エビデンスとしてレポートから参照可能。

再実行:
```bash
cd agent_docs/tasks/20260706_opensearch_reference/verification/scripted_upsert
./run-scripted-upsert.sh        # => PASS=26 FAIL=0
```

## 9. ステップ5・6（新スキーマドラフト / レポート）への申し送り

- **[事実] 確定した採用仕様**（レポート §scripted_upsert に転記）: Update/Bulk とも `scripted_upsert:true`＋`upsert:{}` 必須 / dedup は Painless 内 `contains`+`add` / 競合は `retry_on_conflict`（既定 3〜5・呼び出し側事前集約併用）/ null 安全は `== null` 初期化で担保。
- **[要確認] score の扱い**: 本検証は現行どおり score 再計算を含む。ステップ5 で score 廃止（MIG-02 案A）を採るならスクリプトから当該行を除去（両論併記の方針は要件定義の合意どおり「廃止前提＋復活余地の注記」）。
- **[事実] スキーマ整合**: 加算対象＝`long`、マージ対象＝`keyword` 配列という現行型は Painless の long 加算・集合マージにそのまま適合（型変更不要）。`reading_*` の動的増加も `params.readings` Map 走査で吸収できる → ステップ5 の `dynamic:"strict"` 検討時、reading_* を明示定義 or dynamic_template 維持のいずれでも scripted_upsert 側は影響を受けない。
- **[要確認] 実装タスクでの決定事項**: stored script 化の採否 / `retry_on_conflict` の既定値 / 呼び出し側事前集約の有無（いずれも本タスクのスコープ外＝後続の実装/設計で確定）。
