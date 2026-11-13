# 0017 ステップ A-6 のレビュー指摘の反映（2026-09-04）

**対象**: `0007-phase-a-fess-precede.md` §6（ステップ A-6 = **R0** 分のテスト）の実施結果に対する外部レビュー（**要修正**。Major 2 / Low 1）。

**結論**: **3 件すべてを妥当と判断し、すべて是正した** [確認]。**Major 2 件はいずれも「テストが実際には検証していない」という指摘であり、実行可能なテストに置き換えた。** **設計書（`docs/0003-migration-ops-design.md`）は第 16 版のまま無改訂であり、新しい X 番号も MO 番号も起こしていない**（判定は §4）。**`modules/fess-suggest` は無変更である**（C-01）[確認]。

**検証**: **`mvn test`（`modules/fess` 全体）= `Tests run: 7468, Failures: 0, Errors: 0, Skipped: 0` / `BUILD SUCCESS`** [確認]。**A-6 完了時点の 7461 件に対して +7 であり、本書で追加した 7 件と一致する。**

---

## 1. 指摘 3 件と判定

| # | 指摘 | 判定 | 対処 |
| --- | --- | --- | --- |
| **1**（Major） | **T-S1 の完了条件を満たしていない。** `SuggestCreatorTest` の構造検査はソース文字列の順序を確認するだけで、`exitCode != 0` のときに実際に `switchIndex()` / `removeDisableIndices()` が呼ばれないことを実行検証していない | **妥当** [確認]。`0007` §6.3 の 3 と §6.5 の 8 が自らこの限界を認めている（「実施（ただし代替手段）」） | **`create()` を実際に走らせる制御フローテスト 5 件を追加した**（§5）。**そのために production 側へ差し込み口を 1 つ作った**（§3） |
| **2**（Major） | **X-7 / MO-27 の本質である「次世代件数を更新エイリアスから取得する」ことにテストが無い。** `canSwitchByWordsNum` の純関数検査は `getNextGenerationWordsNum()` が `.update` エイリアスを検索することを保証しない。**検索エイリアスへ戻す回帰でも現状のテストは通る** | **妥当** [確認]。**A-6 が MO-27 に対して持っていたのは呼び出し元の grep 検査（`SuggestHelperRebuildIsolationTest:186`）だけであり、これは「どのエイリアスを数えるか」を 1 つも見ていない** | **`(fess test) helper/SuggestHelperNextGenerationCountTest.java` を新設し、数えに行く索引名を実行時に捕まえる形にした**（§5）。**指摘どおりの回帰（検索エイリアスへ戻す）で赤くなることを確認済み**（§6 の 2） |
| **3**（Low） | **ソース構造を検査するテストが相対パス `src/main/java` に依存する。** `modules/fess` を作業ディレクトリにする必要があり、IDE や CI の実行方式によっては機能と無関係に失敗する | **妥当** [確認]。該当は 3 ファイル（`SuggestCreatorTest` の構造検査 ／ `SuggestHelperRebuildIsolationTest` の grep 検査 2 件 ／ `SuggestIndicesResourceTest` の 2 件） | **`(fess test) unit/ModulePaths.java` を新設し、production クラスのロード元（`<module>/target/classes`）からモジュール根を導くようにした。** 作業ディレクトリは fallback にのみ使う（§5 / §6 の 5） |

> **指摘 3 件のいずれも「設計が間違っている」ではなく「検証が足りない」である** [確認]。**したがって是正は `0003` の決定（MO-24 / MO-25 / MO-27・G1 / G3 の内容）を 1 つも動かしていない。**

---

## 2. 変更したファイル（production **2** ＋ テスト **6**）

