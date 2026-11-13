# 作業履歴: 機能観点の問題点・改善点の洗い出し（事前作業）

- タスク: `20260922_document_for_improve`（要件: [0000-requirements-definition.md](./0000-requirements-definition.md)）
- 実施日: 2026-09-23
- 担当: tech-architect（メインセッションから委譲）
- 追記: 2026-09-23 に task-reviewer のレビューを受け、本書の数値・行番号の一部を訂正した。訂正の内訳は [0006-improve-point-review.md](./0006-improve-point-review.md) を参照。

## 目的

要件定義の事前作業 3 項目のうち最後の「機能観点の問題点、改善点を箇条書きでまとめる」を行う。[0001](./0001-current-implementation-overview.md) §9 所見 7 の 4 件と [refactoring_point.md](./task_docs/refactoring_point.md) §3 の [要判断] 18 件を出発点にしつつ、丸写しにせず実コードで裏を取り、観点を広げて洗い出した。

`refactoring_point.md` が「機能変更を行わないリファクタリング」の対象を扱い機能面を本書に切り出しているので、**本書は「外部から観測できる振る舞い・機能仕様」だけに集中**し、内部構造・可視性・重複コード・デッドコードは扱わなかった。要件の対応内容が「機能変更は行わないが、機能変更が容易になる構成を検討する」であることから、**各項目を「今回の構成で備えるべきか / 別タスクか / バグとして今回直す価値があるか」で分類すること**、および **§4「今回のリファクタリング設計への申し送り」で拡張点を具体的に示すこと**を最重視した。

## 実施内容

### 調査範囲

- fess-suggest main
  - 自分で読んだもの: `Suggester`（ライフサイクル・refresh・語数）、`SuggestIndexer`（コンストラクタのコスト）、`SuggestItem`（コンストラクタのクランプ・`isBadWord`）、`SuggestItemSerializer`（`toSource` / `toUpdatedSource` / `fromSource`）、`SuggestItemMerger`、`ElevateWord`、`SuggestIndexWriter`、`IndexingOperations`、`DeletionOperations`、`WordManagementOperations`、`ContentIndexingOperations`（`indexFromDocument` / `indexFromSearchWord`）、`DefaultContentsParser`、`ESSourceReader`、`PitOperationHelper`、`SuggestRequest`、`SuggestQueryBuilder`、`SuggestResponseCreator`、`PopularWordsRequest`、`AnalyzerConverter`、`KatakanaToAlphabetConverter`、`ReadingConverterChain`、`AnalyzerNormalizer`、`AnalyzerSettings`、`SuggestSettings`、`ArraySettings`、`BadWordSettings`、`ElevateWordSettings`、`Deferred`、`SuggestUtil`
  - `res:suggest_indices/` 配下の全 JSON（`suggest.json` / `suggest/mappings-default.json` / `suggest_settings.json` / `suggest_settings_array.json` / `analyzer/mapping-default.json` / `suggest_analyzer.json`）、`res:suggest_settings/default-badwords.txt`
- fess 側: `SuggestHelper`（全体）、`SuggestCreator`、`SuggestJob`、`SearchLogHelper`（検索ログ→サジェストの経路）、`SuggestWordsHandler`、`PopularWordHelper`、`RoleQueryHelper`、`PermissionHelper`、`FessProp`（`isValidSearchLogPermissions` / `getSearchGuestRoleList`）、`AdminSuggestAction` / `AdminBadwordAction` / `AdminElevatewordAction` と API 版、`AdminBackupAction`、`fess_config.properties` の `suggest.*` 全 22 キー、`fess_indices/fess.json`、`fess_indices/fess_config.bad_word/`、`fess_indices/fess_config.scheduled_job/scheduled_job.bulk`、`fess-res:suggest_indices/`（default / `_aws` / `_cloud`）
- フロントエンド: `fess-web:js/suggestor.js`（478 行を通読）、`search.js` の `SUGGESTOR_CONFIG`

### 機械的な検査

読解では確認しきれない「不在の証明」と大量の設定値の突き合わせは、スクリプトで行った。

