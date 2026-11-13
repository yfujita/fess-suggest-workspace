# 0004 新規発見事項の棚卸しと処遇決定

> タスク: `20260706_design_document`（作業プラン `0003-design-document-work-plan.md` §3 ステップ 1）
> 実施日: 2026-08-10
> 目的: 作業プラン §2 の **F-01〜F-12** を正式な記録に落とし、全件を「設計に織り込む / 処遇が確定済み / 後続タスク（スコープ外）」のいずれかと、着地先（設計書と節）に機械的に割り当てる。

---

## 1. 概要

本書はステップ 1 の成果物である。設計書 4 本（`docs/0000`〜`0003`）の執筆中に、プラン作成時のコード追検証で判明した事実が**どこにも着地しないまま消える事故**を防ぐことを目的とする。

- 本書作成にあたり、F-01〜F-12 の根拠をすべて**実コードで再確認**した。プラン §2 の記述と食い違った点は §6「プラン記載の訂正」に列挙する（結論が変わったものは無い）。
- **新規 ISS は提案書（`docs/improvement-proposal.md`）に起票しない**。P9 により過去資料は凍結されているため、既存 ISS に該当しない発見は**本書と `docs/0000-design-overview.md` の「既存資料に対する訂正一覧」で扱う**。
- ファイルパスは各モジュールルート以下の短縮表記。無印は `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下、`(fess)` 付きは `modules/fess/src/main/java/org/codelibs/fess/` 配下、`(res)` 付きは `modules/fess-suggest/src/main/resources/` 配下を指す。

---

## 2. 凡例

作業プラン・改善提案書と同一。

- **[事実] / [確認]**: ソースコード・実機・一次情報で直接確認できたもの。本書の F-01〜F-12 はすべてこれに該当する。
- **[提案]**: 設計提案。断定ではない。
- **[確定]**: `0001-unresolved-items-resolution.md` またはプラン §1.1 / §6.1 で決定済みのもの。
- **[要確認]**: 未解消。**本書には 1 件も存在しない**（ステップ 1 時点で未決の事項は「どのステップで決めるか」を着地先として記載した）。

---

## 3. F-01〜F-12 の詳細

### F-01 `reading_i` の `i` は「text の語インデックス」であり上限が存在しない [確認]

- **内容**: 書き込みは `readings.length`（= text の語数）だけ `reading_0`, `reading_1`, ... を生成する。読み出しは `i` を無限にインクリメントし `reading_i` が存在しなくなるまで走査する。検索はクエリの語数分しか引かない。したがって**フィールド数の上限はコード上どこにも存在しない**。
- **根拠**: `entity/SuggestItemSerializer.java:59-63`（`toSource`）、`:146-158`（`toUpdatedSource`）、`:87-95`（`fromSource` の無限ループ）、`request/suggest/SuggestQueryBuilder.java:84-86`、`entity/SuggestItem.java:81`（`String[][] readings`）
- **設計への影響**: `20260622_improvement_proposal/0005-schema-draft.md` 案 A の前提（`MAX_READING_NUM=10` により `reading_0..9` の 10 本に確定）は**誤り**。`dynamic:"strict"` + `reading_0..9` の明示列挙を採ると、11 語以上の item が `strict_dynamic_mapping_exception` で失敗する。→ ステップ 4 で `dynamic` 方針を決める。

### F-02 `getMaxReadingNum`（既定 10）は「1 語あたりの読み候補数」の上限 [確認]

- **内容**: F-01 の直接の根拠。`ReadingConverter#getMaxReadingNum` はフィールド数の上限ではなく、1 語に対して何通りの読みを生成するかの上限である。
- **根拠**: `converter/ReadingConverter.java:31-33`（`default int getMaxReadingNum() { return 10; }`、Javadoc も "maximum number of readings"）
- **設計への影響**: `0005-schema-draft.md` の `MAX_READING_NUM` 誤認を訂正一覧に載せる根拠。

