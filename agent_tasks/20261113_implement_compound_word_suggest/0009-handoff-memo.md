# 0009 フェーズ6: 引き渡しメモ(Fess 組み込み・動作確認用)

第2回再確認(code-reviewer): Critical / Important なし、「次工程に進めてよい」。未対応の Suggestion 2 件・Nitpick 4 件は 6 章の既知の制約に記載。

## 1. 成果物

- jar: `/Users/yfujita/fuji/n2sm/fess/fess-suggest-workspace/modules/fess-suggest/target/fess-suggest-15.10.0-SNAPSHOT.jar`(207,069 バイト。`-sources.jar` / `-javadoc.jar` も同ディレクトリ)
- コードは `modules/fess-suggest`(独立 git リポジトリ、HEAD `214421a`)に**未コミット**で入っている。コミットはしていない。
- 検証状況: `mvn test` 全体 827 件、失敗 0・エラー 0・スキップ 0(ローカルの `SuggestTestServer`、neologd 構成)。
- 変更していないもの: `suggest_analyzer.json`(両方)、`modules/fess` 全体、`SuggestTestServer`。fess 側は変更不要(アナライザ定義を変えないので既存環境の `fess_suggest_analyzer` index の再作成も不要)。

## 2. 変更内容の要約(`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下)

| ファイル | 内容 |
| --- | --- |
| `analysis/SuggestAnalyzer.java` | `default TokenizerStageResult analyzeTokenizerStage(text, field, lang)`(既定は `null`=取得不可)を追加。既存の実装クラスは変更不要 |
| `analysis/TokenizerStageResult.java`(新規) | tokenizer 段のトークン(品詞・読み・offset)と char_filter 適用後の本文を持つ不変クラス。トークン空も許す |
| `settings/AnalyzerSettings.java` | `DefaultContentsAnalyzer.analyzeTokenizerStage` を実装(explain 付き `_analyze`、`attributes` で `partOfSpeech`/`reading` に絞る)。`_analyze` 失敗は例外にせず WARN(60 秒に 1 回)+`null` |
| `index/contents/DefaultContentsParser.java` | 隣接する対象品詞(12 種)の最大連続列を連結語として追加候補にする。断片(従来の 1 トークン=1 候補)は残す。設定 3 種、縮退カウンタ、ログ |
| `util/LogRateLimiter.java`(新規) | ログを間引く小さな public クラス |

連結の規則(設計書 3.2): 対象品詞は完全一致 12 種、連続は offset の隣接で判定、最大連続列のみ(部分列は作らない)、2 トークン以上かつ `max.tokens` 以下、表層は小文字化後 `max.length` 以下、連結した表層が char_filter 適用後の本文に含まれること。数・助数詞・人名接尾辞・動詞・助詞は対象外。

## 3. 設定(System property。suggest 作成プロセスの JVM に `-D...` で渡す)

設計書 3.4 のとおり、`fess.suggest.max.analyzed.content.length` と同じ方式。suggest 作成プロセスには `jvm.suggest.options`(`fess_config.properties`)に `-D...` を足して渡す。

| プロパティ | 既定 | 内容 |
| --- | --- | --- |
| `fess.suggest.compound.enabled` | `true`(**暫定**) | `false`(大文字小文字無視)で連結語の生成と追加の explain 呼び出しを止める。**`false` 以外(typo・空値・`yes`・`1` など)もすべて無効扱い**になる。既定 `true` は、実環境の評価なしに本番既定として確定しない |
| `fess.suggest.compound.max.tokens` | `5` | 連結するトークン数の上限。**2 未満・不正値は既定値(5)** |
| `fess.suggest.compound.max.length` | `20` | 連結語の表層の最大文字数。1 未満・不正値は既定値、30 超は 30 |

## 4. 反映・停止・ロールバック(設計書 4.2)

