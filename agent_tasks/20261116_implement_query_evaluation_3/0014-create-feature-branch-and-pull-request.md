# 0014: feature ブランチの作成・push・PR 作成

作成日: 2026-11-16 / 担当: メインエージェント(ユーザーの明示的な指示「featureブランチを作ってpushしてPRを作って」による)

## 1. 実施内容

- `modules/fess-suggest`(独立 git リポジトリ。origin は `https://github.com/codelibs/fess-suggest.git`)で、`main`(HEAD `7db7938`。PR #107 のマージ済みコミット)から `feature/fragment-suggest` を作成。
- `src` 配下の変更 9 ファイル(本体 4、テスト 5〔新規 3、変更 2〕)だけをステージし、1 コミット `bbfe198`(`feat: Exclude fragment candidates from suggest`)を作成。末尾に `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` を付与。
- `origin` に push(`feature/fragment-suggest`)。
- `gh pr create --base main` で PR #108 を作成: https://github.com/codelibs/fess-suggest/pull/108。本文は概要・変更内容・設定表・テスト結果・既知の制約。末尾に `🤖 Generated with [Claude Code](https://claude.com/claude-code)` を付与。

## 2. 注意

- PR の本文には、Fess 組み込みでの確認は「確認済み(項目別の詳細は未記録)」と書いた。`_vanilla` 未検証、explain の負荷・ヒープ未測定、`inflection.enabled` の既定が暫定であること、`ne`・`ku` は既定で消えないことを、既知の制約として明記している。
- ワークスペース側のリポジトリ(`agent_tasks/`、`.claude/audit/events.jsonl`、`.obsidian/workspace.json`)は未コミット。今回の指示の範囲外のため触っていない(連結語設計書の更新 0013 もワークスペース側の変更で、未コミット)。
- `modules/fess-suggest` の作業ツリーは、コミット後にクリーンのはず(ただし target/ は無視されている前提)。

## 3. 未対応事項・次にやること

- PR #108 のレビュー・マージ待ち(ユーザー作業)。
- ワークスペース側の `agent_tasks/`(連結語設計書の更新を含む)のコミット要否は未回答。
- 0013 の 4 章の未対応項目、`ne`・`ku` の既定、設計書の恒久化の要否は未回答のまま(STATUS.md 参照)。
