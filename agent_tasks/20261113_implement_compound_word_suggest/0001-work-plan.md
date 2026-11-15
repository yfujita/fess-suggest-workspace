# 作業プラン: 20261113_implement_compound_word_suggest

(planner 作成。状態: ユーザー承認待ち)

## 1. 目的とゴール

`task_docs/design_compound_word_suggest.md`(以下「設計書」)に沿って、fess-suggest の文書由来の候補生成に「隣接する名詞の連結語」を加える。
評価書 §4 #2 の例語(`新型コロナ`、`大統領選`、`高市早苗`、`石破首相`、`ワクチン接種`、`円安`)が、語そのもの、またはその語を前方に含む連結語として候補になる。断片の候補は現状どおり残す。

受け入れ基準(実装タスクの範囲)

- [ ] 設計書 3.1〜3.4 の変更が fess-suggest に実装されている。`suggest_analyzer.json` は変更しない。fess 本体は変更しない。
- [ ] 単体テスト(設計書 5.1 の全ケース)が追加され、通る。
- [ ] 統合テスト(設計書 5.2。`SuggestTestServer` の実 OpenSearch)が追加され、通る。
  - 実際の explain 応答から連結語が実際に生成されること(全件縮退していないこと)。
  - 出力した連結語がすべて char_filter 適用後の本文の部分文字列であること。
- [ ] 既存テスト(`DefaultContentsParserTest`、`DefaultContentsParserEdgeCaseTest`、`SuggestAnalyzerTest` ほか)が回帰なく通る。
- [ ] 縮退の観測(設計書 4.5。件数と原因別内訳、警告ログ)が実装されている。
- [ ] code-reviewer / test-reviewer の指摘が「なし」または Critical/Important 解消済み。task-reviewer も同様。
- [ ] ユーザーが Fess へ組み込めるよう、jar のビルドと引き渡しメモが用意されている(組み込みと動作確認はユーザーが行う)。

完了条件のうち「ユーザーが Fess に組み込んで動作確認し、問題なし」はプラン外のユーザー作業。問題が出た場合は追加の作業記録を起こして対応する(フェーズ7)。

## 2. 確定事項・前提

確定事項(設計書による)

- 方式: `parseDocument` で、explain の tokenizer 段(品詞・読み・offset)から、対象品詞の隣接最大連続列(2 トークン以上)を連結して追加候補にする。断片は残す。
- 変更箇所は fess-suggest のみ。
  - `analysis/SuggestAnalyzer.java`: default メソッド追加。
  - `settings/AnalyzerSettings.java` の `DefaultContentsAnalyzer`: 実装。
  - `index/contents/DefaultContentsParser.java`: 連結語の抽出と `SuggestItem` 生成。
  - 新設の小クラス(tokenizer 段の結果を持つ `TokenizerStageResult`)。置き場所は `analysis/` を想定。
- 設定は System property の 3 つ。
  - `fess.suggest.compound.enabled`(既定 `true`(暫定))
  - `fess.suggest.compound.max.tokens`(既定 5)
  - `fess.suggest.compound.max.length`(既定 20。30 を超える値は 30 に丸める)
- explain の取り出し方: `builder.request().explain(true)` と `attributes(List.of("partOfSpeech","reading"))`。応答は `Response.toXContent` で JSON 化して `detail.tokenizer.tokens[]` と `detail.charfilters[].filtered_text`(単数形)を読む。

前提(プラン作成者の確認事項)

