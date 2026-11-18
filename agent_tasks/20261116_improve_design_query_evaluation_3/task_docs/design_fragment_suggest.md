# 断片(意味のない語)を候補にしない設計

`docs/global/improvement_points/20261109/suggest_quality_evaluation.md` §4 #3「断片が候補になる」の改善設計。文書(クロール結果)由来の候補から、活用の途中形・促音長音のみ・記号のみ・1 文字の英数かなを除く。

- 表記: **[確認]** コードまたは実測で裏取り済み / **[推測]** 未検証の推定 / **[要確認]** 実装前に確かめる事項。
- 根拠パスは `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` を省略して書く(`fess-suggest:`)。`fess:` は `modules/fess/src/main/java/org/codelibs/fess/`、`fess-res:` は `modules/fess/src/main/resources/`。
- 数値は、ローカルの 100 文書(はてなブックマーク一覧ページ、ja)から作った suggest 索引 18,144 件(断片 11,825、連結語 6,319)での見積もり。50% のランダム読み取りの 1 回分で、再生成ごとに変動する。単一コーパスの値であり、他のデータには当てはまらない。実測環境は OpenSearch 3.9.0、アナライザは `fess_japanese_normal`(analysis-extension)。

## 1. 背景と原因

### 観測と原因 [確認]

文書経路(`fess-suggest:index/contents/DefaultContentsParser.java:346-402` の `parseDocument`)は「形態素 1 トークン = 1 候補」で、保存前のフィルタは `contents_analyzer_ja` の `pos_filter`(品詞)、`content_length_filter`(最大 30 文字)、既定のブラックリスト(`* ? " '` を含む語)だけである。最小長・文字種・活用形のフィルタは無い(コード側の `SuggestItem`、`IndexingOperations` にも長さ・文字種の検査は無い)。

| 観測した断片 | 生まれる処理(実測) | 落ちない理由 |
| --- | --- | --- |
| `なかっ` `よかっ` `大き` `難し` | Kuromoji が「形容詞-自立」と判定(`なかっ`/`よかっ` は連用タ接続、`大き`/`難し` はガル接続) | `pos_filter` の `stoptags` に `形容詞` はあるが `形容詞-自立` が無い(`fess-res:suggest_indices/suggest_analyzer.json` ほか 2 定義、計 3 定義で同一)。動詞は `動詞-自立` があり全部落ちる |
| `ッ` `ッッ` `ー` `ーー` | 「買いまくりッ!!!」「すげー」などが名詞-一般になる | 品詞は名詞で通る。文字種・最小長の検査が無い |
| `.` `/` `:` `-` など記号のみ | ASCII 記号は辞書上「名詞-サ変接続」。URL が `p . hatena . ne . jp` のように分割される | 名詞-サ変接続は実名詞(反響など)があり品詞では落とせない |
| `ne` `ku` | 本文中の英字トークンそのもの(`hatena.ne.jp` の `ne` など。読みの変換ではない) | 名詞-一般/固有名詞として通る。最小長の検査が無い |
| 連結語の `ー…`(13 件) | 連結語の経路で `ー` が連結対象品詞(名詞-一般)になり、`trimSymbolTokens`(`:664`)も `Character.isLetterOrDigit('ー')` が true のため外さない | 断片を引き継ぐ |
| 検索ログ経路 | `isExcludeSearchword`(`:860`)は「アナライザでトークンが 1 つでも残るか」だけを見る | 現状は実データで断片 0 件だが、`ッ` `ー` などが検索されれば候補になる |

デモ環境の `ーッッ` などは同じ機構で出る見込み [推測、デモ未確認]。

### 基準値(ローカル 100 文書コーパス)

断片 11,825 件を次の規則で機械的に分類した値(上から順に最初に当てはまる区分)。

| 区分 | 規則 | 件数 | 例(docFreq) | 本設計の扱い |
| --- | --- | ---: | --- | --- |
| C1 促音・長音のみ | 全文字が {ッ っ ー ｰ ｯ} | 4 | `ー`(299)、`ーー`(11)、`ッ`(4) | 除外 |
| C2 記号のみ | 英字・数字(`Character.isLetterOrDigit`)が 1 文字も無い | 194 | `/`(4,040)、`.`(4,015) | 除外 |
| C3 形容詞の途中形 | 全出現が形容詞-自立で、活用形にガル接続/連用タ接続を含む | 72 | `おもしろ`(370)、`なかっ`(35) | 除外(活用形) |
| C4 形容詞のその他の活用形 | 全出現が形容詞-自立で、活用形に基本形以外を含む(C3 以外) | 104 | `なく`(89)、`長く`、`なけれ` | 除外(活用形) |
| C5 英数字のみ 2 文字以下 | ASCII の英数字だけで 1〜2 文字 | 199 | `ai`(737。正当)、`jp`(724)、`ne`(12) | 1 文字(25 件)だけ既定で除外。2 文字は設定 |
| C6 1 文字 | 上記以外の 1 文字 | 821 | `月`(932)、`人`、`ろ`、`ガ` | かな 1 文字(44 件)だけ既定で除外。単漢字は設定 |
| C7 その他 | 上記以外 | 10,431 | 完成語がほとんど。形容詞の基本形 132(`ない`、`いい`) | 残す |