| # | ファイル | 区分 | 変更 |
| --- | --- | --- | --- |
| 1 | `(fess) exec/SuggestCreator.java` | **production・改変** | **`create()` の可視性を `private` → package-private に変えた**（`:264`）。**実行文は 1 行も変えていない** [確認] |
| 2 | `(fess) helper/SuggestHelper.java` | **production・改変** | **`getNextGenerationWordsNum()`（`:423`）の検索チェーンを `protected long countWordsInIndex(String)`（`:438`）へ切り出した。** 呼び出し側は `countWordsInIndex(suggester.getIndex() + UPDATE_ALIAS_SUFFIX)` の 1 行になった。**エイリアス名の組み立て・クエリ・timeout はいずれも無変更** [確認] |
| 3 | `(fess test) exec/SuggestCreatorTest.java` | **改変** | **`create()` を走らせる制御フローテスト 5 件を追加**（`:392` / `:410` / `:431` / `:452` / `:469`）＋ スタブ 3 種（`:480` / `:494` / `:550`）。**構造検査（`:365`）と既存の純関数検査は残した**（§8 の 3）。**パス解決を `ModulePaths` へ**（`:366`） |
| 4 | `(fess test) helper/SuggestHelperNextGenerationCountTest.java` | **新規**（79 行・**2 件**） | **MO-27 の検証**。`getNextGenerationWordsNum()` が数えに行く索引名を `countWordsInIndex` の override で捕まえ、`fess.suggest.update` であることを assert する（`:39` / `:50`） |
| 5 | `(fess test) unit/StubSuggester.java` | **新規**（159 行） | **実クラスタに触れない `Suggester`。** ライフサイクル呼び出し（`createNextIndex` / `switchIndex` / `removeDisableIndices`）を記録する。3 と 4 の両方が使う |
| 6 | `(fess test) unit/ModulePaths.java` | **新規**（114 行） | **モジュール根の解決**（指摘 3 への対処） |
| 7 | `(fess test) helper/SuggestHelperRebuildIsolationTest.java` | **改変** | **パス解決を `ModulePaths.sourceRoot()` へ**（`:199`）。**検査内容は無変更** |
| 8 | `(fess test) helper/SuggestIndicesResourceTest.java` | **改変** | **パス解決を `ModulePaths.resourcePath(...)` へ**（`:34`）。**検査内容は無変更** |

**追加したテストメソッドは 7 件である** [確認]（`SuggestCreatorTest` に 5 ＝ 31 → 36 件、新規クラスに 2）。

---

## 3. なぜ production を触ったのか（差し込み口の必要性）

**A-6 と同じ問題である** — **fess 本体側のこの領域は、DI の差し込み口を作らないと単体テストから観測できない。** **A-6 は `SuggestHelper` に seam 3 つを置いて解決した**（`0007` §6.4）。**本書はそれを 2 箇所に広げた。**

### 3.1 指摘 1（T-S1）に必要だったもの

| # | 必要なこと | 実物での確認 | 結論 |
| --- | --- | --- | --- |
| **1** | **`create()` をテストから呼べること** | **`private int create()` だった**（A-6 時点）。**`(fess) exec/SuggestCreator.java` の `create()` は `process(Options)`（`:224`）からしか呼ばれない** [確認] | **package-private にした。** **同一パッケージの `SuggestCreatorTest` からのみ見える。** リフレクション（`getDeclaredMethod("create")`）でも呼べるが、**メソッド名の変更が `NoSuchMethodException` という無関係な形で現れるため採らなかった** [提案] |
| **2** | **`ComponentUtil.getSuggestHelper()` がスタブを返すこと** | **`getComponent(String)` は LaContainer を先に引き、`ComponentNotFoundException` のときだけ `componentMap` へ落ちる**（`(fess) util/ComponentUtil.java:1076-1090`）。**`(fess test res) test_app.xml` は `suggestHelper` を宣言していない**（宣言は `(fess res) app.xml:64` であり、`test_app.xml` はこれを include しない）[確認] | **`ComponentUtil.register(helper, "suggestHelper")` がそのまま効く。** **production 変更は不要だった。** 登録は `UnitFessTestCase#tearDown` の `setFessConfig(null)` が `componentMap.clear()` するため次のテストへ漏れない（`ComponentUtil.java:1185-1192`）[確認] |
| **3** | **`suggestHelper.suggester()` が返す `Suggester` を観測できること** | **`Suggester` のコンストラクタは代入と `settings.getAsString(INDEX, "")` だけである**（`(sug) Suggester.java:138-153`）。**`SuggestSettings` のコンストラクタも代入だけであり、クラスタに触れるのは `get(...)` 以降**（`(sug) settings/SuggestSettings.java:164-173` ／ `:245-252`）[確認] | **`StubSuggester extends Suggester` が成立する。** **A-6 が「スタブ化できない」と判定したのは `SuggestIndexer` であって `Suggester` ではない**（`0007` §6.4 の 3 事実はすべて `SuggestIndexer` → `BadWordSettings` → `ArraySettings` の経路についてのものである）[確認]。**production 変更は不要だった** |

> **Mockito はこのモジュールのテスト依存に入っていない** [確認]（`mvn dependency:list` の test スコープは junit / junit-jupiter / hamcrest / utflute のみ）。**依存を増やす選択はしていない** — 手書きのスタブで足りる。

### 3.2 指摘 2（MO-27）に必要だったもの

