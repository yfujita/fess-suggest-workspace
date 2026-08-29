# 0002 データモデル設計書

> 対象: fess-suggest 改善設計 ／ 実施日: 2026-08-13（初版） ／ 現在の版: **第 9 版**（2026-08-25）
> 凡例: `0000-design-overview.md` §3.1 に同じ
>
> **対象 MIG**: MIG-01（完全設計。**挙動の正は本書**）, MIG-02（完全設計）, MIG-04（`userBoost` の格納・合成規則）, MIG-13（完全設計。データモデル側）, MIG-17（完全設計。settings の To-Be） ／ MIG-15 第 1 段（マージ規則が multiGet 化で不変であることのみ） ／ MIG-16（`refresh_interval` の位置づけのみ。戦略は `0003`） ／ **ID-01（MIG 外・完全設計）**
> **消化する申し送り**: realtime get のためマージの正しさが refresh に非依存 → §4.5 ／ 頻度集約の回帰テスト仕様 → §7.2 ／ MIG-13 のレイテンシ計測（後続へ）→ §6.4 ／ 決定的 ID 再設計（P11）→ §4 ／ F-04・F-10 を既知の制約として明記（P12）→ §5.6 / §8 ／ `0001` 申し送り 2（bad word 判定の等価性テスト）→ §7.4 ／ `0001` 申し送り 4（`SuggestItemMergePolicy` の挙動）→ §5 ／ `0001` 申し送り 9・10（`text` の mapping 型と normalizer 不在）→ §2.4 ／ ステップ 4 申し送り 1（`ElevateWord` の読みセマンティクス — `0000` §5.3）→ §5.4 ／ 同 申し送り 2・3（決定 1・3 の本文化）→ §2 / §3 ／ 同 申し送り 4（同一再構築に載せる変更の束）→ §4.7
> **依存する [確定] 番号**: `0000` §5 の C-02, C-03, C-04, C-12, C-13, C-14 ／ `0000` §5.1 の P4, P5, P9, P10, P11, P12, P13, U1, U2, U3, U4, U5
> **消化する [確認] 事項**: F-01, F-02, F-04, F-05, F-06, F-10, F-12（`0000` §5.2）
> **第 5 版で消化する外部レビュー指摘（第 2 回）**: bad word の重複マッチ解除 → §5.3（DM-18） ／ `userBoost` の可換性 → §5.3（DM-19） ／ スレッド安全性契約との接続 → §8 の K-1
> **第 6 版で消化する外部レビュー指摘（第 3 回）**: bad word 操作の 2 段書き込みにおける部分適用と収束 → §5.3（DM-20） ／ 回帰テスト T-21 → §7.2
> **第 7 版で消化する外部レビュー指摘（第 4 回）**: bad word 該当語の取り込み時 drop を廃止し `excluded = true` で保存する → §5.3 / §6.5（**DM-21**） ／ K-2（`roles` の集合和）をリリース判断項目として明示 → §8 ／ 回帰テスト T-22・T-23 → §7.2
> **第 9 版で解消する設計上の不足（逸脱 X-3・区分 I）**: **本書はリリース段（L1 / L2）の存在を認識しておらず、「L1 バイナリ ＋ 旧世代インデックス」という中間実行状態を扱っていなかった** → **§5.2 に「W で回したが `reading_i` が存在しない」場合の扱いを定義**（穴 2） ／ §5.6 の前提の限定 ／ §6.1 の共存範囲を**読み取り経路**に限定（書き込み経路は `0003` §10.6 が扱う）

## 改訂履歴

| 版 | 日付 | 変更 | 作業履歴 |
| --- | --- | --- | --- |
| 初版 | 2026-08-13 | ステップ 5（5-1〜5-6）の執筆 | `20260706_design_document/0010` |
| **第 2 版** | 2026-08-13 | **DM-14 を「suggest 本体を読む全クエリ経路」に一般化した**（初版は `SuggestRequest` のみを定めており、`PopularWordsRequest` が未定義で bad word 登録済みの語が人気語に露出しうる欠落があった）。あわせて `previewBadWordImpact` の件数を定義（§6.2）、`userBoost` の「指定あり／なし」を実装判断から **`0001` の改訂事項**へ格上げ（§9 の 5）、INV-1 強制と `ElevateWord` 修正の**同一リリース制約**を明記（§5.2 / §9 の 7b） | `20260706_design_document/0011` |
| **第 3 版** | 2026-08-13 | **ステップ 7 の通し整合レビューによる改訂。** (1) **全置換（§5.6）が `SuggestItem` に `excluded` を要求することを明記**（`0001` 第 3 版の D-17 と対。レビューで検出した未申告の不整合）。(2) §9 の申し送り 5・8・9・10 を決着済みに更新。(3) 他文書への参照を作業プランのステップ番号から実節番号へ置換（`0001` §3.2 → §2.5、`0001` §2.2 → §3.7、`0003` §5 → §7、`0003` §6-1 → §3〜§6） | `20260706_design_document/0014` |
| **第 5 版** | 2026-08-17 | **外部レビュー（第 2 回）指摘の反映。** (1) **bad word の解除規則を「削除後の bad word 集合のいずれにも該当しない語だけを解除する」へ是正**（DM-18、§5.3。`0001` 第 5 版 D-25）。第 4 版までは部分一致で重複マッチする語（`foo` / `bar` / `foobar`）の解除が壊れていた。(2) **`userBoost` の合成規則が可換でないことを明記**し、`SuggestSource` が `userBoost` を指定しないことを本書側の要求として書いた（DM-19、§5.3。`0001` D-27）。(3) **K-1 を `0001` 第 5 版 D-26（スレッド安全性契約の限定）と接続**（§8）。(4) **§9 の申し送り 5 が第 3 版の記述のまま放置されていた誤りを是正**（第 4 版で D-16 が反転済み）。(5) テスト T-19 / T-20 を追加（§7.2） | `20260706_design_document/0016` |
| **第 4 版** | 2026-08-17 | **外部レビュー指摘の反映。** (1) **INV-5 を「数学的な単射」から「決定的導出＋実用上十分な衝突耐性」へ書き改め**、multiGet 後の衝突・ID 生成バグ検出を追加（DM-16、§1 / §4.4）。(2) **語数上限 N の切り捨てが頻度統計の意味を変える**ことを明記し、観測項目を追加（DM-17、§2.3(b)）。(3) **`0001` 第 4 版の 3 型分離（D-19）を本書の各節に反映**（§5.3 の合成表・§5.6 の全置換の前提）。(4) `userBoost` の「指定あり／なし」の表現を `SuggestCandidate.userBoost`（`OptionalDouble`）に更新（DM-11）。(5) テスト T-15〜T-18 を追加（§7.2） | `20260706_design_document/0015` |
| **第 6 版** | 2026-08-17 | **外部レビュー（第 3 回）指摘の反映。** (1) **DM-18 が定めた「`excluded == true` ⇔ 現在の bad word 集合のいずれかに該当する」が、bad word 操作の 2 段書き込み（設定インデックス → suggest インデックス）の途中失敗で一時的に破れることを明記**し、**同一操作の再実行により収束することを不変条件の成立条件として書いた**（DM-20、§5.3。`0001` 第 6 版 D-29）。(2) 収束の回帰テスト **T-21** を追加（§7.2）。**mapping・合成規則・ID 方式に変更は無い** | `20260706_design_document/0017` |
| **第 7 版** | 2026-08-17 | **外部レビュー（第 4 回）指摘の反映。** (1) **bad word に該当する新規候補を取り込み時に捨てる（drop）扱いを廃止し、`excluded = true` で保存する形にした**（DM-21、§5.3 / §6.5。`0001` 第 7 版 D-32）。第 6 版までは §6 の表 ② が取り込み時フィルタを「維持」としており、**C-02 の「即時・可逆な論理除外」が新規流入については成立していなかった**。**mapping は変わらない** — `excluded` は boolean のままであり、変わるのは「どのドキュメントが作られるか」と「新規語の初期値を誰が決めるか」である。(2) **`SuggestItemMergePolicy.initialize` が `excluded` を引数で受ける**ことを合成規則側の要求として明記（§5.3）。(3) **K-2（`roles` の集合和）を「後続スコープ」から「維持することをリリース時に明示的に判断する項目」へ格上げ**し、`SuggestSource` を公開拡張点にしたことによる混入経路の増加と、全件再構築が唯一の回復手段であることを追記（§8）。(4) 回帰テスト **T-22 / T-23** を追加（§7.2）。(5) `Kind` の Java 型が `api.SuggestKind` へ移ったことに伴う参照の更新（§2.5。**永続表現は変わらない**） | `20260706_design_document/0018` |
| **第 8 版** | 2026-08-22 | **設計書セットの閉包リファクタリング（設計内容の変更なし）。** (1) **本文から作業記録（`00XX-*.md`）への相対リンクを除去**し、前提はすべて番号参照（`0000` 経由で解決）に置き換えた。(2) **作業記録への参照を改訂履歴の「作業履歴」列と付録の 2 箇所に限定**し、表記を相対パスから「タスク名／文書番号」のテキスト（例: `20260706_design_document/0010`）に改めた（設計書を `docs/` 直下や `agent_docs/global/references/` へ移設してもリンク切れしない）。(3) **冒頭宣言の「消化する [確認] 事項」欄の参照先を `0000` §5.2 に変更**（F 番号のスナップショットが `0000` に新設されたため）。(4) **DM-2 / DM-4 / DM-7 の根拠欄と §2 / §3 / §5.4 の本文が参照していたステップ 4 の「決定 1〜4」を `0000` §5.3 経由の参照に変更**した（同節が `0000` に新設されたため）。実機検証を根拠とする記述は [確認] マーカーと `0000` §5.3 の参照に置き換え、検証の経緯は付録 B.3 に残した。**決定・番号体系・仕様・テスト仕様に変更は無い。** 規律は `0000` §3.5 | `20260706_design_document/0019` |
| **第 9 版** | 2026-08-25 | **逸脱 X-3（区分 I）の反映 — L1 期間の設計上の穴。** **L1 という中間実行状態を設計書が扱っていなかった。設計書は最終形と移行手順の中は精密だが、リリース段の間に置かれた実行状態の記述が欠けていた。** 本書は `L1` / `L2` の語を 1 つも持たず、リリース段の存在自体を認識していなかった。(1) **§5.2 に「W で回したが `reading_i` が存在しない」場合の扱いを [確定] として定義**した — **欠損スロットは空配列として復元し、例外にしない**（決定者: ユーザー ／ 決定日: 2026-08-25）。旧世代ドキュメントを読む際の未定義動作を消すための設計判断である。(2) **§5.6 の「INV-1 により既存ドキュメント側の `reading_i` の本数も W に等しい」という前提を、既存ドキュメントが INV-1 強制後のバイナリで書かれている場合に限定**した。(3) **§6.1 の「共存が問題になるのは `excluded` の有無だけである」を読み取り経路に限定**し、**書き込み経路の共存は `0003` §10.6（L1 期間）が扱う**ことを明記した。**あわせて冒頭「現在の版」表記が第 8 版への更新時に据え置かれていた不整合（第 7 版のまま）を本版で是正した**（区分 II）。**mapping・ID 方式・合成規則・番号体系・テスト仕様に変更は無い** | `20260822_implementation/0003` |

---

## 0. エグゼクティブサマリ

本書は「fess-suggest が OpenSearch に持つデータの形」を確定させる。**`0001` が公開契約の正であるのに対し、本書はマージ挙動の正である**（`0001` §3.4 / D-8）。

| # | 決定 | 節 | 根拠 |
| --- | --- | --- | --- |
| **DM-1** | データモデルの正しさを **5 つの不変条件（INV-1〜INV-5）** に集約する。以降の全決定はこの 5 条件のいずれかを成立させるためにある | §1 | MIG-01 / F-01 / F-04 |
| **DM-2** | mapping は `dynamic: "strict_allow_templates"` ＋ `match:"reading_*"` テンプレート ＋ `reading_0..9` の明示列挙。**明示列挙は正当性の要件ではなく最適化**である | §2.2 | `0000` §5.3 決定 1 |
| **DM-3** | `score` を廃止し `excluded`（boolean）を追加する。**mapping は 1 つだけ**とし、両論併記を持ち込まない | §2.1 / §2.6 | MIG-02 / MIG-13 / C-02 |
| **DM-4** | text の語数に上限 **N（既定 10 / 設定可能 / 設定上限 50）** を設け、超過語を切り捨てる | §2.3 | U3 / `0000` §5.3 決定 2 |
| **DM-5** | `text` は `keyword` のまま。**サブフィールドも normalizer も analyzer も導入しない**（`0001` 申し送り 9・10 への回答） | §2.4 | `0001` §3.5 / §10 |
| **DM-6** | `number_of_replicas: 0` の削除対象は **C-14 が数えた 4 ファイルではなく 7 ファイル**である（fess 本体側に 3 ファイルの見落とし） | §3.2 | 本ステップの実査 [確認] |
| **DM-7** | `index.mapping.total_fields.limit: 100` を **`suggest.json` にのみ**明示する。語数上限 N と独立に変更してはならない | §3.3 / §3.4 | `0000` §5.3 決定 3・4 |
| **DM-8** | ID を **`text` の SHA-256 → Base64 URL-safe（パディングなし・43 文字固定）** に置換する。`ID_MAX_LENGTH = 445` による切り詰めロジックを廃止する | §4.1 | P11 / U1 / F-05 |
| **DM-9** | **ID の構成要素は `text` のみに保つ**（kind を含めない）。含めると KEEP-03（決定的 ID による重複排除・頻度集約）の前提が壊れる | §4.2 | P13 / U5 / F-06 |
| **DM-10** | 走査基準を **text の語数 W ただ 1 つ**に統一する。現行の 3 通り（`SuggestItemMerger` / `toSource`・`toUpdatedSource` / `fromSource`）を廃する | §5.2 | MIG-01 / ISS-05 |
| **DM-11** | `userBoost` に **「指定あり／なし」の区別**を導入し、**指定ありの incoming だけが既存値を上書きする**。通常取り込みは「指定なし」とする。これが F-06 ③（elevate word の boost 潰れ）の解消であり、同時に MIG-04（丸め撤廃）の受け皿である ※**表現は `SuggestCandidate.userBoost`（`OptionalDouble`）**（`0001` 第 4 版 D-16。第 3 版の補助 boolean は廃止） | §5.3 | P13 / U5 / MIG-04 / F-06 ③ |
| **DM-12** | `ElevateWord` の読みは **位置対応（第 1 次元 ＝ 語位置）** である。**ステップ 4 が判別不能として申し送った 2 解釈のうち後者が正**であり、同ステップが示した修正形（`new String[][] { allReadings }`）は W > 1 で成立しない（E-22） | §5.4 | 本ステップの実査 [確認] |
| **DM-13** | **F-04（`reading_i` の消滅）は INV-1 の確立によって構造的に解消される。** `OpType.INDEX` の全置換は維持する | §5.6 | F-04 / P12 |
| **DM-14** | **suggest 本体インデックスを読むすべてのクエリ経路**（`SuggestRequest` と `PopularWordsRequest`）に **`mustNot(termQuery("excluded", true))` を必須**とし、`must(termQuery("excluded", false))` を**禁止**する。既存の `excludeWords` 機構は代替にならない | §6.2 | C-02 |
| **DM-15** | **旧世代インデックスとの共存は ID 方式の変更により成立しない。** 部分移行・段階適用の選択肢は存在せず、全件再構築＋エイリアス切替以外の経路を取らない | §4.7 | P11 / `0000` §4.2 の ID-01 |
| **DM-16** | **INV-5 は「異なる `text` が異なる ID を持つ」ではなく「ID は `text` のみから決定的に導出され、実用上十分な衝突耐性を持つ」である。** SHA-256 で単射は保証できない。**代わりに multiGet 後の突き合わせで衝突と ID 生成バグを検出する** | §1 / §4.4 | 外部レビュー指摘 9 |
| **DM-17** | **語数上限 N による切り捨ては安全装置ではなく、頻度統計の意味を変える設計判断である。** 先頭 N 語が一致する異なるクエリが同一 `text`・同一 ID に集約される。N=10 の妥当性は仮定であり、**切り捨て件数と超過クエリ数を観測項目として定義する** | §2.3(b) | 外部レビュー指摘 8 |
| **DM-18** | **`excluded = true` の意味は「現在の bad word 集合のいずれかに該当する」である。** 判定が部分一致であるため 1 語が複数の bad word に該当しうる。**解除は「削除後の集合のいずれにも該当しなくなった語」に限る**（`0001` の `BadWordPolicy.releaseCondition`）。付与は単調であり非対称なのは解除だけである。**`excluded` は boolean のままとし、mapping は変えない** | §5.3 / §7.2 | 外部レビュー（第 2 回）指摘 3 ／ `0001` D-25 |
| **DM-19** | **`userBoost` の合成規則（present の incoming が上書き）は可換ではない。** したがって**`userBoost` を present にする候補を作ってよいのは elevate word 経路だけ**である。この制約の下でのみ複数ソースの合成が順序非依存になる。**合成規則そのものは変えない**（max / min / 平均はいずれも §5.3 の却下表に抵触する） | §5.3 / §7.2 | 外部レビュー（第 2 回）指摘 5 ／ `0001` D-27 |
| **DM-21** | **bad word に該当する新規候補も保存する。`excluded = true` を初期値として書き込み、取り込み時の drop を廃止する。** 第 6 版までは「既存語は可逆に隠す／新規流入は不可逆に捨てる」という非対称があり、**C-02 の「即時・可逆な論理除外」が全ドキュメントについては成立していなかった**。この変更により **DM-18 の同値関係が新規流入語にも成立する**。**mapping も合成規則も変わらない** — 変わるのは「どのドキュメントが作られるか」と「`initialize` が `excluded` を引数で受けること」である。代償（bad word 該当語がインデックスに残る）は `deleteByCondition` による明示的な物理削除で扱う | §5.3 / §6.5 | 外部レビュー（第 4 回）指摘 2 ／ `0001` D-32 / C-02 |
| **DM-20** | **DM-18 の「`excluded == true` ⇔ 現在の bad word 集合のいずれかに該当する」は、bad word 操作の途中では一時的に破れる。** 設定インデックスの更新と suggest インデックスの `excluded` 更新は別リクエストであり、後段の失敗で部分適用状態が残る。**分散トランザクションを持ち込まず、「同一操作の再実行により収束する」を不変条件の成立条件として書く**（`0001` D-29）。**データモデル側の変更は無い** — `excluded` は boolean のままであり、収束性は操作の定義（後段が現在の集合から条件を再計算する）から導かれる | §5.3 / §7.2 | 外部レビュー（第 3 回）指摘 2 ／ `0001` D-29 |