| 検査 | 手段 | 結果 |
| --- | --- | --- |
| アナライザ定義 2 ファイルの差分 | 両 JSON を `json.dumps(indent=2, sort_keys=True)` で正規化して `diff` + Python で analyzer / filter / tokenizer 単位に比較 | **diff 出力 228 行 / 実際に相違する行 146 行。** analyzer 14 個・filter 24 個が相違。tokenizer は完全に別（`kuromoji_neologd_normal` vs `fess_japanese_normal`）。`title_contents_analyzer` は fess-suggest 側のみ |
| 言語別アナライザの構成 | 両モジュールの `suggest_analyzer.json` を Python でパースし 5 系統 × 48 をグルーピング | `reading_form` を持つのは無印と `_ja` の 2 つだけ。`reading_analyzer` と `reading_term_analyzer` は 48 系統中 46 系統が完全同一。`normalize_analyzer` は 48 個中 **42 個**が同一で、`_ca` / `_nl` / `_fr` / `_el` / `_it` / `_tr` の 6 個のみ elision / lowercase / stemmer を追加（`_tr` だけ `turkish_stemmer` を含む） |
| `mapping_char` の網羅範囲 | 142 エントリを Python で走査し特定文字の有無を確認 | 半濁音 `ﾊﾟ`/`ﾋﾟ`/`ﾎﾟ`、半角長音 `ｰ`、単独 `ﾞ`/`ﾟ` が**不在**。`Ｇ=>g`/`Ｊ=>j`/`Ｋ=>k` のみ小文字（他は大文字） |
| ローマ字変換表の網羅範囲 | `KatakanaToAlphabetConverter` の `map.put` を正規表現で抽出（135 エントリ） | `ー` が**不在**、`ン` は `["nn"]` のみ、`ッ` は `["tu","tsu"]`。2 文字キー 54、複数候補キー 22 |
| `suggest.*` 22 キーの到達先 | 各 getter を `modules/fess/src/main` で grep（`FessConfig` / `FessProp` を除外） | **死んだキーは 0 件。** `getSuggestSearchLogPermissions` だけ `FessProp` 内部で消費 |
| 機能の不在 | `fuzz` / `Levenshtein` / `spell` / `didYouMean` / `typo` / `completion` / `ngram` / `infix` / `edge_ngram` / `synonym` / `highlight` / `personaliz` / `decay` / `gauss` / `abtest` を両モジュールで grep | すべて 0 件（W 章に検索語と対象を明記） |
| チューニング setter の未使用 | `setPrefixMatchWeight` / `setMatchWordFirst` / `setSkipDuplicateWords` / `setSuggestDetail` を `modules/fess/src/main` で grep | 0 件（Y-05） |
| `FieldNames.SCORE` の参照 | 両モジュールで grep | 書き込み 4 箇所のみ、読み出し 0 件（Z-07） |
| `apply` 引数の実値 | fess の全 Action / API Action で `addBadWord` / `addElevateWord` / `storeAll*` / `deleteElevateWord` / `deleteBadWord` を grep | 操作経路は 19 箇所。うち **`apply` を取る 17 箇所すべてが `false`。`true` は `SuggestCreator` の 2 箇所だけ**。残る 2 箇所（`deleteBadWord`）は `apply` 引数自体が無い（X-04） |
| `escapeWildcardQuery` の参照 | 両モジュールで grep | main から 0 件（テストのみ）。bad word 削除は未エスケープ（X-05） |

### 使用したサブエージェント

観点を 4 系統に分け、`Explore` を並列で実行した。**各エージェントの報告は、結論を左右する主張をすべて自分で実コードに当たって検証してから採用した**（訂正したものは下記）。

| エージェント | 担当観点 | 成果物への反映先 |
| --- | --- | --- |
| Explore #1 | X: 現行仕様の欠陥・不整合（非対称な挙動、潜在的な不具合） | X 章（特に X-02〜X-05、X-15、X-19、X-21、X-26） |
| Explore #2 | Y: 設定・運用性（効かない設定、多言語、インデックス運用、監視、管理画面、性能） | Y 章（特に Y-06、Y-08、Y-09、Y-14、Y-17、Y-18）、X-27 |
| Explore #3 | Z: サジェスト品質（スコアリング、正規化、読み変換、マージ、リコール） | Z 章（特に Z-05、Z-06、Z-10、Z-12、Z-15） |
| Explore #4 | W: 未実装機能候補（一般的なサジェスト機能セットとの比較） | W 章全体 |

