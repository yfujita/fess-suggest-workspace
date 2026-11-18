# タスク状態

## 基本情報

- 状態: done
- 現在工程: 完了(ユーザーの Fess 組み込み確認済み)
- 最終更新: 2026-11-16
- 最新作業記録: [0017-remove-unused-analyze-text-methods.md](./0017-remove-unused-analyze-text-methods.md)

## 現在の状況

実装・テスト・レビュー・タスクレビューが完了し(Critical / Important なし)、ユーザーが Fess に組み込んで確認した(「確認した限りでは問題なさそうでいい感じ」。0012。確認の詳細は報告なし)。完了条件「実装が完了し、テストも完了している」を満たし、タスクは完了。

- 実装(`modules/fess-suggest`。未コミット、HEAD `7db7938`): 文書経路の断片フィルタ(促音長音のみ・記号のみ・英数1文字・かな1文字)、形容詞-自立の活用形の除外(tokenizer 段を連結語と共用)、連結語の両端の促音長音のトリム、検索ログ経路の C1/C2 除外。`suggest_analyzer.json`・`modules/fess` は変更なし(0003〜0005)。
- プロパティ: `fess.suggest.fragment.filter.enabled`(既定 true)、`.inflection.enabled`(既定 true、暫定)、`.latin.short.enabled`(既定 false)、`.single.han.enabled`(既定 false)。`ne`・`ku` は既定では消えない。
- テスト: `mvn package` で **960 件、失敗 0、BUILD SUCCESS**(最終ソースで再実行済み。0011)。統合テスト(実 OpenSearch)で offset 一致・複数チャンクの活用形除外・例語の退行なし・C1/C2 と端トリムを確認した(0006、0009)。
- 成果物 jar: `/Users/yfujita/fuji/n2sm/fess/fess-suggest-workspace/modules/fess-suggest/target/fess-suggest-15.10.0-SNAPSHOT.jar`(217,925 bytes)。
- レビュー: code-reviewer は Critical / Important なし。test-reviewer は Important 2 件を修正し再レビューで解消を確認。task-reviewer は Critical / Important なし(0008〜0011)。
- ユーザーの Fess 組み込みでの確認手順は 0010 の 5 章と 0011 の 3.1(活用形の除外が効いているかの見分け方)。プラン(0001)は 2026-11-16 にユーザーが承認済み。
- 追加作業: ユーザーの指示で連結語設計書を実装に合わせて更新した(0013。document-reviewer の Important 3 件を反映。未対応の軽微な項目は 0013 の 4 章)。
- PR: ユーザーの指示で `modules/fess-suggest` に `feature/fragment-suggest` ブランチ(コミット `bbfe198`)を作成して push し、PR #108(https://github.com/codelibs/fess-suggest/pull/108)を作成した(0014)。ワークスペース側の `agent_tasks/` は未コミット。
- PR #108 の Copilot のレビュー指摘 2 件(tokenizer 段の保持量、`parseQueryLog` が C1/C2 を素通り)を妥当と判断して作業ツリーで対応した(0015)。全体 976 件・失敗 0、jar 219,011 bytes。設計書も更新済み。ユーザーの指示でコミット `d9d1935` を作成して push し、PR 本文も更新した(0016)。0010 の一部記述(ヒープ)は古いまま(0015 の 5 章に注記)。Copilot のコメントへの返信は未実施。
- 追加作業: ユーザーの指示で、テストからしか呼ばれていない protected の `analyzeText` / `analyzeTextByReading` と、それだけを対象にしたテスト 3 件を削除した(0017。未コミット。`DefaultContentsParserTest` 9 件成功、全体の再実行はしていない)。
- 作業中、修正担当の復元用 `cp -i` が本体を上書きしうる形で残っていたため停止した。上書きは起きていない(0009 の 4 章、0011 の 4 章)。

## 次のアクション

1. なし(本タスクは完了)。
2. 連結語設計書の更新は完了(0013)。0013 の 4 章の未対応項目(行番号参照、`compound.break.*` の記載漏れなど)を直すかをユーザーが判断する。
3. ユーザーが `ne`・`ku` の扱い(M2 を既定にするか)と設計書の恒久化の要否を判断する。
4. PR #108 のレビュー・マージ待ち(ユーザー作業)。Copilot のコメント 2 件への返信の要否をユーザーが判断する。
5. PR #108 のレビュー・マージ待ち(ユーザー作業)。ワークスペース側の `agent_tasks/` のコミット要否は未回答(指示があるまで行わない)。

## 未解決事項

- ユーザーの実環境確認項目は **0010 の 5〜6 章と 0011 の 3 章**を参照: `_vanilla`(標準 kuromoji)で `inflectionForm` が取れるか(ローカル再現不可)、explain の負荷とヒープ(設計書 7 章 5・8)、1 文字英数 25 語の個別設定の要否(同 9)、`inflection.enabled` の既定(暫定)の確定。
- `ne`・`ku` は既定では消えない(M2 は既定無効)。
- `analyzeText` / `analyzeTextByReading` は削除した(0017)。継承する外部コードがあればコンパイルエラーになる(ワークスペース内には無い)。
- 設計書の恒久化の要否(`docs/global/` への配置)。

## ユーザー判断待ち(完了を妨げない)

- Copilot のコメント 2 件(#4582846623、#4582846653)への返信の要否。
- 設計書 7 章にヒープ面の記述を新設するか。
- 連結語設計書の追加修正(0013 の 4 章)の要否。
- `ne`・`ku` の扱い(M2 を既定にするか)。
- 設計書の恒久化の要否。
