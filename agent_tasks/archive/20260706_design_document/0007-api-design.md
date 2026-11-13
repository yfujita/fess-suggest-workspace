# 0007 ステップ 3: `docs/0001-api-design.md` の執筆

> タスク: `20260706_design_document`（作業プラン `0003-design-document-work-plan.md` §3 ステップ 3、3-1〜3-10）
> 実施日: 2026-08-12
> 目的: 公開 4 インタフェース・spi 7 インタフェース・非同期/例外契約・旧 → 新の対応表・fess 本体側の適合を、`[要確認]` を残さずシグネチャレベルで確定させる。
> 凡例: **[確認]**＝実コード・実ファイル・計測で確認済み ／ **[提案]**＝設計判断 ／ **[確定]**＝`0000` §5・§5.1 の C / P / U

> **文書番号について**: `0006-step2-review-reflection.md` 冒頭の注記により、作業プラン §3 ステップ 8 の想定割り当て（ステップ 3 → `0006`）から 1 つ繰り下がり、本書が `0007` となる。

---

## 1. 実施サマリ

| 項目 | 内容 |
| --- | --- |
| 成果物 | **`docs/0001-api-design.md`（新規作成）** |
| 作業履歴 | **`0007-api-design.md`（本書・新規作成）** |
| 変更したその他のファイル | **なし**（プロダクションコード・過去タスク文書・`docs/0000-design-overview.md` はいずれも無変更） |

`docs/0001-api-design.md` の構成と作業プランのステップの対応（同書 §0.1 にも掲載）:

| プラン | 節 | 内容 |
| --- | --- | --- |
| 3-1 | 付録 A | 0016 との差分表（A1〜A8）＋ 0016 §9 の 8 項目のクローズ状況 ＋ 差分 8 点に含まれない上書き 3 件 |
| 3-2 | §2 | 公開 4 IF（計 **19 メソッド**）＋ 公開 DTO 12 種 |
| 3-3 | §3 | spi 7 IF ＋ 補助型 6 種（`SourceContext` / `ScoringContext` / `ScoringPlan` / `ProcessedText` / `TextProcessingContext` / `QueryCondition`） |
| 3-4 | §4 | 単一規則・メソッド別契約表・部分失敗・スレッド安全性/タイムアウト/キャンセル/Executor・例外階層 |
| 3-5 | §5 | フィールド選択方式・許可リスト 11 種・`roles` の権限扱い（`AccessScope`） |
| 3-6 | §6 | `SuggestSettingsBuilder` の拡張（`Duration` / shards / `auto_expand_replicas` / `RefreshPolicy`） |
| 3-7 | §7 | `AuthorizationFilter` への集約・デフォルト deny・二重合成の解消対応表 |
| 3-8 | §8 | `Suggester` 18 件 ＋ `SuggestIndexer` 30 件の全件対応表・委譲設計・`Deferred` アダプタ・`apply` 最終形 |
| 3-9 | §9 | fess 側 4 ファイル ＋ 設定 1 ファイルの変更後の姿 |
| 3-10 | 本書 §4 | 自己レビュー |

---

## 2. 判断した点とその理由

### 2.1 差分表 A1〜A8 の決着

| # | 決着 | 判断の要点 |
| --- | --- | --- |
| A1 | multiGet を確定設計、`scripted_upsert` は `SuggestStore.bulkUpsert` の差し替え実装 | C-03 をそのまま適用。0016 の優先順位を逆転させた |
| A2 | **2 分割を採らない**（再判断。§2.2 に詳述） | C-10 と併用すると「返却属性を決める手段」が 2 系統になる |
| A3 | `numberOfReplicas` を削除し `autoExpandReplicas` に置換。`logicalDeleteField` も持たない | C-13 / C-14。`excluded` の有無は mapping の話であり `0002` の担当 |
| A4 | 境界で変換。Lasta Config には手を入れない | C-08。0016 §8 の「設定基盤を型安全化」は事実誤認 |
| A5 | `apply` を 3 メソッドから全廃 | P6。根拠は F-07（呼び出し箇所は E-09 で訂正済みの版を使用） |
| A6 | **全メソッド非同期。同期ラッパ API も提供しない**（再判断。§2.3 に詳述） | 境界を「I/O の有無」に置くと分類が判断依存になる |
| A7 | **項目単位の失敗は `failures` に積んで正常完了、操作全体の失敗のみ例外完了**（再判断。§2.4 に詳述） | 現行挙動の維持でもある |
| A8 | `RefreshPolicy`（`NONE` / `ON_COMPLETION` の 2 値）を追加。`onProgress` を `LongConsumer` 化し `pacing` を分離 | C-12。毎バッチ refresh を値域に残さない |