### 0.1 本書の節と作業プランのステップ番号の対応

**`0000` §4.2 はステップ 7 で実節番号に置換済みである。** 本表は作業プランのステップ番号から本書の節を引くための対応表として残す。

| 作業プラン | 本書の節 |
| --- | --- |
| 5-1（To-Be mapping の統合定義） | **§2** |
| 5-2（index settings の設計） | **§3** |
| 5-3（マージ規則の単一化仕様） | **§5** |
| 5-4（決定的 ID の再設計） | **§4** |
| 5-5（旧世代インデックスとの共存） | **§6** |
| 5-6（0002 のレビュー） | **§10** |

**本書は 5-4 → 5-3 の順（作業順）ではなく、5-1 → 5-2 → 5-4 → 5-3 → 5-5 の順（読解順）で並べている。** データの形を先に示さないとマージ規則が読めないためである。§1 の不変条件は全節の前提であり、作業プランのどのステップにも対応しない本書固有の節である。

---

## 1. データモデルの不変条件

**本書の決定はすべて、次の 5 条件のいずれかを成立させるためにある。** 逆に、これらが成立していれば ISS-05 / F-01 / F-04 は個別の対処なしに消える。

| # | 不変条件 | 現状 | 成立させる節 |
| --- | --- | --- | --- |
| **INV-1** | `readings` の第 1 次元の長さ ＝ `text` の語数 **W**。すなわち `readings[i]` は「第 i 語に対する読み候補の集合」であり、`reading_i` フィールドの複数値として格納される | **恒常的には成立していない**。elevate word 経路が破る（§5.4） | §5.2 / §5.4 |
| **INV-2** | 語自身は区切り文字（半角空白）を含まない。`text` の語数は `text` 文字列を空白で分割した数と一致する | 保証されていない（ISS-05 が挙げるエッジケース） | §5.2 |
| **INV-3** | W ≤ N（語数上限。既定 10） | 上限が存在しない（F-01 / F-03） | §2.3 |
| **INV-4** | `reading_i` に `null` を書き込まない | 書き込みうる（`entity/SuggestItemSerializer.java:59-63`） | §2.3 |
| **INV-5** | **ID は `text` のみから決定的に導出され、実用上十分な衝突耐性を持つ**（DM-16） | 決定性は成立するが衝突耐性が無い。切り詰めにより現実的な長さで衝突する（F-05） | §4.1 / §4.4 |

> **INV-5 の書き方について**（第 4 版で改訂）。第 3 版までは「**異なる `text` は異なる ID を持つ**」と書いていたが、**新方式は SHA-256 のハッシュであり、単射性は数学的に保証できない**。不変条件として書けるのは次の 2 つに分かれる。
>
> | 性質 | 保証の強さ |
> | --- | --- |
> | **決定性**（同一 `text` ⇒ 同一 ID、ID は `text` 以外に依存しない） | **保証できる。** `0001` §2.6.3 が `id()` を `text` からの導出メソッドにしたことで型の上でも成立する |
> | **単射性**（異なる `text` ⇒ 異なる ID） | **保証できない。** 実用上無視できるだけである（SHA-256 の 256 ビット空間） |
>
> **実用上の差は無いが、書き方の差は下流に効く。** 「保証されている」と書くと、§5.6 が INV-5 に依拠して導く「同一 ID ⇒ 同一 `text` ⇒ 同一 W」という推論が**無検査の前提**になる。**検査を 1 つ置けば、確率的にしか成り立たない性質の破れも、決定性を壊す実装バグも、同じ 1 箇所で捕まえられる**（§4.4）。

**なぜ不変条件の形にまとめるか。** 現行の不具合は「マージが壊れている」「`reading_i` が消える」「ID が衝突する」という別々の症状として観測されるが、原因はいずれも上表の条件が成立していないことである。個別の症状に個別の対処を当てると、`0001` §3.4 が要求する「走査基準を実装内部の 1 箇所に閉じる」形にならない。

### 1.1 `text` は配列ではなく文字列である [確認]

**INV-1 / INV-2 を読むうえで前提になる事実**であり、既存資料が触れていない。

`entity/SuggestItem` のフィールド `text` は `String[]` ではなく **`String`** である（`:71`）。コンストラクタは `String[] text` を受け取るが、`:116` で `String.join(SuggestConstants.TEXT_SEPARATOR, text)`（区切りは半角空白 — `constants/SuggestConstants.java:37`）により即座に単一文字列へ結合し、以降の `getText()` / `setText()` はこの結合済み文字列を扱う。

したがって「text の語数」には**2 つの異なる量**がある。

| 量 | 定義 | 使っている箇所 |
| --- | --- | --- |
| **配列長** | コンストラクタ引数 `String[] text` の要素数 | どこにも保持されない（結合後は失われる） |
| **W（語数）** | `getText().split(" ").length` | `entity/SuggestItemMerger.java:70` |

**両者は一致するとは限らない。** 一致しないのは (a) 語自身が空白を含む場合（INV-2 の違反）、(b) 配列が 1 要素で、その要素が空白を含む複合語である場合（elevate word — §5.4）である。**本書は W を唯一の基準として採り、配列長は基準にしない。**

---

## 2. To-Be mapping（suggest 本体インデックス）

### 2.1 統合定義

**本節の JSON が唯一の正である。** ステップ 4 の骨格 JSON（`0000` §5.3 決定 1）、`20260706_opensearch_reference/0005-schema-draft.md` の案 A / 案 B、現行 `(res) suggest_indices/suggest/mappings-default.json` は、いずれも本 JSON に置き換わる。

```jsonc
{
  "dynamic": "strict_allow_templates",
  "dynamic_templates": [
    {
      "readings": {
        "match": "reading_*",
        "mapping": { "type": "keyword" }
      }
    }
  ],
  "properties": {
    "@timestamp": { "type": "date", "format": "epoch_millis" },
    "text":       { "type": "keyword" },
    "queryFreq":  { "type": "long" },
    "docFreq":    { "type": "long" },
    "userBoost":  { "type": "double" },
    "excluded":   { "type": "boolean" },
    "kinds":      { "type": "keyword" },
    "tags":       { "type": "keyword" },
    "roles":      { "type": "keyword" },
    "languages":  { "type": "keyword" },
    "fields":     { "type": "keyword" },

    "reading_0": { "type": "keyword" },
    "reading_1": { "type": "keyword" },
    "reading_2": { "type": "keyword" },
    "reading_3": { "type": "keyword" },
    "reading_4": { "type": "keyword" },
    "reading_5": { "type": "keyword" },
    "reading_6": { "type": "keyword" },
    "reading_7": { "type": "keyword" },
    "reading_8": { "type": "keyword" },
    "reading_9": { "type": "keyword" }
  }
}
```

**固定フィールドは 11 本**（`@timestamp` / `text` / `queryFreq` / `docFreq` / `userBoost` / `excluded` / `kinds` / `tags` / `roles` / `languages` / `fields`）である。この 11 という数は §3.4 の連動制約が参照する。

`embedding`（`knn_vector`）は**含めない**（P5）。後付け手順は `0003` が持つ。

`excluded` に `null_value` を設定しない。**書き込み側が明示的に `false` を格納する**（§5.3）。旧世代インデックスの未定義文書に対する扱いは §6 が持つ。

### 2.2 `dynamic` 方針

`dynamic: "strict_allow_templates"` は **OpenSearch 2.16 で追加された OpenSearch 独自値**であり、`dynamic_templates` に合致する新規フィールドだけを許可し、それ以外を `StrictDynamicMappingException` で拒否する。OpenSearch 3.7.0 での実機検証済み [確認]（`0000` §5.3 決定 1。検証の経緯は付録 B.3）。

**`reading_0..9` の明示列挙は正当性の要件ではなく最適化である。** ここが `0005-schema-draft.md` の案 A（`strict` ＋ 明示列挙）との決定的な差であり、本方針を採る最大の理由である。

| | 案 A（`strict` ＋ 明示列挙） | 本設計（`strict_allow_templates` ＋ テンプレート ＋ 明示列挙） |
| --- | --- | --- |
| 列挙を超える `reading_i` | **取り込みが失敗する** | テンプレートが受けるので**動く** |
| 語数上限 N の引き上げ | mapping の追随が必須。追随漏れ＝障害 | mapping は無変更でよい。列挙漏れ＝わずかな性能劣化 |
| 定数とスキーマの二重管理 | 生じる（`0005-schema-draft.md:89` の [要確認]） | **構造的に生じない**（当該 [要確認] は解消） |

明示列挙する理由は次の 2 点に限られる。

1. **取り込み時の cluster-state 更新を避ける最適化。** 動的フィールド追加は cluster-manager 経由の cluster-state 更新を伴う。全件再投入の序盤で `reading_0`〜`reading_9` の追加が逐次発生するのを、事前宣言によりゼロにする。
2. **スキーマの自己文書化。** 「通常想定は 10 語」がスキーマから読める。

**テンプレートに `match_mapping_type` を付けない。** `match_mapping_type: "string"` を付けると、値が空配列 `[]` の `reading_i` がテンプレートに合致せず拒否される（実機検証済み [確認]。`0000` §5.3 決定 1 の付帯規則）。`entity/SuggestItemSerializer.java:59-63` は `readings[i]` をそのまま put するため空配列が渡りうる。

**最小バージョン要件が上がる。** `strict_allow_templates` は Elasticsearch に存在せず、OpenSearch も 2.16 未満では受け付けない。**本設計の適用条件は OpenSearch 2.16 以上**である。移行前提としての扱い（AWS OpenSearch Service で 2.16 未満を使う利用者への影響を含む）は `0003` が持つ。

`reading_abc` のような誤ったキーはテンプレートに合致して通る。実害は keyword が 1 本増えるだけであり、許容する。

### 2.3 `reading_*` の付帯規則

#### (a) `reading_i` に `null` を書き込んではならない（INV-4）

`null` は型を持たないため `dynamic_templates` に合致せず、未マップの `reading_i` に対しては `StrictDynamicMappingException` で**取り込みが失敗する**。現行 `entity/SuggestItemSerializer.java:59-63` は `readings[i] == null` のときそのまま `map.put(..., null)` するため、**null をスキップする形に改める**。

これは `dynamic: "strict_allow_templates"` の採用によって初めて必須になる規則である（現行の既定 `dynamic: true` では null は単に無視される）。**mapping の変更だけを適用してコード側を直さないと取り込みが止まる**ため、両者は同一の変更として扱う。

#### (b) 語数上限 N（INV-3）

**text の語数 W に上限 N を設ける。既定 10、設定可能、設定値の上限 50。** 超過語は**切り捨てる**（拒否しない）。

| 切断点 | 位置 | 役割 |
| --- | --- | --- |
| 一次 | `index/contents/DefaultContentsParser.java:86-103`（`parseSearchWords` の語ループ）。除外判定（`:87-89`）の**後**、正規化（`:91`）・読み変換（`:92`）の**前**に break | 通常経路。`wordsList`（`:101`）と `readingList`（`:102`）が同一反復で append されるため、text 側と readings 側が片方だけ切れる事故が構造的に起きない |
| バックストップ | `entity/SuggestItem` のコンストラクタ（`:113-141`）で INV-1 ＋ INV-3（W ＝ `readings.length` ≤ N）を強制 | `entity/ElevateWord.java:143-149` は parser を通らない第 2 の生成経路であり、一次切断点だけでは守れない。ID 生成（`:140`）と同じコンストラクタ内なので text / readings / ID が常に整合する |

> **バックストップの実装には順序依存がある。** §5.4 で `ElevateWord.toSuggestItem` を INV-1 に適合させることが**先**であり、コンストラクタでの強制はその後でなければならない。順序を逆にすると、読みトークン数と語数が食い違う elevate word の登録がすべて失敗する。

**N を超える語数のサジェストクエリは 0 件になる。** `request/suggest/SuggestQueryBuilder.java:112` が語ごとの節を `must`（AND）で連結するため、N を超える語に対応する `reading_i` がドキュメント側に存在しない以上、必ず 0 件である。それでも切り捨てを採るのは、N=10 が実運用のクエリ語数分布を十分覆い、queryLog 経路の既存制限 `MAX_QUERY_TERM_NUM = 5`（`util/SuggestUtil.java:63`）より緩いためである。

> **作業プラン `0003:194` / `:407` の根拠文（「検索側はクエリの語数分しか `reading_i` を引かないため実害がない」）は誤りであり、本書はそれを採らない。** 結論（切り捨て）だけが同じである。

##### 切り捨ては頻度統計の意味を変える（DM-17・第 4 版で追加）

**N は「暴走を止める安全装置」ではない。データの意味を変える設計パラメータである。** 影響は 2 段ある。

| 段 | 影響 |
| --- | --- |
| 1 | **N を超える語数のクエリは検索できない**（上記。K-5 として §8 に記録済み） |
| 2 | **先頭 N 語が一致する異なる入力が、同一 `text`・同一 ID へ集約される** |

2 が第 3 版で明示されていなかった。`a b c … j X` と `a b c … j Y` は切り捨て後どちらも `a b c … j` になり、**別々の語として数えるべき頻度が 1 つのドキュメントに加算される**。これは「11 語目以降を検索できない」という到達性の話ではなく、**`queryFreq` / `docFreq` が何を数えているかが変わる**という統計の話である。

> **N=10 が実運用のクエリ語数分布を十分覆うという判断は、実測ではなく仮定である**（C-04 により本タスクは性能・分布の実測を行わない）。**仮定であることを明示したうえで、仮定を検証できる観測項目を定義する。**

| # | 観測項目 | 取得箇所 | 用途 |
| --- | --- | --- | --- |
| **OB-1** | **切り捨てが発生した件数**（累計・取り込み 1 回あたり） | §2.3(b) の一次切断点（`index/contents/DefaultContentsParser.java:86-103` の break 位置）でカウントし、取り込み完了時にログ／メトリクスへ出す | 0 に近ければ N=10 の仮定が成立している。無視できない割合なら 2 の集約が起きている |
| **OB-2** | **N を超える語数の検索クエリ数** | `request/suggest/SuggestQueryBuilder.java` のクエリ組み立て時に語数を見る。**N 超過なら必ず 0 件になる**ため、0 件応答の中の「構造的に 0 件」を切り分けられる | 「サジェストが出ない」という問い合わせの一次切り分け |
| **OB-3** | **本番投入前のクエリ語数分布** | 既存の検索ログ（`fess_log.search_log`）から語数のヒストグラムを取る。**再構築の前に 1 回取れば足りる** | N の初期値を仮定ではなく実測で決める |

**N を引き上げる判断基準**: OB-1 の切り捨て率が運用上許容できない水準になった場合、または OB-3 の分布が N を超える裾を持つ場合に引き上げる。**引き上げ時は §3.4 の連動制約（`total_fields.limit`）と 1 ドキュメントあたりの term 数（上記）を必ず併せて見る。**

