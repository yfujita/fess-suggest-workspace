# ステップ2: コードベースの補足確認（改善案の根拠強化）

## 1. 概要

本ドキュメントは、fess-suggest 抜本的改善提案タスク（`20260622_improvement_proposal`）の**ステップ2「コードベースの補足確認」**の成果物である。

- **目的**: ステップ1の課題インベントリ（`0002-step1-issue-inventory.md` の ISS-01〜15 / TBD-01〜05）について、改善案の妥当性判断に追加確認が必要な箇所だけをピンポイントで実コードに当たり、**補足根拠を強化・精緻化・是正**する。
- **スコープ**: 提案の根拠付けに必要な最小限の確認に限定。全コード網羅読解はしない。既存分析で十分な項目（②デッドパス、cache.expire 単位不一致 等）は再確認していない。
- **凡例**: **[確認]** = 本ステップでソースコードを直接確認した事実（`file_path:line` 追跡可能）/ **[推測]** = 実装から合理的に推測した内容 / **[改善の種]** = 確認過程で気づいた改善候補のメモ（ステップ3以降の領分）。

### 実施範囲（確認したファイル）

| 領域 | 確認ファイル |
| --- | --- |
| suggestDetail 既定 | `request/suggest/SuggestRequest.java`, `SuggestRequestBuilder.java`, `Suggester.java`, fess `SuggestWordsHandler.java` |
| bad word 削除 | `index/operations/WordManagementOperations.java`, `index/operations/DeletionOperations.java`, `resources/suggest_indices/suggest/mappings-default.json`, `constants/SuggestConstants.java` |
| 二段マージ | `entity/SuggestItemMerger.java`, `entity/SuggestItemSerializer.java`, `index/writer/SuggestIndexWriter.java` |
| スコアリング | `request/suggest/SuggestQueryBuilder.java`, `entity/SuggestItemSerializer.java`, `request/popularwords/PopularWordsRequest.java`, `constants/FieldNames.java`, mappings |
| ファサード規模 | `Suggester.java`, `index/SuggestIndexer.java`（行数・公開メソッド数） |
| 行数規模/テスト | `src/main/java` / `src/test` の `wc -l`・パッケージ別テスト構成 |

---

## 2. 課題別の補足確認結果

### TBD-02 / ISS-03: `suggestDetail` 既定値 → **是正（解決）**

- **確認結果 [確認]**:
  - `SuggestRequest.suggestDetail` のフィールド初期値は `true`（`request/suggest/SuggestRequest.java:103` → `private boolean suggestDetail = true;`）。
  - `SuggestRequestBuilder` は `setSuggestDetail` を提供するのみで、ビルダ生成時に既定を上書きしない（`SuggestRequestBuilder.java:34-38` のコンストラクタは reading/normalizer のみ設定）。
  - `Suggester.suggest()` は `new SuggestRequestBuilder(client, readingConverter, normalizer).setIndex(...)` を返すだけで `suggestDetail` に触れない（`Suggester.java:159-160`）。
  - fess 側 `SuggestWordsHandler` も `setSuggestDetail` を呼ばない（`SuggestWordsHandler.java:76-104`）。よって **既定値 `true` のまま `items`（text/tags）が常に返る**。
- **ステップ1からの変化**: ステップ1 では「設定主体が未確定、暗黙依存の破綻リスク（中）」としていたが、**既定値 `true` の出所がコードで確定**した。Handler が `items` を前提にできる根拠は確定。**TBD-02 はクローズ可能**。
- **是正後の課題の本質 [確認]**: リスクは「未確定」ではなく「**暗黙のデフォルト依存**」。すなわち `SuggestRequest` のフィールド既定値という1箇所の変更が、明示呼び出しを持たない fess 側 Handler を**サイレントに破壊する**結合になっている。可読性（呼び出し側を読んでも detail 取得意図が見えない）・変更容易性（ライブラリ側既定変更の影響が API に波及）の課題として残る。
- **検討軸への含意**: 可読性 / 変更容易性。改善方向 [改善の種]: 呼び出し側で `setSuggestDetail(true)` を明示するか、`items` 取得専用の高レベル API を用意して既定値依存を断つ。

