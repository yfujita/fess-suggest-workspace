# 0014: 3 回目のレビュー（`0013`）の反映 — フェーズ A ステップ A-1 / A-2

> 本書は **`0013-review-phase-a-a1-a2.md`（A-1 / A-2 を通しで見た 3 回目の外部レビュー）の指摘 6 件に対する判断と反映の記録**である。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[要確認]** = 未解消 ／ **[推測]** = 実測していない推論
>
> **パス短縮表記**: `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/` ／ `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-09-01** |
| 対象レビュー | `0013-review-phase-a-a1-a2.md`（指摘 6 件。Medium 2 / Low 2 / Info 2） |
| ブランチ | `modules/fess` の **`feature/suggest-l1-precede`**（HEAD = `73e912715`。A-2 は未コミットの作業ツリー 2 ファイル） |
| コード変更 | **`(fess) helper/SuggestHelper.java` の 1 ファイルのみ**（指摘 3 の反映）[確認] |
| 設計書の改訂 | **なし**（`docs/0003-migration-ops-design.md` は**第 13 版のまま**。**逸脱手続きは発火しない** — §4） |
| ドキュメント更新 | `0007`（§2 冒頭の追記 3 ／ §2.4 の要件 1・3 ／ §2.9 の DoD 5 ／ §2.11 に申し送り 11〜13）／ `0001-work-plan.md`（**A-6 の作業内容 2 に 1 項目**） |
| `modules/fess-suggest` | **無変更**（C-01 を守っている）[確認] |

**結論: 6 件すべてを妥当と判断した。ただし 1 件（指摘 4）は前提が成立しないことを実物で確認したため、レビューの提案どおりではなく是正した形で反映した。コードを変えたのは指摘 3 の 1 件だけである。**

---

## 1. 指摘ごとの判断（一覧）

| # | 重大度 | 指摘の要旨 | 妥当性の判断 | 反映 |
| --- | --- | --- | --- | --- |
| **1** | Medium | 「public 3 メソッドの挙動が完全に同一」は、`storeAllElevateWords` → `deleteAllElevateWord` が仮想呼び出しから private 呼び出しに変わった 1 点で厳密には成立しない | **妥当** [確認] | **記述に注記**（コードは変えない）。`0007` §2.4 要件 1 ／ §2.9 DoD 5 |
| **2** | Medium | 失敗件数に「生キー削除（移行期クリーンアップ）の失敗」が混入しうる。A-3 の `exitCode` 合流時に昇格規則を決める必要がある | **妥当** [確認] | **A-3 への申し送り**（`0007` §2.11 の 11）。**A-2 の実装は変えない** |
| **3** | Low | elevate word 追加ループの 2 行・6 引数の呼び出しが逐語的に 2 回書かれており、削除側（`deleteOneElevateWordRow`）と非対称 | **妥当** [確認] | **コード修正**（`storeOneElevateWordRow` を切り出し。§2.3） |
| **4** | Low | `failedIds` の `HashSet` は `getId()` が `null` の行を 1 件に潰す。A-6 に `null` id のモック行を足すべき | **問題の指摘は妥当だが、提案は採らない** [確認] | **前提（`getId()` が `null` になりうる）が成立しないことを実物で確認し、是正した形で A-6 へ申し送り**（§2.4） |
| **5** | Info | 既存 24 件のテストは握り潰し構造で、A-1 / A-2 の正しさを何も保証していない | **妥当** [確認] | **記録のみ**。`0007` §2.11 の 9（A-6 まで完了してから R0 を出す）を維持（同 13） |
| **6** | Info | 増分コンパイルの落とし穴は現に残っている（`Nothing to compile`） | **妥当** [確認] | **記録のみ**。`0007` §2.11 の 4（A-6 で `mvn clean`）を維持（同 13） |

---

## 2. 各指摘への対応

### 2.1 指摘 1 [Medium] — 「完全に同一」の 1 点の例外

**事実を再確認した** [確認]。

- `storeAllElevateWordsInternal` は削除フェーズを **private な `deleteAllElevateWordInternal(apply, failedIds)`** で駆動する（`(fess) helper/SuggestHelper.java:605`）。**A-2 着手前は `storeAllElevateWords` が public な `deleteAllElevateWord(apply)` を呼んでいた**ため、**サブクラスの override はこの経路に効かなくなっている。**
- **同じ書き換えを受けた `deleteAllBadWords()`（protected）は仮想呼び出しのまま**である（`:778` が本体 `:711-713` を呼ぶ）[確認]。**2 つの削除フェーズで扱いが非対称である。**
- **`SuggestHelper` は DI コンポーネントである** [確認]（`(fess res) app.xml:64`）が、**`grep -rn "extends SuggestHelper" --include='*.java' modules/fess/src` は 0 件** [確認]。

**判断: コードは変えない。** 仮想呼び出しを復元するには `failedIds == null` のときだけ public 側を呼ぶ形にするしかなく、**それは MO-25 の規則（同じロジックの 2 実装を作らない ＝ `0010` §5.1 の要件 3）に真っ向から反する。** **`deleteAllElevateWordInternal` を protected にしても override 対象は `deleteAllElevateWord(boolean)` のままなので、拡張点は復元しない。**

**反映: 記述の側を直した。** `0007` §2.4 の要件 1 と §2.9 の DoD 5 に、**「完全に同一」の例外が 1 点あること・観測可能な挙動（`void`・fail-fast・例外の伝播）は同一であること・差が出るのは継承して override した場合に限られること**を注記した。**レビューの言うとおり、例外を抱えたまま「完全」と記録すると後続ステップが同じ語を根拠に使えなくなる。**

### 2.2 指摘 2 [Medium] — 生キー削除の失敗が失敗件数に混入しうる

**発火経路を独立に確認した** [確認]。

- `deleteOneElevateWordRow`（`:690-700`）は **正規化キー（`:693`）と生キー（`:698`）の 2 回の削除を発行する。** **2 回目は A-1 / MO-24 の移行期クリーンアップであり、行データの妥当性とは無関係である。**
- **writer 層は投げない** — `(sug) index/writer/SuggestIndexWriter.java:83-91` が `catch (final Exception e) { result.addFailure(e); }` で握り、`SuggestHelper` は戻り値を捨てている [確認]。
- **settings 層は投げる** — `(sug) index/operations/WordManagementOperations.java:125-132` の `deleteElevateWord` は、**`settings.elevateWord().delete(normalized)`（`:127`）を `try` の外で実行している** [確認]。ここが `SuggestSettingsException` を投げると `deleteOneElevateWordRow` の外へ伝播し、その行が `failedIds` に入る。
- **発火確率は低い**（設定インデックスへの書き込み障害時に限られる）[推測]。

**判断: A-2 の実装は変えない。** MO-25 の規則 1・3 は「1 行の処理が落ちたら 1 件と数えてスキップする」であり、**実装はそのとおりに動いている。** **論点は A-3 が `exitCode` をどう組むかであり、`0003` 第 13 版 §10.4 (j) は担当範囲を定めているだけで昇格規則までは定めていない** [確認]。

**反映: `0007` §2.11 に申し送り 11 を追加した**（宛先 **A-3**・作業内容 5）。**`0003` §4.2.2 の「不正行を運用者が直すまで世代を更新させない」意図は正規化キー側の失敗にしか合わない**ことを根拠として書いた。

### 2.3 指摘 3 [Low] — 追加ループの呼び出し式の二重化（**唯一のコード修正**）

**修正前**（`storeAllElevateWordsInternal`）: `addElevateWord(...)` の **2 行・6 引数の呼び出しが fail-fast 側と隔離側に逐語的に 2 回**書かれていた。**削除側は `deleteOneElevateWordRow` に括り出し済みで、非対称だった。**

**修正内容**: `storeOneElevateWordRow(ElevateWord, boolean)` を切り出し、2 分岐の双方がこれを呼ぶようにした。

```java
    private void storeOneElevateWordRow(final ElevateWord elevateWord, final boolean apply) {
        addElevateWord(elevateWord.getSuggestWord(), elevateWord.getReading(), elevateWord.getLabelTypeValues(),
                elevateWord.getPermissions(), elevateWord.getBoost(), apply);
    }
