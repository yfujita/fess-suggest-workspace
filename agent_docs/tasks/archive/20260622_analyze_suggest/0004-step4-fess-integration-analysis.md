# ステップ4: fess 本体側からの fess-suggest 利用方法の分析

本ドキュメントは作業プラン `0001-work-plan.md` のステップ4の成果物である。
ステップ2（`0002-step2-architecture-analysis.md`）・ステップ3（`0003-step3-suggest-contents-analysis.md`）の成果を前提とし、その申し送り事項（4つのデータ供給経路を駆動する fess 本体側のジョブ/設定、および UI 表示・`suggestDetail` の使われ方）を、`modules/fess` の実コードで補完する。

調査対象は `modules/fess`（fess 本体）。根拠は `file_path:line` 形式で示す（パスは `modules/fess/` 以下の短縮表記）。
**[確認]** はコードで確認できた事実、**[推測]** は実装から合理的に推測した内容を表す。

---

## 0. fess 本体の技術スタック前提（サジェスト連携に関わる範囲）

- **[確認]** Web フレームワークは **LastaFlute**、DI は **Lasta Di**、データアクセスは **DBFlute（OpenSearch 用 ORM）**。検索エンジンは **OpenSearch**（`modules/fess/CLAUDE.md`）。
- **[確認]** fess-suggest はライブラリとして組み込まれ、`org.codelibs.fess.suggest.*` を直接 import して利用する（例: `helper/SuggestHelper.java:48-56`）。
- **[確認]** fess-suggest への呼び出しは原則 **`SuggestHelper`（Lasta Di コンポーネント / ヘルパ）に集約**される。フロント・ジョブ・各種 Action は `ComponentUtil.getSuggestHelper()` 経由でアクセスする。

---

## 1. fess 本体 → fess-suggest の呼び出し経路（コンポーネント全体像）

**[確認]** fess-suggest を直接利用するクラスは以下に限られる（`grep` で網羅確認）。

| fess 本体クラス | 役割 | fess-suggest の利用点 |
| --- | --- | --- |
| `helper/SuggestHelper.java` | **中核ブリッジ**。`Suggester` の生成・初期化・全 indexer 操作を集約 | `Suggester.builder()`, `indexer().indexFrom*`, `addElevateWord` 等 |
| `exec/SuggestCreator.java` | バッチ本体（別 JVM プロセス）。索引再構築のオーケストレーション | `suggester().createNextIndex()/switchIndex()/removeDisableIndices()` 等 |
| `job/SuggestJob.java` | スケジューラから `SuggestCreator` を別プロセス起動 | `SuggestCreator` をコマンド実行 |
| `helper/PopularWordHelper.java` | 人気語取得＋キャッシュ | `suggester().popularWords()` |
| `helper/SearchLogHelper.java` | 検索ログ保存時にリアルタイムでサジェスト索引へ反映 | `suggestHelper.indexFromSearchLog(...)` |
| `api/v2/handlers/SuggestWordsHandler.java` | サジェスト検索の REST API（`/api/v2/suggest-words`） | `suggester().suggest()` |
| `app/web/admin/suggest/AdminSuggestAction.java` | 管理画面（語数表示・削除） | `SuggestHelper.getAllWordsNum()/delete*Words()` |
| `app/web/admin/elevateword/AdminElevatewordAction.java` | 優先表示語の登録/削除 | `suggestHelper.addElevateWord/deleteElevateWord/storeAllElevateWords` |
| `app/web/admin/badword/AdminBadwordAction.java` | NG ワードの登録/削除 | `suggestHelper.addBadWord/deleteBadWord/storeAllBadWords` |

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

### 1.1 `SuggestHelper` の初期化（`Suggester` 生成）

**[確認]** `SuggestHelper.init()`（`@PostConstruct`, `helper/SuggestHelper.java:114-159`）:
- `fessConfig` から **content / tag / role フィールド集合**を読み込む（`:120-124`）。
  - `suggest.field.contents`（既定 `_default`）→ `contentFieldNameSet`
  - `suggest.field.tags`（既定 `label`）→ `tagFieldNameSet`
  - `suggest.field.roles`（既定 `role`）→ `roleFieldNameSet`
  - `suggest.field.index.contents`（既定 `content,title`）→ 後述 SUPPORTED_FIELDS
