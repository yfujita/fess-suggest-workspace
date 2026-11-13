# 複合語・固有名詞をサジェスト候補にする設計

`docs/global/improvement_points/20261109/suggest_quality_evaluation.md` §4 #2「複合語・固有名詞が候補にならない」の改善設計。文書(クロール結果)由来の候補生成に、隣接する名詞の連結語を加える。

- 表記: **[確認]** コードまたは実測で裏取り済み / **[推測]** 未検証の推定 / **[要確認]** 実装前に確かめる事項。
- 根拠パスは `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` を省略して書く(`fess:` は `modules/fess/src/main/java/org/codelibs/fess/`、`fess-res:` は `modules/fess/src/main/resources/`)。

## 1. 背景と原因

評価では `新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種` が候補 0 件、`円安` は 4 文書に出現するのに 0 件、`新型` と `コロナ` は断片だけが候補になった。

### 原因 [確認]

1. **文書経路は「形態素 1 トークン = 1 候補」である。** `index/contents/DefaultContentsParser.java:154-211`(`parseDocument`)は、アナライザが返したトークンごとに `words = { word }` の `SuggestItem` を作る(`:185`)。連結・N-gram・shingle は無い。IPADIC が 1 語として持つ語(`日本経済新聞`、`東京大学`)だけが連結語のまま候補になる。
2. **品詞フィルタが接尾辞を落とす。** 文書経路のアナライザ `contents_analyzer` / `contents_analyzer_ja` は `pos_filter` を持つ(`fess-res:suggest_indices/suggest_analyzer.json:64-68`、定義は `:1291`)。`stoptags` は `名詞-接尾` 系(`選`、`安`、`症`、`県` など)と `名詞-数` を含む。語長フィルタは `max: 30` のみ(`:1374`)で、最小長や頻度の足切りは無い。
3. 検索ログ経路(`parseSearchWords`、`:79`)は語を分割せず保持するため、複合語は検索された時点で候補になる。評価で 0 件だったのは、その語がまだ検索ログに無かったため [推測]。検索ログに頼らず文書から候補にするのが本設計の目的。

### 例語の分割結果

Lucene Kuromoji 9.5.0 / IPADIC(NORMAL モード、ユーザー辞書なし)を、analysis-extension プラグイン同梱の `lucene-analysis-kuromoji-9.5.0.jar`(実環境と同一かは未確認)でオフライン再現した結果。**実環境の `contents_analyzer_ja` を `_analyze` で呼んだ結果ではない。** 評価書の観測(断片のみ候補になる)とはすべて一致した。

| 入力 | 分割(品詞) | 現状の候補 |
| --- | --- | --- |
| 新型コロナ | 新型(名詞-一般) / コロナ(名詞-一般) | `新型`、`コロナ` |
| 大統領選 | 大統領(名詞-一般) / 選(**名詞-接尾-一般**) | `大統領` のみ |
| 高市早苗 | 高市(人名-姓) / 早苗(人名-名) | `高市`、`早苗` |
| 石破首相 | 石破(人名-姓) / 首相(名詞-一般) | `石破`、`首相` |
| ワクチン接種 | ワクチン(名詞-一般) / 接種(名詞-サ変接続) | `ワクチン`、`接種` |
| 円安 | 円(名詞-一般) / 安(**名詞-接尾-一般**) | `円` のみ |

## 2. 方針

`parseDocument` で、`_analyze` の explain(段階別の結果)から得た品詞・読み・offset をもとに、**隣接する対象品詞トークンの最大連続列(2 トークン以上)を連結し、連結語を追加の候補にする。断片(現状の候補)は残す。**

- 断片を残す理由: `コロナ` のように連結語の末尾側にある語は、連結語の前方一致では引けない。断片の整理は #3 / #14 の課題で、本設計は現状を悪化させない。
- アナライザ定義(`suggest_analyzer.json`)を変更しない。アナライザ定義は既存環境では更新されない(improve_point.md の Y-09、`settings/AnalyzerSettings.java:137-166`)ため、jar の更新だけで既存環境に効く。

検討して採らなかった案: アナライザ内連結案(アナライザ内で `kuromoji_pos_concat` により連結する案)は、連結した断片が消える(残すには analyze をもう 1 本足す)こと、`suggest_analyzer.json` を 3 か所で変更するが既存環境に反映されないこと、上限を設定で変えられないことから不採用。(補助案)`stoptags` から `名詞-接尾-一般` を外す案は、`大統領`+`選` のように断片が増えるだけで連結語は出ず、`選`・`安`・`症` など 1 文字断片が増えて #3 / #7 を悪化させるため不採用。

## 3. 変更内容

### 3.1 fess-suggest

