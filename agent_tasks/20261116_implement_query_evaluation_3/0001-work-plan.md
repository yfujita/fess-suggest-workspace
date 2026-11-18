# 作業プラン: 20261116_implement_query_evaluation_3

(planner 作成。状態: ユーザー承認待ち)

## 1. 目的とゴール

`task_docs/design_fragment_suggest.md`(以下「設計書」)に沿って、fess-suggest の Java 側だけで、文書(クロール結果)由来と検索ログ由来の候補から、意味のない断片(促音長音のみ・記号のみ・1 文字の英数かな・形容詞-自立の活用形)を除く。評価書 §4 #3 の「なかっ」などが候補にならない状態にする。

完了条件は要件定義のとおり「実装が完了し、テストも完了している」。具体的には次を満たす。

- [ ] 設計書 3.1〜3.7 が fess-suggest に実装されている。`suggest_analyzer.json`(3 か所)、fess 本体、`FessConfig`、`fess_config.properties` は変更しない。
- [ ] 単体テスト(設計書 5.1 の全ケース)が追加され、通る。
- [ ] 統合テスト(設計書 5.2。`SuggestTestServer` の実 OpenSearch)が追加され、通る。
- [ ] 既存テスト(`DefaultContentsParserCompoundWordTest`、`CompoundWordIntegrationTest`、`DefaultContentsAnalyzerParseTokenizerStageTest`、`DefaultContentsParserTest`、`DefaultContentsParserEdgeCaseTest`、`SuggestAnalyzerTest` ほか)が回帰なく通る。設計書 3.8 の更新対象を反映している。
- [ ] `mvn formatter:format license:format` 済みで、`mvn test`(全体)と `mvn package` が成功する。
- [ ] code-reviewer / test-reviewer / task-reviewer の指摘が「なし」または Critical/Important 解消済み。
- [ ] ユーザーが Fess へ組み込めるよう、jar と引き渡しメモ(5.3 の確認手順、プロパティ、ロールバック手順)が用意されている。

「ユーザーが Fess に組み込んで確認」(要件の具体的にやること 4 つ目、設計書 5.3)はユーザー作業で、プランの実装完了条件には含めない。問題が出た場合はフェーズ 9 で追加の作業記録を起こす。

## 2. 確定事項・前提

### 設計書による確定事項

- 方式: fess-suggest の Java 側のみ。
  1. 文書経路の断片フィルタ(C1 促音長音のみ、C2 記号のみ、英数 1 文字、かな 1 文字)。英数 2 文字以下・単漢字は設定で有効にでき、既定は無効。
  2. 形容詞-自立で活用形が「基本形」以外のトークンの除外。tokenizer 段(explain)の結果を連結語と共用する。
  3. 連結語の両端にある促音長音のみのトークンのトリム(中間は残す)。
  4. 検索ログ経路(`isExcludeSearchword`)の C1/C2 除外。最小長・文字数の規則は入れない。
- 設定は System property の 4 つ。
  - `fess.suggest.fragment.filter.enabled`(既定 `true`)
  - `fess.suggest.fragment.inflection.enabled`(既定 `true`(暫定))
  - `fess.suggest.fragment.latin.short.enabled`(既定 `false`)
  - `fess.suggest.fragment.single.han.enabled`(既定 `false`)
- 真偽値は `Boolean.parseBoolean` で読む(`true` 以外は `false`)。`DefaultContentsParser` のコンストラクタで 1 回だけ読む。
- `analyzeText` / `analyzeTextByReading`(protected)のシグネチャと動作は変えない。`parseDocument` はチャンク対応つきの内部メソッドを使う。
- tokenizer 段の取得は `compound.enabled` または `inflection.enabled` が `true` のときに行い、両方 `false` のときだけ explain を呼ばない。空のチャンクでは呼ばない。
- 取得結果は「トークンあり / 取得不可(`null`) / 例外」の 3 通りに区別する。
  - 連結語側は従来どおり `STAGE_UNAVAILABLE` と `FAILURE` を別々に数え、警告も別枠で制限する。
  - 活用形側は、取得不可・例外・品詞なしのいずれでもそのチャンクは除外しない。例外で `parseDocument` を失敗させない。
  - 連結語名義の警告は `compound.enabled=true` のときだけ出す。
