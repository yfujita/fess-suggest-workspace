# 発見した課題・未確定事項

本ファイルは fess-suggest 調査ドキュメントの一部であり、調査の過程で発見した課題・未確定事項・運用理解上の要点を扱う。インデックス・前提（バージョン情報・参照ソースの所在・凡例）は [README.md](./README.md) を参照のこと。関連: [概要](./01-overview.md) / [全体アーキテクチャ](./02-architecture.md) / [サジェスト表示内容](./03-suggest-contents.md) / [fess 本体からの利用方法](./04-fess-integration.md)。

凡例: **[確認]** = ソースコードで直接確認できた事実、**[推測]** = 実装から合理的に推測した内容。根拠は `file_path:line` 形式。

---

## 5.1 ② 検索クエリログ経路が fess 本体で未使用 [確認]

- fess 本体から `indexFromQueryLog(...)` を呼ぶ箇所は存在しない（`grep` 確認）。fess は構造化済みの `SearchLog`（検索語・フィールド・ロール）を持つため、生の Lucene クエリ文字列を再パースする ② より ③（検索語経路）を採用している（`SuggestHelper` も `indexFromQueryLog` をラップしていない）。
- → ライブラリには ② のコードパスが残るが、fess 本体の標準フローでは到達しないデッドパスである。改修・削減の検討対象になりうる。

（4経路の整理は [04-fess-integration.md](./04-fess-integration.md) の 4.3、データソース定義は [03-suggest-contents.md](./03-suggest-contents.md) の 3.2 を参照）

## 5.2 `suggest.popular.word.cache.expire` のコメントと実装の不一致 [確認]

- `PopularWordHelper.java:77` で `TimeUnit.MINUTES` として渡されている（既定値 60 → 60分）。`fess_config.properties` のコメントは「秒」と記載されており、コメントと実装が不一致。**実装値（分）が正**。ドキュメント・運用判断は分で扱うこと。

（設定項目の一覧は [04-fess-integration.md](./04-fess-integration.md) の 4.2 を参照）

## 5.3 `SuggestWordsHandler` の `suggestDetail` 設定主体が未確定 [確認/推測]

- `SuggestWordsHandler` は `suggestResponse.getItems()` を参照している（`:106-113`、`text` と `tags`=`types` を取り出す）が、コード上で `setSuggestDetail(true)` の明示呼び出しは見当たらない。
- → **[確認]** fess が `items` を参照している事実は確認済み。**[推測]** ライブラリ側ビルダの既定挙動（`suggestDetail` の既定値）で `items` が返っている可能性がある。`items` が常に返る前提でリファクタリングする場合は、`SuggestRequestBuilder` の `suggestDetail` 既定を確認すべき。

（レスポンス項目の詳細は [03-suggest-contents.md](./03-suggest-contents.md) の 3.5、UI/API 経路は [04-fess-integration.md](./04-fess-integration.md) の 4.5 を参照）

## 5.4 bad word の wildcard 削除の影響範囲 [確認/注記]

- `addBadWord(apply=true)` は `deleteByQuery(wildcardQuery(TEXT, "*badword*"))` で既存語を削除する（`WordManagementOperations.java:77-84`）。部分一致削除のため、意図せず広い範囲の語が削除されうる。コード上は確認済みだが影響評価は未実施。運用・改修時の注意点。

## 5.5 二段マージ・二段権限フィルタの整合性 [確認/注記]

- 登録時、同一バッチ内マージ（`SuggestItemMerger`）と OpenSearch 既存 doc とのマージ（`toUpdatedSource`）の二段でマージが行われる。集約の正確性を検証する際は両方を確認する必要がある。（マージ規則は [03-suggest-contents.md](./03-suggest-contents.md) の 3.4 を参照）
- 検索時、ライブラリ側の `_guest_` 補完（`SuggestRequest.java:354-356`）と API 側の `RoleQueryHelper` による `addRole`（`SuggestWordsHandler.java:83`）で権限フィルタが二重に担保されている。

## 5.6 運用理解上の要点（課題ではないが申し送り）

- サジェスト索引は **バッチ（毎日12:00 全件再構築）＋ リアルタイム（検索ごとの検索語追加）** の二段構成。
- purge は Kind 条件（DOCUMENT のみ / QUERY のみ）で古語を削除し、USER・複数 Kind 語は保護する。
- 検索エイリアス/更新エイリアスの二重構造により再構築はゼロダウンタイム。