| 対象 | 変更 |
| --- | --- |
| `analysis/SuggestAnalyzer.java` | `default TokenizerStageResult analyzeTokenizerStage(String text, String field, String lang) { return null; }` を追加。tokenizer 段のトークンと char_filter 適用後の本文を返す。戻りは tokenizer 段の `AnalyzeToken` のリストと char_filter 適用後の本文を持つ値(新設の小さなクラス)。トークンは `getAttributes()` に `partOfSpeech`、`reading` を含む。`null` は「取得不可」の意味。default 実装により、既存の実装クラス(テストの代役など)は変更不要 |
| `settings/AnalyzerSettings.java` の `DefaultContentsAnalyzer`(`:369`) | `analyzeTokenizerStage` を実装。`analyze`(`:388`)と同じ文字数上限チェック・アナライザ名解決(`getContentsAnalyzerName`)を使い、explain 付きで `_analyze` を呼ぶ。detail の取り出し方は下記 |
| `index/contents/DefaultContentsParser.java` | 連結語の抽出と `SuggestItem` 生成を追加。設定値の読み込みはコンストラクタ(`:74-76`)に追加 |
| fess(`fess:helper/SuggestHelper.java` ほか)・`suggest_analyzer.json`・`FessConfig`・`fess_config.properties` | **変更なし** |

**explain の取り出し方 [確認]:** 依存する `fesen-httpclient 3.9.0` に同梱の `AnalyzeAction` では、`AnalyzeRequestBuilder` に `setExplain` が無く、`Response` に `detail()` も無い(`getTokens()` のみ公開)。explain 付きの応答では `getTokens()` は `null` になる。そのため次の方法を取る。

- リクエスト: `prepareAnalyze(...).setAnalyzer(...)` の戻り値に対し `builder.request().explain(true)`(コンパイル確認済み)。応答を絞るため `request().attributes(List.of("partOfSpeech", "reading"))` を併用する(`AnalyzeAction$Request` に `attributes(List<String>)` があることを `javap` で確認。実環境で効くかと縮小効果は 7 章 2 で測る)。
- 応答: `Response.toXContent` で JSON にし、`detail.tokenizer.tokens[]` を読む。各トークンは `token`、`start_offset`、`end_offset` に加え、属性 `partOfSpeech`、`reading` を持つ(クライアントのパーサを通して JSON に出力されることを、模擬の explain 応答で確認。実環境の応答は未確認、7 章)。
- char_filter 適用後の本文を `detail.charfilters[].filtered_text` から読む(連結語が本文に存在することの検証に使う、3.2)。キーは**単数形の `filtered_text`** で、値は文字列の配列 [確認: OpenSearch 3.9.0 の `AnalyzeAction.CharFilteredText` と fesen-httpclient 3.9.0 の `HttpAnalyzeAction$Fields.FILTERED_TEXT` の定数がともに `"filtered_text"`]。`mapping_char` は 1 つの char_filter なので、その `filtered_text` の先頭要素が対象。キーを誤ると本文が常に取れず、全チャンクが縮退して連結語が 0 件になる(気づきにくいため 4.5 の観測と 5.2 の統合テストで検知する)。
- `detail` や `tokenizer` が無い場合、`partOfSpeech` が一度も出ない場合、char_filter 適用後の本文が取れない場合は `null`(縮退、4.1)。

### 3.2 連結アルゴリズム(`parseDocument`)

既存の `analyzeTextInternal`(`:261`)は、本文を空白(`\s`)で分割して順に溜め、溜めた長さが `fess.suggest.max.analyzed.content.length`(既定 1000)文字を超えた時点でチャンクとして `_analyze` を呼ぶ。区切れるのは空白の位置だけなので、空白の無い日本語本文では 1 フィールド全体が 1 チャンクになりうる。チャンクが `maxContentLength`(既定 50000 文字、`settings/AnalyzerSettings.java:378`)を超えると `analyze` は空を返し、そのチャンクからは候補が作られない。連結語の抽出も**同じチャンク単位**で行う(offset はチャンク内の値で、チャンクは空白で区切られるため連結がチャンクをまたぐことはない)。

実装メモ: `analyzeTextInternal` は `private` で、`processBuffer` が `analyze` / `analyzeAndReading` の 2 通りだけを呼び分ける。explain にも同じ分割を使うには、分割処理を共通化するか、explain 用のメソッドを新設する。

前提: トークナイザは NORMAL モード(`fess_japanese_normal` は `mode: normal`、`fess-res:suggest_indices/suggest_analyzer.json:12`)。search モードの重なりトークンは連続の判定が成立しないため対象外。