- 設計書の行番号は現行コードと照合して一致した(`DefaultContentsParser.java` `:74-76`/`:154-211`/`:173-176`/`:185-195`/`:202`/`:261`/`:291-310`、`AnalyzerSettings.java` `:369`/`:378`/`:388`、`SuggestItem.java:446`、`SuggestUtil.java:93`/`:266`、`IndexingOperations.java:78`)。
- `SuggestAnalyzer` の実装は本体の `DefaultContentsAnalyzer` と、テスト内の `SuggestAnalyzerTest.TestSuggestAnalyzer` のみ。default メソッドなので後者は変更不要。`modules/fess` 側に参照なし。
- `DefaultContentsParserTest` は `protected` メソッド `analyzeText` / `analyzeTextByReading` を直接呼んでいる。シグネチャは維持する。
- 設計書の `javap` 確認(`AnalyzeAction$Request.attributes(List)`、`explain(boolean)`、`HttpAnalyzeAction$Fields.FILTERED_TEXT`)は未再確認。フェーズ1で実コードにより再確認する。
- ローカルの `SuggestTestServer` が使う `suggest_analyzer.json` は `kuromoji_neologd_normal`(`modules/fess-suggest/src/main/resources/suggest_indices/suggest_analyzer.json:10,38`)。Fess 本体は `fess_japanese_normal` で分割結果が異なりうる。統合テストの期待値はフェーズ1で実測した分割結果に合わせる。
- `mvn` の実行場所は `modules/fess-suggest`。整形は `mvn formatter:format license:format`。
- `git commit` は行わない。
- 作業記録と `STATUS.md` はメインエージェントのみが作成・更新する。

### 設計書 7 章「本番有効化ゲート」の扱い

- **範囲外(ユーザーが Fess 組み込み時に実施)**: ゲート 2〜4(実環境の性能、品質比較、全件反映・停止手順の確認)。
- **範囲内(ローカル)**:
  - ゲート 1 のローカル版(実 OpenSearch の explain 応答からの生成確認)を統合テストとして必須実施。
  - 縮退・生成件数の観測(4.5)を実装。
  - フェーズ1でローカルで測れる範囲の応答サイズ・処理時間の目安を記録(参考値。ゲート合否には使わない)。
- 引き渡し時に、ユーザー向け測定チェックリストを作業記録に残す。
- 既定値 `enabled=true`(暫定)は設計書どおり実装し、「評価なしに本番既定として確定しない」旨を JavaDoc と引き渡しメモに明記する。

## 3. 影響範囲(`modules/fess-suggest/` 配下)

| ファイル | 内容 |
| --- | --- |
| `src/main/java/org/codelibs/fess/suggest/analysis/SuggestAnalyzer.java` | `default TokenizerStageResult analyzeTokenizerStage(String text, String field, String lang)`(`null` を返す)を追加 |
| `src/main/java/org/codelibs/fess/suggest/analysis/TokenizerStageResult.java`(新規) | tokenizer 段の `AnalyzeToken` リストと char_filter 適用後の本文を持つ値クラス |
| `src/main/java/org/codelibs/fess/suggest/settings/AnalyzerSettings.java`(`:369` 以降) | `DefaultContentsAnalyzer.analyzeTokenizerStage` を実装。`analyze`(`:388`)と同じ文字数上限チェックとアナライザ名解決を使う |
| `src/main/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParser.java` | 設定値の読み込み、チャンク分割の共通化または explain 用メソッド新設、連結語の抽出と `SuggestItem` 生成、縮退カウンタ |
| `src/test/java/.../index/contents/` 新規(例: `DefaultContentsParserCompoundWordTest`) | 単体テスト(スタブ analyzer。設計書 5.1) |
| `src/test/java/.../settings/AnalyzerSettingsTest.java` または新規 | `analyzeTokenizerStage` の統合テスト(設計書 5.2) |
| `src/test/java/.../index/contents/` 新規(例: `CompoundWordIntegrationTest`) | `parseDocument` の実 OpenSearch 統合テスト |

変更しないもの: `suggest_analyzer.json`(2 か所)、`modules/fess` 全体、`FessConfig`、`fess_config.properties`、`SuggestTestServer`(必要最小限の変更が要る場合のみフェーズ1で判断して記録)。

## 4. 実装フェーズ

