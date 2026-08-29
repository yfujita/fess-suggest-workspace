# 0005 現行スキーマ棚卸しと新スキーマドラフト作成（ステップ5）

> タスク: `20260706_opensearch_reference` ステップ5（作業プラン `0001-work-plan.md` §ステップ5）。
> 実施日: 2026-07-06。凡例は改善案/00-docs-research に準拠（**[事実]** 実機/一次情報で確認 / **[提案]** 本メモの判断 / **[要確認]** 後続で確定）。
> 目的: ステップ3（`scripted_upsert`・`0003`）／ステップ4（`knn`・`0004`）の検証結果と改善案の設計判断を反映した、新 fess-suggest インデックスマッピング定義（JSON）**ドラフト**を作成する。**本タスクでは実ファイル（`modules/fess-suggest/src/main/resources/suggest_indices/`）は差し替えない。**

---

## 1. 実施サマリ（結論）

- **新スキーマ mapping ドラフト（`verification/schema-draft/mappings-default.draft.json`）と index settings ドラフト（同 `suggest.draft.json`）を作成した。** 各フィールドに「維持/変更/廃止/追加」の区分・根拠・対応 MIG/ISS・確定度を注記した（本ドキュメント §3・§4）。
- **主対象2点（プラン §ステップ5-1）の決定**:
  - **`score`（死蔵 double）は廃止前提**でドラフトを描く。要件定義の合意（`0001` L132/134：「廃止前提で描き、注記として復活の余地を残す」）どおり、mapping から除外しつつ復活手順を注記（MIG-02 案A）。
  - **`knn_vector`（`embedding`）を追加**。ステップ4（`0004`）で確定した `method` オブジェクト方式（`hnsw` / engine=`lucene` / `space_type=cosinesimil`）で定義。**IF（フィールド定義）のみ用意**し、`dimension` は仮値・埋め込み基盤は後続（プラン前提のユーザー回答どおり）。
- **`dynamic` 設定は `dynamic:"strict"`（案A）を第一提案**とし、`reading_0`〜`reading_9`（`MAX_READING_NUM=10` 相当）を明示定義する。dynamic_templates 維持案（案B）・`dynamic:false` 中間案も §5 で両論併記。
- **scripted_upsert（`0003`）との整合を確認**: 加算対象=`long`／マージ対象=`keyword` 配列という型はそのまま適合（型変更不要）。ただし **score 廃止に伴い、採用マージスクリプトから score 再計算ブロックを除去する**（`0003` §3 の注記と対応）。`dynamic:strict` 採用時は、スクリプトが `ctx._source` に書き込む全フィールドが mapping に定義済みである必要があり、ドラフトはこれを満たす（§6）。
- **既存データ移行**: すべての変更（score 廃止・reading 明示化・knn 追加・`index.knn`）は**二重エイリアス再構築（KEEP-02）1回に束ねて**吸収可能（`0004` K9 で knn の reindex+alias 切替を実証済み）。

## 2. 棚卸しの基点（現行スキーマ・[事実]）

- 現行 mapping: `modules/fess-suggest/src/main/resources/suggest_indices/suggest/mappings-default.json`
  - `dynamic_templates`: string → `keyword`（match `*`）
  - `properties`: `@timestamp`(date/epoch_millis) / `docFreq`(long) / `queryFreq`(long) / `userBoost`(double) / `score`(double) / `text`(keyword) / `kinds`・`tags`・`roles`・`languages`・`fields`(keyword)
  - `reading_*`（`FieldNames.READING_PREFIX="reading_"`、`MAX_READING_NUM=10`）は dynamic_template により keyword 化
- 現行 index settings: `.../suggest_indices/suggest.json`（`number_of_shards=1` / `number_of_replicas=0` / `refresh_interval=10s` / `auto_expand_replicas=0-1`）

## 3. フィールド棚卸し表（維持 / 変更 / 廃止 / 追加）

