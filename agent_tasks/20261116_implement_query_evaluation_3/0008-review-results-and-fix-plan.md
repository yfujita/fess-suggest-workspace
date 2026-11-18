# 0008: レビュー結果と対応方針(フェーズ 7)

作成日: 2026-11-16 / 担当: code-reviewer、test-reviewer(記録はメインエージェント)

レビュー対象: `modules/fess-suggest` の作業ツリー(比較基準 HEAD `7db7938`)。code-reviewer は本体 4 ファイル、test-reviewer は追加・変更したテスト 5 ファイル。

## 1. code-reviewer: Critical / Important なし(Suggestion 4、Nitpick 4)

設計書 3.2〜3.7 との整合を確認済み(チャンク対応、取得結果 3 通りの区別、連結語名義の警告の条件、読み index、並列共有安全性、ログ)。食い違いは軽微な 2 点のみ。

| 区分 | 指摘 | 対応 |
| --- | --- | --- |
| Suggestion 1 | 全チャンクの tokenizer 段結果を保持するためメモリが増える(推測、未測定) | **対応しない**(現構造のまま)。引き渡しメモの実環境確認(設計書 7 章 5)に「ヒープも含めて測る」を足す |
| Suggestion 2 | protected の `analyzeText` / `analyzeTextByReading` を `parseDocument` が呼ばなくなったことが Javadoc に無い | **対応する**(両メソッドの Javadoc に追記。引き渡しメモにも転記) |
| Suggestion 3 | 形容詞-自立なのに `inflectionForm` が無い構成(`_vanilla` 等)で、除外が黙って 0 件になり気づけない | **対応しない**(設計書の範囲外の追加)。引き渡しメモに「`INFLECTION_FORM` カウンタが長期間 0 のときの見分け方」を書く |
| Suggestion 4 | 非日本語チャンクでも活用形が有効なだけで explain を 1 回呼ぶ | **対応しない**(設計書 3.4 の想定内)。引き渡しメモの負荷確認に「多言語環境では非日本語チャンクの分も増える」を添える |
| Nitpick 1 | 空文字の検索語が `SOKUON_CHOUON_ONLY` として数えられる | 対応しない(結果は設計 3.6 どおり。`getExcludedSearchWordCount` の Javadoc に一言書く程度は任意) |
| Nitpick 2 | 検索ログ経路の除外にデバッグログが無い(設計 3.7 は「カウンタとデバッグログ」) | 対応しない(語を出せず、1 語ごとのログは量が多い。引き渡しメモに「検索ログ経路はカウンタのみ」と記載) |
| Nitpick 3 | `toAnalyzeToken` で `inflectionForm` だけ型を検査する非対称 | 対応しない(0002「実装で守る点 3」に従った実装。他の属性の挙動を変えない方針) |
| Nitpick 4 | トークンごとの小さなアロケーション(未計測) | 対応しない(推測だけの最適化は不要) |

## 2. test-reviewer: Critical なし、Important 2 件、Suggestion 6 件、Nitpick 4 件

設計書 5.1 / 5.2 の全ケースにテストがあり(網羅表は報告のとおり。offset 不一致の 1 行だけ △)、既存テストの変更(`test_symbol_longVowelMarkIsALetter`、`test_degradation_disabled`)は妥当(期待値の無条件な書き換えではない)。単独実行は全件成功。

| 区分 | 指摘 | 対応 |
| --- | --- | --- |
| **Important 1** | offset 不一致のケースが「start と end の両方が違う」1 通りだけ。start のみ・end のみで照合する変異を検知できない(`DefaultContentsParserInflectionTest.java:149-166`) | **対応する**(同じ term で start のみ違う・end のみ違うケースを、小さい独立テストとして追加) |
| **Important 2** | 英数 1 文字・かな 1 文字の規則が実アナライザ + 実 lang で検証されていない(スタブのみ。`FragmentIntegrationTest`) | **対応する**(`x ろ 7 ne 東京 ai` を lang ja / null / en で通す統合テストを追加。`filter=false` との比較つき) |
| Suggestion 3 | `〇`・`★` は `filter=false` でも出ず、`test_runsOfSokuonChouonAndSymbolsAreNotCandidates` の当該部分が空振り | **対応する**(`filter=false` で出るかを確認し、出なければ外す) |
| Suggestion 4 | 端トリムのテストが `max.length`、`ッ`・`っ`・`ｰ`・`ｯ` の端を見ていない | **対応する**(`ッ`+`東京`+`大学`+`ｯ`、トリム後に `compound.max.length` に収まるケース) |
| Suggestion 5 | 検索ログ経路が lang `ja`/null でしか試されていない | **対応する**(`en` または `xx` を追加) |
| Suggestion 6 | 統合テストが `compound.enabled` の既定 true に暗黙に依存 | **対応する**(`before()` で `compound.enabled=true` を明示。結果に影響する他のプロパティも退避・クリア対象に) |
| Suggestion 7 | 集合の厳密一致が辞書依存で脆い | 対応しない(根拠は 0006 に実測つきで記録済み。`_vanilla` は実環境確認) |
| Suggestion 8 | 並列使用のテストが無い | 対応しない(任意。code-reviewer が共有安全性をコードで確認済み) |
| Nitpick 9 | テストの補助クラスが 3 クラスで重複 | 対応しない(既存のスタイルに合わせたクラス単位の複製) |
| Nitpick 10 | `contains("ompound")` | **対応する**(大文字小文字を区別しない確認に) |
| Nitpick 11 | `test_symbol_longVowelMarkIsALetter` で `fragment.filter.enabled` を個別に退避・復元 | **対応する**(`COMPOUND_PROPERTIES` に追加して共通の退避・復元に統一) |
| Nitpick 12 | `testInflectionFormDoesNotAffectPartOfSpeechJudgement` の名前と後半の内容のずれ | **対応する**(コメントを足すか分割) |

## 3. 対応後の手順

1. code-implementer が上記の「対応する」項目を修正する(本体は Suggestion 2 の Javadoc のみ。テストは `src/main` の挙動を変えない)。
2. 影響する 5 クラスと全体回帰(`mvn test`、`mvn package`)を再実行する。
3. Important 2 件の修正を、test-reviewer に絞って再レビューする(対象は追加・変更したテストのみ)。
4. 引き渡しメモ(フェーズ 8)に、対応しなかった指摘のうちユーザー確認に関わるもの(メモリ・負荷・`INFLECTION_FORM` が 0 のときの見分け方・検索ログ経路はカウンタのみ・`analyzeText` の継承)を載せる。
