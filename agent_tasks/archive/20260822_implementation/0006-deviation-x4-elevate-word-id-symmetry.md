# 0006: 逸脱 X-4 — elevate word の追加経路と削除経路の ID 対称性（区分 I）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ A」**ステップ A-1** の**実装中に発火した**逸脱の記録である（同 §9.1 の注記「実装中に新たな逸脱が発生した場合は、その時点の最大番号 +1 で独立ファイルを作る。フェーズのファイルに混ぜない」に従う）。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[確定]** = 決定済み ／ **[要確認]** = 未解消
>
> **パス短縮表記**: `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` ／ `(sug res)` = `modules/fess-suggest/src/main/resources/` ／ `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/`

| 項目 | 値 |
| --- | --- |
| 実施日 | 2026-08-31 |
| 対象ステップ | **A-1**（**実装中に発火**） |
| 逸脱区分 | **区分 I（設計判断の誤り・不足）** — プラン §2.1 ／ 判定理由は本書 §3 |
| 改訂した設計書 | `docs/0003-migration-ops-design.md` — **第 9 版 → 第 10 版** |
| 採番した決定 | **MO-24**（改訂前の最大は MO-23） |
| コード変更 | **なし**（逸脱手続きは「改訂を先に行う」ことを要求する。**A-1 の実装は本書の完了後に再開する**） |

**結果: 設計書の改訂が完了した。ステップ A-1 の実装（削除経路を含む最終形）に着手してよい。**

---

## 1. 発見の経緯

**ステップ A-1 の作業内容 2（`word` 側も trim・正規化して `ElevateWord` に渡す）を実装した後の検証で発見した。**

| 項目 | 状態 |
| --- | --- |
| **A-1 の add 側実装** | **適用済み・未コミット** [確認]。`modules/fess` の作業ツリーに `helper/SuggestHelper.java` の 1 ファイル分の未コミット変更がある（`git status --short` = `M src/main/java/org/codelibs/fess/helper/SuggestHelper.java`）。内容は「区切り文字の衛生化（全角空白 → 半角・連続空白の畳み込み・前後 trim・空トークン除去）を `word` と `readings` の両方に適用する」 |
| **`modules/fess-suggest`** | **無変更** [確認]（`git status --short` = 空） |
| **本書の作業でのコード変更** | **なし。** `modules/` 配下には一切触れていない |

**A-1 の作業内容 2 は `0003` §10.3 の 3（INV-2 を fess 側の入力段階でも満たす）を実現するものであり、設計どおりである。** **問題は、その正規化が同時にドキュメント `_id` の変更でもあることを設計書が扱っていなかった点にある。**

---

## 2. 事象 — 追加経路と削除経路で `_id` が食い違う

> **A-1 の作業内容 2 を入れると、elevate word の追加経路と削除経路でドキュメント `_id` が食い違う。**
> **`0003` §10.3（第 9 版）は入力側（INV-2 の担保）だけを見ており、語テキストが削除経路と共有される ID キーでもあることを扱っていない。**

### 2.1 根拠 [確認]

**すべて実物を開いて確認した。行番号は下記のとおりであり、プラン外で報告されていた値との差分は §8 に記録する。**

#### (1) ドキュメント `_id` は語テキストから決まる

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 1a | `text` は語配列を `TEXT_SEPARATOR`（**半角空白**。`(sug) constants/SuggestConstants.java:37`）で結合したものである | `(sug) entity/SuggestItem.java:116` — `this.text = String.join(SuggestConstants.TEXT_SEPARATOR, text);` |
| 1b | `_id` はその `text` から生成される | `(sug) entity/SuggestItem.java:140` — `id = SuggestUtil.createSuggestTextId(this.text);` |
| 1c | `createSuggestTextId` は **Base64(text の UTF-8 バイト列)** であり、`ID_MAX_LENGTH = 445` で切り詰める。**テキストが 1 文字でも違えば別 `_id` になる** | `(sug) util/SuggestUtil.java:91-97`（`:73` が `Base64.getEncoder()`、`:75` が `ID_MAX_LENGTH = 445`） |

#### (2) 追加経路と削除経路はいずれも `normalizer.normalize(...)` を通してから ID を作る