### 追加の原因(本設計では直さない)

- N1: トークナイザの誤分割。「(おもしろ)」のように括弧に接する位置で `おもし`+`ろ`(ともに名詞-一般)に割れる。品詞では落とせない。
- N2: 英字・URL・識別子の断片(`jp`、`co`、`https`)。#8 と同根。
- N3: 取り込み元の文章に欠けた語がある。`ハンバーガ` は取り込み元が「ハンバーガとピザ」と書いている(10 文書。`ハンバーガー` を含む文書は 0 件)。#9 の領域。
- N4: アナライザ定義は `fess_suggest_analyzer` 索引の作成時にだけ書き込まれ、既存環境には反映されない(`fess-suggest:settings/AnalyzerSettings.java:155-190` の `init`。`updateAnalyzer`〔`:278`〕の呼び出し元はコード中に無い)。このため、定義(`suggest_analyzer.json`)の変更は方式として採らない。

stemmer による末尾の `ー` 欠落は存在しない [確認: suggest 用 ja アナライザに stemmer は無い]。

## 2. 方針

fess-suggest の Java 側のみで次の 4 点を行う。`suggest_analyzer.json` は変更しない。

1. **断片フィルタ(文書経路)**: `parseDocument` で、促音長音のみ(C1)・記号のみ(C2)・英数 1 文字・かな 1 文字の語を候補にしない。英数 2 文字以下・単漢字は設定で有効にでき、既定は無効。
2. **活用形の除外**: 品詞が「形容詞-自立」で活用形(`inflectionForm`)が「基本形」以外のトークンを候補にしない。判定には、連結語用に取得している tokenizer 段の結果を共用する。基本形(`ない`、`いい`、`すごい`)は残す。
3. **連結語の端トリム**: 連結語の両端にある促音長音のみのトークンを、既存の記号トークンのトリムと同様に外す。中間は残す(`ぴー先生`)。
4. **検索ログ経路**: `isExcludeSearchword` に C1/C2(促音長音のみ・記号のみ)の除外を足す。最小長・文字数の規則は入れない。

理由: jar の更新と次回の suggest 作成だけで既存環境に効く(4.1)。有用語の巻き添えは少ない(主観の判断)。ただし 1 文字の英数 25 語(docFreq 計 1,303。`x` 319、`m` 119、`t` 94、`e` 79、`c` 66)は既定で消える(7 章)。検索ログ経路では利用者が検索した事実(`ai`、`月`、`安い`)を壊さない。

### 検討した他案(採らない)

| 案 | 内容 | 採らない理由 |
| --- | --- | --- |
| A | `stoptags` に `形容詞-自立` を追加 | 基本形 132 語(`ない` 375、`いい` 189、`すごい` 137 など)も失う。検索ログ経路でも `安い` などの検索が候補にならない(`isExcludeSearchword` が 1 トークンも残らない語を除外するため)。アナライザ索引の再作成が必要 |
| B | `fess_japanese_baseform` で基本形に寄せる | 誤った基本形(`うい` 51、`こい` 60)が出る。`reading_form` は表層の読みを返すため基本形に別表層の読みが付く(`なかっ`→`ナカッ`)。`ない` の頻度が上がり #7 を悪化させる。アナライザ索引の再作成が必要 |
| J' | アナライザ側の `pattern_replace` + `length` | `content_length_filter` は 96 アナライザ(47 言語 + 言語なしの 48 定義 × contents/contents_reading)が共有し、言語非依存で危険。contents だけ変えて reading を変え忘れるとトークン数が不一致になり、読みが静かに変換器へ縮退する(30 文書 300 チャンクで 267〜299 チャンク)。検索ログ経路で `月`、`ai` も除外される。アナライザ索引の再作成が必要 |
| D | 取得時(`SuggestResponseCreator`)の除外 | 索引に断片が残り、除外後に件数を満たせない。手動登録・elevate word の分岐が要る。連結語の `ー…` は直らない。再作成を待てない場合の暫定策に限る |
| 頻度の足切り | docFreq が小さい候補を落とす | 選択的でない。docFreq<10 で全体の 83% が消え、連結語の 47%・C7 の 30% も巻き込む。`おもし`(62)は閾値 10 でも残る |

ブラックリストも使えない(部分一致で、`ー` や `/` を登録すると `ラーメン` や URL 系の語まで消える。`fess-suggest:entity/SuggestItem.java:455`)。

### 見積もり(ローカル 100 文書コーパス)

