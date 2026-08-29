# fess-suggest 改善後 API インタフェース仕様書（To-Be API IF）

> 本書は fess-suggest 抜本的改善提案タスク（`20260622_improvement_proposal`）の成果物 **`0014-improvement-proposal.md`（改善提案）** を入力として、To-Be アーキテクチャ（`0005`）が定義する **公開 API・拡張点・ストレージ抽象の具体的なインタフェース定義**を1枚に集約した「API IF 書」である。
>
> - **位置づけ**: 改善提案（意思決定材料）を、実装着手前に合意すべき **API 契約（シグネチャ・引数・戻り値・同期/非同期・例外・互換性）** の粒度へ具体化したもの。
> - **本書は「To-Be の目標 API 契約」であり、実装指示でも最終確定でもない**。移行は段階的（`0014` §4 / `0013`）であり、各 IF は MIG 単位で漸進的に到達する。確定できない箇所は **[要確認]** として残す（特に TBD-01: OpenSearch/Lucene 数値バージョン未解決）。
> - 設計判断の根拠は `0005` §（To-Be 設計）、`0014` §（提案集約）、MIG-xx（`0013` 移行単位）、ISS-xx（`0002` 課題）で辿れる。現行シグネチャは `modules/fess-suggest/src/main/java/...:line` を出典とする。

## 凡例（`0014` と同一）

| 凡例 | 意味 |
| --- | --- |
| **[事実]** | コード確認済みの現行仕様（`file_path:line` / ISS / TBD 番号で出典明示） |
| **[提案]** | 本タスクの To-Be API 契約の提案（最終判断はユーザー） |
| **[要確認]** | TBD（特に TBD-01）に依存し断定できない箇所 |

- 言語前提: **Java 21+**（`record` / sealed / パターンマッチ使用）[事実]、Maven、検索エンジン **OpenSearch 系** [事実]。
- 本書のコードはすべて **API 契約を示すための擬似シグネチャ**であり、パッケージ名・補助メソッド・例外階層の細部は実装時に確定する。
- パッケージ規約 [提案]: 公開 API は `org.codelibs.fess.suggest.api`（仮）、拡張点抽象は `org.codelibs.fess.suggest.spi`（仮）、実装は `...internal`（非公開）。**`internal` 配下は fess 本体から直接参照しない**（`0005` §3.2「公開しないものは内部に隠す」の契約化）。

---

## 1. API 全体マップ

`0005` §2 / §3.2 の「用途別4インタフェース＋横の拡張点＋ストレージ抽象」を API 境界として確定する。

```
 fess本体 (Consumer)
   SuggestCreator(バッチ) / 起動初期化 ─────► SuggestIndexLifecycle   ┐
   SuggestWordsHandler(検索API) ───────────► SuggestQueryService       │ 公開API (api)
   管理画面 ───────────────────────────────► SuggestWordAdmin          │  §2
   バッチ再構築 / 検索ログ反映 ─────────────► SuggestIngestService      ┘
        │
        ▼  （以下は内部。fess本体は直接触らない）
 Domain Core (spi: 拡張点)  §3
   SuggestSource           … サジェスト語の供給（DOCUMENT/SEARCH_WORD/ELEVATE/[新]SYNONYM/SEMANTIC）
   ScoringStrategy         … 検索時ランキング単系統の構成
   TextProcessor (Chain)   … 正規化→読み変換→解析（踏襲資産）
   SuggestItemMergePolicy  … マージ規則の単一の真実
   AuthorizationFilter     … 権限条件の単一の真実（デフォルト deny）
        │
        ▼
 Storage Abstraction (spi)  §4
   SuggestStore            … OpenSearch 実装を差し替え可能に隔離
        │
        ▼
   OpenSearch  [要確認] TBD-01
```

| 層 | インタフェース | 本書 § | 主担当の `0005`/`0014` § | 主な MIG |
| --- | --- | --- | --- | --- |
| 公開API | `SuggestIndexLifecycle` | §2.1 | `0005` §3.2/§6.2.3 | MIG-06 |
| 公開API | `SuggestQueryService` | §2.2 | `0005` §3.2/§9.2 | MIG-06,02,14 |
| 公開API | `SuggestWordAdmin` | §2.3 | `0005` §9.3 | MIG-03,13 |
| 公開API | `SuggestIngestService` | §2.4 | `0005` §4.2/§7.2 | MIG-06,07,15,16 |
| 拡張点 | `SuggestSource` | §3.1 | `0005` §4.2 | MIG-07,19,20,24 |
| 拡張点 | `ScoringStrategy` | §3.2 | `0005` §9.2 | MIG-11 |
| 拡張点 | `TextProcessor` | §3.3 | `0005` §5.2 | MIG-12,23 |
| 拡張点 | `SuggestItemMergePolicy` | §3.4 | `0005` §7.2.1 | MIG-01 |
| 拡張点 | `AuthorizationFilter` | §3.5 | `0005` §10.2 | MIG-09 |
| ストレージ | `SuggestStore` | §4 | `0005` §2/§6/§7.2.2 | MIG-15,17 |
| DTO/型 | `SuggestItem` 他 | §5 | `0005` §4.2/§6.2.1 | MIG-02,04 |
| 並行 | `CompletableFuture` 規約 | §6 | `0005` §8.2 | MIG-08 |

