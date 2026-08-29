# 00 公式ドキュメント調査（Web 参照） — OpenSearch `scripted_upsert` / `knn`

> タスク: `20260706_opensearch_reference` ステップ1（作業プラン `0001-work-plan.md` §ステップ1）。
> 目的: 実機検証（ステップ3・4）に入る前に、OpenSearch 3.7.0 の公式ドキュメントを一次情報として参照し、`scripted_upsert` / `knn` の正式仕様・構文・制約・推奨構成を押さえ、**実機で検証すべき項目リスト**を洗い出す。
> 参照日: すべて **2026-07-06**。凡例は改善案に準拠（**[事実]** 一次情報で確認 / **[提案]** 本メモの判断 / **[要確認]** 実機または後続で確定）。
> 注記: `docs.opensearch.org/latest/…` の HTML ページは JS レンダリングのため WebFetch では本文が取れない。**一次情報は同内容の Markdown ソース（`raw.githubusercontent.com/opensearch-project/documentation-website/main/…`）を参照**した。URL は §5 に一覧化。docs サイトの `/latest/` は現行 3.x 系ドキュメント。

---

## 0. 調査サマリ（要点と確定度）

- **[事実] TBD-01 クローズの裏取り成立**: OpenSearch 3.7.0 のリリースノートおよび現行ドキュメントで、`scripted_upsert`（Update/Bulk API）・`knn`（ベクトル）・Painless・`fuzzy` はいずれも利用可能。3.7.0 のリリースノートに `scripted_upsert` / knn / scripting に関する**破壊的変更・非推奨は無い**（3.7.0 の knn 変更はすべて性能改善系）。
- **[事実] 2.x → 3.x の破壊的変更で後続設計に効くもの（重要）**:
  1. **既定 knn engine が `nmslib` → `faiss` に変更**。`nmslib` は非推奨（faiss / lucene を推奨）。
  2. **index レベルの knn パラメータ設定が 3.0 で削除**: `index.knn.algo_param.ef_construction` / `index.knn.algo_param.m` / `index.knn.space_type` は廃止。**`method` オブジェクト（mapping 側）で指定する方式に一本化**。→ 新スキーマ（ステップ5）の書き方に直接影響。
  3. `knn.plugin.enabled` 設定削除。
  4. **JDK 21 が最低要件**（fess は Java 21+ 前提のため充足済み・[事実]）。
  5. bulk API でもドキュメント ID 512 バイト制限が一貫適用（`text` を ID にする設計への留意点）。
- **[事実] scripted_upsert の要件**: `scripted_upsert: true` は `script` と `upsert` の**両方**を要求。`upsert` が空 `{}` でも可（その場合スクリプトがゼロから doc を構築）。未存在時=Insert（スクリプト実行）、存在時=スクリプトで Update。`retry_on_conflict`（Update はクエリパラメータ、Bulk は action メタフィールド）で並行更新の read-modify-write 競合をリトライ。→ 改善案 MIG-15 第2段・ISS-10「原子的集約」の裏取りが取れる見込み。
- **[要確認・重要／ステップ3の手順修正が必要] Painless `_execute` API に `update` context は無い**: `_scripts/painless/_execute` が公式に提供する context は **`painless_test` / `filter` / `score` の3つのみ**。作業プラン ステップ3-2 が想定する「`context: "update"` + `context_setup.document` でスクリプト単体検証」は**そのままでは実施不可**。→ 代替手順を §4 に明記。
- **[事実] knn 共存・ハイブリッド**: 同一インデックスで keyword フィールドと `knn_vector` を共存可能。keyword スコアと knn スコアはスケールが異なるため、統合には **`hybrid` クエリ + Search Pipeline の `normalization-processor`**（`min_max`/`l2`/`z_score` 正規化、`arithmetic_mean` 等で結合、weights は合計 1.0）が公式の推奨パターン。ただし `hybrid` の `neural` サブクエリは `model_id`（埋め込みモデル）を要する。**埋め込みモデル未用意の本タスクでは、`neural` の代わりに生ベクトルを渡す `knn` サブクエリで構文成立性のみ確認**するのが現実的（IF 確定が目的、埋め込み生成は後続）。
- **[事実] knn の filter は `faiss` / `lucene` engine でのみ有効**（`nmslib` 不可）。fess-suggest は roles/tags 等での絞り込みが前提のため、engine 選定上も faiss/lucene が必須。
- **[提案] engine 選定の当たり**: fess-suggest は単一シャード・小規模・roles/tags フィルタ必須という特性上、**`lucene` engine が有力候補**（フィルタ適合が良い、Lucene セグメントに内包され別途ネイティブメモリ管理が不要、小規模向けと明記）。faiss は大規模・量子化（PQ/SQ）でメモリ削減したい場合に優位。最終判断はステップ4/5で。

