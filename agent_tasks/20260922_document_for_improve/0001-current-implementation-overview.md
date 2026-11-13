# fess-suggest 現行実装の概要（リファクタリング事前調査）

- タスク: `20260922_document_for_improve`（要件: [0000-requirements-definition.md](./0000-requirements-definition.md)）
- 作成日: 2026-09-22 / 対象: fess-suggest `15.9.0-SNAPSHOT`（HEAD `f7a8039` #100 時点）、fess `15.9.0-SNAPSHOT`
- 目的: 現行実装の全体像を短時間で掴めるようにする。細部の網羅はしない。後続のリファクタリング設計の出発点とする。

凡例と表記:
- **[確認]** はソースで直接確かめた事実、**[推測]** は実装から推し量った内容、**[提案]** はリファクタリングに向けた提案。
- 根拠は `file:line` で示す。パスは次の短縮表記を使う。
  - 無印: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下（例 `Suggester.java:159`）
  - `res:`: `modules/fess-suggest/src/main/resources/` 配下
  - `fess:`: `modules/fess/src/main/java/org/codelibs/fess/` 配下
- 旧資料 `agent_docs/global/references/legacy/`（15.7.1-SNAPSHOT 時点）と違う点は、§10 にまとめた。

---

## 1. 概要

fess-suggest は、OpenSearch 上に「サジェスト語インデックス」を作り、次の 3 つを提供する Java ライブラリである。
- 入力途中の語句に対する候補（オートコンプリート）
- 人気語
- NG ワード（bad word）と優先表示語（elevate word）の管理

fess 本体から見ると、`SuggestHelper` が保持する `Suggester` 1 個が唯一の入口になる。

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| 座標 | `org.codelibs.fess:fess-suggest:15.9.0-SNAPSHOT`（jar、Automatic-Module-Name `org.codelibs.fess.suggest`） | `modules/fess-suggest/pom.xml` |
| 親 POM | `fess-parent:15.9.0-SNAPSHOT`（Java release 21、OpenSearch 3.8.0、Lucene 10.5.0、fesen-httpclient 3.8.1-SNAPSHOT） | `~/.m2/.../fess-parent-15.9.0-SNAPSHOT.pom:56,59,124,174` |
| 検索エンジン API | **fesen-httpclient**（provided）に同梱された、OpenSearch のフォークパッケージ `org.codelibs.fesen.opensearch.*` を使う。`org.opensearch:opensearch` には依存していない（#98） | `pom.xml`、`Suggester.java:41-53` |
| その他の依存 | `corelib`（compile）、`lucene-queryparser`・`log4j-api`（provided）、`icu4j`（**optional**。`ICUNormalizer` だけが使う。#99） | `pom.xml` |
| テスト依存 | JUnit 4、`opensearch-runner`（組み込みノード）、`analyzers`、`lucene-analysis-kuromoji` | `pom.xml` |
| 規模 | main 65 ファイル・約 11,900 行、test 80 ファイル・約 15,800 行（`@Test` 660 件） | `wc -l` |
| fess 側の依存宣言 | `fess-suggest:${suggest.version}`。バージョンは fess-parent が決める | `modules/fess/pom.xml:1363-1367` |

## 2. パッケージ構成と責務

| パッケージ | 主要クラス | 責務 |
| --- | --- | --- |
| （ルート） | `Suggester`, `SuggesterBuilder` | ファサード。検索用・更新用エイリアスの管理、インデックスのライフサイクル（作成・切替・削除）、各ビルダーの生成 |
| `settings` | `SuggestSettings`(+Builder), `ArraySettings`, `BadWordSettings`, `ElevateWordSettings`, `AnalyzerSettings`, `TimeoutSettings` | 設定の永続化（OpenSearch 上の設定用インデックス群）。アナライザの定義と `_analyze` の呼び出しもここにある |
| `index` | `SuggestIndexer`, `SuggestIndexResponse`, `SuggestDeleteResponse` | 登録・削除のファサード。処理は `operations` に委譲する |
| `index.operations` | `IndexingOperations`, `DeletionOperations`, `WordManagementOperations`, `ContentIndexingOperations`, `ContentIndexingContext` | 実際の登録・削除・語管理・データソース別の登録処理（#88 で分割された） |
| `index.contents` | `ContentsParser`, `DefaultContentsParser`, `document.{DocumentReader, ESSourceReader}`, `querylog.{QueryLog, QueryLogReader}` | 入力（文書・クエリログ・検索語）を `SuggestItem` に変換する。文書インデックスを走査する Reader |
| `index.writer` | `SuggestWriter`, `SuggestIndexWriter`, `SuggestBulkFileWriter`, `SuggestWriterResult` | OpenSearch への書き込み（既存ドキュメントと集計値をマージしてから bulk） |
| `request` | `Request`, `RequestBuilder`, `Response` | 非同期リクエストの基底（`Deferred` を返す） |
| `request.suggest` | `SuggestRequest`(+Builder), `SuggestQueryBuilder`, `SuggestResponseCreator`, `SuggestResponse` | サジェスト検索（クエリ構築、スコアリング、レスポンス整形） |
| `request.popularwords` | `PopularWordsRequest`(+Builder), `PopularWordsResponse` | 人気語の取得 |
| `entity` | `SuggestItem`, `SuggestItemSerializer`, `SuggestItemMerger`, `ElevateWord` | ドメインモデルと、OpenSearch の source との相互変換・マージ |
| `normalizer` | `Normalizer`, `NormalizerChain`, `AnalyzerNormalizer`, `ICUNormalizer` ほか | 表記の正規化 |
| `converter` | `ReadingConverter`, `ReadingConverterChain`, `AnalyzerConverter`, `KatakanaToAlphabetConverter`, `KatakanaConverter` | 読み（カナ・ローマ字）への変換 |
| `analysis` | `SuggestAnalyzer` | トークン化の IF。実装は `AnalyzerSettings.DefaultContentsAnalyzer` |
| `concurrent` | `Deferred`(+`Promise`) | 独自の Promise 実装 |
| `util` | `SuggestUtil`, `PitOperationHelper`, `TransliteratorUtil`, `MapValueExtractor`, `SettingsResourceLoader` | ID 生成、PIT による走査、delete-by-query、ICU を使わない文字変換など |
| `constants` / `exception` | `FieldNames`, `SuggestConstants` / `SuggesterException`, `SuggestIndexException`, `SuggestSettingsException` | フィールド名の定数と例外（3 種とも RuntimeException） |