**設計の柱（`0014` §1.2 の7原則を API に焼き込む）**:
- 公開面は4インタフェースの必要メソッドのみ（現行 `Suggester` public ~18 + `SuggestIndexer` public ~28 を統合・縮小）。ISS-13/17 を構造的に回避。
- I/O を伴う操作は **非同期（`CompletableFuture`）が基本**、同期版は `.join()` ラッパとして一箇所で提供（§6）。ISS-09 回避。
- detail 取得は **メソッド名・戻り値型から自明**（暗黙の既定値結合を作らない）。ISS-03 回避。

---

## 2. 公開 API（用途別4インタフェース）

### 2.1 `SuggestIndexLifecycle` — インデックスのライフサイクル

**責務**: インデックス作成・世代切替・破棄・エイリアス管理。二重エイリアス（検索/更新）ゼロダウンタイム再構築（KEEP-02）を露出面に限定して提供する。
**主な利用者**: `SuggestCreator`（バッチ）、起動時初期化。
**As-Is 対応** [事実]: `Suggester.createIndexIfNothing()/createNextIndex()/switchIndex()/removeDisableIndices()/refresh()/getIndex()/getAllWordsNum()/getDocumentWordsNum()/getQueryWordsNum()`（`Suggester.java:196-442`）。

```java
public interface SuggestIndexLifecycle {

    /** 既存が無ければ初期インデックス＋二重エイリアスを作成。作成したら true。 */
    boolean createIndexIfNothing();

    /** 次世代インデックス {base}.{timestamp} を構築（更新エイリアスのみ向ける）。世代ハンドルを返す。 */
    IndexGeneration createNextIndex();

    /** 検索エイリアスを最新世代へ原子的に切替（ゼロダウンタイム再構築の確定）。 */
    void switchIndex();

    /** 無効化済み（旧世代）物理インデックスを削除。 */
    void removeDisableIndices();

    /** 反映を確定（refresh 相当）。 */
    CompletableFuture<Void> refresh();

    /** 現在の検索エイリアスが指す物理インデックス名。 */
    String currentIndexName();

    /** 登録語数の統計（種別別内訳つき）。As-Is の getAllWordsNum/getDocumentWordsNum/getQueryWordsNum を1メソッドに集約。 */
    WordCountStats wordCountStats();
}

/** 世代ハンドル（物理インデックス名と作成時刻）。[提案] */
public record IndexGeneration(String physicalIndexName, java.time.Instant createdAt) {}

/** 語数統計。Kind ごとの内訳を Map で保持し、種別追加に強い構造にする。[提案] ISS-12 関連 */
public record WordCountStats(long total, java.util.Map<SuggestItem.Kind, Long> byKind) {}
```

**設計メモ**:
- [提案] `getDocumentWordsNum()/getQueryWordsNum()` の Kind 別個別メソッド（`Suggester.java:432-442`）を `WordCountStats.byKind` に集約。新 Kind（SYNONYM/SEMANTIC）追加時に **API を増やさず**統計が載る（ISS-12 のカバレッジ拡張と整合）。
- [提案] 物理世代管理・エイリアス操作の実体は `SuggestStore`（§4）が担い、本 IF はその責務を露出面に限定（`0005` §6.2.3）。
- **互換影響**: fess 本体 `SuggestCreator` / 起動初期化が呼ぶ。MIG-06 で同期改修（`0014` §5.3）。

### 2.2 `SuggestQueryService` — サジェスト検索・人気語取得

**責務**: リアルタイムのサジェスト検索と人気語取得。ランキングは**検索時 function score 単系統**（`0005` §9.2、死蔵 score 非参照）。
**主な利用者**: `SuggestWordsHandler`（検索 API）。
**As-Is 対応** [事実]: `Suggester.suggest()`（`SuggestRequestBuilder` 経由）/`Suggester.popularWords()`（`PopularWordsRequestBuilder` 経由）。`SuggestRequest.suggestDetail=true`（`SuggestRequest.java:103`）への暗黙結合（ISS-03）を解消する。

```java
public interface SuggestQueryService {

    /** 候補語のみを返す軽量版（items を返さない＝detail なし）。返却型から「語だけ」が自明。ISS-03 解消。 */
    CompletableFuture<SuggestWords> suggest(SuggestQuery query);

    /** 候補語＋蓄積属性（SuggestItem）を返す詳細版。メソッド名で detail を返すことが自明。ISS-03/ISS-11 解消。 */
    CompletableFuture<SuggestResult> suggestWithDetail(SuggestQuery query);

    /** 人気語取得（詳細つき）。 */
    CompletableFuture<SuggestResult> popularWords(PopularWordsQuery query);
}
```

入力 DTO（`0005` §3.2「detail を型から自明に」/ ISS-06 権限を `roles` として受領）:

```java
/** サジェスト検索条件。現行 SuggestRequestBuilder の設定群を不変 record に集約。[提案]
 *  出典(As-Is): SuggestRequestBuilder.java:45-158, SuggestRequest.java:87-113 */
public record SuggestQuery(
        String query,                 // 既定 ""
        int size,                     // 既定 10
        java.util.List<String> tags,
        java.util.List<String> roles, // 呼び出しユーザのロール集合（_guest_ 補完は AuthorizationFilter が一元担当: §3.5, ISS-06）
        java.util.List<String> fields,
        java.util.List<String> kinds,
        java.util.List<String> languages,
        float prefixMatchWeight,      // 既定 2.0f（前方一致優先 weight, KEEP）
        boolean matchWordFirst,       // 既定 true
        boolean skipDuplicateWords    // 既定 true
) {
    public static Builder builder() { return new Builder(); }
    /** 任意項目を省略しても安全な既定値を埋めるビルダー（fluent, 後方互換のため）。 */
    public static final class Builder { /* setQuery/size/addTag/addRole/addField/addKind/addLang/... */ }
}

/** 人気語取得条件。出典(As-Is): PopularWordsRequestBuilder.java:39-132 */
public record PopularWordsQuery(
        int size,
        java.util.List<String> tags,
        java.util.List<String> roles,
        java.util.List<String> fields,
        java.util.List<String> languages,
        java.util.List<String> excludeWords,
        String seed,                  // ランダム rescorer 用シード（再現性）
        int windowSize,
        int queryFreqThreshold        // ISS-12: 既定の閾値(>=10) を可変化（MIG-14）
) {
    public static Builder builder() { return new Builder(); }
    public static final class Builder { /* ... */ }
}
```

出力 DTO（**detail の有無を型で分離**）:

```java
/** 軽量版の戻り（語のみ）。ISS-03 解消の中核。[提案] */
public record SuggestWords(String index, long tookMs, long total, java.util.List<String> words) {
    public int num() { return words.size(); }
}

/** 詳細版の戻り。As-Is SuggestResponse/PopularWordsResponse を統合。
 *  出典(As-Is): SuggestResponse.java:54-110 */
public record SuggestResult(String index, long tookMs, long total,
                            java.util.List<String> words,
                            java.util.List<SuggestItem> items) {
    public int num() { return words.size(); }
}
```

**設計メモ**:
- [提案] `suggest`（語のみ） / `suggestWithDetail`（属性つき）の **2メソッド分離**で ISS-03（`suggestDetail=true` 既定値への暗黙結合）を構造的に解消。fess 本体は用途に応じて選ぶ。
- [提案] `roles` は「呼び出しユーザのロール集合を渡す」責務に一本化。`_guest_`（`SuggestConstants.DEFAULT_ROLE`）補完は **ライブラリ内 `AuthorizationFilter` が一元担当**（§3.5）。現行の二重担保（`SuggestRequest.java:352-357` ＋ `SuggestWordsHandler` 側 `addRole`、ISS-06）を解消。**fess 本体側の `addRole` 二重呼び出しは廃止**（MIG-09、互換影響あり）。
- [提案] `SuggestResult.items` は `SuggestItem`（§5）。蓄積属性（reading/kinds/freq/roles）を選択的に露出でき、ISS-11 の死蔵属性を UI 機能（MIG-18）へ転用する素地。
- ランキングは検索時単系統（`0005` §9.2）。**死蔵 `score` フィールドは参照しない**（ISS-14/16、MIG-02）。

### 2.3 `SuggestWordAdmin` — 語管理（bad word / elevate word）

**責務**: bad word・elevate word の管理。**誤削除排除（term 完全一致）と削除前ドライラン**を契約に含める（`0005` §9.3、ISS-04＝唯一の「中〜高」重大度）。
**主な利用者**: 管理画面。
**As-Is 対応** [事実]: `SuggestIndexer.addBadWord(String,boolean)/deleteBadWord(String)/addElevateWord(ElevateWord,boolean)/deleteElevateWord(String,boolean)/restoreElevateWord()`（`SuggestIndexer.java:395-440`）。

```java
public interface SuggestWordAdmin {

    /** bad word を登録し、term 完全一致で該当語を除外する。ISS-04 解消の中核(MIG-03)。
     *  削除は keyword 完全一致(termQuery)で行い、現行の *badword* 部分一致(ワイルドカード)による
     *  不可逆な巻き添え削除を機構から排除する。[提案] */
    CompletableFuture<WordOpResult> addBadWord(String word, boolean apply);

    /** bad word を取り消す。 */
    CompletableFuture<Void> deleteBadWord(String word);

    /** 「この bad word を適用すると何語に影響するか」を実削除せず事前提示する（ドライラン）。
     *  MIG-13/ISS-04 上積み。管理画面で誤操作を防ぐ。[提案] */
    CompletableFuture<BadWordImpact> previewBadWordImpact(String word);

    CompletableFuture<WordOpResult> addElevateWord(ElevateWord word, boolean apply);

    /** elevate word を削除。論理削除(excluded フラグ)を基本とし復元可能にする。[提案/要確認] 容量・クエリコスト */
    CompletableFuture<Void> deleteElevateWord(String word);

    /** 論理削除した語の復元。 */
    CompletableFuture<WordOpResult> restoreElevateWord(String word);
}

/** 語操作の結果（影響件数とエラー）。[提案] */
public record WordOpResult(int affectedDocs, java.util.List<Throwable> errors) {
    public boolean hasError() { return !errors.isEmpty(); }
}

/** ドライラン結果。影響語のサンプルを返し、適用前に確認できる。[提案] MIG-13 */
public record BadWordImpact(long matchedCount, java.util.List<String> sampleWords) {}
```