担当: 実装は `code-implementer`、レビューは `code-reviewer` / `test-reviewer`、工程全体は `task-reviewer`。作業記録・`STATUS.md` はメインエージェント。各フェーズ完了時に作業記録を残し `STATUS.md` を更新する。

### フェーズ1: 事前検証(設計書 [要確認] のうちコードで確認できるもの)

担当: `code-implementer`(使い捨ての検証テストを `src/test` に作成して実行。結果は報告で返す。永続化する価値のあるものはフェーズ2・4のテストに取り込む)。

`SuggestTestServer`(`ExtensionPlugin`)で explain 付き呼び出しを行い、応答を JSON で出力する。

| # | 確認内容 | 判定 |
| --- | --- | --- |
| V1 | `contents_analyzer_ja`(および `contents_analyzer`)で `新型コロナ` 等を explain したとき、`detail.tokenizer.tokens[]` に `partOfSpeech` と `reading` が出るか | 必須。出なければ停止 |
| V2 | `explain(true)` と `attributes(List)` がコンパイル・実行できるか。`attributes` 指定で応答が縮小するか。`Response.toXContent` の JSON 化で属性が落ちないか | 必須 |
| V3 | `detail.charfilters[].filtered_text`(単数形、文字列の配列)が取れるか | 必須 |
| V4 | `mapping_char` で文字数が変わる入力(`ﾜｸﾁﾝ接種`、`ＡＩ活用`)で、tokenizer 段の offset が元の本文の座標か | 必須 |
| V5 | 例語 6 語と `神奈川県` の分割結果と品詞の実測(neologd 構成) | 必須 |
| V6 | 読みの取れないトークン(`ChatGPT` 等)で `reading` がどう出るか | 必須 |
| V7 | `contents_analyzer_en` など非日本語アナライザの tokenizer 段に `partOfSpeech` が出ないこと | 確認 |
| V8 | 長いチャンク(空白なし 50,000 文字程度)の explain 応答サイズ・所要時間(`attributes` あり/なし)、`index.analyze.max_token_count` 超過エラーの有無 | 参考値 |
| V9 | `SuggestTestServer` が `_vanilla` 構成を読むか。読まなければ対象外 | 確認 |

あわせて `AnalyzeToken` のコンストラクタが単体テストのスタブで使えるかを確認する。

成果物: 検証結果(項目ごとの結果、応答 JSON の抜粋、V5 の分割結果)→ メインエージェントが `0002-pre-implementation-verification.md` に記録。

ゲート: V1〜V4 のいずれかが不成立ならフェーズ2に進まず、結果と代替案(取り出し方の変更、テスト用アナライザ構成の変更、連結ロジック前提の見直し)を `NEEDS_USER_INPUT` としてユーザーに報告する。V8 が極端に悪い場合も同様。

### フェーズ2: `SuggestAnalyzer` 拡張と `DefaultContentsAnalyzer.analyzeTokenizerStage`

担当: `code-implementer`。依存: フェーズ1が通ること。

1. `TokenizerStageResult` を新設。
2. `SuggestAnalyzer` に default メソッド `analyzeTokenizerStage`(`null` を返す)を追加。
3. `DefaultContentsAnalyzer` に実装(文字数上限チェックは `analyze` と同じ。アナライザ名は `getContentsAnalyzerName`。`explain(true)` + `attributes`。`detail`/`tokenizer` なし、`partOfSpeech` なし、`filtered_text` なしは `null`)。
4. 統合テスト: 実応答から `partOfSpeech` / `reading` / offset / `filtered_text` が取れる。`filtered_text` の内容(正規化後の本文)も検証。

完了基準: 追加した統合テスト、`SuggestAnalyzerTest`、`AnalyzerSettingsTest` が通る。整形済み。作業記録にフェーズ1との差分を記載。

### フェーズ3: `DefaultContentsParser` の連結ロジック

担当: `code-implementer`。依存: フェーズ2。