**`getNextGenerationWordsNum()` の中身は `ComponentUtil.getSearchEngineClient().prepareSearch(...)....getTotalHits().value()` という 1 本のチェーンである。** **この形のまま「どの索引名を渡したか」を観測するには `SearchRequestBuilder` → `ActionFuture` → `SearchResponse` → `SearchHits` → `TotalHits` を全部作る必要があり**（`TotalHits` は Lucene の final クラス）、**テストの複雑さが検証したい 1 行に見合わない** [確認]。

**したがって「何を数えるか」（`suggester.getIndex() + UPDATE_ALIAS_SUFFIX`）と「どう数えるか」（検索チェーン）を分け、後者を `countWordsInIndex(String)` として切り出した。** **テストは前者だけを見る。** **これは MO-27 が定めた内容そのものである** — `0003` 第 16 版 §4.2 が是正したのは**どのエイリアスを数えるか**であって、検索の作り方ではない。

**振る舞いを変えていないことの根拠** [確認]:

| # | 論点 | 根拠 |
| --- | --- | --- |
| 1 | 切り出しは純粋な移動であり、クエリ・`setSize(0)`・`setTrackTotalHits(true)`・timeout の取得元はいずれも同一 | `(fess) helper/SuggestHelper.java:438-450` |
| 2 | エイリアス名の組み立ては呼び出し側に残っている | 同 `:423`。**`UPDATE_ALIAS_SUFFIX`（`:89`）も無変更** |
| 3 | 可視性は `protected` — A-6 の seam 3 つ（`:190` / `:205` / `:220`）と同じ流儀。**public API は広がっていない** | `0007` §6.4 の 4 と同じ判断 |

---

## 4. 逸脱区分の判定（**区分 II**。新しい X / MO 番号は起こさない）

| 問い | 判定 | 根拠 |
| --- | --- | --- |
| **設計書（`0003`）の記述と矛盾するか** | **しない** | **§11.1 の T-S1 は「`exitCode != 0` のとき切替が起きないこと」を求めている。本書はそれを字義どおり満たす方向の変更であり、要求を緩めていない。** §11.1 / §11.3 は差し込み口の方式を定めていない（`0007` §6.4 と同じ読み） |
| **MO-27 の内容が動いたか** | **動いていない** | **「次世代の件数は更新エイリアスに対して数える」という規則はそのままであり、本書はその規則に回帰検知を付けただけである** |
| **区分 I（設計判断の誤り・不足）か** | **否** | 設計判断を 1 つも動かしていない。**`docs/0003-migration-ops-design.md` は第 16 版のまま無改訂** |
| **区分 II（事実の更新）か** | **然り** | **プラン §4 ステップ A-6 の「対象」欄に production 1 ファイル（`SuggestCreator.java`）が増え、作業内容 3 の実施形態が「構造検査で代替」から「実行検査」へ変わった。** いずれも観測値・実施形態の更新である |
| **プラン §4 ステップ A-3 の作業内容 7「`create()` のシグネチャは変えない」との関係** | **可視性のみ変更した** [確認] | **同項の趣旨は「ガード判定部の切り出しのために `create()` を作り直すな」であり**（`0001` §9.2 の該当行 ＝ 3 回目レビューの指摘 4 への対処）、**本書は引数・戻り値・実行文を 1 つも変えていない。** **package-private 化は A-6 の T-S1 を成立させるために必要であり、A-6 の DoD（`0003` §11.1）が A-3 の書き方の制約に優先する** [提案]。**プラン §4 ステップ A-3 の該当行と A-6 の対象欄に、この 1 点を追記した** |
| **処理** | **プランに追記 ＋ 本書を作成** | プラン §4 ステップ A-6 の対象欄・作業内容 3 ／ §4 ステップ A-3 の作業内容 7 ／ §9.1 の台帳 ／ §9.2 の末尾注記 ／ `0007` §6.11（本書への参照） |

---

## 5. 追加・変更したテスト（7 件）

### 5.1 T-S1（指摘 1）— `create()` を実際に走らせる

**`RecordingSuggestHelper extends SuggestHelper`（`SuggestCreatorTest:494`）が `create()` の呼ぶ 7 メソッドだけを override し、`StubSuggester`（`:496`）と 1 本の呼び出し順リストを共有する。** **したがって「件数の取得」と「ライフサイクル操作」が 1 つの時系列に並ぶ。**

