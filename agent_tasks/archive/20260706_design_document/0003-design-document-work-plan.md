# 作業プラン: 20260706_design_document（設計書執筆）

> 本書は、要件定義（`0000-requirements-definition.md`）が求める設計書 4 本を執筆するための作業プランである。
> 前提となる決定はすべて `0001-unresolved-items-resolution.md`（未決項目の解消）と
> `0002-improvement-proposal-review-reflection.md`（提案書第4版）で確定済みであり、本プランはそれを消費する。
>
> 凡例は改善提案書と同一（**[事実]** = コード確認済み / **[提案]** = 設計提案 / **[確定]** = 決定済み / **[要確認]** = 未解消）。

---

## 0. 概要

`docs/` 配下に設計書 4 本（`0000-design-overview.md` / `0001-api-design.md` / `0002-datamodel-design.md` / `0003-migration-ops-design.md`）を執筆し、
Phase 1a + 1b をシグネチャレベルで完全設計する。あわせて、インデックス設計と不可分な MIG-13 / MIG-16 / MIG-17 を含める。

**現状**: `docs/` にあるのは入力資料 2 本（`improvement-proposal.md` / `opensearch-verification-reference.md`）のみで、**設計書は 1 本も存在しない**。残作業は設計書 4 本の執筆そのものである。

---

## 1. 前提・スコープ

### 1.1 本プランの前提（本プラン作成時に承認済み）

| # | 決定 | 内容 |
| --- | --- | --- |
| P1 | 文書構成 | 要件定義の 4 文書構成をそのまま採用する |
| P2 | 0016 の扱い | `20260622_improvement_proposal/0016-improved-api-interface.md` をベースに発展させる。矛盾 8 点の差分表を作り、それぞれの決着を明記する独立ステップを置く |
| P3 | spi の深度 | spi 5 IF は補助型（`ScoringContext` / `ScoringPlan` / `QueryCondition` / `ProcessedText` / `SourceContext` / `TextProcessingContext`）まで含めた完全シグネチャを書く |
| P4 | reading_* | `reading_*` の生成規則と上限をコード追検証する先行独立ステップを置き、`dynamic` 方針を確定してから 0002 を執筆する |
| P5 | knn_vector | 初期 To-Be mapping には含めない。0003 に「`knn_vector` を後から追加する手順」を 1 節置く |
| P6 | `apply` 引数 | 新 API `SuggestWordAdmin` のシグネチャから**削除**し、旧ファサードは `@Deprecated` で **no-op 維持** |
| P7 | 執筆順序 | 0000 の骨組みを先行作成 → 0001 → 0002 → 0003 を各完成ごとにレビュー → 最後に通し整合レビュー |
| P8 | MIG-25 | 0000 に「設計不要・実装時の作業内容のみ記載」として置く |
| P9 | 既存資料 | 過去タスクの文書は**凍結**。0000 に「既存資料に対する訂正一覧」を 1 節設ける |
| P10 | スコープ | **設計書の作成のみ**。コード実装は後続タスク |
| P11 | 決定的 ID | **ID 設計の見直しを今回のスコープに含める**。F-05/F-06 の 3 問題をすべて解消し、Phase 1a の MIG-02（score 廃止）による全インデックス再構築に**相乗り**させる。設計は 0002、移行手順は 0003 |
| P13 | ID の構成要素 | **ID は `text` のハッシュとし、構成要素を増やさない**（kind を含めない）。①② はハッシュ化で解消し、③（elevate word の `userBoost` 潰れ）は **ID ではなくマージ規則で解く**。**根拠: ID に kind を含めると同一語の DOCUMENT / QUERY / USER が別ドキュメントに分裂し、KEEP-03（決定的 ID による重複排除・頻度集約）の前提が壊れるため。③ の実体は `SuggestItemSerializer.java:181` の `userBoost` 無条件上書きであり、ID ではなく合成規則の問題である** |
| P12 | 楽観ロック | F-10（`setIfSeqNo`/`setIfPrimaryTerm` 未使用によるロストアップデート）は 0002 に**既知の制約として明記するに留め**、解消は後続スコープ。MIG-15 第2段（`scripted_upsert` + `retry_on_conflict`）と同じ問題領域であり、そこで一括して扱う旨を併記する |

### 1.2 スコープ

**対象**:
- Phase 1a: MIG-01, 02, 03, 04, 05, 07, 11, 12, 25
- Phase 1b: MIG-06, 08, 09, 10
- 例外的に含める: MIG-13（`excluded`）, MIG-16（refresh 分離）, MIG-17（shards/replicas）
- 拡張点の形状のみ保証: MIG-14, MIG-15第2段, MIG-18〜24

**スコープ外**:
- コード実装、テストコードの記述（設計書には**テスト仕様**を書くが、実装はしない）
- `scripted_upsert` の Painless スクリプト仕様・冪等性・失敗時挙動（`SuggestStore` の拡張点として形だけ用意）
- 性能実測（負荷試験・A/B）に依存する最適値の決定（提案書 §5.3、後続タスク）
- 過去タスクの文書の修正（P9 により凍結）

---

## 2. 本プラン作成時の追加調査で判明した事実

以下はプラン作成のためのコード追検証で判明した **[事実]** であり、既存資料には記載がない、または既存資料の記述を否定する。設計書の内容に直結するため、ステップ 1 で正式に棚卸しする。

