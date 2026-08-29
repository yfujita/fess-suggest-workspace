# OpenSearch 技術検証レポート（fess-suggest 抜本改善・前提確定）

> タスク: `20260706_opensearch_reference`（要件定義 `0000-requirements-definition.md` / 作業プラン `0001-work-plan.md`）。
> 成果物: 要件 §アウトプット指定の `opensearch_tech_verification.md`。本レポートは Step1〜5 の検証結果（`00-docs-research.md` / `0002`〜`0005`）を1本に統合したもの。
> 作成日: 2026-07-06。検証はすべて実機 OpenSearch **3.7.0**（Docker）で実施。
> 凡例（改善案と共通）: **[事実]** 実機または一次情報（公式ドキュメント）で確認 / **[提案]** 本検証の判断 / **[要確認]** 後続タスクで確定。

---

## 0. エグゼクティブサマリ（結論）

本タスクの目的は、fess-suggest 抜本改善の後続設計（インデックス設計・インターフェース設計）に着手できるよう、未確定の OpenSearch 仕様・API を実機で検証し前提条件を確定することである。3件すべてについて確定に至った。

| 検証項目 | 結論 | 判定 |
|---|---|---|
| **1. `scripted_upsert`**（未存在=Insert / 存在=Painless で Update） | 現行 Get-then-update（`SuggestIndexWriter`）を **Painless スクリプト1本で置換可能**。頻度加算・配列集合マージ・null 安全・並行競合回避まで実機確認（26 アサーション green）。**改善案 MIG-15 第2段・ISS-10「原子的集約」の裏取り成立**。 | [事実] |
| **2. `knn`**（ベクトル検索のマッピング・クエリ要件） | knn の**必須マッピング・index 設定・クエリ構文・keyword 共存・filter・ハイブリッド統合・reindex/alias 親和**まで確定（28 アサーション green）。**MIG-24 / 拡張点 E3 の IF 確定の裏取り成立**。`dimension` は埋め込みモデル未定のため IF のみ（仮値）。 | [事実]（構文）＋[要確認]（実値） |
| **3. 新スキーマドラフト** | mapping / index settings ドラフトを作成。**`score` 廃止前提（復活余地注記）**・**`knn_vector`(embedding) 追加**・**`dynamic:"strict"` 化**を反映。 | [事実]／[提案] |

- **Definition of Done**（要件 §完了条件）: 「インデックス設計」「インターフェース設計」に着手できる前提（採用 API 仕様・スキーマドラフト・未確定事項の一覧）が本レポートに揃った。**充足。**
- **再現性**: すべての検証は冪等スクリプト化され、`verification/` 配下に request/response JSON を保存済み（§6）。

---

## 1. 検証環境・決定バージョン

### 1.1 決定バージョンと起動手段 [事実]

- **対象: OpenSearch 3.7.0**（改善案 §5.1 TBD-01 でクローズ済み・本タスクは「バージョン可否の証明」でなく API 仕様・用途適合の確定が目的）。実機で `GET /` が `"number":"3.7.0"` / `"lucene_version":"10.4.0"` を返すことを確認。
- **起動手段: Docker `opensearchproject/opensearch:3.7.0` 単一ノード**（security 無効・heap 1g・ホストポート 9201）。コンテナ名 `os370-verify`。
  ```bash
  docker run -d --name os370-verify -p 9201:9200 \
    -e "discovery.type=single-node" \
    -e "DISABLE_SECURITY_PLUGIN=true" -e "DISABLE_INSTALL_DEMO_CONFIG=true" \
    -e "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g" \
    opensearchproject/opensearch:3.7.0
  ```
- **プラグイン**: `opensearch-knn 3.7.0.0` / `opensearch-neural-search 3.7.0.0` が同梱されていることを `_cat/plugins` で確認（knn・ハイブリッド検証に必要なプラグインが揃う）。

### 1.2 opensearch-runner を使わない判断（プラン前提の訂正） [事実]