```
for 各チャンク:
  result = analyzer.analyzeTokenizerStage(chunk, field, lang)   // null ならこのチャンクは連結なし
  tokens = result.tokens
  filteredText = result.charFilteredText                         // char_filter 適用後の本文。無ければこのチャンクは連結なし
  run = []
  for t in tokens:
    if not valid(t, prev): flush(run); run = []; prev = t; continue   // offset が不正なトークンは連結しない
    if t.品詞 ∈ 対象品詞 and (run が空 or t.startOffset == run.last.endOffset): run.add(t)
    else: flush(run); run = (t.品詞 ∈ 対象品詞) ? [t] : []
    prev = t
  flush(run)

valid(t, prev):                                                  // offset は元の本文の座標
  return 0 <= t.startOffset < t.endOffset and (prev == null or prev.endOffset <= t.startOffset)

flush(run):
  if run.size < 2 or run.size > maxTokens: return          // 部分列は出さない
  raw = 各 term をそのまま連結                                // 小文字化前。char_filter 適用後の本文の表層
  if not filteredText.contains(raw): return                 // 本文に無い語は作らない
  surface = toLowerCase(Locale.ROOT, raw)
  if surface.length > maxLength: return
  reading = 各トークンの (reading ?: term.toLowerCase(Locale.ROOT)) をカタカナのまま連結
  emit(surface, reading)
```

**連結語が本文に存在することの保証**

連結語は、品詞で選んだ「offset が隙間なく連続するトークン」の表層を並べたもので、語の挿入や並べ替えはしない。したがって、連結語は char_filter 適用後の本文の連続した部分文字列になる(現状の断片と同じ性質。`mapping_char` で全角英数が半角になるなど、原文そのままではなく正規化後の表層)。この性質が explain の応答の不備で崩れないよう、次の 2 つを検証し、満たさない連結語は作らない(縮退、4.1)。

1. **offset の妥当性**: 各トークンが `0 <= startOffset < endOffset` で、前のトークンと重ならない(`prev.endOffset <= startOffset`)。offset が欠けた応答(両方 0 など)や、重なりトークン(search モードの分割)で、無関係なトークンが連結されることを防ぐ。
2. **本文との照合**: 連結した表層(小文字化前)が、explain の応答に含まれる char_filter 適用後の本文(`detail.charfilters[].filtered_text`)の部分文字列であること。追加の `_analyze` は要らない。`contains` は本文のどこかに同じ文字列があることしか示さず、対象 offset の位置の一致までは保証しない。したがってこれは**必要条件の検証(明らかな不整合の除外)であり、十分条件ではない**。連続性の判定は offset の隣接で行う。
   - 座標系: トークンの offset は元の本文の座標、`filtered_text` は char_filter 適用後の本文で、文字数が変わりうる(半角カナの濁点付きなど)ため座標が異なる。**offset を `filtered_text` に直接適用して部分文字列を切り出す処理は書かない**(位置のずれで誤った語を作るため)。照合は `contains` に限る。

- **連結対象品詞**(完全一致、12 種): `名詞-一般`、`名詞-サ変接続`、`名詞-固有名詞-一般`、`名詞-固有名詞-人名-一般`、`名詞-固有名詞-人名-姓`、`名詞-固有名詞-人名-名`、`名詞-固有名詞-組織`、`名詞-固有名詞-地域-一般`、`名詞-固有名詞-地域-国`、`名詞-接尾-一般`、`名詞-接尾-サ変接続`、`名詞-接尾-地域`。
  - 対象外: 数(`名詞-数`)、助数詞・人名の接尾辞、形容動詞語幹、助詞・動詞などの非名詞。数や助数詞を含む語(`3000万円`、`令和5年度`)は連結されず、#6 を悪化させない。
- **連続の判定**は offset の隣接(`startOffset == 前の endOffset`)。空白・句読点・助詞で途切れる(`検索 エンジン` は連結されない)。
- **最大連続列のみ**: 連続列から部分列は作らない。たとえば実文書で `新型コロナウイルス` と現れると連続列は 3 トークンで、連結語は `新型コロナウイルス` だけになり、`新型コロナ` 単独は連結語にならない。サジェストは前方一致で引けるため、先頭側の語は最大連続列だけで足りる(`新型コロナ` の入力で `新型コロナウイルス` が返る)。
  - **意図的な取りこぼし(品質上の制約、4.4)**: 中間・末尾側の部分語(`新型コロナウイルス` に対する `コロナウイルス`)は前方一致で引けず、連結語にならない(断片 `コロナ` などは残る)。
- **上限**: トークン数 5 以下かつ表層 20 文字以下。超える連続列は連結語を作らず断片のみ。**超過した連続列は、その中の有用な部分複合語も含めて一切出ない**(4.4)。
- 連結語の例(オフライン再現): `新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安` の 6 語はいずれも 2 トークンの連続列として得られる。`神奈川県`(`県` = `名詞-接尾-地域`)も得られる。

