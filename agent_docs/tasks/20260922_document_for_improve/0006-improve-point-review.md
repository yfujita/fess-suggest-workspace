# 作業履歴: `improve_point.md` のレビューと指摘の反映

- タスク: `20260922_document_for_improve`（要件: [0000-requirements-definition.md](./0000-requirements-definition.md)）
- 実施日: 2026-09-23
- 担当: doc-writer（task-reviewer のレビュー結果を反映）

## 目的

[0005](./0005-improve-point-investigation.md) で作成した成果物 [task_docs/improve_point.md](./task_docs/improve_point.md) を task-reviewer がレビューし、必須修正 4 件（M1〜M4）・推奨修正 6 件（R1〜R6）・軽微 1 件（L1）の指摘が出た。本作業ではその指摘を反映し、レビュー結果そのものを記録する。

**指摘の事実主張（行番号・件数）はすべて自分で実ファイル・grep・JSON パースで再確認し、レビュー側と値が異なった場合は自分の実測値を採用した**（該当 3 件は下記に明記）。

## 1. レビューの実施内容

| 項目 | 内容 |
| --- | --- |
| 実施者 | task-reviewer（サブエージェント） |
| 対象 | `task_docs/improve_point.md`（729 行 / 78 項目）、`0005-improve-point-investigation.md` |
| 検証範囲 | 根拠 `file:line` のサンプリング約 90 箇所（P1 22 件は全件）、数値主張（件数・行数・エントリ数）の再カウント、ドキュメント内部整合性（§0 集計値 ↔ §1 一覧表 ↔ §2 詳細のラベル）の検算 |
| 判定 | **条件付き受け入れ可**（M1〜M4 の訂正が条件） |

## 2. レビュー指摘と反映内容

### M1 `normalize_analyzer` が「全 48 言語で完全に同一」は事実誤り（必須）

- 指摘: 48 件のうち同一は 42 件。`_ca` / `_nl` / `_fr` / `_el` / `_it` / `_tr` の 6 件が追加フィルタを持つ。
- 再確認: 両モジュールの `suggest_analyzer.json` を JSON パースして全件グルーピングし、**指摘どおり 42 + 6** を確認。6 件の内容も一致し、**両モジュールで同一**（X-24 の乖離には含まれない）。
- 反映:
  - Y-07（`improve_point.md`）: 42 + 6 の内訳を明記し、「**`lang` 指定が `text` の正規化結果（= `_id`）を変えるのはこの 6 言語に限られる**」に改めた。`_tr` だけが `turkish_stemmer` を含む点を強調。
  - Y-07 の言語別内訳を両モジュール分に書き分け（R3 と統合）。
  - `0005` の「機械的な検査」表を同じ値に訂正。

### M2 X-09 / X-14 の一次根拠の行番号誤り（必須）

- 指摘: `fess:helper/SuggestHelper.java:284-286` ではなく `:294-297`。
- 再確認: `:294-297` が `.then(response -> { refresh(); success.accept(true); }).error(...)`、`:284-287` が `reader.setQuery(...)` であることを確認。**指摘どおり。**
- 反映: X-09 を `:294-297`、X-14 の success コールバックを `:295-296`、`0005` を `:294-297` に訂正。主張は変えていない。

### M3 X-11 の refresh 呼び出し箇所の行番号誤り・件数過少（必須）

- 指摘: 実測は `258, 295, 372, 387, 402, 423, 440, 451, 486, 511, 522, 532` の 12 箇所（定義は 538）。うち bad/elevate word 系が 7 箇所。
- 再確認: `grep -n "refresh()"` で**指摘どおり 12 箇所 + 定義 538** を確認。旧記載の `:418` は空行、`:519` / `:527` は javadoc。
- 追加で判明した誤り: 「優先語 1 件更新で**語数 × 2 回**の全 index refresh」は成立しない。実際は **語数 + 3 回**（`deleteAllElevateWord` の `:440` が 1 回 + `storeAllElevateWords` 内部の `deleteAllElevateWord` で `:440` が 1 回 + 語ごとの `addElevateWord` `:486` が N 回 + 末尾の `:423` が 1 回）。
- 反映: 行番号を実測値に差し替え、定量根拠を「N + 3 回」に訂正。併せて **bad word の一括保存は `:511` の 1 回だけ**（語ごとに `suggester.indexer().addBadWord(...)` を直接呼ぶため、`fess:helper/SuggestHelper.java:507-510`）という非対称を [確認] として追記した。`0005` も 12 箇所 / 7 箇所に訂正。

