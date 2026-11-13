# サジェスト表示内容（データソース・種別・表示項目・スコアリング）

本ファイルは fess-suggest 調査ドキュメントの一部であり、サジェストに表示される内容（種別・データソース・スコアリング・表示項目）を扱う。インデックス・前提（バージョン情報・参照ソースの所在・凡例）は [README.md](./README.md) を参照のこと。関連: [概要](./01-overview.md) / [全体アーキテクチャ](./02-architecture.md) / [fess 本体からの利用方法](./04-fess-integration.md) / [発見した課題](./05-issues.md)。

凡例: **[確認]** = ソースコードで直接確認できた事実、**[推測]** = 実装から合理的に推測した内容。根拠は `file_path:line` 形式。

---

## 3.1 サジェストの種別（Kind）[確認]

種別は `SuggestItem.Kind` enum の3種類のみ（`entity/SuggestItem.java:47-69`）。

| Kind | 文字列値 | 由来 | 主な頻度フィールド |
| --- | --- | --- | --- |
| `DOCUMENT` | `"document"` | クロール済みドキュメント本文のトークン | `docFreq` |
| `QUERY` | `"query"` | 検索語・検索クエリログ由来の語 | `queryFreq` |
| `USER` | `"user"` | 管理者が登録した elevate word（優先表示語） | `userBoost`（高ブースト） |

- **[確認]** 1つのサジェスト語（＝同一 `text` の1ドキュメント）は **複数の Kind を同時に持ちうる**。決定的 `_id` と集合和マージ（3.4）により、ある語が本文にも検索ログにも現れれば `kinds=["document","query"]` になりうる。

## 3.2 データソース（4経路）[確認]

サジェスト語の供給元は4経路。すべて `SuggestItem` に変換され同一インデックスへ書き込まれる。

| # | データソース | Kind | parse メソッド | 入口 API | 初期頻度 |
| --- | --- | --- | --- | --- | --- |
| 1 | **ドキュメント本文** | `DOCUMENT` | `parseDocument`（`DefaultContentsParser.java:153-211`） | `indexFromDocument(...)` | docFreq=1 |
| 2 | **検索クエリログ**（Lucene クエリ文字列） | `QUERY` | `parseQueryLog`（`:114-151`） | `indexFromQueryLog(...)` | queryFreq=1 |
| 3 | **検索語**（件数付き生検索語） | `QUERY` | `parseSearchWords`（`:78-112`） | `indexFromSearchWord(...)`（`ContentIndexingOperations.java:395`） | queryFreq=件数 |
| 4 | **Elevate Word**（優先表示語） | `USER` | `ElevateWord.toSuggestItem()`（`entity/ElevateWord.java:143-149`） | `addElevateWord(...)`（`WordManagementOperations.java:103`） | userBoost=boost |

- **[確認] 同義語辞書は独立したデータソースではない**。同義語等は OpenSearch アナライザ（`suggest_analyzer.json` 等）側のテキスト解析の一部であり、サジェスト語そのものを供給するのは上記4経路のみ。
- **[確認] userBoost の正規化**: コンストラクタで `userBoost <= 1` は強制的に 1 に丸められる（`SuggestItem.java:131-135`）。よって document/query 経路（boost=-1 を渡す）は実質 userBoost=1。USER（elevate）経路のみ boost>1 を保持できる。

## 3.3 各データソースの収集・正規化の詳細 [確認]

- **ドキュメント本文（DOCUMENT）** `parseDocument`（`DefaultContentsParser.java:153-211`）: 対象 `fields` の各値を `SuggestAnalyzer` でトークン分割し **1トークン=1 SuggestItem**（`docFreq=1`）化。`maxAnalyzedContentLength`（既定1000、システムプロパティ `fess.suggest.max.analyzed.content.length`）ごとにバッファ分割（`:75, 261-278`）。`tags`/`roles`/`languages` は各フィールド設定値から付与。
- **検索クエリログ（QUERY）** `parseQueryLog`（`:114-151`）: Lucene クエリ文字列を `SuggestUtil.parseQuery` でフィールド別に語抽出し `queryFreq=1`。
- **検索語（QUERY）** `parseSearchWords`（`:78-112`）/ `indexFromSearchWord`（`ContentIndexingOperations.java:395-435`）: 生検索語を正規化・読み変換し、除外フィルタに該当しない語のみ `queryFreq = score`（呼び出し元が渡す件数）で1 SuggestItem 化。
- **検索語のノイズ除外** `isExcludeSearchword`（`DefaultContentsParser.java:344-358`）: アナライザにかけてトークンが1つも出ない語は除外。

## 3.4 スコアリング規則

### 登録時のマージ（Get-then-update）[確認] `SuggestItemSerializer.toUpdatedSource`（`entity/SuggestItemSerializer.java:142-185`）