- OpenSearch クラスタの yellow 待機後（`:127-132`）、`SuggestSettingsBuilder` に各種タイムアウト・設定インデックス名を渡し（`:134-141`）、`Suggester.builder()...build(searchEngineClient, fessConfig.getIndexDocumentSuggestIndex())` で **`Suggester` を生成**（`:142`）。
  - インデックス名のベースは `index.document.suggest.index`（既定 `fess`、`fess_config.properties:591`）。設定ストアのインデックス名は `{base}_suggest`（`:141`）。
- **[確認]** `suggest.field.index.contents` の各フィールドを `Suggester` の設定キー `SUPPORTED_FIELDS` に登録し直し（既存を delete してから add、`:147-154`）、`createIndexIfNothing()` で初期インデックス＋エイリアスを作成（`:155`）。
  → ステップ2で述べた「`setSupportedFields` で指定したフィールドのみ document/querylog 収集」の実値が、ここで `content,title` として設定される **[確認]**。

> **[確認] 重要な設計点**: `SuggestHelper` は Lasta Di の **シングルトンに近いヘルパ**で、アプリ起動時に `Suggester` を1つ生成して保持する。検索 API・人気語・リアルタイム検索ログ反映はこの同一 `Suggester`（＝検索エイリアス/設定）を共有する。一方バッチ再構築（`SuggestCreator`）は **別 JVM プロセス** で動くため、自分の `SuggestHelper`/`Suggester` インスタンスを別途生成する（後述 3.1）。

---

## 2. サジェスト関連の設定項目

### 2.1 `fess_config.properties` のサジェスト設定（静的設定）

**[確認]** `fess_config.properties:1411-1457` ほか。`FessConfig` 経由でアクセスされる。

| プロパティ | 既定値 | 意味 | 主な参照 |
| --- | --- | --- | --- |
| `index.document.suggest.index` | `fess` | サジェスト用インデックスのベース名 | `SuggestHelper.java:142, 273` |
| `suggest.field.contents` | `_default` | サジェスト**本文収集**対象フィールド（検索ログ由来の本文判定にも使用） | `SuggestHelper.java:120` |
| `suggest.field.tags` | `label` | tag として扱うフィールド名 | `SuggestHelper.java:122` |
| `suggest.field.roles` | `role` | role として扱うフィールド名 | `SuggestHelper.java:123` |
| `suggest.field.index.contents` | `content,title` | document/querylog の **SUPPORTED_FIELDS**（実際に索引する本文フィールド） | `SuggestHelper.java:148` |
| `suggest.min.hit.count` | `1` | 検索ログを索引化する最小ヒット件数（これ未満は無視） | `SuggestHelper.java:202-204` |
| `suggest.update.request.interval` | `0` | document バッチの1リクエスト間隔(ms) | `SuggestHelper.java:269, 293` |
| `suggest.update.doc.per.request` | `2` | document バッチの1リクエスト件数 | `SuggestHelper.java:270, 291` |
| `suggest.update.contents.limit.num.percentage` | `50%` | document 索引対象の割合上限 | `SuggestHelper.java:276` |
| `suggest.update.contents.limit.num` | `10000` | document 索引対象の件数上限 | `SuggestHelper.java:277` |
| `suggest.update.contents.limit.doc.size` | `50000` | document 1件あたりサイズ上限 | `SuggestHelper.java:278` |
| `suggest.source.reader.scroll.size` | `1` | `ESSourceReader` の scroll サイズ | `SuggestHelper.java:275` |
| `suggest.popular.word.seed` | `0` | 人気語のランダム seed | `PopularWordHelper.java:95` |
| `suggest.popular.word.tags` | （空） | 人気語の既定タグ | `PopularWordHelper.java:96` |
| `suggest.popular.word.fields` | （空） | 人気語の既定フィールド | `PopularWordHelper.java:103` |
| `suggest.popular.word.excludes` | （空） | 人気語の除外語 | `PopularWordHelper.java:104` |
| `suggest.popular.word.size` | `10` | 人気語取得件数 | `PopularWordHelper.java:111` |
| `suggest.popular.word.window.size` | `30` | 人気語の window サイズ | `PopularWordHelper.java:112` |
| `suggest.popular.word.query.freq` | `10` | 人気語の queryFreq 閾値（ステップ3 §4.1 の閾値10の実値） | `PopularWordHelper.java:113` |
| `suggest.popular.word.cache.size` | `1000` | 人気語キャッシュ最大件数 | `PopularWordHelper.java:76` |
| `suggest.popular.word.cache.expire` | `60` | 人気語キャッシュ有効期間（**分**, `TimeUnit.MINUTES`） | `PopularWordHelper.java:77` |
| `suggest.search.log.permissions` | `{user}guest,{role}guest` | 検索ログ索引化を許可するパーミッション | `FessProp.java:1342-1352` |
| `suggest.system.monitor.interval` | `60` | バッチ中のシステムモニタ間隔(秒) | `SuggestCreator.java:171` |
| `jvm.suggest.options` | （JVM 設定） | `SuggestCreator` 別プロセスの JVM オプション | `SuggestJob.java:185` |

