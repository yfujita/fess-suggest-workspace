# ステップ1: 既存分析の課題インベントリ化

## 1. 概要

本ドキュメントは、fess-suggest 抜本的改善提案タスク（`20260622_improvement_proposal`）の**ステップ1「既存分析ドキュメントの読み込みと課題インベントリ化」**の成果物である。

- **目的**: 改善案の事実ベースを固める。再調査は行わず、既存の分析ドキュメントを一次インプットとして「課題インベントリ」へ変換する。
- **スコープ外（本ステップでは扱わない）**: あるべき姿・解決策・改善案そのもの（これらはステップ3以降）。本ステップは「課題の事実整理」に集中する。
- **5つの検討軸**（要件定義 `0000-requirements-definition.md` より）: 可読性 / 変更容易性 / サジェスト品質 / 性能 / 新機能。

### 参照した分析ドキュメント（一次インプット）

| # | ファイル | 内容 |
| --- | --- | --- |
| 1 | `agent_docs/global/references/legacy/01-overview.md` | ライブラリ全体の概要・特徴 |
| 2 | `agent_docs/global/references/legacy/02-architecture.md` | アーキテクチャ・インデックス構造・登録/検索フロー・公開 API |
| 3 | `agent_docs/global/references/legacy/03-suggest-contents.md` | 種別・データソース・スコアリング・表示項目 |
| 4 | `agent_docs/global/references/legacy/04-fess-integration.md` | fess 本体からの利用方法・設定項目・駆動経路 |
| 5 | `agent_docs/global/references/legacy/05-issues.md` | 発見した課題・未確定事項 |
| 6 | `agent_docs/global/references/legacy/README.md` | インデックス・バージョン情報・参照ソース所在 |

> 凡例（出典分析ドキュメントから継承）: **[確認]** = ソースコードで直接確認できた事実 / **[推測]** = 実装から合理的に推測した内容。本ドキュメントでも、課題が「確認済み事実」に基づくか「推測・未確定」に基づくかを区別する。

---

## 2. 前提（バージョン・スコープ）

分析時点（出典: `legacy/README.md` §0.1）の前提を以下に明記する。改善案はこの前提に立脚する。

| 項目 | 値 | 確度 |
| --- | --- | --- |
| fess-suggest バージョン | `15.7.1-SNAPSHOT` | 確認済み（`modules/fess-suggest/pom.xml`） |
| fess 本体バージョン | `15.7.0-SNAPSHOT` | 確認済み（`modules/fess/pom.xml`） |
| 共通親 POM | `org.codelibs.fess:fess-parent:15.7.0` | 確認済み |
| 検索エンジン | **OpenSearch 系**（Elasticsearch ではない） | 確認済み（依存定義・import・CLAUDE.md） |
| Java | **21 以上**（record / パターンマッチ instanceof を使用） | 確認済み（`modules/fess-suggest/CLAUDE.md`） |
| ビルド | Maven | 確認済み |
| fess → fess-suggest 依存 | `fess-suggest:${suggest.version}` を依存宣言 | 確認済み（`modules/fess/pom.xml:1401-1404`） |

**前提に関する要確認事項（分析でも未解決）**:
- OpenSearch / Lucene の**具体的な数値バージョン**は `fess-parent:15.7.0`（本ワークスペース外）の `<properties>` に定義されており、本ワークスペース内では解決できない（出典: `legacy/README.md` §0.1 注意）。OpenSearch のバージョン依存 API（function score / rescorer 等）に関わる改善案を出す場合は、この数値バージョンの確認が前提となる。→ **要確認** フラグ。

---

## 3. 分析からの主要事実サマリ（改善に効く事実）

ステップ3以降の改善案の起点となる、確認済みの主要事実を観点別に整理する。

### 3.1 アーキテクチャ

