# 0002 原因調査(フェーズ1)

担当: tech-advisor(報告をメインエージェントが記録)。コード・既存ファイルの変更なし。OpenSearch / Fess は読み取りのみ。

## 1. 結論

観測した断片はすべて文書経路(`parseDocument` の「1 トークン = 1 候補」)で生まれる。保存前のフィルタは `contents_analyzer_ja` の `pos_filter`(品詞)、`content_length_filter`(最大 30)、既定ブラックリスト(`* ? " '` を含む語)だけで、最小長・文字種・活用形のフィルタは無い。

ローカルの suggest インデックス `fess.suggest.20261115085528534` は 18,144 件(document のみ 18,132、query のみ 6、document+query 6)。

| 断片 | 生まれる経路・処理(実測) | 落ちない理由 |
| --- | --- | --- |
| `なかっ` `よかっ` `大き` `難し`(活用の途中形) | 文書経路。Kuromoji が「形容詞-自立」と判定(`なかっ`/`よかっ` は連用タ接続、`大き`/`難し` はガル接続) | stoptags に `形容詞` はあるが `形容詞-自立` が無い。`JapanesePartOfSpeechStopFilter` は完全一致で前方一致ではない。動詞は `動詞-自立` が明記されており全部落ちる。「面白く+なかっ+た」のように助動詞と判定された場合は落ちる |
| `おもし` | 文書経路。「(おもしろ)」のように括弧に接する位置で `おもし`(名詞-一般)+`ろ`(名詞-一般)に誤分割 | 両方とも名詞-一般で、品詞では原理的に落とせない |
| `ハンバーガ` | 取り込み元の文章が「ハンバーガとピザ」と書いている(10 文書で確認、`ハンバーガー` を含む文書は 0 件) | 候補生成の欠陥ではなくデータ側の表記 |
| `ッ` `ッッ` `ー` `ーー` | 文書経路。「買いまくりッ!!!」「すげー」「知ったーー。」など。名詞-一般 | `pos_filter` は名詞を通す。最小長・文字種のフィルタが無い |
| `.` `/` `:` `-` `@` など記号のみ | 文書経路。ASCII 記号は辞書上「名詞-サ変接続」。URL が `p . hatena . ne . jp` のように分割される | 名詞-サ変接続は実名詞(反響など)があり品詞では落とせない |
| `ne` `ku` | 文書経路。読みの変換ではなく本文中の英字トークンそのもの(`ne` は `hatena.ne.jp` 等。`ku` は現在の索引に無い) | 最小長・文字種のフィルタが無い |
| `ー…` で始まる連結語(13 件) | 連結語の経路。`ー` が連結対象品詞(名詞-一般)で、`Character.isLetter` が true のため `trimSymbolTokens` でも除かれない | 断片を引き継ぐ |

## 2. 仮説の判定

| 仮説 | 判定 | 要旨 |
| --- | --- | --- |
| H1 `pos_filter` が活用形を落とさない | 部分的に確認 | 動詞は全部落ちる。形容詞だけ `形容詞-自立` が無く通る。`おもし` は別原因(誤分割) |
| H2 基本形に戻していない | 確認(寄与要因) | suggest アナライザに `*_baseform` は無い(3 定義すべて)。`fess_japanese_baseform` を入れると なかっ→ない、大き→大きい、難し→難しい、よかっ→よい になる。通過の直接原因は H1 で、baseform は対処手段 |
| H3 文字種・最小長フィルタが無い | 確認 | `content_length_filter` は `{"type":"length","max":30}` のみ。コード側(`DefaultContentsParser`、`SuggestItem`、`IndexingOperations`)にも長さ・文字種の検査は無い |
| H4 stemmer が末尾の `ー` を落とす | 棄却 | suggest 用 ja アナライザに stemmer は無い。`ハンバーガ` は取り込み元の表記。stemmer は検索用 `japanese_analyzer` にだけある |
| H5 ローマ字断片は読み前方一致か英字分割 | 読みは棄却、英字トークンは確認 | `ne` の `reading_0` は `['ne']`。本文の URL ラベルや識別子の英字トークン |
| H6 検索ログ・連結語経路にも出る | 部分的に確認 | 検索ログ経路は 12 件で断片 0。ただし品詞・文字種フィルタを通らない(`isExcludeSearchword` は「トークンが 1 つでも残るか」だけ)ため、`なかっ` `ッ` `ー` と検索されれば候補になる。連結語経路は断片を引き継ぐ |