## 3. 全体アーキテクチャ

```
 fess 本体                             fess-suggest
 ───────────────                      ─────────────────────────────────────────────────────────
 SuggestHelper ──build/保持──▶ Suggester (Facade, index=<id>.suggest)
   │  ├ suggest() ───────────▶ SuggestRequestBuilder ─▶ SuggestRequest ─▶ SuggestQueryBuilder
   │  ├ popularWords() ──────▶ PopularWordsRequestBuilder ─▶ PopularWordsRequest      │ normalize/reading
   │  ├ indexer() ───────────▶ SuggestIndexer (呼ぶたびに new)                         ▼
   │  │                          ├ IndexingOperations ──┐        Normalizer / ReadingConverter
   │  │                          ├ DeletionOperations ──┼▶ SuggestWriter(SuggestIndexWriter)
   │  │                          ├ WordManagementOps ───┤          │ GET→merge→bulk
   │  │                          └ ContentIndexingOps ──┘          ▼
   │  │                               └ ContentsParser ─▶ SuggestItem ─▶ [OpenSearch] <id>.suggest.<ts>
   │  ├ settings() ──────────▶ SuggestSettings ─┬ ArraySettings / BadWord / ElevateWord ─▶ [設定用 index 群]
   │  └ create/switch/remove index             └ AnalyzerSettings ─▶ [*_analyzer index] (_analyze API)
   └ ESSourceReader を生成し indexFromDocument に渡す（文書 index を PIT + search_after で走査）
 共通: Normalizer・ReadingConverter・SuggestAnalyzer の既定実装は、OpenSearch の _analyze API を呼ぶ（リモート呼び出し）
```

- [確認] 既定のテキスト処理部品は `SuggesterBuilder.build` が組み立てる（`SuggesterBuilder.java:149-190`、`util/SuggestUtil.java:252-300`）。
  - `readingConverter`: `AnalyzerConverter` → `KatakanaToAlphabetConverter` の順のチェーン（クエリ・検索語・メタデータ用）
  - `contentsReadingConverter`: `KatakanaToAlphabetConverter` だけ（文書の本文用。読みは、アナライザが出す読みトークンを使う）
  - `normalizer`: `AnalyzerNormalizer` だけ（他の Normalizer はコメントアウトされている。`SuggestUtil.java:283-286`）
  - `analyzer`: `AnalyzerSettings.DefaultContentsAnalyzer`
  - `threadPool`: `Executors.newFixedThreadPool(CPU 数)`
- [確認] `Suggester` は公開コンストラクタで全部品を受け取れる（`Suggester.java:138`）。ただし fess はビルダー経由の既定構成しか使っていない。

## 4. データモデル

### 4.1 インデックスとエイリアス

fess の既定設定 `index.document.suggest.index=fess` の場合の具体名を併記する。