| 設定 | 除去される断片(11,825 件中) | docFreq 計 | 1 文字入力で返る断片の減少(返却 1,067 語中) |
| --- | --- | ---: | --- |
| 現状 | 0 | 0 | 0(現状は C1〜C6 が 125 語、11.7%) |
| 既定(活用形 + C1/C2 + 英数 1 + かな 1) | 443(3.7%) | 20,897 | 34(3.2%) |
| 既定 + 英数 2 文字以下 | 617(5.2%) | 23,814 | 68(6.4%) |
| 既定 + 単漢字 | 1,220(10.3%) | 30,274 | 91(8.5%) |
| 既定 + 両方 | 1,394(11.8%) | 33,191 | 125(11.7%。C1〜C6 の全件) |

注: 既定の 443 = C1 4 + C2 194 + 活用形 176(C3 72 + C4 104)+ 英数 1 文字 25 + かな 1 文字 44(C6 の分)。C3 のうちかな 1 文字の 3 語は活用形の 176 に含まれる。1 文字入力で返る断片には、入力した文字自身が返る分が含まれ、過大である。活用形の除外は出現ごとの判定なので、名詞用法を持つ語(`うま`、`多`、`強` など約 12 語)は部分的に残る。

## 3. 変更内容

### 3.1 対象

| 対象 | 変更 |
| --- | --- |
| `fess-suggest:index/contents/DefaultContentsParser.java` | 断片フィルタ(3.3)、活用形の除外(3.4)、連結語の端トリム(3.5)、検索ログ経路の除外(3.6)、設定の読み込み(3.2)、チャンク単位の tokenizer 段取得の共通化(3.4) |
| `fess-suggest:settings/AnalyzerSettings.java` | 外側クラスの定数群(`PART_OF_SPEECH_ATTRIBUTE` と同じ場所、`:115-117`)に `INFLECTION_FORM_ATTRIBUTE = "inflectionForm"` を追加。`DefaultContentsAnalyzer.analyzeTokenizerStage` の `attributes` 指定(`:475`)と `toAnalyzeToken` の属性コピー(`:568`)に足す |
| `fess-suggest:analysis/TokenizerStageResult.java`、`SuggestAnalyzer.java` | 構造の変更なし。Javadoc の「トークンが持つ属性」に `inflectionForm` を足す |
| `suggest_analyzer.json`(3 か所)、fess 本体、`FessConfig`、`fess_config.properties` | 変更なし |

### 3.2 設定(System property)

`fess.suggest.compound.enabled` と同じ方式(`DefaultContentsParser` のコンストラクタで 1 回読む。`SuggestIndexer.java:192` で生成される)。suggest 作成プロセスには `jvm.suggest.options`(`fess-res:fess_config.properties:101`)に `-D...` を足して渡す。真偽値は `Boolean.parseBoolean` で、`true`(大文字小文字を問わない)以外はすべて `false` として扱う。

| プロパティ(案) | 既定 | 内容 |
| --- | --- | --- |
| `fess.suggest.fragment.filter.enabled` | `true` | 文書経路の断片フィルタ(C1/C2、英数 1 文字、かな 1 文字)、検索ログ経路の C1/C2 除外、連結語の促音長音の端トリムをまとめて有効にする。`false` で 3 つとも従来の動作に戻る |
| `fess.suggest.fragment.inflection.enabled` | `true`(暫定) | 形容詞-自立の活用形の除外。連結語の `compound.enabled` と同様に既定値は暫定で、本番での既定は 7 章の評価の結果で確定する |
| `fess.suggest.fragment.latin.short.enabled` | `false` | 英数字のみ 2 文字以下も除外する(`jp`、`ne`、`ku`。`ai`、`pc`、`tv`、`cm` なども消える)。`filter.enabled=true` のときだけ効く |
| `fess.suggest.fragment.single.han.enabled` | `false` | 単漢字も除外する(`月`、`人`、`米`)。`filter.enabled=true` のときだけ効く |

1 文字の英数(`x` など)だけを個別に残す・消す設定を別に設けるかは、7 章で検討する。

### 3.3 断片フィルタ(文書経路)

`parseDocument` のトークンループ(`:371`)で、`isBlank(word)` の直後(`:373`)に判定を置き、該当すれば `continue` する。`readingTokens` はトークンと同じ index で対応する(`:376`)ため、スキップしても他の語の読みはずれない。

```
isNoiseFragment(word, lang):                       // filter.enabled のときだけ呼ぶ
  cps = word のコードポイント列
  if cps がすべて {ッ っ ー ｰ ｯ}: return true         // C1
  if cps に Character.isLetterOrDigit が 1 つも無い: return true   // C2
  if not (lang が null/空/"ja"): return false         // 以下は日本語の解析経路だけ
  if cps.length == 1:
     if ASCII の英数字: return true                    // 英数 1 文字
     if script が HIRAGANA または KATAKANA: return true // かな 1 文字
     if single.han.enabled and script == HAN: return true
  if latin.short.enabled and cps.length == 2 and 両方 ASCII の英数字: return true
  return false
```

