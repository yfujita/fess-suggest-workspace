# 0009: 逸脱 X-5 — 全件再投入系メソッドの失敗隔離が削除フェーズを勘案していない（区分 I）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ A」**ステップ A-2** の**着手時に発火した**逸脱の記録である（同 §9.1 の注記「実装中に新たな逸脱が発生した場合は、その時点の最大番号 +1 で独立ファイルを作る。フェーズのファイルに混ぜない」に従う）。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[確定]** = 決定済み ／ **[要確認]** = 未解消
>
> **パス短縮表記**: `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` ／ `(sug res)` = `modules/fess-suggest/src/main/resources/` ／ `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-08-31** |
| 対象ステップ | **A-2**（**着手時に発火**） |
| 逸脱区分 | **区分 I（設計判断の誤り・不足）** — プラン §2.1 ／ 判定理由は本書 §3 |
| X 番号 | **X-5（新規に起こした）** — 判定理由は本書 §3.2 |
| 改訂した設計書 | `docs/0003-migration-ops-design.md` — **第 11 版 → 第 12 版** |
| 採番した決定 | **MO-25**（改訂前の最大は MO-24） |
| コード変更 | **なし**（逸脱手続きは「改訂を先に行う」ことを要求する。**A-2 の実装は本書の完了後に着手する**） |

**結果: 設計書の改訂が完了した。ステップ A-2 の実装（削除フェーズを含む最終形）に着手してよい。**

> **行番号の基準** [確認]: 本書の `(fess) helper/SuggestHelper.java` の行番号は、**ステップ A-1 ＋ `0008` のレビュー反映を適用した現作業ツリー**（`modules/fess` の `feature/suggest-l1-precede`。**未コミット変更を含む**）を基準にする。`0008` §4.1 が是正した値と同じ基準であり、**本書の執筆にあたって全件を実物で開き直して確認した**（§8）。

---

## 1. 発見の経緯

**ステップ A-2 の着手時、対処対象である `storeAllElevateWords` の実体を読んだ時点で発見した。実装は 1 行も書いていない。**

| 項目 | 状態 |
| --- | --- |
| **A-1 の実装** | **適用済み・未コミット**（`0007` §1 ／ `0008` §4）。`modules/fess` の作業ツリーに `helper/SuggestHelper.java` の未コミット変更がある |
| **A-2 の実装** | **未着手。本書の作業でのコード変更は無い** |
| **`modules/fess-suggest`** | **無変更** [確認] |

**プラン §4 ステップ A-2 は `0003` §10.4 を設計書の対応として指している。** **その §10.4 の対処方針が、`storeAllElevateWords` の制御フローの半分しか見ていなかった。**

---

## 2. 事象 — §10.4 の対処範囲が追加フェーズに閉じている

> **`0003` §10.4（第 11 版）は「1 件の変換失敗で全体を止めない」を追加フェーズ（`SuggestItem` 化）だけに掛けており、`storeAllElevateWords` が最初に駆動する削除フェーズを勘案していない。**
> **その結果、対処方針を字義どおり実装しても「再構築全体が失敗するのを防ぐ」は成立しない。**

### 2.1 第 11 版までの対処方針（原文）

> 「`storeAllElevateWords` / `storeAllBadWords` において、**1 件の変換失敗**で全体を止めず、警告ログを出してスキップし、末尾で失敗件数を `exitCode` に反映する」

### 2.2 根拠 [確認]

**すべて実物を開いて確認した。**

#### (1) `storeAllElevateWords` は同じ DB 行集合を 2 周する

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 1a | `storeAllElevateWords` は**本体のループに入る前に** `deleteAllElevateWord(apply)` を呼ぶ | `(fess) helper/SuggestHelper.java:411` / `:412` |
| 1b | 追加フェーズは自身の `selectList` を発行してループする | 同 `:414-417`（`selectList`）／ `:419-422`（ループ） |
| 1c | 削除フェーズも**独立した `selectList`** を発行してループする。**2 つのフェーズは行オブジェクトを共有しない** | 同 `:437`（`deleteAllElevateWord`）／ `:438-441`（`selectList`）／ `:443-453`（ループ） |

#### (2) DB エンティティの getter は不正行に対して `null` を返しうる

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 2a | `getSuggestWord()` は `convertEmptyToNull(suggestWord)` を返す。**`suggestWord` が空文字または未設定の行では `null` が返る** | `(fess) opensearch/config/bsentity/BsElevateWord.java:190-193` |
| 2b | `convertEmptyToNull` は `value.length() == 0` を `null` に変換する | `(fess) opensearch/config/allcommon/EsAbstractEntity.java:199-201` |
| 2c | `boost` は **`Float`（ラッパ型・null 許容）**であり、`getBoost()` は素の値を返す | 同 `BsElevateWord.java:41` / `:140-143` |
| 2d | bad word 側も同型である | `(fess) opensearch/config/bsentity/BsBadWord.java:153-156` |
| 2e | **mapping にも不正行を止める仕組みは無い。** `suggestWord` / `reading` は `keyword`、`boost` は `float` と宣言されるだけで**必須制約を持たない**（OpenSearch の mapping は必須項目を表現できない） | `(fess res) fess_indices/fess_config.elevate_word/elevate_word.json` |

#### (3) 削除フェーズは 1 件の `null` で確実に落ちる

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 3a | A-1（MO-24）で削除ループに `normalizeSeparators(rawWord)` が入った | `(fess) helper/SuggestHelper.java:444-445` |
| 3b | `normalizeSeparators` の実体は `text.replace("　", TEXT_SEP)...` であり、**`null` に対して無条件に NPE を投げる** | 同 `:551-553` |

#### (4) **これは A-1 が持ち込んだ回帰ではない**（穴は §10.4 執筆時点から存在した）

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 4a | ライブラリ側の `Normalizer` は **null セーフで `null` を素通しする** | `(sug) normalizer/NormalizerChain.java:55-58`（`text == null` なら `null` を返す）／ `(sug) normalizer/AnalyzerNormalizer.java:100-103`（同型） |
| 4b | したがって A-1 以前も、削除経路は `deleteElevateWord` → `createSuggestTextId(null)` → `text.getBytes(...)` で NPE になった | `(sug) index/operations/WordManagementOperations.java:125-132` ／ `(sug) util/SuggestUtil.java:91-92` |

> **ただし A-1 は「落ちる呼び出し元」の範囲を広げている** [確認]。**これは §2.2 の (4) を報告どおり「発生位置の前倒しだけ」とすると取りこぼす事実であり、本書で追加確認した。**
>
> | 時点 | `apply = true`（再構築経路） | `apply = false`（管理画面経路） |
> | --- | --- | --- |
> | **A-1 以前** | **NPE**（`(sug) util/SuggestUtil.java:92`） | **落ちない。** NPE 発生点が `if (apply)` の**内側**にあるため（`(sug) index/operations/WordManagementOperations.java:128`）。`settings.elevateWord().delete(null)` は `createId` の文字列連結で `"value:null"` になるだけで例外にならない（`(sug) settings/ArraySettings.java:169-175` / `:192-193`）[確認] |
> | **A-1 以後** | **NPE**（`(fess) helper/SuggestHelper.java:552`） | **NPE。** `normalizeSeparators` は `apply` に関わらず呼ばれる |
>
> **管理画面経路は 3 箇所である**: `(fess) app/web/admin/elevateword/AdminElevatewordAction.java:379` / `:434` ／ `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:177`（いずれも `deleteAllElevateWord(false)`）。
> **「穴そのものは §10.4 執筆時点から存在していた」ことと「A-1 が影響範囲を広げた」ことは両立する。** 本書はどちらも事実として記録する。**A-2 の実装（失敗隔離）は後者も同時に閉じる**（§6 の規則 6）。

#### (5) 追加フェーズにも「`SuggestItem` 化の失敗」以外の失敗要因がある

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 5a | `addElevateWord` の第 5 引数は **`Float`（ラッパ型）**である | `(fess) helper/SuggestHelper.java:509-510` |
| 5b | 同メソッドは `new org.codelibs.fess.suggest.entity.ElevateWord(normalizedWord, boost, ...)` を呼ぶ | 同 `:527` |
| 5c | **`(sug) entity/ElevateWord` のコンストラクタの第 2 引数は `float`（プリミティブ）である。** `boost` が `null` の行は**アンボクシングで NPE** になり、**`SuggestItem` の INV-1 検査に到達する前に落ちる** | `(sug) entity/ElevateWord.java:66-67` |
| 5d | `suggestWord` が `null` の行は、そもそも `normalizeSeparators(word)` で落ちる | `(fess) helper/SuggestHelper.java:511` |

#### (6) 例外は `create()` の外まで伝播する

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 6a | `storeAllBadWords(true)` / `storeAllElevateWords(true)` はいずれも try 節の外にある | `(fess) exec/SuggestCreator.java:255` / `:258`（`create()` は `:243-304`） |
| 6b | `process()` の `creator.create()` も try で囲われていない。**`ret == 0` のときだけ `purge()` が走る** | 同 `:235-239` |

#### (7) bad word 側には同じ穴が無い

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 7a | `storeAllBadWords` が最初に呼ぶ `deleteAllBadWords()` は `settings.badword().deleteAll()` の **1 呼び出し**であり、**行単位ループを持たない** | `(fess) helper/SuggestHelper.java:558-560`（`deleteAllBadWords`）／ `:567`（`storeAllBadWords`）／ `:568`（駆動） |
| 7b | 追加フェーズだけがループを持つ | 同 `:573-576` |

> **報告時に共有されていた `deleteAllBadWords()` = `:550` は実物と食い違う。実物は `:558-560` である**（§8）。

### 2.3 帰結 [確認]

| # | 帰結 |
| --- | --- |
| **1** | **`suggestWord` が空の行が 1 件あるだけで `storeAllElevateWords` は削除フェーズで落ち、追加ループのスキップ機構に到達しない。** **§10.4 が達成しようとした「再構築全体が失敗するのを防ぐ」は成立しない** |
| **2** | **プラン §4 ステップ A-2 の DoD 1（「不正な elevate word を 1 件含む入力で `storeAllElevateWords` が完走し、失敗件数 1 を報告する」）も満たせない** |
| **3** | `boost` が `null` の行では、追加ループが `SuggestItem` 化の手前で落ちる。**「変換失敗をスキップする」を `SuggestItem` の構築だけに掛けた実装は、この行を取りこぼす** |
| **4** | **この不足は L1 を待たずに現行バイナリで顕在化している。** §2.2 の (4) のとおり `apply = true` の再構築経路では A-1 以前から NPE になる。**§10.4 が「INV-1 強制がバッチ全体を落としうる経路」という将来形で書かれていたことが、現在の欠陥を隠していた** |

---

## 3. 区分と X 番号の判定

### 3.1 区分 I と判定した理由

| # | 理由 |
| --- | --- |
| **1** | **観測値の訂正ではない。** 変わるのは **§10.4 の対処範囲という設計判断**である。「どのループに失敗隔離を適用するか」「失敗件数の集計単位をどう定義するか」はいずれも新しい決定であり、区分 II（「設計の内容が変わらないこと」を積極的に示せる場合）にはあたらない |
| **2** | **プラン §2.1 の「設計どおり実装すると成立しない」に直接あたる。** §2.3 の帰結 1・2 のとおり、第 11 版の §10.4 を字義どおり実装しても目的が達成されず、A-2 の DoD も満たせない |
| **3** | プラン §2.1 の「**判定に迷ったら区分 I として扱う**」に合致する |

> **区分 II 相当の付随訂正が 2 件ある**（§8）。本体ではないため区分 I の手続きの中で一緒に処理した — `0006` §3 の 3 と同じ扱いである。

### 3.2 新しい X 番号（X-5）を起こした理由

**先例は `0008` §2.5 である。** 同書は `0003` 第 11 版の改訂について「**MO-24 の内部の根拠の是正であり、新しい設計判断を追加していない**」として新しい X 番号を起こさなかった。**本件はその基準の対偶にあたる。**

| # | 理由 |
| --- | --- |
| **1** | **新しい設計判断を追加している。** §10.4 の対処範囲を削除フェーズへ拡張し、**失敗件数の集計単位**（合算／行数ではなく項目処理数）を新たに定める |
| **2** | **新しい MO 番号（MO-25）を採番する。** `0008` の改訂は MO-24 の (d) 3 を書き直しただけで採番していない |
| **3** | **実装への要件が変わる。** プラン §4 ステップ A-2 の対象メソッド・作業内容・DoD がいずれも変わる（§7） |
| **4** | **既存の MO の内部ではない。** MO-25 は MO-24 とは独立した決定であり、「X-4 の追補」として扱うと台帳の対応関係が壊れる |

---

## 4. 検討した代替案と採否

### 4.1 案 1 — 失敗隔離をどこに掛けるか

| # | 案 | 判定 | 理由 |
| --- | --- | --- | --- |
| **(a)** | **`storeAll*` が駆動するすべての行単位ループ（削除フェーズを含む）に掛ける** | **採用** | **目的（再構築全体を 1 件の不正行で落とさない）に必要十分。** 対象は `(fess) helper/SuggestHelper.java` の 3 メソッドに閉じ、fess-suggest 側を触らない。**フェーズ A の「先行リリースできる安全網」の範囲に収まる** |
| **(b)** | 追加フェーズだけに掛け、削除フェーズは `deleteAllElevateWord` の呼び出し全体を `try` で包んで丸ごとスキップする | **不採用** | **1 件の不正行で削除フェーズ全体が飛ぶ。** 削除フェーズは「前世代由来の settings エントリと生キー文書を掃除する」役割を持つ（MO-24 ／ `0003` §10.3.1 (c)）ため、丸ごと飛ばすと**掃除が行われないまま新世代が作られる**。**粒度が粗すぎる** |
| **(c)** | 削除フェーズを `storeAllElevateWords` から外す（次世代インデックスは新規作成されるので削除は不要という理屈） | **不採用** | **成立しない。** `deleteElevateWord` は **suggest ドキュメントの削除と settings エントリの削除の 2 段操作**であり（`(sug) index/operations/WordManagementOperations.java:125-132`）、**settings は世代をまたいで共有される**（`(sug) settings/ArraySettings.java:182-184` の `createArraySettingsIndexName` は `{settingsIndexName}_array` を返すだけで世代名を含まず、`settingsIndexName` の既定値は `(sug) settings/SuggestSettingsBuilder.java:36` の `"fess_suggest"` — 世代ごとに変わらない）[確認]。削除フェーズを外すと settings 側の掃除が失われる。**加えて `deleteAllElevateWord` は管理画面から直接も呼ばれる**（§2.2 の (4)）ため、本メソッドの責務を変えると影響が A-2 の外へ出る |
| **(d)** | 入口側（backup の `/_bulk` 復元）にバリデーションを入れて不正行が入らないようにする | **不採用（本タスクでは）** | **`0003` §13 の 8 が後続スコープと定めており、第 12 版でもこれを変えていない。** また入口を塞いでも**既に DB に入っている不正行**は残るため、出口側の隔離は結局必要である |

### 4.2 案 2 — 失敗隔離を `deleteAllElevateWord` の外に置くか中に置くか

| # | 案 | 判定 | 理由 |
| --- | --- | --- | --- |
| **(a)** | **`deleteAllElevateWord` のループ本体に置く**（＝管理画面の 3 経路にも及ぶ） | **採用** | **ループはそこにしかない。** 隔離した「安全版」を別実装として持つと **MO-24 の規則 1（追加側と削除側で別実装を持たない）と同型の乖離**を新たに作る。**加えて現状は 1 件の不正行があるだけで elevate word の編集・アップロードがすべて失敗する**（各経路が `catch (Exception)` でバリデーションエラーに変換する）ため、**スキップ＋警告ログの方が運用上厳密に良い** |
| **(b)** | 行単位の private ヘルパを切り出し、`storeAllElevateWords` だけが隔離版のループを回す | **不採用** | **同じロジックの 2 実装になる。** 得られるのは「管理画面では従来どおり例外にする」という互換性だけだが、**その従来動作は「不正行 1 件で管理画面が使えなくなる」**であり、守る価値が無い |

### 4.3 案 3 — 失敗件数の集計単位

| # | 案 | 判定 | 理由 |
| --- | --- | --- | --- |
| **(a)** | **削除フェーズと追加フェーズを合算して 1 つの数にする**（「失敗した項目処理の件数」。**行数ではない**） | **採用** | 根拠は §5 |
| **(b)** | フェーズ別に 2 つの数を返す | **不採用** | **G3 は件数を 0 / 非 0 の二値としてしか使わない**（`0003` §4.2 / §4.2.2）ため、内訳を分けても判定は変わらない。呼び出し元（A-3 のガード）が読む数が増えるだけである |
| **(c)** | 「失敗した**行数**」で数える（同一行の 2 フェーズ失敗を 1 と数える） | **不採用** | **削除フェーズと追加フェーズは別々の `selectList`** であり（§2.2 の (1)）、行を突き合わせる鍵は `suggestWord` — **まさに `null` になっている値**である。**突き合わせは実装できないか、できても脆い。** 運用上必要なのは「どの行が落ちたか」であり、それは警告ログが与える |

---

## 5. 失敗件数を合算する根拠（設計判断）

| # | 根拠 | 出典 |
| --- | --- | --- |
| **1** | **G3 の判定式は `exitCode == 0` であり、件数を 0 / 非 0 の二値としてしか使わない。** §4.2.2 は「**全件再構築では 1 件の失敗でも不合格とする。閾値を設けると『何件までなら公開してよいか』を実測なしに決めることになる**」と明記しており、**閾値を持たない以上、内訳を分けても判定は変わらない** | `0003` §4.2（G3 の行）／ §4.2.2 |
| **2** | §4.2.2 は「**取り込みと語管理の両方が 1 つのガードに集まる**」ことを既に定めている。**フェーズ別に分けるのはこの集約方針と逆行する** | `0003` §4.2.2 |
| **3** | **分けると `exitCode` へ落とす経路が 1 本増えるだけで得るものが無い** | `0003` §4.3（ガードの配置） |
| **4** | **「行数」で数える案は §4.3 の (c) のとおり実装できない／脆い** | 本書 §4.3 |

> **帰結: A-2 の DoD は「失敗件数が 1」ではなく「失敗件数が 1 以上で報告され、警告ログに落ちた行が記録されていること」で閉じる。** **1 件の不正行が 2 件（削除フェーズ ＋ 追加フェーズ）として数えられることは仕様である。**

---

## 6. `0003` 第 12 版の改訂内容

**改訂したのは `docs/0003-migration-ops-design.md` の 1 本のみである**（`docs/0002` / `docs/0001` / `docs/0000` / `docs/0004` はいずれも無変更 — 理由は §9）。

| # | 箇所 | 内容 |
| --- | --- | --- |
| 1 | **冒頭「現在の版」**（`:3`） | 第 11 版（2026-08-31）→ **第 12 版（2026-08-31）** |
| 2 | **冒頭宣言**（`:16`） | **「第 12 版で解消する設計上の不足（逸脱 X-5・区分 I）」の 1 行を追加**（第 11 版の同種の行の直後・同じ書式） |
| 3 | **改訂履歴**（`:33`） | **第 12 版の行を追加。**「作業履歴」列は `20260822_implementation/0009` |
| 4 | **§0 の決定表**（`:68`） | **MO-25 の行を追加**（MO-24 の行の直後。節参照は §10.4） |
| 5 | **§4.2.2 の判断表**（`:368`） | 語管理経路の行に**集計単位への参照を 1 文追加**（「その失敗件数は削除フェーズと追加フェーズの合算値 1 つである」）。**同行の「1 件の変換失敗」を「1 件の失敗」に改めた**（追加フェーズに限定されない表現へ） |
| 6 | **§10.4 を全面的に書き直した**（`:937-1032`） | **表題を「全件再投入系メソッドの失敗隔離（backup 復元経由の不正データ）」に改めた** ／ (a) 入口（`/_bulk` 復元 ＋ mapping に必須制約が無いこと） ／ (b) 何が足りなかったか（**なぜ見落としたかの構造的原因を含む**） ／ (c) 根拠 8 件 ／ (d) 帰結 3 件 ／ **(e) MO-25 の規則 7 項** ／ **(f) 合算する根拠 4 件** ／ (g) 検証 3 点 ／ **(h) `0002` / `0001` への波及が無いことの明記** |

**変更していないもの** [確認]: **MO-1〜MO-24 は無変更。** **§11 のテスト仕様（T 番号）は無変更**（新しい T 番号を起こしていない）。**§13 の 8（復元時バリデーションは後続スコープ）は無変更** — **入口側は塞がない方針は不変である**（§10.4 (e) の規則 7 に再掲した）。**mapping・§3〜§9・§12 のいずれにも触れていない。**

### 6.1 MO-25 の規則（設計書からの再掲）

| # | 規則 |
| --- | --- |
| **1** | 失敗隔離は `storeAll*` が駆動する**すべての行単位ループ**に適用する（削除フェーズ `:443-453` ＋ 追加フェーズ `:419-422`） |
| **2** | 1 行の処理を `try` で囲み、**例外の型を問わず**スキップする。握り潰さず、対象行の識別情報と例外を警告ログに出す |
| **3** | 失敗件数は**削除フェーズと追加フェーズを合算して 1 つの数**とする。**「失敗した項目処理の件数」であって「行数」ではない** |
| **4** | 失敗件数は**呼び出し元が読める形で返す**。**`SuggestHelper` のインスタンスフィールドに保持してはならない**（シングルトン ＋ 非同期呼び出しのため） |
| **5** | **`storeAllBadWords` の削除フェーズは対象外**（行単位ループを持たない）。**非対称は意図的** |
| **6** | 失敗隔離は `deleteAllElevateWord` のループ本体に置くため**管理画面の 3 経路にも及ぶ**。これは受け入れる |
| **7** | **入口側（backup の `/_bulk` 復元）は塞がない**（§13 の 8 は不変） |

---

## 7. 実装側が満たすべき仕様（次工程への引き渡し）

> **本書はコードを変更していない。** 以下は **A-2 の実装を担当するエージェントが満たすべき最終形**であり、`0003` 第 12 版 §10.4 (e) の規則を擬似コードに落としたものである。

**対象は `(fess) helper/SuggestHelper.java` の 3 メソッドに閉じる。fess-suggest 側は触らない。**

```text
// 0) 失敗件数の受け渡し
//    [提案] 3 メソッドの戻り値を void -> int（失敗した項目処理の件数）に変える。
//    - void -> int は既存の呼び出し文（式文）に対して source-compatible である。
//    - SuggestHelper は DI のシングルトン（(fess res) app.xml:64）であり、
//      管理画面から CommonPoolUtil.execute 経由で非同期に呼ばれるため、
//      インスタンスフィールドへの保持は禁止（MO-25 の規則 4）。
//    最終的な受け渡し形は A-3 のガード実装と合わせて確定する（プラン A-2 の作業内容 2）。