### 自分で検証して採用した主な指摘

サブエージェントの報告のうち、結論を左右するものは以下を実コードで再確認した。

- `entity/SuggestItemSerializer.java:181` が `userBoost` を無条件上書きすること、文書経路が `-1` を渡し（`DefaultContentsParser.java:107,144,202`）`SuggestItem.java:131-135` で 1 に丸められること、`fess:exec/SuggestCreator.java:255-296` の実行順が「elevate word → 文書 → 検索ログ」であることを確認。→ X-01
- `entity/ElevateWord.java:143-149` が readings に語そのものを含めないこと、`DefaultContentsParser.java:194` は逆に `l.add(word)` していること、`fess:helper/SuggestHelper.java:466-471` が読みと語を排他で使うことを確認。→ X-02 / X-03
- fess の全 Action / API Action のうち `apply` を取る 17 箇所すべてが `false` を渡すこと、`SuggestCreator.java:255,258` だけが `true` であることを確認。加えて `deleteBadWord`（2 箇所）は `apply` 引数を持たず、`WordManagementOperations.java:91-93` に index 反映の実装が無いことを確認。→ X-04
- `util/SuggestUtil.java:394` の `escapeWildcardQuery` が main から呼ばれておらず、`WordManagementOperations.java:81` が未エスケープであること、`fess:app/web/admin/badword/CreateForm.java:47-48` の `@Pattern("[^\\s]+")` が `*` を許容することを確認。→ X-05
- `fess:helper/SuggestHelper.java:294-297` の成功コールバックが `response.getErrors()` を見ていないこと、`ContentIndexingOperations.java:342,352-353` が errors を積んで resolve していることを確認。→ X-09
- `fess:helper/SuggestHelper.java:305-332` の 2 本の purge クエリが「document かつ query」の語をどちらも拾わないこと、`SuggestItemSerializer.java:183` が `@timestamp` を上書きすることを確認。→ X-10
- `Suggester.java:179` の `prepareRefresh()` に index 引数が無いこと、`fess:helper/SuggestHelper.java` の **12 箇所**（`:258, 295, 372, 387, 402, 423, 440, 451, 486, 511, 522, 532`。うち bad/elevate word 系が `:423, 440, 451, 486, 511, 522, 532` の 7 箇所）から呼ばれることを確認。→ X-11
- `concurrent/Deferred.java:211-213` の `getResponse()` が 1 分固定であること、`fess:exec/SuggestCreator.java:276` の `latch.await()` にタイムアウトが無いことを確認。→ X-13 / X-14
- `DeletionOperations.java:162-195` の第 2 段クエリに kinds 条件が無く elevate word を巻き込むこと、`:194` と `:212` が常に errors=null を返すことを確認。→ X-15
- `Suggester.java:213-219`（`createIndexIfNothing` は alias を作成リクエストに含む）と `:247-267`（`createNextIndex` は別リクエスト）の非対称を確認。→ X-19
- `fess:helper/PermissionHelper.java:86-111` と `fess:mylasta/direction/FessProp.java:1445-1456` から、fess の権限値が `_guest_` と一致しないことを確認。`fess:helper/RoleQueryHelper.java:181-195,228-233` がログイン時にゲストロールを足さないことも確認。→ X-18 / Y-03
- `fess:mylasta/direction/FessProp.java:1425-1438` の `allMatch` と `fess:helper/SearchLogHelper.java:181,213` の roles の出所を確認。→ Y-03
- `fess-res:fess_indices/fess.json` の `japanese_tokenizer` に `user_dictionary` があり、`fess-res:suggest_indices/suggest_analyzer.json` の `fess_japanese_normal` に無いことを直接比較。`_aws` / `_cloud` が `keywords_path` をインラインのサンプル語に置換していることも確認。→ Y-08
- `ESSourceReader.java:134-138`（コンストラクタで `getTotal()`）と `fess:helper/SuggestHelper.java:272-290`（`setQuery` は生成後）の順序を確認。→ Y-02
- `fess:helper/PopularWordHelper.java:151-160` のキャッシュキーが区切り無し連結であること、`:77` が `TimeUnit.MINUTES` で `fess-res:fess_config.properties:1518` のコメントが `(seconds)` であることを確認。→ X-28
- `fess:helper/SuggestHelper.java:120-124` が同じ設定値を `split(",")` と可変長引数版 `stream()` の 2 通りで解釈していることを確認。→ X-27
- `settings/ArraySettings.java:214-238` のコンパレータが `@timestamp` を取り出しておきながら `o1.toString()` を比較していることを確認。→ X-26
- `fess-web:js/suggestor.js:196-208`（`label` を送らない）、`:463-474`（`!suggestingSts` で入力を捨てる）、`:287`（`.text()` 固定でハイライト無し）を確認。→ X-30 / W-06
- `fess:job/SuggestJob.java:112-134` のクラスパス順（`WEB-INF/classes` が jar より前）を確認し、X-24 で「fess 側が勝つ」と [推測] する根拠にした。

