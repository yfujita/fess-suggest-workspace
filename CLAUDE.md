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

## タスクドキュメント

あるタスクについてエージェントが作業を行なった際の関連ドキュメント。

### 要件定義

タスクの要件定義は `agent_docs/tasks/[タスク名]/0000-requirements-definition.md` ファイルに定義する。

### 作業履歴

タスクに関連する作業を行なった場合は `agent_docs/tasks/[タスク名]/[通し番号]-[作業名].md` ファイルに作業内容を記述する。必ず記述すること。
作業ドキュメントを作成する際の[通し番号]は、すでにタスク内に存在するドキュメントの内一番大きい数字に+1した数を設定していく。

## サブエージェント

タスクを実施する際は、サブエージェントを適切に使用する。

- プラン作成: work-plan-creator
- 技術的調査: tech-architect
- コード実装: code-implementer
- ドキュメント作成: doc-writer