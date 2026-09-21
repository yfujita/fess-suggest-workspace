# 0013: フェーズ A ステップ A-1 / A-2 の実施結果レビュー（**独立検証**）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ A」の **ステップ A-1 / A-2 の実施結果に対するレビュー記録**である。**新しいステップではなく、実装の是正でもない。** 作業履歴 `0007` §1 / §2 の主張を実物（コード・ビルド・テスト）で独立に検証し、未指摘の論点を洗い出したものである。
>
> **本書ではコードも設計書も一切変更していない。** 指摘への対応は本書の完了後に別途判断する（§6）。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[要確認]** = 未解消 ／ **[推測]** = 実測していない推論
>
> **パス短縮表記**: `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/` ／ `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-09-01** |
| 対象 | **ステップ A-1**（`0007` §1 ／ 反映記録 `0008`）／ **ステップ A-2**（`0007` §2 ／ 反映記録 `0009` / `0010`） |
| ブランチ | `modules/fess` の **`feature/suggest-l1-precede`** |
| 検証時の作業ツリー | HEAD = **`73e912715`**（A-1 の実装）／ **A-2 の実装は未コミットの作業ツリー 2 ファイル** [確認] |
| コード変更 | **なし** [確認] |
| 設計書の改訂 | **なし**（**逸脱手続きは発火していない** — 判定は §5） |
| 位置づけ | A-1 に対する 1 回目（`0008`）、A-2 に対する 1 回目・2 回目（`0010` §1〜§12 / §13）に続く**通算 4 回目のレビュー**。**A-1 と A-2 を同時に、実装完了後の作業ツリー全体に対して見た点が過去 3 回と異なる** |

**結果: 指摘 6 件。うち是正の判断を要するのは 2 件（指摘 1・2、いずれも Medium）、改善提案が 2 件（指摘 3・4、Low）、記録のみが 2 件（指摘 5・6、Info）。リリースを止める性質の欠陥は 1 件も無い。**

---

## 1. 検証した事実

**`0007` §2.7 が記録している値を、本書の執筆時点の作業ツリーで独立に再実行した** [確認]。

| 検証 | 結果 |
| --- | --- |
| `git status --short`（`modules/fess`） | **2 ファイル**（`exec/SuggestCreator.java` ／ `helper/SuggestHelper.java`）— `0007` §2.7 と一致 [確認] |
| `git status --short`（`modules/fess-suggest`） | **空**（無変更）— C-01 を守っている [確認] |
| `mvn -o compile` | **BUILD SUCCESS** |
| `mvn -o formatter:validate license:check` | **BUILD SUCCESS**（読み取り専用の検査で確認） |
| `mvn -o test -Dtest=SuggestHelperTest` | **Tests run: 24, Failures: 0, Errors: 0, Skipped: 0** → BUILD SUCCESS |
| `*ForRebuild` の呼び出し元 | **`(fess) exec/SuggestCreator.java:257` / `:261` の 2 箇所のみ** [確認]（`0007` §2.7 の grep と同一の結論） |
| public 3 メソッドの呼び出し元 | **11 箇所・4 クラス**、いずれも無変更 [確認] — `AdminBadwordAction:348,402` ／ `ApiAdminBadwordAction:154,210` ／ `AdminElevatewordAction:379,380,434,435` ／ `ApiAdminElevatewordAction:177,178,236` |
| `deleteElevateWord`（A-1 の対象）の呼び出し元 | **`AdminElevatewordAction:409` / `ApiAdminElevatewordAction:206` の 2 箇所**、いずれも無変更 [確認] |
| `0007` §2.2〜§2.9 が引用する `file_path:line` | **すべて現物と一致** [確認] |

### 1.1 DoD の充足状況（本書の独立判定）

**`0007` §1.9 / §2.9 の自己判定と一致した。**

| ステップ | DoD | 判定 |
| --- | --- | --- |
| **A-1** | 5 項目 | **5/5 充足**（DoD 5「A-6 のテストが緑」は A-6 で閉じる） |
| **A-2** | 10 項目 | **8/10 充足**。**DoD 7（失敗件数が `exitCode` に到達）は A-3、DoD 10（A-6 のテスト）は A-6 で閉じる** — **プラン自身がそう書いており**（`0001-work-plan.md:472` の「（A-3 で完成する）」）、**A-2 の実装不足ではない** |

### 1.2 設計意図の解釈が正しいことの確認 [確認]

**A-1 の `normalizeSeparators` が語中の空白を残す**（`(fess) helper/SuggestHelper.java:581-583`）ことは、**INV-2 に照らして正しい**。

- **INV-2 は「語自身が区切り文字を含まない」**であり（`docs/0002-datamodel-design.md:87`）、**その「語」とは `text` を空白分割して得た配列の各要素**である（同 `:116`）。
- **`0002` §5.4 は W > 1 の elevate word（「東京 タワー」）を正当な入力として明示的に扱っている**（`toSuggestItem` の 4 分岐表）。**語中の空白まで潰すと W > 1 のフレーズが 1 語に潰れ、`SuggestQueryBuilder` の `reading_i` × AND 構造で検索到達不能になる**（`0002` §5.4 の「現行の挙動と、この規則で変わること」の表）。
- したがって **「fess 側は区切り文字の衛生だけを担い、k ≠ W の調停はライブラリ側」というプラン A-1 作業内容 4 の分担は、`0002` §5.4 と整合している** [確認]。**責務の二重化も無い**（A-1 の DoD 2）。

---

## 2. 指摘 1 [Medium] — 「public 3 メソッドの挙動が完全に同一」は厳密には成立していない

### 2.1 事実 [確認]

`storeAllElevateWords(boolean)` は **A-2 着手前は public な `deleteAllElevateWord(apply)` を呼んでいた**が、**現在は private な `deleteAllElevateWordInternal(apply, failedIds)` を呼ぶ**（`(fess) helper/SuggestHelper.java:605`）。

**`SuggestHelper` は DI コンポーネントである** [確認]（`(fess res) app.xml:64` — `<component name="suggestHelper" class="org.codelibs.fess.helper.SuggestHelper">`）。**サブクラスが `deleteAllElevateWord` を override した場合、A-2 着手前は `storeAllElevateWords` 経由でもその override が効いたが、現在は効かない。**

**同じ書き換えを受けた `deleteAllBadWords()`（protected）は、依然として仮想呼び出しのまま残っている** [確認]（`:766` が `storeAllBadWordsInternal` から本体 `:699-701` を呼ぶ）。**2 つの削除フェーズで扱いが非対称である。**

### 2.2 影響 [確認]

**現時点の実害はゼロである。** `grep -rn "extends SuggestHelper" --include='*.java' modules/fess/src` の結果は **0 件** [確認]。

### 2.3 判定

**実装を変える必要は無い。** ただし **`0007` §2.4 の要件 1・§2.9 の DoD 5 が無条件に「完全に同一」と断じている記述は、この 1 点で厳密には成り立っていない** [確認]。**記述の側に注記を足すのが正確である** [提案]。

> **本書が指摘 1 を Medium に置いた理由**: 実害ではなく、**`0010` §5.1 の要件 1 が MO-25 の規則 6 の中身そのものであり、その充足判定が「完全に同一」という強い語で閉じられている**ためである。**例外を 1 つ抱えたまま「完全」と記録すると、後続ステップが同じ語を根拠に使えなくなる。**

---

## 3. 指摘 2 [Medium] — 失敗件数に「移行期クリーンアップの失敗」が混入しうる

### 3.1 事実 [確認]

`deleteOneElevateWordRow`（`(fess) helper/SuggestHelper.java:678-688`）は **2 回の削除を発行する** — 正規化キー（`:681`）と、正規化で語が変わった場合の**生キー**（`:686`）。**この 2 回目は A-1 / MO-24 が入れた移行期クリーンアップであり、行データの妥当性とは無関係である。**

**この 2 回目が投げると、その行は `failedIds` に入る**（`:654-660`）。**A-3 で戻り値が `exitCode` に合流すると、G3 が世代切替を止める。**

### 3.2 発火経路の実測 [確認]

**writer 層は投げない** — `(sug) index/writer/SuggestIndexWriter.java:83-91` の `delete` は `catch (final Exception e) { result.addFailure(e); }` で握り、`SuggestHelper` は戻り値の `SuggestDeleteResponse` を捨てている。

**ただし settings 層は投げる** [確認] — `(sug) index/operations/WordManagementOperations.java:125-132` の `deleteElevateWord` は、writer を呼ぶ前に **`settings.elevateWord().delete(normalized)`（`:127`）を try の外で実行している。** ここが `SuggestSettingsException` を投げると `deleteOneElevateWordRow` の外へ伝播する。

**発火確率は低い** [推測]（設定インデックスへの書き込み障害時に限られる）。

### 3.3 判定

**A-2 の実装バグではない** — MO-25 の規則 1・3 は「1 行の処理が落ちたら 1 件と数えてスキップする」であり、実装はそのとおりに動いている。

**論点は A-3 の側にある** [提案]。`0003` §4.2.2 の「**不正行を運用者が直すまで世代を更新させない**」という意図は、**正規化キー側の失敗（＝行データが壊れている）には合うが、生キー側の失敗（＝過去のゴミの掃除に失敗した）には合わない。** **A-3 で `exitCode` への合流を設計するときに「どの失敗を切替阻止へ昇格させるか」を一度考える価値がある。**

> **`0007` §2.11 の申し送りに 1 本追加することを提案する** [提案]（宛先: **A-3**）。

---

## 4. 指摘 3・4 [Low] — 改善提案

### 4.1 指摘 3 — 3 ループの呼び出し式が二重化している

**`if (failedIds == null) { X; continue; } try { X; } catch ...` の形は、`X` を逐語的に 2 回書く** [確認]。

| ループ | fail-fast 側 | 隔離側 | 重複の量 |
| --- | --- | --- | --- |
| elevate word 削除（`:648-661`） | `:649` | `:653` | **1 行**（`deleteOneElevateWordRow` に括り出し済み） |
| **elevate word 追加**（`:613-628`） | **`:614-615`** | **`:619-620`** | **2 行・6 引数の呼び出しが逐語的に 2 回** |
| bad word 追加（`:772-782`） | `:773` | `:776` | 1 行 |

**削除側は `deleteOneElevateWordRow`（`:678`）に括り出したのに、追加側は括り出していない**という非対称がある。`0010` §5.1 要件 3（「同じロジックの 2 実装を作らない」）は満たしているが、**将来 `addElevateWord` の引数が増えたときに片方だけ直す事故が起こりうる。**

**[提案]**: `storeOneElevateWordRow(ElevateWord, boolean)` 相当を切り出せば **3 ループがすべて同じ形になる。** **`readable-code` の観点でも、3 ループが同型であることが「この分岐は失敗隔離の有無だけを切り替えている」という意図を最も強く表す。**

### 4.2 指摘 4 — `failedIds` の `HashSet` は `getId()` が `null` の行を 1 件に潰す

`storeAllElevateWordsForRebuild`（`:482`）／ `storeAllBadWordsForRebuild`（`:744`）は `new HashSet<>()` を使う。**`HashSet` は `null` 要素を 1 つだけ保持できるため、`getId()` が `null` の行が複数あっても失敗件数は 1 になる。**

**`0010` §2.2 の 2 は「`getId()` は `selectList` 経由の行で `null` にならない」としている**が、**A-2 が守ろうとしている `/_bulk` 復元こそが入口検証を迂回する経路そのものである** [要確認]。**`_id` を欠いた復元が成立しうるかは本書では確認していない。**

**影響は件数の過小評価に限られ、`exitCode != 0` の判定自体は成立する**（1 件でも非ゼロ）ため、**実害は小さい。**

**[提案]**: **A-6 のテストに `getId()` が `null` のモック行を 1 本足す**のが安い（宛先: **A-6**）。

---

## 5. 指摘 5・6 [Info] — 記録のみ

### 5.1 指摘 5 — A-1 / A-2 の振る舞いは 1 つも機械的に検査されていない

**既存の `(fess test) helper/SuggestHelperTest.java:222-297` は、対象 6 メソッドすべてについて `try { ... ; assertTrue(true); } catch (Exception e) { assertTrue(true); }` の握り潰し構造である** [確認]。**成功しても失敗しても緑になるため、24 件が緑であることは A-1 / A-2 の正しさを何も保証しない。**

**これは `0007` §2.9 の DoD 10 が A-6 送りにしているとおりであり、A-2 の不足ではない。** ただし**現状は「A-2 完了」と「A-2 が正しい」の間に機械的な裏付けが無い**状態であることを、リリース判断の材料として明記しておく。

**`0007` §2.11 の 9（フェーズ A は A-6 まで完了してから先行リリースする）は妥当である** [確認]。**本書はこの申し送りを支持する。**

### 5.2 指摘 6 — 増分コンパイルの落とし穴は現に残っている

**本書の `mvn -o test -Dtest=SuggestHelperTest` も、`testCompile` が `Nothing to compile - all classes are up to date` と出したうえで 24 件が緑になった** [確認]。**`0007` §2.7 の枠が警告しているとおりの状態である**（既に再コンパイル済みのため症状は再現しない）。

**A-6 は既存テストを必ず再コンパイルさせる必要があるため、`mvn clean` を挟むこと** [提案]（宛先: **A-6**。`0007` §2.11 の 4 と同旨）。

---

## 6. 逸脱手続きの判定

> **[確定] 逸脱手続き（X 番号）は発火しない。**

プラン §2.1 の逸脱手続きは「**実装中に設計の誤り・不足を発見した場合**」に発火する。**本書の指摘 6 件はいずれも設計判断を動かさない。**

| 指摘 | 設計書の改訂 | 理由 |
| --- | --- | --- |
| **1** | **不要** | **設計（MO-25 の規則 6）は正しく、実装もその意図を満たしている。** 是正対象は**作業履歴 `0007` の記述の強さ**であり、設計判断ではない |
| **2** | **不要** | **A-2 の実装は MO-25 のとおりである。** 論点は **A-3 が `exitCode` をどう組むか**であり、**A-3 の着手時に判断すれば足りる**（`0003` 第 13 版 §10.4 (j) は担当範囲を定めているだけで、昇格規則までは定めていない）[確認] |
| **3・4** | **不要** | 実装内部の形とテスト設計の提案であり、設計書は何も述べていない |
| **5・6** | **不要** | 既知の事項の再確認 |

---

## 7. 次ステップへの申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **`0007` §2.4 の要件 1・§2.9 の DoD 5 の「完全に同一」に、`storeAllElevateWords` → `deleteAllElevateWord` の仮想呼び出しが private 呼び出しに変わった 1 点の例外があることを注記する** [提案]。**実装は変えない**（`extends SuggestHelper` は 0 件） | **`0007` の追補** |
| **2** | **A-3 で `exitCode` への合流を組むとき、「生キー削除（移行期クリーンアップ）の失敗を切替阻止へ昇格させるか」を明示的に判断する** [提案]。`0003` §4.2.2 の意図は正規化キー側の失敗にしか合わない（§3.3） | **A-3**（作業内容 5） |
| **3** | **elevate word 追加ループの 2 行・6 引数の呼び出しを `storeOneElevateWordRow` 相当に括り出し、3 ループを同型にする** [提案]。削除側（`deleteOneElevateWordRow`）と揃う（§4.1） | **A-2 の追補**（任意）／ **F-5** |
| **4** | **A-6 のテストに `getId()` が `null` のモック行を 1 本足す** [提案]（§4.2）。**`0007` §2.11 の 2 が挙げる 4 点に対する 5 点目**として扱う | **A-6** |
| **5** | **A-6 では `mvn clean` を挟む** [提案]。本書の実行でも `Nothing to compile` が出ている（§5.2） | **A-6** |
| **6** | **本書はリリースを止める欠陥を 1 件も検出しなかった。** ただし **§5.1 のとおり A-6 まで機械的な裏付けが無い**ため、**`0007` §2.11 の 9（A-6 まで完了してから先行リリース）を維持すること** | **フェーズ A のリリース判断** |

---

## 8. 参照した一次情報

### 8.1 プロダクションコード / リソース

- `(fess) helper/SuggestHelper.java` — `:422` / `:454` / `:481-485` / `:602-630` / `:641-666` / `:678-688` / `:718` / `:743-746` / `:765-784` / `:810-815`
- `(fess) exec/SuggestCreator.java` — `:257` / `:261`
- `(fess) app/web/admin/elevateword/AdminElevatewordAction.java` — `:379-380` / `:401-418`（`delete()`。**`elevateWordService.delete(entity)` が `suggestHelper.deleteElevateWord(...)` より先に走るため、suggest 側の失敗で DB 行が残ることは無い** [確認]）／ `:434-435`
- `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java` — `:177-178` / `:206` / `:236`
- `(fess) app/web/admin/badword/AdminBadwordAction.java` — `:348` / `:402`
- `(fess) app/web/api/admin/badword/ApiAdminBadwordAction.java` — `:154` / `:210`
- `(fess res) app.xml` — `:64`
- `(fess test) helper/SuggestHelperTest.java` — `:222-297`
- `(sug) entity/ElevateWord.java` — `:66`（コンストラクタが `final float boost`。アンボクシング NPE の根拠）
- `(sug) index/operations/WordManagementOperations.java` — `:125-132`
- `(sug) index/writer/SuggestIndexWriter.java` — `:83-91`

### 8.2 タスク内文書

- `0001-work-plan.md` — §4 ステップ A-1 / A-2 / A-3 / A-6 ／ `:472`
- `0007-phase-a-fess-precede.md` — §1（A-1）／ §2（A-2。特に §2.4 / §2.7 / §2.9 / §2.11）
- `0008-review-response-a1.md` ／ `0009-deviation-x5-store-all-delete-phase.md` ／ `0010-review-response-a2.md`（§2.2 / §5.1 / §7 / §13）
- `docs/0002-datamodel-design.md` — `:87`（INV-2）／ `:116` ／ §5.2 ／ **§5.4**
- `docs/0003-migration-ops-design.md` — 第 13 版 §10.3 / §10.3.1（MO-24）／ §10.4（MO-25。(e) / (f) / (i) / (j)）／ §4.2.2 ／ §13 の 8