### 2.2 A2 の再判断: `SuggestWords` / `SuggestResult` の 2 分割を採らない [提案]

作業プランが「2 メソッド分割の要否自体を再判断する」としていた点である。**採らない**と結論した。

1. C-10 のフィールド選択を導入すると、「どの属性が返るか」を決める手段が**メソッド選択とフィールド指定の 2 系統**になる。ISS-03 の本質は「返却内容が呼び出し側から見えない」ことであり、ノブが 2 つある状態はその再発である。
2. fess の実需要が `text` と `tags` だけであることを実コードで確認した [確認]。`(fess) api/v2/handlers/SuggestWordsHandler.java:105-111` は `getText()` と `getTags()` しか読まず、`(fess) helper/PopularWordHelper.java:120` は `getItems()` から `getText()` のみを取る。既定（text / tags）が両者を満たすため、軽量版を別メソッドにする動機がそもそも無い。
3. ISS-03 の実体は `request/suggest/SuggestRequest.java:103` の `private boolean suggestDetail = true;` という**暗黙の既定値**である [確認]。既定を `Set.of(TEXT, TAGS)` として明示し、`SuggestResult.populatedFields()` で実際に埋まった属性を宣言させれば、型を割らずに自己記述性が得られる。

結果、`SuggestWords` 型は新設せず、`SuggestQueryService` は 2 メソッド（`suggest` / `popularWords`）になった。

### 2.3 A6 の再判断: 全メソッド非同期・同期ラッパなし [提案]

- 0016 は lifecycle 系を同期・`refresh()` のみ非同期としていたが、この分け方の基準が書かれていない。「I/O の有無」で分けようとすると `currentIndexName()`（クラスタ状態の参照）や `wordCountStats()`（集計クエリ）の分類が判断依存になり、「このメソッドは同期か非同期か」を毎回調べる状態（ISS-09）が形を変えて残る。
- 0016 §6 が挙げた同期ラッパ（`Suggesters.sync(service)`）も**採らない**。同じ操作に 2 つの呼び方ができると、どちらを使うべきかという問いが恒久的に残る。
- 同期が必要な fess 側は 3 箇所（`(fess) api/v2/handlers/SuggestWordsHandler.java:104` / `(fess) helper/PopularWordHelper.java:120` / `(fess) helper/SuggestHelper.java` の各 `join()` 化箇所）で、いずれも 1 行で済むことを確認した [確認]。C-07 の「`getResponse()` → `join()` 相当の 1 行置換」と整合する。

**副作用として挙動が 1 点変わる** [確認]: `concurrent/Deferred.java:211-213` の `getResponse()` は**引数なしで既定 1 分待ち**、超過で `SuggesterException` を投げる。`join()` は無期限待ちであるため、待ち時間の担保が `SuggestSettings` の下位タイムアウト（`settings/TimeoutSettings.java:47,63,79,95,111,127`）に移る。設計書 §4.4 に明記した。

### 2.4 A7 の再判断: バルク部分失敗は例外にしない [提案]

境界を「**呼び出し側が『どこまで進んだか』を知りうるか**」に置いた。

- リクエストが送れず項目単位の成否が得られない場合（接続断・タイムアウト・インデックス不在）は進捗を語れないので**例外完了**。
- リクエストが成立して項目単位に成否が返った場合は**正常完了**し、失敗項目を `failures` に積む。**全項目が失敗した場合も正常完了**とする（0 件成功と 1 件成功で呼び出し側の分岐が変わることを避けるため）。

C-06 が禁じた `Result<T>` 型との区別を設計書に明文化した。`Result<T>` は「成功値と失敗値の二者択一で例外を置き換える型」であり、ここで導入するのは「成功したレスポンスの一部として失敗項目を報告するフィールド」である。区別を実装時に崩さないため、`IngestResult` / `DeleteResult` に `orElseThrow` 相当のメソッドを持たせないことを契約にした。

なお**これは現行挙動の維持でもある** [確認]。`index/writer/SuggestIndexWriter.java:71-78` が bulk の失敗を `SuggestWriterResult` に積み、`index/operations/IndexingOperations.java:88` が `SuggestIndexResponse` に載せて返しており、項目単位の失敗で例外を投げていない。

