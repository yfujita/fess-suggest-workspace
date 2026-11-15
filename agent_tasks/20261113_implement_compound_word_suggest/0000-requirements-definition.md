# 20261113_implement_compound_word_suggest

## 背景・目的

`docs/global/improvement_points/20261109/suggest_quality_evaluation.md` §4 #2「複合語・固有名詞が候補にならない」の改善設計。文書(クロール結果)由来の候補生成に、隣接する名詞の連結語を加える。

## 要件

### 現状(As-Is)

サジェストされる単語がトークナイザーによって細分化されている。

### あるべき姿(To-Be)

複合語や固有名詞がサジェストされる。

### 具体的にやること

- suggest_quality_evaluation.mdに記載されている問題の確認。
- 改善設計の確認 `task_docs/design_compound_word_suggest.md`
- 改善の実施
- ユーザー動作確認時に問題あればその対応

## 対象範囲

- fess-suggest

## スコープ外

- 実際にFessへの組み込みはユーザーが行う。


## 完了条件

- [ ] コード改修が完了
- [ ] ユーザーがFessに組み込んで動作確認を行って問題ない。

## 成果物

- fess-suggestの改修後のコード

## 補足・参考情報

- `task_docs/design_compound_word_suggest.md`
- `docs/global/improvement_points/20261109/suggest_quality_evaluation.md`