### F-03 語数制限は queryLog 経路にしかなく、fess が実際に使う経路には無い [確認]

- **内容**: `MAX_QUERY_TERM_NUM = 5` / `MAX_QUERY_TERM_LENGTH = 48` は `SuggestUtil.parseQuery` の内部制限であり、queryLog 経路でしか効かない。fess 本体が使う `indexFromSearchWord` 経路は空白正規化後に `split(" ")` するだけで**語数無制限**。
- **根拠**: `util/SuggestUtil.java:63,64`（定数）、`:99-110`（`parseQuery`）、`index/operations/ContentIndexingOperations.java:401-412`（`:412` が `buf.toString().trim().split(" ")`。語数チェック無し）、`(fess) helper/SuggestHelper.java:252`（`indexFromSearchWord` 呼び出し。語数チェック無し）
- **設計への影響**: `reading_*` のフィールド数は理論上 `index.mapping.total_fields.limit`（既定 1000）まで到達しうる。→ ステップ 4 で「書き込み側の語数上限」（U3 [確定]）と `total_fields.limit` の明示要否を決める。

### F-04 書き込みは `OpType.INDEX` の全置換であり、`toUpdatedSource` が出力しないキーは消える [確認]

- **内容**: `update && getResponse.isExists()` の分岐でも `OpType.INDEX` を指定しており、部分更新ではなく**ドキュメント全体の置換**である。`toUpdatedSource` は `readings.length` の範囲でしか `reading_i` を出力しないため、既存ドキュメント側にのみ存在する `reading_i`（`i` ≥ 新 item の語数）は復元されず消滅する。
- **根拠**: `index/writer/SuggestIndexWriter.java:56-66`（`:59` / `:64` がともに `setOpType(IndexRequest.OpType.INDEX)`）、`entity/SuggestItemSerializer.java:142-185`
- **設計への影響**: ISS-05 の実害の具体形。0002 §5-3 でマージ規則を単一化して潰し、§5-4 に既知の制約として明記する（P12・V11）。なお発生条件については §5 の注記を参照。

### F-05 決定的 ID は `text` の Base64 で、445 文字で切り詰められる（ハッシュではない） [確認]

- **内容**: ID は `text` の UTF-8 バイト列を **標準アルファベット** Base64 でエンコードした文字列。長さが `ID_MAX_LENGTH = 445` を超えると先頭 445 文字に切り詰める。
- **根拠**: `util/SuggestUtil.java:66`（`Base64.getEncoder()`）、`:68`（`ID_MAX_LENGTH = 445`）、`:84-90`（`createSuggestTextId`）
- **設計への影響**: OpenSearch の 512 バイト ID 制限には抵触しないが、①元テキストが約 334 バイト以上で切り詰めが発生 ②`445 % 4 = 1` のため 4 文字境界外で切断 ③先頭が一致する長文同士が**同一 ID に衝突**する。P11 により今回の設計対象（0002 §5-4 でハッシュ方式へ置換）。

### F-06 ID の生成要素は `text` のみ [確認]

- **内容**: ID は `String.join(" ", text)` した結果のみから生成され、kind / tags / roles / languages / fields を含まない。結果として同一語の DOCUMENT / QUERY / USER が 1 ドキュメントに合流する。さらに `userBoost` は**新 item で無条件上書き**されるため、elevate word の boost が通常取り込み（`userBoost=1`）で潰れる。
- **根拠**: `entity/SuggestItem.java:116`（`String.join(SuggestConstants.TEXT_SEPARATOR, text)`）、`:140`（`id = SuggestUtil.createSuggestTextId(this.text)`）、`constants/SuggestConstants.java:37`（`TEXT_SEPARATOR = " "`）、`entity/SuggestItemSerializer.java:181`（`map.put(FieldNames.USER_BOOST, item.getUserBoost())`）、`entity/SuggestItemMerger.java:86-88`（コメント `// Take newer values from item2` の直下で `setUserBoost(item2.getUserBoost())`）、`entity/SuggestItem.java:131-135`（通常取り込みは `userBoost > 1` でなければ `1`）、`entity/ElevateWord.java:143-149`（`toSuggestItem` が `getBoost()` を渡す）
- **設計への影響**: P13 [確定] により **ID の構成要素は増やさない**（kind を含めない）。①② はハッシュ化（0002 §5-4）、③ は `userBoost` のマージ規則（0002 §5-3）で解く。

