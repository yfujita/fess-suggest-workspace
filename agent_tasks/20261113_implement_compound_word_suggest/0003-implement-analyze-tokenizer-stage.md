# 0003 フェーズ2: SuggestAnalyzer 拡張と DefaultContentsAnalyzer.analyzeTokenizerStage

実施: code-implementer。結果: 完了。`analyzeTokenizerStage` が実 explain 応答から `partOfSpeech` / `reading` / offset / `filtered_text` を取得できることを統合テストで確認した。

## 変更ファイル(`modules/fess-suggest/` 配下)

新規
- `src/main/java/org/codelibs/fess/suggest/analysis/TokenizerStageResult.java`: 不変クラス。`getTokens()`(`List.copyOf` の防御コピー)、`getCharFilteredText()`。両引数 `requireNonNull`(既存コードに record が無いため getter 付きクラス)。
- `src/test/java/org/codelibs/fess/suggest/analysis/DefaultContentsAnalyzerTokenizerStageTest.java`: `SuggestTestServer` を使う統合テスト 9 件。
- `src/test/java/org/codelibs/fess/suggest/analysis/TokenizerStageResultTest.java`: 単体 3 件。

変更
- `analysis/SuggestAnalyzer.java`: `default TokenizerStageResult analyzeTokenizerStage(text, field, lang)`(`null` を返す)を追加。`null` は「取得不可」(未対応・`_analyze` 失敗・応答に必要な情報なし)と JavaDoc に明記。
- `settings/AnalyzerSettings.java`: `DefaultContentsAnalyzer.analyzeTokenizerStage` と解析用 private メソッド、定数 `PART_OF_SPEECH_ATTRIBUTE` / `READING_ATTRIBUTE` を追加。
- `src/test/.../analysis/SuggestAnalyzerTest.java`: default 実装が `null` を返すテストを 1 件追加。

`DefaultContentsParser`、`suggest_analyzer.json`、`modules/fess`、`SuggestTestServer` は未変更。既存 public API のシグネチャは変更なし。

## 実装の要点

- 文字数上限(`text == null || length > maxContentLenth` で `null`)とアナライザ名解決(`getContentsAnalyzerName`)は `analyze` と同じ。
- `explain(true)` + `attributes(["partOfSpeech","reading"])`。応答は `toXContent` → JSON → `XContentHelper.convertToMap`。`detail.tokenizer.tokens[]` と `detail.charfilters[0].filtered_text[0]`(単数形)を読む。`AnalyzeToken` は `(term, position, startOffset, endOffset, 1, type, attributes)`。`reading` が無いトークンは `reading` キーを入れない。
- `null` になる場合: `detail`/`tokenizer` なし、`filtered_text` なし、トークンの形が不正、`partOfSpeech` が一度も出ない。
- `_analyze` 失敗(`OpenSearchException | IOException | IllegalArgumentException | IllegalStateException`。トークン数超過を含む)は例外を投げず、警告ログ(analyzer / field / lang / textSize / error。本文は出さない。debug 時のみスタックトレース)+ `null`。
- 構造的な `null`(`partOfSpeech` なし等)は debug ログのみ。`en` など非日本語アナライザで全チャンクが該当し、警告だと大量に出るため。

## 判断: null の区別

default 実装の `null` と `_analyze` 失敗の `null` を区別する API は追加しなかった(公開インターフェースを増やさない)。`DefaultContentsAnalyzer` を使う限り default の `null` は発生しない。失敗の原因は警告ログで追える。区別が必要になれば `default boolean supportsTokenizerStage()` を足す最小案がある(必要になった場合のみ)。

→ 設計書 4.5 の縮退原因のうち「`partOfSpeech` なし」「本文なし」「`_analyze` 失敗」は、パーサ側では「`analyzeTokenizerStage` が null」の 1 区分として数える(内訳はアナライザのログ)。「offset 不正」「照合失敗」「上限超過」はパーサ側で個別に数える。この点は設計書 4.5 の原因別内訳からの縮小であり、レビューで確認する。

## 検証

`modules/fess-suggest` で `mvn -q compile` 成功、`mvn -q formatter:format license:format` 実行、`mvn -q test -Dtest='DefaultContentsAnalyzerTokenizerStageTest,TokenizerStageResultTest,SuggestAnalyzerTest,AnalyzerSettingsTest'` 失敗なし(9 + 3 + 20 + 7 件)。

統合テストの検証内容: `新型コロナ` の品詞・読み・offset・`filtered_text`、`高市早苗` の品詞(人名-姓 / 人名-名)、`ｶﾞｲﾄﾞﾌﾞｯｸ新型コロナ` で `filtered_text == "ガイドブック新型コロナ"` かつ offset が元の本文の座標(同じ offset を `filtered_text` に適用すると別の文字列)かつ隣接、`ＡＩ活用` → `AI活用`、`ChatGPT` に `reading` キーなし、50,001 文字・null 入力・`en` で `null`、`円安` を 10,000 回繰り返した 20,000 文字(空白なし)で通常 `analyze` は成功し `analyzeTokenizerStage` は例外なく `null`(その後のリクエストも成功)。`filtered_text` のキーを誤ると検証テストが落ちる。

## フェーズ1との差分

なし(実測どおり)。V8 の制約 1 を受け、`_analyze` 失敗は警告ログ + `null`。

## 未対応事項・次にやること

- フェーズ3(`DefaultContentsParser` の連結ロジック)へ。
- 約 17,000 文字超の空白なしチャンクは explain 失敗で警告ログがチャンクごとに出る。ログ量が問題なら、フェーズ3の縮退カウンタ側で集約する。
- 実環境(`fess_japanese_normal` / `_vanilla`)での確認はユーザー作業。
