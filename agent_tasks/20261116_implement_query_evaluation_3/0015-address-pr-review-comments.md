# 0015: PR #108 のレビュー指摘への対応

作成日: 2026-11-16 / 担当: code-implementer(修正)、code-reviewer・test-reviewer(レビュー)、document-writer(設計書)、記録はメインエージェント

ユーザーの指示(「PRにレビュー指摘があった。確認して指摘が適切であれば対応して」)による。対象は PR #108(https://github.com/codelibs/fess-suggest/pull/108)の Copilot のレビュー(inline 2 件)。**コミット・push は未実施**(作業ツリーの変更のみ。ユーザーの指示待ち)。

## 1. 指摘の確認と判断

| # | 指摘(要旨) | 判断 | 理由 |
| --- | --- | --- | --- |
| 1 | `fetchTokenizerStages` が全チャンクの tokenizer 段の結果(トークンと属性 Map)をフィールドの間ずっと保持し、旧実装(連結語を 1 チャンクずつ処理して捨てる)よりピークヒープが増える。活用形の除外と連結語の生成を 1 チャンクずつ一緒に処理して解放せよ | **妥当。対応** | 実際に全チャンク分を保持していた。0008 で code-reviewer の Suggestion 1 として出ていたが「対応しない」とした判断を、レビュー指摘と構造的に低コストで直せることから改めた |
| 2 | `parseQueryLog`(公開 API `SuggestIndexer.indexFromQueryLog` が直接呼ぶ)が C1/C2 の除外を通らず、`content:ッ` のようなログが QUERY 候補になる | **妥当。対応** | 設計書 3.6 は「Fess から使われておらず対象外」としていたが、ライブラリの公開経路として一貫させるべきで、変更も小さい。Fess の検索ログ処理は `parseSearchWords` 経由で、この経路は影響を受けない |

## 2. 変更内容(`modules/fess-suggest`。未コミット)

- `src/main/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParser.java`
  - 指摘 1: `fetchTokenizerStages` / `findInflectedAdjectives` / `createCompoundItems` を廃止し、`analyzeTokenizerStages` を新設。**1 チャンクずつ**「取得(`fetchTokenizerStage`)→ 活用形の対応表 `findInflectedTerms`((start,end)→term だけ)→ compound.enabled なら `createCompoundItemsOfChunk` → 取得結果を破棄」を 1 パスで行う。戻り値は `TokenizerStageOutcome`(`InflectedAdjectives` + `compoundItems`)。取得結果はラムダ内のローカルだけで、次のチャンクの取得前に参照が外れる。リクエスト回数、3 通りの区別、連結語側の `STAGE_UNAVAILABLE` / `FAILURE` の別カウントと警告、活用形側の縮退、チャンク index の対応(空チャンクも空の Map を 1 要素追加)、出力順(断片 → 連結語)は不変。
  - 指摘 2: `isExcludedByFragmentFilter(String)` を新設(filter 有効かつ非 null で C1/C2 に該当すれば `excludedSearchWordCounts` を加算して true)し、`isExcludeSearchword` の先頭ガードもこれを呼ぶ形に。`parseQueryLog` で、パース後の各語を**正規化・読みの生成の前に**判定し、除外語は読みも作らず落とし、残った語と読みを同じ index で組み直す。全語除外のフィールドは項目なし。一部残れば残りだけで 1 項目(`parseSearchWords` と同様)。最小長・文字数の規則は入れない。filter.enabled=false では従来どおり。Javadoc を更新。
- `src/test/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParserFragmentTest.java`: 38 → 47 件(下記 3 章)。
- 設計書 `task_docs/design_fragment_suggest.md` を実装に合わせて更新(3.1、3.4、3.6、3.7、5.1、2 章の方針 4、行番号参照をメソッド名参照に)。

## 3. レビューと対応

