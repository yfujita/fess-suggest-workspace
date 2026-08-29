# 未決項目の解消（improvement-proposal.md）

> 本書は、タスク `20260706_design_document` の設計書作成に先立ち、改善提案書
> `docs/improvement-proposal.md` に残っていた **[要確認] / TBD / ユーザー判断事項** を
> 「コード追検証」と「ユーザーへの確認」で解消した記録である。
>
> 以降の設計書（インタフェース・API設計書 / データモデルとインデックス移行設計書）は、
> **本書で確定した決定を前提**として記述する。
>
> 凡例は改善提案書と同一（**[事実]** = コード確認済み / **[提案]** = 本タスクの設計提案 / **[要確認]** = 未解消）。

## 0. サマリ

| 分類 | 件数 | 状態 |
| --- | --- | --- |
| コード追検証で解消 | 4（設定型化 / Promise 互換 / TBD-04 / TBD-05） | ✓ クローズ（§1） |
| ユーザー判断で確定 | 14 | ✓ 確定（§2） |
| 新規発見（改善提案書に未記載） | 3 | ✓ 本書で処理（§1.3・§1.4・§2.14） |
| 残る [要確認] | （§4 参照） | 設計書には持ち込まない形で処理 |

**improvement-proposal.md の `§5.1` / `§5.2` に残っていた [要確認] は全件クローズした。** 実測（負荷試験・A/B）に依存する `§5.3` の項目のみ後続スコープとして残る。

---

## 1. コード追検証で解消した項目

### 1.1 設定基盤の型化可否（`§5.2`「設定基盤の型化可否」/ MIG-10 の前提）→ **クローズ [事実]**

**結論: fess 本体の設定基盤（Lasta Config）は `java.time.Duration` を扱えない。**

| 検証項目 | 結果 | 根拠 |
| --- | --- | --- |
| `ObjectiveConfig` の公開アクセサ | `get` / `getOrDefault` / `getAsInteger` / `getAsLong` / `getAsDecimal` / `getAsDate` / `is` のみ。**`Duration` を返すメソッドは存在しない** | `org.lastaflute.core.direction.ObjectiveConfig`（lastaflute-2.0.0.jar）。継承は `FessConfig.SimpleImpl`（`FessConfig.java:10130`）→ `FessEnv.SimpleImpl`（`FessEnv.java:184`）→ `ObjectiveConfig` |
| freegen の型推論 | `fess_config.properties` の既定値をパースして通った型のアクセサを生成する**値駆動の推論**。`FessConfig.java` 内の生成数は `AsInteger()` 494 / `AsDecimal()` 20 / `AsLong()` 0 / `AsDate()` 0 / **`AsDuration()` 0** | `FessConfig.java` 全体の実測。freegen 設定は `modules/fess/dbflute_fess/dfprop/lastafluteMap.dfprop` |
| 単位付き文字列の既存の扱い | **String のまま素通しして下流に渡す**のが fess の作法。`index.search.timeout=3m`（`fess_config.properties:635`）等は `String getIndexSearchTimeout()`（`FessConfig.java:5005`）で取得し、そのまま fess-suggest へ渡している | `SuggestHelper.java:136-140`（`settingsBuilder.bulkTimeout(...)` / `searchTimeout(...)`） |
| 明示変換の実例 | fess 本体全体で **1 箇所のみ**（`TimeValue.parseTimeValue` / `Duration.parse` / `Duration.of` の使用箇所） | `HotThreadMonitorTarget.java:57` |
| 多数派の代替作法 | **プロパティ名に単位を含める**（`rate.limit.retry.after.seconds=60`（`:273`）、`purge.suggest.search.log.day`（`FessProp.java:577`）） | 同左 |
| ISS-02 の実害の再確認 | `suggest.popular.word.cache.expire=60` はコメントに「Cache expiration (seconds)」とあるが（`fess_config.properties:1452-1453`）、消費側は `TimeUnit.MINUTES` で扱う | `PopularWordHelper.java:77` |

→ **[要確認]「設定基盤の型化可否」をクローズ**。MIG-10 の実現手段は §2.8 で確定した。

### 1.2 独自 `Promise` 置換の互換（`§5.2`「独自 `Promise` 置換の互換」/ MIG-08 の前提）→ **クローズ [事実]**

**結論: fess 本体のコールバック依存は 1 箇所のみ。`SuggestHelper` の公開シグネチャを変えずに `CompletableFuture` へ置換できる。**

fess-suggest 側の定義（`concurrent/Deferred.java`）:

| API | 位置 |
| --- | --- |
| `class Deferred<RESPONSE extends Response>` | `Deferred.java:52` |
| `Promise then(Consumer<RESPONSE>)` / `Promise error(Consumer<Throwable>)` | `Deferred.java:129` / `:138` |
| `inner class Promise` | `Deferred.java:153` |
| `RESPONSE getResponse()`（既定 1 分待ち） / `getResponse(long, TimeUnit)` | `Deferred.java:211` / `:221` |

