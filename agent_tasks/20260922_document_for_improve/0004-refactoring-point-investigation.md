# 作業履歴: リファクタリング観点の問題点・改善点の洗い出し（事前作業）

- タスク: `20260922_document_for_improve`（要件: [0000-requirements-definition.md](./0000-requirements-definition.md)）
- 実施日: 2026-09-23
- 担当: tech-architect（メインセッションから委譲）

## 目的

要件定義の事前作業「リファクタリング観点の問題点、改善点を箇条書きでまとめる」を行う。[0001](./0001-current-implementation-overview.md) §9 の 9 項目を出発点にしつつ、丸写しにせず実コードで裏を取り、観点を広げて洗い出す。本タスクの対応内容は「機能変更を行わないリファクタリング。ただし機能変更が容易になる構成を検討する」なので、**各項目が機能変更に当たるかどうかを明示する**ことを重視した。

## 成果物の配置についての判断

要件定義（`0000:15`）は成果物パスを `task_docs/refactoring_point.md` と記載している。作成時点では `task_docs/` ディレクトリが存在しなかったため、いったんプロジェクト規約（CLAUDE.md / `.claude/rules/task-general-rule.md`）の採番に従い `0003-refactoring-point.md` として作成した。

その後ユーザーの指示により、タスクディレクトリ配下に `task_docs/` を作成し、成果物を `agent_docs/tasks/20260922_document_for_improve/task_docs/refactoring_point.md` へ移動した。要件定義の記載が正となる。本作業履歴は従来どおり採番方式（`0004`）で残す。

## 実施内容

### 調査範囲

- fess-suggest main 全 65 ファイル（約 11,860 行）
  - 自分で通読したもの: `Suggester`、`SuggesterBuilder`、`SuggestIndexer`、`SuggestItem`、`SuggestItemSerializer`、`SuggestItemMerger`、`Deferred`、`SuggestIndexWriter`、`SuggestWriter`、`IndexingOperations`、`DeletionOperations`、`ContentIndexingOperations`（public メソッド一覧）、`SuggestSettings`、`AnalyzerSettings`（`DefaultContentsAnalyzer` / `getAnalyzerName` / `checkAnalyzer`）、`BadWordSettings`、`SuggestUtil`（ファクトリ・`createBulkLine`）、`PitOperationHelper`、`ESSourceReader`（PIT 周辺）、`NormalizerChain`、`SuggestAnalyzer`、`ElevateWord`、`RequestBuilder` 系、`FieldNames` / `SuggestConstants`、`exception` 3 クラス
  - 残りはサブエージェントの報告を受けて該当箇所だけ確認
- fess-suggest test 全 80 ファイル（テストクラス 53 + `SuggestTestServer` + extension 26）
- fess 側: `SuggestHelper`、`SystemHelper.reloadConfiguration`、`AdminBackupAction`、fess-suggest の import 一覧
- `pom.xml` とローカル `~/.m2` の `fess-parent-15.9.0-SNAPSHOT.pom`（静的解析プラグインの有無）

### 機械的な検査

読解だけでは漏れる観点を、スクリプトで網羅的に確認した。

| 検査 | 手段 | 結果 |
| --- | --- | --- |
| パッケージ依存の循環 | import 文を Python で集計 | 2 者間の循環が 5 組（`settings⇄util`、`converter⇄util`、`entity⇄util`、`concurrent⇄request`、`index⇄index.operations`） |
| メソッド長 | 波括弧の深さを追う Python スクリプト | 最長は `KatakanaToAlphabetConverter.generateConvertMapping` 171 行、以下 `checkAnalyzer` 67、`mergeChar` 66、`processRequest` 63 |
| クラス可視性 | `grep` + `uniq -c` | main 65 ファイルすべて `public`（package-private ゼロ） |
| `protected` 可変フィールド | `grep` | 51 個 |
| 定数の使用回数 | `FieldNames` の各定数を両モジュールで `grep` | `FieldNames.ID` が 0 件 |
| main からの未使用クラス・メソッド | `grep -rn` で main / test を分離して集計 | `MapValueExtractor`・`SettingsResourceLoader`・`createBulkLine`・`getTotalHitCount` ほか |
| fess からの依存 | `import` 行の抽出 | fess が import する fess-suggest の型は 13 種のみ。継承は 0 件 |

### 使用したサブエージェント

観点を 4 つに分け、`Explore` を並列で実行した。**各エージェントの報告は、重要な主張を自分で実コードに当たって検証してから採用した**（検証で誤りが見つかったものは下記「検証で訂正した点」参照）。

| エージェント | 担当観点 | 成果物への反映先 |
| --- | --- | --- |
| Explore #1 | リソース管理（Client / threadPool / PIT / InputStream / スレッドセーフティ） | H 章、D-02 |
| Explore #2 | ログ出力と例外ハンドリング（catch 53 件の分類、例外階層） | F 章、G 章 |
| Explore #3 | 重複コードとマジックナンバー・定数管理 | D 章、E 章 |
| Explore #4 | テストの保守性 | J 章 |

### 自分で検証して採用した主な指摘