**OB-1〜OB-3 の実装と閾値の決定は後続タスクである**（§9 の申し送り 11）。本書が定めるのは「何を観測するか」までであり、**観測せずに N を変えないこと**が規則である。

**実質的な制約は `total_fields.limit` ではなく 1 ドキュメントあたりの term 数である。** N=10 なら最大 100 term/doc（10 語 × 各 10 読み）、N=50 なら 2500 term/doc になる。フィールド数は N=50 でも 61 本にすぎない（§3.4）。**N を引き上げる判断は、フィールド数ではなく term 数を見て行うこと。**

設定値は `settings/SuggestSettings.getAsInt(key, default)`（`:276`）で読む。キー名と `SuggestSettingsBuilder` への露出は `0001` §6 の設定 API に従う。

### 2.4 `text` の型は変えない

`text` は `keyword`、**サブフィールドも normalizer も analyzer も持たない**。現行（`(res) suggest_indices/suggest/mappings-default.json:42-44`）から変更しない。

これは `0001` §10 の申し送り 9・10 に対する回答である。

- **申し送り 9**（`BadWordPolicy.matchCondition` の実装方式が `text` の mapping 型に依存する）: `text` が `keyword` のままなので、`0001` §3.5 が選んだ**エスケープ済みワイルドカード**（`*value*`）が引き続き唯一の現実的手段であり、選び直しは不要である。
- **申し送り 10**（等価性は normalizer の不在にも依存する）: **normalizer を導入しない。** 導入すると OpenSearch 側は正規化後の索引値に照合する一方、`BadWordPolicy.isBadWord` は Java の文字列判定として正規化前を見るため、`0001` §10 申し送り 2 の等価性（両判定が同じ語集合に一致すること）が壊れる。

`wildcard` 型フィールドや ngram サブフィールドの追加も採らない。MIG-03 が「スキーマ変更なしの局所変更」であるという位置づけ（`improvement-proposal.md:380`）を崩すためである。

### 2.5 `kinds` の値域

`kinds` は `keyword` で、**値域は `document` / `query` / `user` の 3 値**である（現行 `entity/SuggestItem.java:47-53` の `Kind` enum。**新設計では `org.codelibs.fess.suggest.api.SuggestKind`** — `0001` 第 7 版の D-33 / §2.6.0）。mapping 上の型による制約はないため、**本節が値域の唯一の明文化された定義**になる（F-12）。

> **D-33（`Kind` を `SuggestItem` の外へ出す）は Java の型の置き場所を変えるだけであり、永続表現は変わらない。** 保存される値は引き続き小文字の `document` / `query` / `user` である。**本節が永続表現の正であり、`0001` §2.6.0 は Java 側の型の正である。**

elevate word は専用フィールドを持たず `kinds` に `user` を持つことで区別される（`entity/ElevateWord.java:143-149`）。**この点は変更しない。** ID の構成要素に kind を含めない判断（§4.2）と対になっており、`userBoost` の合成規則（§5.3）が kind に依存しない形になっている理由でもある。

### 2.6 現行 mapping との差分

対象は `(res) suggest_indices/suggest/mappings-default.json`（全 49 行）。

| # | 項目 | 現行 | To-Be | 根拠 |
| --- | --- | --- | --- | --- |
| M-1 | トップレベル `dynamic` | **指定なし**（＝既定 `true`） | `"strict_allow_templates"` | §2.2 |
| M-2 | `dynamic_templates` | `strings`: `match:"*"` ＋ `match_mapping_type:"string"` → `keyword`（`:2-12`） | `readings`: `match:"reading_*"` → `keyword`（`match_mapping_type` なし） | §2.2 / §2.3(a) |
| M-3 | `score` | `double`（`:36-38`） | **削除** | MIG-02（案 A） |
| M-4 | `excluded` | なし | `boolean` を追加 | MIG-13 / C-02 |
| M-5 | `reading_0`〜`reading_9` | なし（すべて動的生成） | `properties` に明示列挙 | §2.2 |
| M-6 | `text` | `keyword`（`:42-44`） | **変更なし** | §2.4 |
| M-7 | `@timestamp` / `queryFreq` / `docFreq` / `userBoost` / `kinds` / `tags` / `roles` / `languages` / `fields` | 現行どおり | **変更なし** | — |
| M-8 | `embedding` | なし | **追加しない** | P5 |

**M-2 は「テンプレートの追加」ではなく「置換」である。** 現行の `match:"*"` テンプレートを残したまま `strict_allow_templates` にすると、`*` があらゆるフィールド名に合致するため厳格化が無意味になる（誤ったキーがすべて通る）。

**M-3 の影響**: `score` は書き込み時に `(queryFreq + docFreq) * userBoost` として格納されているだけで（`entity/SuggestItemSerializer.java:73`、`:182`、`entity/SuggestItem.java:360`）、検索側は参照していない。廃止に伴い、この格納を検査している既存テスト 4 箇所の更新が要る（§7.1）。

---

## 3. index settings

### 3.1 適用範囲の設計原則

> **`dynamic` の厳格化は、インデックス再作成が設計に組み込まれているインデックスにのみ適用する。**

| インデックス | 生成元 | `dynamic` | `total_fields.limit` |
| --- | --- | --- | --- |
| `{index}.{timestamp}`（**suggest 本体**） | `(res) suggest_indices/suggest.json` ＋ `suggest/mappings-default.json` | **`strict_allow_templates`**（§2.2） | **100 を明示**（§3.3） |
| `fess_suggest`（設定ドキュメント） | `(res) suggest_indices/suggest_settings.json`（mapping ファイルは存在しない） | `true` のまま | 明示しない |
| `fess_suggest_array.{id}` / `_badword.{id}` / `_elevate.{id}` | `(res) suggest_indices/suggest_settings_array.json` ＋ `settings/ArraySettings.java:366-378` のコード内 mapping | `true` のまま | 明示しない |
| `fess_suggest_analyzer` | `suggest_indices/suggest_analyzer.json` ＋ `(res) suggest_indices/analyzer/mapping-default.json` | 現状維持 | 明示しない |

**この分岐の理由**:

- **suggest 本体**は `createNextIndex()`（`Suggester.java:235`）→ `switchIndex()`（`:282`）の世代交代が設計に組み込まれており、mapping は毎世代でリソース定義から作り直される（`:239-249`、`:467-484`）。厳格化してもバージョンアップで壊れない。
- **設定系**は `settings/ArraySettings.java:335-383`（`createMappingIfEmpty`）と `settings/AnalyzerSettings.java:130-142`（`init`）がいずれも「無ければ作る」だけで、**既存インデックスの mapping を更新する経路が存在しない**。厳格化すると、v15.7 で作られた strict mapping が、将来のバージョンで追加された新フィールドの書き込みを恒久的に拒否する。
- 加えて `fess_suggest` は `settings/SuggestSettings.set(String, Object)`（`:315-332`）にキーのバリデーションがなく、**任意の文字列キー**が入る設計である（fess は `search_engine.type` を投入 — `(fess) helper/SuggestHelper.java:134`。ステップ 4 の記述は `:135` としているが実際は `:134` である [確認]）。そもそも厳格化できない。

### 3.2 `number_of_replicas: 0` の削除対象は 4 ファイルではなく 7 ファイル [確認]

C-14 は削除対象を「4 ファイル」としているが、**本ステップの実査で 3 ファイルの見落としが判明した**。

| # | ファイル | 該当行 |
| --- | --- | --- |
| 1 | `(res) suggest_indices/suggest.json` | `:5` |
| 2 | `(res) suggest_indices/suggest_settings.json` | `:5` |
| 3 | `(res) suggest_indices/suggest_settings_array.json` | `:5` |
| 4 | `(res) suggest_indices/suggest_analyzer.json` | `:5` |
| **5** | **`(fess res) suggest_indices/suggest_analyzer.json`** | **`:5`** |
| **6** | **`(fess res) suggest_indices/_aws/suggest_analyzer.json`** | **`:5`** |
| **7** | **`(fess res) suggest_indices/_cloud/suggest_analyzer.json`** | **`:5`** |

`settings/AnalyzerSettings.java:309-317`（`getSuggestAnalyzerPath`）は `search_engine.type` の値により `suggest_indices/_{type}/suggest_analyzer.json` を優先し、無ければ `suggest_indices/suggest_analyzer.json` にフォールバックする。いずれもクラスパス解決（`:295` の `ClassLoader#getResourceAsStream`）であるため、fess 本体側の同名リソースが fess-suggest 側を遮蔽しうる。**どちらが優先されるかに関わらず、7 ファイルすべてを直さなければ削除は完了しない。**

`(res)` ＝ `modules/fess-suggest/src/main/resources/`、`(fess res)` ＝ `modules/fess/src/main/resources/`。**`(fess res)` は `0000` §3.1 のパス短縮表記に無い接頭辞であり、本書で新設する**（付録 A）。

### 3.3 各ファイルの To-Be

**`(res) suggest_indices/suggest.json`**（suggest 本体）:

```json
{
  "index": {
    "refresh_interval": "10s",
    "number_of_shards": 1,
    "auto_expand_replicas": "0-1",
    "mapping": {
      "total_fields": {
        "limit": 100
      }
    }
  }
}
```

| 項目 | 現行 | To-Be | 根拠 |
| --- | --- | --- | --- |
| `number_of_replicas: 0` | `:5` | **削除** | C-14。`auto_expand_replicas` と併記されており、後者が唯一のレプリカ制御である |
| `number_of_shards: 1` | `:4` | **値は据え置き、位置づけを「API 無指定時の既定値」に格下げ** | C-13。`${...}` プレースホルダ置換は導入しない |
| `auto_expand_replicas: "0-1"` | `:6` | 変更なし（**唯一のレプリカ制御**） | C-14 |
| `refresh_interval: "10s"` | `:3` | 値は据え置き（§3.5） | MIG-16 |
| `index.mapping.total_fields.limit` | **なし**（既定 1000 が効く） | **`100` を追加** | 下記 |

**`total_fields.limit: 100` の根拠**: 必要数は N=10 で 21 本（固定 11 ＋ `reading_0..9`）、設定上限 N=50 の最悪ケースでも 61 本である。100 は十分な余裕を持ちつつ既定 1000 の 1/10 であり、**暴走が「1000 本のゴミフィールドと肥大した cluster state」になる前に止まる**。

これは load-bearing な制御ではなく **tripwire** である。§2.3(b) の語数上限が効いている限り到達しない。暴走には「語数上限のバイパス」かつ「フィールド名が `reading_*` に合致」の両方が必要で、実質コードバグに限られる。それでも安価な保険として置く。

明示しない場合は既定 1000 が効き、到達すると `IllegalArgumentException: Limit of total fields [1000] has been exceeded` で取り込みが失敗する。**OpenSearch には Elasticsearch 8.x の `index.mapping.total_fields.ignore_dynamic_beyond_limit` に相当する緩和機構が存在しない**（`opensearch-3.7.0.jar` を走査して確認 [確認]。`0000` §5.3 決定 3）ため、超過は必ずハードエラーになる。

**残り 6 ファイル**（`suggest_settings.json` / `suggest_settings_array.json` / `suggest_analyzer.json` ＋ fess 側 3 ファイル）: **`number_of_replicas: 0` の 1 行を削除するだけ**とする。`refresh_interval: "1s"` / `number_of_shards: 1` / `auto_expand_replicas: "0-1"` は据え置き、`total_fields.limit` は**追加しない**（§3.1）。

### 3.4 語数上限 N と `total_fields.limit` の連動制約

**この 2 つの数値は独立に変更してはならない。** 不変条件として次を保つ。

> **固定フィールド数 ＋ 語数の設定可能上限 ＋ 余裕 ≤ `index.mapping.total_fields.limit`**

現在の値では **11（固定、§2.1）＋ 50（語数の設定可能上限、§2.3(b)）＝ 61 ≤ 100** である。**語数上限の設定可能上限を引き上げる場合は `total_fields.limit` も併せて見直すこと。**

なお `total_fields.limit` は `_settings` API で reindex なしに引き上げられる（実機検証済み [確認]。`0000` §5.3 決定 3）ため、運用上の逃げ道はある。手順は `0003` が持つ。

### 3.5 `refresh_interval` の位置づけ

`suggest.json` の `refresh_interval: "10s"` は**値としては据え置く**。本書が定めるのは「これがインデックス定義側の既定であり、取り込み中の refresh 制御はこれとは別の層で行う」という位置づけだけである。

- 取り込み中に `refresh_interval: -1` へ一時変更する定石、および `RefreshPolicy`（`0001` §6.3）との使い分けの運用手順は **`0003` §7 が持つ**（MIG-16 / C-12）。
- **マージの正しさは refresh に依存しない**（§4.5）ため、refresh 戦略の変更が本書の決定に波及することはない。この非依存性が MIG-16 を独立に進められる根拠である。
- 値の最適化は行わない（C-04：性能実測は後続タスク）。

---

## 4. 決定的 ID の再設計（ID-01 / P11）

### 4.1 新方式

> **ID ＝ Base64URL-without-padding( SHA-256( UTF-8( text ) ) )**
>
> `text` は `entity/SuggestItem` が保持する結合済み文字列（§1.1）。**長さは入力によらず常に 43 文字**であり、切り詰めは発生しない。

**現行 `util/SuggestUtil.java:66,68,84-90` の `ID_MAX_LENGTH = 445` と `substring(0, 445)` は廃止する。**

| 項目 | 現行 | 新方式 |
| --- | --- | --- |
| 変換 | Base64（標準アルファベット・パディングあり） | SHA-256 → Base64 URL-safe（`-` `_`・パディングなし） |
| 長さ | 入力依存（最大 445） | **43 文字固定** |
| 切り詰め | あり（`:86-87`） | **なし** |
| 可逆性 | あり | なし |
| 衝突 | **実在する**（下記） | 実用上ゼロ |

**URL-safe を選ぶ理由**: 標準アルファベットは `+` `/` `=` を含む。OpenSearch の `_id` としては許容されるが、`GET /{index}/_doc/{id}` の形で REST パスに現れるときに URL エンコードが要る。運用時の手作業（curl による個別ドキュメントの確認）とログの可読性のために URL-safe とし、パディングも同じ理由で外す。

### 4.2 ID の構成要素は `text` のみに保つ（P13 / U5）

**`kinds` を ID に含めない。** F-06 ③（elevate word の `userBoost` が通常取り込みで潰れる）は ID ではなく §5.3 のマージ規則で解く。

> **根拠**: ID に kind を含めると同一語の DOCUMENT / QUERY / USER が別ドキュメントに分裂し、**KEEP-03（決定的 ID による重複排除・頻度集約）の前提が壊れる**。頻度集約が kind ごとに割れ、検索結果に同一 text が重複しうる（`request/suggest/SuggestRequest.java:363-365` の kinds フィルタと `(fess) api/v2/handlers/SuggestWordsHandler.java:96` の意味も変わる）。③ の実体は `entity/SuggestItemSerializer.java:181` の無条件上書きであり、ID ではなく合成規則の問題である。

同一語の DOCUMENT / QUERY / USER が 1 ドキュメントに合流する**現行動作は変えない**。

### 4.3 現行方式の衝突条件（F-05 の精密化）[確認]

既存資料は「先頭約 333 バイトが一致する長文が同一 ID に衝突する」としている。実コードから導かれる正確な条件は次のとおりである。

- Base64（パディングあり）の出力長は `n` バイトに対し `4 × ceil(n / 3)`。445 を超えるのは `n ≥ 334` バイトのとき。**`n ≤ 333` バイトでは切り詰めが起きず衝突もしない。**
- 切り詰め後の 445 文字は、完全な 4 文字グループ 111 個（＝先頭 333 バイトを過不足なく符号化）＋ 112 番目グループの先頭 1 文字である。この 1 文字は **334 バイト目の上位 6 ビットのみ**を表す。
- したがって衝突条件は「**先頭 333 バイトが完全一致し、334 バイト目の上位 6 ビットが一致する**」であり、**335 バイト目以降は長さも内容も一切影響しない**。

**「333 バイト」は文字数ではない。** UTF-8 の日本語（1 文字 3 バイト）なら**約 111 文字**、絵文字（4 バイト）なら約 83 文字で切り詰め境界に達する。日本語のサジェスト用途では現実的な長さである。

**衝突が引き起こす具体的な破壊** [確認]: `index/writer/SuggestWriter.java:76-102`（`mergeItems`）は**バッチ内の重複を ID の一致だけで判定**しており、text の一致を確認していない。したがって 334 バイト以上の異なる text が同一バッチに現れて衝突すると、**2 つの別の語が「同一アイテム」として無言でマージされ、`entity/SuggestItemMerger.java:67` が item1 の text を採るため一方の text が失われる**。これは検索結果の欠落として現れるが、ログにも例外にも現れない。

