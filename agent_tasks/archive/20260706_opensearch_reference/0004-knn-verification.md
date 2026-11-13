# 0004 `knn`（ベクトル検索）のマッピング・API 検証（ステップ4）

> タスク: `20260706_opensearch_reference` ステップ4（作業プラン `0001-work-plan.md` §ステップ4）。
> 実施日: 2026-07-06。凡例は改善案/00-docs-research に準拠（**[事実]** 実機/一次情報で確認 / **[提案]** 本メモの判断 / **[要確認]** 後続で確定）。
> 目的: セマンティック検索拡張（MIG-24 / 拡張点 E3）に必要な knn の**マッピング定義要件とクエリ構文**を実機で確定する。実運用の埋め込み生成はスコープ外だが、フィールド定義とクエリ（keyword 共存・filter・ハイブリッド）の成立性を本タスクで確定する。

---

## 1. 実施サマリ（結論）

- **[事実] knn の必須マッピング項目・インデックス設定・クエリ構文、および既存 keyword フィールドとの共存・filter・ハイブリッド（keyword+vector）スコア正規化・reindex/alias 親和性まで、OpenSearch 3.7.0 実機で確定した。** 検証スクリプト `verification/knn/run-knn.sh` の全28アサーションが green（PASS=28 / FAIL=0）。→ **MIG-24 / E3 の IF（マッピング・クエリ）確定の裏取り成立。**
- **[事実] 検証環境**: ステップ2の Docker OpenSearch 3.7.0（`os370-verify` / `http://localhost:9201`、`opensearch-knn 3.7.0.0` 有効）。検証用インデックス `knnv_*` を毎回作り直して実行（冪等）。
- **確定した採用構成の骨子**（レポート §knn に転記する確定事項）:
  - **engine = `lucene`（第一候補）**。fess-suggest は単一シャード・小規模・roles/tags フィルタ必須という特性に適合（filter が効き、Lucene セグメントに内包）。faiss も cosinesimil + filter で同等に成立を確認（大規模・量子化時の比較対象）。**`nmslib` は 3.0 以降 新規作成がブロックされる**ため不採用。
  - **`index.knn: true`（settings）必須**。無いと knn クエリは `Field '...' is not built for ANN search` で失敗。
  - **マッピングは `method` オブジェクト方式のみ**（`index.knn.algo_param.*` 等の index レベル knn 設定は 3.0 で削除され、指定すると `unknown setting` で拒否）。
  - keyword フィールド（`text`/`roles` 等）と `knn_vector` は**同一インデックスに共存可能**（prefix 検索と knn クエリが両立）。
  - ハイブリッド（keyword+vector）のスコア統合は **`hybrid` クエリ + Search Pipeline の `normalization-processor`** が必須（パイプライン無しの `hybrid` は未正規化スコアで実用不可）。
  - knn フィールドは **reindex + エイリアス切替**で問題なく移行でき、既存の二重エイリアス再構築（KEEP-02）とも親和。
- **[要確認] `dimension` / `space_type`**: 埋め込みモデル未定のため本検証は仮値 `dimension=4` / `space_type=cosinesimil`。IF 成立性の確認が目的（プラン §前提のユーザー回答どおり embedding は後回し・IF のみ）。実値はモデル確定後に差し替え。

## 2. 検証項目と結果（K1〜K9・チェックリスト対応）

00-docs-research §4 の knn チェックリスト（K1〜K9）に対する実機結果。各行の詳細エビデンスは `verification/knn/out/` の request/response JSON。