---

## 1. バージョン確認（3.7.0 での利用可否・2.x からの差分）

### 1.1 3.7.0 での利用可否 [事実]

| 機能 | 3.7.0 可否 | 根拠 |
|---|---|---|
| `scripted_upsert`（Update/Bulk） | 可 | Update document API ドキュメントに仕様記載（§2）。3.7.0 リリースノートに当該 API の破壊的変更なし |
| `knn`（ベクトル） | 可 | 3.7.0 リリースノートに knn 改善多数（性能系）。knn マッピング/クエリ ドキュメント現行 |
| Painless | 可 | script-apis ドキュメント現行。3.0 以降 scripting の破壊的変更なし |
| `fuzzy` | 可 | 標準 query DSL。バージョン依存の可否なし（本メモでは深掘り対象外・改善案で [事実] 済み） |

- 3.7.0 の knn 関連はすべて**性能改善・機能追加**（例: `knn_vector` docvalue_fields の base64 バイナリ既定化で ~2x スループット、doc_values 経由のベクトル取得で k=1000/768次元で最大 5.5x レイテンシ改善、1-bit スカラー量子化のリモートインデックスビルド、ハイブリッド最適化への z_score 正規化 / RRF 結合のオンボード等）。**破壊的変更・非推奨は 3.7.0 では記載なし** [事実]（§5-A）。

### 1.2 2.x → 3.x（主に 3.0）破壊的変更 [事実]（§5-D）

- **knn 既定 engine 変更**: `nmslib` → `faiss`。`nmslib` は非推奨（2.19 で deprecation、faiss/lucene 推奨）。※「新規インデックスでの nmslib 作成が 3.0 でブロックされる」との二次情報もあるが、現行ドキュメントは「deprecated（推奨しない）」表現。**ブロックか警告かは実機で確認**（§4-K1）。
- **index レベル knn 設定の削除**: `index.knn.algo_param.ef_construction` / `index.knn.algo_param.m` / `index.knn.space_type` を廃止 → `method`/`method.parameters`（mapping）で指定。**新スキーマ（ステップ5）は必ず mapping 側 method で書く**。
- `knn.plugin.enabled` 削除。
- **最低 JDK 21**（fess は Java 21+ のため充足・[事実]）。
- bulk API でも doc ID 512 バイト制限を一貫適用。
- Painless/scripting に 3.0 の破壊的変更は記載なし [事実]。

---

## 2. `scripted_upsert` 仕様（構文・パラメータ・Painless・retry_on_conflict）

### 2.1 Update document API のパラメータ [事実]（§5-B）

| パラメータ | 位置 | 仕様 |
|---|---|---|
| `scripted_upsert` | body | `true` でドキュメント有無に関わらず `script` を実行。既定 `false`。`script` と `upsert` の両方を要求 |
| `upsert` | body | 対象ドキュメントが存在しない場合に index する内容。`scripted_upsert: true` かつ `upsert: {}`（空）なら、スクリプトが空 doc から構築 |
| `script` | body | 更新ロジック本体（`source` or stored の `id` + `params`）。`ctx._source.*` を操作 |
| `doc_as_upsert` | body | `true` で `doc` を更新にも挿入にも使う。既定 `false`（scripted_upsert とは別方式） |
| `detect_noop` | body | `true` で変更が無ければ更新スキップ |
| `retry_on_conflict` | **query param**（Update）/ **action メタ**（Bulk） | version 競合時のリトライ回数。既定 `0` |