### 3.3 `SuggestItem` の組み立て

連結語 1 つにつき `SuggestItem` を 1 件、既存の断片と同じ形で作る(`parseDocument` の `:185-203` と同じ引数)。

| 項目 | 内容 |
| --- | --- |
| `words` | `{ 連結語 }` の 1 要素。区切りを入れない(`text = "新型コロナ"`)。`{新型, コロナ}` にすると `text` が空白区切り(`SuggestConstants.TEXT_SEPARATOR`)になり、複数語項目と混ざる |
| `readings` | 連結したカタカナの読みを `contentsReadingConverter.convert(読み, field, lang)` に 1 回通し(既定は `KatakanaToAlphabetConverter`、`util/SuggestUtil.java:266`)、末尾に表層形を加える(`:188-195` と同じ)。読みが取れないトークンは小文字化した表層形で代用する(`ChatGPT` 等)。`reading` 属性が全トークンで無い場合は `readingConverter.convert(連結語, field, lang)` を使う(既存の縮退 `:173-176`、`:188-190` と同じ) |
| `docFreq` / `fields` / `tags` / `roles` / `languages` / `kind` | 断片と同じ(`docFreq = 1`、`Kind.DOCUMENT`) |
| ID | `SuggestUtil.createSuggestTextId(text)`(`text` の Base64)。同じ語の検索ログ由来項目と ID が一致し、書き込み時に 1 項目へ統合される(`SuggestItem.merge`、`:446`) |

連結語も既存と同じ後段を通る: bad word 判定(`index/operations/IndexingOperations.java:78`、`text` の部分一致)、`SuggestIndexWriter` での重複項目の統合。表層形は 20 文字以下なので `content_length_filter`(max 30)相当の制限も満たす。

### 3.4 設定(System property)

`fess.suggest.max.analyzed.content.length`(`DefaultContentsParser.java:75`)と同じ方式。suggest 作成プロセスには `jvm.suggest.options`(`fess-res:fess_config.properties:101`)に `-D...` を足して渡す。

| プロパティ(案) | 既定 | 内容 |
| --- | --- | --- |
| `fess.suggest.compound.enabled` | `true`(暫定) | `false` で連結語の生成と、追加の `_analyze`(explain)呼び出しを止める。**既定値は暫定**で、リリース時の既定を `true` にするかは 7 章「本番有効化ゲート」の測定結果で決める(評価なしに `true` を本番既定として確定しない) |
| `fess.suggest.compound.max.tokens` | `5` | 連結するトークン数の上限 |
| `fess.suggest.compound.max.length` | `20` | 連結語の表層の最大文字数。`content_length_filter` の 30 を超える値は 30 に丸める |

### 3.5 データ・インデックスへの影響

- インデックスのマッピング・設定の変更なし。**インデックス定義の再作成は不要**。
- 次回以降の suggest 更新(文書読み込み、`fess:helper/SuggestHelper.java:362` の `indexFromDocuments`)で、処理された文書について連結語の項目が追加される。既存項目はそのまま。
- **既存文書への反映は自動では全件に及ばない [確認]**: `indexFromDocuments` は `ESSourceReader` に文書取得の割合・件数・文書サイズの上限を設定する(`fess:helper/SuggestHelper.java:371-373`)。既定は `suggest.update.contents.limit.num.percentage=50%`、`suggest.update.contents.limit.num=10000`、`suggest.update.contents.limit.doc.size=50000`(`fess-res:fess_config.properties:1619-1623`)。そのため、次回更新で全既存文書が処理されるとは限らず、10,000 件を超える環境では連結語が一部の文書分しか入らない。全件に反映したい場合の手順は 4.2。
- 項目数が増える。増加率は実コーパス未測定(7 章 3 で測る)。書き込みは項目ごとに GET を 1 回行う(`index/writer/SuggestIndexWriter.java:55`)ため、書き込み負荷も項目数に比例して増える [確認]。
- 連結語項目は断片と同じ寿命。文書由来のみの項目は `purgeDocumentSuggest`(`fess:helper/SuggestHelper.java:421`)で期限削除される。機能を止めて即座に消したい場合は `deleteDocumentWords`(`:497`)で文書由来の語を全削除して再作成する。
- `_analyze` の回数: 文書 1 フィールド 1 チャンクにつき、既存 2 回(`analyze`、`analyzeAndReading`)に explain を 1 回足す。explain の応答には char_filter 適用後のテキスト、tokenizer 段、フィルタ 5 段(`contents_analyzer_ja` の構成)のトークン列が返るため、応答は現状より大きくなる(3.1 の `attributes` 指定で縮小を試みる)。3 回分を 1 回に統合する最適化は本設計に含めない。Y-10 は同種の課題だが検索時が対象で、文書経路(`parseDocument`)の `analyze` / `analyzeAndReading` / explain の統合は別途起票する(未起票)。