- 文字種の判定は既存の `isSymbolToken`(`:677`)と同じ `Character.isLetterOrDigit`(コードポイント単位)。長音(U+30FC)は Letter なので C1 は別規則にしてある [確認: `ー` `ッ` `ｰ` は isLetterOrDigit が true]。
- `〇`、ローマ数字、`①` は `isLetterOrDigit` が false のため、単独のトークンなら C2 として除外される [確認]。実害は小さいとみなして既存の記号判定に揃える。
- 全角英数は `mapping_char` で半角に正規化済みのため、ASCII のみを対象にする。
- **lang による適用範囲**: 最小長の規則(英数・かな・単漢字)は、lang が null/空/`ja` のときだけ適用し、サポート外の lang を含むそれ以外には適用しない(安全側)。lang なしの `contents_analyzer` は Kuromoji を使うため日本語として扱う [確認: `fess-res:suggest_indices/suggest_analyzer.json:37-42`]。サポート外の lang も `contents_analyzer` に落ちる(`getAnalyzerName`、`fess-suggest:settings/AnalyzerSettings.java:206-222`)ため、実際には Kuromoji で解析されうるが、その lang で 1 文字が語かどうかは分からないので適用しない。C1/C2 は言語を問わない。

### 3.4 活用形の除外と tokenizer 段の共用

**取得**: tokenizer 段(`analyzeTokenizerStage`)の `_analyze` は explain 付きで、連結語用に 1 チャンクにつき 1 回呼んでいる。`attributes` に `inflectionForm` を足すだけで、同じ応答から活用形が取れる [確認: ローカルの `contents_analyzer_ja` で `なかっ`(連用タ接続)、`大き`・`難し`(ガル接続)、`大きい`(基本形)を確認。explain の最終段(`limit_token_count_filter`)のトークンの offset は tokenizer 段と一致し、`pos_filter` を通ったトークンは tokenizer 段のトークンの部分集合]。`baseForm` などは不要。通常の `analyze` の offset が同じかは 7 章。

**判定**: 最終段に残った語を、チャンク内の (startOffset, endOffset) で tokenizer 段のトークンに対応付け、次を満たせば除外する。

```
isInflectedAdjective(stageToken):
  pos  = stageToken.attributes["partOfSpeech"]
  form = stageToken.attributes["inflectionForm"]
  return pos == "形容詞-自立" and form は空でない文字列 and form != "基本形"

// チャンクごとに作る。キーは (start, end)、値は tokenizer 段のトークンの term
inflected[c] = { (t.start, t.end) -> t.term  for t in stage[c].tokens if isInflectedAdjective(t) }

for 最終段の各トークン i (チャンク c = chunkOf[i]):
  term = inflected[c][(tokens[i].start, tokens[i].end)]
  if term != null and term.toLowerCase(ROOT) == tokens[i].term: 除外    // 小文字化後に一致しなければ除外しない
```

- 活用形が取れない(属性なし)場合は除外しない。「基本形」との完全一致で判定し、文語基本形(`なし`)や体言接続も除外側に入る。
- **チャンク対応**: tokenizer 段と最終段の offset は、いずれもチャンク(`chunk.trim()`)内の座標で、チャンクごとに 0 から始まる。現行の `analyzeText` はチャンクの結果を 1 本のリストに連結するため、次の変更が要る。(a) 分割済みチャンクごとに tokenizer 段を 1 回取得する処理を、連結語の処理から切り出して共通化する。(b) 最終段のトークンがどのチャンク由来かを記録する(例: 各チャンクを連結する直前のリスト長を保持する)。`parseDocument` はこの記録つきの内部メソッドを使い、protected の `analyzeText` / `analyzeTextByReading` のシグネチャと動作は変えない(既存テストが直接呼ぶ)。`analyzeText` を継承して差し替えている外部コードがある場合、`parseDocument` はそれを経由しなくなる [要確認: 外部での継承の有無]。
- 対応付けは NORMAL モードの重なりのないトークンを前提とする(連結語と同じ前提。`fess-res:suggest_indices/suggest_analyzer.json:12`)。
- **取得結果の区別**: 共通化した取得処理は、結果を「トークンあり」「取得不可(`null`)」「例外」の 3 通りに区別して返す。空のチャンク(`chunk.trim()` が空)では呼ばない。
  - 連結語側は従来どおり、`null` を `STAGE_UNAVAILABLE`、例外を `FAILURE` として別々に数え、警告も別枠で制限する(現行の動作を変えない)。
  - 活用形側は、`null` も例外も、トークンが空(品詞なし)の場合も、そのチャンクでは除外しない(従来どおり候補にする)。例外で `parseDocument` を失敗させない。
  - 連結語の警告(`warnIfDegraded`、`logNoPartOfSpeech`)は `compound.enabled=true` のときだけ出す。連結語が無効で活用形だけ有効なときは、連結語名義の警告を出さない。活用形側の取得不可はデバッグログと件数(3.7)にとどめる。