### M4 X-04 の「全 CRUD 経路が `apply=false`」が `deleteBadWord` について不正確（必須）

- 指摘: `deleteBadWord` は `apply` 引数を持たず index 反映手段が無い。`AdminBadwordAction.java:376` を `apply=false` 側に列挙しているのは誤りで、`ApiAdminBadwordAction.java:181` が漏れている。`apply` を渡すのは 17 箇所。
- 再確認: grep で操作経路 **19 箇所**（`apply` を取る 17 箇所はすべて `false`、`deleteBadWord` 2 箇所は `apply` 無し）を確認。`WordManagementOperations.java:91-93` が `settings.badword().delete(...)` のみで、`addBadWord`（`:77-84`）にある `apply` 分岐が存在しないことも確認。**指摘どおり。** `true` が `SuggestCreator.java:255, 258` の 2 箇所だけという点も一致。
- 反映:
  - X-04 を「`apply` を取る 17 経路すべてが `false`」+「`deleteBadWord` は `apply` 引数も反映実装も無い（`fess:helper/SuggestHelper.java:530-533` → `index/SuggestIndexer.java:406-408` → `index/operations/WordManagementOperations.java:91-93`）」に分けて記述。
  - 「NG ワードを削除したのに候補が復活しない」は `apply=false` とは**別の欠陥**であることを「ユーザーから見て」に明示。
  - §0 サマリー 1、§1 一覧表の X-04 概要、§4-9、§5 の問い 1 を同じ理解に揃えた。
  - `0005` の「14 箇所」を本文と同じ 17 / 19 に訂正。

### R1 Z-04 の根拠 `:181` が実装と食い違う（推奨）

- 指摘: `parseDocument` は引数 `normalizer` を一度も使わず、`:181` は `contents_analyzer` のトークンをそのまま `word` にしている。
- 再確認: `DefaultContentsParser.java` の `normalizer` の実参照は `:91`（`parseSearchWords`）と `:139`（`parseQueryLog`）のみで、`parseDocument`（`:153-211`）は `analyzeText`（`:235-236`）→ `getContentsAnalyzerName` 経路であることを確認。**指摘どおり。** `contents_analyzer` が `mapping_char` + `lowercase` を含むため Z-04 の結論は保たれる。
- 反映:
  - Z-04 を「文書経路 = `contents_analyzer_<lang>`」「検索語経路 = `normalize_analyzer_<lang>`」に書き分け、結論が変わらない理由を 1 行で添えた。
  - M1 と組み合わせた**新規の非対称**を Z-08 に追記（新規採番はせず、集計値を動かさない方針を採った）。内容は「索引側 `contents_analyzer_tr` は stemmer を持たないのに検索側 `normalize_analyzer_tr` は `turkish_stemmer` を持つ」という `tr` 固有の非対称。
    - 再確認の結果、**残る 5 言語（`ca` / `nl` / `fr` / `el` / `it`）は elision / lowercase / `stemmer_override` が索引側にも揃っているため対称**だった。非対称なのは `tr` だけ。
    - 併せて「elevate / bad word の正規化は `normalizer.normalize(word, "")` で言語を渡さない」（`WordManagementOperations.java:78, 104-106`）ことによる食い違いも追記。
  - §4-1 に「索引時と検索時の正規化器が同一であることをポートの契約にする」を (d) として追加。

### R2 Z-02 の「stoptags 76 件」は実測 74 件（推奨）

- 再確認: 両モジュールの `pos_filter.stoptags` をいずれも **74 件**と計数。**指摘どおり。**
- 反映: Z-02 を 74 件に訂正し、両モジュールとも同数であることと計数方法を明記。

### R3 Y-07 の言語別内訳とサマリーの不整合（推奨）