| # | 発見 | 根拠 | 設計への影響 |
| --- | --- | --- | --- |
| **F-01** | **`reading_i` の `i` は「text の語インデックス」であり、上限は事実上存在しない** | `SuggestItemSerializer.java:147-158`（`readings.length` で走査）、`SuggestQueryBuilder.java:84-86`（クエリの語数分だけ `reading_i` を引く）、`SuggestItem.java:81`（`String[][]`） | **`0005-schema-draft.md` 案 A の前提（`MAX_READING_NUM=10` で 10 本に確定）は誤り**。`dynamic:"strict"` + `reading_0..9` 明示では 11 語以上の item が `strict_dynamic_mapping_exception` で失敗する |
| **F-02** | `ReadingConverter#getMaxReadingNum`（既定 10）は**1 語あたりの読み候補数**の上限であって、フィールド数の上限ではない | `ReadingConverter.java:31-33`、利用箇所は `ReadingConverterChain.java:60,68,83,95-96` と `KatakanaToAlphabetConverter.java:103` のみ | F-01 の根拠。訂正一覧に記載 |
| **F-03** | 語数制限は queryLog 経路（`MAX_QUERY_TERM_NUM=5`）にしか無く、**fess が実際に使う `indexFromSearchWord` 経路には制限がない** | `SuggestUtil.java:63,101-108`、`DefaultContentsParser.java:132`（唯一の利用）、`ContentIndexingOperations.java:402-412`（制限なし）、`SuggestHelper.java:222-256`（チェックなし） | `reading_*` のフィールド爆発は理論上 `index.mapping.total_fields.limit`（既定 1000）まで到達しうる。settings に当該設定は無い |
| **F-04** | **書き込みは `OpType.INDEX` の全置換**であり、`toUpdatedSource` が出力しないキーは消える | `SuggestIndexWriter.java:59,64`、`SuggestItemSerializer.java:142-185` | 既存ドキュメントの `reading_i`（`i` ≥ 新 item の語数）が**黙って消滅する**。ISS-05 の実害の具体形 |
| **F-05** | **決定的 ID は `text` の Base64 で、445 文字で切り詰められる**（ハッシュではない） | `SuggestUtil.java:66,68,84-90` | 512 バイト制限には抵触しないが、①元テキスト約 334 バイト以上で切り詰め ②`445 % 4 = 1` のため 4 文字境界外で切断 ③先頭が同じ長文同士が**同一 ID に衝突**。**P11 により今回の設計対象**（0002 §5-4） |
| **F-06** | ID の生成要素は **`text` のみ**。kind / tags / roles / languages / fields を含まない | `SuggestItem.java:116,140` | 同一語の DOCUMENT / QUERY / USER が 1 ドキュメントに合流する。**elevate word の `userBoost` が通常取り込み（`userBoost=1`）で上書きされる**（`SuggestItemSerializer.java:181` が無条件上書き、`SuggestItemMerger.java:88` も item2 採用）。**P11 により今回の設計対象**。ただし解消は **ID ではなくマージ規則で行う**（P13 / §6.1 U5） |
| **F-07** | **`apply=true` の実挙動は既に実質 no-op** | 管理画面/API は常に `apply=false`（`AdminBadwordAction.java:322,349,403`、`ApiAdminBadwordAction.java:133,155,211`）。`true` は `SuggestCreator.java:255,258` のみで、`createNextIndex()`（`:252`）直後の**空インデックス**に対して wildcard deleteByQuery を投げている | **P6（`apply` を新 API から削除・旧ファサードで no-op 維持）を強く裏づける [事実]**。設計書に根拠として記載する |
| **F-08** | `SuggestIndexer.deleteBadWord` が `badWords` キャッシュを再取得していない | `SuggestIndexer.java:406-409`（`addBadWord` は `:398` で再取得しているのに対し非対称） | bad word を削除しても indexer は古い配列でフィルタし続ける。`BadWordPolicy` 設計で解消すべき |
| **F-09** | apply 時の wildcard が**エスケープされていない** | `WordManagementOperations.java:81`。`SuggestUtil.escapeWildcardQuery`（`:398-400`）は存在するが未使用 | ISS-04 の具体形。`BadWordPolicy` の単一規則で解消 |
| **F-10** | Get-then-update に**楽観ロックが無い**（`setIfSeqNo`/`setIfPrimaryTerm` 未使用）。`SuggestIndexer` は `parallel` フラグを持つ | `SuggestIndexWriter.java:44-80`、`SuggestIndexer.java:185` | multiGet 化（MIG-15 第1段）でも解決しない。並行時のロストアップデート可能性を設計書で扱うか判断が要る |
| **F-11** | `deleteByQuery` は OpenSearch の `_delete_by_query` API ではなく、**scroll + bulk delete の手動ループ** | `SuggestUtil.java:332-374`（scroll size 500、末尾 `:368` で prepareRefresh） | `SuggestStore` 抽象の設計時に、この実装の置き換え可否を明示する |
| **F-12** | elevate word は専用フィールドを持たず **`kinds` の `"user"`** で区別している | `SuggestItem.java:53`、`ElevateWord.java:143-149`、`mappings-default.json:24-26` | mapping 設計で `kinds` の値域を明文化する |

---

## 3. ステップ

### ステップ 1: 新規発見事項の棚卸しと処遇決定

- **目的**: §2 の F-01〜F-12 を正式な記録に落とし、各々を「設計に織り込む / 記録のみ / 後続タスク」に振り分ける。設計書執筆中に発見事項が漏れる事故を防ぐ。
- **対象**: `agent_docs/tasks/20260706_design_document/0004-new-findings.md`（新規）
- **作業内容**:
  1. F-01〜F-12 を根拠（file:line）付きで記載する。
  2. 各々を以下に分類する。
     - **設計に織り込む**: F-01〜F-04, F-07, F-09, F-11, F-12（既存 ISS/MIG の範囲内、または既存決定の根拠）
     - **処遇が確定済み**: F-05・F-06（ID 設計の見直し → P11・P13、§6.1 U1/U5）、F-08・F-10（新規バグ相当 → P12、§6.1 U2）
  3. 既存 ISS への対応付け（F-04→ISS-05、F-07/F-09→ISS-04、F-10→ISS-10）と、既存 ISS に該当しないものの列挙。
- **完了条件**: F-01〜F-12 のすべてが「どの設計書のどの節で扱うか」または「対象外・理由」に割り当てられている。
- **注意点**: 新規 ISS を提案書に起票してはならない（P9 の凍結）。本書と 0000 の訂正一覧で扱う。

### ステップ 2: `docs/0000-design-overview.md` の骨組み作成

- **目的**: 設計書群の入口を先に固定する。カバレッジ表を最初に作らないと、MIG-25 のような設計要素を持たない項目が最後まで宙に浮く。
- **対象**: `docs/0000-design-overview.md`
- **作業内容**:
  1. **MIG → 設計書対応表**（MIG-01〜25 全件）。各行に「担当文書・節 / 完全設計 or 拡張点のみ / 対象外の場合は理由」。この時点では節番号は未確定でよく、ステップ 7 で実体から埋める。**MIG に属さない今回スコープ追加項目**（P11 の決定的 ID 再設計）を、MIG-02 に相乗りする独立行として表に加える。カバレッジ表が MIG 番号だけで構成されていると、この項目が表から漏れる。
  2. **[確定] 事項のスナップショット**: `0001-unresolved-items-resolution.md` §2.1〜§2.14 の**結論だけ**を転記する。根拠は同書へのリンクに留める（設計書肥大の最大要因は根拠の重複転記）。
  3. **既存資料に対する訂正一覧**（P9）: 少なくとも F-01/F-02（`0005-schema-draft.md` の `MAX_READING_NUM` 誤認）を明記する。「どの文書のどの記述が、本設計書のどの決定で上書きされたか」の表形式。
  4. **MIG-25**: 設計不要である旨と、実装時の作業内容（README のバージョン記載を pom から単一ソース化、`modules/fess-suggest/CLAUDE.md` の非同期サンプルを MIG-08 完了後に `CompletableFuture` ベースへ書き換え）を記載。
  5. **共通凡例**と、各設計書の冒頭に置く宣言フォーマット（対象 MIG / 消化する申し送り / 依存する [確定] 番号）の定義。