また `List<Throwable> errors`（0016）ではなく `ItemFailure(id, text, reason)` を積む形にした。10,000 件のバルクで大量の例外オブジェクト（スタックトレース付き）を保持するのは、報告に必要な情報量に対して代償が大きい。

### 2.5 bad word の単一規則を「完全一致」にした判断 [提案]

現行は 2 規則が併存している [確認]。取り込み時フィルタが `text.contains(badWord)`（`entity/SuggestItem.java:455-462`、呼び出しは `index/operations/IndexingOperations.java:78`）、`apply=true` の物理削除が `wildcardQuery(text, "*"+normalized+"*")`（`index/operations/WordManagementOperations.java:81`）である。

**完全一致（term 一致）に統一した。** 理由: ①どちらの現行規則も「登録した語とは別の語」を巻き込む点で同種の危険を持つ。1 つに寄せるなら不可逆な巻き添えを機構から排除する（ISS-04 の主眼）安全側を採る。②部分一致で消したい要求は bad word の複数登録で表現でき、機構に不可逆性を持ち込まずに済む。③ C-02 により適用は論理除外（`excluded`）になり誤登録を戻せる。取り消せる操作にしたうえで判定を絞るほうが、取り消せない操作を広い判定で走らせるより安全である。

**F-09（wildcard 未エスケープ）は「規則がワイルドカードを使わない」ことで構造的に消える。** あわせて `util/SuggestUtil.java:398-400` の `escapeWildcardQuery` は利用箇所ゼロ（本ステップで再確認 [確認]）のまま残ると死蔵になるため削除対象とした。

**F-08（キャッシュ更新の非対称）は `BadWordPolicy` が bad word 集合の所有者になることで構造的に消える。** 現行は `index/SuggestIndexer.java:398` が `addBadWord` 後に `settings.badword().get(true)` を呼び直す一方、`deleteBadWord`（`:406-409`）は呼び直さない [確認]。`add` / `remove` が集合更新を内包する設計にすれば更新箇所が 1 つしかなく、非対称が起きようがない。「両方で `reload()` を呼ぶ」という規律に頼らないことを意図した。

**取り込み時フィルタの挙動が現行より弱くなるのは意図的な差分である**（現行 `contains` で弾かれていた「bad word を部分文字列として含む別の語」が取り込まれる）。設計書 §10 の申し送り 2 として `0002` のテスト仕様へ引き渡した。

### 2.6 `SuggestItemMergePolicy` をシグネチャのみに留めた判断

作業プラン §4 の「5-3 で挙動を決め 3-3 が従う」に従い、**挙動を先取りして断定しなかった**。設計書 §3.4 には「シグネチャに対する要求」の表だけを置き、`initialize` / `merge` の 2 メソッドに分けることで U4（`excluded` は既存値保持・既存に無い場合のみ `false` 初期化）と P13/U5（`userBoost` はマージ規則で解く）が**表現可能な形になっている**ことを示すに留めた。

- `initialize` を別メソッドにしたのは、1 メソッドで `existing == null` を許すと「既存なし」と「既存あり」が同じコードパスに混ざり、`excluded` を初期化のときだけ書くという U4 の要求が実装依存になるためである。
- `merge(existing, incoming)` が**両方を受け取る**ことが P13/U5 の前提である。現行 `entity/SuggestItemSerializer.java:181` は既存値を参照せず新値で無条件上書きしており、この形では表現できない片側書き込みだった。

### 2.7 `ScoringStrategy` に人気語用メソッドを追加した判断

執筆中のコード実査で、**人気語がサジェスト検索とは別系統のスコアリングを持つ**ことが判明した [確認]。詳細は §3 の(8)。0016 §3.2 の `ScoringStrategy` は `plan(SuggestQuery, ScoringContext)` の 1 メソッドで、人気語経路を扱えない。これを放置すると人気語のスコアリングだけが抽象化の外に残り MIG-11 が半分しか達成されないため、`planForPopularWords(PopularWordsQuery, ScoringContext)` を追加し、`ScoringPlan` に `Optional<RandomRescore>` を持たせ、`SuggestStore.popularWords` の引数に `ScoringPlan` を加えた。

### 2.8 拡張点に「置かない」ことを明示的に決めた点

