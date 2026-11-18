# 0004: 断片フィルタ・連結語の端トリム・検索ログ経路(フェーズ 3)

作成日: 2026-11-16 / 担当: code-implementer(記録はメインエージェント)

## 1. 概要

設計書 3.2、3.3、3.5、3.6、3.7(tokenizer 段に依存しない部分)を実装した。活用形(`inflection.enabled`、tokenizer 段の共通化)はフェーズ 4。コミットなし。

## 2. 変更したファイル(`modules/fess-suggest/` 配下。未コミット)

- `src/main/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParser.java`(変更)
- `src/test/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParserFragmentTest.java`(新規。29 件)
- `src/test/java/org/codelibs/fess/suggest/index/contents/DefaultContentsParserCompoundWordTest.java`(変更。既存 1 件の期待値を変更、1 件追加)

## 3. 実装の要点

1. **設定**: コンストラクタで 1 回、`Boolean.parseBoolean`。`fragmentFilterEnabled`(`fess.suggest.fragment.filter.enabled`、既定 true)。`latinShortEnabled`・`singleHanEnabled` は各プロパティ(既定 false)と `fragmentFilterEnabled` の論理積で確定する(filter=false では自動的に効かない)。
2. **除外判定**: `findFragmentExclusion(word, lang)`(設計書 3.3 の擬似コードどおり。コードポイント単位、C1 は {ッ っ ー ｰ ｯ} のみ、最小長規則は lang が null/空/`ja` のときだけ、英数は ASCII、かなは `UnicodeScript` の HIRAGANA/KATAKANA、単漢字は HAN)。プランの `isNoiseFragment`(boolean)ではなく**除外理由(`FragmentExclusion`。なければ null)を返す**形にした(理由別カウンタのため。挙動は同じ)。C1/C2 は `findLanguageIndependentExclusion` に切り出し、文書経路と検索ログ経路で共用。`parseDocument` のトークンループで `isBlank` の直後に `continue`(リストは組み替えず、`readingTokens` の index はずれない)。
3. **端トリム**: `trimSymbolTokens` の判定を `isTrimmedAtEnd`(記号のみ、または filter 有効時の促音長音のみ)に広げた。両端から順に外し、中間は残る。外した後の 2 トークン未満判定、`max.tokens`、`contains`、`max.length` は既存の `flushRun` の順序のまま。
4. **検索ログ経路**: `isExcludeSearchword` の先頭で、filter 有効かつ非 null のとき C1/C2 ならアナライザを呼ぶ前に除外。null は従来処理へ、空文字は除外(従来も除外のため結果は同じ)。言語を問わず、最小長規則なし。
5. **カウンタ・ログ**(`CompoundDegradation` に倣った):
   - enum `FragmentExclusion`: `SOKUON_CHOUON_ONLY` / `SYMBOL_ONLY` / `ALPHANUMERIC_SHORT`(1 文字と latin.short 有効時の 2 文字)/ `SINGLE_KANA` / `SINGLE_HAN`。フェーズ 4 で `INFLECTION_FORM` を足す想定。
   - 保持: `EnumMap<FragmentExclusion, AtomicLong>` を 2 つ(文書経路 `excludedFragmentCounts`、検索ログ経路 `excludedSearchWordCounts`。検索ログ経路は C1/C2 のみ)。コンストラクタで全値の `AtomicLong` を投入済み。追加フィールドは final の設定値とこの final な EnumMap のみ(並列ストリームから共有されても安全)。
   - 公開 getter: `getExcludedFragmentCount(reason)`、`getExcludedSearchWordCount(reason)`。
   - ログ: 除外した断片をフィールドごとに集計し、`parseDocument` で 1 行(`Excluded fragments: field, lang, counts`)をデバッグ出力。語は出さない。INFO 以上のログは追加していない。
   - クラス Javadoc に断片フィルタの節(プロパティ 3 つ)を追加。`compound.enabled` の説明の更新はフェーズ 4。
6. **単体テスト `DefaultContentsParserFragmentTest`(29 件)**: 設計書 5.1 のこの範囲のケースを網羅(C1、C1 境界、C2、英数 1 文字×lang、英数 2 文字、かな 1 文字、単漢字〔`𠮷` 含む〕、境界、読みの非ずれ、理由別カウンタ、設定〔filter=false、`TRUE`、`yes`〕、端トリム、`max.tokens` が外した後に適用、例語 8 つ、検索ログ経路〔アナライザを呼ばないことを検証〕)。System property は `@Before` で退避、`@After` で復元。

## 4. 既存テストへの影響と判断

- 落ちたのは `DefaultContentsParserCompoundWordTest.test_symbol_longVowelMarkIsALetter` の 1 件のみ。`ー`+`quiet`→`ーquiet`、`quiet`+`ー`→`quietー`(`ー` は Letter なので記号トリムされない、という旧仕様)を期待していた。設計書 2 章・3.5(`ー警視庁編ー`→`警視庁編`)の仕様変更で、既定では端の `ー` が外れるため、**期待値は仕様変更に追随すべき**と判断した。
- 対応: 元のテストは「記号ルールでは `ー` が外れない」ことを filter=false で検証する形に変更(System property は finally で復元)。新テスト `test_symbol_longVowelMarkAtTheEndsIsRemovedByTheFragmentFilter` を追加(既定で `ー`+`quiet`・`quiet`+`ー` は連結語なし、`ー`+`quiet`+`city` は `quietcity`)。
- 他の既存テスト(`DefaultContentsParserTest`、`EdgeCaseTest`、CompoundWordTest の他 114 件)は影響なし。

## 5. テスト結果(`modules/fess-suggest`)

- `mvn -q formatter:format license:format` 実行済み。
- 関連 8 クラス(FragmentTest 29、CompoundWordTest 116、ParserTest 12、EdgeCaseTest 32、FragmentIntegrationTest 4、ParseTokenizerStageTest 15、SuggestAnalyzerTest 20、AnalyzerSettingsTest 7、CompoundWordIntegrationTest 11)は失敗 0。
- 全テスト(`mvn test`): 899 件、失敗 0、エラー 1。エラーは `AnalyzerConverterTest.initializationError`(`BindException: Address already in use`、127.0.0.1:55366。ポート衝突で本変更と無関係)で、単独再実行(20 件)は成功。ログ: `/private/tmp/claude-501/-Users-yfujita-fuji-n2sm-fess-fess-suggest-workspace/e4bfbd87-1e6d-47a4-9c3b-1c79786606e5/scratchpad/full-test.log`

## 6. 未対応事項・次のアクション

- `DefaultContentsParser` の Javadoc の `compound.enabled` 説明、`test_degradation_disabled` への `inflection.enabled=false` 併記は、フェーズ 4(設計書 3.8)。
- 次: フェーズ 4(`inflection.enabled`、tokenizer 段の共通化、活用形の除外。`FragmentExclusion.INFLECTION_FORM` を追加)。