| 種別 | 名前（fess 既定） | 定義・根拠 |
| --- | --- | --- |
| 物理サジェストインデックス | `fess.suggest.yyyyMMddHHmmssSSS` | `Suggester.java:463-465`。設定は `res:suggest_indices/suggest.json`（shards=1、replicas=0、auto_expand 0-1、refresh 10s） |
| 検索用エイリアス | `fess.suggest` | `Suggester.java:455-457`。`suggest()`、`popularWords()`、語数カウントが参照する |
| 更新用エイリアス | `fess.suggest.update` | `Suggester.java:459-461`。`indexer()` が参照する |
| 基本設定（1 ドキュメント） | `fess_suggest`（doc id = `fess`） | `SuggestSettings.java:182-247`。`index`、`tagFieldName`、`roleFieldName`、`langFieldName`、`parallel` など |
| 配列設定 | `fess_suggest_array.fess` | `ArraySettings.java:183,206`（`supportedFields` など） |
| bad word | `fess_suggest_badword.fess` | `BadWordSettings.java:57`（既定語 `res:suggest_settings/default-badwords.txt`） |
| elevate word | `fess_suggest_elevate.fess` | `ElevateWordSettings.java:100` |
| アナライザ定義 | `fess_suggest_analyzer` | `AnalyzerSettings.java:306`。定義は `res:suggest_indices/suggest_analyzer.json`（言語別の `*_analyzer_<lang>`）。`search_engine.type` 別の差し替えパスもある（`:333-341`） |

- [確認] 配列系の設定 index は `<設定index>_<種別>.<settingsId>` という名前になる（`ArraySettings.java:206`。`index + "." + settingsId` を実名にする）。
- [確認] サジェスト index 名の既定値は `(settingsId + ".suggest").toLowerCase()`（`SuggestSettings.java:512`）。
- [確認] fess は `settingsId` にベース名（`fess`）を、設定用 index 名に `fess_suggest` を渡している（`fess:helper/SuggestHelper.java:141-142`）。

### 4.2 サジェストドキュメントの主要フィールド（`res:suggest_indices/suggest/mappings-default.json`、`constants/FieldNames.java`）

| フィールド | 内容 |
| --- | --- |
| `text` | 表示する語。複数語は空白で連結する |
| `reading_0..n` | 語の位置ごとの読みの配列（dynamic_templates により keyword になる）。検索はここに対して行う |
| `docFreq` / `queryFreq` | 文書由来 / 検索由来の出現回数（登録のたびに加算する） |
| `userBoost` / `score` | 手動ブースト値 / 事前計算スコア `(queryFreq+docFreq)*userBoost` |
| `kinds` | `document` / `query` / `user`（elevate word）。複数の値を持てる |
| `fields` / `tags` / `roles` / `languages` | 元のフィールド、タグ（label・virtual_host）、ロール（空なら `_guest_`）、言語 |
| `@timestamp` | 最終更新時刻（purge の判定に使う） |

### 4.3 SuggestItem と ID

- [確認] `SuggestItem` は、全フィールドに setter がある可変の POJO である。種別は `Kind{DOCUMENT, QUERY, USER}`（`entity/SuggestItem.java:42-140`）。source への変換・マージは `SuggestItemSerializer` と `SuggestItemMerger` に分離されている。
- [確認] `_id` は `Base64(text)` で、445 文字を超えると切り詰める（`util/SuggestUtil.java:77,93-99`）。同じ語は常に同じドキュメントに集約されるので、頻度を加算していける。[推測] 非常に長い語では、切り詰めによって ID が衝突しうる。
- [確認] 既存ドキュメントとのマージ規則（`SuggestItemSerializer.java:142-184`）:
  - 読み・fields・tags・roles・languages・kinds は和集合にする。
  - freq は加算する。
  - userBoost と timestamp は新しい値で上書きする。

## 5. 主要フロー

### 5.1 登録

```
SuggestIndexer.xxx() ─▶ ContentIndexingOperations ─▶ ContentsParser.parseXxx ─▶ SuggestItem[]
   ─▶ IndexingOperations.index（bad word を部分一致で除外）─▶ SuggestIndexWriter.write
        ├ mergeItems（同じバッチ内で同じ ID をマージ。O(n²)）
        ├ 1 件ずつ GET して既存 source を取得 ─▶ toUpdatedSource / toSource
        └ bulk index（op_type=INDEX）
```

| 経路 | API | 同期/非同期 | 生成される SuggestItem | fess での利用 |
| --- | --- | --- | --- | --- |
| 文書 | `indexFromDocument(Supplier<DocumentReader>, docPerReq, waitController)` | 非同期（threadPool で実行し、`Promise` を返す。バッチごとに refresh） | 対象フィールドを `_analyze` でトークン化し、1 トークン = 1 件（DOCUMENT, docFreq=1） | `SuggestCreator` のバッチ処理 |
| 検索語 | `indexFromSearchWord(word, fields, tags, roles, num, langs)` | 同期 | 空白で区切った語の列 = 1 件（QUERY, queryFreq=num） | 検索ログを保存するときにリアルタイムで呼ぶ。バッチの再構築でも呼ぶ |
| クエリログ | `indexFromQueryLog(QueryLog…/QueryLogReader)` | 同期 / 非同期 | Lucene のクエリ文字列を解析し、フィールドごとに 1 件（QUERY） | **未使用** |
| elevate | `addElevateWord(ElevateWord, apply)` / `restoreElevateWord()` | 同期 | USER（userBoost 付き） | 管理画面 |
| bad word | `addBadWord(word, apply)` | 同期 | —（設定に保存し、apply なら `*word*` の wildcard で削除） | 管理画面 |
| 直接 | `index(SuggestItem[])` | 同期 | 呼び出し側が用意する | 未使用 |

