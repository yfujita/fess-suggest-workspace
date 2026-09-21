# fess-suggest-workspace

## プロジェクト概要

このプロジェクトはfessサジェスト機能を開発するためのワークスペース。

## モジュール構成

- modules/fess-suggest: fessのサジェスト用ライブラリ
- modules/fess: fess本体。fess-suggestを利用するアプリケーション。

## 技術スタック



## エージェントドキュメント

エージェント用のドキュメントをagent_docs配下に作成する。

### global

タスク間で共通の基本的となる知識を格納する。

- reference: agent_docs/global/references/

### tasks

タスクドキュメントを格納する。

- tasks: agent_docs/tasks/[タスク名]/

## サブエージェント

タスクを実施する際は、サブエージェントを適切に使用する。

- プラン作成: work-plan-creator
- 技術的調査: tech-architect
- コード実装: code-implementer
- ドキュメント作成: doc-writer
- コードレビュー: code-reviewer
- テスト観点のレビュー: test-reviewer
- タスクのプロセス・成果物のレビュー: task-reviewer

## 制約

- 明確な指示がなければ変更実施後にgit commitを行わないこと。