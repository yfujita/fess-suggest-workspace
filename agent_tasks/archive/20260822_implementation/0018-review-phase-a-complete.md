# 0018: フェーズ A（R0 準備リリース）実施結果の総合レビュー（**独立検証**）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ A」の **全 5 ステップ（A-1 / A-2 / A-3 / A-4 / A-6）の実施結果に対するレビュー記録**である。**新しいステップではなく、実装の是正でもない。** 作業履歴 `0007`（および反映記録 `0008` / `0010` / `0014` / `0017`）の主張を、実物（コード・ビルド・テスト）で独立に再実行して検証し、未指摘の論点を洗い出したものである。
>
> **本書ではコードも設計書も一切変更していない** [確認]。指摘への対応は本書の完了後に別途判断する（§7）。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[要確認]** = 未解消 ／ **[推測]** = 実測していない推論
>
> **パス短縮表記**: `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/` ／ `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-09-07** |
| 対象 | **フェーズ A の全 5 ステップ**（A-1 / A-2 / A-3 / A-4 / A-6。**A-5 は 2026-08-31 に削除済み**） |
| ブランチ | `modules/fess` の **`feature/suggest-l1-precede`** |
| 検証時の作業ツリー | HEAD = **`73e912715`**（A-1 の実装）／ **A-2 / A-3 / A-4 / A-6 は未コミットの作業ツリー**（変更 6 ファイル ＋ 未追跡 6 ファイル）[確認] |
| コード変更 | **なし** [確認]（レビュー中に `git status --short` が変化していないことを確認済み） |
| 設計書の改訂 | **なし**（**逸脱手続きは発火していない** — 判定は §6） |
| 位置づけ | A-1 / A-2 に対する `0013`（通算 4 回目）、A-6 に対するレビュー（`0017` が反映した 5 回目）に続く **通算 6 回目**。**フェーズ A の全ステップが揃った状態を一度に見た点が過去 5 回と異なる** |

**結果: 指摘 5 件。うち是正の判断を要するのが 2 件（指摘 1・2、いずれも Medium）、改善提案が 2 件（指摘 3・4、Low）、記録のみが 1 件（指摘 5、Info）。R0 のリリースを止める性質の欠陥は 1 件も無い。**

---

## 1. 検証した事実 [確認]

**`0007` §7 と `0017` §7 が記録している値を、本書の執筆時点の作業ツリーで独立に再実行した。**

| # | 検証 | 結果 | 記録との一致 |
| --- | --- | --- | --- |
| 1 | `git status --short`（`modules/fess`） | **変更 6 ファイル ＋ 未追跡 6 ファイル** | `0017` §7 の 4 と一致（未追跡は `SuggestHelperElevateWordTest` / `SuggestHelperNextGenerationCountTest` / `SuggestHelperRebuildIsolationTest` / `SuggestIndicesResourceTest` / `unit/ModulePaths.java` / `unit/StubSuggester.java`） |
| 2 | `git status --short`（`modules/fess-suggest`） | **空**（無変更） | **C-01 を守っている** [確認] |
| 3 | `mvn -o test`（`modules/fess` 全体） | **`Tests run: 7468, Failures: 0, Errors: 0, Skipped: 0` / `BUILD SUCCESS`** | **`0017` §7 の 4 と完全一致** [確認] |
| 4 | フェーズ A の新規テスト 5 クラス単独実行 | **`BUILD SUCCESS`** | — |
| 5 | `grep -rn "number_of_replicas" src/main/resources/suggest_indices/` | **0 件** | `0007` §4.4 の 1 と一致 |
| 6 | `git diff HEAD~1 -- src/main/resources/` | **3 ファイル・各 1 行削除のみ**（`refresh_interval` / `number_of_shards` / `auto_expand_replicas` は据え置き） | A-4 の DoD 2 と一致 |
| 7 | `modules/fess-suggest` の `Suggester.java` | **`getSearchAlias(index)` = `index` ／ `getUpdateAlias(index)` = `index + ".update"`**（`:454-461`） | MO-27 の前提と一致 |

### 1.1 独立に確認した「記録が主張していない」健全性 [確認]

**レビューの主眼として、G1 の 2 つの件数が本当に比較可能かを実物で確かめた。** これが崩れると G1 は静かに誤判定するが、どの作業記録も明示的には検証していない。

| 観点 | 旧世代（`getAllWordsNum()`） | 次世代（`getNextGenerationWordsNum()`） | 判定 |
| --- | --- | --- | --- |
| 対象 | 検索エイリアス `index`（`(sug) Suggester.java:454-456`） | 更新エイリアス `index + ".update"`（`(fess) helper/SuggestHelper.java:422-423`） | **意図どおり** |
| クエリ | `matchAllQuery()`（`Suggester.java:424-426`） | `matchAllQuery()`（`SuggestHelper.java:441`） | **一致** |
| `setSize` | `0`（`Suggester.java:446`） | `0`（`SuggestHelper.java:440`） | **一致** |
| `setTrackTotalHits` | `true`（`Suggester.java:448`） | `true`（`SuggestHelper.java:442`） | **一致** |
| timeout | `suggestSettings.getSearchTimeout()` | `suggester.settings().getSearchTimeout()` | **一致** |

> **結論: 2 つの件数は同形のクエリで得られており、割合判定は成立する** [確認]。`getDocumentWordsNum()` / `getQueryWordsNum()` のような絞り込みクエリ（`Suggester.java:432` / `:439`）を片側だけに使っていれば比率が意味を成さなくなるが、そうなっていない。

**あわせて「数える時点で次世代のドキュメントが可視か」も確認した** [確認]。`create()` が `getNextGenerationWordsNum()`（`(fess) exec/SuggestCreator.java:337`）に到達する前に、次の 3 経路すべてが `refresh()` を通る。`Suggester.refresh()`（`(sug) Suggester.java:174-179`）は `prepareRefresh()` を**索引指定なし**で発行するため次世代も対象に入る。

| 経路 | refresh の位置 |
| --- | --- |
| 語管理（bad word / elevate word） | `storeAllBadWordsInternal` / `storeAllElevateWordsInternal` の末尾（`SuggestHelper.java:735`（elevate word） / `:923`（bad word）） |
| ドキュメント由来 | `indexFromDocuments` の `then` コールバック内（`SuggestHelper.java:349`）— `success.accept` より前 |
| 検索ログ由来 | `indexFromSearchLog` の末尾（`SuggestHelper.java:312`） |

> **`refresh_interval: 1s` に依存した過小カウントで G1 が誤って不合格を出す経路は無い** [確認]。

---

## 2. 指摘 1 [Medium] — ガードが落ち続ける間、`removeDisableIndices()` が二度と走らず孤児インデックスが単調増加する

### 2.1 事実 [確認]

`removeDisableIndices()` の呼び出し元は **`(fess) exec/SuggestCreator.java:360` の 1 箇所だけ**である（`0003` §3 が「呼び出し元は 1 箇所のみ」と明記しており、本書でも再確認した）。A-3 のガードは、不合格時に `switchIndex()`（`:357`）とともに `removeDisableIndices()`（`:360`）も飛ばして `return` する（`:341-352`）。

**一方 `createNextIndex()`（`:279`）は毎回無条件に新しいインデックスを作り、更新エイリアスをそこへ移す**（`(sug) Suggester.java:235-267`）。したがって:

- 1 回目の不合格 → 次世代インデックス A が更新エイリアスを持ったまま残る
- 2 回目の実行 → `createNextIndex()` がインデックス B を作り更新エイリアスを B へ移す。**A はエイリアス 0 個の孤児になる**
- 2 回目も不合格 → `removeDisableIndices()` は走らない → **A は回収されない**
- 以降、**不合格が続く限り毎回 1 つずつ孤児が増える**

### 2.2 設計書の前提との衝突 [確認]

`docs/0003-migration-ops-design.md` は**少なくとも 4 箇所**で「孤児は次回の `removeDisableIndices()` が回収する」と書いている。

| 箇所 | 記述 |
| --- | --- |
| `:180` | 「エイリアス 0 個の孤児インデックスが残る」→ 回収欄が「**次回 `removeDisableIndices()` が回収**」 |
| `:189` | 「前回の中途インデックスは**次回の `removeDisableIndices()` で回収される**」 |
| `:245` | 「実害は**次回 `removeDisableIndices()` まで残るディスク使用のみ**」 |
| `:252` | 「**次回実行で S1 からやり直せる。孤児は次回の `removeDisableIndices()` が回収する**」 |

**A-3 のガードはこの「次回必ず回収される」という前提を条件付きにした。** ガードが不合格を返し続ける状況（＝ **不正行が 1 件でも DB に残ったまま日次ジョブが回り続ける状況**。まさに `0003` §4.2.2 が「運用者が直すまで世代を更新させない」と意図した状況そのもの）では、回収は**一度も**走らない。

### 2.3 影響の見積もり [推測]

**ディスクの単調増加**である。日次ジョブなら 1 日 1 インデックス。suggest インデックスは `number_of_shards: 1` で通常は小さいが、放置期間に比例して増える。**シャード数の上限（既定 1000/ノード）に達すればクラスタ全体のインデックス作成が止まる**ため、影響は suggest 機能に閉じない。

### 2.4 論点: 不合格時に `removeDisableIndices()` を走らせるのは危険か [提案]

**本書の実査では、危険ではない** [確認]。

- `removeDisableIndices()` の削除判定は「**エイリアスを 1 つも持たない** suggest インデックス」である（`(sug) Suggester.java:339-360` ／ `0003` §1.4）。
- ガード不合格の時点では **`switchIndex()` を実行していない**ため、**検索エイリアスは旧世代を、更新エイリアスは次世代を指したまま**である。どちらもエイリアスを持つので削除対象にならない。
- **MO-2 が防ごうとしている「旧世代の即物理削除」（`0003` D-b）は `switchIndex()` が走った直後にのみ成立する障害**であり、切替を飛ばした状態では成立しない。

> **したがって「G3 / G1 不合格でも `removeDisableIndices()` は実行してから `return` する」は成立しうる** [提案]。**ただしこれは MO-2 の字面（「切替と `removeDisableIndices()` を実行せずに終了する」— `0003` `:54`）を変更する設計判断であり、本書の権限では決められない。** **逸脱手続き（区分 I）を経て `0003` を改訂するか、あるいは「改訂しない」と決めたうえで §2.2 の 4 箇所に条件を書き足し、運用周知（ガードが落ち続ける間はディスクを監視する）に載せるかの二択である。**

**最低限、どちらを採るにせよ `0003` §2.2 の 4 箇所の「次回回収される」という記述は、現状のままでは誤りである** [確認]。

---

## 3. 指摘 2 [Medium] — 「生キー削除の失敗を昇格させない」という 2026-09-04 の決定に、回帰検知が 1 件も付いていない

### 3.1 事実 [確認]

**この決定はフェーズ A で最も議論された判断の 1 つである** — `0013` §3（指摘 2）が提起し、`0014` §2.2 が判断を A-3 へ送り、`0015` §5 が再確認し、`0016` §6 の 1 が確定させ、プラン A-3 作業内容 5 に「**[確定]**」として書き込まれた。**4 文書にまたがる。**

**実装は入っている** [確認] — `(fess) helper/SuggestHelper.java:801-826` の `deleteOneElevateWordRow`。`isolateCleanupFailure == true`（再構築経路）のとき、生キー削除だけを個別に `catch` して WARN を出し、`failedIds` には入れない（`:822-825`）。

**しかしこの分岐は、どのテストからも一度も実行されない** [確認]。

| テストクラス | `deleteOneElevateWordRow` の呼び方 | 分岐に入るか |
| --- | --- | --- |
| `(fess test) helper/SuggestHelperRebuildIsolationTest.java` | `storeAllElevateWordsForRebuild()` 経由 → **`isolateCleanupFailure = true`**（`SuggestHelper.java:773`） | **入らない**。使う語が `"normal"` / `"broken"`（`:75` / `:94` / `:143` / `:150`）で**正規化前後が同一**のため、`if (!normalizedWord.equals(rawWord))`（`:805`）が偽 |
| `(fess test) helper/SuggestHelperElevateWordTest.java` | `deleteAllElevateWord(true)` 経由 → **`isolateCleanupFailure = false`**（`SuggestHelper.java:769`） | **入らない**。語（`"東京　タワー"` 等）は正規化で変わるが、**通るのは fail-fast 側の `:809-812`** |

> **`:814-826`（隔離側の生キー削除と、その try/catch）は、`mvn test` 7468 件のいずれからも実行されていない** [確認]。

### 3.2 なぜこれが問題か

**A-6 の DoD は「各テストが実際に失敗しうることを確認する（実装を一時的に戻して赤くなることを 1 回確かめる）」を必須としており、`0017` §6 は 5 件についてそれを実施している。** 本決定はその対象に入っていない。

**回帰は静かに起こる**: 将来 `deleteOneElevateWordRow` を整理して try/catch を外す（＝ 2026-09-04 以前の挙動に戻す）と、**生キー削除の失敗が `failedIds` に入り、G3 が世代切替を止める。** これは「過去のゴミの掃除に失敗しただけで新世代を公開しない」という、`0013` §3.3 が明確に否定した挙動である。**現在のテストは 1 件も落ちない。**

### 3.3 提案するテスト [提案]

**`SuggestHelperRebuildIsolationTest` に 2 件足せば閉じる。** どちらも実クラスタ不要で、既存の `RecordingSuggestHelper`（`deleteElevateWordFromIndex` の seam を持つ）にキー別の失敗注入を 1 つ足すだけである。

| # | 内容 | 期待 |
| --- | --- | --- |
| **(a)** | 正規化で語が変わる行（例: `"東京　タワー"`）を含む入力で、**生キー `"東京　タワー"` の削除だけ**が例外を投げるようにして `storeAllElevateWordsForRebuild()` を呼ぶ | **戻り値が 0**（`failedIds` に入らない）。正規化キー `"東京 タワー"` の削除は成功しており、追加も走っている |
| **(b)** | 同じ行で、**正規化キー `"東京 タワー"` の削除**が例外を投げるようにする | **戻り値が 1**（従来どおり隔離の対象） |

> **(a) と (b) を対にすることが要点である** [提案]。(a) だけでは「両方とも数えない」実装でも通る。**「どちらのキーの失敗か」で扱いが分かれることが決定の本体であり、片側だけのテストはそれを固定しない。**

### 3.4 判定

**実装バグではない** [確認]。`0016` §6 の 1 の決定どおりに動いている。**指摘は「4 文書で確定させた判断に、機械的裏付けだけが無い」という不均衡に対するものである。** **R0 のリリースを止める性質ではない**（現在の挙動は正しい）が、**A-6 の DoD の趣旨（「常に緑」なテストを作らない）に照らすと、閉じておく価値が高い。**

---

## 4. 指摘 3・4 [Low] — 改善提案

### 4.1 指摘 3 — `getNextGenerationWordsNum()` が G3 不合格時にも無条件に発行される

**プラン A-3 作業内容 2 は「S3 相当の位置（**G3 の後**）で次世代の件数を同じ手段で取得し」と書いている** [確認]。実装は `(fess) exec/SuggestCreator.java:337` で**ガード判定の前に無条件に**呼ぶ。

| 影響 | 程度 |
| --- | --- |
| `exitCode != 0` が確定している経路でクラスタへ 1 クエリ余分に投げる | **軽微**（1 回） |
| そのクエリが投げると `create()` が例外で抜け、ガードの明示的な `return` を通らない | **安全側**。`main()` の `catch (final Throwable t)`（`:197`）が拾って `Constants.EXIT_FAIL` になる。**切替が起きることはない** [確認] |

**[提案]**: `canSwitchAfterIngest(exitCode.get())` が偽なら件数を取らずに `return` する形に短絡すれば、両方消えてプランの記述とも一致する。**現状でも安全であり、是正の必要性は低い。**

### 4.2 指摘 4 — 2 つの新規テストで `SuggestHelper.suggester` フィールドの扱いが非対称

| テスト | 形 |
| --- | --- |
| `(fess test) helper/SuggestHelperNextGenerationCountTest.java` の `RecordingSuggestHelper` | **親の `protected Suggester suggester` フィールドに代入する**（`suggester = new StubSuggester(index);`） |
| `(fess test) exec/SuggestCreatorTest.java` の `RecordingSuggestHelper` | **同名の `private final StubSuggester suggester` を宣言して親フィールドを隠蔽する**。`suggester()` を override しているため現状は動くが、**親の `suggester` は `null` のまま** |

**現状は壊れていない** [確認]（`create()` は `suggestHelper.suggester()` 経由でしか触らない）。**ただし `SuggestHelper` 側の任意のメソッドが `suggester` フィールドを直接読む形でテストに入ってくると、`SuggestCreatorTest` 側だけが NPE で落ちる。** `refresh()`（`:950-951`）や `getAllWordsNum()` がその形である。

**[提案]**: `SuggestCreatorTest` 側もフィールド名を変える（`stubSuggester`）か、親フィールドへ代入する形に揃える。**`readable-code` の観点でも、同じ役割の 2 クラスが同じ形をしている方が意図が読める。**

---

## 5. 指摘 5 [Info] — `0007` §7 の完了宣言表に、`0017` で解消済みの限界が残っている

`0007-phase-a-fess-precede.md` §7 の「**フェーズ A の完了宣言**」表で:

- 「**A-6 のレビュー反映**」行 = 「外部レビュー（Major 2 / Low 1）を反映済み（§6.11 ／ `0017`）」
- その **2 行下**の「**残る限界**」行 = 「**T-S1 の実行時検証は代替手段（ソースの構造検査）にとどまる**（§6.5 の 8 ／ §6.10 の 1）」

**後者は `0017` §1 の指摘 1 で解消済みである** [確認]。現在は `create()` を package-private にして実際に走らせ、`StubSuggester` がライフサイクル呼び出しを記録する形になっている（`(fess test) exec/SuggestCreatorTest.java:392` / `:410` / `:431` / `:452` / `:469`）。**同じ表の中で 2 行が矛盾している。**

**正は `0017` §7 と `0007` §6.11 である。** **記録のみ**（実装への影響なし）。**ただし完了宣言の表はリリース判断時に読まれる位置にあるため、直す価値はある** [提案]。

> **なお `0007` §6.10 の 1 と §6.5 の 8 の本文には「【2026-09-04】§6.11 で解消」の追記が入っている** [確認]。**取り残されているのは §7 の表だけである。**

---

## 6. 逸脱手続きの判定

**本レビューでは逸脱は発火していない** [確認]。**本書はコードも設計書も変更しておらず、設計判断を動かしていない。**

**ただし指摘 1 への対応は、採る道によって区分が変わる** [提案]:

| 対応 | 区分 |
| --- | --- |
| **不合格時も `removeDisableIndices()` を走らせる** | **区分 I**（MO-2 の内容変更。`0003` の改訂 → 記録 → 実装の順が要る） |
| **現状維持のまま `0003` §2.2 の 4 箇所に条件を書き足し、運用周知に載せる** | **区分 II**（事実の更新。設計判断は動かない） |

**指摘 2・3・4 への対応はいずれも区分 II 以下である**（テストの追加 ／ 短絡 ／ テストの整形。**設計書に定めが無い**）。

---

## 7. 指摘の一覧と宛先

| # | 重大度 | 内容 | 宛先 | R0 を止めるか |
| --- | --- | --- | --- | --- |
| **1** | **Medium** | ガード不合格が続く間 `removeDisableIndices()` が走らず孤児インデックスが単調増加する。`0003` の「次回回収される」記述 4 箇所が現状のままでは誤り | **`0003` の改訂判断**（区分 I か II か） | **止めない**（運用周知で足りる） |
| **2** | **Medium** | 「生キー削除の失敗を昇格させない」（`0016` §6 の 1・確定）に回帰検知が無い。`SuggestHelper.java:814-826` は 7468 件のどれからも実行されない | **A-6 の追補**（テスト 2 件） | **止めない**（現在の挙動は正しい） |
| **3** | Low | `getNextGenerationWordsNum()` が G3 不合格時にも発行される（プランは「G3 の後」と書いている） | 任意 | 止めない |
| **4** | Low | 2 つの `RecordingSuggestHelper` で `suggester` フィールドの扱いが非対称（片方は隠蔽） | 任意 | 止めない |
| **5** | Info | `0007` §7 の完了宣言表に `0017` で解消済みの限界が残っている | `0007` の記述訂正 | 止めない |

---

## 8. 総評

**フェーズ A は R0 としてリリースできる状態にある** [確認]。

**特に評価できる点**:

1. **MO-27（次世代を更新エイリアスで数える）が、実装だけでなく「検索エイリアスへ戻す回帰」を検知するテストまで揃っている**（`SuggestHelperNextGenerationCountTest`）。**これは signature を変えない静かな回帰であり、`0017` §6 の 2 が「A-6 時点のテスト一式はこの回帰で 1 件も落ちなかった」と記録しているとおり、テストが無ければ本番で G1 が no-op 化するまで気付けない性質のものである。**
2. **T-S1 が構造検査から実行検査へ引き上げられている**（`0017` §5.1）。**その反対側のテスト（`test_create_switchesTheIndex_...`）で呼び出し順を等値検査している**ため、「そもそも切替に到達できない」形の偽陽性も塞がっている。
3. **`ModulePaths` によってソース／リソースを読む検査が作業ディレクトリ非依存になっている**（`0017` §1 の 3）。
4. **`ForRebuild` 2 メソッドと `getNextGenerationWordsNum()` の呼び出し元制約が、Javadoc だけでなく grep 検査で機械化されている**（`SuggestHelperRebuildIsolationTest:173` / `:186`）。**型システムで表現できない制約に対して、取りうる最善の手段である。**

**残る 2 件の Medium は、いずれも「実装は正しいが、その正しさを守る仕組みが足りない」型である** — 指摘 1 は設計書の記述が実装に追いついていないこと、指摘 2 は確定した判断にテストが無いこと。**どちらも R0 のリリース前に必須ではないが、指摘 1 は運用周知の対象に加えるべきである**（`0007` §6.10 の 7 のリリース周知事項 3 点に **4 点目**として）。

---

## 9. 参照した一次情報

### 9.1 プロダクションコード / リソース

| ファイル | 参照した箇所 |
| --- | --- |
| `(fess) exec/SuggestCreator.java` | `:73`（`MIN_NEXT_GENERATION_RATIO`）／ `:264`（`create()` の可視性）／ `:275`（旧件数）／ `:279`（`createNextIndex()`）／ `:337`（次世代件数）／ `:341-352`（ガード本体）／ `:357` / `:360`（`switchIndex` / `removeDisableIndices`）／ `:374-412`（3 つの判定メソッド）／ `:197`（`main` の `catch (Throwable)`）／ `:224-248`（`process()`） |
| `(fess) helper/SuggestHelper.java` | `:87`（`UPDATE_ALIAS_SUFFIX`）／ `:190` / `:205` / `:220`（seam 3 メソッド）／ `:312` / `:349` / `:735` / `:785` / `:923`（refresh の位置）／ `:422-423`（`getNextGenerationWordsNum`）／ `:438-445`（`countWordsInIndex`）／ `:617` / `:649-653`（正規化）／ `:689-691`（`normalizeSeparators`）／ `:710-737`（追加ループ）／ `:761-786`（削除ループ）／ `:801-826`（`deleteOneElevateWordRow`）／ `:950-955`（`refresh`） |
| `(fess res) suggest_indices/*.json` | 3 ファイル・各 `:5` の削除 |
| `(sug) Suggester.java` | `:174-179`（`refresh`）／ `:235-267`（`createNextIndex`）／ `:282-337`（`switchIndex`）／ `:339-360`（`removeDisableIndices`）／ `:424-426`（`getAllWordsNum`）／ `:443-452`（`getNum`）／ `:454-461`（エイリアス命名） |
| `(sug) entity/ElevateWord.java` | `:143-150`（`toSuggestItem`） |
| `(sug) entity/SuggestItem.java` | `:113-141`（コンストラクタ — R0 時点では不変条件の強制が無いこと） |
| `(sug) index/operations/WordManagementOperations.java` | `:125-132`（`deleteElevateWord` — `settings.elevateWord().delete` が try の外） |

### 9.2 テストコード

`(fess test) exec/SuggestCreatorTest.java` ／ `(fess test) helper/SuggestHelperElevateWordTest.java` ／ `(fess test) helper/SuggestHelperNextGenerationCountTest.java` ／ `(fess test) helper/SuggestHelperRebuildIsolationTest.java` ／ `(fess test) helper/SuggestIndicesResourceTest.java` ／ `(fess test) unit/ModulePaths.java` ／ `(fess test) unit/StubSuggester.java`

### 9.3 タスク内文書

`0001-work-plan.md` §4（フェーズ A）／ `0007-phase-a-fess-precede.md` §1〜§7 ／ `0013` ／ `0014` ／ `0015` ／ `0016` ／ `0017` ／ `docs/0002-datamodel-design.md` §5.4 ／ `docs/0003-migration-ops-design.md` §1.4 / §2.2 / §3 / §4.2