- 根拠 [確認]:
  - `index/operations/ContentIndexingOperations.java:131-359,395-434`
  - `index/contents/DefaultContentsParser.java:78-210`
  - `index/writer/SuggestIndexWriter.java:45-80`
  - `index/operations/WordManagementOperations.java:77-156`
- [確認] 文書の本文は `fess.suggest.max.analyzed.content.length`（システムプロパティ、既定 1000 文字）ごとに分割して `_analyze` する。解析エラーの握りつぶしは 2 か所ある。
  - パーサ側は、チャンク単位で `OpenSearchStatusException` / `IllegalStateException` を原因を問わず warn ログだけ出して捨てる（`DefaultContentsParser.java:75,261-309`）。
  - `ContentIndexingOperations` 側は、`index.analyze.max_token_count` 超過のときに限り、その文書を捨てる（`ContentIndexingOperations.java:265-271`）。

### 5.2 検索（suggest / popular words）

```
suggest().setQuery(q)...execute() ─▶ SuggestRequest.processRequest
  ├ SuggestQueryBuilder.buildQuery: 空白で分割し、語ごとに normalize → readingConverter（ここで _analyze 呼び出し）
  │    reading_i に対して bool(should)。最後の語かつ末尾が空白でなければ prefix、それ以外は term
  ├ function_score: text の prefix 一致 × prefixMatchWeight（単語 1 つで非ひらがなのとき）
  │    × log2p(docFreq) × log2p(queryFreq) × userBoost（boostMode=REPLACE, scoreMode=MULTIPLY）
  ├ filter: tags / roles（常に _guest_ を追加）/ fields / kinds
  └ 非同期で search ─▶ SuggestResponseCreator（重複語の除去、クエリ一致語を先頭へ）─▶ Deferred.resolve
```

- [確認] 根拠: `request/suggest/SuggestRequest.java:329-391`、`SuggestQueryBuilder.java:72-166`。
- [確認] 既定値は `size=10`、`suggestDetail=true`、`prefixMatchWeight=2.0`、`matchWordFirst=true`、`skipDuplicateWords=true`（`SuggestRequest.java:91-113`）。`skipDuplicateWords` が有効なら `size*2` 件を取得する。
- [確認] `languages` は読み変換にだけ使い、フィルタには使わない（`SuggestRequest.java:346-365`）。
- [確認] popularWords の処理（`request/popularwords/PopularWordsRequest.java:211-246`）:
  - 条件は kinds=query、`reading_1` が無い（= 1 語）、`queryFreq >= threshold`。
  - スコアは queryFreq。`windowSize` の範囲を random_score（seed、`_seq_no`）で rescore して、表示をばらつかせる。
  - roles が空のときだけ `_guest_` を使う。suggest（常に追加）と挙動が異なる。

### 5.3 インデックス管理

| API | 動作 | 根拠 |
| --- | --- | --- |
| `createIndexIfNothing()` | 検索用エイリアスが無ければ、新しい物理 index を両エイリアス付きで作る | `Suggester.java:196-230` |
| `createNextIndex()` | 新しい物理 index を作り、**更新用エイリアスだけ**を付け替える | `Suggester.java:235-277` |
| `switchIndex()` | 各エイリアスがちょうど 1 index を指すことを検証してから、検索用エイリアスを更新用 index に原子的に付け替える | `Suggester.java:282-334` |
| `removeDisableIndices()` | `GET *` で全 index を取得する。名前が `index` で始まり、エイリアスの無い index を削除する | `Suggester.java:339-360,485-487` |
| purge | ライブラリ: `deleteOldWords`（USER 以外）、`deleteDocumentWords` / `deleteQueryWords` は 2 段階で動く。他の kind を持たない語は delete-by-query で削除し、残りの語は該当 kind を外して freq を 0 に更新する。fess はこれらを使わず、独自クエリで `SuggestUtil.deleteByQuery` を直接呼ぶ | `DeletionOperations.java:162-212`、`fess:helper/SuggestHelper.java:308-331`、`fess:exec/SuggestCreator.java:236-238,306-320` |

- [確認] 削除と走査は、すべて PIT + `search_after` で行う（`util/PitOperationHelper.java:123-147`、#97）。
  - delete-by-query は、500 件ずつ ID を取得して bulk delete し、最後に refresh する（`SuggestUtil.java:341-360`）。
  - PIT の keepAlive には `scrollTimeout` 設定を流用している（`PitOperationHelper.java:173-175`）。

fess の再構築バッチ（`fess:exec/SuggestCreator.java:248-301`）は、次の順で処理する。