> **[確認]** `suggest.popular.word.cache.expire` は `init()` で **`TimeUnit.MINUTES`** として渡されている（`PopularWordHelper.java:77`）。プロパティ名のコメントは「秒」と記載されているが、実装上は分で解釈される点に注意（コメントと実装の不一致）。

### 2.2 ランタイム切替フラグ（System Properties、管理画面から変更可能）

**[確認]** 以下は `fess_config.properties` ではなく **System Properties ストア**に保存され、`FessProp` の default メソッド経由で参照される（`mylasta/direction/FessProp.java:557-580`）。

| フラグ / 値 | 既定 | 意味 | 定義 |
| --- | --- | --- | --- |
| `isSuggestSearchLog()` | `true` | 検索ログ由来サジェストの有効/無効 | `FessProp.java:561-563`（`SUGGEST_SEARCH_LOG_PROPERTY`） |
| `isSuggestDocuments()` | `true` | ドキュメント本文由来サジェストの有効/無効 | `FessProp.java:569-571`（`SUGGEST_DOCUMENTS_PROPERTY`） |
| `getPurgeSuggestSearchLogDay()` | `DEFAULT_SUGGEST_PURGE_DAY` | 検索ログサジェストの保持日数 | `FessProp.java:577-580` |

→ これらの2フラグが「ステップ3で挙げた4経路のうち document / searchlog を実際に流すか」のマスタースイッチに相当する **[確認]**。両方 false なら `SuggestCreator.create()` は索引再構築自体をスキップする（`SuggestCreator.java:244-247`）。
（elevate word / bad word は別管理 — 管理画面の CRUD で随時反映、後述 5。）

---

## 3. 4つのデータ供給経路と fess 本体側の駆動元の対応付け

ステップ3で確定した4経路（① ドキュメント本文 / ② 検索クエリログ / ③ 検索語 / ④ elevate word）を、fess 本体で「いつ・どの処理が駆動するか」に対応付ける。

| # | データソース（Kind） | fess-suggest の入口 | fess 本体の駆動元 | タイミング |
| --- | --- | --- | --- | --- |
| ① | ドキュメント本文（DOCUMENT） | `indexer().indexFromDocument(...)` | `SuggestHelper.indexFromDocuments` ← `SuggestCreator.create`（`isSuggestDocuments()` 時） | **バッチ**（"Suggest Indexer" ジョブ, 既定 cron `0 12 * * *`） |
| ② | 検索クエリログ（QUERY） | `indexer().indexFromQueryLog(...)` | **[確認] fess 本体からの直接呼び出しは無い**（後述 3.4） | — |
| ③ | 検索語（QUERY） | `indexer().indexFromSearchWord(...)` | `SuggestHelper.indexFromSearchLog` ← (a) `SuggestCreator.storeSearchLog`（バッチ）/ (b) `SearchLogHelper.processSearchLog`（リアルタイム） | **バッチ + リアルタイム両方** |
| ④ | elevate word（USER） | `indexer().addElevateWord(...)` | `SuggestHelper.addElevateWord/storeAllElevateWords` ← 管理画面 Action / `SuggestCreator.create` | 管理 CRUD（即時）＋ 再構築時に全件復元 |

### 3.1 ① ドキュメント本文 → バッチ（`SuggestCreator`）