**§2.3(b) の語数上限との関係**: N=10 で text を切ると、日本語で 334 バイトに達するには 1 語平均 11 文字以上が必要になり、切り詰めの発生確率が大きく下がる。ただし**確率を下げるだけで解消はしない**（1 語が長大な入力は作れる）。ハッシュ化が必要な理由はここにある。

### 4.4 ID 変更の影響範囲

**ID 生成箇所は 3 箇所** [確認]。いずれも「text から ID を再計算する」形であり、新方式に差し替えるだけでよい。

| 箇所 | 入力 |
| --- | --- |
| `entity/SuggestItem.java:140` | コンストラクタ内。`:116` で結合済みの `this.text` |
| `entity/SuggestItemSerializer.java:130` | `fromSource` 内。既存ドキュメントの `text` フィールド（`:85`）から再計算する（保存された `_id` は使わない） |
| `index/operations/WordManagementOperations.java:129` | `deleteElevateWord` 内。正規化済みの elevate word 文字列 |

**ID を前提とする経路**: `index/writer/SuggestIndexWriter.java:55`（`prepareGet` の `setId`）、`:58`・`:64`（`IndexRequest` の `setId`）、`index/writer/SuggestWriter.java:81,92`（バッチ内重複判定のキー）。いずれも ID の**値**にのみ依存し、形式には依存しない。

**可逆性の喪失は影響しない** [確認]。本ステップでリポジトリ全体（fess-suggest / fess の両モジュール、テスト・リソース・スクリプトを含む）を走査した結果、**ID をデコードして text を復元している箇所は存在しない**。`Base64.getDecoder()` 相当の呼び出しは fess-suggest モジュールに 1 件もなく、fess 本体側の Base64 デコードはロール ID・ログファイル名・JWT など suggest と無関係な用途のみである。

**外部露出もない** [確認]。`SuggestItem.getId()` の呼び出しは fess-suggest 内部（マージ・重複排除・リクエスト構築）に限られ、`(fess) api/v2/handlers/SuggestWordsHandler.java:107-113` は `getText()` と `getTags()` のみ、`(fess) helper/PopularWordHelper.java:120` は `getText()` のみをレスポンスに詰めている。管理画面（`admin_suggest.jsp`）にも個別アイテムの ID 表示はない。

#### 4.4.1 衝突と ID 生成バグの検出（DM-16・第 4 版で追加）

> **multiGet（`0001` §3.7）で引いた既存ドキュメントと取り込み候補を突き合わせ、ID が一致するのに `text` が一致しない場合は例外にする。**

```java
// 取り込み経路の畳み込みループの入口（`0001` §3.7.1）
final SuggestItem existing = fetched.get(candidate.id());
if (existing != null && !existing.text().equals(candidate.text())) {
    throw new SuggestIndexException(
            "ID collision or ID generation bug: id=" + candidate.id()
                    + " existing.text=" + existing.text()
                    + " incoming.text=" + candidate.text());
}
```

**この検査が安い保険として成立する理由**:

| # | 理由 |
| --- | --- |
| 1 | **コストがほぼゼロである。** multiGet の結果は合成のために既にメモリ上にあり、`text` の比較 1 回が増えるだけである。ハッシュの再計算も追加の I/O も要らない |
| 2 | **捕まえる対象が 2 つある。** (a) SHA-256 の衝突（実用上ゼロだが INV-5 が保証しないもの）、(b) **ID 生成の実装バグ**（`entity/SuggestItem` / `entity/SuggestItemSerializer` / `index/operations/WordManagementOperations` の 3 箇所（§4.4）で生成規則が食い違う、正規化のタイミングがずれる 等）。**実際に起こりうるのは圧倒的に (b) である** |
| 3 | **無検査だと沈黙して壊れる。** 現行の同型の欠陥（`index/writer/SuggestWriter.java:76-102` が ID の一致だけで重複判定し `text` を確認していない）は、**2 つの別の語を無言でマージし一方の text を失わせる**（§4.3）。**新方式でも「ID が一致すれば同一語」という前提は変わらない**ため、前提を検査する場所を 1 つ持つ |
| 4 | **§5.6 の推論の前提を実行時に守る。** §5.6 は「同一 ID ⇒ 同一 `text` ⇒ 同一 W」から F-04 の解消を導いている。この検査はその第 1 段を保証する |

- **失敗の扱いは「項目単位の失敗」である。** `IngestResult.failures` に積み（`0001` §4.3）、バッチ全体を落とさない。ただし **fess の全件再構築では `hasFailures()` により切替が止まる**（`0001` D-22 ／ `0003` §4.2 の G3）ため、**本番で起きれば必ず気づく**。
- **バッチ内の重複判定（`index/writer/SuggestWriter.java:81,92`）にも同じ検査を置く。** 既存ドキュメントとの突き合わせだけでは、同一バッチ内で衝突した 2 件を捕まえられない。
- 回帰テストは §7.2 の T-15 とする。

### 4.5 realtime get の明文化（申し送り 1）

**マージの正しさは refresh に依存しない。** `index/writer/SuggestIndexWriter.java:55` の ID 指定 GET は `setRealtime(false)` を指定していないため既定の realtime（translog 読み）で動作する。直前のバッチが未 refresh でも既存ドキュメントは見える。

**OpenSearch 3.7.0 の `GetRequest` のコンストラクタが `realtime = true` を設定していることをバイトコードで確認した** [確認]（`opensearch-3.7.0.jar` の `org/opensearch/action/get/GetRequest`）。

**ID 方式を変えてもこの性質は保たれる。** ID 指定 GET であること自体が不変だからである。

**MIG-15 第 1 段（multiGet 化）でも保たれる** [確認]。同 jar の `org/opensearch/action/get/MultiGetRequest` も同様にコンストラクタで `realtime = true` を設定している。**したがって multiGet 化は本書のマージ規則に何の変更も要求しない**（`0001` §3.7 / MIG-15 第 1 段）。

### 4.6 F-10（楽観ロック欠如）を既知の制約として明記する（P12）

**解消は本設計のスコープ外である。** 記録のみ行う。

- `index/writer/SuggestIndexWriter.java:44-80` は `prepareGet` → マージ → `IndexRequest` の read-modify-write だが、**`setIfSeqNo` / `setIfPrimaryTerm` を使っていない** [確認]（fess-suggest モジュール全体で当該メソッドの呼び出しは 0 件）。同 `:82-91` の `delete()` も同様である。
- **multiGet 化（MIG-15 第 1 段）では解決しない。** 往復が減るだけで read-modify-write のままである。
- **MIG-15 第 2 段（`scripted_upsert` ＋ `retry_on_conflict`）と同じ問題領域であり、そこで一括して扱う。** 解消は後続スコープ（`0000` §2.2）。

**成立条件の精密化** [確認]: 既存資料（F-10）は `index/SuggestIndexer.java:185` の `parallel` フラグを根拠に「並行実行時にロストアップデートが起きうる」としているが、**`parallel` はロストアップデートの直接原因ではない**。

- `parallel` の実効箇所は `index/operations/ContentIndexingOperations.java:138-139` と `:256-257` であり、いずれも**パース処理のストリームを並列化するだけ**である。書き込みは `:147` / `:275` で 1 回だけ呼ばれ、`index/writer/SuggestWriter.java:80-99` のループは逐次実行される。**1 回の呼び出しの中では競合しない。**
- 実際の成立条件は「**異なる呼び出し元が同時に書き込み系メソッドを呼び、同一 ID を含むバッチが競合すること**」である。楽観ロックが無いこと（上記）が唯一の根本原因である。

### 4.7 移行への帰結（申し送り）

**旧世代インデックスとの共存は成立しない。** 同じ語が新旧で別 ID になるため、「旧インデックスに書き足しながら移行する」形は取れず、**必ず全件再構築＋エイリアス切替**になる。部分移行・段階適用の選択肢は存在しない。

**同一の再構築に束ねる変更は次の 4 つである。** いずれも既存ドキュメントの読み替えができない。

| # | 変更 | 既存データが読み替え不能な理由 | 本書 |
| --- | --- | --- | --- |
| 1 | ID のハッシュ化 | 同じ語が新旧で別 ID になる | §4.1 |
| 2 | 語数上限 N の導入 | 切り捨てにより `text` が変わり ID も変わる | §2.3(b) |
| 3 | `ElevateWord` の格納形の変更 | `reading_0..k-1` に 1 値ずつ → 語位置対応（§5.4） | §5.4 |
| 4 | `score` 廃止・`excluded` 追加・`dynamic` 厳格化 | mapping そのものの変更 | §2.6 |

手順・ロールバック条件・切替前の件数検証基準は **`0003` §3〜§6** が持つ。

---

## 5. マージ規則の単一化（MIG-01 / ISS-05）

**本節が `SuggestItemMergePolicy`（`0001` §3.4）の挙動の正である。** `0001` はシグネチャのみを確定しており、その申し送り 4 を本節が消化する。

### 5.1 現行実装の何が問題か

現行のマージは**2 つの独立した実装**に分かれており、しかも**走査基準が 3 通り**ある [確認]。

| 実装 | 役割 | 走査基準 |
| --- | --- | --- |
| `entity/SuggestItemMerger.merge`（`:59-96`） | 同一バッチ内の同一 ID どうしの合成（`index/writer/SuggestWriter.java:76-102` から呼ばれる） | **`item1.getText().split(" ").length`**（＝ item1 の W） — `:70-74` |
| `entity/SuggestItemSerializer.toSource`（`:55-76`） | 新規ドキュメントの source 生成 | **`item.getReadings().length`** — `:59-63` |
| 同 `toUpdatedSource`（`:142-185`） | 既存ドキュメントとの合成 | **新 item 側の `readings.length`** — `:146-158` |
| 同 `fromSource`（`:84-133`） | 既存ドキュメントからの復元 | **既存ドキュメント側のフィールド存在**（`reading_i` が `List` である限り回す無限ループ） — `:87-95` |

**`toUpdatedSource` は既存 source をコピーせず新規 `HashMap` を構築する**（`:143`）。`OpType.INDEX` の全置換（`index/writer/SuggestIndexWriter.java:59,64`）と組み合わさるため、**新 item 側が言及しないキーは消える**。これが F-04 の実体である。

### 5.2 走査基準の単一化（DM-10）

> **走査基準は `text` の語数 W ただ 1 つとする。** `readings` の第 1 次元の長さは W に等しく（INV-1）、既存ドキュメントの `reading_i` も `i ∈ [0, W)` の範囲でのみ読み書きする。`fromSource` の無限ループは廃止し、`text` から導出した W で回す。

これにより 3 通りの基準が 1 通りになる。`0001` §3.4 が求めた「走査基準が実装内部の 1 箇所に閉じる」形は、`SuggestItemMergePolicy` の実装が W を 1 回だけ計算することで満たされる。

**成立には INV-1 と INV-2 の両方が要る。**

- **INV-1**（`readings.length == W`）を破るのは elevate word 経路である（§5.4）。
- **INV-2**（語が区切り文字を含まない）を破ると、`text` 文字列を分割して得た W と、生成側が意図した語数がずれる。これは ISS-05 が「`text` 配列の要素自身が空白を含むエッジケース」として挙げたものそのものである（`improvement-proposal.md:133`）。**正規化の段階で語に空白を残さないことを規則とし、`SuggestItem` のコンストラクタで検査する。**

**強制する場所は `entity/SuggestItem` のコンストラクタ**（`:113-141`）とする。ID 生成（`:140`）と同じスコープであり、text / readings / ID の三者が常に整合する。§2.3(b) のバックストップと同一の実装である。

> **[確定] W で回したときに `reading_i` が存在しないスロットの扱い**（第 9 版で追加・**穴 2 の解消**）
>
> **欠損スロットは空配列として復元し、例外にしない。** `i ∈ [0, W)` のうち既存ドキュメントに `reading_i` が存在しない i について、`fromSource` は**要素 0 個のリスト**を復元する。**存在しないことを理由に例外を投げてはならない。**
>
> **決定者**: ユーザー ／ **決定日**: 2026-08-25 ／ **出典**: 作業プラン `20260822_implementation/0001` §7.2 の穴 2（ステップ 0-4 の作業内容 8）
>
> **なぜ定義が要るか** [確認]: **INV-1 が保証されるのは新バイナリが書いたドキュメントだけである。** `0003` §10.6 が定める **L1 期間**（L1 バイナリ ＋ 旧世代インデックス）に旧世代ドキュメントを multiGet で引くと、`reading_i` の本数が W と一致しない状態に入る。第 8 版までの本節は「`fromSource` の無限ループは廃止し `text` から導出した W で回す」と定めるだけで、**この場合の挙動を定義していなかった。**
>
> **保存される source では欠損が埋まる。** §5.3 の `readings` の合成規則は「位置ごとの和集合（existing 優先）」であり、**新 item 側は INV-1 により必ず W 本を持つ**ため、空配列のスロットには新 item 側の読みが入る。**欠損は次の書き込みで解消し、恒久的に残らない。**
>
> **INV-4（`reading_i` に `null` を書き込まない・§2.3(a)）と矛盾しない。** 本規定が定めるのは**読み取り時の復元値**であり、`null` を書き込むことを許すものではない。
>
> **余剰（i ≥ W）の `reading_i` は読まない。** 走査基準の単一化そのものであり、§5.6 の経路 A と同じく旧来から起きていた現象である（F-04 と同型）。
>
> **却下した案: 存在しないスロットで例外を投げる。** **被害が非対称だからである** — `0003` §10.6.3 の **M-1（L1 デプロイ直後の即時再構築）は運用手順であり、飛ばされうる。** 飛ばされた状態で欠損が例外になると、**1 件の旧世代ドキュメントで再構築全体が落ちる**（`0003` §10.4 が backup 復元について述べているのと同型の経路であり、`(fess) exec/SuggestCreator.java:258` はガードの外側である）。空配列として扱えば**再構築は完走し、新世代で INV-1 が回復する。** 一方、空配列扱いによる損失は「旧世代ドキュメントの余剰・欠損した読みが引き継がれない」ことだけであり、**これは全件再構築で元データから作り直される。**

> **コードレベルの同時性の要求**: **コンストラクタでの INV-1 強制と、§5.4 の `ElevateWord.toSuggestItem` の修正は、同一リリースに入れなければならない。**
>
> 現行の `ElevateWord.toSuggestItem`（`entity/ElevateWord.java:143-149`）は k ≠ W のとき INV-1 を破る。**強制だけを先行させると、読みトークン数と語数が食い違う elevate word の登録が実行時にすべて失敗する。** `(fess) helper/SuggestHelper.java:464-487` は管理画面の「読み」入力を空白分割して渡すだけであり、k ≠ W は実運用で普通に発生する。
>
> これは §4.7 が定めた**データ移行の束ね**とは別の、**コード変更の順序制約**である。両者を混同しないこと。§4.7 は「1 回の再構築に載せる」話であり、本注記は「1 回のリリースに入れる」話である。

### 5.3 フィールドごとの合成規則

`SuggestItemMergePolicy.initialize(SuggestCandidate incoming)` と `merge(SuggestItem existing, SuggestCandidate incoming)` の挙動を全フィールドについて定める。**`0001` §3.4 が `initialize` を別メソッドに分けているのは、`excluded` が「既存があれば触らない」規則だからである。**

> **第 4 版で引数型が変わった。** `0001` D-19 により incoming は `SuggestCandidate`（取り込み候補）、existing と戻り値は `SuggestItem`（保存されている完全状態）である。**下表の「incoming は `excluded` を書かない」「`userBoost` が指定なしなら existing を保持」は、第 3 版では実装が守るべき規約だったが、第 4 版では引数の型がそれを表す**（`SuggestCandidate` に `excluded` フィールドが無く、`userBoost` が `OptionalDouble` である）。**規則の内容は変わっていない。**

| フィールド | `initialize`（既存なし） | `merge`（既存あり） | 現行との差 | 根拠 |
| --- | --- | --- | --- | --- |
| `text` | incoming | **existing を保持** | 同じ（`SuggestItemMerger.java:67`） | ID が同一なら text も同一（INV-5） |
| `readings` | incoming（W 本） | **位置ごとの和集合**（順序維持・重複排除、existing 優先） | 走査基準のみ変更（§5.2） | `SuggestItemMerger.java:101-117` |
| `queryFreq` / `docFreq` | incoming | **加算** | 同じ | KEEP-03 |
| `kinds` | incoming | **集合和** | 同じ | `SuggestItemMerger.java:84,139-151` |
| `tags` / `roles` / `languages` / `fields` | incoming | **集合和**（順序維持・重複排除） | 同じ | `SuggestItemMerger.java:78-81,122-134` |
| `userBoost` | `incoming.userBoost()` が present なら その値、empty なら **1.0** | **present の incoming のみが上書き。empty なら existing を保持** | **変更**（現行は無条件上書き） | **DM-11**（下記） |
| `@timestamp` | incoming | **max(existing, incoming)** | **変更**（現行は無条件に incoming） | 下記 |
| `excluded` | **`false`** | **existing を保持**（`SuggestCandidate` は `excluded` を持たないため、書きようがない — `0001` D-17） | **新規** | U4 |