```
createNextIndex → storeAllBadWords / storeAllElevateWords → indexFromDocuments（文書を全件）
  → storeSearchLog（検索ログを再投入）→ switchIndex → removeDisableIndices → purge（古い DOCUMENT / QUERY 語）
```

### 5.4 設定（SuggestSettings）

- [確認] `SuggestSettingsBuilder` が設定用 index 名（既定 `fess_suggest`）、初期値、タイムアウト 6 種を受け取る。タイムアウトの既定は search 15s、index / bulk / indices / cluster / scroll 1m（`settings/TimeoutSettings.java`）。
- [確認] `SuggestSettings.init()` の動作（`SuggestSettings.java:182-263`）:
  - 設定ドキュメントが無ければ、index を作成して既定値・初期値を upsert する。
  - 同時に初回起動した場合（`resource_already_exists` や 503）は許容する（#100）。
  - 続いて `AnalyzerSettings.init()` がアナライザ用 index を用意する。
- [確認] `get(key)` は毎回 OpenSearch に GET を発行し、キャッシュしない（`SuggestSettings.java:271-279`）。`set` は update（upsert）のたびに refresh する（`:341-383`）。

## 6. 横断的関心事

| 観点 | 現状 [確認] | 根拠 |
| --- | --- | --- |
| 非同期モデル | 独自の `Deferred` / `Promise`（`then` / `error` / `getResponse(timeout)`。既定 1 分）。検索は常に非同期で、`ActionListener` から resolve する。登録は Reader 系の 2 メソッドだけが threadPool で動く。fess は結局 `getResponse()` で同期的に待っている | `concurrent/Deferred.java:52-235`、`request/Request.java:41-54` |
| 例外 | RuntimeException が 3 種ある。失敗の伝え方は「例外を投げる」と「`Response.getErrors()` に積む」が混在している。bulk の部分失敗は errors に、それ以外は例外になる | `IndexingOperations.java:77-92`、`SuggestIndexWriter.java:69-79` |
| エラーの型の不統一 | suggest の失敗は `SuggesterException` に包むが、popularWords は例外をそのまま reject する | `SuggestRequest.java:386-389`、`PopularWordsRequest.java:195-198` |
| スレッド | `Suggester` が保持する固定サイズのプール（`shutdown()` で `shutdownNow`）。`SuggestIndexer` は `indexer()` のたびに生成し、状態（badWords など）をインスタンスに持つ | `Suggester.java:185-190,366-368` |
| プールの破棄 | fess は `Suggester.shutdown()` を呼んでいない（`modules/fess/src/main` を grep して確認）。プールはプロセス終了まで残る | — |
| アナライザ / 読み | 正規化・読み・トークン化は、**すべて OpenSearch の `_analyze` への同期 HTTP 呼び出し**で行う。言語別のアナライザ名は、`AnalyzerSettings` の **static な** Map キャッシュ（キーは index 名）で解決する | `settings/AnalyzerSettings.java:111,113,161-162,186-187,384-425`、`converter/AnalyzerConverter.java:123-160` |
| ICU 非依存化 | ひらがな→カタカナ、全角→半角、小文字化は `TransliteratorUtil` を JDK だけで実装している（#99）。`ICUNormalizer` だけが icu4j（optional）を必要とする | `util/TransliteratorUtil.java`、`normalizer/ICUNormalizer.java` |
| 設定の保存先 | 全設定を OpenSearch の設定用 index 群（§4.1）に置く。fess 側の `fess_config.properties`（`suggest.*`）は、fess が値を読んで API 引数に渡すだけ | `fess:helper/SuggestHelper.java:133-155` |
| 外部設定 | システムプロパティ `fess.dictionary.path`（アナライザ JSON 内のパスを置換）と `fess.suggest.max.analyzed.content.length` | `AnalyzerSettings.java:315-326`（同じ置換が `SuggestSettings.java:531-542`、`ArraySettings.java:374-384`、`util/SettingsResourceLoader.java:111-125` にもある）、`DefaultContentsParser.java:75` |

## 7. fess 本体からの利用と、互換性を保つべき境界

### 7.1 利用箇所

fess-suggest を import しているのは main の **3 ファイルだけ**である。他のクラスは、すべて `SuggestHelper` を経由する。

| fess 側 | 用途 | 主な呼び出し |
| --- | --- | --- |
| `helper/SuggestHelper`（中心） | 初期化、検索ログの反映、文書の取り込み、purge、件数、bad/elevate の管理 | `:134-155` build と settings、`:251` indexFromSearchWord、`:272-297` indexFromDocument + ESSourceReader、`:308-331` deleteByQuery、`:340-358` 語数、`:367-397` delete*、`:438-531` elevate / bad、`:539` refresh |
| `exec/SuggestCreator`（`job/SuggestJob` が別 JVM で起動） | 日次の再構築と purge | `:252` createNextIndex、`:298` switchIndex、`:301` removeDisableIndices |
| `helper/SearchLogHelper` | 検索のたびのリアルタイム反映 | `:488` `SuggestHelper.indexFromSearchLog` |
| `api/v2/handlers/SuggestWordsHandler` | `/api/v2/suggest-words` | `:76-119` suggest() ビルダーと `SuggestResponse` / `SuggestItem` の getter |
| `helper/PopularWordHelper` | 人気語（Guava キャッシュ付き） | `:109-121` popularWords() ビルダー |
| 管理画面 `Admin{Suggest,Badword,Elevateword}Action` と API 版 | 語数、削除、NG ワード、優先語 | `SuggestHelper` の wrapper だけを呼ぶ |

