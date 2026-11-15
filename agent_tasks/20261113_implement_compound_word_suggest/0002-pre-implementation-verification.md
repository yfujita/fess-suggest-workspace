# 0002 フェーズ1: 事前検証(explain 応答の実測)

実施: code-implementer。環境: `SuggestTestServer`(実 OpenSearch 3.9.0 + ExtensionPlugin、`kuromoji_neologd_normal` 構成)。fesen-httpclient 経由と素の HTTP の両方で確認。`src/main` は未変更。使い捨ての検証テストは削除済み(リポジトリに残っていない)。

## 判定

ゲート(V1〜V4)はすべて成立。フェーズ2に進む。

| # | 判定 | 内容 |
| --- | --- | --- |
| V1 | 成立 | `contents_analyzer` / `contents_analyzer_ja` とも `detail.tokenizer.tokens[]` に `partOfSpeech` と `reading` が出る(両者は同一応答。tokenizer は `kuromoji_neologd_normal`、char_filter は `mapping_char` のみ) |
| V2 | 成立 | `builder.request().explain(true)` と `request().attributes(List.of("partOfSpeech","reading"))` はコンパイル・実行できる。explain 時 `getTokens()` は `null`。`Response.toXContent` → JSON → Map(`XContentHelper.convertToMap(new BytesArray(json), true, XContentType.JSON).v2()`)で属性は落ちず、素の HTTP の応答と一致。`attributes` 指定で応答は縮小(`新型コロナ` で 3721→1741 文字、素の HTTP で 5321→1745 文字) |
| V3 | 成立 | `detail.charfilters[0].filtered_text` は単数形キー、値は文字列の配列(`["新型コロナ"]`) |
| V4 | 成立 | tokenizer 段の offset は元の本文の座標。`ｶﾞｲﾄﾞﾌﾞｯｸ新型コロナ`(14 文字)は `filtered_text` が `ガイドブック新型コロナ`(11 文字)になり、offset を `filtered_text` に直接適用すると誤った語になることを実測。「offset を `filtered_text` に直接適用しない」(設計書 3.2)が正しい。連続性判定は元の座標で成立 |
| V5 | 実測済 | 下記 |
| V6 | 確認済 | 読みの無いトークンは `reading` キーが存在しない(`getAttributes().get("reading") == null` で判定)。`ChatGPT`、`iPhone`、`15`、`AI`、`アイフォン` が該当。空白トークンも reading なし。記号は reading が自身の文字 |
| V7 | 確認済 | `contents_analyzer_en`・`_th` の tokenizer 段に `partOfSpeech` なし(token / start_offset / end_offset / type / position のみ)。縮退で連結なしになる |
| V8 | 参考値(制約あり) | 下記 |
| V9 | 対象外 | `_vanilla` 構成は `modules/fess` にのみある。`SuggestTestServer` では `search_engine.type` が未設定で常に neologd 構成。実環境確認はユーザー |

`AnalyzeToken` のコンストラクタは public でスタブに使える: `(String term, int position, int startOffset, int endOffset, int positionLength, String type, Map<String,Object> attributes)`。**position が先で offset が後**。

## V5 分割結果(neologd、単独入力)

| 入力 | トークン(品詞)[offset] | reading |
| --- | --- | --- |
| 新型コロナ | 新型(名詞-一般)[0,2) / コロナ(名詞-一般)[2,5) | シンガタ / コロナ |
| 大統領選 | 大統領(名詞-一般)[0,3) / 選(名詞-接尾-一般)[3,4) | ダイトウリョウ / セン |
| 高市早苗 | 高市(名詞-固有名詞-人名-姓)[0,2) / 早苗(名詞-固有名詞-人名-名)[2,4) | タカイチ / サナエ |
| 石破首相 | 石破(名詞-固有名詞-人名-姓)[0,2) / 首相(名詞-一般)[2,4) | イシバ / シュショウ |
| ワクチン接種 | ワクチン(名詞-一般)[0,4) / 接種(名詞-サ変接続)[4,6) | ワクチン / セッシュ |
| 円安 | 円(名詞-一般)[0,1) / 安(名詞-接尾-一般)[1,2) | エン / ヤス |
| 神奈川県 | 神奈川(名詞-固有名詞-地域-一般)[0,3) / 県(名詞-接尾-地域)[3,4) | カナガワ / ケン |

設計書のオフライン再現(IPADIC)と分割・品詞とも一致。7 語とも 2 トークン・offset 隣接で対象品詞 12 種に含まれ、連結語になる。

文脈付きの観察(テスト期待値に使える)