- **完了条件**: MIG-01〜25 の全件が対応表に現れ、「未割り当て」の行が 0 である。
- **注意点**: この時点では骨組み。節番号の解決はステップ 6。

### ステップ 3: `docs/0001-api-design.md` の執筆

前提: ステップ 2 完了。0002/0003 とは独立して進められる。

#### 3-1: 0016 との差分表の作成（独立ステップ / P2）

- **目的**: 0016 を無言で書き換えると、どちらが正か後から追えなくなる。矛盾 8 点の決着を機械検査可能な形で残す。
- **対象**: `docs/0001-api-design.md` の付録（API の話に閉じるため 0000 ではなく 0001 に置く）
- **作業内容**: 以下 8 点それぞれに「0016 の記述 / 本設計書の決定 / 根拠となる [確定] 番号」を書く。

| # | 0016 の記述 | 決着 |
| --- | --- | --- |
| A1 | `scripted_upsert` 第一候補・multiGet フォールバック | **逆転**。multiGet が確定設計、`scripted_upsert` は `SuggestStore` の拡張点のみ（§2.3） |
| A2 | `SuggestWords`/`SuggestResult` の 2 分割で detail を表現 | **フィールド選択方式**に置換。既定は現行互換（text/tags）（§2.10）。2 メソッド分割の要否自体を再判断する |
| A3 | `IndexSchema(int numberOfShards, int numberOfReplicas, ...)` | `numberOfReplicas` を削除し `autoExpandReplicas` に置換（§2.14） |
| A4 | 「fess 本体の設定基盤を型安全化」 | **誤り**。Lasta Config は `Duration` 非対応。境界で変換（§1.1・§2.8） |
| A5 | `addBadWord(String, boolean apply)` | **`apply` を削除**（P6）。F-07 を根拠として付す |
| A6 | lifecycle 系が同期・`refresh()` のみ `CompletableFuture` | 非同期の適用範囲を決め直す（§2.6） |
| A7 | `errors` 配列を戻り値に持つ | `Result` 型は導入しない。**バルク部分失敗を errors に積むか throw か**を明示的に決着させる（§2.6） |
| A8 | `IngestOptions(bulkSize, parallelism, onProgress)` | refresh 制御パラメータを追加（§2.12） |

- **完了条件**: 8 点すべてに決着が書かれ、0016 の `[要確認]` マーカー 8 項目が全件クローズ扱いになっている。

#### 3-2: 公開 4 インタフェースのシグネチャ確定

- **対象**: `SuggestQueryService` / `SuggestIndexLifecycle` / `SuggestWordAdmin` / `SuggestIngestService`
- **作業内容**: 0016 の 23 メソッドを起点に、3-1 の決着（A1/A2/A5/A6/A7/A8）を反映した最終シグネチャを Java の IF 宣言として書く。パッケージは `org.codelibs.fess.suggest.api`。ISS-03（`suggestDetail` の暗黙結合）を API 名/型から自明にする（MIG-06 に内包）。
- **完了条件**: 全メソッドに戻り値型・引数型・throws・Javadoc（1 行以上）があり、「（仮）」の記述が残っていない。

#### 3-3: spi 5 インタフェースと補助型の完全定義（P3）

- **対象**: `SuggestSource` / `ScoringStrategy` / `SuggestItemMergePolicy` / `BadWordPolicy` / `AuthorizationFilter`（＋ `TextProcessor`, `SuggestStore`）
- **作業内容**:
  - 補助型 `SourceContext` / `ScoringContext` / `ScoringPlan` / `ProcessedText` / `TextProcessingContext` / `QueryCondition` をフィールドまで定義する。
  - **拡張予約の検証可能化**（§2.11）: `ScoringContext` が**ベクトル類似度スコアを加点要素として受け取れる**こと、`ScoringPlan` が **fuzzy マッチを完全一致と区別して低重みで加点できる**ことを、シグネチャ上で示す。`TextProcessor` は言語別／誤字正規化の実装を差し替え・追加できる形にする。
  - **織り込まないもの**を明記: `SuggestSource` は「候補を返す抽象」に留め、ソース別重み付けとマージ規則を IF に組み込まない（MIG-19/20）。パーソナライズ用の検索コンテキストをリクエストモデルに予約しない（MIG-22）。
  - `BadWordPolicy`: `contains`（`SuggestItem.java:455-462`）と `wildcard`（`WordManagementOperations.java:81`）の二重実装を単一規則に統一。エスケープ（F-09）を規則内に含める。取り込み時フィルタ（新規流入の防止）と `excluded`（既存語の論理除外）は**両方残すが判定規則は 1 つ**であることを明記する。キャッシュ更新の非対称（F-08）を解消する。
  - `SuggestStore`: `scripted_upsert` を差し替え可能な実装として載せられる形。F-11（scroll+bulk delete の手動ループ）の置き換え余地も記述。
- **完了条件**: 1 行 IF が 0 件。すべての補助型に中身がある。§2.11 の 3 機能（ベクトル / fuzzy / 多言語）が「後から載る」ことをシグネチャで説明できる。

#### 3-4: 非同期・例外契約

- **作業内容**: `CompletableFuture` 統一、`Result` 型なし、`SuggesterException` throw、非同期経路の `CompletionException` ラップ（§2.6）。加えて 0016 に無かった以下を定義する。
  - どのメソッドが同期でどれが非同期か（A6 の決着）
  - バルク部分失敗の扱い（A7 の決着）
  - スレッド安全性、タイムアウト、キャンセル、`Executor` 指定の規約
  - 例外階層
- **完了条件**: 4 IF の全メソッドについて同期/非同期と例外の振る舞いが決まっている。

#### 3-5: レスポンスのフィールド選択と権限（申し送り消化）

- **作業内容**: 返却フィールドの指定方式、既定値（text / tags）、**選択可能フィールドの許可リスト**、および `roles` を露出可能にする場合の権限上の扱い（呼び出し元が管理系か検索系か）を明示する。これは提案書からの明示的な申し送り。
- **完了条件**: 許可リストが列挙され、`roles` について「どの呼び出し経路でなら返せるか」が書かれている。

#### 3-6: 設定 API