> ※ `done()` メソッドは**存在しない**（`then` / `error` のみ）。`modules/fess-suggest/CLAUDE.md` の "Async Operations" サンプルにある `.done(...)` は実装と不一致の古い記述であった（→ ISS-19 として起票）。
>
> **→ 暫定修正を適用済み**（本タスク内で先行実施）: `modules/fess-suggest/CLAUDE.md` の "Async Operations" サンプルを `.done(...)` → `.then(...)` に訂正し、「`Promise` に `done()` は無い」旨のコメントを添えた。あわせて **fess の実利用の 2/3 を占める同期パターン**（`getResponse()`。既定 1 分待ち・タイムアウトや失敗時は `SuggesterException`）の例を "Sync Operations" として追記した。**MIG-08 で `Deferred` 自体を廃止する際に `CompletableFuture` ベースへ再度書き換える**（MIG-25 に含む）。

fess 本体側の全呼び出し箇所:

| # | 箇所 | 形態 | 分類 |
| --- | --- | --- | --- |
| 1 | `SuggestHelper.java:272-297` | `indexFromDocument(...).then(r -> {...}).error(t -> error.accept(t))` | **コールバック登録（唯一）** |
| 2 | `SuggestWordsHandler.java:104` | `builder.execute().getResponse()` | 同期待ちのみ |
| 3 | `PopularWordHelper.java:120` | `...execute().getResponse().getItems()` | 同期待ちのみ |

決め手となる事実:

- **fess 本体に `Deferred` / `Promise` 型の変数・フィールド・引数の宣言は 0 件** [事実]。すべてメソッドチェーンで即消費している。
- 唯一のコールバック依存 #1 も、戻り値の Promise は捨てる fire-and-forget であり、fess 側の `Consumer<Boolean>` / `Consumer<Throwable>` に橋渡ししているだけ。
- さらに呼び出し元 `SuggestCreator.java:263-276` は `CountDownLatch` で受けて `latch.await()` しており、**実質は「非同期 API をコールバック＋ラッチで同期待ちに戻している」**。
- `RoleQueryHelper.java` に `Deferred` / `Promise` の参照は 0 件（suggest とは無関係）。

→ **[要確認]「独自 `Promise` 置換の互換」をクローズ**。MIG-08 の fess 互換リスクは改善提案書の想定（`§4.2` で「API 互換: **あり**[要確認]」、コスト「高」）より**小さい**。対応方針は §2.7 で確定した。

### 1.3 TBD-04: バッチ別 JVM 隔離・`doc.per.request=2` の設計意図 → **クローズ**

#### (a) 「バッチ別 JVM 隔離」は [事実]

**suggest 生成は fess 本体とは別 JVM の子プロセスで動く**（スレッドではない）。

| 内容 | 根拠 |
| --- | --- |
| `SuggestJob` が `java` コマンド＋`-cp`＋各種 `-D` を組み立て、子プロセスを起動して `waitFor()` | `SuggestJob.java:92`（`executeSuggestCreator()`）、`:99`（`getJavaCommandPath()`）、`:203`（`cmdList.add(SuggestCreator.class.getCanonicalName())`）、`:220`（`processHelper.startProcess(...)`） |
| 子 JVM の JVM オプションは独立設定 | `jvm.suggest.options`（`fess_config.properties:100-103` 以降）を `SuggestJob.java:185` で適用 |
| 子 JVM のエントリポイント | `SuggestCreator.java:115` `main(String[])` → `:266` `suggestHelper.indexFromDocuments(...)` |

→ **ヒープは fess 本体と隔離されている**ため、`docPerReq` を上げてもアプリ本体の GC 圧には直結しない。負荷は主に OpenSearch 側（`_analyze` と refresh）に出る。

#### (b) `doc.per.request=2` は「根拠のあるチューニング値」ではない [事実]

| 定義・利用 | 根拠 |
| --- | --- |
| 既定値 `2` | `fess_config.properties:1441` |
| キー定数 / getter | `FessConfig.java:1762` / `:8682`, `:8691`, `:13187`, `:13191` |
| **唯一の利用箇所** | `SuggestHelper.java:270` |
| 実処理 | `SuggestIndexer.java:367` → `ContentIndexingOperations.java:317-359` |

git 履歴（fess リポジトリ）:

| commit | 日付 | 内容 |
| --- | --- | --- |
| `706242822` | 2015-11-09 | "add suggest job" — **初出**。`indexFromDocument(reader, 2, 100)` と**ハードコードのマジックナンバー `2`** で登場。根拠の記述なし |
| `4ea814bf6` | 2015-12-15 | "fix oom at suggest job" — OOM 対策で `sourceReaderScrollSize=1` 等を導入。**`2` 自体は変更せず** |
| `1ea921c46` | 2020-04-03 | "#2442 improve suggest processing" — `waitController` 化して `calibrateCpuLoad()` を挿入。`2` はハードコードのまま |
| `0e3b39a8d` | 2020-04-03 | "fix #2443 add suggest.update.doc.per.request" — **ハードコード `2` をそのまま設定既定値に外出ししただけ**（diff は `}, 2, ()->{` → `}, docPerReq, () -> {` と 1 行追加のみ） |