### F-07 `apply=true` の実挙動は既に実質 no-op [確認]

- **内容**: fess 本体の管理画面・API はすべて `apply=false` で呼び出す。`apply=true` を渡すのは `SuggestCreator` の全件再投入経路のみで、その直前に `createNextIndex()` で**新規の空インデックス**を作っているため、wildcard の deleteByQuery は削除対象を持たない。
- **根拠**（すべて `(fess)`）:

| 呼び出し元 | 行 | `apply` |
| --- | --- | --- |
| `app/web/admin/badword/AdminBadwordAction.java` | `:322` `addBadWord(..., false)` / `:377` `deleteBadWord(...)`（`apply` 引数なし） | false |
| `app/web/api/admin/badword/ApiAdminBadwordAction.java` | `:133` `addBadWord(..., false)` / `:182` `deleteBadWord(...)` | false |
| `app/web/admin/elevateword/AdminElevatewordAction.java` | `:351-352` `addElevateWord(..., false)` / `:410` `deleteElevateWord(..., false)` | false |
| `app/web/api/admin/elevateword/ApiAdminElevatewordAction.java` | `:154-155` `addElevateWord(..., false)` / `:207` `deleteElevateWord(..., false)` | false |
| `exec/SuggestCreator.java` | `:255` `storeAllBadWords(true)` / `:258` `storeAllElevateWords(true)`（直前の `:252` が `suggester().createNextIndex()`） | **true** |

  `apply=true` の実体は `(fess) helper/SuggestHelper.java:501-512` の `storeAllBadWords` が `:509` で `suggester().indexer().addBadWord(word, apply)` をループする経路であり、その先が `index/operations/WordManagementOperations.java:81` の wildcard deleteByQuery である。対象が空インデックスであるため削除は発生しない。
- **設計への影響**: **P6（新 API `SuggestWordAdmin` から `apply` を削除し、旧ファサードは `@Deprecated` で no-op 維持）を強く裏づける [事実]**。0001 §3-1（差分表 A5）と §3-8 に根拠として記載する。

### F-08 `deleteBadWord` が `badWords` キャッシュを再取得していない [確認]

- **内容**: `addBadWord` は処理後に `badWords = settings.badword().get(true)` でキャッシュを更新するが、`deleteBadWord` は更新しない。bad word を削除しても indexer は古い配列でフィルタし続ける。
- **根拠**: `index/SuggestIndexer.java:395-400`（`:398` で再取得）に対し `:406-409`（再取得なし）
- **設計への影響**: `BadWordPolicy`（0001 §3-3）の設計にキャッシュ更新規則を含めて解消する（U2 [確定]）。

### F-09 apply 時の wildcard がエスケープされていない [確認]

- **内容**: bad word 文字列をそのまま `"*" + normalized + "*"` として `wildcardQuery` に渡している。bad word に `*` / `?` が含まれると意図しない範囲が一致する。エスケープ用のユーティリティは存在するが**どこからも呼ばれていない**。
- **根拠**: `index/operations/WordManagementOperations.java:81`、`util/SuggestUtil.java:398-400`（`escapeWildcardQuery`。grep により利用箇所ゼロを確認）
- **設計への影響**: ISS-04 の「メタ文字誤爆」の具体形。`BadWordPolicy` の単一判定規則にエスケープを含める（0001 §3-3）。

### F-10 Get-then-update に楽観ロックが無い [確認]

