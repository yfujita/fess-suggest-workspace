# fess-suggest リファクタリング観点の問題点・改善点

- タスク: `20260922_document_for_improve`（要件: [0000-requirements-definition.md](../0000-requirements-definition.md)）
- 作成日: 2026-09-23 / 対象: fess-suggest `15.9.0-SNAPSHOT`（HEAD `f7a8039`）、fess `15.9.0-SNAPSHOT`（HEAD `8a9e1e15c`）
- 前提資料: [0001-current-implementation-overview.md](../0001-current-implementation-overview.md)（特に §7.2 公開 API、§9 所見）
- 目的: 「機能変更を行わないリファクタリング」の対象を、根拠つきで列挙する。機能面の改善提案は別ドキュメント（`improve_point.md` 相当）の担当なので、本書では**機能変更に当たりうる項目の識別までにとどめる**。

## 凡例と表記

- **[確認]** ソースで直接確かめた事実 / **[推測]** 実装から推し量った内容 / **[提案]** 改善案
- 根拠パスの短縮表記（0001 に準拠、`test:` のみ追加）
  - 無印: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下（例 `Suggester.java:185`）
  - `test:`: `modules/fess-suggest/src/test/java/org/codelibs/fess/suggest/` 配下
  - `fess:`: `modules/fess/src/main/java/org/codelibs/fess/` 配下
- 各項目に付けるラベル

| 軸 | 値 | 意味 |
| --- | --- | --- |
| 優先度 | **P1** / **P2** / **P3** | P1=今回のリファクタリングで着手すべき / P2=着手が望ましい / P3=余力があれば |
| 機能変更 | **[不変]** / **[要判断]** | [不変]=外部から観測できる振る舞いが変わらない / [要判断]=挙動が変わりうるのでユーザー判断が必要 |
| API 影響 | **[境界外]** / **[境界内]** | 0001 §7.2 の「fess が依存する公開 API」を壊さないか / 触れる（fess 側の追従または互換維持が必要） |

---

## 0. サマリー

- 本書で挙げた項目は **75 件**。うち P1 が 27 件、P2 が 35 件、P3 が 13 件。[要判断]（機能変更の可能性あり）が 18 件、[境界内]（0001 §7.2 に触れる）が 13 件。
- 最も反復して現れた構造的問題は次の 4 つ。
  1. **「共通化のために作られたユーティリティが呼び出し側に適用されていない」**（`SettingsResourceLoader`、`MapValueExtractor`、`SuggestItem.concatValues` など）。重複は減らず、むしろコード量とテストだけが増えている。→ D 章・E 章
  2. **可視性がすべて `public`、フィールドがほぼ `protected` 可変**で、意図された API 境界が存在しない。main 65 ファイルが**すべて public クラス**、非 final の `protected` フィールドが 51 個。→ B 章
  3. **同じ意味の処理に 2 通り以上の書き方が併存**（例外の投げ方、エラーの返し方、ログの出し方、ビルダーの命名、リソース読み込み）。→ F/G/I 章
  4. **プロセスグローバルな可変 static とライフサイクル未定義**（`AnalyzerSettings` の static キャッシュ、`Suggester.shutdown()` の非対称）。fess 側でスレッドプールが実際にリークする経路を確認した。→ H 章
- テスト側にも同じ構図がある。`@Test` 660 件という数字に対し、**39 メソッドは自作 stub 自身を検証しており**、アサーションが 1 つも無いテストが 16 件、常に成功する空テストが 2 件ある。リファクタリングの安全網としては見かけほど機能しない。→ J 章
- 着手順は **安全網（J-05 / J-07 / K-01）→ E 章（除去）→ D 章（集約）→ B 章（可視性）→ A 章（責務分割）** を推奨する（§4）。

---

## 1. 項目一覧

| ID | 概要 | 優先度 | 機能変更 | API 影響 |
| --- | --- | --- | --- | --- |
| **A. 責務・構造** ||||
| A-01 | `util` パッケージがファクトリ兼ドメイン依存の神パッケージ化。パッケージ循環が 5 組 | P1 | [不変] | [境界外] |
| A-02 | `Suggester` にライフサイクル・検索・件数・部品保持が同居 | P2 | [不変] | [境界内] |
| A-03 | `SuggestIndexer` が 14 個の可変フィールドを持つ委譲専用ファサード | P2 | [不変] | [境界内] |
| A-04 | `ContentIndexingOperations` に旧シグネチャのオーバーロードが 5 本残存 | P1 | [不変] | [境界外] |
| A-05 | `DefaultContentsAnalyzer` が `AnalyzerSettings` の非 static 内部クラス（層の逆転） | P2 | [不変] | [境界外] |
| A-06 | `mergeItems` の実装がインターフェースの `default` メソッドに置かれている | P3 | [不変] | [境界外] |
| A-07 | `SuggestRequest` の `@Deprecated` メソッドが実処理経路から呼ばれており削除できない | P2 | [不変] | [境界外] |
| **B. 公開 API 境界と可視性** ||||
| B-01 | main 65 クラスすべてが `public`、package-private がゼロ | P1 | [不変] | [境界内] |
| B-02 | 非 final の `protected` フィールドが 51 個。継承前提の設計だが fess は一切継承していない | P1 | [不変] | [境界内] |
| B-03 | OpenSearch 型が API 表面とドメイン層に露出（34/65 ファイル） | P3 | [不変] | [境界内] |
| B-04 | `analysis.SuggestAnalyzer`（ポート）が OpenSearch の `AnalyzeToken` を返す | P2 | [不変] | [境界外] |
| B-05 | 使われないのに public な内部 API（`AnalyzerSettings` 系ほか） | P2 | [不変] | [境界外] |
| **C. 不変性・null 安全性** ||||
| C-01 | `SuggestItem` が 12 個の setter を持つ可変 POJO。`equals`/`hashCode` 未実装 | P2 | [不変] | [境界内] |
| C-02 | `SuggestItem.emptySource` が書き込み経路で一切使われない死んだ状態 | P1 | [不変] | [境界外] |
| C-03 | `Objects.requireNonNull` が `Suggester` にしか無い（規約違反） | P2 | [不変] | [境界外] |
| C-04 | `analyzeAndReading` が `null` を返す契約が Javadoc に無い | P2 | [不変] | [境界外] |
| C-05 | `SuggestItemSerializer.fromSource` が全フィールド無検査 | P2 | [要判断] | [境界外] |
| C-06 | `Kind` の文字列→enum 変換が if-else の羅列で、未知値が `null` 要素になる | P2 | [要判断] | [境界外] |
| C-07 | `ElevateWord` が受け取った `List` を防御的コピーせず保持 | P3 | [不変] | [境界外] |
| C-08 | `tagFieldNames` が空設定時に `[""]` になる | P3 | [要判断] | [境界外] |
| **D. 重複コードと定数** ||||
| D-01 | `fess.dictionary.path` 置換が 3 重複 + 未使用の 4 実装目 | P1 | [不変] | [境界外] |
| D-02 | classpath リソース読み込みが 6 重複、null チェック・文字コード・ClassLoader が不統一 | P1 | [不変] | [境界外] |
| D-03 | index 作成 + yellow 待ちが 4 系統。`Suggester` だけ競合対策が無い | P2 | [要判断] | [境界外] |
| D-04 | 文字列配列の和集合マージが 4 実装併存 | P2 | [不変] | [境界外] |
| D-05 | `ArraySettings` 内で `actualIndex` 算出が 5 重複 | P3 | [不変] | [境界外] |
| D-06 | ページサイズ `500` が 4 クラスで別定数、リトライ回数 `5` が 3 箇所で直書き | P2 | [不変] | [境界外] |
| D-07 | index 名サフィックス 9 種がすべてリテラル直書き。`toLowerCase` の Locale が不統一 | P2 | [要判断] | [境界外] |
| D-08 | スコア計算式 `(queryFreq+docFreq)*userBoost` が 4 箇所に直書き | P2 | [不変] | [境界外] |
| D-09 | `AnalyzerSettings.checkAnalyzer` が同型 catch を 5 回コピペ | P3 | [不変] | [境界外] |
| D-10 | `_doc` が未使用定数 2 個に重複定義。`EMPTY_STRING` と `StringUtil.EMPTY` が混在 | P3 | [不変] | [境界外] |
| **E. デッドコード・未使用 API** ||||
| E-01 | `MapValueExtractor`（275 行・15 メソッド）が main から未使用 | P1 | [不変] | [境界外] |
| E-02 | `SettingsResourceLoader` が main から未使用 | P1 | [不変] | [境界外] |
| E-03 | `SuggestUtil.createBulkLine` が `_type` 前提の旧形式かつ `FieldNames` を使わない重複実装 | P1 | [不変] | [境界外] |
| E-04 | `SuggestItem.convertJsonString(s)` が完全な dead private code | P1 | [不変] | [境界外] |
| E-05 | `SuggestSettings.badWordIndexName` / `elevateWordIndexName` が代入のみの dead field | P1 | [不変] | [境界外] |
| E-06 | `SuggestBulkFileWriter` が全メソッド `UnsupportedOperationException` | P1 | [不変] | [境界外] |
| E-07 | `PitOperationHelper.getTotalHitCount` / `AnalyzerSettings` の 3 メソッドが未使用 | P2 | [不変] | [境界外] |
| E-08 | `FieldNames.ID` / `SuggestConstants.DEFAULT_TYPE` が未参照 | P2 | [不変] | [境界外] |
| E-09 | 未使用 import 4 件 / コメントアウトされた構成コード | P2 | [不変] | [境界外] |
| E-10 | クエリログ経路一式が fess から未使用 | P2 | [要判断] | [境界外] |
| E-11 | `createDefaultContentsReadingConverter` の引数 2 個が未使用 | P3 | [不変] | [境界外] |
| **F. 例外とエラー伝搬** ||||
| F-01 | `SuggestSettingsException` が `SuggesterException` を継承せずルート例外が 2 本 | P1 | [要判断] | [境界内] |
| F-02 | cause を捨てる catch が 2 箇所、メッセージも同一 | P1 | [不変] | [境界外] |
| F-03 | `Deferred` が 2 箇所でコールバック例外を完全に握りつぶす | P1 | [要判断] | [境界外] |
| F-04 | エラーリストの先頭 1 件だけ例外化し残りを破棄 | P2 | [要判断] | [境界外] |
| F-05 | `deleteOldWords` が `deleteByQuery` の結果を捨てて常に errors=null を返す | P1 | [要判断] | [境界外] |
| F-06 | 同一 writer 内で write は throw、delete は errors 蓄積 | P2 | [要判断] | [境界外] |
| F-07 | reject のラップが Request 実装間で不統一 | P2 | [要判断] | [境界内] |
| F-08 | 例外型の選択ルールが未確立（同一ファイル内で 2 型混在） | P2 | [不変] | [境界外] |
| F-09 | `InterruptedException` で割り込みフラグを復元していない | P2 | [要判断] | [境界外] |
| **G. ログ** ||||
| G-01 | ログのガードとレベルが不一致（debug ガード内で `warn`、info ガード外で重い処理） | P1 | [不変] | [境界外] |
| G-02 | `logger.error` の使用が 0 件で warn/error の使い分けルールが無い | P3 | [不変] | [境界外] |
| G-03 | `SuggestIndexer` の logger が未使用のまま残存、修飾子順も逸脱 | P3 | [不変] | [境界外] |
| G-04 | 「catch → debug ログ → throw」パターンが 5 箇所だけに適用 | P2 | [不変] | [境界外] |
| **H. リソース管理・並行性** ||||
| H-01 | fess 側で `Suggester` 再生成時にスレッドプールがリークする | P1 | [要判断] | [境界内] |
| H-02 | `Suggester` が `AutoCloseable` 非実装、`shutdownNow()` のみ、注入プールも停止 | P1 | [不変] | [境界内] |
| H-03 | `AnalyzerSettings` の可変 static キャッシュが無制限に蓄積・NPE 経路あり | P1 | [不変] | [境界外] |
| H-04 | `BadWordSettings.defaultWords` が非 volatile static の遅延初期化 | P2 | [不変] | [境界外] |
| H-05 | `SuggestSettings` の遅延初期化 4 箇所 + `init()` の check-then-act | P2 | [不変] | [境界外] |
| H-06 | `ESSourceReader` が上限到達時に PIT を解放しない経路 | P2 | [要判断] | [境界内] |
| H-07 | `SuggestIndexer` の `ensureOperations()` が非原子 | P3 | [不変] | [境界外] |
| **I. 命名・ビルダーの一貫性** ||||
| I-01 | ビルダーの命名規約が 3 通り混在、typo `contentsReadigConverter` | P2 | [要判断] | [境界内] |
| I-02 | scroll 廃止後の命名残骸（`scrollTimeout` / `setScrollSize`） | P3 | [要判断] | [境界内] |
| I-03 | `@Deprecated` な入れ子 `TimeoutSettings` が完全修飾を強いる | P2 | [不変] | [境界外] |
| I-04 | typo `maxContentLenth` | P3 | [不変] | [境界外] |
| **J. テストの保守性** ||||
| J-01 | JUnit 3 形式が 6 クラス混在 | P2 | [不変] | [境界外] |
| J-02 | 本体が TODO コメントだけの空テストが 2 件（常に成功）/ アサーション 0 件が 16 件 | P1 | [不変] | [境界外] |
| J-03 | main から未使用のコードにだけテストが付いている | P1 | [不変] | [境界外] |
| J-04 | テストが `protected` フィールド・private メンバ（リフレクション）に密結合 | P2 | [不変] | [境界外] |
| J-05 | 境界 API の I/O 契約テストが無い | P1 | [不変] | [境界外] |
| J-06 | 自作 stub 自身を検証しているテストが 39 メソッド（カバレッジの偽陽性） | P1 | [不変] | [境界外] |
| J-07 | アサーションが握り潰される / 無限ハング / 再現不能なテストが各 1〜2 件 | P1 | [不変] | [境界外] |
| J-08 | 共通基底クラスが無く、25 クラスがライフサイクル定型句をコピペ。ノード起動 26 回 | P2 | [不変] | [境界外] |
| J-09 | テストソースにベンダリングされた解析プラグイン 26 ファイル・1,980 行。21 個が未使用 | P2 | [要判断] | [境界外] |
| **K. ビルド・静的解析** ||||
| K-01 | 静的解析プラグインが 0 個（デッドコード・NPE が自動検出できない） | P1 | [不変] | [境界外] |