- **[事実]** 関連 issue（`codelibs/fess#2442` / `#2443`、いずれも 2020-04-02）は**本文が空**で、`2` を根拠づけるコミットメッセージ・コメント・issue 記述は存在しない。
- **[推測]** 意図的な CPU 負荷抑制ではなく「**2015 年に小さめに倒した安全側の値の放置**」。CPU 抑制の主役は `docPerReq` ではなく `waitController`（`calibrateCpuLoad()`（`SystemHelper.java:999-1021`）＋ `suggest.update.request.interval`（既定 0、`fess_config.properties:1439`））側である。

#### (c) 本当のボトルネックは `docPerReq` ではなく **バッチごとの refresh** [事実]

`ContentIndexingOperations.java:331-350` のループ:

```java
docs.add(doc);
doc = documentReader.read();
if (doc == null || docs.size() >= docPerReq) {
    final SuggestIndexResponse res = indexFromDocument(ctx, docs.toArray(new Map[docs.size()]));  // :341
    ...
    client.admin().indices().prepareRefresh(index).execute().actionGet(...);                       // :345 ★毎バッチ refresh
    docs.clear();
    waitController.run();                                                                          // :348
}
```

- **`docPerReq=2` は「ソースドキュメント 2 件ごとに 1 バッチ」であり、1 バッチごとに index refresh が同期発行される。**100 万ドキュメントなら 50 万回の refresh。
- 1 件あたりのコストも大きい: 1 ドキュメント最大 50KB（`suggest.update.contents.limit.doc.size=50000`（`fess_config.properties:1447`）／`ESSourceReader.java:103`）の `content`+`title` 全文に対し `_analyze` API 呼び出しと reading 変換が走る（`ContentIndexingOperations.java:259-273`）。スクロール取得も 1 件ずつ（`suggest.source.reader.scroll.size=1`、`fess_config.properties:1449` / `ESSourceReader.java:99`）。

→ **TBD-04 クローズ**。MIG-16 の設計方針は §2.12 で確定した。

### 1.4 TBD-05: 単一シャードが「意図」か「デフォルトのまま」か → **クローズ（意図的な引き下げ）[事実]**

#### (a) 該当ファイルと現在値

fess-suggest 側の 4 ファイルが同一値を持つ:

- `suggest_indices/suggest.json`（`refresh_interval` のみ `10s`）
- `suggest_indices/suggest_settings.json` / `suggest_settings_array.json` / `suggest_analyzer.json`（いずれも `1s`）

```json
{ "index": { "refresh_interval": "...", "number_of_shards": 1, "number_of_replicas": 0, "auto_expand_replicas": "0-1" } }
```

fess 本体側にも同名リソースのオーバーライドがある（`modules/fess/src/main/resources/suggest_indices/suggest_analyzer.json` および `_aws/` / `_cloud/` 版）。

#### (b) 他インデックスとの比較 [事実]

| インデックス | shards | 根拠 |
| --- | --- | --- |
| ドキュメント本体 `fess` | **設定可能**、既定 5 | `fess_indices/fess.json` の `"${fess.index.number_of_shards}"` ／ `fess_config.properties:481` |
| 検索ログ `fess_log.search_log` | 5（固定） | `fess_indices/fess_log.search_log.json` |
| クローラ queue/data/filter | 10（設定可） | `fess_config.properties:595,597,599` |
| `fess_config.*` / `fess_user.*` | 1（固定） | `fess_indices/fess_config.scheduled_job.json` 等 |
| **suggest 系** | **1（固定・上書き不可）** | 上記 4 ファイル |

→ suggest は「本体ドキュメント index（5・設定可）」ではなく「**config/user 系メタデータ index（1・固定）**」と同じ扱いに置かれている。

#### (c) git 履歴 — `1` は `5` からの意図的な引き下げ [事実]

fess-suggest リポジトリ:

| commit | 日付 | 内容 |
| --- | --- | --- |
| `2de2559` | 2017-01-06 | "apply index settings" — `suggest_indices/*.json` を新規作成。**当初は `number_of_shards: 5`** |
| `d8b5ccc` | 2018-04-19 15:36 | "add auto_expand_replicas" — **4 ファイルすべてを `5` → `1` に変更し、同時に `auto_expand_replicas: "0-1"` を追加** |

fess リポジトリ側の**同日**コミット（時系列が重要）:

| commit | 時刻 | 内容 |
| --- | --- | --- |
| `aed8385fc` | 2018-04-19 12:07 | "fix #1612 add index.auto_expand_replicas" — `index.number_of_shards=5` と `index.auto_expand_replicas=0-1` を**設定項目として新規追加**。fess 本体の index 群を設定化 |
| `119a3d99b` | 2018-04-19 14:40 | "fix #1614 add auto_expand_replicas" — fess 側 `suggest_indices/suggest_analyzer.json` を `5` → `1` に変更 |

- **[事実]** 同一日・数時間内に「**本体 index はシャード数を設定可能にする**」判断と「**suggest index はシャード 1 に固定する**」判断が別々に行われている。**`1` は Elasticsearch のデフォルト放置ではなく、5 からの明確な引き下げ。**
- **[推測]** 意図は「suggest index は元ドキュメントから抽出した語彙で本体 index より桁違いに小さく、5 シャードは over-shard」および「`auto_expand_replicas: "0-1"` と組で『小さい index の標準形』（`fess_config.*` 系と同じ）に揃えた」のいずれか／両方。関連 issue（`codelibs/fess#1612` / `#1614`）は**いずれも本文が空**で、コミットメッセージも `auto_expand_replicas` にしか触れていないため確証はない。

#### (d) 設定で上書きする仕組みは存在しない [事実]

- `Suggester.java:476-483` `getDefaultIndexSettings()` は `classLoader.getResourceAsStream("suggest_indices/suggest.json")` を読むだけで、**プレースホルダ置換がない**。fess 本体の `SearchEngineClient.readIndexSetting()`（`SearchEngineClient.java:985-1000`）が `${fess.index.number_of_shards}` を置換するのとは対照的。
- 適用箇所は `Suggester.java:213`（`createIndexIfNothing()`）と `Suggester.java:250`（`createNextIndex()`）の `setSettings(...)`。
- `SuggestHelper` に shards 関連コードは皆無。`fess_config.properties` の `suggest.*`（`:1415-1457` が全量）にもシャード設定はない。
- 事実上の差し替え口は 2 つだけ: ①**classpath シャドウイング**（`SuggestJob.java:114-140` が `WEB-INF/classes` を jar より先に置く。fess 側の `suggest_analyzer.json` がまさにこれ）、②**search engine type 別ルックアップ**（`AnalyzerSettings.java:308-317` の `suggest_indices/_<type>/suggest_analyzer.json`。ただし**analyzer 設定にしか実装がなく `suggest.json` には効かない**）。

#### (e) 新規発見: `number_of_replicas: 0` は実質死んでいる [事実]

`auto_expand_replicas: "0-1"` が優先されるため、**2 ノード以上ではレプリカ 1 になり、`number_of_replicas: 0` は一度も効かない**。改善提案書 `§2.2` ISS-07 は「`number_of_shards=1`/`replicas=0` のスケール上限」としているが、**`replicas=0` の部分は前提が誤り**である。扱いは §2.14 で確定した。

→ **TBD-05 クローズ**。MIG-17 の設計方針は §2.13 で確定した。

---

## 2. ユーザー判断で確定した項目

### 2.1 移行戦略 → **戦略B: 段階的移行（Strangler Fig）** [確定]

改善提案書 `§4.1` の推奨どおり。設計書は次を前提とする。

- 新実装は `api` / `spi` / `internal` パッケージに**並置**し、既存 `index` / `request` / `Suggester` は当面残置（`§4.1.1`）。
- 手順は **NEW 実装 → 旧ファサードから委譲 → 呼び出し切替 → 旧除去** の 4 段。
- 既存テスト資産（test 77 ファイル / 15,194 行）を等価性の安全網に使う。
- スキーマ変更系は**新世代インデックスの並行構築＋二重エイリアス切替**（KEEP-02）を併用。

→ 設計書には「旧公開シグネチャを維持したまま内部を新部品へ委譲する」節を含める。

### 2.2 bad word の適用方式 → **③ 即時・可逆な論理除外（`excluded` フラグ）を既定** [確定]

改善提案書 `§5.2` の推奨どおり。

- mapping に `"excluded": {"type": "boolean"}` を追加し、書き込み側は明示的に `false` を格納（`null_value` に依存しない）。
- 検索時は **`mustNot(termQuery("excluded", true))`** の term filter で除外する。
- **`must(termQuery("excluded", false))` は使わない**（旧世代インデックス＝当該フィールド未定義の文書が一件も一致せず、サジェスト結果が全滅するため。`§4.1.2`）。ロールバック時も同じ理由で否定形が必須。
- 移行順は **MIG-03（マッチ規則の統一・物理削除の既定オフ）→ MIG-13（`excluded` 導入）**。
- **①（即時・不可逆な物理削除）は明示オプションとして残さない**。過渡期の逃げ道を作らず、API 表面積と設計の分岐を増やさない判断。

### 2.3 書き込み往復削減の範囲 → **第1段 multiGet のみ確定設計、第2段は拡張余地** [確定]

