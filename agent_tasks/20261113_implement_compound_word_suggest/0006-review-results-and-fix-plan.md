# 0006 フェーズ5: レビュー結果と対応方針

対象: `modules/fess-suggest`(HEAD `214421a` + 未コミット差分)。code-reviewer / test-reviewer を並列実施。
判定: code-reviewer「修正後可」(Critical なし、Important 2 件)、test-reviewer「十分」(Critical / Important なし、Suggestion 中心)。

## code-reviewer の指摘と対応

| # | 区分 | 指摘 | 対応 |
| --- | --- | --- | --- |
| C1 | Important | 非 Kuromoji 言語(`contents_analyzer_en` は standard トークナイザ)で、`partOfSpeech` なし・トークン 0 件が `STAGE_UNAVAILABLE` になり、全チャンクで WARN(60 秒に 1 回)が出る。正常運用で警告が常時出ると、4.5 の可視化の目的に反する | **修正する**。アナライザは、応答が有効で `detail.tokenizer` と `filtered_text` はあるが `partOfSpeech` が無い(またはトークン 0 件)場合、`null` ではなく **トークン空の `TokenizerStageResult`** を返す。パーサはこれを `NO_PART_OF_SPEECH`(新設)として数え、warn 対象にしない。`null` は真の取得不可(`_analyze` 失敗、`detail`/`tokenizer`/`filtered_text` 欠落、上限超過、default 実装)に限定する。設計書 3.1/4.1 の「`partOfSpeech` なしは `null`」からの変更(連結語 0 件になる効果は同じ)。`filtered_text` キー誤りは引き続き `null` → `STAGE_UNAVAILABLE` → warn で検知できる。無駄な explain 呼び出し自体は残る(言語単位のスキップは範囲外。引き渡しメモに既知の制約として記載) |
| C2 | Important | explain 失敗の WARN が `DefaultContentsParser` の 60 秒制限を通らず、約 17,000 文字超の空白なしチャンクで文書×フィールドごとに出る | **修正する**。`analyzeTokenizerStage` 内の WARN にも 60 秒に 1 回の間引きを持たせ(抑制分は debug)、原因(例外メッセージ)は WARN に残す |
| C3 | Suggestion | `STAGE_UNAVAILABLE` に複数原因が混在 | 一部対応(C1 で `NO_PART_OF_SPEECH` を分離)。残りは debug ログ文言で区別する。API は追加しない |
| C4 | Suggestion | `charfilters` が複数なら `get(0)` は最終段でない / 無い場合に `text` で代用 | 複数の場合は**最後**の char_filter の `filtered_text` を使う。`charfilters` が無い場合の `text` 代用は**採らない**(キー誤りを検知できなくなるため。同梱構成は `mapping_char` 1 つ) |
| C5 | Suggestion | 縮退カウンタが本番で観測できない(`SuggestIndexer` の private) | 実装しない(範囲外)。`SuggestIndexer` 側で更新完了時に info 要約を出す案を引き渡しメモの未対応事項に記載 |
| C6 | Suggestion | `FAILURE` の WARN が他の WARN と 60 秒枠を共有し Javadoc と食い違う | 原因区分ごとに枠を分ける(`FAILURE` は別枠)。Javadoc を実態に合わせる |
| C7 | Suggestion | `max.tokens=1` が有効値になり実質無効 | 下限を 2 とし、2 未満は既定値にフォールバック |
| C8 | Suggestion | `enabled` が `Boolean.parseBoolean`(typo で無効化) | 対応しない(Javadoc 記載済み。既定 true の機能が設定ミスで止まる点は引き渡しメモに注記) |
| C9 | Suggestion | `DefaultContentsParser` の責務肥大 | 対応しない(設計書 3.1 が `DefaultContentsParser` への実装を指定。任意) |
| C10 | Nitpick | 定数の 2 クラス重複、`convertToMap` の二重変換、`isLast` 未使用、`createDocumentItem` の Javadoc、`split` の回数 | 未使用引数と Javadoc のみ軽く直す。他は対応しない(実害小) |

設計書 4.5 の区分変更の妥当性(code-reviewer 評価): `OVER_LIMIT` の WARN なし=妥当、`FAILURE` 追加=妥当、60 秒間引き=妥当、ログに本文は出ていない=OK、スレッド安全性=OK、`STAGE_UNAVAILABLE` 合算は粗すぎる(C1 で対応)。

## test-reviewer の指摘と対応

| # | 指摘 | 対応 |
| --- | --- | --- |
| T1 | 非対象品詞のテストが、間に数が挟まるため除外を区別できない | 直前に隣接する `名詞-一般` を置いて、非対象品詞(`名詞-数`、`名詞-接尾-助数詞`、`名詞-接尾-人名`、`名詞-形容動詞語幹`、`名詞-非自立`、`名詞-代名詞`、`動詞-自立`、`助詞-連体化` など)ごとにループで連結語 0 件を検証 |
| T2 | 警告集約テストが常に通る(60 秒制限で WARN は 1 件) | WARN メッセージに含まれる `STAGE_UNAVAILABLE=<チャンク数>` が `getDegradedChunkCount` と一致し 2 以上であることを検証 |
| T3 | 統合テストが `lang="ja"` を通っていない | 例語テスト 1 件に `lang=ja` を付与 |
| T4 | 正規化の統合テストの OR 判定が弱い | 実測値に固定するか該当行を削除 |
| T5 | 部分文字列検証の集計が粗い | 文書ごとに最低 1 件の連結語を期待(連結語が出ない文書の検知) |
| T6 | 実コンバータでの読みの検証が弱い(`endsWith("korona")`) | `KatakanaToAlphabetConverter` の実出力で具体値を検証 |
| T7 | 60 秒の時間依存(ホストのスリープ) | 対応しない(許容。時計差し替えは本体変更を伴うため) |
| T8 | `test_deleteOldWords` で enabled=false にしたため、連結語有効時の `deleteOldWords` が未検証 | 追加 1 件: 連結語が有効なまま `deleteOldWords` を通し、古い連結語が消え新しい連結語が残ることを検証 |
| T9 | 「partOfSpeech なし」の件数が未固定 | C1 の変更に合わせて `NO_PART_OF_SPEECH` を検証 |
| T10 | 未使用 import、空白なし長文テストが `max_token_count` 既定値に依存、`max.tokens=1,2` や `enabled` 不正値、無効 offset 直後の `prev` が未検証 | 未使用 import 削除、依存のコメント追記、`max.tokens=1,2` と `enabled` 不正値のテスト追加。`prev` 比較は余裕があれば |

確認できた良い点: `contains` だけで決めない/offset を `filtered_text` に直接適用しない検証、統合テストが「0 件では通らない」構成、System property・ログ設定の後始末、`SuggestAnalyzerTest` の変更が最小限。

## 未対応(意図的)として引き渡しメモに記載する事項

- 縮退カウンタを本番から観測する経路(`SuggestIndexer` の info 要約案)。
- 非日本語アナライザでの無駄な explain 呼び出し。
- `enabled` は `false` 以外(typo・空値)でも無効になる。
- 警告 60 秒制限テストのホスト時間依存。

## 次のアクション

- 上記を code-implementer で修正(フェーズ5-修正)し、`mvn test` 全体を再実行。
- 修正範囲に対して code-reviewer / test-reviewer で再レビューし、Critical/Important が解消されたことを確認する。
