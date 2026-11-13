# 原因調査: 複合語・固有名詞が候補にならない（改善点 #2）

凡例: **[確認]** コード・実機で確認 / **[推測]** 根拠からの推定（未検証）

## 1. 結論

| 対象語 | 原因 | 根拠（概要） |
| --- | --- | --- |
| `新型コロナ`・`高市早苗`・`ワクチン接種` | **分割** | 構成語に分割され、1トークン=1候補で登録される。構成語（`新型` 等）は索引に存在する |
| `大統領選`・`円安` | **分割 + 品詞除去** | `選`・`安` が `名詞-接尾-一般` で除去され、`大統領`・`円` だけが残る |
| `石破首相` | **データ不在** | クロール文書に `石破首相` は0件（実際は `石破茂前首相`・`石破前首相` 等） |

- **クエリ側は原因ではない** [確認]。同じ語が1語の候補として索引にあれば、表記・読みの前方一致で返る（3章）。
- **閾値は #2 の直接原因ではない** [確認]。`suggest.min.hit.count` は検索ログにのみ適用され、構成語は高い docFreq で索引済み。ただし文書の処理件数に上限があり、頻度は過小になっている（4章）。

## 2. 実解析結果（分割・品詞除去）

実機の `fess_suggest_analyzer` 索引（fess の `suggest_analyzer.json` から生成、OpenSearch 3.9.0）に `_analyze`（`explain: true`）を実行した結果 [確認]。

- `contents_analyzer_ja` = `fess_japanese_normal`（normal モード）+ `pos_filter` 等（`modules/fess/src/main/resources/suggest_indices/suggest_analyzer.json:64-68`）。`contents_reading_analyzer_ja` はこれに `reading_form` を加えたもの（同 `:70-74`）。実機定義とファイルの内容は一致。

| 入力 | 品詞（tokenizer） | `contents_analyzer_ja` の出力 (term, position, start-end) | 除去 |
| --- | --- | --- | --- |
| 新型コロナ | 新型=名詞-一般, コロナ=名詞-一般 | (新型,0,0-2) (コロナ,1,2-5) | なし |
| 高市早苗 | 高市=名詞-固有名詞-人名-姓, 早苗=…-人名-名 | (高市,0,0-2) (早苗,1,2-4) | なし |
| ワクチン接種 | ワクチン=名詞-一般, 接種=名詞-サ変接続 | (ワクチン,0,0-4) (接種,1,4-6) | なし |
| 石破首相 | 石破=…-人名-姓, 首相=名詞-一般 | (石破,0,0-2) (首相,1,2-4) | なし |
| 大統領選 | 大統領=名詞-一般, 選=**名詞-接尾-一般** | (大統領,0,0-3) | `選` |
| 円安 | 円=名詞-一般, 安=**名詞-接尾-一般** | (円,0,0-1) | `安` |
| 643円安、下落 | 643=名詞-数, 円=**名詞-接尾-助数詞**, 安=名詞-接尾-一般 | （下落 のみ） | `643`・`円`・`安` |
| 石破茂前首相 | 石破, 茂=…-人名-名, 前=**接頭詞-名詞接続**, 首相 | (石破,0,0-2) (茂,1,2-3) (首相,3,4-6) | `前` |

- 除去の根拠: `pos_filter` の stoptags に `名詞-接尾-一般`・`名詞-接尾-助数詞`・`名詞-数`・`接頭詞-名詞接続` がある（同 json `:1359`, `:1361`, `:1355`, `:1343`）[確認]。
- 候補化の単位: `parseDocument` はトークン1件ごとに `words = { word }` の SuggestItem を作る（`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParser.java:179-203`）。隣接トークンを結合する処理は無い [確認]。
- 実索引（`fess.suggest`）の document 由来候補: `新型`(docFreq 70)・`コロナ`(70)・`大統領`(90)・`高市`(91)・`早苗`(31)・`石破`(41)・`首相`(80)・`ワクチン`(5)・`接種`(5)・`円`(2) は存在し、連結語は document 由来では0件 [確認]。

## 3. クエリ側

- `SuggestQueryBuilder#buildQuery` は空白区切りの各語を正規化・読み変換し、最後の語を `reading_N` への prefix クエリにする（`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/request/suggest/SuggestQueryBuilder.java:85-113`）[確認]。
- クエリの読みは `AnalyzerConverter` が `reading_analyzer_ja`（品詞除去なし）のトークンの読みを連結して作る（`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/converter/AnalyzerConverter.java:123-163`）。`新型コロナ`→`シンガタコロナ`、`円安`→`エンヤス` [確認]。
- 実 API（`/api/v2/suggest-words`）で、検索ログ由来（kind=query）の `新型コロナ`・`大統領選`・`円安` が返ることを確認 [確認]:
  - `新型`→新型, 新型コロナ / `しんがたこ`→新型コロナ / `大統領`→大統領, 大統領選 / `えんや`→円安
  - 1語の候補が索引にあれば、表記・読みとも照合で落ちない。`高市早苗`・`石破首相` は索引に無いため0件。

## 4. 頻度・閾値