作業プラン §ステップ2 は「runner が 2.18.0.0（2.x）でバージョン差がある」ことを runner 不使用の論拠としていたが、実機調査で**前提を訂正**した。

- fess-suggest が実際にピン止めするのは **`opensearch-runner 3.7.0.0`**（親 `fess-parent:15.7.0` で `opensearch.version=3.7.0` / `opensearch.runner.version=3.7.0.0`）。よって「runner=2.x だからバージョン差がある」という論拠は成立しない。
- **より強い論拠**: `opensearch-runner` は **knn プラグインを同梱しない**（jar/pom に knn 参照皆無、`.m2` に knn 成果物なし）。runner は OpenSearch コアを組み込み起動するだけで、faiss/nmslib の JNI ネイティブを含む `opensearch-knn` プラグインは載らない。
- **結論**: バージョン差ではなく**プラグイン同梱の有無**を理由に、本検証は全プラグイン同梱の公式ディストリビューション（Docker）で実施。`scripted_upsert`（コア機能）も同一環境に揃えるため Docker に一本化。

### 1.3 2.x → 3.x の破壊的変更で後続設計に効くもの [事実]（出典 §7-D）

1. **既定 knn engine が `nmslib` → `faiss` に変更**。`nmslib` は非推奨、かつ **3.0 以降 新規インデックス作成がブロックされる**（実機確認・§3 K1）。
2. **index レベルの knn パラメータ設定が 3.0 で削除**（`index.knn.algo_param.ef_construction` / `.m` / `index.knn.space_type`）。→ **`method` オブジェクト（mapping 側）で指定する方式に一本化**（新スキーマの書式に直結・§4）。
3. `knn.plugin.enabled` 削除。
4. **JDK 21 が最低要件**（fess は Java 21+ 前提のため充足済み）。
5. bulk API でも doc ID 512 バイト制限が一貫適用（`text` を決定的 ID にする設計への留意点）。
6. Painless/scripting に 3.0 の破壊的変更は無し。

---

## 2. `scripted_upsert` 検証結果（Step3）

> 目的: 「未存在=Insert / 存在=Painless スクリプトで Update（頻度加算・属性マージ）」で現行 Get-then-update（`SuggestIndexWriter`）を置換できるかを確定する。写経元マージ規則: `SuggestItemSerializer#toUpdatedSource`（`SuggestItemSerializer.java:142-185`）。
> 全26アサーション green（`verification/scripted_upsert/run-scripted-upsert.sh`、PASS=26 / FAIL=0）。

### 2.1 採用する `scripted_upsert` 仕様（確定事項） [事実]

- **Update / Bulk とも `scripted_upsert: true` ＋ `upsert: {}`（空 doc）必須 ＋ `script`（Painless）**。
  - **`upsert` 行を省くと未存在 ID は `document_missing_exception`(404) で落ちる**（実機確認）。公式 Bulk 例は `upsert` を省略しているが、**Bulk でも本文行に `upsert:{}` を明示必須**（プラン §4-S4 の疑問に決着）。
- **並行更新の頻度取りこぼしは `retry_on_conflict` で回避**（Update=クエリパラメータ / Bulk=action メタ行）。retry 不足時は `version_conflict_engine_exception`(409) で取りこぼす。
- **配列の集合マージ（dedup）は Painless 内 `contains`+`add`**（現行 `concatValues` と同一戦略）。
- **null 安全は `ctx._source[f] == null` → `new ArrayList()` 初期化**でフィールド欠落時の NPE/型エラーを回避。

### 2.2 採用 Bulk NDJSON 形（実機成功形） [事実]

```
{ "update": { "_index": "<idx>", "_id": "<id>", "retry_on_conflict": 3 } }
{ "scripted_upsert": true, "upsert": {}, "script": { "lang":"painless", "source":"<merge-script>", "params": {...} } }
```

### 2.3 写経したマージ規則（`toUpdatedSource` → Painless） [事実]