- **作業内容**: 0016 に存在しなかった `SuggestSettings` / `SuggestSettingsBuilder` を定義する。時間設定は `java.time.Duration`、単位付き文字列（`"3m"`）のパースは fess-suggest 側で行う（§2.8）。シャード・レプリカ設定の受け口を追加し、これを正とする。`auto_expand_replicas` を設定できる形にし、`number_of_replicas` は復活させない（§2.13・§2.14）。
- **完了条件**: §2.8 / §2.13 / §2.14 の受け皿がすべて存在する。

#### 3-7: 権限集約（MIG-09）

- **作業内容**: `AuthorizationFilter` にロール集合の決定・`_guest_` 補完・クエリ変換を集約する。fess 本体は「現在のユーザーのロール一覧」を渡すだけ。**デフォルト deny を維持**する（§2.9）。現行の二重合成（`SuggestWordsHandler.java:83` の `addRole` と `SuggestRequest.java:354-356` の `_guest_` 補完）の解消を対応表で示す。

#### 3-8: 旧 → 新の対応表と、旧ファサードの委譲設計

- **作業内容**:
  - 旧公開メソッド（`Suggester` public 18 / `SuggestIndexer` public 28）→ 新 IF の対応表。**廃止するものには廃止理由**を付す。
  - Strangler Fig の第 2 段「旧公開シグネチャを維持したまま内部を新部品へ委譲する」具体設計（§2.1）。`Deferred`/`Promise` ↔ `CompletableFuture` のアダプタを含む。
  - `apply` の最終形（P6）: 新 API から削除、旧ファサードは `@Deprecated` で no-op。**MIG-03 段階と MIG-13 段階それぞれの `apply=true` の挙動**を定義する。F-07 を根拠に「実挙動は不変」を示す。
- **完了条件**: 旧公開メソッドの全件が「新 IF の何に対応するか」または「廃止・理由」に割り当てられている。

#### 3-9: fess 本体側の API 適合設計

- **作業内容**: `SuggestHelper.indexFromDocuments(Consumer<Boolean>, Consumer<Throwable>)` のシグネチャ維持と内部書き換え、`SuggestWordsHandler.java:104` / `PopularWordHelper.java:120` の `getResponse()` → `join()` 相当への置換、`SuggestCreator.java:263-276` の `CountDownLatch` 維持（§2.7）。`suggest.popular.word.cache.expire` を `60` → `60m` に改める件（§2.8、ISS-02）。
- **注**: fess 側の**リリース手順・同期タイミング**は 0003 に書く。ここでは「変更後の形」だけを書く。
- **完了条件**: fess 側の変更ファイルが列挙され、各々の変更後の姿が示されている。

#### 3-10: 0001 のレビュー（P7）

- **観点**: 3-1 の 8 点が反映されているか / 1 行 IF が残っていないか / [要確認] が 0 件か / 申し送り（`apply`・`roles` 許可リスト）が着地しているか。

### ステップ 4: `reading_*` の方針確定（先行・独立 / P4）

前提: ステップ 1 完了。ステップ 3 と並行可。**ステップ 5 の着手条件**。

- **目的**: F-01 により `0005-schema-draft.md` 案 A の前提が崩れている。mapping 全体の `dynamic` 方針を左右するため、0002 を書き始める前に決着させる。
- **作業内容**:
  1. F-01〜F-04 の再確認（本プラン作成時の調査結果の検証）。
  2. `dynamic` 方針を決める。**推奨は案 B 系**: トップレベル `dynamic: "strict"` ＋ `dynamic_templates` を `match: "reading_*"` に限定して keyword を許可。`reading_0..9` の明示列挙は採らない（F-01 により上限が保証できないため）。
  3. **書き込み側の語数上限**を仕様として入れるか決める。推奨は「設定可能な上限を設け、超過語は切り捨てる」。根拠: 検索側（`SuggestQueryBuilder.java:84-86`）はクエリの語数分しか `reading_i` を引かないため、書き込み側だけが `index.mapping.total_fields.limit`（既定 1000）に向かって膨らむ非対称がある。上限を設けても検索結果への実害はない。
  4. `index.mapping.total_fields.limit` を settings に明示するか決める。
  5. `suggest` 以外のインデックス（`analyzer/mapping-default.json` の `match:"*"` テンプレート、設定系インデックスの完全 dynamic）に同じ方針を適用するか決める。
- **完了条件**: `dynamic` 方針・語数上限・`total_fields.limit` の 3 点が [要確認] を残さず確定している。
- **注意点**: 決定は 0002 に本文として、経緯は作業履歴と 0000 の訂正一覧に書く。提案書・`0005` は書き換えない（P9）。

### ステップ 5: `docs/0002-datamodel-design.md` の執筆

前提: ステップ 4 完了。ステップ 3 と並行可（ただし `SuggestItemMergePolicy` の挙動定義は 3-3 と整合を取る）。

#### 5-1: To-Be mapping の統合定義

- **作業内容**: **1 つの mapping 定義**に以下をすべて統合する。
  - `score` 廃止（案 A、MIG-02）— 両論併記を持ち込まず断定する
  - `excluded`（boolean）追加（MIG-13）— 書き込み側は明示的に `false` を格納し、`null_value` に依存しない
  - ステップ 4 で決めた `dynamic` 方針と `reading_*` の扱い
  - `kinds` の値域（`document` / `query` / `user`、F-12）
  - **`embedding`（`knn_vector`）は含めない**（P5）
- **完了条件**: そのまま投入できる JSON として完成し、現行 `mappings-default.json` との差分表が付いている。

#### 5-2: index settings の設計

- **作業内容**:
  - `number_of_replicas: 0` を 4 ファイル（`suggest.json` / `suggest_settings.json` / `suggest_settings_array.json` / `suggest_analyzer.json`）から削除し、`auto_expand_replicas: "0-1"` を唯一のレプリカ制御とする（§2.14）
  - `number_of_shards` の既定は 1 のまま据え置き、API 経由で可変にする（§2.13）。`suggest_indices/*.json` の値は API 無指定時の既定値に格下げする。`${...}` プレースホルダ置換は導入しない
  - `refresh_interval` の位置づけ（MIG-16 と表裏）
  - `index.mapping.total_fields.limit`（ステップ 4 の決定次第）
- **完了条件**: 4 ファイルそれぞれの To-Be が示されている。

#### 5-3: マージ規則の単一化仕様（MIG-01 / ISS-05）

