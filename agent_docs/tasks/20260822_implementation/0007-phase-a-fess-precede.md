# 0007: フェーズ A — 先行リリース（fess 本体の安全網）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ A」の作業履歴である（§9.1 の割当てにより、ステップ **A-1〜A-6** を 1 ファイルに収める。Q9=(B)「フェーズ単位で 1 ファイル」）。
> **ステップ A-1 の実装中に発火した逸脱 X-4（区分 I）は `0006-deviation-x4-elevate-word-id-symmetry.md` に分離してある**（§9.1 の注記「実装中に新たな逸脱が発生した場合は、その時点の最大番号 +1 で独立ファイルを作る。**フェーズのファイルに混ぜない**」）。**本書は X-4 の経緯・代替案・根拠を繰り返さず、A-1 の実装が §2.1 の手続きを踏んだことだけを §1.6 に記す。**
> **ステップ A-2 の着手時に発火した逸脱 X-5（区分 I）も同じ扱いで `0009-deviation-x5-store-all-delete-phase.md` に分離してある。**
> **さらに、A-2 の実装に対する外部レビューで発火した逸脱 X-6（区分 I）も同じ扱いで `0010-review-response-a2.md` に分離してある**（**A-1 のレビュー反映 `0008` と同型の文書だが、`0008` と違って設計判断そのものを覆したため X 番号を起こしている** — 判定の根拠は `0010` §1.1 / §1.2）。**本書は X-5 / X-6 の経緯・代替案・根拠を繰り返さず、A-2 の実装が同じ手続きを踏んだことだけを §2.6 に記す。**
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[確定]** = 決定済み ／ **[要確認]** = 未解消
>
> **パス短縮表記**: `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-08-31**（A-1 / A-2） |
| 対象ステップ | **A-1（本書 §1・完了）** ／ **A-2（本書 §2・完了）** ／ **A-3 / A-4 / A-6（本書 §3・§4・§6・未着手）** ／ **~~A-5~~（本書 §5・**2026-08-31 に削除**）** |
| ブランチ | `modules/fess` の **`feature/suggest-l1-precede`**（`modules/fess-suggest` の `feature/suggest-l1` には**一切触れない**） |
| 分離した逸脱記録 | **X-4**（区分 I・**A-1 の実装中**に発火） → `0006-deviation-x4-elevate-word-id-symmetry.md` ／ **X-5**（区分 I・**A-2 の着手時**に発火） → `0009-deviation-x5-store-all-delete-phase.md` ／ **X-6**（区分 I・**A-2 の実装に対する外部レビュー**で発火） → `0010-review-response-a2.md` |
| 分離したレビュー反映記録 | **A-1** → `0008-review-response-a1.md`（決定は不変。X 番号を起こしていない） ／ **A-2** → `0010-review-response-a2.md`（**1 回目 = Request changes ＝ X-6**。決定そのものが変わった。／ **2 回目 = Approve（軽微修正推奨）** — **同書 §13**。**Javadoc 3 ブロックの是正のみで、設計書の改訂も新しい X / MO 番号も無い**） |

### フェーズ A の進捗

| ステップ | 内容 | 本書の節 | 状態 |
| --- | --- | --- | --- |
| **A-1** | elevate word 入力の正規化（INV-2 の fess 側担保 ＋ **MO-24**） | **§1** | **完了**（2026-08-31）。**レビュー指摘の反映を `0008-review-response-a1.md` で実施済み**（コメント／Javadoc の是正のみ。ロジックは無変更） |
| **A-2** | 語管理の一括処理を 1 件の失敗で止めない（`0003` §10.4 ／ **MO-25**） | **§2** | **完了**（2026-08-31）。**着手時に逸脱 X-5（区分 I）が発火し、記録は `0009-deviation-x5-store-all-delete-phase.md` に分離。さらに実装に対する外部レビューで逸脱 X-6（区分 I）が発火し、記録は `0010-review-response-a2.md` に分離**（本書 §2.6）。**X-6 の反映で実装を書き直しており、§2 は書き直し後の実装を記録している。** **その書き直し版に対する 2 回目のレビューで Approve を得た**（軽微修正推奨。反映は `0010` §13 に記録。**Javadoc 3 ブロックの是正のみ・設計書の改訂なし**）。**DoD 10 件中 8 件を充足。残り 2 件は A-3（`exitCode` への合流）と A-6（テスト）で閉じる** |
| A-3 | 切替可否ガード G1 / G3 の設置（MO-2 / MO-18） | §3 | **未着手** |
| A-4 | `(fess res) suggest_indices/` の `number_of_replicas` 削除（3 ファイル・U-2） | §4 | **未着手** |
| ~~A-5~~ | ~~`.prev` 付与の暫定実装（M-6・U-7）~~ | §5 | **【2026-08-31】削除**（着手前。実装は 1 行も無い）。**配布・運用モデルの確定（要件定義 `0000` 第 2 版 §2）により暫定 `.prev` が不要になったため** — 記録は `0011` |
| A-6 | **R0** 分のテスト | §6 | **未着手** |

> **フェーズ A の完了 = R0 をリリースできる**（プラン §4 末尾）。**A-6 まで終わるまで R0 はリリースできない。**
>
> **【2026-08-31】リリース段が R0 / R1 / R2 に組み替わった**（要件定義 `0000` 第 2 版 §3 ／ `0003` 第 14 版 §10.1）。**本書に残る「先行リリース」は R0、「L1」は R1、「L2」は R1 の fess 本体側（後続タスク）、「L3」は R2 と読む。** **A-1 / A-2 の実装内容には一切影響しない** — 両ステップが対処した問題（MO-24 / MO-25）はリリース方式と独立している。

---

## 1. ステップ A-1: elevate word 入力の正規化（INV-2 の fess 側担保）

**結果: プラン §4 ステップ A-1 の DoD 5 件のうち 4 件を充足。残り 1 件（T-F3 が緑）は A-6 で閉じる（§1.9）。**

> **【2026-08-31 追記】本節の後に外部レビューを受け、その反映を `0008-review-response-a1.md` に記録した。**
> **反映したのはコメント／Javadoc の是正 2 件のみで、`normalizeSeparators` の実装・両キー削除の有無・呼び出し構造はいずれも変えていない**（`0008` §2・§3）。**あわせて `docs/0003-migration-ops-design.md` を第 11 版へ改訂した**（MO-24 (d) の規則 3 の根拠の是正。**区分 I — X-4 の追補改訂であり、MO-24 の決定そのものは不変。新しい X 番号は起こしていない**。判定の根拠は `0008` §2.5）。
> **本節が引用する行番号は是正前のものである。是正後の行番号は `0008` §4 の表を正とする。**

### 1.1 前提と着手時の状態

| 項目 | 値 | 根拠 |
| --- | --- | --- |
| ブランチ | `feature/suggest-l1-precede` | `git branch --show-current` [確認] |
| 着手時の HEAD | **`39cc32fa7`**（`fix: report an invalid crawl.order once per crawl, not once per queue poll (#3354)`） | `git log --oneline -1` [確認] |
| 着手時の作業ツリー | **clean** | 実装エージェントの報告。**本書執筆時点で HEAD に対する差分が `SuggestHelper.java` 1 ファイルのみであることを再確認した** [確認]（§1.2） |
| `modules/fess-suggest` | **無変更**（`git status --short` が空・ブランチは `feature/suggest-l1`） | [確認] |

> **フェーズ 0 の記録との差分（プランの逸脱ではない）**: `0004` §1.1 は本ブランチの起点を **`3cd39b173`** と記録しているが、着手時の HEAD は **`39cc32fa7`** である。**`3cd39b173` は `39cc32fa7` の祖先であり、その間に upstream の 18 コミットが入っている** [確認]（`git merge-base --is-ancestor` が真、`git rev-list --count 3cd39b173..HEAD` = 18）。**巻き戻しや履歴の書き換えではなく、単に upstream に追随した結果である。** 含まれる変更には破壊的なもの（`f0beb83bc feat!: migrate to Jackson 3 (#3352)` ／ `b814bbab7 feat(script)!: default to JavaScript ...`）があるが、**いずれも suggest 経路ではなく、A-1 の対象コードに影響していない**（`mvn -o compile` / `SuggestHelperTest` が緑 — §1.7）[確認]。**以降のフェーズ A の作業は `39cc32fa7` を起点とする。**

### 1.2 変更したファイル

**唯一の変更ファイルは `(fess) helper/SuggestHelper.java` である** [確認]。

```
$ git diff --stat
 .../org/codelibs/fess/helper/SuggestHelper.java    | 76 +++++++++++++++++++---
 1 file changed, 67 insertions(+), 9 deletions(-)
```

| 項目 | 値 |
| --- | --- |
| 変更ファイル数 | **1** |
| 挿入 / 削除 | **67 / 9** |
| 新規ファイル | **なし** |
| **`modules/fess-suggest` への変更** | **なし** [確認] |
| **テストの追加** | **なし**（意図的 — §1.7 の末尾） |
| コミット | **未実施**（作業ツリーに未コミットで保持） |

**変更後の主要メソッドの所在**（すべて `(fess) helper/SuggestHelper.java`。**本書執筆時に実物を開いて確認した** [確認]）:

| メソッド | 変更前（HEAD） | 変更後（現作業ツリー） |
| --- | --- | --- |
| `storeAllElevateWords` | `:411` | `:411`（**無変更**） |
| `deleteAllElevateWord` | `:431` | `:437` |
| `deleteElevateWord` | `:449` | `:471` |
| `addElevateWord` | `:464` | `:501` |
| **`normalizeSeparators`（新設）** | — | **`:543-545`** |

> **プラン §4 ステップ A-1 が挙げる変更前の行番号（`:464` / `:449` / `:431`）は、HEAD (`39cc32fa7`) の実物と一致した** [確認]（`git show HEAD:... | grep -n`）。

### 1.3 作業内容 1〜4（プラン当初分）

| # | プランの作業内容 | 実装 | 根拠 `file_path:line` |
| --- | --- | --- | --- |
| **1** | `split(TEXT_SEP)` の**前に trim を入れる** | **`normalizeSeparators` の末尾に `.trim()` を置いた。** HEAD の `:468` / `:470` は `replace("　", TEXT_SEP).replaceAll(TEXT_SEP + "+", TEXT_SEP).split(TEXT_SEP)` であり、**`replaceAll(TEXT_SEP + "+", TEXT_SEP)` は連続空白を 1 個に畳むだけで先頭・末尾の空白を落とさない**。そのため `" test"` が**空文字要素を含む `readings`** を生んでいた | `(fess) helper/SuggestHelper.java:544`（変更後） ／ HEAD の `:468` `:470`（変更前） |
| **2** | **`word` 側も同じ正規化を通す** | `normalizedWord = normalizeSeparators(word)` を取り、**`ElevateWord` のコンストラクタへ `word` ではなく `normalizedWord` を渡す**ようにした。**`readings` だけ直しても `text` 側が INV-2 を破るため** | `:503`（正規化） ／ `:519`（`new ...ElevateWord(normalizedWord, ...)`） |
| **3** | **空文字要素を除去する** | `split(normalizeSeparators(readingSource), TEXT_SEP).of(stream -> stream.filter(StringUtil::isNotBlank).forEach(readingList::add))` にした。**`String[]` ＋ `Arrays.asList` から `List<String>` の構築へ変えている** | `:505-507` ／ `:519`（`readingList` を渡す） |
| **4** | **k と W の一致を fess 側で強制せず、分担をコメントに明記する** | `addElevateWord` の Javadoc に「本メソッドは**区切り文字の正規化だけ**を行い、**読みトークン数と語数の突き合わせ（不足の補完・過剰の切り詰め）は suggest ライブラリの責務**である」と明記した | `:483-492`（Javadoc） |

> **作業内容 3 のイディオムは新しい流儀ではない** [確認]。**同ファイルの `init()` が既に `split(...).of(stream -> stream.filter(StringUtil::isNotBlank).forEach(...))` を 3 回使っている**（`:120-123`）。**同型の既存コードに合わせた。**
>
> **`Arrays.asList(readings)` を除いても `import java.util.Arrays` は未使用にならない** [確認]。同ファイル `:124` が `Arrays.asList(stream(...))` で使い続けている。

**`0002` §5.4 の 4 分岐に相当する処理は fess 側に一切書いていない** [確認]。`addElevateWord` は `readingList` の要素数と `normalizedWord` の語数を比較しておらず、不足の補完も過剰の切り詰めも行っていない（`:501-523` の全文で該当する分岐が存在しない）。**この分担は `0003` 第 10 版 §10.3.1 (d) の 4 が「MO-24 で変わらない」と明記している。**

### 1.4 作業内容 5（実装中に発火した逸脱 X-4 / MO-24 への対応）

**設計の正本は `0003` 第 10 版 §10.3.1（MO-24）。擬似コードは `0006` §7。** 実装は同 §7 の要件 1〜5 に対応する。

| # | 実装したこと | 根拠 `file_path:line` |
| --- | --- | --- |
| **1** | **`deleteElevateWord`（変更前 `:449`）と `deleteAllElevateWord`（変更前 `:431`）にも同じ正規化を適用し、追加経路と削除経路が同じドキュメント `_id` を指すようにした** | `:472`（`normalizeSeparators(word)`） ／ `:445`（`normalizeSeparators(rawWord)`） |
| **2** | **正規化前後で語が変わる場合のみ、生キーでも削除を試みる。** 変わらない場合は削除呼び出しは 1 回だけである | `:474-479`（`if (!normalizedWord.equals(word))`） ／ `:447-452`（`if (!normalizedWord.equals(rawWord))`） |
| **3** | **正規化ロジックを `protected String normalizeSeparators(final String text)` に切り出し、3 メソッドで共有した。別実装を持たない** | `:543-545`（定義） ／ 呼び出しは `:445` `:472` `:503` `:507` の 4 箇所 |
| **4** | **両キー削除の意図をコメントに残した**（次の実装者が「冗長だ」と削らないように — `0006` §7 の要件 5） | `:448-450` ／ `:475-477`（行コメント） ／ `:429-432` ／ `:460-466`（Javadoc） |
| **5** | **`refresh()` の呼び出し回数は従来どおり各 public メソッド末尾 1 回のまま**（ループ内では呼ばない） | `:454`（`deleteAllElevateWord`・for ループの**外**） ／ `:480`（`deleteElevateWord`） ／ `:522`（`addElevateWord`） [確認] |

**両キー削除にした理由**（`0003` §10.3.1 / `0006` §2.2 に詳述。ここでは結論のみ）: **A-1 を含むバイナリへ上げる前に生キーで投入済みのドキュメントが残っている**ため。**削除は存在しない `_id` に対して実質 no-op である**（根拠は `0006` §7 の要件 3）。

**`storeAllElevateWords`（`:411`）は無変更である** [確認]。同メソッドは `deleteAllElevateWord(apply)`（`:412`）を呼んでから全行を `addElevateWord(...)`（`:420-421`）で再登録するだけであり、**両メソッドの内部実装の変更をそのまま受け取る**（`git diff` に同メソッドのハンクが存在しない [確認]）。

### 1.5 実装上の判断

| # | 判断 | 理由 |
| --- | --- | --- |
| **1** | **`normalizeSeparators` の可視性を `protected` にした** | 同クラスの既存の切り出しヘルパと同じ流儀に合わせた。**`deleteAllBadWords`（`:550`）が `protected` である** [確認]。`private` にすると A-6 の単体テストから直接検証しにくくなる |
| **2** | **配置を `addElevateWord` の直後（`:543`）にした** | 3 つの呼び出し元（`:445` / `:472` / `:503`・`:507`）に近い位置に置くことを優先した。add / delete のまとまりの末尾に当たる |
| **3** | **Javadoc に「なぜ共有するのか」（`_id` キーの対称性）を書いた** | What ではなく Why を残す。`0006` §7 の要件 5 に対応（`:533-538`） |
| **4** | **`storeAllElevateWords` に触れなかった** | プラン A-1 の対象は 3 メソッドに閉じる。同メソッドは自動的に恩恵を受ける（§1.4 末尾） |

### 1.6 逸脱 X-4 の手続き（**詳細は `0006` — ここでは繰り返さない**）

**A-1 の実装中に区分 I の逸脱が 1 件発火し、プラン §2.1 の手続きを踏んだ。** **手続きの順序は守られた** [確認]。

| 順序 | 実施内容 | 記録 |
| --- | --- | --- |
| **1** | **設計書 `docs/0003-migration-ops-design.md` を第 9 版 → 第 10 版へ改訂し、MO-24 を採番した**（コード変更なし） | `docs/0003-migration-ops-design.md:3`（現在の版 = 第 10 版）／ `:29`（改訂履歴 第 10 版の行）／ `:63`（MO-24）／ `:882`（§10.3.1） [確認] |
| **2** | **`0006-deviation-x4-elevate-word-id-symmetry.md` に逸脱を記録した**（同書のメタ表に「コード変更: **なし**。A-1 の実装は本書の完了後に再開する」と明記） | `0006-deviation-x4-elevate-word-id-symmetry.md:16` [確認] |
| **3** | **その後で実装した**（本節 §1.4） | 本書 §1.4 |

**繰り返さない事項**（`0006` を参照すること）: 発見の経緯（§1）／ 事象と根拠（§2）／ 区分 I と判定した理由（§3）／ **代替案 3 案の採否**（§4）／ **残存リスク**（§6）／ 実装側が満たすべき仕様の擬似コード（§7）。

### 1.7 検証結果 [確認]

**すべて `modules/fess` で実行した。以下の 3 件は本書の執筆時に独立に再実行して確認した値である。**

| コマンド | 結果 | 備考 |
| --- | --- | --- |
| `mvn -o formatter:validate` | **`BUILD SUCCESS`** ／ `Processed 1694 files (Formatted: 0, ..., Failed: 0)` | **整形違反なし。** 実装エージェントは `mvn -o formatter:format license:format` を実行し `EXIT=0` ／ 整形差分なしと報告している。**本書ではソースを書き換えない読み取り専用の `validate` で同じ結論を確認した** |
| `mvn -o compile` | **`BUILD SUCCESS` / EXIT=0** ／ Total time 10.699 s | **オフラインで成功した。** `0004` §1.4 の 2 ／ `0005` §5 の結論（`-o` を既定にしてよい）と整合する |
| `mvn -o test -Dtest=SuggestHelperTest` | **`Tests run: 24, Failures: 0, Errors: 0, Skipped: 0`** → **`BUILD SUCCESS` / EXIT=0** ／ Total time 22.474 s | 既存 24 件が全緑。**テスト実行後も `git status --short` は `SuggestHelper.java` 1 件のままである** [確認]（テストが追跡対象ファイルを書き換えていない） |

> **`-o` を付けてもビルド中にネットワークアクセスは発生する** [確認]。`mvn -o test` のログに antrun の `[get] Getting: https://repo1.maven.org/.../jakarta.annotation-api-2.1.1.jar` と `[get] Getting: https://github.com/codelibs/fess-kopf/archive/refs/heads/main.zip` が出る。**`-o` は Maven の依存解決をオフラインにするだけで、`maven-antrun-plugin` の `<get>` タスクには効かない。** ネットワーク不通の環境では `-o` を付けても `mvn test` が通らない可能性がある [推測]。**A-6 でオフライン実行を DoD にしないこと。**

**テストは追加していない。** **MO-24 と INV-2 の検証テスト（T-F3）は A-6 の担当である**（プラン A-6 の作業内容 1 ／ `0003` §10.3.1 が「MO-24 の検証は A-6 が担う。§11 に新しい T 番号は起こしていない」と明記 — `docs/0003-migration-ops-design.md:930`）。

### 1.8 報告と実物の食い違い（**実物を優先した**）

**本書の執筆にあたり、引用された `file_path:line` と主張をすべて実物で確認した。食い違いが 2 件あった。**

| # | 報告された内容 | 実物 | 扱い |
| --- | --- | --- | --- |
| **1** | 「不要になった **`import java.util.function.UnaryOperator;` を除去した**」 | **HEAD と現作業ツリーの import 一覧は完全に一致しており、`UnaryOperator` は HEAD にも現在にも存在しない** [確認]（`git show HEAD:... \| grep -n "^import"` と現物の diff が 0 行）。**`git diff` にも import のハンクが無い**。同ファイル本文にも `UnaryOperator` の出現は 0 件 | **本書は「HEAD に対する最終差分として import の増減は 0 である」と記録する。** 実装中の未コミット作業ツリー内で一時的に導入し、`normalizeSeparators` への切り出しで消したものと解される [推測]。**HEAD からの差分としては存在しないため、成果物の説明としては書かない** |
| **2** | 既存の同型イディオムの所在を **`:121-124`** とする記述 | **`:120-123`** が正しい [確認]（`:120-121` が `getSuggestFieldContents` の 2 行折り返し、`:122` が `getSuggestFieldTags`、`:123` が `getSuggestFieldRoles`） | **`:120-123` を正とする**（§1.3 の注記） |

### 1.9 DoD の充足状況

**プラン §4 ステップ A-1 の DoD は 5 項目である。**

| # | DoD | 結果 | 何をもって充足と判断したか |
| --- | --- | --- | --- |
| **1** | `addElevateWord` に **trim と空要素除去**が入っている | **充足** | trim = `normalizeSeparators` 末尾の `.trim()`（`:544`）を `word`（`:503`）と読み（`:507`）の**両方**に適用。空要素除去 = `split(...).of(stream -> stream.filter(StringUtil::isNotBlank)...)`（`:507`）。**`mvn -o compile` が成功している**（§1.7）[確認] |
| **2** | **`0002` §5.4 の 4 分岐に相当する処理を fess 側に書いていない**こと（責務の二重化をしていない） | **充足** | `addElevateWord` の本文（`:501-523`）に `readingList.size()` と語数を比較する分岐が **0 件**であることを実物で確認した [確認]。分担は Javadoc（`:486-491`）に明記済み |
| **3** | **`addElevateWord` と `deleteElevateWord` が同じキー（同じ正規化関数の出力）を使っている**こと（**X-4 / MO-24**） | **充足** | 両者とも**同一メソッド `normalizeSeparators`（`:543`）を呼ぶ** — add 側 `:503`、delete 側 `:472`。**別実装を持たない**（同ファイル内に正規化ロジックの重複が無いことを確認 — `replaceAll(TEXT_SEP + "+"` の出現は `:544` の 1 箇所のみ）[確認] |
| **4** | **削除経路 2 メソッドに両キー削除が入っている**こと。**正規化前後で語が変わらない場合は 1 回だけ**であること（**X-4 / MO-24**） | **充足** | `deleteElevateWord`: `:473`（正規化キー）＋ `:474-479`（`if (!normalizedWord.equals(word))` の中でのみ生キー）。`deleteAllElevateWord`: `:446` ＋ `:447-452`。**条件分岐の中に置いてあるため、変わらない場合の呼び出しは 1 回である** [確認] |
| **5** | **A-6 で追加する T-F3 が緑** | **A-6 で閉じる**（**未充足ではない**） | **T-F3 は A-6 の成果物であり、A-1 の時点では存在しない。** プラン A-6 の作業内容 1 が「MO-24 の検証も同じ T-F3 の範囲に含める（新しい T 番号は起こさない）」と定めており、`0003` `:930` も同じ割当てである。**本項目は A-6 の完了をもって閉じる。それまでフェーズ A は完了しない**（§8 の DoD 15 も「A-1 の DoD ＋ **A-6 の T-F3**」を検証方法としている） |

> **DoD 5 が A-6 待ちであることは、A-1 の実装に不足があることを意味しない。** ただし **A-6 が終わるまで MO-24 の正しさは機械的に保証されていない**（現時点の 24 件のテストは正規化の振る舞いを何も検証していない — §1.11 の 2）。

### 1.10 スコープ外（変更していないもの）

**誤解を防ぐため、あえて触れなかった範囲を明記する。**

| 対象 | 状態 | 理由 |
| --- | --- | --- |
| **`modules/fess-suggest` 全体** | **無変更** [確認] | プラン §4 の冒頭「fess-suggest には一切触れない」／ MO-24 も「fess-suggest 側は変更しない」（`docs/0003-migration-ops-design.md:63`） |
| `storeAllElevateWords`（`:411`）／ `storeAllBadWords`（`:559`） | **無変更** [確認] | 前者は自動的に恩恵を受ける（§1.4 末尾）。後者は**ステップ A-2 の対象** |
| `(fess) exec/SuggestCreator.java` | **無変更** [確認]（`git diff --stat` が 1 ファイル） | **ステップ A-3 / A-5 の対象** |
| `(fess res) suggest_indices/` の 3 ファイル | **無変更** [確認] | **ステップ A-4 の対象**（U-2） |
| `(fess test) helper/SuggestHelperTest.java` | **無変更** [確認] | **ステップ A-6 の対象**。プラン A-6 の作業内容 8 が「既存 `SuggestHelperTest` の握り潰し構造には手を入れない」としている |
| DB 保存時の正規化（`AdminElevatewordAction` ほか） | **無変更** | `0006` §4 の案 (c)。**L2 以降の候補**として `0006` §10 の 3 に申し送り済み |
| コミット | **未実施** | フェーズ 0 と同じ運用（`0004` §1.6 の 4）。作業ツリーに保持している |

### 1.11 次ステップへの申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **A-6 で MO-24 を検証すること。** ①`addElevateWord` と `deleteElevateWord` が**同じキー**を使うこと ②**正規化前後で語が変わる場合に生キー側の削除も発行される**こと ③変わらない場合は**削除が 1 回だけ**であること ④`deleteAllElevateWord` についても同じ 3 点。**T-F3 の範囲に含め、新しい T 番号は起こさない**（`0006` §10 の 1 ／ プラン A-6 の作業内容 1） | **A-6** |
| **2** | **既存の `SuggestHelperTest` の構造をそのまま流用すると検証にならない** [確認]。`test_addElevateWord`（`(fess test) helper/SuggestHelperTest.java:251-259`）／ `test_addElevateWord_noReading`（同 `:261-269`）／ `test_deleteElevateWord`（同 `:241-249`）は **try-catch で必ず `assertTrue(true)` する**構造であり、**正規化の振る舞いを何も検証していない**。**さらに悪いことに、これらは正常系すら通っていない**（下記の枠を参照） | **A-6** |
| **3** | **`0006` §6 の残存リスクは A-1 の実装では解消しない。** **【2026-08-31 是正・区分 II — 実物で確認し、対象を 2 つに分けた】** **(a) suggest ドキュメントの孤児は次回の全件再構築で消える** [確認] — `createNextIndex()` が空の新インデックスを作り（`(sug) Suggester.java:235-260`）、`storeAllElevateWordsForRebuild()` が **DB の行だけ**を新世代へ書く（`(fess) exec/SuggestCreator.java:261`）。旧世代は `removeDisableIndices()`（`:304`）で物理削除される。**掃除手順は不要である。** **(b) settings エントリの孤児は残る** [確認] — `fess_suggest` 設定インデックス側にあり `createNextIndex()` の対象外。`deleteAllElevateWord` は DB の行を回すため名指しされない（`0003` §10.3.1 (c) の障害 3）。**実害になる経路は 1 つだけである** [確認]: `indexer().deleteAll()` → `restoreElevateWord()`（`(sug) index/SuggestIndexer.java:295` ／ `(sug) index/operations/WordManagementOperations.java:148-152`）が settings の全エントリを再投入する。**その呼び出し元は `SuggestHelper.deleteAllWords()`（`:365-373`）＝ 管理画面「サジェスト」の全語削除と `/api/admin/suggest` の同操作の 2 つだけで、再構築経路からは呼ばれない。** **掃除の要否の判断は R1 以降の後続タスクへ送る**（旧記述の「L2 以降」を読み替え）。**旧記述は (a) と (b) を区別せず「孤児は掃除されない」とだけ書いていた** — 是正の記録は `0012` §11.4 |
| **4** | **`-o` はビルド中のネットワークアクセスを完全には止めない**（§1.7 の枠）。**A-6 / F-5 の DoD を「オフラインで成功すること」にしないこと**（プラン F-5 の作業内容 3 と同旨） | **A-6 / F-5** |
| **5** | **本ブランチの起点は `0004` §1.1 の記録（`3cd39b173`）から 18 コミット進んで `39cc32fa7` になっている**（§1.1 の枠）。**フェーズ A の残りステップが引用する `(fess)` 側の行番号は、その都度現物で確認すること**（`0004` §2.8 の 3 と同旨） | **A-2〜A-6** |

> **[確認] 既存 `SuggestHelperTest` が「常に緑」になる仕組み**（申し送り 2 の根拠。**A-6 の設計に直結するので実物で確認した**）
>
> | 事実 | 根拠 `file_path:line` |
> | --- | --- |
> | `setUp` は `suggestHelper = new SuggestHelper()` するだけで、**`suggester` を注入していない** | `(fess test) helper/SuggestHelperTest.java:43` |
> | **`suggestHelper.suggester()` は `null` である**（テスト自身がそう assert している） | 同 `:71`（`assertNull(suggestHelper.suggester())`） |
> | テストクラス内に `MockSuggester` が定義されているが、**どこからも生成・登録されていない**（定義箇所以外の出現が 0 件） | 同 `:502`（定義）／ `grep -n "MockSuggester"` の結果が定義行のみ [確認] |
>
> **したがって `addElevateWord` / `deleteElevateWord` は `suggester.indexer()` の時点で NPE を投げ、try-catch がそれを握って `assertTrue(true)` に落ちている** [推測。NPE そのものは捕捉していないが、上記 3 事実から演繹される]。**「渡された `ElevateWord` の中身を捕捉する」以前に、正規化コードの後半（`new ElevateWord(...)` の構築）まで到達していない可能性が高い。**
>
> **A-6 への含意** [提案]: **`suggester` を差し替えられる仕組みが要る。** ただし `MockSuggester` は `(sug) Suggester` を継承していない独立クラスであるため、**そのままでは `SuggestHelper.suggester` フィールドに代入できない** [確認]。プラン A-6 の作業内容 1 は「`Suggester` / `SuggestIndexer` をスタブ化し、`deleteElevateWord(...)` に渡された引数列を検査する形で足りる」[提案] としているが、**その差し込み口の設計自体が A-6 の作業に含まれる**。**プラン A-6 の作業内容 8 が「新規テストは別クラスに置くことを推奨する」としているので、既存クラスを直さずに別クラスで差し込み口を用意する方針と整合する。**
>
> なお fess 本体のテストは **JUnit 5**（`org.junit.jupiter.api.Test` / `TestInfo`）である [確認]（同 `:33-34` = `org.junit.jupiter.api.Test` / `org.junit.jupiter.api.TestInfo`）。fess-suggest 側（JUnit 4）と混同しないこと。

---

## 2. ステップ A-2: 語管理の一括処理を 1 件の失敗で止めない（`0003` §10.4 ／ **MO-25**）

**結果: プラン §4 ステップ A-2 の DoD 10 件のうち 8 件を充足。残り 2 件（失敗件数が A-3 の `exitCode` 判定に到達する ／ A-6 で追加するテストが緑）は A-3 / A-6 で閉じる（§2.9）。**

> **【2026-08-31 追記】本節の後に外部レビューを受け、その反映を `0010-review-response-a2.md` に記録した。**
> **反映にあたり `docs/0003-migration-ops-design.md` を第 13 版へ改訂した**（**MO-25 の規則 3 = 失敗件数の集計単位／規則 6 = 失敗隔離の適用範囲**の是正。**区分 I — 新しい X 番号 X-6 を起こし、新しい MO 番号は起こさない**。判定の根拠は `0010` §1.1 / §1.2）。
> **§1（A-1）と違い、A-2 は実装そのものが書き直された。** `0008` の反映がコメント／Javadoc に閉じたのに対し、**本ステップは public 3 メソッドを A-2 着手前の挙動（`void`・fail-fast）へ戻し、失敗隔離と件数集計を新設した再構築専用 2 メソッド（`ForRebuild`）へ移している。**
> **したがって本節は書き直し後の実装だけを記録する。** 第 12 版に基づく一度目の実装の記述（行番号・要件対応・DoD・申し送り）は**残していない** — **レビュー指摘の経緯・代替案・根拠は繰り返さず、`0010` を正本とする。** 覆った点の要約だけを §2.6 に置く。
> **本節が引用する行番号は、すべて書き直し後の作業ツリーで実物を開いて確認した値である**（§2.2）。
>
> **【2026-08-31・追記 2】書き直し後の実装に対する 2 回目の外部レビューで Approve（軽微修正推奨）を得た。その反映も `0010` §13 に記録した。**
> **指摘は 3 件で、コード修正を要したのは Javadoc 2 種のみである**（`(fess) helper/SuggestHelper.java` の **`storeAllElevateWords` / `deleteAllElevateWord` / `storeAllBadWords` の Javadoc 3 ブロック**。**実行文は 1 行も変えていない** — 根拠は `0010` §13.3）。
> **設計判断は 1 つも動いていない。** **`docs/0003-migration-ops-design.md` は第 13 版のまま無変更であり、新しい X 番号も MO 番号も起こしていない**（区分の判定は `0010` §13.5）。**プランもステップ A-2 / A-6 の本文は無変更である**（既に第 13 版を反映済みであり、レビュアーが参照したのは改訂前のプランであった — `0010` §13.2）。
> **本節の行番号・差分値・検証結果は、この 2 回目の反映を適用した後の作業ツリーで取り直した値である。**

> **本ステップの着手時に発火した逸脱 X-5（区分 I）は `0009-deviation-x5-store-all-delete-phase.md` に、その実装に対する外部レビューで発火した逸脱 X-6（区分 I）は `0010-review-response-a2.md` に、それぞれ分離してある**（§9.1 の注記「実装中に新たな逸脱が発生した場合は、その時点の最大番号 +1 で独立ファイルを作る。**フェーズのファイルに混ぜない**」）。**本節は両者の経緯・代替案・根拠を繰り返さず、A-2 の実装がプラン §2.1 の手続きを踏んだことだけを §2.6 に記す**（§1.6 が X-4 / `0006` に対して行っているのと同じ扱い）。**実装の正本は `0010` §5（擬似コード ＋ 要件 14 項目）である。`0009` §7 の擬似コードは `0010` が上書きしたので参照しないこと。**

### 2.1 前提と着手時の状態

| 項目 | 値 | 根拠 |
| --- | --- | --- |
| ブランチ | `feature/suggest-l1-precede` | `git branch --show-current` [確認] |
| HEAD | **`73e912715`**（`fix: normalize elevate word separators and keep add/delete ids symmetric` ＝ **A-1 の実装**） | `git log --oneline -1` [確認]。**`0008` / `0010` のメタ表「起点コミット」と同一である** |
| **「A-2 着手前」の意味** | **HEAD ＋ `0008` のレビュー反映**（コメント／Javadoc のみ・実行文 0 行）。**本節が「A-2 着手前と同一」と書くときはこの状態を指す** | `0008` §4 [確認] |
| 着手前の行番号の基準 | **`0008` §4.1 の値**（`storeAllElevateWords` = `:411` ／ `deleteAllElevateWord` = `:437` ／ `deleteAllBadWords` = `:558-560` ／ `storeAllBadWords` = `:567`） | `0008` §4.1 ／ プラン §4 ステップ A-2 の「対象」欄も同じ基準 [確認]。**HEAD 単独では `:411` / `:437` / `:550` / `:559` である** [確認]（`git show HEAD:... \| grep -n`。`0008` が `:550` より前で純増 8 行） |
| `modules/fess-suggest` | **無変更**（`git status --short` が空・ブランチは `feature/suggest-l1`） | [確認] |
| A-2 のコード変更 | **`(fess) helper/SuggestHelper.java` ＋ `(fess) exec/SuggestCreator.java` の 2 ファイル** | `git status --short` [確認] |

> **未コミットで作業ツリーに載っているのは `0008` のレビュー反映と本ステップ A-2 の変更の 2 つである** [確認]。**A-1 は `73e912715` としてコミット済みであり、以下の `git diff` には含まれない。**

### 2.2 変更したファイル

**変更ファイルは 2 つである** [確認]。**第 12 版に基づく一度目の実装は `(fess) helper/SuggestHelper.java` 1 ファイルだったが、X-6 の改訂で `(fess) exec/SuggestCreator.java` が対象に加わった**（プラン §4 ステップ A-2 の「対象」／ `0003` 第 13 版 §10.4 (j)）。

```
$ git diff --stat            # HEAD = 73e912715（A-1 適用済み）に対して
 .../org/codelibs/fess/exec/SuggestCreator.java     |   7 +-
 .../org/codelibs/fess/helper/SuggestHelper.java    | 306 +++++++++++++++++----
 2 files changed, 265 insertions(+), 48 deletions(-)
```

| 項目 | 値 |
| --- | --- |
| 変更ファイル数 | **2** |
| 挿入 / 削除（`0008` 込みの累積） | **265 / 48**（内訳は `git diff --numstat` で `SuggestHelper.java` = **260 / 46** ／ `SuggestCreator.java` = **5 / 2**）[確認]。**2 回目のレビュー反映（Javadoc 3 ブロック）で挿入が 255 → 260 に増えたが、削除は 46 のまま動いていない**（`0010` §13.3）|
| 新規ファイル | **なし** |
| **`import` の増減** | **0 行** [確認]。`Set`（`:31`）と `HashSet`（`:28`）は着手前から import 済みである |
| **フィールド宣言の増減** | **0 行** [確認]（`:80-107` に件数用・`Set` 用のフィールドは無い。MO-25 の規則 4） |
| **`modules/fess-suggest` への変更** | **なし** [確認] |
| **テストの追加・変更** | **なし**（意図的 — A-6 の担当。§2.10） |
| **呼び出し元の変更** | **管理画面／API の 11 箇所は無変更。`SuggestCreator` の 2 箇所のみ呼び先を切り替えた** [確認]（§2.3 の 8） |
| コミット | **未実施**（作業ツリーに未コミットで保持） |

> **この 265 / 48 は A-2 単独の差分ではない** [確認]。**HEAD に対する作業ツリーの累積差分であり、`0008` のレビュー反映（26 挿入 / 18 削除・コメントと Javadoc のみ — `0008` §4）を含む。** A-2 単独の差分は取得できない（`0008` が未コミットのため、コミット単位で分離できない）。**`SuggestHelper.java` の 13 ハンクのうち `@@ -475,3 +512,3 @@`（`deleteElevateWord` 内の行コメント）と `@@ -489,3 +526,4 @@`（`addElevateWord` の Javadoc）の 2 つが `0008` によるものである** [確認]（`git diff -U0` のハンクを実物で確認した。**旧側の範囲は `0007` §2 の第 12 版時点の記述と同一であり、新側の位置だけが移動している**）。

**変更後の主要メソッドの所在**（すべて `(fess) helper/SuggestHelper.java`。**2 回目のレビュー反映の適用後に、実物を開いて確認し直した値である** [確認]。**本表は `0008` §4.1 の値を上書きする**）:

| メソッド | 種別 | **Javadoc / 本体の位置（現作業ツリー）** |
| --- | --- | --- |
| `storeAllElevateWords(boolean)` | **public・A-2 着手前と同一挙動へ復元** | Javadoc `:406-420`（**2 回目のレビューで是正・+1 行**）／ 本体 **`:421-423`** |
| `deleteAllElevateWord(boolean)` | **public・同上**（Javadoc は §2.3 の 9 ＋ **2 回目のレビュー**で是正・+2 行） | Javadoc `:425-452` ／ 本体 **`:453-455`** |
| **`storeAllElevateWordsForRebuild()`** | **新設・public** | Javadoc `:457-480` ／ 本体 **`:481-485`** |
| `deleteElevateWord` | 無変更（位置のみ移動） | **`:508`** |
| `addElevateWord` | 無変更（位置のみ移動） | **`:539`** |
| `normalizeSeparators` | 無変更（位置のみ移動） | **`:581-583`** |
| **`storeAllElevateWordsInternal(boolean, Set<String>)`** | **新設・private** | Javadoc `:585-601` ／ 本体 **`:602-630`** |
| **`deleteAllElevateWordInternal(boolean, Set<String>)`** | **新設・private** | Javadoc `:632-640` ／ 本体 **`:641-666`** |
| **`deleteOneElevateWordRow(ElevateWord, boolean)`** | **新設・private**（A-1 / MO-24 の 1 行分の処理の抽出） | Javadoc `:668-677` ／ 本体 **`:678-688`** |
| `deleteAllBadWords()` | **本文は無変更。Javadoc のみ追記**（§2.3 の 5） | Javadoc `:690-698` ／ 本体 **`:699-701`** |
| `storeAllBadWords(boolean)` | **public・A-2 着手前と同一挙動へ復元** | Javadoc `:703-716`（**2 回目のレビューで是正・+2 行**）／ 本体 **`:717-719`** |
| **`storeAllBadWordsForRebuild()`** | **新設・public** | Javadoc `:721-742` ／ 本体 **`:743-747`** |
| **`storeAllBadWordsInternal(boolean, Set<String>)`** | **新設・private** | Javadoc `:749-764` ／ 本体 **`:765-784`** |

**`(fess) exec/SuggestCreator.java`**（`create()` は `:243-307`）:

| 変更前（プラン・`0003` 第 13 版の表記） | **変更後（現作業ツリー）** |
| --- | --- |
| `:255` `suggestHelper.storeAllBadWords(true);` | **`:257` `suggestHelper.storeAllBadWordsForRebuild();`**（`:255-256` に理由コメント 2 行） |
| `:258` `suggestHelper.storeAllElevateWords(true);` | **`:261` `suggestHelper.storeAllElevateWordsForRebuild();`**（`:260` に理由コメント 1 行） |

> **プラン・`0003` 第 13 版 §10.4 (j)・`0010` §5 が書く `:255` / `:258` はいずれも変更前の行番号である。** **変更後は `:257` / `:261` に移っている**（§2.8 の 1）。**2 回目のレビュー反映は `SuggestCreator.java` を 1 行も動かしていない**（`5 / 2` のまま）[確認]。

> **【2026-08-31・2 回目のレビュー反映による行番号の移動】** [確認] **是正した Javadoc 3 ブロックより後ろのメソッドが下へずれている。** 移動幅は **`deleteAllElevateWord` 以降が +3 ／ `storeAllBadWords` 以降が +5** である（`storeAllElevateWords` の Javadoc +1 ／ `deleteAllElevateWord` の Javadoc +2 ／ `storeAllBadWords` の Javadoc +2 の累積）。**本節および §2.3 / §2.4 / §2.8 / §2.9 の行番号は、すべて移動後の値へ更新済みである。** **`0010` §5 / §13.3 と `0003` 第 13 版が引く値との対応は §2.8 の 3 を参照。**

### 2.3 作業内容 1〜9（プラン §4 ステップ A-2）

**設計の正本は `0003` 第 13 版 §10.4（MO-25。規則 3・6 は X-6 で改訂）。擬似コードは `0010` §5。**

| # | プランの作業内容 | 実装 | 根拠 `file_path:line` |
| --- | --- | --- | --- |
| **1** | **再構築経路が駆動するすべての行単位ループを隔離する**（**3 ループ**。**削除フェーズを外してはならない**） | **3 ループとも `if (failedIds == null) { X; continue; } try { X } catch (...)` の形にし、`X` は 1 呼び出しに収めた**（`selectList` は `try` の外に置いたまま）。**削除フェーズは `storeAllElevateWordsInternal` が `deleteAllElevateWordInternal(apply, failedIds)` を呼ぶことで再構築経路にも掛かる** | 追加（elevate）: `for` = `:612`／fail-fast 分岐 = `:613-617`／`try` = `:618`／`catch` = `:621` ／ 削除（elevate）: `for` = `:647`／`:648-651`／`:652`／`:654` ／ 追加（bad word）: `for` = `:771`／`:772-775`／`:776`／`:778` ／ 削除フェーズの駆動 = `:605` ／ `selectList` は `:607-610` / `:642-645` / `:767-770` |
| **2** | **catch する例外の型を絞らない** | **3 箇所とも `catch (final Exception e)`** [確認]。狭める記述は無い。**理由（`normalizeSeparators` の NPE ／ `boost` のアンボクシング NPE ／ 将来の `SuggestItem` 不変条件違反）をコメントに残した** | `:621` ／ `:654` ／ `:778` ／ 理由コメント `:622-624` |
| **3** | **【X-6 で全面改訂】失敗件数は「失敗した行の数」とし、行 ID（`getId()`）で dedupe する。** `Set<String>` は `ForRebuild` のローカル変数とし、削除フェーズと追加フェーズで同一インスタンスを共有する。**インスタンスフィールドに持たない** | **`ForRebuild` 2 メソッドが `new HashSet<>()` を作り、`Internal` へ引数で渡し、`failedIds.size()` を返す。** `storeAllElevateWordsInternal` は**受け取った同じ `Set` をそのまま削除フェーズへ渡す**ため、**1 件の不正行が両フェーズで落ちても `Set` の要素は 1 つである** | 生成 `:482` / `:744` ／ 委譲 `:483` / `:745` ／ `return failedIds.size()` `:484` / `:746` ／ **両フェーズでの共有** `:603-605`（意図をコメントに明記）／ 収集 `:625` / `:658` / `:779` ／ **フィールド宣言の追加 0 件** [確認]（`:80-107`） |
| **4** | **握り潰さない。** 警告ログに**対象行の識別情報と例外**を含める。**`getSuggestWord()` を単独の識別子にしない** — `getId()` を主に、語は補助 | **3 箇所とも `logger.warn("Failed to ...: id={}, word={}", ...getId(), ...getSuggestWord(), e)`。`getId()` が先頭、例外 `e` が最終引数**（スタックトレースが出る）。**`getSuggestWord()` が `null` でありうるため単独の識別子にしない理由をコメントに残した** | `:626`（store elevate）／ `:659`（delete elevate）／ `:780`（store bad word）／ 理由コメント `:655-657`。`getId()` の存在は `(fess) opensearch/config/exentity/ElevateWord.java:92` ／ `BadWord.java:27`（いずれも `asDocMeta().id()`）[確認] |
| **5** | **`deleteAllBadWords()` は隔離しない**（行単位ループを持たない）。**非対称は意図的であり、コメントで明記する** | **本文は `suggester.settings().badword().deleteAll();` の 1 文のまま** [確認]。**`storeAllBadWordsInternal` は `failedIds` の値によらず `try` の外でこれを呼ぶ** — 例外は `storeAllBadWordsForRebuild()` からもそのまま伝播する。**理由を 2 箇所の Javadoc に明記した** | 本文 `:699-701` ／ 呼び出し `:766`（`try` の外）／ Javadoc `:690-698`（`deleteAllBadWords` 側）／ `:753-759`（`storeAllBadWordsInternal` 側） |
| **6** | **【X-6 で全面改訂】失敗隔離は再構築専用の内部経路に限定する。** public 3 メソッドの挙動は A-2 着手前と完全に同一（`void`・fail-fast・例外をそのまま伝播）。**呼び出し元 11 箇所は 1 行も変えない** | **public 3 メソッドは `Internal` へ `null` を渡す 1 行の facade になった**（`void` を返し、`failedIds == null` の分岐は `try` に一切入らない）。**管理画面／API の 11 箇所は無変更** [確認]（`git status --short` が 2 ファイル。うち 1 つは `SuggestCreator`）。**共通実装は private に 1 つだけ持ち、隔離版・非隔離版の 2 実装を作っていない** | facade `:421-423` / `:453-455` / `:717-719` ／ fail-fast 分岐 `:613-617` / `:648-651` / `:772-775` ／ 呼び出し元 11 箇所 = `AdminBadwordAction:348,402` ／ `AdminElevatewordAction:379,380,434,435` ／ `ApiAdminBadwordAction:154,210` ／ `ApiAdminElevatewordAction:177,178,236` [確認] |
| **7** | **`refresh()` の呼び出し位置と回数は A-2 着手前と同じにする** | **3 つの private 実装とも `refresh()` はループの外・末尾で 1 回のまま** [確認]。**`storeAllElevateWordsInternal` 経由では削除フェーズ内と末尾で合計 2 回走るが、それも A-2 着手前と同じである** — 減らしていない。**その旨をコメントに残した** | `:629`（追加フェーズ末尾）／ `:665`（削除フェーズ末尾）／ `:783`（bad word）／ 2 回走ることの説明 `:662-664`。**着手前は `:423` / `:454` / `:569` の 3 箇所**（HEAD 実物）[確認] |
| **8** | **【X-6 で追加】`(fess) exec/SuggestCreator.java:255` / `:258` の 2 行を `ForRebuild` の呼び出しに切り替える。** 戻り値は捨ててよい。**捨てていることと合流先が A-3 であることをコメントで明記する** | **2 つの式文を `storeAllBadWordsForRebuild()` / `storeAllElevateWordsForRebuild()` へ差し替え、理由コメントを付した。** 戻り値は受けていない。**それ以外の行に触れていない** [確認] | 現行 `:257` / `:261` ／ コメント `:255-256`（「The failure count is discarded here; folding it into exitCode is done by A-3.」）／ `:260` ／ 差分は `git diff` で **5 挿入 / 2 削除** [確認] |
| **9** | **【X-6 で追加】`deleteAllElevateWord` の Javadoc の誤りを是正する。** **`convertEmptyToNull` を経由することを必ず書く** | **3 段の記述に改めた**: 「`/_bulk` 復元が blank な `suggestWord` の行を残しうる」→「`getSuggestWord()`（生成コード `BsElevateWord`）が `convertEmptyToNull` で `null` に変換する」→「`normalizeSeparators(null)` が NPE を投げる」。**さらに「`normalizeSeparators("")` 自体は throw せず `""` を返す」ことを明示した**。**加えて 2 回目のレビューで第 3 段落（`:442-449`）も是正した** — 「`storeAllElevateWords` はこのメソッドを直接呼ばない。両者は同じ private 共通実装に委譲する」（`0010` §13.3 (a)） | `:433-441`（第 2 段落）／ `:442-449`（第 3 段落・**2 回目のレビュー分**）。裏付けは `(fess) opensearch/config/bsentity/BsElevateWord.java:190-193`（`return convertEmptyToNull(suggestWord);`）／ `(fess) opensearch/config/allcommon/EsAbstractEntity.java:199-201`（`value != null && value.length() == 0` を `null` に）[確認] |

> **`0010` §5 の擬似コードとの相違は 1 点だけである** [確認]。**警告ログに `word={}` を足した**（擬似コードも `id={}, word={}` を書いているため、実質的な相違は無い）。**`0010` §5 の要件 10 が「語は補助として第 2 引数に置く」と明記しており、一度目の実装の判断がそのまま維持されている。**

### 2.4 `0010` §5.1 の実装要件 14 項目との対応

**`0010` §5.1 の要件表を項目番号どおりに照合した。14 項目すべてを満たしている** [確認]。

| # | 要件（`0010` §5.1） | 充足の根拠 |
| --- | --- | --- |
| **1** | public 3 メソッドの挙動を A-2 着手前と完全に同一にする。呼び出し元 11 箇所は 1 行も変えない | `:421-423` / `:453-455` / `:717-719` はいずれも `void` を返し `Internal(..., null)` へ委譲するのみ。**`failedIds == null` の分岐は `try` に入らない**（`:613-617` / `:648-651` / `:772-775`）。呼び出し元 11 箇所は無変更 [確認] |
| **2** | `ForRebuild` 2 メソッドを新設し `apply = true` を固定。**呼び出し元制約を Javadoc に明記** | `:481-485` / `:743-747`（`Internal(true, failedIds)`）。**「this method exists only for `org.codelibs.fess.exec.SuggestCreator` to call. It cannot be package-private because `SuggestCreator` lives in a different package」を両方の Javadoc に書いた** — `:468-475` ／ `:731-738` |
| **3** | 共通実装は private に 1 つだけ。**同じロジックの 2 実装を作らない** | `storeAllElevateWordsInternal`（`:602`）／ `deleteAllElevateWordInternal`（`:641`）／ `storeAllBadWordsInternal`（`:765`）の 3 つだけ。**さらに 1 行分の処理を `deleteOneElevateWordRow`（`:678`）に切り出し、fail-fast 側（`:649`）と隔離側（`:653`）が同じ 1 実装を呼ぶ** [確認] |
| **4** | 失敗件数は行 ID で dedupe。`Set` は `ForRebuild` のローカルで両フェーズ共有。フィールドにしない | §2.3 の 3。**`:603-605` が「Sharing the same Set with the delete phase is what makes a row that fails in both phases count once instead of twice.」と明記** |
| **5** | 削除フェーズも隔離の対象 | `deleteAllElevateWordInternal` の `try`（`:652-661`）。再構築経路からの駆動は `:605` |
| **6** | catch する型を絞らない | `catch (final Exception e)` ×3（`:621` / `:654` / `:778`） |
| **7** | `deleteAllBadWords()` は隔離しない | `:766` が `try` の外。本文 `:699-701` は無変更 |
| **8** | `deleteAllElevateWord` の Javadoc を 3 段の記述に是正。`convertEmptyToNull` を必ず書く | `:433-441`（§2.3 の 9） |
| **9** | `refresh()` の位置と回数は着手前と同じ。**2 回走ることも含めて減らさない** | `:629` / `:665` / `:783` ／ 説明コメント `:662-664`（§2.3 の 7） |
| **10** | 警告ログの識別子は `getId()` を主に、語は第 2 引数、例外は最終引数 | `:626` / `:659` / `:780` |
| **11** | `SuggestCreator` の 2 行を切り替え、戻り値は捨ててよい（合流は A-3 とコメント） | `:255-257` / `:260-261`（§2.3 の 8） |
| **12** | `AdminBackupAction` に手を入れない | **無変更** [確認]（`git status --short` の 2 ファイルに含まれない） |
| **13** | `modules/fess-suggest` を触らない | **無変更** [確認]（同モジュールの `git status --short` が空） |
| **14** | **A-1 / MO-24 が書いた文（`normalizeSeparators` の実装・両キー削除の条件式）を変えない** | `normalizeSeparators`（`:581-583`）は `text.replace("　", TEXT_SEP).replaceAll(TEXT_SEP + "+", TEXT_SEP).trim()` のまま [確認]。`deleteOneElevateWordRow`（`:678-688`）の**実行文 5 行は HEAD の `deleteAllElevateWord` のループ本体と完全に一致する** [確認]（§2.8 の 2） |

### 2.5 実装上の判断

| # | 判断 | 理由 |
| --- | --- | --- |
| **1** | **fail-fast と隔離の切り替えを `if (failedIds == null) { X; continue; } try { X } catch` の形にした**（`0010` §5.2 の 2 の [提案] を採用） | **public 経路が `try` に一切入らないことがコード上で自明になり、「挙動が変わっていない」ことを差分レビューで確認しやすい。** `catch (Exception e) { throw e; }` の precise-rethrow 形でも挙動は同じだが、読み手に「public も一度 `try` に入る」と読ませる |
| **2** | **`X` を 1 呼び出しに収めるため、削除側は `deleteOneElevateWordRow` を切り出した** | 上記 1 の形では `X` の**呼び出し文**が 2 回書かれる。**1 呼び出しに収めれば重複は 1 行で済み、ロジックの重複にはならない**（`0010` §5.2 の 2）。**追加側は元から `addElevateWord(...)` / `addBadWord(...)` の 1 呼び出しであるため切り出していない** |
| **3** | **`ForRebuild` を public にした** | **`SuggestHelper`（`org.codelibs.fess.helper`）と `SuggestCreator`（`org.codelibs.fess.exec`）が別パッケージであり、package-private では呼べない** [確認]。**「呼び出し元は `SuggestCreator` のみ」という制約は型システムで強制できず、Javadoc（`:468-475` / `:731-738`）でしか表明できない。** これは本設計が引き受けた制約であり、`0010` §7 の 7 に残存リスクとして記録されている |
| **4** | **Javadoc に Why を書いた**（**記述は 2 回目のレビューで精密化した**） | public 3 メソッドには**「fail-fast は意図的である」**ことと、その理由を書いた（`:408-417` / `:442-449` / `:705-713`）。**当初は「管理画面／API の呼び出し元が伝播した例外を validation error に変換する」と一般化していたが、2 回目のレビューを受けて「同期 4 経路は validation error になる／CSV upload の非同期 4 経路は背景タスク内の `FessSystemException` にしかならない」と書き分けた**（`0010` §13.3 (b)）。`Internal` には**「引数で切り替えるのは 2 実装の drift を防ぐためである」**ことを書いた（`:588-594`）。**A-1 / `0008` の文体（`<p>` 段落・What ではなく Why）に合わせた** [確認] |
| **5** | **A-1 / `0008` が書いた文を書き換えず、`try` と分岐で囲んで移設するだけにした** | 差分レビューで **A-1 / MO-24 の決定（正規化・両キー削除の条件）が変わっていないことを確認しやすくする**ため（§2.4 の 14） |
| **6** | **`storeAllBadWordsInternal` では、着手前にあった局所変数 `final String word = badWord.getSuggestWord();` を残さず `addBadWord(badWord.getSuggestWord(), apply)` に直接渡した** [確認] | **`try` の内側で宣言すると `catch` 節から参照できず、ログ側で `badWord.getSuggestWord()` を呼び直すことになる** [推測]。**挙動は同一である** — `getSuggestWord()` は `checkSpecifiedProperty` ＋ `convertEmptyToNull` を通すゲッタであり（`(fess) opensearch/config/bsentity/BsBadWord.java:153-156`）[確認]、**public 経路での呼び出し回数も 1 行につき 1 回のまま**である（2 回目は隔離経路の失敗時のログ出力だけ） |

### 2.6 逸脱 X-5 / X-6 の手続きと、一度目の実装が覆った経緯（**詳細は `0009` / `0010` — ここでは繰り返さない**）

**A-2 は 2 度の逸脱を経ている。いずれもプラン §2.1 の手続き（改訂 → 記録 → 実装）の順序が守られた** [確認]。

| 順序 | 実施内容 | 記録 |
| --- | --- | --- |
| **1** | **着手時に逸脱 X-5（区分 I）が発火。** `docs/0003-migration-ops-design.md` を第 11 版 → **第 12 版**へ改訂し **MO-25** を採番した（コード変更なし） | `docs/0003-migration-ops-design.md:3` ／ `:34`（改訂履歴 第 12 版の行）／ `:70`（MO-25）／ `:939`（§10.4） |
| **2** | **`0009-deviation-x5-store-all-delete-phase.md` に記録した** | `0009` のメタ表 |
| **3** | **第 12 版に沿って一度目の実装を行った**（下表 A 列） | — |
| **4** | **その実装に対する外部レビューで逸脱 X-6（区分 I）が発火。** `0003` を **第 13 版**へ改訂し、**MO-25 の規則 3 と規則 6 を是正した**（コード変更なし。**新しい MO 番号は起こさない**） | `docs/0003-migration-ops-design.md:3`（現在の版 = 第 13 版）／ `:17`（第 13 版の宣言）／ `:35`（改訂履歴 第 13 版の行）／ `:998-1008`（(e) の規則）／ `:1010`（(f)）／ `:1049`（(i)）／ `:1071`（(j)） [確認] |
| **5** | **`0010-review-response-a2.md` に記録した**（同書のメタ表に「コード変更: **なし**。A-2 の再実装は本書の完了後に行う」と明記） | `0010:20` [確認] |
| **6** | **第 13 版に沿って実装を書き直した**（下表 B 列） | 本節 §2.3 / §2.4 |
| **7** | **書き直し版に対する 2 回目の外部レビューで Approve を得た（軽微修正推奨）。** **逸脱は発火していない** — **設計判断が 1 つも動かず、`0003` の改訂も版上げも不要だったため**（区分の判定は `0010` §13.5）。**是正は `(fess) helper/SuggestHelper.java` の Javadoc 3 ブロックのみで、実行文は 0 行** | **`0010` §13**（§1〜§12 は 1 回目の記録として無変更） |

**覆った点の要約**（**判定理由・代替案・撤回した根拠は `0010` を参照すること**）:

| 論点 | **A: 一度目の実装（第 12 版）** | **B: 現在の実装（第 13 版）** | 正本 |
| --- | --- | --- | --- |
| **失敗件数の集計単位** | 削除フェーズと追加フェーズの**合算（項目処理数）**。1 件の不正行は **2 件**と数える | **失敗した行の数。行 ID（`getId()`）で dedupe** し、両フェーズで落ちても **1 件** | `0010` §2 ／ `0003` 第 13 版 §10.4 (e) の 3・(f) |
| **失敗隔離の適用範囲** | **public 3 メソッドのループ本体**に置く。管理画面／API 経路にも及ぶことを**受け入れる** | **再構築専用の内部経路に限定。** public 3 メソッドは fail-fast のまま | `0010` §3 ／ 同 (e) の 6・(i) |
| **メソッド構成** | public 3 メソッドの戻り値を `void` → **`int`** に変更 | public 3 メソッドは **`void` へ戻す**。**`ForRebuild` 2 メソッドを新設**し、共通実装を private に 1 つ持つ | `0010` §5 ／ 同 (j) |
| **`SuggestCreator`** | **触れない**（A-3 の対象） | **`:255` / `:258` の 2 行の呼び先を切り替える**（戻り値は捨てる） | `0010` §5 の 4 ／ 同 (j) |
| **A-2 の DoD** | 8 項（うち失敗件数は「**1 以上**」で検査） | **10 項**（失敗件数は「**1**（等値）」で検査） | プラン §4 ステップ A-2 ／ `0010` §2.4 |

> **「規則 1・2・4・5・7 は生き残っている」** [確認]（`0010` §6.1）。**X-5 の中核的な発見（削除フェーズが追加ループのスキップ機構に到達する前に落ちる）は覆っていない** — 現在の実装でも削除フェーズは隔離対象である（§2.3 の 1）。**覆ったのは規則 3 と規則 6 の 2 つだけである。**

### 2.7 検証結果 [確認]

**すべて `modules/fess` で実行した。以下の 4 件は、2 回目のレビュー反映（Javadoc 3 ブロックの是正）を適用した後の作業ツリーで独立に再実行した値である** [確認]（`0010` §13.6 と同一の実行）。

| コマンド | 結果 | 備考 |
| --- | --- | --- |
| `mvn -o formatter:validate` | **`BUILD SUCCESS`** ／ `Processed 1694 files (Formatted: 0, Skipped: 1694, Unchanged: 0, Failed: 0, Readonly: 0)` ／ Total time 4.504 s（`license:check` と同時実行） | **整形違反なし。** 実装エージェントは `mvn -o formatter:format license:format` を実行している。**本書ではソースを書き換えない読み取り専用の `validate` で同じ結論を確認した**（§1.7 / 第 12 版時点と同じ扱い） |
| `mvn -o license:check` | **`BUILD SUCCESS`** ／ `License check: 1694 file(s) checked (OK: 1694, Missing: 0, Unknown: 0)` ／ 同上 | **ライセンスヘッダの欠落なし。** `license:format` の読み取り専用版 |
| `mvn -o compile` | **`BUILD SUCCESS`** ／ **`Warnings: 0, Errors: 0`** ／ Total time 10.512 s | **`int` → `void` の戻しと `ForRebuild` の新設を含めて、呼び出し元 13 箇所（管理画面／API 11 ＋ `SuggestCreator` 2）がすべて解決する**ことの実測 |
| `mvn -o test -Dtest=SuggestHelperTest` | **`Tests run: 24, Failures: 0, Errors: 0, Skipped: 0`** → **`BUILD SUCCESS`** ／ Total time 23.743 s | 既存 24 件が全緑。**テスト実行後も `git status --short` は 2 ファイルのままである** [確認] |
| `git diff --stat`（HEAD = `73e912715`） | **2 files changed, 265 insertions(+), 48 deletions(-)** — `SuggestCreator.java` **7 行**（5 / 2）／ `SuggestHelper.java` **306 行**（260 / 46） | **2 回目のレビュー反映で `SuggestHelper.java` の挿入が 255 → 260 に増え、削除は 46 のまま動いていない**（§2.2 ／ `0010` §13.3）。**`modules/fess-suggest` は `git status --short` が空** [確認] |

**`ForRebuild` の呼び出し元を grep で確認した** [確認]（`0010` §7 の 7 / §8 の 7 の [提案] を本書の執筆時に実施した）:

```
$ grep -rn -e storeAllElevateWords -e deleteAllElevateWord -e storeAllBadWords src/main/java | grep -v helper/SuggestHelper.java
```

**`*ForRebuild` の呼び出しは `(fess) exec/SuggestCreator.java:257` / `:261` の 2 箇所のみであり、他のファイルには 1 件も存在しない。** **残り 11 箇所はすべて public 3 メソッドの呼び出しであり、管理画面／API の 4 クラスに閉じている**（§2.3 の 6 の表）。

> **【落とし穴・A-3 / A-6 へ再掲】戻り値型だけを変える変更では、Maven の増分コンパイルが古いテストバイトコードを再利用しうる** [確認]
>
> **第 12 版の実装（`void` → `int`）で発生した事象である**: `testCompile` が **`Nothing to compile - all classes are up to date`** と判定し、変更前のシグネチャでコンパイル済みの `SuggestHelperTest.class` を再利用して **`NoSuchMethodError` が 3 件**発生した。`(fess test) helper/SuggestHelperTest.java` を **`touch`** して強制的に再コンパイルさせたところ 24 件すべて緑になった。
>
> **本ステップの書き直し（`int` → `void` の戻し）も同じ落とし穴に当たる** [確認]（`0010` §5.2 の 3 が事前に警告している）。**呼び出し側のソース文は式文のままで変わらないため、ソース差分の検出だけではシグネチャ変更を検知できない。** **`touch` か `mvn clean` を挟むこと。** **本書執筆時の再実行では `Nothing to compile - all classes are up to date` と出たうえで 24 件が緑であり、再現していない**（既に再コンパイル済みのため）[確認]。**CI のように `clean` を挟む環境では再現しない** [推測]。

**テストは追加していない。** **A-2 の検証（MO-25 の 4 点）は A-6 の作業内容 2 の担当である**（`0001-work-plan.md:586-592` ／ `0003` 第 13 版 §10.4 (g) が「MO-25 の検証は A-2 の DoD ＋ A-6 の作業内容 2 が担う。§11 に新しい T 番号は起こしていない」と明記 — `docs/0003-migration-ops-design.md:1036`）。

### 2.8 報告と実物の食い違い（**実物を優先した**）

**本節の執筆にあたり、引用された `file_path:line` と主張をすべて実物で確認した。記録すべき差異が 5 件あった**（**4・5 は 2 回目のレビュー反映で新たに生じたものである**）。

| # | 記述 | 実物 | 扱い |
| --- | --- | --- | --- |
| **1** | プラン §4 ステップ A-2 の作業内容 8・DoD 6、`0003` 第 13 版 §10.4 (j)、`0010` §5 の 4 は、`SuggestCreator` の対象を **`:255` / `:258` の 2 行**と書いている | **変更後は `:257` / `:261` である** [確認]。**作業内容 8 自身が要求する理由コメント（3 行）を足したため、2 つの式文が下へずれた** | **`:255` / `:258` は変更前の行番号として読む。** **DoD 6「変更が 2 行に限られている」は「実行文の変更が 2 行」と解した** — `git diff --numstat` は **5 挿入 / 2 削除**であり、増分 3 行はすべてコメントである [確認]。**コメントの付与は作業内容 8 が明示的に要求している**ため、DoD 違反ではない（§2.9 の DoD 6） |
| **2** | `0010` §5 の 3 は `deleteOneElevateWordRow` について「A-1 / MO-24 が入れた 1 行分の処理。**文面（正規化・両キー削除の条件）は変えない**」としている | **実行文 5 行は HEAD（A-1）の `deleteAllElevateWord` のループ本体と完全に一致する** [確認]（`rawWord` の取得 → `normalizeSeparators` → 正規化キーの削除 → `if (!normalizedWord.equals(rawWord))` → 生キーの削除）。**一方、内側の行コメントは HEAD の文面ではなく、`0008` §2.3 の 3 が是正した「`deleteElevateWord` へ委譲する」形である** [確認] | **「A-2 が文面を変えていない」という主張は実行文について成立する。** コメントの差は `0008` によるものであり A-2 によるものではない。**ただし `0008` は未コミットであるため「A-2 着手前の作業ツリー」を再現できず、コメント文字列の byte 単位の一致までは検証していない** [要確認] |
| **3** | `0003` 第 13 版 §10.4 (e) の規則 1 は、削除フェーズを `(fess) helper/SuggestHelper.java:443-453`、追加フェーズを `:419-422` と書いている | **いずれも A-2 着手前の行番号である。** 現在は削除フェーズが `:647-661`、追加フェーズが `:612-628` である [確認] | **設計書は改訂しない**（本作業の対象外）。**本書 §2.2 / §2.3 の行番号を正とする** |
| **4** | **【2 回目のレビュー反映で発生】本節の初稿が記録した `(fess) helper/SuggestHelper.java` の行番号は、Javadoc 3 ブロックの是正によって全面的にずれた** | **`deleteAllElevateWord` 以降が +3 ／ `storeAllBadWords` 以降が +5** [確認]（`storeAllElevateWords` の Javadoc は +1）。例: `normalizeSeparators` 本体 `:578-580` → **`:581-583`** ／ `storeAllBadWordsInternal` 本体 `:760-779` → **`:765-784`** | **§2.2〜§2.4・§2.8・§2.9 の行番号をすべて実物で取り直して更新した。** **`(fess) exec/SuggestCreator.java` は動いていない**（`:257` / `:261`）[確認] |
| **5** | `0010` §4.2 は「**是正対象は `deleteAllElevateWord` の Javadoc 1 箇所である**」と書いており、プラン §4 ステップ A-2 の作業内容 9（`0001-work-plan.md:464`）も同メソッドのみを対象としている | **実物では Javadoc 3 ブロックが是正されている** [確認]（`storeAllElevateWords` `:406-420` ／ `deleteAllElevateWord` `:425-452` ／ `storeAllBadWords` `:703-716`） | **食い違いではなく追加である。** **`0010` §4.2 が扱ったのは「`normalizeSeparators` が throw する機序」の誤りであり、2 回目のレビューが指摘したのは「エラー契約の一般化が過剰」という別の誤りである**（`0010` §13.3）。**対象外のブロックを正確にすることは作業内容 9 の違反ではないため、プランは改訂していない** |

### 2.9 DoD の充足状況

**プラン §4 ステップ A-2 の DoD は 10 項目である**（`0001-work-plan.md:466-475`。**X-6 で 8 項 → 10 項に増えた**）[確認]。

| # | DoD | 結果 | 何をもって充足と判断したか |
| --- | --- | --- | --- |
| **1** | **再構築経路の削除フェーズが 1 件の不正行（`getSuggestWord()` が `null`）で止まらない**（X-5 / MO-25） | **充足** | `storeAllElevateWordsForRebuild()` は `failedIds`（非 `null`）を `deleteAllElevateWordInternal` へ渡す（`:483` → `:605`）ため、削除フェーズが `try`（`:652`）の側に入る。**`deleteOneElevateWordRow` 内の `normalizeSeparators(rawWord)`（`:680`）が投げる NPE を `catch (final Exception e)`（`:654`）が受け、`failedIds.add(...)`（`:658`）してループを継続する** [確認]。**機械的検証は A-6**（DoD 10） |
| **2** | 不正な elevate word を 1 件含む入力で **`storeAllElevateWordsForRebuild()` が完走し、失敗件数 1（等値）**（X-6。「1 以上」は撤回） | **充足** | 追加フェーズも `try`（`:618`）で隔離され、`:484` が `failedIds.size()` を返す。**同じ不正行は削除フェーズ（`:658`）と追加フェーズ（`:625`）で同一の `getId()` を同一の `Set` に入れるため、要素数は 1 のままである** [確認]（共有は `:603-605`）。**`getId()` は `selectList` 経由の行で `null` にならない**（`0010` §2.2 の 2）。**機械的検証は A-6** |
| **3** | **`boost` が `null` の行を 1 件含む入力で追加フェーズが止まらず、失敗件数 1**（X-5） | **充足** | `boost` のアンボクシング NPE の発生点は `addElevateWord` 内の `new org.codelibs.fess.suggest.entity.ElevateWord(normalizedWord, boost, ...)`（`:557`。コンストラクタは `final float boost` — `(sug) entity/ElevateWord.java:66-67`）であり、**`try`（`:618-620`）の内側の呼び出しから生じる**ため `catch`（`:621`）が受ける [確認]。**このケースは削除フェーズを通過する**（`suggestWord` は正常）ため、`Set` に入る `getId()` は 1 つだけである |
| **4** | **bad word の追加ループに失敗隔離が入り、`deleteAllBadWords()` には入っていない**（X-5 / MO-25 の規則 5） | **充足** | 追加ループ = `try` `:776` / `catch` `:778`。`deleteAllBadWords()` の呼び出し `:766` は `try` の外、本文 `:699-701` に `try` 無し [確認]。**非対称の理由を 2 箇所の Javadoc（`:690-698` / `:753-759`）に明記した** |
| **5** | **【X-6】public 3 メソッドの挙動が A-2 着手前と完全に同一である**（`void`・fail-fast・例外をそのまま伝播）。**呼び出し元 11 箇所が無変更**（MO-25 の規則 6） | **充足** | 3 メソッドとも `void` を返し `Internal(apply, null)` へ委譲する（`:422` / `:454` / `:718`）。**`failedIds == null` の分岐（`:613-617` / `:648-651` / `:772-775`）は `try` に一切入らないため、例外はそのまま伝播する** [確認]。呼び出し元 11 箇所は `git status --short` の 2 ファイルに含まれない [確認]。**同期 4 経路（`AdminElevatewordAction:379-380` / `ApiAdminElevatewordAction:177-178` / `AdminBadwordAction:348` / `ApiAdminBadwordAction:154`）が例外を `throwValidationError(Api)` に変換する構造も無変更である** [確認]。**機械的検証は A-6**（作業内容 2 の④） |
| **6** | **【X-6】`(fess) exec/SuggestCreator.java` の変更が `:255` / `:258` の 2 行に限られている** | **充足**（**解釈を付す**） | **実行文の変更は 2 行のみである** [確認]。増えた 3 行はすべて**作業内容 8 が明示的に要求した理由コメント**（`:255-256` / `:260`）であり、`git diff --numstat` は 5 挿入 / 2 削除。**`create()` の他の行・他のメソッド・他のファイルには触れていない** [確認]（§2.8 の 1） |
| **7** | **失敗件数が A-3 の `exitCode` 判定に到達する** | **A-3 で閉じる**（**本ステップでは未充足**） | **`SuggestCreator` は `ForRebuild` を呼ぶが戻り値を捨てている** [確認]（`:257` / `:261` は式文）。**プラン自身が「（A-3 で完成する）」と書いており**（`0001-work-plan.md:472`）、**合流は A-3 の作業内容 5 の担当である**（`0003` 第 13 版 §10.4 (j) の担当範囲表）。**コード側にも「folding it into exitCode is done by A-3」と明記してある**（`:256`） |
| **8** | **失敗件数と dedupe 用の `Set` が `SuggestHelper` のインスタンスフィールドに保持されていない**（MO-25 の規則 4） | **充足** | **`Set<String> failedIds` は `ForRebuild` 2 メソッドのローカル変数のみ**（`:482` / `:744`）。件数は `failedIds.size()` の戻り値であり変数にも保持していない。**クラスのフィールド宣言（`:80-107`）に追加は 0 件** [確認]（`git diff` にフィールド宣言のハンクが無い） |
| **9** | **`AdminBackupAction` の `/_bulk` 復元経路に手を入れていない** | **充足** | **無変更** [確認]（`git status --short` が `SuggestHelper.java` ＋ `SuggestCreator.java` の 2 件）。`0003` §13 の 8 により後続スコープ |
| **10** | **A-6 で追加するテストが緑** | **A-6 で閉じる**（**未充足ではない**） | **A-6 の成果物であり、A-2 の時点では存在しない。** プラン A-6 の作業内容 2（`0001-work-plan.md:586-592`）と DoD（同 `:602-603`）が **X-6 を受けて更新済み**であり、**新しい T 番号は起こさない**。**本項目は A-6 の完了をもって閉じる**（§1.9 の DoD 5 と同じ扱い） |

> **DoD 7・10 が A-3 / A-6 待ちであることは、A-2 の実装に不足があることを意味しない。** ただし **A-3 が終わるまで失敗件数は誰にも読まれない**（`SuggestCreator` が戻り値を捨てている）ため、**A-2 単体をリリースしても切替は止まらない**（`0010` §7 の 6）。**また A-6 が終わるまで MO-25 の正しさは機械的に保証されていない**（現時点の 24 件のテストは失敗隔離の振る舞いを何も検証していない — §1.11 の 2 と同じ構造上の理由）。
>
> **[確認] 本ステップは `ForRebuild` を新設したことで「dead code を残さない」条件も満たしている**（`0003` 第 13 版 §10.4 (j) の理由 1）。**`SuggestCreator` の呼び先を切り替えたため、A-2 の完了時点で SuggestJob の全件再構築が 1 件の不正行で止まらなくなっている。**

### 2.10 スコープ外（変更していないもの）

**誤解を防ぐため、あえて触れなかった範囲を明記する。**

| 対象 | 状態 | 理由 |
| --- | --- | --- |
| **`modules/fess-suggest` 全体** | **無変更** [確認] | `0010` §5.1 の 13 ／ **C-01**（プラン `0001-work-plan.md:22`）／ `0003` 第 13 版 §10.4 (h)「MO-25 はライブラリ側に新しい受け口を求めない。**`ForRebuild` 2 メソッドも fess 本体側である**」 |
| **`(fess) exec/SuggestCreator.java` の `:255` / `:258` 以外のすべて** | **無変更** [確認] | **`exitCode` への合流・G1 / G3 の設置・ガード判定部の切り出しは A-3 の対象**（作業内容 5・7） |
| **管理画面／API の呼び出し元 11 箇所**（`AdminElevatewordAction` / `ApiAdminElevatewordAction` / `AdminBadwordAction` / `ApiAdminBadwordAction`） | **無変更** [確認] | **【X-6】エラー契約を変えないことが MO-25 の規則 6 の中身そのものである**（`0003` 第 13 版 §10.4 (i)）。**第 12 版の実装はここに影響していたが、それは撤回された** |
| **`(fess) app/web/admin/backup/AdminBackupAction.java`** | **無変更** [確認] | 入口側バリデーションは後続スコープ（`0003` §13 の 8。**第 13 版でも不変**） |
| **`(fess test) helper/SuggestHelperTest.java`** | **無変更** [確認]（第 12 版の実装時に `touch` はしたがソースは 1 行も変えていない — §2.7） | **A-6 の対象**。プラン A-6 の作業内容 8 が「既存 `SuggestHelperTest` の握り潰し構造には手を入れない」としている |
| **A-1 / `0008` の成果**（`normalizeSeparators` の実装・両キー削除の条件式・既存 Javadoc の文面） | **無変更** [確認] | A-2 は分岐／`try`／`Set` への収集／facade 化と Javadoc の**追記**のみ。既存の記述は削っていない（§2.4 の 14 ／ §2.8 の 2） |
| **`(fess res) suggest_indices/` の 3 ファイル** | **無変更** [確認] | **ステップ A-4 の対象**（U-2） |
| **`docs/0003-migration-ops-design.md`** | **無変更**（**第 13 版のまま**）[確認] | **X-6 の改訂は `0010` の作業で完了済みである。** **2 回目のレビューは設計判断を 1 つも動かしていないため、改訂も版上げも行わない**（区分の判定は `0010` §13.5） |
| **`0009`** | **無変更** | X-5 の記録は履歴として保存する |
| **`0010` ／ `0001-work-plan.md`** | **2 回目のレビュー反映で更新した**（`0010` = **§13 を追記**・§1〜§12 は無変更 ／ プラン = **§9.2 の末尾注記に 1 行**のみ。**ステップ A-2 / A-6 の本文は無変更**） | `0010` §13.2 / §13.5 / §13.7 |
| コミット | **未実施** | A-1 以外はフェーズ 0 と同じ運用（`0004` §1.6 の 4）。作業ツリーに保持している |

### 2.11 次ステップへの申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **`(fess) exec/SuggestCreator.java` の呼び先は既に `ForRebuild` に切り替わっている**（`:257` / `:261`）[確認]。**A-3 に残っているのは「戻り値（`int`）を受けて `exitCode` に合流させる」ことだけである。** **受け渡し形は `0010` で確定済みであり、A-3 で再検討しない**（`0009` §11 の 2 はこれで閉じた）。**public 3 メソッドを呼んではならない** — fail-fast であり失敗件数を返さない（プラン A-3 の作業内容 5）。**2 回目のレビューの指摘 3 が同じ点を独立に指摘している** — §2.11 の 9 | **A-3**（作業内容 5） |
| **2** | **A-2 用のテストは本ステップで追加していない。** **A-6 の検査は 4 点である**（`0003` 第 13 版 §10.4 (g) ／ `0010` §8 の 3 ／ プラン A-6 の作業内容 2）: ①`getSuggestWord()` が `null` の行で**再構築経路の削除フェーズが止まらない** ②同じ入力で **`storeAllElevateWordsForRebuild()` が完走し失敗件数 1（等値）** ③`getBoost()` が `null` の行で**追加フェーズが止まらず失敗件数 1** ④**`storeAllElevateWords(false)` / `deleteAllElevateWord(false)` / `storeAllBadWords(false)` が従来どおり例外を伝播する**（回帰防止）。**新しい T 番号は起こさない** | **A-6** |
| **3** | **失敗件数は「1 以上」ではなく「1」（等値）で検査すること** [確認]。**行 ID で dedupe しているため、1 件の不正行は両フェーズで落ちても 1 件である**（`0003` 第 13 版 §10.4 (e) の 3 / (f)）。**`assertTrue(failures >= 1)` は 2 も 3 も通すため、二重計上の回帰を検知できない**（`0010` §2.4）。**第 12 版までの記述（`0009` §11 の 3 ／ プラン §9.2 の第 12 版改訂注記 `0001-work-plan.md:1916`）を参照しないこと — いずれも撤回済みである。** **本節の第 12 版時点の記述は本書から削除した**（§2 冒頭の追記ブロック） | **A-6** |
| **4** | **「戻り値型だけを変える変更」では、テストソースを変更していなくても Maven の増分コンパイルが古いバイトコードを再利用しうる**（§2.7 の枠）。**症状は `NoSuchMethodError` である。** **`void` → `int` でも `int` → `void` でも同じであり、本ステップは両方向を経験した。** 対象テストソースを `touch` するか `mvn clean` を挟むこと。**A-3 も `SuggestCreator` のシグネチャを触る可能性が高く、A-6 は既存テストを再コンパイルさせる必要がある** | **A-3 / A-6**（および以降の実装ステップ全般） |
| **5** | **【X-6】管理画面の挙動は変わらないため、リリースノートへの記載は不要である** [確認]。**第 12 版の実装が申し送っていた「管理画面 3 経路で例外がスキップに変わることをリリースノートに書く」は撤回された**（`0009` §11 の 4 は無効）。**ただし `0010` §7 の 2（不正行を直すまでサジェストの世代が更新されなくなる）は運用者へ周知すること** [提案]。**また「1 件の不正行があると管理画面から elevate word を編集できない」という現状は解消されていない**（`0010` §7 の 1。本来の解は入口側バリデーション = `0003` §13 の 8） | **フェーズ A のリリース作業** |
| **6** | **`ForRebuild` の「`SuggestCreator` のみが呼ぶ」制約は Javadoc でしか表明できない** [確認]（別パッケージのため package-private にできない）。**本書執筆時の grep では呼び出し元は `:257` / `:261` の 2 箇所のみであった**（§2.7）が、**将来これが管理画面から呼ばれると規則 6 が事実上復活する。** **A-6 の検査項目 4 はこの回帰を検知できないため、呼び出し元が 1 ファイルであることを別途 grep で確認する検査を足すこと** [提案]（`0010` §7 の 7 ／ §8 の 7 ／ プラン A-6 の作業内容 2 の末尾） | **A-6 / F-5** |
| **7** | **行番号は書き直しで大きく移動した**（例: `addElevateWord` は `0008` §4.1 の `:509` から `:539` へ、`storeAllBadWords` は `:567` から `:717` へ）。**`(fess) exec/SuggestCreator.java` も `create()` 内の行が 3 行下へずれている**（`switchIndex()` が `:298` → `:301` ほか — §3 の引き継ぎ表の 5）。**`0007` §1、`0008` §4.1、`0003` 第 13 版 §10.4 (e) の規則 1・(j)、プラン §4 ステップ A-2 / A-3 の行番号は、本節 §2.2 の表と §3 の引き継ぎ表が上書きする。** 以降のステップは**その都度現物で確認すること**（§1.11 の 5 と同旨） | **A-3〜A-6** |
| **8** | **「設計どおり実装すると DoD が満たせない」を発見したときの判断規律** [提案]: **DoD を緩める向きの改訂を選んでよいのは、DoD 自体が実装不能な要求だった場合に限る。** X-5 はその確認を経ずに DoD を「1 以上」へ緩め、X-6 がそれを差し戻した（`0010` §2.4 / §8 の 5）。**A-3 以降でも同種の判断が起こりうる** | **フェーズ A 以降の全ステップ** |
| **9** | **【2 回目のレビュー指摘 3】`ForRebuild` の戻り値（失敗した行数）を必ず G3 の `exitCode` 判定へ接続すること** [確認]。**現状は `(fess) exec/SuggestCreator.java:257` / `:261` が式文であり戻り値を捨てている**ため、**不正行を skip したまま `:301` の `switchIndex()` が走る。** **したがって A-2 の変更だけを本番リリースしてはならない** — **フェーズ A は A-6 まで完了してから先行リリースする**（`0001-work-plan.md:610` ／ 本書 §7 ／ `0010` §7 の 6・§13.4）。**レビュアーはこれを実装バグではなく「A-2 / A-3 がセットである」ことの帰結として指摘している** | **A-3**（作業内容 5）／ **フェーズ A のリリース判断** |
| **10** | **[提案] Javadoc に呼び出し元クラス名を列挙する記述は実物と乖離しやすい** [確認]。2 回目のレビューの指摘 2 (b) は、`storeAllElevateWords` / `storeAllBadWords` の Javadoc が**同期経路と非同期経路を区別せずに「validation error になる」と一般化していた**ことを突いたものである。**是正後も呼び出し元が増減すれば再び古くなる。** **F-5 で Javadoc が挙げる 4 クラス（`AdminElevatewordAction` / `ApiAdminElevatewordAction` / `AdminBadwordAction` / `ApiAdminBadwordAction`）の実在と同期／非同期の別を grep で確認すること**（`0010` §13.8 の 4） | **F-5** |

---

## 3. ステップ A-3: 切替可否ガード G1 / G3 の設置（MO-2 / MO-18）

**未着手。** 作業内容・DoD・注意点はプラン §4 ステップ A-3 を参照。**依存: A-2（完了 — §2）。**

> **A-2 から引き継ぐもの**（**X-6 で形が変わった。第 12 版に基づく旧記述は撤回済みである**）[確認]:
>
> | # | 引き継ぐもの |
> | --- | --- |
> | **1** | **`(fess) exec/SuggestCreator.java` の呼び先は既に `ForRebuild` に切り替わっている** — `:257` `storeAllBadWordsForRebuild()` ／ `:261` `storeAllElevateWordsForRebuild()`（§2.2 / §2.3 の 8）。**プランと `0003` 第 13 版 §10.4 (j) が書く `:255` / `:258` は変更前の行番号である。** |
> | **2** | **両メソッドは失敗した行数（行 ID で dedupe 済み）を `int` で返すが、現在は戻り値が捨てられている** [確認]。**本ステップに残っているのは、その戻り値を受けて `exitCode` へ合流させることだけである**（作業内容 5）。コード側にも `:256` に「folding it into exitCode is done by A-3」と明記してある |
> | **3** | **受け渡し形（戻り値 `int`）は `0010` で確定済みであり、本ステップで再検討しない**（`0009` §11 の 2 はこれで閉じた）。**この数は「失敗した行の数」であって「項目処理数」ではない** — 第 12 版の記述を参照しないこと |
> | **4** | **public 3 メソッド（`storeAllElevateWords(boolean)` ほか）を呼んではならない** [確認]。**それらは `void` の fail-fast に戻されており失敗件数を返さない**（MO-25 の規則 6 ／ §2.3 の 6） |
> | **5** | **プラン A-3 が引く `(fess) exec/SuggestCreator.java` の行番号は、A-2 が足したコメント 3 行分だけ下へずれている** [確認]。**現物との対応は次のとおり**: `create()` = **`:243-307`**（プランの記載は `:243-304`）／ `createNextIndex()` = **`:252`**（不変。コメント挿入より上）／ G3 の設置位置「`:295` の直後・`:297` の直前」 = **`:298` の直後・`:300` の直前** ／ `switchIndex()` = **`:301`**（プランは `:298`）／ `removeDisableIndices()` = **`:304`**（プランは `:301`）／ `return exitCode.get()` = **`:306`**。**着手時に必ず現物で確認すること** |
>
> **注意**: **本ステップも `SuggestCreator` のシグネチャや戻り値を触る可能性が高い。** **増分コンパイルが古いテストバイトコードを再利用しうる**ため `touch` か `mvn clean` を挟むこと（§2.11 の 4）。

---

## 4. ステップ A-4: `(fess res) suggest_indices/` の `number_of_replicas` 削除（3 ファイル・U-2 の決定）

**未着手。** 作業内容・DoD・注意点はプラン §4 ステップ A-4 を参照。**A-1〜A-3 と並行可。**

---

## 5. ~~ステップ A-5: `.prev` 付与の暫定実装（M-6・U-7 の決定）~~ — **【2026-08-31 削除】**

**削除した。着手前であり、実装・手順書・撤去箇所一覧のいずれも存在しない。**

| 項目 | 内容 |
| --- | --- |
| **削除の理由** | 本ステップは **L1 期間（新 fess-suggest ＋ 旧 fess 本体）に実際のメジャー移行が走るのに切り替え後の戻り先が無い**という問題への暫定対処だった。**要件定義 `0000` 第 2 版 §2 の R-P1（fess 本体と fess-suggest は常に同時更新）により、その区間が消滅した** |
| **決定者・決定日** | ユーザー ／ **2026-08-31**（U-8） |
| **記録** | `0011-requirements-revision-release-model.md` ／ プラン §4 の A-5 削除ブロック ／ `0003` 第 14 版 §10.6 |
| **`.prev` はどうなるか** | **捨てていない。** R1 では**正式 primitive**（`switchIndexRetainingPrevious()` / `rollbackToPrevious()` / `aliasState()`）を最初から使う。実装はプラン **ステップ D-2**（fess-suggest 側）にあり、削除していない |
| **本ステップに紐づいていた成果物** | **ロールバック手順書（R1〜R3 の暫定版）と L2 での撤去箇所一覧は作らない。** 正式なロールバック手順は `0003` §5.3 が既に定めている |
| **A-6 への影響** | **A-6 の作業内容 7（`.prev` の検証 4 項目）を削除した。** A-6 の依存から A-5 を外した（依存は A-1 / A-2 / A-3 / A-4） |

## 6. ステップ A-6: 先行リリース分のテスト

**未着手。** 作業内容・DoD・注意点はプラン §4 ステップ A-6 を参照。**依存: A-1 / A-2 / A-3 / A-4**（**A-5 は削除済み。作業内容 7 の `.prev` 検証も削除**）**。**

**本ステップで閉じる持ち越し事項**:

| 出所 | 内容 |
| --- | --- |
| 本書 §1.9 の DoD 5 | **A-1 の DoD「T-F3 が緑」** |
| 本書 §1.11 の 1 | **MO-24 の検証 4 点（①〜④）**（プラン §8 の DoD 15） |
| 本書 §1.11 の 2 | **既存テストの握り潰し構造への対処**（そのまま流用しない） |
| 本書 §2.9 の DoD 10 | **A-2 の DoD「A-6 で追加するテストが緑」** |
| 本書 §2.11 の 2 | **【X-6 で 3 点 → 4 点に改訂】MO-25 の検証 4 点**（プラン §8 の DoD 16 ／ プラン A-6 の作業内容 2 ／ `0003` 第 13 版 §10.4 (g) ／ `0010` §5 の I/O 契約）:<br>①`getSuggestWord()` が `null` を返す行を 1 件含む入力で **再構築経路の削除フェーズが `getSuggestWord()==null` で止まらない**こと<br>②同じ入力で **`storeAllElevateWordsForRebuild()` が完走し、失敗件数が 1（等値）**であること<br>③`getBoost()` が `null` の行で **追加フェーズが止まらず、失敗件数が 1（等値）**であること<br>④**`storeAllElevateWords(false)` / `deleteAllElevateWord(false)` / `storeAllBadWords(false)` の public 3 メソッドが、同じ不正行に対して従来どおり例外を伝播する**こと（**回帰防止**。これが無いと次の実装で隔離が public 側へ再び漏れる） |
| 本書 §2.11 の 3 | **【X-6 で撤回・差し戻し】失敗件数は「1 以上」ではなく「1」（等値）で検査する。** 行 ID で dedupe しているため 1 件の不正行は両フェーズで落ちても 1 件である。**`assertTrue(failures >= 1)` は 2 も 3 も通すため、二重計上の回帰を検知できない**（`0010` §2.4）。**第 12 版までの記述（`0009` §11 の 3 ／ プラン §9.2 の第 12 版改訂注記）を参照しないこと** |
| 本書 §2.11 の 4 | **戻り値型を変えた後のテスト再実行で増分コンパイルが古いバイトコードを再利用しうる**（`NoSuchMethodError`。`touch` か `clean` が要る）。**`void` → `int` でも `int` → `void` でも同じであり、A-2 は両方向を経験した** |
| 本書 §2.11 の 6 | **`ForRebuild` の呼び出し元が `(fess) exec/SuggestCreator.java` 1 ファイルだけであることを grep で確認する検査を足す** [提案]（Javadoc でしか表明できない制約であるため） |

---

## 7. フェーズ A 全体の状況

| プラン §8 の DoD | 関係する項目 | 現状 |
| --- | --- | --- |
| **11** | **【2026-08-31 改訂】フェーズ A の全 5 ステップ（A-1 / A-2 / A-3 / A-4 / A-6）が完了し、R0 をリリースできる。** **「回復（暫定 `.prev`・A-5）」の条件は撤回した**（A-5 の削除に伴う。回復手段は R1 で正式 primitive として入る） | **未充足**（**A-1 / A-2 が完了**。**A-3 / A-4 / A-6 が未着手のため、現時点で R0 をリリースしてはならない**） |
| **15** | **MO-24 が実装され、A-6 で検証されている** | **実装は完了**（§1.4・§1.9 の DoD 3・4）。**検証は A-6 待ち**（§1.9 の DoD 5） |
| **16** | **【X-6 で全面改訂】MO-25（全件再投入系メソッドの失敗隔離）が実装され、A-6 で検証されている** — ①**再構築経路の**削除フェーズと追加フェーズの両方にスキップ機構 ②**失敗した行の数（行 ID で dedupe した 1 つの数）を `ForRebuild` の戻り値で返し、インスタンスフィールドに持たない**（件数用フィールドも dedupe 用 `Set` も） ③`deleteAllBadWords()` には入れない ④**public 3 メソッドの挙動が A-2 着手前と完全に同一**（呼び出し元 11 箇所が無変更） ⑤**`SuggestCreator` の変更が 2 行に限られ、`ForRebuild` の呼び出し元がその 1 ファイルだけ** | **実装は完了**（§2.3・§2.4・§2.9 の DoD 1〜6・8・9）。**⑤の grep は本書執筆時に実施済み**（§2.7）。**検証は A-6 待ち**（§2.9 の DoD 10）。**`exitCode` への合流は A-3 待ち**（§2.9 の DoD 7 ／ §2.11 の 9 ＝ 2 回目のレビュー指摘 3） |
| **9** | 7 ファイルすべてから `number_of_replicas` が消えている（fess 本体側 3 = A-4） | **未着手**（§4） |
| **10** | 逸脱手続き **6 件（X-1 / X-2 / X-3 / X-4 / X-5 / X-6）**がすべて改訂 → 記録 → 実装の順 | **X-4（§1.6）と X-5 / X-6（§2.6）について順序を確認した。** **X-6 では「改訂（`0003` 第 13 版）→ 記録（`0010`）→ 実装の書き直し」の順序が守られている** [確認]（§2.6 の手続き表）。**A-2 の 2 回目のレビュー（Approve）では新たな逸脱は発火していない** — **設計判断が動かず設計書の改訂が不要だったため、発火は 6 件のままである**（`0010` §13.5 ／ §2.6 の手続き表の 7）[確認] |

> **リリース順序の制約は不変である** [確定]（**呼称のみ変わった**）。**R0 のリリースは R1 リリースより先でなければならない**（プラン §5.5 ／ `0003` §10.3 の同一リリース制約）。**A-1 だけを単独でリリースしてはならない** — MO-24 は「同一リリース制約」の 4 項目目として `0003` `:865` に置かれており、**追加経路と削除経路の変更は同時に入る必要がある**（本書 §1.4 で両方入れてある）が、**G1 / G3 ガード（A-3）が無い状態では切替可否の判定が働かない**（**【2026-08-31】「暫定 `.prev`（A-5）が無い＝回復手段が無い」という論点は撤回した** — A-5 の削除に伴う）。

> **A-2 だけを単独でリリースしても切替は止まらない** [確認]。**失敗件数を返し、`SuggestCreator` から `ForRebuild` を呼ぶところまでが A-2 であり、`exitCode` へ合流させて G3 に渡すのは A-3 の作業内容 5 である**（本書 §2.9 の DoD 7 ／ `0010` §7 の 6）。**現時点では `(fess) exec/SuggestCreator.java:257` / `:261` が戻り値を捨てている。**
>
> **ただし A-2 の完了時点で「SuggestJob の全件再構築が 1 件の不正行で止まらない」ことは既に達成されている** [確認]。**`ForRebuild` が dead code のまま残っていないため**（`0003` 第 13 版 §10.4 (j) の理由 1 ／ 本書 §2.9 の枠）、**A-3 で加わるのは「止まらなかった結果を切替可否の判断に反映する」ことである。**

> **【X-6】管理画面／API の挙動は A-2 で変わっていない** [確認]。**第 12 版に基づく一度目の実装は管理画面 3 経路の挙動を変えており「リリースノートに書く」と申し送っていたが、X-6 でその変更ごと撤回された**（本書 §2.6 の比較表 ／ §2.11 の 5 ／ `0009` §11 の 4 は無効）。**フェーズ A のリリースノートに語管理経路の挙動変更を書く必要は無い。**