#### `userBoost`: 「指定あり／なし」の導入（DM-11）

**F-06 ③ の解消はここで行う。** 現行は `entity/SuggestItemSerializer.java:181` と `entity/SuggestItemMerger.java:88` がともに新 item で無条件上書きするため、`userBoost = 1` の通常取り込みが elevate word の boost を潰す。

**採る規則**: 取り込み候補の `userBoost` に「指定あり／なし」を区別できる表現を持たせ、**指定ありの incoming だけが既存値を上書きする**。指定なしの incoming は既存値に触れない。既存が無い場合の初期値は `1.0`。**表現は `SuggestCandidate.userBoost`（`OptionalDouble`）である**（`0001` D-16。第 3 版が採っていた補助 boolean `userBoostSpecified` は第 4 版で廃止された — 同書の改訂履歴）。

- **通常取り込み経路は「指定なし」**（`OptionalDouble.empty()` ／ `SuggestCandidate.document(...)`）とする。現行は `index/contents/DefaultContentsParser.java:107-108,:144` が `userBoost = -1` というセンチネルを渡し、`entity/SuggestItem.java:131-135` が「1 以下なら 1 に丸める」ことで実質 1 にしている。この 2 段構えを廃し、素直に「指定なし」として表現する。
- **elevate word 経路は「指定あり」**（`SuggestCandidate.elevate(...)`）とする（`entity/ElevateWord.java:147` が `getBoost()` を渡す）。

**この規則は MIG-04（`userBoost` の丸め撤廃）の受け皿でもある。** `entity/SuggestItem.java:131-135` の丸め（`userBoost > 1` でなければ 1）を撤廃すると、センチネル `-1` がそのまま格納されてしまう。**丸めを外せるのは「指定なし」という表現を導入したときだけ**であり、DM-11 と MIG-04 は分離できない。丸めの撤廃により `0 < userBoost < 1`（＝負のブースト）も表現可能になる。

> **この規則は可換ではない**（DM-19・第 5 版で追記）。「present の incoming が上書きする」は、**present の incoming が同一 `text` に 2 つ来ると後勝ちになる**。boost 2.0 の候補 A と boost 5.0 の候補 B では、A → B なら 5.0、B → A なら 2.0 である。**`0001` 第 4 版 §3.9.3 が「複数ソースの結果は順序に依存しない」と無条件に書いていたのは、この点について誤りだった。**
>
> **本書側の要求は 1 つである: `userBoost` を present にする候補を作ってよいのは elevate word 経路だけである。** `SuggestSource` は `SuggestCandidate.document(...)` のみを使う（`0001` 第 5 版の **D-27**）。この制約の下でのみ、合成は全フィールドについて可換になる。**規則そのものは変えない** — 競合規則（max / min / 平均）はいずれも下表の却下理由に抵触するためである。

**却下した代替案**:

| 案 | 却下理由 |
| --- | --- |
| **max(existing, incoming)** | 管理者が boost を **5.0 → 2.0 に引き下げられなくなる**。既存値が常に勝つため elevate word の編集が効かない |
| **既存が既定値（1）でない限り保持** | 同上。一度 5.0 を設定すると変更できない |
| **`kinds` に USER を含む incoming を優先** | 動作は同じだが、`kinds` は集合和で蓄積されるため「incoming が USER を含むか」と「既存ドキュメントが USER を含むか」が混同されやすい。**boost の指定は kind の副作用ではなく明示的な意図として表現すべき**である |

**`deleteElevateWord` は引き続きドキュメントごと削除する**（`index/operations/WordManagementOperations.java:129`）。boost だけを取り消す経路は設けない。この場合、その語に蓄積された `queryFreq` / `docFreq` も失われる（§8 の既知の制約）。

#### `@timestamp`: max を採る

現行は `entity/SuggestItemMerger.java:87` と `entity/SuggestItemSerializer.java:183` がともに無条件に新 item の値を採る。実際には `entity/SuggestItem.java:138` がコンストラクタで `ZonedDateTime.now()` を入れるため後退は起きにくいが、**「後退しないこと」がコードの都合ではなく規則として保証されている状態にする**ため max を採る。`@timestamp` の意味は「最終更新時刻」であり、単調非減少であるべきである。

#### `excluded`: 既存値を保持する（U4）／ 新規語は bad word 判定で初期化する（DM-21）

**取り込みのたびに bad word 除外が解除される事故を防ぐ。** `merge(existing, incoming)` は `existing.excluded` をそのまま引き写す。**`SuggestCandidate` は `excluded` を持たない**ため（`0001` D-17）、incoming 側から上書きされる経路が型として存在しない。

**既存ドキュメントが無い場合の初期値は、取り込み時点の bad word 集合が決める**（DM-21・第 7 版）。

| 分岐 | `excluded` の値 | 決める主体 |
| --- | --- | --- |
| 既存ドキュメントあり | `existing.excluded`（保持） | 合成規則（U4） |
| 既存ドキュメントなし ＋ bad word に非該当 | `false` | `initialize(candidate, false)` |
| **既存ドキュメントなし ＋ bad word に該当** | **`true`** | `initialize(candidate, true)`。判定は取り込み経路が `BadWordPolicy.isBadWord` で行い、値だけを渡す（`0001` §3.4 / §3.5.2） |

> **第 6 版までは 3 行目のケースでドキュメントが作られなかった**（取り込み時 drop）。**その結果、bad word 登録中に流入した語は `deleteBadWord` で復元できず、C-02 の「可逆」が新規流入について成立していなかった。** 廃止の根拠と代償の扱いは §6.5 にある。

`excluded` を**既存ドキュメントに対して** `true` / `false` に反転させるのは **`BadWordPolicy`（`0001` §3.5）が駆動する専用経路のみ**とする。bad word の登録で該当語に `true` を、解除で `false` を明示的に設定する。**合成規則が `excluded` を変えることは無い**（新規作成時に初期値を決めるだけである）。

> **解除の対象は「その bad word に該当する語」ではない**（DM-18・第 5 版）。判定規則は部分一致であるため（`0001` D-6）、**1 つの語が複数の bad word に同時に該当しうる**。bad word `foo` と `bar` が登録された状態でサジェスト語 `foobar` は両方に該当し、`foo` だけを削除して「`foo` を含む語」を一律 `excluded = false` にすると、**まだ `bar` に該当している `foobar` まで復活する**。
>
> **正しい対象は「削除後の bad word 集合のいずれにも該当しない語」である。** 条件の生成は `BadWordPolicy.releaseCondition(String)` が持ち、`QueryCondition.mustNotContain` で表す（`0001` 第 5 版の **D-25** ／ 同書 §3.5.1）。**付与側は単調であるため影響を受けない** — 非対称なのは解除だけである。
>
> **データモデル側の帰結は無い。** `excluded` は boolean のままであり（「該当する bad word のリスト」に変えると DM-14 の否定形フィルタの前提が崩れる）、mapping も変わらない。**本書が持つのは「`excluded` の真偽が何を意味するか」であり、第 5 版でその意味が「現在の bad word 集合のいずれかに該当する」と精密化された。**

> **この同値関係は操作の途中では成立しない**（DM-20・第 6 版）。bad word の登録・取り消しは
>
> | # | 手順 | 書き込み先 |
> | --- | --- | --- |
> | 1 | `BadWordPolicy.add` / `remove` — bad word 集合の更新 | **設定インデックス** |
> | 2 | `SuggestStore.updateExcluded(condition, …)` — 既存語の `excluded` 更新 | **suggest インデックス（本書の対象）** |
>
> という**2 リクエストの 2 段書き込み**であり（`0001` §2.3.1 / §3.5.1）、**2 が失敗すると同値関係が破れた状態が残る。**
>
> | 失敗した操作 | 残る状態 |
> | --- | --- |
> | `addBadWord("foo")` の 2 | 集合に `foo` があるのに、`foo` を含む既存語が `excluded = false` のまま**検索に出続ける** |
> | `deleteBadWord("foo")` の 2 | 集合から `foo` が消えているのに、`foo` にしか該当しない語が `excluded = true` のまま**検索に出てこない** |
>
> **本書は分散トランザクションを要求しない。** 代わりに **DM-18 の同値関係を「操作が完了している限りにおいて成立する」条件つきの不変条件**として読み、**破れた状態からの回復手段を「同一操作の再実行」と定める**。これが成立するのは、**手順 2 の条件が手順 1 の差分ではなく「現在の bad word 集合」から毎回再計算されるためである**（`releaseCondition` の定義がまさにそれである — `0001` §3.5.1）。契約と収束表の正は `0001` §2.3.1（D-29）にあり、**本書側の帰結は「`excluded` の意味を読むときに『操作が完走していること』を前提に置く」ことだけである。**
>
> **`excluded` を「該当する bad word のリスト」に変えれば 2 段目が冪等な集合演算になり収束が自明になる、という案は DM-18 で既に却下している**（DM-14 の否定形フィルタの前提が崩れるため）。収束性は型ではなく操作の定義で担保する。

これは bad word の適用方式そのものの変更である。現行は 2 つの独立した仕組みで実現されている [確認]。

| 現行の仕組み | 実装 | 本設計での扱い |
| --- | --- | --- |
| ① 既存ドキュメントの**物理削除**（`apply=true` 時） | `index/operations/WordManagementOperations.java:77-84` の wildcard `deleteByQuery` | **廃止**。`excluded = true` の設定に置換（C-02） |
| ② 取り込み時の**フィルタ除外** | `index/operations/IndexingOperations.java:78` が `entity/SuggestItem.isBadWord`（`:455-462`）で item を配列から取り除く | **廃止**（第 7 版 / DM-21）。同じ判定位置で **`initialize` に渡す `excluded` 初期値を決める**形に変える（`BadWordPolicy.isBadWord` に移設 — `0001` §3.5.2）。第 6 版までは「維持」としていた |

現行 ① は不可逆であり、`deleteBadWord`（`WordManagementOperations.java:91-93`）は設定から語を削除するだけで**削除済みドキュメントを復元しない**。C-02 が「即時・可逆な論理除外」を選んだ理由がこれである。**第 6 版までの本設計は ① だけを可逆化し、② の不可逆性を残していた** — ② も同じ不可逆性であることは §6.5 で扱う。

### 5.4 `ElevateWord` の読みセマンティクスの確定（DM-12）

**ステップ 4（`reading_*` 方針 — `0000` §5.3）が [要確認] として申し送った解釈問題を本節で解消する。** 同ステップは「1 語に対する k 個の代替読み」と「k 語それぞれの読み」の 2 解釈を挙げ、判別不能としていた。

#### 判定: 後者（**位置対応**）が正である [確認]

決め手は `(fess) helper/SuggestHelper.java:464-487` の**読み未入力時のフォールバック**である。

```java
if (StringUtil.isBlank(reading)) {
    readings = word.replace("　", TEXT_SEP).replaceAll(TEXT_SEP + "+", TEXT_SEP).split(TEXT_SEP);   // :468
} else {
    readings = reading.replace(...).split(TEXT_SEP);                                                // :470
}
```

**読みが未入力なら「単語そのものを空白分割したもの」を読みとして使う。** この既定は常に「読みトークン数 ＝ 語数」を作る。すなわち**入力仕様は位置対応を前提としている**。

これは検索側とも整合する [確認]。`request/suggest/SuggestQueryBuilder.java` は、クエリ語のインデックス `i` に対して `reading_i` を引き（`:86`）、**同一語の読み候補は `should`（OR、`minimumShouldMatch(1)`）で束ね**（`:101-108`）、**語どうしは `must`（AND）で連結する**（`:112`）。つまり「1 つの `reading_i` フィールドに複数値」が読み候補の正しい表現形であり、「複数のフィールドに 1 値ずつ」は語の並びを意味する。

通常経路（`index/contents/DefaultContentsParser.java:86-107`、`:141`、`:185-195`）も一貫して「第 1 次元＝語位置、第 2 次元＝その語の読み候補」で `String[][]` を組み立てている。`getMaxReadingNum`（既定 10、`converter/ReadingConverter.java:31-33`）が制限するのは**第 2 次元**であり、F-02 の内容と一致する。

#### ステップ 4 が示した修正形の訂正（E-22）

同書は「`ElevateWord.toSuggestItem` を 1 語 × k 候補形（`new String[][] { allReadings }`）に修正するのが先」としているが、**この修正形は W > 1 の elevate word で成立しない。**

`entity/ElevateWord.java:144-146` は `text` を `new String[] { this.getElevateWord() }` の 1 要素配列にするが、`entity/SuggestItem.java:116` が空白で結合するため、**`elevateWord` が「東京 タワー」なら W = 2 になる**（§1.1）。`allReadings` を 1 スロットに入れると `readings.length = 1 ≠ W = 2` となり、INV-1 を別の形で破る。加えて 2 語のフレーズを 2 語のクエリで引くには `reading_0` と `reading_1` の両方が要る（`SuggestQueryBuilder.java:112` の AND）ため、**検索でヒットしなくなる**。

同書の「複数の読みを持つ elevate word はすべて INV-1 に違反する」という記述も、正確には「**読みトークン数 k と語数 W が食い違うときに違反する**」である。W = 1 の単語に 2 つの読みを与えた場合は違反するが、W = 2 のフレーズに 2 つの読みを与えた場合は違反しない。

#### 採る規則

> **`ElevateWord.toSuggestItem` は `text` を空白分割して `String[W]` とし、`readings` を W 個のスロットに次の規則で割り当てる。**
>
> | 条件 | 割り当て |
> | --- | --- |
> | **W == 1** | `readings[0] = { 全 k トークン }`（1 語に対する代替読みとして扱う） |
> | **W > 1 かつ k == W** | `readings[i] = { token[i] }`（位置対応） |
> | **W > 1 かつ k > W** | 位置対応。**余剰トークンは切り捨てる** |
> | **W > 1 かつ k < W** | 位置対応。**不足分は `readings[i] = { words[i] }`（語自身）で補う**（`SuggestHelper.java:468` の既定と同じ） |

**W == 1 を特別扱いする理由**: 位置対応の解が一意に定まらない唯一のケースだからである。W = 1 に対して k > 1 のトークンが与えられたとき、位置対応で解釈すると 2 番目以降を捨てるしかない。一方、`SuggestQueryBuilder.java:101-108` が同一フィールド内の複数値を OR で引く性質により、**すべてを `reading_0` に入れれば全候補が検索で活きる**。捨てるより活かす方が管理者の入力を尊重する。

この規則は W == 1 を位置対応の特殊解（「全トークンが第 0 語の候補」）と読めるため、規約としての一貫性も保たれる。

**現行の挙動と、この規則で変わること** [確認]:

| ケース | 現行の格納 | 現行の検索到達性 | 新規則の格納 |
| --- | --- | --- | --- |
| `東京`＋読み `トウキョウ` | `reading_0 = [トウキョウ]` | 到達可 | 同じ |
| `東京`＋読み `トウキョウ トーキョー` | `reading_0 = [トウキョウ]`, `reading_1 = [トーキョー]` | **`トーキョー` は到達不能**（単一語クエリは `reading_0` しか引かない） | `reading_0 = [トウキョウ, トーキョー]`（**両方が到達可**） |
| `東京 タワー`＋読み `トウキョウ タワー` | `reading_0 = [トウキョウ]`, `reading_1 = [タワー]` | 到達可 | 同じ |
| `東京 タワー`＋読み `トウキョウ` | `reading_0 = [トウキョウ]` のみ | **2 語クエリで 0 件**（`reading_1` が無い） | `reading_0 = [トウキョウ]`, `reading_1 = [タワー]`（到達可） |

**副次的な効果** [確認]: `request/popularwords/PopularWordsRequest.java:213` は `mustNot(existsQuery("reading_1"))` により単一語のみを人気語として扱う。現行では「単語に読みを 2 つ付けた elevate word」が `reading_1` を持つため人気語から除外される。新規則ではこれが解消する。

**「1 語に対する代替読み」を W > 1 のフレーズに対して指定する方法は、現行の入力形式（単一の読み入力欄・空白区切り）では表現できない。** 表現するには入力形式の拡張が要るため、後続スコープとする（§9）。

**この変更は既存 elevate word の格納形を変える。** 既存ドキュメントの読み替えはできないため、§4.7 の再構築に載せる。

### 5.5 バッチ内マージと既存ドキュメントマージの同一化