```

**これで 3 ループがすべて「1 呼び出しを 2 分岐から呼ぶ」同型になった** [確認]。**「この分岐は失敗隔離の有無だけを切り替えている」という意図が形として表れる**（`readable-code`）。

**挙動は変わらない** [確認]:

- **切り出したのは private メソッドであり、`addElevateWord` の呼び出し自体は仮想呼び出しのまま**である（`storeOneElevateWordRow` の中から public な `addElevateWord` を呼ぶ）。**指摘 1 と同種の拡張点の喪失は起きない。**
- **例外の発生点も伝播経路も同じ**である。`catch (final Exception e)` の位置・`failedIds.add` の位置・`refresh()` の位置と回数はいずれも無変更 [確認]。
- **`0010` §5.1 の要件 14（A-1 / MO-24 が書いた文を変えない）に抵触しない** — `normalizeSeparators` と `deleteOneElevateWordRow` は 1 行も触っていない [確認]。

### 2.4 指摘 4 [Low] — `HashSet` と `null` id（**是正した形で反映**）

**レビューが `[要確認]` として残した「`/_bulk` 復元で `_id` を欠いた行が成立しうるか」を実物で確認した** [確認]。

- `ElevateWord#getId()` は `asDocMeta().id()` を返す（`(fess) opensearch/config/exentity/ElevateWord.java:92-94`）。
- **`selectList` は検索ヒットの `_id` を必ず `docMeta` に入れる** — `(fess) opensearch/config/allcommon/EsAbstractBehavior.java:166` の `docMeta.id(hit.getId())`。
- **`_id` は `/_bulk` 復元でも OpenSearch 自身が採番する**ため、**入口検証を迂回する経路にはならない。** **`getId()` が `null` の行は本番経路では存在しない**（`0010` §2.2 の 2 は正しい）。

