# 20260706_opensearch_reference

## 目的
fess-suggestの改善に向け、未確定となっているOpenSearchの仕様やAPIを技術検証し、後続の詳細設計（データモデルやインターフェース設計）に必要な前提条件を確定させる。

## インプット（参照資料）
* `agent_docs/tasks/20260706_desighn_document/docs/improvement-proposal.md` （改善案）

## タスク（検証項目）
1. **API検証 (`scripted_upsert`):** * サジェスト辞書の更新において、ドキュメントが存在しない場合はInsert、存在する場合はスクリプト（Painless等）によるUpdateが意図通りに動作するか検証する。
2. **マッピング・API検証 (`knn`):** * セマンティック検索拡張を見据えた `knn`（ベクトル）検索を利用するための要件（マッピング定義やクエリ構文）を検証する。
3. **新スキーマのドラフト作成:** * 上記の検証結果を踏まえ、新しいfess-suggestで利用するインデックスマッピング定義（JSON形式）のドラフトを作成する。

## アウトプット（成果物）
* `opensearch_tech_verification.md` : 検証結果、決定したバージョン、採用するAPIの仕様、および新スキーマのドラフトをまとめたレポート。

## 完了条件 (Definition of Done)
* 「インデックス設計」および「インターフェース設計」に着手できる状態になっていること。

## 参照

- OpenSearchについての調査結果 `verification/00-docs-research.md`
- 検証環境 `verification/env/`