### 検証で訂正した点

- Explore #1 は「`restoreElevateWord` が設定 index に重複エントリを作る」と報告したが、`settings/ElevateWordSettings.java:154-155` が `createId(key, elevateWord.getElevateWord())` で**正規化語から `_id` を作る**ため同一 id を上書きし、重複は増えない。成果物では X-25 として「`@timestamp` の書き換えと語数 × (update + refresh) の I/O」に限定し、優先度を P3 に下げた。
- Explore #1 は「`normalize_analyzer` が複数語を先頭語に切り詰める」可能性を挙げたが、`keyword` tokenizer なので全文が 1 トークンになり切り詰めは起きない。同エージェント自身が否定していたが、念のため `res:suggest_indices/suggest_analyzer.json` の定義を読んで確認し、採用しなかった。
- Explore #1 は `maxContentLenth`（50000）超過による「文書のデータ欠落」を挙げたが、文書経路は `DefaultContentsParser.java:261-278` で 1000 文字ずつに分割されるため 50000 には当たらない。成果物（Z-16）では「実質は 50000 文字超の検索語だけが対象」と範囲を狭めて記載した。
- Explore #2 は「アナライザ設定に起因して読み変換が効かない言語がある」ことを指摘した一方、Explore #3 は「表記ゆれ正規化が効いていない」という 0001 §9 由来の理解を**半分は誤り**として訂正した。両方を自分で `mapping_char` の 142 エントリと 241 個の analyzer 定義に当たって検証し、Z-08 では「吸収されているもの（大文字小文字・全角英数・半角カナ濁音）」と「誰も担当していないもの（半濁音・半角長音・かな/カナ・異体字・記号・trim）」を分けて記載した。
- Explore #4 は「fess の同義語辞書がサジェストに効かない」と報告したが、根拠が grep 結果だけだったので `fess-res:fess_indices/fess.json`（`synonym_graph` あり）と両モジュールの `suggest_analyzer.json`（0 件）を直接比較して確認した上で W-03 に採用した。
- 語数カウントについて、当初「`track_total_hits` の 10,000 上限で打ち止めになる」ことを疑ったが、`Suggester.java:449` が `setTrackTotalHits(true)` を明示しているため**正確**である。誤った指摘を書かないよう X-29 に「打ち切りは起きない」と明記した。
- `removeDisableIndices` の前方一致について、fess の index 名（`fess.search` / `fess.update` / `fess_crawler` / `fess_suggest*`）を確認した結果、**fess 既定では衝突しない**ことが分かった。0001 §9-7 の指摘をそのまま危険視せず、X-20 では「クラスタ共有時と X-19 の窓でリスク」と条件を限定した。

### 0001 §9 および `refactoring_point.md` との関係