- 主エントリポイントは `Suggester`（ファサード）。`Suggester.builder()....build(client, indexName)` で生成（出典: `legacy/01-overview.md`、`Suggester.java:374`）。
- 登録は `SuggestIndexer`（ファサード）が4つの内部オペレーションクラス（`IndexingOperations` / `DeletionOperations` / `WordManagementOperations` / `ContentIndexingOperations`）へ委譲（出典: `legacy/02-architecture.md`、`SuggestIndexer.java:203-210`）。
- 共通テキスト処理パイプライン: **Normalizer(Chain) → ReadingConverter(Chain) → SuggestAnalyzer**（出典: `legacy/02-architecture.md`）。ドキュメント側とクエリ/メタ側で別々の `ReadingConverter`（`readingConverter` / `contentsReadingConverter`、`Suggester.java:113-115`）。
- **二重エイリアスによるゼロダウンタイム再構築**: 物理インデックス `{base}.{timestamp}`、検索エイリアス `{base}`、更新エイリアス `{base}.update`（出典: `legacy/02-architecture.md`、`Suggester.java:455-465`）。
- **決定的 ID による頻度集約**: `_id` を `text` から決定的生成（`SuggestUtil.createSuggestTextId`、`SuggestItem.java:140`）。同一語を1ドキュメントへ集約し頻度を累積。
- 非同期基盤は独自の `Deferred`/`Promise`。**検索は常に非同期**、登録は Reader 系のみ非同期（出典: `legacy/01-overview.md`, `02-architecture.md`）。

### 3.2 データソース経路

- サジェスト語の供給は **4経路**: ①ドキュメント本文（DOCUMENT, docFreq=1）/ ②検索クエリログ（QUERY, queryFreq=1）/ ③検索語（QUERY, queryFreq=件数）/ ④elevate word（USER, userBoost=boost）（出典: `legacy/03-suggest-contents.md` 3.2）。
- すべて `SuggestItem` に正規化し同一インデックスへ書き込む。
- **fess 本体が標準で駆動するのは ①③④ の3経路のみ**。**② 検索クエリログ経路は fess 本体から未使用（デッドパス）**（出典: `legacy/04-fess-integration.md` 4.3、`legacy/05-issues.md` 5.1）。
- ③ 検索語は **バッチ（毎日12:00 全件再構築）＋ リアルタイム（検索ごと）** の二段供給（出典: `legacy/04-fess-integration.md` 4.3）。
- 同義語辞書は独立データソースではなく、OpenSearch アナライザ側の解析の一部（出典: `legacy/03-suggest-contents.md` 3.2）。

### 3.3 スコアリング

- **登録時マージ（Get-then-update）** `SuggestItemSerializer.toUpdatedSource`（`SuggestItemSerializer.java:142-185`）: reading/fields/tags/roles/languages/kinds は**集合和**、queryFreq/docFreq は**加算**、userBoost/@timestamp は**最新置換**、score は `(queryFreq+docFreq)*userBoost` を**再計算**（`:182`）（出典: `legacy/03-suggest-contents.md` 3.4）。
- 同一バルク内の同 `_id` も `SuggestItemMerger.merge`（`SuggestItemMerger.java:59-96`）で統合 → **二段マージ**（出典: `legacy/03-suggest-contents.md` 3.4、`legacy/05-issues.md` 5.5）。
- **検索時 function score**（`SuggestQueryBuilder.buildFunctionScoreQuery`）: 前方一致 `weightFactorFunction(prefixMatchWeight)`（既定2.0）、docFreq/queryFreq は `fieldValueFactorFunction(...).modifier(LOG2P)`（対数加点で飽和）、userBoost は乗算 `missing(1f)`。`boostMode=REPLACE`, `scoreMode=MULTIPLY`（出典: `legacy/03-suggest-contents.md` 3.4）。
- **userBoost 正規化**: コンストラクタで `userBoost <= 1` は強制的に 1 に丸め（`SuggestItem.java:131-135`）。よって document/query 経路（boost=-1）は実質 userBoost=1、USER 経路のみ boost>1 を保持（出典: `legacy/03-suggest-contents.md` 3.2）。
- **人気語（popularWords）**: `must(termQuery(KINDS,"query"))` 強制、`reading_1` 不在（単一語）かつ `queryFreq >= threshold`（既定10）のみ対象。ランダム化 rescorer でシャッフル（出典: `legacy/03-suggest-contents.md` 3.4、`PopularWordsRequest.java:212-214, 242-246`）。

