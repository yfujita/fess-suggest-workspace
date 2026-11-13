# Pre-phase: PR description (English)

PR description for branch `fix/settings-read-after-concurrent-init` (`modules/fess-suggest`, branched from `main`). Paste the text below. The Japanese version is `0016-pre-phase-pr-description.md`.

---

## Summary

Fixes a race where, when multiple processes/threads call `init()` concurrently, a freshly created settings index is read via PIT and fails with `no shard is available`. This is also the cause of the existing test `SettingsIndexCreationRaceTest#test_concurrentInitOnFreshCluster` failing 5 out of 5 runs.

## Cause

- When 4 threads call `init()` at the same time, a thread that did not create `fess_suggest_analyzer` itself waits only for yellow and then proceeds to read.
- OpenSearch reports a freshly created index whose primary is not yet started as YELLOW, not RED (`ClusterShardHealth.getInactivePrimaryHealth`). The yellow wait therefore returns without waiting for the primary to start.
- PIT allows partial creation, so a response without an ID comes back and `PitOperationHelper.createPit` throws `SuggesterException`.
- `SuggestSettings#getSettingsDocument` already avoids this with a retry on get, but `AnalyzerSettings` had no such safeguard. `ArraySettings` has the same structure.

This can also happen when several fess instances are started at the same time.

## Changes

- Added `PitUnavailableException` (a subclass of `SuggesterException`), thrown by `PitOperationHelper.createPit` when no shard is available. Retry eligibility is decided by type, not by message string. Existing code that catches `SuggesterException` keeps working.
- Added `PitOperationHelper.readWithRetry(client, settings, index, reader)`, using the same approach as `SuggestSettings#getSettingsDocument`.
  - Retries with the interval doubling from 100ms up to 2000ms, using `clusterTimeout` as the deadline. After the deadline, the original `PitUnavailableException` is rethrown.
  - Before each retry, it waits for yellow on the target index again.
  - Only `PitUnavailableException` is retried. Others such as `IndexNotFoundException` propagate as-is.
- Wrapped `getFieldAnalyzerMapping()` in `AnalyzerSettings.init()` and the PIT search in `ArraySettings.getFromArrayIndex()` with `readWithRetry`.
  - `getAnalyzerNames()` only reads the cluster state and does not use PIT, so it is out of scope.

## Behavior changes

- The only change: cases that previously failed by reading a freshly created index during concurrent `init()` now succeed after retries.
- In normal startup without a race, `reader.get()` succeeds on the first attempt, so return values and behavior are unchanged.
- No public API break (only a new exception class is added).

## Tests

- Added
  - `PitOperationHelperTest`: 3 unit tests for `readWithRetry` (succeeds after one retry; rethrows the last exception instance as-is after the deadline; propagates other exceptions without retrying).
  - `ArraySettingsTest`: 1 integration test verifying that `array().get()` retries and returns the correct value when PIT creation fails exactly once.
- Changed: the catch type in `PitOperationHelperTest#testCreatePit_indexWithUnassignedShards` is now `PitUnavailableException`, making the retry-eligibility contract explicit.
- Results
  - `mvn test`: all 722 tests pass.
  - `SettingsIndexCreationRaceTest` run alone 5 times in a row: all pass.
  - `PitOperationHelperTest` and `ArraySettingsTest` run alone 3 times in a row: all pass.

## Known issues (not addressed in this PR)

- `readWithRetry` can exceed `clusterTimeout` by up to one health check. This matches the existing structure of `SuggestSettings#getSettingsDocument`, so it was kept consistent.
- If interrupted during the `actionGet()` of the yellow wait, fesen-httpclient throws `IllegalStateException("Future got interrupted")`, which propagates as-is. `SuggestSettings` has the same structure. An integration test for `InterruptedException` handling would be flaky, so it was not added.
- Partially successful PITs (`pitId != null` and `successfulShards < totalShards`) are not detected. Settings indexes have a single shard, so this has no practical impact today.
- Consolidating the yellow wait duplicated in `SuggestSettings`, `AnalyzerSettings` and `ArraySettings` will be done in a follow-up refactoring.

## Review focus

- The decision to limit retries to `PitUnavailableException`.
- The decision to extend the fix to `ArraySettings`: if the yellow wait in `createMappingIfEmpty` returns early, the immediately following `settings.array().get(...)` can hit the same race.