Painless 実体は `verification/scripted_upsert/merge-script.painless`。写経元 Java と1:1対応。

| 項目 | 現行 Java（`toUpdatedSource`） | Painless 再現 |
|---|---|---|
| `queryFreq` / `docFreq` | `newValue + Long.parseLong(existing)`（null時=new のみ） | `((Number) ctx._source.f).longValue()` で加算、null 時は params 値のみ |
| `text` / `userBoost` / `@timestamp` | 上書き | `ctx._source.x = params.x`（timestamp は epoch_millis） |
| `score` | `(queryFreq+docFreq) * userBoost` を再計算 | 同式で再計算 ※**score 廃止時は当該行を削除**（§4.3） |
| `fields`/`tags`/`roles`/`languages`/`kinds` | `concatValues`（`contains`+`add` dedup） | 同戦略のループ |
| `reading_*`（動的） | 各 `reading_i` を集合マージ | `params.readings`(Map) を走査し同戦略 |
| （欠落フィールド） | 既存が List でなければ new をそのまま | `== null` なら `new ArrayList()` 初期化（null 安全） |

**実機結果の要点**:
- **Insert**: 未存在 ID へ `scripted_upsert:true`+`upsert:{}` → `result:"created"`。空 doc にスクリプトが走り正しく構築。
- **Update**: 同 ID 再投入で頻度加算（`queryFreq 12→15`）・スカラー上書き・`score=42.0=(15+6)*2.0` 再計算・配列 dedup（`roles=[admin,guest,user]`）を確認。
- **null 安全**: `roles` 未定義の最小 doc に `roles:["user"]` を投入 → 例外なく初期化・マージ。

### 2.4 並行競合の検証（`retry_on_conflict`） [事実]

同一 ID に 50 並行 `_update`（各回 `queryFreq += 1`）を打ち、retry 値を振って最終 `queryFreq`（=成功数）を比較（1ノード・1シャード）:

| retry_on_conflict | 2xx 成功 | 409 衝突 | loss | 最終 queryFreq |
|---:|---:|---:|---:|---:|
| 0  | 29 | 21 | 21 | 29 |
| 5  | 34 | 16 | 16 | 34 |
| 50 | 50 | 0  | **0** | **50** |

- **retry が十分なら取りこぼしゼロ**（`retry_on_conflict=50` で loss=0）。→ read-modify-write 競合を `scripted_upsert`＋`retry_on_conflict` で吸収でき、**改善案 §3.3 / ISS-10「原子的集約で頻度取りこぼし防止」の裏取り成立**。
- **retry=0 は取りこぼす**（loss=409件数と一致）。→ **`retry_on_conflict` は必須**。

### 2.5 複雑度評価・採用の推奨 [提案]

- **本体規模は約40行**（頻度加算 / スカラー上書き / score 再計算 / 固定フィールド集合マージ / 動的 `reading_*` 集合マージ の5ブロック）。各ブロックは現行 Java と1:1対応で可読性を保てる。改善案の「script 複雑化ゆえ慎重」に対しては**保守可能な範囲**と評価。
- **stored script 化を推奨**（`_scripts/<id>` に登録し `script:{id, params}` 参照）。利点: bulk ペイロード軽量化・改版の一元管理・呼び出し側の関心が params 契約のみに集約。inline/stored で同一挙動を確認済み。**採否の最終判断はユーザー（実装タスク）**。
- **dedup コスト**: `contains` は O(n) 線形走査のため1フィールドが数百要素規模だと O(n²)。fess-suggest の roles/tags は小さい想定だが、**呼び出し側で params を渡す前に dedup 済みにする**と走査対象を減らせる（現行 `getSource` も `distinct()` 済み配列を出す設計と整合）。定量評価は負荷試験（後続）。
- **params 契約**（呼び出し側＝将来の `SuggestIndexWriter` が組み立て）: `text`(String), `userBoost`(double), `timestamp`(long/epoch_millis), `queryFreq`/`docFreq`(long), `fields`/`tags`/`roles`/`languages`/`kinds`(String[]), `readings`(Map<String,String[]>: `"reading_0"->[...]`)。