| フィールド | 現行型 | 区分 | 新ドラフト | 根拠・対応 | 確定度 |
|---|---|---|---|---|---|
| `@timestamp` | date/epoch_millis | **維持** | date/epoch_millis | 頻度更新時刻。scripted_upsert が epoch_millis で上書き（`0003` §3） | [事実] |
| `text` | keyword | **維持** | keyword | サジェスト本体キー。前方一致 keyword 検索・決定的 ID の対象（KEEP-01/03） | [事実] |
| `queryFreq` | long | **維持** | long | 加算対象。Painless `longValue()` 加算に適合（`0003` §3） | [事実] |
| `docFreq` | long | **維持** | long | 同上 | [事実] |
| `userBoost` | double | **維持** | double | スカラー上書き。function score の係数 | [事実] |
| `kinds` | keyword | **維持** | keyword | 集合マージ対象（DOCUMENT/QUERY/USER） | [事実] |
| `tags` | keyword | **維持** | keyword | 集合マージ対象・filter 対象 | [事実] |
| `roles` | keyword | **維持** | keyword | 集合マージ対象・権限 filter（knn filter でも使用・`0004` K5） | [事実] |
| `languages` | keyword | **維持** | keyword | 集合マージ対象 | [事実] |
| `fields` | keyword | **維持** | keyword | 集合マージ対象 | [事実] |
| `reading_*`（動的） | keyword（dynamic_template） | **変更** | `reading_0`〜`reading_9` を**明示定義**（案A）／template を `reading_*` に限定（案B） | `dynamic:strict` 化のため明示化（§5）。`MAX_READING_NUM=10` で上限確定 | [提案] |
| `score` | double | **廃止** | （削除） | 死蔵フィールド（ISS-14/16・参照ゼロ）。MIG-02 案A。**復活余地を注記** | [提案]（両論併記） |
| `embedding` | （無し） | **追加** | `knn_vector`（hnsw/lucene/cosinesimil/dim=4 仮） | セマンティック拡張の IF（MIG-24 / E3）。`0004` で構文確定 | [事実]（構文）＋[要確認]（dim/採否） |
| （拡張枠のみ） | — | **追加候補** | 未記載 | `excluded`(MIG-13 bad word 可逆化)・時系列 freq(MIG-20 トレンド) は本タスク対象外。枠のみ言及 | [提案] |

### 3.1 廃止＝`score` の扱い（両論併記・[提案]）

- **採用（ドラフト）: 廃止（MIG-02 案A・検索時計算）**。書き込み時 score 再計算コスト・double 容量を削減（改善案 §6.2.1）。ランキングは検索時 function score 単系統で成立（ISS-14：現行も score は死蔵で未参照＝廃止しても検索挙動は不変）。
- **復活の余地（注記）: 案B（score 保持・書き込み時計算＋検索時 sort）**。想定 QPS・レイテンシ要件次第で検索レイテンシ低減のため保持する選択肢が残る。復活時は (1) mapping に `"score": {"type":"double"}` を戻す、(2) scripted_upsert マージスクリプトに score 再計算ブロック（`(queryFreq+docFreq)*userBoost`）を復帰、の2点で足りる（`0003` §3）。**最終採否は負荷試験（後続・改善案 §5.3）とユーザー判断**（TBD／§5.2 未確定）。

### 3.2 追加＝`embedding`（knn_vector・[事実]構文／[要確認]値）

- ステップ4（`0004` §3.2）で確定した書式をそのまま採用：`method` オブジェクト方式（`hnsw` / engine=`lucene` 第一候補 / `space_type=cosinesimil` / `ef_construction=100` / `m=16`）。
- `dimension=4` は**仮値**。埋め込みモデル未定のため IF のみ用意（プラン前提のユーザー回答：embedding は後回し・IF だけでよい）。実値はモデル確定後に差し替え（[要確認]）。
- keyword フィールドと同一 `properties` に併記して共存可（`0004` K4）。`dynamic:strict` 採用でも明示定義フィールドのため影響なし（`0004` §7 申し送り）。
- **段階導入**: 埋め込み基盤が整うまでは `embedding` フィールドと `index.knn:true`（§4）を**外した状態でリリース**してもよい（score 廃止のみ先行）。knn は後日、再構築（KEEP-02）で追加可能（`0004` K9）。

