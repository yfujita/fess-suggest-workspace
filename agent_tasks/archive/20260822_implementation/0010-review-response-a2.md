# 0010: ステップ A-2 の外部レビュー指摘への対応（**逸脱 X-6・区分 I**）

> 本書は作業プラン `0001-work-plan.md` §4「フェーズ A」**ステップ A-2** の実装（作業履歴 `0007` §2）に対する**外部レビュー指摘への対応記録**である。**新しいステップではなく、A-2 の是正である。**
>
> **本件は `0008`（A-1 のレビュー反映）より踏み込んでいる。** `0008` は MO-24 の**根拠欄の不足**を直しただけで決定は不変だったが、**本書は MO-25 の規則 3 と規則 6 の内容そのものを覆す**。したがって**新しい X 番号（X-6）を起こす** — 判定の根拠は §1.1 / §1.2。
>
> **凡例**: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[確定]** = 決定済み ／ **[要確認]** = 未解消
>
> **パス短縮表記**: `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/` ／ `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/`

| 項目 | 値 |
| --- | --- |
| 実施日 | **2026-08-31** |
| 対象 | **ステップ A-2**（`0007` §2）／ レビュー指摘 5 件 |
| ブランチ | `modules/fess` の **`feature/suggest-l1-precede`**（`modules/fess-suggest` には**一切触れない**） |
| 起点コミット | **`73e912715`**（`fix: normalize elevate word separators and keep add/delete ids symmetric` ＝ A-1 の実装）。**A-2 の実装は未コミットで作業ツリーに載っている** [確認] |
| 逸脱区分 | **区分 I（設計判断の誤り）** — プラン §2.1 ／ 判定理由は **§1.1** |
| X 番号 | **X-6（新規に起こした）** — 判定理由は **§1.2**。**新しい MO 番号は起こさない**（MO-25 の改訂である） |
| 改訂した設計書 | `docs/0003-migration-ops-design.md` — **第 12 版 → 第 13 版**（MO-25 の規則 3・6 の改訂 ＋ (f) の全面書き直し ＋ (i) / (j) の新設） |
| コード変更 | **なし** [確認]。**逸脱手続きは「改訂を先に行う」ことを要求する**（プラン §2.1）。**A-2 の再実装は本書の完了後に `code-implementer` が行う** — 仕様は **§5** |
| ユーザー判断 | **「再構築専用の内部経路を分ける」形を選択**（2026-08-31。§4.3） |

**結果: 指摘 5 件のうち、是正を要するのは 3 件（指摘 1・2・5）。いずれも設計書 第 13 版に反映し、実装仕様として §5 に落とした。指摘 3・4 は肯定的評価であり対応不要（記録のみ）。**

---

## 1. レビュー指摘の一覧と判定

| # | 指摘 | 重み | **本書の判定** | 対応 |
| --- | --- | --- | --- | --- |
| **1** | **失敗件数の二重計上。** 1 件の不正行が削除フェーズと追加フェーズで 2 件として数えられる。G3 が知りたいのは「取り込みに失敗した source item が存在するか」であって内部の operation 数ではない。**行 ID 単位で dedupe すべき** | **Blocker** | **採用。** レビュアーの論拠は正しく、**さらに MO-25 の規則 3 を支えていた根拠 (f) の 4 が事実誤認だった**ことを本書で確認した | **§2** — 規則 3 を「失敗した行の数。行 ID で dedupe」に改訂。**(f) を全面的に書き直した。** DoD を「1 以上」から「1」へ戻す（**自己訂正** — §2.4） |
| **2** | **`apply=false` の管理画面／API の**エラー契約**を変えてしまっている。** 同期経路が 200 OK / 成功メッセージを返し、運用者が唯一の異常検知手段を失う | **Major** | **採用。** **実物で裏が取れた**（§3 の表）。**加えてレビュアー／依頼が挙げた「同期 2 経路」は elevate word 側だけであり、bad word 側にも同型が 2 経路ある — 同期は 4 経路である** [確認]（§3.1 の表） | **§3** — 規則 6 を「失敗隔離は再構築経路に限定する。public の挙動は変えない」に改訂。**却下した旧根拠と覆した理由の両方を `0003` (i) に記録** |
| **3** | `deleteAllElevateWord` を保護した判断自体は正しい | — | **同意** | **対応不要**（記録のみ — §6.1）。**規則 1（削除フェーズも隔離対象）は維持する** |
| **4** | `storeAllBadWords` の形は良い。ただし「public メソッドの通常の意味にしている点」は指摘 2 に含まれる | — | **同意** | **対応不要**（記録のみ — §6.1）。**後半は指摘 2 の対応に吸収される** |
| **5** | **Javadoc の記述が不正確。** 「a row with a blank `suggestWord` … makes `normalizeSeparators` throw」と書いているが、**`normalizeSeparators("")` は throw せず `""` を返す** | **Minor** | **正しい** [確認] | **§4** — 正確な記述（`convertEmptyToNull` の 1 段を経由して `null` になる）を §5 の実装要件に組み込んだ |
| — | `catch (Exception)` の広さ | **Blocker ではない** | **同意。規則 2 は維持する** | **対応なし。** ただし副作用（**障害時に全行分の WARN が並びうる**）を残存リスクに記録 — §7 の 3 |

### 1.1 区分 I と判定した理由

**プラン §2.1 に照らす。**

| # | 理由 |
| --- | --- |
| **1** | **観測値の訂正ではない。** 変わるのは **MO-25 の規則 3（失敗件数の集計単位）と規則 6（失敗隔離の適用範囲）という設計判断そのもの**である。区分 II の判定基準（バージョン・行番号・ファイル数などの観測値が変わった／誤っていた）に当たらない |
| **2** | **プラン §2.1 は区分 II の手続きを「軽微改訂（該当箇所の値のみ更新。版は上げない）」と定めている。** 本件は**版を第 13 版へ上げる**（`0008` §2.5 の 1 と同じ論理） |
| **3** | **規則 6 は結論が反転している** — 「管理画面の経路にも及ぶ。**これは受け入れる**」→「**受け入れない**。public の挙動は変えない」。**「設計の内容が変わらないことを積極的に示せる場合に限る」という区分 II の要件を満たしようがない** |
| **4** | プラン §2.1 の「**判定に迷ったら区分 I として扱う**」に合致する |

> **区分 II 相当の付随訂正が 1 件ある**（`0003` 第 12 版が「管理画面の 3 経路」と書いていた値を「同期 4 経路／非同期 4 経路の計 8 経路」に是正した — §3.1）。**本体ではないため区分 I の手続きの中で一緒に処理した** — `0009` §3.1 の注記と同じ扱いである。

### 1.2 新しい X 番号（X-6）を起こす理由

**先例は 2 つあり、本件はその中間ではなく明確に一方に落ちる。**

| 先例 | 内容 | X 番号 |
| --- | --- | --- |
| **`0008` §2.5** | `0003` 第 11 版。**MO-24 の (d) の規則 3 の根拠欄の不足を是正した。** 決定そのものは不変。新しい MO 番号を採番していない。**コードの変更は実行文 0 行**（コメントと Javadoc のみ） | **起こさない**（X-4 の追補改訂） |
| **`0009` §3.2** | `0003` 第 12 版。**§10.4 の対処範囲を削除フェーズへ拡張し、集計単位を新たに定めた。** MO-25 を採番。実装への要件が変わった | **起こす**（X-5） |

**`0008` §2.4 の 4 が事実上の判定基準を残している** [確認]:

> 「撤去は**決定そのものの変更**であるため、**`0003` の改訂に加えて新しい X 番号での逸脱記録 ＋ プラン §2.2・§8 の DoD ＋ §4 のステップの DoD の修正**が必要になる（**本書 §2.5 の追補改訂とは手続きの重さが違う**）」

**本件はこの「決定そのものの変更」の側に落ちる。**

| # | 判定基準 | 本件 | `0008`（追補） | `0009`（X-5） |
| --- | --- | --- | --- | --- |
| **1** | **新しい設計判断を追加／変更しているか** | **YES。** 規則 3 の集計単位を変え、規則 6 の結論を反転させ、対象メソッド集合（`ForRebuild` 2 メソッドの新設）と `SuggestCreator` の呼び先を変える。**`0009` §4.2 が明示的に「不採用」とした案 (b) を採用に転じている** | NO | YES |
| **2** | **新しい MO 番号を採番するか** | **NO**（§1.2 の下段） | NO | YES |
| **3** | **実装への要件が変わるか** | **YES。** A-2 の対象・作業内容・DoD がいずれも変わり、**既に完了している A-2 の実装を書き直す** | NO（実行文 0 行） | YES |
| **4** | **プラン §2.2・§8 の DoD・ステップの DoD の修正を伴うか** | **YES（3 つとも）** | NO | YES |

> **したがって X-6 を起こす。** **X-5 の行に追補を書き足すだけでは足りない理由**は次の 2 点である。
>
> | # | 理由 |
> | --- | --- |
> | **1** | **`0009` を一次情報として読む後続作業者が誤導される。** `0009` §4.2 は案 (b)（private ヘルパの切り出し）を、§4.3 は案 (c)（行数で数える）を、いずれも**「不採用」と大書したまま残る**。**本件はその 2 つをどちらも採用に転じる。** X-5 の行に小さく追補を書くだけでは、台帳から `0009` へ辿った読み手が撤回済みの判断を有効なものとして読む |
> | **2** | **`0008` §2.4 の 4 が定める「手続きの重さの違い」がそのまま当てはまる。** 本件は `0003` の改訂に加えてプラン §2.2・§8 の DoD 16・§4 の A-2 / A-3 / A-6 の修正を**実際にすべて行う**。`0008` の追補改訂（`0003` の根拠欄 1 箇所のみ）とは手続きの重さが違う |