| 経路 | 流れ | `file_path:line` |
| --- | --- | --- |
| **追加** | `normalize(elevateWord.getElevateWord(), "")` → `new ElevateWord(normalizedWord, ...)` → `normalized.toSuggestItem()` → index | `(sug) index/operations/WordManagementOperations.java:104` / `:107` / `:111`（`toSuggestItem` の実体は `(sug) entity/ElevateWord.java:143-149`） |
| **削除** | `final String normalized = normalizer.normalize(elevateWord, "");` → `settings.elevateWord().delete(normalized)` ＋ `deletionOps.delete(index, SuggestUtil.createSuggestTextId(normalized))` | `(sug) index/operations/WordManagementOperations.java:126` / `:127` / `:129` |

**両者は同じ `normalize` を通すが、そこへ渡される入力が同じでなければ `_id` は一致しない。**

#### (3) その `normalize` は前後空白を落とさず、全角空白も半角化しない

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 3a | 既定の正規化チェーンは **`AnalyzerNormalizer` の 1 段のみ**である。`HankakuKanaToZenkakuKana` / `FullWidthToHalfWidthAlphabetNormalizer` / `ICUNormalizer` は**コメントアウトされている** | `(sug) util/SuggestUtil.java:278-285`（`createDefaultNormalizer`） |
| 3b | `AnalyzerNormalizer` は OpenSearch の `normalize_analyzer` に掛け、**先頭トークンの term をそのまま返す** | `(sug) normalizer/AnalyzerNormalizer.java:100-116`（`:116` が `return termTokenList.get(0).getTerm();`） |
| 3c | `normalize_analyzer` は **`keyword` トークナイザ ＋ `mapping_char` ＋ `lowercase`** である。**`keyword` トークナイザは入力全体を 1 トークンにするため、前後空白も語中の全角空白もそのまま残る** | `(fess res) suggest_indices/suggest_analyzer.json:31-36` ／ `(sug res) suggest_indices/suggest_analyzer.json:30-35`（**両者の `normalize_analyzer` 定義は同一** [確認]） |
| 3d | `mapping_char` の **142 マッピング**に**全角空白（U+3000）の項目は無い**。マッピングは半角カナ → 全角カナ、全角英数 → 半角英数のみである | `(fess res) suggest_indices/suggest_analyzer.json:1273-1285` ／ `(sug res) suggest_indices/suggest_analyzer.json:1283-1295`。**両モジュールで `mappings` 配列は完全一致（142 件・U+3000 は 0 件）であることを JSON パースで機械的に確認した** [確認] |

> **注意**: `suggest_analyzer.json` は**ファイル全体としては両モジュールで同一ではない** [確認]（fess 本体側は `fess_japanese_tokenizer` / `fess_korean_tokenizer` を使い、fess-suggest 側は `reloadable_kuromoji_tokenizer` / `standard` を使う。他にも差分がある）。**同一なのは `normalize_analyzer` の定義と `mapping_char` の `mappings` 配列である。** この 2 つが本件の根拠であり、そこは一致している。

#### (4) fess 本体の削除経路は生の DB 値を渡している

| # | 事実 | `file_path:line`（**A-1 適用前の HEAD 基準**） |
| --- | --- | --- |
| 4a | `deleteAllElevateWord`（`:431`）が `elevateWord.getSuggestWord()` を**生**のまま渡す | `(fess) helper/SuggestHelper.java:438` — `suggester.indexer().deleteElevateWord(elevateWord.getSuggestWord(), apply);` |
| 4b | `deleteElevateWord`（`:449`）が引数の `word` を**生**のまま渡す | `(fess) helper/SuggestHelper.java:450` — `suggester.indexer().deleteElevateWord(word, apply);` |
| 4c | **A-1 変更前は追加経路も生の `word` を渡していた**ため、両者の `_id` は一致していた | `(fess) helper/SuggestHelper.java:483`（HEAD） — `.addElevateWord(new org.codelibs.fess.suggest.entity.ElevateWord(word, boost, Arrays.asList(readings), ...)` |

### 2.2 帰結 — A-1 をそのまま入れた場合の障害 [確認]