## 4. index settings ドラフト（`suggest.draft.json`）

```json
{ "index": {
  "refresh_interval": "10s",
  "number_of_shards": 1,
  "number_of_replicas": 0,
  "auto_expand_replicas": "0-1",
  "knn": true
} }
```

- **`index.knn: true` を追加**（変更点）。`embedding`(knn_vector) を使う場合は**必須**（無いと knn クエリが `not built for ANN search` で失敗・`0004` K3）。**embedding を載せない段階では本行を外し、現行 `suggest.json` と同一設定**でよい。
- index レベルの knn アルゴリズムパラメータ（`knn.algo_param.*` / `knn.space_type`）は**書かない**（3.0 で削除・`0004` K8）。すべて mapping の `method` 側で指定。
- `number_of_shards=1` / `number_of_replicas=0` / `auto_expand_replicas=0-1` は**現行踏襲**。ただし単一シャードが「意図」か「既定のまま」かは **[要確認] TBD-05**、シャード可変化は MIG-17。現状規模なら単一で十分の可能性（改善案 §6.2.2）。本ドラフトは既定値提示にとどめ断定しない。
- `refresh_interval=10s` は現行踏襲（サジェスト用途で準リアルタイムで十分）。

## 5. `dynamic` 設定の検討（プラン §ステップ5-2）

現行は `dynamic_templates`（string→keyword、match `*`）に依存し、**未知フィールドが自動で keyword 追加される**。マッピング肥大化・意図しない型付けを防ぐため厳格化を検討する。OpenSearch の `dynamic` 挙動（[事実]・一次仕様）を踏まえた3案：

| 案 | 設定 | reading_* の扱い | 未知フィールド | 評価 |
|---|---|---|---|---|
| **案A（推奨）** | `dynamic: "strict"` | `reading_0`〜`reading_9` を**明示定義** | **拒否**（`strict_dynamic_mapping_exception`） | 肥大化・誤型付けを機構的に防止。reading 数は `MAX_READING_NUM=10` で上限確定済のため明示列挙が可能 |
| 案B | `dynamic: true` ＋ dynamic_template を `match:"reading_*"` に限定 | template で keyword 化（可変数許容） | template 非該当は個別に mapping 追加され得る（`reading_*` 以外の未知フィールドも追加） | reading 数を列挙せず可変対応。ただし厳格化効果は弱い |
| 案C（中間） | `dynamic: false` | 明示定義しないと**インデックスされない**（保存のみ） | 保存はするがインデックスしない | 未知フィールドを黙って保存。reading_* を明示定義しないと検索不能になるため、結局 reading_0..9 の明示定義が必要＝案A に近づく |

- **[提案] 案A を推奨**。理由：
  1. `MAX_READING_NUM=10` で reading フィールド数の**上限が確定**しており、`reading_0`〜`reading_9` の明示列挙が現実的（可変長の悩みが実質ない）。
  2. `dynamic:strict` は未知フィールドを**明示的に拒否**するため、`scripted_upsert` の params 契約ミスや想定外フィールド混入を早期検知でき、マッピング肥大化を機構的に防げる（改善案の意図に最も適合）。
  3. `knn_vector` は明示定義のため strict 化の影響を受けない（`0004` §7）。