**設計メモ**:
- [提案] **bad word 削除を `termQuery(TEXT, word)` の完全一致に変更**（現行 `WordManagementOperations` の `wildcardQuery("*badword*")`、ISS-04）。これは局所変更・依存なし・スキーマ変更なしで到達でき、**最優先クイックウィン（MIG-03）**。
- [提案] `previewBadWordImpact` と論理削除（`excluded` フラグ）はゼロベース上積み（MIG-13、`excluded` 追加で**再構築**が必要、`0014` §4.4 Phase 2）。**[要確認]** 論理削除はインデックス容量・クエリコストとトレードオフ（`0005` §9.3）。
- **互換影響**: 管理画面（fess 本体）と連動。ドライラン UI は MIG-13 で追加。

### 2.4 `SuggestIngestService` — 取り込み（ドキュメント・検索語）

**責務**: ドキュメント本文・検索語からサジェスト語を取り込む（バルク・upsert 集約）。
**主な利用者**: バッチ再構築、リアルタイム検索ログ反映。
**As-Is 対応** [事実]: `SuggestIndexer.index()/indexFromDocument()/indexFromSearchWord()/indexFromQueryLog()/delete*/deleteOldWords()`（`SuggestIndexer.java:243-450`）。

```java
public interface SuggestIngestService {

    /** SuggestItem を直接バルク登録（マージ＝SuggestItemMergePolicy §3.4、書き込み＝SuggestStore §4 が担当）。 */
    CompletableFuture<IngestResult> index(java.util.List<SuggestItem> items);

    /** ドキュメント（Map ストリーム）からバルク取り込み。DocumentSource(§3.1) 経由。 */
    CompletableFuture<IngestResult> indexFromDocuments(
            java.util.function.Supplier<DocumentReader> readerSupplier, IngestOptions options);

    /** 検索語からの取り込み（リアルタイム検索ログ反映）。As-Is indexFromSearchWord の引数群を record に集約。 */
    CompletableFuture<IngestResult> indexFromSearchWord(SearchWordInput input);

    /** 任意条件削除（query 文字列 / 構造化条件）。 */
    CompletableFuture<DeleteResult> deleteByQuery(SuggestDeleteCriteria criteria);

    /** 全削除 / 種別削除。 */
    CompletableFuture<DeleteResult> deleteAll();
    CompletableFuture<DeleteResult> deleteByKind(SuggestItem.Kind kind);

    /** 古い語の削除（時刻基準）。 */
    CompletableFuture<DeleteResult> deleteOldWords(java.time.Instant threshold);
}

/** 取り込みオプション。バッチ件数等。ISS-08(per.request=2の極小)を可変・適正化(MIG-16)。[提案/要確認 TBD-04] */
public record IngestOptions(int bulkSize, int parallelism, Runnable onProgress) {
    public static IngestOptions defaults() { /* 適正既定値（実測依存, 要確認） */ }
}

/** 検索語入力。出典(As-Is): SuggestIndexer.indexFromSearchWord(String,String[]...,int,String[]):383 */
public record SearchWordInput(String word, java.util.List<String> fields, java.util.List<String> tags,
                              java.util.List<String> roles, long queryFreq, java.util.List<String> languages) {}

/** 取り込み結果。出典(As-Is): SuggestIndexResponse.java:31-98 */
public record IngestResult(int numberOfSuggestDocs, int numberOfInputDocs,
                           java.util.List<Throwable> errors, long tookMs) {
    public boolean hasError() { return !errors.isEmpty(); }
}

/** 削除結果。出典(As-Is): SuggestDeleteResponse.java:28-66 */
public record DeleteResult(java.util.List<Throwable> errors, long tookMs) {
    public boolean hasError() { return !errors.isEmpty(); }
}
```

**設計メモ**:
- [提案] **`indexFromQueryLog` は標準 API に持たない**（ISS-01 のデッドパス。fess 本体未使用）。将来必要なら `QueryLogSource`（§3.1）を追加するだけで載る「未実装の拡張点」とする（`0005` §4.2）。
- [提案] 書き込みは **`scripted_upsert` による OpenSearch 側原子的集約**を第一候補、**multiGet バルク化**をフォールバックとする（`0005` §7.2.2、MIG-15）。アプリ側 N回同期 Get（`SuggestIndexWriter.java:54-55`、ISS-10）を排除。**[要確認] TBD-01**（upsert/スクリプト集約の利用可否）。利用可否確定まで multiGet 経路を保持。
- [提案] `IngestOptions.bulkSize` で ISS-08（`doc.per.request=2`）を適正化（MIG-16、クイックウィン）。**[要確認] TBD-04**（CPU 負荷調整の設計意図）。
- マージ規則は `SuggestItemMergePolicy`（§3.4）の単一実装に委譲（ISS-05 解消、MIG-01）。

