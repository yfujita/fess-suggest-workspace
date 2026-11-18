# 0002: 事前検証(フェーズ 1)

作成日: 2026-11-16 / 担当: code-implementer(記録はメインエージェント)

## 1. 概要

設計書 7 章の [要確認] のうち、ローカルで確かめられる項目(プランのフェーズ 1)を実施した。**項目 1〜3(必須)はすべて成立し、ゲートを通過した。** 使い捨ての検証テスト(`src/test/.../tmpverify/`)は削除済みで、`src/main` に変更はない。

- 開始時・終了時の `modules/fess-suggest`: HEAD `7db7938aeebeb70fbc0f7764b1bff12ed289dc95`(main)、`git status --short` は空。**レビューの比較基準はこの HEAD**。
- 生データ(scratchpad): `/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/e4bfbd87-1e6d-47a4-9c3b-1c79786606e5/scratchpad/phase1-out.txt`(項目 1〜3)、`.../scratchpad/phase1-out2.txt`(文字種・項目 4)。

## 2. 項目ごとの結果

### 項目 1: tokenizer 段に `inflectionForm` が出るか — 成立

- `SuggestTestServer` が読むのは fess-suggest 同梱の `suggest_indices/suggest_analyzer.json`(`search_engine.type` 未設定のため `_vanilla` は読まれない)。`kuromoji_neologd_normal` は `reloadable_kuromoji_tokenizer`、mode normal、`discard_punctuation=false`。`contents_analyzer_ja` と `contents_analyzer` は同じ構成。
- 入力 `それはなかったが、大きな犬は大きい。難しい問題だった。`(explain、attributes=`partOfSpeech, reading, inflectionForm`)の結果(`ja` と lang なしで同一):
  - `なかっ`: 形容詞-自立 / 連用タ接続
  - `大きい`、`難しい`: 形容詞-自立 / 基本形
  - `大き`、`難し`(別入力 `なかっ 大き 難し`): 形容詞-自立 / ガル接続
  - 名詞・助詞・記号には `inflectionForm` が付かない(クライアント再出力ではキーが欠落、REST の生応答では `null`)。
- 例文の注意: 「大きな」は連体詞で活用形判定の対象外。統合テストでは `大きく`(連用テ接続)、`大きかっ`・`難しかっ`(連用タ接続)などを使うと検知力が上がる。
- `_vanilla`(標準 `kuromoji_tokenizer`)は、ローカルに analysis-kuromoji の jar が無く**未確認**。取れない構成では活用形の除外が働かないだけで、誤って除外はしない(設計書 4.2)。ユーザーの実環境確認項目にする。

### 項目 2: Java クライアント経由の JSON で属性が落ちないか — 成立

- `Response.toXContent` → JSON(`AnalyzerSettings.convertToMap` と同じ処理)で `inflectionForm` が残る。例: `{"token":"なかっ","start_offset":3,"end_offset":6,...,"inflectionForm":"連用タ接続","partOfSpeech":"形容詞-自立","reading":"ナカッ"}`
- 実装の注意: 値が null または文字列以外なら「属性なし」と扱う(`toAnalyzeToken` は既存どおり null を入れない)。

### 項目 3: 最終段(通常の `analyze`)と tokenizer 段の (start, end, term) の一致 — 成立

- `ja` と lang なしの 2 通り、入力 7 種(半角カナ濁点付き、全角英数、サロゲートペア、絵文字を含む)で、最終段トークン 92 件のうち不一致 0 件。term は `toLowerCase(ROOT)` 後に一致(`AI`→`ai`、`gPU`→`gpu`)。explain の最終段(`limit_token_count_filter`)と `analyze()` も全ケースで一致。
- **設計に影響する発見**: トークンの offset は **char filter 前の元テキスト座標**(filteredText の座標ではない。例: 半角カナ入力で `大きい` は元 10–13、filtered では 7–10)。tokenizer 段と最終段は同じ座標系なので対応付けの前提は成立するが、offset を `charFilteredText` の `substring` に使ってはならない。活用形側は offset を「チャンク元テキスト内の座標」としてだけ使う。

### 項目 4: 応答サイズ・処理時間 — 参考値(合否には使わない)

交互に 8 ラウンド × 20 回、ウォームアップ 30 回。ローカル 1 ノード、explain=true。

| 条件 | 足す前 | 足した後 |
| --- | --- | --- |
| 1000 文字 クライアント再出力 JSON | 299,781 chars | 312,783 chars(+4.3%) |
| 1000 文字 REST 生応答 | 300,501 chars | 356,337 chars(+18.6%。`inflectionForm: null` が全トークンに出るため) |
| 1000 文字 平均処理時間 | 22.7 ms | 22.6 ms |
| 8000 文字 クライアント再出力 JSON | 2,462,545 chars | 2,564,551 chars(+4.1%) |
| 8000 文字 REST 生応答 | 2,468,440 chars | 2,916,616 chars(+18%) |
| 8000 文字 平均処理時間 | 176.8 ms | 174.2 ms |