- **作業内容**:
  - **走査基準の非対称を解消する**。現状は `SuggestItemMerger.java:70`（text の語数）と `SuggestItemSerializer.java:60,147`（`readings.length`）と `:87-95`（既存ドキュメント側の存在）で 3 通りある。単一の走査基準を定義する。
  - **F-04 の実害を明示的に潰す**: `OpType.INDEX` の全置換により、既存ドキュメントの `reading_i`（`i` ≥ 新 item の語数）が消滅する。全置換を維持するなら**既存 `reading_i` の復元規則**を、`UPDATE` に変えるならその旨を定義する。
  - `SuggestItemMergePolicy` の挙動をフィールド単位で定義する: `queryFreq`/`docFreq` = 加算、`kinds`/`tags`/`roles`/`languages`/`fields` = 集合和、`readings` = 和集合、`text` / `@timestamp` / `userBoost` = 現行は無条件上書き（`SuggestItemSerializer.java:181,183`）だがこれを正とするか決める。
  - **`userBoost` の合成規則をここで確定させる（P13 [確定]）**。F-06 ③（elevate word の boost が通常取り込みで潰れる）は **ID ではなく本節のマージ規則で解く**。現行は `SuggestItemSerializer.java:181` と `SuggestItemMerger.java:88` がともに**新 item で無条件上書き**しているため、`userBoost=1` の通常取り込みが elevate の boost を潰す。代替案（USER kind の値を優先する / max を採る / 既存が既定値でない限り保持する）を比較し、1 つに決める。`ElevateWord.toSuggestItem`（`ElevateWord.java:144-148`）が `userBoost=boost`、通常取り込みが `userBoost=1`（`SuggestItem.java:131-135`）である点を判断材料にする。
  - `@timestamp` の無条件上書き（`SuggestItemSerializer.java:183`）が既存値を後退させうる点もあわせて決着させる。
  - **`excluded` のマージ時の扱い**を定義する（既存資料に一切記述がない）。推奨: **既存値を保持**（新 item は `excluded` を書かず、既存に無い場合のみ `false` を初期化する）。取り込みのたびに bad word 除外が解除される事故を防ぐため。bad word 解除時は `deleteBadWord` 経路で明示的に `false` に戻す。
  - `ElevateWord.toSuggestItem`（`ElevateWord.java:144-148`）が `readings.length ≠ text 語数` になりうる件の扱い。
- **完了条件**: 全フィールドについて合成規則が 1 つに決まり、既存テスト（`SuggestItemMergerTest` 等）で現行と同一結果になるものと、意図的に変える差分が区別されている。

#### 5-4: 決定的 ID の再設計（P11）

**本ステップは P11 により今回スコープに追加された。0002 で最も分量が大きくなる節であり、5-3 と 5-5、およびステップ 6 に波及する。**

- **目的**: F-05 / F-06 の 3 問題をすべて解消する。ただし解き方を分ける（P13）: **①② は ID のハッシュ化で、③ は 5-3 のマージ規則で解く**。ID 方式の変更は Phase 1a の MIG-02 再構築に相乗りさせる。
- **解消すべき 3 問題**:

| # | 問題 | 根拠 |
| --- | --- | --- |
| ①② | `text` の Base64 を 445 文字で切り詰めるため、`445 % 4 = 1` で 4 文字境界外を切断し、先頭約 333 バイトが一致する長文が**同一 ID に衝突**する | `SuggestUtil.java:66,68,84-90` |
| ③ | ID が `text` のみから作られ kind を含まないため、同一語の DOCUMENT / QUERY / USER が 1 ドキュメントに合流し、**elevate word の `userBoost` が通常取り込み（`userBoost=1`）で上書きされる** | `SuggestItem.java:116,140`、`SuggestItemSerializer.java:181`、`SuggestItemMerger.java:88` |

- **作業内容**:
  1. **①② の解消**: 固定長ハッシュ方式（例: `text` の UTF-8 バイト列の SHA-256 を Base64 URL-safe エンコード）に置換する。長さが入力に依存しないため切り詰めが発生せず、衝突は実用上ゼロになる。現行の `ID_MAX_LENGTH=445` による切り詰めロジックを廃止する。
     - **検討事項**: 現行 ID は可逆（Base64 デコードで text が復元できる）。ハッシュ化すると ID から text を逆引きできなくなるため、運用・デバッグ上これに依存している箇所がないか確認する（`WordManagementOperations.java:129`、`SuggestItemSerializer.java:130` は text から ID を再計算しており逆引きはしていない）。
     - Base64 標準アルファベットは `+` `/` `=` を含むため URL-safe への変更も同時に判断する。
  2. **③ の解消は ID では行わない（P13 [確定]）**。**ID の構成要素は `text` のみに保つ**（kind を含めない）。③ は 5-3 の `userBoost` マージ規則で解く。
     - **この判断の根拠を 0002 本文に 1 行残す**: ID に kind を含めると同一語の DOCUMENT / QUERY / USER が別ドキュメントに分裂し、**KEEP-03（決定的 ID による重複排除・頻度集約）の前提が壊れる**（頻度集約が kind ごとに割れ、検索結果に同一 text が重複しうる。`SuggestRequest.java:363-365` の kinds フィルタと `SuggestWordsHandler.java:96` の意味も変わる）。③ の実体は `SuggestItemSerializer.java:181` の無条件上書きであり、ID ではなく合成規則の問題である。
     - 同一語の DOCUMENT / QUERY / USER が 1 ドキュメントに合流する**現行動作は変えない**。
  3. **ID 変更の影響範囲の列挙**: ID 生成箇所（`SuggestItem.java:140`、`SuggestItemSerializer.java:130`、`WordManagementOperations.java:129`）、および ID を前提とする経路（`SuggestIndexWriter.java:55` の `prepareGet`、`SuggestWriter.mergeItems`）。
  4. **realtime get 前提の明文化**（申し送り 1）: `SuggestIndexWriter.java:55` の ID 指定 GET は `setRealtime(false)` 指定がなく既定 realtime（translog 読み）であるため、**マージの正しさは refresh に非依存**である。ID 方式を変えてもこの性質は保たれる（ID 指定 GET であることは不変）ことを明記する。
  5. **回帰テスト仕様**（申し送り 2）: refresh 廃止後に「同一語が連続バッチに現れるケースで頻度が正しく集約される」ことを確認するテスト。MIG-15 第 1 段の multiGet 化後も同様（multiGet も既定 realtime）。**新 ID 方式でも同一語が同一 ID に落ちることを確認するテスト**を追加する。
  6. **F-10（楽観ロック欠如）を「既知の制約」として明記**（P12）: `SuggestIndexWriter.java:44-80` が `setIfSeqNo`/`setIfPrimaryTerm` を使っておらず、`SuggestIndexer.java:185` の `parallel` 実行時にロストアップデートが起きうること。**multiGet 化（MIG-15 第 1 段）では解決しない**（往復が減るだけで read-modify-write のままである）こと。**MIG-15 第 2 段（`scripted_upsert` + `retry_on_conflict`）と同じ問題領域であり、そこで一括して扱う**こと。解消は後続スコープ（§6.3）。
  7. **F-04 を明記**（P12 の前提）: `OpType.INDEX` の全置換（`SuggestIndexWriter.java:59,64`）により、既存ドキュメントの `reading_i`（`i` ≥ 新 item の語数）が消滅する。2 語クエリで登録された doc に 1 語クエリが来ると `reading_1` が失われる。解消は 5-3 で行う。