// 1) deleteAllElevateWord(apply) : int
deleteAllElevateWord(apply):
    failures = 0
    for elevateWord in ElevateWordBhv.selectList(...):     // :438-441
        try:
            raw = elevateWord.getSuggestWord()             // null になりうる
            normalized = normalizeSeparators(raw)          // <- 現状ここで NPE
            suggester.indexer().deleteElevateWord(normalized, apply)
            if (!normalized.equals(raw)):
                suggester.indexer().deleteElevateWord(raw, apply)   // MO-24 の両キー削除
        catch (Exception e):                               // 型を問わない（MO-25 規則 2）
            failures++
            logger.warn("Failed to delete an elevate word: id={}", elevateWord.getId(), e)
            // suggestWord は null でありうるため、単独の識別子にしない
    refresh()
    return failures

// 2) storeAllElevateWords(apply) : int
storeAllElevateWords(apply):
    failures = deleteAllElevateWord(apply)                 // 削除フェーズの件数を引き継ぐ（合算）
    for elevateWord in ElevateWordBhv.selectList(...):     // :414-417
        try:
            addElevateWord(elevateWord.getSuggestWord(), elevateWord.getReading(),
                           elevateWord.getLabelTypeValues(), elevateWord.getPermissions(),
                           elevateWord.getBoost(), apply)
            // 失敗点は 3 つある:
            //   normalizeSeparators(null)           -> NPE   (:511)
            //   new ElevateWord(word, boost, ...)   -> NPE   (:527。boost が null のとき)
            //   SuggestItem の INV 検査             -> L1 以降
        catch (Exception e):
            failures++
            logger.warn("Failed to store an elevate word: id={}", elevateWord.getId(), e)
    refresh()
    return failures