**新しい MO 番号（MO-26）を起こさない理由**:

| # | 理由 |
| --- | --- |
| **1** | **決定の主題が同一である。** MO-25 は「全件再投入系メソッドの失敗隔離」という 1 つの主題の決定であり、変わったのはその内部の規則 2 項である。**規則 1・2・4・5・7 はそのまま生き残る** |
| **2** | **MO-26 を起こすと、MO-25 と MO-26 が矛盾する 2 つの有効な決定として台帳に並ぶ**（規則 3 と規則 6 が両方の番号に存在する）。**設計書は「現在有効な決定の集合」であるべきで、撤回された規則を番号として残さない** |
| **3** | **先例と整合する。** MO-24 は第 10 版（新設）と第 11 版（根拠の是正）の 2 回にまたがって 1 番号のまま改訂された（`0008` §2.5）。**MO-25 が第 12 版（新設）と第 13 版（規則の是正）にまたがるのも同型である** |

> **帰結**: **1 つの MO 番号（MO-25）に 2 つの X 番号（X-5 / X-6）が対応する。** これは MO-24 が 1 つの X 番号（X-4）で 2 版にまたがったのと**逆の対応**である。**プラン §2.2 の X-6 の行と §9.2 の改訂表の両方に「MO-25 の改訂であり新しい MO 番号は起こさない」ことを明記して、台帳の対応関係が読めるようにした。**


---

## 2. 指摘 1 — 失敗件数の二重計上（Blocker）

### 2.1 レビュアーの論拠と、本書の追加確認 [確認]

| # | 主張 | 実物 | 判定 |
| --- | --- | --- | --- |
| 1 | 現実装は 1 件の不正行を削除フェーズと追加フェーズで **2 件**として数える | `(fess) helper/SuggestHelper.java:427`（`int failures = deleteAllElevateWord(apply);`）／ `:442`（追加フェーズの `failures++`）／ `:494`（削除フェーズの `failures++`） | **正しい**。**これは MO-25 の規則 3 そのものであり、バグではなく仕様として書かれていた** |
| 2 | G3 が知りたいのは「取り込みに失敗した source item が存在するか」であって内部の operation 数ではない | `0003` §4.2 の G3 ／ §4.2.2 | **正しい** |
| 3 | 将来 delete が 3 段になれば同じ行が 3 件になるのは不合理 | **より具体的に成立する** [確認]: **MO-24 の両キー削除は移行期の暫定措置であり L2 で撤去される**（`0003` §10.3.1 (d)）。**撤去されると同じ不正行の件数が 2 → 1 に変わる** — 外に出す数が実装のループ段数に追随している | **正しい**。**本書はこれを (f) の根拠 2 として設計書に記録した** |
| 4 | 行 ID 単位で dedupe すべき（`Set<String> failedIds` に `getId()` を入れ `size()` を返す） | **実装可能である** [確認]。§2.2 | **正しい** |

### 2.2 **第 12 版の根拠 (f) の 4 は事実誤認だった** [確認]

**これは本書がレビュー指摘を検証する過程で新たに発見した事実であり、レビュアーは指摘していない。**

> `0003` 第 12 版 §10.4 (f) の 4:
> 「**『行数』で数える案は採らない。** 削除フェーズと追加フェーズは**別々の `selectList`** であり、行を突き合わせる鍵は `suggestWord` — **まさに `null` になっている値**である。突き合わせは実装できないか、できても脆い。」

**突き合わせの鍵は `suggestWord` ではない。`getId()` である。**

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 1 | `ElevateWord` / `BadWord` はいずれも `getId()` を持ち、`asDocMeta().id()` を返す | `(fess) opensearch/config/exentity/ElevateWord.java:92` ／ `(fess) opensearch/config/exentity/BadWord.java:27` |
| 2 | **その値は `selectList` が OpenSearch の検索ヒットの `_id` から設定する。** したがって `selectList` 経由で得た行の `getId()` は `null` になりえない | `(fess) opensearch/config/allcommon/EsAbstractBehavior.java:166` / `:207` / `:230` — いずれも `docMeta.id(hit.getId())` |
| 3 | **`getId()` は `suggestWord` から独立している。** 不正行（`suggestWord` が空文字／未設定）でも `_id` は存在する | 同上 ／ `(fess) opensearch/config/bsentity/BsElevateWord.java:190-193`（`getSuggestWord()` のみが `convertEmptyToNull` を通る） |

> **第 12 版の実装（`0007` §2.3 の 4）自身が `logger.warn("... id={}", elevateWord.getId(), ...)` で `getId()` を使っている** [確認]（`:443` / `:495` / `:639`）。**「識別子として使える」ことは実装時点で分かっていたのに、集計の鍵としては使えないと書いていた。** 根拠 (f) の 4 は執筆時に `getId()` を見落としたまま組み立てられていた。

### 2.3 (f) の 1〜3 は「合算」と「行数」の間の選択に効かない

| # | 第 12 版の根拠 | 本書の判定 |
| --- | --- | --- |
| **1** | G3 は件数を 0 / 非 0 の二値としてしか使わないため、内訳を分けても判定は変わらない | **事実としては正しいが、論証として成立していない。** これは「**合算でよい**」（許容性）の根拠であって「**合算が良い**」（優越性）の根拠ではない。**同じ論理は dedupe にもそのまま当てはまる。判定に効かない以上、この根拠はどちらの案も選ばない** |
| **2** | §4.2.2 の集約方針（1 つのガードに集まる）と逆行する | **「フェーズ別に 2 つの数を返す案」を否定する根拠としては有効。** **行 ID で dedupe した行数も「1 つの数」**であり集約方針を満たす。**(a) と (c) の間の選択には無関係** |
| **3** | 分けると呼び出し元が読む数が増える | 同上。**2 つ返す案の否定にのみ効く** |
| **4** | 行数案は突き合わせの鍵が `suggestWord` であるため実装できない／脆い | **事実誤認**（§2.2） |

> **したがって第 12 版の (f) は、4 つの根拠のうち 3 つが「別の案（フェーズ別に 2 つ返す）」を否定するものであり、1 つが事実誤認であった。「合算」を積極的に選ぶ根拠は 1 つも残らない。** 第 13 版はこれを全面的に書き直し、**「運用者が読む数として意味が通るか」「実装のループ段数に追随しないか」「DoD が等値で閉じられるか」**の 3 点で行数を選ぶ形に改めた。

### 2.4 **自己訂正 — DoD ではなく実装を曲げるべきだった**

**レビュアーが引用した DoD「不正行 1 件で失敗件数 1」は、X-5（`0009`）より前のプランの文面である。**

| 時点 | プラン §4 ステップ A-2 の DoD 2 | 経緯 |
| --- | --- | --- |
| **X-5 より前** | 「不正な elevate word を 1 件含む入力で `storeAllElevateWords` が完走し、**失敗件数 1** を報告する」 | 元の DoD |
| **X-5（`0009` §5）** | 「**失敗件数が 1 以上**で報告される」（等値ではない） | **削除フェーズを勘定に入れると 2 になるため、DoD を緩めた** |
| **本書（X-6）** | **「失敗件数 1」へ戻す** | **行 ID で dedupe すれば元の DoD がそのまま満たせる** |

> **X-5 の時点で私が下した「DoD を緩める」という判断は誤りだった。**
>
> **DoD は「1 件の不正行が何件と数えられるか」という実装の内部事情ではなく、「不正行が 1 件あることを検知できるか」という外部から見える要求を表していた。** それが満たせないとき、疑うべきは要求ではなく実装の集計単位だった。**曲げるべきだったのは実装であって DoD ではなかった。**
>
> **さらに「1 以上」への緩和は回帰検知能力を落としていた** [確認]: **`assertTrue(failures >= 1)` は 2 も 3 も通すため、二重計上の回帰を検知できない。** 等値検査に戻すことで、**dedupe が壊れた瞬間にテストが赤くなる。**
>
> **一般化して申し送る** [提案]: **「設計どおり実装すると DoD が満たせない」ことを発見したとき、逸脱手続き（プラン §2.1）は設計書を改訂させるが、改訂の向きとして「DoD を緩める」を選んでよいのは、DoD 自体が実装不能な要求だった場合に限る。** X-5 はその確認を経ずに DoD を緩めた。**同種の判断は今後 A-3 以降でも起こりうる**（§8 の 3）。

### 2.5 dedupe しても両ケースが「1」で閉じることの確認 [確認]

| 不正行の種別 | 削除フェーズ | 追加フェーズ | **dedupe 後の件数** |
| --- | --- | --- | --- |
| `suggestWord` が空文字／未設定（`getSuggestWord()` が `null`） | **落ちる**（`normalizeSeparators(null)` → NPE） | **落ちる**（`addElevateWord` 内の `normalizeSeparators(word)` → NPE） | **1**（同じ `getId()` が 2 回 `Set` に入るだけ） |
| `boost` が未設定（`getBoost()` が `null`） | **落ちない**（`suggestWord` は正常なので正規化は通る） | **落ちる**（`new ElevateWord(word, boost, ...)` のアンボクシング NPE） | **1** |

> **どちらのケースも「不正行 1 件 → 失敗件数 1」で閉じる。** これは §2.4 の「元の DoD がそのまま満たせる」ことの直接の裏付けである。

---

## 3. 指摘 2 — `apply=false` の管理画面／API のエラー契約（Major）

### 3.1 実物確認 — **同期は 2 経路ではなく 4 経路である** [確認]

**依頼で示された「同期 2 経路」は elevate word 側だけを数えた値である。bad word 側にも同型が 2 経路ある。本書はすべて実物を開いて確認した。**