| ID | 検証項目 | 結果 | 判定 |
|---|---|---|---|
| **K1** | `nmslib` は 3.x で新規作成拒否か警告か | **作成拒否（ブロック）**。`mapper_parsing_exception`: *"nmslib engine is deprecated … and cannot be used for new index creation in OpenSearch from 3.0.0."* | [事実] |
| **K2** | `space_type=cosinesimil` が lucene / faiss で通るか | 両 engine で `cosinesimil` マッピング作成成功。既定 `space_type` は `l2`（cosine 使用時は明示指定が必要） | [事実] |
| **K3** | 既定 engine=faiss / `index.knn:true` 無しで knn クエリ失敗 | `index.knn:true` かつ method 指定で knn クエリ成立（最近傍が先頭）。`index.knn` 未設定だと `Field '...' is not built for ANN search` で失敗。method 省略でも作成・検索・filter 可（=既定 engine は nmslib でない=faiss/lucene、docs では faiss） | [事実] |
| **K4** | keyword フィールドと `knn_vector` の同一インデックス共存 | `text`/`roles`(keyword) と `embedding`(knn_vector) を同一 doc に投入成功。prefix 検索（v1/v2）と knn クエリ（3件）が両立 | [事実] |
| **K5** | `knn` + `filter`(roles/tags) が faiss / lucene で動作 | lucene: `filter{roles:user}` で v1/v2 に絞り込み。faiss: 同 filter で id=1 に絞り込み。両 engine で filter 成立（nmslib は K1 で作成不可のため対象外） | [事実] |
| **K6** | `hybrid` + `normalization-processor` でスコア統合 | パイプライン（`min_max` / `arithmetic_mean` / weights `[0.3,0.7]`）で統合スコアが [0,1] に正規化・重複なく統合。**パイプライン無しの `hybrid` は負スコア・重複 hit で未正規化** → パイプライン必須 | [事実] |
| **K7** | engine/method 別メモリ傾向（概算式） | HNSW full-precision ≈ `1.1*(4*dimension + 8*m)` bytes/vector（doc 数に線形）。byte/FP16・量子化で係数減。定量測定はスコープ外 | [事実]（docs 転記） |
| **K8** | index レベル knn 設定（3.0 削除）が拒否されるか | `index.knn.algo_param.ef_construction` は `settings_exception`（unknown setting）で拒否 → **method オブジェクト方式のみで記述**（新スキーマ書式確定）。※ 検索時 `index.knn.algo_param.ef_search` は現存 | [事実] |
| **K9** | 二重エイリアス再構築・単一シャードとの親和性 | 同一 knn マッピングの v2 へ `_reindex`（3件・失敗0）→ エイリアス付与 → エイリアス経由 knn クエリ成立。knn フィールドは reindex/alias 切替で移行可能 | [事実] |

## 3. 確定した採用マッピング・設定（レポート §knn 転記元）

### 3.1 インデックス設定（settings）[事実]

```json
{ "settings": { "index": {
  "knn": true,
  "number_of_shards": 1, "number_of_replicas": 0, "refresh_interval": "10s"
} } }
```

- **`index.knn: true` 必須**（無いと knn クエリが `not built for ANN search` で失敗・K3）。
- index レベルの knn アルゴリズムパラメータ（`knn.algo_param.ef_construction` / `knn.space_type` 等）は **書かない**（3.0 で削除・K8）。すべて mapping の `method` 側で指定。

### 3.2 `knn_vector` フィールド（method オブジェクト方式）[事実]

```json
"embedding": {
  "type": "knn_vector",
  "dimension": 4,               // [要確認] 埋め込みモデル確定後に差し替え（仮値）
  "space_type": "cosinesimil",  // 意味的類似は cosine。既定 l2 のため明示（K2）
  "method": {
    "name": "hnsw",
    "engine": "lucene",         // 第一候補。faiss も可（K2/K5）。nmslib 不可（K1）
    "parameters": { "ef_construction": 100, "m": 16 }
  }
}
```

- keyword フィールド（`text`/`roles`/`tags` 等）と**同一 `properties` 内に併記して共存**（K4）。
- **engine 選定 [提案]**: fess-suggest の「単一シャード・小規模・roles/tags フィルタ必須」特性から **`lucene` を第一候補**（filter 適合が良く、別途ネイティブメモリ管理が不要）。大規模化・量子化（PQ/SQ）でメモリ削減したい場合に faiss を再評価（本タスクで faiss も cosinesimil+filter 成立を確認済み）。

### 3.3 クエリ構文 [事実]

- **単体 knn（k 近傍）**:
  ```json
  { "query": { "knn": { "embedding": { "vector": [/* dim 個 */], "k": 3 } } } }
  ```
- **knn + filter（roles/tags 絞り込み）** — faiss/lucene で有効:
  ```json
  { "query": { "knn": { "embedding": { "vector": [...], "k": 3, "filter": { "term": { "roles": "user" } } } } } }
  ```
- **ハイブリッド（keyword + vector）** — Search Pipeline 必須（§4）。

## 4. ハイブリッド検索とスコア正規化の確定（K6）

- **[事実] `hybrid` クエリ単体ではスコア統合されない**。keyword（`match`）と vector（`knn`）を `queries` 配列で束ねても、**検索パイプライン無しでは負スコア・同一 doc 重複**が返り実用不可（本検証で実測）。
- **[事実] `normalization-processor`（`phase_results_processors`）でスコア統合が成立**:
  ```json
  { "phase_results_processors": [ { "normalization-processor": {
      "normalization": { "technique": "min_max" },
      "combination":   { "technique": "arithmetic_mean", "parameters": { "weights": [0.3, 0.7] } }
  } } ] }
  ```
  - `weights` は要素数=サブクエリ数・**合計 1.0**。正規化 `min_max`/`l2`/`z_score`、結合 `arithmetic_mean`（既定）/`geometric_mean`/`harmonic_mean`。統合スコアは [0,1] に正規化され、doc 重複なく統合されることを確認。