**連結語が無効のときの扱い**: tokenizer 段の取得は `compound.enabled` または `inflection.enabled` が `true` のときに行い、両方 `false` のときだけ explain を呼ばない。活用形の除外は連結語とは独立した改善で、連結語の停止スイッチで黙って無効になると断片が戻ることに気づきにくいためである。

- 連結語が有効なら、呼び出し回数は現状から増えない(1 チャンク 1 回を共用)。
- 連結語が無効で活用形が有効なら、1 チャンクにつき explain が 1 回残る(`analyze` と `analyzeAndReading` の 2 回に 1 回が加わる)。負荷が許容できない環境は `inflection.enabled=false` にする。負荷は未測定(7 章)。

### 3.5 連結語の端トリム

`trimSymbolTokens`(`:664`)の判定を「記号のみ **または** 促音長音のみ」に広げる。`isSymbolToken` のほかに、トークンの表層がすべて {ッ っ ー ｰ ｯ} であれば端から外す(`filter.enabled` のときだけ)。

- 両端から順に外し、外した結果が 2 トークン未満なら連結語を作らない。上限(`max.tokens`、`max.length`)と本文との照合(`contains`。別位置の同一文字列を見分けられない限界は従来と同じ)は、外した後の語に適用される(既存と同じ順序)。
- 中間は残す: `ぴ`+`ー`+`先生` は `ぴー先生` のまま。「トークンごとに run を切る」方式は `ぴー先生` まで失うため採らない。
- 効果(ローカル 100 文書コーパス): 促音長音のみのトークンを含む連結語 16 件(先頭 13、末尾 3)のうち 15 件が消えるか短くなる(`ー警視庁編ー`→`警視庁編`、`ーめん才遊記`→`めん才遊記`、`ゆー`→なし)。

### 3.6 検索ログ経路

`isExcludeSearchword`(`:860`)の先頭で、`filter.enabled` のとき、検索語がすべて {ッ っ ー ｰ ｯ}(C1)または `isLetterOrDigit` を 1 つも含まない(C2)なら `true`(除外)を返す。アナライザを呼ぶ前に判定するため、`_analyze` の呼び出しも省ける。

- `null` は C1/C2 の判定をせず従来の処理に渡す(除外される)。空文字は「すべて {…}」が空集合で真になって除外される(従来も空文字はトークンが残らず除外されるため結果は同じ)。
- 言語を問わず適用し、最小長・文字数の規則は入れない(`ai`、`月`、`x` の検索履歴は残す)。
- `parseSearchWords`(`:271`)は除外された語を飛ばして残りで 1 件の項目を作り、すべて除外されれば `null` を返す(既存の動作)。
- 形容詞の活用形(`大きく` など)の除外は検索ログ経路に入れない。検索された事実を尊重する。
- Fess は検索ログを `SuggestHelper.indexFromSearchLog` → `indexSearchWord` → `SuggestIndexer.indexFromSearchWord` → `parseSearchWords` で処理する [確認: `fess:helper/SuggestHelper.java:273,353`]。`parseQueryLog` 経路は Fess から使われておらず、対象外。

### 3.7 データ・インデックスへの影響と観測

- インデックスのマッピング・設定の変更なし。候補の項目数が減るだけで、読み(`readings`)の形式は変わらない。
- 除外した断片の件数を理由別(C1/C2、英数、かな、単漢字、活用形)にカウンタとデバッグログで残し、活用形の判定を行えなかったチャンク数(取得不可・例外・品詞なし)も数える。カウンタの保持方法は連結語の `CompoundDegradation` に倣い、実装時に決める。

### 3.8 影響を受ける既存の記述・テスト

tokenizer 段の取得条件が変わる(3.4)ため、次を実装時に合わせて更新する。

- `DefaultContentsParser` の Javadoc: `compound.enabled=false` が「追加の分析リクエストを止める」という説明を、「活用形の除外も無効のとき」に直す。
- 連結語の設計書(`agent_tasks/20261113_implement_compound_word_suggest/task_docs/design_compound_word_suggest.md`): 3.4 と 4.2 の停止手順(`false` で explain を止める)、7 章「本番有効化ゲート」(ベースライン測定 `enabled=false` に `inflection.enabled=false` を併記する)、2 章 L33 の「断片は残す」(促音長音・記号・1 文字・活用形の断片は残らなくなる)。
- 既存テスト `DefaultContentsParserCompoundWordTest`:
  - `test_degradation_disabled` は `compound.enabled=false` で tokenizer 段の呼び出しが 0 回であることを検証している。`inflection.enabled=false` を併記して維持する。
  - `test_chunk_blankTextIsNotAnalyzed`(空文字で tokenizer 段を呼ばない)は、活用形が有効でも成り立つようにする。
  - `STAGE_UNAVAILABLE` と `FAILURE` の区別・警告の別枠制限を検証するテスト(`test_degradation_failureWarningHasItsOwnTimeLimit` など)は、そのまま通るようにする。