**`"東京　タワー"`（全角空白）／`" test"`（前後空白）／`"a  b"`（連続空白）のように、正規化で文字列が変わる語について次が起きる。**

| # | 障害 | 経路 |
| --- | --- | --- |
| **1** | **管理画面から elevate word を削除しても suggest ドキュメントが残る。削除後も引き上げが効き続ける** | `(fess) app/web/admin/elevateword/AdminElevatewordAction.java:409` ／ `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:206` → `deleteElevateWord`（生キー）→ `(sug) index/operations/WordManagementOperations.java:129` が**存在しない `_id`** を削除する。**追加時に書いた正規化キーの文書は残る** |
| **2** | **再構築のたびに孤児ドキュメントが残る** | `storeAllElevateWords`（`(fess) helper/SuggestHelper.java:411`）は冒頭で `deleteAllElevateWord`（`:412`。生キー）を呼ぶが、**追加は正規化キーで書く**（`:420-421` → `addElevateWord`）。**旧世代由来の生キー文書が消えずに蓄積する** |
| **3** | **設定側の elevate word エントリも消え残る** | `settings.elevateWord().delete(normalized)`（`(sug) index/operations/WordManagementOperations.java:127`）も同じキーで動く。設定エントリの ID は語テキストから作られる（`(sug) settings/ElevateWordSettings.java:162-167` → `(sug) settings/ArraySettings.java:169-174` → `:192-193` の `createId` が `Base64("key:" + key + "value:" + value)`）。**残ったエントリは `restoreElevateWord`（`(sug) index/operations/WordManagementOperations.java:140-156`）の入力になる** |

> **障害 1 が最も重い。** **「削除したのに引き上げが効き続ける」は、運用者から見て挙動が壊れているとしか見えない。** 障害 2・3 はディスク／設定の汚染であり、影響は緩やかである。

---

## 3. 区分 I と判定した理由

| # | 理由 |
| --- | --- |
| **1** | **設計書どうしの矛盾ではなく、`0003` §10.3 の「不足」である。** 同節は「fess 側は区切り文字の衛生だけを担う」と定めた際、**その衛生化が同時に ID キーの変更でもある**という副作用を扱っていない。**設計どおりに実装すると成立しない**という区分 I の判定基準に当たる |
| **2** | **プラン §2.1 の「判定に迷ったら区分 I として扱う。区分 II は『設計の内容が変わらないこと』を積極的に示せる場合に限る」に合致する。** 本件は設計の内容（同一リリース制約の対象範囲）が変わるため、区分 II ではありえない |
| **3** | **観測値の訂正だけでは閉じない。** §8 に記録した行番号の差分（区分 II 相当）は本件の付随物であって本体ではない |

> **`0003` §10.3 が持っていた誤りは 1 つではない。** 第 9 版の同節は「管理画面の create / update / **delete** / CSV アップロード、API の POST / PUT / **DELETE** / upload …のすべてが `addElevateWord(...)`（`:464`）を通る」と書いていたが、**delete / DELETE についてこれは成立しない** [確認]。この誤りが、**削除経路が別のキーを使いうるという可能性を視野から外していた構造的原因である。**

---

## 4. 検討した代替案と採否

| # | 案 | 判定 | 理由 |
| --- | --- | --- | --- |
| **(a)** | **削除経路も同じ正規化を通し、正規化前後で語が変わる場合は新旧両キーで削除する** | **採用**（ユーザー決定・2026-08-31） | **ID の対称性を回復し、かつ既に生キーで投入済みのドキュメントも掃除できる。** 対象は `(fess) helper/SuggestHelper.java` の 3 メソッドに閉じ、fess-suggest 側を触らない。**フェーズ A の「先行リリースできる安全網」の範囲に収まる** |
| **(b)** | A-1 の作業内容 2（`word` の正規化）を撤回し、`readings` だけ正規化する | **不採用** | **ID 対称性は保たれるが、INV-2 を `text` 側で担保できず `0003` §10.3 の 3 の目的が半分残る。** さらに **L1 で `SuggestItem` コンストラクタが INV-2 を強制した時点で、全角空白入りの elevate word が実行時エラーになる**（`0002` INV-2 / §5.2）。**問題を A-1 から C-2 へ先送りするだけである** |
| **(c)** | DB 保存時（`AdminElevatewordAction` / `ApiAdminElevatewordAction` / CSV アップロード）に `suggest_word` 自体を正規化する | **不採用** | **根本的だが対象ファイルが増え、既存 DB データの移行も要る。** `AdminElevatewordAction.java` / `ApiAdminElevatewordAction.java` / `ElevateWordService.importCsv` の 3 系統に手が入り、加えて既存行の一括正規化という**データ移行タスク**が発生する。**フェーズ A の「fess 本体側の安全網を先行リリースする」という範囲を超える** |