### 7.2 fess が依存している公開 API（リファクタリングで互換を保つべき境界）

| 型 | fess が使うメンバ |
| --- | --- |
| `Suggester` | `builder()`, `settings()`, `indexer()`, `suggest()`, `popularWords()`, `createIndexIfNothing()`, `createNextIndex()`, `switchIndex()`, `removeDisableIndices()`, `refresh()`, `getIndex()`, `getAllWordsNum()`, `getDocumentWordsNum()`, `getQueryWordsNum()` |
| `SuggesterBuilder` | `settings(SuggestSettingsBuilder)`, `build(Client, String)` |
| `SuggestSettings` / `SuggestSettingsBuilder` | `builder()`, `array()`, `badword()`, `DefaultKeys.SUPPORTED_FIELDS` / `addInitialSettings`, `setSettingsIndexName`, `{bulk,cluster,index,indices,search}Timeout` |
| `ArraySettings` / `BadWordSettings` | `add(key,value)`, `delete(key)` / `deleteAll()` |
| `SuggestIndexer` | `indexFromSearchWord(6 引数)`, `indexFromDocument(Supplier, int, Runnable)`, `deleteAll()`, `deleteDocumentWords()`, `deleteQueryWords()`, `addElevateWord`, `deleteElevateWord`, `addBadWord`, `deleteBadWord` |
| `ESSourceReader` | コンストラクタ `(Client, SuggestSettings, String)`, `setScrollSize`, `setLimitDocNumPercentage`, `setLimitNumber`, `setLimitOfDocumentSize`, `setQuery`, `addSort` |
| `SuggestRequestBuilder` / `SuggestResponse` | `setQuery`, `addField`, `setSize`, `addLang`, `addTag`, `addKind`, `execute().getResponse()` / `getItems`, `getNum`, `getTotal`, `getTookMs` |
| `PopularWordsRequestBuilder` | `setSize`, `setWindowSize`, `setQueryFreqThreshold`, `setSeed`, `addTag`, `addRole`, `addField`, `addExcludeWord`, `execute().getResponse().getItems()` |
| エンティティ・その他 | `SuggestItem.getText/getTags`, `SuggestItem.Kind`, `ElevateWord(6 引数)`, `SuggestDeleteResponse.hasError/getErrors`, `FieldNames.TIMESTAMP/KINDS`, `SuggestUtil.deleteByQuery`, `SuggesterException`, `SuggestSettingsException`, `Deferred.Promise.then/error/getResponse` |

- [確認] fess のテスト `SuggestHelperTest` は、継承を使わない独立クラス `MockSuggestIndexer`（`:539-571`）を持ち、その中で `ElevateWord` 型を完全修飾名で参照している（`:560`）。`SuggestHelper.suggester()` も使っている（`:62`）。いずれも `modules/fess/src/test/java/org/codelibs/fess/helper/` 配下。
- [確認] 境界の上で OpenSearch の型（`Client`、`QueryBuilder`、`SortBuilder`）がそのまま行き来している。fess も `org.codelibs.fesen.opensearch.*` を import しているので、**fesen-httpclient のバージョンは両モジュールで一致させる必要がある**（`fess:helper/SuggestHelper.java:58-63`）。
- [確認] 境界でもう一つ暗黙に共有されているのが、**インデックスのスキーマ**（フィールド名と kinds の値）である。fess は `FieldNames` と `Kind` を使って purge のクエリを自前で組み立てている。
- [推測] 管理画面でアナライザ設定を扱っていないため、`AnalyzerSettings` 系は事実上、内部 API として扱ってよい。

## 8. テストの現状

- [確認] 構成: JUnit 4、テストクラス 53、`@Test` 660 件。このうち 26 ファイルが組み込み OpenSearch（`SuggestTestServer`: `OpenSearchRunner` + fesen `HttpClient` + 同梱の `ExtensionPlugin`）を起動する結合テストである。
  - kuromoji などのアナライザプラグインは、テストソース側 `org.codelibs.opensearch.extension.*`（26 ファイル。テストクラスではない）に同梱している（#98 以降）。
- [確認] 実行方法:
  - 全件: `cd modules/fess-suggest && mvn test`
  - 個別: `mvn test -Dtest=SuggesterTest`
  - カバレッジ: `mvn clean jacoco:prepare-agent test jacoco:report`
  - 本調査ではテストを実行していない（既存の `target/surefire-reports` は 2026-08-24 のもの）。