**[確認]** `SuggestCreator.create()`（`exec/SuggestCreator.java:243-304`）が再構築をオーケストレーションする:
1. `isSuggestDocuments()` も `isSuggestSearchLog()` も false ならスキップ（`:244-247`）。
2. `suggester().createNextIndex()` で新インデックス作成（更新エイリアス付替, `:252`）。
3. `storeAllBadWords(true)` → `storeAllElevateWords(true)` で NG/優先語を先に投入（`:255-258`）。
4. `isSuggestDocuments()` なら `suggestHelper.indexFromDocuments(...)` を実行し `CountDownLatch` で完了待ち（`:262-283`）。
5. `isSuggestSearchLog()` なら `suggestHelper.storeSearchLog()` を実行（`:285-295`）。
6. `switchIndex()`（検索エイリアス切替）→ `removeDisableIndices()`（旧インデックス削除）（`:297-301`）。

**[確認]** `SuggestHelper.indexFromDocuments`（`helper/SuggestHelper.java:267-298`）:
- `ESSourceReader`（fess-suggest 提供）で **fess の文書検索インデックス**（`index.document.search.index`, `:273-274`）を読み出す。
- `randomFunction` でランダム化した `functionScoreQuery(matchAllQuery())` ＋ `clickCount` / `_score` ソートで読み出し順を制御（`:280-289`）。
  → **[推測]** クリック数の多い人気文書を優先しつつランダム要素で偏りを抑え、`limit.num`/`limit.num.percentage` 上限内で代表的な文書本文を索引化する設計。
- `indexFromDocument(readerSupplier, docPerReq, waitController)` を呼び（`:272, 291`）、`waitController` で `calibrateCpuLoad()` + `sleep(interval)`（CPU 負荷調整, `:292-293`）。完了後 `refresh()`（`:295`）。

### 3.2 ③ 検索語 → バッチ + リアルタイムの2系統

**[確認]** どちらも最終的に `SuggestHelper.indexFromSearchLog(List<SearchLog>)`（`helper/SuggestHelper.java:199-259`）を通り、`indexer().indexFromSearchWord(...)`（`:251-253`）に到達する。

- **(a) バッチ**: `SuggestCreator.storeSearchLog`→ `SuggestHelper.storeSearchLog()`（`:173-192`）。`SearchLogBhv` から過去 `getPurgeSuggestSearchLogDay()` 日分の検索ログを bulk 取得し（`:176-191`）、`indexFromSearchLog` へ流す。
- **(b) リアルタイム**: `SearchLogHelper.processSearchLog`（`helper/SearchLogHelper.java:475-490`）。検索ログ保存処理の中で `isSuggestSearchLog()` が true なら、その場で `suggestHelper.indexFromSearchLog(searchLogList)` を呼ぶ（`:484-488`）。
  → **[確認] つまり検索が行われるたびに、検索語が（条件を満たせば）準リアルタイムでサジェスト索引へ追加される**。バッチ再構築を待たずに新しい検索語がサジェストに反映される設計。

**[確認]** `indexFromSearchLog` のフィルタ・整形ロジック（`:199-258`）:
- `hitCount` が `suggest.min.hit.count`（既定1）未満のログは無視（`:202-204`）。
- セッション ID 単位で `searchStoreInterval`（既定1分, `:107`）内の重複検索を間引く（`:200, 216-220, 254`）。
- 検索フィールドログを `contentFieldNameSet` / `tagFieldNameSet` / `roleFieldNameSet` で振り分け、本文語・tag・role を構成（`:227-245`）。virtualHost も tag に追加（`:242-245`）。
- `isValidSearchLogPermissions(roles)`（`suggest.search.log.permissions` で判定）を満たす場合のみ `indexFromSearchWord(text, fields, tags, roles, num=1, langs)` を呼ぶ（`:250-253`）。
  → **[確認]** ここで `num=1` を渡すため、ステップ3 §3.4 の「queryFreq=score(=件数)」は **1検索＝queryFreq+1** として効く。

### 3.3 ④ elevate word → 管理 CRUD（即時）＋ 再構築時の全件復元

**[確認]**
- 管理画面 `AdminElevatewordAction`:
  - 登録時 `suggestHelper.addElevateWord(..., apply)` （`app/web/admin/elevateword/AdminElevatewordAction.java:351`）。
  - 削除時 `deleteElevateWord(word, false)`（`:410`）、一括再投入 `deleteAllElevateWord(false)`＋`storeAllElevateWords(false)`（`:380-381, 435-436`）。
  - **[確認]** 多くの呼び出しが `apply=false`（DB が正、索引は次回再構築で反映）だが、`addElevateWord` の登録経路は `apply` 引数を渡しており、UI 設定で即時反映可能。