## 4. エッジケース・互換性・移行

### 4.1 既存環境への反映と互換性

- jar の更新と、次回の suggest 作成だけで反映される。Fess の `SuggestCreator` は実行のたびに `createNextIndex()` で新しい空の suggest 索引を作り(`fess:exec/SuggestCreator.java:252`)、文書と検索ログから全項目を作り直して `switchIndex()`(`:298`)で切り替え、旧索引を `removeDisableIndices()`(`:301`)で消す [確認]。このため、既存索引に残った断片を消す作業は不要。
- アナライザ索引(`fess_suggest_analyzer`)の再作成は不要 [確認: アナライザ定義を変更しない。tokenizer 段の `attributes` はリクエスト側の指定]。
- 設定は `DefaultContentsParser` のコンストラクタで読むため、変更は次回の suggest 作成プロセスから有効になる。
- 停止・ロールバック: `fragment.filter.enabled=false` と `fragment.inflection.enabled=false` で従来の動作に戻る。次の suggest 作成で反映される。
- `DefaultContentsParser` は公開クラスで、`SuggestIndexer.setContentsParser`(`fess-suggest:index/SuggestIndexer.java:530`)で差し替えられる。差し替えない Fess 以外の利用者にも、既定で候補が減る(上のプロパティで戻せる)。公開メソッドのシグネチャは変えない。

### 4.2 エッジケース(3.3〜3.6 に書いたもの以外)

| ケース | 扱い |
| --- | --- |
| tokenizer 段が使えない(取得不可、50000 文字超のチャンク、品詞なし) | 活用形を除外せず従来どおり。C1/C2 など tokenizer 段に依存しない規則は効く |
| `en`、`zh-cn` | C1/C2 のみ。`standard` tokenizer で品詞が無く、活用形の除外も働かない [確認: `contents_analyzer_en` / `_zh-cn` の定義]。`ko` など他の言語の tokenizer は [推測] |
| 属性 `inflectionForm` が取れない構成(`_vanilla`、`SuggestTestServer`) | 活用形の除外が働かず現状と同じになる。誤って除外はしない [要確認、7 章] |
| 形容詞-自立の名詞用法(`うま`、`多`、`強`) | 出現ごとに判定するため、名詞として現れた分は残る |
| 読み(`readingTokens`)との対応 | 除外は `continue` だけでリストを組み替えない(3.3)。`analyze` と `analyzeAndReading` のトークン数が一致しない場合の縮退(`:366`)も変わらない |
| 並列処理 | `DefaultContentsParser` は並列ストリームから共有される(`ContentIndexingOperations`)。追加するフィールドは final の設定値とアトミックなカウンタに限る |

## 5. テスト方針

### 5.1 単体テスト(`DefaultContentsParserTest` 系。OpenSearch なし)

`SuggestAnalyzer` の代役(`DefaultContentsParserCompoundWordTest` の `StubAnalyzer` と同様に、tokenizer 段と最終段のトークンを固定で返す)を使う。既存テストへの影響は 3.8。

