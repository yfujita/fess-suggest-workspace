# ステップ2: fess-suggest 全体アーキテクチャ分析

本ドキュメントは作業プラン `0001-work-plan.md` のステップ2の成果物である。
`modules/fess-suggest` の実コードを調査し、サジェスト機能の全体アーキテクチャ（インデックス構造・登録フロー・検索フロー・公開API・コンポーネント関係）を明らかにする。

調査対象パス（全て `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下、リソースは `modules/fess-suggest/src/main/resources/`）。
記述中の根拠は `file_path:line` 形式で示す。**[確認]** はコードで確認できた事実、**[推測]** は実装から合理的に推測した内容を表す。

---

## 0. 技術スタックの前提

- **[確認]** 検索エンジンは **OpenSearch**。主要クラスが `org.opensearch.transport.client.Client` を直接利用する（例: `Suggester.java:53`, `SuggestIndexer.java:46`）。
- **[確認]** Java 21+ / Maven（モジュール `CLAUDE.md` に記載、`Suggester.java` のパターンマッチ instanceof / record 構文使用 `ContentIndexingOperations.java:443`）。
- **[確認]** 非同期処理は独自の `Deferred`/`Promise` 実装（`concurrent/Deferred.java`）。OpenSearch の `ActionListener` を `Deferred` にブリッジしている（`SuggestRequest.java:376`）。

---

## 1. サジェスト用インデックスの構造

### 1.1 定義元リソース

| リソースファイル | 用途 | 参照箇所 |
| --- | --- | --- |
| `suggest_indices/suggest/mappings-default.json` | フィールドマッピング | `Suggester.java:468` (`getDefaultMappings`) |
| `suggest_indices/suggest.json` | インデックス設定（shards/replicas/refresh） | `Suggester.java:477` (`getDefaultIndexSettings`) |
| `suggest_indices/suggest_settings.json` ほか | 設定ストア・アナライザ定義 | `settings/` パッケージで利用 |

### 1.2 フィールドマッピング（`mappings-default.json`）

**[確認]** `mappings-default.json:13-48` で定義されるフィールド。フィールド名定数は `constants/FieldNames.java`。

| フィールド | 型 | 意味 | 定数 (`FieldNames.java`) |
| --- | --- | --- | --- |
| `text` | keyword | サジェスト表示語句（複数語は空白連結） | `TEXT` (`:54`) |
| `reading_*` | keyword(動的) | 読み（`reading_0`, `reading_1`...）クエリ照合用 | `READING_PREFIX` (`:56`) |
| `docFreq` | long | ドキュメント由来の出現頻度 | `DOC_FREQ` (`:62`) |
| `queryFreq` | long | 検索クエリ由来の出現頻度 | `QUERY_FREQ` (`:60`) |
| `userBoost` | double | 手動ブースト値 | `USER_BOOST` (`:64`) |
| `score` | double | スコア | `SCORE` (`:58`) |
| `kinds` | keyword | 種別 (`document`/`query`/`user`) | `KINDS` (`:66`) |
| `fields` | keyword | 元フィールド名（title, content 等） | `FIELDS` (`:74`) |
| `tags` | keyword | タグ（絞り込み用） | `TAGS` (`:70`) |
| `roles` | keyword | ロール（権限フィルタ用） | `ROLES` (`:72`) |
| `languages` | keyword | 言語 | `LANGUAGES` (`:76`) |
| `@timestamp` | date(epoch_millis) | 登録/更新時刻 | `TIMESTAMP` (`:68`) |

- **[確認]** `reading_*` フィールドは mapping に静的定義されず、`dynamic_templates` の `strings`（全 string を keyword にマップ）で動的に作られる（`mappings-default.json:2-12`）。読みは語の位置ごとに `reading_0`, `reading_1`... と分割される（`SuggestItem.createEmptyMap` `SuggestItem.java:351-353`、クエリ側 `SuggestQueryBuilder.java:86`）。
- **[確認]** ドキュメント `_id` は本文 `text` から決定的に生成（`SuggestItem.java:140` → `SuggestUtil.createSuggestTextId`）。これにより同一語は同一ドキュメントに集約され、頻度の加算更新が可能になる（後述 1.4）。

### 1.3 インデックス設定（`suggest.json`）

**[確認]** `suggest.json:1-8`: `refresh_interval=10s`, `number_of_shards=1`, `number_of_replicas=0`, `auto_expand_replicas=0-1`。
→ **[推測]** 単一シャード前提の比較的小規模な専用インデックス設計。リフレッシュ10秒は近リアルタイム更新を許容しつつ書き込み負荷を抑える狙い。

### 1.4 エイリアスによるゼロダウンタイム更新戦略

**[確認]** `Suggester.java` はインデックス名とエイリアスを分離する。

```
物理インデックス名: {baseIndex}.{yyyyMMddHHmmssSSS}   (createIndexName  Suggester.java:463-465)
検索エイリアス     : {baseIndex}                          (getSearchAlias  Suggester.java:455)
更新エイリアス     : {baseIndex}.update                   (getUpdateAlias  Suggester.java:459)
```

- **[確認]** 検索 (`suggest()`/`popularWords()`) は **検索エイリアス** を参照（`Suggester.java:160, 168`）。
- **[確認]** 登録 (`indexer()`) は **更新エイリアス** を参照（`Suggester.java:408`）。
- **[確認]** ライフサイクル: `createNextIndex()` で新インデックスを作り更新エイリアスを付け替え（`Suggester.java:235-277`）→ 全件再投入 → `switchIndex()` で検索エイリアスを更新インデックスへ切替（`Suggester.java:282-334`）→ `removeDisableIndices()` でエイリアス無し旧インデックスを削除（`Suggester.java:339-360`）。
→ これにより、再構築中も旧インデックスで検索を継続でき、切替が原子的になる。**[確認]**

---

## 2. 登録（インデキシング）フロー

### 2.1 エントリポイントと委譲構造

**[確認]** `Suggester.indexer()`（`Suggester.java:366`）が `SuggestIndexer` を生成。`SuggestIndexer` はファサードで、4つの内部オペレーションクラスに委譲する（`SuggestIndexer.java:203-210`）。

| 内部クラス | 責務 | ファイル |
| --- | --- | --- |
| `IndexingOperations` | SuggestItem の実書き込み・bad word フィルタ | `index/operations/IndexingOperations.java` |
| `DeletionOperations` | ID/クエリ/種別による削除 | `index/operations/DeletionOperations.java` |
| `WordManagementOperations` | bad word / elevate word 管理 | `index/operations/WordManagementOperations.java` |
| `ContentIndexingOperations` | クエリログ・ドキュメント・検索語からの登録 | `index/operations/ContentIndexingOperations.java` |

### 2.2 データソース別の SuggestItem 生成（ContentsParser）

**[確認]** `DefaultContentsParser`（`index/contents/DefaultContentsParser.java`）が3つのデータソースを `SuggestItem` に変換する。

1. **検索語 (search word)** → `parseSearchWords` (`DefaultContentsParser.java:78-112`)。Kind=`QUERY`、`queryFreq=score`。正規化 → 読み変換を実施。
2. **クエリログ (query log)** → `parseQueryLog` (`:114-151`)。Lucene クエリ文字列をフィールド別にパース（`SuggestUtil.parseQuery`）し Kind=`QUERY`、`queryFreq=1` の SuggestItem を生成。tag/role はクエリ文字列から抽出。
3. **ドキュメント (document)** → `parseDocument` (`:153-211`)。`SuggestAnalyzer` で本文をトークン分割し、各トークンを Kind=`DOCUMENT`、`docFreq=1` の SuggestItem 化。読みは reading トークン or `contentsReadingConverter` から付与。

→ **テキスト処理パイプライン [確認]**: 正規化 (`Normalizer` / `NormalizerChain`) → 読み変換 (`ReadingConverter` / `ReadingConverterChain`、カタカナ/ローマ字) → 解析 (`SuggestAnalyzer`)。ドキュメント側とクエリ/メタ側で別々の `ReadingConverter` を使う（`readingConverter` と `contentsReadingConverter`、`Suggester.java:113-115`、利用 `DefaultContentsParser.java:189-192`）。

### 2.3 書き込み（IndexingOperations → SuggestWriter）

**[確認]** フロー: `IndexingOperations.index` (`IndexingOperations.java:77-92`)
- bad word を `SuggestItem.isBadWord` でフィルタ（`:78`）。
- `SuggestWriter.write` に委譲。デフォルト実装 `SuggestIndexWriter`（`index/writer/SuggestIndexWriter.java`）。

**[確認]** `SuggestIndexWriter.write` (`SuggestIndexWriter.java:44-80`):
1. `mergeItems(items)` で同一 ID のアイテムをアプリ側マージ（`:49`）。
2. 各アイテムについて `GetResponse` で既存ドキュメントを確認（`:55`）。
3. 既存あり & update → `item.getUpdatedSource(existingSource)` で **頻度を加算した** source を作成し INDEX（`:56-61`）。なければ新規 source で INDEX（`:62-65`）。
4. `BulkRequestBuilder` でまとめて実行（`:69`、タイムアウト `settings.getBulkTimeout()`）。

→ **[確認]** `getUpdatedSource` は `SuggestItemSerializer.toUpdatedSource` に委譲（`SuggestItem.java:398-399`）。決定的 `_id` + Get-then-merge により、同一語の `docFreq`/`queryFreq` が登録のたびに累積する。

### 2.4 同期 / 非同期の境界

- **[確認] 同期**: `index(SuggestItem)`, `index(SuggestItem[])`, `indexFromQueryLog(QueryLog[])`, `indexFromDocument(Map[])`, `indexFromSearchWord(...)` は呼び出しスレッドで実行し `SuggestIndexResponse` を即時返却。
- **[確認] 非同期（バッチ）**: Reader を引数に取る2メソッドのみ `threadPool.execute(...)` で別スレッド実行し `Deferred.Promise` を返す。
  - `indexFromQueryLog(QueryLogReader, docPerReq, requestInterval)` (`ContentIndexingOperations.java:185-222`)
  - `indexFromDocument(Supplier<DocumentReader>, docPerReq, waitController)` (`ContentIndexingOperations.java:317-359`)
  - これらは `docPerReq` 件ずつ読み出し→バルク投入→`Thread.sleep`/`waitController` で間隔調整、をループ。ドキュメント版はバッチごとに `refresh` を実行（`:345`）。
  - **[確認]** `parallel` 設定が有効なら、各バッチ内の parse は `Stream.parallel()` 化される（`:138-140, 255-257`）。書き込み自体はバルク1回。

```
[同期 index 系]   呼び出しスレッド ──▶ ContentsParser.parse ──▶ IndexingOperations.index ──▶ SuggestIndexWriter.bulk ──▶ OpenSearch
[非同期 reader 系] 呼び出しスレッド ──▶ Deferred.promise() を即返却
                  threadPool スレッド ─▶ Reader.read ループ ─▶ (上記同期パイプラインをバッチごとに) ─▶ resolve(SuggestIndexResponse)