### ISS-04 / TBD-03: bad word の wildcard 削除 → **裏付け強化（重大度引き上げ妥当）**

- **確認結果 [確認]**:
  - `addBadWord(apply=true)` は `deletionOps.deleteByQuery(index, QueryBuilders.wildcardQuery(FieldNames.TEXT, "*" + normalized + "*"))`（`WordManagementOperations.java:77-84`）。
  - `text` フィールドは **`keyword` 型（非解析）**（`resources/suggest_indices/suggest/mappings-default.json:48-50`）。よって wildcard は**語全体の文字列に対する部分一致**として効く。
  - 多語フレーズの `text` は **半角スペース区切り**で1つの keyword 値に格納される（`SuggestConstants.TEXT_SEPARATOR = " "`、`SuggestConstants.java:37`。マージ時も `item1.getText().split(TEXT_SEPARATOR)` で語数を数える `SuggestItemMerger.java:70`）。
- **影響範囲の精緻化 [確認/推測]**:
  - keyword + `*badword*` のため、bad word が**他語の部分文字列**になっているだけで巻き込み削除される。例: `*ai*` は `email` / `rain` / `japan airlines`（フレーズ全体が1 keyword）等にマッチしうる [推測：実データ依存だが機構上不可避]。
  - 短い bad word ほど誤削除リスクが指数的に増す。先頭/末尾アンカーが無く `deleteByQuery` のため**復元不可（物理削除）**。
- **ステップ1からの変化**: ステップ1 は「広範囲に波及しうる（中）」と挙動レベルで指摘。本ステップで **(1) text=keyword 非解析、(2) 区切りが単一スペースで多語が1値、(3) 両端ワイルドカードでアンカー無し** という3点が機構として確定し、**誤削除が設計上不可避であること**を裏付けた。体感重大度は **中→中〜高** へ引き上げが妥当（品質に直接の負の影響＋不可逆）。
- **検討軸への含意**: サジェスト品質（主）/ 変更容易性。改善方向 [改善の種]: 完全一致削除（term）化、またはトークン単位マッチ、削除前ドライラン件数確認、論理削除フラグ化。
- **TBD-03 の扱い**: 「実データでの影響度」は本ステップでも未測定だが、**機構上の誤削除可能性は確定**したため、TBD-03 は「実データ定量評価が望ましいが、改善の必要性判断には機構確認で十分」と更新。

### ISS-05: 二段マージの整合性 → **裏付け強化＋新事実（潜在バグの疑い）**

- **確認結果 [確認] — 二段マージの所在**:
  - 第1段（同一バルク内）: `SuggestIndexWriter.write` が `mergeItems(items)` を呼び（`SuggestIndexWriter.java:49`）、同一 `_id` を `SuggestItemMerger.merge` で統合。
  - 第2段（既存ドキュメント）: 同 `write` 内で各 item につき `client.prepareGet()` で既存 source を取得し（`SuggestIndexWriter.java:55`）、`update && exists` の場合 `item.getUpdatedSource(existing)` = `SuggestItemSerializer.toUpdatedSource` でマージ（`SuggestItemSerializer.java:142-185`）。
  - **マージ規則が2クラスに分散**: 第1段は `SuggestItemMerger`（Java オブジェクト同士）、第2段は `SuggestItemSerializer.toUpdatedSource`（item と OpenSearch の Map）。両者で「集合和 / 加算 / 最新置換」のルールを**それぞれ独立に再実装**している。
- **規則の食い違い [確認]**:
  - readings: Merger は `item1.getText().split` の語数ぶんループし `mergeReadings`（`SuggestItemMerger.java:70-75`）。Serializer は `item.getReadings()` の要素数ぶんループし既存 List と concat（`SuggestItemSerializer.java:146-158`）。**走査の基準が異なる**（前者=テキスト語数、後者=新 item の reading 配列長）。
  - userBoost/timestamp: 両者とも「新しい方（item2 / 新 item）で置換」で一致（`SuggestItemMerger.java:87-88`, `SuggestItemSerializer.java:181,183`）。
  - score: Serializer は `(updatedQueryFreq + updatedDocFreq) * userBoost` を**書き込み時に毎回再計算**（`SuggestItemSerializer.java:182`）。Merger は score を扱わない（`SuggestItem` の score は別途）。