- 除外した断片の件数を理由別(C1/C2、英数、かな、単漢字、活用形)にカウンタとデバッグログで残す。活用形を判定できなかったチャンク数(取得不可・例外・品詞なし)も数える。カウンタの保持方法は `CompoundDegradation` に倣い、実装時に決めて作業記録に残す。
- 追加するフィールドは final の設定値とアトミックなカウンタに限る(並列ストリームで共有されるため)。
- git commit は行わない。作業記録と `STATUS.md` はメインエージェントのみが作成・更新する。
- 設計書でユーザー判断待ちの `ne`/`ku`(M2)は、設計書どおり既定=無効(`latin.short.enabled=false`)で進める。

### 現行コードとの照合結果(プラン作成時点。設計書の行番号とずれはない)

- `modules/fess-suggest` は独立 git リポジトリ。現在 main、HEAD `7db7938`。
- `DefaultContentsParser.java`:
  - `parseDocument`(`:346-402`)のトークンループは `:371-384`。
  - tokenizer 段の取得は `createCompoundItemsOfChunk`(`:456-497`)にあり、`forEachChunk`(`:779`)でチャンクを分割している。
  - `trimSymbolTokens`(`:664`)、`isSymbolToken`(`:677`)、`isExcludeSearchword`(`:860`)、`parseSearchWords`(`:271` 付近)。
  - 連結語の縮退カウンタは `degradedChunkCounts`(`:193`)、`LogRateLimiter` 3 つ、`warnIfDegraded`(`:522`)、`logNoPartOfSpeech`(`:504`)。
- `AnalyzerSettings.java`:
  - 外側クラスの定数 `PART_OF_SPEECH_ATTRIBUTE` / `READING_ATTRIBUTE` は `:115-117`。
  - `analyzeTokenizerStage` の `attributes(List.of(...))` は `:475`。
  - `toAnalyzeToken` の属性コピーは `:568`。`DefaultContentsAnalyzer` はその内部クラス。
- `SuggestAnalyzer.analyzeTokenizerStage` は default メソッドで `null` を返す(`SuggestAnalyzer.java:65`)。スタブ analyzer(テスト)は `null` を返す側になるため、`inflection.enabled=true` が既定の今回は、取得不可の経路が既存テストでも通る。
- 既存テストの `compound.enabled=false` 前提のもの(`test_degradation_disabled`)は、`inflection.enabled=false` の併記が必要(設計書 3.8)。

### 前提(プラン作成者が置いたもの)

- `mvn` の実行場所は `modules/fess-suggest`。整形は `mvn formatter:format license:format`。
- 既定で断片フィルタが有効になるため、既存テストで 1 文字語・記号語を期待しているものが見つかる可能性がある。その場合は「既存テストの期待値が仕様変更(設計書 2 章)に追随しているか」を個別に判断し、作業記録に理由を残す。無条件にテストを直さない。
- 設計書 3.8 のうち、連結語の設計書(`agent_tasks/20261113_implement_compound_word_suggest/task_docs/design_compound_word_suggest.md`)の更新は、別タスクの文書の変更になる。実装とは独立のため、フェーズ 8 の最後に置いた条件付きの工程とし、プラン承認時にユーザーに確認する(10 章)。

## 3. 影響範囲(`modules/fess-suggest/` 配下)

| ファイル | 内容 |
| --- | --- |
| `src/main/java/org/codelibs/fess/suggest/settings/AnalyzerSettings.java` | 定数 `INFLECTION_FORM_ATTRIBUTE = "inflectionForm"` を追加(`:115-117` の並び)。`analyzeTokenizerStage` の `attributes` 指定(`:475`)と `toAnalyzeToken` の属性コピー(`:568`)に足す |
| `src/main/java/org/codelibs/fess/suggest/analysis/TokenizerStageResult.java`、`SuggestAnalyzer.java` | Javadoc の「トークンが持つ属性」に `inflectionForm` を足すのみ(構造は変えない) |
| `src/main/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParser.java` | 設定の読み込み、断片フィルタ(`isNoiseFragment`)、活用形の判定、チャンク単位の tokenizer 段取得の共通化と最終段トークンのチャンク記録、連結語の端トリム拡張、`isExcludeSearchword` の C1/C2、カウンタとログ、Javadoc の更新 |
| `src/test/java/.../index/contents/DefaultContentsParserFragmentTest`(新規。名称は実装時に確定) | 設計書 5.1 の単体テスト(スタブ analyzer) |
| `src/test/java/.../index/contents/DefaultContentsParserCompoundWordTest.java` | 設計書 3.8 の既存テストの調整(`test_degradation_disabled` など) |
| `src/test/java/.../settings/DefaultContentsAnalyzerParseTokenizerStageTest.java` | `inflectionForm` が属性にコピーされるケースの追加 |
| `src/test/java/.../index/contents/FragmentIntegrationTest`(新規。名称は実装時に確定) | 設計書 5.2 の統合テスト。`CompoundWordIntegrationTest` と同じ構成 |