```

---

## 3. 検索（サジェスト取得）フロー

### 3.1 エントリポイント

**[確認]** `Suggester.suggest()`（`Suggester.java:159-161`）が `SuggestRequestBuilder` を返し、`setIndex(getSearchAlias(index))` で **検索エイリアス** を対象にする。
ビルダ経由で `SuggestRequest` を構成し `.execute()` で実行（`Request` 基底 → `SuggestRequest.processRequest`）。

### 3.2 クエリ構築（SuggestQueryBuilder）

**[確認]** `SuggestRequest.processRequest`（`SuggestRequest.java:328-391`）の流れ:
1. `buildQuery(query, fields)` → `SuggestQueryBuilder.buildQuery`（`SuggestQueryBuilder.java:71-121`）。
   - クエリを空白分割し、各語を **正規化 → 読み変換**。
   - 語ごとに `reading_{i}` フィールドへ bool(should, minimumShouldMatch=1) を構築。
   - **最後の語かつ末尾が空白でない**場合のみ `prefixQuery`（前方一致 = オートコンプリート）、それ以外は `termQuery`（完全一致）（`:105-109`）。
2. `buildFunctionScoreQuery`（`SuggestQueryBuilder.java:141-167`）でスコアリング:
   - 単一語かつ非ひらがなクエリなら `text` への prefix 一致に `prefixMatchWeight`（既定 2.0）を加点（`:145-148`、`SuggestRequest.java:109`）。
   - `docFreq`, `queryFreq` を `LOG2P` modifier の field value factor で加点、`userBoost` を乗算（`:150-159`）。
   - `boostMode=REPLACE`, `scoreMode=MULTIPLY`（`:163-164`）。
3. フィルタクエリ: `tags`/`roles`/`fields`/`kinds` を term フィルタ化（`SuggestRequest.java:346-374`）。
   - **[確認]** roles には常に `_guest_`（`SuggestConstants.DEFAULT_ROLE`）が補完される（`SuggestRequest.java:354-356`）。権限のないユーザーにも公開語を返すための仕組み。
4. `_score` 降順ソート（`SuggestRequest.java:343`）。重複除去 (`skipDuplicateWords`) が有効なら `size*2` を取得して後で間引く（`:332-334`）。

### 3.3 実行とレスポンス生成

**[確認]** `builder.execute(ActionListener)` で OpenSearch を非同期検索（`SuggestRequest.java:376-390`）。
- 失敗シャードがあれば `deferred.reject`、成功なら `createResponse` 後 `deferred.resolve`。
→ 呼び出し側は `.done(...)/.error(...)` で受け取る（`Deferred`）。**検索は常に非同期**。

**[確認]** `SuggestResponseCreator.createResponse`（`SuggestResponseCreator.java:71-123`）:
- ヒットを走査し `text` を収集。`skipDuplicateWords` 有効時は空白除去後の語で重複排除（`:94-100`）。
- `matchWordFirst` 有効かつ単一語・非ひらがなクエリでは、クエリを含む語を「先頭グループ」に寄せて並べ替え（`isFirstWordMatching` `:132-140`）。
- `suggestDetail=true` なら各ヒットを `SuggestItem.parseSource` で復元し詳細を返す（`:110-117`）。
- 返却: `SuggestResponse(index, took, words, totalHits, items)`（`:121-122`）。

```
suggest() ─▶ SuggestRequestBuilder ─▶ SuggestRequest.processRequest
   ├─ SuggestQueryBuilder.buildQuery (正規化→読み変換→reading_n bool/ prefix or term)
   ├─ buildFunctionScoreQuery (docFreq/queryFreq/userBoost/prefix加点)
   ├─ filter: tags/roles(+_guest_)/fields/kinds
   └─ client.prepareSearch(searchAlias).execute(ActionListener)
            └─▶ SuggestResponseCreator.createResponse ─▶ Deferred.resolve(SuggestResponse)