> 補足（検証手順の修正）: プラン §3-2 が想定した `_scripts/painless/_execute` の `context:"update"` は **公式に存在しない**（context は `painless_test`/`filter`/`score` のみ）。よって単体検証は **使い捨てインデックス＋実 `_update`** で `_source` を突き合わせる方式に変更した（純ロジックの early check のみ `painless_test` を併用）。

---

## 3. `knn` 検証結果（Step4）

> 目的: セマンティック検索拡張（MIG-24 / 拡張点 E3）に必要な knn のマッピング定義要件とクエリ構文を確定する。実運用の埋め込み生成はスコープ外、IF（フィールド定義・クエリ成立性）の確定が目的。
> 全28アサーション green（`verification/knn/run-knn.sh`、PASS=28 / FAIL=0）。

### 3.1 チェックリスト結果（K1〜K9） [事実]

| ID | 検証項目 | 結果 |
|---|---|---|
| **K1** | `nmslib` は 3.x で作成拒否か警告か | **作成拒否（ブロック）**。`mapper_parsing_exception`: *"nmslib engine is deprecated … cannot be used for new index creation in OpenSearch from 3.0.0."* → **nmslib は不採用確定** |
| **K2** | `space_type=cosinesimil` が lucene/faiss で通るか | 両 engine で作成成功。**既定 `space_type` は `l2`** → cosine 使用時は明示指定が必要 |
| **K3** | `index.knn:true` 無しで knn クエリ失敗するか | `index.knn:true`＋method 指定で knn クエリ成立。**未設定だと `Field '...' is not built for ANN search` で失敗** |
| **K4** | keyword と `knn_vector` の同一インデックス共存 | `text`/`roles`(keyword) と `embedding`(knn_vector) を同一 doc に共存。prefix 検索と knn クエリが両立 |
| **K5** | `knn` + `filter`(roles/tags) が faiss/lucene で動作 | lucene・faiss とも filter で絞り込み成立（nmslib は K1 で作成不可のため対象外） |
| **K6** | `hybrid` + `normalization-processor` でスコア統合 | パイプライン（`min_max`/`arithmetic_mean`/weights`[0.3,0.7]`）で [0,1] 正規化・重複なく統合。**パイプライン無しの `hybrid` は負スコア・重複 hit で実用不可** → パイプライン必須 |
| **K7** | engine/method 別メモリ傾向 | HNSW full-precision ≈ `1.1*(4*dimension + 8*m)` bytes/vector（doc 数に線形）。byte/FP16・量子化で係数減 |
| **K8** | index レベル knn 設定（3.0 削除）が拒否されるか | `index.knn.algo_param.ef_construction` は `settings_exception`(unknown setting) で拒否 → **method オブジェクト方式のみで記述** |
| **K9** | 二重エイリアス再構築・単一シャード親和性 | 同一 knn マッピングの v2 へ `_reindex`（失敗0）→ エイリアス付与 → エイリアス経由 knn 成立。**reindex+alias 切替で無停止移行可能** |

### 3.2 確定した採用構成の骨子 [事実]

- **engine = `lucene`（第一候補）**。fess-suggest の「単一シャード・小規模・roles/tags フィルタ必須」特性に適合（filter が効き、Lucene セグメントに内包、別途ネイティブメモリ管理が不要）。**faiss** も cosinesimil+filter で同等成立を確認（大規模・量子化時の比較対象）。**`nmslib` は不採用**（K1）。
- **`index.knn: true`（settings）必須**（K3）。
- **マッピングは `method` オブジェクト方式のみ**（index レベル knn 設定は 3.0 で削除・K8）。
- keyword フィールドと `knn_vector` は**同一インデックスに共存可能**（K4）。
- **ハイブリッド（keyword+vector）のスコア統合は `hybrid` クエリ + Search Pipeline の `normalization-processor` が必須**（K6）。