### 3.4 連携（fess 本体）

- 呼び出しは原則 `SuggestHelper`（Lasta Di ヘルパ）に集約。アプリ起動時に `Suggester` を1つ生成・保持し、検索 API・人気語・リアルタイム検索ログ反映が同一 `Suggester` を共有（出典: `legacy/04-fess-integration.md` 4.1、`SuggestHelper.java:114-159`）。
- バッチ再構築（`SuggestCreator`）のみ**別 JVM プロセス**で動き、自前の `Suggester` を別途生成（出典: `legacy/04-fess-integration.md` 4.1, 4.6）。スケジュール "Suggest Indexer" は cron `0 12 * * *`（毎日12:00）。
- 検索 API は `GET /api/v2/suggest-words`（`SuggestWordsHandler.java:61-127`）。**Kind フィルタを動的構築**: 常に `addKind(USER)`、`isSuggestSearchLog()` true で `addKind(QUERY)`、`isSuggestDocuments()` true で `addKind(DOCUMENT)`（出典: `legacy/04-fess-integration.md` 4.5）。
- **UI に最終的に出るのは各語の `text` と `tags`（`types`）のみ**。読み・頻度・Kind は API レスポンスに含めない（出典: `legacy/04-fess-integration.md` 4.5）。
- **権限フィルタの二重担保**: ライブラリ側 `_guest_` 補完（`SuggestRequest.java:354-356`）＋ API 側 `RoleQueryHelper` の `addRole`（`SuggestWordsHandler.java:83`）（出典: `legacy/05-issues.md` 5.5）。

### 3.5 設定

- インデックス設定: `refresh_interval=10s`, `number_of_shards=1`, `number_of_replicas=0`, `auto_expand_replicas=0-1`（`suggest.json:1-8`）→ **単一シャード前提の小規模専用インデックス設計 [推測]**（出典: `legacy/02-architecture.md`）。
- 主要な静的設定（`fess_config.properties`）: `index.document.suggest.index=fess`, `suggest.field.index.contents=content,title`, `suggest.update.doc.per.request=2`, `suggest.update.contents.limit.num=10000`, `suggest.popular.word.query.freq=10` 等（出典: `legacy/04-fess-integration.md` 4.2）。
- ランタイム切替フラグ（管理画面から変更可、System Properties）: `isSuggestSearchLog()`（既定 true）/ `isSuggestDocuments()`（既定 true）/ `getPurgeSuggestSearchLogDay()`。両 false なら `SuggestCreator.create()` は再構築自体をスキップ（出典: `legacy/04-fess-integration.md` 4.2、`SuggestCreator.java:244-247`）。
- ドキュメント解析最大長: `fess.suggest.max.analyzed.content.length`（既定1000、`DefaultContentsParser.java:75`）（出典: `legacy/03-suggest-contents.md` 3.6）。

---

## 4. 課題インベントリ

各課題に **課題ID / 課題内容 / 根拠（出典）/ 影響する検討軸 / 体感重大度** を付与する。重大度は分析記述の確度・影響範囲から本ステップで暫定評価したもの（あくまで体感値であり、ステップ2以降で精緻化）。

### 4.1 課題一覧表