- `SuggestIndexWriter` の `prepareGet` N 回（`SuggestIndexWriter.java:54-55`）を **multiGet 1 回**に置換するところまでを確定設計とする。
- `scripted_upsert`（第2段）は **`SuggestStore` 抽象の差し替え可能な実装として拡張点だけ用意**し、Painless スクリプト仕様・冪等性・失敗時挙動は今回の設計書に含めない。
- 理由: OpenSearch 3.7.0 で API 上は利用可能（[事実]）だが、script 複雑度が高く、低リスクの multiGet で往復削減の大半に到達できる（`§3.4`）。

### 2.4 Phase 0（性能・実現性 PoC）→ **実施しない。設計書で判断を確定させる** [確定]

- OpenSearch 3.7.0 で `scripted_upsert` / `script_score` / `function_score` / `rescore` / `knn` / `fuzzy` / Painless が利用可能なことは確定済み（[事実]、TBD-01 クローズ）。
- **性能実測（負荷試験・A/B）は後続タスクに回す**。設計書は現時点の判断（案A採用・multiGet 優先など）で断定し、[要確認] を持ち込まない。
- 実測が必要な項目は `§5.3` のまま後続スコープとして残す（本書 §4 に再掲）。

### 2.5 設計書のカバー範囲 → **Phase 1a + 1b（基盤）を完全設計、Phase 2〜4 は拡張点の形だけ** [確定]

| 区分 | MIG | 設計書での扱い |
| --- | --- | --- |
| **完全設計** | MIG-01（単一マージ規則）、MIG-02（死蔵 score 廃止）、MIG-03（bad word マッチ統一）、MIG-04（userBoost 丸め撤廃）、MIG-05（`@Deprecated` シム除去）、MIG-06（用途別 API 分離）、MIG-07（デッドパス排除＋`SuggestSource` 抽象）、MIG-08（`CompletableFuture` 統一）、MIG-09（権限集約）、MIG-10（設定の型安全化）、MIG-11（`ScoringStrategy` 抽象化）、MIG-12（`TextProcessor` 明文化）、MIG-25（バージョン単一ソース化） | 具体的なインタフェース・メソッドシグネチャまで設計 |
| **拡張点の形のみ** | MIG-13/14（Phase 2）、MIG-15第2段/16/17（Phase 3）、MIG-18〜24（Phase 4） | 「この拡張点に後から載る」ことを IF 形状で保証するに留める |

※ **上表からの例外（インデックス設計と不可分のため、後続フェーズだが今回設計に含める）**:

| MIG | 含める理由 | 決定 |
| --- | --- | --- |
| **MIG-13**（`excluded` フィールド） | mapping 定義・共存期の否定形ルールがインデックス移行設計書と不可分 | §2.2 |
| **MIG-17**（シャード/レプリカ可変化） | index settings の設計そのもの。§2.14 の `number_of_replicas` 削除とも一体 | §2.13・§2.14 |
| **MIG-16**（バッチ件数・refresh 分離） | refresh 戦略は index settings（`refresh_interval`）と表裏 | §2.12 |

### 2.6 非同期・エラー契約 → **`CompletableFuture` 統一 ＋ 例外は従来どおり throw** [確定]

- 非同期は `java.util.concurrent.CompletableFuture` に統一する（独自 `Deferred`/`Promise` を廃止）。
- **`Result<T>` 型は導入しない**。改善提案書 `§4.1.2` / `§8.2` の「例外を投げない `Result` 型」提案は**取り下げる**。
- エラーは従来どおり `SuggesterException` を throw する（非同期経路では `CompletionException` でラップされる）。
- 理由: API の学習コストを抑え、fess 側の修正量を最小化するため。

### 2.7 MIG-08 の fess 側対応範囲 → **`SuggestHelper` 内で吸収し、fess の公開面は一切変えない** [確定]

§1.2 の追検証結果に基づく。

- `SuggestHelper.indexFromDocuments(Consumer<Boolean>, Consumer<Throwable>)` の**シグネチャを維持**し、内部の `.then(...)` / `.error(...)`（`SuggestHelper.java:294-297`）を `.thenAccept(...)` / `.exceptionally(...)` 相当に書き換えるのみ。
- `SuggestCreator.java:263-276` の `CountDownLatch` はそのまま維持する（`join()` 化は今回は行わない）。
- `SuggestWordsHandler.java:104` / `PopularWordHelper.java:120` は `getResponse()` → `join()` 相当の 1 行置換。
- → **fess 側の修正は 3 ファイルの局所変更に収まる**。改善提案書 `§4.2` の MIG-08 属性「API 互換: あり [要確認] / コスト: 高」は、**「API 互換: なし（内部のみ） / コスト: 中」に下方修正**する。

### 2.8 MIG-10 の実現手段 → **境界で変換（fess-suggest 側 API のみ `Duration`）** [確定]