### 3.3 クエリ構文 [事実]

```json
// 単体 knn（k 近傍）
{ "query": { "knn": { "embedding": { "vector": [/* dim 個 */], "k": 3 } } } }

// knn + filter（roles/tags 絞り込み）— faiss/lucene で有効
{ "query": { "knn": { "embedding": { "vector": [...], "k": 3, "filter": { "term": { "roles": "user" } } } } } }
```

ハイブリッドのスコア統合パイプライン（`phase_results_processors`）:
```json
{ "phase_results_processors": [ { "normalization-processor": {
    "normalization": { "technique": "min_max" },
    "combination":   { "technique": "arithmetic_mean", "parameters": { "weights": [0.3, 0.7] } }
} } ] }
```
- `weights` は要素数=サブクエリ数・**合計 1.0**。正規化 `min_max`/`l2`/`z_score`、結合 `arithmetic_mean`（既定）/`geometric_mean`/`harmonic_mean`。
- 埋め込みモデル未用意のため `neural` サブクエリを**生ベクトル `knn` サブクエリに置換**して構文成立性のみ確認。運用では `neural`（`model_id` 必須）に置換するか、アプリ側で別クエリ取得しマージするかを後続で選定。

### 3.4 fess-suggest への適用方針（2案・後続で決定） [提案]

1. **パイプライン統合案**: OpenSearch 側で `hybrid`+`normalization-processor` によりスコアを統合。サーバ側完結だが埋め込みモデル（`model_id`）と検索パイプライン運用が要る。
2. **アプリ側マージ案**: 現行の前方一致 keyword 検索と knn を別クエリで取得し、fess-suggest 側（`SuggestResponse` 生成）で統合。既存 function score ロジックと親和。

適合率の優劣は A/B・負荷試験（後続タスク・改善案 §5.3）で評価。本タスクは**両案とも構文・機構が成立することの確認まで**。

### 3.5 リソース傾向（定性・K7） [事実]（docs 転記）

- HNSW full-precision メモリ概算 = **`1.1 * (4 * dimension + 8 * m)` bytes/vector**（`dimension`・doc 数に線形）。例: `dimension=768, m=16` → ≈ 3.44KB/vec。
- `data_type` を `byte`/FP16 にする、または量子化（PQ/SQ・`compression_level`）で係数を下げられる。
- fess-suggest は単一シャード・小規模想定のため in_memory HNSW で収まる見込み（**定量測定はスコープ外・後続の負荷試験**）。

---

## 4. 新スキーマドラフト（Step5）

> **本タスクではドラフトのみ。実ファイル（`modules/fess-suggest/src/main/resources/suggest_indices/`）は差し替えない。** ドラフト実体は `verification/schema-draft/`。

### 4.1 mapping ドラフト（案A: `dynamic:"strict"`） [提案]

`verification/schema-draft/mappings-default.draft.json`（抜粋・`//_draft` 注記キーは JSON パース時に除去）:

```json
{
  "dynamic": "strict",
  "properties": {
    "@timestamp": { "type": "date", "format": "epoch_millis" },
    "text":       { "type": "keyword" },
    "queryFreq":  { "type": "long" },
    "docFreq":    { "type": "long" },
    "userBoost":  { "type": "double" },
    "kinds":      { "type": "keyword" },
    "tags":       { "type": "keyword" },
    "roles":      { "type": "keyword" },
    "languages":  { "type": "keyword" },
    "fields":     { "type": "keyword" },
    "reading_0":  { "type": "keyword" },
    "...":        "reading_1 〜 reading_9 まで明示定義（MAX_READING_NUM=10）",
    "embedding": {
      "type": "knn_vector",
      "dimension": 4,                 // [要確認] 埋め込みモデル確定後に差し替え（仮値）
      "space_type": "cosinesimil",    // 意味的類似は cosine。既定 l2 のため明示（K2）
      "method": {
        "name": "hnsw", "engine": "lucene",
        "parameters": { "ef_construction": 100, "m": 16 }
      }
    }
  }
}
```