| 課題ID | 課題内容 | 根拠（出典） | 影響する検討軸 | 体感重大度 |
| --- | --- | --- | --- | --- |
| ISS-01 | **② 検索クエリログ経路が fess 本体で未使用のデッドパス**。ライブラリに `indexFromQueryLog(...)` のコードパスが残るが、fess 本体の標準フローからは到達しない（`SuggestHelper` もラップしない）。改修・削減の検討対象。 | `legacy/05-issues.md` 5.1（grep 確認済み）、`legacy/04-fess-integration.md` 4.3 | 変更容易性 / 可読性 | 中 |
| ISS-02 | **`suggest.popular.word.cache.expire` のコメントと実装の不一致**。`PopularWordHelper.java:77` で `TimeUnit.MINUTES`（既定60→60分）だが、`fess_config.properties` のコメントは「秒」。実装値（分）が正だが、ドキュメント/運用判断を誤らせる。 | `legacy/05-issues.md` 5.2、`legacy/04-fess-integration.md` 4.2 | 可読性 / 変更容易性 | 低 |
| ISS-03 | **`SuggestWordsHandler` の `suggestDetail` 設定主体が未確定**。Handler は `items`（text/tags）を参照するが、`setSuggestDetail(true)` の明示呼び出しが見当たらない。ライブラリ既定挙動に暗黙依存している可能性があり、リファクタリング時に破綻リスク。<br>**【ステップ2補足・是正】** `SuggestRequest.java:103` で `suggestDetail` 既定値 `true` を確認。Builder/`Suggester.suggest()`/Handler のいずれも上書きしないため `items` は常に返る（TBD-02 クローズ）。課題は「未確定」ではなく「**ライブラリ側フィールド既定値への暗黙結合**」と再定義（1箇所の既定変更が明示呼び出しを持たない Handler をサイレント破壊）。出典: `0003-step2-codebase-verification.md` §2。 | `legacy/05-issues.md` 5.3（確認/推測）、`SuggestWordsHandler.java:106-113`、`SuggestRequest.java:103` | 変更容易性 / 可読性 | 中 |
| ISS-04 | **bad word の wildcard 削除が広範囲に波及しうる**。`addBadWord(apply=true)` が `deleteByQuery(wildcardQuery(TEXT,"*badword*"))` で部分一致削除するため、意図せず広い範囲の語が削除されうる。影響評価は未実施。<br>**【ステップ2補足・強化】** `text` は `keyword` 非解析（`mappings-default.json:48-50`）、多語フレーズは単一スペース区切りで1値（`SuggestConstants.java:37`）、両端ワイルドカードでアンカー無し。よって短い bad word が他語の部分文字列であるだけで**誤削除が機構上不可避**（`deleteByQuery` のため不可逆）。重大度 **中→中〜高** が妥当。出典: `0003-step2-codebase-verification.md` §2。 | `legacy/05-issues.md` 5.4、`WordManagementOperations.java:77-84`、`mappings-default.json:48-50` | サジェスト品質 / 変更容易性 | 中〜高 |
| ISS-05 | **二段マージの整合性検証コスト**。同一バルク内マージ（`SuggestItemMerger`）と OpenSearch 既存 doc とのマージ（`toUpdatedSource`）の二段でマージが行われ、集約の正確性検証には両方の確認が必要。複雑性の所在。<br>**【ステップ2補足・強化＋新事実】** マージ規則が `SuggestItemMerger.merge`（`:59-96`、オブジェクト同士）と `SuggestItemSerializer.toUpdatedSource`（`:142-185`、item と OpenSearch Map）に**重複実装**され、readings の走査基準が非対称（前者=text 語数 `:70-75` / 後者=新 item の reading 配列長 `:146-158`）。`mergeReadings` が `item1` 語数基準のため item2 超過スロットの取りこぼし疑い [推測]。複雑性は「読解コスト」に加え「**規則の二重メンテナンスによる不整合リスク**」を含む。出典: `0003-step2-codebase-verification.md` §2。 | `legacy/05-issues.md` 5.5、`legacy/03-suggest-contents.md` 3.4、`SuggestItemMerger.java:59-96`、`SuggestItemSerializer.java:142-185` | 変更容易性 / 可読性 / サジェスト品質 | 中 |
| ISS-06 | **権限フィルタの二重担保による責務の重複**。検索時にライブラリ側 `_guest_` 補完と API 側 `RoleQueryHelper` の `addRole` で権限フィルタが二重に行われる。安全側だが、責務境界が曖昧で変更時に二箇所の同期が必要。 | `legacy/05-issues.md` 5.5、`SuggestRequest.java:354-356`、`SuggestWordsHandler.java:83` | 変更容易性 / 可読性 | 低 |
| ISS-07 | **単一シャード固定設計のスケーラビリティ上限 [推測]**。`number_of_shards=1`, `number_of_replicas=0` 固定で小規模専用インデックス前提。語彙規模・検索 QPS が増大した場合の水平スケール余地が設計上限定的。 | `legacy/02-architecture.md`（`suggest.json:1-8`、[推測]） | 性能 | 中 |
| ISS-08 | **document バッチの1リクエスト件数が極小（既定2件）**。`suggest.update.doc.per.request=2`。全件再構築のスループットに影響しうる設定値。CPU 負荷調整との兼ね合いだが要評価。 | `legacy/04-fess-integration.md` 4.2 | 性能 | 中 |
| ISS-09 | **登録パイプラインの同期/非同期境界が不均一**。単発系（`index`/`indexFromSearchWord` 等）は同期、Reader 系2メソッドのみ非同期。API の一貫性が低く、利用側が境界を理解しないと性能/挙動を誤りやすい。 | `legacy/02-architecture.md`（同期/非同期の境界）、`legacy/01-overview.md` | 変更容易性 / 性能 | 中 |
| ISS-10 | **書き込みが Get-then-update（既存 doc を都度 Get）依存**。決定的 ID で集約する代償として、各アイテムで既存ドキュメントの Get が発生する。大量登録時の OpenSearch 往復コストが性能ボトルネックになりうる。<br>**【ステップ2補足・強化】** `SuggestIndexWriter.java:54-55` で Get が **1件ずつ同期 round-trip**（`multiGet` でない）と確定。N 件登録で **N 回 Get + 1 回 bulk**、往復が件数に線形。出典: `0003-step2-codebase-verification.md` §2。 | `legacy/02-architecture.md`、`SuggestIndexWriter.java:54-55,69` | 性能 / サジェスト品質 | 中 |
| ISS-11 | **詳細レスポンスが UI でほぼ未活用**。`SuggestItem` には reading/kinds/freq/roles 等の豊富な属性があるが、API レスポンスは `text` と `tags` のみ。蓄積データを活かした新機能（種別バッジ・頻度可視化・読み活用 UI 等）の余地が未開拓。 | `legacy/04-fess-integration.md` 4.5、`legacy/03-suggest-contents.md` 3.5 | 新機能 / サジェスト品質 | 中 |
| ISS-12 | **人気語が「Kind=query・単一語・queryFreq>=10」に限定**。多語フレーズや document 由来の人気語が人気語結果に出ない。人気語の表現力・カバレッジ拡張の余地。 | `legacy/03-suggest-contents.md` 3.4、`PopularWordsRequest.java:212-214` | サジェスト品質 / 新機能 | 中 |
| ISS-13 | **ファサード `Suggester`/`SuggestIndexer` への責務集中**。両ファサードがライフサイクル・エイリアス管理・全 indexer 操作を集約。委譲構造はあるが、ファサードが肥大化しやすく変更影響が広がりやすい。<br>**【ステップ2補足・実測】** `Suggester.java` **507行/public 約18**、`SuggestIndexer.java` **547行/public 約28**。Operations への委譲は維持されるが**公開 API 表面積（特に Indexer の28メソッド）**が主課題。出典: `0003-step2-codebase-verification.md` §2,§3.1。 | `legacy/02-architecture.md`、`Suggester.java`、`index/SuggestIndexer.java` | 可読性 / 変更容易性 | 中 |
| ISS-14 | **score 事前計算と検索時 function score の二重スコアリング**。登録時に `score=(queryFreq+docFreq)*userBoost` を事前計算する一方、検索時は別途 function score（LOG2P 等）でスコアを再計算する。スコア源が二系統あり、ランキング挙動の理解・調整が難しい。<br>**【ステップ2補足・是正】** 検索 (`SuggestQueryBuilder.java:141-167`) も人気語 (`PopularWordsRequest.java:210-246`) も DOC_FREQ/QUERY_FREQ/USER_BOOST を都度評価し、**事前計算 `score` フィールドを一切参照していない**（grep で read/sort/query 参照ゼロ、書き込み4箇所のみ）。よって「二系統が併存」ではなく「**ランキングは function score 単系統、事前計算 score は死蔵**」が実態（→ ISS-16 へ分離）。出典: `0003-step2-codebase-verification.md` §2。 | `legacy/03-suggest-contents.md` 3.4、`SuggestQueryBuilder.java:141-167`、`PopularWordsRequest.java:210-246` | サジェスト品質 / 可読性 | 中 |
| ISS-15 | **userBoost<=1 の強制丸めによる boost 表現力の制約**。document/query 経路では userBoost が実質1に固定され、USER 経路以外で微調整したブーストを効かせられない。スコアリング調整の自由度が低い。 | `legacy/03-suggest-contents.md` 3.2（`SuggestItem.java:131-135`） | サジェスト品質 / 変更容易性 | 低 |
| ISS-16 | **【ステップ2新規】事前計算 `score` フィールドの死蔵**。`score` は書き込み4箇所（`SuggestItemSerializer.java:73,182,217`, `SuggestItem.java:360`, `SuggestUtil.java:214`）＋ mapping (`mappings-default.json:36-38`, double) に存在するが、検索/人気語/ソートのいずれからも参照されない。インデックス容量・書き込みコストの無駄＋「スコアに使われる」誤解を招く。 | `0003-step2-codebase-verification.md` §2、grep 確認 | 可読性 / 性能 | 低〜中 |
| ISS-17 | **【ステップ2新規】`SuggestRequest` の `@Deprecated` 委譲シム残存**。`buildQuery`/`buildFunctionScoreQuery`/`createResponse`/`isHiraganaQuery` 等が `SuggestQueryBuilder`/`SuggestResponseCreator` へ抽出済みだが、本体に後方互換用の `@Deprecated` 委譲メソッドが残り可読性ノイズ（392行のうち相当割合）。 | `SuggestRequest.java:243-326`、`0003-step2-codebase-verification.md` §3.1 | 可読性 / 変更容易性 | 低 |

