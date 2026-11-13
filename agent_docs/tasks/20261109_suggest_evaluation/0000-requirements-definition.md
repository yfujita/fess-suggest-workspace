# タスク: 20261109_suggest_evaluation

## 背景・目的

サジェストに表示される単語の品質を改善したい。

## 要件

- サジェストを実機で動作確認して、品質を評価し、改善点を見つける。特に日本語を重点的に。

## 対応範囲

- 改善点のリストアップ

## 完了条件

- 改善点のリストアップが完了。

## 動作確認方法

suggest apiの使用。

- ローカルAPI（最新）
  - 100件のドキュメントを元にクロールした結果からサジェストを生成したもの
  - http://localhost:8080/api/v2/suggest-words?q={フォーム入力文字列}&num=10&fn=_default&fn=content&fn=title
  - 元のドキュメントは `http://localhost:8080/api/v2/search?q={検索キーワード}&start=0&num=10` で検索できる。
- デモ環境（やや古い）
  - https://search.n2sm.co.jp/api/v1/suggest-words?q={フォーム入力文字列}&field=_default&field=content&field=title&num=20