- 指摘 (a): `reading_analyzer_ko` は `standard` なので「tokenizer のみ」は誤解を招く。正確には「`_th` のみ `thai`、残り 45 言語は `standard`」。
- **再確認でレビュー側と値が異なった点**: `reading_analyzer_ko` が `standard` なのは **fess-suggest 側（`res:`）だけ**。**fess 側（`fess-res:`）は `fess_korean_normal`** を使う（`contents_analyzer_ko` などを含め `_ko` の 4 定義が X-24 の相違 14 個に含まれる）。クラスパス順では fess 側が勝つため（X-24）、実行時の内訳は fess 側が正になる。レビューの「残り 45 言語は `standard`」は `res:` 側のみ成立する値。
- 反映: Y-07 に**両モジュールの内訳を書き分け**、`_ko` の差が X-24 の乖離の一部であることを明記。
- 指摘 (b): §0 サマリー 3 の「48 言語中 ja だけ」が Y-07 本文と不一致で、実体は 47 言語 + 無印。
- 再確認: `SUPPORTED_LANGUAGES` は **47 言語**（`settings/AnalyzerSettings.java:116-118`）で、analyzer は 5 系統 × 48。**指摘どおり。**
- 反映: §0 を「48 系統（47 言語 + 無印）のうち無印と `_ja` の 2 つだけ」に統一。Y-07 に「`reading_analyzer` と `reading_term_analyzer` は 48 系統中 46 系統が完全同一」を追記し、Y-10 の「44 言語では 1 回が無駄」も「46 系統」に訂正。

### R4 X-24 の「228 行乖離」の測り方が復元できない／例示が不適切（推奨）

- 指摘: 228 は `json.dumps(indent=2, sort_keys=True)` 正規化後の `diff` 出力行数で、相違行は 146 行。`english_keywords` は両モジュール同一なので例として不適切。
- 再確認: **diff 出力 228 行 / `^[<>]` 行 146 行**を確認。`english_keywords` は両モジュールとも `["hello"]` で同一。**指摘どおり。**
- **再確認でレビュー側と値が異なった点**: レビューは「`["Hola"]` も実際は `spanish_keywords` の `["¡Hola"]`」としたが、**`catalan_keywords` が lib 側で `["Hola"]` であり、fess 側の `keywords_path` と相違する**。つまり `["Hola"]` は有効な例だった（`spanish_keywords` は `["¡Hola"]` で、これも相違する別の例）。
- 反映: X-24 に測定方法を明記し、例示を `arabic_keywords`（lib `["مرحباا"]` vs fess `keywords_path`）に差し替え、**`english_keywords` / `bulgarian_keywords` / `finnish_keywords` は両モジュール同一で全言語ではない**ことを注記。併せて analyzer 241 個 / 240 個、fess-suggest 側のみの定義（`title_contents_analyzer` / `pattern_split` / `zero_width_spaces`）、`_ko` 系 4 定義の相違を追記。`0005` も同じ定義に訂正。

### R5 ±1〜2 行の行ずれ（推奨）

| 項目 | レビュー指摘 | 自分の再確認 | 反映 |
| --- | --- | --- | --- |
| X-15 | 「`:194`, `:211-212`」→ `:194` と `:212` | `deleteOldWords` の return は `:212`（`:211` は `deleteByQuery`）。指摘どおり | `:194`, `:212` に訂正 |
| X-14 | 「`latch.countDown()` は `:267, :271`」→ `268` / `272` | `SuggestCreator.java:268`（success）/ `:272`（error）。指摘どおり | `:268, :272` に訂正 |
| X-19 | 「`Suggester.java:286-305`」→ 判定は `288-305` | **レビュー側が誤り。** `:286` が `if (updateIndices.size() != EXPECTED_INDEX_COUNT) {` で判定の開始行。`:288` は debug ログ | **訂正せず `286-305` を維持** |
| X-17 | 「`CreateForm.java:60-64`」→ アノテーションは `61-63` | `@Required`（61）/ `@ValidateTypeFailure`（62）/ `public Float boost`（63）。`:60` は javadoc。指摘どおり | `:61-63` に訂正し、検証内容も `@ValidateTypeFailure` と正確に記載 |

### R6 `0005` の表と本文の数値を一致させる（推奨）

- 反映: M1 / M3 / M4 / R4 の訂正を `0005` の「機械的な検査」表と「自分で検証して採用した主な指摘」の両方に同時に適用。`0005` の成果物行数（729 行 → 744 行）も更新。

### L1 `0004` の旧ファイル名参照（軽微）

- 再確認: `0004:124`（「0003 §5 の未解決の問い 8 件」）と `0004:130`（「0003 §3 の [要判断]」）が移動済みの旧名を参照していることを確認。`refactoring_point.md` の §5 が 8 件、§3 が [要判断] 一覧であることも確認。
- 反映: いずれも `[refactoring_point.md](./task_docs/refactoring_point.md)` への相対リンクに変更。なお `0004:13` の `0003-refactoring-point.md` は**リネームの経緯そのものの記述**なのでそのまま残した。