1. **反映(通常)**: jar を更新して通常の suggest 更新を待つ。取得上限(`suggest.update.contents.limit.num.percentage`=50%、`.num`=10000、`.doc.size`=50000)の範囲で処理された文書分だけ連結語が入る。
2. **反映(全件)**: `deleteDocumentWords` で文書由来の語を削除してから再作成するか、取得上限を一時的に引き上げて更新する。更新時間とメモリに直結するので、先に 5 章の測定を行う。
3. **停止**: `fess.suggest.compound.enabled=false`。jar を戻さずに止められるが、**生成済みの連結語はすぐには消えない**(新規生成が止まるだけ。文書由来のみの項目は `purgeDocumentSuggest` の期限削除で徐々に消える)。
4. **ロールバック(即時除去)**: `enabled=false` にしたうえで `deleteDocumentWords` で文書由来の語を全削除し、再作成する。検索ログ由来・ユーザー登録の項目も持つ語は `docFreq` が 0 に戻るだけで残る。

## 5. 動作確認チェックリスト(ユーザー作業。設計書 7 章のゲートのうち実環境分)

**ベースライン(`enabled=false`)を先に取り、その値と比較する。** 閾値の数値は設計書では決めていない(ベースライン測定後に決める)。

- [ ] **(最優先)実環境の explain が `partOfSpeech` / `reading` を返すこと。** `contents_analyzer_ja` に `explain: true` で `新型コロナ` を渡し、tokenizer 段に `partOfSpeech: 名詞-一般` と `reading` が出ること(ローカルは neologd 構成の実測のみ。実環境の `fess_japanese_normal` / `_vanilla` は未確認)。あわせて、char_filter 適用後の本文 `detail.charfilters[].filtered_text`(単数形)が返ること、`mapping_char` で文字数が変わる入力(`ﾜｸﾁﾝ接種` など)で offset が元の本文の座標であること。
- [ ] **ログで状況を確認する**(`DefaultContentsParser` / `DefaultContentsAnalyzer` のログ)。
  - **日本語環境で `NO_PART_OF_SPEECH` の INFO 要約(「partOfSpeech 属性が取得できていない可能性」の文言)が出続けていないこと。** 出続けていれば `partOfSpeech` が取れていない(連結語は 0 件になる)。日本語と他言語の混在環境では、他言語の正常な出力でも INFO が出るので、`lang=` を見て切り分ける。
  - `STAGE_UNAVAILABLE` / `INVALID_OFFSET` / `TEXT_MISMATCH` の WARN(`degradedChunks={...}`)が出ていないこと。出る場合は原因別の件数と、アナライザ側の理由付き debug で切り分ける。
  - explain 失敗の WARN(`error=...`。空白なしで約 17,000 文字超のチャンクで出る)が許容範囲か。
- [ ] **受け入れ確認**: 評価時と同じデータで文書由来の suggest を再作成し、例語(`新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`)が、語そのもの、またはその語を前方に含む連結語として `/api/v2/suggest-words` で取得できること。`新型`、`コロナ` などの断片も残ること。語そのものの存在を確認する場合は、その語が連続列として単独で現れる文書を含むデータで行う(`新型コロナウイルス` の連続列では、連結語は `新型コロナウイルス` のみで `新型コロナ` 単独にはならない)。
- [ ] **性能(ゲート 2)**: explain の応答サイズ、1 チャンク当たりの処理時間、suggest 更新ジョブの総実行時間を、改善前後で測る。ローカルの参考値は 1,000 文字で約 309 KB・50〜70 ms、10,000 文字で約 3.16 MB・290〜370 ms(`attributes` 指定あり。通常の analyze の 5〜10 倍の処理時間)。許容できなければチャンク長の調整や `analyze` / `analyzeAndReading` / explain の統合を検討する。応答サイズ対策の代替案として、tokenizer と char_filter のみを指定した explain(応答が約 1/10)がある(素の HTTP でのみ確認。fesen-httpclient での組み立ては未検証)。
- [ ] **品質(ゲート 3)**: (a) 例語 6 語の取得率、(b) 代表的な検索プレフィックスでの上位候補の内容とノイズ率、(c) 候補総数の増加、(d) 更新処理時間を、改善前後で比較する。ナビゲーション文字列(`ホーム製品情報会社概要` のような名詞の羅列)が連結語として上位に来ていないか。問題があれば `fess.suggest.compound.max.tokens` を下げる、または連続列の文書内頻度で足切りする、を検討する。
- [ ] **反映・停止手順(ゲート 4)**: 4 章の全件反映・停止・ロールバックが実環境で行えること。
- [ ] NEologd 辞書の有無(設計書 7 章 要確認 4): 実環境で NEologd が効く場合は `新型コロナウイルス` など 1 語になる語が増え、連結の対象が変わる。上限の既定値(5 トークン / 20 文字)の妥当性もあわせて確認する。
- [ ] 他言語アナライザ(`contents_analyzer_<lang>`)の tokenizer 段に `partOfSpeech` が出ないこと(出ない場合は連結語なしで正常。INFO 要約が出る)。