**Update（scripted_upsert）最小リクエスト例** [事実]（§5-B）:
```json
POST /sample-index1/_update/2
{
  "scripted_upsert": true,
  "script": {
    "source": "ctx._source.first_name = params.first_name; ...",
    "params": { "first_name": "Selina" }
  },
  "upsert": {}
}
```
挙動: ID が存在すれば script で更新、存在しなければ script で新規作成。`scripted_upsert:true` が無いと script は既存 doc にのみ実行され、新規は `upsert` の内容がそのまま index される。

### 2.2 Bulk API の update アクション [事実]（§5-C）

**NDJSON 例（scripted_upsert）**:
```
{ "update": { "_index": "movies", "_id": "tt0816711" } }
{ "script": { "source": "ctx._source.title = params.title; ...", "params": {...} }, "scripted_upsert": true }
```
- `retry_on_conflict` は action メタ行（`{ "update": { ..., "retry_on_conflict": 3 } }`）で指定。
- **[要確認]** 上記公式サンプルは `upsert` を省略している。Update API 仕様では scripted_upsert は `upsert` を要求するため、**Bulk でも `upsert:{}` を本文行に含める必要があるか**を実機確認（§4-S4）。

### 2.3 Painless で `ctx._source` 経由の更新 [事実]/[要確認]

- Update スクリプトの実行 context では `ctx._source`（Map）を直接読み書きする（`ctx._source.queryFreq += params.qf` など）。`ctx.op` で `"none"`/`"delete"` 制御も可能。
- `ctx._source` の配列は Java の `ArrayList`。集合マージ（重複排除）は Painless で `if (!ctx._source.tags.contains(x)) ctx._source.tags.add(x)` 等で実装可能だが、**null 安全（フィールド未存在時の初期化）・型（long 加算 vs Integer）・dedup コストは実機で潰す必要あり**（§4-S2, S3）。
- **[要確認・重要] スクリプト単体検証の手段**: `_scripts/painless/_execute` の context は `painless_test` / `filter` / `score` のみで **`update` context が無い**（§5-E）。よって「既存 source を渡して update スクリプトを単体実行」は当 API では不可。代替は §4-S1。

---

## 3. `knn` 仕様（マッピング・index 設定・クエリ・ハイブリッド/正規化・リソース）

### 3.1 `knn_vector` マッピング [事実]（§5-F）

| パラメータ | 値 | 既定 | 備考 |
|---|---|---|---|
| `type` | `knn_vector` | — | 必須 |
| `dimension` | 1〜16000 | — | 必須。埋め込みモデル依存（本タスクは仮値・[要確認]） |
| `data_type` | `float` / `byte` / `binary` | `float` | byte/binary はメモリ削減 |
| `space_type` | `l2`/`l1`/`linf`/`cosinesimil`/`innerproduct`/`hamming`/`hammingbit` | `l2` | 意味的類似は `cosinesimil` が定石（[提案]） |
| `mode` | `in_memory` / `on_disk` | `in_memory` | on_disk は量子化前提でメモリ節約 |
| `compression_level` | `1x`〜`32x` | — | 量子化と連動 |
| `method.name` | `hnsw` / `ivf` | — | サジェスト規模なら `hnsw`（[提案]） |
| `method.engine` | `faiss` / `lucene` / `nmslib` | **`faiss`** | nmslib は非推奨。filter 必要なら faiss/lucene |
| `method.parameters.ef_construction` | int | engine 依存 | ビルド精度/コスト |
| `method.parameters.m` | int | engine 依存 | グラフ次数。メモリに直結 |