## 4. エッジケース・互換性・移行

### 4.1 縮退(連結せず従来動作)

次の場合は連結語を作らず、断片のみの現状の動作になる。例外は投げない。

- `analyzeTokenizerStage` が `null` を返す(default 実装のまま、explain 応答に `detail.tokenizer` や char_filter 適用後の本文が無い、`_analyze` が失敗した)。
- offset が不正なトークン(`0 <= start < end` を満たさない、前のトークンと重なる)は連結に使わない。連結した表層が char_filter 適用後の本文に含まれない連結語は作らない(3.2)。本文に存在を確認できない語は作らない方針。失敗時は既存の `processBuffer`(`:291-310`)と同様に警告ログを出して続行する。
- トークンに `partOfSpeech` が無い。他言語のアナライザ(Kuromoji 以外のトークナイザ)が該当する見込み [推測]。対象品詞が一致しないため連結語は 0 件になるだけで、有害ではない。
- `fess.suggest.compound.enabled=false`。

縮退の件数と原因は 4.5 のとおり観測できるようにする。

### 4.2 互換性・移行

- **Y-09 の影響を受けない [確認]**: `suggest_analyzer.json` を変更せず、既存のアナライザ(`contents_analyzer*`)をそのまま explain で呼ぶだけなので、`fess_suggest_analyzer` index の再作成は不要。
- 検索ログ由来の項目と ID が一致する場合は 1 項目に統合され、`docFreq` と `queryFreq` の両方を持つ(同じ語が両方から来た場合の既存の挙動と同じ)。
- 既存の公開 API は変更しない。`SuggestAnalyzer` の追加は default メソッドで、実装クラスの修正は不要。
- 既存項目の更新: 以降の suggest 更新で連結語の `docFreq` が積まれる。連結語を含まない文書だけになった項目は期限削除の対象になる。
- **反映・停止・ロールバック手順**(「インデックス定義の再作成は不要」と「既存文書への全件反映」は別):
  1. **反映(通常)**: jar を更新して通常の suggest 更新を待つ。上限(3.5)の範囲で処理された文書分だけ連結語が入る。
  2. **反映(全件)**: 全文書の連結語が必要な場合は、`deleteDocumentWords`(`fess:helper/SuggestHelper.java:497`)で文書由来の語を削除してから再作成するか、取得上限(`suggest.update.contents.limit.num.percentage` / `.num`)を一時的に引き上げて更新する。取得上限の引き上げは更新時間とメモリに直結するため、7 章の測定を先に行う。
  3. **停止**: `fess.suggest.compound.enabled=false` にして jar を戻さずに止められるが、**`false` に戻しても生成済みの連結語はすぐには消えない**(新規生成が止まるだけ。文書由来のみの項目は `purgeDocumentSuggest`(`fess:helper/SuggestHelper.java:421`)の期限削除で徐々に消える)。
  4. **ロールバック(即時除去)**: `enabled=false` にしたうえで `deleteDocumentWords` で文書由来の語を全削除し、再作成する。文書由来のみの項目は削除され、検索ログ由来・ユーザー登録の項目も持つ語は `docFreq` が 0 に戻るだけで残る(`index/operations/DeletionOperations.java:130-136`)。

### 4.3 ノイズ