| 対象 | ケース | 期待 |
| --- | --- | --- |
| C1 | `ッ`、`ッッ`、`ー`、`ーー`、`ーッッ`、`っ`、`ｰ` | 候補にならない |
| C1 の境界 | `ーメン`、`ラー`(letter を含む) | 候補に残る |
| C2 | `.`、`/`、`://`、`-`、`(@`、`!!!`、絵文字 | 候補にならない |
| 英数 1 文字 | `x`、`7`(lang `ja`/null) | 候補にならない |
| 英数 1 文字 × lang | `x`(lang `en`)、`x`(サポート外の lang。例 `xx`、`ja_JP`) | 候補に残る |
| 英数 2 文字 | `ne`、`ai` | 既定で残る。`latin.short.enabled=true` で消える(`ai` も消える) |
| かな 1 文字 | `ろ`、`ガ`、`ん` | 候補にならない |
| 単漢字 | `月`、`米` | 既定で残る。`single.han.enabled=true` で消える |
| 境界 | 2 文字のかな(`あと`)、2 文字の漢字(`日本`)、3 文字の英字(`com`) | 残る |
| 活用形 | tokenizer 段が `形容詞-自立` + `連用タ接続`/`ガル接続` の `なかっ`、`大き`、`難し` | 候補にならない |
| 基本形 | `大きい`、`ない`、`いい`(基本形) | 残る |
| 活用形の周辺 | `inflectionForm` なしの形容詞、名詞(`新型`)、offset が一致しない最終段のトークン、offset は一致するが小文字化後の term が一致しないトークン | 残る |
| チャンクをまたぐ | 2 チャンクで同じ (start, end) に別の語がある | チャンクごとに対応付ける(他チャンクの活用形で誤って除外しない) |
| 縮退 | tokenizer 段が `null`、例外、品詞なし | 活用形は除外されず従来どおり(例外でも `parseDocument` は失敗しない)。C1/C2 は除外される |
| 連結語の縮退の区別 | `null` と例外が混在 | 連結語側は `STAGE_UNAVAILABLE` と `FAILURE` を別々に数える |
| 読みの対応 | 活用形や断片を除外した後に残る語の `readings` | 各語の読みが元の index の読みと一致する(ずれない) |
| 設定 | 各プロパティの `false` / 既定 | 従来の動作に戻る/規則が増える。`filter.enabled=false` で `latin.short`/`single.han` が効かない |
| tokenizer 段の取得回数 | `compound=true/inflection=true`、`compound=false/inflection=true`、両方 `false`、空文字 | 1 チャンクにつき 1 回、1 回、0 回、0 回。`compound=false` では連結語名義の警告が出ない |
| 連結語の端トリム | `ー`+`めん`+`才遊記`、`ー`+`警視庁`+`編`+`ー`、`.`+`ー`+`東京`+`大学`+`ー` | `めん才遊記`、`警視庁編`、`東京大学` |
| 端トリム: 残るもの | `ぴ`+`ー`+`先生`(中間)、`ゆ`+`ー`(トリム後 1 トークン)、`ー`+`ー` | `ぴー先生` が出る。後者 2 つは連結語なし |
| #2 の例語 | `新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`、`togetter.com`、`神奈川県` | 連結語が従来どおり出る(退行なし)。既存の `DefaultContentsParserCompoundWordTest` が通る |
| 検索ログ経路 | `ッ`、`ー`、`!!!`、`...` | 除外される(アナライザを呼ばない)。`ai`、`月`、`x`、`大きく` は残る |
| 検索ログ経路: 複数語・全除外・null・空 | `ー 映画`、`ー ッ`、`null`、空文字 | `映画` だけの項目、`null`(項目なし)、除外、除外 |
| 応答の解析 | `DefaultContentsAnalyzerParseTokenizerStageTest` に、`inflectionForm` がトークンの属性にコピーされるケース(属性なしでも品詞の有無の判定は変わらない)を足す | 属性が保持される |

### 5.2 統合テスト(自動)

`SuggestTestServer`(`modules/fess-suggest/src/test/java/org/codelibs/fess/suggest/SuggestTestServer.java`)の実 OpenSearch で、スタブでは検知できない応答の取り扱いを確認する。連結語の `CompoundWordIntegrationTest` と同じ構成にする。

- `analyzeTokenizerStage` の応答から `inflectionForm` が取れる(`なかっ`、`大き`、`難し`、`大きい`)。クライアントの応答パーサを通した JSON 再出力で属性が落ちないこと(`partOfSpeech` / `reading` と同じ汎用の仕組みで、`inflectionForm` は未確認)を含む。
- 最終段(通常の `analyze`)のトークンの offset が tokenizer 段の offset と一致する(対応付けの前提)。`mapping_char` で文字数が変わる入力(半角カナの濁点付きなど)でも一致する。
- 上の語を含む文書を `parseDocument` に通すと、`なかっ`、`大き`、`難し` が候補にならず、`大きい` が残る。複数チャンク(空白区切りで 1000 文字超)でも同様。
- 例語(`新型コロナ` など)の連結語が従来どおり生成される。

### 5.3 受け入れ確認(手動、実環境)

評価時と同じデータで suggest を再作成し、`/api/v2/suggest-words` と suggest 索引で確認する。再生成ごとに変動するため、比較は同一コーパスで、1 章の分類規則を実装した同じスクリプトで行い、できれば取得割合を一時的に 100% にする(`suggest.update.contents.limit.num.percentage`、`fess-res:fess_config.properties:1619`)。

1. 観測した断片が候補にならない: `なかっ`、`よかっ`、`大き`、`難し`、`ッ`、`ッッ`、`ー`、`ーー`。`ne`、`ku` は **既定では 2 文字のため残る**。`latin.short.enabled=true` で確認する(`ku` は現在の索引に無く、本文からの再現のみ)。
2. #2 の例語(`新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`、`togetter.com`、`神奈川県`)が、従来どおり語そのもの、またはその語を前方に含む連結語として取得できる。読み補完(`にほん`→`日本`)が退行しない。
3. 基本形(`ない`、`いい`、`すごい`)が残る。
4. 基準値との比較(1 章の分類): C1 と C2 が 0、C3/C4 が 0(名詞用法のある約 12 語を除く)、C5 は 199 → 174、C6 は 821 → 777。断片の総数は 11,825 → 約 11,380(443 減)。促音長音を含む連結語 16 件のうち 15 件が消えるか短くなる。
5. `fragment.*` の各プロパティを切り替えた再作成で、期待どおりに増減する。

## 6. 他の改善点との相互影響とスコープ外