- **新事実（潜在バグの疑い）[確認/推測]**:
  - `SuggestItemMerger.mergeReadings` は **`item1` 側のテキスト語数だけ**を走査基準にする（`SuggestItemMerger.java:70-75`）。`item2` が `item1` より多くの reading スロットを持つケースでは、超過スロットの reading が**取り込まれない**可能性がある [推測：text 語数が両 item で同一である限り顕在化しないが、`_id` は text から決定的生成のため同一 text → 同一語数となり実害は出にくい。ただし不変条件への暗黙依存]。→ ステップ3 で「マージ規則の単一実装化」を検討する根拠。
- **ステップ1からの変化**: ステップ1 は「両方の確認が必要（複雑性の所在、中）」と指摘。本ステップで **マージ規則が2クラスに重複実装され、走査基準・スコア扱いが非対称** であることを `file:line` で具体化。複雑性が「読解コスト」だけでなく「**規則の二重メンテナンスによる不整合リスク**」を含むことを裏付けた。
- **検討軸への含意**: 変更容易性（主）/ 可読性 / サジェスト品質（集約の正確性）。

### ISS-13: ファサードの責務集中 → **実測で精緻化**

- **確認結果 [確認]（`wc -l`・公開メソッド数の実測）**:
  - `Suggester.java`: **507 行**、public メソッド **約18個**（ライフサイクル: `createIndexIfNothing` / `createNextIndex` / `switchIndex` / `removeDisableIndices`、検索系: `suggest` / `popularWords`、`indexer` 取得、エイリアス・getter 多数）。
  - `SuggestIndexer.java`: **547 行**、public メソッド **約28個**（`index` 各種・`delete` 各種・`addBadWord`/`deleteBadWord`・`addElevateWord`/`deleteElevateWord`/`restoreElevateWord`・`indexFromSearchWord`・`indexFromDocument`・Reader 系 等）。
  - `SuggestIndexer` は4 Operations（`IndexingOperations`/`DeletionOperations`/`WordManagementOperations`/`ContentIndexingOperations`）へ委譲する構造は維持されている（ステップ1 §3.1 の通り）。委譲先の規模: `ContentIndexingOperations.java` 470 行 / `DeletionOperations.java` 235 行 / `WordManagementOperations.java` 158 行。
- **ステップ1からの変化**: ステップ1 は「肥大化しやすい（中）」と定性指摘。本ステップで **両ファサードが各 500 行超・公開メソッド 18/28個** と実測。`SuggestIndexer` は委譲済みだが**公開 API 表面積が広い**（28メソッド）ことが変更容易性の主課題と精緻化。
- **検討軸への含意**: 可読性 / 変更容易性。改善方向 [改善の種]: 公開 API の用途別グルーピング（lifecycle / query / word-management）、用途別インタフェース分離。

### ISS-14 / スコアリング: 二重スコアリング → **是正（より強い事実：事前計算 score は検索で未使用＝デッドフィールド）**

- **確認結果 [確認] — 検索時スコア**:
  - 通常サジェスト `SuggestQueryBuilder.buildFunctionScoreQuery`（`SuggestQueryBuilder.java:141-167`）は **`DOC_FREQ`/`QUERY_FREQ`（ともに `LOG2P` modifier, missing 0.1f, weight 1.0）と `USER_BOOST`（missing 1f）を fieldValueFactor で都度評価**。前方一致は `weightFactorFunction(prefixMatchWeight)`。`boostMode=REPLACE`, `scoreMode=MULTIPLY`。**事前計算 `score` フィールドは参照していない。**
  - 人気語 `PopularWordsRequest.buildQuery`（`PopularWordsRequest.java:232-235`）も `QUERY_FREQ` の fieldValueFactor を使い、rescorer はランダム関数（`buildRescore`, `:242-246`）。**やはり `score` フィールド未使用。**
