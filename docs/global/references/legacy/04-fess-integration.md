# fess 本体からの利用方法

本ファイルは fess-suggest 調査ドキュメントの一部であり、fess 本体が fess-suggest をどう組み込み・駆動するか（呼び出し経路・設定項目・4経路の駆動元・パージ・UI/API・スケジューリング・管理画面）を扱う。インデックス・前提（バージョン情報・参照ソースの所在・凡例）は [README.md](./README.md) を参照のこと。関連: [概要](./01-overview.md) / [全体アーキテクチャ](./02-architecture.md) / [サジェスト表示内容](./03-suggest-contents.md) / [発見した課題](./05-issues.md)。

凡例: **[確認]** = ソースコードで直接確認できた事実、**[推測]** = 実装から合理的に推測した内容。根拠は `file_path:line` 形式。

---

## 4.1 呼び出し経路（コンポーネント全体像）[確認]

fess 本体は fess-suggest をライブラリとして組み込み、呼び出しは原則 **`SuggestHelper`（Lasta Di ヘルパ）に集約**される。Web フレームワークは LastaFlute、DI は Lasta Di、データアクセスは DBFlute（`modules/fess/CLAUDE.md`）。

| fess 本体クラス | 役割 | fess-suggest 利用点 |
| --- | --- | --- |
| `helper/SuggestHelper.java` | **中核ブリッジ**。`Suggester` の生成・初期化・全 indexer 操作を集約 | `Suggester.builder()`, `indexer().indexFrom*`, `addElevateWord` 等 |
| `exec/SuggestCreator.java` | バッチ本体（**別 JVM プロセス**）。索引再構築のオーケストレーション | `createNextIndex()/switchIndex()/removeDisableIndices()` |
| `job/SuggestJob.java` | スケジューラから `SuggestCreator` を別プロセス起動 | `SuggestCreator` をコマンド実行 |
| `helper/PopularWordHelper.java` | 人気語取得＋キャッシュ | `suggester().popularWords()` |
| `helper/SearchLogHelper.java` | 検索ログ保存時にリアルタイムでサジェスト索引へ反映 | `suggestHelper.indexFromSearchLog(...)` |
| `api/v2/handlers/SuggestWordsHandler.java` | サジェスト検索 REST API（`/api/v2/suggest-words`） | `suggester().suggest()` |
| `app/web/admin/suggest/AdminSuggestAction.java` | 管理画面（語数表示・削除） | `getAllWordsNum()/delete*Words()` |
| `app/web/admin/elevateword/AdminElevatewordAction.java` | 優先表示語の登録/削除 | `addElevateWord/deleteElevateWord/storeAllElevateWords` |
| `app/web/admin/badword/AdminBadwordAction.java` | NG ワードの登録/削除 | `addBadWord/deleteBadWord/storeAllBadWords` |

```
                          ┌─────────────────────────────────────────────┐
   検索画面/外部クライアント │  fess 本体（LastaFlute / Lasta Di）           │
        │ GET /api/v2/      │                                             │
        │  suggest-words    ▼                                             │
        │            SuggestWordsHandler ─┐                               │
        │            PopularWordsHandler ─┤  suggest()/popularWords()      │
        │                                 ▼                               │
        ▼                          ┌───────────────┐    indexer()         │
   FessSearchAction ──────────────▶│ SuggestHelper │────────────┐         │
   (画面の人気語)  PopularWordHelper │  (Suggester)  │            ▼         │
                                    └───────┬───────┘     SuggestIndexer   │
   検索実行 ─▶ SearchLogHelper ─────────────┘  (realtime)    (fess-suggest)│
                 indexFromSearchLog                              │         │
                                                                 ▼         │
   スケジューラ(Lasta Job) ─▶ SuggestJob ─▶ 別JVM: SuggestCreator ─▶ Suggester
        "Suggest Indexer" (cron 0 12 * * *)   createNextIndex/index/switch │
                                                                           │
└──────────────────────────────────────────────────────────────────────┘
                                    ▼
                            OpenSearch（suggest 専用インデックス + fess 文書/検索ログ）
```

### `SuggestHelper` の初期化 [確認] `helper/SuggestHelper.java:114-159`（`@PostConstruct`）