### L3 分量圧縮（実施せず）

- レビューで 729 行は許容範囲と判定されたため、圧縮は行っていない。訂正により **744 行**になった。

## 3. レビューで問題が無いと確認された点

| 観点 | 確認結果 |
| --- | --- |
| 要件との整合 | `0000` の事前作業「機能観点の問題点、改善点を箇条書きでまとめる」を満たす |
| 成果物パス・採番 | 成果物は `task_docs/improve_point.md`、作業履歴は通し番号方式。規約どおり |
| `refactoring_point.md` との役割分担 | 内部構造・可視性・重複コード・デッドコードを本書が扱わない方針が守られている |
| [要判断] 18 件の網羅 | §3 の対応表で 18 件すべてに機能観点の結論がある |
| [確認] / [推測] の規律 | 未再現の並行実行系（X-12 / X-14 / X-19）や導出による挙動記述が [推測] になっている |
| W 章の「無い」判定 | すべて grep 0 件の確認で、検索語と対象が本文に明記されている |
| §0 集計値の内部整合 | 78 件 / P1 22・P2 38・P3 18 / [欠陥] 30・[制約] 18・[品質] 16・[新機能] 14 / [即修正候補] 19・[構成で備える] 42・[別タスク] 17 / [境界内] 28。§1 一覧表と §2 詳細見出しのラベルも全 78 件一致（訂正後に再検算済み） |
| HEAD 記載 | fess-suggest `f7a8039`、fess `8a9e1e15c` が明記されている |

## 4. 検証の前提

- **テスト・ビルドは一切実行していない**（`mvn test` / `mvn compile` とも未実行）。レビューおよび本作業の再確認は、静的なコード読解・`grep`・JSON / 変換表の機械的走査に限る。
- 実機未検証のまま残る項目: Z-01 の長音・促音系の一致可否、Y-01 / Y-02 の再構築時間、X-24 のクラスパス順、本作業で追記した `_tr` の正規化非対称。
- ソースコードは変更していない。git commit もしていない。

## 5. ユーザー判断待ちの事項

1. `improve_point.md` §5 の**未解決の問い 9 件**（X-04 の既定、Y-03 の既定、Y-01 / Y-02 の既定値、X-08 のスコープ、X-24 の所有権、Z-01 の実装方針、W-02 の採否、`parallel` の実績、Z-02 のフレーズ供給源）。
2. **本タスクのスコープに fess 側を含めるか**（`0005` の申し送り 6 と `refactoring_point.md` H-01 と同じ問い）。X-04 の `deleteBadWord` の反映手段欠落も fess / fess-suggest の両側に手が入る。
3. `0005` の申し送り 4「**同時に直す価値が高い 6 件**」（X-11 / X-05 / Y-08 / X-28 / X-09 / X-13）の採否。**X-11 は M3 の訂正により想定より影響が大きい**（優先語 1 件の更新で語数 + 3 回の全 index refresh）ため、優先度を上げる余地がある。

## 変更ファイル

| ファイル | 変更内容 |
| --- | --- |
| [task_docs/improve_point.md](./task_docs/improve_point.md) | M1〜M4、R1〜R5 の訂正（§0 / §1 / X-04 / X-09 / X-11 / X-14 / X-15 / X-17 / X-24 / X-27 / Y-07 / Y-10 / Z-02 / Z-04 / Z-08 / W-07 / §4-1 / §4-9 / §5）。729 → 744 行 |
| [0005-improve-point-investigation.md](./0005-improve-point-investigation.md) | R6（検査表・検証済み指摘・成果物行数の数値を本文と統一）、冒頭に訂正の追記 |
| [0004-refactoring-point-investigation.md](./0004-refactoring-point-investigation.md) | L1（旧ファイル名参照 2 箇所を `refactoring_point.md` への相対リンクに変更） |
| 本ファイル | 新規作成 |

### レビュー指摘外で自分の確認中に見つけて訂正した点

- X-27: `contentFieldList` が `ElevateWord` の `fields` に渡る箇所を `fess:helper/SuggestHelper.java:437-440` → **`:482-484`** に訂正（`:437-440` は `deleteAllElevateWord` のループ）。
- W-07: `ElevateWordBhv.selectList` が 3 回走る根拠を `:428-441` → **`:411-441`**（`storeAllElevateWords` の開始行を含む範囲）に訂正。