- **内容**: `SuggestIndexWriter#write` は `prepareGet` → マージ → `IndexRequest` という read-modify-write だが、`setIfSeqNo` / `setIfPrimaryTerm` を一切使っていない。`SuggestIndexer` は `parallel` フラグを持ち、並行実行時にロストアップデートが起きうる。
- **根拠**: `index/writer/SuggestIndexWriter.java:44-80`（全体に `setIfSeqNo` / `setIfPrimaryTerm` なし）、`index/SuggestIndexer.java:185`（`parallel = settings.getAsBoolean(...PARALLEL_PROCESSING, false)`）
- **設計への影響**: **multiGet 化（MIG-15 第 1 段）では解決しない**（往復が減るだけで read-modify-write のまま）。P12 [確定] により 0002 §5-4 に既知の制約として明記するに留め、解消は MIG-15 第 2 段（`scripted_upsert` + `retry_on_conflict`）と一括で後続スコープ（プラン §6.3）。

### F-11 `deleteByQuery` は OpenSearch の `_delete_by_query` API ではない [確認]

- **内容**: `prepareSearch` + `setSize(500)` + scroll ループ + `prepareBulk` の `DeleteRequest` という**手動ループ実装**。末尾で `prepareRefresh` を同期発行する。
- **根拠**: `util/SuggestUtil.java:332-374`（`:337` が `setSize(500)`、`:349-350` が `DeleteRequest` の bulk 追加、`:368` が `prepareRefresh`）
- **設計への影響**: `SuggestStore` 抽象（0001 §3-3）の設計時に、この実装を `_delete_by_query` へ置き換え可能かどうかを明示する。運用面（refresh の同期発行）はステップ 6 の refresh 戦略と接する。

### F-12 elevate word は専用フィールドを持たず `kinds` の `"user"` で区別している [確認]

- **内容**: `Kind` enum は `document` / `query` / `user` の 3 値。elevate word は `Kind.USER` で登録される。mapping 上 `kinds` は単なる `keyword` で、値域の制約は無い。
- **根拠**: `entity/SuggestItem.java:47-53`、`entity/ElevateWord.java:143-149`、`(res) suggest_indices/suggest/mappings-default.json:24-26`
- **設計への影響**: 0002 §5-1 の To-Be mapping で `kinds` の値域（`document` / `query` / `user`）を明文化する。P13 の「ID に kind を含めない」判断の前提でもある。

---

## 4. 処遇の振り分け表

**本書の中核。F-01〜F-12 の全 12 件が 1 行ずつ現れる。**