サブエージェントの報告のうち、結論を左右するものは以下を実コードで再確認した。

- `fess:helper/SystemHelper.java:915,919` → `SuggestHelper.init()` の再呼び出し。`SuggestHelper` に `@PreDestroy` が無く（`:114` は `@PostConstruct` のみ）、`:142` で新しい `Suggester`＝新しいスレッドプールを作って上書きすることを確認。呼び出し元は `fess:app/web/admin/backup/AdminBackupAction.java:283`。→ H-01
- `index/contents/document/ESSourceReader.java:229-232` が上限到達時に `releasePit()` を呼ばないことを確認。→ H-06
- `settings/AnalyzerSettings.java:163-164` と `settings/ArraySettings.java:363-364` が `IOException e` を受け取りながら cause に渡していないこと、メッセージが同一であることを確認。→ F-02
- `index/contents/DefaultContentsParser.java:302-308` の `isDebugEnabled()` ガード内 `logger.warn` を確認。→ G-01
- `index/operations/DeletionOperations.java:211-212` が `deleteByQuery` の戻り値を捨てていることを確認。→ F-05
- `exception/SuggestSettingsException.java:31` が `RuntimeException` を直接継承していることを確認。→ F-01
- `settings/AnalyzerSettings.java:184-200` の `getAnalyzerName` が static キャッシュの戻り値を null チェックせず使うことを確認。→ H-03
- `test:index/contents/document/ESSourceReaderTest.java:119`（シード無し `Random`）、`:138`（`new Thread` 内の `assertTrue`）、`test:SuggesterTest.java:382,384`（コールバック内 `fail()` とタイムアウト無し `latch.await()`）を確認。→ J-07
- `test:analysis/SuggestAnalyzerTest.java:35-39` が自作 stub を検証対象にしていること、`test:SuggestTestServer.start()` のクラスタ名 `"ArraySettingsTest"` が 6 クラスで重複していること、`test:SuggesterBuilderTest.java:34,41` が JUnit 3 の `setUp`/`tearDown` でテストごとにノードを起動することを確認。→ J-06、J-08

### 検証で訂正した点

- Explore #2 は「`QueryLogReader` が `AutoCloseable` を実装していないため try-with-resources が使えない」と報告したが、`index/contents/querylog/QueryLogReader.java:24` は `extends Closeable` であり **try-with-resources は使える**。原因の説明が誤りだったため、成果物では「`finally { close() }` と try-with-resources の書き方が割れている」という事実のみを F-06 の周辺で扱い、誤った原因説明は採用しなかった。
- Explore #3 は `SuggestRequest` の `@Deprecated` メソッド群を「削除できない絡み合い」と報告したが、自分で `request/suggest/SuggestRequest.java:329-392` を読んだ結果、**`processRequest` が `:339, :342, :382` で実際に呼んでおり、匿名サブクラスによる override 温存のトランポリンになっている**ことが分かった。成果物では A-07 として、この構造と「fess は一切継承していない」という事実をセットで記載した。
- 0001 §9 の記述のうち、`SuggestItem.emptySource` について「マージ時にしか受け渡されない」とあった点を掘り下げ、**書き込み経路（`toUpdatedSource`）では一度も参照されない**こと、`@timestamp` の表現が ISO 文字列と epoch millis で食い違うことを確認して C-02 に格上げした。

### 0001 §9 との関係

§9 の 9 項目はすべて本書に引き継いだ上で、対応関係を次のようにした。

| 0001 §9 | 本書での扱い |
| --- | --- |
| 1. `_analyze` への強結合 | **B-04 に具体化。** ポート `SuggestAnalyzer` が OpenSearch の `AnalyzeToken` を返すため、§9-1 の提案は現状のままでは実現できないことを新たに指摘 |
| 2. N+1 / read-modify-write | 本書では扱わない（性能・機能の論点。`improve_point.md` 側）。ただし A-06（`mergeItems` の O(n²)）と C-02（1 件ごとの HashMap 割り当て）は純粋リファクタリングとして分離した |
| 3. 設定アクセスのコストと状態の持ち方 | A-03、H-03〜H-05 に分解。`indexer()` 1 回あたり PIT 2 セット + GET 4 回という内訳を追加 |
| 4. ファサードの肥大化 | A-02、A-03、A-04 に分解 |
| 5. 境界が広すぎる | B-01、B-02、B-03、B-05 に分解。「全 65 クラスが public」「protected 可変フィールド 51 個」「fess が import するのは 13 種のみ」という定量的な裏付けを追加 |
| 6. 非同期・エラーモデルの不統一 | F 章（9 項目）に展開 |
| 7. 挙動の非対称・潜在的な不具合 | 機能面なので本書では深入りせず、§3 の [要判断] 一覧に再掲するにとどめた |
| 8. デッドコード・命名の負債 | E 章（11 項目）と I 章（4 項目）に展開。`MapValueExtractor`・`PitOperationHelper.getTotalHitCount`・`FieldNames.ID`・`SuggestConstants.DEFAULT_TYPE`・`AnalyzerSettings` の 3 メソッドを新規に追加 |
| 9. 設定とスキーマの管理が分散 | 機能変更（データ移行）を伴うため本書の対象外。§5 の未解決の問いには含めていない（0001 の判断を踏襲） |