### 4.2 index settings ドラフト [事実]

`verification/schema-draft/suggest.draft.json`:

```json
{ "index": {
  "refresh_interval": "10s",
  "number_of_shards": 1,
  "number_of_replicas": 0,
  "auto_expand_replicas": "0-1",
  "knn": true
} }
```

- **`index.knn: true` を追加**（`embedding` を使う場合必須・K3）。**embedding を載せない段階では本行を外し**、現行 `suggest.json` と同一設定でよい。
- index レベル knn algo_param は**書かない**（3.0 削除・K8）。すべて mapping の `method` 側で指定。
- `shards=1`/`replicas=0`/`auto_expand_replicas=0-1`/`refresh=10s` は**現行踏襲**（単一シャードが意図か既定かは [要確認] TBD-05・MIG-17）。

### 4.3 フィールド棚卸し表（維持 / 変更 / 廃止 / 追加）

| フィールド | 現行型 | 区分 | 新ドラフト | 根拠・対応 MIG/ISS | 確定度 |
|---|---|---|---|---|---|
| `@timestamp` | date/epoch_millis | 維持 | 同左 | 頻度更新時刻。scripted_upsert が epoch_millis 上書き | [事実] |
| `text` | keyword | 維持 | 同左 | サジェスト本体キー・前方一致検索・決定的 ID（KEEP-01/03） | [事実] |
| `queryFreq`/`docFreq` | long | 維持 | 同左 | 加算対象。Painless `longValue()` 加算に適合 | [事実] |
| `userBoost` | double | 維持 | 同左 | スカラー上書き。function score 係数 | [事実] |
| `kinds`/`tags`/`roles`/`languages`/`fields` | keyword | 維持 | 同左 | 集合マージ対象・filter 対象（roles は knn filter でも使用・K5） | [事実] |
| `reading_*`（動的） | keyword（dynamic_template） | **変更** | `reading_0`〜`reading_9` を**明示定義** | `dynamic:strict` 化のため明示化。`MAX_READING_NUM=10` で上限確定 | [提案] |
| `score` | double | **廃止** | （削除） | 死蔵フィールド（ISS-14/16・参照ゼロ）。MIG-02 案A。**復活余地を注記** | [提案]（両論併記） |
| `embedding` | （無し） | **追加** | `knn_vector`（hnsw/lucene/cosinesimil/dim=4 仮） | セマンティック拡張 IF（MIG-24/E3）。構文確定 | [事実]（構文）＋[要確認]（dim/採否） |
| `excluded` / 時系列 freq | — | 追加候補 | 未記載（枠のみ） | bad word 可逆化(MIG-13)・トレンド(MIG-20) は本タスク対象外 | [提案] |

### 4.4 主要な設計判断

- **`score` 廃止（両論併記）** [提案]:
  - **採用（ドラフト）= 廃止（MIG-02 案A）**。書き込み時 score 再計算コスト・double 容量を削減。現行も score は死蔵で未参照のため、廃止しても検索挙動は不変（ランキングは検索時 function score 単系統で成立）。
  - **復活の余地（注記）**: 想定 QPS・レイテンシ次第で保持案（案B）が残る。復活時は (1) mapping に `"score":{"type":"double"}` を戻す、(2) マージスクリプトに score 再計算ブロック（`(queryFreq+docFreq)*userBoost`）を復帰、の2点で足りる。最終採否は負荷試験（後続）とユーザー判断。
  - 要件定義の合意（`0001` L132/134「廃止前提で描き、復活余地を注記」）に沿う。