| # | テスト | 何を固定するか |
| --- | --- | --- |
| 1 | `test_create_doesNotSwitchTheIndex_whenTheRebuildReportedFailures`（`:392`） | **G3**: `storeAllBadWordsForRebuild()` が 1 を返す（＝ `exitCode = 1`）とき、**件数は十分でも `switchIndex()` / `removeDisableIndices()` が呼ばれない**こと。`createNextIndex()` は呼ばれていること（＝次世代の構築自体は走っている）。戻り値は 1 |
| 2 | `test_create_doesNotSwitchTheIndex_whenIndexingFromDocumentsFailed`（`:410`） | **G3 の非同期経路**: `indexFromDocuments` の error コールバックで `exitCode` が立つ場合も同じであること。**`0007` §6.6 の赤検査 6 では触れていなかった経路である** |
| 3 | `test_create_doesNotSwitchTheIndex_whenTheNextGenerationIsEmpty`（`:431`） | **G1**: 失敗が 0 でも、**次世代の件数が 0 なら切替に至らない**こと。戻り値は 1 |
| 4 | `test_create_switchesTheIndex_whenTheRebuildSucceededAndTheNextGenerationIsLargeEnough`（`:452`） | **反対側**。これが無いと 1〜3 は「`create()` がそもそも切替に到達できない」場合でも通ってしまう。**呼び出し順を `[getAllWordsNum, createNextIndex, getNextGenerationWordsNum, switchIndex, removeDisableIndices]` で等値検査しており、旧世代の件数が `createNextIndex()` の前に、次世代の件数がその後に取られることまで固定する**（MO-27 の前提） |
| 5 | `test_create_switchesTheIndex_onTheFirstRun_whenThereIsNoOldGeneration`（`:469`） | **初回**（旧件数 0）に割合判定が邪魔をしないこと。**`0003` 第 16 版が「初回の判定条件はエイリアス不在ではなく旧件数 0」と明記した点の実行検査である** |

### 5.2 MO-27（指摘 2）

| # | テスト | 何を固定するか |
| --- | --- | --- |
| 6 | `test_getNextGenerationWordsNum_countsThroughTheUpdateAlias`（`SuggestHelperNextGenerationCountTest:39`） | 数えに行く索引名が **`fess.suggest.update`**（更新エイリアス）であること ＋ 数えた値がそのまま返ること |
| 7 | `test_getNextGenerationWordsNum_derivesTheAliasFromTheConfiguredIndexName`（`:50`） | **エイリアス名が `suggester.getIndex()` から導かれる**こと（索引名を `custom.suggest.index` にすると `custom.suggest.index.update` になる）。**名前のハードコードを防ぐ** |

---

## 6. 「一度赤くなること」の確認

**production を一時的に壊し、意図したテストだけが落ちることを確認した。確認後はすべて元に戻し、最終状態で全緑を確認済みである** [確認]。

| # | 壊した箇所 | 落ちたテスト |
| --- | --- | --- |
| **1** | **`(fess) exec/SuggestCreator.java` のガード（`if (!canSwitchIndex(...))` のブロック）を丸ごと削除** | **`SuggestCreatorTest` が 4 件失敗** — 新規の 1 / 2 / 3（**期待どおり `[... switchIndex, removeDisableIndices]` まで進んでしまう**）＋ 構造検査 |
| **2** | **`(fess) helper/SuggestHelper.java:423` を `countWordsInIndex(suggester.getIndex())` に変更**（**＝ 指摘 2 が言う「検索エイリアスへ戻す回帰」そのもの**） | **`SuggestHelperNextGenerationCountTest` が 2 件とも失敗**（`expected: <fess.suggest.update> but was: <fess.suggest>`）。**A-6 時点のテスト一式はこの回帰で 1 件も落ちなかった** [確認] |
| **3** | **`(fess) exec/SuggestCreator.java` の `getAllWordsNum()` を `createNextIndex()` の後ろへ移動** | **テスト 4 が 1 件失敗**（`expected: <[getAllWordsNum, createNextIndex, ...]> but was: <[createNextIndex, getAllWordsNum, ...]>`） |
| **4** | **`canSwitchByWordsNum` の初回分岐を `return true` → `return false` に変更** | **2 件失敗** — 新規のテスト 5 ＋ A-6 の純関数検査（`SuggestCreatorTest:342`） |
| **5** | **作業ディレクトリの独立性**（指摘 3） | **壊す形の検査ではなく、`/tmp` を作業ディレクトリにして `ModulePaths` を実行し、`moduleRoot()` が `.../modules/fess` を返すことを確認した** [確認] |

---

## 7. 検証結果 [確認]