変更しないもの: `suggest_analyzer.json`(3 か所)、`modules/fess` 全体、`SuggestTestServer`(必要最小限の変更が要る場合のみフェーズ 1 で判断して記録)。

## 4. 実装フェーズ

担当: 実装は `code-implementer`。レビューは `code-reviewer` / `test-reviewer`、工程全体は `task-reviewer`。作業記録と `STATUS.md` の更新はメインエージェント。各フェーズ完了時に作業記録を残し `STATUS.md` を更新する。

### フェーズ 1: 事前検証(設計書 7 章 [要確認] のうちローカルで確かめられるもの)

担当: `code-implementer`(使い捨ての検証テストを `src/test` に作って実行し、結果を報告で返す。永続化する価値のあるものはフェーズ 2・5 のテストに取り込み、使い捨てファイルは削除する)。フェーズ開始時に `modules/fess-suggest` の `git status` と HEAD を記録する(レビューの比較基準)。

| 設計書 7 章 | 確認内容 | 方法 | 判定 |
| --- | --- | --- | --- |
| 1 | `SuggestTestServer` の `contents_analyzer_ja`(`reloadable_kuromoji_tokenizer` + `ExtensionPlugin`)で、tokenizer 段に `inflectionForm` が出るか。`_vanilla` 構成を `SuggestTestServer` が読むかの確認も含める | explain + `attributes(List.of(partOfSpeech, reading, inflectionForm))` の JSON を出力。`なかっ`、`大き`、`難し`、`大きい` | **必須**。出なければフェーズ 2 以降の統合テストが成立しない |
| 2 | `Response.toXContent` を通した JSON(`convertToMap`、`AnalyzerSettings.java:495`)で `inflectionForm` が落ちないか | 同上 | **必須** |
| 3 | 通常の `analyze` の最終段のトークンの offset が tokenizer 段と一致するか。`mapping_char` で文字数が変わる入力(半角カナの濁点付き、全角英数)を含む | `analyze` と `analyzeTokenizerStage` を同じ入力で呼び、(start, end, term) を比較 | **必須**。不一致なら対応付け方式を見直す |
| 4 | `attributes` に `inflectionForm` を足したときの応答サイズ・処理時間 | 長いチャンクで足す前後を比較 | 参考値(ローカルの目安。合否には使わない) |
| 6 | `analyzeText` を継承する外部コードの有無 | `modules/fess`、`modules/fess-suggest` を Grep(ワークスペース内に限る。外部の第三者コードは確認できないため、引き渡しメモに注意書きを残す) | 確認 |
| 7 | Fess が `parseDocument` に渡す lang の値の形式(`ja` か `ja_JP` か) | `modules/fess` の suggest 作成(`SuggestHelper` など)で、`langFieldName` が指す文書フィールドの値の元をコードで確認 | 確認(形式が `ja_JP` なら最小長の規則が効かない。結果を報告して判断を仰ぐ) |

あわせて確認する項目: 設計書 3.3 の `Character.UnicodeScript` による文字種判定(HIRAGANA / KATAKANA / HAN)が、半角カナ `ｶ` などのサロゲートペア・異体の扱いで想定どおりか。

**設計書 7 章のうちフェーズ 1 では確かめないもの**

