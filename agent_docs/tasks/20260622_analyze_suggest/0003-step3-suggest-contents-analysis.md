# ステップ3: サジェスト表示内容（データソース・種別・表示項目）の分析

本ドキュメントは作業プラン `0001-work-plan.md` のステップ3の成果物である。
ステップ2の成果物 `0002-step2-architecture-analysis.md` を前提とし、その申し送り事項（種別の実利用挙動、elevate/bad word の apply タイミング、`SuggestItemSerializer.toUpdatedSource` のマージ規則）を深掘りした。

調査対象は全て `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下（リソースは `modules/fess-suggest/src/main/resources/`）。
根拠は `file_path:line` 形式で示す。**[確認]** はコードで確認できた事実、**[推測]** は実装から合理的に推測した内容を表す。
※ file_path はリポジトリ相対の短縮表記（`.../suggest/` 以下）で記す。

---

## 1. サジェストの種別（Kind）

**[確認]** サジェスト項目の種別は `SuggestItem.Kind` enum で3種類のみ定義される（`entity/SuggestItem.java:47-69`）。

| Kind | 文字列値 | 由来 | 主な頻度フィールド |
| --- | --- | --- | --- |
| `DOCUMENT` | `"document"` | クロール済みドキュメント本文のトークン | `docFreq` |
| `QUERY` | `"query"` | 検索語・検索クエリログ由来の語 | `queryFreq` |
| `USER` | `"user"` | 管理者が登録した elevate word（優先表示語） | `userBoost`（高ブースト） |

- **[確認]** Kind 文字列は `toString()` がそのまま返す（`SuggestItem.java:65-68`）。インデックス上は `kinds` フィールド（keyword 配列）に格納される（`SuggestItemSerializer.java:69`）。
- **[確認]** 1つのサジェスト語（= 同一 `text` の1ドキュメント）は **複数の Kind を同時に持ちうる**。`_id` が `text` から決定的に生成され（`SuggestItem.java:140`）、同一語の登録時に kinds が集合和でマージされるため（後述 4.3、`SuggestItemSerializer.java:165-173`）。例: ある語が本文にも検索ログにも現れれば、その1ドキュメントの `kinds=["document","query"]` になりうる。

---

## 2. データソースの洗い出し（供給元と実装クラス）

**[確認]** サジェストのデータ供給元は大きく **4経路**。すべて `SuggestItem` に変換されて同一インデックスへ書き込まれる。
parse の実体は `index/contents/DefaultContentsParser.java`、登録の入口は `index/operations/ContentIndexingOperations.java`（クエリログ/ドキュメント/検索語）および `index/operations/WordManagementOperations.java`（elevate word）。

| # | データソース | Kind | parse メソッド | 入口 API（`SuggestIndexer`） | 初期 docFreq / queryFreq / userBoost |
| --- | --- | --- | --- | --- | --- |
| 1 | **ドキュメント本文**（クロール文書のフィールド値） | `DOCUMENT` | `parseDocument` (`DefaultContentsParser.java:153-211`) | `indexFromDocument(...)` | docFreq=1, queryFreq=0, userBoost=-1→1 |
| 2 | **検索クエリログ**（Lucene クエリ文字列） | `QUERY` | `parseQueryLog` (`DefaultContentsParser.java:114-151`) | `indexFromQueryLog(...)` | docFreq=0, queryFreq=1, userBoost=-1→1 |
| 3 | **検索語**（ユーザー入力の生検索語、件数付き） | `QUERY` | `parseSearchWords` (`DefaultContentsParser.java:78-112`) | `indexFromSearchWord(...)` (`ContentIndexingOperations.java:395`) | docFreq=0, queryFreq=score(=件数), userBoost=-1→1 |
| 4 | **Elevate Word（優先表示語）**（管理者登録の辞書的語） | `USER` | `ElevateWord.toSuggestItem()` (`entity/ElevateWord.java:143-149`) | `addElevateWord(...)` (`WordManagementOperations.java:103`) | docFreq=1, queryFreq=0, userBoost=boost |

> **[確認] 同義語辞書は専用のデータソースではない。** fess-suggest 単体には「同義語/サジェスト辞書をソースとして直接取り込む」経路は存在しない。同義語等は OpenSearch アナライザ（`suggest_analyzer.json` 等）側で処理されるテキスト解析の一部であり、サジェスト語そのものを供給するのは上記4経路のみ。**[推測]** fess 本体側のクロール/検索ログ収集がこれら4経路を駆動する（ステップ4の範囲）。

> **[確認] userBoost の正規化**: コンストラクタで `userBoost <= 1` は強制的に 1 に丸められる（`SuggestItem.java:131-135`）。よって document/query 経路（boost=-1 を渡す）は実質 userBoost=1。USER（elevate）経路のみ boost>1 を保持できる。

---

## 3. 各データソースの収集・正規化・スコアリング

### 3.1 共通テキスト処理パイプライン

**[確認]** いずれの経路も `正規化(Normalizer) → 読み変換(ReadingConverter) → 解析(SuggestAnalyzer)` の順で処理する（ステップ2 §2.2 参照）。

- **正規化**: `normalizer.normalize(word, field, langs)`（例 `DefaultContentsParser.java:91, 139`）。全角→半角英字、半角カナ→全角カナ、ICU正規化等のチェイン（`normalizer/` 配下）。
- **読み変換**: `readingConverter.convert(...)` でカタカナ/ローマ字読みを生成し `reading_i` に格納（`DefaultContentsParser.java:92, 140`）。ドキュメント経路のみ、reading トークン数が本体トークン数と一致する場合に `contentsReadingConverter` を使う（`DefaultContentsParser.java:188-193`）。
- **解析（トークン分割）**: ドキュメント経路は `SuggestAnalyzer` で本文をトークン化し、**1トークン=1 SuggestItem** にする（`DefaultContentsParser.java:169, 179-204`）。検索語経路は語ごとに解析で「サジェスト対象になりうるか」を判定（除外フィルタ、3.5）。

### 3.2 ドキュメント本文（DOCUMENT）

**[確認]** `parseDocument`（`DefaultContentsParser.java:153-211`）:
- 対象は `fields`（サポート対象フィールド）の各値。フィールド値が無ければスキップ（`:162-165`）。
- 本文を `analyzeText` でトークン分割（`:169`）。`maxAnalyzedContentLength`（既定1000、システムプロパティ `fess.suggest.max.analyzed.content.length` で変更可）ごとにバッファ分割して解析（`:75, 261-278`）。
- 空白トークンはスキップ（`:182-184`）。各トークンを `docFreq=1` の `SuggestItem`(Kind=DOCUMENT) 化（`:202-203`）。
- `tags` は `tagFieldNames` のフィールド値から、`roles` は `roleFieldName` のフィールド値から、`languages` は `langFieldName` の値から付与（`:158-167, 201`）。

→ **スコアへの効き方 [確認]**: docFreq は登録のたびに +1 加算され（4.3）、検索時に `LOG2P` modifier の field value factor で加点される（`request/suggest/SuggestQueryBuilder.java:150-153`）。出現回数が多い語ほどスコアが上がる。

### 3.3 検索クエリログ（QUERY）

**[確認]** `parseQueryLog`（`DefaultContentsParser.java:114-151`）:
- `QueryLog.getQueryString()` / `getFilterQueryString()` を `SuggestUtil.parseQuery(queryString, field)` で **フィールド別に語を抽出**（`:117-132`）。
- tags / roles はクエリ文字列・フィルタクエリ文字列から `tagFieldNames` / `roleFieldName` を使って抽出（`:120-127, 221-225`）。
- 抽出語ごとに `queryFreq=1` の `SuggestItem`(Kind=QUERY) を生成（`:144`）。フィールドは抽出元フィールド1つ。

### 3.4 検索語（QUERY）

**[確認]** `indexFromSearchWord`（`ContentIndexingOperations.java:395-435`）→ `parseSearchWords`（`DefaultContentsParser.java:78-112`）:
- 生検索語の連続空白を単一空白に圧縮して語分割（`ContentIndexingOperations.java:402-412`）。
- 各語を正規化・読み変換。除外フィルタに該当しない語のみ採用（`:86-103`）。
- **`queryFreq = score`（= 呼び出し元が渡す `num` = 検索件数等）** の `SuggestItem`(Kind=QUERY) を1つ生成（`:107-108`、`ContentIndexingOperations.java:415`）。つまり検索語経路は「検索された回数/件数」を直接 queryFreq に積める。

→ **スコアへの効き方 [確認]**: queryFreq も `LOG2P` で加点（`SuggestQueryBuilder.java:154-157`）。検索ログ・検索語経路の語は人気度として効く。

### 3.5 検索語の除外（isExcludeSearchword）

**[確認]** `isExcludeSearchword`（`DefaultContentsParser.java:344-358`）: 検索語をアナライザにかけてトークンが1つも出なければ **除外（サジェスト化しない）**。langs 指定がある場合は、いずれかの言語でトークンが出れば採用。
→ **[推測]** 記号のみ・解析不能なノイズ検索語をサジェスト辞書から排除する役割。

### 3.6 Elevate Word（USER）

**[確認]** `ElevateWord.toSuggestItem()`（`entity/ElevateWord.java:143-149`）:
- `docFreq=1, queryFreq=0, userBoost=boost`、Kind=USER の `SuggestItem` を生成。readings は登録時の reading をそのまま使う（`:144-145`）。
- 登録は `WordManagementOperations.addElevateWord`（`:103-115`）。語と reading を正規化し、`settings.elevateWord().add(...)` で **設定（OpenSearch 上の設定ストア）に永続化**してから、`apply=true` のときのみ即座にインデックスへ書き込む（`:109-112`）。

→ **スコアへの効き方 [確認]**: userBoost は検索時に `fieldValueFactorFunction(USER_BOOST).missing(1f)` で乗算的に効く（`SuggestQueryBuilder.java:158-159`）。boost>1 の USER 語は他種別より上位に出やすい。

---

## 4. 申し送り事項の解明

### 4.1 種別（document/query/user）の実利用挙動

- **[確認] 検索時の既定はKind無フィルタ**。`SuggestRequest` は `addKind(...)` で明示的に追加された場合のみ kinds フィルタを付ける（`request/suggest/SuggestRequest.java:363-365`、`kinds` が空ならフィルタなし）。つまり既定では document/query/user すべてが候補になり、スコア順（4.4）で混在表示される。`addKind("query")` 等で種別を絞り込める。
- **[確認] popularWords は QUERY 種別固定**。`PopularWordsRequest.buildQuery` が `must(termQuery(KINDS, "query"))` を強制し、さらに `reading_1` が存在しない（=単一語）かつ `queryFreq >= queryFreqThreshold`（既定10）の語のみ対象（`request/popularwords/PopularWordsRequest.java:212-214`）。人気語は「よく検索された単一語」に限定される。
- **[確認] USER 種別は elevate（優先表示）専用**で、boost により上位に押し上げる用途。document/query は自動収集、user は手動登録という役割分担。

### 4.2 elevate / bad word の apply タイミング

**[確認]** いずれも「設定への永続化」と「インデックスへの即時反映（apply）」を分離している。

- **addBadWord(index, badWord, apply)**（`WordManagementOperations.java:77-84`）:
  - 常に `settings.badword().add(normalized)` で設定に追加。
  - `apply=true` のときのみ `deleteByQuery(wildcardQuery(TEXT, "*badword*"))` で **既存の該当語を即削除**。
  - `apply=false` なら設定追加のみ（既存ドキュメントはそのまま、以後の登録時に `IndexingOperations.index` の badword フィルタで弾かれる、`IndexingOperations.java:78`）。
- **deleteBadWord(badWord)**（`:91-93`）: 設定からの削除のみ。インデックスは変更しない。
- **addElevateWord(index, elevateWord, apply)**（`:103-115`）:
  - 常に `settings.elevateWord().add(normalized)` で設定に追加。
  - `apply=true` のときのみ `indexingOps.index(...)` で **即座にインデックスへ USER 語を投入**（badword フィルタは通る）。
  - `apply=false` なら設定追加のみ。
- **deleteElevateWord(index, elevateWord, apply)**（`:125-132`）: 設定から削除。`apply=true` なら `delete(createSuggestTextId(normalized))` でインデックスからも即削除。
- **restoreElevateWord(index)**（`:140-157`）: 設定に保存済みの全 elevate word を `apply=true` で再投入。**[推測]** インデックス再構築（switchIndex 後の新インデックス）に対して USER 語を復元する用途。

→ **[確認] 要点**: bad word は「既存削除（apply 時）＋以後の登録フィルタ」、elevate word は「設定保存＋即時 index（apply 時）」。設定ストアが正本で、apply はインデックスへの即時反映フラグ。

### 4.3 `SuggestItemSerializer.toUpdatedSource` のマージ規則（Get-then-update 時）

**[確認]** `SuggestItemSerializer.toUpdatedSource(item, existingSource)`（`entity/SuggestItemSerializer.java:142-185`）。`SuggestIndexWriter` が既存ドキュメントを Get し、本メソッドで新規 item とマージした source を作って再 INDEX する。

| フィールド | マージ規則 | 根拠 |
| --- | --- | --- |
| `text` | 新 item の値で置換（同一 `_id` なので実質同値） | `:144` |
| `reading_i` | 既存リストへ新値を**重複排除して追加（集合和）**、distinct 化 | `:147-158, 254-263` |
| `fields` | 既存リストへ新値を集合和（`mergeListField`） | `:160, 227-238` |
| `tags` | 集合和 | `:161` |
| `roles` | 集合和 | `:162` |
| `languages` | 集合和 | `:163` |
| `kinds` | 既存リストへ新 kind 文字列を集合和（重複排除） | `:165-173` |
| `queryFreq` | **既存値 + 新値（加算）** | `:175, 243-249` |
| `docFreq` | **既存値 + 新値（加算）** | `:178` |
| `userBoost` | 新 item の値で**置換（加算ではない）** | `:181` |
| `score` | `(更新後queryFreq + 更新後docFreq) * userBoost` を再計算 | `:182` |
| `@timestamp` | 新 item の値で置換 | `:183` |

- **[確認] 頻度は加算、集合系（reading/fields/tags/roles/languages/kinds）は集合和、userBoost と timestamp は最新で置換**。これにより同一語の出現頻度が登録のたびに累積し、由来（kinds）や所属フィールド・タグ・ロールは累積的に広がる。
- **[確認] `mergeFrequency`** は既存値が null なら新値、あれば `新値 + 既存値`（`:243-249`）。
- **[確認] score はインデックス時に事前計算されたフィールド**でもあるが、検索時のランキングは `SuggestQueryBuilder` の function score（docFreq/queryFreq/userBoost）で別途計算される（4.4）。インデックス上の `score` フィールドは popularWords 等での補助・並べ替え用途。

> **[確認] 参考: アプリ側マージ `SuggestItemMerger.merge`**（`entity/SuggestItemMerger.java:59-96`）。同一バルク内の同 `_id` アイテムを書き込み前に統合する経路で、規則はほぼ同様（readings/fields/tags/languages/roles/kinds は集合和、queryFreq/docFreq は加算、timestamp/userBoost は item2＝新しい方を採用）。`toUpdatedSource`（OpenSearch 既存 doc とのマージ）と `SuggestItemMerger`（同一バッチ内マージ）で二段のマージが行われる。

### 4.4 検索時スコアリングの確定（function score）

**[確認]** `SuggestQueryBuilder.buildFunctionScoreQuery`（`request/suggest/SuggestQueryBuilder.java`）:
- 単一語かつ非ひらがなクエリで `text` 前方一致した場合、`weightFactorFunction(prefixMatchWeight)`（既定2.0）で加点（`:145-147`）。
- `docFreq`: `fieldValueFactorFunction(DOC_FREQ).modifier(LOG2P).setWeight(1.0)`（`:150-153`）。
- `queryFreq`: `fieldValueFactorFunction(QUERY_FREQ).modifier(LOG2P).setWeight(1.0)`（`:154-157`）。
- `userBoost`: `fieldValueFactorFunction(USER_BOOST).missing(1f).setWeight(1.0)`（`:158-159`）。
- → 頻度系は対数加点（飽和）、userBoost は乗算。最終的に `boostMode=REPLACE`, `scoreMode=MULTIPLY`（ステップ2 §3.2）。

---

## 5. サジェスト結果として返るフィールド（表示項目）

### 5.1 SuggestItem の構造（詳細レスポンスの中身）

**[確認]** `SuggestItem`（`entity/SuggestItem.java:71-95`）が保持する属性 = インデックス上の1ドキュメント = 1サジェスト語。

| 属性 | 型 | 意味 | getter / インデックスフィールド |
| --- | --- | --- | --- |
| `text` | String | サジェスト表示語句（複数語は区切り連結） | `getText()` / `text` |
| `readings` | String[][] | 読み（語位置 i ごとに複数候補）。クエリ照合用 | `getReadings()` / `reading_i` |
| `fields` | String[] | 由来フィールド名（title, content 等） | `getFields()` / `fields` |
| `tags` | String[] | タグ（絞り込み用） | `getTags()` / `tags` |
| `roles` | String[] | ロール（権限フィルタ用）。空なら `_guest_` 補完 | `getRoles()` / `roles`（`:121-126`） |
| `languages` | String[] | 言語 | `getLanguages()` / `languages` |
| `kinds` | Kind[] | 種別（document/query/user の集合） | `getKinds()` / `kinds` |
| `queryFreq` | long | 検索由来出現頻度 | `getQueryFreq()` / `queryFreq` |
| `docFreq` | long | ドキュメント由来出現頻度 | `getDocFreq()` / `docFreq` |
| `userBoost` | float | 手動ブースト（>1で有効、既定1） | `getUserBoost()` / `userBoost` |
| `timestamp` | ZonedDateTime | 登録/更新時刻 | `getTimestamp()` / `@timestamp` |
| `score` | （導出） | `(queryFreq+docFreq)*userBoost`。インデックスフィールドとして保存 | `SuggestItemSerializer.java:73` / `score` |
| `id` | String | `text` から決定的生成 | `getId()` |

- **[確認] フィールド名定数は `constants/FieldNames.java`**（`text`/`reading_`/`score`/`queryFreq`/`docFreq`/`userBoost`/`kinds`/`@timestamp`/`tags`/`roles`/`fields`/`languages`）。

### 5.2 suggest() のレスポンス（SuggestResponse）

**[確認]** `request/suggest/SuggestResponse.java`:
- `index`（`getIndex`）, `tookMs`（`getTookMs`）, `words: List<String>`（`getWords` = サジェスト語の文字列リスト）, `num`（語数）, `total`（総ヒット数）, `items: List<SuggestItem>`（`getItems` = 詳細）。
- **[確認] `suggestDetail=false`（既定）では `items` は空**で、`words`（語文字列のみ）が返る（ステップ2 §3.3、`SuggestResponseCreator`）。`suggestDetail=true` で `items` に上記 §5.1 の全属性が載る。
- → **UI に最低限表示されるのは `words`（サジェスト語句）**。読み仮名・件数（freq）・kinds・tags・roles 等は詳細取得時に `items` 経由で利用可能。

### 5.3 popularWords() のレスポンス（PopularWordsResponse）

**[確認]** `PopularWordsRequest.createResponse`（`request/popularwords/PopularWordsRequest.java:253-277`）:
- `words: List<String>`（人気語文字列）と、`detail=true`（既定）なら `items: List<SuggestItem>`。
- ランダム化 rescorer（`buildRescore`, `:242-246`）で同程度人気の語をシャッフルして返す。

---

## 6. データソースの有効/無効・設定による切り替え

| 切り替え対象 | 条件 / 設定 | 根拠 |
| --- | --- | --- |
| ドキュメント解析の最大長 | システムプロパティ `fess.suggest.max.analyzed.content.length`（既定1000） | `DefaultContentsParser.java:75` |
| 対象フィールド（document/querylog） | `SuggestIndexer.setSupportedFields(...)` 等で指定したフィールドのみ収集 | `parseDocument`/`parseQueryLog` の `fields` 引数 |
| tag / role / lang フィールド | `setTagFieldNames` / `setRoleFieldName` / `langFieldName` で指定 | `DefaultContentsParser.java:158-167` |
| bad word による除外 | 設定 `settings.badword()` に登録された語を含む item は登録時に除外。apply 時は既存も削除 | `IndexingOperations.java:78`, `WordManagementOperations.java:77-84` |
| elevate word（USER語）の反映 | `apply=true` で即時 index、`false` で設定保存のみ | `WordManagementOperations.java:103-115` |
| 検索語のノイズ除外 | アナライザでトークンが出ない語は不採用 | `DefaultContentsParser.java:344-358` |
| 検索時の種別フィルタ | `addKind(...)` を呼んだ場合のみ kinds 絞り込み（既定は全種別） | `SuggestRequest.java:363-365` |
| popularWords の閾値 | `queryFreqThreshold`（既定10）以上、単一語、Kind=query のみ | `PopularWordsRequest.java:212-214` |

> **[推測]** 「どのデータソースを実際に流すか（document / querylog / searchword / elevate のどれを有効にするか）」は fess-suggest 単体では選択肢を持たず、各 `indexFrom*` / `addElevateWord` を **呼び出すか否か** が有効/無効に相当する。これらを駆動するのは fess 本体側のジョブ設定（ステップ4で確認）。

---

## 7. 要点まとめ（ステップ3 完了条件への対応）

### 種別（Kind）一覧
- `DOCUMENT`（ドキュメント本文由来, docFreq）/ `QUERY`（検索語・検索ログ由来, queryFreq）/ `USER`（elevate word 由来, userBoost）。1語が複数 Kind を併せ持ちうる（集合和マージ）。

### データソース一覧（4経路）
1. ドキュメント本文 → `parseDocument`（DOCUMENT, docFreq+=1）
2. 検索クエリログ → `parseQueryLog`（QUERY, queryFreq+=1）
3. 検索語（件数付き）→ `parseSearchWords` / `indexFromSearchWord`（QUERY, queryFreq+=件数）
4. Elevate Word → `ElevateWord.toSuggestItem` / `addElevateWord`（USER, userBoost=boost）
- 同義語辞書は独立ソースではなくアナライザ層の処理。

### スコアリング規則
- **登録時**: 同一語（決定的 `_id`）に対し docFreq/queryFreq は**加算**、reading/fields/tags/roles/languages/kinds は**集合和**、userBoost/timestamp は**最新で置換**（`SuggestItemSerializer.toUpdatedSource`）。インデックスの `score = (queryFreq+docFreq)*userBoost` を事前計算。
- **検索時**: function score で docFreq/queryFreq を `LOG2P` 加点、userBoost を乗算、前方一致に `prefixMatchWeight`(2.0) 加点。`boostMode=REPLACE`。
- **popularWords**: Kind=query・単一語・queryFreq>=10 を `queryFreq` で順位付けし、ランダム rescorer で多様化。

### 表示項目
- `suggest()` 既定は **`words`（語句文字列リスト）** のみ。`suggestDetail=true` で `items`（`SuggestItem`）として **text / readings(読み) / fields / tags / roles / languages / kinds / queryFreq / docFreq / userBoost / timestamp / score** が取得可能。
- レスポンス共通: `index`, `tookMs`, `total`, `num`。

### elevate / bad word の apply
- **bad word**: 設定追加は常時。`apply=true` で既存語を wildcard 削除。以後の登録は常にフィルタ。
- **elevate word**: 設定追加は常時。`apply=true` で USER 語を即 index。`restoreElevateWord` で再構築時に一括復元。

---

## 8. 残課題・未確定事項（次ステップへの申し送り）

- **[推測]** 4つのデータソースを実際に駆動する fess 本体側のジョブ/設定（どの経路を有効にするか、対象フィールド・タグ・ロールフィールドの実値、更新タイミング）はステップ4の範囲。
- **[推測]** UI 上でサジェストとして最終的に何が見えるか（words のみか詳細か）は fess 本体のサジェスト API / フロントエンド実装に依存。ステップ4で `suggestDetail` の使われ方を確認推奨。
- bad word の wildcard 削除（`*badword*`）は部分一致削除であり、意図せず広く消える可能性がある点は運用上の注意点として記録（コード上は確認済み、影響評価は未実施）。