---

## 3. Domain Core 拡張点（spi）

公開 API から呼ばれる内部抽象。**fess 本体は直接実装・参照しない**が、新機能（`0014` §3.5、E1〜E5）はここに実装を足すだけで載る。

### 3.1 `SuggestSource`（拡張点 E1）

**責務**: 「外部入力 → `SuggestItem` ストリーム」への変換のみ。書き込み・集約・スコアリングは共通機構が担う（`0005` §4.2）。

```java
public interface SuggestSource {
    /** 供給する種別。新 Kind を返すだけで新ソースが載る。 */
    SuggestItem.Kind kind();

    /** バッチ/逐次の両対応。Stream で大量データを段階供給。 */
    java.util.stream.Stream<SuggestItem> produce(SourceContext ctx);
}

/** 供給コンテキスト（対象フィールド・言語・進捗等）。[提案] */
public interface SourceContext { /* supportedFields, languages, ... */ }
```

- **標準実装**（internal）: `DocumentSource`(①) / `SearchWordSource`(③) / `ElevateWordSource`(④)。`QueryLogSource`(②) は持たない（ISS-01）。
- **新機能ソース** [提案]: `SynonymSource`/`RelatedWordSource`（MIG-19）、`SemanticSource`（MIG-24、**[要確認] TBD-01** knn/埋め込み）、`TrendSource`（MIG-20）。
- 解消: ISS-01（デッドパスを拡張点化）、ISS-11/12（カバレッジ拡張の素地）。

### 3.2 `ScoringStrategy`（拡張点 E2）

**責務**: 検索時 function score 単系統の構成を抽象化（前方一致 weight・freq modifier・userBoost の効かせ方）。

```java
public interface ScoringStrategy {
    /** 検索時に適用するスコアリング構成を組み立てる（OpenSearch クエリへ反映）。[要確認 TBD-01] */
    ScoringPlan plan(SuggestQuery query, ScoringContext ctx);
}
```

- 解消: ISS-14（検索時単系統に統一・死蔵 score 廃止）、ISS-15（`userBoost<=1` 丸め撤廃・連続値 boost、`SuggestItem.java:131-135`）。
- 新機能 [提案]: セマンティック類似度加点・鮮度 time-decay・パーソナライズ重み・fuzzy 低重み（MIG-11 基盤、MIG-20/21/22/24）。
- **[要確認] TBD-01**: function score / `script_score` の重み設計はバージョン依存。検索時計算 vs 書き込み時計算（案A/案B、`0014` §3.4）の選択は実測依存。

### 3.3 `TextProcessor`（拡張点 E4 / 踏襲資産 KEEP-01）

**責務**: 「テキスト → テキスト/トークン」を Chain（Composite）で合成。現行 Normalizer/ReadingConverter/SuggestAnalyzer を統一抽象化（`0005` §5.2）。

```java
public interface TextProcessor {
    ProcessedText process(String input, TextProcessingContext ctx);
}
```

- **踏襲** [事実]: 既存 `normalizer/`・`converter/`・`analysis/`（計約1,369行、責務分割良好）は再利用。安易な全置換はしない（原則7）。ドキュメント側/クエリ側の二系統（`readingConverter`/`contentsReadingConverter`）も踏襲。
- 新機能 [提案]: 多言語強化（言語判定→言語別 Chain 選択、MIG-23）、タイプミス正規化（MIG-21）。
- 解消: 直接の ISS なし（現状健全）。MIG-12 は「踏襲の明文化」。

### 3.4 `SuggestItemMergePolicy`（単一の真実）

**責務**: マージ規則を**1箇所**に定義（同一バルク内マージも既存doc マージも同一規則）。

```java
public interface SuggestItemMergePolicy {
    /** 集合和(reading/fields/tags/roles/languages/kinds) / 加算(queryFreq/docFreq) / 最新置換(userBoost/timestamp)。 */
    SuggestItem merge(SuggestItem existing, SuggestItem incoming);
}
```

- 解消: ISS-05（現行は `SuggestItemMerger.java:59-96` と `SuggestItemSerializer.java:142-185` の二重実装・走査基準非対称・readings 取りこぼし疑い）。**単一実装化で構造的に解消**（MIG-01、層0で後続 MIG-07/15 の前提）。

### 3.5 `AuthorizationFilter`（単一の真実・デフォルト deny）

**責務**: 「誰がどのロールで検索するか」の権限条件構築を1箇所に集約。