| # | 概要 | 分類 | 対応する ISS | 着地先（設計書と節） | 根拠となる決定 |
| --- | --- | --- | --- | --- | --- |
| **F-01** | `reading_i` に上限が無い | 設計に織り込む | 該当なし | **ステップ 4**（`dynamic` 方針の決定）→ `0002` §5-1、および `0000` 訂正一覧 | P4 / U3 |
| **F-02** | `getMaxReadingNum` は語あたりの読み候補数 | 設計に織り込む | 該当なし | `0000` 訂正一覧（F-01 の根拠として）、**ステップ 4** | P4 / P9 |
| **F-03** | 語数制限は queryLog 経路のみ | 設計に織り込む | 該当なし | **ステップ 4**（語数上限・`total_fields.limit`）→ `0002` §5-1 / §5-2 | U3 / P4 |
| **F-04** | `OpType.INDEX` の全置換で `reading_i` が消滅 | 設計に織り込む | **ISS-05** | `0002` §5-3（マージ規則で解消）＋ `0002` §5-4（既知の制約として明記） | P12 / V11 |
| **F-05** | ID は `text` の Base64・445 文字で切り詰め | 処遇が確定済み | 該当なし | `0002` §5-4（ハッシュ方式へ置換）＋ `0003` §6-1（移行手順） | P11 / P13 / U1 |
| **F-06** | ID の構成要素は `text` のみ／`userBoost` 潰れ | 処遇が確定済み | 該当なし | `0002` §5-4（構成要素は `text` のまま維持）＋ `0002` §5-3（`userBoost` 合成規則で ③ を解消） | P11 / P13 / U1 / U5 |
| **F-07** | `apply=true` は実質 no-op | 設計に織り込む | **ISS-04** | `0001` §3-1（差分表 A5）＋ `0001` §3-8（`apply` の最終形の根拠） | P6 |
| **F-08** | `deleteBadWord` のキャッシュ未更新 | 処遇が確定済み | 該当なし | `0001` §3-3（`BadWordPolicy` にキャッシュ更新規則を含める） | U2 |
| **F-09** | wildcard 未エスケープ | 設計に織り込む | **ISS-04** | `0001` §3-3（`BadWordPolicy` の単一判定規則にエスケープを含める） | U2 / ISS-04 |
| **F-10** | 楽観ロック欠如（ロストアップデート） | 処遇が確定済み | **ISS-10** | `0002` §5-4 に**既知の制約として明記するのみ**。解消はプラン §6.3（後続タスク／MIG-15 第 2 段） | P12 / U2 |
| **F-11** | `deleteByQuery` が scroll+bulk の手動ループ | 設計に織り込む | 該当なし | `0001` §3-3（`SuggestStore` の置き換え余地を記述）＋ **ステップ 6**（refresh 戦略との接続） | P3 |
| **F-12** | elevate word は `kinds="user"` で区別 | 設計に織り込む | 該当なし | `0002` §5-1（`kinds` の値域を明文化） | P13 / MIG-01 |

**未割り当て: 0 件**（12 行すべてに「分類」と「着地先」が入っている）。分類の内訳は **設計に織り込む 8 件**（F-01, F-02, F-03, F-04, F-07, F-09, F-11, F-12）／**処遇が確定済み 4 件**（F-05, F-06, F-08, F-10）／**後続タスク（スコープ外）0 件**。ただし F-10 は「記録は今回・解消は後続」という二段構えであり、解消そのものはスコープ外である。

---

## 5. 既存 ISS への対応付け

`docs/improvement-proposal.md` の課題インベントリ（§2.2）を実際に読み、以下を確認した。

| F | 対応 ISS | 妥当性の検証 |
| --- | --- | --- |
| F-04 | **ISS-05** | 妥当。ISS-05 の本文が `OpType.INDEX`＝全置換と `reading_i` の脱落を既に [事実] として記載している（`improvement-proposal.md:133`）。F-04 はその根拠行を最新のコードで再確認したもの |
| F-07 | **ISS-04** | 妥当。ISS-04 は「fess 本体の呼び出し実態では物理削除は発火しない」までを記載している（`:132`）。F-07 は**さらに踏み込み、唯一の `apply=true` 経路も空インデックス相手のため no-op である**ことを示す。ISS-04 の記述を否定せず補強する |
| F-09 | **ISS-04** | 妥当。ISS-04 の残る実害 (b)「`contains`/`wildcard` 二重化に伴う保守負担とメタ文字（`*`/`?`）誤爆」の具体形（`:132`）。ただし ISS-04 は `escapeWildcardQuery` が**存在するのに未使用**である点までは書いていない |
| F-10 | **ISS-10** | 妥当。ISS-10 は「書き込みが Get-then-update（N回同期 Get）依存」（`:138`）で、便益側に「並行登録時の read-modify-write 競合＝頻度取りこぼしを防止」と記載がある（`:213`）。ただし ISS-10 本文の重点は往復性能であり、**`setIfSeqNo`/`setIfPrimaryTerm` 未使用という具体は書かれていない**。F-10 はその補強 |

### 5.1 既存 ISS に該当しないもの（8 件）

**F-01 / F-02 / F-03 / F-05 / F-06 / F-08 / F-11 / F-12** は、提案書の ISS インベントリに対応する項目が存在しない。