- `新型コロナウイルス感染症が拡大した。`: 新型 / コロナ / ウイルス(名詞-一般)/ 感染(名詞-サ変接続)/ 症(名詞-接尾-一般)/ が(助詞)…。連続列は 5 トークン・12 文字(上限ちょうど)。neologd でも `新型コロナウイルス` は 1 語にならない。
- `高市早苗氏が石破首相と会談した。`: `氏`(名詞-接尾-人名)は対象外。連結語は `高市早苗`、`石破首相`。
- `ワクチン接種、新型コロナ、円安、検索 エンジン`: `、`(記号-読点)で途切れ、連結語は `ワクチン接種`・`新型コロナ`・`円安`。**空白もトークン(記号-空白)として出る**。対象外品詞なので連結は切れる。
- `3000万円の令和5年度予算`: 数・助数詞が対象外で連結語は出ない。
- `神奈川県横浜市`: 4 トークンで連結語 `神奈川県横浜市`。
- `ホーム製品情報会社概要`: 5 トークンすべて名詞-一般で連結語になる(設計書 4.3 のナビゲーション文字列の懸念どおり)。
- `ﾜｸﾁﾝ接種` → `ワクチン接種`(トークン `ワクチン`[0,4)、`接種`[4,6))。`ＡＩ活用` → `AI活用`(`AI`[0,2)、`活用`[2,4))。`ﾊﾟｿｺﾝ` は `mapping_char` で半濁点が単独のまま `ハﾟソコン` になる(既存挙動)。

## V8 長いチャンクの参考値(空白なしの日本語繰り返し)

| 入力長 | explain + attributes | explain(attributes なし) | 通常 analyze |
| --- | --- | --- | --- |
| 1,000 文字 | 約 309 KB、50〜70 ms | 約 735 KB、60〜80 ms | 6〜12 ms |
| 10,000 文字 | 約 3.16 MB、290〜370 ms | 約 7.4 MB、400〜480 ms | 約 20 ms |

- explain は 1 文字あたり約 300 バイト。通常 analyze の 5〜10 倍の処理時間。
- **制約 1(重要)**: `index.analyze.max_token_count`(10000)超過が **explain でのみ**発生する。通常 analyze は `limit_token_count_filter` で打ち切られ 50,000 文字でも成功するが、explain は tokenizer 段のトークン数で判定され、`illegal_state_exception: The number of tokens produced by calling _analyze has exceeded the allowed maximum of [10000]`(`OpenSearchStatusException`)になる。この入力では 15,000 文字は成功、20,000 文字は失敗(目安は約 17,000 文字前後。トークン密度 0.57/文字の場合)。→ 空白のない長文チャンクでは explain が例外になり、**そのチャンクは連結語なし(断片のみ)に縮退する**(設計書 4.1)。
- **制約 2(提案、今回は不採用)**: tokenizer + char_filter のみを指定した explain(素の HTTP で確認)は、1,000 文字で約 70 KB・約 14 ms、10,000 文字で約 720 KB・約 52 ms と大幅に小さい。アナライザの tokenizer 名・char_filter 名をインデックス設定から引く必要があり、fesen-httpclient 側で組み立てられるかは未検証。設計書の方針(アナライザ名で explain)から外れるため採用しない。実環境で応答サイズ・処理時間が問題になった場合の対策案として残す。

## 判断・方針への反映

- 設計書の [確認] 記載(`explain(true)`、`attributes(List)`、`filtered_text` 単数形)は実測で裏付けられた。想定と違った点は無い。
- 実測はすべて neologd 構成(ローカル)。実環境(`fess_japanese_normal`)の `partOfSpeech` / `reading` / offset / 分割の確認は、ローカルでは代替できずユーザー作業(引き渡しメモの測定チェックリストに含める)。
- V8 の制約 1 を受けて、フェーズ2・3 を次の方針で進める(設計書 4.1「`_analyze` が失敗した → `null`」の範囲内で、プランの変更ではない)。
  - `analyzeTokenizerStage` は `_analyze` 失敗(トークン数超過を含む)で例外を投げず、警告ログを出して `null` を返す。
  - フェーズ3の縮退カウンタは「`_analyze` 失敗」を default 実装の `null`(未対応アナライザ)と区別して数える。
  - 統合テストに「explain がトークン数超過になる長文(約 20,000 文字の空白なし日本語)でも例外なく縮退する」ケースを加える。
- フェーズ2の統合テストに取り込む資産(退避コピー): `/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/29c14188-937e-4a69-b0fc-ef50091ed0cd/scratchpad/CompoundWordPreVerificationTest.java.txt`(explain 呼び出しヘルパー、JSON→Map 変換、`detail.tokenizer.tokens[]` / `detail.charfilters[0].filtered_text[0]` の取り出し)。実行出力全文は同ディレクトリの `out.txt`。

## 未対応事項・次にやること

- フェーズ2(`TokenizerStageResult`、`SuggestAnalyzer` default メソッド、`DefaultContentsAnalyzer.analyzeTokenizerStage` と統合テスト)へ進む。
- 実環境での確認項目(ユーザー作業): `fess_japanese_normal` 構成での品詞・読み・offset、explain の応答サイズ・処理時間(設計書 7 章ゲート 2)、`_vanilla` 構成。
- 空白のない約 17,000 文字超のチャンクは explain が失敗し連結語が出ない(断片のみ)。これは既知の制約として引き渡しメモに記載する。