- **[事実・IF 検証上の置換] 埋め込みモデル未用意のため `neural` サブクエリを生ベクトル `knn` サブクエリに置換**して構文成立性のみ確認した。運用では `neural`（`model_id` 必須）に置換するか、アプリ側で別クエリ取得してマージするかを後続で選定。
- **[提案] fess-suggest への適用方針（2案・後続で決定）**:
  1. **パイプライン統合案**: OpenSearch 側で `hybrid`+`normalization-processor` によりスコアを統合。サーバ側完結だが埋め込みモデル（`model_id`）と検索パイプライン運用が要る。
  2. **アプリ側マージ案**: 現行の前方一致 keyword 検索と knn を別クエリで取得し、fess-suggest 側（`SuggestResponse` 生成）で統合。既存の function score ロジックと親和。
  - 適合率の優劣（どちらが良い並びか）は A/B・負荷試験（後続タスク・改善案 §5.3）で評価。本タスクは**両案とも構文・機構が成立することの確認まで**。

## 5. リソース傾向（K7・定性）

- **[事実]（docs 転記）** HNSW full-precision メモリ概算 = **`1.1 * (4 * dimension + 8 * m)` bytes/vector**。`dimension` と doc 数に線形。
  - 例: `dimension=768, m=16` → `1.1*(4*768+8*16)=1.1*3200≈3520 bytes/vec ≈ 3.44KB/vec`。
  - `data_type` を `byte`/FP16 にする、または量子化（PQ/SQ・`compression_level`）で係数を下げられる。
- fess-suggest は単一シャード・小規模想定のため、仮 dimension でも in_memory HNSW で収まる見込み（**定量測定はスコープ外・後続の負荷試験**）。engine 別の正確な最新係数は改訂され得るため実装時に再確認（[要確認]）。

## 6. 成果物（再現可能な検証資産）

`verification/knn/` に配置:

- `run-knn.sh` — K1〜K9 を一括実行し28アサーションを判定する冪等スクリプト（`out/` に request/response JSON を保存）。前提: ステップ2の `os370-verify`(:9201) 起動済み。冒頭で検証用インデックス/エイリアス/パイプラインを削除→再作成。
- `out/` — 生成した request/response（`k1-*` 〜 `k9-*`、`k6-pipeline.json`/`k6-hybrid-query.json` 等）。レポートのエビデンスとして参照可能。

再実行:
```bash
cd agent_docs/tasks/20260706_opensearch_reference/verification/knn
./run-knn.sh        # => PASS=28 FAIL=0
```

## 7. ステップ5・6（新スキーマドラフト / レポート）への申し送り

- **[事実] 確定した採用構成**（レポート §knn / 新スキーマ §index settings に転記）:
  - settings: `index.knn: true`（+ 現行 `shards=1`/`replicas=0`/`refresh=10s`）。index レベル knn algo_param は書かない。
  - mapping: `knn_vector` を `method` オブジェクト方式（`hnsw` / engine=`lucene`（第一候補）/ `space_type=cosinesimil` / `ef_construction`/`m`）で記述。keyword フィールドと同一 `properties` に併記。
  - クエリ: knn（+filter）成立。ハイブリッドは `hybrid`+`normalization-processor` 必須。
- **[要確認] 新スキーマ（ステップ5）へ持ち込む未確定点**:
  - `dimension` / `space_type`（埋め込みモデル依存・仮値）。**IF（フィールド定義）だけ用意し実値は後続**。
  - engine の最終確定（lucene ⇔ faiss）は規模・量子化要否で後続判断。本タスクは lucene を既定候補として提示。
  - ハイブリッド統合方式（パイプライン統合 vs アプリ側マージ）は後続の設計・A/B で決定。
- **[事実] 既存設計との整合**:
  - `index.knn:true` はインデックス単位設定 → **reindex + エイリアス切替（KEEP-02 二重エイリアス再構築）で無停止移行可能**（K9 実証）。
  - knn フィールド追加は既存 keyword フィールド・単一シャード設定と衝突しない（K4）。**新スキーマでは knn_vector を「拡張フィールド」として追加**する形が取れる（ステップ5 の棚卸しで「追加」に分類）。
  - `dynamic:"strict"` 化（ステップ5論点）を採る場合も、`knn_vector` は明示定義フィールドのため影響なし。