§1.1 の追検証結果に基づく。

- **fess-suggest 側**: 時間を表す設定の型を `java.time.Duration` にする。`SuggestSettingsBuilder` 等の受け口で `"3m"` / `"60s"` のような**単位付き文字列をパースして `Duration` に変換**する。
- **fess 本体側**: 既存の `index.search.timeout=3m`（`fess_config.properties:635`）と同じ作法で**単位付き文字列を String のまま渡す**。**Lasta Config の拡張や `FessProp` への変換ヘルパ追加は行わない**。
- **ISS-02 の解消**: `suggest.popular.word.cache.expire` の値を `60` → 単位付き（例 `60m`）に改め、**単位を値自体に埋め込む**。コメント（秒）と実装（分）の乖離（`fess_config.properties:1452-1453` vs `PopularWordHelper.java:77`）は、この時点で**実装側の分を正**として単位を明示する。
- → MIG-10 は fess 側にプロパティ値とアクセサ利用箇所の修正が入るため **Phase 1b 据え置き**だが、Lasta Config 基盤に手を入れないぶんコストは下がる。

### 2.9 権限フィルタの集約先 → **ライブラリ側 `AuthorizationFilter` に集約** [確定]

改善提案書 `§10.2` / `§3.1` ISS-06 の推奨どおり。

- ロール集合の決定・`_guest_` 補完・クエリ変換を fess-suggest 側の単一クラスに寄せる。
- fess 本体は「現在のユーザーのロール一覧」を渡すだけにする（現行の `SuggestWordsHandler.java:83` の `addRole` と `SuggestRequest.java:354-356` の `_guest_` 補完の二重合成を解消）。
- **デフォルト deny を維持**する（`§3.7`「逆方向の差」= fess 固有の価値を損なわない前提）。
- fess 側修正が必要なため **Phase 1b**（MIG-09、ハード依存 H:MIG-06）。

### 2.10 蓄積属性の露出粒度 → **クライアントがフィールドを選択できる形** [確定]

- リクエストで**返却フィールドを指定**できるようにし、必要な属性（reading / kinds / freq / roles など）だけ返す。
- **既定は現行互換**（text / tags）とし、無指定時のレスポンスは変わらない。
- UI 要件が未確定でも設計を先に確定でき、後から UI を追いつかせられる。改善提案書 `§3.5` の「露出粒度（UI 要件）[要確認]」を**この形で吸収してクローズ**。
- ※ `roles` を露出可能にする以上、**選択可能フィールドの許可リストと権限上の扱い**（呼び出し元が管理系か検索系か）を API 設計書で明示すること。

### 2.11 拡張点に前提として織り込む新機能 → **セマンティック/ベクトル（MIG-24）、fuzzy（MIG-21）、多言語（MIG-23）** [確定]

Phase 4 の実装は今回のスコープ外だが、**拡張点の IF 形状がこれらを後から載せられること**を設計時の制約として織り込む。

| 織り込む機能 | 設計上の含意 |
| --- | --- |
| **MIG-24 セマンティック/ベクトル** | インデックス移行設計に **`knn_vector` フィールドを後から追加できる**ことを予約する（新世代インデックス並行構築＋二重エイリアスで追加可能なことを手順として示す）。`ScoringStrategy` が**ベクトル類似度スコアを加点要素として受け取れる**形にする |
| **MIG-21 fuzzy / MIG-23 多言語** | `TextProcessor` 拡張点（正規化・読み変換・アナライザ）を**言語別／誤字正規化の実装を差し替え・追加できる**形にする。`ScoringStrategy` が **fuzzy マッチを低重みで加点できる**（完全一致と区別できる）シグネチャにする |

**織り込まない**（拡張点の形状に制約を課さない）:

- **MIG-19 同義語/関連語・MIG-20 トレンド**: 複数ソースのマージ規則とソース別重み付けを IF に組み込む必要があるが、今回は `SuggestSource` を「候補を返す抽象」として定義するに留める。
- **MIG-22 パーソナライズ**: 「検索コンテキスト」をリクエストモデルに予約しない。プライバシー要件の確認が別途必要なため。

### 2.12 MIG-16（バルク件数適正化）→ **既定値引き上げ ＋ refresh の発行頻度を分離** [確定]

§1.3 の追検証結果に基づく。**「バッチ件数」と「refresh 頻度」は現状同一ループに癒着しているため、これを分離することを設計の主眼とする。**

| 設計項目 | 内容 |
| --- | --- |
| **バッチ件数** | `suggest.update.doc.per.request` の既定値を引き上げる。`2` に技術的根拠がないこと（§1.3(b)）と、子 JVM でヒープが隔離されていること（§1.3(a)）が引き上げの根拠 |
| **refresh の分離** | `ContentIndexingOperations.java:345` の**毎バッチ refresh を廃し、取り込み完了時に 1 回**（もしくは `refresh_interval` 任せ）に変更する。設計書では refresh 戦略を**明示的な設定/パラメータ**として切り出す |
| **CPU 抑制の責務** | CPU 負荷制御は `waitController`（`calibrateCpuLoad()` ＋ `suggest.update.request.interval`）の責務であることを設計書に明記し、バッチ件数に負荷制御の意味を持たせない |

