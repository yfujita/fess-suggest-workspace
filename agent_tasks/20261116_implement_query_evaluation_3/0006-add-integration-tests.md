# 0006: 統合テストの追加(フェーズ 5)

作成日: 2026-11-16 / 担当: code-implementer(記録はメインエージェント)

## 1. 概要

設計書 5.2 の統合テスト(`SuggestTestServer` の実 OpenSearch)を `FragmentIntegrationTest` に追加した(既存 4 件 + 追加 11 件 = 15 件)。`src/main` の変更は不要だった。コミットなし。

## 2. 変更したファイル

- `modules/fess-suggest/src/test/java/org/codelibs/fess/suggest/index/contents/FragmentIntegrationTest.java`(追加のみ。既存 4 件は無変更)
- 実測に使った探索用テストは削除済み。検知力の確認のために `src/main` を 1 行だけ一時変更し、復元した(メインエージェントが `termsByChunk.get(chunkIndex)` であることを確認)。

## 3. 追加テスト(11 件)

共通: `@Before` で `filter.enabled` / `inflection.enabled` / `compound.enabled` の System property を退避・クリアし、`@After` で復元。

1. **offset の一致**
   - `test_offsetsOfFinalStageMatchTokenizerStage`: 半角カナ(`ｶﾞｲﾄﾞﾌﾞｯｸは大きい。ﾜｸﾁﾝ接種が難しかった`)、全角英数(`ＡＩ活用の最前線 ＧＰＵサーバーは大きくなかった`)、活用形入りの文、サロゲートペアと絵文字(`𠮷野家の大きい牛丼😀は難しかった`)。lang は ja と null。最終段の全トークンの (start, end) が tokenizer 段と一致し、lower(term) も一致する。
   - `test_offsetsAreInCoordinatesOfTextBeforeCharFilters`: `charFilteredText.length() < text.length()` を前提確認し、元テキストの `substring(start, end)` が `大きい`・`難しかっ` になる(char filter 後の座標ではない)ことを確認。
2. **活用形の除外(`parseDocument`)**
   - `test_inflectedFormsAreNotCandidatesButBaseFormsAre`: `なかっ 大き 難し 大きい 難しい`(ja / null)。`なかっ`・`大き`・`難し` が消え、`大きい`・`難しい` が残る。`INFLECTION_FORM` カウンタ 3、`InflectionUndetermined` は全て 0。
   - `test_inflectedFormsInSentenceAreNotCandidates`: 文中の `大きかっ`・`なかっ`・`大きく`・`難しかっ` が消える(カウンタ 4)。`大きい`・`難しい` は残る。
   - `test_inflectedFormsAreNotExcludedWhenInflectionIsDisabled`: `inflection.enabled=false` では全語が残る(検知力の比較)。
   - `test_inflectedFormsAreExcludedPerChunkInMultiChunkDocument`: `"大きい 難しかっ " + "円安 "×331 + "難しい 大きかっ なかっ"`(1002 文字で 1 チャンク目が閉じ、2 チャンク目が `難しい` から始まる)。両チャンクで形容詞が同じ offset に別の語で現れるため、チャンクの対応付けを取り違えると除外が外れる。`getCompoundAnalyzedChunkCount()==2`。`inflection=false` では 3 語が残ることも確認。
   - `test_inflectedFormsAreExcludedForMappedCharFilterInput`: 半角カナ入力で `難しかっ` が消え、`ガイドブック`・`大きい`・`ワクチン`・`接種`・`ワクチン接種` が残る。
3. **例語の退行なし**: `test_exampleWordsAreGeneratedAsBefore`: 8 語(`togetter.com` を含む)が既定と、`filter=false` かつ `inflection=false`(従来動作)の両方で生成される。両者の差は断片 `.` が既定で消える 1 件のみ(`removed==Set.of(".")`、`added==Set.of()`)。
4. **C1/C2 と端トリム**
   - `test_sokuonChouonAndSymbolFragmentsAreNotCandidates`: `ー警視庁編ー 新型コロナ ッ . / ー ッッ 円安 ー`。`ー`・`ッ`・`.`・`/`・`ッッ` が消え、`ー警視庁編ー` ではなく `警視庁編` が残る。カウンタは 0 より大きい。
   - `test_sokuonChouonAndSymbolFragmentsAreCandidatesWhenFilterIsDisabled`: `filter=false` では断片と `ー警視庁編ー` が残り `警視庁編` は出ない。カウンタは 0。
   - `test_runsOfSokuonChouonAndSymbolsAreNotCandidates`: `ーーー ッ ッッ . / ... 〇 ★ 大統領選`。既定では候補が `{大統領, 大統領選}` のみ。`filter=false` では記号類が残る。

## 4. 実測で分かった事実

- `大きくなかった` の `なかっ` は助動詞(連用タ接続)で、形容詞-自立ではないため除外対象外。形容詞の `なかっ` は単独入力か `なかったし` の文脈で出る。
- `大きく`=連用テ接続、`大きかっ`・`難しかっ`・`なかっ`=連用タ接続(いずれも文中で除外される)。`大き`・`難し`(ガル接続)は単独入力のときだけ出る。
- 最終段と tokenizer 段の (start, end, lower(term)) は全入力・ja と null で不一致 0。サロゲートペアの offset は UTF-16 単位(`𠮷`=[0,2])で両段が揃う。
- 実応答で、`ー警視庁編ー` の `ー` と `ッ`・`ッッ` は名詞-一般、`.` と `/` は名詞-サ変接続、`〇` と `★` は記号-一般。
- 例語はローカルの neologd 構成でも 8 語とも従来どおり(実測と異なる分割なし)。

## 5. 検知力の確認

`InflectedAdjectives.contains` を一時的に `termsByChunk.get(0)` に変えると `test_inflectedFormsAreExcludedPerChunkInMultiChunkDocument` が失敗することを確認し、元に戻した。`inflection=false` / `filter=false` の比較テストにより、除外処理が無効化された場合も検知できる。

## 6. テスト結果

`mvn -q formatter:format license:format` 実行済み。`FragmentIntegrationTest` 15、`CompoundWordIntegrationTest` 11、`DefaultContentsParserCompoundWordTest` 116、`DefaultContentsParserFragmentTest` 29、`DefaultContentsParserInflectionTest` 22(計 193 件)が失敗 0、BUILD SUCCESS。

## 7. 未対応事項・次のアクション

- `_vanilla` 構成での `inflectionForm` はローカルで検証できない(ユーザーの実環境確認)。
- 次: フェーズ 6(全体回帰とビルド確認: `mvn test`、`mvn package`)。