## 6. 既知の制約・設計書との差異

既知の制約(いずれも断片は従来どおり出る)
- **空白のない約 17,000 文字超のチャンク**は、explain が `index.analyze.max_token_count`(10000)超過で失敗し、そのチャンクは連結語が出ない(通常の analyze は成功する)。WARN は 60 秒に 1 回に間引かれる。
- **超過列**(6 トークン以上、または表層 21 文字以上の連続列)と、**中間・末尾の部分語**(`新型コロナウイルス` に対する `コロナウイルス`)は連結語にならない(意図的な取りこぼし。設計書 4.4)。
- **非日本語アナライザでも explain を 1 回余計に呼ぶ**(結果は使えず無駄になる)。言語・アナライザ単位で「品詞なし」を覚えてスキップする最適化は未実装。
- **非日本語言語でも `NO_PART_OF_SPEECH` の INFO 要約が 1 分に 1 行出る**(INFO のため許容)。日本語と他言語の混在環境では、日本語側の不具合と区別しにくい(限定枠と累計が全言語共通。`lang=` で切り分ける)。記号だけのチャンク(トークン 0 件)も `NO_PART_OF_SPEECH` に数える。
- **縮退カウンタ**(`getCompoundChunkCount()`、`getCompoundWordCount()`、`getDegradedChunkCount(...)` など)は `DefaultContentsParser` の public getter だが、パーサは `SuggestIndexer` の private で、Fess から読む経路がない。観測はログ頼り。`SuggestIndexer` 側で更新完了時に info 要約を出す案は未実装(範囲外)。
- `enabled` は `false` 以外のすべての値で無効になる(typo で静かに止まる)。
- 60 秒間引きのテストはホストの時間に依存する(時計の差し替えは未実装)。
- 無効 offset のトークンの直後に有効なトークンが来る場合の `prev` 比較は、テスト未実施。
- `LogRateLimiter` は壁時計を使うため、時計の逆行があると間引きが長引く可能性がある(ログ用途のため許容)。
- 実環境の測定結果によっては、`enabled` の既定値(`true` は暫定)を見直す。

設計書(`task_docs/design_compound_word_suggest.md`)との差異(実装が正。設計書への反映が必要なら別途行う)
- 3.1 / 4.1: `partOfSpeech` なし(またはトークン 0 件)は `null` ではなく**トークン空の `TokenizerStageResult`**。`charfilters` の有無によらず返す(`charFilteredText` は取れなければ `""`)。`partOfSpeech` はあるのに `charfilters`/`filtered_text` が無い場合は `null`(キー誤りの検知)。
- 3.1: char_filter が複数ある場合は先頭ではなく**最後**の `filtered_text` を使う。
- 4.5: 縮退区分は `STAGE_UNAVAILABLE`(取得不可全般。内訳はアナライザの debug ログ)、`NO_PART_OF_SPEECH`、`INVALID_OFFSET`、`TEXT_MISMATCH`、`OVER_LIMIT`、`FAILURE`(例外。追加)。`OVER_LIMIT` は warn を出さない。`NO_PART_OF_SPEECH` は INFO 要約(60 秒に 1 回)。縮退の WARN はチャンクごとではなく `parseDocument` 内のフィールド単位で集約し、60 秒に 1 回(縮退の WARN、FAILURE の WARN、アナライザの `_analyze` 失敗の WARN、`NO_PART_OF_SPEECH` の INFO は別枠)。
- 3.4: `max.tokens` は 2 未満を不正値として既定にフォールバック。
- 新設クラス `LogRateLimiter`(設計書に無い)。
