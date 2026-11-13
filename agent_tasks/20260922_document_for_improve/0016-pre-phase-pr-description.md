# 事前フェーズ: PR description

ブランチ `fix/settings-read-after-concurrent-init`（`modules/fess-suggest`、分岐元 `main`）の PR description 用。以下を貼り付けて使う。

---

## 概要

複数のプロセス/スレッドが同時に `init()` したとき、作成直後の設定インデックスを PIT で読んで `no shard is available` で失敗する競合を修正します。既存テスト `SettingsIndexCreationRaceTest#test_concurrentInitOnFreshCluster` が 5 回中 5 回失敗していた原因でもあります。

## 原因

- 4 スレッドが同時に `init()` すると、`fess_suggest_analyzer` を自分で作らなかったスレッドは、yellow 待ちだけで読み出しに進みます。
- OpenSearch は、作成直後で primary が未起動のインデックスを RED ではなく YELLOW と報告します（`ClusterShardHealth.getInactivePrimaryHealth`）。このため yellow 待ちは primary の起動を待たずに返ります。
- PIT は部分作成を許可しているため、ID なしの応答が返り、`PitOperationHelper.createPit` が `SuggesterException` を投げます。
- `SuggestSettings#getSettingsDocument` は同じ問題を get のリトライで回避していますが、`AnalyzerSettings` にはその対策がありませんでした。`ArraySettings` も同じ構造です。

fess を複数台同時に起動した場合にも起こりうる不具合です。

## 変更内容

- `PitUnavailableException`（`SuggesterException` のサブクラス）を追加し、`PitOperationHelper.createPit` が「shard が 1 つも使えない」場合に投げるようにしました。メッセージ文字列ではなく型でリトライ対象を判定するためです。`SuggesterException` を catch している既存コードはそのまま動きます。
- `PitOperationHelper.readWithRetry(client, settings, index, reader)` を追加しました。`SuggestSettings#getSettingsDocument` と同じ方式です。
  - 100ms から 2000ms まで倍々に間隔を伸ばし、`clusterTimeout` を期限に再試行します。期限後は元の `PitUnavailableException` を再 throw します。
  - 再試行の前に対象インデックスの yellow 待ちをもう一度行います。
  - リトライ対象は `PitUnavailableException` のみです。`IndexNotFoundException` などはそのまま伝播します。
- `AnalyzerSettings.init()` の `getFieldAnalyzerMapping()` と、`ArraySettings.getFromArrayIndex()` の PIT 検索を `readWithRetry` で包みました。
  - `getAnalyzerNames()` はクラスタステートを読むだけで PIT を使わないため、対象外です。

## 挙動の変化

- 変わるのは、同時 `init()` で作成直後のインデックスを読んで失敗していたケースが、リトライの末に成功するようになる点だけです。
- 競合がない通常起動では `reader.get()` が 1 回で成功するので、戻り値と挙動は変わりません。
- 公開 API の破壊はありません（新しい例外クラスの追加のみ）。

## テスト

- 追加
  - `PitOperationHelperTest`: `readWithRetry` の単体テスト 3 件（1 回のリトライで成功、期限後に最後の例外インスタンスをそのまま再 throw、他の例外はリトライせず伝播）。
  - `ArraySettingsTest`: PIT 作成が 1 回だけ失敗する場合に、`array().get()` がリトライして正しい値を返す統合テスト 1 件。
- 変更: `PitOperationHelperTest#testCreatePit_indexWithUnassignedShards` の catch 型を `PitUnavailableException` にしました（リトライ判定の契約として明示）。
- 結果
  - `mvn test`: 722 件すべて成功。
  - `SettingsIndexCreationRaceTest` を単独で 5 回連続実行し、すべて成功。
  - `PitOperationHelperTest` と `ArraySettingsTest` を単独で 3 回連続実行し、すべて成功。

## 既知の課題（今回は対応しない）

- `readWithRetry` は `clusterTimeout` を最大でヘルスチェック 1 回分超過しうる。`SuggestSettings#getSettingsDocument` と同じ構造のため、既存に揃えました。
- yellow 待ちの `actionGet()` 中に割り込まれると、fesen-httpclient が `IllegalStateException("Future got interrupted")` を投げ、そのまま伝播する。`SuggestSettings` と同じ構造です。このため `InterruptedException` 処理の統合テストは不安定になり、追加していません。
- 部分成功 PIT（`pitId != null` かつ `successfulShards < totalShards`）は検出しない。settings 系インデックスは単一シャードのため、現状は実害がありません。
- yellow 待ちが `SuggestSettings`・`AnalyzerSettings`・`ArraySettings` の 3 箇所に重複している点の集約は、後続のリファクタリングで行います。

## レビューしてほしい点

- リトライ対象を `PitUnavailableException` に限定する判断。
- `ArraySettings` へ横展開した判断。`createMappingIfEmpty` の yellow 待ちが早期に返ると、その直後の `settings.array().get(...)` で同じ競合が起こりうるためです。