- **完了条件**: 新 ID 方式が確定し（切り詰めロジックが存在しない／構成要素は `text` のみ）、③ の解消が 5-3 に委ねられていることと**その根拠（KEEP-03 との衝突回避）が本文に 1 行残っている**、申し送り 1・2 が消化済みと機械的に判定でき、F-04 / F-10 が既知の制約として本文に現れている。
- **注意点**: ID 方式の変更は**旧世代インデックスとの共存が成立しない**（同じ語が新旧で別 ID になる）。したがって「旧インデックスに書き足しながら移行する」形は取れず、**必ず全件再構築＋エイリアス切替**になる。これを 6-1 の手順とロールバック条件に反映する。

#### 5-5: 旧世代インデックスとの共存

- **作業内容**: `excluded` 未定義文書に対する**否定形フィルタ必須**ルール（`mustNot(termQuery("excluded", true))`。`must(termQuery("excluded", false))` は旧世代文書が一件も一致せずサジェスト結果が全滅するため**禁止**）。データモデル側の理由づけを書き、手順は 0003 に委ねる。
- **注**: MIG-13 実施時に**除外フィルタ付与前後のレイテンシ差分を計測項目に含める**旨を、後続タスクへの申し送りとして記載する（申し送り 5）。

#### 5-6: 0002 のレビュー

- **観点**: mapping が 1 つに統合されているか / `[要確認]` が 0 件か / `0005-schema-draft.md` の誤りを再生産していないか / `scripted_upsert` 前提の記述が混入していないか（検証タスクは Painless を単一の権威とする前提で書かれているが、本設計では **Java 側 `SuggestItemMergePolicy` が単一の正**である）/ V10・V11（ID 再設計と既知の制約の明記）を満たすか。

### ステップ 6: `docs/0003-migration-ops-design.md` の執筆

前提: ステップ 5 完了（mapping が確定していないと切替対象が定まらない）。

- **注意**: 調査の結果、**ゼロダウンタイム切替手順は既存文書のどこにも書かれていない**。`0013-step4-migration-roadmap.md` は「二重エイリアスを使う」という宣言が実質 10 行あるだけで、`removeDisableIndices` という語すら登場しない。一次情報は `agent_docs/global/references/legacy/02-architecture.md:80-90`（4 ステップと `Suggester.java` の行番号）にしかない。**本章は再構成ではなく新規書き起こしである**。

- **作業内容**:
  1. **二重エイリアス切替手順**: `createNextIndex()`（新インデックス作成＋更新エイリアス付替、`Suggester.java:250`）→ 全件再投入 → 検証 → `switchIndex()`（検索エイリアス切替）→ `removeDisableIndices()`（旧削除）の 4 ステップ。エイリアス付替を atomic に行う API 呼び出し形（aliases actions の add/remove を 1 リクエストに束ねる）まで書く。
  2. **事前条件と検証基準**: 切替前の件数検証、スモークテスト、切替可否の判定基準。
  3. **ロールバック手順**: エイリアスを戻すだけで済む範囲、旧世代インデックスの保持期間と削除タイミング、切戻し時にも**否定形フィルタが必須**である理由。
  4. **フェーズ内のスキーマ変更を 1 回の再構築に束ねるルール**。Phase 1a は MIG-02（score 廃止）に**決定的 ID の方式変更（P11）を相乗り**させ、1 回の再構築に束ねる。
     - **ID 方式変更の移行手順**（P11 / 0002 §5-4 と対）: ID が変わると新旧で同じ語が別 ID になるため、**旧世代インデックスとの共存・部分移行は成立しない**。したがって「新スキーマ・新 ID で全件再投入 → 検証 → エイリアス切替」以外の経路を取らないことを手順として明記する。ロールバックは**エイリアスを旧世代に戻すのみ**（旧インデックスは切替後も一定期間保持する）で、新世代に書いた内容を旧世代へ戻す経路は存在しないことを明示する。ID 変更に伴う切替前の検証項目（新旧の件数比較が単純一致にならない場合の判定基準。①② の衝突解消により**新世代のほうが件数が増えうる**）を定義する。
  5. **refresh 戦略**（MIG-16）: 毎バッチ refresh（`ContentIndexingOperations.java:345`）の廃止、取り込み完了時 1 回もしくは `refresh_interval` 任せへの変更、refresh 戦略を明示的な設定/パラメータとして切り出すこと。**再構築時は投入中 `refresh_interval=-1` → 完了後に既定へ復帰**という定石（申し送り 3）。CPU 負荷制御は `waitController` の責務でありバッチ件数に負荷制御の意味を持たせない旨。**具体的な最適値は決めない**（実測は後続）。トレードオフ（取り込み途中の逐次可視性が失われる）を明記。
  6. **shards / replicas 設定の受け渡し**（MIG-17）: fess の `fess_config.properties` に設定項目を追加し `SuggestHelper` が API に渡す経路。スキーマ変更を伴うため二重エイリアス再構築経由であること。
  7. **`knn_vector` を後から追加する手順**（P5・MIG-24 の予約）: 並行構築＋二重エイリアスで `embedding` フィールドと `index.knn: true` を追加できることを手順として示す。`dimension` は実値未定であるため予約に留める旨を明記。
  8. **fess 本体との同期リリース手順**: Phase 1b（MIG-06/08/09/10）は fess 本体 PR の同期リリースが前提。リリース順序、fess 連携テストの補強が必須である旨。
  9. **`SuggestJob` / `SuggestCreator`（別 JVM 子プロセス）との協調**: 12:00 バッチ以外の任意タイミングで再構築を起動する手段、失敗時の再実行と冪等性。
- **完了条件**: 運用者が手順書として実行できる粒度になっている（「二重エイリアスで切り替える」で終わっていない）。申し送り 3 が消化済み。
- **リスク**: 一次情報が `legacy/02-architecture.md` と `Suggester.java` の実装しかないため、記述の正しさはコード確認に依存する。手順の各ステップに対応する実装箇所（file:line）を必ず併記する。

### ステップ 7: `docs/0000-design-overview.md` の完成と通し整合レビュー