```java
public interface AuthorizationFilter {
    /** 呼び出しユーザのロール集合を検索クエリの権限条件へ反映（_guest_ 補完を含む）。
     *  フェイルセーフ: ロール未指定/受け渡し漏れ時はデフォルト deny（全件露出しない）。[提案] */
    QueryCondition apply(java.util.List<String> roles);
}
```

- 解消: ISS-06（現行は `SuggestRequest.java:354-356` の `_guest_` 補完 ＋ `SuggestWordsHandler.java:83` の `addRole` の二重担保）。
- 責務分担 [提案]: **アプリ（fess 本体）= ロール集合を渡すのみ**／**ライブラリ = 検索クエリへ反映（`_guest_` 補完・deny 既定）**。`0005` §10.2。
- **[要確認]**: fess 本体 `RoleQueryHelper` の責務再配置は連携 API 変更を伴う（MIG-09、`0014` §5.3）。fess 連携部テストは手薄な可能性があり、移行時のテスト補強が必須。

---

## 4. ストレージ抽象 `SuggestStore`（spi）

**責務**: OpenSearch 直結を隔離。インデックス世代・エイリアス・bulk upsert・query を抽象化（`0005` §2/§6/§7.2.2）。OpenSearch 実装は `internal`。

```java
public interface SuggestStore {
    // --- lifecycle（§2.1 が委譲） ---
    boolean createIfAbsent(IndexSchema schema);
    IndexGeneration createNextGeneration(IndexSchema schema);
    void switchSearchAlias();
    void removeDisabledGenerations();
    CompletableFuture<Void> refresh();

    // --- write（§2.4 が委譲。upsert 集約 or multiGet フォールバック） ---
    CompletableFuture<IngestResult> bulkUpsert(java.util.List<SuggestItem> items, SuggestItemMergePolicy policy);
    CompletableFuture<DeleteResult> deleteByCriteria(SuggestDeleteCriteria criteria);

    // --- read（§2.2 が委譲） ---
    CompletableFuture<SuggestResult> search(SuggestQuery query, ScoringPlan scoring, QueryCondition auth);
    CompletableFuture<SuggestResult> popularWords(PopularWordsQuery query, QueryCondition auth);

    WordCountStats wordCountStats();
}

/** インデックススキーマ（シャード/レプリカ可変・死蔵 score なし）。[提案/要確認 TBD-05] */
public record IndexSchema(int numberOfShards, int numberOfReplicas, boolean logicalDeleteField /* excluded */) {}
```

**設計メモ**:
- [提案] **死蔵 `score` フィールドを持たない**（`FieldNames.SCORE` 廃止、ISS-16、MIG-02、再構築）。または「持って必ず使う」案B（`0014` §3.4、**[要確認]** 実測選択）。
- [提案] **シャード/レプリカ可変化**（現行 `number_of_shards=1`/`replicas=0`、ISS-07/TBD-05、MIG-17、再構築）。決定的 ID（`createSuggestTextId`、KEEP-03）のハッシュルーティングで複数シャードでも集約整合。**[要確認] TBD-05**。
- [提案] **`bulkUpsert` は `scripted_upsert` 第一候補／multiGet フォールバック**（ISS-10、MIG-15）。**[要確認] TBD-01**。
- 二重エイリアス再構築（KEEP-02）を `createNextGeneration`/`switchSearchAlias` に閉じ込め。

---

## 5. 共通 DTO・ドメイン型

### 5.1 `SuggestItem`（ドメインの中核）

**As-Is** [事実]: 可変クラス。フィールド text/timestamp/queryFreq/docFreq/userBoost/readings(`String[][]`)/fields/tags/roles/languages/kinds(`Kind[]`)/id（`SuggestItem.java`）。Kind = DOCUMENT/QUERY/USER。

**To-Be** [提案]: **不変 record 化**（マージは `SuggestItemMergePolicy` が新インスタンスを返す＝単一の真実、§3.4）。**`score` を保持しない**（死蔵廃止、ISS-16）。`userBoost` の `<=1` 丸めを撤廃（連続値、ISS-15）。Kind は将来の SYNONYM/SEMANTIC 追加に開く。

```java
public record SuggestItem(
        String text,
        String[][] readings,
        String[] fields,
        long queryFreq,
        long docFreq,
        float userBoost,          // 連続値（<=1 丸めなし, ISS-15）
        String[] tags,
        String[] roles,
        String[] languages,
        Kind[] kinds,
        java.time.Instant timestamp,
        String id                 // 決定的 ID（createSuggestTextId 相当, KEEP-03）
) {
    public enum Kind { DOCUMENT, QUERY, USER /* , [新] SYNONYM, SEMANTIC, TREND ... */ }
    // score フィールドは持たない（ISS-16/14, MIG-02）
}
```

- **互換注記**: As-Is の setter 群（`setText` 等、`SuggestItem.java:235-333`）は record 化で消える。fess 本体が直接 setter を使う箇所があれば MIG-06/07 で同期改修。`merge`/`getUpdatedSource`/`parseSource` はストレージ/マージ層（§3.4/§4）へ移設。

### 5.2 `ElevateWord`