- F-01 / F-02 / F-03（`reading_*` の上限とフィールド爆発）: 提案書は `reading_*` の増殖をどの ISS でも扱っていない。
- F-05 / F-06（決定的 ID の切り詰め・衝突・構成要素）: ID は KEEP-03 として**維持すべき長所**として扱われており、課題として起票されていない。F-06 ③（`userBoost` 潰れ）は ISS-15（`userBoost<=1` 強制丸め）と隣接するが、ISS-15 は丸めの話であって上書きの話ではない。
- F-08（キャッシュ未更新）/ F-11（手動 scroll ループ）/ F-12（`kinds` の値域が未明文化）: いずれも新規発見。

**P9 により、これらを提案書へ新規 ISS として起票することはしない。** 代わりに、①本書 §4 の振り分け表で着地先を保証し、②`docs/0000-design-overview.md` の「既存資料に対する訂正一覧」で既存記述の誤りを明示する（§7）。

### 5.2 対応付けにあたっての注記（ステップ 5-3 への申し送り）

ISS-05 は `reading_i` 脱落の**発生条件**を「`text` 配列の要素自身が空白を含む／空要素があるためトークン数と `readings` 長がずれるエッジケースに限られ、通常経路では顕在化しない」と限定している（`improvement-proposal.md:133`）。一方、作業プラン §5-4 作業内容 7 は例として「2 語クエリで登録された doc に 1 語クエリが来ると `reading_1` が失われる」と記している。

ID は `text`（`" "` 区切りで join した文字列。`SuggestConstants.java:37`）のみから生成されるため（F-06）、語数の異なる入力は**別 ID の別ドキュメント**になる。したがってプランの例（「2 語クエリで登録された doc に 1 語クエリが来る」）はそのままでは成立しない。**プランのこの例は 0002 §5-3 執筆時にそのまま転記してはならない。**

ただし、**同一 `text`（＝同一 ID）でありながら `readings.length` が食い違う経路は実在する** [確認]。`ElevateWord.toSuggestItem`（`entity/ElevateWord.java:144-148`）は `readingArray` を **`readings` の要素数ぶん**生成する（`this.getReadings().stream().map(reading -> new String[] { reading })`）のに対し、`text` は `new String[] { this.getElevateWord() }` の **1 語**である。よって次が起きる。

1. elevate word `東京`（readings = `["トウキョウ", "トーキョー"]`）を登録 → `readings.length = 2` → `reading_0` / `reading_1` が書かれる（`entity/SuggestItemSerializer.java:59-63`）。
2. 同じ語 `東京` が通常の検索ログ取り込みで来る → `text` が 1 語なので `readings.length = 1`。ID は同一（F-06）なので `update` 経路に入り、`toUpdatedSource`（`:146-158`）は `i = 0` しか回さない。
3. `OpType.INDEX` の全置換（`index/writer/SuggestIndexWriter.java:59`）により、**既存の `reading_1` が黙って消滅する**。

これは ISS-05 が挙げるエッジケース（`text` 要素自身が空白を含む）とは別経路であり、**elevate word を使う環境では通常経路で顕在化しうる**。プラン §5-3 も「`ElevateWord.toSuggestItem` が `readings.length ≠ text 語数` になりうる件の扱い」を独立項目として挙げており、本件はその具体形である。**発生条件の最終的な確定と解消（走査基準の単一化）は 0002 §5-3 で行う。**

---

## 6. プラン記載の訂正

プラン §2 および §3 の記述を実コードで再確認した結果、以下の差異があった。**いずれも結論（各 F の内容と処遇）を変えない。**