- **`ScoringContext` に汎用の属性マップ（`Map<String,Object>`）を置かない。** 任意属性の受け口は事実上「検索コンテキストの予約」であり、C-11 が**織り込まない**と決めた MIG-22（パーソナライズ）をシグネチャで先取りすることになる。プライバシー要件が未確認のまま拡張点だけ開けない。
- **`SuggestSource` にソース別重み付け・マージ規則を持たせない**（C-11 / MIG-19/20）。要件が固まっていない段階で「重みの合成規則」を先に決めることになるため。
- **`RefreshPolicy` に `PER_BATCH` を置かない。** C-12 が廃止すると決めた挙動を選択肢として残すと死蔵オプションになる（設計原則 4）。
- **`ResponseField` に `score` / `_id` / `excluded` を含めない。** それぞれ「mapping から消える」「ID 方式の変更が API の互換性問題になる」「検索経路では常に `false` しか返らない死蔵の選択肢になる」ため。

---

## 3. コード実査で判明した事実と既存資料とのズレ

**作業プラン・0016 に書かれた行番号を無検証で転記せず、全件を実コードで確認した。** 一致したものは列挙せず、**食い違ったもの・既存資料に記載が無いもの**のみ挙げる。

| # | 内容 | 実測値 | 既存資料の記述 | 処置 |
| --- | --- | --- | --- | --- |
| (1) | `SuggestIndexer` の public メンバ数 | **30**（メソッド 29 ＋ コンストラクタ 1）。`grep -c '^    public ' index/SuggestIndexer.java` = 30。`:227` `createContext` と `:235` `getBadWords` は `private` | 作業プラン §3 ステップ 3-8 と V5 は「**28**」、0016 §1・§7 は「~28」 | **実数 30 を採用**し、設計書 §8.2 冒頭にその旨を注記。**E-13 以降の候補**（§5） |
| (2) | `Suggester` の public メンバ数 | **18**（メソッド 17 ＋ コンストラクタ 1） | プラン「18」 | 一致。実数をそのまま使用 |
| (3) | `Suggester.refresh()` の対象範囲 | `Suggester.java:179` は `client.admin().indices().prepareRefresh()` を**インデックス名を渡さずに**呼んでおり、**クラスタの全インデックス**が対象 | 既存資料に記載なし | 設計書 §2.2 で「suggest インデックスのみ」と契約を明示し、§10 の申し送り 5 に登録。**E-13 以降の候補**（§5） |
| (4) | 例外階層 | `exception/SuggestSettingsException.java:31` は `extends RuntimeException` であり、**`SuggesterException` を継承していない**（`exception/SuggestIndexException.java:33` は継承している） | 既存資料に記載なし | 設計書 §4.5 で親クラスを `SuggesterException` へ移す [提案]。§10 の申し送り 6。**E-13 以降の候補**（§5） |
| (5) | fess が `SuggestUtil` を直接使用 | `(fess) helper/SuggestHelper.java:314,331` が `SuggestUtil.deleteByQuery(client, suggester.settings(), suggester.getIndex(), boolQueryBuilder)` を呼んでおり、**OpenSearch の `BoolQueryBuilder` を fess 側で組み立てている** | 0016 §8 の fess 影響一覧に記載なし | 設計書 §1（パッケージ規約違反として明示）・§9.2（`deleteByCondition` への置換）で扱う |
| (6) | `Suggester.settings()` の internal 化可否 | fess 本体が **4 箇所**（`(fess) helper/SuggestHelper.java:147,150` / `:273-274` / `:314,331` / `:493`）で使用。うち `:273-274` の `ESSourceReader` 構築だけは代替経路が無い | 0016 §7 は `settings()` を `getReadingConverter()` / `getNormalizer()` とまとめて「internal 化」 | **0016 の誤り**。設計書 §8.1.1 で「公開のまま残す」と決定し、付録 A.2 に上書きとして記録。§10 の申し送り 1 |
| (7) | `addRole` の位置づけ | `(fess) api/v2/handlers/SuggestWordsHandler.java:83` の `addRole` は**ユーザーのロールを渡す唯一の経路**であり、それ自体は重複ではない。ISS-06 の実体は「権限条件の生成が fess 側と fess-suggest 側に分かれている」こと | 0016 §2.2 は「fess 本体側の `addRole` **二重呼び出し**は廃止」 | **0016 の誤り**。設計書 §7.3 で実体を記述し、付録 A.2 に記録 |
| (8) | 人気語のスコアリング | `request/popularwords/PopularWordsRequest.java:232-235` は `queryFreq` の `fieldValueFactorFunction`（`missing(0)`・`boostMode(REPLACE)`）**のみ**を使い、サジェスト検索の 4 要素（`request/suggest/SuggestQueryBuilder.java:146-159`）と構成が異なる。さらに `:244` の `randomFunction().seed(seed).setField("_seq_no")` を `:182` で `windowSize` 付きの rescorer として適用 | 0016 §3.2 も提案書も、人気語が別系統である点に触れていない | 設計書 §3.2 に `planForPopularWords` と `ScoringPlan.rescore` を追加（§2.7）。**E-13 以降の候補**（§5） |
| (9) | `suggest.popular.word.cache.expire` を `60m` にすると壊れるもの | `(fess) src/main/resources/fess_config.properties:1453` の値を `60m` にすると、freegen の値駆動の型推論により `getSuggestPopularWordCacheExpireAsInteger()` が生成されなくなる。したがって `(fess) helper/PopularWordHelper.java:77` の `.expireAfterWrite(...AsInteger().longValue(), TimeUnit.MINUTES)` も**必ず変更が要る** | C-08 / ISS-02 は「値を `60` → `60m` に改める」までで、消費側の変更に触れていない | 設計書 §9.4 に消費側の変更を明記。パース手段は fess-suggest 側のパーサを使う [提案] |