- 0001 §9-7 の挙動非対称 4 件はすべて本書に引き継ぎ、X-18（roles）/ X-20（前方一致）/ X-25（二重保存、訂正あり）/ X-05〜X-07（bad word）に展開した。
- 0001 §9-2（N+1 書き込み）は `refactoring_point.md` が性能・機能の論点として本書に委ねていたので、**X-12（楽観ロック無しによるロストアップデート）として機能面の欠陥に格上げ**した。
- `refactoring_point.md` §3 の [要判断] 18 件は本書 §3 に対応表を置き、機能観点からの結論（実施すべき / 削除してよい / 格上げ）を明示した。特に F 章（例外とエラー伝搬）は X-09 / X-14 / X-15 / Y-16 の共通の根であることを示し、申し送り §4-7 に格上げした。
- `refactoring_point.md` B-04（`SuggestAnalyzer` の脱 OpenSearch 化）と A-07（クエリ構築のトランポリン解体）が、本書の Z 章 16 件と W 章の主要項目のほぼ全部の前提であることを §4-1 / §4-3 として明示した。

### 新たに追加した主な観点（0001 §9 に無かったもの）

- 優先表示語（elevate word）の 4 段階の機能欠落（X-01〜X-04）。**機能面で最も影響の大きい塊。**
- 失敗が外に出ない経路の連鎖（X-08 → X-09 → X-15 → Y-16）。「壊れた状態が黙って本番になる」構図。
- ローマ字変換表の具体的な欠落（Z-01）。入力例ごとの一致可否を表にした。
- アナライザ定義の二重管理（X-24）。**統合境界の設計問題として `refactoring_point.md` J-09 と同根であることを示した。**
- 既定値の病理（Y-01 / Y-02）。`scroll.size=1` と `doc.per.request=2` の組み合わせ。
- 認証環境での機能停止（Y-03）。`suggest.search.log.permissions` の `allMatch` 判定。
- 未実装機能 14 件（W 章）。すべて grep の 0 件確認つき、部分的にあるものは到達点を明記。

## 成果物

- [task_docs/improve_point.md](./task_docs/improve_point.md)（744 行。作成時 729 行 + [0006](./0006-improve-point-review.md) のレビュー反映分）
  - 凡例、評価軸（優先度 P1〜P3 / 分類 [欠陥]・[制約]・[品質]・[新機能] / 今回との関係 [即修正候補]・[構成で備える]・[別タスク] / API 影響 [境界内]・[境界外]）
  - 全 78 項目の一覧表（X / Y / Z / W の 4 章）と、根拠 `file:line` つきの詳細
  - `refactoring_point.md` [要判断] 18 件との対応表（§3）
  - **今回のリファクタリング設計への申し送り 10 項目と着手順（§4）**
  - 未解決の問い 9 件（§5）
  - 内訳: P1 22 件 / P2 38 件 / P3 18 件、[欠陥] 30 / [制約] 18 / [品質] 16 / [新機能] 14、[即修正候補] 19 / [構成で備える] 42 / [別タスク] 17、[境界内] 28
- 本ファイル（作業履歴）

要件は「数百行規模に収める」と戒めているが、項目数が 78 に達したため 729 行になった（`refactoring_point.md` は 75 項目 / 667 行なので同程度の密度）。分量は [0006](./0006-improve-point-review.md) のレビューで許容範囲と判定され、圧縮は行っていない。1 項目あたり平均 6 行で、大半が `file:line` の根拠行である。**一覧表と §4 だけ読めば判断できる構成**にして冗長な散文を避けた。分量が過大であれば、P3 の 18 項目を一覧表のみに圧縮することで約 100 行削減できる。

## 検証の前提