1. 設定の読み込みをコンストラクタに追加(`max.length` は 30 に丸める。不正値は `Integer.getInteger` の既定値フォールバックに揃える)。
2. チャンク分割の共通化(`analyzeTextInternal`)。`analyzeText` / `analyzeTextByReading`(`protected`)のシグネチャ・挙動は維持。連結は同じチャンク単位。
3. 連結アルゴリズム(設計書 3.2 の擬似コード、対象品詞 12 種、上限 5 トークン・20 文字、offset 妥当性検証、`contains` 照合)。**offset を `filtered_text` に直接適用する処理は書かない**。連結ロジックはスタブで単体テストしやすい形に切り出す(クラス追加は最小限)。
4. `SuggestItem` の組み立て(設計書 3.3)。
5. 縮退の観測(設計書 4.5)。連結語生成チャンク数・総数、縮退チャンク数を原因別(`null`、`partOfSpeech` なし、本文なし、offset 不正、照合失敗、上限超過)に保持し、警告ログに原因を含める。保持方法は実装時に決めて作業記録に残す。
6. `enabled=false` では連結生成と追加 explain 呼び出しを行わない。
7. 失敗時は例外を投げず、`processBuffer` と同様に警告ログで続行。

完了基準: 設計書 5.1 の全ケースの単体テストが通る。既存テストが通る(断片が従来どおり)。整形済み。

### フェーズ4: 統合テストと全体回帰

担当: `code-implementer`。依存: フェーズ2・3。

1. `parseDocument` を実 `DefaultContentsAnalyzer` で通すテスト(設計書 5.2)。V5 の実測に基づき連結語が実際に生成されること、全件縮退していないこと、複数文書(全角英数・半角カナ・空白・句読点)で出力した連結語がすべて char_filter 適用後の本文の部分文字列であること、断片が残ること、`enabled=false` で連結語が出ないこと。neologd との差異は期待値を実測に合わせ作業記録に残す。
2. 空白なし長文で例外なく処理されること。
3. `modules/fess-suggest` の全テスト(`mvn test`)。
4. `mvn package` で jar 生成。生成物パスを作業記録に残す。

### フェーズ5: レビュー(6 参照)

### フェーズ6: 引き渡しメモとタスクレビュー

- 引き渡しメモ: 変更要約、3 つの System property と `jvm.suggest.options` への渡し方、反映・停止・ロールバック手順(設計書 4.2)、縮退・生成件数の確認方法(4.5)、ユーザー向け測定チェックリスト(ベースラインは `enabled=false` で先に取る)、既定値 `true` が暫定であること。
- 7 のタスクレビューを実施。

### フェーズ7: ユーザーによる Fess 組み込み・動作確認と問題対応

- ユーザーが jar を組み込み、評価時と同じデータで確認(設計書 5.2 手動)。
- 問題があれば追加の作業記録を起こして対応。軽微なものはプラン再作成なし。設計判断が変わるもの(部分列生成、ナビゲーション文字列抑制など)はプラン更新の作業記録と承認。修正後は規模に応じて再レビュー。

## 5. テスト方針

- 単体(OpenSearch なし): スタブ `SuggestAnalyzer` で設計書 5.1 の全ケース。設定値ケースは System property 設定後に `DefaultContentsParser` を new し、テスト後に必ず戻す。
- 統合(`SuggestTestServer`): 実応答を使うテストを合格条件にする(`filtered_text` のキー誤りのような応答解析の不備はスタブでは検知できないため)。「実際に連結語が生成される」「連結語が本文の部分文字列」の 2 点。
- 回帰: `modules/fess-suggest` 全テスト。特に `DefaultContentsParserTest`、`DefaultContentsParserEdgeCaseTest`、`SuggestAnalyzerTest`、`AnalyzerSettingsTest`、`SuggestIndexerTest`、`SuggesterTest`。
- 手動: ユーザーによる実環境確認(フェーズ7)。

## 6. レビューフェーズ

`code-reviewer` と `test-reviewer` を**両方**実施(並列可)。

