# 0017 未使用メソッド `analyzeText` / `analyzeTextByReading` の削除

## 1. 作業概要

ユーザーの指示「`analyzeText` および `analyzeTextByReading` がテストコードからしか呼ばれていない不要なメソッドになっていたら削除」に従い、呼び出し元を確認して削除した。

- 確認結果: `modules/` 配下の main コードに呼び出しはなく(`parseDocument` は private の `analyzeTextByChunk` を直接使う)、`DefaultContentsParserTest` の 3 テストだけが呼んでいた。よって不要と判断した。
- コミットは行っていない(`modules/fess-suggest` の作業ツリーに未コミットの変更)。

## 2. 変更ファイル(`modules/fess-suggest`)

- `src/main/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParser.java`
  - protected の `analyzeText` / `analyzeTextByReading` を削除。
  - `analyzeText` に言及していたコメントを調整。
  - private の `analyzeTextByChunk` は `parseDocument` が使うため残した。
- `src/test/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParserTest.java`
  - 削除したメソッドだけを対象にしていた `test_analyzeText` / `test_analyzeTextByReading` / `test_analyzeTextWithLargeContent` を削除。未使用になった `AnalyzeToken` の import も削除。
  - 大きな文書のチャンク分割は、残っている `parseDocument` のテスト(「Should handle large text by splitting into chunks」)が確認する。

`agent_tasks/20261116_implement_query_evaluation_3/task_docs/design_fragment_suggest.md` の 3.4 と未確認事項 6 も、削除後の状態に合わせて更新した。

## 3. 検証

- `mvn test -Dtest=DefaultContentsParserTest`: 9 件、失敗 0。
- import 削除後に `mvn test-compile` が成功。
- 全体の再実行(`mvn package`)はしていない。

## 4. 判断・影響

- protected メソッドの削除なので、継承して使う外部コードがあればコンパイルエラーになる。ワークスペース内には無い(STATUS.md の既存の未解決事項)。
- レビュー(code-reviewer 等)は、数行の削除のため省略した。

## 5. 未対応事項

- 全体テスト(`mvn package`)の再実行。必要ならユーザーの指示で行う。
- 既存の作業記録(0001〜0016)と STATUS.md の過去記述に `analyzeText` への言及が残る。作業記録は書き換えない方針のため、そのままにした。