- `fessConfig` から content / tag / role フィールド集合を読み込む（`:120-124`）。
- OpenSearch yellow 待機後、`Suggester.builder()...build(searchEngineClient, fessConfig.getIndexDocumentSuggestIndex())` で `Suggester` を1つ生成（`:142`）。インデックス名のベースは `index.document.suggest.index`（既定 `fess`）。
- `suggest.field.index.contents`（既定 `content,title`）を `SUPPORTED_FIELDS` に設定し（`:147-154`）、`createIndexIfNothing()` で初期インデックス＋エイリアスを作成（`:155`）。
- **[確認]** `SuggestHelper` はアプリ起動時に `Suggester` を1つ生成・保持するヘルパ。検索 API・人気語・リアルタイム検索ログ反映がこの同一 `Suggester` を共有する。バッチ再構築（`SuggestCreator`）のみ別 JVM プロセスで動き、自前の `Suggester` を別途生成する。

## 4.2 サジェスト関連の設定項目

### 静的設定（`fess_config.properties`）[確認] 主要項目

| プロパティ | 既定値 | 意味 |
| --- | --- | --- |
| `index.document.suggest.index` | `fess` | サジェスト用インデックスのベース名 |
| `suggest.field.contents` | `_default` | 本文収集対象フィールド |
| `suggest.field.tags` | `label` | tag として扱うフィールド名 |
| `suggest.field.roles` | `role` | role として扱うフィールド名 |
| `suggest.field.index.contents` | `content,title` | document/querylog の実索引対象フィールド（SUPPORTED_FIELDS） |
| `suggest.min.hit.count` | `1` | 検索ログを索引化する最小ヒット件数 |
| `suggest.update.doc.per.request` | `2` | document バッチの1リクエスト件数 |
| `suggest.update.contents.limit.num` | `10000` | document 索引対象の件数上限 |
| `suggest.popular.word.query.freq` | `10` | 人気語の queryFreq 閾値（[03-suggest-contents.md](./03-suggest-contents.md) 3.4 の閾値10の実値） |
| `suggest.popular.word.size` | `10` | 人気語取得件数 |
| `suggest.popular.word.cache.size` | `1000` | 人気語キャッシュ最大件数 |
| `suggest.popular.word.cache.expire` | `60` | 人気語キャッシュ有効期間（実装上は**分**, [05-issues.md](./05-issues.md) 5.2 の注意点） |
| `suggest.search.log.permissions` | `{user}guest,{role}guest` | 検索ログ索引化を許可するパーミッション |

参照箇所は `helper/SuggestHelper.java` / `helper/PopularWordHelper.java` / `mylasta/direction/FessProp.java`。

### ランタイム切替フラグ（System Properties、管理画面から変更可）[確認] `mylasta/direction/FessProp.java:557-580`

| フラグ | 既定 | 意味 |
| --- | --- | --- |
| `isSuggestSearchLog()` | `true` | 検索ログ由来サジェストの有効/無効 |
| `isSuggestDocuments()` | `true` | ドキュメント本文由来サジェストの有効/無効 |
| `getPurgeSuggestSearchLogDay()` | `DEFAULT_SUGGEST_PURGE_DAY` | 検索ログサジェストの保持日数 |

- → この2フラグが document / searchlog 経路のマスタースイッチ。両方 false なら `SuggestCreator.create()` は索引再構築自体をスキップする（`SuggestCreator.java:244-247`）。elevate word / bad word は別管理（管理画面 CRUD）。

## 4.3 4経路の駆動元（fess 本体での実利用）[確認]

ライブラリには4経路あるが、**fess 本体が標準で駆動するのは ①③④ の3経路**。② 検索クエリログ経路はライブラリ機能としては存在するが fess 本体では未使用（[05-issues.md](./05-issues.md) 5.1 参照）。

| # | データソース | fess 本体の駆動元 | タイミング |
| --- | --- | --- | --- |
| ① | ドキュメント本文 | `SuggestHelper.indexFromDocuments` ← `SuggestCreator.create`（`isSuggestDocuments()` 時） | **バッチ**（"Suggest Indexer" ジョブ） |
| ② | 検索クエリログ | **fess 本体からの直接呼び出しは無い** | — |
| ③ | 検索語 | `SuggestHelper.indexFromSearchLog` ← (a)`SuggestCreator.storeSearchLog`（バッチ）/ (b)`SearchLogHelper.processSearchLog`（リアルタイム） | **バッチ＋リアルタイム両方** |
| ④ | elevate word | `SuggestHelper.addElevateWord/storeAllElevateWords` ← 管理画面 Action / `SuggestCreator.create` | 管理 CRUD（即時）＋再構築時に DB から全件復元 |