**行番号が一致したもの**（無検証転記を避けるため全件を実査した。以下はすべて既存資料の記述どおりであった [確認]）: `entity/SuggestItem.java:455-462`（`isBadWord`）／`index/operations/WordManagementOperations.java:81`（wildcard）／`util/SuggestUtil.java:398-400`（`escapeWildcardQuery`、利用箇所ゼロ）／`index/SuggestIndexer.java:398`・`:406-409`（F-08 の非対称）／`index/SuggestIndexer.java:185`（`parallel`）／`index/writer/SuggestIndexWriter.java:55`・`:59`・`:64`（`prepareGet` と `OpType.INDEX`）／`util/SuggestUtil.java:332-374`（`:337` `setSize(500)`、`:349-350` `DeleteRequest`、`:368` `prepareRefresh`）／`request/suggest/SuggestRequest.java:103`（`suggestDetail = true`）・`:352-357`（`_guest_` 補完は `:354-356`、filter 適用が `:357`）／`index/operations/ContentIndexingOperations.java:345`（毎バッチ refresh）／`(fess) api/v2/handlers/SuggestWordsHandler.java:83`・`:104`／`(fess) helper/PopularWordHelper.java:77`・`:120`／`(fess) exec/SuggestCreator.java:252`・`:255`・`:258`・`:263`・`:276`（**E-09 で訂正済みの版と一致**。管理画面/API 側は `apply=false`）／`Suggester.java:213`・`:250`・`:476-483`／`(fess) src/main/resources/fess_config.properties:1452-1453`。

---

## 4. 3-10 自己レビューの結果（実測値付き）

作業プラン `:182-184` の 5 観点で検査した。