> **(c) を将来の選択肢として捨てていない。** **(a) は「正規化キーを正とし、生キーを掃除しながら収束させる」方式であり、(c) は「DB を正規化キーで揃える」方式である。** (a) を入れた後で (c) を行っても矛盾しない（(c) 実施後は正規化前後で語が変わらなくなるため、(a) の両キー削除が自然に 1 回に縮退する）。**L2 以降で検討する候補として §10 に申し送る。**

---

## 5. `0003` 第 10 版の改訂内容

**改訂したのは `docs/0003-migration-ops-design.md` の 1 本のみである**（`docs/0002-datamodel-design.md` は無変更 — 理由は §9）。

| # | 箇所 | 内容 |
| --- | --- | --- |
| 1 | **冒頭「現在の版」**（`:3`） | 第 9 版（2026-08-25）→ **第 10 版（2026-08-31）** |
| 2 | **冒頭宣言**（`:14`） | **「第 10 版で解消する設計上の不足（逸脱 X-4・区分 I）」の 1 行を追加**（第 9 版の同種の行の直後・同じ書式） |
| 3 | **改訂履歴**（`:29`） | **第 10 版の行を追加。** 「作業履歴」列は `20260822_implementation/0006` |
| 4 | **§0 の決定表**（`:63`） | **MO-24 の行を追加**（節参照は §10.3 / §10.3.1） |
| 5 | **§10.3 の冒頭ブロック** | **同一リリース制約を「3 つ」から「4 つ」へ拡張。** 4 として「削除経路（`:431` / `:449`）も 3 と同じ正規化を通すこと（MO-24）」を追加し、**4 が 3 の副作用への手当てである**ことを注記 |
| 6 | **§10.3 の末尾段落** | **「create / update / delete / CSV アップロード、API の POST / PUT / DELETE / upload のすべてが `addElevateWord(...)` を通る」から delete / DELETE を除去し、訂正の注記を追加。** **「INV-1 強制の影響範囲が `addElevateWord` に閉じる」という結論自体は変えていない** |
| 7 | **§10.3.1 を新設** | **MO-24 の本体。** (a) 何が足りなかったか ／ (b) 根拠（本書 §2.1 の 4 群）／ (c) 帰結（本書 §2.2 の 3 件）／ (d) 規則 4 項 ／ **(e) 一般則「語テキストは入力であると同時に `_id` キーでもある」** ／ (f) 検証の所在 |

**変更していないもの** [確認]: **MO-1〜MO-23 は無変更。** **`0002` の DM 番号・INV 番号・mapping・§11 のテスト仕様（T 番号）はいずれも無変更である。** MO-24 の検証は**新しい T 番号を起こさず**、`0003` §11.3 の **T-F3** の範囲に含めてプラン A-6 で実施する（§10 の申し送り 1）。

### 5.1 作業プラン `0001-work-plan.md` への反映