**判断: レビューの提案（`getId()` が `null` のモック行を 1 本足す）は採らない。** **到達不能な状態を検査に固定することになる。**

**ただし指摘が突いた危険自体は実在する。** **危険の向きは逆である** — A-6 のテストは Bhv をスタブ化するため、**モック行に id を設定し忘れると `getId()` が `null` になり、`HashSet` が `null` を 1 つに潰す。** その結果、**DoD の「失敗件数 1（等値）」が dedupe ではなく `null` の潰れによって偶然通る**（＝二重計上の回帰を検知できない。`0010` §2.4 が守ろうとしたものが空振りする）。

**反映**: **「モック行には必ず一意で非 `null` の `getId()` を設定する」を A-6 の前提として明記した** — `0007` §2.11 の申し送り 12 ／ `0001-work-plan.md` の **A-6 作業内容 2**。**新しい T 番号は起こさない。**

### 2.5 指摘 5・6 [Info] — 記録のみ

- **指摘 5**: `(fess test) helper/SuggestHelperTest.java:222-297` が `try { ... } catch (Exception e) { assertTrue(true); }` の握り潰し構造であることを確認した [確認]。**24 件が緑であることは A-1 / A-2 の正しさを何も保証しない。** **`0007` §2.11 の 9（フェーズ A は A-6 まで完了してから R0 を先行リリースする）を維持する。**
- **指摘 6**: 本書の検証でも `Nothing to compile - all classes are up to date` が出た [確認]（§3.2）。**`0007` §2.11 の 4（A-6 では `mvn clean` を挟む）を維持する。**

**両者を `0007` §2.11 の申し送り 13 にまとめて記録した。**

---

## 3. 検証結果 [確認]

### 3.1 コード変更の範囲