- バッチ `SuggestCreator.create` 内では `storeAllElevateWords(true)`（`apply=true`）で **新インデックスへ全件再投入**（`SuggestCreator.java:258`）。
  → ステップ3 §4.2 の `restoreElevateWord`/即時 index に対応。**[確認]** elevate word の正本は fess の `ElevateWord` テーブル（DBFlute, `ElevateWordBhv`）であり（`SuggestHelper.java:414-422`）、サジェスト索引へは派生反映される。

### 3.4 ② 検索クエリログ経路は fess 本体では未使用（[確認]）

**[確認]** `grep` の結果、fess 本体から `indexFromQueryLog(...)` を呼ぶ箇所は存在しない（`SuggestHelper` も `indexFromQueryLog` をラップしていない）。
fess 本体は検索語の収集に **③ 検索語経路（`indexFromSearchWord`）** を採用しており、Lucene クエリ文字列をパースする ② クエリログ経路（`parseQueryLog`）は **ライブラリ機能としては存在するが fess 本体の標準フローでは駆動されない**。
→ **[推測]** fess は `SearchLog` エンティティ（構造化済みの検索語・フィールド・ロール）を保持しているため、生の Lucene クエリ文字列を再パースする ② より、構造化済みの ③ を使う方が自然なため。実用上、fess のサジェストの QUERY 種別は主に検索語経路で供給される。

### 3.5 索引のパージ（古いデータの削除）

**[確認]** `SuggestCreator.purge(startTime)`（`exec/SuggestCreator.java:306-320`）が再構築後に実行:
- `purgeDocumentSuggest(time)`: `@timestamp` が古く、Kind が DOCUMENT のみ（QUERY/USER を含まない）の語を `deleteByQuery` で削除（`SuggestHelper.java:305-315`）。
- `purgeSearchlogSuggest(time - cleanupDay)`: QUERY のみ（DOCUMENT/USER を含まない）の古い語を削除（`SuggestHelper.java:322-332`）。`cleanupDay = getPurgeSuggestSearchLogDay()`。
  → **[確認]** USER（elevate）や複数 Kind を併せ持つ語は purge 対象外で保護される。

---

## 4. サジェスト UI 表示と API 経路（`suggestDetail` の使われ方）

### 4.1 サジェスト検索 API: `/api/v2/suggest-words`

**[確認]** ルーティング: `SearchApiV2Manager` の `case "/suggest-words" -> suggestWordsHandler.handle(...)`（`api/v2/SearchApiV2Manager.java:272`）。
**[確認]** `SuggestWordsHandler.handle`（`api/v2/handlers/SuggestWordsHandler.java:61-127`）:
- **GET のみ許可**（`:62-66`）。
- パラメータ: `q`（クエリ）, `num`（件数, 既定10, `pagingSearchPageMaxSize` で上限クランプ, `:68-70, 142-155`）, `fn`（フィールド）, `lang`（言語）, `label`（タグ）（`:68-73`）。
- `suggester().suggest()` でビルダ生成。`q`/`fields`/`size`/`langs`/`tags` を設定（`:76-90`）。
- **role**: `RoleQueryHelper.build(SearchRequestType.SUGGEST)` の結果を `addRole`（`:83`）。**[確認] 権限フィルタが API 側で常に付与される**（ステップ2 §3.2 の `_guest_` 補完と合わせ、権限制御が二重に担保）。
- **virtualHost**: 仮想ホストキーがあれば tag に追加（マルチテナント絞り込み, `:91-95`）。
- **[確認] Kind フィルタを動的に構築**（`:96-102`）:
  - 常に `addKind(USER)` を追加（elevate 語は常に対象）。
  - `isSuggestSearchLog()` が true なら `addKind(QUERY)`。
  - `isSuggestDocuments()` が true なら `addKind(DOCUMENT)`。
  → **[確認] ランタイムフラグ（§2.2）が、検索 API 側でも「どの Kind を返すか」を制御する**。両フラグが false でも USER（elevate）は常に返る。

### 4.2 `suggestDetail` の使われ方 — fess 本体は `items` を使う [確認]