---

## 2. 項目詳細

### A. 責務・構造

#### A-01 `util` の神パッケージ化とパッケージ循環 — P1 [不変] [境界外]
- [確認] import 解析の結果、パッケージ間に **2 者間の循環が 5 組**ある。
  - `settings ⇄ util`、`converter ⇄ util`、`entity ⇄ util`、`concurrent ⇄ request`、`index ⇄ index.operations`
- [確認] 原因の中心は `util.SuggestUtil` が**ファクトリを兼ねている**こと。`SuggestUtil.createDefaultReadingConverter` / `createDefaultNormalizer` / `createDefaultAnalyzer`（`util/SuggestUtil.java:252-300`）が `converter`・`normalizer`・`settings` を new するため、下位のはずの `util` が上位層に依存している。
- [確認] `index ⇄ index.operations` は、`SuggestIndexer`(`index`) が `index.operations` を使い、`ContentIndexingOperations` が `index.SuggestIndexResponse` を返すことで生じている。
- [提案] ファクトリを `SuggesterBuilder` 側（または新設の `SuggesterFactory`）へ移し、`util` を「他パッケージに依存しない純粋なヘルパ」に戻す。レスポンス型は `index.operations` から見て下位のパッケージへ移すか、`index` 直下に集約する。循環の解消は依存の向きを一方向にするだけなので振る舞いは変わらない。

