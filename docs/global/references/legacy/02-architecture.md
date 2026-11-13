# 全体アーキテクチャ

本ファイルは fess-suggest 調査ドキュメントの一部であり、ライブラリの全体アーキテクチャ（コンポーネント関係・インデックス構造・登録フロー・検索フロー・公開 API）を扱う。インデックス・前提（バージョン情報・参照ソースの所在・凡例）は [README.md](./README.md) を参照のこと。関連: [概要](./01-overview.md) / [サジェスト表示内容](./03-suggest-contents.md) / [fess 本体からの利用方法](./04-fess-integration.md) / [発見した課題](./05-issues.md)。

凡例: **[確認]** = ソースコードで直接確認できた事実、**[推測]** = 実装から合理的に推測した内容。根拠は `file_path:line` 形式。

---

## コンポーネント関係図

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

## サジェスト用インデックスの構造

### 定義元リソース

| リソースファイル | 用途 | 参照箇所 |
| --- | --- | --- |
| `suggest_indices/suggest/mappings-default.json` | フィールドマッピング | `Suggester.java:468`（`getDefaultMappings`） |
| `suggest_indices/suggest.json` | インデックス設定（shards/replicas/refresh） | `Suggester.java:477`（`getDefaultIndexSettings`） |
| `suggest_indices/suggest_settings.json` ほか | 設定ストア・アナライザ定義 | `settings/` パッケージで利用 |

### フィールド一覧（`mappings-default.json:13-48`、定数は `constants/FieldNames.java`）[確認]

| フィールド | 型 | 意味 | 定数 |
| --- | --- | --- | --- |
| `text` | keyword | サジェスト表示語句（複数語は空白連結） | `TEXT`（`:54`） |
| `reading_*` | keyword(動的) | 読み（`reading_0`, `reading_1`...）。クエリ照合用 | `READING_PREFIX`（`:56`） |
| `docFreq` | long | ドキュメント由来の出現頻度 | `DOC_FREQ`（`:62`） |
| `queryFreq` | long | 検索クエリ由来の出現頻度 | `QUERY_FREQ`（`:60`） |
| `userBoost` | double | 手動ブースト値 | `USER_BOOST`（`:64`） |
| `score` | double | 事前計算スコア | `SCORE`（`:58`） |
| `kinds` | keyword | 種別（`document`/`query`/`user`） | `KINDS`（`:66`） |
| `fields` | keyword | 元フィールド名（title, content 等） | `FIELDS`（`:74`） |
| `tags` | keyword | タグ（絞り込み用） | `TAGS`（`:70`） |
| `roles` | keyword | ロール（権限フィルタ用） | `ROLES`（`:72`） |
| `languages` | keyword | 言語 | `LANGUAGES`（`:76`） |
| `@timestamp` | date(epoch_millis) | 登録/更新時刻 | `TIMESTAMP`（`:68`） |

- **[確認]** `reading_*` は静的定義されず、`dynamic_templates`（全 string を keyword にマップ）で動的生成される（`mappings-default.json:2-12`）。読みは語位置ごとに `reading_0`, `reading_1`... と分割格納される（`SuggestItem.java:351-353`、クエリ側 `request/suggest/SuggestQueryBuilder.java:86`）。
- **[確認]** インデックス設定は `refresh_interval=10s`, `number_of_shards=1`, `number_of_replicas=0`, `auto_expand_replicas=0-1`（`suggest.json:1-8`）。→ **[推測]** 単一シャード前提の小規模専用インデックス設計。

### 決定的 ID による頻度集約 [確認]

サジェスト語の `_id` は `text` から決定的に生成される（`SuggestItem.java:140` → `SuggestUtil.createSuggestTextId`）。これにより、同一の語句は常に同一ドキュメントに集約され、登録のたびに出現頻度（`docFreq`/`queryFreq`）を加算更新できる（書き込み詳細は下記「検索（サジェスト取得）フロー」直前の登録フロー、マージ規則は [03-suggest-contents.md](./03-suggest-contents.md) の 3.4）。

### 二重エイリアスによるゼロダウンタイム再構築 [確認]

```
物理インデックス名: {baseIndex}.{yyyyMMddHHmmssSSS}   (createIndexName  Suggester.java:463-465)
検索エイリアス     : {baseIndex}                          (getSearchAlias  Suggester.java:455)
更新エイリアス     : {baseIndex}.update                   (getUpdateAlias  Suggester.java:459)
```

- 検索（`suggest()`/`popularWords()`）は **検索エイリアス** を参照（`Suggester.java:160, 168`）。
- 登録（`indexer()`）は **更新エイリアス** を参照（`Suggester.java:408`）。
- ライフサイクル: `createNextIndex()`（新インデックス作成＋更新エイリアス付替, `Suggester.java:235-277`）→ 全件再投入 → `switchIndex()`（検索エイリアスを新インデックスへ切替, `:282-334`）→ `removeDisableIndices()`（エイリアス無しの旧インデックス削除, `:339-360`）。
- → 再構築中も旧インデックスで検索を継続でき、切替が原子的になる **[確認]**。