**As-Is** [事実]: フィールド elevateWord/boost/readings/fields/tags/roles（`List<String>`）、`toSuggestItem()`（`ElevateWord.java`）。
**To-Be** [提案]: record 化。`boost` は連続値（ISS-15 整合）。

```java
public record ElevateWord(String word, float boost, java.util.List<String> readings,
                          java.util.List<String> fields, java.util.List<String> tags,
                          java.util.List<String> roles) {}
```

### 5.3 補助型（再掲）

`IndexGeneration`(§2.1) / `WordCountStats`(§2.1) / `SuggestQuery`・`SuggestWords`・`SuggestResult`(§2.2) / `PopularWordsQuery`(§2.2) / `WordOpResult`・`BadWordImpact`(§2.3) / `IngestOptions`・`SearchWordInput`・`IngestResult`・`DeleteResult`(§2.4) / `SuggestDeleteCriteria`(query 文字列 or 構造化条件) / `IndexSchema`(§4)。

---

## 6. 同期／非同期モデル（`0005` §8.2 / ISS-09 / MIG-08）

- [提案] **I/O を伴う操作は `CompletableFuture<T>` を基本**（検索・書き込み・削除・refresh）。同期が必要な箇所は **`.join()` ラッパを1箇所で提供**（例: `Suggesters.sync(service)` 仮）。「このメソッドは同期か非同期か」を毎回調べなくて済む単一規則。
- [事実踏襲]「検索＝非同期」思想（KEEP-04）は維持。変えるのは現行の**不均一さ**（検索のみ非同期・単発登録は同期、ISS-09）。
- [提案] **独自 `Deferred`/`Promise`（`then`/`error`/`getResponse`、`Deferred.java`）を廃止**し標準型へ統一。
- **[要確認]**: fess 本体が独自 `Promise` のコールバック API に依存していれば全面置換の互換影響あり（MIG-08、`0014` §5.2）。確定まではアダプタ併存も可。

---

## 7. As-Is → To-Be API マッピング（移行の対応表）

現行2ファサード（`Suggester` public ~18 / `SuggestIndexer` public ~28）を4インタフェースへ再配置（ISS-13 解消）。

| As-Is（出典） | To-Be IF.メソッド | 備考 / MIG |
| --- | --- | --- |
| `Suggester.createIndexIfNothing()` | `SuggestIndexLifecycle.createIndexIfNothing()` | MIG-06 |
| `Suggester.createNextIndex()` | `SuggestIndexLifecycle.createNextIndex()` | 戻り値に世代ハンドル追加 |
| `Suggester.switchIndex()` | `SuggestIndexLifecycle.switchIndex()` | |
| `Suggester.removeDisableIndices()` | `SuggestIndexLifecycle.removeDisableIndices()` | |
| `Suggester.refresh()` | `SuggestIndexLifecycle.refresh()` | 戻り `CompletableFuture<Void>` 化（§6） |
| `Suggester.getIndex()` | `SuggestIndexLifecycle.currentIndexName()` | 改名（自己説明的） |
| `Suggester.getAllWordsNum()/getDocumentWordsNum()/getQueryWordsNum()` | `SuggestIndexLifecycle.wordCountStats()` | Kind 別 Map に集約（ISS-12 整合） |
| `Suggester.suggest()`（+ `SuggestRequestBuilder`） | `SuggestQueryService.suggest()` / `suggestWithDetail()` | detail を型で分離（ISS-03）、MIG-06 |
| `Suggester.popularWords()`（+ builder） | `SuggestQueryService.popularWords()` | 閾値可変（ISS-12, MIG-14） |
| `Suggester.indexer()` | （廃止） | indexer 取得経由を廃し用途別 IF を直接注入 |
| `Suggester.settings()/getReadingConverter()/getNormalizer()` | （internal 化） | 公開面から除外（`0005` §3.2） |
| `Suggester.shutdown()` | ライフサイクル管理（DI コンテナ/`AutoCloseable`） | [提案] |
| `SuggestIndexer.index(SuggestItem/[])` | `SuggestIngestService.index(List)` | バルク既定化、MIG-15 |
| `SuggestIndexer.indexFromDocument(...)` | `SuggestIngestService.indexFromDocuments(...)` | `IngestOptions`、MIG-16 |
| `SuggestIndexer.indexFromSearchWord(...)` | `SuggestIngestService.indexFromSearchWord(SearchWordInput)` | 引数を record 集約 |
| `SuggestIndexer.indexFromQueryLog(...)` | （廃止＝未実装拡張点） | ISS-01。必要時 `QueryLogSource`(§3.1) |
| `SuggestIndexer.delete/deleteByQuery/deleteAll` | `SuggestIngestService.deleteByQuery()/deleteAll()` | `SuggestDeleteCriteria` |
| `SuggestIndexer.deleteDocumentWords()/deleteQueryWords()` | `SuggestIngestService.deleteByKind(Kind)` | 種別削除に一般化 |
| `SuggestIndexer.deleteOldWords(ZonedDateTime)` | `SuggestIngestService.deleteOldWords(Instant)` | 型を `Instant` へ |
| `SuggestIndexer.addBadWord(String,boolean)` | `SuggestWordAdmin.addBadWord(String,boolean)` | term 一致化（ISS-04, **MIG-03 最優先**） |
| `SuggestIndexer.deleteBadWord(String)` | `SuggestWordAdmin.deleteBadWord(String)` | |
| （新規） | `SuggestWordAdmin.previewBadWordImpact()` | ドライラン（MIG-13） |
| `SuggestIndexer.addElevateWord(...)/deleteElevateWord(...)/restoreElevateWord()` | `SuggestWordAdmin.addElevateWord()/deleteElevateWord()/restoreElevateWord()` | 論理削除化（MIG-13） |
| `SuggestIndexer.setIndexName/setSupportedFields/setRoleFieldName/setReadingConverter/...` | 構築時設定（builder/DI）へ | 実行時 setter を廃し不変構成に |