| 設計書 7 章 | 扱い |
| --- | --- |
| 5(連結語が無効で活用形が有効なときの負荷) | 実環境でしか意味のある測定ができない。ユーザーが Fess 組み込み時に測る(引き渡しメモに手順を残す)。フェーズ 1 ではローカルの目安(項目 4 と同じ測定で、explain 1 回分の所要時間)を参考として記録するにとどめる |
| 8(評価ゲート。`inflection.enabled` の既定の確定) | 実装は設計書どおり既定 `true`(暫定)。Javadoc と引き渡しメモに「評価なしに本番既定として確定しない」と明記する。評価そのものはユーザー作業 |
| 9(1 文字英数だけを個別に切る設定の要否) | 実コーパス(ユーザーのはてなブックマーク 100 文書の suggest 索引)が必要。今回は設定を足さない。ユーザーの確認で必要と判断されたらフェーズ 9 の追加対応にする |

成果物: 検証結果(項目ごとの結果、応答 JSON の抜粋)。メインエージェントが `0002-pre-implementation-verification.md` に記録する。

ゲート: 項目 1〜3 のいずれかが不成立の場合、フェーズ 2 に進まず、結果と代替案を `NEEDS_USER_INPUT` としてユーザーに報告する。想定する代替案は次のとおり。
- 項目 1 が不成立(ローカル構成で活用形が取れない): 活用形の統合テストを「取れる環境でのみ実行」に限定し、応答解析の単体テスト(スタブの応答 Map)で代替して、実環境確認をユーザーに委ねる。
- 項目 3 が不成立: tokenizer 段との対応付けではなく、explain の最終段(`limit_token_count_filter`)から直接トークンを得る方式に変える(設計書の方針変更になるため、プラン更新とユーザー承認が必要)。

### フェーズ 2: 属性の追加と応答解析(設計書 3.1 の `AnalyzerSettings` 部分)

担当: `code-implementer`。依存: フェーズ 1 のゲート通過。

1. `AnalyzerSettings` に `INFLECTION_FORM_ATTRIBUTE` を追加し、`analyzeTokenizerStage` の `attributes` 指定と `toAnalyzeToken` の属性コピーに足す。`hasPartOfSpeech` の判定(品詞の有無で `TokenizerStageResult` を空にするかどうか)は変えない。
2. `TokenizerStageResult`、`SuggestAnalyzer` の Javadoc を更新する。
3. `DefaultContentsAnalyzerParseTokenizerStageTest` に `inflectionForm` がコピーされるケース、属性なしでも品詞の有無の判定が変わらないケースを追加する。
4. 統合テストの足場として、`analyzeTokenizerStage` の実応答から `inflectionForm` を確認するテスト(設計書 5.2 の 1 項目目)を追加する。

完了基準: 追加テストと、既存の `DefaultContentsAnalyzerParseTokenizerStageTest`、`SuggestAnalyzerTest`、`AnalyzerSettingsTest` が通る。整形済み。

### フェーズ 3: 断片フィルタ・連結語の端トリム・検索ログ経路(tokenizer 段に依存しない部分。設計書 3.2、3.3、3.5、3.6)

担当: `code-implementer`。依存: フェーズ 1(フェーズ 2 とは独立だが、直列で行う)。

