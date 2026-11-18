# 0006 設計書のレビュー(document-reviewer)と対応方針

対象: `task_docs/design_fragment_suggest.md`(275 行)。レビュアーは文書・コードを変更していない(読み取りのみ)。

## 1. 総合判定
Critical なし、Important 4 件、Suggestion 6 件、Nitpick 6 件。採用案(M1 既定、M2/W1 は既定無効、A' は tokenizer 段共用、連結語の端トリム、検索ログ経路は C1/C2 のみ)からの逸脱はなし。経緯語の混入なし。行番号・動作・数値の大半が現行 main と一致(`parseDocument` `:346-402`、`trimSymbolTokens` `:664`、`isSymbolToken` `:677`、`isExcludeSearchword` `:860`、`attributes` `:475`、`toAnalyzeToken` `:568`、`SuggestCreator` `:252/:298/:301`、stoptags 74 個の同一性、617/1,220/1,394 の算術など)。

## 2. 指摘と対応方針

### Important(すべて反映)
1. 見積もり 443 の内訳の注記が誤読を招く(2 章 L77)。4+194+176+25+44 = 443 が正しく、「44」は C6 のかなだけの数で、C3 のかな 3 件は活用形 176 に含まれる。「重複 3 を引く」は誤り。→ 注記を修正する。0005 の同じ式は 0006 のこの記述を正とする(既存記録は書き換えない)。
2. tokenizer 段の取得失敗の扱いが矛盾(3.4 L145)。`null` 扱いにすると連結語側で `STAGE_UNAVAILABLE` になり `FAILURE` と区別できない。既存テスト(`DefaultContentsParserCompoundWordTest` L707-730)が両者の区別と WARN の別枠制限を検証している。→ 共通化する取得処理が「結果 / null / 例外」を区別して返す形を明記する。連結語側は従来どおり別々に数え、活用形側は null も例外も「除外しない」。連結語無効で活用形だけ有効なときは、compound 名義の警告(`warnIfDegraded`、`logNoPartOfSpeech`)を出さない。
3. 既定 M1 で失う 1 文字英数の記述が不足(2 章 L58、7 章 L272、3.2、6 章 #8)。1 文字英数 25 語(docFreq 計 1,303。`x` 319、`m` 119、`t` 94、`e` 79、`c` 66)が既定で消える。`x` は M2 ではなく M1 で消える(0003 の M2 行の帰属ミス。設計書側で正す)。→ リスクに明記し、「有用語を失わない」を「巻き添えは少ない(主観)」に弱める。1 文字英数だけを個別に切れる設定の要否を検討事項に書く。
4. 連結語設計書・既存テストとの整合の洗い出しが不完全(3.4 末尾、6 章 #2、5.1)。→ 「影響を受ける既存の記述・テスト」を足す: 連結語設計書 3.4 / 4.2 / 7 章「本番有効化ゲート」(ベースライン測定に `inflection.enabled=false` を併記)と L33「断片は残す」、既存テスト `test_degradation_disabled`(`compound.enabled=false` で `stageChunks` が空であることの検証。`inflection.enabled=false` を併記して維持)、空チャンクで tokenizer 段を呼ばない挙動(`test_chunk_blankTextIsNotAnalyzed`)の維持。`inflection.enabled` の既定 true も、連結語の既定と同様に暫定とし、評価ゲートの対象とする旨を 3.2 に書く。

### Suggestion
5. 対応付けの擬似コードを足す(チャンクごとの (start,end) → 活用形判定の Map、`term` が小文字化後に一致しなければ除外しない)。5.2 の統合テストに `mapping_char` で長さが変わる入力と複数チャンクの入力を足す。L131 の [確認] を「explain の最終段」の範囲に限定する。→ 反映する。
6. `lang` 判定の根拠が実際のアナライザ選択とずれている(`getAnalyzerName` `AnalyzerSettings.java:206-222` はサポート外 lang も `contents_analyzer`〔Kuromoji〕に落とす)。→ 適用範囲は安全側(lang が null/空/`ja` のみ)のままとし、根拠の書き方を「サポート外の lang には適用しない(安全側)」に改める。Fess が渡す lang 値の形式を [要確認] に足す。
7. 単体テストの抜け(`DefaultContentsAnalyzerParseTokenizerStageTest` の拡張、サポート外 lang のケース)。定数 `INFLECTION_FORM_ATTRIBUTE` は外側クラス `AnalyzerSettings` に置く。→ 反映する。
8. `isExcludeSearchword` の null 安全(null は従来どおり除外、空文字は C1 判定が空集合で真になり除外されることを明記)。→ 反映する。
9. 互換性: `DefaultContentsParser` は公開クラスで `SuggestIndexer.setContentsParser` で差し替えられる。Fess 以外の利用者にも既定で候補が減る旨を 4.1 に 1 文足す。→ 反映する。
10. 受け入れ確認が再現できない参照(スクラッチパッドの分類スクリプト)。C1〜C7 の分類規則を表で足す。→ 反映する。

### Nitpick(すべて反映)
- L17「ほか 3 定義」→「ほか 2 定義」(全体で 3 定義)。L66「96 アナライザ(48 言語 × …)」→ 実際は 47 言語 + 言語なしで、数え方を修正する。`parseSearchWords` の行は宣言が `:271`(`:270` は `@Override`)。L189 の「他言語で tokenizer 段は品詞なし」は [推測] と明記するか en/zh に限定する。L115 の否定の範囲を `not (lang が null/空/"ja")` と書く。4.2 の表のうち 3.3/3.4 の再掲は差分だけに絞って冗長を減らす。

## 3. 範囲外の確認事項(完了報告でユーザーに伝える)
- 評価書が挙げた `ne`・`ku` は既定(M1)では消えない。M2(英数 2 文字以下)を既定にするかはユーザー判断。
- STATUS.md の「連結語無効時に A' のためだけに explain を呼ぶか」は設計書 3.4 で決着済み(`compound.enabled` または `inflection.enabled` が true なら呼ぶ)。STATUS.md を整理する。

## 4. 次のアクション
1. document-writer で指摘を設計書に反映する。
2. Important の箇所を再確認する(全文の再レビューは不要)。
3. 完了報告(`ne`・`ku`、設計書の恒久化の要否をユーザーに確認)。