**[確認]** `SuggestWordsHandler` はレスポンス生成で `suggestResponse.getItems()` を走査し（`:106-113`）、各 item から `text` と `tags`（→ `types` キー）を取り出す（`:109-112`）。
- **[確認]** ステップ3 §5.2 のとおり、`items` が中身を持つのは `suggestDetail=true` のとき。本ハンドラは `items` を直接参照しているため、**fess 本体は実質 `suggestDetail` 相当（詳細取得）でサジェストを利用している**。
  ただし `SuggestWordsHandler` のコード上は `setSuggestDetail(true)` の明示呼び出しは見当たらず、`getItems()` に依存している。**[推測]** ライブラリ側の既定もしくはビルダのデフォルト挙動で `items` が返るか、`getWords()`/`getItems()` の関係で `items` が利用可能になっている可能性がある。`text`＋`tags` のみを使うため、読み・freq・kinds などの詳細は API レスポンスには出力していない。
- **[確認] レスポンス JSON 構造**（`:115-121`）: `q`, `page_size`（=`getNum()`）, `record_count`（=`getTotal()`）, `query_time`（=`getTookMs()`）, `suggest_words`（`[{text, types}]` の配列）。
  → **[確認] UI に最終的に出るのは各サジェスト語の `text` と、その語に紐づく `tags`（`types`）**。読み仮名・頻度・Kind 等は API には現れない（ステップ3 §5.2 の「UI 最低限は words 相当」を裏付け）。

### 4.3 人気語 API / 画面表示（補助経路）

**[確認]** 別経路として「人気語（popular words）」がある。
- API: `/api/v2/popular-words` → `PopularWordsHandler`（`SearchApiV2Manager.java:274`）。
- 画面: `FessSearchAction`（`app/web/base/FessSearchAction.java`）が `PopularWordHelper` を利用（`grep` 確認）。
- **[確認]** `PopularWordHelper.getWordList`（`helper/PopularWordHelper.java:93-131`）が `suggester().popularWords()` を呼び、`size`/`windowSize`/`queryFreqThreshold` を §2.1 のプロパティで設定（`:111-113`）。結果は Guava `Cache`（size/expire は §2.1）でキャッシュ（`:106, 75-78`）。
  → **[確認]** 人気語は item の `text` のみ抽出して返す（`:120`）。ステップ3 §4.1 のとおり Kind=query・単一語・queryFreq>=閾値（実値10）が対象。
- **[確認]** キャッシュは `SuggestHelper.refresh()`（`helper/SuggestHelper.java:538-543`）および `SuggestJob` 完了時（`job/SuggestJob.java:245`）に `clearCache()` で無効化される。

---

## 5. 管理画面からの操作（elevate / bad word / 索引メンテ）

**[確認]**
- `AdminSuggestAction`（`app/web/admin/suggest/AdminSuggestAction.java`）: 索引内の語数表示（`getAllWordsNum`/`getDocumentWordsNum`/`getQueryWordsNum`, `:57-59`）と、語の一括削除（`deleteAllWords`/`deleteDocumentWords`/`deleteQueryWords`, `:89-124`）を提供。
- `AdminElevatewordAction` / `AdminBadwordAction`: elevate / bad word の CRUD を行い、対応する `SuggestHelper` メソッドで索引へ反映（§3.3）。bad word は `storeAllBadWords` / `addBadWord` / `deleteBadWord`、apply フラグでインデックス即時反映を制御（ステップ3 §4.2）。
- **[確認]** elevate / bad word の **正本は fess 本体の DBFlute テーブル**（`ElevateWordBhv` / `BadWordBhv`, `SuggestHelper.java:414, 503`）。サジェスト索引・fess-suggest 設定ストアへは派生的に反映され、バッチ再構築時に DB から全件再投入される。

---

## 6. スケジューリング（バッチ駆動の起点）

**[確認]**
- DI 定義: `fess_job.xml:11` に `<component name="suggestJob" class="org.codelibs.fess.job.SuggestJob" instance="prototype">`。
- 既定スケジュール: `fess_indices/fess_config.scheduled_job/scheduled_job.bulk:3-4` に **"Suggest Indexer"** ジョブ（`_id=suggest_indexer`）が seed 登録されている。
  - `cronExpression`: **`0 12 * * *`**（毎日12:00）。
  - `scriptData`: `container.getComponent("suggestJob").logLevel("info").sessionId("SUGGEST").execute(executor)`（groovy）。
  - `available: true`, `target: all`, `sortOrder: 2`。