## 登録（インデキシング）フロー

### エントリポイントと委譲構造 [確認]

`Suggester.indexer()`（`Suggester.java:366`）が `SuggestIndexer` を生成する。`SuggestIndexer` はファサードで、4つの内部オペレーションクラスに委譲する（`SuggestIndexer.java:203-210`）。

| 内部クラス | 責務 | ファイル |
| --- | --- | --- |
| `IndexingOperations` | `SuggestItem` の実書き込み・bad word フィルタ | `index/operations/IndexingOperations.java` |
| `DeletionOperations` | ID/クエリ/種別による削除 | `index/operations/DeletionOperations.java` |
| `WordManagementOperations` | bad word / elevate word 管理 | `index/operations/WordManagementOperations.java` |
| `ContentIndexingOperations` | クエリログ・ドキュメント・検索語からの登録 | `index/operations/ContentIndexingOperations.java` |

### データソース別の SuggestItem 生成（`DefaultContentsParser`）[確認]

`DefaultContentsParser`（`index/contents/DefaultContentsParser.java`）が各データソースを `SuggestItem` に変換する。共通のテキスト処理パイプラインは **正規化（Normalizer/NormalizerChain）→ 読み変換（ReadingConverter/ReadingConverterChain）→ 解析（SuggestAnalyzer）**。ドキュメント側とクエリ/メタ側で別々の `ReadingConverter`（`readingConverter` と `contentsReadingConverter`、`Suggester.java:113-115`）を使う。

### 書き込み（IndexingOperations → SuggestWriter）[確認]

- `IndexingOperations.index`（`IndexingOperations.java:77-92`）で bad word をフィルタ（`SuggestItem.isBadWord`, `:78`）し、`SuggestWriter.write`（既定実装 `index/writer/SuggestIndexWriter.java`）へ委譲。
- `SuggestIndexWriter.write`（`:44-80`）:
  1. `mergeItems(items)` で同一 ID のアイテムをアプリ側マージ（`:49`）。
  2. 各アイテムについて既存ドキュメントを Get（`:55`）。
  3. 既存あり & update → `item.getUpdatedSource(existingSource)` で **頻度を加算した** source を作成し INDEX（`:56-61`）。なければ新規 source（`:62-65`）。
  4. `BulkRequestBuilder` でまとめて実行（`:69`）。
- → 決定的 `_id` + Get-then-merge により、同一語の `docFreq`/`queryFreq` が登録のたびに累積する **[確認]**（マージ規則は [03-suggest-contents.md](./03-suggest-contents.md) の 3.4）。

### 同期 / 非同期の境界 [確認]

- **同期**: `index(SuggestItem)`, `index(SuggestItem[])`, `indexFromQueryLog(QueryLog[])`, `indexFromDocument(Map[])`, `indexFromSearchWord(...)` は呼び出しスレッドで実行し `SuggestIndexResponse` を即時返却。
- **非同期（バッチ）**: Reader を引数に取る2メソッドのみ `threadPool.execute(...)` で別スレッド実行し `Deferred.Promise` を返す。
  - `indexFromQueryLog(QueryLogReader, docPerReq, requestInterval)`（`ContentIndexingOperations.java:185-222`）
  - `indexFromDocument(Supplier<DocumentReader>, docPerReq, waitController)`（`ContentIndexingOperations.java:317-359`）
  - これらは `docPerReq` 件ずつ読み出し → バルク投入 → 間隔調整、をループする。ドキュメント版はバッチごとに `refresh` を実行（`:345`）。`parallel` 設定が有効なら各バッチ内の parse は `Stream.parallel()` 化される（`:138-140, 255-257`）。

```
[同期 index 系]   呼び出しスレッド ──▶ ContentsParser.parse ──▶ IndexingOperations.index ──▶ SuggestIndexWriter.bulk ──▶ OpenSearch
[非同期 reader 系] 呼び出しスレッド ──▶ Deferred.promise() を即返却
                  threadPool スレッド ─▶ Reader.read ループ ─▶ (上記同期パイプラインをバッチごとに) ─▶ resolve(SuggestIndexResponse)
```

## 検索（サジェスト取得）フロー

### エントリポイントとクエリ構築 [確認]

`Suggester.suggest()`（`Suggester.java:159-161`）が `SuggestRequestBuilder` を返し、`setIndex(getSearchAlias(index))` で **検索エイリアス** を対象にする。実行は `SuggestRequest.processRequest`（`request/suggest/SuggestRequest.java:328-391`）:

1. `SuggestQueryBuilder.buildQuery`（`request/suggest/SuggestQueryBuilder.java:71-121`）:
   - クエリを空白分割し、各語を **正規化 → 読み変換**。
   - 語ごとに `reading_{i}` フィールドへ bool(should, minimumShouldMatch=1) を構築。
   - **最後の語かつ末尾が空白でない**場合のみ `prefixQuery`（前方一致＝オートコンプリート）、それ以外は `termQuery`（完全一致）（`:105-109`）。
2. `buildFunctionScoreQuery`（`:141-167`）でスコアリング（[03-suggest-contents.md](./03-suggest-contents.md) の 3.4 参照）。
3. フィルタ: `tags`/`roles`/`fields`/`kinds` を term フィルタ化（`SuggestRequest.java:346-374`）。**roles には常に `_guest_`（`SuggestConstants.DEFAULT_ROLE`）が補完される**（`:354-356`）。
4. `_score` 降順ソート（`:343`）。`skipDuplicateWords` 有効時は `size*2` を取得して後で間引く（`:332-334`）。

### 実行とレスポンス生成 [確認]

- `builder.execute(ActionListener)` で OpenSearch を非同期検索（`SuggestRequest.java:376-390`）。失敗シャードがあれば `deferred.reject`、成功なら `createResponse` 後 `deferred.resolve`。→ **検索は常に非同期**。
- `SuggestResponseCreator.createResponse`（`request/suggest/SuggestResponseCreator.java:71-123`）:
  - ヒットを走査し `text` を収集。`skipDuplicateWords` 有効時は空白除去後の語で重複排除（`:94-100`）。
  - `matchWordFirst` 有効かつ単一語・非ひらがなクエリでは、クエリを含む語を先頭グループへ寄せる（`:132-140`）。
  - `suggestDetail=true` なら各ヒットを `SuggestItem.parseSource` で復元し詳細を返す（`:110-117`）。
  - 返却: `SuggestResponse(index, took, words, totalHits, items)`。

```
suggest() ─▶ SuggestRequestBuilder ─▶ SuggestRequest.processRequest
   ├─ SuggestQueryBuilder.buildQuery (正規化→読み変換→reading_n bool / prefix or term)
   ├─ buildFunctionScoreQuery (docFreq/queryFreq/userBoost/prefix加点)
   ├─ filter: tags/roles(+_guest_)/fields/kinds
   └─ client.prepareSearch(searchAlias).execute(ActionListener)
            └─▶ SuggestResponseCreator.createResponse ─▶ Deferred.resolve(SuggestResponse)
```

## 主要な公開 API

### `Suggester`（ファサード / 主エントリポイント）`Suggester.java`

| API | 役割 | 行 |
| --- | --- | --- |
| `static builder()` | `SuggesterBuilder` 生成（構築起点） | `:374` |
| `suggest()` | サジェスト検索リクエストビルダ生成（検索エイリアス対象） | `:159` |
| `popularWords()` | 人気語リクエストビルダ生成 | `:167` |
| `indexer()` | 登録用 `SuggestIndexer` 生成（更新エイリアス対象） | `:366` |
| `createIndexIfNothing()` | 初期インデックス＋両エイリアス作成 | `:196` |
| `createNextIndex()` / `switchIndex()` / `removeDisableIndices()` | 再構築ライフサイクル | `:235 / :282 / :339` |
| `refresh()` / `shutdown()` | リフレッシュ / スレッドプール停止 | `:175 / :185` |
| `getAllWordsNum()` / `getDocumentWordsNum()` / `getQueryWordsNum()` | 語数カウント | `:424 / :432 / :440` |

### `SuggestIndexer`（登録エンジン）`SuggestIndexer.java`

| API | 役割 | 行 |
| --- | --- | --- |
| `index(SuggestItem)` / `index(SuggestItem[])` | 単体/複数登録 | `:243 / :253` |
| `indexFromQueryLog(...)` | クエリログから登録（同期/非同期バッチ） | `:322 / :332 / :344` |
| `indexFromDocument(...)` | ドキュメントから登録（同期/非同期バッチ） | `:355 / :367` |
| `indexFromSearchWord(...)` | 検索語1件から登録 | `:383` |
| `delete*` 各種 | ID/クエリ/種別/古語削除 | `:263-450` |
| `addBadWord/deleteBadWord` | NG ワード管理 | `:395 / :406` |
| `addElevateWord/deleteElevateWord/restoreElevateWord` | 優先表示語管理 | `:417-440` |

### 検索系リクエストビルダ

- `SuggestRequestBuilder`（`request/suggest/`）: `setQuery/setSize/addField/addTag/addRole/addKind/addLang/setSuggestDetail/setPrefixMatchWeight/setMatchWordFirst/setSkipDuplicateWords` 等を設定し `execute()` で `Deferred<SuggestResponse>.Promise` を返す。
- `PopularWordsRequestBuilder`（`request/popularwords/`）: 人気語（高頻度語）取得。