### 新たに追加した主な観点（§9 に無かったもの）

- パッケージ依存の循環と層の逆転（A-01、A-05）
- 不変性・null 安全性（C 章 8 項目）。特に `Objects.requireNonNull` が `Suggester` にしか無く、`modules/fess-suggest/CLAUDE.md` の規約と乖離している点
- リソース管理と並行性（H 章 7 項目）。fess 側の実リーク経路を含む
- ログ（G 章 4 項目）
- ビルダーの一貫性（I-01。`addLang` vs `addLanguage`、3 通りの命名規約）
- テストの保守性（J 章 9 項目）
- 静的解析プラグインの不在（K-01）。E 章・C-03・F-02・G-01 が機械検出可能な種類であることから、検出手段の欠如が蓄積の一因と [推測] した

## 成果物

- [task_docs/refactoring_point.md](./task_docs/refactoring_point.md)（667 行）
  - 凡例、評価軸（優先度 P1〜P3 / 機能変更 [不変]・[要判断] / API 影響 [境界外]・[境界内]）
  - 全 75 項目の一覧表（A〜K の 11 カテゴリ）と、根拠 `file:line` つきの詳細
  - [要判断] 18 件の一覧（0001 §9-7 の 4 件を再掲）
  - 6 フェーズの着手順と、未解決の問い 8 件
  - 内訳: P1 27 件 / P2 35 件 / P3 13 件、[境界内] 13 件
- 本ファイル（作業履歴）

要件は「数百行規模に収める」と戒めているが、項目数が 75 に達したため 669 行になった。1 項目あたり平均 9 行で、大半が `file:line` の根拠行である。**一覧表だけ読めば全体を把握できる構成**にして冗長な散文を避けたが、分量が過大であれば P3 の 13 項目を一覧表のみに圧縮することで約 60 行削減できる。

## 検証の前提

- fess-suggest: HEAD `f7a8039a65c86dbdd68acc32bf96ccabc2b65d26`（#100、version 15.9.0-SNAPSHOT）。作業開始時点で working tree はクリーン
- fess: HEAD `8a9e1e15c`（version 15.9.0-SNAPSHOT）
- 依存とプラグインは `modules/fess-suggest/pom.xml` とローカル `~/.m2` の `fess-parent-15.9.0-SNAPSHOT.pom` で確認
- **テスト・ビルドは一切実行していない**（`mvn test` / `mvn compile` とも未実行）。記述はすべて静的なコード読解と機械的な `grep` / スクリプト集計に基づく
  - したがって「未使用」と判定したコードは**静的参照が無いこと**の確認であり、リフレクション経由の利用は検出していない（`test:SuggesterRefactoringTest` と `test:util/SuggestUtilTest` がリフレクションを使うことは確認済みで、対象は `getIndicesForAlias` / `EXPECTED_INDEX_COUNT` / private コンストラクタ）
  - 行数の削減見込み（§4）は概算であり、実測ではない
- ソースコードは変更しておらず、git commit もしていない

## 後続タスクへの申し送り

1. **フェーズ 0 を最優先で実施する。** `test-io-verifier` に、0001 §7.2 の境界 API に対する I/O 契約テストを依頼する（J-05）。同時に J-07（アサーションが握り潰される 3 箇所、タイムアウト無し `latch.await()`、シード無し `Random`）を直さないと、以降のフェーズで「テストが緑」の意味が薄い。
2. **ユーザー判断が必要な項目**（[refactoring_point.md](./task_docs/refactoring_point.md) §5 の未解決の問い 8 件）。特に次の 3 つは、着手前に方針を決める必要がある。
   - 公開 API の縮小（B-01 / B-02）をどこまでやるか。fess 以外の利用者の有無が未確認
   - `MapValueExtractor` / `SettingsResourceLoader` を「適用」するか「削除」するか（E-01 / E-02）
   - クエリログ経路（E-10）を残すか。削除できれば `lucene-queryparser` 依存も外せる
3. **fess 本体側の修正**（H-01 の `@PreDestroy` 追加）を本タスクのスコープに含めるかを確認する。fess-suggest 側だけではスレッドプールのリークを塞げない。
4. **「機能変更が容易になる構成」という要件に直接効くのは B-04（`SuggestAnalyzer` の戻り値を自前型にする）と C-01 / A-03（不変な構成オブジェクト化）**。0001 §9-1「テキスト処理を差し替え可能にする」は B-04 を先にやらないと着手できない。設計書ではこの依存関係を明示すること。
5. **機能観点のドキュメント（`improve_point.md` 相当）へ渡す項目**: 0001 §9-2（N+1 書き込み）、§9-7 の挙動非対称 4 件、[refactoring_point.md](./task_docs/refactoring_point.md) §3 の [要判断] のうち挙動が変わるもの。本書では深入りしていない。
6. **本書の項目 ID（A-01 〜 K-01）は設計書・作業プランから参照できるよう安定させる。** 追加が出た場合は末尾に採番し、既存 ID は振り直さない。