- タイミング: フェーズ4完了・作業記録と `STATUS.md` 更新後。
- 対象(`modules/fess-suggest/` 配下): 本体 `SuggestAnalyzer.java`、`TokenizerStageResult.java`、`AnalyzerSettings.java`、`DefaultContentsParser.java`。テスト: 追加・変更した全ファイル。
- 比較基準: 実装開始時点のコミット `5be5f76`。実装は未コミットのため作業ツリー差分と untracked ファイルが対象。`.claude/audit/events.jsonl`、`.obsidian/workspace.json` などは除外。フェーズ1開始時に `git status` を記録する。
- 渡す文脈: `0000-requirements-definition.md`、本プラン、設計書、フェーズ1〜4の作業記録。
- 観点
  - code-reviewer: 設計書との整合(アルゴリズム、品詞 12 種、上限、offset 検証、`contains` 照合、座標系の非混同)、縮退時に例外を投げないこと、default 追加の後方互換、設定値の丸めと不正値、カウンタのスレッド安全性、ログ、断片の既存挙動。
  - test-reviewer: 5.1 全ケース網羅、統合テストでスタブの限界を担保できているか、期待値が neologd 依存で脆くないか、System property の後始末。
- 指摘対応: Critical/Important は修正して再レビュー。Suggestion/Nitpick は対応可否を理由とともに記録。

## 7. タスクレビューフェーズ

**実施する**。実装フェーズが複数あり複数セッションにまたがる見込みで、「縮退の可視化」「ゲートの扱い」が実装・記録・引き渡しに漏れなく反映されているか確認する価値があるため。

- 実行条件: フェーズ5完了、フェーズ1〜6の作業記録と `STATUS.md` が揃っていること。
- 観点: 要件定義・プラン・作業記録・実際の変更の突き合わせ(コード・テスト単体は重複させない)。
- Critical/Important は該当工程に差し戻して修正後、再度 task-reviewer。解消するまでユーザーへの引き渡しを報告しない。
- フェーズ7で設計判断が変わった場合は再実施を判断する。

## 8. リスクと対策

| リスク | 対策 |
| --- | --- |
| explain 応答に `partOfSpeech` / `reading` が出ない、または取り出しが設計どおりにできない | フェーズ1で最優先に検証。不成立ならフェーズ2に進まずユーザーに報告 |
| `filtered_text` のキー誤りで全チャンクが縮退し気づかない | 統合テストで「実際に生成される」を合格条件に。縮退カウンタで観測 |
| ローカル(neologd)と実環境(`fess_japanese_normal`)で分割が異なる | V5 で実測し期待値を合わせる。差異を記録。実環境確認はユーザー |
| explain の応答増大・処理時間増加 | `enabled=false` で停止可能。V8 で目安。実環境測定はユーザー |
| ナビゲーション文字列の連結語が上位に来る | 初版は対策せず、ユーザー確認で量・順位を見て判断 |
| 既存テストの回帰 | 既存ケース維持、分割共通化が挙動不変であることをテストで確認 |
| 項目数増加による書き込み負荷増 | `enabled` と `max.tokens` で制御。実環境測定はユーザー |
| ロールバック | `enabled=false` で新規生成停止。生成済みは期限削除か `deleteDocumentWords` で全削除(設計書 4.2) |

## 9. 未解決事項

- **承認時に確認**: `fess.suggest.compound.enabled` の既定値を設計書どおり `true`(暫定)で実装してよいか。安全側の代替は既定 `false` + 検証時に `-Dfess.suggest.compound.enabled=true`。変更する場合はフェーズ3の既定値と引き渡しメモのみが変わる。
- 設計書 7 章の要確認 3(項目数増加率・ナビゲーション文字列)、要確認 4 の実環境側(NEologd の有無)はユーザーの実環境確認に委ねる。
- フェーズ1の結果次第で、取り出し方や連結ロジックの前提の見直しが必要になる可能性がある。