| 検証 | 結果 |
| --- | --- |
| `git status --short`（`modules/fess`） | **2 ファイル**（`exec/SuggestCreator.java` ／ `helper/SuggestHelper.java`）— **A-2 の時点から増えていない** [確認] |
| `git status --short`（`modules/fess-suggest`） | **空**（無変更）— **C-01 を守っている** [確認] |
| 本書の変更 | **`helper/SuggestHelper.java` のみ**。`storeOneElevateWordRow` の新設（Javadoc 込み **+14 行**）と、2 分岐の呼び出し式の置換（**-2 行**）＝ **正味 +12 行** [確認] |
| `exec/SuggestCreator.java` | **本書では無変更** [確認] |
| 呼び出し元 | **11 箇所・4 クラスは無変更** [確認]（private メソッドの切り出しのため影響しない） |

### 3.2 ビルド・検査

| コマンド | 結果 |
| --- | --- |
| `mvn -o compile` | **BUILD SUCCESS** [確認] |
| `mvn -o formatter:format license:format` → `mvn -o formatter:validate license:check` | **BUILD SUCCESS**（整形差分なし）[確認] |
| `mvn -o test -Dtest=SuggestHelperTest` | **Tests run: 24, Failures: 0, Errors: 0, Skipped: 0** → BUILD SUCCESS [確認] |

> **[確認] このテスト結果は指摘 5 のとおり回帰検知能力を持たない。** **本書の修正が挙動を変えていないことの根拠は、テストではなく「private メソッドへの純粋な括り出しであること」（§2.3）である。** **機械的な裏付けは A-6 で付く。**
>
> **[確認] 指摘 6 のとおり、テスト実行時に `Nothing to compile - all classes are up to date` が出た。** **本書ではテストソースを `touch` してから実行した**（`Compiling 517 source files` を確認）。

### 3.3 `(fess) helper/SuggestHelper.java` の行番号（**`0007` §2.2 / §2.3 / §2.4 / §2.9 の値を上書きする**）

**`:612` 以降が §2.3 の括り出しで最大 +12 行ずれた。以降のステップはこの表を基準にすること**（`0007` §2.11 の 7 と同じ扱い）。

| 要素 | 行 |
| --- | --- |
| `storeAllElevateWords`（public・facade） | `:421-423` |
| `deleteAllElevateWord`（public・facade） | `:453-455` |
| `storeAllElevateWordsForRebuild` | `:481-485`（`new HashSet<>()` = `:482` ／ `return failedIds.size()` = `:484`） |
| `deleteElevateWord`（A-1 / MO-24。**無変更**） | `:508-518` |
| `addElevateWord`（**無変更**） | `:539-561` |
| `normalizeSeparators`（A-1。**無変更**） | `:581-583` |
| `storeAllElevateWordsInternal` | `:602-628`（削除フェーズの駆動 = `:605` ／ `selectList` = `:607-610` ／ `for` = `:612` ／ fail-fast 分岐 = `:613-616` ／ `try` = `:617-618` ／ `catch` = `:619` ／ `failedIds.add` = `:623` ／ 警告ログ = `:624` ／ `refresh()` = `:627`） |
| **`storeOneElevateWordRow`（本書で新設）** | **`:630-642`**（Javadoc = `:630-638` ／ 本体 = `:639-642`） |
| `deleteAllElevateWordInternal` | `:653-678`（`selectList` = `:654-657` ／ `for` = `:659` ／ fail-fast 分岐 = `:660-663` ／ `try` = `:664-665` ／ `catch` = `:666` ／ `failedIds.add` = `:670` ／ `refresh()` = `:677`） |
| `deleteOneElevateWordRow`（**無変更**） | `:690-700`（正規化キー削除 = `:693` ／ 生キー削除 = `:698`） |
| `deleteAllBadWords`（protected・**無変更**） | `:711-713` |
| `storeAllBadWords`（public・facade） | `:729-731` |
| `storeAllBadWordsForRebuild` | `:755-759`（`new HashSet<>()` = `:756` ／ `return failedIds.size()` = `:758`） |
| `storeAllBadWordsInternal` | `:777-796`（`deleteAllBadWords()` = `:778`。**`try` の外** ／ `for` = `:783` ／ fail-fast 分岐 = `:784-787` ／ `try` = `:788-789` ／ `catch` = `:790` ／ `failedIds.add` = `:791` ／ `refresh()` = `:795`） |