### 4.2 重大度の内訳

- 高: 0 件
- 中: 11 件（ISS-01, 03, 04, 05, 07, 08, 09, 10, 11, 12, 13, 14 のうち中評価）
- 低: 3 件（ISS-02, ISS-06, ISS-15）

> 注: 体感重大度は本ステップでの暫定評価。ステップ2（深掘り）以降で、影響範囲・発生頻度・改修コストを加味して再評価する想定。現時点で「高」と断定できる課題はなく、全体としてアーキテクチャは健全で、改善は局所的・段階的に行える可能性が示唆される（あくまで現時点の所感であり、確定事項ではない）。

---

## 5. 未確定・要確認事項の一覧

分析で「未解決」「推測」とされた事項。改善案でも**前提確認が必要**な事項として「要確認」フラグで区別する。

| 要確認ID | 内容 | 出典 | 確認方法（参考） |
| --- | --- | --- | --- |
| TBD-01 | **OpenSearch / Lucene の具体的な数値バージョンが未解決**。`fess-parent:15.7.0`（ワークスペース外）の `<properties>` 依存。function score / rescorer 等のバージョン依存 API に関わる改善案では前提となる。 | `legacy/README.md` §0.1 注意 | `fess-parent` POM を参照 |
| TBD-02 | ~~**`SuggestWordsHandler` で `items` が常に返る根拠が未確定**~~ → **【ステップ2でクローズ】** `SuggestRequest.java:103` で `suggestDetail` 既定 `true` を確認。Builder/`Suggester.suggest()`/Handler のいずれも上書きしないため `items` は常に返る。ISS-03 は「暗黙のデフォルト依存」として残るが、本未確定事項は解消。 | `legacy/05-issues.md` 5.3、`SuggestRequest.java:103` | （完了）`SuggestRequest` フィールド既定値で確認済み |
| TBD-03 | **bad word wildcard 削除の実影響範囲が未評価**（ISS-04 と対応）。**【ステップ2更新】** 機構上の誤削除可能性（keyword 非解析＋両端ワイルドカード）は確定。残るのは実データでの定量影響のみで、改善必要性の判断には機構確認で十分。 | `legacy/05-issues.md` 5.4、`0003-step2-codebase-verification.md` §2 | 実データ/テストでの影響度の定量評価（必要性判断は確定済み） |
| TBD-04 | **バッチ別 JVM 隔離・CPU 負荷調整の設計意図が推測**。全件再構築を本体 Tomcat と別プロセスに隔離し `calibrateCpuLoad` で検索性能影響を抑える、という設計理由は [推測]。 | `legacy/04-fess-integration.md` 4.6（[推測]） | 設計意図の裏取り（コミット履歴/ドキュメント） |
| TBD-05 | **単一シャード前提が「設計上の意図」か「デフォルトのまま」かが未確定**（ISS-07 と対応）。`suggest.json` の固定値の根拠は [推測]。スケール改善提案の前提となる。 | `legacy/02-architecture.md`（[推測]） | 設計意図/運用実績の確認 |