| # | 観点 | 判定 | 実測値・根拠 |
| --- | --- | --- | --- |
| ① | **3-1 の 8 点が本文に反映されているか** | **pass** | 付録 A の表に `A1`〜`A8` の 8 行（`grep -cE '^\| \*\*A[1-8]\*\*'` = **8**）。各行に「0016 の記述／本設計書の決定／根拠となる [確定] 番号／本書の節」の 4 情報が揃っている。本文側の着地は A1→§3.7、A2→§2.1・§5、A3→§6.2、A4→§6.2・§9.4、A5→§8.5、A6→§4.1、A7→§4.3、A8→§6.3。加えて **0016 §9 の `[要確認]` 8 項目が全件クローズ**であることを付録 A.1 の表で明示した |
| ② | **1 行 IF が残っていないか** | **pass** | 設計書が定義する interface は **11 件**で、メンバ数は `SuggestQueryService` 2 / `SuggestIndexLifecycle` 7 / `SuggestWordAdmin` 7 / `SuggestIngestService` 8 / `SuggestSource` 3 / `ScoringStrategy` 2 / `TextProcessor` 2 / `SuggestItemMergePolicy` 2 / `BadWordPolicy` 5 / `AuthorizationFilter` 2 / `SuggestStore` 13。**最小 2 メンバ**で、本体がコメントのみの IF は 0 件。補助型 6 種（`SourceContext` / `ScoringContext` / `ScoringPlan` / `ProcessedText` / `TextProcessingContext` / `QueryCondition`）はいずれも**名前と型を持つフィールドまで定義**済み（0016 の `public interface SourceContext { /* supportedFields, languages, ... */ }` のような形は残っていない） |
| ③ | **`[要確認]` が 0 件か** | **pass** | `grep -c '要確認' docs/0001-api-design.md` = **3**。内訳は (a) §10 冒頭の「`[要確認]` は本書に 1 件も存在しない」という宣言、(b) 付録 A.1 の見出し「0016 §9『要確認事項』8 項目のクローズ状況」、(c) その直下の「本書に `[要確認]` を持ち込まないための確認である」。**いずれも参照文脈であり、分類マーカーとしての `[要確認]` は 0 件**（V3 の期待どおり） |
| ④ | **申し送りが着地しているか** | **pass** | `apply` の最終形 → **§8.5**（新 API から削除・旧ファサードは `@Deprecated` で値を無視。**MIG-03 段階と MIG-13 段階それぞれの `apply=true` の挙動**を表で定義し、F-07 を根拠に MIG-03 段階では実挙動が変わらないことを示した。呼び出し箇所は E-09 訂正後の事実を使用）。`roles` の許可リストと権限扱い → **§5**（許可リスト 11 種を列挙、除外 3 種に理由を付し、`roles` は `AccessScope.ADMIN` の呼び出しでのみ選択可・違反は例外・黙って落とさない、と規定） |
| ⑤ | **`Suggester`/`SuggestIndexer` の public 全件が対応表に現れるか** | **pass** | §8.1 に `Suggester` **18 行**（`:138`〜`:440`）、§8.2 に `SuggestIndexer` **30 行**（`:174`〜`:541`）。合計 **48 件が全件掲載**され、未割り当ては 0 件。廃止するものには**すべて廃止理由**を付した（`Suggester` 5 件・`SuggestIndexer` 17 件） |

### 4.1 追加で行った書式検査

`0006` §2.1 が定めた全テーブル区切り行の一括照合を実施した。**書式から外れる行は 0 件** [確認]。

```
grep -nE '^\| *-' docs/0001-api-design.md | grep -vE ':\| (--- \| )*--- \|$'
# → 出力なし
```

### 4.2 分量の実測（V6）

**V6 の目安（提案書の 1/5、20KB 前後）を大きく超過している。** 指示に従い、削らずに実測値と理由を記録する。

| 対象 | 文字数（`wc -m`） | バイト数（`wc -c`） | 提案書比 |
| --- | --- | --- | --- |
| `docs/0001-api-design.md` | **70,516** | 105,224 | **116.2%** |
| （参考）`docs/improvement-proposal.md` | 60,700 | — | 100% |
| （参考）`docs/0000-design-overview.md` | 21,829 | — | 36.0% |

節別のバイト数:

| 節 | バイト | 節 | バイト |
| --- | --- | --- | --- |
| §0 サマリ | 3,629 | §6 設定 API | 5,857 |
| §1 パッケージ規約 | 1,385 | §7 権限集約 | 3,304 |
| §2 公開 4 IF | 13,669 | §8 旧 → 新の対応表 | 17,060 |
| §3 spi と補助型 | **23,652** | §9 fess 側適合 | 9,293 |
| §4 非同期・例外契約 | 8,725 | §10 申し送り | 2,661 |
| §5 フィールド選択と権限 | 5,140 | 付録 A 差分表 | 7,032 |
| | | 付録 B 一次情報 | 2,844 |

**超過の理由**（いずれも削減すると作業プランの完了条件を満たせなくなる）:

1. **§3（23.7KB）と §2（13.7KB）はシグネチャ定義そのもの**であり、指示により削らない対象である。P3 が要求する「補助型をフィールドまで定義」と 3-3 の完了条件「1 行 IF が 0 件」は、記述量と直結する。
2. **§8（17.1KB）は V5 が要求する 48 行の全件対応表**である。廃止 22 件それぞれに廃止理由を付す要件も分量を押し上げる。
3. **§9（9.3KB）は 3-9 の完了条件「変更ファイルを列挙し各々の変更後の姿を示す」**により、`SuggestHelper` だけで 18 行の変更表になる。

**削減のために実際に行ったこと**: 付録 B.1 を「実読ファイル一覧」に圧縮した（4,331 → 2,844 バイト）。個々の行番号は本文の各主張に `file_path:line` として付いており（V9）、付録での再掲は `0000` §3.3 の記述ルール 1（根拠の重複を作らない）に反するためである。提案書の内容の転記は行っていない（根拠は `improvement-proposal.md` と `0001-unresolved-items-resolution.md` へのリンクに留めた）。