- **確認結果 [確認] — 事前計算 score の書き込みと未読**:
  - `score` は **書き込みのみ** 4箇所で生成: `SuggestItemSerializer.toSource:73`、`toUpdatedSource:182`、`toJson:217`、`SuggestItem.java:360`（empty source で 1.0F）。`SuggestUtil.java:214` でも算出。
  - mappings に `score: double` が定義（`mappings-default.json:36-38`）。
  - **`FieldNames.SCORE`（"score"）を read / sort / query で参照する箇所はライブラリ内に存在しない**（grep 確認: 参照は全て書き込み or 定数定義）。
- **ステップ1からの変化（是正）**: ステップ1 は「事前計算 score と検索時 function score の**二重スコアリング**でスコア源が二系統」と表現。本ステップの確認で、より正確には **「事前計算 score は検索・人気語のどちらでも一切読まれていない＝実質デッドフィールド（書き込みコストとインデックス容量のみ消費）」** であることが判明。**ランキングは検索時 function score 単系統で決まる**のが実態。ステップ1 の「二系統が併存しランキング挙動の理解が難しい」は**「二系統あるように見えるが片方は死んでいる」と是正**する。これは可読性課題としてむしろ明確（誤解を招く死蔵フィールド）。
- **検討軸への含意**: 可読性（主：死蔵フィールドの誤解）/ 性能（書き込み・容量の無駄）/ サジェスト品質（実ランキングは function score のみ）。改善方向 [改善の種]: (a) score フィールドを廃止し function score 単系統に統一、または (b) 逆に事前計算 score で sort してクエリ時計算を削減（性能 vs 鮮度のトレードオフ）。ステップ3-C/D で両論検討の好材料。

### ISS-10: Get-then-update → **裏付け強化**

- **確認結果 [確認]**: `SuggestIndexWriter.write` は `mergedItems` を**1件ずつループ**し、各件で `client.prepareGet().setIndex(index).setId(item.getId()).get(settings.getIndexTimeout())` を**同期実行**（`SuggestIndexWriter.java:54-55`）。その結果でバルクの index リクエストを組み立て、最後に1回 bulk 実行（`:69`）。
- **ステップ1からの変化**: 「各アイテムで Get が発生（中）」を `file:line` で確定。さらに **Get がバルク化されず1件ずつ同期 round-trip** である点を精緻化（`multiGet` ではない）。N アイテム登録で **N 回の Get + 1 回の bulk** となり、往復回数が登録件数に線形。性能ボトルネックの根拠強化。
- **検討軸への含意**: 性能（主）。改善方向 [改善の種]: `multiGet` で Get をまとめる、または OpenSearch の `update`/`upsert`・スクリプト集約でアプリ側 Get 自体を排除。

---

## 3. 横断観察

### 3.1 行数規模の実測（主要クラス・降順抜粋）

| クラス | 行数 | 備考 |
| --- | --- | --- |
| `settings/AnalyzerSettings.java` | 576 | 設定系最大 |
| `index/SuggestIndexer.java` | 547 | ファサード（public 約28） |
| `settings/SuggestSettings.java` | 541 | 設定中核 |
| `Suggester.java` | 507 | ファサード（public 約18） |
| `entity/SuggestItem.java` | 490 | ドメインモデル |
| `index/operations/ContentIndexingOperations.java` | 470 | 委譲先最大 |
| `settings/ArraySettings.java` | 404 | |
| `util/SuggestUtil.java` | 401 | ユーティリティ集積 |
| `request/suggest/SuggestRequest.java` | 392 | うち多数が `@Deprecated` 委譲メソッド（後述）|
| `index/contents/DefaultContentsParser.java` | 359 | テキスト処理 |
| `entity/SuggestItemSerializer.java` | 317 | マージ第2段 |
| `entity/SuggestItemMerger.java` | 152 | マージ第1段 |

- main: **64 ファイル / 11,591 行**。
- テキスト処理パイプライン（converter + normalizer + analysis）: **計約1,369 行**。最大は `KatakanaToAlphabetConverter.java`（299行）。Chain（`ReadingConverterChain` 108 / `NormalizerChain` 80）で Composite 構成。各 converter/normalizer は単機能で小規模＝**責務分割は比較的良好** [確認]。
- [改善の種]: `SuggestRequest.java`（392行）は §2 の通り `buildQuery`/`buildFunctionScoreQuery`/`createResponse`/`isHiraganaQuery` 等が **`SuggestQueryBuilder`/`SuggestResponseCreator` へ抽出済みで本体は `@Deprecated` 委譲シム**（`SuggestRequest.java:243-326`）。後方互換のための過渡コードが残存しており、可読性ノイズ。