| # | 経路 | 同期／非同期 | 呼び出し | 失敗時の運用者への表出 |
| --- | --- | --- | --- | --- |
| **1** | `(fess) app/web/admin/elevateword/AdminElevatewordAction.java:372-391` `update()` | **同期** | `:379` `deleteAllElevateWord(false)` ／ `:380` `storeAllElevateWords(false)` | `:382` `catch (final Exception e)` → `:384` `throwValidationError(... addErrorsCrudFailedToUpdateCrudTable ...)`。**画面にエラーが出る** |
| **2** | `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:171-186` `put$setting()` | **同期** | `:177` `deleteAllElevateWord(false)` ／ `:178` `storeAllElevateWords(false)` | `:179` `catch` → `:181` `throwValidationErrorApi(...)`。**API がエラーを返す** |
| **3** | `(fess) app/web/admin/badword/AdminBadwordAction.java:341-357` `update()` | **同期** | `:348` `storeAllBadWords(false)` | `:350` `catch` → `:352` `throwValidationError(...)` |
| **4** | `(fess) app/web/api/admin/badword/ApiAdminBadwordAction.java:148-162` `put$setting()` | **同期** | `:154` `storeAllBadWords(false)` | `:155` `catch` → `:157` `throwValidationErrorApi(...)` |
| **5** | `(fess) app/web/admin/elevateword/AdminElevatewordAction.java:428-441` `upload()` | **非同期**（`:431` `CommonPoolUtil.execute`） | `:434` / `:435` | `:436` `catch` → `FessSystemException` を投げるだけ。**レスポンスは既に `saveInfo(... addSuccessUploadElevateWord ...)` で返っている** |
| **6** | `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:231-242` `put$upload()` | **非同期**（`:233`） | `:236` | 同上 |
| **7** | `(fess) app/web/admin/badword/AdminBadwordAction.java:396-406` `upload()` | **非同期**（`:399`） | `:402` | 同上 |
| **8** | `(fess) app/web/api/admin/badword/ApiAdminBadwordAction.java:205-214` `put$upload()` | **非同期**（`:207`） | `:210` | 同上 |

> **`0003` 第 12 版の規則 6 が言う「管理画面の 3 経路」は、elevate word の `deleteAllElevateWord(false)` の呼び出し 3 箇所（`:379` / `:434` ／ Api `:177`）を数えた値であり、`storeAll*` 側と bad word 側を含んでいなかった** [確認]。**全体は 8 経路（同期 4 ／ 非同期 4）である。** 第 13 版はこれを是正した。

### 3.2 判定 — 規則 6 を撤回する

| # | 論点 | 判定 |
| --- | --- | --- |
| **1** | **同期 4 経路では、例外がバリデーションエラーとして UI / API に現れることが、運用者にとって唯一の異常検知手段である。** 隔離すると 200 OK ＋ 成功メッセージを返し、WARN ログだけが残る | **第 12 版の規則 6 はこの点を一切評価していなかった。** 規則 6 の根拠欄が挙げたのは「1 件の不正行で編集・アップロードが全滅する」ことだけであり、**全滅の代わりに何を失うか**を数えていない |
| **2** | **非同期 4 経路では隔離の利益が小さい。** レスポンスは既に返っており、失敗は `FessSystemException` になるだけで運用者に届かない | **規則 6 が得ようとした利益は非同期側で小さく、失う検知手段は同期側で大きい。** 差引きで不利である |
| **3** | **A-2 の目的（`0003` §10.4 (d) の 1）は「SuggestJob の全件再構築を 1 件の不正行で止めない」ことであり、管理画面のエラー契約の変更はその目的に含まれない** | **目的外の挙動変更である。** 第 12 版は実際にそれを「リリースノートに書く」「運用者へ周知する」として申し送っていた（`0009` §11 の 4・5）が、**変更面積を小さく保つ先行リリース（フェーズ A）の趣旨に反する** |
| **4** | **規則 6 が (b) 案（private ヘルパの切り出し）を退けた理由「同じロジックの 2 実装になる」は前提が誤っている** | **共通実装を private に 1 つだけ持ち、失敗隔離の有無を引数で切り替えれば 2 実装にならない** [確認]。**`0009` §4.2 の案 (b) の評価が「行単位の private ヘルパを切り出す」を「2 実装」と読み違えていた。** MO-24 の規則 1 との衝突は起きない |

### 3.3 旧根拠のうち、**依然として一理ある**もの

> 「**現状は 1 件の不正行があるだけで elevate word の編集・アップロードがすべて失敗する。** スキップ＋警告ログの方が運用上厳密に良い」

**これは観察として正しく、本版でも解消されない。** ただし:

| # | 理由 |
| --- | --- |
| **1** | **それは MO-25 が直すと約束したものではない**（§3.2 の 3） |
| **2** | **本来の解は入口側バリデーション（規則 7 ／ `0003` §13 の 8）であり、後続スコープである。** 出口側で黙らせるのは症状の隠蔽に近い |
| **3** | **管理画面で失敗すれば運用者は気づく。** 隔離すると気づかないまま壊れ続ける。**「気づく形で失敗する」方を選んだ** |

**これは本書が引き受けるコストであり、残存リスクとして §7 の 1 に記録した。**

---

## 4. 指摘 5 — Javadoc の記述が不正確（Minor）

### 4.1 事実確認 [確認]

**現 Javadoc**（`(fess) helper/SuggestHelper.java:459-461`。`deleteAllElevateWord` の第 2 段落）:

> "a row restored from a backup's raw `/_bulk` request can have a blank `suggestWord`, which makes `normalizeSeparators` throw"

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 1 | **`normalizeSeparators("")` は throw しない。`""` を返す** — `"".replace(...)`・`replaceAll(...)`・`trim()` はいずれも空文字に対して正常に動く | `(fess) helper/SuggestHelper.java:596-598`（`text.replace("　", TEXT_SEP).replaceAll(TEXT_SEP + "+", TEXT_SEP).trim()`） |
| 2 | **throw するのは引数が `null` のときである**（`null.replace(...)` → NPE） | 同上 |
| 3 | **空文字が `null` になるのは `getSuggestWord()` の中である。** `convertEmptyToNull(suggestWord)` を経由する | `(fess) opensearch/config/bsentity/BsElevateWord.java:190-193` |
| 4 | `convertEmptyToNull` は `value != null && value.length() == 0` を `null` に変換する | `(fess) opensearch/config/allcommon/EsAbstractEntity.java:199-201` |

> **「blank `suggestWord` → `normalizeSeparators` が throw」は 1 段飛ばしている。** 正しくは **「blank `suggestWord` → `getSuggestWord()` が `convertEmptyToNull` により `null` を返す → `normalizeSeparators(null)` が NPE」**である。**この 1 段を書かないと、読み手が `normalizeSeparators("")` を試して「throw しないではないか」となり、コメントが信用を失う。**

### 4.2 対応

**§5 の実装要件 8 に組み込んだ。** **`convertEmptyToNull` を経由することを明記させる。** **同じ誤りは `storeAllElevateWords` 側の Javadoc（`:408-412`「a row with a blank `suggestWord` or a missing `boost` can reach this method」）にはない**（そちらは「到達しうる」としか書いておらず、throw の機序に踏み込んでいない）[確認]。**是正対象は `deleteAllElevateWord` の Javadoc 1 箇所である。**

---

## 5. 実装側が満たすべき仕様（次工程への引き渡し）

> **本書はコードを変更していない** [確認]。以下は **A-2 の再実装を担当するエージェントが満たすべき最終形**であり、`0003` **第 13 版** §10.4 (e) / (j) の規則を擬似コードに落としたものである。
>
> **`0009` §7 の擬似コードは本節が上書きする。** **`0009` §7 を参照しないこと。**

**対象は `(fess) helper/SuggestHelper.java` ＋ `(fess) exec/SuggestCreator.java` の 2 行である。`modules/fess-suggest` は触らない。**