- [確認] カバー範囲の概観:
  - Suggester のライフサイクル（`SuggesterIndexLifecycleTest`、`SuggesterRefactoringTest`）
  - 登録（`SuggestIndexerTest`、`...ErrorHandlingTest`）
  - パーサ（通常ケースと境界ケース）
  - クエリ構築（`SuggestRequestQueryBuildingTest`）
  - エンティティとシリアライズ
  - 設定の同時作成（`SettingsIndexCreationRaceTest`）
  - PIT（`PitOperationHelperTest`）
  - ICU との等価性（`TransliteratorUtilTest`）
- [確認] 空のテスト（TODO のままコメントアウト）: `KatakanaConverterTest`、`ReadingConverterChainTest`。
- [確認] JUnit 3 形式（`extends TestCase`）のテストが 6 クラス・48 メソッドあり、JUnit 4 形式と混在している。
- [推測] fess 側の結合（`SuggestHelper` → 本ライブラリ）は、fess の `SuggestHelperTest` 以外に自動テストが無い。
- [提案] リファクタリング前に、§7.2 の境界 API に対する I/O 契約テスト（入力→index の状態→suggest の結果）を固定する。

## 9. リファクタリング観点での所見

重要度の高い順に並べる（**事実**と**提案**を分けて書く）。

1. **テキスト処理が OpenSearch の `_analyze` に強く結合している**
   - [確認] 正規化・読み・トークン化のすべてが同期 HTTP 呼び出しになる。suggest 1 回ごとに「語数 × 言語数 × 3 回」の `_analyze` が検索の前に走る。内訳は `AnalyzerNormalizer` が 1 回、`LangAnalyzerConverter` が reading 用と reading-term 用で 2 回（`normalizer/AnalyzerNormalizer.java:59-72`、`converter/AnalyzerConverter.java:88-145`）。
   - [確認] 文書の取り込みでは、1000 文字のチャンクごとに 2 回（通常 + reading）呼ぶ。トークン数が一致しないときは、トークンごとに `readingConverter`（`_analyze` を含む）へフォールバックする（`DefaultContentsParser.java:173-193`）。
   - [提案] テキスト処理をポート（IF）として切り出し、OpenSearch 実装とローカル実装を差し替えられるようにする。まずは計測を先に行う。
2. **書き込みが N+1 で、read-modify-write になっている**
   - [確認] `SuggestIndexWriter` は 1 件ずつ GET し、マージしてから INDEX する（`SuggestIndexWriter.java:54-66`）。
   - [確認] 同じバッチ内のマージは O(n²)（`SuggestWriter.java:76-102`）。
   - [推測] 並行して書き込むと（リアルタイムの検索ログとバッチなど）、加算が失われうる（楽観ロックなし）。
   - [提案] multi-get、または scripted upsert / `_update` への置き換えを検討する。
3. **設定アクセスのコストと、状態の持ち方**
   - [確認] `SuggestSettings.get` は毎回 GET を発行する。`indexer()` は呼ぶたびに新しい `SuggestIndexer` を作り、そのコンストラクタで設定 GET 4 回と配列設定の検索 2 回を行う。fess はこれを検索ログ 1 件ごとに呼ぶ（`SuggestIndexer.java:174-198`、`fess:helper/SuggestHelper.java:251`）。
   - [確認] `deleteBadWord` は、インスタンスが持つ `badWords` を更新しない（`addBadWord` は更新する。`SuggestIndexer.java:395-409`）。
   - [確認] `AnalyzerSettings` のキャッシュはプロセス全体で共有する static である。
   - [提案] 設定をスナップショット（不変オブジェクト）として読み込み、明示的に再読み込みするモデルにする。
4. **ファサードが肥大化し、責務が重複している**
   - [確認] `Suggester` にライフサイクル・検索・語数・部品保持が同居している。`SuggestIndexer` は 4 つの Ops へ委譲するだけのファサードで、setter で部品を差し替えると Ops を作り直す（`operationsStale`、`SuggestIndexer.java:161,216-220`）。
   - [確認] `ContentIndexingOperations` には、`ContentIndexingContext` 導入前の旧シグネチャのオーバーロードが残っている（`:118,170,237,302,375`。main からの呼び出しは無い）。
   - [提案] 「インデックスのライフサイクル」「登録」「検索」「設定」の 4 つのサービスに分ける。`Suggester` は互換用の薄いファサードとして残す。
5. **境界（公開 API）が広すぎて曖昧**
   - [確認] ほぼ全クラスが public で、protected フィールドを持つ。OpenSearch の型が API に露出している（§7.2）。
   - [確認] fess は `SuggestUtil.deleteByQuery` と `FieldNames` を使って purge を自前で実装している。ライブラリ側の `deleteOldWords` とは条件が異なる。
   - [提案] fess が使う API（§7.2）を「公開 API」として明文化し、それ以外を package-private や internal へ縮める。purge はライブラリの API に寄せる。