```

---

## 4. 主要な公開 API 一覧

### 4.1 Suggester（ファサード / 主エントリポイント）`Suggester.java`

| API | 役割 | 行 |
| --- | --- | --- |
| `static builder()` | `SuggesterBuilder` 生成（構築起点） | `:374` |
| `suggest()` | サジェスト検索リクエストビルダ生成（検索エイリアス対象） | `:159` |
| `popularWords()` | 人気語リクエストビルダ生成 | `:167` |
| `indexer()` | 登録用 `SuggestIndexer` 生成（更新エイリアス対象） | `:366` |
| `createIndexIfNothing()` | 初期インデックス＋両エイリアス作成 | `:196` |
| `createNextIndex()` | 新インデックス作成し更新エイリアス付替 | `:235` |
| `switchIndex()` | 検索エイリアスを更新インデックスへ切替 | `:282` |
| `removeDisableIndices()` | エイリアス無し旧インデックス削除 | `:339` |
| `refresh()` | インデックスリフレッシュ | `:175` |
| `shutdown()` | スレッドプール停止 | `:185` |
| `getAllWordsNum()/getDocumentWordsNum()/getQueryWordsNum()` | 語数カウント | `:424/:432/:440` |
| `settings()/getReadingConverter()/getNormalizer()/getIndex()` | 各種ゲッタ | `:383-417` |

### 4.2 SuggestIndexer（登録エンジン）`SuggestIndexer.java`

| API | 役割 | 行 |
| --- | --- | --- |
| `index(SuggestItem)/index(SuggestItem[])` | 単体/複数登録 | `:243/:253` |
| `indexFromQueryLog(QueryLog / QueryLog[])` | クエリログから登録（同期） | `:322/:332` |
| `indexFromQueryLog(QueryLogReader, docPerReq, interval)` | クエリログから**非同期バッチ**登録 | `:344` |
| `indexFromDocument(Map[])` | ドキュメントから登録（同期） | `:355` |
| `indexFromDocument(Supplier<DocumentReader>, docPerReq, waitController)` | ドキュメントから**非同期バッチ**登録 | `:367` |
| `indexFromSearchWord(...)` | 検索語1件から登録 | `:383` |
| `delete/deleteByQuery/deleteAll/deleteDocumentWords/deleteQueryWords/deleteOldWords` | 各種削除 | `:263-450` |
| `addBadWord/deleteBadWord` | NGワード管理 | `:395/:406` |
| `addElevateWord/deleteElevateWord/restoreElevateWord` | 優先表示語管理 | `:417-440` |
| `setIndexName/setSupportedFields/setTagFieldNames/setRoleFieldName/...` | 設定変更（フルーエント） | `:457-545` |

### 4.3 検索系リクエストビルダ

- `SuggestRequestBuilder`（`request/suggest/`）: `setQuery/setSize/addField/addTag/addRole/addKind/addLang/setSuggestDetail/setPrefixMatchWeight/setMatchWordFirst/setSkipDuplicateWords` 等を設定し `execute()` で `Deferred<SuggestResponse>.Promise` を返す。
- `PopularWordsRequestBuilder`（`request/popularwords/`）: 人気語（高頻度語）取得。`PopularWordsRequest` がフィルタ＋function score＋rescorer で構築（`PopularWordsRequest.java:30-38`）。

---

## 5. コンポーネント関係図

```
                         ┌────────────────────────────────────────────┐
                         │              Suggester (Facade)             │
                         │  - 検索/更新エイリアス管理                   │
                         │  - index ライフサイクル (create/switch/...)  │
                         └───────┬───────────────┬──────────────┬──────┘
              suggest()/         │    indexer()  │              │ settings()
              popularWords()     │               │              ▼
                    │            │               │        SuggestSettings
                    ▼            │               │        (OpenSearch 上に保存:
        ┌───────────────────┐    │               │         analyzer/badword/
        │ SuggestRequest    │    │               │         elevateword/timeout)
        │ Builder /         │    │               ▼
        │ PopularWordsReq.. │    │        ┌──────────────────────────┐
        └─────────┬─────────┘    │        │      SuggestIndexer       │ (Facade)
                  ▼              │        └──┬────────┬────────┬──────┘
        ┌───────────────────┐    │           │        │        │
        │ SuggestQueryBuilder│    │  Indexing │ Deletion│ WordMgmt│ ContentIndexing
        │ (正規化/読み変換/   │    │   Ops     │   Ops   │   Ops   │      Ops
        │  prefix/term/score)│    │           │        │        │  └─ ContentsParser
        └─────────┬─────────┘    │           ▼        ▼        ▼     (Document/QueryLog/
                  ▼              │     SuggestWriter (SuggestIndexWriter)  SearchWord
        ┌───────────────────┐    │           │  merge + Get-then-update    →SuggestItem)
        │SuggestResponse     │    │           ▼                              │
        │Creator (重複除去/   │    │     ┌───────────────────────────────────┘
        │ 先頭一致優先)       │    │     ▼
        └─────────┬─────────┘    │  ┌──────────────────────────────┐
                  ▼              └─▶│   OpenSearch  ({base}.{ts})    │◀── 検索/更新エイリアス
            SuggestResponse        │   docs keyed by text-derived _id│
            (Deferred.resolve)     └──────────────────────────────┘

  共通テキスト処理: Normalizer(Chain) ─▶ ReadingConverter(Chain) ─▶ SuggestAnalyzer
  非同期基盤      : Deferred / Promise（検索は常に非同期、登録はReader系のみ非同期）
