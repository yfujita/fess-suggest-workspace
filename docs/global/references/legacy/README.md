# fess-suggest 調査ドキュメント（インデックス）

本ディレクトリは fess のサジェスト用ライブラリ **fess-suggest** と、それを利用する **fess 本体** のサジェスト機能について、ソースコードを調査して整理したグローバルリファレンスである。
サジェスト機能を改修・拡張・移行する際の出発点として参照することを想定している。

元は単一ファイル（`fess-suggest-overview.md`）として作成されたものを、読者が目的に応じて必要な部分だけを参照できるよう、目的別に複数ファイルへ分割した。本 README はそのインデックスであり、あわせて全体共通の前提となる「バージョン情報・参照ソースの所在」（旧 §0）と「要件カバレッジ」（旧 §6）を収容する。

記述の凡例:
- **[確認]**: ソースコードで直接確認できた事実。
- **[推測]**: 実装から合理的に推測した内容（断定ではない）。
- 根拠は `file_path:line` 形式で示す。パスは原則として各モジュールルート（`modules/fess-suggest/` または `modules/fess/`）以下の短縮表記。fess-suggest の Java ソースは特記なき限り `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下。

---

## どの目的のときどれを読むか（ガイド）

| 知りたいこと | 読むファイル |
| --- | --- |
| fess-suggest とは何か・特徴の概要 | [01-overview.md](./01-overview.md) |
| 全体アーキテクチャ（コンポーネント図・インデックス構造・登録/検索フロー・公開 API） | [02-architecture.md](./02-architecture.md) |
| サジェストに何が表示されるか（種別・データソース・スコアリング・表示項目） | [03-suggest-contents.md](./03-suggest-contents.md) |
| fess 本体からの利用方法（呼び出し経路・設定項目・バッチ/リアルタイム・UI/API） | [04-fess-integration.md](./04-fess-integration.md) |
| 発見した課題・未確定事項 | [05-issues.md](./05-issues.md) |
| バージョン情報・参照ソースの所在・要件カバレッジ | 本ファイル（下記） |

各ファイルは h1 から始まる独立した文書であり、相互参照は相対リンクで辿れる。

---

## 0. 調査時点のバージョン情報と参照ソースの所在

### 0.1 バージョン

| 項目 | 値 | 根拠 |
| --- | --- | --- |
| fess-suggest バージョン | `15.7.1-SNAPSHOT` | `modules/fess-suggest/pom.xml`（`<artifactId>fess-suggest</artifactId>` の `<version>`） |
| fess 本体バージョン | `15.7.0-SNAPSHOT` | `modules/fess/pom.xml`（`<artifactId>fess</artifactId>` の `<version>`） |
| 共通親 POM | `org.codelibs.fess:fess-parent:15.7.0` | 両 `pom.xml` の `<parent>` |
| 検索エンジン | **OpenSearch** | `modules/fess-suggest/pom.xml`（`org.opensearch:opensearch` 依存）/ `modules/fess/CLAUDE.md`（Tech Stack）/ コードが `org.opensearch.transport.client.Client` を直接利用（`Suggester.java:53`） |
| Java | **21 以上** | `modules/fess-suggest/CLAUDE.md`（"Java 21+, Maven"）。record / パターンマッチ instanceof 構文を使用（`index/operations/ContentIndexingOperations.java:443`） |
| ビルド | Maven | 両モジュールの `pom.xml` |
| fess → fess-suggest 依存 | `org.codelibs.fess:fess-suggest:${suggest.version}` を依存宣言 | `modules/fess/pom.xml:1401-1404` |

> **[注意]** OpenSearch / Lucene の具体的な数値バージョンは `fess-parent:15.7.0`（本ワークスペース外）の `<properties>` で定義されており、本ワークスペース内のファイルだけでは解決できない。検索エンジンが **OpenSearch 系**（Elasticsearch ではない）である点は、依存定義・import・CLAUDE.md から確定している **[確認]**。正確な OpenSearch バージョンが必要な場合は `fess-parent` の POM を参照すること。

### 0.2 主要な参照ソースの所在

| 領域 | 主要パス |
| --- | --- |
| サジェストのファサード / ライフサイクル | `modules/fess-suggest/.../suggest/Suggester.java` |
| 登録（インデキシング） | `modules/fess-suggest/.../suggest/index/SuggestIndexer.java`, `index/operations/`, `index/contents/`, `index/writer/` |
| 検索（サジェスト取得） | `modules/fess-suggest/.../suggest/request/suggest/`, `request/popularwords/` |
| エンティティ / シリアライズ | `modules/fess-suggest/.../suggest/entity/`（`SuggestItem`, `SuggestItemSerializer`, `ElevateWord`） |
| インデックス定義リソース | `modules/fess-suggest/src/main/resources/suggest_indices/`（`mappings-default.json`, `suggest.json` ほか） |
| フィールド名定数 | `modules/fess-suggest/.../suggest/constants/FieldNames.java` |
| fess 本体のブリッジ | `modules/fess/.../helper/SuggestHelper.java` |
| バッチ再構築 | `modules/fess/.../exec/SuggestCreator.java`, `job/SuggestJob.java` |
| リアルタイム反映 | `modules/fess/.../helper/SearchLogHelper.java` |
| 検索 API | `modules/fess/.../api/v2/handlers/SuggestWordsHandler.java` |
| 人気語 | `modules/fess/.../helper/PopularWordHelper.java` |
| 管理画面 | `modules/fess/.../app/web/admin/{suggest,elevateword,badword}/` |
| 静的設定 | `modules/fess/src/main/resources/fess_config.properties`（`suggest.*`） |

---

## 6. 要件カバレッジ（調査3項目）

| 要件項目 | 該当ファイル |
| --- | --- |
| fess-suggest の概要 | [01-overview.md](./01-overview.md)（および本 README の §0 バージョン情報） |
| サジェストの全体的なアーキテクチャ | [02-architecture.md](./02-architecture.md)（インデックス構造・登録フロー・検索フロー・公開 API・コンポーネント図）、[04-fess-integration.md](./04-fess-integration.md)（fess 本体からの利用方法） |
| サジェストにどのようなものが表示されるか | [03-suggest-contents.md](./03-suggest-contents.md)（種別・データソース・スコアリング・表示項目）、[04-fess-integration.md](./04-fess-integration.md) の §4.5（UI/API 表示） |