---

## 6. 検討軸カバレッジ確認

5軸それぞれに最低1つ以上の課題が紐づいていることを確認する（MECE を意識し、各課題は主たる軸＋関連軸を持つ）。

| 検討軸 | 紐づく課題ID | 件数 |
| --- | --- | --- |
| **可読性** | ISS-01, ISS-02, ISS-03, ISS-05, ISS-06, ISS-13, ISS-14, ISS-16, ISS-17 | 9 |
| **変更容易性** | ISS-01, ISS-02, ISS-03, ISS-04, ISS-05, ISS-06, ISS-09, ISS-13, ISS-15, ISS-17 | 10 |
| **サジェスト品質** | ISS-04, ISS-05, ISS-10, ISS-11, ISS-12, ISS-14, ISS-15 | 7 |
| **性能** | ISS-07, ISS-08, ISS-09, ISS-10, ISS-16 | 5 |
| **新機能** | ISS-11, ISS-12 | 2 |

> **【ステップ2追記】** ISS-16（score 死蔵）・ISS-17（Deprecated 委譲シム）を追加。可読性・変更容易性・性能の件数が増加。詳細は `0003-step2-codebase-verification.md`。

→ **5軸すべてに最低1つ以上の課題が紐づいており、カバレッジ条件を満たす。**

補足観察:
- 「新機能」軸は課題数が最少（2件）。これは既存分析が現状の事実整理に主眼を置いており、新機能は既存課題の裏返し（蓄積データの未活用 ISS-11、人気語の限定 ISS-12）として現れているため。新機能の機会発掘はステップ2以降（あるべき姿の検討）でより広げる余地がある。
- 「変更容易性」「可読性」に課題が集中しており、リファクタリング/整理系の改善余地が相対的に大きいことが示唆される（現時点の所感）。

---

## 付録: 確認済み事実 vs 未確定事項の区別

- **本ドキュメントの「3. 主要事実サマリ」「4. 課題インベントリ」の根拠は、原則 [確認] ベース**（出典の `file_path:line` まで追跡可能）。
- **[推測] に基づく課題**: ISS-07（単一シャード設計意図）。→ 対応する未確定事項 TBD-05。
- **[確認/推測] 混在の課題**: ISS-03（事実=items 参照は確認、未確定=既定挙動への依存は推測）。→ 対応する未確定事項 TBD-02。
- 改善案（ステップ3以降）でこれら推測ベースの課題を扱う際は、必ず対応する TBD を前提確認として明示すること。