- **[確認]** `SuggestJob.executeSuggestCreator`（`job/SuggestJob.java:92-260`）は **`SuggestCreator` を別 JVM プロセスとして起動**する（classpath・システムプロパティ・`jvm.suggest.options` を組み立て、`SuggestCreator.class` をコマンド実行, `:185-235`）。lasta.env は `suggest`（`getExecuteType()` = `EXECUTE_TYPE_SUGGEST`, `:262-265`）。
  → **[推測]** 索引全件再構築はメモリ・CPU 負荷が高いため、本体 Tomcat とは別プロセスに隔離し、JVM オプションや CPU 負荷調整（`calibrateCpuLoad`）で本体の検索性能への影響を抑える設計。

---

## 7. 要点まとめ（ステップ4 完了条件への対応）

### fess 本体 → fess-suggest の呼び出し経路
- 中核は **`SuggestHelper`**（Lasta Di ヘルパ）。アプリ起動時に `Suggester` を1つ生成・保持し、検索 API・人気語・リアルタイム検索ログ反映が共有する。バッチ再構築のみ別 JVM（`SuggestCreator`）。
- 直接 fess-suggest を呼ぶのは `SuggestHelper` / `SuggestCreator` / `PopularWordHelper` / `SearchLogHelper` / `SuggestWordsHandler` と管理 Action 群に限られる。

### 設定項目
- 静的設定: `fess_config.properties` の `suggest.*`（収集フィールド `suggest.field.index.contents=content,title`、tag=`label`、role=`role`、document バッチ上限、人気語パラメータ、検索ログ permissions など）。
- ランタイム切替（管理画面・System Properties, 既定 true）: `isSuggestDocuments()` / `isSuggestSearchLog()` が document / searchlog 経路のマスタースイッチ。`getPurgeSuggestSearchLogDay()` で保持日数。

### 4経路の駆動元
- ① ドキュメント本文 → **バッチ**（"Suggest Indexer" ジョブ → `SuggestCreator` → `indexFromDocuments`、`isSuggestDocuments` 時）。
- ② 検索クエリログ → **fess 本体では未使用**（ライブラリ機能のみ存在、③ で代替）。
- ③ 検索語 → **バッチ（過去ログ一括）＋ リアルタイム（検索のたびに `SearchLogHelper`→`indexFromSearchLog`→`indexFromSearchWord`, num=1）**。`isSuggestSearchLog` 時。
- ④ elevate word → **管理 CRUD（即時 apply 可）＋ 再構築時に DB から全件復元**。正本は DBFlute テーブル。
- 索引メンテ: 再構築は二重エイリアスでゼロダウンタイム、古い DOCUMENT/QUERY 語は `purge*` で削除（USER は保護）。

### UI 表示 / `suggestDetail`
- サジェスト検索 UI は **`GET /api/v2/suggest-words`**（`SuggestWordsHandler`）経由。GET のみ、role/virtualHost フィルタ付き、Kind は USER 常時＋（フラグに応じ）QUERY/DOCUMENT。
- レスポンスは `suggest_words: [{text, types(=tags)}]` ＋メタ（`page_size`/`record_count`/`query_time`）。**`items`（詳細）を参照しており、UI には語の `text` とタグのみ出力**。読み・頻度・Kind 等の詳細はライブラリでは取れるが API には出していない。
- 人気語は別経路 `/api/v2/popular-words`（`PopularWordsHandler`）/ 画面 `FessSearchAction` ← `PopularWordHelper`（キャッシュ付き、`text` のみ）。

---

## 8. 残課題・未確定事項（ステップ5 への申し送り）

- **[推測]** `SuggestWordsHandler` が `setSuggestDetail(true)` を明示せずに `getItems()` を使っている点は、ライブラリ側ビルダの既定挙動（`items` が常に返るのか、`suggestDetail` 既定値）を fess-suggest 側コードで確認すると正確になる。現状「fess は items を参照している」事実は確認済みだが、`suggestDetail` フラグの設定主体は未確定。
- **[確認/注記]** `suggest.popular.word.cache.expire` はコメント「秒」だが実装は分（`TimeUnit.MINUTES`）。ドキュメント化の際は実装値（分）を正とする。
- **[確認]** ② クエリログ経路は fess 本体で未使用。最終統合ドキュメント（ステップ5）では「ライブラリには4経路あるが fess 本体が標準で駆動するのは ①③④ の3経路」と整理すると実態に即する。
- バッチ（毎日12:00 全件再構築）とリアルタイム（検索ごとの検索語追加）の二段構成、および purge の Kind 条件は運用理解上の要点としてステップ5 に反映する。