- **`index.knn: true`（index settings）が必須** [事実]。
- マッピング例（faiss/hnsw）:
```json
{
  "settings": { "index": { "knn": true } },
  "mappings": { "properties": {
    "my_vector": {
      "type": "knn_vector", "dimension": 1024, "space_type": "l2",
      "method": { "name": "hnsw", "engine": "faiss", "parameters": { "ef_construction": 100, "m": 16 } }
    }
  }}
}
```
- **[要確認]** WebFetch では `space_type` 既定が「例示上 l2」と曖昧。cosinesimil を使う場合は明示指定する前提（§4-K2）。

### 3.2 methods / engines [事実]（§5-G）

- 既定 engine = **faiss**。
- space_type 対応: **lucene** = `l2`/`cosinesimil`/`innerproduct`。**faiss** = `l2`/`innerproduct`/`hamming`/`cosinesimil`。**nmslib** = `l2`/`innerproduct`/`cosinesimil`/`l1`/`linf`。
- メモリ傾向: faiss/HNSW=高（PQ で削減可）、faiss/IVF=中（PQ で削減可）、lucene/HNSW=高。
- **filter（検索時フィルタ）は lucene が得意**（"smart filtering"）、faiss は post-filter 等。**nmslib は filter 不可** → fess-suggest の roles/tags 絞り込み前提では nmslib を除外。

### 3.3 knn クエリ [事実]（§5-H）

```json
GET /my-vector-index/_search
{ "query": { "knn": { "my_vector": { "vector": [1.5, 2.5], "k": 3 } } } }
```
- `vector`（必須, float/byte 配列）, `k`（1〜10000, 近傍数）, `filter`（faiss/lucene のみ）, `max_distance` / `min_score`（半径検索。`k`/`max_distance`/`min_score` は排他）。

### 3.4 ハイブリッド検索 + スコア正規化 [事実]（§5-I, §5-J）

- **`hybrid` クエリ**が keyword（`match` 等）と ベクトル（`neural`/`knn`）サブクエリを `queries` 配列で束ねる:
```json
"query": { "hybrid": { "queries": [
  { "match": { "text": { "query": "..." } } },
  { "neural": { "embedding": { "query_text": "...", "model_id": "...", "k": 5 } } }
]}}
```
- **スコア統合には Search Pipeline の `normalization-processor` が必須**（`phase_results_processors`）:
  - 正規化 technique: `min_max` / `l2` / `z_score`。
  - 結合 technique: `arithmetic_mean`（既定）/ `geometric_mean` / `harmonic_mean`。3.7 で `z_score` 正規化・`rrf` 結合が HYBRID_OPTIMIZER にオンボード [事実]（§5-A）。
  - `combination.parameters.weights`: 0.0〜1.0、**合計 1.0**、要素数 = サブクエリ数。省略時は均等。
  - **hybrid クエリでのみ機能**（通常検索では無効）。
- **[提案] fess-suggest への適用**: `neural` サブクエリは `model_id`（埋め込みモデル）必須。本タスクは埋め込み未用意のため、(a) IF 検証としては `neural` を **生ベクトル `knn` サブクエリに置換**して hybrid + normalization の**構文成立性のみ**確認、(b) 運用ではアプリ側で keyword 結果と knn 結果を別クエリ取得してマージする案とパイプライン統合案を比較（適合率評価は後続 A/B、スコープ外）。

### 3.5 リソース傾向 [事実]/[要確認]（§5-K）

- HNSW グラフの概算メモリは公式に **`1.1 * (4 * dimension + 8 * m)` bytes/vector**（full-precision の従来式）。byte/FP16 や量子化で係数が下がる（例 `1.1 * (2 * dimension + 8 * m)`）。→ **dimension と doc 数に線形**でメモリ・インデックスサイズが増える。
- **[要確認]** 現行 3.x ドキュメントの正確な式・engine 別係数はページ改訂で変わり得るため、ステップ4 で methods-engines / performance ページの最新式を転記して確定（本メモは桁感の把握用）。
- サジェスト用途は 1 シャード・小規模想定のため、次元と件数次第で in_memory HNSW でも収まる見込み（定量測定はスコープ外・後続）。

---

## 4. 実機検証項目リスト（ステップ3/4 向けチェックリスト・各項目に出典）