| # | 箇所 | 内容 |
| --- | --- | --- |
| 1 | **§2.2** | 見出しを「発火 3 件」→「**発火 4 件**」に改め、**X-4 の行を追加**（区分 I ／ ステップは **A-1（実装中に発火）**）。**本プラン作成時点の 3 件と実装中発火の 1 件を区別する 1 文**を表の前に追加 |
| 2 | **ステップ A-1** | 「対象」に `deleteElevateWord`（`:449-452`）と `deleteAllElevateWord`（`:431-441`）を追加 ／ 「設計書の対応」に `0003` §10.3 の 4（**MO-24**）を追加 ／ **作業内容 5 を新設**（削除経路 2 メソッドにも同じ正規化 ＋ 両キー削除）／ **DoD に 2 項目を追加**（add と delete が同じキーを使うこと・両キー削除が入っていること）／ **注意点/リスクに 3 項目を追加**（delete は `addElevateWord` を通らないことの訂正・語テキストが `_id` キーでもあること・残存リスク）／ 冒頭に X-4 発火の注記 |
| 2b | **ステップ A-6** | **作業内容 1（T-F3 相当）に MO-24 の検証 4 点を追加**（add と delete が同じキーを使うこと ／ 語が変わる場合に生キー側の削除も発行されること ／ 変わらない場合は 1 回だけであること ／ `deleteAllElevateWord` も同じ 3 点）。**新しい T 番号は起こしていない**（`0003` §11.3 の T-F3 の範囲に含める）。**DoD にも 1 項目を追加** |
| 3 | **§8（本タスクの DoD）** | **DoD 15 を新設**（MO-24 が実装され A-6 で検証されること）／ **DoD 10 を「3 件（X-1 / X-2 / X-3）」→「4 件（＋ X-4）」に更新** |
| 4 | **§9.1（作業履歴ドキュメント）** | **0006 を本書に割り当て、既存の 0006〜0011（フェーズ A〜F）を 0007〜0012 へ繰り下げた。** 各行の内容記述は保った。但し書きに繰り下げの事実を追記 |
| 5 | **§9.2（設計書の改訂）** | **`docs/0003-migration-ops-design.md` を第 10 版へ改訂した行を追加**（ステップ欄は A-1、改訂内容は §10.3 への MO-24 追加） |
| 6 | **§11（自己検証）** | 項目 4 の MO 全件カバー表に **MO-24 → A-1** を追加 ／ 項目 8 に**実装中発火でも同じ手続きが機能した**ことを追記 |
| 7 | **ステップ A-5** | ロールバック手順書の置き先が `0005-*` という**繰り下げ前の古い番号**のままだったため、`0007-phase-a-fess-precede.md` に是正した（**区分 II 相当の軽微な訂正**） |
| 8 | **末尾の確定版ブロック** | **実装中発火の逸脱 X-4（2026-08-31）を反映した旨**を追記 |

### 5.2 作業履歴 `0005-review-response-phase0.md` への追記

**同書 §8 は「文書番号の繰り下げ」の記録である。** **本ステップでさらに 1 つ繰り下がった**（フェーズ A〜F が 0007〜0012）ため、**§8 の表の直後と §10 の申し送り 4 に【2026-08-31 追記】を入れた。** **表そのものは執筆時点の割当てとして残してある**（履歴を書き換えない）。

---

## 6. 残存リスク

> **[要確認] 両キー削除を入れても、掃除されないドキュメントが残る。**

| # | 残存リスク | 内容 |
| --- | --- | --- |
| **1** | **一度も触られない語は残る** | **A-1 を含むバイナリへ上げる前に生キーで投入済みのドキュメントは、その語が再度 add / delete されるまで掃除されない。** 両キー削除により削除・再構築の経路を通れば掃除されるが、**通らなければ残り続ける** |
| **2** | **DB から既に消えている語の孤児は残る** | 全件再構築（`storeAllElevateWords`。`(fess) helper/SuggestHelper.java:411`）は**冒頭で `deleteAllElevateWord`（`:412`）を呼び、DB の全行に対して両キー削除を回す**ため、**DB に行が残っている語については実質的に掃除される** [確認]。**しかし DB から既に削除された語のドキュメントは、削除対象を列挙する術が無いため残る**（`deleteAllElevateWord` は `ElevateWordBhv` の select 結果しか回らない — `:432-435`） |
| **3** | **リスク 2 の回復手段** | **`0003` §12.1（MO-23）の「除外語の物理削除」と同型の運用操作**（`deleteByCondition` 相当）でしか掃除できない。**本タスクでは手順を新設しない**（フェーズ A の範囲外）。**L2 以降の運用手順として §10 に申し送る** |