### 3.2 テストカバレッジの所在マップ

- **規模**: test **77 ファイル / 15,194 行**（うち約24ファイルは `org.codelibs.opensearch.extension.*` のテスト用アナライザ実装で、純粋なユニット/結合テストはそれ以外）。main 64 ファイルに対しテスト本数は十分多い。
- **テストが手厚い領域 [確認]**:
  - 中核フロー: `SuggesterTest`(849) / `SuggestIndexerTest`(707) / `SuggestIndexerErrorHandlingTest`(502) / `SuggesterIndexLifecycleTest`(361) / `SuggesterRefactoringTest`(313)。
  - エンティティ/マージ: `SuggestItemTest`(422) / `SuggestItemBoundaryTest`(577) / `SuggestItemMergerTest` / `SuggestItemSerializerTest`。**二段マージ両クラスに専用テストあり** → リファクタリングのセーフティネットは存在 [確認]。
  - テキスト処理: converter 群 / normalizer 群 / `SuggestAnalyzerTest`(465) / `DefaultContentsParserTest`+EdgeCase(284+495)。
  - クエリ構築: `SuggestRequestQueryBuildingTest`(502) / `SuggestRequestTest` / `PopularWordsRequestTest`。
  - 設定: settings パッケージ各クラスに対応テストあり。
- **テストが相対的に薄い/要確認の領域 [確認/推測]**:
  - **fess 本体連携（`SuggestWordsHandler` / `SuggestHelper`）**: fess-suggest 側テストには当然含まれず、fess 側の API テスト有無は本ステップ未確認 → 連携部の I/O 検証は手薄な可能性 [推測]。
  - **bad word 誤削除（ISS-04）の影響範囲テスト**: `WordManagementOperations` の wildcard 削除が「意図しない語まで消さない」ことを検証するテストは見当たらない [推測：要確認]。
- **含意**: fess-suggest 単体は**ユニット/結合テストが充実しており、ライブラリ内のリファクタリングは比較的安全に行える**（変更容易性の根拠としてポジティブ）。一方、fess 連携境界とエッジケース（誤削除）はテスト補強の余地。

### 3.3 責務分割の所感（[確認]＋[推測]）

- 良好: テキスト処理（converter/normalizer/analysis の Strategy + Composite）、Operations への委譲構造、エンティティのマージ/シリアライズ抽出。
- 課題: (1) ファサード2クラスの公開 API 表面積（§ISS-13）、(2) マージ規則の2クラス重複実装（§ISS-05）、(3) `SuggestRequest` の Deprecated 委譲シム残存（§3.1）、(4) 事前計算 score の死蔵（§ISS-14）。いずれも**致命的破綻ではなく整理・統一系の負債**。

---

## 4. 課題インベントリへの更新差分サマリ

ステップ1（`0002-step1-issue-inventory.md`）に対し、以下の追記・是正・新規を提案する。本ステップでは ISS-03 / ISS-04 / ISS-05 / ISS-13 / ISS-14 に「ステップ2補足」を反映済み（後述の本体追記）。

