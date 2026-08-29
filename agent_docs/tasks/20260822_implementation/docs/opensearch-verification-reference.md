# OpenSearch 技術検証 結果リファレンス（設計インプット）

> 本書は設計タスク `20260706_design_document` から参照するための **技術検証結果のダイジェスト**である。
> 一次資料（フルレポート・エビデンス）は別タスク `20260706_opensearch_reference` にある。本書は設計判断に必要な確定事項を抜粋し、フルレポートへのポインタを示す。
> 凡例（改善提案と共通）: **[事実]** 実機/一次情報で確認 / **[提案]** 検証の判断 / **[要確認]** 後続で確定。

## 参照元（一次資料）

| 資料 | パス | 内容 |
|---|---|---|
| **検証レポート（本体）** | `agent_docs/tasks/20260706_opensearch_reference/opensearch_tech_verification.md` | 全検証結果の統合レポート（本書の詳細版） |
| 公式ドキュメント調査 | `.../20260706_opensearch_reference/verification/00-docs-research.md` | 一次情報・URL 一覧 |
| scripted_upsert 検証 | `.../verification/scripted_upsert/`（`merge-script.painless` / `run-scripted-upsert.sh` / `out/`） | 採用マージスクリプト・26 アサーション・request/response |
| knn 検証 | `.../verification/knn/`（`run-knn.sh` / `out/`） | K1〜K9・28 アサーション・request/response |
| 新スキーマドラフト | `.../verification/schema-draft/`（`mappings-default.draft.json` 他） | mapping / settings ドラフト |

- 前提バージョン: **OpenSearch 3.7.0**（`fess-parent:15.7.0` 系 / Java 21+）。改善提案 §5.1 TBD-01 クローズ済み。検証は全て実機（Docker `opensearchproject/opensearch:3.7.0`）で実施。

---

## 1. この検証結果が効く設計判断（早見表）

設計タスクの2成果物に対する、本検証からのインプットの対応。

| 設計成果物 | 本検証が与える確定事項 | 参照 §（本書） |
|---|---|---|
| **インターフェース・API 設計書**（Suggester/SuggestIndexer 分割） | scripted_upsert の **params 契約**＝Ingest/Index 系インターフェースの入力仕様。マージ規則の単一化仕様（Painless 1本）。 | §2 |
| **データモデル・インデックス移行設計書** | 新スキーマ mapping/settings ドラフト・マージ規則の単一化・**二重エイリアスによるゼロダウンタイム移行**の実証。 | §3, §4 |

---

## 2. `scripted_upsert`：マージ規則の単一化と Ingest インターフェースへのインプット

改善提案 MIG-15 第2段・ISS-10「原子的集約」の裏取りが**実機で成立**。現行 Get-then-update（`SuggestIndexWriter` の N 回 `prepareGet`→マージ→bulk）を **Painless スクリプト1本 + `scripted_upsert`** で置換できることを確認（26 アサーション green）。

### 2.1 API 設計への確定インプット [事実]

- **採用形**: Update / Bulk とも `scripted_upsert: true` ＋ **`upsert: {}` 必須** ＋ `script`。`upsert` 省略で未存在 ID は `document_missing_exception`(404)。
- **競合対策**: `retry_on_conflict`（Update=クエリパラメータ / Bulk=action メタ行）。**必須**（retry=0 は並行更新で頻度取りこぼし、retry 十分なら loss=0 を実測）。初期値は 3〜5 を提案、呼び出し側の事前集約と併用可。
- **Bulk NDJSON 形**:
  ```
  { "update": { "_index": "<idx>", "_id": "<id>", "retry_on_conflict": 3 } }
  { "scripted_upsert": true, "upsert": {}, "script": { "lang":"painless", "id/source":..., "params": {...} } }
  ```
- **Bulk チャンクサイズ**: 1 リクエストで処理する件数（現行 `suggest.update.doc.per.request` 相当）は性能に直結するが、**最適値は負荷試験で決定**する（本検証はスコープ外・§5 定量性能）。→ **API 設計では、このチャンクサイズ（および `retry_on_conflict` 値）を固定せず、バッチ処理パラメータとして外部注入可能にする**（設定/引数で差し替えられる）シグネチャにしておくと、後続の負荷試験結果を実装変更なしに反映できる。

