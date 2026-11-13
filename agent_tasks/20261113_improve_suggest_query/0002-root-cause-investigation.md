# 0002 原因調査(フェーズ1)

担当: tech-advisor。リポジトリ内のコード・ファイルは変更していない。

## 1. 結論

複合語・固有名詞が候補にならない主因は、**文書経路が「形態素 1 トークン = 1 候補」で、さらに品詞フィルタが接尾辞を落とす設計**であること(仮説 H1 + H4)。評価書の例語の挙動をすべて説明できる。

| 仮説 | 判定 | 要旨 |
| --- | --- | --- |
| H1 分割単位 | **確認** | 文書経路は形態素単位でしか候補を作らない。IPADIC が 1 語として持つ語(`日本経済新聞`、`東京大学`)だけが連結語のまま残る |
| H2 頻度閾値 | **ほぼ棄却** | fess-suggest に最小頻度の足切りは無い。小規模コーパス特有の副要因のみ(§2-4) |
| H3 ユーザー辞書なし | **確認(構造として)** | suggest 側トークナイザにユーザー辞書が無く、運用者が複合語を 1 語登録する手段が効かない。例語が落ちる直接原因ではなく、救済手段が塞がれている位置づけ |
| H4 品詞フィルタ | **確認(一部)** | `pos_filter` が `名詞-接尾-一般` を落とすため、`大統領選` の `選`、`円安` の `安` が消える。語長フィルタは `max: 30` のみで最小長制約は無い |
| 検索ログ経路 | コード上は問題なし | 複合語をそのまま保持して候補化できる。評価で 0 件だったのは、その語がまだ検索ログに無かった可能性が高い [推測] |

## 2. 確認した事実

### 2-1. 文書経路のコード追跡
- `fess-suggest:index/contents/DefaultContentsParser.java:154-211` の `parseDocument` は、`analyzeText`(`:169`、`:235`)の戻りトークンを 1 個ずつ `SuggestItem`(`:185` の `words = { word }`)にする。連結・N-gram・shingle の処理は無い。
- 使うアナライザは `contents_analyzer_ja`(日本語)または無印 `contents_analyzer`。構成は `fess_japanese_normal`(mode: normal)+ `mapping_char` + `lowercase` + `stopword_en_filter` + `pos_filter` + `content_length_filter` + `limit_token_count_filter`。
  - 場所: `fess:src/main/resources/suggest_indices/suggest_analyzer.json:10, 37, 64`(`pos_filter` は `:1291`、`content_length_filter` は `:1374`)。
  - fess-suggest 側の同名ファイルも構成は同じ(`kuromoji_neologd_normal` を使う違いのみ)。`pos_filter` の `stoptags` 74 件は両ファイルで一致(JSON パースで確認)。
- 語長・頻度の足切りは無い。
  - `content_length_filter` は `{"type":"length","max":30}` のみ。
  - 頻度は `SuggestQueryBuilder.java` の関数スコア(`DOC_FREQ` / `QUERY_FREQ` の log2p)で順位に効くだけで、足切りにはならない。
  - `IndexingOperations.java:78` の bad word 判定以外に、保存前のフィルタは無い。

### 2-2. トークン分割の実測(Lucene Kuromoji 9.5.0 / IPADIC、ユーザー辞書なし、NORMAL モード)
品詞は fess の `pos_filter`(stoptags 74 個)で判定。実環境の `contents_analyzer_ja` 経由ではなく、手元の jar によるオフライン再現。