6. **非同期・エラーのモデルが独自で、一貫していない**
   - [確認] `Deferred` は独自実装で、`resolve` 内のコールバック例外を握りつぶす（`Deferred.java:91-93`）。失敗の伝え方は、例外と `getErrors()` が混在している（§6）。
   - [提案] `CompletableFuture` への移行を検討する（`Promise` は互換アダプタで残す）。失敗の伝え方を統一する。
7. **挙動の非対称・潜在的な不具合**（機能変更に当たるかは要判断）
   - [確認] roles の既定値の扱いが、suggest と popularWords で異なる（§5.2）。
   - [確認] `removeDisableIndices` は `startsWith(index)` で対象を判定している。同じプレフィックスを持つ別の index も削除対象になりうる（`Suggester.java:485-487`）。
   - [確認] `restoreElevateWord` は `addElevateWord` を再利用しているため、設定 index へも再保存してしまう（`WordManagementOperations.java:148-151`）。
   - [確認] bad word の判定と削除は部分一致である（`SuggestItem.java:455-461`、`WordManagementOperations.java:81`）。
8. **デッドコード・命名の負債**
   - [確認] `SuggestBulkFileWriter`（全メソッドが `UnsupportedOperationException`）。
   - [確認] `SuggestUtil.createBulkLine`（`_type` を使う旧形式。テストからのみ参照）。
   - [確認] `SuggestSettings.badWordIndexName` / `elevateWordIndexName`（`-badword` という名前で、実際の `_badword` と食い違い、どこからも使われていない。`SuggestSettings.java:132-134,175-176`）。
   - [確認] `SuggestItem.convertJsonString(s)`（private で未使用）、`emptySource` / `toEmptyMap`（マージ時にしか受け渡されない）。
   - [確認] `SuggestRequest` の `@Deprecated` 委譲メソッド群、`SuggestSettings.TimeoutSettings`（Deprecated）、`KatakanaConverter`（既定の構成では未使用で、テストも TODO のまま）。
   - [確認] `util/SettingsResourceLoader`（main から参照されていない）。
   - [確認] `fess.dictionary.path` を置換する処理が 3 か所で重複している（`AnalyzerSettings.java:315-326`、`SuggestSettings.java:531-542`、`ArraySettings.java:374-384`）。共通化のために用意されたとみられる `SettingsResourceLoader` は使われていない。
   - [確認] クエリログ経路（`indexFromQueryLog`、`QueryLog*`、`SuggestUtil.parseQuery` による Lucene の解析）は fess から使われていない。
   - [確認] 命名の負債: `contentsReadigConverter`（typo、`SuggesterBuilder.java:98`）、`scrollTimeout` を PIT の keepAlive に流用、`ESSourceReader` の `setScrollSize`、`maxContentLenth`。
   - [提案] 公開 API（§7.2）に含まれないものから順に削除・改名する。
9. **設定とスキーマの管理が分散している**
   - [確認] サジェスト index の mapping と settings は JAR 内の JSON で固定されている。スキーマのバージョン管理や移行の仕組みは無く、再構築（`createNextIndex`）が事実上の移行手段になっている。
   - [確認] 設定用 index が 5 つに分かれている（§4.1）。
   - [提案] 設定用 index の統合は、データ移行を伴う機能変更になる。今回のリファクタリングの範囲外とし、設計書に課題として記録するにとどめる。

## 10. legacy 資料（15.7.1-SNAPSHOT 時点）との主な差異

| 項目 | 15.7.1 時点（legacy 資料・当時の実装） | 現行（15.9.0-SNAPSHOT） |
| --- | --- | --- |
| 検索エンジン API | `org.opensearch:opensearch` に依存し、`org.opensearch.transport.client.Client` を使う | fesen-httpclient のフォークパッケージ `org.codelibs.fesen.opensearch.*`（#98）。fess 側も同じパッケージ |
| 全件走査・削除 | scroll | PIT + `search_after`（#97、`PitOperationHelper`）。`scrollTimeout` は keepAlive として残る |
| ICU4J | 読み変換に必須 | `TransliteratorUtil` で JDK だけで実装し、icu4j は optional（#99） |
| 設定 index の初期化 | 競合時の考慮は記述なし | 同時に初回起動した場合の `resource_already_exists` や 503 を許容する（#100） |
| `suggestDetail` の既定 | legacy 5.3 では「未確定」、legacy `03-suggest-contents.md:78` では「既定 false」 | `true`（`SuggestRequest.java:103`）。fess が `getItems()` を使えるのはこのため。15.7.0 のリリース時点でも `true` だったので、legacy の「既定 false」は作成当時から誤り |
| 行番号 | `Suggester.java`、`fess/pom.xml:1401` など | おおむね近いが、ずれている箇所がある（例: fess の依存宣言は `pom.xml:1363`）。legacy の行番号は参考程度に扱うこと |
| クエリログ経路が未使用（legacy 5.1） | 未使用 | 現在も未使用（変わらず） |