---

## 8. fess 本体（Consumer）への影響と互換性

API 互換は移行コストの主要因（`0014` §4.1 後方互換3軸の②）。fess 本体側で同時改修・同期リリースが必要な箇所:

| fess 本体 | 影響 | 対応 MIG |
| --- | --- | --- |
| `SuggestHelper` | `Suggester`/`SuggestIndexer` 直呼び → 用途別4 IF へ差し替え | MIG-06 |
| `SuggestWordsHandler` | `suggest()` 呼び出しを `suggest()`/`suggestWithDetail()` に分岐。`addRole` 二重呼び出し廃止 | MIG-06, MIG-09 |
| `RoleQueryHelper` | 権限を `AuthorizationFilter` へ集約（責務再配置） | MIG-09 [要確認] |
| `SuggestCreator` | ライフサイクル IF へ差し替え | MIG-06 |
| 設定基盤（Lasta Config） | 型安全設定（`Duration` 等）化 | MIG-10 [要確認] |
| 管理画面 | bad word ドライラン UI・蓄積属性表示 | MIG-13, MIG-18 |

**移行方針**（`0014` §4.1 戦略B 推奨）: 段階的移行（Strangler Fig）。Phase 1（基盤）で用途別 IF・拡張点・単一規則・標準並行を導入し、過渡的に旧ファサードを新 IF への委譲シムとして一時保持して互換を保つ（ゼロベース最終形にはシムを残さない＝ISS-17）。スキーマ変更系（MIG-02/13/17）は新世代インデックス並行構築＋二重エイリアス切替を併用。

---

## 9. 要確認事項（API 確定前にユーザー判断/前提確認が必要）

| 項目 | 内容 | 影響する IF |
| --- | --- | --- |
| **TBD-01（最重要）** | OpenSearch/Lucene 数値バージョン未解決。`scripted_upsert`/`script_score`/`knn`/`fuzzy` の利用可否 | §4 `bulkUpsert`、§3.2 `ScoringStrategy`、§3.1 `SemanticSource`、§5.1 score の扱い |
| score の扱い（案A/案B） | 死蔵廃止（検索時計算）か sort 用保持（書き込み時計算）か | §4 `IndexSchema`、§5.1 `SuggestItem`、§3.2 |
| 並行基盤の互換 | fess 本体が独自 `Promise` コールバックに依存するか | §6、MIG-08 |
| 権限責務の再配置 | `RoleQueryHelper` と `AuthorizationFilter` の境界 | §3.5、§2.2、MIG-09 |
| 設定の型安全化 | Lasta Config が `Duration`/単位付き文字列を扱えるか | MIG-10（本書では §8 のみ言及） |
| バルク件数の最適値 | `IngestOptions.bulkSize` 既定（TBD-04） | §2.4、MIG-16 |
| シャード可変の是非 | 単一が意図かデフォルトか（TBD-05） | §4 `IndexSchema`、MIG-17 |
| detail 分離の粒度 | `SuggestWords`/`SuggestResult` の2分割で UI 要件を満たすか | §2.2 |

> いずれも `0014` §5 と整合。**本 IF はこれらが未確定でも「方向性（メソッド形・型・責務境界）」を確定でき、TBD 依存箇所はフォールバック経路（multiGet 等）を保持したまま段階導入できる**よう設計している。

---

## 付録: 参照

| 参照 | 役割 |
| --- | --- |
| `0014-improvement-proposal.md` | 本書の入力（提案集約・MIG・優先度・要確認） |
| `0005-step3-1-to-be-architecture.md` | 公開API4分割・拡張点・ストレージ抽象の設計根拠（§3〜§10） |
| `0013-step4-migration-roadmap.md` | MIG-01〜24 / KEEP-01〜04 / フェーズ・依存 |
| `0002-step1-issue-inventory.md` | ISS-01〜17 / TBD-01〜05 |
| `modules/fess-suggest/src/main/java/...` | 現行シグネチャの出典（`file:line`） |

> **本書の位置づけ再掲**: To-Be の **目標 API 契約**であり、確定実装ではない。シグネチャ・型・責務境界は実装フェーズ（MIG 単位）と要確認事項（§9）の解消に応じて確定する。