現行は `entity/SuggestItemMerger`（バッチ内）と `entity/SuggestItemSerializer.toUpdatedSource`（既存ドキュメント）が**別々の実装**であり、規則が食い違っている（`readings` の走査基準、`userBoost` の扱いは同じだが、`kinds` の合成経路が異なる）。

> **`SuggestItemMergePolicy` の実装 1 つが両方を担う。** `index/writer/SuggestWriter.mergeItems`（`:76-102`）と `index/writer/SuggestIndexWriter.write`（`:44-80`）は、どちらも同じ `merge(existing, incoming)` を呼ぶ。

**畳み込みの形**（`0001` §3.7.1 の第 7 版で確定）:

```text
既存あり: item = merge(existing, c1); item = merge(item, c2); ...
既存なし: item = initialize(c1, isBadWord(text)); item = merge(item, c2); ...
```

**`initialize` はバッチ内で ID ごとに高々 1 回しか呼ばれない。** したがって **bad word 判定も ID ごとに 1 回**であり、同一 `text` の候補が何件来ても結果は変わらない（DM-21 の下でもバッチ内マージの結果は候補数に依存しない）。

`entity/SuggestItem.merge(SuggestItem, SuggestItem)`（`:446-448`、static）と `entity/SuggestItemMerger` は本 IF の実装へ移設し、エンティティから合成ロジックを外す（`0001` §3.4）。

**`SuggestItemMergePolicy` は Java 側の単一の正である。** 検証タスク（`20260706_opensearch_reference/0005-schema-draft.md`）は Painless スクリプトを権威とする前提でスキーマを設計しているが、本設計では採らない（E-03 / C-03）。

> **第 7 版でこの「単一の正」が無条件に成立するようになった**（`0001` D-31）。第 6 版までは `SuggestStore.bulkUpsert` が `SuggestItemMergePolicy` を引数に取る形だったため、**「MIG-15 第 2 段で `scripted_upsert` を載せる場合、その挙動が `SuggestItemMergePolicy` と一致することは実装側の責務である」という条件付きの主張**しかできなかった（これは任意のカスタム MergePolicy については実現不能な要求だった）。第 7 版は `SuggestStore` を `multiGet` / `bulkPut` の永続化境界に限定し、**合成を常に Java 側の 1 実装が行う**形にした。第 2 段の原子マージ能力と合成規則の関係は、その段で設計する（`0001` §3.7.1 / 同 §10 の申し送り 18）。

### 5.6 F-04 の解消（DM-13）

> **F-04（`reading_i` の消滅）は INV-1 の確立によって構造的に解消される。** `OpType.INDEX` の全置換は維持する。

**理由**: 同一 ID ⇒ 同一 `text`（INV-5）⇒ 同一 W。INV-1 により既存ドキュメント側の `reading_i` の本数も新 item 側の本数も W に等しい。したがって**「既存にのみ存在する `reading_i`」が原理的に存在しなくなる**。`toUpdatedSource` が新規 Map を構築しても落ちるものが無い。

> **前提の限定**（第 9 版で追加）: **ただしこれは既存ドキュメントが INV-1 強制後のバイナリで書かれている場合に限る。** **L1 期間に旧世代ドキュメントを読む場合は成立せず、`0003` §10 の L1 期間の節（§10.6）が扱う。** 旧世代ドキュメントは INV-1 未強制の旧バイナリで書かれており、`reading_i` の本数が W と一致しない。**その場合の走査時の挙動は §5.2 の [確定]（欠損スロットは空配列として復元する）が定める。**

全置換を `OpType.UPDATE`（部分更新）に変えることは**しない**。`SuggestItemMergePolicy` が既存ドキュメント全体と新 item を受け取って完全な source を返す設計であり、部分更新の必要が無いためである。

> **全置換の前提**: この設計は「**書き込む source の全属性を、マージの戻り値の型が保持していること**」に依存する。型に無い属性は全置換で必ず失われる。**`excluded` がこれに該当する**（§5.3 の合成規則は既存値の保持を要求する — U4）。`0001` 初版・第 2 版は `SuggestItem` から `excluded` を外していたため、本節の全置換と組み合わせると**取り込みのたびに bad word 除外が解除される**。ステップ 7 の通し整合レビューでこの食い違いを検出し、**`0001` 第 3 版が `excluded` を `SuggestItem` に戻した**（`0001` D-17）。
>
> **第 4 版で前提の担保の仕方が変わった。** `0001` D-19 の 3 型分離により、マージの戻り値は `SuggestItem`（保存される完全状態）、引数の incoming は `SuggestCandidate`（`excluded` を持たない）となった。**「戻り値の型は全属性を持つ」と「取り込み側は `excluded` を書けない」が別々の型で表され、生成 API の分離という規約に頼らなくなった。** 第 3 版までは `public record` の canonical constructor から規約を破れたため、この前提は文章上のものにとどまっていた（`0001` §2.6.1 の 3）。

**現行で実際に消滅が起きる経路** [確認]。既存資料の記述を 2 点訂正する。

| 経路 | 成否 | 説明 |
| --- | --- | --- |
| 作業プランの例（「2 語クエリで登録された doc に 1 語クエリが来ると `reading_1` が失われる」） | **成立しない** | ID は `text` のみから作られるため、語数の異なる入力は別 ID の別ドキュメントになる（E-07 で訂正済み） |
| **経路 A: elevate word の読み件数の変更** | **成立する** | 同一 `elevateWord`（＝同一 ID）に対し、管理画面から読みトークン数 k を減らして再登録すると、`toUpdatedSource` が新 item の `readings.length` でしか回さないため、余剰の `reading_i` が消える。`restoreElevateWord`（`WordManagementOperations.java:140-157`）が全 elevate word を再適用するため、設定変更のたびに再現しうる |
| **経路 B: ID 切り詰めによる衝突** | **成立する**（稀） | §4.3 のとおり 334 バイト以上の異なる text が同一 ID を持つと、W が異なるまま同一ドキュメントに合流する |

**経路 A は INV-1 の確立（§5.4）で、経路 B は ID のハッシュ化（§4.1）で消える。** どちらも本書の他節の決定に吸収され、F-04 のための個別の対処は要らない。

---

## 6. 旧世代インデックスとの共存

### 6.1 何が共存するのか

**ドキュメントのスキーマは共存しない**（§4.7）。ID 方式が変わるため、旧世代インデックスに書き足しながらの移行は成立しない。

**読み取り経路について**共存が問題になるのは **`excluded` フィールドの有無**だけである。MIG-13 を適用したコードが、`excluded` を持たない旧世代インデックス（MIG-13 適用前に作られたもの）を検索する期間が存在しうる。エイリアス切替の前後で検索側のコードは同一であるため、**検索クエリは両方のスキーマで正しく動かなければならない**。

> **共存範囲の限定**（第 9 版で追加）: **書き込み経路の共存は `0003` §10 の L1 期間の節（§10.6）が扱う。** 第 8 版までの本節は「共存が問題になるのは `excluded` の有無だけである」と宣言し、**書き込み側の共存を §6 の議題から外していた**（§6.2 / §6.3 が扱うのは読み取り経路だけである）。**しかし新 ID バイナリが旧世代インデックスへ書き込む期間は現実に存在する** — L1 デプロイから初回再構築までの窓であり、**そこでは同一語が旧 ID と新 ID の 2 ドキュメントに分裂する**（`0003` K-19）。**この区間の運用は本書ではなく `0003` §10.6 が定める。**

### 6.2 否定形フィルタの必須化（DM-14）

> **除外フィルタは `mustNot(termQuery("excluded", true))` としなければならない。**
> **`must(termQuery("excluded", false))` は禁止する。**
> **これは suggest 本体インデックスを読む「すべての」クエリ経路に適用する。**

**否定形でなければならない理由**: `excluded` を持たない旧世代ドキュメントは `term("excluded", false)` に**一件も一致しない**。肯定形を使うとサジェスト結果が全滅する。否定形なら、フィールドが存在しないドキュメントは「`true` ではない」として通る。

これはデータモデル側の理由づけであり、切替手順そのものは `0003` が持つ。

#### 適用対象は 2 経路である

**suggest 本体インデックスを読むリクエストは 2 つしかない** [確認]（`request/` 配下の実装は `request/suggest/` と `request/popularwords/` の 2 系統のみ）。**両方に付ける。**

| 経路 | 組み込み位置 |
| --- | --- |
| **サジェスト検索** | `request/suggest/SuggestRequest.java:346` の `filterList` に `boolQuery().mustNot(termQuery(FieldNames.EXCLUDED, true))` を**無条件に追加**する。同 `:370` が `filterList` の各要素を `filter` 節として合成する |
| **人気語** | `request/popularwords/PopularWordsRequest.java:211-235`（`buildQuery`）のトップレベル `BoolQueryBuilder` に `mustNot(termQuery(FieldNames.EXCLUDED, true))` を**無条件に追加**する。同 `:213` の `mustNot(existsQuery("reading_1"))` と並ぶ位置である |

**条件付きで付けない（例: 「新スキーマのときだけ付ける」）ことはしない** — インデックス世代を検索時に判定する手段を持たないためである。

`FieldNames`（`constants/FieldNames.java`）に `EXCLUDED = "excluded"` を追加する。現行に該当定数は無い。

#### 既存の `excludeWords` 機構は代替にならない [確認]

人気語には既に除外の仕組みがある（`PopularWordsRequest.java:87`, `:165-166`, `:229-230` の `excludeWords`）。**これで足りるとする案は採らない。** 理由は 2 つあり、いずれも決定的である。

| # | 理由 |
| --- | --- |
| 1 | **判定意味論が違う。** `excludeWords` は `termsQuery(FieldNames.TEXT, excludeWords)` による**完全一致**である（`:230`）。bad word の意味論は**正規化後テキストの部分一致**であり（C-02 / `0001` §3.5 の D-6、`improvement-proposal.md:380`）、完全一致では bad word を部分文字列として含む語を捕まえられない |
| 2 | **語の集合が違う。** `excludeWords` に積まれるのは fess の静的プロパティ `suggest.popular.word.excludes`（`(fess) mylasta/direction/FessConfig.java:1732`）を `(fess) helper/PopularWordHelper.java:104,118` が展開したものであり、**管理画面が管理する bad word 集合とは無関係**である。両者を混ぜると `BadWordPolicy` が bad word 集合の唯一の所有者であるという `0001` §3.5（D-7）の設計が崩れる |

**`excludeWords` は廃止せず、現行の用途（人気語表示から特定の語を静的に外す）のまま残す。** MIG-13 の論理除外とは目的が異なる独立した機構である。

#### `previewBadWordImpact` の件数の定義

`0001` §2.3 の `previewBadWordImpact(word)` が返す `BadWordImpact.matchedCount`（`0001` §2.5）を次のとおり定める。

> **`matchedCount` は `BadWordPolicy.matchCondition(word)` に一致する全ドキュメントの件数であり、`excluded` の現在値では絞り込まない。** すなわち**他の bad word によって既に `excluded = true` になっている語も件数に含む**。

理由は 2 つある。

1. **`matchCondition` は「`excluded` の付与とドライランが共有する」条件である**（`0001` §3.5 の Javadoc）。解除は `releaseCondition`（DM-18 ／ `0001` D-25）が別に持つが、**その中核も `mustContain(text, removed)` であり、`excluded` の現在値では絞り込まない** — 解除（`true` → `false`）は既に `excluded = true` の語を対象にするため、**条件そのものに `excluded` の絞り込みを含めると解除経路が動かない**。
2. 「この bad word を適用すると何語が除外されるか」という問いの答えは、**その bad word が支配する語の総数**である。既に除外済みの語を数から外すと、bad word を 1 つ削除したときに何が戻るかが分からなくなる。総数であれば bad word の追加順序に依存せず、冪等である。

**「うち新たに `excluded` が `false` → `true` に変わるのは何件か」を別に示したい場合は `BadWordImpact` にフィールドを足すことになり、`0001` §2.5 の改訂にあたる。** 本書は総数のみを定義し、内訳は設けない。

### 6.3 `excluded` を持たないドキュメントの意味

**「`excluded` が無い」＝「除外されていない」と解釈する。** `null_value` を mapping に置かないのはこのためである（§2.1）。mapping で `null_value: false` を指定しても、**フィールドそのものが存在しない旧世代ドキュメントには適用されない**（`null_value` は「値が `null` として明示的に書かれた場合」にのみ効く）ため、肯定形フィルタの問題は解決しない。

新世代のドキュメントには `initialize` が必ず `false` または `true` を書き込む（§5.3）ため、この曖昧さは再構築の完了とともに消える。

### 6.4 レイテンシ計測の申し送り

**MIG-13 の実施時に、除外フィルタ付与の前後でレイテンシ差分を計測項目に含めること。** `filterList` に節が 1 つ増えるコストは小さいと見込まれるが **[推測]**、本設計は性能実測を行っていない（C-04）。後続タスクへの申し送りである。

**第 7 版では計測対象が 1 つ増える**（DM-21）。除外フィルタの**述語の数**は変わらないが、**インデックスに残る除外語のぶんドキュメント数が増える**ため、**「同一データ・同一 bad word 集合で、drop するモデルと保存するモデルのドキュメント数・インデックスサイズ・検索レイテンシを比較する」**を計測項目に加える。増分の大きさは bad word の登録数と部分一致の広さに依存し、**設計時点では見積もれない**（C-04）。

### 6.5 取り込み時 drop の廃止（DM-21・第 7 版）

**§5.3 の表 ② を「維持」から「廃止」に変えた根拠を本節に置く。**

#### 何が矛盾していたか [確認]

| 出典 | 記述 |
| --- | --- |
| `0000` §5 の **C-02** | bad word の適用方式は「**即時・可逆な論理除外**」。①物理削除は明示オプションとしても残さない |
| 第 6 版 §5.3 の表 | ① 物理削除は**廃止** ／ ② 取り込み時のフィルタ除外は**維持** |
| 第 6 版 §5.3 の本文 | 「現行 ① は不可逆であり…C-02 が『即時・可逆な論理除外』を選んだ理由がこれである」 |
| 第 6 版 **DM-18** | `excluded == true` ⇔ 現在の bad word 集合のいずれかに該当する |

**② も ① と同じ不可逆性を持つ。** ① は「既に保存された語を消す」、② は「保存されるべき語を作らない」であり、**どちらも `deleteBadWord` で元に戻せない**という点で同じである。第 6 版は ① の不可逆性を理由に物理削除を廃止しながら、② を「新規流入の防止」という別の目的として残していた。

**DM-18 の同値関係も、正確には「保存されているドキュメントに限り」成立していた。** drop された語はドキュメントが存在しないため同値関係の主語にならず、**bad word を解除しても `excluded = false` に戻す対象そのものが無い**。

#### 採る形と、それが変えるもの

> **bad word に該当する新規候補も保存する。`excluded = true` を初期値として書き込む。**

| 観点 | 第 6 版 | **第 7 版** |
| --- | --- | --- |
| **ドキュメントの有無** | bad word 該当語は作られない | **作られる**（`excluded = true`） |
| **DM-18 の適用範囲** | 保存されているドキュメントに限る | **全ドキュメント**（例外が無くなる） |
| **`deleteBadWord` 後の状態** | 該当語は消えたまま。頻度も失われる | **`excluded = false` に戻り、蓄積された `queryFreq` / `docFreq` がそのまま復活する** |
| **`previewBadWordImpact` の意味** | 「これから除外される語」の数（既に捨てられた語は数えられない） | **その bad word が支配する語の総数**（§6.2 の定義がそのまま実態になる） |
| **mapping** | — | **変わらない**（`excluded` は boolean のまま） |
| **合成規則** | — | **変わらない**（`merge` は既存値保持、`initialize` が初期値を受け取る点だけが増える） |

#### 代償: インデックスに残る除外語

**定常状態のドキュメント数は「bad word に該当する語の全集合」ぶん増える。** 第 6 版のモデルではこれが 0 だった。**全件再構築でも drop しない**ため、再構築を重ねても減らない。

| 影響 | 扱い |
| --- | --- |
| 検索レイテンシ | 述語数は不変（DM-14 の否定形フィルタ 1 節のまま）。増えるのは転置索引の規模である。計測は §6.4 |
| ディスク・再構築時間 | 増える。増分は実測依存（C-04） |
| 語数統計（`WordCountStats`） | **`excluded = true` のドキュメントを含む件数になる。** `0003` §4.2 の G1（件数の絶対下限）は**下限**の判定であるため、増える方向の変化で誤判定を起こさない。**ただし移行前後で件数を比較する運用者に対しては、増加の理由を説明できる必要がある**（`0003` §4.1 の「新旧の件数は単純一致しない」に 1 行追加した） |
| **物理削除したい運用** | **`deleteByCondition` に `mustMatchAny("excluded", ["true"])` を渡す**（`0001` §2.4 / §3.6）。**不可逆であり、ライブラリが自動で行うことは無い。** 運用手順は `0003` §12.1 |