### 2.2 マージ規則の単一化仕様（設計書「重複しているマージ規則の単一化」へ直結） [事実]

現行は `SuggestItemSerializer#toUpdatedSource`（Java）にマージ規則が存在。これを **Painless に写経して単一の権威にする**のが本検証の裏取り。マージ規則の内容:

| 対象 | 規則 |
|---|---|
| `queryFreq` / `docFreq`（long） | 既存値へ加算（null 安全・`Number.longValue()` で型安全） |
| `text` / `userBoost` / `@timestamp` | 上書き（timestamp は epoch_millis） |
| `fields`/`tags`/`roles`/`languages`/`kinds` / `reading_*`（keyword 配列） | 集合マージ（`contains`+`add` で dedup） |
| `score`（double） | `(queryFreq+docFreq)*userBoost` 再計算 ※**新スキーマで廃止時は当該行を除去**（§4.2） |

- 採用スクリプト実体: `.../verification/scripted_upsert/merge-script.painless`（約40行・5ブロック）。
- **[提案] stored script 化**を推奨（bulk ペイロード軽量化・改版一元管理・呼び出し側の関心が params のみに集約）。inline/stored 同一挙動を確認済み。**採否は実装/設計で決定**。

### 2.3 `params` 契約（Ingest/Index インターフェースのメソッドシグネチャ設計の入力） [提案]

呼び出し側（分割後の Ingest/Index 系コンポーネント）がスクリプトへ渡す契約:

```
text(String), userBoost(double), timestamp(long/epoch_millis),
queryFreq(long), docFreq(long),
fields/tags/roles/languages/kinds(String[]),
readings(Map<String,String[]>: "reading_0" -> [...])
```

→ インターフェース分割（Ingest 系）では、この params を組み立てて渡す責務を持たせる。マージ・dedup の本体は OpenSearch 側（Painless）に集約され、アプリ側は「入力の整形」に薄くなる。

---

## 3. `knn`：データモデルへの拡張フィールド仕様

セマンティック検索拡張（MIG-24 / 拡張点 E3）の **IF（マッピング・クエリ）を確定**（28 アサーション green）。実運用の埋め込み生成はスコープ外、フィールド定義とクエリ成立性のみ確定。

### 3.1 データモデル設計への確定インプット [事実]

- **engine = `lucene`（第一候補）**。単一シャード・小規模・roles/tags フィルタ必須という fess-suggest 特性に適合。faiss も成立確認（大規模・量子化時の比較対象）。**`nmslib` は 3.0 以降 作成ブロックで不採用**。
- **`index.knn: true`（settings）必須**。無いと knn クエリが `not built for ANN search` で失敗。
- **マッピングは `method` オブジェクト方式のみ**（index レベル knn 設定は 3.0 で削除）。
- keyword フィールドと `knn_vector` は**同一インデックス共存可**（既存 keyword 設計を壊さず「拡張フィールド」として追加できる）。
- ハイブリッド（keyword+vector）統合は **`hybrid` クエリ + Search Pipeline `normalization-processor` が必須**（統合方式＝サーバ側パイプライン統合 / アプリ側マージ の2案は後続で選定・§3.3）。

### 3.2 移行設計への確定インプット [事実]

- knn フィールド追加・`index.knn:true` は **reindex + エイリアス切替で無停止移行可能**（K9 実証）。→ **二重エイリアス再構築（KEEP-02）とそのまま親和**。
- 段階導入可: 埋め込み基盤が整うまで `embedding`＋`index.knn` を外してリリースし、後日再構築で追加できる。

### 3.3 [要確認]（設計で断定しない・後続依存）

- `dimension` / `space_type`：埋め込みモデル未定のため仮値（`dimension=4` / `cosinesimil`）。IF のみ確定。
- engine 最終確定（lucene ⇔ faiss）・ハイブリッド統合方式（パイプライン vs アプリ側マージ）は規模・A/B で後続決定。

---