### scripted_upsert（ステップ3）

- **S1 [手順修正・必須]** Painless スクリプト単体検証の手段。`_scripts/painless/_execute` に **`update` context は無い**（§5-E）。代替を実機で確立する:
  - 案A: 使い捨てインデックスに既存 source を `PUT` → 実際の `_update`（scripted_upsert）で加算/マージ結果を `_source` 確認（最も忠実）。
  - 案B: `painless_test` context に `params` で既存値相当を渡し、加算・dedup・null 分岐など**純ロジック**だけ先行検証（`ctx._source` は使えないため式を分離）。
  - 出典: §5-E, §5-B。
- **S2** `getUpdatedSource` の写経: `queryFreq`/`docFreq` の long 加算、`readings`/`tags`/`roles`/`languages`/`fields` の集合マージ（dedup）、`userBoost`/`@timestamp` 更新を Painless で再現し型エラー/NPE が出ないか。フィールド未存在時の初期化（null 安全）を1ケース。出典: §5-B（ctx._source 操作）。
- **S3** keyword 配列の重複排除方針決定（Painless 内 `contains`+`add` vs 呼び出し側整形）。大量 tags でのコスト感。出典: §5-B。
- **S4** Bulk `update` + `scripted_upsert` で `upsert:{}` 行が必要か（公式 Bulk 例は省略、Update 仕様は要求）。未存在 ID の初回 Insert と再投入 Update を Bulk で確認。出典: §5-C, §5-B。
- **S5** `retry_on_conflict`（Update=query param / Bulk=action メタ）で並行更新の競合リトライが効くか。同一 ID 同時更新で頻度取りこぼしが無いことを確認（改善案 §3.3 / ISS-10 の裏取り）。出典: §5-B, §5-C。
- **S6** エラー時挙動（型不一致・null）を1ケース確認し、スクリプト複雑度・可読性を評価（stored script 化の要否）。出典: §5-B。

### knn（ステップ4）

- **K1** `nmslib` は 3.0/3.7 で「新規インデックス作成が拒否されるか、警告のみで作成可か」を実機で確認（ドキュメントは "deprecated" 表現、二次情報は "blocked"）。出典: §5-D, §5-G。
- **K2** `space_type` 既定の確認（`cosinesimil` 使用時は明示要か）。faiss/lucene それぞれで cosinesimil マッピングが通るか。出典: §5-F, §5-G。
- **K3** 既定 engine が faiss であること、`index.knn:true` 無しだと knn クエリが失敗すること。出典: §5-F, §5-G。
- **K4** 既存 keyword フィールド（text/roles/tags 等）と `knn_vector` を**同一インデックス**に共存させ、mapping 作成・ドキュメント投入・両クエリが成立するか。出典: §5-F。
- **K5** `knn` クエリ + `filter`（roles/tags）が faiss と lucene で動作し、nmslib では filter 不可を確認。出典: §5-G, §5-H。
- **K6** `hybrid` クエリ + `normalization-processor`（`min_max`/`arithmetic_mean`, weights 合計 1.0）で keyword+ベクトルのスコア統合が成立するか。埋め込み未用意のため `neural` を生ベクトル `knn` サブクエリに置換して構文成立性を確認。出典: §5-I, §5-J。
- **K7** engine/method 別のメモリ・インデックスサイズ傾向（`1.1*(4*dim+8*m)` 系の式）を最新ドキュメントで転記し、仮 dimension での桁を把握。定量測定はスコープ外。出典: §5-K。
- **K8** 3.0 で index レベル knn 設定（`index.knn.algo_param.*`, `index.knn.space_type`）が削除されたことを踏まえ、**method オブジェクト方式のみで**マッピングが通ることを確認（新スキーマ ステップ5 の書式確定）。出典: §5-D。
- **K9** 二重エイリアス再構築（KEEP-02）・単一シャード設定と knn インデックスの親和性（reindex/alias 切替で knn フィールドが問題なく移行できるか）。出典: §5-F（index.knn 設定はインデックス単位）。

---