- **① ドキュメント本文（バッチ）**: `SuggestCreator.create()`（`exec/SuggestCreator.java:243-304`）が `createNextIndex` → badword/elevateword 投入 → `indexFromDocuments`（`isSuggestDocuments` 時）→ `storeSearchLog`（`isSuggestSearchLog` 時）→ `switchIndex` → `removeDisableIndices` をオーケストレーション。`indexFromDocuments`（`SuggestHelper.java:267-298`）は `ESSourceReader` で fess の文書検索インデックスを読み出し、clickCount/_score＋ランダム化で代表文書を索引化する。
- **③ 検索語（バッチ＋リアルタイム）**: どちらも `SuggestHelper.indexFromSearchLog`（`:199-259`）→ `indexFromSearchWord(..., num=1, ...)` に到達。リアルタイム経路は `SearchLogHelper.processSearchLog`（`:475-490`）で、検索のたびに（`isSuggestSearchLog()` true かつ permission 充足時）準リアルタイムにサジェスト索引へ追加される。`hitCount < suggest.min.hit.count` のログは無視、セッション単位の重複は間引く。
- **④ elevate word**: 正本は fess の DBFlute テーブル（`ElevateWordBhv`）。管理画面で随時反映され、バッチ再構築時に `storeAllElevateWords(true)` で全件再投入される。

## 4.4 索引のパージ [確認] `SuggestCreator.purge`（`exec/SuggestCreator.java:306-320`）

再構築後に実行。`purgeDocumentSuggest` は Kind が DOCUMENT のみの古語を削除、`purgeSearchlogSuggest` は QUERY のみの古語を削除。**USER（elevate）や複数 Kind を併せ持つ語は purge 対象外で保護される**（`SuggestHelper.java:305-332`）。

## 4.5 サジェスト UI 表示と API 経路 [確認]

### サジェスト検索 API: `GET /api/v2/suggest-words`（`api/v2/handlers/SuggestWordsHandler.java:61-127`）

- ルーティング: `SearchApiV2Manager.java:272`。**GET のみ許可**。
- パラメータ: `q`（クエリ）, `num`（件数, 既定10）, `fn`（フィールド）, `lang`（言語）, `label`（タグ）。
- role: `RoleQueryHelper.build(SearchRequestType.SUGGEST)` の結果を `addRole`（`:83`）。virtualHost があれば tag に追加（マルチテナント絞り込み）。
- **Kind フィルタを動的に構築**（`:96-102`）: 常に `addKind(USER)`。`isSuggestSearchLog()` true なら `addKind(QUERY)`、`isSuggestDocuments()` true なら `addKind(DOCUMENT)`。→ ランタイムフラグが検索 API 側でも「どの Kind を返すか」を制御する。両フラグ false でも USER（elevate）は常に返る。
- レスポンス JSON（`:115-121`）: `q`, `page_size`（=num）, `record_count`（=total）, `query_time`（=tookMs）, `suggest_words`（`[{text, types}]` の配列。`types` は語の `tags`）。
- → **UI に最終的に出るのは各サジェスト語の `text` と、その語の `tags`（`types`）のみ**。読み・頻度・Kind 等は API レスポンスには含めていない。

### 人気語 API / 画面（補助経路）

- API: `/api/v2/popular-words` → `PopularWordsHandler`（`SearchApiV2Manager.java:274`）。画面: `FessSearchAction` ← `PopularWordHelper`。
- `PopularWordHelper.getWordList`（`helper/PopularWordHelper.java:93-131`）が `popularWords()` を呼び、結果を Guava `Cache` でキャッシュ。Kind=query・単一語・queryFreq>=10 が対象。キャッシュは `SuggestHelper.refresh()` および `SuggestJob` 完了時に無効化。

## 4.6 スケジューリング（バッチ駆動の起点）[確認]

- DI 定義: `fess_job.xml:11`（`suggestJob`, prototype）。
- 既定スケジュール: `fess_indices/fess_config.scheduled_job/scheduled_job.bulk:3-4` に **"Suggest Indexer"**（`_id=suggest_indexer`）。`cronExpression`: **`0 12 * * *`**（毎日12:00）。scriptData は groovy で `suggestJob` を実行。
- `SuggestJob.executeSuggestCreator`（`job/SuggestJob.java:92-260`）が **`SuggestCreator` を別 JVM プロセスとして起動**（classpath・システムプロパティ・`jvm.suggest.options` を組み立て）。
- → **[推測]** 索引全件再構築は負荷が高いため本体 Tomcat と別プロセスに隔離し、CPU 負荷調整（`calibrateCpuLoad`）で本体検索性能への影響を抑える設計。

## 4.7 管理画面からの操作 [確認]

- `AdminSuggestAction`: 索引内の語数表示と一括削除。
- `AdminElevatewordAction` / `AdminBadwordAction`: elevate / bad word の CRUD。正本は fess 本体の DBFlute テーブル（`ElevateWordBhv` / `BadWordBhv`）で、サジェスト索引・fess-suggest 設定ストアへ派生反映される。