| # | 対象 | プランの記述 | 実際 | 結論への影響 |
| --- | --- | --- | --- | --- |
| **T-1** | F-03 | `DefaultContentsParser.java:132` が `parseQuery` の「唯一の利用」 | `index/contents/DefaultContentsParser.java` の `:121` `:123`（tag 抽出）、`:132`（text 語の抽出）、`:222` `:223`（role 抽出）の**計 5 箇所**で使用。正しくは「**text の語を作る用途での利用が `:132` のみ**」 | なし（語数制限が queryLog 経路にしか無いという結論は不変） |
| **T-2** | F-03 | `(fess) SuggestHelper.java:222-256`（チェックなし） | `indexFromSearchWord` の呼び出しは `(fess) helper/SuggestHelper.java:252`（引数を含めても `:251-253`） | なし |
| **T-3** | F-03 | `ContentIndexingOperations.java:402-412` | 正しくは `index/operations/ContentIndexingOperations.java:401-412`（`:401` が `final long start = ...`、`:412` が `split(" ")`） | なし |
| **T-4** | F-07 | `AdminBadwordAction.java:322,349,403` / `ApiAdminBadwordAction.java:133,155,211` | `:349` `:403` `:155` `:211` は `storeAllBadWords(false)` であって `addBadWord` ではない。実際の `apply` 引数を伴う呼び出し箇所は §3 F-07 の表のとおり（elevate word 側 4 箇所を含む）。`apply=true` は `(fess) exec/SuggestCreator.java:255,258` のみ | なし（「管理画面/API は常に `apply=false`」という結論は不変。むしろ elevate word 側も同様であることが加わり **P6 の根拠が強化**される） |
| **T-5** | 補足（F 番号は追加しない） | `index.mapping.total_fields.limit` は「settings に当該設定は無い」。`dynamic_templates` の `match:"*"` は `analyzer/mapping-default.json` にある | `(res) suggest_indices/` の 4 ファイル（`suggest.json` / `suggest_settings.json` / `suggest_settings_array.json` / `suggest_analyzer.json`）のいずれにも `total_fields` の記述は**無い**（各ファイル `:4` が `number_of_shards: 1`、`:5` が `number_of_replicas: 0`）。したがって**既定 1000 が効く**。加えて `(res) suggest_indices/suggest/mappings-default.json:2-12` にも `match: "*"` / `match_mapping_type: "string"` → `keyword` の `dynamic_templates` が**存在する**（suggest インデックス側の mapping にもある）。トップレベル `dynamic` の明示指定は無い（＝既定 `true`） | **ステップ 4 の判断材料として重要**。`dynamic:"strict"` 化は `mappings-default.json` 側のテンプレートの扱いとセットで決める必要がある |

---

## 7. `0000-design-overview.md` の訂正一覧へ引き継ぐ項目

ステップ 2 で作成する「既存資料に対する訂正一覧」（P9）に、少なくとも以下を載せる。

| 対象文書 | 誤っている記述 | 訂正内容 | 根拠 |
| --- | --- | --- | --- |
| `20260622_improvement_proposal/0005-schema-draft.md` | `MAX_READING_NUM=10` により `reading_*` は 10 本に確定するという前提（案 A） | `reading_i` の `i` は text の語インデックスで**上限が無い**。`getMaxReadingNum` は 1 語あたりの読み候補数の上限であってフィールド数の上限ではない | F-01 / F-02（本書 §3） |
| 同上（`dynamic` 方針の前提） | `dynamic:"strict"` + `reading_0..9` 明示列挙で足りるという前提 | 11 語以上の item が `strict_dynamic_mapping_exception` で失敗する。方針はステップ 4 で確定し `0002` §5-1 に本文として書く | F-01 |
| 作業プラン `0003` §2 F-03 の脚注 | `index.mapping.total_fields.limit` の所在についての記述 | `suggest_indices/` の 4 settings ファイルに当該設定は存在せず**既定 1000 が効く**。また `dynamic_templates` の `match:"*"` は `analyzer/mapping-default.json` だけでなく `suggest/mappings-default.json:2-12` にも存在する | T-5（本書 §6） |
| 作業プラン `0003` §2 / §5-4 の行番号・呼び出し箇所 | T-1〜T-4 に挙げた各記述 | 本書 §6 の「実際」欄のとおり | 本書 §6 |