| 対象 | 種別 | 内容 |
| --- | --- | --- |
| TBD-02 | クローズ | `suggestDetail` 既定 `true`（`SuggestRequest.java:103`）を確認。`items` 前提の根拠確定。 |
| ISS-03 | 是正 | 「未確定」→「**既定値依存の暗黙結合（確定）**」。リスクの性質を再定義。 |
| ISS-04 / TBD-03 | 強化 | text=keyword 非解析・単一スペース区切り・両端ワイルドカードで**誤削除が機構上不可避**を確定。重大度 中→中〜高。TBD-03 は「機構確認で必要性判断は十分」に更新。 |
| ISS-05 | 強化＋新事実 | マージ規則が `SuggestItemMerger` と `SuggestItemSerializer.toUpdatedSource` に**重複実装**・走査基準が非対称。`mergeReadings` の走査基準に潜在的取りこぼし疑い [推測]。 |
| ISS-13 | 強化 | `Suggester` 507行/public 18、`SuggestIndexer` 547行/public 28 と実測。公開 API 表面積が主課題と精緻化。 |
| ISS-14 | 是正 | 「二重スコアリング」→「**事前計算 score は検索で未使用のデッドフィールド**、ランキングは function score 単系統」。 |
| ISS-10 | 強化 | Get が **1件ずつ同期 round-trip**（multiGet でない）と確定。 |
| **ISS-16（新規）** | 新規 | **事前計算 `score` フィールドの死蔵**。書き込み4箇所＋mapping 定義があるが read/sort/query 参照ゼロ。容量・書き込みコストの無駄＋可読性の誤解。軸: 可読性/性能。重大度: 低〜中。 |
| **ISS-17（新規）** | 新規 | **`SuggestRequest` の `@Deprecated` 委譲シム残存**（`SuggestRequest.java:243-326`）。`SuggestQueryBuilder`/`SuggestResponseCreator` 抽出後の過渡コードが本体に残り可読性ノイズ。軸: 可読性/変更容易性。重大度: 低。 |

> ISS-16/17 はステップ1 の体系（ISS-xx）への追補。ステップ3 の改善案検討で扱う。

---

## 5. 残課題・本ステップでも未確定の事項

| ID | 内容 | 状態 |
| --- | --- | --- |
| TBD-01 | OpenSearch/Lucene の数値バージョン（`fess-parent:15.7.0` 外部依存） | 未解決（本ワークスペース外、本ステップ対象外） |
| TBD-03 | bad word 誤削除の**実データ定量影響** | 機構上の不可避性は確定。実データ件数測定は未実施（改善判断には機構確認で足りる） |
| TBD-04 | バッチ別 JVM 隔離・CPU 負荷調整の設計意図 | 未確認（コミット履歴/設計ドキュメント要、本ステップ対象外） |
| TBD-05 | 単一シャード前提が意図かデフォルトか | 未確認（`suggest.json` 固定値の根拠は依然 [推測]） |
| 新規 | `SuggestItemMerger.mergeReadings` の走査基準による reading 取りこぼし | [推測] 段階。`_id` が text 由来で同一 text→同一語数のため実害は出にくいが、不変条件依存。再現テストでの確証は未実施 |
| 新規 | fess 側連携（`SuggestWordsHandler`/`SuggestHelper`）の API テスト有無 | fess モジュール側テスト未確認 |

---

## 付録: 本ステップで確定した「事実」一覧（file:line）

- `SuggestRequest.java:103` … `suggestDetail` 既定 `true`。
- `SuggestRequestBuilder.java:34-38` / `Suggester.java:159-160` … 既定を上書きしない。
- `WordManagementOperations.java:77-84` … bad word を `wildcardQuery(TEXT,"*x*")` で削除。
- `mappings-default.json:48-50` … `text` は `keyword`。`:36-38` … `score` は `double`。
- `SuggestConstants.java:37` … `TEXT_SEPARATOR = " "`。
- `SuggestItemMerger.java:59-96`（特に `:70-75` readings 走査）… マージ第1段。
- `SuggestItemSerializer.java:142-185`（`:182` score 再計算）… マージ第2段。
- `SuggestIndexWriter.java:49`（mergeItems）/ `:54-55`（1件ずつ同期 Get）/ `:69`（bulk）… 二段マージ起点・Get-then-update。
- `SuggestQueryBuilder.java:141-167` … 検索 function score（DOC_FREQ/QUERY_FREQ=LOG2P, USER_BOOST, prefix weight）。`score` 未参照。
- `PopularWordsRequest.java:210-246` … 人気語 query（QUERY_FREQ factor）＋ random rescorer。`score` 未参照。
- `FieldNames.SCORE`（"score"）参照箇所 = 書き込み4箇所のみ（`SuggestItemSerializer.java:73,182,217`, `SuggestItem.java:360`, `SuggestUtil.java:214`）、read/sort/query 参照ゼロ。
- 規模: main 64ファイル/11,591行、test 77ファイル/15,194行。`Suggester` 507行/public18、`SuggestIndexer` 547行/public28。