**ステップ 7 への申し送り**: `0000` §8.1 の 7-5 は**本書（`0000`）の分量**についての発動条件であり、`0001` には適用範囲が及ばない。`0001` の分量を分割等で扱うかは、ステップ 7 の通し整合レビューで判断すること（§5 の申し送り 4）。

---

## 5. スコープ外（本作業で**やっていない**こと）

- **プロダクションコードを一切変更していない**（P10）。`modules/fess-suggest` / `modules/fess` は無変更である。
- **過去タスクの文書を書き換えていない**（P9）。`20260622_improvement_proposal/0016-improved-api-interface.md`、`docs/improvement-proposal.md`、`0004-new-findings.md`、`0003-design-document-work-plan.md` はいずれも無変更。0016 の誤りは設計書の付録 A（差分 8 点）と付録 A.2（その他 3 件）で上書きした。
- **`docs/0000-design-overview.md` を編集していない。** §6 の訂正一覧への E-13 以降の追加はステップ 7 の担当であるため、候補を §6 の申し送りに登録するに留めた。
- **`SuggestItemMergePolicy` の挙動を決めていない**（§2.6）。シグネチャのみを確定し、挙動の正が `0002` §5-3 にあることを設計書 §3.4 に明記した。
- **mapping・index settings の実体を書いていない。** `excluded` の mapping、`kinds` の値域、`reading_*` の `dynamic` 方針、4 settings ファイルの To-Be はいずれも `0002` の担当である。設計書からは「`0002` が正」と参照するに留めた。
- **移行手順・リリース順序を書いていない。** 3-9 の注記に従い「変更後の形」だけを書き、リリース手順と fess との同期タイミングは `0003` に委ねる旨を §9.5 末尾に明記した。
- **`scripted_upsert` の Painless 仕様を書いていない**（C-03 / `0000` §2.2）。`SuggestStore.bulkUpsert` の差し替え可能性の記述に留めた。
- **`IngestOptions.bulkSize` / `parallelism` の最適値を決めていない**（`0000` §2.2）。実測依存のため後続タスクへ。
- **fess 側 public メソッドの `apply` 引数を除去していない**（設計書 §9.2）。fess の公開面であるため引数を残して値を無視する形にした。

---

## 6. 未確定事項・申し送り

### 6.1 `0000` §6 の訂正一覧への追加候補（**E-13 以降**。ステップ 7 の担当）

**本ステップでは `0000` を編集していない。** 以下は追加すべきかをステップ 7 で判断する候補である。

| 候補 | 対象 | 内容 | 根拠 |
| --- | --- | --- | --- |
| **候補 1** | `0003-design-document-work-plan.md` §3 ステップ 3-8 および §5 の V5 | 「`SuggestIndexer` public **28**」は実数と食い違う。実測は **30**（メソッド 29 ＋ コンストラクタ 1） | 本書 §3 の (1)。`grep -c '^    public ' index/SuggestIndexer.java` = 30 |
| **候補 2** | 既存資料全般（記載なし） | `Suggester.java:179` の `refresh()` は**インデックス名を渡しておらず、クラスタの全インデックスを refresh している**。ISS にも F 番号にも存在しない新規の [確認] 事項 | 本書 §3 の (3)。設計書 §2.2 / §10 の申し送り 5 |
| **候補 3** | 既存資料全般（記載なし） | `exception/SuggestSettingsException.java:31` が `SuggesterException` を継承しておらず、fess-suggest 由来の失敗を 1 つの型で捕捉できない | 本書 §3 の (4)。設計書 §4.5 / §10 の申し送り 6 |
| **候補 4** | 既存資料全般（記載なし） | 人気語が**サジェスト検索とは別系統の function score ＋ random rescorer** を持つ（`request/popularwords/PopularWordsRequest.java:232-235,244` と `:182`）。0016 §3.2 の `ScoringStrategy`（1 メソッド）では扱えない | 本書 §3 の (8)。設計書 §3.2 |
| **候補 5** | `20260622_improvement_proposal/0016-improved-api-interface.md` §7 / §2.2 / §1 | ① `Suggester.settings()` の internal 化は fess の実利用と矛盾 ② 「`addRole` 二重呼び出し」は不正確 ③ 公開面の件数「~18 / ~28」は実測 18 / 30 | 本書 §3 の (6)(7)(1)。**設計書付録 A.2 で既に上書き済み**のため、`0000` §6 に重ねるかは重複の要否で判断されたい |

