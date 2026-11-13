# fess-suggest の概要

本ファイルは fess-suggest 調査ドキュメントの一部であり、ライブラリ全体の概要を扱う。インデックス・前提（バージョン情報・参照ソースの所在・凡例）は [README.md](./README.md) を参照のこと。関連: [全体アーキテクチャ](./02-architecture.md) / [サジェスト表示内容](./03-suggest-contents.md) / [fess 本体からの利用方法](./04-fess-integration.md) / [発見した課題](./05-issues.md)。

凡例: **[確認]** = ソースコードで直接確認できた事実、**[推測]** = 実装から合理的に推測した内容。根拠は `file_path:line` 形式。

---

**fess-suggest** は、検索エンジン **OpenSearch** 上に専用インデックスを構築し、検索画面のオートコンプリート（入力補完）と人気語表示のための「サジェスト語」を供給する Java ライブラリである **[確認]**（`modules/fess-suggest/CLAUDE.md`）。fess 本体はこれをライブラリとして組み込み、`org.codelibs.fess.suggest.*` を直接 import して利用する。

特徴（いずれも本ドキュメントで後述・[確認]）:

- **専用インデックス + 二重エイリアス**: サジェスト語は fess の文書インデックスとは別の専用インデックスに格納される。検索用エイリアスと更新用エイリアスを分離し、全件再構築をゼロダウンタイムで行える。（詳細: [02-architecture.md](./02-architecture.md) の 2.2）
- **決定的 ID による頻度集約**: サジェスト語の `_id` を語句テキストから決定的に生成し、同一語の出現を1ドキュメントに集約して出現頻度を累積する。（詳細: [02-architecture.md](./02-architecture.md) の 2.2）
- **複数データソースの統合**: ドキュメント本文・検索語・検索クエリログ・優先表示語（elevate word）という複数の供給経路を、同一の `SuggestItem` 構造に正規化して同じインデックスへ書き込む。（詳細: [03-suggest-contents.md](./03-suggest-contents.md) の 3.2）
- **読み（reading）対応**: 語の「読み」（カタカナ/ローマ字）を格納し、未確定入力（かな入力途中など）に対するマッチを可能にする。
- **function score によるランキング**: 検索時に出現頻度・手動ブースト・前方一致を組み合わせてスコアリングする。（詳細: [03-suggest-contents.md](./03-suggest-contents.md) の 3.4）
- **同期/非同期の使い分け**: 検索は常に非同期（独自の `Deferred`/`Promise`）。登録は単発系が同期、Reader を使うバッチ系が非同期。（詳細: [02-architecture.md](./02-architecture.md) の 2.3）

ライブラリ単体の主エントリポイントは `Suggester`（ファサード）であり、`Suggester.builder()....build(client, indexName)` で生成する（`Suggester.java:374`）。