- 処理時間の差はノイズの範囲。explain 1 回分は 1000 文字で約 23 ms、8000 文字で約 175 ms。通常の `analyze`(8000 文字で約 15 ms)の約 10 倍以上で、設計書 7 章 5(連結語が無効で活用形が有効なときの負荷)の裏付けになる。応答が大きい点は属性追加の前から(全 filter 段のトークンが出るため)。
- 8000 文字は 1 回の測定。数万文字のチャンクはユーザーが実環境で測る。

### 項目 6: `analyzeText` を継承する外部コード — ワークスペース内には無し

`modules/fess`、`modules/fess-suggest` に `extends DefaultContentsParser`・匿名サブクラスは無い。呼び出しは `DefaultContentsParserTest` のみ(`test_analyzeText`、`test_analyzeTextByReading`、`test_analyzeTextWithLargeContent`)。`ContentsParser` の他の実装も無い。第三者の外部コードは確認できないため、引き渡しメモに注意書きを残す。

### 項目 7: lang の値の形式 — `ja` 形式(最小長の規則は日本語文書に効く)

`parseDocument` は `document.get(langFieldName)` の `toString()` を lang にする(`:359`)。`langFieldName` の既定は `lang`(`SuggestSettings.java:540`)で、`modules/fess` は上書きしていない。`LanguageHelper.updateDocument` が `supported.languages` の項目を小文字化・`_`→`-` 化して入れる(日本語は `ja`、`zh_CN` は `zh-cn`)。端のケース: 未サポート値かつ言語検出失敗なら生の値(`ja_JP` など)が残りうるが、その場合は最小長の規則が効かないだけ(設計書 3.3 の安全側)で、実害は小さい。

### 文字種の確認(`Character.UnicodeScript` / `isLetterOrDigit`)

設計書 3.3 の方針(コードポイント単位、`isLetterOrDigit` による C2 判定、ASCII 英数と HIRAGANA / KATAKANA / HAN の判定)は想定どおり。

- `ｶ`、`ｱ`、`ｧ`、`ｯ`、`ﾊ` は KATAKANA。半角の濁点・半濁点(`ﾞ`、`ﾟ`)は COMMON で `isLetterOrDigit=true` のため、C2 にもかな 1 文字規則にも掛からない。`mapping_char` の濁点の写像は一部だけで、`ﾊﾟ` は `ハﾟ`(2 文字)で残る(既知の挙動。実害は小さい)。
- `ー`(U+30FC)・`ｰ` は COMMON で `isLetterOrDigit=true` → かな 1 文字規則では拾えず、C1 の別規則が要る(設計どおり)。`ッ`・`っ` は単独でも C1 で除外される。
- 異体 `ゝ`、`ヽ`、`ヶ` などは かな 1 文字規則に掛かる。`𛀁`(サロゲートペア)は HIRAGANA。
- `𠮷`、`𩸽` は HAN、`length()=2` / コードポイント 1 → コードポイント単位で数えること(`length()` は誤判定)。`々` は HAN で `isLetterOrDigit=true`(`single.han.enabled` 有効時に単独で除外される)。`〇` は HAN だが `isLetterOrDigit=false`(C2。設計書記載どおり)。
- 絵文字は単独なら C2。全角英数は `mapping_char` で半角化されるため ASCII のみを対象にすれば足りる。

## 3. フェーズ 1 の対象外とした項目(プランどおり)

設計書 7 章の 5(連結語無効時の負荷)、8(評価ゲート)、9(1 文字英数の個別設定の要否)は、ユーザーの実環境確認に委ねる。

## 4. 実装で守る点

1. offset はチャンク元テキスト内の座標として扱い、`charFilteredText` に当てない。
2. 文字種はコードポイント単位で判定する。
3. 応答パーサは `inflectionForm` が null または文字列以外のとき「属性なし」と扱う。
4. 統合テストの例文は、連体詞の「大きな」だけに頼らず、`大きく`・`大きかっ`・`難しかっ` なども使う。

## 5. 永続化するテストの案(フェーズ 2・5 に取り込む)

1. `analyzeTokenizerStage` の実応答で、`なかっ`(連用タ接続)、`大き`・`難し`(ガル接続)、`大きい`・`難しい`(基本形)を確認する。
2. 通常の `analyze` の各トークンについて (start, end, lower(term)) が tokenizer 段と一致することを確認する。入力: `ｶﾞｲﾄﾞﾌﾞｯｸは大きい。ﾜｸﾁﾝ接種が難しかった`、`ＡＩ活用の最前線 ＧＰＵサーバーは大きくなかった`。
3. offset が元テキスト座標であることを前提にしたテスト(活用形の判定が offset だけで term と突き合わせる設計であることの確認)。

## 6. 未対応事項・次のアクション

- `_vanilla` 構成での `inflectionForm` は未確認(引き渡しメモ、ユーザーの実環境確認項目)。
- 引き渡しメモに載せる: `_vanilla` 未検証、lang は `ja` 形式、ワークスペース内に `analyzeText` の継承なし(外部は注意書き)、explain は通常の analyze の約 10 倍以上のコスト。
- 次: フェーズ 2(属性の追加と応答解析)。