| 入力 | 分割と品詞(落ちるものに ×) | 候補になる単位 | 評価書の観測との整合 |
| --- | --- | --- | --- |
| 新型コロナ | 新型(名詞-一般) / コロナ(名詞-一般) | `新型`、`コロナ` | 一致 |
| 大統領選 | 大統領(名詞-一般) / **選(名詞-接尾-一般)×** | `大統領` のみ | 一致 |
| 高市早苗 | 高市(固有名詞-人名-姓) / 早苗(固有名詞-人名-名) | `高市`、`早苗` | 一致(#14 の根) |
| 石破首相 | 石破(人名-姓) / 首相(名詞-一般) | `石破`、`首相` | 一致 |
| ワクチン接種 | ワクチン(名詞-一般) / 接種(名詞-サ変接続) | `ワクチン`、`接種` | 一致 |
| 円安 | 円(名詞-一般) / **安(名詞-接尾-一般)×** | `円` のみ | 一致 |
| 新型コロナウイルス感染症 | 新型 / コロナ / ウイルス / 感染 / **症(接尾)×** | 各断片 | 追加確認 |
| 日本経済新聞、東京大学 | 1 トークン(名詞-固有名詞-組織) | **連結語のまま候補になる** | 一致 |

- 連結語が候補になるのは、IPADIC が 1 語として持つ語だけ。それ以外の複合語は、何件出現しても連結語が候補になり得ない。
- 接尾辞(`選`、`安`、`高`、`症`)は単独では意味が弱く落とす理由があるが、直前の名詞と連結すれば有用な語になる(`大統領選`、`円安`、`円高`)。

### 2-3. 検索ログ経路
- 保持: `DefaultContentsParser.java:79-112` の `parseSearchWords` は `normalizer.normalize` に通すだけ。`normalize_analyzer` は `keyword` tokenizer + `mapping_char` + `lowercase` で分割しない。品詞・語長フィルタも通らない(除外は `isExcludeSearchword`(`:344`)と bad word のみ)。
- 閾値: `suggest.min.hit.count=1`(`fess:fess_config.properties:1605`)。判定は `SuggestHelper.java:273-278` で、ヒット 0 件のログだけを落とす。`FessConfig.java:1931` は定数宣言のみ。`新型コロナ` は 100 件ヒットなので通る。
- 権限: `suggest.search.log.permissions={user}guest,{role}guest`(`fess_config.properties:1631`)。ゲスト検索なら通り、ログイン検索は通らない(既存知見 Y-03)。
- ログ生成経路: `TermQueryCommand.java:262` の `addFieldLog` → `SearchHelper.java:234-237` → `SearchLogHelper.addSearchLog`(`:176`)→ Log Aggregator ジョブ(毎分)が `processSearchLog`(`:652-657`)で処理 → `isSuggestSearchLog()`(既定 true)なら `indexFromSearchLog`。
- 評価で 0 件だった理由の候補:
  1. 0 件を確認した後に検索 API でヒット件数を確認しているため、サジェスト確認時点でその語が検索ログに無かった [推測。最有力]。
  2. ログイン済みで権限判定により除外、`suggest.search.log` 無効、Log Aggregator 未実行などの環境起因 [推測]。
  3. 検索ログ経路は利用状況依存で、導入初期や検索されない語には効かない(仕様上の制約。既存知見 Z-02 / Y-03)。

### 2-4. 小規模コーパス特有の取りこぼし(H2 の補足)
- 文書経路の読み取り上限は `suggest.update.contents.limit.num.percentage=50%` と `limit.num=10000` の少ない方(`fess:SuggestHelper.java:367-379`、`fess-suggest:ESSourceReader.java:196-216, 324-330`)。100 文書のクロールでは約 50 文書しか読まない。読む順序はクリック数 → ランダム(`SuggestHelper.java:394-396`)。
- `大統領選`(3 件)や `円安`(4 件)は入力に入らない可能性がある。ただし §2-2 のとおり構造的にも落ちるため、主因ではなく再現性を下げる副要因。

## 3. 推測・要確認
- [推測] 評価の 0 件は、検索ログがまだ存在しなかったため(§2-3 の 1)。
- [推測] 実環境の `fess_japanese_tokenizer` が Lucene 9.5.0 IPADIC と同じ分割をすること。評価書の観測とは完全に一致している。
- [要確認] fess-suggest 側の `kuromoji_neologd_normal` が NEologd 辞書を引く構成か。NEologd なら `新型コロナウイルス`、`高市早苗` 等が 1 語になる可能性がある(fess 本体は `fess_japanese_normal` を使う)。
- [要確認] 実環境の API 実測(未実施)。手順: ① `_analyze` に `contents_analyzer_ja` と `新型コロナ` を渡す ② `fess_log.search_log` に `searchWord=新型コロナ` があるか確認 ③ 検索後に `/api/v2/suggest-words?q=新型コロナ&fn=_default` を再確認。

## 4. 改善の方向性の材料(案の選定はフェーズ2)
- **案 A: 文書経路で連続名詞・接尾辞を連結して候補化する**
  - 例語 6 語をすべて救済できる(連続名詞の連結 + 接尾辞を直前の名詞に連結)。
  - 実現方法は、`pos_filter` で消した位置を隙間として扱う(shingle の filler token など)か、`_analyze` の offset 情報で隣接を判定するか。変更箇所は `DefaultContentsParser.parseDocument` とアナライザ定義(fess-suggest と fess の 2 か所)。
  - 候補とインデックスが増える。#3 / #14(断片の抑制)とは逆方向で、相互影響の明記が必要。既存の文書由来語は再構築でしか更新されない。
- **案 B: suggest 側トークナイザにユーザー辞書を適用する(Y-08)**
  - `fess_indices/fess.json:670` の `user_dictionary` 相当を `suggest_analyzer.json` の `fess_japanese_normal` に足す。変更は小さいが、運用者が登録した語しか救えず、単独では不十分。案 A の補完。既存環境への反映手段は Y-09 に依存する。
- **案 C: 閾値・重み付けの調整**: 原因が頻度閾値ではないため効果は薄い。検索ログ側も最低ヒット 1 で通るため調整余地が無い。
- **補助案: `名詞-接尾-一般` を stoptags から外す**: 案 A の接尾辞連結ができない場合の次善策。`選`、`安`、`症` の単独断片が増え #3 を悪化させる。

## 5. 実測の可否
- ローカル環境の API 実測は不可(`localhost:9200` / `8080` に接続できず、docker も空)。起動はしていない。
- 代替として Lucene Kuromoji 9.5.0 jar でオフライン再現した。

## 6. 一時ファイル(scratchpad、リポジトリ外)
`/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/008316e7-be3e-44e7-8c0b-10d0bbfa6ee1/scratchpad/` 配下の `Tok.java`、`cp.sh`、`stoptags_fess.txt`、`stoptags_suggest.txt`。

## 7. 未対応事項・次にやること
- 実環境での `_analyze` と検索ログの確認、NEologd の有無の確認(設計書の「実装前に確認する事項」に残す)。
- 他言語アナライザ(`pos_filter` なし)での複合語の扱いは未調査(評価書の対象は日本語)。
- 判定: 原因は確定でき、方式選択に影響する不確かさは小さい。プランの判定基準に従い、ユーザー報告なしでフェーズ2へ進む。