```text
// ===== 0) 受け渡し形 [確定] =====
//   失敗件数は ForRebuild メソッドの戻り値 int。
//   dedupe 用の Set は ForRebuild メソッドのローカル変数として生成し、private 実装へ引数で渡す。
//   SuggestHelper のインスタンスフィールドにしない（MO-25 の規則 4）。
//   dedupe の対象範囲 = ForRebuild メソッド 1 回の呼び出し全体（削除フェーズ ＋ 追加フェーズ）。

// ===== 1) public 3 メソッド: A-2 着手前と完全に同一の挙動へ戻す =====
//   void / fail-fast / 例外をそのまま伝播。呼び出し元 11 箇所は無変更。
public void storeAllElevateWords(final boolean apply) {
    storeAllElevateWordsInternal(apply, null);        // null = 失敗隔離なし
}
public void deleteAllElevateWord(final boolean apply) {
    deleteAllElevateWordInternal(apply, null);
}
public void storeAllBadWords(final boolean apply) {
    storeAllBadWordsInternal(apply, null);
}

// ===== 2) 再構築専用: SuggestCreator だけが呼ぶ =====
public int storeAllElevateWordsForRebuild() {
    final Set<String> failedIds = new HashSet<>();
    storeAllElevateWordsInternal(true, failedIds);    // 削除フェーズと追加フェーズが同じ Set を共有する
    return failedIds.size();                          // <- 行 ID で dedupe された「行数」
}
public int storeAllBadWordsForRebuild() {
    final Set<String> failedIds = new HashSet<>();
    storeAllBadWordsInternal(true, failedIds);
    return failedIds.size();
}

// ===== 3) private 共通実装 =====
//   failedIds == null -> 失敗隔離なし。例外はそのまま伝播する（public 経路）
//   failedIds != null -> 1 行ごとに catch し、行 ID を Set へ入れてループを継続する（再構築経路）

private void storeAllElevateWordsInternal(final boolean apply, final Set<String> failedIds) {
    deleteAllElevateWordInternal(apply, failedIds);   // 同じ Set を渡す = dedupe が両フェーズをまたぐ
    final List<ElevateWord> list = ...selectList(...);            // selectList は try の外（現状どおり）
    for (final ElevateWord elevateWord : list) {
        if (failedIds == null) {
            addElevateWord(elevateWord.getSuggestWord(), ..., elevateWord.getBoost(), apply);
            continue;                                 // fail-fast
        }
        try {
            addElevateWord(elevateWord.getSuggestWord(), ..., elevateWord.getBoost(), apply);
        } catch (final Exception e) {                 // 型を絞らない（規則 2）
            failedIds.add(elevateWord.getId());
            logger.warn("Failed to store an elevate word: id={}, word={}",
                        elevateWord.getId(), elevateWord.getSuggestWord(), e);
        }
    }
    refresh();                                        // <- 位置・回数は A-2 着手前と同じ（ループ外・末尾で 1 回）
}

private void deleteAllElevateWordInternal(final boolean apply, final Set<String> failedIds) {
    final List<ElevateWord> list = ...selectList(...);
    for (final ElevateWord elevateWord : list) {
        if (failedIds == null) {
            deleteOneElevateWordRow(elevateWord, apply);
            continue;                                 // fail-fast
        }
        try {
            deleteOneElevateWordRow(elevateWord, apply);
        } catch (final Exception e) {
            failedIds.add(elevateWord.getId());
            logger.warn("Failed to delete an elevate word: id={}, word={}",
                        elevateWord.getId(), elevateWord.getSuggestWord(), e);
        }
    }
    refresh();                                        // <- 現状どおり。storeAll 経由では refresh() が 2 回走るが、それも現状どおり
}

// A-1 / MO-24 が入れた 1 行分の処理。文面（正規化・両キー削除の条件）は変えない。
private void deleteOneElevateWordRow(final ElevateWord elevateWord, final boolean apply) {
    final String rawWord = elevateWord.getSuggestWord();
    final String normalizedWord = normalizeSeparators(rawWord);
    suggester.indexer().deleteElevateWord(normalizedWord, apply);
    if (!normalizedWord.equals(rawWord)) {
        suggester.indexer().deleteElevateWord(rawWord, apply);    // MO-24 の両キー削除
    }
}

private void storeAllBadWordsInternal(final boolean apply, final Set<String> failedIds) {
    deleteAllBadWords();                              // 隔離しない。例外はそのまま伝播（規則 5）
    final List<BadWord> list = ...selectList(...);
    for (final BadWord badWord : list) {
        if (failedIds == null) {
            suggester.indexer().addBadWord(badWord.getSuggestWord(), apply);
            continue;
        }
        try {
            suggester.indexer().addBadWord(badWord.getSuggestWord(), apply);
        } catch (final Exception e) {
            failedIds.add(badWord.getId());
            logger.warn("Failed to store a bad word: id={}, word={}",
                        badWord.getId(), badWord.getSuggestWord(), e);
        }
    }
    refresh();
}

// ===== 4) SuggestCreator の 2 行（A-2 の担当。A-3 ではない） =====
// :255  suggestHelper.storeAllBadWords(true);       ->  suggestHelper.storeAllBadWordsForRebuild();
// :258  suggestHelper.storeAllElevateWords(true);   ->  suggestHelper.storeAllElevateWordsForRebuild();
// A-2 では戻り値を捨ててよい。exitCode への合流は A-3 の作業内容 5。
```

### 5.1 実装要件

| # | 要件 | 根拠 |
| --- | --- | --- |
| **1** | **public 3 メソッドの挙動を A-2 着手前と完全に同一にする**（`void`・fail-fast・例外をそのまま伝播）。**呼び出し元 11 箇所は 1 行も変えない** | `0003` 第 13 版 §10.4 (e) の 6 ／ (i) |
| **2** | **`storeAllElevateWordsForRebuild()` / `storeAllBadWordsForRebuild()` を新設し、`apply = true` を固定する。** **Javadoc に「呼び出し元は `(fess) exec/SuggestCreator.java` のみ。管理画面／API から呼んではならない」と明記する** — 別パッケージのため package-private にできず、制約を型で強制できない | 同 (j) |
| **3** | **共通実装は private に 1 つだけ持ち、失敗隔離の有無を引数で切り替える。** **同じロジックの 2 実装を作らない** | 同 (e) の 6 ／ MO-24 の規則 1 |
| **4** | **失敗件数は「失敗した行の数」であり、行 ID（`getId()`）で dedupe する。** **`Set<String>` は `ForRebuild` メソッドのローカル変数とし、削除フェーズと追加フェーズで同じインスタンスを共有する。** **インスタンスフィールドにしない** | 同 (e) の 3・4 ／ (f) |
| **5** | **削除フェーズも隔離の対象である。** 追加ループだけに `try` を入れる実装は不可 | 同 (e) の 1 |
| **6** | **catch する型を絞らない**（`catch (final Exception e)`）。現に発生するのは NPE であり、L1 以降は `SuggestItem` の不変条件違反も加わる | 同 (e) の 2 |
| **7** | **`deleteAllBadWords()` は隔離しない。** 例外はそのまま伝播させる（`storeAllBadWordsForRebuild()` からも伝播する） | 同 (e) の 5 |
| **8** | **`deleteAllElevateWord` の Javadoc の誤りを是正する。** 現在の「a row with a blank `suggestWord` … makes `normalizeSeparators` throw」を、**「`getSuggestWord()` が `convertEmptyToNull` により空文字を `null` に変換するため `normalizeSeparators(null)` が NPE になる」**という 3 段の記述に改める。**`convertEmptyToNull` を経由することを必ず書く** | §4 ／ `(fess) opensearch/config/bsentity/BsElevateWord.java:190-193` ／ `(fess) opensearch/config/allcommon/EsAbstractEntity.java:199-201` |
| **9** | **`refresh()` の呼び出し位置と回数は A-2 着手前と同じにする。** 3 つの private 実装とも**ループの外・末尾で 1 回**。**`storeAllElevateWordsInternal` 経由では削除フェーズ内と末尾で合計 2 回走るが、それも A-2 着手前と同じである** — 減らさない | 同 (j) の表 ／ `0007` §2.3 の 7 |
| **10** | **警告ログの識別子は `getId()` を主にし、語（`getSuggestWord()`）は補助として第 2 引数に置く。** 例外 `e` は最終引数（スタックトレースを出す） | 同 (e) の 2 ／ `0007` §2.5 の 2（A-2 実装の判断を維持する） |
| **11** | **`(fess) exec/SuggestCreator.java:255` / `:258` の 2 行を `ForRebuild` の呼び出しに切り替える。** **それ以外の行に触れない。** **戻り値は捨ててよい**（コメントで「合流は A-3」と明記する） | 同 (j) |
| **12** | **`(fess) app/web/admin/backup/AdminBackupAction.java` には手を入れない** | `0003` §13 の 8 ／ (e) の 7 |
| **13** | **`modules/fess-suggest` を触らない** | 同 (h) ／ C-01 |
| **14** | **A-1 / MO-24 が書いた文（`normalizeSeparators` の実装・両キー削除の条件式）を変えない** | `0007` §2.5 の 4 と同じ規律 |

### 5.2 実装上の注意 [確認]

| # | 注意 |
| --- | --- |
| **1** | **`getId()` は `selectList` 経由の行に対して `null` にならない**（§2.2 の 2）。したがって `Set` へ `null` が入って複数行が 1 件に潰れる（**過小計上**）ことは起こらない。**ただし将来 `selectList` 以外の経路から行を渡す実装に変えるときは、この前提を再確認すること** [要確認] |
| **2** | **`if (failedIds == null) { X; continue; } try { X } catch ...` の形は、`X` の呼び出し文が 2 回書かれる。** `X` を private メソッド 1 呼び出しにすれば重複は 1 行に収まる（**ロジックの重複ではない**）。**`catch (Exception e)` 内で `throw e` する precise-rethrow 形でも挙動は同じだが、`if/continue` の形は「public 経路では `try` に一切入らない」ことがコード上で自明であり、挙動が変わっていないことをレビューで確認しやすい。後者を推奨する** [提案] |
| **3** | **「戻り値型だけを変える変更」では Maven の増分コンパイルが古いテストバイトコードを再利用しうる**（`0007` §2.7 の枠）。**本書の是正は `int` → `void` の**戻し**であり同じ落とし穴に当たる。** 症状は `NoSuchMethodError`。**`(fess test) helper/SuggestHelperTest.java` を `touch` するか `mvn clean` を挟むこと** |
| **4** | **検証は `mvn -o formatter:validate` ／ `mvn -o compile` ／ `mvn -o test -Dtest=SuggestHelperTest`**（`0007` §2.7 と同じ 3 点）。**既存 24 件が緑であることは是正の正しさの証拠にならない**（`suggester` 未注入で NPE を握る構造 — `0007` §1.11 の 2）。**機械的検証は A-6 が担う** |

---

## 6. 指摘 3・4 への対応（**対応不要 — 記録のみ**）

### 6.1 いずれも肯定的評価である

| # | 指摘 | 本書の扱い |
| --- | --- | --- |
| **3** | `deleteAllElevateWord` を保護した判断自体は正しい | **同意。MO-25 の規則 1（削除フェーズも隔離対象）は第 13 版でも維持する。** X-5 の中核的な発見（削除フェーズが追加ループのスキップ機構に到達する前に落ちる）は**依然として正しく、本書はそれを覆していない** |
| **4** | `storeAllBadWords` の形は良い | **同意。** 規則 5（`deleteAllBadWords()` は隔離しない。非対称は意図的）も維持する |
| **4 の後半** | 「public メソッドの通常の意味にしている点」は指摘 2 に含まれる | **そのとおり。§3 の対応に吸収される** — 保護そのものは正しく、**保護を置く場所が誤っていた** |