- **`dynamic:"strict"` 化（案A 推奨）** [提案]: `MAX_READING_NUM=10` で reading 数の上限が確定しているため `reading_0`〜`reading_9` の明示列挙が現実的。strict 化で未知フィールドを機構的に拒否し、scripted_upsert の params 契約ミス・マッピング肥大化を早期検知できる。`knn_vector` は明示定義のため影響なし。
  - 代替案B（`dynamic_templates` を `reading_*` に限定・可変長許容）を `mappings-default.alt-dynamic-template.draft.json` に併記。案C（`dynamic:false`）は reading_* が検索不能になるため実質案A に収束。
  - [要確認] 案A は `MAX_READING_NUM` 変更時に mapping 追随が必要（定数とスキーマの二重管理）。実装タスクで定数からの mapping 生成 or 固定を選ぶ。
- **scripted_upsert との整合** [事実]: 加算対象=`long`・マージ対象=`keyword` 配列は現行型のまま適合（型変更不要）。**score 廃止に伴いマージスクリプトから score 再計算行を除去**。`dynamic:strict` 採用時はスクリプトが書き込む全フィールドが mapping 定義済みである必要があり、本ドラフト（`text`/freq/`userBoost`/`@timestamp`/各 keyword 配列/`reading_0..9`）はこれを満たす。`embedding` はマージ対象外（別経路で投入）で未投入でも strict と両立。

### 4.5 移行 [事実]

score 廃止・reading 明示化・knn 追加・`index.knn` の全変更は、**二重エイリアス再構築（KEEP-02）1回に束ねて無停止移行可能**（K9 で knn の reindex+alias 切替を実証）。改善案 §8.1「フェーズ内のスキーマ変更は1回の再構築に束ねる」に整合。埋め込み基盤が整うまでは `embedding`＋`index.knn` を外した状態でリリースし（score 廃止のみ先行）、knn は後日再構築で追加する段階導入も可能。

---

## 5. 未確定事項・後続への申し送り

後続「インデックス設計」「インターフェース設計」および実装タスクへ引き継ぐ未確定事項。

| # | 未確定事項 | 現状の扱い | 確定タイミング |
|---|---|---|---|
| 1 | **埋め込みモデル / `dimension` / `space_type`** | IF（フィールド定義）のみ確定。仮値 `dimension=4` / `cosinesimil`。 | 埋め込みモデル確定後（MIG-24 前提の後続） |
| 2 | **knn engine 最終確定**（lucene ⇔ faiss） | lucene を第一候補として提示。faiss も成立確認済み。 | 規模・量子化要否で後続判断 |
| 3 | **ハイブリッド統合方式**（パイプライン統合 vs アプリ側マージ） | 両案とも機構成立を確認。 | 後続の設計・A/B（改善案 §5.3） |
| 4 | **`score` 採否**（廃止 案A / 保持 案B） | ドラフトは廃止前提＋復活余地注記。 | 負荷試験・ユーザー判断（改善案 §5.2・TBD） |
| 5 | **`dynamic` 案の最終選択**（案A/B/C） | 案A（strict）推奨。 | `MAX_READING_NUM` の二重管理許容度で判断 |
| 6 | **シャード / レプリカ**（単一維持 or 可変化） | 現行踏襲（既定値提示）。 | MIG-17 / TBD-05・現状規模で要確認 |
| 7 | **scripted_upsert の実装詳細**（stored script 化 / `retry_on_conflict` 既定値 / 呼び出し側事前集約） | inline/stored 同一挙動を確認。retry 3〜5 を初期値提案。 | 実装タスクで決定 |
| 8 | **定量性能**（スループット・レイテンシ・容量・適合率） | 定性評価＋公式ドキュメント根拠のみ。 | 負荷試験・A/B（後続タスク・改善案 §5.3） |

---

## 6. 成果物・再現手順

すべて `agent_docs/tasks/20260706_opensearch_reference/verification/` 配下。