- **ナビゲーション文字列**(`ホーム製品情報会社概要` のような単語の羅列)は 5 トークン・11 文字で、上限を満たし連結語になる。`新型コロナウイルス感染症`(5 トークン)も同じ条件で、上限では両者を区別できない [確認、オフライン再現]。`docFreq` は出現文書数ではなく、出現ごとの `docFreq = 1`(`DefaultContentsParser.java:202`)を `SuggestIndexWriter` / `SuggestItemMerger` が加算した値で、文書単位の重複排除は無い。全ページ共通のナビゲーション文字列は `docFreq` が大きくなり、連結語が上位に来うる [推測]。抑制策は 7 章 3 で量と順位を確認したうえで決める。
- **候補数の増加は品質改善の証拠にならない**。評価は候補総数ではなく、(a) 改善対象語(例語 6 語)の取得率、(b) 代表的な検索プレフィックスでの上位候補の内容とノイズ率、(c) 候補総数の増加、(d) 更新処理時間を、改善前後で比較する。許容基準は現行環境のベースライン測定後に決める(7 章「本番有効化ゲート」)。
- 連結語の `docFreq` は断片より小さくなりやすく、順位は断片の下になりうる [推測]。順位の調整は本設計の対象外(評価書 #12)。

### 4.4 品質上の制約(初版で意図的に受け入れる取りこぼし)

最大連続列のみを連結語にする(3.2)ため、次は初版では候補にならない。いずれも断片は従来どおり残る。

- **超過列**: 6 トークン以上、または表層 21 文字以上の連続列は、その部分列も含めて連結語が出ない。
- **中間・末尾の部分語**: 連続列 `新型コロナウイルス` に対する `コロナウイルス`(前方一致で引けない)。

部分列の生成(例: 最大連続列に加えて最大 3 トークンの部分列)は**比較検討用の案であり、確定した変更ではない**。導入するなら、候補数・ノイズの増加とセットで 7 章のベースラインと比較して判断する(5.1 に比較用のテストケースを置く)。

### 4.5 運用上の観測(縮退の可視化)

縮退(4.1)は例外を投げず従来動作に戻る設計のため、常時縮退して機能が実質無効になっても気づきにくい(`filtered_text` のキー誤りなど)。次をログまたは取得可能な件数として残す。

- 連結語を生成したチャンク数と、生成した連結語の総数。
- 縮退したチャンク数と**原因別の内訳**: `analyzeTokenizerStage` が `null`(explain 応答の欠落、`_analyze` 失敗)、`partOfSpeech` なし、char_filter 適用後の本文なし、offset 不正、本文との照合失敗、上限超過。
- 縮退の原因は警告ログに含める(既存の `processBuffer` の警告と同じ扱い)。ログの粒度・カウンタの保持方法(`DefaultContentsParser` のカウンタか、ログの集計か)は実装時に決める。
- 受け入れ確認(5.2)と本番有効化ゲート(7 章)では、縮退率が高い(連結語が 0 件に近い)場合を異常として扱う。

## 5. テスト方針

### 5.1 単体テスト(`DefaultContentsParserTest` 系)

`SuggestAnalyzer` の代役(`analyzeTokenizerStage` が品詞・読み・offset 付きの固定トークンと、char_filter 適用後の本文を返す)を使い、OpenSearch なしで連結ロジックを検証する。

| ケース | 期待 |
| --- | --- |
| `新型コロナ`(名詞-一般 + 名詞-一般) | 連結語 `新型コロナ` と断片 `新型`、`コロナ` の両方 |
| `大統領選`、`円安`(接尾-一般) | 連結語 `大統領選`、`円安` |
| `高市早苗`(人名-姓 + 人名-名)、`石破首相`、`ワクチン接種`(名詞-サ変接続) | 連結語が出る |
| `神奈川県`(名詞-接尾-地域) | 連結語 `神奈川県` |
| 途切れ: 空白(`検索 エンジン`)、助詞・句読点を挟む(`ワクチン接種、新型コロナ`) | 連結語は `ワクチン接種` と `新型コロナ` の別々 |
| 非対象: 数・助数詞を含む(`3000万円`、`令和5年度`)、動詞・助詞 | 連結語なし |
| 上限: 6 トークンの連続列、表層 21 文字以上の連続列 | 連結語なし(部分列も出さない)。断片は出る |
| 上限ちょうど: 5 トークン、20 文字 | 連結語が出る |
| 取りこぼしの明示(4.4): 3 トークンの連続列 `新型コロナウイルス` | 連結語は `新型コロナウイルス` のみ。`コロナウイルス`・`新型コロナ` は連結語にならない(部分列生成方式との比較の基準になる。部分列生成を入れる場合はこのケースの期待値と、件数・ノイズの増加を併せて見直す) |
| 超過列の取りこぼし: 6 トークンの連続列の途中に有用な 2〜3 トークンの語を含む | 連結語なし(断片のみ)。部分列を出さないことを固定する |
| 単独トークン(連続列が 1) | 連結語なし |
| offset の不正: `start`/`end` がともに 0、`end <= start`、前のトークンと重なる(search モード相当の分割) | その位置は連結に使わず、無関係なトークンが連結されない。断片は出る |
| 本文との照合: 連結した表層が char_filter 適用後の本文に含まれない、本文が取れない | 連結語なし。断片は従来どおり |
| 照合の限界(必要条件であること): 連結した表層が本文の別の位置にも現れ、対象 offset の位置では連続していない(例: 対象位置は間に空白がある) | offset の隣接判定で連結されない。照合(`contains`)だけでは連結の可否を決めず、offset を `filtered_text` に直接適用して切り出す処理が無いこと(座標系の混同が無いこと) |
| 縮退の観測(4.5): 縮退の各原因(`null`、`partOfSpeech` なし、本文なし、offset 不正、照合失敗、上限超過) | 原因ごとの件数が記録され、警告ログに原因が出る |
| 正規化: 全角英数(`ＡＩ活用`)、半角カナ(`ﾜｸﾁﾝ接種`)を含む本文 | 連結語は正規化後の表層になり、char_filter 適用後の本文の部分文字列(offset は元の本文の座標) |
| 縮退: `analyzeTokenizerStage` が `null`、`partOfSpeech` が無い、`enabled=false` | 連結語なし。断片は従来どおり |
| 読み | `新型コロナ` の `readings` に `シンガタコロナ` 由来のローマ字と表層形が入る。読みの無いトークン(`ChatGPT活用`)は表層形で代用 |
| 表層形 | 連結語は小文字化される(`AIモデル` → `aiモデル`)。ID が同じ語の `SuggestItem` と一致する |
| チャンク境界 | 空白を含む 1000 文字超の本文で、連結がチャンクをまたがない。空白なしの長文(1 チャンクになる)で、全体が 1 回の呼び出しで処理される |
| 設定値 | System property で上限・有効フラグを変えると反映される |

### 5.2 統合テスト(自動)・受け入れ確認(手動)

- **統合テスト(自動、必須)**: `SuggestTestServer`(`modules/fess-suggest/src/test/java/org/codelibs/fess/suggest/SuggestTestServer.java`)で実 OpenSearch を起動し、`DefaultContentsAnalyzer.analyzeTokenizerStage` が実際の explain 応答から `partOfSpeech` / `reading` / offset / char_filter 適用後の本文(`detail.charfilters[].filtered_text`)を取得できることを確認する(3.1 の取り出し方の検証を兼ねる)。**スタブの単体テストだけでは `filtered_text` のキー誤りのような応答解析の不備を検知できない**ため、実応答を使うこのテストを合格条件にする。具体的には、`新型コロナ` などの例語で、実応答から対象の連結語(`新型コロナ`、`大統領選` など)が**実際に生成される**ことを確認する(全件縮退して 0 件になっていないこと)。explain 応答形式(`detail.tokenizer.tokens[]`、`detail.charfilters[].filtered_text`、属性キー)の変化もこのテストで検知する。あわせて、複数の文書(全角英数・半角カナ・空白・句読点を含むもの)で `DefaultContentsParser.parseDocument` を実行し、**出力したすべての連結語が char_filter 適用後の本文の部分文字列であること**を検証する。`SuggestTestServer` は同梱の `ExtensionPlugin`(Kuromoji 系トークナイザ)を使うが、その構成で `partOfSpeech` / `reading` が取れるかは**未確認**。
- **受け入れ確認(手動、実環境)**: 評価時と同じデータで文書由来の suggest を再作成し、例語(`新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`)が、語そのもの、またはその語を前方に含む連結語として `/api/v2/suggest-words` で取得できる。語そのものの存在を確認する場合は、その語が連続列として単独で現れる文書を含むデータで行う。`新型`、`コロナ` などの断片も残る。
- 回帰: 既存の `DefaultContentsParserTest` / `DefaultContentsParserEdgeCaseTest` が通る。

## 6. 他の改善点との相互影響

- **#3(断片)・#14(人名断片)**: 断片を残すため現状は悪化しない(項目数は増える)。連結語 `高市早苗` が候補になれば、姓だけの断片(`高市`)を落とす #14 の対策を後から安全に入れられる。#3 / #14 の対策自体は本設計に含めない。
- **#6(数値)**: 数・助数詞を対象外にしたため悪化しない。
- **#7(汎用語・1 文字語)**: 連結語の追加で上位語の構成が変わりうる [推測]。`選`・`安` の 1 文字断片は引き続き `pos_filter` で落ちるため増えない。
- **#1(複数語入力)**: 本設計は 1 語(区切りなし)の連結語のみで、空白区切りの複数語項目は扱わない。

## 7. 実装前に確認する事項・リスク・関連課題

### 本番有効化ゲート

次を満たすまで、`fess.suggest.compound.enabled` の既定値を本番で `true` と確定しない(実装自体は進めてよい)。測定は現行環境でのベースライン(`enabled=false`)を先に取り、その値に対して許容閾値を決める。閾値の数値は本設計では置かない(ベースライン測定後に決める)。

1. **explain の実応答での動作確認(最優先)**: 実 OpenSearch で explain 応答から品詞・読み・offset・`filtered_text` を取得し、対象の連結語が実際に生成されること(5.2 の統合テスト)。
2. **性能**: explain の応答サイズ、1 チャンク当たりの処理時間、suggest 更新ジョブの総実行時間を、改善前後で測る。入力は代表コーパスに加え、空白が少なく 1 チャンクが数万文字(上限 50000)になる長文、空白なし／ありの長文、全角英数、半角カナを含むテキスト。成功件数と縮退件数(4.5 の原因別)も記録する。
3. **品質**: 4.3 の (a)〜(d)(例語 6 語の取得率、代表プレフィックスの上位候補とノイズ率、候補総数、更新処理時間)を改善前後で比較する。
4. **反映・停止手順の確認**: 4.2 の全件反映・停止・ロールバックが実環境で行えること。

### 実装前に確認する事項 [要確認]

1. **実環境の explain が `partOfSpeech` / `reading` を返すか。** 実環境の `fess_japanese_tokenizer`(analysis-extension)は、Lucene の Kuromoji と同じ属性を出す想定だが未確認。`contents_analyzer_ja` に `explain: true` で `新型コロナ` を渡し、tokenizer 段に `partOfSpeech: 名詞-一般` と `reading` が出ることを確かめる。`_vanilla` 構成(`fess-res:suggest_indices/_vanilla/suggest_analyzer.json`)は標準の `kuromoji_tokenizer` で、同様に確認する。あわせて次を確かめる。(a) tokenizer 段の offset が、`mapping_char`(142 件)で文字数が変わる入力(半角カナの濁点付きなど)でも元の本文の座標で返ること(オフラインの再現では簡易版の文字フィルタで確認したのみ)。(b) `detail.charfilters[].filtered_text`(単数形)が返ること。(c) 評価データ全体で、連結語の本文との照合(3.2)が通らないものが 0 件であること。
2. **explain の応答サイズと処理時間。** 応答は現状の数倍(段数分)になる見込み [推測]。空白が無く 1 チャンクが数万文字(上限 50000)になる本文(50,000 文字程度の長文)で、explain の応答サイズと所要時間を測り、`attributes` 指定あり・なしを比較する。あわせて suggest 更新ジョブ全体の増加時間を測る(測定項目は上記「本番有効化ゲート」 2)。許容できなければ、チャンク長を調整するか、`analyze` / `analyzeAndReading` / explain の統合を前倒しする。
3. **実コーパスでの項目数の増加率**と、ナビゲーション文字列由来の連結語の量・順位(4.3)。問題があれば後続の対処として、`fess.suggest.compound.max.tokens` を下げる、または連続列の文書内頻度で足切りする、を検討する。
4. **NEologd 辞書の有無。** `fess-suggest` の同梱 `suggest_analyzer.json` は `kuromoji_neologd_normal` を使う(`modules/fess-suggest/src/main/resources/suggest_indices/suggest_analyzer.json:10`)が、fess 本体が使うのは `fess_japanese_normal`(`fess-res:` 同ファイル `:10`)。実環境で NEologd が効く場合は `新型コロナウイルス` など 1 語になる語が増え、連結の対象は変わる。上限の既定値(5 トークン / 20 文字)の妥当性もあわせて確認する。
5. **他言語アナライザの扱い。** `pos_filter` を持たない言語別アナライザ(`contents_analyzer_<lang>`)の tokenizer 段に `partOfSpeech` が出ないことの確認。出ない場合は 4.1 の縮退で連結語なしになる。
6. **`index.analyze.max_token_count` との関係。** explain でも既存のトークン数超過エラー(`index/operations/ContentIndexingOperations.java:265-270` で警告して読み飛ばす)が起きうるかを確認する。

### リスク

- explain の応答形式は Lucene / OpenSearch 側で実験的な位置づけ(推測)。依存ライブラリ更新時は `detail.tokenizer.tokens[]` と属性キー(`partOfSpeech`、`reading`)の変化を、5.2 の統合テストで検知する(スタブを使う単体テストでは検知できない。`filtered_text` のキー誤りも同様)。
- 本文では `fesen-httpclient` のクラス構成(`detail()` 非公開)に依存した取り出し方をしている。依存更新でアクセサが公開されれば簡素にできる。

### 関連課題(本設計に含めない)

出典: `docs/global/improvement_points/20261109/improve_point.md`

- **Y-08**(`:382`): suggest 側 Kuromoji トークナイザにユーザー辞書が効かない。辞書登録した語だけは 1 語として候補になる補完策だが、未登録の語は救えない。本設計とは独立に進められる。
- **Y-09**(`:390`): アナライザ定義を運用中に変更する手段が無い。本設計はこの制約を避けるため JSON を変更しない。
- **Y-10**(`:397`): 検索時の `normalize` / `readingConverter` による `_analyze` の重複呼び出しの課題。文書経路(`parseDocument`)の `_analyze` は扱っていない。文書経路の統合は別途起票する(未起票)。