#### A-02 `Suggester` の責務混在 — P2 [不変] [境界内]
- [確認] `Suggester`（507 行）は、index ライフサイクル（`Suggester.java:196-360`）、検索ビルダー生成（`:159-169`）、語数カウント（`:424-453`）、テキスト処理部品の保持（`:109-125`）、threadPool の保持と停止（`:185-190`）を同時に担う。
- [確認] クラス Javadoc（`Suggester.java:55-101`）が public/protected/**private メソッドの一覧まで手書き**しており、実装変更のたびに二重メンテが要る。
- [確認] `getSearchAlias(String)` / `getUpdateAlias(String)` / `createIndexName(String)` / `isSuggestIndex(String)`（`:455-487`）は、**引数名 `index` がフィールド `index` をシャドーイング**しており、呼び出し側は常にフィールドを渡している。`getSearchAlias` に至っては恒等関数。
- [提案] `SuggestIndexLifecycle` / `SuggestSearcher` / `SuggestStats` に分け、`Suggester` は §7.2 互換の薄いファサードとして残す。シャドーイングしている 4 メソッドは引数を落として no-arg 化する（純粋な整理）。Javadoc のメソッド一覧は削除する。

#### A-03 `SuggestIndexer` の可変状態 — P2 [不変] [境界内]
- [確認] 14 個の `protected` フィールド（`index/SuggestIndexer.java:122-152`）と、それを書き換える 9 個の setter（`:457-545`）を持つが、実処理は 4 つの Ops へ委譲するだけ。
- [確認] setter のうち `setReadingConverter` 等 5 個は `operationsStale = true` を立て、`setIndexName`・`setSupportedFields`・`setTagFieldNames`・`setRoleFieldName` の 4 個は立てない（後者は毎回 `createContext()` 経由で渡されるため）。**同じ「setter」に 2 つの意味が混在**している。
- [確認] `langFieldName` と `parallel` には setter が無く、他フィールドとの対称性が崩れている。
- [提案] 構成値を不変の `SuggestIndexerConfig`（record）に束ね、コンストラクタ注入にする。setter を残す必要があるのは §7.2 に無いので、public API を壊さずに削除できる。

#### A-04 旧シグネチャのオーバーロード残存 — P1 [不変] [境界外]
- [確認] `ContentIndexingOperations` の public メソッド 12 本のうち、`ContentIndexingContext` を取らない旧形式が 5 本（`index/operations/ContentIndexingOperations.java:118, 170, 237, 302, 375`）。main からの呼び出しは**ゼロ**（`SuggestIndexer` は全て ctx 版を使う）。
- [確認] 逆に `indexFromSearchWord`（`:395`）だけは ctx 化されておらず 8 引数のまま。
- [提案] 旧 5 本を削除し、`indexFromSearchWord` を ctx 版に揃える。いずれも `SuggestIndexer` の内側なので §7.2 に影響しない。

#### A-05 `DefaultContentsAnalyzer` の配置 — P2 [不変] [境界外]
- [確認] `analysis.SuggestAnalyzer` の唯一の実装が `settings.AnalyzerSettings` の**非 static 内部クラス**（`settings/AnalyzerSettings.java:365`）。そのため生成側は `analyzerSettings.new DefaultContentsAnalyzer()` という修飾付き構文を使わざるを得ない（`util/SuggestUtil.java:297`）。
- [確認] 結果として `settings` パッケージが `analysis` インターフェースを実装する層の逆転が起きている。
- [提案] `analysis` パッケージへ独立クラスとして移し、必要な設定値をコンストラクタで受け取る。

#### A-06 インターフェースの `default` メソッドにアルゴリズム — P3 [不変] [境界外]
- [確認] `SuggestWriter.mergeItems`（`index/writer/SuggestWriter.java:76-102`）は O(n²) のマージ実装を interface の `default` として持つ。
- [確認] 内側のループで `item1.equals(item2)` を使うが、`SuggestItem` は `equals` を override していない（C-01）。実質は参照比較で、同一インスタンスが配列に 2 回現れると集約されない。
- [提案] `SuggestItemMerger` 側の静的メソッドへ移し、`Map<String, SuggestItem>` による O(n) 実装に置き換える（同一入力に対する出力は変わらない）。

#### A-07 `@Deprecated` メソッドが実処理経路にある — P2 [不変] [境界外]
- [確認] `SuggestRequest` の `@Deprecated` メソッド 6 本（`request/suggest/SuggestRequest.java:243, 255, 267, 278, 297, 310`）は、`processRequest` が **`buildQuery`(:339)・`buildFunctionScoreQuery`(:342)・`createResponse`(:382)** として実際に呼んでいる。単なる後方互換の残骸ではない。
- [確認] これらは `createOverridableQueryBuilder()`（`:318` 以降）で匿名サブクラスを作り、サブクラスの override を尊重するための**トランポリン**になっている。
- [確認] fess は fess-suggest のどのクラスも継承していない（`modules/fess/src/main`・`src/test` を grep して確認）。
- [提案] `processRequest` を `SuggestQueryBuilder` / `SuggestResponseCreator` の直接呼び出しに書き換え、6 本のトランポリンと匿名サブクラスを削除する。

### B. 公開 API 境界と可視性

#### B-01 全クラス public — P1 [不変] [境界内]
- [確認] main の 65 ファイルすべてがトップレベル `public` 宣言（package-private が 0 件）。
- [確認] 一方で fess が import している fess-suggest の型は **13 種**のみ（`Suggester`, `SuggestSettings`, `SuggestSettingsBuilder`, `SuggestItem`, `ESSourceReader`, `SuggestRequestBuilder`, `SuggestResponse`, `PopularWordsRequestBuilder`, `SuggestDeleteResponse`, `FieldNames`, `SuggestUtil`, 例外 2 種）。ほかに `SuggesterBuilder` を `Suggester.builder()` のチェーン経由で、`ElevateWord` を完全修飾名（`fess:helper/SuggestHelper.java:483`）で使う。
- [提案] §7.2 を「公開 API」として明文化し、それ以外を package-private / `internal` パッケージへ移す。JPMS を使わなくても、パッケージ分離＋可視性縮小だけで十分効果がある。fess 側の修正は不要（現状 import していないため）だが、外部利用者への影響があるので **メジャーバージョン境界での実施**を推奨。

#### B-02 `protected` 可変フィールド — P1 [不変] [境界内]
- [確認] 非 final の `protected` フィールドが **51 個**。`SuggestIndexer` 14 個、`ESSourceReader`、`RequestBuilder`（`request/RequestBuilder.java:30-32` の `client` / `request`）など。
- [確認] 継承による拡張点は fess からは使われていない（A-07 参照）。
- [提案] `private final` へ縮小。継承の余地が要るクラスだけを明示的に選び、それ以外は `final class` にする。

#### B-03 OpenSearch 型の露出 — P3 [不変] [境界内]
- [確認] main 65 ファイル中 **34 ファイル**が `org.codelibs.fesen.*` を import。`Client` / `QueryBuilder` / `SortBuilder` が API 表面を行き来する（0001 §7.2）。
- [確認] ドメインモデル `entity/SuggestItem.java:35` が `org.codelibs.fesen.opensearch.common.Nullable` を import している（アノテーション 1 個のためだけの依存）。
- [提案] 今回のスコープでは、少なくとも `entity` パッケージから OpenSearch 依存を外す（`@Nullable` は JSpecify / 自前アノテーション / Javadoc 記述へ置換）。`Client` の隠蔽は API 破壊を伴うので今回は対象外とし、設計書に課題として残す。

#### B-04 ポートが OpenSearch 型を返す — P2 [不変] [境界外]
- [確認] `analysis/SuggestAnalyzer.java:35,45` は `List<AnalyzeToken>`（OpenSearch の型）を返す。0001 §9-1 の「テキスト処理をポートとして切り出す」提案は、**このインターフェースが既に OpenSearch に縛られているため現状のままでは実現できない**。
- [提案] 戻り値を自前の `SuggestToken`（term / startOffset / endOffset / position）に置き換える。実装は `AnalyzeToken` からの変換 1 行で済み、振る舞いは変わらない。これをやっておくと将来ローカル解析実装への差し替えが可能になる（「機能変更が容易になる構成」の中核）。

#### B-05 使われないのに public な内部 API — P2 [不変] [境界外]
- [確認] `AnalyzerSettings.deleteAnalyzerSettings()`(`:268`)、`createAnalyzerSettings(Map,Map)`(`:292`)、`checkAnalyzer()`(`:478`) は main・test とも呼び出しゼロ。
- [確認] `createAnalyzerSettings(Map settings, Map mappings)`（`:292-299`）は**引数 `mappings` を一切使っていない**。`updateAnalyzer(Map)`（`:256-263`）と本体が完全に同一。
- [提案] 削除するか、`mappings` を使わないなら引数を落とす。0001 §7.2 の [推測]「`AnalyzerSettings` 系は事実上、内部 API」は、fess 側 grep で裏が取れている。

### C. 不変性・null 安全性

#### C-01 `SuggestItem` の可変性 — P2 [不変] [境界内]
- [確認] `entity/SuggestItem.java:235-333` に 12 個の setter。`equals` / `hashCode` は未実装（`toString` のみ `:464`）。
- [確認] 可変である理由は `SuggestItemSerializer.fromSource`（`:106-131`）がパッケージプライベートな no-arg コンストラクタ + setter 列で組み立てているため。
- [提案] `SuggestItem` にパッケージプライベートな Builder を用意し、setter を削除して全フィールドを `final` にする。fess が使うのは `getText` / `getTags` / `Kind` だけ（§7.2）なので [境界内] だが破壊はしない。`equals`/`hashCode` は `id` ベースで実装し、A-06 の O(n) 化に使う。

#### C-02 `emptySource` が死んだ状態 — P1 [不変] [境界外]
- [確認] `SuggestItem` のコンストラクタは毎回 `createEmptyMap()` を呼び（`entity/SuggestItem.java:139, 347-366`）、13 エントリの `HashMap` を生成する。
- [確認] この `emptySource` は `toEmptyMap()` で取れるが、**書き込み経路では一切使われない**。`toUpdatedSource`（`entity/SuggestItemSerializer.java:142-184`）は OpenSearch から GET した `existingSource` のみを参照する。main の唯一の参照は `SuggestItemMerger.java:89` の詰め替えだけ。
- [確認] さらに `createEmptyMap` は `@timestamp` を **ISO_INSTANT 文字列**で入れるが（`:364`）、実際の書き込み 3 経路はすべて **epoch millis**（`SuggestItemSerializer.java:74, 183, 220`）で、読み出しも `Long.parseLong`（`:104`）。表現が食い違っている。
- [提案] `emptySource` / `toEmptyMap` / `setEmptySource` / `createEmptyMap` を削除する。文書一括取り込みでは SuggestItem がトークン数だけ生成されるので、**1 件あたり HashMap 1 個分の割り当てが丸ごと消える**（性能改善を伴うが振る舞いは不変）。

#### C-03 `Objects.requireNonNull` の適用が 1 クラスのみ — P2 [不変] [境界外]
- [確認] main 全体で `Objects.requireNonNull` を使っているのは `Suggester.java`（7 箇所）**だけ**。`SuggestIndexer` のコンストラクタ（`index/SuggestIndexer.java:174-198`）は 8 引数すべて無検査。
- [確認] `modules/fess-suggest/CLAUDE.md` は「Validate parameters with `Objects.requireNonNull()`」を原則として明記しており、規約と実装が乖離している。
- [提案] 公開コンストラクタと公開 setter に絞って適用する。null を渡す既存テストがあれば失敗しうるので、適用範囲はテスト確認の上で決める。

#### C-04 `null` を返す契約が文書化されていない — P2 [不変] [境界外]
- [確認] `AnalyzerSettings.DefaultContentsAnalyzer.analyzeAndReading`（`settings/AnalyzerSettings.java:404-420`）は、reading 用アナライザ名が空なら `null` を返す（`:409`）。一方 `analyze` は `Collections.emptyList()` を返す（`:386`）。同一インターフェースの 2 メソッドで null 契約が食い違う。
- [確認] インターフェース側 `analysis/SuggestAnalyzer.java:38-45` の Javadoc には null の可能性が書かれていない。
- [確認] main 全体で `return null;` は 16 箇所。`NormalizerChain.normalize`（`normalizer/NormalizerChain.java:57,63`）は null を黙って伝播させる。
- [提案] Javadoc に契約を明記する（最小コスト）。可能なら `Optional` か空リストへ統一するが、それは [要判断]。

#### C-05 `fromSource` が無検査 — P2 [要判断] [境界外]
- [確認] `entity/SuggestItemSerializer.java:85, 97-104` は `source.get(FieldNames.XXX).toString()` を null チェックなしで呼ぶ。フィールド欠損ドキュメントで NPE。
- [確認] 本来この用途のために `util/MapValueExtractor` が作られているが未使用（E-01）。
- [提案] `MapValueExtractor` へ置き換える。ただし NPE が `SuggesterException` や既定値に変わるため、**エラー時の挙動が変わる**。[要判断]。

#### C-06 `Kind` 変換の if-else 羅列 — P2 [要判断] [境界外]
- [確認] `entity/SuggestItemSerializer.java:117-128` は 3 分岐の if-else。どれにも一致しない値は配列要素が `null` のまま残り、後段で NPE になりうる。
- [提案] `Kind` に `fromString(String)` を生やし、未知値の扱い（無視 / 例外）を明示する。現状は暗黙に null を通すので [要判断]。

#### C-07 `ElevateWord` の防御的コピー欠如 — P3 [不変] [境界外]
- [確認] フィールドは `final` だが、`entity/ElevateWord.java:67-82` は渡された `List` をそのまま保持し、getter（`:107-134`）もそのまま返す。呼び出し側からの変更が反映される。
- [提案] `List.copyOf` で包む。`ElevateWord` の 6 引数コンストラクタは §7.2 の境界にあるが、シグネチャは変わらない。

#### C-08 `tagFieldNames` が空設定で `[""]` になる — P3 [要判断] [境界外]
- [確認] `index/SuggestIndexer.java:182` は `settings.getAsString(TAG_FIELD_NAME, StringUtil.EMPTY).split(",")`。設定が空文字のとき `String.split` は `[""]` を返すので、空文字のタグフィールド名が 1 個できる。
- [提案] 空なら空配列にする。fess は常に値を設定しているので実害は [推測] 無いが、挙動が変わりうるため [要判断]。

### D. 重複コードと定数

#### D-01 `fess.dictionary.path` 置換の 3 重複 — P1 [不変] [境界外]
- [確認] ほぼ逐語同一のメソッドが 3 箇所: `settings/AnalyzerSettings.java:315-327`、`settings/SuggestSettings.java:531-543`、`settings/ArraySettings.java:373-385`。
- [確認] **正しい共通実装が `util/SettingsResourceLoader.java:110-125` に既にあるが、main から一切使われていない**（E-02）。
- [確認] プロパティ名 `"fess.dictionary.path"` とプレースホルダ `"${fess.dictionary.path}"` が各 4 箇所にハードコード。
- [提案] 3 箇所を `SettingsResourceLoader` 呼び出しへ置き換える。ただし置き換え前に D-02 の差分（null チェック・文字コード）を吸収する必要がある。

#### D-02 リソース読み込みの 6 重複と不統一 — P1 [不変] [境界外]
- [確認] classpath からテキストを読む処理が 6 箇所: `AnalyzerSettings.java:317-325`、`AnalyzerSettings.java:350-358`、`SuggestSettings.java:533-541`、`ArraySettings.java:375-383`、`BadWordSettings.java:143-152`、`Suggester.java:467-483`（2 メソッド）。
- [確認] 不統一が 3 種類ある。
  - **null チェック**: `Suggester.java:469,478` のみ `IOException("Resource not found: ...")` を投げる。他は `getResourceAsStream` の戻りを無検査で `InputStreamReader` に渡すので、リソース欠損時に**生 NPE**。
  - **文字コード**: `Suggester` は `StandardCharsets.UTF_8` 明示、他は `new InputStreamReader(is)` で**プラットフォーム既定**。対象は UTF-8 の JSON / 辞書。
  - **ClassLoader**: `BadWordSettings.java:145` だけ `Thread.currentThread().getContextClassLoader()`、他は `this.getClass().getClassLoader()`。
- [確認] 実装方式も 2 通り（`readAllBytes` vs `BufferedReader` ループ）。
- [提案] `SettingsResourceLoader` に一本化し、null チェック・UTF-8・ClassLoader を揃える。**文字コードの明示は厳密には挙動変更**だが、非 UTF-8 環境で現在壊れているものを直す方向なので [不変] 扱いとした（実行環境の既定文字コードを確認の上で判断）。

#### D-03 index 作成 + yellow 待ちの 4 系統 — P2 [要判断] [境界外]
- [確認] 「exists 確認 → なければ create → 競合を許容 → yellow 待ち」が独立に 4 回書かれている: `AnalyzerSettings.java:137-166`、`SuggestSettings.java:191-248`、`ArraySettings.java:308-366`、`Suggester.java:196-230`/`:235-277`。
- [確認] `setWaitForYellowStatus()` が 5 箇所（うち `Suggester.java:220,260` は対象 index を指定しない全クラスタ待ち）。
- [確認] **`Suggester` にだけ `SuggestUtil.isResourceAlreadyExistsException` による競合対策が無い**（`:224` は全例外を `SuggesterException` に包む）。#100 の修正が settings 系にしか入っていない。
- [確認] 競合判定は `message.contains("type=resource_already_exists_exception")` という文字列マッチ（`util/SuggestUtil.java:409-412`）。
- [提案] `IndexCreationHelper` に共通化する。`Suggester` に競合対策を入れるのは**挙動変更**なので [要判断]（入れる方が正しいが、今回のスコープ外にする判断もありうる）。

#### D-04 配列マージの 4 実装併存 — P2 [不変] [境界外]
- [確認] 「重複を除いて連結」が 4 通り。
  - `SuggestItem.concatValues`（`entity/SuggestItem.java:408-414`）— main 未使用
  - `SuggestItem.concatKinds`（`:422-438`）— main 未使用
  - `SuggestItemSerializer.concatValues`（`entity/SuggestItemSerializer.java:254-263`）— 上と同一ロジックの private 再実装
  - `SuggestItemMerger.mergeStringArrays` / `mergeKinds` / `mergeReadings`（`entity/SuggestItemMerger.java:101-151`）— 前 2 つは `LinkedHashSet`、`mergeReadings` だけ contains ループ
- [提案] `SuggestItemMerger` の `LinkedHashSet` 版に統一し、`SuggestItem` の 2 メソッドは削除（E 章と同時に実施）。

#### D-05 `actualIndex` 算出の 5 重複 — P3 [不変] [境界外]
- [確認] `final String actualIndex = index + "." + type.toLowerCase(Locale.ENGLISH);` が逐語的に 5 回（`settings/ArraySettings.java:206, 253, 278, 293, 309`）。
- [確認] 同ファイル内で update 後 refresh も重複（`:265`, `:296`）。`SuggestSettings.java:354`, `:380` も同様。
- [提案] private ヘルパへ抽出。

#### D-06 ページサイズとリトライ回数 — P2 [不変] [境界外]
- [確認] `500` が 4 クラスで**別々の定数名**として定義: `AnalyzerSettings.java:102`（FIELD_ANALYZER_MAPPING_PAGE_SIZE）、`ArraySettings.java:92`（DEFAULT_SEARCH_SIZE）、`SuggestUtil.java:73`（DELETE_PAGE_SIZE）、`DeletionOperations.java:52`（SEARCH_PAGE_SIZE）。
- [確認] `setRetryOnConflict(5)` が 3 箇所直書き（`ArraySettings.java:262`、`SuggestSettings.java:351, 377`）。`ESSourceReader.java:105` の `maxRetryCount = 5` も同値だが無関係。
- [提案] 用途が違うなら定数名だけ残して集約せず、コメントで根拠を書く。少なくとも `setRetryOnConflict(5)` は定数化する。

#### D-07 index 名サフィックスと Locale — P2 [要判断] [境界外]
- [確認] リテラル直書きのサフィックス 9 種: `"_analyzer"`(`AnalyzerSettings.java:307`)、`"_array"`(`ArraySettings.java:184`)、`"_badword"`(`BadWordSettings.java:58`)、`"_elevate"`(`ElevateWordSettings.java:101`)、`"-badword"`/`"-elevateword"`(`SuggestSettings.java:175-176`、E-05 の dead field)、`".suggest"`(`SuggestSettings.java:512`)、`".update"`(`Suggester.java:460`)、`"fess_suggest"`(`SuggestSettingsBuilder.java:36`)。
- [確認] `SuggestSettings.java:512` の `.toLowerCase()` は **Locale 未指定**。`ArraySettings.java:206` や `SuggestSettingsBuilder.java:50` は `toLowerCase(Locale.ENGLISH)`。トルコ語ロケールでは index 名が変わる。
- [提案] サフィックスを `SuggestConstants` へ集約し、`toLowerCase` に `Locale.ENGLISH` を付ける。**Locale の付与は index 名が変わりうる**ため [要判断]（実質は既存のバグ修正だが、特定ロケール環境では既存 index を見失う）。

#### D-08 スコア計算式の 4 重複 — P2 [不変] [境界外]
- [確認] `(queryFreq + docFreq) * userBoost` が `SuggestItemSerializer.java:73, 182, 219` と `util/SuggestUtil.java:223` の 4 箇所に直書き。
- [確認] readings の distinct 化も 3 箇所（`SuggestItemSerializer.java:61, 155, 199`）。
- [提案] `SuggestItem.calculateScore()` に集約（E-03 で `createBulkLine` を消せば 3 箇所に減る）。

#### D-09 `checkAnalyzer` の 5 回コピペ — P3 [不変] [境界外]
- [確認] `settings/AnalyzerSettings.java:483-540` に、5 種類のアナライザに対する同型 try/catch が 5 ブロック並ぶ。同ファイル `:184-200` のラムダ集約（`getAnalyzerName`）が適用されていない。
- [提案] メソッド自体が未使用なので B-05 で削除すれば解消する。残すならラムダ + ループへ。

#### D-10 定数の重複と混在 — P3 [不変] [境界外]
- [確認] `"_doc"` が `SuggestConstants.DEFAULT_TYPE` と `AnalyzerSettings.DOC_TYPE_NAME` に重複定義（どちらも参照ゼロ。削除は E-08）。
- [確認] 空文字が `SuggestConstants.EMPTY_STRING`（2 箇所）と corelib の `StringUtil.EMPTY`（10 箇所）で混在。
- [確認] [推測] `SuggestItemMerger.java:70` の `item1.getText().split(SuggestConstants.TEXT_SEPARATOR)` は、join 用の区切り文字定数を**正規表現として** `split` に渡している。現在値 `" "` では正規表現としても同義なので動くが、定数値を変えると破綻する。
- [提案] 未使用定数を削除し、空文字は `StringUtil.EMPTY` に寄せる。`split` は `Pattern.quote` か専用定数にする。

### E. デッドコード・未使用 API

> 本章はすべて「main から到達不能」を grep で確認済み。テストのみが参照しているものは J-03 と対で扱う。

#### E-01 `MapValueExtractor` — P1 [不変] [境界外]
- [確認] 275 行・public static メソッド 15 個（`util/MapValueExtractor.java:42-274`）。main からの参照は**ゼロ**。参照元は `test:util/MapValueExtractorTest.java` のみ。
- [確認] クラス Javadoc に「Centralizes map access patterns to reduce code duplication」と書かれているが、置き換え対象（C-05 の `SuggestItemSerializer.fromSource`）が手書きのまま残っている。
- [確認] `MapValueExtractor.getStringList`（`:233-247`）は `SuggestUtil.getAsList`（`:315-329`）と完全重複。
- [提案] **適用するか削除するかを決める**。適用する場合は C-05 と同時に実施（[要判断] になる）。削除する場合は純粋な [不変]。

#### E-02 `SettingsResourceLoader` — P1 [不変] [境界外]
- [確認] main からの参照ゼロ（自クラス内 3 行のみ）。参照元は `test:util/SettingsResourceLoaderTest.java`。
- [確認] 本来の適用先は D-01 / D-02 の 5〜6 箇所。
- [提案] D-02 と併せて適用する。適用後に `SettingsResourceLoader.java:86` の `new InputStreamReader(is)`（文字コード未指定）も直す。

#### E-03 `SuggestUtil.createBulkLine` — P1 [不変] [境界外]
- [確認] `util/SuggestUtil.java:197-235`。main からの呼び出しゼロ、`test:util/SuggestUtilTest.java` が 6 箇所で使用。
- [確認] `_type` を含む旧 bulk 形式（`:205`）。OpenSearch では `_type` は廃止済み。
- [確認] **`FieldNames` を import すらせず**、`"text"`, `"reading_" + i`, `"queryFreq"`, `"@timestamp"` 等 12 個のフィールド名をすべて生文字列で書いている（`:204-227`）。`SuggestItemSerializer.toSource` の重複実装。
- [提案] 削除。§7.2 で fess が使う `SuggestUtil` のメンバは `deleteByQuery` のみ。

#### E-04 `SuggestItem.convertJsonString(s)` — P1 [不変] [境界外]
- [確認] `entity/SuggestItem.java:472-481`。`convertJsonString` は `convertJsonStrings` からのみ呼ばれ、`convertJsonStrings` は**どこからも呼ばれない**。完全な dead private code。
- [確認] 同等処理は `SuggestItemSerializer.escapeJsonString`（`:268-297`）にあり、そちらは `\n` `\r` `\t` `\\` までエスケープする（SuggestItem 版は `"` のみ）。**品質の低い方が残っている**。
- [提案] 削除。あわせて未使用 import `java.util.stream.Collectors`（`:28`）も除去。

#### E-05 `SuggestSettings` の dead field — P1 [不変] [境界外]
- [確認] `badWordIndexName` / `elevateWordIndexName`（`settings/SuggestSettings.java:132,134`）は `:175-176` で代入されるだけで**一度も読まれない**。
- [確認] 値は `settingsIndexName + "-badword"` / `"-elevateword"` で、実際に使われる `_badword` / `_elevate`（`BadWordSettings.java:58`、`ElevateWordSettings.java:101`）と**区切り文字も語も違う**。
- [提案] 削除。

#### E-06 `SuggestBulkFileWriter` — P1 [不変] [境界外]
- [確認] 全メソッドが `UnsupportedOperationException` を投げるのみ。main からの生成箇所ゼロ。
- [提案] 削除。

#### E-07 未使用の public メソッド — P2 [不変] [境界外]
- [確認] `util/PitOperationHelper.getTotalHitCount`（`:158-164`）は main・test とも参照ゼロ。かつ PIT を使っていないのに `PitOperationHelper` に置かれている。さらに `setTrackTotalHits(true)` が無く、`ESSourceReader.getTotal`（`:340-341`）や `Suggester.getNum`（`:447-449`）と実装が揃っていない（10,000 件で打ち切られる）。
- [確認] `AnalyzerSettings` の 3 メソッド（B-05）。
- [提案] 削除。

#### E-08 未使用定数 — P2 [不変] [境界外]
- [確認] `FieldNames.ID`（`constants/FieldNames.java:52`）は main・test とも参照ゼロ。実際の `"_id"` は `SuggestUtil.java:206` で生文字列。
- [確認] `SuggestConstants.DEFAULT_TYPE`（`constants/SuggestConstants.java:43`）/ `AnalyzerSettings.DOC_TYPE_NAME`（`settings/AnalyzerSettings.java:99`）。いずれも `"_doc"` の重複定義（D-10）。
- [確認] `SuggestConstants.USER_DICT_PATH` / `USER_DICT_ENCODING`（`:31,34`）の唯一の出現は `converter/KatakanaConverter.java:72-73` の**コメントアウトされた TODO ブロック内**。
- [提案] 削除。

#### E-09 未使用 import とコメントアウトされた構成 — P2 [不変] [境界外]
- [確認] `entity/SuggestItem.java` の `java.time.Clock`(`:18`)・`java.time.Instant`(`:19`)・`java.util.Collections`(`:24`)・`java.util.stream.Stream`(`:29`) は import 行にしか出現しない（`SuggestItemSerializer` 分離時の取り残しと [推測]）。
- [確認] `util/SuggestUtil.java:282-285` に `HankakuKanaToZenkakuKana` / `FullWidthToHalfWidthAlphabetNormalizer` / `ICUNormalizer` をチェーンに追加するコードがコメントアウトされている。結果として **`normalizer` パッケージの 3 クラス（`HankakuKanaToZenkakuKana` は 178 行）は既定構成から到達不能**。`icu4j` が optional 依存として残っているのもこのため。
- [確認] `converter/KatakanaConverter.java:72-73, 144, 157` にもコメントアウトされたコードブロックがある。
- [提案] 未使用 import は即削除。コメントアウト構成は git 履歴に残るので削除し、必要なら設計書に「正規化チェーンの拡張余地」として記録する。

#### E-10 クエリログ経路 — P2 [要判断] [境界外]
- [確認] `indexFromQueryLog`（`SuggestIndexer` 3 オーバーロード + `ContentIndexingOperations` 6 本）、`index.contents.querylog` パッケージ、`SuggestUtil.parseQuery`（Lucene の `lucene-queryparser` 依存）は fess から未使用（0001 §5.1）。
- [確認] `SuggestUtil.getKeywords`（`:130-141`）は catch で無言の空リスト返却（G-02）。
- [提案] 削除すれば `lucene-queryparser` 依存も外せてビルドが軽くなるが、**ライブラリとしての機能削除**に当たるので [要判断]。今回はスコープ外にして設計書に判断事項として残すのが安全。

#### E-11 未使用引数 — P3 [不変] [境界外]
- [確認] `SuggestUtil.createDefaultContentsReadingConverter(Client, SuggestSettings)`（`:266-270`）は**両方の引数を使っていない**。
- [提案] 引数を落とす（`SuggesterBuilder.java:168` の 1 箇所を直すだけ）。

### F. 例外とエラー伝搬

#### F-01 ルート例外が 2 本 — P1 [要判断] [境界内]
- [確認] `SuggestIndexException extends SuggesterException` だが、`SuggestSettingsException`（`exception/SuggestSettingsException.java:31`）だけは `RuntimeException` 直下。
- [確認] 結果、`catch (SuggesterException e)` では settings 系のエラーを捕まえられない。`Suggester.java:268,325` の `catch (SuggesterException e) { throw e; }` ガードも `SuggestSettingsException` を素通しし、直後の `catch (Exception e)` で `SuggesterException` に包み直される。
- [確認] fess は両方を個別に import している（`fess:helper/SuggestHelper.java`）。
- [提案] `SuggestSettingsException extends SuggesterException` にする。fess の既存 catch は壊れない（より広い型を捕まえるだけ）が、**利用者の catch 順によって挙動が変わりうる**ため [要判断]。

#### F-02 cause を捨てる catch — P1 [不変] [境界外]
- [確認] 2 箇所で `IOException e` を受け取りながら使っていない。メッセージも同一の `"Failed to create mappings."` で、どちらで起きたか区別できない。
  - `settings/AnalyzerSettings.java:163-164`
  - `settings/ArraySettings.java:363-364`
- [確認] `settings/ArraySettings.java:329-330` は逆に、**分岐の契機にすぎない** `IndexNotFoundException e` を「create が ack されなかった」ことの cause として渡している。
- [提案] cause を渡し、メッセージにクラス / index 名を含める。純粋な改善。

#### F-03 `Deferred` の握りつぶし — P1 [要判断] [境界外]
- [確認] `concurrent/Deferred.java:93` と `:119` が `catch (final Exception ignore) {}`。`Deferred` にはロガーが無いため、コールバック内のバグが完全に不可視。
- [確認] さらに `stream().forEach` を try で包んでいるので、**1 つのコールバックが投げると残りのコールバックが実行されない**。
- [確認] 非対称: 同じ処理を `Promise.then`(`:166-182`) / `Promise.error`(`:189-205`) 側では try で包んでいない。**コールバックの登録タイミングによって例外時の挙動が変わる**。
- [提案] コールバックを 1 件ずつ try で囲み、ログを出す。例外が外へ漏れるかどうかが変わるため [要判断]。

#### F-04 エラーリストの先頭 1 件以外を破棄 — P2 [要判断] [境界外]
- [確認] `index/operations/DeletionOperations.java:173-175` と `:188-190` が `getErrors().get(0)` / `getFailures().get(0)` だけを例外化し、残りの `Throwable` を破棄（ログにも残らない）。
- [提案] 全件を suppressed exception として付ける、またはまとめてログに出す。

#### F-05 `deleteOldWords` が結果を捨てる — P1 [要判断] [境界外]
- [確認] `index/operations/DeletionOperations.java:211-212`。`deleteByQuery(index, query)` の戻り値（エラーを含みうる `SuggestDeleteResponse`）を**無視**し、常に `new SuggestDeleteResponse(null, ...)`（errors=null）を返す。
- [確認] `deleteWordsByKind`（`:194`）も同じく常に errors=null。
- [提案] 戻り値を伝播させる。呼び出し側が `hasError()` を見るようになるため [要判断]（ただし fess は `deleteOldWords` を使っておらず自前 purge のため、実影響は小さい — 0001 §5.3）。

#### F-06 writer 内の非対称 — P2 [要判断] [境界外]
- [確認] `index/writer/SuggestIndexWriter` の 3 メソッドで方針が割れている。
  - `write`(`:45-80`) — try/catch 無し。GET / bulk の例外はそのまま伝播。bulk の**部分失敗だけ** `result.addFailure`（`:74`）
  - `delete`(`:83-91`) / `deleteByQuery`(`:94-103`) — `catch (Exception e) { result.addFailure(e); }`
- [確認] `SuggestWriter` インターフェースはこの差を規定していない。`request/Response.java` は中身ゼロのマーカーで `getErrors()` を宣言しておらず、`SuggestDeleteResponse` に至っては `Response` を実装していない。
- [提案] 「例外を投げる」か「errors に積む」かを層ごとに決め、`Response` 側に契約を持たせる。[要判断]。

#### F-07 reject のラップが不統一 — P2 [要判断] [境界内]
- [確認] 同じ `ActionListener.onFailure` の実装で、`request/suggest/SuggestRequest.java:388` は `new SuggesterException(e.getMessage(), e)` で包み、`request/popularwords/PopularWordsRequest.java:197` は `deferred.reject(e)` と生のまま渡す。
- [確認] fess は `Deferred.Promise.getResponse()` 経由で受けるので（§7.2）、`getResponse` が `SuggesterException` に包み直す（`Deferred.java:228`）。**[推測] 実害は限定的**だが、`error()` コールバックを使う利用者には型が変わって見える。
- [提案] `SuggesterException` に統一し、メッセージに文脈（index 名 / クエリ）を足す。

#### F-08 例外型の選択ルールが未確立 — P2 [不変] [境界外]
- [確認] `index` 配下でも型が割れている: `index/operations/*` は `SuggestIndexException`、`index/contents/DefaultContentsParser.java:110,147,206` と `index/contents/document/ESSourceReader.java:269` は `SuggesterException`。
- [確認] `settings/SuggestSettings.java:215` は同じファイル内の `:356, :382` が `SuggestSettingsException` を使うのに対し `SuggesterException` を使う。
- [確認] `serialVersionUID` も `SuggestIndexException.java:37` だけ生成値、他 2 つは `1L`。
- [提案] 「パッケージ = 例外型」の単純ルールを決めて揃える。

#### F-09 割り込みフラグの復元漏れ — P2 [要判断] [境界外]
- [確認] `index/operations/ContentIndexingOperations.java:215` / `:354` の `catch (final Throwable t)` が、`:210` の `Thread.sleep(requestInterval)` が投げる `InterruptedException` を吸収し、`Thread.currentThread().interrupt()` を呼ばない。
- [確認] 同じループ（`:198`, `:334`）は `Thread.currentThread().isInterrupted()` を見て break する設計なので、**フラグ復元漏れは論理的に実害がある**。
- [確認] `concurrent/Deferred.java:231-233` も `InterruptedRuntimeException` に変換するだけでフラグを復元しない。
- [確認] `catch (Throwable)` は `OutOfMemoryError` まで Promise に押し込む。
- [提案] `InterruptedException` を個別に捕まえてフラグを復元し、`catch (Throwable)` を `catch (Exception)` に狭める。中断時の完了状態が変わるので [要判断]。

### G. ログ

#### G-01 ガードとレベルの不一致 — P1 [不変] [境界外]
- [確認] `index/contents/DefaultContentsParser.java:302-308`:
  ```java
  if (logger.isDebugEnabled()) {
      logger.warn("Failed to analyze {}{}text: ...", ..., e);     // ← debug ガードの中で warn
  } else {
      logger.warn("Failed to analyze {}{}text: ..., error={}", ..., e.getMessage());
  }
  ```
- [確認] 意図は「DEBUG 有効ならスタックトレース付き」と読めるが、ガードとしては誤用。DEBUG を切ると `e` 本体が失われる。
- [確認] 逆向きの不一致もある。`ContentIndexingOperations.java:150,278,422` は呼び出し側で `isInfoEnabled()` ガードしているのに、`printProcessingInfo` 内の `logger.info`（`:454`）はガード無しで、`String.format` と `ManagementFactory.getOperatingSystemMXBean()`（`:442-453`）が常時走る。
- [提案] `logger.warn(msg, e)` へ一本化するか、`isDebugEnabled` ブロックは `logger.debug` にする。`printProcessingInfo` はガードを内側へ移す。

#### G-02 `logger.error` が 0 件 — P3 [不変] [境界外]
- [確認] main 全体で `logger.error` の使用 0 件。`logger.warn` は 4 箇所のみ。
- [確認] Logger を持つクラスは 14/65。`util/SuggestUtil.java:67` はロガーを持つのに `:138-140` の catch で使っていない。
- [提案] 「例外送出＝ログなし / 回復して継続＝warn / 継続不能だが投げられない＝error」といった方針を決めて明文化する。

#### G-03 `SuggestIndexer` の未使用ロガー — P3 [不変] [境界外]
- [確認] `index/SuggestIndexer.java:119` の `private final static Logger logger` は、クラス内で一度も使われていない。Javadoc（`:99`）の `{@link #logger}` だけが残っている。
- [確認] 修飾子順が `private final static` で、他 13 クラスの `private static final` から逸脱。
- [提案] 削除。

#### G-04 「catch → debug ログ → throw」の適用が不均一 — P2 [不変] [境界外]
- [確認] このパターンは 5 箇所だけ（`Suggester.java:224-229, 271-276, 328-333`、`ContentIndexingOperations.java:282-287, 426-433`）。同種の catch→throw 20 箇所超には debug ログが無い。
- [確認] 例外を投げる以上、呼び出し側でスタックトレースは出るので debug ログは冗長。
- [提案] 「投げるならログを出さない」に統一して 5 箇所を削る（ログ出力が減るが、例外情報は失われないので [不変] 扱い）。

### H. リソース管理・並行性

#### H-01 fess 側でのスレッドプールリーク — P1 [要判断] [境界内]
- [確認] `fess:helper/SuggestHelper.java:114` の `init()` は `@PostConstruct` 付きだが、**同ファイルに `@PreDestroy` が無い**（import も無い）。fess の他コンポーネント（`SearchEngineClient`、`ThumbnailManager`、`IndexUpdater`）は `@PreDestroy` を持つ。
- [確認] `init()` は `:142` で毎回 `Suggester.builder()...build(...)` して**新しい固定スレッドプールを作り**、`suggester` フィールドを上書きする。
- [確認] `init()` は `@PostConstruct` 以外に、`fess:helper/SystemHelper.java:919`（`reloadConfiguration(boolean)`）から明示的に再呼び出しされる。呼び出し元は `fess:app/web/admin/backup/AdminBackupAction.java:283`（バックアップのリストア）。
- [確認] **旧 `Suggester.shutdown()` は呼ばれない**（`modules/fess/src/main` 全体で `shutdown` / `close` の呼び出し 0 件 — 0001 §6 と一致）。リストア 1 回につき CPU コア数分の非デーモンスレッドがリークする。
- [確認] バッチ側 `fess:exec/SuggestCreator.java` も shutdown を呼ばないが、`main` 末尾の `System.exit` でプロセスごと終了するため顕在化しない。
- [提案] fess 側に `@PreDestroy` を追加し、`init()` の先頭で旧 suggester を shutdown する。**fess 本体の修正**なので、fess-suggest 側のリファクタリング範囲か要判断。fess-suggest 側では H-02 で「閉じ忘れを検出可能にする」対応を行う。

#### H-02 `Suggester` の終了 API — P1 [不変] [境界内]
- [確認] `Suggester.shutdown()`（`:185-190`）は `threadPool.shutdownNow()` のみ。`awaitTermination` も、戻り値の未実行 `List<Runnable>` の処理も無い。
- [確認] 捨てられたタスクの `Deferred` は誰も resolve/reject しないため、`Deferred.Promise.getResponse()`（`Deferred.java:211-213`）が**既定 1 分**ブロックしてからタイムアウト例外。`then`/`error` は永久に呼ばれない。
- [確認] `SuggesterBuilder.threadPool(ExecutorService)`（`:128`）で外部注入されたプールも同じく `shutdownNow` される（owned / injected の区別が無い）。
- [確認] `Suggester` は `AutoCloseable` を実装していない（`:102`）ため try-with-resources で守れず、閉じ忘れが静的に検出できない。
- [確認] `Executors.newFixedThreadPool(n)` は `ThreadFactory` 未指定（`SuggesterBuilder.java:186`）→ スレッド名が `pool-N-thread-M` になり、スレッドダンプで fess-suggest 由来と判別できない。
- [確認] client の所有権も文書化されていない。`Suggester` は client を保持しているのに getter が無いため、fess は `ComponentUtil.getSearchEngineClient()` で取り直している（`fess:helper/SuggestHelper.java:273, 314, 331`）。
- [提案] `Suggester implements AutoCloseable` とし、`close()` で `shutdown()` + `awaitTermination` を行う。owned フラグを持たせて注入プールは停止しない。`ThreadFactory` で名前を付ける。Javadoc に「client は呼び出し側所有で close しない」と明記する。`shutdown()` は互換のため残す。

#### H-03 `AnalyzerSettings` の static キャッシュ — P1 [不変] [境界外]
- [確認] `settings/AnalyzerSettings.java:111, 113` の 2 つのキャッシュは `protected static`（**`final` でない**）な `ConcurrentHashMap`。プロセス全体で共有され、エントリは削除されない。
- [確認] `deleteAnalyzerSettings()`(`:268`) は index を消すがキャッシュは残す。`updateAnalyzer()`(`:256`) は設定を変えるが `analyzerMap` を更新しない → stale。
- [確認] `getAnalyzerName`（`:184-200`）は `:186-187` で取得した map / set を **null チェックなしで** `:189` `:196` で参照する。当該 index 名で `init()` が走っていない JVM では NPE。**検索経路（`AnalyzerConverter` → `getReadingAnalyzerName`）がプロセスグローバル static の事前投入に依存している。**
- [確認] `init()` の `synchronized`（`:137`）はインスタンスロックなのに、守っている状態は static。さらに `AnalyzerSettings` は 1 設定につき 2 インスタンス生成される（`SuggestSettings.java:188` の使い捨て + `:401-406` の遅延生成）。
- [提案] `private static final` にしてキャッシュを `Suggester` インスタンス単位へ移す（または明示的な無効化 API を設ける）。`getAnalyzerName` に null フォールバックを入れる。`SuggestSettings.init()` は `analyzer()` を使って 2 重生成をやめる。

#### H-04 `BadWordSettings.defaultWords` — P2 [不変] [境界外]
- [確認] `settings/BadWordSettings.java:44` の `protected static String[] defaultWords = null` は、**非 volatile static の遅延初期化をロック無しの check-then-act で行う**（読み `:74-79`、書き `:138-156`）。
- [確認] 可変 `String[]` を共有するので、呼び出し側から要素を書き換え可能。
- [提案] holder イディオム（`private static final class Holder`）+ 不変リストへ。

#### H-05 `SuggestSettings` の遅延初期化 — P2 [不変] [境界外]
- [確認] `array()` / `analyzer()` / `badword()` / `elevateWord()`（`settings/SuggestSettings.java:390-428`）が非 volatile フィールドへの非同期 lazy singleton。4 箇所で同型のコード。
- [確認] `init()`（`:182-189`）は `initialized = true` を**実処理の前**に立てるため、`initialize()` が例外を投げても再試行時は初期化がスキップされる。`initialized` は非 volatile。
- [確認] `settings/SuggestSettings.java:227` のローカル変数 `arraySettings` がフィールド `arraySettings`（`:139`）をシャドーイングしている。
- [提案] 4 つを `SuggesterBuilder.build()` の時点で eager 生成して `final` にする。`initialized` のセットを処理成功後に移す（例外時の再試行挙動が変わるが、現状は壊れた状態が固定されるだけなので [不変] 扱い）。

#### H-06 `ESSourceReader` の PIT 解放漏れ経路 — P2 [要判断] [境界内]
- [確認] PIT は `index/contents/document/ESSourceReader.java:118` の可変フィールド。解放は `:242`（空ページ）/ `:272`（リトライ時）/ `:310-315`（`close()`）。
- [確認] **`:229-232` の「読み取り上限に達した」分岐は `isFinished` を立てて `return` するだけで `releasePit()` を呼ばない。**
- [確認] 本リポジトリ内の利用（`ContentIndexingOperations.java:331` の try-with-resources）は close するので実害は出ない。しかし `ESSourceReader` は §7.2 の公開 API で **fess が直接 new している**（`fess:helper/SuggestHelper.java:273`）。close を呼ばない利用者は PIT を漏らす。
- [確認] `SuggestUtil.deletePitContext`（`:369-382`）は `ActionListener` による fire-and-forget で、失敗は warn ログのみ・リトライ無し。
- [確認] `close()` と `read()` が同じインスタンスロック（`:142`, `:151`）のため、ハングした読み取りを close で中断できない。
- [確認] `setScrollSize` / `setQuery` / `addSort` / `setLimitNumber`（`:161-224`）は非同期化されておらず、`synchronized` メソッドが読む状態を外から書き換えられる。
- [提案] `:232` に `releasePit()` を足す（挙動が変わるので [要判断] だが、漏れを塞ぐ方向）。`ESSourceReader` の setter 群を不変な設定オブジェクトに束ねる。

#### H-07 `ensureOperations()` の非原子性 — P3 [不変] [境界外]
- [確認] `index/SuggestIndexer.java:216-220` は `operationsStale`（volatile）を見て `initializeOperations()` を呼ぶ check-then-act。守られる `indexingOps` 等（`:155-158`）は**非 volatile**。
- [確認] `modules/fess-suggest/CLAUDE.md` は「SuggestIndexer: Thread-safe for indexing」と書いているが、実装はそれを保証していない。
- [提案] A-03（不変な構成オブジェクト化）で setter ごと無くすのが根治。ドキュメントの記述も実態に合わせる。

### I. 命名・ビルダーの一貫性

#### I-01 ビルダーの命名規約が 3 通り — P2 [要判断] [境界内]
- [確認] 3 つの流儀が混在している。
  - `SuggesterBuilder`: 名詞形（`settings(x)`, `normalizer(x)`, `threadPool(x)`）
  - `SuggestSettingsBuilder`: **同一クラス内で混在**（`setSettingsIndexName` / `addInitialSettings` と、`scrollTimeout` / `searchTimeout` / `indexTimeout` …）
  - `SuggestRequestBuilder` / `PopularWordsRequestBuilder`: `setXxx` / `addXxx`
- [確認] 同じ概念のメソッド名も割れている: `SuggestRequestBuilder.addLang(String)`（`:155`）vs `PopularWordsRequestBuilder.addLanguage(String)`（`:89`）。
- [確認] typo: `SuggesterBuilder.contentsReadigConverter`（`:98`。正しくは Reading）。
- [確認] これらはすべて §7.2 に載る境界。
- [提案] 新名を追加し、旧名は委譲 + `@Deprecated` で残す（fess 側は `addLang` / `settings` / `build` しか使わないので追従は不要）。名前の追加は [不変] だが、旧名をいつ消すかの判断があるので [要判断]。

#### I-02 scroll 廃止後の命名残骸 — P3 [要判断] [境界内]
- [確認] PIT 移行（#97）後も `scrollTimeout` が残り、PIT の keepAlive として流用されている（`util/PitOperationHelper.java:167-175`、`settings/SuggestSettings.java:442`、`settings/TimeoutSettings.java:35`）。
- [確認] `ESSourceReader.setScrollSize` / `scrollSize`（`:103, 161`）は実際にはページサイズ。**既定値が `1`**（1 件ずつ取得）。fess は `setScrollSize` を呼ぶので実害は無いが、驚きのある既定値。
- [提案] `keepAlive` / `pageSize` を追加し旧名を `@Deprecated` 委譲。既定値の変更は [要判断]。

#### I-03 入れ子 `TimeoutSettings` — P2 [不変] [境界外]
- [確認] `settings/SuggestSettings.java:150` の `@Deprecated public static class TimeoutSettings extends org.codelibs.fess.suggest.settings.TimeoutSettings` は、トップレベル版の空サブクラス。
- [確認] 名前が衝突するため、**同じパッケージ内で完全修飾名を書かざるを得ない箇所が 3 つ**（`:137`, `:150`, `:168`）。
- [提案] 削除（`@Deprecated` なので次のメジャーで落とせる）。fess は使っていない。

#### I-04 typo `maxContentLenth` — P3 [不変] [境界外]
- [確認] `settings/AnalyzerSettings.java:374, 385`。private フィールドなので改名は安全。
- [確認] 同じ行に既定値 `50000` が直書き。`DefaultContentsParser.java:75` の `fess.suggest.max.analyzed.content.length`（既定 1000）とは別系統の長さ制限で、**2 つの独立した上限が存在する**。
- [確認] `analyze()` は `text.length() > maxContentLenth` のとき `Collections.emptyList()` を返すが**ログを出さない**（無言のデータ欠落）。
- [提案] 改名 + 定数化 + debug ログ。ログ追加は [不変]。

### J. テストの保守性

#### J-01 JUnit 3 形式の混在 — P2 [不変] [境界外]
- [確認] `extends TestCase`（JUnit 3）が 6 クラス（`test:SuggesterBuilderTest`、`test:converter/` の 3 クラス、`test:util/TransliteratorUtilTest`、`test:normalizer/ICUNormalizerTest`）。残り 47 クラスは JUnit 4。JUnit 5 は 0 件、テスト依存は `junit:junit` のみ（Mockito / AssertJ 等も無い）。
- [確認] 書き方も割れている。例外検証は `@Test(expected=...)`・`try/fail/catch`・フラグ変数（`test:SuggesterRefactoringTest.java:174-190`）の 3 通りで `assertThrows` は 0 件。メソッド名は `test_xxx`（36 ファイル）と `testXxx`（12 ファイル）が混在。
- [確認] `test:SuggesterRefactoringTest.java` は**作業都合（リファクタリング）が名前**になっており、4 つの関心事が同居して `SuggesterIndexLifecycleTest` / `SuggesterResourceLoadingTest` と重複している。
- [提案] JUnit 4 へ寄せ、メソッド名を `test_xxx` に統一（多数派）。`SuggesterRefactoringTest` は関心事ごとに既存クラスへ振り分けて解体する。JUnit 5 移行は別途判断。

#### J-02 常に成功するテスト — P1 [不変] [境界外]
- [確認] `test:converter/ReadingConverterChainTest.java`（30 行）の `test_convert()` は、本体が丸ごと TODO コメント。**アサーションゼロで必ず成功する。** `test:converter/KatakanaConverterTest.java`（27 行）も同様。
- [確認] `KatakanaConverter`（160 行）は既定構成から未使用（0001 §9-8）で、テストも空。つまり**このクラスは実質的に無検証**。
- [確認] **アサーションが 1 つも無いテストメソッドが 16 件**。内訳は `test:request/suggest/SuggestRequestQueryBuildingTest.java:386,393,400,406,412,418,424,430`（setter を呼ぶだけ）、`test:index/SuggestIndexerErrorHandlingTest.java:403,457,464,471`、`test:SuggesterIndexLifecycleTest.java:348`、`test:converter/AnalyzerConverterTest.java:136,331`、`test:util/SuggestUtilTest.java:403`。いずれも「例外が飛ばないこと」のスモークだが意図がコメントにしか書かれていない。
- [確認] `assertTrue(true)` が 3 箇所（`test:settings/BadWordSettingsTest.java:67,76,83`）。空の `@Before` が 2 件（`test:entity/ElevateWordTest.java:36`、`test:util/SuggestUtilTest.java:82`）。
- [確認] `@Ignore` / `@Disabled` は 0 件。無効化は「中身を消す」形で行われており、**ツールから無効化テストとして検出できない**。
- [提案] 空テストは実装するか削除する。アサーション無しのスモークは `assertDoesNotThrow` 相当の明示的な書き方に変え、意図をコードで表す。

#### J-03 未使用コードにだけテストがある — P1 [不変] [境界外]
- [確認] main から未使用なのにテストクラスが存在するもの: `MapValueExtractor`（`test:util/MapValueExtractorTest.java`）、`SettingsResourceLoader`（`test:util/SettingsResourceLoaderTest.java`）、`SuggestUtil.createBulkLine`（`test:util/SuggestUtilTest.java` の 6 箇所）。
- [確認] これらは**テストがデッドコードを延命させている**構図。E-01〜E-03 の削除判断をテストが妨げる。
- [提案] E 章の判断（適用 or 削除）と同時にテストも処理する。

#### J-04 テストが内部構造に密結合 — P2 [不変] [境界外]
- [確認] `test:settings/BadWordSettingsTest.java:60` は `settings.badword().arraySettings.arraySettingsIndexName` と**フィールドを 2 段階たどって**検証している。`test:settings/ElevateWordSettingsTest.java:60` も同様。B-02（`protected` 可変フィールド）の縮小を、この種のテストが直接ブロックする。
- [確認] **リフレクションで private メンバを叩くテスト**が複数ある。`test:SuggesterRefactoringTest.java:87-88, 110-111, 141-142`（`getDeclaredMethod("getIndicesForAlias", String.class)` + `setAccessible(true)`）、`:233-234`（`getDeclaredField("EXPECTED_INDEX_COUNT")`）、`test:util/SuggestUtilTest.java:90-95`。**メソッド名・フィールド名が文字列リテラル**なので、A-02 で提案したリネームをしてもコンパイルは通り、実行時に初めて壊れる。
- [確認] `test:request/suggest/SuggestRequestQueryBuildingTest.java:442` の `TestableSuggestRequest`（60 行）は `SuggestRequest` を継承し、`:473-475 createQueryBuilder()` で**プロダクションの配線をテスト内に再実装**している。A-07（Deprecated トランポリンの解体）を行うと、テストが古い配線を検証したまま緑になる。
- [提案] 可視性縮小・リネームとセットで、公開 API 経由の検証に書き換える。リフレクション参照は最優先で外す。

#### J-05 境界 API の I/O 契約テストが無い — P1 [不変] [境界外]
- [確認] 組み込み OpenSearch を使う結合テストは 25 クラスあるが、**0001 §7.2 の境界 API をひとまとめに固定するテストは存在しない**（クラス単位の検証に留まる）。
- [確認] fess 側の結合検証は `fess:` の `SuggestHelperTest` のみ（0001 §8）。
- [提案] リファクタリング**着手前に**、`test-io-verifier` で境界 API の I/O 契約テストを固定する。対象は「登録 → index 状態 → suggest / popularWords 結果」と index ライフサイクル（create / switch / remove）。これが本書の他項目すべての安全網になる。

#### J-06 stub 自身を検証しているテスト — P1 [不変] [境界外]
- [確認] `test:analysis/SuggestAnalyzerTest.java` の 19 テストは、`setUp()`（`:35-39`）で `analyzer = testAnalyzer` としており、**検証対象は同ファイル `:375-449` に自作した `TestSuggestAnalyzer`**。この stub は `:384-411` で正規表現による単語分割まで自前実装しており、プロダクションの `AnalyzerSettings.DefaultContentsAnalyzer` は一度も実行されない。
- [確認] `test:converter/ReadingConverterTest.java` の 20 テストも同構造（stub は `:328`, `:386`, `:418`）。
- [確認] `test:SuggesterResourceLoadingTest.java:72-88` の `testTryWithResources_nullInputStreamSafety` は `try (InputStream is = null)` を書いて **Java 言語仕様を検証しているだけ**で、`Suggester` を import すらしていない。`:90-105`、`:184-198` も同様。
- [確認] 合計約 39 メソッド・約 900 行が、カバレッジ上は「テストがある」ように見えて**実装を一切守っていない**。
- [提案] 削除するか、プロダクション実装に対する検証に置き換える。B-04（ポートの脱 OpenSearch 化）を行う際、これらの stub は真っ先に陳腐化する。

#### J-07 結果が信用できないテスト — P1 [不変] [境界外]
- [確認] **別スレッド内のアサーションが握り潰される**: `test:index/contents/document/ESSourceReaderTest.java:138` と `:162` の `assertTrue` は `new Thread(() -> {...})` の中にあり、ワーカースレッドの `AssertionError` は `Thread.join()` に伝播しない。**失敗してもテストはグリーンになる。** `test:SuggesterTest.java:382` の `.error(t -> { ...; fail(); })` も同様。
- [確認] **無限ハングしうる待機**: `test:SuggesterTest.java:384` は `latch.await()`（タイムアウト無し）。同リポジトリの `test:concurrent/DeferredTest.java` は全箇所で `await(5, TimeUnit.SECONDS)` 等を使っており、ここだけ例外。CI ハングの要因になる。
- [確認] **再現不能な乱数**: `test:index/contents/document/ESSourceReaderTest.java:119` の `int threadNum = new Random().nextInt(20) + 1;` はシード無し。失敗時に値を知る手段は `:120` の `System.out.println` だけ（テスト全体で唯一の標準出力）。対照的に `test:util/TransliteratorUtilTest.java:170` は `new Random(20260915L)` と固定シードで、作法が割れている。
- [確認] `Thread.sleep` が 21 箇所（`DeferredTest` 15、`SuggesterRefactoringTest` 5、`SuggesterTest` 2）。`DeferredTest` は `CountDownLatch` と `Thread.sleep` が同一クラス内に併存しており、同期戦略が 2 本立っている。
- [提案] スレッド内例外を `AtomicReference<Throwable>` で収集して join 後に検証、`await` にタイムアウト、`Random` に固定シード。いずれも独立に適用できる。

#### J-08 共通基底クラスの不在とノード起動コスト — P2 [不変] [境界外]
- [確認] 共通フィクスチャは `test:SuggestTestServer.java`（148 行、ノード起動ラッパ）のみで、**抽象基底クラスは 0 件**。25 クラスがライフサイクル定型句（`@BeforeClass` / `@Before` / `@AfterClass` / static フィールド 3 点セット）をコピペしている。`settings/` 配下 5 クラスは `@BeforeClass` も `@Before` も**完全一致**。
- [確認] **クラスタ名 `"ArraySettingsTest"` を 6 クラスが共有**しており（`settings/` 配下 5 クラス + `SuggesterBuilderTest`）、失敗ログからどのクラスのノードか判別できない。`test:normalizer/DefaultNormalizerTest.java:40` は id に `"SuggesterTest"` をコピペしたまま。
- [確認] **`SuggesterBuilderTest` だけがテストメソッドごとにノードを起動**する（JUnit 3 の `setUp`/`tearDown` 由来、`:34, :41`）。`DefaultNormalizerTest` は `@Test` 1 個のためにノードを起動する。フルランでのノード起動は計 26 回。
- [確認] `prepareDelete("_all")` を毎テスト実行している箇所が 15 件。`modules/fess-suggest/CLAUDE.md` の「Clean only test-specific indices (not `_all` unless needed)」という自プロジェクト規約に反している。
- [提案] 抽象基底クラス（または `@ClassRule` / `Suite`）を 1 つ用意して定型句を吸収する。[推測] `settings/` 系 6 クラスは 1 ノードに集約できる。

#### J-09 テストソースにベンダリングされた解析プラグイン — P2 [要判断] [境界外]
- [確認] `src/test/java/org/codelibs/opensearch/extension/` 配下に **26 ファイル・約 1,980 行**。`ExtensionPlugin`（95 行）が char filter 3・token filter 18・tokenizer 3 を登録し、`test:SuggestTestServer.java:47,86` から埋め込みノードに読み込まれる。テスト対象ではなく**テストフィクスチャとしてのプロダクションコード**。
- [確認] 登録される 24 個のうち、`src/main/resources/suggest_indices/suggest_analyzer.json` から参照されるのは `reloadable_kuromoji_tokenizer` / `reloadable_kuromoji_part_of_speech` / `reloadable_kuromoji_readingform` の **3 個のみ**。残り 21 個は main・test とも参照ゼロ。
- [確認] 特に `ngram_synonym`（`test:.../extension/ExtensionPlugin.java:91` で登録）は他に参照が無く、`NGramSynonymTokenizer`(508 行) + `NGramSynonymTokenizerFactory`(65 行) + `SynonymLoader`(197 行) = **約 770 行が未使用**。
- [確認] ベンダリング元の TODO がそのまま残っている（`test:.../extension/analysis/NGramSynonymTokenizerFactory.java:47`、`NGramSynonymTokenizer.java:200`）。
- [確認] `src/test/java` に置かれているため、formatter / license / jacoco の対象になり、本体の変更差分に混ざる。
- [提案] 未使用の 21 個を削除するか、テスト専用モジュール（または `fess-analysis-extension` の test-jar 依存）へ外出しする。削除はテスト環境の解析器構成を変えるため [要判断]。

### K. ビルド・静的解析

#### K-01 静的解析プラグインが無い — P1 [不変] [境界外]
- [確認] `modules/fess-suggest/pom.xml` のプラグインは compiler / source / formatter / surefire / javadoc / jar / license / jacoco の 8 個。**SpotBugs・Checkstyle・PMD・ErrorProne・NullAway は無い**。親 POM（`~/.m2/.../fess-parent-15.9.0-SNAPSHOT.pom`）にも無いことを確認。
- [確認] 本書の E 章（未使用コード 11 件）、C-03（null 検査の欠落）、F-02（cause の破棄）、G-01（ログのガード誤用）は、いずれも一般的な静的解析で機械検出できる種類のもの。**検出手段が無いために蓄積した**と [推測] される。
- [提案] リファクタリングの**最初の一手**として、警告を出すだけ（`failOnError=false`）で SpotBugs か ErrorProne を導入する。既存の指摘を棚卸ししてから段階的に `failOnError` を上げる。これにより、以降の劣化を自動で止められる。

---

## 3. 機能変更に当たる可能性がある項目（[要判断]）一覧

本書で [要判断] を付けた 18 件に加え、0001 §9-7 の挙動非対称 4 件を再掲する。**いずれも本タスクでは「変更しない」判断がデフォルト**で、機能面の是非は `improve_point.md` の担当。

| 項目 | 変わりうる挙動 | 本書での扱い |
| --- | --- | --- |
| C-05 / C-06 | 不正ドキュメント読み込み時の例外種別・既定値 | 設計書に判断事項として記録 |
| C-08 | 空のタグフィールド設定時の登録内容 | 同上 |
| D-03 | `Suggester` の index 作成が競合時に成功扱いになる | 同上（入れる方が正しい） |
| D-07 | トルコ語ロケールでの index 名 | 同上 |
| E-10 | クエリログ経路の削除 = ライブラリ機能の削除 | スコープ外を推奨 |
| F-01 | `catch (SuggesterException)` が settings 系も捕まえる | 実施を推奨（fess の既存 catch は壊れない） |
| F-03 / F-04 / F-05 / F-06 / F-07 | 失敗の伝わり方・伝わる件数 | F-01 とセットで設計方針を決めてから |
| F-09 | 中断時に「成功」で resolve されなくなる | 実施を推奨（現状は不正確） |
| H-01 / H-06 | リソースの解放タイミング | H-06 は実施を推奨 |
| I-01 / I-02 | 旧メソッド名の削除時期、`scrollSize` 既定値 | 旧名は残す |
| J-09 | テスト環境の解析器構成（未使用 21 個の削除） | 実施を推奨（テストのみに影響） |
| 0001 §9-7（roles 既定値、`removeDisableIndices` の前方一致、`restoreElevateWord` の再保存、bad word の部分一致） | サジェスト結果・削除対象 | 本書では触れない |

---

## 4. 推奨する着手順

段階ごとに「終わった時点でビルドとテストが通る」ことを条件にする。

| フェーズ | 内容 | 主な項目 | リスク |
| --- | --- | --- | --- |
| **0. 安全網** | 境界 API の I/O 契約テストを固定。信用できないテストを先に直す。静的解析を警告のみで導入 | J-05, J-07, K-01 | 低 |
| **1. 除去** | デッドコード・未使用 import・dead field・未使用定数・偽陽性テストを削除 | E-03〜E-09, E-11, G-03, I-03, I-04, J-02, J-03, J-06, J-09 | 低（純粋削除） |
| **2. 集約** | 共通ユーティリティの適用と重複の解消。テスト基底クラスの導入 | D-01, D-02, D-04, D-05, D-06, D-08, D-10, E-01, E-02, J-01, J-08 | 低〜中 |
| **3. 境界** | 可視性の縮小、旧オーバーロード削除、Deprecated トランポリンの解体 | A-04, A-07, B-01, B-02, B-05, J-04 | 中（外部利用者に影響） |
| **4. 状態** | リソース管理と並行性の整理 | C-02, H-02〜H-05, H-07, A-03 | 中 |
| **5. 構造** | パッケージ循環の解消、責務分割、ポートの脱 OpenSearch 化 | A-01, A-02, A-05, A-06, B-04, C-01 | 中〜高 |
| **6. 方針** | 例外・エラー伝搬・ログの統一（[要判断] を含むので個別に確認） | F 章, G 章 | 要判断 |

- 表に無い項目のうち、[要判断] のものは §3 の判断後に該当フェーズへ入れる。B-03・C-03・C-04・C-07 は各フェーズで対象クラスに触れる際に併せて行う（D-09 は B-05 の削除で解消）。
- フェーズ 1 と 2 だけでも、main は概算 **800〜1,000 行（約 7〜8%）**、test は **1,600〜1,800 行（約 10%）** 減る見込み（E-01 を削除側で判断した場合。main: `MapValueExtractor` 275 + `createBulkLine` 39 + `SuggestBulkFileWriter` + dead メソッド群 / test: J-06 の約 900 行 + J-09 の未使用 21 個、いずれも [推測]）。
- J-05 と J-07 をフェーズ 0 に置くのが本計画の要。ここを先に固めないとフェーズ 3 以降のリスクを正しく評価できない。
- 「機能変更が容易になる構成」という要件に直接効くのは **B-04（ポートの脱 OpenSearch 化）** と **C-01/A-03（不変な構成オブジェクト）**。0001 §9-1「テキスト処理を差し替え可能にする」は、B-04 を先にやらないと着手できない。

---

## 5. 未解決の問い

1. **公開 API の縮小（B-01 / B-02）をどこまでやるか。** fess は 13 型しか import していないが、fess-suggest は Maven Central 相当（`maven.codelibs.org`）に公開されているライブラリで、**fess 以外の利用者が存在するか**は未確認。存在するならメジャーバージョン境界での実施が必要。
2. **`MapValueExtractor` / `SettingsResourceLoader` を「適用」するか「削除」するか**（E-01 / E-02）。適用すると C-05 の挙動が変わる（[要判断]）。削除すると重複は残る。判断が要る。
3. **クエリログ経路（E-10）を残すか。**（ライブラリ機能の削除。§3）
4. **例外階層の変更（F-01）を今回に含めるか。** 含めるなら F-03〜F-07 のエラー伝搬統一まで一括で方針を決める（§3）。
5. **fess 本体側の修正（H-01 の `@PreDestroy`）を本タスクのスコープに含めるか。** fess-suggest 側だけでは塞げない。
6. **文字コード明示（D-02）の影響範囲。** 現在の実行環境（`file.encoding`）が UTF-8 なら完全に [不変]。Java 18 以降は既定 UTF-8 なので [推測] 実害は無いが、fess の起動スクリプトで `-Dfile.encoding` が指定されていないかの確認が要る。
7. **ベンダリングされた解析プラグイン（J-09）の出所と同期方針。** `test:org/codelibs/opensearch/extension/` の 26 ファイルが `fess-analysis-extension` 等の上流からのコピーだとすると、**上流が更新されたときに追従する手段が無い**。削除・外出し・現状維持のいずれを選ぶかは、上流との関係を確認してから決める必要がある。
8. **テストの偽陽性（J-06）をどう扱うか。** 約 900 行を単純に削除するとカバレッジ数値が下がるため、指標を見ている場合は事前合意が要る。実質的な検証力は変わらない（むしろ正確になる）。