- `suggest.min.hit.count=1` は検索ログの hitCount 判定のみ（`modules/fess/src/main/java/org/codelibs/fess/helper/SuggestHelper.java:278`）で、文書由来の候補には効かない [確認]。
- 文書由来の処理件数上限: `suggest.update.contents.limit.num.percentage=50%`・`limit.num=10000`・`limit.doc.size=50000`（`modules/fess/src/main/resources/fess_config.properties:1617-1621`）。`ESSourceReader` は処理済み件数が `min(総数×50%, 10000)` を超えると読込を打ち切る（`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/index/contents/document/ESSourceReader.java:230`, `:324-330`）[確認]。102文書のうち約半数のみ処理される計算。
  - docFreq は出現回数の合計（`parseDocument` が1出現ごとに docFreq=1 を作り、`SuggestItemMerger.java:93` で加算）。`新型` は全文書で152回出現するが docFreq=70 であり、半数程度しか処理されていないことと整合する [推測]。
  - 文書サイズ上限（50000）を超える文書は0件（最大 41401 文字）[確認]。
- 対象語の文書内出現 [確認]: `新型コロナ` 100文書/135回、`高市早苗` 20/53、`ワクチン接種` 4/7、`大統領選` 3/5、`円安` 4/9、`石破首相` 0/0。

## 5. 隣接結合（案A）の実現性に関わる事実

- **offset 連続性** [確認]: 除去トークン・空白・句読点の箇所では offset が途切れる（`新型 コロナ`→2-3間に隙間、`大統領選で`→`大統領`(1-4) の次は `トランプ`(6-10)）。`前.endOffset == 次.startOffset` で「元テキストで直接隣接し、間に除去語が無い」ことを判定できる。
- **position** [確認]: 除去トークン分の position の飛びが保持される（`米大統領選でトランプ`→ 1, 4）。測定した範囲では offset 判定と結果が一致。
- **バッファ境界** [確認]: 本文は `text.split("\\s")` で空白分割し、約1000文字（`fess.suggest.max.analyzed.content.length`）ごとに別々に `_analyze` してトークンを連結する（`DefaultContentsParser.java:75`, `:267-276`, `:294-295`）。offset/position はバッファごとに0から始まるため、隣接判定はバッファを跨がないようにする必要がある。境界は常に空白位置なので、空白を含まない複合語がバッファで切断されることは無い。
- **読みトークンの件数一致** [確認]: `contents_reading_analyzer_ja` は `contents_analyzer_ja` に `reading_form` を足しただけでトークンを除去しないため、測定した全例で件数・position が一致した。読みは index `i` で対応付けられる（`DefaultContentsParser.java:173-176`, `:191`）。構成語の読みの連結（`シンガタ`+`コロナ`）はクエリ側の読み（`シンガタコロナ`）と一致する。不一致時（バッファ単位の解析失敗等）は `readingConverter.convert(word)` にフォールバックし、結合語にもそのまま適用できる。
- **品詞情報** [確認]: `DefaultContentsAnalyzer` は explain を要求しておらず（`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/settings/AnalyzerSettings.java:392-397`）、`parseDocument` で品詞は使えない。
- **案Aで解決しない語** [確認]: `大統領選`・`円安` は接尾辞が除去済みで、結合しても `大統領`・`円` にしかならない。`石破前首相` は `前` の除去で offset が途切れ `石破首相` にならない（`石破茂前首相` からは `石破茂` が得られる）。
- **過結合の例** [確認]: `日本経済新聞社長`→`日本経済新聞`+`社長`、`高市早苗首相`→3トークン、`新型コロナウイルスの`→`新型`+`コロナ`+`ウイルス` がいずれも offset 連続。
- **既存のアナライザー差分** [確認]: 作業ツリーの fess の `suggest_analyzer.json` には未コミットの `compound_pos_filter`（`pos_filter` から `名詞-接尾-一般`・`名詞-接尾-サ変接続`・`名詞-接尾-地域` を外したもの）と `contents_compound_analyzer_ja`・`contents_compound_reading_analyzer_ja` が定義されているが、実機索引には存在せず、Java コードからの参照も無い。

## 6. テスト実行可否

- `mvn -o test -Dtest='DefaultContentsParserTest,DefaultContentsParserEdgeCaseTest'`（`modules/fess-suggest`）は成功（12件・32件、約100秒）[確認]。
- これらは組み込みの OpenSearchRunner（`SuggestTestServer`）と fess-suggest 同梱の `suggest_analyzer.json` を使う。同梱定義のトークナイザーは `reloadable_kuromoji_tokenizer` で、fess 実行時の `fess_japanese_tokenizer` と異なる（`pos_filter` の stoptags は同一）[確認]。日本語の分割結果は fess 実行時と一致しない可能性がある [推測]。結合ロジックの単体テストは、トークン列を与えるスタブで行うのが確実。

## 7. 要判断事項

1. **`大統領選`・`円安` を対象にするか**: 案A では解決しない。対象にするなら `名詞-接尾-一般` を残すアナライザー変更（fess 側 json）または品詞取得が必要。
2. **`石破首相` の扱い**: 評価データに存在しない。確認クエリから外すか、`石破茂` 等に置き換える。
3. **実機確認の判定方法**: 評価時の検索で `新型コロナ`・`大統領選`・`円安` が検索ログに入り、kind=query の候補として既に返る。改善の判定は document 由来（`kinds` に `document` を含む）かどうかで行うか、検索ログ由来の候補を除いて比較する必要がある。
4. **文書処理上限（50%）**: 改善前後で同じ設定なら比較は公平だが、頻度・カバー率は過小になる。改善確認のために変えるかどうか。