> **X-5 が発見した問題（削除フェーズの穴）と、X-6 が是正する問題（集計単位と適用範囲）は独立している。** X-5 の結論のうち規則 1・2・4・5・7 はすべて生き残っており、**覆るのは規則 3 と規則 6 の 2 つだけである。**

### 6.2 `catch (Exception)` について — **規則 2 は維持する**

**レビュアーは Blocker にしていない。** 理由（fail-closed で安全側・G3 に合流する）に同意する。

**ただし副作用の指摘があった: 障害時（OpenSearch 接続断など）に全行分の WARN が並びうる。** これは残存リスクとして §7 の 3 に記録した。**規則 2 を狭める（型を絞る）ことはしない** — 現に発生するのは NPE であり、型を絞ると X-5 が塞いだ穴が再び開く。

---

## 7. 残存リスク

| # | 残存リスク |
| --- | --- |
| **1** | **【本版で新たに引き受ける】public を fail-fast のまま残すため、「1 件の不正行があると管理画面／API からの編集・アップロードが失敗する」という現状は解消されない** [確認]。**第 12 版はこれを解こうとしていたが、本版は解かないことを選ぶ**（§3.3）。**本来の解は入口側バリデーション（`0003` §13 の 8）であり後続スコープである。** **管理画面が失敗すること自体は「気づく形で失敗する」ことでもあり、隔離して気づかせないよりは良い** — ただし**運用者から見れば「不正行があると elevate word を編集できない」という不便が残る。** **リリースノートに書く必要は無い（挙動が変わらないため）が、`0003` §13 の 8 の優先度を上げる材料にはなる** [提案] |
| **2** | **不正行は「スキップされる」だけで DB からは消えない**（`0009` §10 の 1 から不変）。毎回の再構築で同じ行が失敗し、**`exitCode != 0` により G3 が毎回切替を止める。** **運用者が DB の不正行を直すまでサジェストの世代が更新されなくなる。** これは意図した挙動（`0003` §4.2.2）だが、**「サジェストが古いまま」という症状で現れる。リリース時に運用者へ周知することを推奨する** [提案] |
| **3** | **【本版で追加】規則 2（例外の型を問わずスキップ）の副作用として、障害時に全行分の WARN が並びうる** [確認]。**OpenSearch への接続断のように「全行が同じ理由で落ちる」障害では、`getPageElevateWordMaxFetchSizeAsInteger()` の上限件数分の WARN がログに出る。** これは fail-closed（G3 が確実に切替を止める）と引き換えのコストであり、**規則 2 を狭めて回避すべきではない**（狭めると X-5 が塞いだ穴が再び開く）。**軽減するなら「同じ例外クラスが N 件連続したら以降を要約する」といったログ側の対処になるが、本タスクのスコープ外である** [提案] |
| **4** | **入口が開いたままである。** backup の `/_bulk` 復元は引き続き不正行を通す（`0003` §13 の 8。**規則 7 は不変**） |
| **5** | **`null` 以外の不正値は網羅していない** [要確認]（`0009` §10 の 3 から不変）。確認済みなのは `suggestWord` = `null` と `boost` = `null` の 2 種である。**`suggestWord` が空白のみ（`" "`）の行は `normalizeSeparators` が空文字にするため `createSuggestTextId("")` が空の `_id` を作る** — この経路の挙動は未確認。**「例外にならずに壊れたデータが書かれる」場合は規則 2 では拾えない。** L1 で `SuggestItem` の INV 検査が入れば追加側は塞がる（`0002` §5.2） |
| **6** | **失敗件数が `exitCode` へ届く経路は A-3 で完成する。** A-2 では `SuggestCreator` の呼び先を切り替えるところまでであり、**G3 に合流するのは A-3 の作業内容 5 である。** **A-2 のみをリリースしても切替は止まらない** |
| **7** | **`ForRebuild` の「`SuggestCreator` のみが呼ぶ」という制約は Javadoc でしか表明できない** [確認]。`SuggestHelper`（`org.codelibs.fess.helper`）と `SuggestCreator`（`org.codelibs.fess.exec`）が別パッケージのため package-private にできない。**将来 `ForRebuild` が管理画面から呼ばれれば、本版が撤回したはずの規則 6 が事実上復活する。** **A-6 の検査項目 4（public が例外を伝播すること）はこの回帰を検知できないため、`ForRebuild` の呼び出し元が `SuggestCreator` 1 箇所であることを別途 grep で確認することを推奨する** [提案] |

---

## 8. 次ステップへの申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **A-2 の再実装は §5 の擬似コードと要件 14 項目を最終形とする。** **`0009` §7 の擬似コードは本書が上書きしたので参照しないこと。** 特に **①public を fail-fast に戻す ②行 ID による dedupe ③`SuggestCreator` の 2 行の切替**の 3 点を落とさない | **ステップ A-2**（`code-implementer`） |
| **2** | **A-3 の作業内容 5 は「`ForRebuild` の戻り値を読む」形になる。** `(fess) exec/SuggestCreator.java:255` / `:258` は **A-2 の時点で `ForRebuild` 呼び出しに切り替わっており、戻り値だけが捨てられている状態**である。**A-3 はその戻り値を受けて `exitCode` へ合流させる。** **受け渡し形（`int` の戻り値）は本書で確定した** — A-3 で再検討する必要はない（`0009` §11 の 2 はこれで閉じる） | **ステップ A-3** |
| **3** | **A-6 の検査は 4 点になる**（`0003` 第 13 版 §10.4 (g)）: ①`getSuggestWord()` が `null` の行で削除フェーズが止まらない ②同じ入力で `storeAllElevateWordsForRebuild()` が完走し**失敗件数 1（等値）** ③`getBoost()` が `null` の行で追加フェーズが止まらず**失敗件数 1** ④**`storeAllElevateWords(false)` / `deleteAllElevateWord(false)` / `storeAllBadWords(false)` が従来どおり例外を伝播する**（回帰防止）。**「1 以上」で検査してはならない** — 等値でなければ二重計上の回帰を検知できない（§2.4）。**新しい T 番号は起こさない** | **ステップ A-6**（`test-io-verifier`） |
| **4** | **`0007` §2（A-2 の作業記録）は本書では更新していない。** 同節は第 12 版の実装を記録したものであり、**再実装後に別途更新する必要がある** — 特に §2.2 の行番号表・§2.3 の作業内容表・§2.4 の要件対応表・§2.9 の DoD 表・§2.11 の申し送り 3（「1 以上で検査すること」）は**すべて古い** | **A-2 の再実装後の作業記録** |
| **5** | **「設計どおり実装すると DoD が満たせない」を発見したときの判断規律** [提案]: **DoD を緩める向きの改訂を選んでよいのは、DoD 自体が実装不能な要求だった場合に限る。** X-5 はその確認を経ずに緩めた（§2.4）。**A-3 以降でも同種の判断が起こりうる** | **フェーズ A 以降の全ステップ** |
| **6** | **レビューに出す際は `0009`（X-5）と `0003` §10.4 を差分と一緒に渡すこと。** 今回のレビューは**規則 3 が「仕様として」書かれていることを知らずに二重計上をバグとして指摘した**が、**結果として仕様そのものの誤りを当てた。** 前提が揃っていれば「仕様が誤っている」と直接指摘でき、判定の精度が上がる（`0008` §6 の 2 と同旨） | **フェーズ A 以降のレビュー全般** |
| **7** | **`ForRebuild` の呼び出し元が `SuggestCreator` 1 箇所であることを、A-6 か F-5 で grep により確認すること** [提案]（§7 の 7） | **A-6 / F-5** |

---

## 9. 変更したファイル

| # | ファイル | 変更 |
| --- | --- | --- |
| **1** | `docs/0003-migration-ops-design.md` | **第 12 版 → 第 13 版**（§10 の詳細） |
| **2** | `0001-work-plan.md` | §2.2（X-6 の行を追加）／ §4 ステップ A-2 / A-3 / A-6 ／ §8 の DoD 16 ／ §9.1 の台帳（**0010 の追加とフェーズ B〜F の 0011〜0015 への繰り下げ**）／ §9.2（第 13 版の行） |
| **3** | `0010-review-response-a2.md` | **本書**（新規） |
| **4** | **`modules/` 配下** | **無変更** [確認]（`git status --short` は A-2 の実装分＝`src/main/java/org/codelibs/fess/helper/SuggestHelper.java` 1 件のまま。**本書の作業で新たに触っていない**） |
| **5** | **`0007-phase-a-fess-precede.md`** | **無変更**（§8 の 4 のとおり、再実装後に別途更新する） |

---

## 10. `0003` 第 13 版の改訂内容

**改訂したのは `docs/0003-migration-ops-design.md` の 1 本のみである**（`docs/0000` / `docs/0001` / `docs/0002` / `docs/0004` はいずれも無変更 — 理由は §11）。