- **[要確認] 案A の結合点**: `MAX_READING_NUM` を変更する場合、mapping の `reading_N` 定義も追随が必要（コード定数とスキーマの二重管理）。実装タスクで、定数からの mapping 生成 or 定数値の固定を選ぶ（本タスクはドラフト提示まで）。dynamic_template の可変長を残したい方針なら案B を採る。
- **[事実] scripted_upsert との両立**: `reading_*` を明示定義（案A）でも dynamic_template 維持（案B）でも、scripted_upsert 側は `params.readings` Map 走査で `ctx._source['reading_i']` に書き込むだけで影響を受けない（`0003` §9 申し送り）。**案A では書き込む `reading_i` が mapping 定義範囲（0..9）内である必要がある**点のみ留意。

## 6. `scripted_upsert` 前提でのフィールド設計整合（プラン §ステップ5-3・[事実]）

- **型適合**: 加算対象（`queryFreq`/`docFreq`=`long`）は Painless `longValue()` 加算に、集合マージ対象（`kinds`/`tags`/`roles`/`languages`/`fields`/`reading_*`=`keyword` 配列）は `contains`+`add` の dedup に、それぞれ**現行型のまま適合**（型変更不要・`0003` §3/§9）。
- **score 廃止との連動 [提案]**: 新スキーマで `score` を廃止する場合、採用する `scripted_upsert` マージスクリプト（`verification/scripted_upsert/merge-script.painless`）から **score 再計算ブロックを除去**する（スクリプトはさらに単純化）。復活する場合は当該ブロックを戻す（§3.1）。
- **`dynamic:strict` との連動 [事実/要確認]**: strict 化すると、スクリプトが `ctx._source` に書き込む全フィールドが mapping に定義済みである必要がある。本ドラフトの明示フィールド（`text`/`queryFreq`/`docFreq`/`userBoost`/`@timestamp`/`kinds`/`tags`/`roles`/`languages`/`fields`/`reading_0..9`）は params 契約（`0003` §7）と一致し、これを満たす。**embedding はマージスクリプト対象外**（別途 embedding 生成経路で投入想定）で、未投入でも欠落は許容されるため strict と両立。

## 7. 成果物

`verification/schema-draft/` に配置：

- `mappings-default.draft.json` — **新 mapping ドラフト（案A: `dynamic:strict`＋reading_0..9 明示＋embedding 追加＋score 廃止）**。レポート（ステップ6）§新スキーマ転記元。
- `mappings-default.alt-dynamic-template.draft.json` — 代替案B（dynamic_templates を `reading_*` に限定・`dynamic:true`）。
- `suggest.draft.json` — index settings ドラフト（現行踏襲＋`index.knn:true`）。

> いずれも先頭に `//_draft` 注記を付し、**本タスクでは実ファイルを差し替えない**ことを明示。JSON パーサに通す際は `//_draft` キー（および案B の `//_draft`）を除去すること（コメント代替のダミーキー）。

## 8. ステップ6（レポート）への申し送り

- **[事実/提案] 新スキーマドラフト（mapping + index settings）と変更理由表（本 §3）が完成**。レポート §新スキーマドラフトへ §3 表・§4 settings・§5 dynamic 判断をそのまま転記可能。
- **[要確認] 明示する未確定事項**（レポート §未確定事項へ）:
  - `score` 採否（案A 廃止／案B 保持）＝負荷試験・ユーザー判断（改善案 §5.2・TBD）。ドラフトは廃止前提＋復活余地注記。
  - `embedding` の `dimension`/`space_type`/engine 最終確定＝埋め込みモデル依存・後続（IF のみ確定）。knn を載せる時期（初回 or 後日再構築）も選択事項。
  - `dynamic` 案A/案B/案C の最終選択＝`MAX_READING_NUM` の二重管理許容度で判断。
  - シャード/レプリカ（MIG-17／TBD-05）＝現状規模で単一シャード維持か可変化かは要確認。
- **[事実] 移行**: 上記全変更は二重エイリアス再構築（KEEP-02）1回に束ねて無停止移行可（`0004` K9 で knn の reindex+alias 実証）。「フェーズ内のスキーマ変更は1回の再構築に束ねる」（改善案 §8.1）に整合。
