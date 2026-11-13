# 事前フェーズ: 設定読み出しの競合修正

## 変更内容

### 1. リトライ対象の見分け方

`PitOperationHelper.createPit` が「PIT 作成時に shard が 1 つも使えない」場合に投げる例外を、`SuggesterException` の専用サブクラス `PitUnavailableException` に変更した。メッセージ文字列の一致ではなく例外の型でリトライ対象を判定できるようにするため。

- 追加: `src/main/java/org/codelibs/fess/suggest/exception/PitUnavailableException.java`
- 変更: `src/main/java/org/codelibs/fess/suggest/util/PitOperationHelper.java:221`（`throw new SuggesterException(...)` → `throw new PitUnavailableException(...)`）
- `PitUnavailableException` は `SuggesterException` のサブクラスなので、既存の `catch (SuggesterException e)`（例: `PitOperationHelperTest.testCreatePit_indexWithUnassignedShards`）は変更なしで動作する。公開 API の破壊はない（既存の型を狭めただけで、新しい公開クラスの追加のみ）。

### 2. リトライ処理

`PitOperationHelper` に `readWithRetry(client, settings, index, reader)` を追加した（`PitOperationHelper.java:244` 付近）。`SuggestSettings#getSettingsDocument`（`SuggestSettings.java:266`）と同じ書き方・命名で揃えた。

- 初回間隔 100ms、最大間隔 2000ms で倍々に伸ばす（`SETTINGS_INDEX_RETRY_INITIAL_INTERVAL` / `SETTINGS_INDEX_RETRY_MAX_INTERVAL` に対応する `PIT_RETRY_INITIAL_INTERVAL` / `PIT_RETRY_MAX_INTERVAL`）。
- `clusterTimeout` を期限にし、期限を過ぎたら元の `PitUnavailableException` を再 throw する。
- リトライ前に対象インデックスの yellow 待ちをもう一度行い、初回リトライ時だけ info ログを出す。
- `InterruptedException` を受けたら割り込みフラグを立てて直前の例外を throw する。
- catch するのは `PitUnavailableException` のみ。`IndexNotFoundException` など他の失敗はそのまま伝播する。

共通化は「PIT 読み出しをリトライで包む」部分だけにし、`PitOperationHelper` という既存の集約点に置いた。yellow 待ち自体の共通化（3 箇所: `SuggestSettings`・`AnalyzerSettings`・`ArraySettings`）はフェーズ 2 の対象として今回は行っていない。

### 3. 呼び出し側の変更

- `AnalyzerSettings.init()`（`AnalyzerSettings.java:161` 付近）: `getFieldAnalyzerMapping()` の呼び出しを `PitOperationHelper.readWithRetry(client, settings, analyzerSettingsIndexName, this::getFieldAnalyzerMapping)` に変更した。`getAnalyzerNames()` は `prepareGetSettings` でクラスタステートから読むだけで PIT を使わないため、`PitUnavailableException` を投げることがなく、リトライ対象にしていない（ラップしても無害だが何もしないラップになるため、わかりやすさを優先して外した）。
- `ArraySettings.getFromArrayIndex()`（`ArraySettings.java:208` 付近）: `PitOperationHelper.search(...)` の呼び出しを同じ `readWithRetry` でラップした。`IndexNotFoundException` の catch はそのまま残した（インデックス自体が存在しない場合はリトライ対象ではない）。

## ArraySettings への横展開の判断

`ArraySettings.createMappingIfEmpty`（yellow 待ちは旧 `ArraySettings.java:341-346`）自体は、待ちの直後に PIT 読み出しを行わない（`preparePutMapping` のみ）。しかし、この yellow 待ちが早期に返ることで「primary 未起動のまま使える」と判定された `ArraySettings` インスタンスは `SuggestSettings` にキャッシュされ、直後に別の経路（`SuggestIndexer` や `ESSourceReader` が `settings.array().get(SUPPORTED_FIELDS)` を呼ぶ箇所、または本テストの `assertSettingsUsable()` の `settings.array().get(...)`）で PIT 読み出しが行われる。したがって `AnalyzerSettings.init` と同じ競合が `ArraySettings.get()` 経由で起こりうると判断し、`getFromArrayIndex` に同じリトライを入れた。

## 挙動の変化

- 変わるのは「複数プロセス/スレッドが同時に `init()` したとき、作成直後のインデックスを PIT で読んで `no shard is available` になっていた `init()` が、リトライの末に成功するようになる」ことのみ。
- 正常起動時（競合がない場合）は `PitUnavailableException` が発生しないため `readWithRetry` は 1 回で `reader.get()` が成功し、戻り値・挙動は変わらない。

## テスト結果

- `mvn formatter:format license:format` 実行後、`mvn test`: **718 件すべて成功**（`SettingsIndexCreationRaceTest` の 6 件を含む）。
- `mvn test -Dtest=SettingsIndexCreationRaceTest` を単独で 5 回連続実行し、**5 回すべて成功**。

| 実行回 | 結果 | 所要時間 |
| --- | --- | --- |
| 1 | 成功 | 65s |
| 2 | 成功 | 62s |
| 3 | 成功 | 61s |
| 4 | 成功 | 62s |
| 5 | 成功 | 63s |

各回のログで、OpenSearch 側が `TransportCreatePitAction` で PIT 作成失敗（`no shard is available`）を 1 回記録した直後に、`readWithRetry` の「A point in time on ... is not available yet, waiting for it」ログが 3〜4 回（5 ラウンド中、競合が発生したラウンド分）出力され、最終的に例外が `init()` まで伝播せずに成功していることを確認した。

## 新規・変更ファイル

- 追加: `src/main/java/org/codelibs/fess/suggest/exception/PitUnavailableException.java`
- 変更: `src/main/java/org/codelibs/fess/suggest/util/PitOperationHelper.java`
- 変更: `src/main/java/org/codelibs/fess/suggest/settings/AnalyzerSettings.java`
- 変更: `src/main/java/org/codelibs/fess/suggest/settings/ArraySettings.java`

テストファイルの変更はない（既存の `SettingsIndexCreationRaceTest` がそのまま通ることを確認した）。