前提: ステップ 3・5・6 完了。

- **作業内容**:
  1. MIG → 設計書対応表の**節番号を実体から埋める**。
  2. 訂正一覧を確定させる（ステップ 4・5 で判明した既存資料の誤りを追加）。
  3. **申し送り事項の着地確認**（提案書の運用ルール (1)）:

| 申し送り | 着地先 | 確認 |
| --- | --- | --- |
| `apply` 引数の最終形 | 0001 §3-8 | |
| realtime get のためマージ正しさが refresh に非依存 | 0002 §5-4 | |
| 頻度集約の回帰テスト仕様 | 0002 §5-4 | |
| `refresh_interval=-1` 定石 | 0003 §5 | |
| `roles` の許可リストと権限扱い | 0001 §3-5 | |
| MIG-13 のレイテンシ計測（後続へ） | 0002 §5-5 | |
| MIG-25 の作業内容 | 0000 | |
| 決定的 ID 再設計（P11、MIG 外） | 0002 §5-4 ＋ 0003 §6-1 | |
| F-04 / F-10 を既知の制約として明記（P12） | 0002 §5-3 / §5-4 | |

  4. **通し整合レビュー**:
     - 各設計書の冒頭に「対象 MIG / 消化する申し送り / 依存する [確定] 番号」の宣言があるか
     - **提案書の内容を転記していないか**（根拠・経緯は提案書に一本化し、設計書は結論と仕様だけ。各文書が提案書の 1/5 程度に収まっているか）
     - `[要確認]` が全文書で 0 件か（§5.3 の実測依存項目は「後続タスク」として参照するのみで、設計の前提にしていないか）
     - 0001 の IF と 0002 のマージ規則が矛盾していないか（`SuggestItemMergePolicy` のシグネチャと挙動）
     - 0002 の mapping と 0003 の切替手順が同じスキーマを指しているか
- **完了条件**: 上記チェックが全項目 pass。

### ステップ 8: 作業履歴の記録

- **対象**: `agent_docs/tasks/20260706_design_document/` 配下に通し番号で作成
- **作業内容**: 各ステップの実施記録。想定される番号割り当ては以下（実際の分割は作業量に応じて調整）。

| 番号 | 内容 |
| --- | --- |
| `0004-new-findings.md` | ステップ 1 |
| `0005-design-overview-skeleton.md` | ステップ 2 |
| `0006-api-design.md` | ステップ 3 |
| `0007-reading-field-policy.md` | ステップ 4 |
| `0008-datamodel-design.md` | ステップ 5 |
| `0009-migration-ops-design.md` | ステップ 6 |
| `0010-final-consistency-review.md` | ステップ 7 |

---

## 4. 依存関係と推奨実行順序

```
ステップ1（新規発見の棚卸し）
   │
   ├─→ ステップ2（0000 骨組み）
   │       │
   │       ├─→ ステップ3（0001 API設計）──────────┐
   │       │      3-1 差分表 → 3-2 公開IF          │
   │       │      → 3-3 spi → 3-4 非同期契約       │
   │       │      → 3-5 フィールド選択 → 3-6 設定  │
   │       │      → 3-7 権限 → 3-8 旧→新 → 3-9 fess│
   │       │      → 3-10 レビュー                  │
   │       │                                       │
   │       └─→ ステップ4（reading_* 方針）         │
   │               │                               │
   │               └─→ ステップ5（0002 データモデル）
   │                       5-4 ID再設計(ハッシュ化) → 5-3 マージ規則
   │                       → 5-1 mapping → 5-2 settings → 5-5 共存
   │                       │                       │
   │                       └─→ ステップ6（0003 移行運用）
   │                               │               │
   └───────────────────────────────┴───────────────┴─→ ステップ7（0000 完成＋通し整合）
                                                           │
                                                           └─→ ステップ8（作業履歴）
```

- **並行可能**: ステップ 3（0001）とステップ 4→5（0002）は並行できる。ただし `SuggestItemMergePolicy` は 3-3 と 5-3 の両方に現れるため、どちらかを先に確定させて他方が従う（推奨: **5-3 で挙動を決め、3-3 のシグネチャがそれに従う**。挙動が形を決めるため）。
- **クリティカルパス**: ステップ 1 → 4 → **5（5-4 → 5-3 → 5-1）** → 6 → 7。
- **P11 / P13 によるクリティカルパスの変化**: ID 再設計（5-4）が加わったことで、ステップ 5 内部の順序に制約が生まれた。ID の構成要素は `text` のまま（P13）なので **`kinds` の意味・検索側の重複除去には波及しない**が、`userBoost` の合成規則（5-3）と切替・ロールバックの前提（6-1/6-4）には波及する。ステップ 5 の工数は当初想定から**1 節ぶん増加**し、ステップ 6 にも移行手順が 1 項目増える。
- **循環なし**: 上記 DAG に循環はない（5-4 → 5-3 → 5-1 の内部順序を含む）。

---

## 5. 検証方針

設計書の「テスト」は執筆物の自己検査になる。以下を完了判定に使う。

| # | 検証項目 | 方法 |
| --- | --- | --- |
| V1 | MIG カバレッジ | 0000 の対応表に MIG-01〜25 が全件現れ、「未割り当て」が 0 件 |
| V2 | 申し送り消化 | ステップ 7-3 の表が全行 pass |
| V3 | `[要確認]` 残存 0 件 | `grep -c '要確認' docs/000*.md` が期待値どおり（参照文脈以外で 0） |
| V4 | 1 行 IF の不在 | spi 5 IF と全補助型に中身がある（P3） |
| V5 | 旧公開メソッドの網羅 | `Suggester` public 18 / `SuggestIndexer` public 28 の全件が対応表に現れる |
| V6 | 根拠の非転記 | 各設計書が提案書の 1/5 程度（目安 20KB 前後）に収まっている |
| V7 | 文書間整合 | 0001 の IF ↔ 0002 のマージ規則、0002 の mapping ↔ 0003 の切替手順 |
| V8 | 既存資料の訂正明示 | F-01/F-02 を含む訂正一覧が 0000 にある |
| V9 | コード根拠 | 事実主張に file:line が付いている（特に 0003 の手順） |
| V10 | ID 再設計（P11 / P13） | ①②（切り詰め・衝突）が**ハッシュ化**で解消され、切り詰めロジックが新方式に存在しない。**ID の構成要素が `text` のみである**（kind を含まない）。③（elevate word の boost 潰れ）が **0002 §5-3 の `userBoost` 合成規則**で解消されている。**KEEP-03 との衝突を避けた判断であることの根拠が 0002 本文に 1 行残っている**。0003 に ID 変更の移行手順とロールバック条件がある |
| V11 | 既知の制約の明記（P12） | F-04（`reading_i` の消滅）と F-10（楽観ロック欠如）が 0002 に明記され、F-10 には「multiGet では解決しない」「MIG-15 第 2 段で一括して扱う」が併記されている |