### 追加で見つかった原因
- N1: トークナイザの誤分割(`おもし`+`ろ`)。品詞フィルタでは落とせない。
- N2: ASCII 記号が名詞-サ変接続、英字が名詞-一般/固有名詞-組織として通る。URL・識別子が分割されたまま候補になる(#8 と同根)。
- N3: 取り込み元に欠けた語がある(`ハンバーガ`、`ケンタッキ`)。フィルタでは除けない。#9 の表記ゆれ統合の領域。
- N4: アナライザ定義は suggest 用アナライザ索引(`fess_suggest_analyzer`)の作成時にだけ書き込まれる(`AnalyzerSettings.java:151-190`。`updateAnalyzer`(`:275`)の呼び出し元はコード中に無い)。既存環境は、索引を削除して再作成し、suggest を再生成するまで定義の変更が反映されない。

## 3. 基準値(ローカル suggest インデックス、全 18,144 件)

出所の判定: `contents_analyzer_ja` の 1 トークン(100 文書の再現に一致、または単独で 1 トークン)は断片、2 トークン以上は連結語。断片 11,825 件、連結語 6,319 件。

| 区分 | 件数 | 断片内割合 | 全体割合 | docFreq 合計 | 代表例(docFreq) |
| --- | ---: | ---: | ---: | ---: | --- |
| C1 促音・長音のみ | 4 | 0.0% | 0.0% | 317 | `ー`(299)、`ーー`(11)、`ッ`(4) |
| C2 記号のみ | 194 | 1.6% | 1.1% | 17,291 | `/`(4,040)、`.`(4,015)、`-`、`:` |
| C3 形容詞の途中形(形容詞-自立 かつ ガル接続/連用タ接続) | 72 | 0.6% | 0.4% | 756 | `おもしろ`(370)、`なかっ`(35)、`よかっ`、`大き`、`難し` |
| C4 形容詞のその他の活用形 | 104 | 0.9% | 0.6% | 716 | `なく`(89)、`長く`、`早く`、`なけれ` |
| C5 英数字のみ 2 文字以下 | 199 | 1.7% | 1.1% | 4,220 | `ai`(737。正当)、`jp`(724)、`ne`(12) |
| C6 1 文字(C1〜C5 以外) | 821 | 6.9% | 4.5% | 9,891 | `月`(932)、`人`、`米` |
| C7 その他 | 10,431 | 88.2% | 57.5% | 116,511 | 完成語がほとんど |
| 連結語(参考) | 6,319 | - | 34.8% | 25,171 | `新着エントリー`、`togetter.com` |

- C1〜C6 合計 1,394 件(断片の 11.8%、全体の 7.7%)。確度の高い C1〜C4 は 374 件(断片の 3.2%、全体の 2.1%)。
- C7 の参考内訳: 形容詞の基本形 132(`ない`、`いい`)、英字 3 文字以上 2,350(#8)、ひらがな 2〜3 文字 221(`あと`、`おもし`)、その他 7,728。
- 長音あり/なしが両方候補の組が 19 組(#9)。
- 返却側の露出: 1 文字入力 72 種で `suggest-words`(num=15)を呼んだ結果、返却語 1,067 件中 C1〜C6 が 125 件(11.7%。C5 5.5%、C6 5.7%、C3 0.3%、C4 0.2%)。
- 制約: 100 文書・50% ランダム読み取りの 1 回分で、再生成のたびに変動する。比較には同一コーパスと同じ分類スクリプトを使う。

## 4. 経路とフィルタ

### 文書経路
1. `ESSourceReader`(`:249-262`)がサイズ 50000 以下の文書を、`limit.num.percentage=50%` と `limit.num=10000` の少ない方まで読む。
2. `parseDocument`(`DefaultContentsParser.java:346-402`)。`forEachChunk`(`:779`)が ASCII 空白で分割し、1,000 文字ごとにチャンク化。`analyzeText`(`:739`)が `contents_analyzer_ja` を呼ぶ。構成: `mapping_char` → `fess_japanese_normal` → `lowercase` → `stopword_en_filter` → `pos_filter` → `content_length_filter`(max 30)→ `limit_token_count_filter`。
3. 残ったトークンごとに `createDocumentItem`(`:417`)で `SuggestItem(DOCUMENT)` を作る。読みは `contents_reading_analyzer_ja`。正規化(`normalizer`)は使われない。
4. 連結語: `createCompoundItems`(`:433`)。
5. `IndexingOperations.index`(`:78`)が `SuggestItem.isBadWord`(`:455`、部分一致)でブラックリスト除外(既定は `* ? " '`)。
6. `SuggestIndexWriter` がマージして書き込む。頻度の足切りは無い。

### 検索ログ経路
`indexFromSearchLog`(ヒット 0 件を除く、`suggest.min.hit.count=1`)→ `parseSearchWords`(`:271-304`)→ `isExcludeSearchword`(`:860`)→ `normalize_analyzer` → 読み変換 → `isBadWord`。品詞・文字種・長さのフィルタは通らない。

### 取得側
`SuggestQueryBuilder.buildQuery` は reading_N の前方一致または完全一致。`buildFunctionScoreQuery` は `docFreq`/`queryFreq` の log2p と `userBoost` の積。`SuggestResponseCreator` / `SuggestWordsHandler` に品詞・長さ・頻度による足切りは無い。

### アナライザ定義(3 か所)
`pos_filter` の stoptags 74 個は 3 か所で同一(JSON パースで確認)で、いずれも `形容詞-自立` を含まず、stemmer・baseform も無い。

| ファイル | tokenizer / pos_filter の型 | 備考 |
| --- | --- | --- |
| `fess-suggest/src/main/resources/suggest_indices/suggest_analyzer.json`(`pos_filter:1301`) | `reloadable_kuromoji_tokenizer` / `reloadable_kuromoji_part_of_speech` | `limit_token_count_filter` は 10000。`title_contents_analyzer` あり |
| `fess/src/main/resources/suggest_indices/suggest_analyzer.json`(`:1291`) | `fess_japanese_tokenizer` / `fess_japanese_part_of_speech` | ローカル稼働中の実体と ja 系 4 アナライザ・`pos_filter` が一致 |
| `fess/src/main/resources/suggest_indices/_vanilla/suggest_analyzer.json`(`:1291`) | `kuromoji_tokenizer` / `kuromoji_part_of_speech` | プラグイン無しの OpenSearch 向け |

検索用 `fess.json` の `japanese_pos_filter` は 33 個で形容詞・動詞を通す。suggest だけが広い stoptags にしている。

## 5. 実測環境と版情報

- OpenSearch 3.9.0(Docker `fess-opensearch`)。Fess は IntelliJ 起動。classpath は `modules/fess/target/classes` と `~/.m2/.../fess-suggest-15.10.0-SNAPSHOT.jar`(2026-11-14 06:53 ビルド)。
- クロール対象 `fess.20261109121845553`(100 文書、すべてはてなブックマーク一覧ページ、ja)。`fess_suggest_analyzer` は 2026-11-09 12:21 作成。
- `~/.m2` の jar は PR #107 の初期版(連結語は入っているが break chars / `ら` 除外 / 記号トリム / `名詞-形容動詞語幹` が無い)。main との差は `DefaultContentsParser.java` の連結語まわりだけで、断片の経路・`suggest_analyzer.json`・`AnalyzerSettings` は同一。C1〜C6 の原因は jar の版に依存しない。
- 使用した操作は `_cat/*`、`_settings`、`_mapping`、`_search`、`_analyze`、Fess `suggest-words` API のみ(読み取り)。

## 6. 成果物(scratchpad)

`/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/99af66c6-adc6-4c53-b91d-d8d58ebb8e3f/scratchpad/` 配下
- `dump_suggest.py`(索引全件ダンプ → `suggest_all.jsonl`)、`reproduce_fragments.py`(文書経路の断片再現)、`check_index_only.py`、`classify_fragments.py`(分類定義は冒頭。出力 `classified.json`、`classify_output.txt`)、`exposure.py`(API 露出)、`explain_samples.txt`(`_analyze` の explain 全文)、`analyzer_settings.json`、補助スクリプト。
- 再実行: `python3 -I dump_suggest.py suggest_all.jsonl` → `reproduce_fragments.py` → `check_index_only.py` → `classify_fragments.py`。

## 7. 確度と限界

- 確認済み: 形容詞の通過、記号・促音・長音・英字の通過、stemmer 不在、`ハンバーガ` が取り込み元の表記であること、3 定義の stoptags 同一、既存環境に定義が反映されないこと。
- 推測: デモ環境(`ーッッ` など)も同じ機構で出ること(デモ未アクセス)。評価時にあった `ku` は現在の索引に無く、本文からの再現のみ。main の `ー…` 連結語の発生(未実測)。
- 分類は機械的な定義。C6 の単漢字(`月`、`人`)は #7(1 文字語)の対象とみなすのが妥当で、#3 に含めるかは判断が要る。C3/C4 は「全出現が形容詞-自立」の語に限る。

## 8. フェーズ2への所見(tech-advisor)

- C3/C4: stoptags に `形容詞-自立` を足す(最小変更。3 か所を揃える)、または `*_baseform` で基本形に寄せる(`大き`→`大きい`、`なかっ`→`ない`)。
- C1/C2/C5/C6: 品詞では落とせない。アナライザ側の `pattern_replace` / `length(min)` など、または `DefaultContentsParser` 側の文字種・最小長判定。
- N1/N3(`おもし`、`ハンバーガ`): フィルタでは根絶できない。頻度・スコア・取得時の扱いなど別の手段が要る。
- 連結語(#2)は `analyzeTokenizerStage`(`pos_filter` より前)のトークンを使うため `pos_filter` の変更の影響は受けない。逆に連結語側の `ー` の扱いは別途揃える必要がある。
- `limit_token_count_filter` の値が fess-suggest と fess で異なる点も、定義を揃えるときに確認する。
- 既存環境へ反映するにはアナライザ索引の作り直しと suggest の再生成が必要。

## 9. 未対応事項・フェーズ2でユーザー判断が要る点

- 「断片」の定義に C5(短い英字)・C6(単漢字)を含めるか(#7・#8 との切り分け)。
- 形容詞の基本形(`ない`、`いい`、`すごい` など 132 件)を残すか。`形容詞-自立` を一括で落とすと有用語も消える。
- `おもし`、`ハンバーガ` のように品詞・フィルタで落とせない断片をスコープに含めるか。
- 次のアクション: 改善案の比較(フェーズ2)。