| # | 箇所 | 内容 |
| --- | --- | --- |
| **1** | **冒頭「現在の版」**（`:3`） | 第 12 版 → **第 13 版**（2026-08-31） |
| **2** | **冒頭宣言**（`:17`） | **「第 13 版で是正する設計判断の誤り（逸脱 X-6・区分 I）」の 1 行を追加**（第 12 版の同種の行の直後・同じ書式） |
| **3** | **改訂履歴**（`:35`） | **第 13 版の行を追加。**「作業履歴」列は `20260822_implementation/0010` |
| **4** | **§0 の決定表の MO-25 行**（`:70`） | **規則 3（集計単位）と規則 6（適用範囲）の新しい内容に書き換えた。** 出典欄に **X-6** を追加 |
| **5** | **§4.2.2 の語管理経路の行** | **集計単位への参照を「合算値」から「失敗した行の数（行 ID で dedupe）」に是正。** **「二値でしか使わないことは集計単位の選択根拠にはならない」ことを明記**し、選択根拠は §10.4 (f) にあると示した。**呼び出す対象も `ForRebuild` 2 メソッドに改めた** |
| **6** | **§10.4 の表題**（`:939`） | 「**第 12 版で全面改訂**」に「**第 13 版で規則 3・6 を是正**」を併記。逸脱番号を **X-5 / X-6** に |
| **7** | **§10.4 冒頭の「対象」**（`:943`） | 「`SuggestHelper.java` の 3 メソッド」→ **「`SuggestHelper.java` ＋ `SuggestCreator.java` の 2 行」**。**public 3 メソッドの挙動を変えないことと、失敗隔離が `ForRebuild` 2 メソッドに閉じることを明記** |
| **8** | **§10.4 (e) の規則 3** | 「削除フェーズと追加フェーズの合算・項目処理単位」→ **「失敗した行の数。行 ID（`getId()`）で dedupe し、同一行が両フェーズで落ちても 1 件と数える」**。**第 12 版の定義を撤回すると明記** |
| **9** | **§10.4 (e) の規則 6** | 「管理画面 3 経路にも及ぶ。これは受け入れる」→ **「失敗隔離は再構築専用の内部経路に限定する。public 3 メソッドの挙動は A-2 着手前と完全に同一に保つ。共通実装は private に 1 つだけ持ち引数で切り替える」**。**撤回すると明記し、根拠を (i) に委譲** |
| **10** | **§10.4 (e) の規則 1・2・4・5・7** | **維持。文言のみ整合**（規則 1 に「適用先は再構築専用の内部経路である」を追記／規則 4 を「`ForRebuild` の戻り値として返す」に／規則 4 に「dedupe に使う `Set` もメソッドローカル」を追記／規則 5 の「`storeAllBadWords` の削除フェーズ」を「bad word 側の削除フェーズ」に／規則 7 に第 13 版でも不変であることを明記） |
| **11** | **§10.4 (f) を全面的に書き直した** | 表題を「失敗件数を合算する根拠」→ **「失敗件数の集計単位の根拠」**。**第 12 版の 4 根拠の再評価表**（1〜3 は「フェーズ別に 2 つ返す案」の否定にしか効かない／4 は事実誤認）＋ **行数を採る根拠 4 件**（運用者が読む数としての意味／実装のループ段数に追随しない／実装可能でコストが小さい／DoD が等値で閉じられ回帰検知能力が上がる）。**末尾の「A-2 の DoD は 1 以上で閉じる」を「1（等値）で閉じる」に改めた** |
| **12** | **§10.4 (g)（検証）** | 検証項目 3 点を新しい集計単位に合わせて是正（**「1 以上」→「1（等値）」**）し、**4 点目「public 3 メソッドが従来どおり例外を伝播すること」（回帰防止）を追加した** |
| **13** | **§10.4 (h)（`0002` / `0001` への波及）** | **結論は不変（波及なし）。** **`ForRebuild` 2 メソッドも fess 本体側であり結論を変えない**ことを 1 文追記 |
| **14** | **§10.4 (i) を新設** | **「失敗隔離を再構築経路に限定する根拠」**。**撤回した旧根拠 2 件**（一方は依然として一理あることを認める／一方は前提が誤り）＋ **撤回した理由 4 件**（同期 4 経路の検知手段の喪失／非同期 4 経路では利益が小さい／MO-25 の目的外／規則 7 と組み合わせると検知の契機が残らない）＋ **引き受けるコストの明記** |
| **15** | **§10.4 (j) を新設** | **「対象メソッドと、A-2 / A-3 の担当範囲の境界」**。public / `ForRebuild` / private の 3 段の表 ／ **`ForRebuild` を public にせざるを得ない理由**（別パッケージ）／ **`SuggestCreator` の 2 行の切替を A-2 が行う理由 3 件** ／ **A-2 と A-3 の担当範囲の表** ／ **MO-1 と衝突しないことの明記** |

**変更していないもの** [確認]: **MO-1〜MO-24 は無変更。** **mapping・§3〜§9（§4.2.2 を除く）・§11 のテスト仕様（新しい T 番号を起こしていない）・§12・§13 の 8（復元時バリデーションは後続スコープ）はいずれも無変更。** **§10.4 の (a)〜(d) も無変更である** — X-5 が確認した事実（入口・取りこぼし・根拠 8 件・帰結 3 件）は本版でも正しい。**節記号 (a)〜(h) を振り直していない**ため、`0009` やプランからの既存参照（「§10.4 (e) の 5」など）は壊れていない。

---

## 11. スコープ外（変更していないもの）

| # | 対象 | 理由 |
| --- | --- | --- |
| **1** | **`modules/` 配下のすべてのコード・リソース** | **逸脱手続きは「改訂を先に行う」ことを要求する**（プラン §2.1）。**A-2 の再実装は本書の完了後に別途行う。** A-1 ＋ A-2 の未コミット変更はそのまま残してある |
| **2** | **`docs/0002-datamodel-design.md`** | **本件は `0002` の決定を変えない。** DM / INV 番号・mapping・§7 のテスト仕様はいずれも不変であり、**変わったのは fess 本体側の制御フローに関する `0003` の規則 3・6 だけ**である [確認] |
| **3** | **`docs/0001-api-design.md`** | **公開契約に影響しない** [確認]。**`ForRebuild` 2 メソッドは `(fess) helper/SuggestHelper.java` のメソッドであり、`modules/fess-suggest` には型もメソッドも追加しない**（`0003` 第 13 版 §10.4 (h) / (j)）。**MO-1 とも衝突しない** |
| **4** | **`docs/0000-design-overview.md` / `docs/0004-corrections.md`** | 凡例・番号台帳・訂正一覧のいずれにも影響しない（**MO 番号を新設していないため `0000` §3.4 の台帳の行は増えない**） |
| **5** | **`0007-phase-a-fess-precede.md`** | **A-2 の記録の更新は再実装後に別途行う**（§8 の 4） |
| **6** | **`0003` §11 のテスト仕様（T 番号）** | **新しい T 番号を起こしていない。** MO-25 の検証はプラン A-2 の DoD ＋ A-6 の作業内容 2 が担う |
| **7** | **`agent_docs/tasks/20260706_design_document/docs/` の 5 本** | **凍結スナップショットである**（プラン §2.3 / Q7=(A)）。一切変更していない |

---

## 12. 参照した一次情報

### 12.1 プロダクションコード / リソース

**すべて本作業で実物を開いて確認した** [確認]。**個々の行番号は本文の各主張に付してあるため再掲しない。**

- **fess 本体**: `(fess) helper/SuggestHelper.java`（作業ツリー — A-1 ＋ `0008` ＋ A-2 適用後）／ `exec/SuggestCreator.java:243-304` ／ `app/web/admin/elevateword/AdminElevatewordAction.java` ／ `app/web/api/admin/elevateword/ApiAdminElevatewordAction.java` ／ `app/web/admin/badword/AdminBadwordAction.java` ／ `app/web/api/admin/badword/ApiAdminBadwordAction.java` ／ `opensearch/config/exentity/ElevateWord.java` ／ `opensearch/config/exentity/BadWord.java` ／ `opensearch/config/bsentity/BsElevateWord.java` ／ `opensearch/config/allcommon/EsAbstractEntity.java` ／ `opensearch/config/allcommon/EsAbstractBehavior.java`

### 12.2 タスク内文書

| 文書 | 用途 |
| --- | --- |
| `0001-work-plan.md` | §2.1（逸脱手続きの区分）／ §2.2（逸脱一覧）／ §4 ステップ A-2 / A-3 / A-6 ／ §8 の DoD 16 ／ §9.1 の台帳と繰り下げ規則 |
| `0008-review-response-a1.md` | **§2.4 の 4（「決定そのものの変更なら新しい X 番号 ＋ プラン §2.2・§8・§4 の修正が必要であり、追補改訂とは手続きの重さが違う」）＝ 本書 §3.2 の判定基準** ／ §2.5（X 番号を起こさない先例）／ **本書の書式の雛形** |
| `0009-deviation-x5-store-all-delete-phase.md` | **X-5 / MO-25 の全文** ／ §4.2 の案 (b)（本書が採用に転じたもの）／ §4.3 の案 (c)（同）／ §5（本書が撤回した合算の根拠）／ §7（本書が上書きした擬似コード）／ §10（残存リスクの継承元） |
| `0007-phase-a-fess-precede.md` | §2（A-2 の実装記録。**本書は変更していない**）／ §2.7 の枠（増分コンパイルの落とし穴） |
| `docs/0003-migration-ops-design.md` | **§10.4（改訂対象）** ／ §4.2 / §4.2.2（G3）／ §4.2.1・§4.3（MO-1 の解釈）／ §10.1（先行リリースの位置づけ）／ §10.3.1（MO-24。両キー削除が移行期の暫定であること）／ §13 の 8 |

---

## 13. 【2026-08-31 追記】**2 回目の外部レビュー（Approve・軽微修正推奨）の反映**

> **本節は §1〜§12 を書き換えていない。** §1〜§12 は**1 回目のレビュー（Request changes）**への対応記録であり、履歴としてそのまま残す。**本節はその後に受けた 2 回目のレビューへの対応だけを記録する。**

### 13.1 位置づけ — 1 回目と 2 回目の関係

| 回 | 対象 | 判定 | 帰結 | 記録 |
| --- | --- | --- | --- | --- |
| **1 回目** | **第 12 版に基づく A-2 の実装** | **Request changes**（Blocker 1 ／ Major 1 ／ Minor 1 ＋ 肯定 2） | **`0003` を第 13 版へ改訂（逸脱 X-6・区分 I）し、実装を書き直した** | **本書 §1〜§12** ／ 書き直し後の実装は `0007` §2 |
| **2 回目** | **書き直し後の実装**（`0007` §2 が記録しているもの） | **Approve（軽微修正推奨）** | **コード修正を要したのは Javadoc 2 種のみ。設計判断は 1 つも動いていない** | **本節（§13）** |