> **これは C-02 の「①物理削除は明示オプションとしても残さない」に反しない。** C-02 が禁じたのは ***bad word の適用方式として*** 物理削除を選ぶことである。`addBadWord` は常に論理除外であり、物理削除は「インデックスを掃除する」という別の操作として、bad word の登録とは独立に運用者が実行する。

---

## 7. テスト仕様

**実装は後続タスク（P10）。本節はテストの仕様のみを定める。**

### 7.1 既存テストのうち意図的に変える差分

**現行と同一結果になるべきものと、意図的に変えるものを区別する**（作業プラン §3 ステップ 5-3 の完了条件）。

| 既存テスト | 現在検証している内容 | 本設計での扱い |
| --- | --- | --- |
| `SuggestItemMergerTest`（`testMerge_frequencies` / `_tags` / `_roles` / `_fields` / `_languages` / `_preservesText` / `_preservesId`） | 頻度加算・集合和・text 保持 | **変えない。** 現行と同一結果になることを回帰として維持する |
| `SuggestItemMergerTest.testMerge_frequencies` のコメント `// max(1.0, 2.0)` | 実装は item2 採用であり、コメントと食い違っている [確認] | **意図的に変える。** DM-11 により「指定ありの incoming のみ上書き」になる。コメントの誤りも正す |
| `SuggestItemTest.testMerge`（`:267-298`） | `userBoost` は item2 採用 | **意図的に変える**（DM-11） |
| `SuggestItemTest.testUserBoostMinimum` / `test_userBoostZero` / `test_userBoostNegative`、`SuggestItemBoundaryTest:212-231` | `userBoost <= 1` を一律 `1.0` に丸める | **意図的に変える。** MIG-04 により丸めを撤廃する |
| `SuggestItemSerializerTest:138`、`SuggestItemTest:214`、`SuggestItemBoundaryTest:256,267` | `score` が source に含まれ `(queryFreq + docFreq) * userBoost` であること | **意図的に変える。** MIG-02 により `score` を廃止する（該当アサーションを削除） |
| `SuggestUtilTest.testCreateSuggestTextId`（`:99-117`）、`testCreateSuggestTextIdBoundaryExactly445`（`:490-502`）、`testCreateSuggestTextIdBoundaryJustUnder445`（`:505-516`） | ID が `Base64.getEncoder().encodeToString(...)` と完全一致すること | **意図的に変える。** ハッシュ化により Base64 生値との一致は成立しない |
| `SuggestUtilTest.testCreateSuggestTextIdWithLongText`（`:120-130`） | 長文の ID 長が正確に 445 であること | **意図的に変える。** 43 文字固定になる |
| `SuggestItemBoundaryTest.test_getId_sameTextSameId` / `_differentTextDifferentId` / `_multiWordOrder`（`:538-576`） | 同一 text → 同一 ID、異なる text → 異なる ID | **変えない。** ハッシュ化後も成立すべき意味論であり、**むしろ本設計が強化する不変条件そのもの**である |
| `ElevateWordTest.testToSuggestItemWithCompleteData`（`:198-244`）、`testMultipleReadingsConversion`（`:399-417`） | k 個の読みが `readings.length == k` の各 1 要素配列になること | **意図的に変える。** DM-12 により W に基づく割り当てになる。**このテストは現行の不具合を仕様として固定していた** |

### 7.2 新規に必要なテスト

| # | 対象 | 検証内容 | 由来 |
| --- | --- | --- | --- |
| T-1 | **頻度集約の回帰**（refresh 廃止後） | 同一語が連続バッチに現れるケースで `queryFreq` / `docFreq` が正しく集約される。refresh を挟まずに検証する（realtime get に依存することの明示 — §4.5） | 申し送り 2 |
| T-2 | **頻度集約の回帰**（multiGet 化後） | T-1 と同一の検証を MIG-15 第 1 段の実装に対して行う | 申し送り 2 |
| T-3 | **新 ID 方式の同一性** | 同一 text が同一 ID に落ちること。長さが 43 文字固定であること。**334 バイト以上の異なる text が異なる ID を持つこと**（F-05 の回帰） | §4.1 / §4.3 |
| T-4 | **INV-1 の強制** | `readings.length != W` の `SuggestItem` を構築しようとすると失敗すること。**前提: §5.4 の `ElevateWord` 修正が同一リリースに入っていること**（下記） | §5.2 / §5.4 |
| T-5 | **INV-2 の強制** | 語に空白を含む入力が拒否または分割されること（ISS-05 の回帰） | §5.2 |
| T-6 | **INV-3 の切り捨て** | N を超える語数の入力で先頭 N 語だけが残り、`text` と `readings` が同時に切れること | §2.3(b) |
| T-7 | **`userBoost` の合成** | 「elevate word で boost 5.0 を設定 → 通常取り込み → boost が 5.0 のまま」「管理者が 2.0 に変更 → 2.0 になる」の両方 | §5.3 / F-06 ③ |
| T-8 | **`excluded` の保持** | 「bad word 登録で `excluded = true` → 通常取り込み → `true` のまま」「bad word 解除 → `false`」 | §5.3 / U4 |
| T-9 | **`ElevateWord` の割り当て** | §5.4 の 4 ケース表をそのままテストにする。特に W == 1 で k > 1 のとき全候補が `reading_0` に入ること | §5.4 |
| T-10 | **`reading_i` が消えないこと** | elevate word の読み件数を減らして再登録しても、W が同じである限り `reading_i` の本数が変わらないこと（F-04 の回帰・経路 A） | §5.6 |
| T-11 | **旧世代共存** | `excluded` を持たないドキュメントが `mustNot(term(excluded,true))` フィルタを通過すること。**`must(term(excluded,false))` では 0 件になること**（禁止規則の根拠を明示する negative test） | §6.2 |
| T-11b | **人気語経路の除外** | `excluded = true` の語が **`PopularWordsRequest` の結果に現れないこと**。あわせて、bad word に部分一致するだけの語（＝ `excludeWords` の完全一致では捕まえられない語）が除外されることを検査する。**この 2 経路を別々に検査しないと、サジェスト側だけ塞いで人気語側から漏れる状態を検知できない** | §6.2 |
| T-11c | **`previewBadWordImpact` の件数** | 既に他の bad word で `excluded = true` になっている語も `matchedCount` に含まれること。同じ bad word に対して 2 回呼んでも件数が変わらないこと（冪等） | §6.2 |
| T-12 | **mapping の受理** | To-Be mapping（§2.1）で `reading_10` 以降が動的に受理されること。`reading_i` に `null` を書くと失敗すること。`[]`（空配列）は受理されること | §2.2 / §2.3(a) |
| **T-15** | **ID 衝突・ID 生成バグの検出** | ID が一致し `text` が一致しない組（テストでは ID 生成を差し替えて人為的に作る）を取り込むと、**`IngestResult.failures` に積まれ、バッチ全体は落ちない**こと。既存ドキュメントとの突き合わせ経路とバッチ内重複判定経路の**両方**で検出されること | §4.4.1 / DM-16 |
| **T-16** | **切り捨てによる集約** | 先頭 N 語が一致し N+1 語目が異なる 2 つの入力が、**同一 `text`・同一 ID に集約され頻度が加算される**ことを**仕様として固定する**（バグではない）。あわせて **OB-1 の切り捨て件数が 2 件としてカウントされる**こと | §2.3(b) / DM-17 |
| **T-17** | **`SuggestCandidate` に `excluded` が無いこと** | `excluded = true` のドキュメントに対し、`SuggestCandidate` を経由する取り込みを行っても `excluded` が `true` のまま保たれること。**T-8 の型レベルでの担保にあたる回帰**であり、`0001` D-17 の「型として成立する」が実装で崩れていないことを検査する | §5.3 / `0001` D-19 |
| **T-19** | **bad word の重複マッチ解除**（DM-18 / `0001` D-25） | `foo` と `bar` を登録し、`foobar` が `excluded = true` になった状態から **`foo` だけを削除しても `foobar` の `excluded` が `true` のまま**であること。続けて `bar` も削除すると `false` に戻ること。あわせて **`foo` にだけ該当する語（例 `foobaz`）は `foo` の削除で `false` に戻る**こと。**この 3 点を 1 本のテストで固定する** | §5.3 / `0001` §3.5.1 |
| **T-20** | **`SuggestSource` が `userBoost` を指定しないこと**（DM-19 / `0001` D-27） | 既定 2 ソース（`DocumentSource` / `SearchWordSource`）および任意の `SuggestSource` 実装が返す `SuggestCandidate` の `userBoost` が**すべて `OptionalDouble.empty()`** であること。**契約を型で強制できないための回帰テスト**であり、違反すると複数ソースの合成が順序依存になる | §5.3 / `0001` §3.9.3 |
| **T-18** | **公開 DTO の不変性** | `SuggestItem` / `SuggestCandidate` から取得したコレクションを変更しようとすると失敗すること（`UnsupportedOperationException`）。**構築に渡したコレクションを後から変更しても、既に構築された DTO の内容が変わらない**こと（防御的コピーの検査） | `0001` D-20 / §2.6.5 |
| **T-22** | **bad word 該当語の新規取り込みが可逆であること**（DM-21 / `0001` D-32） | `addBadWord("foo")` 済みの状態から、**未登録の語 `foobar` を 100 回取り込む**。①`foobar` の**ドキュメントが作られ**、`excluded = true` であること（drop されないこと） ②その間 `foobar` がサジェスト結果にも人気語にも現れないこと（DM-14 の否定形フィルタが効く） ③**`deleteBadWord("foo")` の後、`foobar` が `excluded = false` になり、`queryFreq` が 100 であること**。**③ が第 6 版のモデルでは成立しなかった検証点である** — drop していると復元対象そのものが存在しない | §5.3 / §6.5 |
| **T-23** | **`initialize` の呼び出し回数がバッチ内候補数に依存しないこと**（DM-21 / §5.5） | 同一 `text` の候補を 1 バッチに N 件含めて取り込み、**`excluded` の判定（`isBadWord`）が ID あたり 1 回しか行われず**、結果が N に依存しないこと。**既存ドキュメントがある場合は `initialize` が 1 回も呼ばれない**こと（＝ bad word 判定が既存語の `excluded` を上書きしないことの回帰。T-8 / T-17 と対になる） | §5.5 / `0001` §3.7.1 |
| **T-21** | **2 段書き込みの部分適用と再実行収束**（DM-20 / `0001` D-29） | **`SuggestStore.updateExcluded` を 1 回だけ失敗させるスタブ**を使い、次の 2 ケースを検査する。**delete**: `foo` / `bar` 登録済み・`foobar` / `foobaz` が `excluded = true` の状態から `deleteBadWord("foo")` を呼び、①`policy.remove` は成功し `updateExcluded` が失敗して `SuggesterException` になること ②この時点で `foobaz` が `excluded = true` のまま（＝部分適用）であること ③**同じ `deleteBadWord("foo")` を再実行すると `foobaz` が `false`・`foobar` が `true` になる**こと。**add**: 未登録状態から `addBadWord("foo")` を呼び、①同様に失敗し ②`foo` を含む語が `excluded = false` のまま残り ③**再実行で `true` になる**こと。**あわせて 1 段目の冪等性**（再実行時に `policy.remove` / `add` が例外を投げない）を検査する | §5.3 / `0001` §2.3.1 |

### 7.3 テストが到達できない範囲

- **F-10（ロストアップデート）の回帰テストは書かない。** 解消がスコープ外（§4.6）であり、再現には複数呼び出し元の同時実行という不安定な条件が要る。
- **性能に関する検証は含まない**（C-04）。§6.4 のレイテンシ計測、§2.3(b) の term 数、`total_fields.limit` の妥当性はいずれも後続タスクの実測に委ねる。

### 7.4 `0001` 申し送り 2 の消化

`0001` §10 申し送り 2 は「bad word 判定の等価性テスト」を本書に引き渡している。§2.4 で **`text` に normalizer を導入しない**と決めたため、同申し送りが前提とした等価性（`isBadWord` の Java 部分文字列判定 ＝ `matchCondition` のエスケープ済みワイルドカード判定）は成立し続ける。テスト仕様は次のとおり。

| # | 検証内容 |
| --- | --- |
| T-13 | `isBadWord` と `matchCondition` が**同じ語集合に一致する**こと |
| T-14 | bad word に `*` / `?` を含む場合でも、**その語そのものを含む語だけが一致する**こと（F-09 の回帰） |
| **T-14b** | **`releaseCondition` のエスケープ**（第 5 版）: `mustNotContain` の各値も `mustContain` と同一のエスケープ規則で扱われること。**`*` / `?` を含む bad word が残っている状態で別の bad word を削除しても、解除対象が広がらない**こと |

> **`releaseCondition` の意味論そのものの検査は T-19（§7.2）である。** 本節は `0001` 申し送り 2 が求めた**等価性**（Java 判定とストア問い合わせが一致すること）に限る。**T-19 は「どの語が解除されるか」、T-14b は「その条件のエスケープが正しいか」を見る。**

---

## 8. 既知の制約

**本設計では解消しない。記録のみ行う**（P12）。

| # | 制約 | 内容 | 解消 |
| --- | --- | --- | --- |
| **K-1** | **楽観ロックの欠如**（F-10） | `index/writer/SuggestIndexWriter.java:44-80` の read-modify-write に `setIfSeqNo` / `setIfPrimaryTerm` が無い。異なる呼び出し元が同一 ID を含むバッチを同時に書くとロストアップデートが起きる。**multiGet 化（MIG-15 第 1 段）では解決しない**（§4.6）。**この制約は `0001` 第 5 版の D-26 として公開契約にも書かれている** — 「スレッドセーフ」を「頻度が失われない」と読ませないため、同書 §4.4 が **concurrent invocation safe だが同一 `text` への write は atomic でも linearizable でもない**と明示する。**前倒しを見送った理由は同書 §4.4.0 にある** | **MIG-15 第 2 段**（`scripted_upsert` ＋ `retry_on_conflict`）で一括して扱う。`0000` §2.2 |
| **K-2** | **`roles` の集合和は緩む方向にしか動かない** | `roles` が集合和であるため、一度でも `_guest_`（`SuggestConstants.java:40` の `DEFAULT_ROLE`）を持つ item が合流すると、以降そのドキュメントは全員に見える。`entity/SuggestItem.java:121-126` は roles が null または空のとき `_guest_` を入れるため、roles 未指定の elevate word 登録でこれが起きる。**第 7 版で扱いを格上げした（下記 §8.1）** | 挙動は**維持**するが、**「維持する」ことをメジャー版のリリース時に明示的に判断する**（`0000` §9C.4）。解消は権限モデルの変更（MIG-09 / MIG-22）に属し後続スコープ |
| **K-3** | **`deleteElevateWord` は頻度も消す** | ドキュメントごと削除する（`WordManagementOperations.java:129`）ため、その語に蓄積された `queryFreq` / `docFreq` も失われる。boost だけを取り消す経路は本設計でも設けない（§5.3） | 後続スコープ |
| **K-4** | **`queryFreq` / `docFreq` の加算に飽和処理が無い** | `entity/SuggestItemMerger.java:92-93` は単純加算であり上限検査が無い。`long` の上限に達するには非現実的な回数が要るため対処しない | 対処しない |
| **K-5** | **N を超える語数のクエリは 0 件になる** | `SuggestQueryBuilder.java:112` の AND 連結による構造的な帰結（§2.3(b)）。N を上げれば緩和するが、term 数と引き換えである | 設計上の受容 |

### 8.1 K-2 の扱いを「後続スコープ」から格上げする（第 7 版）

**K-2 は文書間の不整合ではなく、認識済みの仕様リスクである。** それでも第 7 版で扱いを変えたのは、**本設計自身が K-2 の露出面を広げているから**である。

| # | 本設計が加えた変化 |
| --- | --- |
| 1 | **`SuggestSource` を公開拡張点にし、`SuggestIngestService.indexFrom` という実行点を置いた**（`0001` D-24）。**新しい供給元を足すことが設計上の推奨経路になった**ため、`roles` を意識しない実装が同一 `text` に `_guest_` を混ぜる機会が増える |
| 2 | **`AuthorizationFilter` をライブラリ側へ集約し、「デフォルト deny」を重要な契約として明文化した**（`0001` D-11 / §7.2）。**この契約が「認可は安全側に倒れている」と読まれると、K-2 が見落とされる** |

**1 と 2 は方向が逆である** — 検索の入口は締まったが、保存される語の可視範囲は締まっていない。`0001` §7.4 がこの区別を表にしている。

**採る扱い**:

| 事項 | 決定 |
| --- | --- |
| **合成規則（集合和）** | **変えない。** 積集合や「最初のソースが勝つ」に変えると、複数ソースから供給される語が誰にも見えなくなる方向の破綻を生む。**権限モデルの再設計（MIG-09 / MIG-22）なしに単独で変えられない** |
| **リリース判断** | **メジャー版のリリース時に「この挙動を維持する」と明示的に判断する。** 「既知の制約だから後で」で流さない。判断項目の登録先は `0000` §9C.4 |
| **契約の明文化** | `0001` §3.1.3（`SuggestSource` 実装に対する `roles` の契約）と `SuggestSource.produce` の Javadoc。**第 6 版までは K-2 が本表にしか無く、拡張点の実装者が読む場所に書かれていなかった** |
| **回復手段** | **全件再構築が唯一の回復手段である**（`0003` §12.2）。新世代は空から作られるため、一過性の混入は次回の再構築で解消する。**供給元そのものが `roles` を空で返し続ける場合は再構築しても再混入する** |

> **なぜ「`roles` が空の候補を拒否する」検査を入れないか。** 空の `roles` は「全ユーザに公開してよい語」という**正当な入力**と区別がつかない。実際、現行の文書取り込みでもロール設定の無い文書は `_guest_` になる。**検査を入れると正当な用途が壊れ、入れなければ誤用が通る** — この二択を解けるのは権限モデルの側であり、データモデル側では決められない。

---

## 9. 未確定事項・申し送り

**未解消の `[要確認]` は本書に 1 件も存在しない**（V3）。本文中に現れる `[要確認]` の語は §2.2 と §5.4 の 2 箇所のみで、いずれも**他文書の `[要確認]` を参照し、それが解消されたことを述べる文脈**である。以下は「決めたうえで他文書・後続タスクに引き渡す事項」である。

| # | 事項 | 引き継ぎ先 |
| --- | --- | --- |
| 1 | **同一の再構築に束ねる 4 変更**（ID ハッシュ化 / 語数上限 / `ElevateWord` 格納形 / mapping 変更）。旧世代との共存・部分移行は成立しない | **`0003` §3〜§6**（手順・ロールバック条件・件数検証基準） |
| 2 | **最小 OpenSearch バージョンが 2.16 に上がる**（§2.2）。AWS OpenSearch Service で 2.16 未満を使う利用者は初回インデックス作成で失敗する | **`0003`**（移行前提・利用者への影響確認） |
| 3 | **`total_fields.limit` は `_settings` API で運用中に引き上げ可能**（§3.4） | **`0003`**（運用手順） |
| 4 | **MIG-13 の除外フィルタのレイテンシ計測**（§6.4） | 後続タスク（性能実測） |
| 5 | **決着済み（第 4 版で結論が反転した）。** `userBoost` の「指定あり／なし」は **`SuggestCandidate.userBoost`（`OptionalDouble`）** で表す。`0001` 第 3 版は「正準ファクトリ `SuggestItem.of(...)` ＋ `withUserBoost(double)`、`OptionalDouble` は却下」としていたが、**第 4 版の D-19 で取り込み側を `SuggestCandidate` へ分離した結果 `OptionalDouble` の意味論が型の役割と一致し、D-16 が反転した**（`0001` 改訂履歴の注記）。**`SuggestItem`（保存されている現在状態）が `OptionalDouble` を持たない点は変わらない。** 本書 §5.3 の合成規則も変更なし。パーサ経路（`index/contents/DefaultContentsParser.java:107-108,:144`）は `SuggestCandidate.document(...)` を、`ElevateWord.toSuggestItem`（`entity/ElevateWord.java:147`）は `.elevate(...)` を使う ※**第 5 版で本行の記述を第 3 版のまま放置していた誤りを是正した** | **決着済み** → `0001` §2.6（D-16 / D-19） |
| 6 | **「1 語に対する代替読み」を W > 1 のフレーズに指定する方法が無い**（§5.4）。現行の単一入力欄・空白区切りでは 2 次元を表現できない。表現するには `(fess) helper/SuggestHelper.java:464-487` の入力仕様と管理画面フォーム（`app/web/admin/elevateword/CreateForm.java:46-51`）・CSV 仕様（`app/service/ElevateWordService.java:230-236`）の拡張が要る | 後続スコープ（fess 本体側） |
| 7 | **`FieldNames` に `EXCLUDED` 定数を追加する**（§6.2）。`constants/FieldNames.java` に該当定数が無い | 実装タスク |
| 7b | **コード変更の順序制約**（§5.2 の注記）: `SuggestItem` コンストラクタでの INV-1 強制と `ElevateWord.toSuggestItem` の §5.4 化は**同一リリース**でなければならない。前者だけ先行すると k ≠ W の elevate word 登録が全滅する。**データ移行の束ね（§4.7）とは別の制約である** | **`0003`**（リリース手順）／ 実装タスク |
| 8 | **決着済み（ステップ 7）。** `0000` §3.4 の番号台帳に `D` / `DM` / `MO` の 3 行が追加された | **決着済み** → `0000` §3.4 |
| 9 | **決着済み（ステップ 7）。** `(fess res)` が `0000` §3.1 のパス短縮表記に追加された | **決着済み** → `0000` §3.1 |
| 10 | **決着済み（ステップ 7）。** ステップ 4（`0000` §5.3）が示した修正形と解釈の申し送りに対する訂正は、**当該作業記録に追記せず訂正一覧に E-22 として採番**した。作業履歴は「その時点で何を考えたか」の記録であり後知恵で書き換えない、訂正の所在は 1 箇所に集約する、という 2 点が理由である | **決着済み** → `0004-corrections.md` の E-22 |
| **11** | **語数上限 N の観測項目 OB-1〜OB-3 の実装と閾値**（§2.3(b) / DM-17）。本書は「何を観測するか」までを定めた。切り捨て率の許容水準と N の初期値は分布の実測に依存する。**OB-3（本番投入前のクエリ語数分布の取得）は再構築の事前作業であるため `0003` の手順にも現れる** | 後続タスク（性能・分布の実測。`0000` §2.2）／ **`0003` §4**（事前作業） |
| **13** | **DM-21 によるインデックス増分の実測**（§6.4 / §6.5）: bad word 該当語を保存するようになったことでドキュメント数・インデックスサイズ・検索レイテンシがどれだけ増えるかは、bad word の登録数と部分一致の広さに依存し、**設計時点では見積もれない**（C-04）。**同一データ・同一 bad word 集合で drop モデルと比較する**ことを計測項目とする | 後続タスク（性能実測。`0000` §2.2）／ **`0003` §12.1**（運用手順としての物理削除） |
| **12** | **`0001` 第 4 版の 3 型分離（D-19）に伴う実装上の割り当て**（§5.3）: 現行で `new SuggestItem` している 2 経路（`index/contents/DefaultContentsParser.java` ／ `entity/ElevateWord.java:143-149`）を `SuggestCandidate.document(...)` / `.elevate(...)` のどちらにするか。**`0001` §10 の申し送り 13 と同一事項であり、本書は合成規則の側から見た要求（`elevate` 経路のみが `userBoost` を present にする）だけを持つ** | 実装タスク（`0001` §10 の 13 と対） |

---

## 10. 自己レビュー（作業プラン §3 ステップ 5-6）

| 観点 | 判定 |
| --- | --- |
| mapping が 1 つに統合されているか | **pass**。§2.1 のみが正であり、ステップ 4 の骨格 JSON を再掲していない |
| 未解消の `[要確認]` が 0 件か | **pass**（§9 冒頭。本文の 2 箇所はいずれも他文書の `[要確認]` を参照・解消する文脈） |
| `0005-schema-draft.md` の誤りを再生産していないか | **pass**。`MAX_READING_NUM` をフィールド数上限としていない（§2.3(b) は「1 語あたりの読み候補数」として扱う）。案 A を採らない理由を §2.2 に明記 |
| `scripted_upsert` 前提の記述が混入していないか | **pass**。§5.5 で「Java 側 `SuggestItemMergePolicy` が単一の正」と明記し、Painless は実装側の責務として言及するに留めた ※**第 7 版で「実装側の責務」という条件付きの言い方も外れた**（`0001` D-31 により合成が常に Java 側の 1 実装に閉じるため） |
| **V10**（ID 再設計） | **pass**。①② がハッシュ化で解消（§4.1）、切り詰めロジックが新方式に存在しない（§4.1）、構成要素は `text` のみ（§4.2）、③ は §5.3 の `userBoost` 合成規則で解消、KEEP-03 との衝突を避けた根拠が §4.2 の引用ブロックに残っている |
| **V11**（既知の制約） | **pass**。F-04 は §5.6、F-10 は §4.6 と K-1。F-10 に「multiGet では解決しない」「MIG-15 第 2 段で一括して扱う」を併記 |
| **V9**（コード根拠） | **pass**。事実主張に `file_path:line` を付した |
| **V6**（根拠の非転記） | **注意**（実測値付き）。本書は **52,592 文字 / 89,275 バイト**、提案書（60,700 文字）比 **86.6%**（初版は 48,278 文字・79.5%）であり、目安の 1/5（20% 前後）を超える。ただし `0001` の 126.0% よりは小さい。**提案書の内容の転記はしていない**（根拠・経緯は `improvement-proposal.md` とステップ 4 の作業記録に一本化し、本書には結論と仕様のみを書いた）。超過の内訳は、作業プラン §3 ステップ 5 が本節構成に対して求めた 6 節ぶん（特に P11 で追加された ID 再設計 §4 とマージ規則 §5）と、テスト仕様 §7・既知の制約 §8 である。**最終判定はステップ 7 の 7-5 に委ねる** |

---

## 付録 A. 既存資料に対する新規訂正（ステップ 7 への入力）

**`0000` §6 の訂正一覧に追加すべき項目。E 番号の採番はステップ 7 で確定する**（既存は E-01〜E-12、`20260706_design_document/0009` §7 が 6 件を提出済み）。

| 対象 | 誤っている記述 | 訂正内容 | 根拠 |
| --- | --- | --- | --- |
| `20260706_design_document/0001` §2.14（C-14 の原典） | `number_of_replicas: 0` の削除対象は **4 ファイル** | **7 ファイル**である。fess 本体側の `(fess res) suggest_indices/suggest_analyzer.json` / `_aws/` / `_cloud/` が漏れている | 本書 §3.2 |
| `20260706_design_document/0004` §3 F-10 | 「`SuggestIndexer` は `parallel` フラグを持ち、並行実行時にロストアップデートが起きうる」（根拠 `index/SuggestIndexer.java:185`） | `parallel` は `ContentIndexingOperations.java:138-139,:256-257` で**パース処理を並列化するだけ**であり、書き込みは逐次である。成立条件は「異なる呼び出し元の同時実行」。**F-10 の結論（楽観ロックが無い）は不変** | 本書 §4.6 |
| `20260706_design_document/0004` §3 F-05 | 「先頭が一致する長文同士が同一 ID に衝突する」（③） | 正確には「先頭 **333 バイト**が完全一致し、**334 バイト目の上位 6 ビット**が一致する」場合に衝突し、**335 バイト目以降は影響しない**。「333 バイト」は文字数ではなく、日本語なら約 111 文字 | 本書 §4.3 |
| `20260706_design_document/0009` §5.2 の★ / §10 申し送り 1 | 「`ElevateWord.toSuggestItem` を 1 語 × k 候補形（`new String[][] { allReadings }`）に修正するのが先」「複数の読みを持つ elevate word はすべて不変条件を違反する」 | **修正形は W > 1 で成立しない**（検索でヒットしなくなる）。正しい規則は本書 §5.4 の 4 分岐。違反するのは「読みトークン数 k ≠ 語数 W」のときであって「読みが複数のとき」ではない | 本書 §5.4 |
| `0000` §3.1（パス短縮表記） | 無印 / `(fess)` / `(res)` の 3 種のみ | **`(fess res)` ＝ `modules/fess/src/main/resources/` を追加する必要がある** | 本書 §3.2 |
| `0000` §3.4（番号体系の台帳） | ISS / TBD / KEEP / MIG / C / P / U / F / T / E / V の 11 系統 | **`D`（`0001` の決定番号）と `DM`（本書の決定番号）が未登録**。同節は「本表に行を追加してから使う」と定めている | 本書 §9 の 8 |

**過去タスクの文書は書き換えていない**（P9）。

---

## 付録 B. 参照した一次情報

### B.1 プロダクションコード / リソース

無印 ＝ `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下、`(fess)` ＝ `modules/fess/src/main/java/org/codelibs/fess/` 配下、`(res)` ＝ `modules/fess-suggest/src/main/resources/` 配下、**`(fess res)` ＝ `modules/fess/src/main/resources/` 配下**（本書で新設 — 付録 A）。

**個々の行番号は本文の各主張に付してあるため再掲しない**（`0000` §3.3 の記述ルール 1）。

- fess-suggest: `Suggester.java` ／ `entity/SuggestItem.java` ／ `entity/SuggestItemSerializer.java` ／ `entity/SuggestItemMerger.java` ／ `entity/ElevateWord.java` ／ `index/SuggestIndexer.java` ／ `index/writer/SuggestIndexWriter.java` ／ `index/writer/SuggestWriter.java` ／ `index/operations/IndexingOperations.java` ／ `index/operations/WordManagementOperations.java` ／ `index/operations/ContentIndexingOperations.java` ／ `index/contents/DefaultContentsParser.java` ／ `request/suggest/SuggestRequest.java` ／ `request/suggest/SuggestQueryBuilder.java` ／ `request/popularwords/PopularWordsRequest.java` ／ `converter/ReadingConverter.java` ／ `converter/ReadingConverterChain.java` ／ `settings/SuggestSettings.java` ／ `settings/AnalyzerSettings.java` ／ `settings/ArraySettings.java` ／ `constants/FieldNames.java` ／ `constants/SuggestConstants.java` ／ `util/SuggestUtil.java`
- リソース: `(res) suggest_indices/suggest.json` ／ `suggest/mappings-default.json` ／ `suggest_settings.json` ／ `suggest_settings_array.json` ／ `suggest_analyzer.json` ／ `analyzer/mapping-default.json` ／ **`(fess res) suggest_indices/suggest_analyzer.json` ／ `_aws/suggest_analyzer.json` ／ `_cloud/suggest_analyzer.json`**
- fess 本体: `(fess) helper/SuggestHelper.java` ／ `(fess) api/v2/handlers/SuggestWordsHandler.java` ／ `(fess) helper/PopularWordHelper.java` ／ `(fess) mylasta/direction/FessConfig.java` ／ `(fess) app/web/admin/elevateword/CreateForm.java` ／ `(fess) app/service/ElevateWordService.java`
- テスト: `SuggestItemTest` ／ `SuggestItemBoundaryTest` ／ `SuggestItemMergerTest` ／ `SuggestItemSerializerTest` ／ `SuggestUtilTest` ／ `ElevateWordTest` ／ `SuggestIndexerTest`

### B.2 バイトコードによる確認

`~/.m2/repository/org/opensearch/opensearch/3.7.0/opensearch-3.7.0.jar` を展開し `javap -c -p` で確認した（§4.5）。

- `org/opensearch/action/get/GetRequest`: 既定コンストラクタが `realtime = true` を設定
- `org/opensearch/action/get/MultiGetRequest`: 同上

### B.3 タスク内文書

| 文書 | 用途 |
| --- | --- |
| `0000-design-overview.md` | §3.1 凡例 ／ §3.2 冒頭宣言 ／ §3.3 記述ルール ／ §3.4 番号台帳 ／ §4.2 MIG 対応表 ／ §5・§5.1 [確定] ／ §6 訂正一覧（**E-03 / E-05 / E-06 / E-07 / E-08** を本書で使用） |
| `0001-api-design.md` | §3.4（`SuggestItemMergePolicy` のシグネチャ）／ §3.5（`BadWordPolicy`）／ §3.7（`SuggestStore`）／ §6（設定 API）／ §10 の申し送り 2・4・9・10 |
| `20260706_design_document/0004` | F-01, F-02, F-04, F-05, F-06, F-10, F-12 ／ §5.2（ステップ 5-3 への申し送り） |
| `20260706_design_document/0009` | 決定 1〜4（`dynamic` 方針・語数上限・`total_fields.limit`・適用範囲）／ §6（本書の各節への指示）／ §10 の申し送り 1〜6 |
| `20260706_design_document/0003` | §3 ステップ 5（5-1〜5-6）の作業定義 ／ §5（V1〜V11）／ §6.1（U1〜U5） |
| `improvement-proposal.md`（第 4 版） | MIG カタログ（`:376-402`）／ ISS-04・ISS-05（`:132-133`）／ MIG-03 の定義（`:380`）。**編集していない**（P9） |