## 4. 新スキーマドラフト（データモデル設計書の起点）

ドラフト実体: `.../verification/schema-draft/mappings-default.draft.json`（案A）/ `suggest.draft.json`。**実ファイルは未差し替え**（設計タスクで確定させる）。

### 4.1 index settings ドラフト [事実]
```json
{ "index": {
  "refresh_interval": "10s", "number_of_shards": 1, "number_of_replicas": 0,
  "auto_expand_replicas": "0-1", "knn": true
} }
```
（`index.knn:true` は embedding 使用時のみ必須。未使用段階では外して現行 `suggest.json` と同一）

### 4.2 主要な変更点と設計判断

| 変更 | 内容 | 確定度 |
|---|---|---|
| **`score` 廃止** | 死蔵フィールド（ISS-14/16・参照ゼロ）を mapping から除外＋マージスクリプトの score 再計算行を除去。**復活余地を注記**（mapping 復帰＋スクリプト行復帰の2点で戻せる）。 | [提案]（両論併記・最終採否は負荷試験/ユーザー） |
| **`embedding` 追加** | `knn_vector`（hnsw/lucene/cosinesimil/dim=4 仮）。IF のみ。 | [事実]（構文）＋[要確認]（実値） |
| **`dynamic:"strict"` 化** | `reading_0`〜`reading_9`（`MAX_READING_NUM=10`）を明示定義。未知フィールドを機構的に拒否し肥大化・params 契約ミスを早期検知。代替案B（dynamic_template を `reading_*` 限定）も併記。**トレードオフ [要確認]**: Java 側定数 `MAX_READING_NUM` を変更すると、スキーマ（`reading_N` の明示定義）の変更も**必須**になる＝**定数とスキーマの二重管理**が生じる。データモデル設計では、この結合を許容した上で「定数から mapping を生成する／定数値を固定する」等の整合策を織り込むこと（可変長を優先するなら案B を選択）。 | [提案] |
| 維持 | `@timestamp`/`text`/`queryFreq`/`docFreq`/`userBoost`/`kinds`/`tags`/`roles`/`languages`/`fields` は型変更不要（Painless 加算・集合マージに適合）。 | [事実] |

### 4.3 移行（ゼロダウンタイム）への確定インプット [事実]

- 上記全変更（score 廃止・reading 明示化・knn 追加・`index.knn`）は **二重エイリアス再構築（KEEP-02）1回に束ねて無停止移行可能**（K9 で reindex+alias 切替を実証）。改善提案 §8.1「フェーズ内のスキーマ変更は1回の再構築に束ねる」に整合。
- → 設計書「二重エイリアスを活用したゼロダウンタイム移行手順」は、本検証の reindex+alias 実証（`.../verification/knn/out/k9-*`）を根拠にできる。

---

## 5. 設計タスクへ持ち込む未確定事項（断定しない）

| # | 事項 | 扱い |
|---|---|---|
| 1 | 埋め込みモデル / `dimension` / `space_type` | IF のみ確定。実値は後続 |
| 2 | knn engine 最終確定（lucene ⇔ faiss） | lucene 第一候補・後続判断 |
| 3 | ハイブリッド統合方式（パイプライン統合 / アプリ側マージ） | 両案とも機構成立確認・A/B で決定 |
| 4 | `score` 採否（廃止 / 保持） | 廃止前提＋復活余地注記・負荷試験/ユーザー判断 |
| 5 | `dynamic` 案（strict / dynamic_template / false） | 案A(strict) 推奨・`MAX_READING_NUM` 二重管理許容度で判断 |
| 6 | シャード/レプリカ（単一維持 / 可変化） | 現行踏襲・MIG-17/TBD-05 で要確認 |
| 7 | scripted_upsert 実装詳細（stored script 化 / retry 既定値 / 事前集約） | 実装で決定 |
| 8 | 定量性能（スループット/レイテンシ/容量/適合率） | 負荷試験・A/B（後続・改善提案 §5.3） |

> 詳細・エビデンス・一次情報 URL はフルレポート `agent_docs/tasks/20260706_opensearch_reference/opensearch_tech_verification.md` を参照。
