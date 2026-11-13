# 0006 検証レポート `opensearch_tech_verification.md` の作成（ステップ6）

> タスク: `20260706_opensearch_reference` ステップ6（作業プラン `0001-work-plan.md` §ステップ6）。
> 実施日: 2026-07-06。凡例は改善案/00-docs-research に準拠。
> 目的: 要件（`0000` §アウトプット）で指定された成果物 `opensearch_tech_verification.md` を作成し、後続設計（インデックス設計・インターフェース設計）の前提条件を確定させる。

---

## 1. 実施サマリ

- **成果物 `agent_docs/tasks/20260706_opensearch_reference/opensearch_tech_verification.md` を作成した。** ステップ1〜5 の成果（`00-docs-research.md` / `0002`〜`0005`）を1本のレポートに統合。
- レポート構成（プラン §ステップ6 の指定5点を網羅）:
  0. エグゼクティブサマリ（3検証項目の結論表・DoD 充足の明示）
  1. 検証環境・決定バージョン（OpenSearch 3.7.0 / Docker / runner 不使用の判断・プラン前提訂正 / 2.x→3.x 破壊的変更）
  2. `scripted_upsert` 検証結果（採用仕様・Bulk NDJSON 形・写経マージ規則・retry_on_conflict 表・複雑度評価・params 契約）
  3. `knn` 検証結果（K1〜K9 表・採用構成・クエリ構文・ハイブリッド2案・リソース傾向）
  4. 新スキーマドラフト（mapping/settings JSON・棚卸し表・score 廃止/dynamic strict/整合・移行）
  5. 未確定事項・後続申し送り（8項目の表）
  6. 成果物・再現手順
  7. 参照した一次情報（公式ドキュメント URL 一覧）
  - 付録: 本レポート章と個別作業ドキュメントの対応表

## 2. 完了条件（DoD）の充足確認

- 要件 `0000` §完了条件「『インデックス設計』および『インターフェース設計』に着手できる状態」を満たす:
  - **採用 API 仕様**: scripted_upsert（§2）・knn マッピング/クエリ（§3）が確定。
  - **スキーマドラフト**: mapping + index settings ドラフト（§4）が変更理由表付きで完成。
  - **未確定事項の一覧**: §5 に8項目を後続タイミング付きで整理。
- 実機検証はすべて冪等スクリプト＋エビデンス JSON として `verification/` に保存済み（再現可能）。

## 3. 本タスクで新規作成・変更していないもの（スコープ厳守）

- fess-suggest / fess 本体の実装ファイルは**一切変更していない**（本タスクは技術検証・ドラフト作成のみ）。
- 実スキーマファイル（`modules/fess-suggest/src/main/resources/suggest_indices/`）は差し替えていない（ドラフトは `verification/schema-draft/`）。

## 4. 凡例・出典の一貫性

- 改善案と共通の凡例（[事実]/[提案]/[要確認]）でレポート全体を記述。
- [事実] には実機アサーション（scripted_upsert 26 / knn 28）または一次情報 URL を紐づけ。
- ドキュメントと実機の食い違い（例: nmslib "deprecated" 表記 vs 実機「作成ブロック」K1）は実機優先で明記。

## 5. タスク完了

- ステップ6 完了をもって、作業プラン `0001` の全ステップ（1〜6）が完了。要件の Definition of Done を充足。
- 後続タスク（インデックス設計・インターフェース設計・負荷試験）への申し送りはレポート §5 に集約。