> **リスクの重みの評価** [提案]: **リスク 1・2 が顕在化するのは「正規化で文字列が変わる語」に限られる。** 全角空白・前後空白・連続空白を含む elevate word は**実運用では少数と考えられる**が、**件数の実測は行っていない**（本ワークスペースに実データが無いため）[要確認]。**残った孤児ドキュメントの実害は「削除したはずの語が引き上げられ続ける」であり、検索品質の問題としては目に見える。** リリース時に運用者へ周知することを推奨する [提案]。

---

## 7. 実装側が満たすべき仕様（次工程への引き渡し）

> **本書はコードを変更していない。** 以下は **A-1 の実装を再開する担当が満たすべき最終形**であり、`0003` 第 10 版 §10.3.1 (d) の規則を擬似コードに落としたものである。

**対象は `(fess) helper/SuggestHelper.java` の 3 メソッドに閉じる。fess-suggest 側は触らない。**

```text
// 共通（既に A-1 の add 側で導入済みの関数をそのまま共有する）
normalizeSeparators(text):
    return text.replace(U+3000, " ").replaceAll(" +", " ").trim()

// 1) addElevateWord（:464） — A-1 実装済み。変更なし
//    normalizeSeparators を word と readings の両方に適用し、空トークンを除去して
//    ElevateWord に渡す。k と W の突き合わせは行わない（0002 §5.4 は fess-suggest の責務）。

// 2) deleteElevateWord（:449）
deleteElevateWord(word, apply):
    normalized = normalizeSeparators(word)
    suggester.indexer().deleteElevateWord(normalized, apply)     // 正規化キー
    if (!normalized.equals(word)):                                // 変わったときだけ
        suggester.indexer().deleteElevateWord(word, apply)        // 生キー（移行期の掃除）
    refresh()

// 3) deleteAllElevateWord（:431）
deleteAllElevateWord(apply):
    for elevateWord in ElevateWordBhv.selectList(...):
        raw = elevateWord.getSuggestWord()
        normalized = normalizeSeparators(raw)
        suggester.indexer().deleteElevateWord(normalized, apply)
        if (!normalized.equals(raw)):
            suggester.indexer().deleteElevateWord(raw, apply)
    refresh()
```

| # | 実装上の要件 | 根拠 |
| --- | --- | --- |
| 1 | **正規化関数は add 側と共有する。** 追加側と削除側で別実装を持たない | `0003` §10.3.1 (d) の 1 |
| 2 | **正規化前後で語が変わらない場合は 1 回だけ削除する**（無駄な呼び出しを避ける） | 同 (d) の 2 |
| 3 | **2 回呼ぶことに副作用は無い** — 削除の実体は `prepareDelete` 1 回で、例外は `SuggestWriterResult` の failure として返り呼び出し元へ伝播しない（`(sug) index/writer/SuggestIndexWriter.java:83-91`）。**fess 側は戻り値を捨てている**（`(fess) helper/SuggestHelper.java:438` / `:450`）[確認]。**【2026-08-31 追記】本欄の根拠は不足していた** — `deleteElevateWord` は **suggest ドキュメントの削除と settings エントリの削除の 2 段操作**であり（`(sug) index/operations/WordManagementOperations.java:126-131`）、2 回目は空振り DELETE だけではなく別キーに対する settings 削除でもある。**結論（2 回呼んでよい）は変わらないが、根拠は `0003` 第 11 版 §10.3.1 (d) の 3 に差し替えた。経緯は `0008-review-response-a1.md` §2** | 同 (d) の 3 |
| 4 | **k と W の突き合わせは fess 側で行わない**（`0002` §5.4 の 4 分岐は fess-suggest 側の責務）。**この分担は MO-24 で変わらない** | 同 (d) の 4 ／ プラン A-1 の作業内容 4 |
| 5 | **両キー削除の理由をコメントに残す**（次の実装者が「冗長だ」と削らないように）[提案] | — |

---

## 8. 参照した行番号の実物確認（プランの記載との差分）

**本書の執筆にあたり、引用したすべての `file_path:line` を実物で開いて確認した。** **報告時点で共有されていた値と実物が食い違うものが 3 件あった。実物を優先した。**

