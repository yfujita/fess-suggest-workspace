# 0005 設計書の作成(フェーズ3)

担当: document-writer。コード・他ファイルは変更していない。

## 成果物
`agent_tasks/20261113_improve_suggest_query/task_docs/design_compound_word_suggest.md`(新規、195 行)

構成: 1 背景と原因 / 2 方針 / 3 変更内容(3.1 fess-suggest の変更点、3.2 連結アルゴリズム、3.3 `SuggestItem` の組み立て、3.4 System property、3.5 データ・インデックスへの影響)/ 4 エッジケース・互換性・移行 / 5 テスト方針 / 6 他の改善点との相互影響 / 7 実装前に確認する事項・リスク・関連課題。経緯語(作業記録・フェーズ・承認など)が 0 件であることを grep で確認済み。

## コードと突き合わせて確認した事実
- `DefaultContentsParser.parseDocument` は `:154-211`、`words={word}` は `:185`、チャンク分割は `analyzeTextInternal` `:261`、System property 読み込みは `:75`。
- `fess-res:suggest_indices/suggest_analyzer.json`: `contents_analyzer_ja` は `:64-68`、`pos_filter` は `:1291`、`content_length_filter` は `max: 30`(`:1374`)。構成は char_filter 1 + tokenizer + filter 5 段。`stoptags` に `名詞-数` と `名詞-接尾-*` を含む。
- tokenizer は fess 本体が `fess_japanese_normal`、`_vanilla` が `kuromoji_tokenizer`、fess-suggest 同梱版が `kuromoji_neologd_normal`。`_vanilla` は fess 側(`fess-res:suggest_indices/_vanilla/`)にある。
- `contentsReadingConverter` の既定は `KatakanaToAlphabetConverter`(`SuggestUtil.java:266`)。`SuggestItem` の ID は `text` の Base64(`SuggestUtil.java:93`)で、同 ID は `SuggestItem.merge`(`:446`)で統合される。
- Lucene Kuromoji 9.5.0 / IPADIC の再実行: 6 語はすべて 2 トークンの連続列として連結される。`神奈川県` も連結される。`検索 エンジン`、`3000万円`、`令和5年度` は連結されない。

## 0003 との食い違い(重要)
- 0003 §4 は「Fesen の HTTP クライアントが `detail` を読む」としたが、**使用中の `fesen-httpclient 3.9.0` は Java API から `detail` を取れない**(`AnalyzeRequestBuilder.setExplain` なし、`Response.detail()` なし、`getTokens()` は explain 時 null)。javap とコンパイルで確認した。
- 設計書の方式: リクエストは `builder.request().explain(true)`、応答は `Response.toXContent` で JSON 化して `detail.tokenizer.tokens[]` を読む。模擬の explain JSON を `HttpAnalyzeAction.fromXContent` で往復させ、`partOfSpeech` / `reading` / offset が残ることを確認した。実環境の応答は未確認。
- explain の段数は「約 7 段」ではなく、tokenizer + フィルタ 5 段。

## 設計書での小判断
- `compound.max.length` に 30 超の値を指定した場合は、`content_length_filter` と揃えて 30 に丸める。
- 連結対象品詞は完全一致で 12 種(0003 §3 の 11 種 + `名詞-接尾-地域`)。
- 連結語の抽出は既存の 1000 文字チャンク単位(offset がチャンク内の値のため)。
- System property 名は `fess.suggest.compound.enabled` / `.max.tokens` / `.max.length`(案。実装時に変更可)。
- `SuggestAnalyzer.analyzeTokenizerStage` を `null` を返す default メソッドで追加し、既存実装を壊さない。
- 読みが null のトークン(`AI`、`ChatGPT`)は表層形で代用する。

## 未対応事項・次にやること
- document-reviewer でレビューする(次工程)。
- 設計書の恒久化(`docs/global/` 配置)の要否をユーザーに確認する。
- 設計書の「実装前に確認する事項」: 実環境の explain が `partOfSpeech` / `reading` を返すか、explain の応答サイズ・処理時間、実コーパスの項目数増加率(+36% はサンプル文の概算)、NEologd の有無、他言語アナライザの扱い、explain でも `index.analyze.max_token_count` エラーが起きうるか。