### 6.2 他ステップへの引き継ぎ

| # | 事項 | 引き継ぎ先 |
| --- | --- | --- |
| **1** | **`SuggestItemMergePolicy` の挙動確定**。設計書 §3.4 の「シグネチャに対する要求」表（U4 / P13・U5 / F-04 の 3 要求）を入力として、`initialize` / `merge` の中身を決めること。`0001` の IF と `0002` の挙動が矛盾しないことは V7 の検査対象 | **ステップ 5（`0002` §5-3）** |
| **2** | **bad word 判定を完全一致に統一したことによる意図的な挙動差分**（§2.5）。回帰テスト仕様で「現行と同一結果になるもの」と「意図的に変える差分」を区別すること | **ステップ 5（`0002` のテスト仕様）** |
| **3** | **`RefreshPolicy`（`NONE` / `ON_COMPLETION`）と `refresh_interval` の使い分け**。設計書 §6.3 は API の受け口までを決めた。運用手順と `refresh_interval=-1` の定石は `0003` の担当 | **ステップ 6（`0003` §5）** |
| **4** | **`0001` の分量の扱い**（§4.2）。`0000` §8.1 の 7-5 は `0000` 自身の分量にしか適用されない。`0001` が提案書比 116.2% であることを V6 の判定でどう扱うか（許容するか、分割を諮るか）を決めること | **ステップ 7** |
| **5** | **`0000` §4.2 の節番号の実体化**。設計書 §0.1 に「作業プランのステップ番号 → 本書の節番号」の対応表を置いた。7-1 はこれをそのまま使える | **ステップ 7（7-1）** |
| **6** | **`0000` §8.2 の着地確認**。`apply` 引数の最終形 → `0001` **§8.5**、`roles` の許可リストと権限扱い → `0001` **§5**（本書 §4 の観点④で pass を確認済み） | **ステップ 7（7-3）** |
| **7** | **宣言欄の突き合わせ**（7-4）。設計書冒頭の「依存する [確定] 番号」に書いたのは C-01, C-02, C-03, C-05, C-06, C-07, C-08, C-09, C-10, C-11, C-12, C-13, C-14 ／ P6, P9, P12, P13, U2, U4, U5 の **20 件**で、すべて `0000` §5 / §5.1 に存在する。C-15 以降・新接頭辞は導入していない | **ステップ 7（7-4）** |
| **8** | **`Suggester.settings()` の最後の依存先**（`(fess) helper/SuggestHelper.java:273-274` の `ESSourceReader` 構築）。公開面から外すには `ESSourceReader` 側の受け取り方の変更が要る | 実装タスク（MIG-06 の後） |

---

## 7. 参照した一次情報

- プロダクションコード: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` および `modules/fess/src/main/java/org/codelibs/fess/` 配下（実読ファイルの一覧は `docs/0001-api-design.md` 付録 B.1、個々の `file:line` は同書本文）
- 設定ファイル: `modules/fess/src/main/resources/fess_config.properties:1415-1457`、`modules/fess-suggest/src/main/resources/suggest_indices/suggest/mappings-default.json`
- `agent_docs/tasks/20260706_design_document/docs/0000-design-overview.md`（§3.1 凡例／§3.2 宣言フォーマット／§3.3 記述ルール／§3.4 番号台帳／§4.2 MIG 対応表／§5・§5.1 [確定]／§6 訂正一覧 E-01〜E-12）
- 同 `0001-unresolved-items-resolution.md` §1.1・§1.2・§2.1〜§2.14
- 同 `0003-design-document-work-plan.md` §1.1（P1〜P13）・§3 ステップ 3（`:105-184`）・§4・§5（V1〜V11）・§6.1（U1〜U5）
- 同 `0004-new-findings.md` §3（F-06〜F-09, F-11）・§6（T-1〜T-5。**設計書からは E-08 / E-09 経由で参照**）
- 同 `0006-step2-review-reflection.md`（文書番号の繰り下がり、§2.1 の書式照合コマンド）
- `agent_docs/tasks/20260622_improvement_proposal/0016-improved-api-interface.md`（本設計書のベース。**無変更** — P9）
- 計測: `wc -m` / `wc -c` / `grep -c`（実測値は本書 §4）