| # | 対象 | 報告値 | **実物**（`modules/fess` の HEAD ＝ A-1 適用前） | 差分の性質 |
| --- | --- | --- | --- | --- |
| 1 | `deleteAllElevateWord` のメソッド宣言 | `:430` | **`:431`** | `:430` は javadoc の閉じ `*/`。**メソッド宣言は `:431`** |
| 2 | `deleteAllElevateWord` 内の生キー呼び出し | `:435` | **`:438`** | `:435` は `selectList` ラムダの閉じ `});`。**呼び出しは `:438`** |
| 3 | `deleteElevateWord` のメソッド宣言 | `:447` | **`:449`** | `:447` は javadoc の `@param word`。**メソッド宣言は `:449`**（生キー呼び出しは `:450`） |

**一致していたもの**: `addElevateWord`（`:464`）／ `storeAllElevateWords`（`:411`）／ `(sug) entity/SuggestItem.java:116` / `:140` ／ `(sug) util/SuggestUtil.java:91-97` / `:278-285` ／ `(sug) index/operations/WordManagementOperations.java:103-107` / `:126-129` ／ `(sug) normalizer/AnalyzerNormalizer.java:100-116` ／ `mapping_char` の 142 マッピングと U+3000 の不在。

> **`normalize_analyzer` の位置は報告値 `:30-35` だったが、これは `(sug res)` 側の行番号である** [確認]。**`(fess res)` 側は `:31-36`**（先頭の `index` ブロックの行数差による）。**設計書には両方を明記した。**

> **`0003` §10.6 の行番号（`(sug) Suggester.java:239` など）は本書の対象外であり、再確認も変更もしていない。**

---

## 9. スコープ外（変更していないもの）

| # | 対象 | 理由 |
| --- | --- | --- |
| 1 | **`modules/` 配下のすべてのコード・リソース** | **逸脱手続きは「改訂を先に行う」ことを要求する。** 実装は本書の完了後に別途行う。**A-1 の add 側の未コミット変更はそのまま残してある**（撤回していない — §4 の (b) を不採用としたため） |
| 2 | **`docs/0002-datamodel-design.md`** | **本件は `0002` の決定を変えない。** INV-1 / INV-2 / DM-8 / DM-16 のいずれも内容は不変であり、**変わったのは fess 本体側の同一リリース制約の範囲**（`0003` §10.3 の管轄）だけである |
| 3 | **`docs/0001-api-design.md` / `docs/0000-design-overview.md` / `docs/0004-corrections.md`** | 公開契約・凡例・訂正一覧のいずれにも影響しない |
| 4 | **`0003` §11 のテスト仕様（T 番号）** | **新しい T 番号を起こしていない。** MO-24 の検証は T-F3 の範囲に含め、閉じ方はプラン A-6 の DoD が指定する（プラン §13.3 の規律「[確定] を書いたら、それがどこで閉じるかを同時に指定する」に従う） |
| 5 | **`0003` MO-1〜MO-23 ／ §3・§4・§5・§7・§8 の手順** | 本件はエイリアス遷移・ガード・refresh・settings のいずれにも触れない |
| 6 | **`agent_docs/tasks/20260706_design_document/docs/` の 5 本** | **凍結スナップショットである**（プラン §2.3 / Q7=(A)）。一切変更していない |
| 7 | **DB 保存時の正規化（案 (c)）** | §4 のとおり不採用。**将来の選択肢としては捨てていない**（§10 の申し送り 3） |

---