**設計書に書く「テスト仕様」**（実装は後続タスク）:
- 頻度集約の回帰テスト（refresh 廃止後 / multiGet 化後、申し送り 2）
- マージ規則の等価性テスト（既存 `SuggestItemMergerTest` 等の流用。現行と同一結果になるものと意図的な差分の区別）
- 旧世代インデックス共存下での否定形フィルタの動作確認
- fess 連携テストの補強（MIG-06/09 の移行時に必須）

---

## 6. リスクと未確定事項

### 6.1 判断事項

#### 確定済み

| # | 事項 | 決定 | 反映先 |
| --- | --- | --- | --- |
| **U1** | 決定的 ID の設計（F-05/F-06） | **[確定] 今回の設計に含める**（P11）。3 問題をすべて解消する新方式を 0002 §5-4 で設計し、移行手順を 0003 §6-1 に記載する。Phase 1a の MIG-02（score 廃止）による全インデックス再構築に**相乗り**させる。これを逃すと次の再構築機会まで待つことになる | 0002 §5-4 / 0003 §6-1 |
| **U2** | 新規発見バグ（F-08 / F-10） | **[確定]** F-08（`deleteBadWord` のキャッシュ未更新）は `BadWordPolicy` の設計に含める（0001 §3-3）。F-10（楽観ロック欠如）は **0002 に「既知の制約」として明記するに留め**、解消は後続スコープ。MIG-15 第 2 段（`scripted_upsert` + `retry_on_conflict`）と同じ問題領域であり**そこで一括して扱う**旨を併記する（P12） | 0001 §3-3 / 0002 §5-4 |
| **U3** | `reading_*` の語数上限 | **[確定]** 設定可能な上限を設けて切り捨てる。検索側（`SuggestQueryBuilder.java:84-86`）はクエリの語数分しか `reading_i` を引かないため実害がない | ステップ 4 |
| **U4** | `excluded` のマージ時の扱い | **[確定]** 既存値を保持する（新 item は `excluded` を書かず、既存に無い場合のみ `false` で初期化する）。取り込みのたびに bad word 除外が解除される事故を防ぐため | 0002 §5-3 |
| **U5** | F-06 ③（elevate word の `userBoost` 潰れ）を ID の構成で解くか、マージ規則で解くか | **[確定] ID は `text` のハッシュとし、構成要素を増やさない**（kind を含めない）。**③ はマージ規則で解く**（P13）。**根拠: ID に kind を含めると同一語の DOCUMENT / QUERY / USER が別ドキュメントに分裂し、KEEP-03（決定的 ID による重複排除・頻度集約）の前提が壊れる**（頻度集約が kind ごとに割れ、検索結果に同一 text が重複しうる。`SuggestRequest.java:363-365` の kinds フィルタと `SuggestWordsHandler.java:96` の意味も変わる）。③ の実体は `SuggestItemSerializer.java:181` の無条件上書きであり、ID ではなく合成規則の問題である。合流する現行動作は維持する | 0002 §5-3 / §5-4 |

**未確定事項は残っていない。** ステップ 1 から着手できる。

### 6.2 リスク

| リスク | 対策 |
| --- | --- |
| **0003 が新規書き起こしで工数が読めない** | 一次情報が `legacy/02-architecture.md:80-90` と `Suggester.java` の実装のみ。ステップ 6 の着手前に該当実装（`Suggester.java:213,250` および `switchIndex` / `removeDisableIndices`）を読み切ってから書く |
| **既存素材の誤りをそのまま転記する** | `0005-schema-draft.md` の `MAX_READING_NUM` 誤認（F-01/F-02）と、検証タスクの `scripted_upsert` 前提（設計では multiGet 確定・Painless は対象外）の 2 点は、素材を機械的に流用すると設計書に誤りが混入する。ステップ 4 とステップ 5-6 のレビュー観点に明記済み |
| **ID 再設計（P11）がスコープを膨らませる** | P13 により ID の構成要素を `text` のまま据え置いたため、`kinds` の意味と検索側の重複除去には波及しない（KEEP-03 を維持）。残る波及先は 5-3（`userBoost` 合成規則）と 6-1/6-4（切替とロールバック）の 2 つに限定される。**旧世代インデックスとの共存が成立しない**（同じ語が新旧で別 ID になる）ため、部分移行・段階適用の選択肢が消える点を 6-1 に明記する |
| **ID のハッシュ化で逆引きができなくなる** | 現行 ID は `text` の Base64 で可逆。運用・デバッグで ID から text を復元している箇所がないかを 5-4 の作業内容 1 で確認する（コード上は `WordManagementOperations.java:129` / `SuggestItemSerializer.java:130` とも text から ID を再計算しており逆引きしていない）。手作業の運用手順に依存がある可能性は残る |
| **設計書が提案書の焼き直しになり肥大する** | V6 で分量を検査。根拠は提案書へのリンクに留める運用ルールを 0000 に明記 |
| **0001 と 0002 の並行執筆で `SuggestItemMergePolicy` が食い違う** | 5-3 を先に確定させ 3-3 が従う（§4 参照） |
| **Phase 1b が fess 本体の同時改修を要する** | 0001 §3-9 で変更後の形を、0003 §8 でリリース手順を分担して記述。fess 連携テストが手薄である前提で補強を必須と明記 |

### 6.3 本タスクのスコープ外（後続タスクへ）

提案書 §5.3 に対応する。設計書はこれらに依存しない形で記述する。

- 性能の定量評価（multiGet の往復削減効果、`doc.per.request` の最適値、refresh 分離の効果、除外フィルタのレイテンシ差分、最適シャード数）
- refresh 分離による可視性低下の許容可否
- プライバシー / データ保持ポリシー（MIG-22 の前提）
- 埋め込みモデル / 推論基盤（MIG-24 の前提、`dimension` の実値）
- **F-10（Get-then-update の楽観ロック欠如）の解消**（U2 / P12）。`setIfSeqNo`/`setIfPrimaryTerm` による競合制御は、リトライ戦略と部分失敗の扱いまで決める必要があり、**MIG-15 第 2 段（`scripted_upsert` + `retry_on_conflict`）と同じ問題領域**である。第 2 段は「拡張点だけ用意し仕様は含めない」と確定している（§2.3）ため、**そこで一括して扱う**。0002 には既知の制約として記録するに留める