**2 回目の指摘は 3 件である。**

| # | 指摘 | 本書の判定 | 対応 |
| --- | --- | --- | --- |
| **1** | **作業プラン ／ A-6 のテスト仕様が古い形のまま**（`storeAllElevateWords` のループを skip+warn にする／不正な elevate word 1 件で `storeAllElevateWords` が完走して failure=1）。**このまま A-6 のテストを書くと、fail-fast 版に対して「完走しろ」という逆のテストを書きかねない** | **指摘の懸念は妥当。ただし対応は不要である** — **第 13 版（X-6）の改訂で既に是正済みであり、レビュアーが参照したのは改訂前のプランである** [確認] | **§13.2**（コード・プランとも無変更） |
| **2** | **Javadoc 2 種が不正確** — (a) `deleteAllElevateWord` の「which calls this method before its own add phase」／ (b) 「admin screen and API callers … turn a propagated exception into a validation error shown to the operator」という一般化 | **いずれも正しい** [確認] | **採用・修正済み**（**Javadoc 3 ブロック**。実行文は 0 行）— **§13.3** |
| **3** | **A-3 で failure count を確実に G3 へ接続すること。** このコミットだけを本番リリースすると「不正 row を skip → failure count を捨てる → `create()` はそのまま `switchIndex()`」となり安全でない | **正しい。ただし A-2 の実装バグではない** — **A-2 / A-3 がセットであることの帰結であり、フェーズ A は A-6 まで完了してから先行リリースする前提である** | **A-3 への申し送り** — **§13.4** |

### 13.2 指摘 1 — **レビュアーが参照したのは改訂前のプランである** [確認]

**現行のプラン `0001-work-plan.md` を実物で開いて確認した。指摘が想定した「古い形」はいずれも残っていない。**

| # | レビュアーが懸念した記述 | **現行プランの実物** | `file_path:line` |
| --- | --- | --- | --- |
| **1** | 「`storeAllElevateWords` のループを skip+warn にする」 | **対象欄が 3 段に分かれている**: **public 3 メソッド**（`storeAllElevateWords(boolean)` ／ `deleteAllElevateWord(boolean)` ／ `storeAllBadWords(boolean)`）＝ **挙動を A-2 着手前と完全に同一に保つ**（`void`・fail-fast）／ **再構築専用 2 メソッド**（`ForRebuild`）＝ **新設**・失敗隔離あり ／ **private 共通実装** ＝ 隔離の有無を引数で切り替える | `0001-work-plan.md:443-446`（public = `:444` ／ `ForRebuild` = `:445` ／ private = `:446`）。**作業内容 6 も同旨**（`:459-461`） |
| **2** | 「不正な elevate word 1 件で **`storeAllElevateWords`** が完走して failure=1」 | **DoD は `storeAllElevateWordsForRebuild()` について書かれている** — 「不正な elevate word を 1 件含む入力で **`storeAllElevateWordsForRebuild()` が完走し、失敗件数 1 を報告する**こと」。**public メソッド名は現れない** | `0001-work-plan.md:467` |
| **3** | （同上・public の挙動が保証されない） | **DoD に「public 3 メソッドの挙動が A-2 着手前と完全に同一である」ことが独立項目として入っている**（`void` を返し、同じ不正行に対して例外をそのまま伝播する。呼び出し元 11 箇所が無変更） | `0001-work-plan.md:470`（**【X-6 で追加】**） |
| **4** | 「A-6 で fail-fast 版に対して『完走しろ』という逆のテストを書きかねない」 | **A-6 の作業内容 2 は 4 点検査になっており、④が回帰防止検査である** — 「**`storeAllElevateWords(false)` / `deleteAllElevateWord(false)` / `storeAllBadWords(false)` が、同じ不正行に対して従来どおり例外を伝播する**こと」。**①〜③はすべて `*ForRebuild()` を対象としており、public を対象にした「完走しろ」という項目は存在しない** | `0001-work-plan.md:586-592`（④ = **`:590`**。①= `:587` ／ ②= `:588` ／ ③= `:589`）。**DoD 側も同じ**（`:602`「作業内容 2 の MO-25 検証 4 点（①〜④）が緑」／ `:603`「失敗件数の検査が『1 以上』ではなく『1』（等値）」） |

> **④の存在が、レビュアーの懸念した「逆のテスト」を構造的に防ぐ** [確認]。**①〜③（`ForRebuild` は完走する）と④（public は例外を伝播する）が同じ作業内容の中に並んでおり、両者を取り違えると④が落ちる。**

**したがって指摘 1 に対するプランの改訂は行わない。** 是正は X-6 の反映（`0001-work-plan.md:1918` の注記が記録している範囲）で完了していた [確認]。**`0003` 第 13 版 §10.4 (g) の検証項目も同様に 4 点である**（`docs/0003-migration-ops-design.md:1034-1044`）[確認]。

> **[提案] レビューに出す際は、プランの該当ステップ（A-2 / A-6）の現行版を差分と一緒に渡すこと。** 本件は**改訂前のプランを前提に「実装とプランが食い違う」と読まれた**ものであり、`0008` §6 の 2 ／ 本書 §8 の 6 と同じ構造の再発である。**指摘の内容自体は正しく、渡す資料が揃っていれば「プランは既に是正済み」と即断できた。**

### 13.3 指摘 2 — **Javadoc 2 種の是正（採用・修正済み）**

#### (a) `deleteAllElevateWord` の「which calls this method before its own add phase」

| 項目 | 内容 |
| --- | --- |
| **指摘** | リファクタ後は **`storeAllElevateWords` がこの public メソッドを直接呼んでいない** |
| **事実確認** [確認] | `storeAllElevateWords` → `storeAllElevateWordsInternal`（`(fess) helper/SuggestHelper.java:422` → `:602`）→ `deleteAllElevateWordInternal`（`:605` → `:641`）。**public の `deleteAllElevateWord`（`:453`）を経由しない。** 逆に `deleteAllElevateWord` 自身も `deleteAllElevateWordInternal(apply, null)` へ委譲するだけの facade である（`:454`） |
| **是正後の文面**（`:443-448`） | 「`storeAllElevateWords` **はこのメソッドを直接呼ばない。両者は同じ private 共通実装に委譲し、その実装が追加の前に対応する削除フェーズを走らせる**」 |

#### (b) 「admin screen and API callers … turn a propagated exception into a validation error」という一般化

| 項目 | 内容 |
| --- | --- |
| **指摘** | **すべての呼び出し元が validation error に変換するかのように読める** |
| **事実確認** [確認] | **同期 4 経路は変換する／非同期 4 経路は変換しない。** 本書 §3.1 の 8 経路表を実物で再確認した（行番号も現物と一致する）: **同期** = `AdminElevatewordAction.update()`（`:372`・catch → `:384` `throwValidationError`）／ `ApiAdminElevatewordAction.put$setting()`（`:171`・→ `:181` `throwValidationErrorApi`）／ `AdminBadwordAction.update()`（`:341`・→ `:352`）／ `ApiAdminBadwordAction.put$setting()`（`:148`・→ `:157`）。**非同期** = `AdminElevatewordAction.upload()`（`:428`・`CommonPoolUtil.execute` `:431` → `:437` `FessSystemException`）／ `ApiAdminElevatewordAction.put$upload()`（`:231`・`:233` → `:238`）／ `AdminBadwordAction.upload()`（`:396`・`:399` → `:404`）／ `ApiAdminBadwordAction.put$upload()`（`:205`・`:207` → `:212`）。**非同期側はレスポンスを返した後の背景タスクであり、`FessSystemException` は運用者に validation error としては表示されない** |
| **是正後の文面** | **同期経路と非同期経路を書き分けた。** `storeAllElevateWords`（`:411-415`）= 「In the synchronous ones (`AdminElevatewordAction#update()` and `ApiAdminElevatewordAction#put$setting()`) a propagated exception becomes a validation error shown to the operator …; **the CSV upload paths run in a background task instead, where it surfaces as a `FessSystemException`**」／ `storeAllBadWords`（`:706-712`）= 「… reaches the operator as a validation error **from the synchronous callers** (`AdminBadwordAction#update()` and `ApiAdminBadwordAction#put$setting()`) and as a `FessSystemException` **from the background CSV upload paths**」 |

#### 是正の範囲 — **Javadoc 3 ブロック・実行文 0 行** [確認]

| # | Javadoc ブロック | 位置（現作業ツリー） | 是正内容 |
| --- | --- | --- | --- |
| **1** | `storeAllElevateWords(boolean)` | **`:406-420`**（旧 `:406-419`・**+1 行**） | (b) — 同期／非同期の書き分け |
| **2** | `deleteAllElevateWord(boolean)` | **`:425-452`**（旧 `:424-449`・**+2 行**） | (a) — 「直接呼ばない／同じ private 共通実装に委譲する」 |
| **3** | `storeAllBadWords(boolean)` | **`:703-716`**（旧 `:700-711`・**+2 行**） | (b) — 同期／非同期の書き分け |