- **#2(連結語)**: 連結語の生成条件は変えない。端の促音長音の除去だけが変わり、例語は退行しない(5.1、5.3)。tokenizer 段の取得条件が変わる影響は 3.8。
- **#7(汎用語・1 文字語)**: 活用形の除外で `なく`、`なし`(評価書が汎用語として挙げた語)が消える。`ない` は基本形のため残る。単漢字(`月`、`人`)の扱いは #7 の領域で、`single.han.enabled` は #7 の判断と合わせて有効にするか決める。
- **#8(ゴミ文字列・識別子)**: `jp`、`co`、`ne` は `latin.short.enabled` で消せるが、`https`、`com`、`html` など 3 文字以上は残る。1 文字の英数(`x` など)は既定でも消える。`ai`、`pc`、`tv`、`cm` などの略語は `latin.short.enabled` で消えるため、頻度では区別できず(`ai` 737、`jp` 724)、許可リストを要する。#8 と合わせて判断する。
- **#9(長音の表記ゆれ)**: `ハンバーガ` は取り込み元の表記で、フィルタでは除けない。長音あり/なしが両方候補の組(19 組)の統合は #9 で扱う。
- **#14(人名断片)**: 影響しない(名詞は対象外)。
- スコープ外: `おもし` の誤分割(N1。品詞では落とせない。辞書側の課題で、相方の `ろ` は本設計で消える)、`ハンバーガ` の取り込み元表記(N3)、頻度やスコアによる取得側の調整(#12)。

## 7. リスク・実装前に確認する事項

### 実装前に確認する事項 [要確認]

1. **`_vanilla` と `SuggestTestServer` の tokenizer 段で `inflectionForm` が取れるか。** `_vanilla` は標準の `kuromoji_tokenizer`(`fess-res:suggest_indices/_vanilla/suggest_analyzer.json:11`)、`SuggestTestServer` は同梱の `ExtensionPlugin`。fess-suggest 同梱の定義(`modules/fess-suggest/src/main/resources/suggest_indices/suggest_analyzer.json:10`)は `reloadable_kuromoji_tokenizer` で、これも未確認。取れない構成では活用形の除外が働かず現状と同じになる(誤った除外はしない)。
2. **Java クライアント経由で `inflectionForm` が取れるか。** 実機確認は REST の応答。クライアントの `Response.toXContent` を通した JSON でも属性が落ちないことを、5.2 の統合テストで確認する。
3. **最終段の offset が tokenizer 段と一致するか(通常の `analyze` で)。** 実機確認は explain の最終段で行った。5.2 で通常の `analyze` の応答と照合する。
4. **`attributes` に `inflectionForm` を足したときの応答サイズと処理時間。** 活用する語(形容詞・動詞・助動詞)にだけ属性が増えるため増加は小さい見込み [推測、未測定]。
5. **連結語が無効で活用形が有効なときの負荷。** 1 チャンクにつき explain が 1 回加わる(3.4)。空白が少なく 1 チャンクが数万文字になる本文を含めて、suggest 作成の総実行時間を測る。許容できない場合は `inflection.enabled=false` で止める。
6. **`analyzeText` を継承する外部コードの有無**(3.4)。
7. **Fess が `parseDocument` に渡す lang の値の形式。** 文書の言語フィールドが `ja` のような短い形式で入ることを確認する。`ja_JP` のような形式で入る場合、最小長の規則(3.3)が日本語の文書に適用されない。
8. **評価ゲート。** `inflection.enabled` の既定 `true` は、連結語の `compound.enabled` と同様に暫定とする。連結語のベースライン測定(`enabled=false`)に `inflection.enabled=false` を併記し、性能(explain の追加分を含む)と、除去される断片・失う語を同じ手順で確認してから、本番の既定を確定する。
9. **1 文字の英数だけを個別に切れる設定の要否。** 既定で消える 1 文字英数 25 語に有用なもの(`x`〔旧 Twitter の呼称〕、`c`、`e` など)があるかを実コーパスで確認し、必要なら `latin.short.enabled` とは別に、1 文字英数を残す設定を足す。

### リスク

- 見積もりは 100 文書・単一コーパス(はてなブックマーク一覧ページ)での 1 回分の値。再生成で変動し、他のコーパスでの割合は未知。
- 「巻き添えは少ない」という評価は主観的な判断(推測)。既定(1 文字の英数・かな)でも、1 文字英数 25 語(docFreq 計 1,303。`x` 319、`m` 119、`t` 94、`e` 79、`c` 66)は消える。英数 2 文字以下の略語(`ai` など)と単漢字(`米` など)は、有用か否かがコーパスと用途で変わるため、既定では除外しない。
- 活用形の除外は Kuromoji(IPADIC)の `inflectionForm` の値(`基本形` の表記)に依存する。辞書やトークナイザが変わると判定が変わる。5.2 の統合テストで検知する。
- デモ環境の断片(`ーッッ` など)が同じ機構かは未確認 [推測]。
- 評価対象の `ne`、`ku` は、既定の設定では解消しない(英数 2 文字)。解消するには `latin.short.enabled` を有効にし、略語の消失を受け入れる。