// 3) storeAllBadWords(apply) : int
storeAllBadWords(apply):
    deleteAllBadWords()                                    // ループ無し。隔離しない（MO-25 規則 5）
    failures = 0
    for badWord in BadWordBhv.selectList(...):             // selectList は :569-572、ループは :573-576
        try:
            suggester.indexer().addBadWord(badWord.getSuggestWord(), apply)
        catch (Exception e):
            failures++
            logger.warn("Failed to store a bad word: id={}", badWord.getId(), e)
    refresh()
    return failures
```

| # | 実装上の要件 | 根拠 |
| --- | --- | --- |
| **1** | **削除フェーズも隔離の対象である。** 追加ループだけに `try` を入れる実装は不可 | `0003` §10.4 (e) の 1 |
| **2** | **catch する型を `IllegalArgumentException` などに絞らない。** 現に発生するのは NPE であり、L1 以降は `SuggestItem` の不変条件違反も加わる | 同 (e) の 2 |
| **3** | **失敗件数は合算した 1 つの数**として呼び出し元へ返す。**1 件の不正行が 2 件として数えられるのは仕様である** | 同 (e) の 3 ／ (f) |
| **4** | **`SuggestHelper` のインスタンスフィールドに件数を持たない** | 同 (e) の 4 |
| **5** | **`deleteAllBadWords()` は隔離しない。** 例外はそのまま伝播させる | 同 (e) の 5 |
| **6** | **警告ログの識別子に `getSuggestWord()` を単独で使わない**（`null` でありうる）。`getId()` を主にし、語は補助として出す | 同 (e) の 2 ／ 本書 §2.2 の (2) |
| **7** | **`refresh()` の呼び出し位置と回数は変えない** | A-1 / `0008` §4.2 と同じ規律（変更面積を小さく保つ） |
| **8** | **`AdminBackupAction` には手を入れない** | `0003` §13 の 8 ／ §10.4 (e) の 7 |
| **9** | **`modules/fess-suggest` を触らない** | `0003` §10.4 (h) ／ C-01 |

---

## 8. 参照した行番号の実物確認（報告値との差分）

**本書の執筆にあたり、引用したすべての `file_path:line` を実物で開いて確認した。報告時点で共有されていた値と食い違うものが 3 件あった。実物を優先した。**

| # | 対象 | 報告値 | **実物**（A-1 ＋ `0008` 適用後の作業ツリー） | 差分の性質 |
| --- | --- | --- | --- | --- |
| 1 | `(fess) helper/SuggestHelper.java` の `normalizeSeparators` 呼び出し（削除ループ） | `:445` 付近 | **`:445`**（一致）。実装は **`:551-553`**（報告値「`:543` 付近」は `0008` 是正前の値） | **区分 II 相当** |
| 2 | `(fess) helper/SuggestHelper.java` の `deleteAllBadWords()` 宣言 | `:550` | **`:558-560`**（`storeAllBadWords` からの呼び出しは `:568`） | **区分 II 相当** |
| 3 | `(sug) util/SuggestUtil.java` の `createSuggestTextId` | `:91` | **`:91`**（宣言）。**NPE が起きる `text.getBytes(...)` は `:92`** | 精度の補足 |

**設計書側で見つかった食い違い**（**第 12 版で訂正した。区分 II の付随訂正**）:

| # | 対象 | 第 11 版の記載 | **実物** |
| --- | --- | --- | --- |
| 1 | `(fess) app/web/admin/backup/AdminBackupAction.java` の復元経路 | `:157,238` | **`:156`**（`upload(final UploadForm form)` の宣言）／ **`:237`**（`ComponentUtil.getCurlHelper().post("/_bulk")`） |

**一致していたもの**: `(fess) helper/SuggestHelper.java:411` / `:412` / `:414-417` / `:419-422` / `:437` / `:438-441` / `:443-453` / `:509-511` / `:527` / `:567` ／ `(fess) exec/SuggestCreator.java:235-239` / `:243` / `:255` / `:258` ／ `(fess) opensearch/config/bsentity/BsElevateWord.java:41` / `:140-143` / `:190-193` ／ `(sug) entity/ElevateWord.java:66-67` ／ `(sug) index/operations/WordManagementOperations.java:125-132` ／ `(sug) normalizer/NormalizerChain.java:55-58`。

---

## 9. スコープ外（変更していないもの）

| # | 対象 | 理由 |
| --- | --- | --- |
| 1 | **`modules/` 配下のすべてのコード・リソース** | **逸脱手続きは「改訂を先に行う」ことを要求する。** 実装は本書の完了後に別途行う。**A-1 の未コミット変更はそのまま残してある** |
| 2 | **`docs/0002-datamodel-design.md`** | **本件は `0002` の決定を変えない。** DM / INV 番号・mapping・§7 のテスト仕様はいずれも不変であり、**変わったのは fess 本体側の制御フローに関する `0003` の対処範囲だけ**である |
| 3 | **`docs/0001-api-design.md`** | **公開契約に影響しない。** MO-25 はライブラリ側に新しい受け口を求めない（`0003` §10.4 (h)） |
| 4 | **`docs/0000-design-overview.md` / `docs/0004-corrections.md`** | 凡例・番号台帳・訂正一覧のいずれにも影響しない（**MO 番号台帳の行は `0000` §3.4 に既にあり、番号の追加で行は増えない**） |
| 5 | **`0003` §11 のテスト仕様（T 番号）** | **新しい T 番号を起こしていない。** MO-25 の検証はプラン A-2 の DoD ＋ A-6 の作業内容 2 が担う（プラン §13.3 の規律「[確定] を書いたら、それがどこで閉じるかを同時に指定する」に従う） |
| 6 | **`0003` §13 の 8**（復元時バリデーション） | **後続スコープのまま。入口側は塞がない方針は不変**である |
| 7 | **`0003` MO-1〜MO-24 ／ §3・§5・§7・§8・§9・§12** | 本件はエイリアス遷移・ロールバック・refresh・settings・`knn_vector`・既知制約のいずれにも触れない |
| 8 | **`agent_docs/tasks/20260706_design_document/docs/` の 5 本** | **凍結スナップショットである**（プラン §2.3 / Q7=(A)）。一切変更していない |

---

## 10. 残存リスク

| # | 残存リスク |
| --- | --- |
| **1** | **不正行は「スキップされる」だけで、DB からは消えない。** 毎回の再構築で同じ行が同じように失敗し、**`exitCode != 0` により G3 が毎回切替を止める**（`0003` §4.2）。**結果として、運用者が DB の不正行を直すまでサジェストの世代が更新されなくなる** [確認]。**これは意図した挙動である**（欠損した世代を公開しないことを優先する — §4.2.2）が、**警告ログを見ずに放置されると「サジェストが古いまま」という症状で現れる**。**リリース時に運用者へ周知することを推奨する** [提案] |
| **2** | **入口が開いたままである。** backup の `/_bulk` 復元は引き続き不正行を通す（`0003` §13 の 8）。**出口側の隔離は症状を止めるが原因は残る** |
| **3** | **`null` 以外の不正値は網羅していない** [要確認]。本書が実物で確認したのは `suggestWord` = `null`（空文字／未設定）と `boost` = `null` の 2 種である。**`suggestWord` が空白のみ（`" "`）の行は `normalizeSeparators` が空文字にするため、`createSuggestTextId("")` が空の `_id` を作る** — この経路の挙動は確認していない。**規則 2（例外の型を問わずスキップ）はこれも拾うが、「例外にならずに壊れたデータが書かれる」場合は拾えない。** L1 で `SuggestItem` の INV 検査が入れば追加側は塞がる（`0002` §5.2） |
| **4** | **失敗件数が `exitCode` へ届く経路は A-3 で完成する。** A-2 単体では件数を返すところまでであり、**G3 に合流するのは A-3 の作業内容 5 である**。A-2 のみをリリースしても切替は止まらない |

---

## 11. 次ステップへの申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **A-2 の実装は §7 の擬似コードを最終形とする。** 特に**削除フェーズの隔離**と**合算した件数**の 2 点を落とさないこと | **ステップ A-2**（`code-implementer`） |
| **2** | **失敗件数の受け渡し形（戻り値 `int`）は A-3 のガード実装と合わせて確定する。** `SuggestHelper` のインスタンスフィールドは禁止（MO-25 規則 4） | **ステップ A-2 / A-3** |
| **3** | **A-6 の作業内容 2 を 3 項目に拡張すること**（`0003` §10.4 (g)）: ①`getSuggestWord()` が `null` の行で `deleteAllElevateWord` が止まらない ②同じ入力で `storeAllElevateWords` が完走し失敗件数が **1 以上**（等値ではない）で報告される ③`getBoost()` が `null` の行で追加フェーズが止まらない。**新しい T 番号は起こさない** | **ステップ A-6**（`test-io-verifier`） |
| **4** | **`deleteAllElevateWord` の挙動変更（管理画面の 3 経路で例外がスキップに変わる）をリリースノートに書くこと** [提案]。**利用者から見た挙動が変わる唯一の点である** | **フェーズ A のリリース作業** |
| **5** | **§10 の残存リスク 1（不正行があると世代が更新され続けなくなる）を運用者向けに周知すること** [提案] | **フェーズ A のリリース作業** |
| **6** | **入口側バリデーション（`0003` §13 の 8）は依然として未着手である。** 出口側を塞いだことで「入口も塞いだ」と誤解されないよう、後続タスクの台帳に残すこと | **後続タスク（本タスクのスコープ外）** |

---

## 12. 参照した一次情報

### 12.1 プロダクションコード / リソース

**すべて本作業で実物を開いて確認した** [確認]。**個々の行番号は本文の各主張に付してあるため再掲しない。**

- **fess 本体**: `(fess) helper/SuggestHelper.java`（作業ツリー）／ `exec/SuggestCreator.java` ／ `app/web/admin/backup/AdminBackupAction.java` ／ `app/web/admin/elevateword/AdminElevatewordAction.java` ／ `app/web/api/admin/elevateword/ApiAdminElevatewordAction.java` ／ `opensearch/config/bsentity/BsElevateWord.java` ／ `opensearch/config/bsentity/BsBadWord.java` ／ `opensearch/config/allcommon/EsAbstractEntity.java` ／ `(fess res) fess_indices/fess_config.elevate_word/elevate_word.json` ／ `(fess res) app.xml`
- **fess-suggest**: `(sug) index/SuggestIndexer.java` ／ `index/operations/WordManagementOperations.java` ／ `util/SuggestUtil.java` ／ `entity/ElevateWord.java` ／ `normalizer/NormalizerChain.java` ／ `normalizer/AnalyzerNormalizer.java` ／ `settings/ElevateWordSettings.java` ／ `settings/ArraySettings.java`

### 12.2 タスク内文書

| 文書 | 用途 |
| --- | --- |
| `0001-work-plan.md` | §2.1（逸脱手続きの区分）／ §2.2（逸脱一覧）／ **§4 ステップ A-2**（発火点）／ ステップ A-3 / A-6 ／ §9.1 の注記（実装中発火は独立ファイル）／ §13.3（閉じ方を同時に指定する規律） |
| `docs/0003-migration-ops-design.md` | **§10.4（改訂対象）** ／ §4.2 / §4.2.2（G3）／ §4.3（ガードの配置）／ §10.3 / §10.3.1（MO-24）／ §11.3（T-F3）／ §13 の 8 |
| `0006-deviation-x4-elevate-word-id-symmetry.md` | **本書の構成・凡例・証拠提示スタイルの雛形** ／ MO-24 の内容 |
| `0008-review-response-a1.md` | **§4.1 の是正後行番号**（本書の行番号基準）／ §2.5（X 番号を起こすかどうかの先例） |