## 5. 参照 URL 一覧（URL＋参照日 2026-07-06＋確認内容）

- **A.** OpenSearch 3.7.0 リリースノート — https://github.com/opensearch-project/opensearch-build/blob/main/release-notes/opensearch-release-notes-3.7.0.md
  - 確認: 3.7.0 の knn/ベクトル/scripting 変更（すべて性能改善系、破壊的変更・非推奨なし）。z_score/RRF の HYBRID_OPTIMIZER オンボード。docvalue base64 既定化。
- **B.** Update document API（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_api-reference/document-apis/update-document.md
  - 確認: `scripted_upsert`/`upsert`/`script`/`doc_as_upsert`/`detect_noop`/`retry_on_conflict` の仕様と scripted_upsert リクエスト例、存在/未存在時の挙動。
- **C.** Bulk API（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_api-reference/document-apis/bulk.md
  - 確認: bulk `update` アクションでの `script`/`scripted_upsert`/`retry_on_conflict`、NDJSON 例。
- **D.** Breaking changes（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_about/breaking-changes.md
  - 確認: 3.0 で nmslib 非推奨・既定 faiss、`index.knn.algo_param.*`/`index.knn.space_type`/`knn.plugin.enabled` 削除、JDK 21 最低要件、bulk doc ID 512B 制限。
- **E.** Painless execute API（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_api-reference/script-apis/exec-script.md
  - 確認: `_scripts/painless/_execute` の context は `painless_test`/`filter`/`score` のみ（**update context 無し**）、`context_setup`（document/index/query）。
- **F.** k-NN vector field type（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_mappings/supported-field-types/knn-vector.md
  - 確認: `dimension`(1〜16000)/`data_type`/`space_type`/`mode`/`compression_level`/`method`、`index.knn:true` 必須、マッピング例。
- **G.** Methods and engines（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_mappings/supported-field-types/knn-methods-engines.md
  - 確認: 既定 engine=faiss、engine 別 space_type、メモリ傾向、nmslib 非推奨、lucene の filter 優位。
- **H.** k-NN query DSL（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_query-dsl/specialized/k-nn/index.md
  - 確認: `knn` クエリの `vector`/`k`/`filter`/`max_distance`/`min_score`、filter は faiss/lucene のみ。
- **I.** Hybrid search（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_vector-search/ai-search/hybrid-search/index.md
  - 確認: `hybrid` クエリの `queries` 配列（match + neural/knn）、Search Pipeline 必須。
- **J.** normalization-processor（Markdown ソース） — https://raw.githubusercontent.com/opensearch-project/documentation-website/main/_search-plugins/search-pipelines/normalization-processor.md
  - 確認: 正規化 min_max/l2/z_score、結合 arithmetic/geometric/harmonic_mean、weights 合計 1.0、hybrid 専用。
- **K.** HNSW メモリ概算式（検索経由・要 3.x 最新転記） — https://docs.opensearch.org/latest/mappings/supported-field-types/knn-methods-engines/ ほか performance tuning ページ
  - 確認: `1.1*(4*dimension+8*m)` bytes/vector 系（量子化で係数減）。正確な最新式はステップ4で転記確定（[要確認]）。

---

## 補足: ステップ3/4・5 への申し送り

- **ステップ3 手順修正**: 作業プラン 3-2 の「`_execute` の `context:"update"` でスクリプト単体検証」は API 上不可（§4-S1）。使い捨てインデックス + 実 `_update`、または `painless_test` context での純ロジック検証に切り替える。
- **ステップ4 engine 選定**: filter 必須（roles/tags）かつ小規模のため **lucene を第一候補**に検証（faiss は量子化・大規模時の比較対象）。nmslib は非推奨・filter 不可のため除外。
- **ステップ5 スキーマ**: knn は **method オブジェクト方式で記述**（index レベル knn 設定は 3.0 で廃止・§4-K8）。`index.knn:true` を settings に追加。`dimension`/`space_type` は埋め込みモデル未定のため仮値＋[要確認]。
</content>
</invoke>
