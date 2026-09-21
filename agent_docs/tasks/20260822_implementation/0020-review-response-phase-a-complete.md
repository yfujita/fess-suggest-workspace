# 0020: フェーズ A 総合レビュー（`0018`）の反映

> 本書は **`0018-review-phase-a-complete.md`（フェーズ A 全 5 ステップに対する通算 6 回目の外部レビュー）の指摘 5 件への対応記録**である。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[確定]** = 本書で確定した決定 ／ **[提案]** = 本書の提案 ／ **[推測]** = 実測していない推論
>
> **パス短縮表記**: `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/` ／ `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-09-07** |
| 対象 | `0018` の指摘 1〜5（Medium 2 / Low 2 / Info 1） |
| ブランチ | `modules/fess` の `feature/suggest-l1-precede` |
| 逸脱 | **X-8 が発火**（指摘 1。区分 I ／ `0003` 第 16 版 → 第 17 版 ／ 記録は `0019`） |
| `modules/fess-suggest` | **無変更**（C-01）[確認] |

**結果: 5 件すべてに対応した。うち 1 件（指摘 1）は逸脱手続き（区分 I）を経ている。**

---

## 0. 指摘の妥当性の判定

**5 件すべてを実物のコードで独立に確認し、いずれも事実として正確であると判定した** [確認]。

| # | 重大度 | 検証した内容 | 判定 |
| --- | --- | --- | --- |
| 1 | Medium | `removeDisableIndices()` の呼び出し元が `(fess) exec/SuggestCreator.java` の 1 箇所のみであること ／ ガード不合格経路がそこを飛ばすこと ／ `createNextIndex()` が毎回無条件に次世代を作ること（`(sug) Suggester.java:235-267`） ／ **`removeDisableIndices()` の削除判定が「エイリアス 0 個」であり不合格時に走らせても旧世代・次世代が対象外であること**（`(sug) Suggester.java:338-359`） | **妥当**（**ただし §1.2 のとおり是正範囲は指摘より狭い**） |
| 2 | Medium | `(fess) helper/SuggestHelper.java` の隔離側 `catch` が、`SuggestHelperRebuildIsolationTest`（語が正規化不変）からも `SuggestHelperElevateWordTest`（fail-fast 経路）からも到達しないこと | **妥当** |
| 3 | Low | `getNextGenerationWordsNum()` がガード判定前に無条件で発行されていること（プランは「G3 の後」） | **妥当**（**X-8 適用後は §3 のとおり重大度が上がる**） |
| 4 | Low | `SuggestCreatorTest` の `RecordingSuggestHelper` が親の `protected Suggester suggester`（`SuggestHelper.java:92`）を同名 `private` フィールドで隠蔽していること | **妥当** |
| 5 | Info | `0007` §7 の完了宣言表の「残る限界」行が `0017` で解消済みの記述を残していること | **妥当** |

---

## 1. 指摘 1 [Medium] — ガード不合格時の孤児インデックス回収（**逸脱 X-8**）

### 1.1 対応方針の決定 [確定]

**ユーザー判断により案 A（不合格時も `removeDisableIndices()` を実行する。区分 I）を採った**（2026-09-07）。**却下した案 B / C（現状維持＋記述訂正＋運用周知）の理由は `0019` §3** — **`removeDisableIndices()` を単独で叩く経路が fess の管理画面にも API にも無く、運用者に手当ての手段が無いため、周知は問題を移すだけで解かない。**

**手続きは区分 I の順序（改訂 → 記録 → 実装）を守った** [確認]:

| # | 手順 | 成果物 |
| --- | --- | --- |
| 1 | **設計書の改訂** | `docs/0003-migration-ops-design.md` **第 16 版 → 第 17 版**（MO-2 の改訂 ＋ §4.3.1 の新設 ＋ 波及 8 箇所。内訳は `0019` §5） |
| 2 | **記録** | **`0019-deviation-x8-remove-disable-indices-on-guard-failure.md`** |
| 3 | **実装** | 本書 §1.3 |
| 4 | **プランへの反映** | §1.5 |

### 1.2 レビューが提示していなかった論点: 判定不能経路との境界 [確認]

**`0018` §2.4 は「G3 / G1 不合格でも `removeDisableIndices()` は実行してから `return` する」と一般形で提案していたが、`0003` は `removeDisableIndices()` を呼んではならない経路を別に持っている** — **§12 の K-18 ／ §11.1 の T-S12（`SuggestAliasStateUnknownException` を受けたとき。切替が適用済みか確定しておらず、エイリアス 0 個の世代がロールバック先でありうる）。**

**一般形のまま実装すると T-S12 と矛盾する。** 本対応では **2 つを排他な経路として分離した** [確認]:

| 経路 | `removeDisableIndices()` | 根拠 |
| --- | --- | --- |
| **ガード不合格**（G1 / G3） | **実行する** | 切替に到達していないため旧世代・次世代ともエイリアスを持つ |
| **判定不能**（`SuggestAliasStateUnknownException`） | **実行しない**（従来どおり） | 切替が適用済みか確定していない |

> **2 つが同時に成り立つことはない** [確認]。**判定不能例外は S1（`createNextIndex()`）ならガードより前、S4（`switchIndexRetainingPrevious()`。R1）ならガードを通過した後で `create()` を抜ける。** **R0 では S1 の例外は `main()` の `catch (Throwable)`（`(fess) exec/SuggestCreator.java:197`）まで伝播する。**

**この分離を `0003` §4.3.1 と §11.1（T-S1 / T-S12 の相互注記）に明記した。**

### 1.3 実装 [確認]

**`(fess) exec/SuggestCreator.java`**:

| # | 変更 |
| --- | --- |
| 1 | **G3 不合格・G1 不合格の 2 経路で、`return` の前に `reclaimOrphanIndices(suggestHelper)` を呼ぶ** |
| 2 | **`private void reclaimOrphanIndices(SuggestHelper)` を新設した** — `suggester().removeDisableIndices()` を呼び、**例外を握って WARN を出す**（best-effort）。**切替を止めるという判定は既に確定しており、後片付けの失敗が終了コードを変えてはならない**（`0019` §6 の 3） |
| 3 | **`switchIndex()` は従来どおり呼ばない** |

**Javadoc に、なぜこれが必要か（回収機構の唯一の呼び出し元であること・毎回孤児が生まれること）と、なぜ安全か（切替前なので両エイリアスが生きていること）と、判定不能経路には及ばないことを書いた。**

### 1.4 テスト [確認]

**`(fess test) exec/SuggestCreatorTest.java` の T-S1 系 3 件の `removeDisableIndices` に関する assert を反転させた**（`assertFalse` → `assertTrue`）。**`switchIndex()` が呼ばれないことの検査は残している。**

> **第 16 版までのテストは「両方とも呼ばれないこと」を固定していた** [確認]。**これは改訂後は誤りであり、放置すると赤くなる。** **T-S1 の是正は `0003` 第 17 版 §11.1 に反映済みである。**

### 1.5 プランへの反映 [確認]

| 箇所 | 反映 |
| --- | --- |
| §2.2 の表題 | 「発火 7 件」→ **「発火 8 件」** |
| §2.2 の前文 | X-8 の発火元（フェーズ A 全体の外部レビュー）を追記 |
| §2.2 の枠 | **X-8 も新しい MO 番号を起こさない**ことを追記（X-5 / X-6 の枠と同型） |
| §2.2 の表 | **X-8 の行を追加** |
| **A-3 作業内容 1** | **`removeDisableIndices()` は不合格時にも実行する**（X-8） |
| **A-3 の DoD** | **「`switchIndex()` / `removeDisableIndices()` がともに呼ばれない」を撤回**し、「`switchIndex()` が呼ばれない・`removeDisableIndices()` は呼ばれる」に是正 |
| **A-6 作業内容 3** | **T-S1 の内容を同じく是正** |

---

## 2. 指摘 2 [Medium] — 生キー削除の失敗を昇格させない決定に回帰検知が無い

### 2.1 事実の確認 [確認]

**`(fess) helper/SuggestHelper.java` の `deleteOneElevateWordRow` の隔離側 `catch` が、`mvn test` 7468 件のいずれからも実行されていない**ことを確認した:

| テストクラス | `isolateCleanupFailure` | 到達しない理由 |
| --- | --- | --- |
| `SuggestHelperRebuildIsolationTest` | **`true`**（再構築経路） | 使う語が `"normal"` / `"broken"` で**正規化前後が同一**のため `if (!normalizedWord.equals(rawWord))` が偽 |
| `SuggestHelperElevateWordTest` | **`false`**（`deleteAllElevateWord(true)` 経由） | 通るのは fail-fast 側 |

**加えて `RecordingSuggestHelper` の `deleteElevateWordFromIndex` seam は失敗を注入できる形になっていなかった** [確認]。

### 2.2 対応 [確認]

**`(fess test) helper/SuggestHelperRebuildIsolationTest.java` に、キー別の失敗注入（`elevateWordKeysToFailOnDelete`）と、テスト 3 件を追加した。**

| # | テスト | 入力 | 期待 |
| --- | --- | --- | --- |
| **(a)** | `test_storeAllElevateWordsForRebuild_doesNotCountTheRow_whenOnlyTheRawKeyDeleteFails` | `"東京　タワー"`（表意文字空白）の行で**生キーの削除だけ**が例外 | **戻り値 0**。正規化キー `"東京 タワー"` の削除と追加は走っている |
| **(b)** | `test_storeAllElevateWordsForRebuild_countsTheRow_whenTheNormalizedKeyDeleteFails` | 同じ行で**正規化キーの削除**が例外 | **戻り値 1**（隔離の対象） |
| **(c)** | `test_deleteAllElevateWord_stillPropagatesARawKeyCleanupFailure` | 同じ行で生キーの削除が例外。**public 経路**（`deleteAllElevateWord(false)`） | **例外が伝播する**（MO-25 の規則 6） |

> **(a) と (b) を対にすることが要点である** [確認]（`0018` §3.3）。**(a) だけでは「どちらのキーの失敗も数えない」実装でも通り、決定の本体 — どちらのキーの失敗かで扱いが分かれること — を固定できない。**
>
> **(c) は `0018` が挙げていない 3 件目である** [提案]。**2026-09-04 の決定は再構築経路に限定されたものであり**（`0016` §6 の 1 ／ MO-25 の規則 6）、**public 側へ漏れたときの検知が (a) / (b) だけでは付かない。** 既存の④（public 3 メソッドが例外を伝播すること）は**別の失敗点**（`boost` の `null`・`suggestWord` の `null`）を使っており、**生キー削除の失敗については検査していなかった** [確認]。

### 2.3 プランへの反映 [確認]

**A-6 作業内容 2 に⑤として追記し、DoD にも加えた。**

---

## 3. 指摘 3 [Low] — `getNextGenerationWordsNum()` の発行位置

### 3.1 X-8 の適用により重大度が上がった [確認]

**`0018` §4.1 はこれを「軽微。現状でも安全であり、是正の必要性は低い」と評価している。その評価は X-8 の適用前のものである。**

**X-8 で `reclaimOrphanIndices()` を G3 不合格経路に置いたことにより、次の連鎖が成立するようになった** [確認]:

| # | 経過 |
| --- | --- |
| 1 | 取り込みが失敗した実行（`exitCode != 0`）で、ガード判定より前に `getNextGenerationWordsNum()` が発行される |
| 2 | そのクエリが例外を投げると `create()` は**ガードの明示的な `return` を通らずに**抜ける（`0018` §4.1 が確認済み） |
| 3 | **X-8 で加えた `reclaimOrphanIndices()` も飛ばされる** |
| 4 | **これが起きるのは「取り込みが失敗している実行」＝ まさに孤児が溜まる経路である。X-8 の是正が空振りする** |

> **したがって本項は体裁の問題ではなく、X-8 の是正の実効性を守るための変更である** [確定]。

### 3.2 実装 [確認]

**ガードを 2 段に分け、G3 不合格なら件数を取らずに `return` する形にした** — プラン A-3 作業内容 2 の記述（「S3 相当の位置（**G3 の後**）で次世代の件数を…取得し」）とも一致する。

**あわせて `static boolean canSwitchIndex(int, long, long)`（G1 と G3 の総合判定）を削除した** [確認]。**分割後は production から呼ばれなくなり、テストからしか呼ばれないメソッドが残る形になるためである。** **G1 / G3 の個別述語（`canSwitchByWordsNum` / `canSwitchAfterIngest`）は package-private のまま残しており、A-3 作業内容 7 の趣旨（ガード判定を検査可能なメソッドへ切り出す）は保たれている。**

> **これは設計書の定めに触れない** [確認]。**`0003` はメソッド分割の粒度を定めていない**（`0003` §11.3 が定めるのはテストのホスト先と検証内容である）。**プラン A-3 作業内容 7 の「3 つ目のメソッド（総合判定）」だけが消えるため、本書に記録する。**

### 3.3 テスト [確認]

**`test_canSwitchIndex_falseWhenExitCodeIsNonZero_evenWithAbundantWordCounts`（削除したメソッドの単体テスト）を、実行レベルの回帰検知に置き換えた** — **`test_create_doesNotCountTheNextGeneration_onceTheRebuildHasReportedFailures`**。**G3 不合格の実行で `getNextGenerationWordsNum` が呼ばれないことを、`RecordingSuggestHelper` の呼び出し記録で検査する。** **元のテストの意図（G3 が単独で切替を止めること）は `test_create_doesNotSwitchTheIndex_whenTheRebuildReportedFailures`（`nextGenerationWordsNum = 1000`）が既に持っている。**

**構造検査も是正した** [確認]。`if (!canSwitchIndex(` を探していた検査を、**2 つのガード呼び出しがこの順で `switchIndex()` より前にあり、それぞれの後に早期 `return` があること**を見る形に書き直した。**`removeDisableIndices()` の位置は検査対象から外した** — **X-8 により不合格経路でも呼ばれるようになり、ガードとの前後関係が意味を持たなくなったためである**（何を呼ぶ／呼ばないかは T-S1 の実行検査が持つ）。

---

## 4. 指摘 4 [Low] — `suggester` フィールドの非対称

**`(fess test) exec/SuggestCreatorTest.java` の `RecordingSuggestHelper` を `SuggestHelperNextGenerationCountTest` 側と揃えた** [確認]:

| # | 変更 |
| --- | --- |
| 1 | **フィールド名を `suggester` → `stubSuggester` に変え、親の `protected Suggester suggester`（`SuggestHelper.java:92`）の隠蔽をやめた** |
| 2 | **コンストラクタで親フィールドにも代入する**（`suggester = stubSuggester;`）。`SuggestHelperNextGenerationCountTest` の `RecordingSuggestHelper` と同じ形になった |
| 3 | 参照箇所 9 件を追従させた |

> **現状の挙動は変わらない** [確認]（`create()` は `suggestHelper.suggester()` 経由でしか触らない）。**`SuggestHelper` 側の `refresh()` や `getAllWordsNum()` のようにフィールドを直接読むメソッドがこのテストに入ってきたときに、片方だけ NPE で落ちる状態を解消したものである。**

---

## 5. 指摘 5 [Info] — `0007` §7 の完了宣言表の記述訂正

**`0007-phase-a-fess-precede.md` §7 の完了宣言表の「残る限界」行を訂正した** [確認]。

- **訂正前**: 「T-S1 の実行時検証は代替手段（ソースの構造検査）にとどまる」
- **訂正後**: **同じ表の 2 行上（「A-6 のレビュー反映」行）と矛盾していた取り残しであることを明記し、`0017` §1 の指摘 1 で解消済みである旨に書き換えた。** **正は `0017` §7 と `0007` §6.11 である。**
- **「既存 `SuggestHelperTest` の 24 件が握り潰し構造である」という限界はそのまま残した** — **こちらは未解消である** [確認]。

> **`0007` §6.10 の 1 と §6.5 の 8 の本文には既に「【2026-09-04】§6.11 で解消」の追記が入っており、取り残されていたのは §7 の表だけであった** [確認]（`0018` §5）。

---

## 6. 検証

### 6.1 テストの実行結果 [確認]

**`mvn -o test`（`modules/fess` 全体）: `Tests run: 7471, Failures: 0, Errors: 0, Skipped: 0` / `BUILD SUCCESS`** [確認]。

**`0018` 時点の 7468 件から 3 件増えている** — **§2.2 で追加した (a) / (b) / (c) の 3 件である。** **指摘 3 で削除した `test_canSwitchIndex_...` 1 件と、置き換えとして追加した `test_create_doesNotCountTheNextGeneration_...` 1 件は相殺して ±0 である。**

| テストクラス | 件数 | 結果 |
| --- | --- | --- |
| `(fess test) exec/SuggestCreatorTest.java` | **36** | 全緑 |
| `(fess test) helper/SuggestHelperRebuildIsolationTest.java` | **12**（9 → 12） | 全緑 |
| `(fess test) helper/SuggestHelperElevateWordTest.java` | 9 | 全緑（無変更） |
| `(fess test) helper/SuggestHelperNextGenerationCountTest.java` | 2 | 全緑（無変更） |
| `(fess test) helper/SuggestIndicesResourceTest.java` | 2 | 全緑（無変更） |

**`modules/fess-suggest` は `git status --short` が空である**（C-01）[確認]。

### 6.2 各テストが実際に失敗しうることの確認（A-6 の DoD）[確認]

**A-6 の DoD は「各テストが実際に失敗しうることを確認する（実装を一時的に戻して赤くなることを 1 回確かめる）」を必須としている。** **本書で追加・変更したテストについても同じ確認を行い、4 種の変異をそれぞれ単独で適用して赤くなることを確かめた** [確認]。

| # | 変異（実装を一時的に戻す内容） | 赤くなったテスト | 判定 |
| --- | --- | --- | --- |
| **1** | **生キー削除の隔離を外す**（`deleteOneElevateWordRow` の `if (!isolateCleanupFailure)` を無条件化 ＝ **2026-09-04 以前の挙動**） | **`test_storeAllElevateWordsForRebuild_doesNotCountTheRow_whenOnlyTheRawKeyDeleteFails` の 1 件のみ**（`expected: <0> but was: <1>`） | **期待どおり** |
| **2** | **2 つのキーを区別しなくなる**（正規化キー側の削除も同じ `catch` で握る ＝ **「どちらの失敗も数えない」実装**） | **`test_storeAllElevateWordsForRebuild_countsTheRow_whenTheNormalizedKeyDeleteFails` の 1 件のみ**（`expected: <1> but was: <0>`） | **期待どおり。§2.2 の (a) / (b) が対として機能していることが確かめられた** |
| **3** | **ガード不合格経路から `reclaimOrphanIndices()` を外す**（＝ **X-8 の適用前の挙動**） | **T-S1 系 3 件**（`test_create_doesNotSwitchTheIndex_whenTheRebuildReportedFailures` / `..._whenIndexingFromDocumentsFailed` / `..._whenTheNextGenerationIsEmpty`） | **期待どおり** |
| **4** | **次世代件数の取得を G3 ガードより前へ戻す** | **`test_create_doesNotCountTheNextGeneration_onceTheRebuildHasReportedFailures` の 1 件のみ** | **期待どおり** |

> **変異 1 と 2 が「1 件のみ」赤くなることが要点である** [確認]。**どちらか一方だけが赤くなる関係になっていなければ、(a) / (b) は決定の本体（キーによって扱いが分かれること）を固定していない。**

---

## 7. 変更したファイル

### 7.1 production（2 ファイル）

| ファイル | 変更 |
| --- | --- |
| `(fess) exec/SuggestCreator.java` | **ガードを G3 / G1 の 2 段に分けた**（指摘 3）／ **不合格 2 経路に `reclaimOrphanIndices()` を追加**（X-8）／ **`private void reclaimOrphanIndices(SuggestHelper)` を新設**（X-8）／ **`static boolean canSwitchIndex(int, long, long)` を削除**（呼び出し元が無くなったため — §3.2） |
| `(fess) helper/SuggestHelper.java` | **無変更** — 指摘 2 はテストのみで閉じた [確認] |

> **production の変更は `SuggestCreator.java` の 1 ファイルに閉じている** [確認]。**`switchIndex()` を呼ぶ条件・`exitCode` の意味・G1 / G3 の判定式はいずれも変えていない。**

### 7.2 テスト（2 ファイル）

| ファイル | 変更 |
| --- | --- |
| `(fess test) exec/SuggestCreatorTest.java` | T-S1 系 3 件の `removeDisableIndices` assert を反転（X-8）／ 構造検査を 2 ガード対応へ書き直し ／ `test_canSwitchIndex_...` を `test_create_doesNotCountTheNextGeneration_...` へ置き換え ／ `suggester` → `stubSuggester` とコンストラクタでの親フィールド代入（指摘 4） |
| `(fess test) helper/SuggestHelperRebuildIsolationTest.java` | `elevateWordKeysToFailOnDelete` seam の追加 ＋ **テスト 3 件の新設**（指摘 2） |

### 7.3 設計書・タスク文書

| ファイル | 変更 |
| --- | --- |
| `docs/0003-migration-ops-design.md` | **第 16 版 → 第 17 版**（X-8。内訳は `0019` §5 の 12 項目） |
| `0001-work-plan.md` | §2.2（発火 8 件へ ＋ X-8 の行）／ A-3 の作業内容 1・2 と DoD ／ A-6 の作業内容 2・3 と DoD ／ **§10 の文書一覧の繰り下げ**（フェーズ B〜F を 0021〜0025 へ） |
| `0007-phase-a-fess-precede.md` | §7 の完了宣言表「残る限界」行の訂正（指摘 5） |
| **`0019-...md`**（新規） | 逸脱 X-8 の記録 |
| **`0020-...md`**（新規） | 本書 |

> **`0018` が記録した作業ツリーの構成（変更 6 ファイル ＋ 未追跡 6 ファイル）は変わっていない** [確認]。**本対応で新しいファイルは `modules/fess` 側に 1 つも増えていない** — 追加したテストはいずれも既存の新規テストクラスに入った。

---

## 8-0. 残る申し送り

| # | 内容 | 送り先 |
| --- | --- | --- |
| 1 | **`0007` §6.10 の 7 のリリース周知事項に 4 点目を足すかどうか** — **`0018` §8 は「ガードが落ち続ける間はディスクを監視する」を 4 点目として加えるべきと書いていたが、X-8 の適用によりその必要は無くなった** [確認]（孤児は不合格の実行の中で回収される）。**したがって周知事項は 3 点のままとする** [確定] | **対応不要**（本書で判断済み） |
| 2 | **T-S12（判定不能時に `removeDisableIndices()` を呼ばないこと）の実行検査は R0 に存在しない** [確認]。`SuggestAliasStateUnknownException` は R1 の fess-suggest 成果物（D-2 / D-23）とともに入るため、**R0 では送出されえない。** **X-8 で「ガード不合格では呼ぶ」と定めた以上、その裏返しの検査は R1 で必ず要る** | **R1（フェーズ F の T-S 系）** |

---

## 8. 参照した一次情報

### 8.1 プロダクションコード

| ファイル | 参照した箇所 |
| --- | --- |
| `(fess) exec/SuggestCreator.java` | `create()` のガード ／ `reclaimOrphanIndices()`（新設）／ `canSwitchAfterIngest` / `canSwitchByWordsNum` ／ `:197`（`main` の `catch (Throwable)`） |
| `(fess) helper/SuggestHelper.java` | `:92`（`protected Suggester suggester`）／ `deleteOneElevateWordRow` の 2 分岐 ／ `deleteAllElevateWordInternal` |
| `(sug) Suggester.java` | `:235-267`（`createNextIndex`）／ `:338-359`（`removeDisableIndices` の削除判定）／ `:454-461`（エイリアス命名） |

### 8.2 テストコード

`(fess test) exec/SuggestCreatorTest.java` ／ `(fess test) helper/SuggestHelperRebuildIsolationTest.java` ／ `(fess test) helper/SuggestHelperNextGenerationCountTest.java` ／ `(fess test) helper/SuggestHelperElevateWordTest.java`

### 8.3 タスク内文書

**`0018-review-phase-a-complete.md`**（対象）／ **`0019-deviation-x8-remove-disable-indices-on-guard-failure.md`**（指摘 1 の逸脱記録）／ `0001-work-plan.md` §2.1 / §2.2 / §4（A-3 / A-6）／ `0007` §6.11 / §7 ／ `0013` / `0014` / `0015` / `0016` / `0017` ／ `docs/0003-migration-ops-design.md` 第 17 版