## 10. 次ステップへの申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **A-6 のテストで両キー削除を検証すること。** ①`addElevateWord` と `deleteElevateWord` が**同じキー**を使うこと（正規化で変わる語で追加 → 削除し、ドキュメントが残らないこと）②**正規化前後で語が変わる場合に生キー側の削除も発行されること** ③変わらない場合は 1 回だけであること。**`0003` §11.3 の T-F3 の範囲に含める**（新しい T 番号は起こさない） | **ステップ A-6** |
| **2** | **`0003` §10.3.1 (e) の一般則「語テキストは入力であると同時に `_id` キーでもある」を C-1 の着手時に読むこと。** `createSuggestTextId` の SHA-256 化は、**追加経路・削除経路・`fromSource` の再計算の 3 箇所が同じ関数を共有していること**に乗っている（`0002` §4.4 の表 / DM-16）。**点検すべき経路の集合は MO-24 と同じである** | **ステップ C-1** |
| **3** | **DB 保存時の正規化（§4 の案 (c)）を L2 以降の候補として検討すること。** 実施すれば正規化前後で語が変わらなくなり、**MO-24 の両キー削除が自然に 1 回へ縮退する**。対象は `AdminElevatewordAction` / `ApiAdminElevatewordAction` / `ElevateWordService.importCsv` ＋ 既存 DB 行の一括正規化 | **L2 以降（本タスクのスコープ外）** |
| **4** | **§6 の残存リスク 2（DB から既に消えている語の孤児）に対する掃除手順が無い。** `0003` §12.1（MO-23）の「除外語の物理削除」と同型の運用操作が要る。**本タスクでは新設しない** | **L2 以降（本タスクのスコープ外）** |
| **5** | **`(fess res)` と `(sug res)` の `suggest_analyzer.json` は `normalize_analyzer` と `mapping_char` については同一だが、ファイル全体としては同一でない** [確認]（トークナイザが異なる）。**`0003` §8.4 のリソース遮蔽の議論を読む際にこの差を前提にすること** — **どちらが遮蔽されるかで正規化の挙動は変わらないが、他のアナライザの挙動は変わりうる** | **ステップ A-4 / C-3** |

---

## 11. 参照した一次情報

### 11.1 プロダクションコード / リソース

**すべて本ステップで実物を開いて確認した** [確認]。**個々の行番号は本文の各主張に付してあるため再掲しない。**

- **fess-suggest**: `(sug) entity/SuggestItem.java` ／ `entity/ElevateWord.java` ／ `util/SuggestUtil.java` ／ `constants/SuggestConstants.java` ／ `normalizer/AnalyzerNormalizer.java` ／ `index/SuggestIndexer.java` ／ `index/operations/WordManagementOperations.java` ／ `index/operations/DeletionOperations.java` ／ `index/writer/SuggestIndexWriter.java` ／ `settings/ElevateWordSettings.java` ／ `settings/ArraySettings.java` ／ `(sug res) suggest_indices/suggest_analyzer.json`
- **fess 本体**: `(fess) helper/SuggestHelper.java`（HEAD と作業ツリーの両方）／ `exec/SuggestCreator.java` ／ `app/web/admin/elevateword/AdminElevatewordAction.java` ／ `app/web/api/admin/elevateword/ApiAdminElevatewordAction.java` ／ `(fess res) suggest_indices/suggest_analyzer.json`

### 11.2 タスク内文書

| 文書 | 用途 |
| --- | --- |
| `0001-work-plan.md` | §2.1（逸脱手続きの区分）／ §2.2（逸脱一覧）／ **ステップ A-1**（作業内容 2 が発火点）／ ステップ A-6 ／ §9.1 の注記（実装中発火は独立ファイル）／ §13.3（閉じ方を同時に指定する規律） |
| `docs/0003-migration-ops-design.md` | **§10.3（改訂対象）** ／ §10.2 ／ §11.3 の T-F3 ／ §12.1（MO-23） |
| `docs/0002-datamodel-design.md` | INV-1 / INV-2（§1）／ §4.4（ID 生成の 3 箇所）／ §5.2 ／ §5.4（k ≠ W の 4 分岐）／ DM-8 / DM-16 |
| `0003-deviation-x3-l1-interim-state.md` | 本書の構成・凡例・証拠提示スタイルの雛形 |

### 11.3 未確認の外部仕様

| # | 事項 | 状態 |
| --- | --- | --- |
| 1 | **OpenSearch の Delete API が存在しないドキュメントに対して例外ではなく `result: not_found` を返すこと** | **[要確認]。** 一次情報（OpenSearch 公式ドキュメント）に到達できなかった。**ただし §7 の要件 3 に記したとおり、「2 回呼んでも副作用が無い」ことの根拠はコード側の 2 段（例外は握られる／戻り値は捨てられる）で閉じており、この外部仕様に依存しない** |