---

## 4. 逸脱手続きの判定

> **[確定] 逸脱手続き（X 番号）は発火しない。新しい MO 番号も起こさない。**

**プラン §2.1 の逸脱手続きは「実装中に設計の誤り・不足を発見した場合」に発火する。** **本書が反映した 6 件は設計判断を 1 つも動かしていない。**

| 指摘 | 設計書の改訂 | 理由 |
| --- | --- | --- |
| **1** | **不要** | **設計（MO-25 の規則 6）は正しく、実装もその意図を満たしている。** 是正対象は `0007` の記述の強さであり、設計判断ではない |
| **2** | **不要** | **A-2 の実装は MO-25 のとおりである。** 論点は A-3 が `exitCode` をどう組むかであり、**A-3 の着手時に判断すれば足りる** |
| **3** | **不要** | **private メソッドへの純粋な括り出しであり、`0003` も `0010` §5 も内部の分割については何も述べていない。** 要件 3（同じロジックの 2 実装を作らない）を**より強く**満たす方向の変更である |
| **4** | **不要** | テスト設計の前提であり、`0003` §10.4 (g) の検査 4 点は変えていない（**5 点目を追加したのではなく、既存 4 点の前提条件を明記した**） |
| **5・6** | **不要** | 既知の事項の再確認 |

---

## 5. 次ステップへの申し送り

**本書が新設した申し送りは `0007` §2.11 の 11〜13 である**（重複記載しない）。**要点だけ再掲する。**

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **生キー削除（移行期クリーンアップ）の失敗を世代切替の阻止へ昇格させるかを、`exitCode` 合流の設計時に明示的に判断する**（`0007` §2.11 の 11 ／ 本書 §2.2） | **A-3**（作業内容 5） |
| **2** | **モック行には必ず一意で非 `null` の `getId()` を設定する。`getId()` が `null` の行は検査対象にしない**（`0007` §2.11 の 12 ／ プラン A-6 作業内容 2 ／ 本書 §2.4） | **A-6** |
| **3** | **A-6 まで A-1 / A-2 の正しさに機械的な裏付けは無い。R0 は A-6 まで完了してから出す**（`0007` §2.11 の 9・13 ／ 本書 §2.5） | **R0 のリリース判断** |
| **4** | **A-6 では `mvn clean` を挟む**（`0007` §2.11 の 4・13 ／ 本書 §2.5） | **A-6** |
| **5** | **`0007` が引用する `(fess) helper/SuggestHelper.java` の行番号は本書 §3.3 の表が上書きする** | **A-3〜A-6** |

---

## 6. 参照した一次情報

### 6.1 プロダクションコード / リソース

- `(fess) helper/SuggestHelper.java` — §3.3 の表のとおり
- `(fess) opensearch/config/exentity/ElevateWord.java` — `:92-94`（`getId()` = `asDocMeta().id()`）
- `(fess) opensearch/config/allcommon/EsAbstractBehavior.java` — `:166`（`docMeta.id(hit.getId())`）
- `(fess res) app.xml` — `:64`（`suggestHelper` の DI 登録）
- `(fess test) helper/SuggestHelperTest.java` — `:222-297`（握り潰し構造。**無変更**）
- `(sug) index/operations/WordManagementOperations.java` — `:125-132`
- `(sug) index/writer/SuggestIndexWriter.java` — `:83-91`

### 6.2 タスク内文書

- `0013-review-phase-a-a1-a2.md` — 全体（本書が反映した指摘の正本）
- `0007-phase-a-fess-precede.md` — §2.4 / §2.9 / §2.11（本書で更新）
- `0010-review-response-a2.md` — §2.2 の 2 ／ §2.4 ／ §5.1（要件 3・14）
- `0001-work-plan.md` — §4 ステップ A-3 / A-6（A-6 の作業内容 2 を本書で更新）
- `docs/0003-migration-ops-design.md` — **第 13 版・無変更**（§4.2.2 ／ §10.3.1 の MO-24 ／ §10.4 の MO-25）