> **実行文を 1 行も変えていないことの根拠** [確認]:
>
> | # | 根拠 |
> | --- | --- |
> | **1** | **`git diff --numstat` の削除行数が動いていない** — `SuggestHelper.java` は **260 / 46**（1 回目反映時の記録は **255 / 46** ＝ `0007` §2.2）。**削除が 46 のまま増えていない**ため、**HEAD 由来の行は 1 行も追加で消えていない。** 増分 5 行はすべて作業ツリー内で新規に足した行（＝ A-2 が新設した Javadoc）である |
> | **2** | **増分 5 行が上表の +1 / +2 / +2 と一致する** |
> | **3** | **メソッド位置のずれが上表から機械的に導ける値と完全に一致する** — `deleteAllElevateWord` 以降が **+3**、`storeAllBadWords` 以降が **+5**（例: `normalizeSeparators` 本体 `:578-580` → **`:581-583`** ／ `storeAllBadWordsInternal` 本体 `:760-779` → **`:765-784`**）。**実行文を挿入・削除していれば、この 2 種類のずれ幅では説明がつかない** |
> | **4** | **`(fess) exec/SuggestCreator.java` は無変更**（**5 / 2** のまま。呼び先は `:257` / `:261`）[確認] |

> **本書 §4.2 は「是正対象は `deleteAllElevateWord` の Javadoc 1 箇所である」と書いていたが、2 回目のレビューで `storeAllElevateWords` / `storeAllBadWords` の 2 ブロックが追加された** [確認]。**§4.2 が扱っていたのは「`normalizeSeparators` が throw する機序」の誤りであり、2 回目の (b) は「エラー契約の一般化が過剰」という別の誤りである。** 両者は同じ Javadoc の別の主張であり、§4.2 の判定が誤っていたわけではない。**プランの作業内容 9（`0001-work-plan.md:464`）も `deleteAllElevateWord` のみを対象としているが、対象外のブロックを正確にすることは作業内容の違反ではないため、プランは改訂しない。**

### 13.4 指摘 3 — **A-3 への申し送り（本書では対応しない）**

| # | 判定 |
| --- | --- |
| **1** | **指摘の事実認識は正しい** [確認]。`(fess) exec/SuggestCreator.java:257` / `:261` は `ForRebuild` を式文として呼んでおり、**戻り値の `int` を捨てている。** `:301` の `switchIndex()` はその値に依存しない |
| **2** | **ただし A-2 の実装バグではない。** **A-2 = 呼び先の切替まで／A-3 = 戻り値の `exitCode` 合流、という分業が `0003` 第 13 版 §10.4 (j) で確定している**（本書 §5 の 4 ／ §8 の 2）。**プラン A-2 の DoD 7 も「失敗件数が A-3 の `exitCode` 判定に到達する（**A-3 で完成する**）」と明記している**（`0001-work-plan.md:472`）[確認] |
| **3** | **「このコミットだけを本番リリースする」という前提が成立しない。** **フェーズ A は A-6 まで完了してから先行リリースする**（`0001-work-plan.md:610`「フェーズ A の完了 = 先行リリース可能。ここまでを 1 つのリリースとして出してから L1 を出す」）[確認]。`0007` の進捗表も「**A-6 まで終わるまでフェーズ A はリリースできない**」と明記している |
| **4** | **同じリスクは本書 §7 の 6 に残存リスクとして既に記録してある**（「A-2 のみをリリースしても切替は止まらない」）。**2 回目のレビューはそれを独立に再発見したものであり、記録の妥当性を裏づけている** |

**対応**: **A-3 の作業内容 5 が担う。** 本書 §8 の 2 ／ `0007` §2.11 の 1 ／ `0007` §3 の引き継ぎ表の 2 に既に申し送り済みであり、**`0007` §2.11 に本指摘を明示的に加えた**（§13.6）。

### 13.5 区分の判定 — **[確定] 逸脱手続きは発火しない**

**プラン §2.1（`0001-work-plan.md:152-159`）に照らした。**

| # | 判定と根拠 |
| --- | --- |
| **1** | **区分 I ではない。** 区分 I の判定基準は「設計書どうしが矛盾する／設計どおり実装すると成立しない／L1 という状態が扱われていない」である。**本件で変わったのは Javadoc の事実記述だけであり、MO-25 の規則 1〜7 も §10.4 (f) / (i) / (j) も 1 文字も変わらない** [確認] |
| **2** | **区分 II でもない。** 区分 II は**設計書の軽微改訂**（該当箇所の値のみ更新）を伴う手続きである。**本件は `docs/0003-migration-ops-design.md` を一切改訂していない** — 是正したのは**プロダクションコード側の Javadoc** であり、設計書に対応する記述が存在しない |
| **3** | **したがって `0003` の改訂は不要であり、新しい X 番号も新しい MO 番号も起こさない** [確定]。**版も上げない**（第 13 版のまま） |
| **4** | **先例と整合する。** `0008`（A-1 のレビュー反映）は `0003` の**根拠欄**を是正したため区分 I の追補改訂として扱ったが（本書 §1.2 の表）、**本件は設計書に触れないためそれより 1 段軽い。** **`0008` §2.4 の 4 が定める「決定そのものの変更」の対極である** |
| **5** | **仮に本件を X-7 として起こすと、台帳（プラン §2.2 の「発火 6 件」）が「設計判断が変わっていない事象」で汚れる。** 逸脱台帳は**設計書の版と 1 対 1 に対応させる**運用であり（§1.2 の 3）、**版を上げない改訂に番号を与えない** |

> **プラン側の反映は §9.2 の末尾注記に 1 行を足すに留めた**（§13.6）。**ステップ A-2 / A-6 の本文は改訂していない** — §13.2 のとおり既に正しいためである。

### 13.6 検証結果 [確認]

**本節の執筆にあたり、`modules/fess` で 4 件を独立に再実行した。**

| コマンド | 結果 |
| --- | --- |
| `mvn -o formatter:validate` | **`BUILD SUCCESS`** ／ `Processed 1694 files (Formatted: 0, Skipped: 1694, Unchanged: 0, Failed: 0, Readonly: 0)` ／ Total time 4.504 s（`license:check` と同時実行） |
| `mvn -o license:check` | **`BUILD SUCCESS`** ／ `License check: 1694 file(s) checked (OK: 1694, Missing: 0, Unknown: 0)` |
| `mvn -o compile` | **`BUILD SUCCESS`** ／ **`Warnings: 0, Errors: 0`** ／ Total time 10.512 s |
| `mvn -o test -Dtest=SuggestHelperTest` | **`Tests run: 24, Failures: 0, Errors: 0, Skipped: 0`** → **`BUILD SUCCESS`** ／ Total time 23.743 s |
| `git diff --stat`（`modules/fess`・HEAD = `73e912715`） | **2 files changed, 265 insertions(+), 48 deletions(-)** — `SuggestCreator.java` **7 行**（5 / 2）／ `SuggestHelper.java` **306 行**（260 / 46） |

> **実装エージェントは `mvn -o formatter:format license:format`（差分なし）を実行している。本節ではソースを書き換えない読み取り専用の `validate` / `check` で同じ結論を確認した**（`0007` §1.7 / §2.7 と同じ扱い）。
> **`modules/fess-suggest` は無変更**（`git status --short` が空・ブランチは `feature/suggest-l1`）[確認]。**テスト実行後も `modules/fess` の `git status --short` は 2 ファイルのままである** [確認]。

### 13.7 変更したファイル

| # | ファイル | 変更 |
| --- | --- | --- |
| **1** | **`0010-review-response-a2.md`** | **本節（§13）を追加。§1〜§12 は無変更** |
| **2** | **`0007-phase-a-fess-precede.md`** | **§2 冒頭の追記ブロック／§2.2 の行番号表と差分値／§2.3・§2.4・§2.9 の行番号／§2.7 の検証結果／§2.11 の申し送り／進捗表・メタ表**を更新（**本節の反映を織り込んだ**） |
| **3** | **`0001-work-plan.md`** | **§9.2 の末尾反映注記に 1 行を追加したのみ**（**ステップ A-2 / A-6 は無変更** — §13.2 / §13.5） |
| **4** | **`docs/0003-migration-ops-design.md`** | **無変更**（第 13 版のまま）[確認] — §13.5 |
| **5** | **`modules/` 配下** | **本節の作業では無変更** [確認]。**Javadoc 3 ブロックの是正は本節の執筆前に適用・検証済みである** |

> **本書 §9 の表（1 回目の反映時点）は「`0007` は無変更」「`modules/` は無変更」と書いているが、それは §1〜§12 の作業についての記述である。** **本節の時点では上表が正である。**

### 13.8 未確定事項・申し送り

| # | 申し送り | 宛先 |
| --- | --- | --- |
| **1** | **A-3 は `ForRebuild` の戻り値を必ず `exitCode` へ合流させること**（2 回目のレビュー指摘 3）。**合流しない限り、不正行が skip されたまま `switchIndex()` が走る**（`(fess) exec/SuggestCreator.java:257` / `:261` → `:301`）。**A-2 と A-3 を分けて先行リリースしてはならない** | **A-3**（作業内容 5） |
| **2** | **プラン A-6 の作業内容 2 の④（public 3 メソッドが例外を伝播することの回帰検査）を落とさないこと** [確認]。**2 回目のレビュアーが懸念した「fail-fast 版に対して『完走しろ』という逆のテスト」は、④が無いと検知できない**（`0001-work-plan.md:590`） | **A-6** |
| **3** | **[提案] レビュー依頼時に、プランの該当ステップの現行版を差分と一緒に渡すこと。** 指摘 1 は**改訂前のプランを前提とした指摘**であった。**本書 §8 の 6 と同じ再発である** | **フェーズ A 以降のレビュー全般** |
| **4** | **[提案] Javadoc に呼び出し元クラス名を列挙する記述は、実物と乖離しやすい** [確認]。今回是正した (b) は**列挙を「同期／非同期」で括り直す**ことで正確になったが、**呼び出し元が増減すれば再び古くなる。** F-5 の最終検証で `(fess) helper/SuggestHelper.java` の Javadoc が挙げる 4 クラスの実在を grep で確認することを推奨する | **F-5** |