**トレードオフ（設計書に明記する）**: 毎バッチ refresh の廃止により、**取り込み途中のサジェスト候補の逐次可視性が失われる**（`refresh_interval` ぶん遅れる）。ただし suggest 生成は `SuggestJob` の子プロセスによるバッチ処理であり、途中結果の即時可視性に依存する要件はない [提案]。

**具体的な最適値は決めない**。実測は後続タスク（§4）。設計書は「設定で可変」かつ「refresh が分離されている」ところまでを保証する。

### 2.13 MIG-17（シャード/レプリカ可変化）→ **API で受け、fess 側はプロパティから渡す** [確定]

§1.4 の追検証結果に基づく。§2.8（設定は境界で変換）の方針と一貫させる。

- **fess-suggest 側**: `SuggestSettings` / `SuggestSettingsBuilder` にシャード・レプリカ設定を受け取る API を追加し、**これを正とする**。`suggest_indices/*.json` の値は API 無指定時の既定値としてのみ機能させる。
- **fess 本体側**: `fess_config.properties` に設定項目（例 `suggest.index.number_of_shards`）を追加し、`SuggestHelper` が読んで API に渡す。**`Suggester.getDefaultIndexSettings()` への `${...}` プレースホルダ置換の導入は行わない**（fess 本体の `SearchEngineClient.readIndexSetting()` 方式は採らない）。
- **理由**: fess-suggest をライブラリとして直接使う利用者にも設定手段が開かれること、および §2.8 で決めた「ライブラリ側は型付き API、fess 側は設定値を渡すだけ」という境界の一貫性。
- **スキーマ変更を伴う**ため、適用は二重エイリアス再構築（KEEP-02）経由。インデックス移行設計書に手順を含める。

### 2.14 `number_of_replicas: 0` の死蔵 → **`auto_expand_replicas` を正とし、`number_of_replicas` を削除** [確定]

§1.4(e) の新規発見への対応。

- `suggest_indices/*.json` の 4 ファイルから **`"number_of_replicas": 0` を削除**し、`auto_expand_replicas: "0-1"` を唯一のレプリカ制御とする。
- 根拠: 設計原則 4「**死蔵コード・死蔵データを持たない**（書くなら読む、読まないなら書かない）」（改善提案書 `§1.2`）。死蔵 `score` フィールド（ISS-16 / MIG-02）と同じ扱いにする。
- §2.13 のレプリカ設定 API は、**`auto_expand_replicas` の値を設定できる形**にする（`number_of_replicas` を復活させる形にはしない）。
- **改善提案書 `§2.2` ISS-07 の記述「単一シャード固定（`number_of_shards=1`/`replicas=0`）のスケール上限」は、`replicas=0` の部分が事実誤認**であるため訂正が必要（§3 参照）。

---

## 3. 改善提案書への反映 → **反映済み（第3版）**

本書の決定を `docs/improvement-proposal.md` に **第3版（未決項目の解消）** として反映済み。反映した差分は以下のとおり。