- **code-reviewer**(本体の差分): Critical / Important なし。取得結果の解放構造、リクエスト回数、縮退、チャンク index、出力順、語と読みの index、二重計上なしを確認。残る任意の指摘(対応しない): (a) 連結語のカウンタ・警告が断片のループより前に記録される(断片のループが `IOException` で失敗する稀なケースで、連結語の件数・警告だけ残る。観測用で語・本文は含まない。許容し、設計書 3.4 に明記した)、(b) `analyzeTokenizerStages` が複数の責務と 8 個の引数を持つ(現状維持)、Nitpick: フィールド Javadoc の冗長さ、空文字の検索語が `SOKUON_CHOUON_ONLY` に数えられる(`parseQueryLog` で従来の結果が変わる点。設計書・Javadoc に記載)、フィルタ判定が正規化前であること(`parseSearchWords` と同じ。設計書に明記)。
- **test-reviewer**(テスト差分): Critical なし、Important 1 件、Suggestion 6 件、Nitpick 2 件。すべて妥当と判断して対応(テストのみ追加。`src/main` は不変):
  - I1(Important): 既定設定では `ai`・`月` が長さ規則の対象外のため、長さ規則の誤適用を検知できない → `latin.short.enabled` と `single.han.enabled` を有効にしても検索ログ経路・検索語経路で `ai`・`月`・`x`・`あ`・`ア` が残ることを確認(`test_queryLog_lengthRulesAreNotAppliedEvenWhenEnabled`、`test_searchWords_..`)。
  - S1: `test_queryLog_sokuonChouonAndSymbolsMakeNoItem` でカウンタ(C1 が 3、C2 が 2)を assert し、語がフィルタに届いたことを確認。
  - S2: `test_queryLog_excludedWordsAreNotPassedToTheReadingConverter`(除外語に読み変換を呼ばない)。
  - S3: `test_queryLog_normalizerIsAppliedToTheRemainingWordsAndTheirReadings`、`test_queryLog_exclusionIsJudgedBeforeNormalization`、`test_searchWords_exclusionIsJudgedBeforeNormalization`(正規化の適用と、判定が正規化の前であること。順序の検証には、`x` と `ー` を入れ替える作為的なスタブ Normalizer を使った)。
  - S4: `test_inflection_blankChunkInTheMiddleDoesNotShiftTheChunkIndex`(途中に空白チャンクが挟まる場合)。
  - S5: `test_order_fragmentsOfAllChunksComeBeforeCompoundWordsOfAllChunks`(複数チャンク・複数 fields の出力順)。
  - S6: `test_stage_isProcessedChunkByChunkWithoutKeepingTheFetchedResults`(スタブの `analyzeTokenizerStage` と連結語の読み変換が共有リストにイベントを記録し、`stage:chunk1` → `convert` → `stage:chunk2` → `convert` の順を検証。全チャンクを先に取得する構造では成り立たず、メモリ対策の回帰ガードになる)。
  - N1: `test_queryLog_filterDisabledKeepsEveryWord` の 2 回呼び出しを 1 回に統合。
  - 変異確認(一時変更 → テストが落ちる → `/bin/cp` で復元、md5 一致を確認): (A) `parseQueryLog` に言語規則つきの除外を足す → I1 の新テストが `ai` で落ちる(旧テストは `x` しか検知しなかった)、(B) 全チャンクを先に取得してから処理する → S6 だけが落ちる、(C) 空白チャンクの空の Map を追加しない → S4 が落ちる。S2・S3・S5 は変異確認をしていない(正しいコードで通ることのみ確認)。
  - 再レビュー(test-reviewer)は行っていない(指摘をそのままテスト追加で反映し、変異確認で検知力を確認したため)。

## 4. 検証

- `mvn -q formatter:format license:format` 実行済み。
- `mvn package`(全体): **テスト 976 件、失敗 0、エラー 0、スキップ 0、BUILD SUCCESS**(967 → 976 件。`DefaultContentsParserFragmentTest` が 38 → 47 件)。jar: `/Users/yfujita/fuji/n2sm/fess/fess-suggest-workspace/modules/fess-suggest/target/fess-suggest-15.10.0-SNAPSHOT.jar`(219,011 bytes)。ログ: `/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/e4bfbd87-1e6d-47a4-9c3b-1c79786606e5/scratchpad/pr108-final-package.log`。ビルド前後で `DefaultContentsParser.java` の md5 は不変(`f1d10e08049ff829ebd4915a5a67b526`)。

## 5. 影響を受ける記述(要更新)

- **引き渡しメモ 0010**(5 章 7 の性能項目、6 章): 「活用形の判定のため、全チャンクの tokenizer 段の結果をフィールド処理の間保持する(code-reviewer の Suggestion 1)」「ヒープも測る」は古くなった。保持するのは活用形の対応表と連結語の項目だけになった。explain 自体のコスト(通常の analyze の約 10 倍以上)と、数万文字のチャンクでの実行時間は引き続き実環境での確認項目。0010 は不変の作業記録のため書き換えない。
- **PR #108 の本文**: 「全チャンクの tokenizer 段の結果を保持するため、数万文字の本文でのヒープ・実行時間は未測定」の記述が古い。`parseQueryLog` にも適用した旨を追記する必要がある。push 後に本文を更新する(ユーザーの指示待ち)。

## 6. 未対応事項・次のアクション

1. ユーザーが変更内容を確認し、**コミット・push の指示**を出す(`feature/fragment-suggest` に追加コミット。指示があるまで行わない)。push 後、PR 本文の更新と、Copilot の指摘 2 件への返信(対応内容)を行うか確認する。
2. 設計書 7 章にヒープ面の記述を新設するか(現状、設計書に「ヒープ」の記載はなく、3.4 の新項目に理由を書いた)。
3. 連結語設計書(0013)の行番号参照のずれ、`compound.break.*` の記載漏れ(0013 の 4 章)は未対応のまま。
4. `ne`・`ku` の既定、設計書の恒久化の要否は未決(STATUS.md 参照)。
