# 0004 採用案の決定と活用形属性の確認

## 1. ユーザーの決定(フェーズ2の承認ゲート)

| 項目 | 決定 |
| --- | --- |
| 「断片」の定義 | M1: 促音長音のみ・記号のみ・英数1文字・かな1文字を除外(0003 §3・§4)。M2(英数2文字以下)・W1(単漢字)は設定で切り替えられる形にする(既定は無効) |
| 活用形の対処 | A': Java 側で形容詞-自立の活用形(基本形以外)だけを除外する。ユーザー指示: 「複合語で使用している Tokenize 時に inflectionForm で活用形も取得して判定に利用できるか確認してみて」 |
| 検索ログ経路 | C1/C2(促音長音のみ・記号のみ)の除外を入れる。最小長は入れない |
| 連結語 | 両端の促音長音のみのトークンを外す(端トリム)。0003 の推奨どおり |

採用パッケージ: J(M1)+ A' + 連結語の端トリム + 検索ログ経路への C1/C2。すべて fess-suggest の Java 側。アナライザ定義(`suggest_analyzer.json`)は変更しない。

## 2. 確認: トークナイザ段のトークンから活用形が取れるか

### 実装の現状(読解)
`AnalyzerSettings.DefaultContentsAnalyzer.analyzeTokenizerStage` は explain 付きの `_analyze` を呼び、応答を絞るため `builder.request().attributes(List.of(PART_OF_SPEECH_ATTRIBUTE, READING_ATTRIBUTE))`(`AnalyzerSettings.java:475`)で `partOfSpeech` と `reading` だけを要求している。`DefaultContentsParser` は `partOfSpeech`(`:619-621`)と `reading`(`:689`)だけを読む。このため `inflectionForm` は現在は要求も参照もされていない。

### 実機確認(ローカル OpenSearch 3.9.0、`fess_suggest_analyzer` の `contents_analyzer_ja`、読み取りのみ)
`_analyze` に `explain: true` と `attributes: [partOfSpeech, reading, inflectionForm, inflectionType, baseForm]` を指定した結果、tokenizer 段(`fess_japanese_normal`)のトークンに次の属性が付いた。

| 入力中の語 | offset | tokenizer 段の品詞 | inflectionForm | baseForm |
| --- | --- | --- | --- | --- |
| なかっ | 3-6 | 形容詞-自立 | 連用タ接続 | ない |
| 大き | 11-13 | 形容詞-自立 | ガル接続 | 大きい |
| 難し | 17-19 | 形容詞-自立 | ガル接続 | 難しい |
| 大きい | 28-31 | 形容詞-自立 | 基本形 | (なし) |
| 新型 / コロナ | 32-34 / 34-37 | 名詞-一般 | (なし) | (なし) |

- 最終段(`limit_token_count_filter`)に残るトークンにも同じ属性が付き、offset は tokenizer 段と一致した(`なかっ` 3-6、`大き` 11-13、`難し` 17-19、`大きい` 28-31)。`pos_filter` を通ったトークンは tokenizer 段のトークンの部分集合で、offset をキーに対応付けられる。
- `attributes` の指定に `inflectionForm` を足すだけで、連結語に使っているのと同じ tokenizer 段の結果から活用形が取れる。したがって A' は、複合語用に取得している tokenizer 段の結果(`TokenizerStageResult`)を共用して判定できる。判定は「最終段に残った語」の (startOffset, endOffset) が、tokenizer 段で `形容詞-自立` かつ `inflectionForm` が `基本形` 以外のトークンと一致するか、で行える。

### 設計への含意
- 連結語用の explain 呼び出しを共用するため、A' のために `_analyze` の呼び出し回数は増えない。ただし連結語が無効(`fess.suggest.compound.enabled=false`)のときも A' を有効にするなら、explain 呼び出しが必要になる。連結語無効時の扱い(A' のためだけに explain を呼ぶか)は設計書で決める。
- `analyzeTokenizerStage` が `null`(他言語・取得失敗・文字数超過)のときは、活用形の除外を行わず現行どおりに縮退させる。
- `attributes` に足す属性は `inflectionForm` のみで足りる(`baseForm` などは不要)。応答サイズの増加は小さい見込みだが、実環境での影響は未測定。

### 未確認(設計書の「要確認」に残す)
- `_vanilla`(標準 `kuromoji_tokenizer`)と `SuggestTestServer` の tokenizer 段で `inflectionForm` が取れるか。
- `attributes` に `inflectionForm` を足した場合の応答サイズ・処理時間への影響。
- 連結語の `analyzeTokenizerStage` を連結語無効時にも呼ぶ場合の負荷。

## 3. 次のアクション
- フェーズ3: document-writer で設計書 `task_docs/design_fragment_suggest.md` を作成する。