| 箇所 | 現行記述 | 本書での決定 |
| --- | --- | --- |
| `§4.1.2` / `§3.2` MIG-08 | 「NEW の部品は標準の `CompletableFuture` と、例外を投げない `Result` 型で実装する」 | **`Result` 型は導入しない**（§2.6） |
| `§4.1.2` 末尾 | 「`CompletableFuture`/`Result` を fess まで露出させるか否かを判断する [要確認]」 | **露出させない。`SuggestHelper` 内で吸収**（§2.7）→ [要確認] クローズ |
| `§4.2` MIG-08 の属性 | スキーマ/API = 「なし/**あり**[要確認]」、コスト = 「高」 | **「なし/なし（内部のみ）」、コスト「中」**（§2.7） |
| `§5.2`「設定基盤の型化可否」 | 「Lasta Config が `Duration` を扱えるか [要確認]」 | **扱えないことが確定 [事実]。境界で変換する方式に決定**（§1.1・§2.8）→ クローズ |
| `§5.2`「独自 `Promise` 置換の互換」 | 「fess 本体のコールバック依存の有無 [要確認]」 | **依存は 1 箇所のみ。公開面を変えず置換可能 [事実]**（§1.2）→ クローズ |
| `§5.2`「bad word の即時削除 vs 可逆性」 | 「①②③のどれを既定にするか。過渡期に①を残すかも判断事項」 | **③を既定。①はオプションとしても残さない**（§2.2）→ クローズ |
| `§5.2`「scripted_upsert の採否・時期」 | 「実測と並行競合の実害次第で慎重に判断」 | **第1段 multiGet のみ確定設計、第2段は拡張点のみ**（§2.3） |
| `§5.2`「移行戦略」 | 「戦略B 推奨。最終判断はユーザー」 | **戦略B に確定**（§2.1）→ クローズ |
| `§3.5`「露出粒度（UI 要件）[要確認]」 | ISS-11 の露出粒度が未確定 | **フィールド選択方式で吸収**（§2.10）→ クローズ |
| `§4.4` Phase 0 | 「性能・実現性検証（任意）」 | **実施しない**（§2.4） |
| `§2.3` / `§5.1` TBD-04 | 「バッチ別 JVM 隔離・CPU 負荷調整の設計意図 [推測]」 | **子 JVM 隔離は [事実] で確定。`2` は根拠なしの放置値**（§1.3）→ クローズ。**真のボトルネックは毎バッチ refresh** という新規発見を追記すべき |
| `§2.3` / `§5.1` TBD-05 | 「単一シャードが『意図』か『デフォルトのまま』か [推測]」 | **2018-04-19 の `d8b5ccc` による 5→1 の意図的な引き下げ [事実]**（§1.4）→ クローズ |
| `§2.2` ISS-07 | 「単一シャード固定（`number_of_shards=1`/**`replicas=0`**）のスケール上限 [推測]」 | **`replicas=0` は事実誤認**。`auto_expand_replicas: "0-1"` が優先され一度も効かない（§1.4(e)）→ **記述の訂正が必要** |
| `§4.2` MIG-16 の概要 | 「バルク件数適正化」 | **「バルク件数適正化 ＋ refresh 発行頻度の分離」に拡張**（§2.12）。件数だけではボトルネックが残る |
| `§2.2` ISS 表（新設） | — | **ISS-19 を新設**: `modules/fess-suggest/CLAUDE.md` の `.done(...)` サンプルが実装と不一致（`then`/`error` のみ）。**暫定修正は本タスクで適用済み**（§1.2）。`CompletableFuture` ベースへの書き換えは MIG-25 に含めた |

---

## 4. 残る要確認事項（設計書には持ち込まない）

以下は本書で解消せず、**後続タスク**として残す。設計書は各々に依存しない形で記述する。
**いずれも実測（負荷試験・A/B）またはビジネス要件に依存するもので、改善提案書 `§5.3`「実装外・後続スコープ」に対応する。`§5.1` / `§5.2` の [要確認] は全件クローズ済み。**

| 項目 | 扱い |
| --- | --- |
| **性能の定量評価** | 後続タスク。multiGet の往復削減効果、案A/案B の QPS 別レイテンシ、**MIG-13 の除外フィルタ付与前後のレイテンシ差分**、**MIG-16 の `doc.per.request` 最適値と refresh 分離の効果**（§2.12）、複数シャードのホットスポット有無とシャード数の最適値（§2.13）、セマンティックの QPS 別レイテンシ・容量、fuzzy の誤補正率 |
| **プライバシー/データ保持** | MIG-22（パーソナライズ）実施時に GDPR 等の保持ポリシー確認が前提。今回は拡張点にも織り込まない（§2.11） |
| **埋め込みモデル/推論基盤** | MIG-24 の実施要件。今回は `knn_vector` を後から追加できることのみ保証（§2.11） |
| **refresh 分離による可視性低下の許容** | §2.12 のトレードオフ。suggest はバッチ生成のため問題ないと判断した [提案] が、逐次可視性に依存する運用があれば再検討 |

---

## 5. 次のステップ

本書の決定を前提に、要件定義（`0000-requirements-definition.md`）の成果物を `docs/` 配下に作成する。

| 成果物 | 本書で確定した前提 |
| --- | --- |
| **インタフェース・API 設計書** | §2.1（Strangler Fig / api・spi・internal 並置）、§2.5（Phase 1a+1b を完全設計）、§2.6（`CompletableFuture` 統一・`Result` 型なし・例外は throw）、§2.7（`SuggestHelper` 内で吸収）、§2.8（設定は境界で `Duration` 変換）、§2.9（`AuthorizationFilter` に権限集約・デフォルト deny 維持）、§2.10（レスポンスのフィールド選択）、§2.11（`ScoringStrategy` / `TextProcessor` の IF 形状にベクトル・fuzzy・多言語を織り込む） |
| **データモデルとインデックス移行設計書** | §2.2（`excluded` mapping ＋ `mustNot` 否定形の共存期ルール）、§2.3（multiGet 確定・`scripted_upsert` は `SuggestStore` の拡張点）、§2.12（refresh 戦略の分離）、§2.13（シャード/レプリカを API で受ける）、§2.14（`number_of_replicas` 削除）、および MIG-01（単一マージ規則）・MIG-02（死蔵 score 廃止）・二重エイリアスによるゼロダウンタイム切替手順（KEEP-02） |