| ディレクトリ / ファイル | 内容 |
|---|---|
| `00-docs-research.md` | Step1 公式ドキュメント調査（一次情報・URL 一覧＝§7） |
| `env/` | Step2 検証環境（`docker-run.sh` / `healthcheck.sh` / `setup-*.sh` / サンプル ndjson） |
| `scripted_upsert/merge-script.painless` | 採用マージスクリプト本体（写経元 `toUpdatedSource`） |
| `scripted_upsert/run-scripted-upsert.sh` + `out/` | Step3 検証（26 アサーション）と request/response |
| `knn/run-knn.sh` + `out/` | Step4 検証（28 アサーション）と request/response |
| `schema-draft/*.draft.json` | Step5 新スキーマ mapping / settings ドラフト（案A・案B・settings） |

再実行（`os370-verify`(:9201) 起動済み前提）:
```bash
cd agent_docs/tasks/20260706_opensearch_reference/verification
./env/healthcheck.sh                              # knn 有効を1コマンド確認
./scripted_upsert/run-scripted-upsert.sh          # => PASS=26 FAIL=0
./knn/run-knn.sh                                   # => PASS=28 FAIL=0
```

---

## 7. 参照した一次情報（公式ドキュメント・参照日 2026-07-06）

> `docs.opensearch.org/latest/…` の HTML は JS レンダリングのため、同内容の Markdown ソース（`raw.githubusercontent.com/opensearch-project/documentation-website/main/…`）を参照。`/latest/` は現行 3.x 系。

| 記号 | 参照先 | 確認内容 |
|---|---|---|
| A | OpenSearch 3.7.0 リリースノート（opensearch-build/release-notes/opensearch-release-notes-3.7.0.md） | 3.7.0 の knn/scripting 変更はすべて性能改善系、破壊的変更・非推奨なし |
| B | Update document API（`_api-reference/document-apis/update-document.md`） | `scripted_upsert`/`upsert`/`script`/`retry_on_conflict` 仕様・挙動 |
| C | Bulk API（`_api-reference/document-apis/bulk.md`） | bulk `update`＋`script`/`scripted_upsert`/`retry_on_conflict` NDJSON |
| D | Breaking changes（`_about/breaking-changes.md`） | nmslib 非推奨・既定 faiss、index レベル knn 設定削除、JDK21、bulk ID 512B |
| E | Painless execute API（`_api-reference/script-apis/exec-script.md`） | `_execute` の context は `painless_test`/`filter`/`score` のみ（update 無し） |
| F | k-NN vector field type（`_mappings/supported-field-types/knn-vector.md`） | `dimension`/`data_type`/`space_type`/`mode`/`method`、`index.knn:true` 必須 |
| G | Methods and engines（`_mappings/supported-field-types/knn-methods-engines.md`） | 既定 engine=faiss、engine 別 space_type、メモリ傾向、lucene の filter 優位 |
| H | k-NN query DSL（`_query-dsl/specialized/k-nn/index.md`） | `knn` クエリの `vector`/`k`/`filter`、filter は faiss/lucene のみ |
| I | Hybrid search（`_vector-search/ai-search/hybrid-search/index.md`） | `hybrid` クエリの `queries` 配列、Search Pipeline 必須 |
| J | normalization-processor（`_search-plugins/search-pipelines/normalization-processor.md`） | 正規化/結合 technique、weights 合計 1.0、hybrid 専用 |

> ドキュメントと実機挙動が食い違った場合は**実機を優先**した（例: nmslib は docs で "deprecated" 表現だが実機は 3.0 以降「作成ブロック」＝K1）。

---

## 付録: 本レポートと個別作業ドキュメントの対応

| 本レポート章 | 出典（作業ドキュメント） |
|---|---|
| §1 検証環境・バージョン | `0002-verification-environment-setup.md`、`00-docs-research.md` §1 |
| §2 scripted_upsert | `0003-scripted-upsert-verification.md` |
| §3 knn | `0004-knn-verification.md` |
| §4 新スキーマドラフト | `0005-schema-draft.md`、`verification/schema-draft/` |
| §5 未確定事項 | 各ドキュメント §申し送り |
| §7 一次情報 | `00-docs-research.md` §5 |
