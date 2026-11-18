# 20261116_implement_query_evaluation_3

## 背景・目的

`docs/global/improvement_points/20261109/suggest_quality_evaluation.md` §4 #3「断片が候補になる」の改善実装。

## 要件

### 現状(As-Is)

「なかっ」のように断片が候補になる

### あるべき姿(To-Be)

意味のない断片が候補にならない。または候補となる断片が少なくなる。

### 具体的にやること

- 設計書の確認 `task_docs/design_fragment_suggest.md`
- 改善の実装
- ビルド確認・単体テスト
- ユーザーがFessに組み込んでの確認

## 対象範囲

- fess-suggest

## 完了条件

- [ ] 実装が完了し、テストも完了している

## 成果物

- fess-suggestの実装

## 補足・参考情報

- 設計書: task_docs/design_fragment_suggest.md