- fess-suggest: HEAD `f7a8039a65c86dbdd68acc32bf96ccabc2b65d26`（#100、version 15.9.0-SNAPSHOT）
- fess: HEAD `8a9e1e15c6276dcd470b2de47835f2e7296b58ef`（version 15.9.0-SNAPSHOT）
- **テスト・ビルドは一切実行していない**（`mvn test` / `mvn compile` とも未実行）。記述はすべて静的なコード読解と、`grep` および Python による設定ファイル・変換表の機械的な走査に基づく。
  - したがって「この入力では一致しない」といった挙動の記述は、クエリ構造とインデックス内容の突き合わせによる導出であり、実機で確認したものではない。Z-01 の一致可否表のうち `ン` 系は `test:converter/KatakanaToAlphabetConverterTest.java:34` のテスト期待値で裏が取れているが、長音・促音系はコード読解のみ。
  - 並行実行が前提の項目（X-12 のロストアップデート、X-19 の alias 二重化、X-14 の永久ハング）は、コード上の競合窓・経路は確認済みだが、発生は未再現。本文では [推測] と明記した。
  - 「無い」と判定した機能（W 章）は**静的参照が 0 件であること**の確認であり、検索語と対象を本文に明記した。
- ソースコードは変更しておらず、git commit もしていない。
- **archive 配下（`agent_docs/tasks/archive/`）の過去の改善提案ドキュメントは参照していない**（ユーザーの明示的な指示によりゼロベースで洗い出した）。`agent_docs/global/references/legacy/` も根拠に使っていない。

## 後続タスクへの申し送り

1. **設計書には §4 の 10 項目を「拡張点の仕様」として取り込む。** 特に **§4-3（クエリ構築とスコアリングの戦略化）が最も効果が大きい**（Z 章 16 件と W 章の主要項目がここに乗る）。その前提として `refactoring_point.md` **B-04**（`SuggestAnalyzer` の脱 OpenSearch 化）と **A-07**（`SuggestRequest` のトランポリン解体）を先に済ませる必要がある。この依存関係を設計書に明示すること。
2. **§4-7（失敗の伝搬の統一）を最初に置く。** `refactoring_point.md` のフェーズ 0（I/O 契約テスト）と同じ論理で、「壊れたことに気付けない」現状（X-08 / X-09 / X-15 / Y-16）を先に直さないと以降の変更を安全に検証できない。`test-io-verifier` に依頼する I/O 契約テストには、**errors が呼び出し側に届くこと**を検証項目として加えること。
3. **ユーザー判断が必要な項目**（§5 の未解決の問い 9 件）。特に次の 3 つは着手前に方針を決める必要がある。
   - X-04（`apply=false` 固定）を仕様と見るか不具合と見るか。即時反映にするなら X-05（ワイルドカード未エスケープ）を先に直す必要がある
   - Y-03（認証ユーザーの検索を学習しない）の既定を変えるか
   - X-24（アナライザ定義の所有権）。`refactoring_point.md` §5 の問い 1（fess 以外の利用者の有無）と同じ前提に依存する
4. **[即修正候補] 19 件のうち、今回のリファクタリングと同時に直す価値が高いのは次の 6 件**（いずれも局所的で、振る舞いの変化が説明しやすい）。
   - X-11（`prepareRefresh(index)` にする）、X-05（ワイルドカードのエスケープ）、Y-08（`user_dictionary` の 1 行追加）、X-28（`cache.expire` のコメント修正）、X-09（`getErrors()` を見る）、X-13（`getResponse` にタイムアウトを渡す）
5. **本書の項目 ID（X-01 〜 W-14）は設計書・作業プランから参照できるよう安定させる。** 追加が出た場合は各章の末尾に採番し、既存 ID は振り直さない。`refactoring_point.md` の ID（A-01 〜 K-01）とは名前空間が分かれている。
6. **fess 本体側の修正を要する項目**: X-04（apply）、X-08（switchIndex の条件）、X-09（errors の伝搬）、X-27（`suggest.field.contents` の解釈）、X-30（UI）、Y-03（設定）、Y-05 / Y-06（設定の注入口）、Y-08（`suggest_analyzer.json`）、Y-14 / Y-15（管理画面）。**本タスクのスコープに fess 側を含めるかを先に確認すること**（`refactoring_point.md` の H-01 と同じ問い）。
7. **実機確認が望ましい項目**: Z-01 の一致可否（長音・促音・撥音のローマ字入力）、Y-01 / Y-02 の再構築時間、X-24 のクラスパス順。`fessdemo` スキルで実機を触れるので、設計方針を固める前に 1 度確認すると精度が上がる。