---

## 8. 後続ステップへの申し送り

- **ステップ 4（`reading_*` 方針）**: F-01（上限なし）・F-02（`MAX_READING_NUM` の意味）・F-03（語数無制限の経路）・**T-5**（`total_fields.limit` 未設定＝既定 1000、`mappings-default.json:2-12` にも `match:"*"` テンプレートあり、トップレベル `dynamic` は既定 `true`）を判断材料とする。`dynamic` 方針・語数上限（U3 [確定]）・`total_fields.limit` の明示要否の 3 点を決める。
- **ステップ 5-3（マージ規則）**: F-04（全置換による `reading_i` 消滅。**プランの例は成立せず、実際の発生経路は elevate word の `readings.length ≠ text 語数` である** — 本書 §5.2）、F-06 ③（`userBoost` の無条件上書き。`SuggestItemSerializer.java:181` と `SuggestItemMerger.java:88`）を消化する。
- **ステップ 5-4（ID 再設計・既知の制約）**: F-05（切り詰めと衝突 → ハッシュ化）、F-06 ①②（構成要素は `text` のまま）、F-04 / F-10 の既知の制約明記。
- **ステップ 3-3（spi）**: F-08（キャッシュ更新の非対称）と F-09（wildcard 未エスケープ）を `BadWordPolicy` の単一規則に統合。F-11 を `SuggestStore` の置き換え余地として記述。
- **ステップ 3-1 / 3-8（API）**: F-07 を P6（`apply` 削除・旧ファサード no-op）の根拠として引く。T-4 で確定した呼び出し箇所一覧をそのまま使える。
- **ステップ 6（移行運用）**: F-11（`prepareRefresh` の同期発行を含む手動 scroll ループ）を refresh 戦略（MIG-16）と突き合わせる。F-05 の ID 方式変更に伴い、**旧世代インデックスとの共存が成立しない**ことを切替・ロールバック手順に反映する。

---

## 9. 検証方針（プラン §5）との対応

| # | 検証項目 | 本書の寄与 |
| --- | --- | --- |
| **V8** | 既存資料の訂正明示（F-01/F-02 を含む訂正一覧が `0000` にある） | §7 に `0000` へ載せるべき訂正項目を表形式で用意し、F-01 / F-02 / T-5 を含めた。ステップ 2 はこれを転記すれば V8 を満たす |
| **V10** | ID 再設計（P11 / P13） | §3 F-05 / F-06 で ①②③ の 3 問題を根拠付きで分離し、①② を `0002` §5-4（ハッシュ化）、③ を `0002` §5-3（`userBoost` 合成規則）に §4 の表で割り当てた。§5.1 で「ID は既存 ISS に無い＝提案書に根拠が無い」ことを明示し、`0002` 本文に根拠を書く必要性を確定させた |
| **V11** | 既知の制約の明記（P12） | §3 F-04 / F-10 を [確認] 済みの根拠付きで記録し、§4 でともに `0002` §5-4 へ着地させた。F-10 には「multiGet では解決しない」「MIG-15 第 2 段で一括」を影響欄に明記済み |

---

## 10. 参照した一次情報

- プロダクションコード: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` および `modules/fess/src/main/java/org/codelibs/fess/` 配下（各 file:line は §3・§6 に記載）
- インデックス定義: `modules/fess-suggest/src/main/resources/suggest_indices/`（4 settings ファイル＋ `suggest/mappings-default.json` ＋ `analyzer/mapping-default.json`）
- `agent_docs/tasks/20260706_design_document/docs/improvement-proposal.md`（第 4 版。ISS インベントリ §2.2。**本タスクでは編集しない** — P9）
- `agent_docs/tasks/20260706_design_document/0001-unresolved-items-resolution.md`（[確定] 事項）
- `agent_docs/tasks/20260706_design_document/0003-design-document-work-plan.md`（P1〜P13 / U1〜U5 / V1〜V11）