```

---

## 6. 要点まとめ（ステップ2 完了条件への対応）

- **インデックス構造**: 専用 OpenSearch インデックス。`text`/`reading_*`/`docFreq`/`queryFreq`/`userBoost`/`kinds`/`fields`/`tags`/`roles`/`languages`/`@timestamp`。定義元は `mappings-default.json`（マッピング）と `suggest.json`（設定）。`_id` は `text` から決定的生成 → 同一語の頻度を加算集約。検索/更新の二重エイリアスでゼロダウンタイム再構築。
- **登録フロー**: `Suggester.indexer()` → `SuggestIndexer`（ファサード）→ `ContentIndexingOperations`（データソース別 parse）→ `DefaultContentsParser`（正規化/読み変換/解析で SuggestItem 化）→ `IndexingOperations`（badword フィルタ）→ `SuggestIndexWriter`（merge + Get-then-update のバルク書き込み）。Reader 系のみ threadPool で非同期バッチ。
- **検索フロー**: `Suggester.suggest()` → `SuggestRequest`（検索エイリアス対象）→ `SuggestQueryBuilder`（reading_n への prefix/term + docFreq/queryFreq/userBoost の function score）→ role(`_guest_`補完)/tag/field/kind フィルタ → OpenSearch 非同期検索 → `SuggestResponseCreator`（重複除去・先頭一致優先）→ `Deferred.resolve(SuggestResponse)`。検索は常に非同期。
- **公開 API**: `Suggester`（ライフサイクル + suggest/popularWords/indexer）、`SuggestIndexer`（index*/delete*/badword/elevateword）、`SuggestRequestBuilder` / `PopularWordsRequestBuilder`（検索系）。

## 7. 残課題・未確定事項（次ステップへの申し送り）

- **[推測]** サジェスト表示種別（document/query/user）の詳細な振る舞いとスコアリングの実利用上の効き方はステップ3で深掘りが必要。
- elevate word / bad word の適用タイミング（`apply` フラグ）の詳細は `WordManagementOperations` 未読。ステップ3で確認推奨。
- `SuggestItemSerializer.toUpdatedSource` のマージ詳細（kinds/languages/fields の集合和、頻度加算の正確な規則）は本ステップで全行確認していない。データ集約の正確性が問われる場合は要確認。
- fess 本体からの呼び出し経路・設定はステップ4の範囲。