| # | 検証 | 結果 |
| --- | --- | --- |
| 1 | `SuggestCreatorTest` | **36 件・Failures 0 / Errors 0**（A-6 完了時 31 件 → +5） |
| 2 | `SuggestHelperNextGenerationCountTest` | **2 件・Failures 0 / Errors 0**（新規） |
| 3 | `SuggestHelperRebuildIsolationTest` / `SuggestHelperElevateWordTest` / `SuggestIndicesResourceTest` | **9 / 9 / 2 件・すべて緑**（パス解決の変更後も回帰なし） |
| 4 | **`mvn test`（`modules/fess` 全体）** | **`Tests run: 7468, Failures: 0, Errors: 0, Skipped: 0` / `BUILD SUCCESS`**（2026-09-04 実行）。**7461 → 7468 で差は 7、追加件数と一致** |
| 5 | `mvn formatter:format` / `mvn license:format` | **実行済み**（`modules/fess` の CLAUDE.md の規約） |
| 6 | `modules/fess-suggest` の `git status --short` | **空**（**無変更・読み取りのみ** — C-01）[確認] |
| 7 | コミット | **未実施**（ワークスペース CLAUDE.md の制約） |

---

## 8. 残る限界（**次の版で緩めないための明記**）

| # | 限界 | 誰が閉じるか |
| --- | --- | --- |
| **1** | **`countWordsInIndex(String)` の中身（`prepareSearch` のチェーン・`setTrackTotalHits(true)`・timeout）は実クラスタなしでは検証できない。** 本書のテストが固定するのは**渡す索引名**だけである | **R1 の `lifecycle.wordCountStats()` への移行**（`0003` 第 16 版 MO-27）と、**統合テスト**（T-F4 相当・後続タスク） |
| **2** | **`create()` のテストは `SuggestHelper` をスタブ化しているため、`SuggestHelper` 自身の実装は検査対象外である。** 両者の結合（`getAllWordsNum()` が検索エイリアスを見ていること等）は依然として未検証 | 同上（統合テスト） |
| **3** | **構造検査（`SuggestCreatorTest:365`）は残してある。** 実行検査と重複するが、**「ガード呼び出しがソース上 `switchIndex()` より前にあり、間に早期 `return` がある」という性質はこちらでしか見ていない**ため削除しなかった [提案] | — |
| **4** | **grep 検査 2 件（`SuggestHelperRebuildIsolationTest:173` / `:186`）の偽陽性の性質は A-6 のまま**（コメント中の言及も「呼び出し」と数える）。**本書はパス解決だけを変えた** | `0007` §6.5 の枠のまま |

---

## 9. スコープ外（変更していないもの）

| 対象 | 状態 | 理由 |
| --- | --- | --- |
| `modules/fess-suggest` 全体 | **無変更**（読み取りのみ）[確認] | **C-01** ／ **R0 は fess 本体側だけで出す**（`0003` §10.1） |
| `(fess test) helper/SuggestHelperTest.java`（既存 24 件の握り潰し構造） | **無変更** | **プラン A-6 の作業内容 8**（後続タスクの T-F1 で新規作成する） |
| **`(fess) exec/SuggestCreator.java` の実行文** | **無変更**（可視性の 1 語だけ） | **A-3 の実装判断に踏み込まないため**（`0007` §6.10 の 1 と同じ理由） |
| 統合テスト（`*Tests.java` / `@Tag("it")`） | **無変更・追加なし** | プラン A-6 の注意点 |
| 設計書 5 本 | **無変更** | §4 の判定（区分 II） |

---

## 10. プラン・作業履歴への反映

| 反映先 | 内容 |
| --- | --- |
| `0001-work-plan.md` §4 ステップ **A-6** | **対象欄**に production 2 ファイル目（`SuggestCreator.java` の可視性）を追記 ／ **作業内容 3** を「構造検査で代替」から「実行検査（＋構造検査を併置）」へ更新 ／ **作業内容 4** に MO-27 の実行検査を追記 |
| `0001-work-plan.md` §4 ステップ **A-3** | 作業内容 7 の「`create()` のシグネチャは変えない」に、**可視性のみ A-6 のレビュー反映で package-private になった**旨を追記 |
| `0001-work-plan.md` §9.1 | **台帳に 0017 を追加し、フェーズ B〜F を 0018〜0022 へ繰り下げた** |
| `0001-work-plan.md` §9.2 | **末尾注記に本書の 1 段落を追加**（設計書は無改訂であること） |
| `0007-phase-a-fess-precede.md` §6 | **§6.11 を新設**（本書への参照 ＋ §6.3 の 3・§6.5 の 8・§6.7・§6.8 の該当行がどう更新されたか） |