1. 設定の読み込み(`fragment.filter.enabled`、`latin.short.enabled`、`single.han.enabled`。`inflection.enabled` はフェーズ 4)をコンストラクタに追加する。
2. `isNoiseFragment(word, lang)`(設計書 3.3 の擬似コードどおり。コードポイント単位、lang の適用範囲、`filter.enabled` が `false` のとき `latin.short` / `single.han` は効かない)。`parseDocument` のトークンループで `isBlank` の直後に `continue` で除外する。`readingTokens` の index は変えない。
3. `trimSymbolTokens` の判定を「記号のみ または 促音長音のみ(`filter.enabled` のとき)」に広げる。外した結果が 2 トークン未満なら連結語を作らない。上限と `contains` 照合は外した後の語に適用される(既存の順序のまま)。
4. `isExcludeSearchword` の先頭に C1/C2 の除外を追加する(`filter.enabled` のとき。`null` は従来の処理に渡す。空文字は除外。言語を問わない。アナライザを呼ぶ前に判定する)。
5. 理由別のカウンタ(C1/C2、英数、かな、単漢字)とデバッグログ。保持方法は `CompoundDegradation` に倣い、決めた内容を作業記録に残す。
6. 設計書 5.1 のうち、この範囲のケース(C1、C1 の境界、C2、英数 1 文字、lang との組み合わせ、英数 2 文字、かな 1 文字、単漢字、境界、読みの対応、設定、連結語の端トリム、端トリム: 残るもの、#2 の例語、検索ログ経路)の単体テストを追加する。System property を設定して `DefaultContentsParser` を new するテストは、後始末(元の値に戻す)を必ず行う。

完了基準: 追加した単体テストと、既存テスト(特に `DefaultContentsParserTest`、`DefaultContentsParserEdgeCaseTest`、`DefaultContentsParserCompoundWordTest`)が通る。既存テストが落ちた場合は、前提の項に従って個別に判断し作業記録に残す。整形済み。

### フェーズ 4: 活用形の除外と tokenizer 段の共用(設計書 3.4、3.7、3.8)

担当: `code-implementer`。依存: フェーズ 2・3。本計画で最も変更が大きいため、単独のフェーズとして切る。

1. `inflection.enabled` の読み込みを追加する。
2. チャンク単位の tokenizer 段取得を `createCompoundItemsOfChunk` から切り出して共通化する。結果は「トークンあり / `null` / 例外」の 3 通りで返す。空のチャンクでは呼ばない。
3. `analyzeText` の内部実装を、各チャンクを連結する直前のリスト長を記録できる形にし、最終段トークンがどのチャンク由来かを持てるようにする。protected の `analyzeText` / `analyzeTextByReading` のシグネチャと動作は変えない。`parseDocument` はチャンク記録つきの内部メソッドを使う(`analyzeText` を差し替える外部コードへの影響は、引き渡しメモに注意書きを残す)。
4. `isInflectedAdjective` と、チャンクごとの (start, end) → term の対応表による判定(設計書 3.4 の擬似コード。小文字化後に term が一致しなければ除外しない)。
5. tokenizer 段の取得条件を「`compound.enabled` または `inflection.enabled`」にする。連結語側の動作(`STAGE_UNAVAILABLE` / `FAILURE` の別々のカウントと別枠の警告制限)は変えない。連結語名義の警告(`warnIfDegraded`、`logNoPartOfSpeech`)は `compound.enabled=true` のときだけ出す。活用形側の取得不可はデバッグログと件数にとどめる。
6. 活用形の除外件数と、判定できなかったチャンク数(取得不可・例外・品詞なし)のカウンタとデバッグログ。
7. 設計書 3.8 の反映: `DefaultContentsParser` の Javadoc(`compound.enabled=false` が「追加の分析リクエストを止める」という説明を「活用形の除外も無効のとき」に直す)。既存テスト `test_degradation_disabled` に `inflection.enabled=false` を併記する。`test_chunk_blankTextIsNotAnalyzed` が活用形有効でも成り立つようにする。`test_degradation_failureWarningHasItsOwnTimeLimit` などはそのまま通ること。
8. 設計書 5.1 のうち、この範囲のケース(活用形、基本形、活用形の周辺、チャンクをまたぐ、縮退、連結語の縮退の区別、読みの対応、設定、tokenizer 段の取得回数)の単体テストを追加する。

完了基準: 追加した単体テストと、`DefaultContentsParserCompoundWordTest` を含む既存テストが通る。`compound=true/inflection=true` で 1 チャンク 1 回、`compound=false/inflection=true` で 1 回、両方 `false` と空文字で 0 回であることがテストで確認されている。整形済み。

### フェーズ 5: 統合テスト(設計書 5.2)

担当: `code-implementer`。依存: フェーズ 2〜4。

`CompoundWordIntegrationTest` と同じ構成で、`SuggestTestServer` の実 OpenSearch を使う。

1. `analyzeTokenizerStage` の応答から `inflectionForm` が取れる(`なかっ`、`大き`、`難し`、`大きい`)。クライアントの JSON 再出力で属性が落ちない。
2. 最終段(通常の `analyze`)の offset が tokenizer 段の offset と一致する。`mapping_char` で文字数が変わる入力でも一致する。
3. 上の語を含む文書を `parseDocument` に通すと、`なかっ`、`大き`、`難し` が候補にならず、`大きい` が残る。複数チャンク(空白区切りで 1000 文字超)でも同様。
4. 例語(`新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`、`togetter.com`、`神奈川県`)の連結語が従来どおり生成される(退行なし。ローカルの neologd 構成で分割が `fess_japanese_normal` と異なる語は、フェーズ 1 の実測に合わせた期待値にし、差異を作業記録に残す)。
5. 促音長音のみ・記号のみのトークンを含む文書で、C1/C2 の語が候補にならず、連結語の端の `ー` がトリムされる。

完了基準: 統合テストが通る。実応答でしか検知できない不備(属性が落ちる、offset のずれ)を実際に検知できる内容になっていること。

### フェーズ 6: 全体回帰とビルド確認

担当: `code-implementer`。依存: フェーズ 5。

1. `mvn formatter:format license:format` を実行する。
2. `modules/fess-suggest` の全テスト(`mvn test`)を実行する。落ちたものは原因を切り分け、本変更に起因するものだけ対応する(それ以外は未対応事項として記録)。
3. `mvn package` で jar を生成し、生成物のパスを作業記録に残す。

完了基準: `mvn test` と `mvn package` が成功している。

### フェーズ 7: レビュー(6 章)

7 章のとおり。

### フェーズ 8: 引き渡しメモ、タスクレビュー、(条件付き)連結語設計書の更新

1. 引き渡しメモ(作業記録として作成。メインエージェント)。内容: 変更要約、4 つの System property と `jvm.suggest.options`(`fess_config.properties:101`)への渡し方、反映・停止・ロールバック手順(設計書 4.1。`fragment.filter.enabled=false` と `fragment.inflection.enabled=false`)、設計書 5.3 の確認手順(8 章)、ユーザー向け測定チェックリスト(設計書 7 章 5・8・9)、`inflection.enabled` の既定 `true` が暫定であること、`analyzeText` を継承する外部コードへの注意、`ne`/`ku` は既定では解消せず `latin.short.enabled=true` が必要なこと。
2. タスクレビュー(9 章)。
3. 条件付き: 設計書 3.8 の連結語の設計書の更新(3.4 と 4.2 の停止手順、7 章のベースライン測定、2 章 L33 の「断片は残す」)。別タスクの task_docs の変更になるため、プラン承認時にユーザーが可とした場合のみ実施する。担当は `document-writer`、レビューは `document-reviewer`(文書のみの変更)。

### フェーズ 9: ユーザーによる Fess 組み込みと確認、問題対応(ユーザー作業)

- ユーザーが jar を Fess に組み込み、評価時と同じデータで suggest を再作成して確認する(設計書 5.3、8 章)。
- 問題があれば追加の作業記録を起こして対応する。軽微なものはプランを作り直さない。設計判断が変わるもの(1 文字英数を個別に切る設定の追加、`latin.short` / `single.han` の既定の変更、`inflection.enabled` の既定の変更など)はプランを更新する作業記録を残し、承認を得る。修正後は規模に応じて再レビューする。

## 5. テスト方針

- 単体(OpenSearch なし): スタブ `SuggestAnalyzer`(`DefaultContentsParserCompoundWordTest` の `StubAnalyzer` と同様に、tokenizer 段と最終段のトークンを固定で返す)で、設計書 5.1 の全ケース(フェーズ 3・4)と、`DefaultContentsAnalyzerParseTokenizerStageTest` の追加(フェーズ 2)。
- 統合(`SuggestTestServer`): 設計書 5.2 の全項目(フェーズ 2 の 4 とフェーズ 5)。応答の取り扱い(属性が落ちる、offset のずれ)はスタブでは検知できないため、合格条件にする。
- 回帰: `modules/fess-suggest` の全テスト(フェーズ 6)。特に `DefaultContentsParserTest`、`DefaultContentsParserEdgeCaseTest`、`DefaultContentsParserCompoundWordTest`、`CompoundWordIntegrationTest`、`SuggestAnalyzerTest`、`AnalyzerSettingsTest`、`SuggestIndexerTest`、`SuggesterTest`。
- 手動(実環境): ユーザーが設計書 5.3 に従い、フェーズ 9 で実施する。

## 6. リスクと対策

| リスク | 対策 |
| --- | --- |
| ローカルの `SuggestTestServer` 構成で `inflectionForm` が取れず、統合テストが成立しない | フェーズ 1 の最優先項目。不成立なら `NEEDS_USER_INPUT` でユーザーに代替案を提示する |
| 最終段と tokenizer 段の offset が一致しない(`mapping_char` で文字数が変わる入力など) | フェーズ 1 項目 3 と、フェーズ 5 の統合テストで確認。不成立なら方式の見直し(プラン更新と承認) |
| `inflectionForm` の値の表記(`基本形`)が辞書やトークナイザで変わると判定が変わる | 統合テストで検知する(設計書 7 章リスク) |
| チャンク記録つきの内部メソッドの導入で、既存の `analyzeText` / `analyzeTextByReading` や連結語の縮退の動作が変わる | シグネチャと動作を維持し、既存テストを回帰として通す。連結語の縮退の区別(`STAGE_UNAVAILABLE` / `FAILURE`)をテストで確認する |
| 断片フィルタが既定で有効になり、既存テストが 1 文字語などで落ちる | フェーズ 3 で個別に判断して作業記録に残す(前提の項) |
| `compound=false/inflection=true` の構成で explain の負荷が残る | `inflection.enabled=false` で止められる。負荷は実環境でユーザーが測る(設計書 7 章 5) |
| 1 文字英数 25 語(`x` など)が既定で消える、英数 2 文字(`ai` など)・単漢字の扱い、`ne`/`ku` が既定では解消しない | 設計書どおり(既定で `latin.short` / `single.han` は無効)。ユーザー確認の結果次第でフェーズ 9 で対応する |
| 並列ストリームでのカウンタ・フィールドの競合 | final の設定値とアトミックなカウンタに限る。code-reviewer の観点に含める |
| lang が `ja_JP` 形式で入ると最小長の規則が日本語文書に効かない | フェーズ 1 項目 7 で確認。形式が合わなければ報告する |
| ロールバック | `fragment.filter.enabled=false` と `fragment.inflection.enabled=false` で従来動作に戻る。次の suggest 作成で反映される(設計書 4.1。コードの戻しは不要) |

## 7. レビューフェーズ

`code-reviewer` と `test-reviewer` を**両方**実施する(独立しているため並列実行)。

- タイミング: フェーズ 6 完了後、フェーズ 1〜6 の作業記録と `STATUS.md` の更新後。
- 対象(`modules/fess-suggest/` 配下。実装は未コミットのため、作業ツリー差分と untracked ファイルが対象):
  - 本体: `AnalyzerSettings.java`、`TokenizerStageResult.java`、`SuggestAnalyzer.java`、`DefaultContentsParser.java`。
  - テスト: 追加・変更した全ファイル(新規の単体テスト・統合テスト、`DefaultContentsParserCompoundWordTest`、`DefaultContentsAnalyzerParseTokenizerStageTest` ほか)。
- 比較基準: `modules/fess-suggest` の実装開始時点の HEAD `7db7938`(フェーズ 1 開始時に `git status` を記録して確認する)。ワークスペース側の `.claude/audit/events.jsonl`、`.obsidian/workspace.json` などは除外する。
- 渡す文脈: `agent_tasks/20261116_implement_query_evaluation_3/` の `0000-requirements-definition.md`、`task_docs/design_fragment_suggest.md`、本プラン、フェーズ 1〜6 の作業記録。
- 観点:
  - code-reviewer: 設計書との整合(3.3 の擬似コード、lang の適用範囲、3.4 のチャンク対応と offset / 小文字化の照合、3 通りの取得結果の区別、連結語名義の警告の条件、3.5 の端トリムの順序、3.6 の `null` / 空文字の扱い)、`analyzeText` / `analyzeTextByReading` の後方互換、例外で `parseDocument` が失敗しないこと、読み(`readingTokens`)の index のずれ、設定値の読み込み、カウンタのスレッド安全性、ログ(本文を出さない)。
  - test-reviewer: 設計書 5.1 / 5.2 の全ケースの網羅、スタブの限界を統合テストが担保しているか、期待値が neologd 依存で脆くないか、System property の後始末、既存テストの修正が妥当か(期待値の無条件な書き換えでないか)。
- 指摘への対応: Critical / Important は修正して再レビューする。Suggestion / Nitpick は対応可否を理由とともに作業記録に残す。「指摘なし」または Critical / Important 解消済みになるまで、レビューフェーズを完了としない。
- 本体コードの変更を含むため、レビューは省略しない。

## 8. 設計書 5.3(ユーザーの Fess 組み込み時の確認手順。引き渡しメモに転記する)

1. 評価時と同じデータで suggest を再作成し、`/api/v2/suggest-words` と suggest 索引で確認する。比較は同一コーパス・同一の分類スクリプトで行い、できれば取得割合を一時的に 100% にする(`suggest.update.contents.limit.num.percentage`)。
2. `なかっ`、`よかっ`、`大き`、`難し`、`ッ`、`ッッ`、`ー`、`ーー` が候補にならない。`ne`、`ku` は既定では残り、`latin.short.enabled=true` で確認する。
3. #2 の例語が従来どおり取得でき、読み補完(`にほん`→`日本`)が退行しない。
4. 基本形(`ない`、`いい`、`すごい`)が残る。
5. 基準値との比較(C1/C2 が 0、C3/C4 が 0(名詞用法のある約 12 語を除く)、C5 199→174、C6 821→777、断片の総数 11,825→約 11,380。促音長音を含む連結語 16 件のうち 15 件が消えるか短くなる)。
6. `fragment.*` の各プロパティを切り替えた再作成で、期待どおりに増減する。
7. あわせて、設計書 7 章 5(連結語無効時の explain の負荷)、8(評価ゲート)、9(1 文字英数の個別設定の要否)を確認する。

## 9. タスクレビューフェーズ

**実施する**(省略しない)。理由: 実装フェーズが複数あり複数セッションにまたがる見込みで、設計書との整合(7 章の確認事項の扱い、3.8 の更新対象の反映、プロパティの既定値の暫定扱い)が実装・記録・引き渡しに漏れなく反映されているかを工程全体で確認する価値があるため。

- 実行条件: フェーズ 7(レビュー)が完了し、フェーズ 1〜6、8 の 1 の作業記録と `STATUS.md` が揃っていること。
- 渡す文脈: タスク名 `20261116_implement_query_evaluation_3`(`agent_tasks/20261116_implement_query_evaluation_3/` 配下すべて)。
- 観点: 要件定義・プラン・作業記録・実際の変更の突き合わせ。コード・テスト単体は前段のレビューと重複させない。
- 指摘への対応: Critical / Important は該当工程に差し戻して修正し、再度 `task-reviewer` でレビューする。Suggestion / Nitpick は対応可否を判断して作業記録に残す。「指摘なし」または Critical / Important 解消済みになるまで、タスクの完了(ユーザーへの引き渡し)を報告しない。
- フェーズ 9 で設計判断が変わった場合は、再実施を判断する。

## 10. 未解決事項

- **承認時に確認(1)**: 設計書 3.8 の「連結語の設計書の更新」(フェーズ 8 の 3)を今回のタスクで行ってよいか。別タスク(`20261113_implement_compound_word_suggest`)の task_docs の変更になる。行わない場合は、更新が必要な箇所を引き渡しメモに列挙するにとどめる。
- 設計書 7 章 5・8・9 はユーザーの実環境での確認に委ねる(8 章)。
- フェーズ 1 の結果次第で、取り出し方や対応付けの前提の見直しが必要になる可能性がある(6 章)。
- `analyzeText` を継承する外部コードの有無は、ワークスペース内でしか確認できない。外部は引き渡しメモで注意喚起にとどめる。
- 設計書 7 章 9(1 文字英数だけを個別に切る設定)は、今回は実装しない。ユーザーの確認結果によってフェーズ 9 で判断する。

## 判断理由

- フェーズ分割: 設計書の変更を「tokenizer 段に依存しない部分(フェーズ 3)」と「活用形・チャンク共通化(フェーズ 4)」に分けた。フェーズ 4 が既存の連結語の縮退処理とテストに触れるため、リスクの大きい部分を独立して検証できるようにした。連結語の実装タスクと同様に、実装前の事前検証を最初に置き、成立しない場合は停止してユーザーに報告するゲートにした。
- 質問を返さなかった理由: 設計書は方式・設定名・既定値・テスト方針・確認手順まで確定しており、要件と矛盾する点もない。残る分岐はプラン承認時の確認またはフェーズ 9 の判断で足りる。
- 連結語設計書の更新を条件付きにした理由: 別タスクの task_docs を書き換えるため。
