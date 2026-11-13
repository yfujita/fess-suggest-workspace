# 0012 SettingsIndexCreationRaceTest の失敗調査と計画への反映

## 目的

fess-suggest の `SettingsIndexCreationRaceTest` が通らない件をフェーズ 0 で対応するため、失敗の確認、原因の調査、[work-plan.md](./task_docs/work-plan.md) への反映を行う（ユーザー指示）。

## 対象

fess-suggest `2ccb4f6`（HEAD）、組み込み OpenSearch 3.9.0、fesen-httpclient 3.9.0-SNAPSHOT。

## 実施内容

1. **失敗の確認**: `mvn test -Dtest=SettingsIndexCreationRaceTest` を 5 回実行し、5 回とも失敗した。失敗するのは `test_concurrentInitOnFreshCluster` だけで、ラウンド 2 で 4 回、ラウンド 3 で 1 回失敗した。原因の例外は毎回同じ（`AnalyzerSettings.getFieldAnalyzerMapping` → `PitOperationHelper.createPit` の `SuggesterException: ... no shard is available (total=-1, successful=-1, failed=0)`）。
2. **原因の特定**
   - 同時に init したとき、`fess_suggest_analyzer` を自分で作らなかったスレッドは、yellow 待ち（`AnalyzerSettings.java:155-160`）の後すぐに PIT で読み出す。
   - OpenSearch 3.9.0 の `ClusterShardHealth.getInactivePrimaryHealth` を逆アセンブルして確認した。新規作成（EMPTY_STORE）で primary が未起動の場合、状態は RED ではなく YELLOW を返す。そのため yellow 待ちは primary の起動を待たない。`SuggestSettings` はこの性質を前提に get をリトライしている（`SuggestSettings.java:266` の Javadoc にも記載あり）が、`AnalyzerSettings` にはリトライがない。
3. **仮説の検証**（一時的にコードを変更し、検証後に `git checkout` で元に戻した）
   - `setWaitForActiveShards` / `setWaitForGreenStatus` を試したが、fesen-httpclient の `ClusterHealthRequestBuilder` にこれらのメソッドがなく、コンパイルできなかった（REST パラメータ `wait_for_active_shards` 自体は `HttpClusterHealthAction` に存在する）。
   - `getFieldAnalyzerMapping` を 100ms 間隔でリトライする仮修正では 3 回中 3 回通った。どの回も 1 回のリトライで回復した。

## 結論

原因は、作成直後の `fess_suggest_analyzer` を yellow 待ちだけで読み出していること（テストではなく本体の不具合）。fess を複数台同時に起動した場合にも同じ失敗が起こりうる [推測]。

## work-plan.md への反映

フェーズ 0（安全網）と混ざらないように、独立した**事前フェーズ**として最初に実施する（ユーザー指示）。

- §1 G1: 対象に事前フェーズを加えた。
- §2: Q12（事前フェーズで最初に直す。Q7 の例外とする）を追加した。
- §3: 全体の流れの先頭に事前フェーズを加えた。
- §4: 「事前フェーズ」節を新設し、症状・原因・検証・制約・修正方針・横展開（`ArraySettings`）・変わる挙動・完了条件（単独で 5 回続けて実行し、すべて通る）・担当をまとめた。フェーズ 0 には「契約テストは事前フェーズの修正後の挙動で固定する」とだけ記載した。

## 次の作業

事前フェーズとして、code-implementer がリトライ処理を実装する。リトライ対象の失敗をどう見分けるかは実装時に決める。