| フィールド | マージ規則 |
| --- | --- |
| `reading_i` / `fields` / `tags` / `roles` / `languages` / `kinds` | **集合和**（重複排除して追加） |
| `queryFreq` / `docFreq` | **加算**（既存値 + 新値） |
| `userBoost` / `@timestamp` | **最新で置換** |
| `score` | `(更新後queryFreq + 更新後docFreq) * userBoost` を再計算（`:182`） |

- → 同一語の出現頻度が登録のたびに累積し、由来（kinds）・フィールド・タグ・ロールは累積的に広がる **[確認]**。
- 同一バルク内の同 `_id` アイテムは書き込み前に `SuggestItemMerger.merge`（`entity/SuggestItemMerger.java:59-96`）でも統合される（二段マージ）。

### 検索時の function score [確認] `SuggestQueryBuilder.buildFunctionScoreQuery`（`request/suggest/SuggestQueryBuilder.java`）

- 単一語かつ非ひらがなクエリで `text` 前方一致した場合、`weightFactorFunction(prefixMatchWeight)`（既定2.0）で加点（`:145-147`、`SuggestRequest.java:109`）。
- `docFreq`: `fieldValueFactorFunction(DOC_FREQ).modifier(LOG2P)`（`:150-153`）。
- `queryFreq`: `fieldValueFactorFunction(QUERY_FREQ).modifier(LOG2P)`（`:154-157`）。
- `userBoost`: `fieldValueFactorFunction(USER_BOOST).missing(1f)`（`:158-159`）。
- → 頻度系は対数加点（飽和）、userBoost は乗算。`boostMode=REPLACE`, `scoreMode=MULTIPLY`。

### 人気語（popularWords）[確認] `PopularWordsRequest`（`request/popularwords/PopularWordsRequest.java`）

- `must(termQuery(KINDS, "query"))` を強制し、`reading_1` が存在しない（＝単一語）かつ `queryFreq >= queryFreqThreshold`（既定10）の語のみ対象（`:212-214`）。
- ランダム化 rescorer（`:242-246`）で同程度人気の語をシャッフル。→ 人気語は「よく検索された単一語」に限定される。

## 3.5 サジェスト結果として返る項目（表示項目）

### `SuggestItem` の構造（詳細レスポンスの中身）[確認] `entity/SuggestItem.java:71-95`

`text` / `readings`（読み, String[][]）/ `fields` / `tags` / `roles`（空なら `_guest_` 補完）/ `languages` / `kinds` / `queryFreq` / `docFreq` / `userBoost` / `timestamp` / `score`（導出, `(queryFreq+docFreq)*userBoost`）/ `id`。

### `suggest()` のレスポンス（`SuggestResponse`）[確認] `request/suggest/SuggestResponse.java`

- `index`, `tookMs`, `words: List<String>`（語句文字列リスト）, `num`（語数）, `total`（総ヒット数）, `items: List<SuggestItem>`（詳細）。
- **`suggestDetail=false`（既定）では `items` は空**で `words` のみ返る。`suggestDetail=true` で `items` に全属性が載る。
- → **UI に最低限表示されるのは `words`（サジェスト語句）**。読み・件数・kinds・tags 等は詳細取得時に `items` 経由で利用可能。

### `popularWords()` のレスポンス（`PopularWordsResponse`）[確認] `PopularWordsRequest.java:253-277`

- `words: List<String>`（人気語文字列）、`detail=true`（既定）なら `items`。

## 3.6 データソースの有効/無効の切り替え（ライブラリ視点）[確認]

| 切り替え対象 | 条件 / 設定 | 根拠 |
| --- | --- | --- |
| ドキュメント解析の最大長 | システムプロパティ `fess.suggest.max.analyzed.content.length`（既定1000） | `DefaultContentsParser.java:75` |
| 対象フィールド | `SuggestIndexer.setSupportedFields(...)` 等で指定したフィールドのみ収集 | `parseDocument`/`parseQueryLog` の `fields` 引数 |
| bad word による除外 | `settings.badword()` 登録語を含む item は登録時に除外。apply 時は既存も削除 | `IndexingOperations.java:78`, `WordManagementOperations.java:77-84` |
| elevate word の反映 | `apply=true` で即時 index、`false` で設定保存のみ | `WordManagementOperations.java:103-115` |
| 検索時の種別フィルタ | `addKind(...)` を呼んだ場合のみ kinds 絞り込み（既定は全種別） | `SuggestRequest.java:363-365` |
| popularWords の閾値 | `queryFreqThreshold`（既定10）以上・単一語・Kind=query のみ | `PopularWordsRequest.java:212-214` |

- **[確認] bad word / elevate word の apply タイミング**: いずれも「設定への永続化（常時）」と「インデックスへの即時反映（apply フラグ時のみ）」を分離。設定ストアが正本で、apply はインデックスへの即時反映フラグ。`restoreElevateWord` は再構築後の新インデックスへ全 elevate word を再投入する。
