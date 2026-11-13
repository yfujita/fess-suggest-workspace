# 作業プラン: 20260822_implementation（fess-suggest 改善の実装 — **R0 準備リリース ＋ R1 ライブラリ実装**）

> 本書は、要件定義（`0000-requirements-definition.md` 第 2 版 §4）が定めるゴール **「R0 を出せる状態にする ＋ fess-suggest 側の実装を完了させる」** を達成するための作業プランである。
> 設計の正は `docs/0000`〜`docs/0004` の 5 本であり、本書はそれを消費して**実装単位に分解する**ことだけを行う。設計判断を新たに行わない。
>
> **凡例**（`docs/0000-design-overview.md` §3.1 に準拠）: **[確認]** = コード／実物で確認済み ／ **[提案]** = 本書の提案 ／ **[確定]** = 決定済み ／ **[要確認]** = 未解消
>
> **パス短縮表記**: `(sug)` = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` ／ `(sug res)` = `modules/fess-suggest/src/main/resources/` ／ `(sug test)` = `modules/fess-suggest/src/test/java/org/codelibs/fess/suggest/` ／ `(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` ／ `(fess res)` = `modules/fess/src/main/resources/` ／ `(fess test)` = `modules/fess/src/test/java/org/codelibs/fess/`

---

## 0. 概要

> **【2026-08-31 改訂】本書は要件定義 `0000-requirements-definition.md` 第 2 版に合わせて改訂した。**
> **配布・運用モデル（R-P1〜R-P3）が確定し、リリース段が L1 / L2 / L3 から R0 / R1 / R2 に組み替わった**（`0003` 第 14 版 §10.1）。**改訂の全体像と、撤回した項目の一覧は作業履歴 `0011-requirements-revision-release-model.md` にある。**
> **本書に残る `L1` / `L2` / `L3` は第 13 版までの呼称である。読み替えは §0.0。**

**R0（準備リリース）を出せる状態にし、続けて fess-suggest 側の実装を完了させる。**

到達点は次の 4 つである。

| # | 到達点 |
| --- | --- |
| 1 | **R0 が出せる** — フェーズ A（fess 本体側の安全網。A-1 / A-2 / A-3 / A-4 / A-6）が完了している |
| 2 | `modules/fess-suggest` に `api` 4 インタフェース（計 30 メソッド）・`spi` 7 インタフェース・`internal` 実装が揃い、`0002` のデータモデル決定（DM-1〜DM-21）が実装されている。**正式なライフサイクル API（`switchIndexRetainingPrevious` / `rollbackToPrevious` / `aliasState` / `validateNext` / `wordCountStats`）を最初から備える** |
| 3 | 旧 `Suggester` / `SuggestIndexer` が新部品へ委譲する（Strangler Fig 第 2 段完了 — `0001` D-13 / §8.3）。**旧ファサードは R1 では `@Deprecated` で維持し、R2 で除去する**（要件定義 §3.1） |
| 4 | **`modules/fess` を一切変更せずにビルドできる**（旧ファサードの互換性が保たれていることの検査）。**ただしこれは「fess 本体を無変更のまま本番稼働させる」という運用要件ではない** — §0.1 |

**fess 本体の新 API 切り替えと R1 のリリース手順（停止中の移行手順書・G2 の fess 側実装）は後続タスクである。R2（旧ファサード除去 / MIG-05）も後続。**

### 0.0 リリース段の読み替え（**2026-08-31 改訂**）

| 第 13 版までの呼称 | 現在 | 内容 |
| --- | --- | --- |
| **フェーズ A の先行リリース** | **R0** | fess 本体側の安全網のみ。fess-suggest は現行のまま |
| **L1**（fess-suggest だけを先に出す） | **R1 に統合** | — |
| **L1 期間**（新 fess-suggest ＋ 旧 fess 本体） | **消滅** | R-P1 により生じない |
| **L2**（fess 本体を新 API へ） | **R1 に統合** | fess 本体と fess-suggest を同時更新し、停止中に再構築・検証・切替まで行う |
| **L3**（旧ファサード除去） | **R2** | — |

**本書の本文に残る `L1` は、特記が無い限り「fess-suggest 側の実装が完成した状態」＝ R1 に入る成果物と読む。** **`L2` は R1、`L3` は R2 と読む。**

### 0.1 【2026-08-31 撤回】L1 リリースそのものがメジャー移行のトリガーになるという発見

> **本節は前提の変更により役目を終えた。記録として残す。**
> **撤回の理由**: 本節は **L1（fess-suggest だけを先に本番へ入れる段）が存在すること**を前提に、「その直後の最初の SuggestJob がメジャー移行を実行してしまう」という危険を指摘したものである。**R-P1（fess 本体と fess-suggest は常に同時更新する）により L1 という段そのものが無くなったため、この危険は発生しない**（`0003` 第 14 版 §10.1 / §10.6）。
> **分析そのものは撤回しない** — L1 を出す運用に戻る場合、本節の指摘は再び有効になる。**§0 の到達点 4「fess 本体を無変更でビルドできる」は、本節が否定した「fess 本体を無変更のまま本番稼働させてよい」という読み方とは別物である。前者はビルドレベルの互換性検査にすぎない。**
> **本節が導いた対処のうち、M-1（デプロイ直後の即時再構築）・M-6 / A-5（暫定 `.prev`）・K-19 は撤回した。G1 / G3 の R0 への配置（A-3）は維持する** — 平常時の日次再構築にも効くためである。

> **以下は撤回前の記述である（記録）。**

> **`0003` §10.1 L813 の「メジャー移行そのもの（`0002` §4.7 の再構築）は L2 以降にしか起きない」は成立しない** [確認]。
> **「L1 は fess 本体無変更で安全に出せる」という設計書の読み方は、実態と異なる。**

**根拠**（すべて実物で確認済み）:

| # | 事実 | `file_path:line` |
| --- | --- | --- |
| 1 | `SuggestCreator.create()` は**毎回が全件再構築**である（次世代作成 → 語の再投入 → 切替） | `(fess) exec/SuggestCreator.java:252` `suggestHelper.suggester().createNextIndex();` ／ `:255` `suggestHelper.storeAllBadWords(true);` ／ `:258` `suggestHelper.storeAllElevateWords(true);` ／ `:298` `suggestHelper.suggester().switchIndex();` |
| 2 | `createNextIndex()` は**新バイナリ同梱の mapping** をクラスローダから読む | `(sug) Suggester.java:238` `final String mappingSource = getDefaultMappings();` |
| 3 | Suggest Indexer ジョブは**既定で日次・有効**である | `(fess res) fess_indices/fess_config.scheduled_job/scheduled_job.bulk:4` — `{"name":"Suggest Indexer","cronExpression":"0 12 * * *", ... ,"available":true}` |

**帰結**:

1. `0002` §4.7 が「1 回の再構築に束ねる」とした 4 変更（ID ハッシュ化 / 語数上限 N / `ElevateWord` 格納形 / mapping 変更）は**すべて fess-suggest 側の成果物**であり、fess 本体側の変更を 1 つも含まない。したがって **L1 デプロイ後、最初の SuggestJob 実行（既定で最大約 1 日）がメジャー移行を実行する。** L2 が追加するのはガード（G2 / `.prev` 保持 / `wordCountStats` への移行）だけである。
2. **MO-22（メジャー移行時は G2 必須）が空振りする。** G2 は fess 側が `validateNext` を呼んで初めて動くが、L1 時点の fess 本体は無変更であり呼ばない。**`.prev` 保持も無いため、切り替わってしまった後の戻り先が無い。**
3. **フェーズ A で先行リリースする G1 / G3 ガードが、唯一の実効的な安全網である**（§3.2）。**フェーズ A が本番に入る前に L1 をリリースしてはならない**（§5.5）。

**詳細な分析は §7.3、採用した緩和策は §7.5（M-1 ＋ M-5・決定済み）、設計書への反映はステップ 0-4 にある。**

---

## 1. 前提・スコープ

### 1.1 本プラン作成時に確定した決定（Q1〜Q12）

プラン作成の前段でユーザーに確認し、確定した事項である。**本書の全ステップはこれを前提にしている。**

| # | 決定 | 影響する節 |
| --- | --- | --- |
| **Q1** | fess 本体側 3 点（`(fess) helper/SuggestHelper.java:464-487` の見直し ＋ `0003` §10.4 のバッチ停止対処）は **L1 より前に先行リリース**する | フェーズ A |
| **Q2** | `api` 4IF ＋ `spi` 7IF ＋ `internal` 実装 ＋ **旧ファサードの委譲まで L1**（第 2 段完了） | フェーズ B〜E |
| **Q3** | データモデル変更（DM-3 / DM-8 / DM-10 / DM-14）は**全部 L1 に同梱**。ただし §7 の L1 中間状態の論点を処理する | フェーズ C ／ §7 |
| **Q4** | `0003` MO-2 の切替可否ガード（G1 / G3）を**含める**。フェーズ A に束ねる | フェーズ A |
| **Q5** | `0002` §7 の T-1〜T-24 全件 ＋ fess-suggest 側 T-S/T-R ＋ 既存テストの改修 | フェーズ F |
| **Q6** | 設計書の**事実誤り**は軽微改訂（値・行番号のみ更新、版は上げない）＋ 作業履歴に記録 | ステップ 0-3 |
| **Q7** | **`agent_docs/tasks/20260822_implementation/docs/` を正本**とし、`20260706_design_document/docs/` は**凍結**（改訂しない） | §2.3 |
| **Q8** | 作業ブランチを切り、**ステップ単位でコミット** | §2.4 |
| **Q9** | 作業履歴は**フェーズ単位で 1 ファイル**。**逸脱手続きの発火は必ず独立した 1 ファイル** | §9 |
| **Q10** | DoD は「fess-suggest で `mvn test` 全緑 ＋ fess 本体を無変更でビルドできる」。検証は**ステップ内は該当パッケージのみ／フェーズ末で全件**の二段構え | §8 |
| **Q11** | `(fess test)` に「`(fess res) suggest_indices/suggest.json` が存在しない」ことを assert するテストを置く ＋ `(sug res)` 側 JSON に `"_comment"` を残す | ステップ A-6 / C-3 |
| **Q12** | 旧 `Suggester.builder()` は `Suggester` を返すまま維持し、`SuggestComponents` を得る入口を**別メソッドとして追加**。併せて **`0001` を第 9 版として改訂** | ステップ 0-2 / D-8 |

**加えて、本プラン初版の作成後に確定した決定が 3 件ある**（2026-08-24）。

| # | 決定 | 反映先 |
| --- | --- | --- |
| **U-1** | L1 中間状態の緩和策は **M-1（デプロイ直後の即時再構築を手順化）＋ M-5（残る窓を K-19 として記録）** | §7.5 ／ ステップ 0-4 |
| **U-2** | `(fess res)` 側 3 ファイルの `number_of_replicas` 削除は **フェーズ A（先行リリース）に移す** | ステップ A-4 ／ §3.2 の P-05 |
| **U-3** | `SuggestIndexer` の setter 9 件は **no-op ＋ 警告ログ** | ステップ E-3 |

**さらに 2026-08-31、配布・運用モデルの確定に伴う決定が 3 件ある**（要件定義 `0000` 第 2 版）。**決定者はいずれもユーザー、決定日は 2026-08-31 である。**

| # | 決定 | 反映先 |
| --- | --- | --- |
| **U-8** | **配布・運用モデル R-P1〜R-P3 を確定した**（fess 本体と fess-suggest は常に同時更新 ／ 更新時のサービス停止を許容 ／ **停止中に再構築の完走・検証・切替まで実施できる**）。**リリース段を R0 / R1 / R2 に組み替える** | §0 / §0.0 / §5.5 ／ `0003` 第 14 版 §10.1（**MO-26**） |
| **U-9** | **旧 `Suggester` / `SuggestIndexer` ファサードは R1 では `@Deprecated` で維持し、R2 で除去する。** `modules/fess-suggest` は公開 artifact であるため（`modules/fess-suggest/pom.xml:92-103`）1 リリースぶん猶予する | フェーズ E は**変更なし**。X-1 の対処（`build(...)` が `Suggester` を返す）も**維持する** |
| **U-10** | **本タスクのゴールは「R0 を出せる状態にする ＋ fess-suggest 側の実装を完了させる」。** fess 本体の新 API 切り替えと R1 のリリース手順は**後続タスク** | §0 / §1.2 |

**これに伴い、既存の決定のうち 3 件が影響を受ける** [確定]。

| # | 従前 | 現在 |
| --- | --- | --- |
| **Q1 / Q4** | fess 本体側の 3 点とガード G1 / G3 は **L1 より前に先行リリース** | **維持する。** 「先行リリース」を **R0** と呼び替えるだけである（理由は `0003` 第 14 版 §10.1 の「なぜ R0 を分けるのか」） |
| **U-1**（M-1 ＋ M-5） | L1 デプロイ直後の即時再構築を手順化し、残る窓を K-19 として記録する | **撤回する。** 窓が生じる区間（L1 期間）が消滅した（§7 / `0003` 第 14 版 §12 の K-19） |
| **U-7**（M-6 / ステップ A-5） | fess 側 alias 操作による暫定 `.prev` をフェーズ A に先行させ、L2 で撤去する | **撤回する。** R1 では最初から正式 primitive（`switchIndexRetainingPrevious()`）を使う。**ステップ A-5 は削除**（§4 / §7.5.1） |

> **U-2（`(fess res)` 3 ファイルの `number_of_replicas` 削除をフェーズ A に移す）は維持する** [確定]。**R1 へ戻すことも可能だが、`auto_expand_replicas` により実効挙動が変わらない**（`0003` §8.2 が実機確認済み）ため、**R0 に置いたままにして DM-6 を早く閉じる。** 判断の理由は `0011` §4。

### 1.2 スコープ

**対象**（fess-suggest 側 = **R1 で出す本体**）:

- `0001` の `api` 4 インタフェース（30 メソッド）・公開 DTO・`spi` 7 インタフェースと補助型・非同期／例外契約・設定 API・権限集約・旧ファサード委譲設計
- `0002` の全決定（DM-1〜DM-21）。mapping・index settings・決定的 ID・マージ規則・旧世代共存
- `0003` のうち **fess-suggest 側に実装が要るもの**: エイリアス primitive（`switchIndexRetainingPrevious` / `rollbackToPrevious` / `aliasState` / `createNextIndex` の post-condition 判定）・`validateNext`・`wordCountStats`・`RefreshInterval` / `updateRefreshInterval`・`IndexSchema`・`IngestOptions.refreshPolicy`・refresh 戦略の (a)(b)

**対象**（fess 本体側 = **R0 で先に出すもの**。Q1 / Q4）:

- `(fess) helper/SuggestHelper.java` の elevate word 入力正規化（`0003` §10.3 の 3）
- `(fess) helper/SuggestHelper.java` に **`storeAllElevateWordsForRebuild()` / `storeAllBadWordsForRebuild()`（再構築専用の内部経路）を設け、その行単位ループに失敗隔離を入れて失敗行数を返す**（`0003` **第 13 版** §10.4 / **MO-25**）。**public 3 メソッド（`storeAllElevateWords(boolean)` / `deleteAllElevateWord(boolean)` / `storeAllBadWords(boolean)`）は `void` の fail-fast のまま変えない**（**X-6 の是正**。管理画面・API の例外契約を壊さないため）
- `(fess) exec/SuggestCreator.java` で **上記の失敗行数を `exitCode` へ合流させる**（**A-3 の責務**。`0003` §10.4 (j)）
- `(fess) exec/SuggestCreator.java` の切替可否ガード G1 / G3（`0003` MO-2 / MO-18 / §4.3）
- 上記に対応する fess 本体側テスト（T-F2 の一部 / T-F3）＋ Q11 の assert テスト

**スコープ外**:

| # | 項目 | 理由 |
| --- | --- | --- |
| 1 | **fess 本体 main 4 クラスの新 API 切り替え**（`0001` §9。旧 L2） | **後続タスク**（U-10）。**R1 の構成要素だが、本タスクのゴールには含めない** |
| 2 | **旧ファサード除去 / MIG-05**（旧 L3） | **R2**。U-9 により R1 では `@Deprecated` で維持する |
| 3 | **G2 の fess 側実装**（検証語の設定キー・メジャー移行フラグ・自動採取。`0003` §4.2.3 / §13 の 12・13） | fess 側の実装であり**後続タスク**。**ライブラリ側の受け口 `validateNext` は本タスクで作る**（D-6）。**【2026-08-31】R1 では G2 が最初のメジャー移行から必須になる**ため（`0003` 第 14 版 §4.2.3）、**後続タスクの必須項目として申し送る**（§10.3） |
| 4 | **T-F1 / T-F4**（`0003` §11.3） | fess 本体側／実クラスタ必須。**後続タスク**（R1 の検証） |
| 5 | **`knn_vector` の実装**（`0003` §9） | P5 により予約のみ。Phase 4 |
| 6 | **MIG-15 第 2 段（`scripted_upsert`）** | `0001` D-31 が「その段で改めて設計する」と明記 |
| 7 | **K-1（楽観ロック）の解消** | `0002` §4.6 / §8。MIG-15 第 2 段で一括 |
| 8 | **性能実測**（C-04。`0003` §13 の 5、`0002` §6.4） | 後続タスク |
| 9 | **`0003` §13 の 3・4・6・8・11・14** | いずれも後続タスクまたは fess 側運用作業と明記されている |

### 1.3 ビルド前提 [確認]

`0003` §10.5 が記す不整合は**すでに解消している**。本プラン作成時に実物で確認した。

| 項目 | 現在値 | 根拠 |
| --- | --- | --- |
| fess 本体 | `15.9.0-SNAPSHOT` | `modules/fess/pom.xml:5` |
| `suggest.version` の実値 | `15.9.0-SNAPSHOT` | `~/.m2/repository/org/codelibs/fess/fess-parent/15.9.0-SNAPSHOT/fess-parent-15.9.0-SNAPSHOT.pom:54` |
| fess-suggest モジュールの実体 | `15.9.0-SNAPSHOT` | `modules/fess-suggest/pom.xml:5` |
| 依存宣言 | `${suggest.version}` | `modules/fess/pom.xml:1424` |
| OpenSearch | **3.8.0**（設計書の記載は 3.7.0） | `fess-parent-15.9.0-SNAPSHOT.pom:60` |
| Java | 21 | 同 pom の `maven-compiler-plugin` `<release>21</release>` |

> **`0003` §10.5 が推奨する「fess 側 `<properties>` で `suggest.version` を上書きする」措置は不要である。** 3 者が同一バージョンなので、`modules/fess-suggest` で `mvn install` すれば `modules/fess` がそれを拾う。**ただし `~/.m2/repository/org/codelibs/fess/fess-suggest/` に `15.9.0-SNAPSHOT` はまだ存在しない**（最新は `15.7.0`）[確認] ため、フェーズ末の検証前に必ず `mvn install` が要る。
>
> OpenSearch 3.8.0 は `0003` §6.3 の前提（2.16 以上）を満たす。`dynamic: "strict_allow_templates"` は使用可能である。

### 1.4 現行コードの実体 [確認]

本プラン作成時に調査した、実装に直接効く事実である。

| # | 事実 | 根拠 |
| --- | --- | --- |
| 1 | `Suggester` の public メンバは 18 件、`SuggestIndexer` は 30 件 | `(sug) Suggester.java:138-440` ／ `(sug) index/SuggestIndexer.java:174-541` |
| 2 | `readings` の走査基準が **3 箇所で不揃い**。`toSource` / `toUpdatedSource` は `readings.length`、`fromSource` は「存在する限り」の無限ループ、`SuggestItemMerger` は **text の split 語数** | `(sug) entity/SuggestItemSerializer.java:60,147,87-95` ／ `(sug) entity/SuggestItemMerger.java:70` |
| 3 | `ElevateWord.toSuggestItem()` は `readings.size()` を第 1 次元長とし、`text` は 1 要素配列固定。**これが INV-1 を破る実体** | `(sug) entity/ElevateWord.java:143-149` |
| 4 | `score` は `SuggestItem` のフィールドではなく、書き込み時に `(queryFreq + docFreq) * userBoost` として導出されるだけ。**検索側は一切参照していない** | `(sug) entity/SuggestItemSerializer.java:73,182` ／ `(sug) entity/SuggestItem.java:360` |
| 5 | 現行 mapping に**トップレベル `dynamic` キーが無い**（＝既定 `true`）。`score` は `double` で実在、`reading_*` の明示マッピングは無い | `(sug res) suggest_indices/suggest/mappings-default.json:2-12,36-38` |
| 6 | ID は `Base64(text)` を 445 文字で切り詰める方式 | `(sug) util/SuggestUtil.java:68,84-90` |
| 7 | `mvn test` は profiles を持たず**全テストを無条件実行**。**51 テストクラス中 24 が in-JVM で OpenSearch ノードを起動**する | `modules/fess-suggest/pom.xml`（`<profiles>` 無し）／ `opensearch-runner` は `scope=test`（`:145-150`） |
| 8 | `(sug) request/suggest/SuggestRequest.java` は `excluded` フィルタを持たない。`PopularWordsRequest` は `excludeWords`（完全一致）のみ持つ | `SuggestRequest.java:346-374` ／ `PopularWordsRequest.java:210-236` |
| 9 | fess 本体が実際に触れる fess-suggest の public 表面は狭い。**まったく使われていない**のは `new Suggester(...)` / `shutdown()` / `getReadingConverter()` / `getNormalizer()` / `SuggestIndexer` の setter **9 種全部** / `indexFromQueryLog` / `new SuggestItem(...)` / `getReadings()` — **すべて該当 0 件** | `modules/fess` 全体の grep [確認] |
| 10 | 逆に fess 本体が依存しているのは `Suggester.builder()`（1 箇所）/ `indexer()`（11 箇所）/ `settings()`（6 箇所）/ `ElevateWord` コンストラクタ（1 箇所）/ `SuggestItem.Kind`（9 箇所）/ `SuggestUtil.deleteByQuery`（2 箇所）ほか | 同上 |
| 11 | **fess 本体のテストは回帰検知能力を持たない**。`SuggestHelperTest` は `suggester` が null のまま全例外を握り潰す構造で常に緑（`:71` が `assertNull` を期待）、`SuggestCreatorTest` の `create()` テストは中身が空、ハンドラ系は 400/500 を許容 | `(fess test) helper/SuggestHelperTest.java` ／ `(fess test) exec/SuggestCreatorTest.java:180-257` ／ `0003` MO-13 |

---

## 2. 運用ルール

### 2.1 逸脱手続き（要件定義の要求）

> 実装中に**設計の誤り・不足**を発見した場合、黙って実装で吸収しない。**該当設計書の改訂（版追記＋変更理由）を先に行い、作業履歴に記録してから実装する。**

本プランではこれを次のとおり運用する。

| 区分 | 判定基準 | 手続き | 記録先 |
| --- | --- | --- | --- |
| **区分 I: 設計判断の誤り・不足** | 設計書どうしが矛盾する／設計どおり実装すると成立しない／L1 という状態が扱われていない | **版を上げて改訂**（改訂履歴に版・日付・変更・変更理由を追記）→ 作業履歴に独立ファイルで記録 → **その後で実装** | `0002-*` 以降の**独立した作業履歴ファイル** |
| **区分 II: 事実の更新（[確認] 記述と実物の差）** | 設計判断ではなく観測値（バージョン・行番号・ファイル数など）が変わった／誤っていた | **軽微改訂**（該当箇所の値のみ更新。版は上げない）→ 作業履歴に記録 | フェーズの作業履歴ファイル内の 1 節（**Q6=(B)**） |

**判定に迷ったら区分 I として扱う。** 区分 II は「設計の内容が変わらないこと」を積極的に示せる場合に限る。

**実装中に新たな逸脱を発見した場合も同じ手続きを踏む。** 該当ステップを中断し、改訂ステップを挿入してから再開する。**改訂せずに実装を進めてはならない。**

### 2.2 確定している逸脱（発火 8 件・すべて確定）

**X-1 / X-2 / X-3 は本プラン作成時点で特定したものであり、X-4 / X-5 / X-6 / X-7 / X-8 は実装フェーズで発火したものである**（X-4 は A-1 の実装中、X-5 は A-2 の着手時、**X-6 は A-2 の実装に対する外部レビュー**、**X-7 は A-3 の着手可否判定**、**X-8 はフェーズ A 全体に対する外部レビュー（`0018` §2）**）。**後者も §2.1 と同じ手続き（改訂 → 記録 → 実装）で処理する。**

> **X-5 と X-6 は同じ MO 番号（MO-25）を対象とする** [確認]。**X-6 は MO-25 の規則 3・6 の是正であり、新しい MO 番号は起こさない**（判定は `0010` §1.2）。**MO-24 が 1 つの X 番号（X-4）で第 10 版・第 11 版の 2 版にまたがったのとは逆の対応である。**
>
> **X-8 も同様に新しい MO 番号を起こさない** [確認]。**MO-2 の内部（不合格時の行動）の改訂であり、新しい設計判断を追加していない**（判定は `0019` §2）。

| # | 内容 | 区分 | ステップ |
| --- | --- | --- | --- |
| **X-1** | **`SuggesterBuilder.build(...)` の戻り値型矛盾**（`Suggester.builder()` 自身の戻り値は `SuggesterBuilder` であり、問題はその先の `build(...)` にある）**。** `0001` §3.9（L1370・L1392）が `build(...)` の戻り値を `SuggestComponents` に変えるとする一方、同 §8.3（L1837-1838）は「旧クラスは public シグネチャを 1 つも変えない」、`0003` §10.1 / C-01 は「L1 では fess 本体は無変更で動く」とする。`(fess) helper/SuggestHelper.java:142` が `Suggester` 型フィールド（`:86`）へ代入しているため、**設計どおりに実装するとコンパイルエラーになる** [確認] | **区分 I** | **0-2** |
| **X-2** | **`0003` の [確認] 記述 2 件が実物と食い違う。** (a) §10.5 のビルド前提（§1.3 のとおり不整合は解消済み・OpenSearch は 3.8.0）、(b) MO-9 / §8.2 の挿入位置（`(fess res) fess_config.properties:591` は `index.field.digest` で suggest と無関係。正しくは **`:639` の直後**、同型例は **`:643-653`** の crawler 系）[確認] | **区分 II** | **0-3** |
| **X-3** | **L1 中間状態（新バイナリ ＋ 旧世代インデックス ＋ 旧 fess 本体）の扱いが設計書に無い** ＋ **`0003` §10.1 L813「メジャー移行は L2 以降にしか起きない」が誤りである**（§0.1 / §7）。前者は 2 つの穴として現れる — 穴 1: 新 ID バイナリが旧世代へ書き込む期間が未定義 ／ 穴 2: `0002` §5.6 の前提が旧世代ドキュメントに成立しない | **区分 I** | **0-4** |
| **X-4** | **elevate word の「語テキスト」が入力であると同時にドキュメント `_id` の生成キーでもあることを `0003` §10.3 が扱っていない。** A-1 の作業内容 2（`word` 側も trim・正規化する）を入れると、**追加経路が正規化キーで書き、削除経路が生キーで消す**という非対称が生まれ、**管理画面から削除しても suggest ドキュメントが残る**（`(fess) helper/SuggestHelper.java:438` / `:450` が生の DB 値を渡す一方、`(sug) entity/SuggestItem.java:140` と `(sug) util/SuggestUtil.java:91-97` により `_id` は語テキストから決まる）[確認]。**対処は MO-24**（add/delete に同じ正規化 ＋ 移行期は新旧両キーで削除）。**【2026-08-31 追記】本件の改訂は `0003` 第 10 版と第 11 版の 2 回にまたがる。** 第 11 版は A-1 実装レビューを受けた**追補改訂（区分 I。MO-24 の決定そのものは不変で、(d) の規則 3 の安全性根拠の不足を是正したもの）**であり、**新しい X 番号は起こしていない**（記録は `0008` §2.5） | **区分 I** | **A-1（実装中に発火）** ／ **追補は A-1 のレビュー反映（`0008`）** |
| **X-5** | **`0003` §10.4 が定める失敗隔離の対処範囲が「追加フェーズ（`SuggestItem` 化）の変換失敗」に狭められており、`storeAllElevateWords` が最初に駆動する削除フェーズを勘案していない。** `storeAllElevateWords`（`(fess) helper/SuggestHelper.java:411`）は本体ループの前に `deleteAllElevateWord(apply)`（`:412`）を呼び、**同じ DB 行集合を 2 周する**。`getSuggestWord()` は不正行に対して `null` を返しうるため（`(fess) opensearch/config/bsentity/BsElevateWord.java:190-193` の `convertEmptyToNull`）、**削除フェーズは `:445` → `:552` の `normalizeSeparators` で NPE になり、追加ループのスキップ機構に到達しない** [確認]。**§10.4 の対処方針を字義どおり実装しても「再構築全体が失敗するのを防ぐ」は成立せず、A-2 の DoD 1 も満たせない。** さらに**追加フェーズにも `SuggestItem` 化以外の失敗点がある**（`boost` の `Float` → `float` アンボクシング — `(fess) helper/SuggestHelper.java:527` ／ `(sug) entity/ElevateWord.java:66-67`）[確認]。**この穴は A-1 が持ち込んだ回帰ではなく §10.4 執筆時点から存在した**（A-1 以前は `(sug) util/SuggestUtil.java:92` で NPE）が、**A-1 は落ちる呼び出し元を `apply = false` の管理画面経路にも広げている** [確認]。**対処は MO-25**（`storeAll*` が駆動するすべての行単位ループに失敗隔離を適用 ＋ 失敗件数は削除・追加フェーズの合算 1 つ ＋ `storeAllBadWords` の削除フェーズは行単位ループを持たないため対象外） | **区分 I** | **A-2（着手時に発火）** |
| **X-6** | **`0003` 第 12 版の MO-25 が 2 つの誤った設計判断を含んでいた。** **(1) 規則 3（集計単位）**: 「削除フェーズと追加フェーズの合算＝項目処理数」とし、1 件の不正行が 2 件と数えられることを仕様としていた。その根拠 §10.4 (f) の 1〜3 は「フェーズ別に 2 つの数を返す案」の否定にしか効かず（**G3 が件数を 0 / 非 0 の二値としてしか使わないという事実は「合算でよい」ことの根拠であって「合算が良い」ことの根拠ではない**）、(f) の 4「行数案は行を突き合わせる鍵が `suggestWord`（まさに `null` になる値）であるため実装できない」は**事実誤認**であった — **鍵は `getId()` である** [確認]（`(fess) opensearch/config/exentity/ElevateWord.java:92` ／ `(fess) opensearch/config/exentity/BadWord.java:27` はいずれも `asDocMeta().id()` を返し、`selectList` が検索ヒットの `_id` から設定する — `(fess) opensearch/config/allcommon/EsAbstractBehavior.java:166` / `:207` / `:230`）。**(2) 規則 6（適用範囲）**: 失敗隔離を public メソッドのループ本体に置き「管理画面の経路にも及ぶ。これは受け入れる」としていたが、**同期 4 経路（`(fess) app/web/admin/elevateword/AdminElevatewordAction.java:372-391` ／ `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:171-186` ／ `(fess) app/web/admin/badword/AdminBadwordAction.java:341-357` ／ `(fess) app/web/api/admin/badword/ApiAdminBadwordAction.java:148-162`）では例外が `throwValidationError(Api)` に変換されて運用者に届いており、それが唯一の異常検知手段である** [確認]。隔離すると 200 OK ＋ 成功メッセージを返す。**A-2 の目的（SuggestJob の全件再構築を止めない）に管理画面のエラー契約の変更は含まれない。** **対処は MO-25 の改訂**（規則 3 = **失敗した行の数。行 ID で dedupe** ／ 規則 6 = **失敗隔離は再構築専用の内部経路（`storeAllElevateWordsForRebuild()` / `storeAllBadWordsForRebuild()`）に限定し、public 3 メソッドの挙動は fail-fast のまま変えない**）。**新しい MO 番号は起こさない**（`0010` §1.2）。**あわせて `(fess) exec/SuggestCreator.java:255` / `:258` の 2 行を `ForRebuild` の呼び出しへ切り替える**（切り替えないと `ForRebuild` は A-3 まで dead code になり A-2 単独で目的が達成されない — `0003` 第 13 版 §10.4 (j)）。**dedupe により A-2 の DoD が元の「失敗件数 1」（等値）で閉じられる** — 第 12 版が「1 以上」へ緩めたのは撤回する（**曲げるべきだったのは実装であって DoD ではなかった** — `0010` §2.4） | **区分 I** | **A-2（実装に対する外部レビューで発火）** |
| **X-7** | **`0003` §4.2 の G1 が「次世代の件数」の取得方法として `getAllWordsNum()` を指定していたが、同 API では次世代を数えられない。** `getAllWordsNum()` は `getNum()` へ委譲し（`(sug) Suggester.java:424-426`）、`getNum()` は **`setIndices(getSearchAlias(index))`** で検索する（`:444-453` の `:446`）。**`getSearchAlias` は素のインデックス名を返し（`:455-457`）、次世代は更新エイリアス `index + ".update"`（`:459-461`）側にある** — `createNextIndex()` は更新エイリアスだけを付け替え検索エイリアスに触れない（`:263` / `:265`）[確認]。**G1 の判定位置は `switchIndex()` の前であり、その時点で検索エイリアスは旧世代を指したままである。** 字義どおり実装すると**新旧どちらも旧世代の件数**になり、比は常に 100%、**G1 は無条件合格の no-op になって本ステップの DoD「次世代件数 0 で切替が中止される」を満たせない**（A-6 の T-S2 相当テストも書けない）。**`0003` §4.2 は G2 については初版から「更新エイリアスに対して実行する」と明記していたが、G1 の行にはエイリアスの別が 1 語も無かった。** **対処は MO-27 の新設**（**次世代の件数は更新エイリアスに対して数える**。R0 は fess 側で `suggester.getIndex() + ".update"` を `SearchEngineClient` により直接数え、R1 で `lifecycle.wordCountStats()` へ移す）。**fess-suggest にカウント API を追加する案は R0 の定義（fess 本体のみ）を破るため却下、G1 を落として G3 のみで出す案は実装可能な代替があるのに DoD を緩めるため却下**（`0007` §2.11 の 8）。**あわせて「旧世代が存在しない初回」の判定条件が「エイリアス不在」ではなく「旧件数 0」であることを明記した**（`createIndexIfNothing()` が `SuggestHelper` の初期化時に走るため検索エイリアスは常に存在する）。**検出は `0015` §3、決定は 2026-09-04、記録は `0016`** | **区分 I** | **A-3（着手可否判定で発火）** |
| **X-8** | **`0003` MO-2 がガード不合格時の行動を「切替と `removeDisableIndices()` を実行せずに終了する」と 1 つに束ねており、`removeDisableIndices()` のもう 1 つの責務（孤児インデックスの回収）を勘定に入れていなかった。** この束ね方が防いでいるのは **D-b**（`0003` §1.3 = 切替直後にエイリアス 0 個になった旧世代を消してロールバック先を失う障害）だけであり、**D-b は切替が走った後にしか成立しない** [確認]。一方 **`removeDisableIndices()` の呼び出し元は `(fess) exec/SuggestCreator.java` の 1 箇所しか無く**（`0003` §3.4 ／ §4.3 の根拠 1 ／ `0003-deviation-x3-l1-interim-state.md` §3）、**不合格時にこの 1 行を飛ばすことは回収機構そのものを止めることと同義である。** `createNextIndex()` は実行のたびに無条件で次世代を作り更新エイリアスを移すため（`(sug) Suggester.java:235-267`）、**ガードが不合格を返し続ける間は実行のたびに前回の次世代がエイリアス 0 個の孤児となり、回収されないまま単調増加する** [確認]。**これは例外的な状況ではなく、`0003` §4.2.2 が「不正行を運用者が直すまで世代を更新させない」と意図した状況そのものである。** **対処は MO-2 の改訂**（**ガード不合格時も `removeDisableIndices()` を実行する**。切替の時点では旧世代も次世代もエイリアスを持ち削除判定（`(sug) Suggester.java:338-359`）に掛からないため安全 — `0003` §4.3.1 を新設）。**`SuggestAliasStateUnknownException` の経路では従来どおり呼ばない**（K-18 / T-S12。2 つの経路は排他である — `0019` §4.1）。**現状維持のまま記述訂正と運用周知で閉じる案（区分 II）は、`removeDisableIndices()` を単独で叩く経路が無く運用者に手当ての手段が無いため却下**（`0019` §3）。**新しい MO 番号は起こさない。** **検出は `0018` §2、決定は 2026-09-07（ユーザー判断）、記録は `0019`** | **区分 I** | **A-3 / A-6（フェーズ A 全体の外部レビューで発火）** |

### 2.3 設計書の正本（Q7）

**正本は `agent_docs/tasks/20260822_implementation/docs/` の 5 本である。** 改訂はここだけに行う。

`agent_docs/tasks/20260706_design_document/docs/` の同名 5 本は**執筆当時のスナップショットとして凍結**し、**一切変更しない**（現時点で両者はバイト単位で同一 [確認]）。本プランの改訂により両者は乖離するが、それは意図した状態である。この方針を `0000-design-overview.md` §3.5（参照規律）の近傍に 1 行追記する（ステップ 0-3 に含む）。

### 2.4 git 運用（Q8）

| 項目 | 内容 |
| --- | --- |
| ブランチ | `modules/fess-suggest`: `feature/suggest-l1` ／ `modules/fess`: `feature/suggest-l1-precede`（フェーズ A 用） |
| 起点 | 両モジュールとも現 HEAD（fess-suggest `5e9d2f9` / fess `d6d6914ff`）。作業ツリーは clean [確認] |
| コミット粒度 | **ステップ 1 つにつき 1 コミット。** ステップの DoD を満たしてからコミットする |
| 逸脱手続き | **設計書の改訂は実装より前のコミットにする。** git 履歴で「改訂 → 実装」の順序が追えること自体が手続きの証跡になる |
| 設計書・作業履歴 | ワークスペース直下は git 管理外 [確認] のため、`agent_docs/` の変更はコミット対象外。作業履歴ファイルの更新で追跡する |

---

## 3. スコープ境界表（**2026-08-31 改訂** — 旧「L1 スコープ境界表」）

**設計書から機械的に洗い出した、「R1 で出す fess-suggest 側の成果物／ R0 で先に出すもの／後続タスクへ送るもの」の 3 分類である。** 本表がステップ分解の根拠になる。

### 3.1 分類 1: 本タスクで実装する（fess-suggest 側 — **R1 で出す**）

> **【2026-08-31】下表の項目 ID `L1-01`〜`L1-40` は本書内の通し番号であり、リリース段の呼称ではない。** 混乱を避けるため番号自体は変更しない（他文書からの参照があるため）。**これらはすべて R1 で出す fess-suggest 側の成果物である。**

| # | 要素 | 根拠（決定番号 / 節） | ステップ |
| --- | --- | --- | --- |
| L1-01 | `api` 4 インタフェース・計 30 メソッド | `0001` D-1 / §2 | B-6 |
| L1-02 | 公開 DTO 全型（`SuggestQuery` / `PopularWordsQuery` / `SuggestResult` / `IndexGeneration` / `WordCountStats` / `WordOpResult` / `BadWordImpact` / `IngestOptions` / `RefreshPolicy` / `SearchWordInput` / `IngestResult` / `DeleteResult` / `AliasState` ほか） | `0001` §2.5 / §2.6 | B-4a |
| L1-03 | **3 型分離**（`SuggestCandidate` / `SuggestItem` / `SuggestHit`） | `0001` D-19 | B-4a / **B-4b** |
| L1-04 | **DTO の不変化**（`final class` ＋ private ctor ＋ 不変コレクション。`float[]` は clone） | `0001` D-20 | B-4a / **B-4b** |
| L1-05 | **`SuggestKind` を `api` のトップレベル enum へ**（`api` → `entity` の逆依存の解消） | `0001` D-33 | B-2 |
| L1-06 | `spi` 7 インタフェースと補助型（`SourceContext` / `ScoringContext` / `ScoringPlan` / `ScoringFactor` 4 種 / `ProcessedText` / `TextProcessingContext` / `QueryCondition` ＋ 5 述語） | `0001` §3 | B-3 / B-7 |
| L1-07 | **例外階層**（`SuggestAuthorizationException` 新規 / `SuggestAliasStateUnknownException` 新規 / `SuggestSettingsException` の親変更） | `0001` §4.5 | B-1 |
| L1-08 | **`CompletableFuture` 一本化**と完了スレッド契約（構築時 `ExecutorService` へディスパッチしてから complete） | `0001` D-3 / §4.4 | D-6 |
| L1-09 | **部分失敗を例外にしない**（`IngestResult.failures` / `DeleteResult.failures`） | `0001` D-4 / §4.3 | D-5 |
| L1-10 | 設定 API 拡張（時間 6 種 × 2 形 ＝ 12 メソッド ＋ `numberOfShards` / `autoExpandReplicas` / `refreshInterval` / `indexSchema()`） | `0001` D-9 / D-10 / §6 | B-5 |
| L1-11 | `IndexSchema` / `RefreshInterval`（`Every` / `Disabled` の sealed interface） | `0001` D-18 / §6.2 | B-5 |
| L1-12 | 権限集約（`AuthorizationFilter` へ一本化・**デフォルト deny 維持**） | `0001` D-11 / §7 | D-3 |
| L1-13 | レスポンスのフィールド選択（`ResponseField` 許可リスト・`roles` は `ADMIN` のみ） | `0001` D-2 / D-12 / §5 | D-6 |
| L1-14 | **決定的 ID の置換**（SHA-256 → Base64URL・43 文字固定・`ID_MAX_LENGTH` 廃止） | `0002` DM-8 / §4.1 | C-1 |
| L1-15 | **ID 衝突・ID 生成バグの検出**（multiGet 後の text 突き合わせ ＋ バッチ内重複判定にも同じ検査） | `0002` DM-16 / §4.4.1 | C-1 / D-5 |
| L1-16 | **INV-1 / INV-2 / INV-3 の強制**（`entity/SuggestItem` コンストラクタ） | `0002` §5.2 / §2.3(b) | C-2 |
| L1-17 | **`ElevateWord.toSuggestItem` の §5.4 化**（4 分岐の割り当て規則） | `0002` DM-12 / §5.4 | C-2（**L1-16 と同一ステップ必須**） |
| L1-18 | **mapping の To-Be 化**（`dynamic: strict_allow_templates` / `reading_*` テンプレート置換 / `reading_0..9` 明示 / `score` 削除 / `excluded` 追加） | `0002` DM-2 / DM-3 / §2.6 | C-3 |
| L1-19 | **index settings**（`number_of_replicas: 0` の削除 — **fess-suggest 側 4 ファイル**。`total_fields.limit: 100` を `suggest.json` にのみ追加）※**fess 本体側 3 ファイルは U-2 の決定によりフェーズ A（先行リリース）へ移した** | `0002` DM-6 / DM-7 / §3.2 / §3.3 | C-3（＋ **A-4**） |
| L1-20 | **マージ規則の単一化**（走査基準を W 単一化・全フィールドの合成規則・バッチ内と既存ドキュメントの同一化） | `0002` DM-10 / DM-11 / DM-13 / §5.2 / §5.3 / §5.5 / §5.6 | C-4 |
| L1-21 | **`userBoost` の丸め撤廃**（`<= 1` を `1.0` にしない） | MIG-04 / `0002` §7.1 | C-4 |
| L1-22 | **`excluded` の否定形フィルタ必須化**（2 経路に無条件付与・`FieldNames.EXCLUDED` 追加） | `0002` DM-14 / §6.2 | C-5 |
| L1-23 | **取り込み時 drop の廃止**（bad word 該当の新規候補も `excluded = true` で保存） | `0002` DM-21 / `0001` D-32 | C-4 / D-3 |
| L1-24 | **bad word の重複マッチ解除**（`releaseCondition` / `mustNotContain`） | `0001` D-25 / `0002` DM-18 | D-3 |
| L1-25 | **`SuggestStore` は純粋な永続化境界**（`bulkPut(List<SuggestItem>)`。read-modify-write は `internal` が所有） | `0001` D-31 / §3.7.1 | D-1 / D-5 |
| L1-26 | **エイリアス primitive**（`switchIndexRetainingPrevious` / `rollbackToPrevious` / `aliasState`） | `0001` D-21 / D-23 ／ `0003` MO-4 / MO-17 / MO-20 | D-2 |
| L1-27 | **post-condition による正常完了判定**（対象 4 メソッド。`createNextIndex` の付替フェーズを含む） | `0001` D-23 ／ `0003` MO-20 / MO-21 | D-2 |
| L1-28 | **`.prev` は常にちょうど 1 インデックスを指す**（付与と解除を同一 primitive に閉じる） | `0003` §3.3 | D-2 |
| L1-29 | **`validateNext(SuggestQuery)`**（G2 スモーククエリの実行経路。**否定形フィルタが自動適用される**） | `0001` D-15 ／ `0003` §4.2.1 | D-6 |
| L1-30 | **`wordCountStats()`**（G1 の件数取得。`excluded = true` を含む） | `0001` §2.2 ／ `0003` §4.1 | D-6 |
| L1-31 | **`updateRefreshInterval`** と `IndexSchema.refreshInterval` による再構築中の停止・復帰 | `0003` MO-8 / §7.3 | D-2 / B-5 |
| L1-32 | **refresh 戦略 (a)**: バッチごと refresh の廃止 | `0003` MO-7 / §7.1 | D-7 |
| L1-33 | **refresh 戦略 (b)**: `Suggester.refresh()` のクラスタ全体 refresh を suggest インデックス限定に是正 | `0003` MO-7 / §7.1 | D-7 |
| L1-34 | **refresh 戦略 (c)**: `IngestOptions.refreshPolicy`（`NONE` / `ON_COMPLETION` の 2 値。`PER_BATCH` は作らない） | `0003` MO-7 / §7.5 | B-5 / D-7 |
| L1-35 | **`SuggestSource<I>` は型付き変換 Adapter**、実行点は `indexFrom`。「登録するだけで載る」形は採らない | `0001` D-24 / D-30 | D-5 / D-8 |
| L1-36 | **SPI の合成点は `SuggesterBuilder` 1 点**（ServiceLoader / DI を使わない）＋ `SuggestComponents` | `0001` §3.9 | D-8 |
| L1-37 | **`apply` の全廃**（新 API から削除。旧ファサードは `@Deprecated` で no-op 維持） | `0001` D-5 / §8.5 | E-2 / E-3 |
| L1-38 | **旧ファサードの委譲**（P-a 同期化 / P-b Promise / P-c 引数読み替え） | `0001` D-13 / §8.3 | E-2 / E-3 |
| L1-39 | **`DeferredAdapter`**（`CompletableFuture` → `Promise` の一方向のみ） | `0001` §8.4 | E-1 |
| L1-40 | **テスト**: `0002` §7.1 の既存テスト改修 ＋ T-1〜T-24 ＋ T-S11 / T-S13 / T-R3 / T-R5 / T-R6 / T-R7 ＋ T-S5・T-S10 の primitive 部分 | `0002` §7 ／ `0003` §11.1 の総則 | F-1〜F-3 |

### 3.2 分類 2: **R0** で先にリリースする（fess 本体側。Q1=(B) / Q4=(A)）

| # | 要素 | 根拠 | ステップ |
| --- | --- | --- | --- |
| P-01 | `(fess) helper/SuggestHelper.java:464-487` の elevate word 入力正規化（**trim による INV-2 の担保**） | `0003` §10.3 の 3 | A-1 |
| P-02 | **再構築専用の内部経路 `storeAllElevateWordsForRebuild()` / `storeAllBadWordsForRebuild()` を設け、その行単位ループ（削除フェーズ・追加フェーズの両方）に失敗隔離を入れる**（警告ログ＋スキップ）。**失敗した行の数（行 ID で dedupe）を戻り値で返す。** **public 3 メソッドは `void` の fail-fast のまま変えない** ／ **`deleteAllBadWords()` は行単位ループを持たないため対象外** | `0003` **第 13 版** §10.4（**MO-25**。**規則 3・6 は X-6 で是正済み**） | A-2 |
| **P-02b** | **P-02 が返す失敗行数を `exitCode` へ合流させ、G3 に渡す**（**A-2 ではなく A-3 の責務である** — `0003` §10.4 (j) ／ `0007` §3 の引き継ぎ 2） | `0003` §10.4 (j) / §4.2.2 | **A-3** |
| P-03 | **G3 ガード**: `exitCode != 0` なら `switchIndex()` と `removeDisableIndices()` を実行せず終了 | `0003` MO-2 / §4.3 | A-3 |
| P-04 | **G1 ガード**: 次世代語数が 0 でない かつ 旧世代件数の一定割合以上。旧件数は S1 直前に取得。**旧世代不在の初回は割合判定を適用しない** | `0003` MO-3 / §4.2 | A-3 |
| **P-05** | **`(fess res) suggest_indices/` の 3 ファイル（`suggest_analyzer.json` / `_aws/suggest_analyzer.json` / `_cloud/suggest_analyzer.json`）からの `number_of_replicas: 0` 削除**（**U-2 の決定によりフェーズ A に移した**） | `0002` DM-6 / §3.2 | **A-4** |
| P-06 | 上記に対応するテスト（T-F3 ＋ T-S1 / T-S2 の一部） | `0003` §11.3 | A-6 |
| P-07 | Q11(D): `(fess res) suggest_indices/suggest.json` が存在しないことを assert するテスト | `0003` §8.4 / §13 の 7 | A-6 |
| ~~**P-08**~~ | **【2026-08-31 撤回】`.prev` 付与の暫定実装（fess 側 alias 操作）＋ ロールバック手順書 ＋ L2 での撤去箇所一覧。** **U-7 で採用を決めたが、U-8 により撤回した** — R1 では最初から正式 primitive（`switchIndexRetainingPrevious()` / `rollbackToPrevious()` / `aliasState()`）を使うため、暫定版を作る意味が無い。**ステップ A-5 は削除**（§4 / §7.5.1 ／ `0003` 第 14 版 §10.6） | ~~`0003` MO-4~~ ／ 撤回の記録は `0011` | ~~**A-5**~~ |

> **なぜ先行できるのか** [確認]: P-01〜P-07 はいずれも **fess-suggest のバージョンに依存しない**。P-05 は JSON リソースから 1 行を消すだけで、`auto_expand_replicas` が既に設定されているため**実効挙動は変わらない**（`0003` §8.2 が実機確認済み — OpenSearch が `number_of_replicas` を上書きするため現行の `0` は一度も効いていない）。P-01 は fess 側の入力バリデーション、P-02〜P-04 は `exitCode` の検査と制御フローで、`0003` §10.1 が MO-2 について「fess 本体側の変更のみで完結するため L1 を待たずに単独でリリースできる。先行させることを推奨する」と明記しているのと同じ性質である。
>
> **なぜ R0 として分けるのか**（**2026-08-31 改訂**）: **必須なのは「フェーズ A の成果物が R1 に入っていること」である** — `0003` §10.3 が「INV-1 強制（L1-16）＋ `ElevateWord.toSuggestItem` の §5.4 化（L1-17）＋ `(fess) SuggestHelper.java:466-471` の見直し（P-01）は**同一リリース**」と定めているためである。**【撤回】第 13 版までの本書はここに「L1 に fess 本体の変更を含めない（C-01 を守る）以上、P-01 を先に出すしかない」と書いていたが、その制約は R-P1 により消滅した。** **R0 を別リリースとして先に出す理由は §5.5 に移した**（ユーザー要望 ＋ 現行 fess-suggest 上で安全網を先に稼働させ、平常時の日次再構築で実績を積むため）。`0003` §10.4 の対処（P-02）も同じ理由である — INV-1 強制が入った L1 バイナリで `storeAllElevateWords` が 1 件の不正データに当たると再構築全体が落ちる。
>
> **G2 は R0 に入れられない** [確認]。`validateNext`（L1-29）が fess-suggest 側の成果物であるため。**R0 では G1・G3 のみで判定する。** **【2026-08-31】これは安全網の不足にならない** — **R0 では fess-suggest が現行のままなのでメジャー移行が起きない**（`0003` 第 14 版 §10.1）。**R1 では G1 / G2 / G3 が 3 つとも揃う。**
>
> **`.prev` 保持と切戻しは R0 に入れない** [確定]。**正式経路（`switchIndexRetainingPrevious()` / `rollbackToPrevious()`）は fess-suggest 側の成果物であり R1 に入る。**
>
> **【2026-08-31 撤回】fess 側 alias 操作による暫定版（M-6 / P-08 / ステップ A-5）は作らない。** U-7 で採用を決めていたが、**その根拠は「L1 期間に実際のメジャー移行が走るのに戻り先が無い」ことだった**（§7.5.1）。**R-P1 によりその区間が消えたため、暫定版を作る意味も無くなった。** 撤回の記録は `0011`。

### 3.3 分類 3: 後続タスク（R1 の fess 本体側 / R2）へ送る

> **【2026-08-31 改訂】下表の「送り先」は R0 / R1 / R2 の呼称に置換済みである。** **`R1（後続タスク）` は「R1 に入るが本タスクのスコープ外であり、後続タスクが実装する」ことを指す。**

| # | 要素 | 根拠 | 送り先 |
| --- | --- | --- | --- |
| N-01 | fess 本体 main 4 クラスの新 API 切り替え（`0001` §9.1〜§9.4） | `0003` 第 15 版 §10.1 | **R1（後続タスク）** |
| N-02 | `(fess res) fess_config.properties` への 2 キー追加 ＋ `FessConfig` 8 箇所（MO-9 ／ `0003` §13 の 9） | 新 API（`IndexSchema`）を fess 側が使う段で初めて意味を持つ | **R1（後続タスク）** |
| N-03 | G2 の fess 側実装（検証語の設定キー・メジャー移行フラグ・自動採取。`0003` §4.2.3 / §13 の 12・13） | `validateNext` の呼び出し側。**R1 では G2 が最初のメジャー移行から必須である**（`0003` 第 15 版 §4.2.3） | **R1（後続タスク・必須）** |
| N-04 | `suggest.popular.word.cache.expire` の `60` → `60m` 化と `PopularWordHelper` の String 版アクセサ移行（`0001` §9.4） | fess 側 API 適合の一部 | **R1（後続タスク）** |
| N-05 | T-F1（`SuggestHelper` が新 API を正しく呼ぶ）／ T-F4（統合テストの切替・ロールバックシナリオ） | `0003` §11.3 | **R1（後続タスク）** |
| N-06 | T-S1〜T-S4 / T-S8 / T-S9 / T-S12 / T-S14 ／ T-R2（`0003` §11.1 の総則により fess 本体側） | 同上。**ただし T-S1 / T-S2 の R0 版相当は A-6 で部分的に書く** | **R1（後続タスク）** |
| N-07 | T-S5〜T-S7 / T-S10 / T-R1 / T-R4 のうち**実クラスタ必須の部分**（T-F4 の内訳） | `0003` §11.1 | **R1（後続タスク）** |
| N-08 | 旧ファサードの除去（MIG-05） | `0003` §10.1 | **R2** |
| N-09 | 除外語の物理削除の運用導線（MO-23 ／ `0003` §13 の 14） | fess 側の運用機能 | **R1 以降（後続タスク）** |
| N-10 | `knn_vector`（`0003` §9） / MIG-15 第 2 段 / K-1 の解消 / 性能実測 | §1.2 のスコープ外 | **後続** |

---

## 4. フェーズ構成とステップ

**7 フェーズ・39 ステップ**（**2026-08-31 に A-5 を削除して 40 → 39**）**。** 各ステップは 1 回の実装セッションで完結する粒度を目安にしている。

| フェーズ | 内容 | ステップ | モジュール |
| --- | --- | --- | --- |
| **0** | 準備と逸脱手続き | 0-1 〜 0-4 | 両方 / `agent_docs` |
| **A** | **R0**（fess 本体の安全網） | A-1 / A-2 / A-3 / A-4 / **A-6**（**A-5 は 2026-08-31 に削除**） | `modules/fess` |
| **B** | 基盤型（`api` / `spi` の宣言と DTO） | B-1 / B-2 / B-3 / **B-4a** / **B-4b** / B-5 / B-6 / B-7 | `modules/fess-suggest` |
| **C** | データモデル | C-1 〜 C-5 | `modules/fess-suggest` |
| **D** | `internal` 実装 | D-1 〜 D-8 | `modules/fess-suggest` |
| **E** | 旧ファサードの委譲 | E-1 〜 E-4 | `modules/fess-suggest` |
| **F** | テストと最終検証 | F-1 〜 F-5 | 両方 |

---

### フェーズ 0: 準備と逸脱手続き

#### ステップ 0-1: ビルド前提の確認とブランチ作成

- **目的**: 以降の全ステップが「隣のモジュールの変更を取り込める」状態で回ることを保証する。`0003` §10.5 が想定した不整合が本当に無いことを実測で確定する。
- **対象**: なし（環境操作のみ）
- **設計書の対応**: `0003` §10.5（**X-2(a) の対象**） ／ `0003` §6.3（OpenSearch 2.16 以上）
- **作業内容**:
  1. `modules/fess-suggest` に `feature/suggest-l1`、`modules/fess` に `feature/suggest-l1-precede` を作成する。
  2. `modules/fess-suggest` で `mvn -q install -DskipTests` を実行し、`~/.m2/repository/org/codelibs/fess/fess-suggest/15.9.0-SNAPSHOT/` が生成されることを確認する。
  3. `modules/fess` で `mvn -q -o compile` が通ることを確認する（**この時点の結果が「無変更でビルドできる」のベースライン**である）。
  4. `modules/fess-suggest` で `mvn test` を 1 回完走させ、**現状の全緑を基準線として記録する**（24 クラスが OpenSearch ノードを起動するため所要時間も記録する）。
- **DoD**:
  - 2 ブランチが作成済み。
  - `mvn install -DskipTests` が成功し、m2 に `15.9.0-SNAPSHOT` が入っている。
  - `modules/fess` の `mvn compile` が成功する。
  - `modules/fess-suggest` の `mvn test` の**基準線**（成功/失敗クラス数・所要時間）が作業履歴に記録されている。
- **検証**: `mvn -q install -DskipTests` ／ `mvn -o compile` ／ `mvn test`
- **依存**: なし（**最初のステップ**）
- **注意点/リスク**: `mvn test` が基準線の時点で赤い場合、**それは本タスクの変更によるものではない**。赤いテストを一覧化し、以降の DoD から除外するか先に直すかを判断する（判断が要る場合は §10 に上げる）。

#### ステップ 0-2: 逸脱 X-1 — `0001` を第 9 版に改訂（**`SuggesterBuilder.build(...)` の戻り値型**）

- **目的**: 設計どおり実装するとコンパイルエラーになる矛盾を、実装前に設計側で解消する。**区分 I の逸脱手続き。**
- **対象**: `agent_docs/tasks/20260822_implementation/docs/0001-api-design.md`（**改変**）
- **設計書の対応**: `0001` §3.9（L1358-1392） ／ `0001` §8.1 の #11（L1770） ／ `0001` §8.3（L1837-1838） ／ C-01 ／ D-13 / D-28
- **作業内容**:
  0. **改訂前に版表記の整合を確認する**（**区分 II**）。**`0001` の冒頭は「現在の版: 第 7 版（2026-08-17）」だが改訂履歴には第 8 版の行がある** [確認]。**食い違っていれば先に冒頭表記を改訂履歴の最新版に合わせる。** その上で、**以降の版番号は「改訂履歴の最新版 +1」を採る**（固定値の「第 9 版」を前提にしない）。
  1. **改訂履歴に次版の行を追加**する。変更理由に「**同書 §3.9 の『`build(...)` の戻り値を `SuggestComponents` に変える』は、同書 §8.3（旧 public シグネチャを 1 つも変えない）および C-01（L1 では fess 本体が無変更で動く）と両立しなかった。`(fess) helper/SuggestHelper.java:142` が戻り値を `Suggester` 型フィールド（`:86`）へ代入しているため、L1 でコンパイルエラーになる**」を明記する。
  2. **同書 §3.9 を書き換える**: `SuggesterBuilder.build(Client, SuggestSettings, ExecutorService)` の**戻り値は `Suggester` のまま維持**し、`SuggestComponents` を得る入口を**別メソッド**として追加する（**[提案] 名称: `buildComponents(Client, SuggestSettings, ExecutorService)`**）。既存の `build(Client client, String id)`（`(sug) SuggesterBuilder.java:149`）も `Suggester` を返すまま維持する。
  3. **同書 §8.1 の #11 の行を書き換える**: 「存続するが `SuggestComponents` を返す形に変わる」→「**シグネチャを維持したまま存続する。`SuggestComponents` は `buildComponents(...)` から得る**」。
  4. **`Suggester` と `SuggestComponents` の関係を明記する**: `build(...)` は内部で `buildComponents(...)` を呼び、得た `SuggestComponents` を保持する `Suggester` を返す。**D-13 の「旧クラスが新 IF を保持する向き」は保たれる**（L3 で `Suggester` を削除しても `SuggestComponents` は残る）。
  5. **D-28（互換性の範囲）に追記**: `Suggester.builder()` とその `build(...)` は**維持する側**である旨を明示する。
- **DoD**:
  - `0001` の改訂履歴に第 9 版の行があり、変更理由が上記のとおり書かれている。
  - 同書 §3.9・§8.1 #11・D-28 の 3 箇所が整合している（`build` が `Suggester` を返すと 3 箇所すべてが述べている）。
  - **`0002` / `0003` に `SuggestComponents` の戻り値型に依存する記述が無いことを grep で確認**し、無いことを作業履歴に記録する。
- **検証**: `grep -n "SuggestComponents" docs/*.md` の全ヒットを目視確認
- **依存**: なし（0-1 と並行可）。**ステップ D-8 の前提**
- **注意点/リスク**: `0000-design-overview.md` §5 の [確定] スナップショット（C-01）と矛盾しないこと。C-01 の記述は変えない（**むしろ本改訂は C-01 を守るための改訂である**）。

#### ステップ 0-3: 逸脱 X-2 — `0003` の事実記述の軽微改訂（区分 II）

- **目的**: 設計書の [確認] 記述と実物の食い違いを解消する。**設計判断は変わらないため版は上げない（Q6=(B)）。**
- **対象**: `docs/0003-migration-ops-design.md`（**改変**） ／ `docs/0000-design-overview.md`（**改変**・1 行追記）
- **設計書の対応**: `0003` §10.5 ／ `0003` MO-9 / §8.2 ／ `0000` §3.5
- **作業内容**:
  1. **同書 §10.5 の表を、本書 §1.3 の実測値に更新する**（fess `15.9.0-SNAPSHOT` / `suggest.version` `15.9.0-SNAPSHOT` / モジュール `15.9.0-SNAPSHOT` / OpenSearch `3.8.0` / Java 21）。**「不整合を解消する必要がある」という記述を「本タスク開始時点で不整合は存在しない。ローカル検証は `mvn install` で足りる」に書き換える**。手段 (1)(2) の記述は「解消済みのため不要」と注記して残す（履歴として）。
  2. **MO-9 ／ 同書 §8.2 の挿入位置を訂正する**: 「`(fess res) fess_config.properties:591` の直後」→「**`:639`（`index.document.suggest.index=fess`）の直後**」。同型例の参照を「`:595-605` の crawler 系」→「**`:643-653` の crawler 系**」に訂正する。
  3. **§6.3（OpenSearch 2.16 以上）に、現行が 3.8.0 で前提を満たす旨を 1 行追記する**。
  4. `0000-design-overview.md` §3.5 の近傍に、**Q7 の正本方針**（`20260822_implementation/docs/` が正本、`20260706_design_document/docs/` は凍結）を 1 行追記する。
  5. **`0004-corrections.md` には追記しない**。同書は「既存資料に対する訂正」であり、設計書自身の事実更新は対象外である（§1 の位置づけ）。
- **DoD**:
  - `0003` §10.5・MO-9 / §8.2・§6.3 の 3 箇所が実物と一致している。
  - `0003` の**改訂履歴に行が増えていない**（版を上げないため）。代わりに作業履歴に「区分 II として処理した」旨と差分が記録されている。
  - `0000` に正本方針の 1 行がある。
  - `20260706_design_document/docs/` の 5 本が**変更されていない**（`diff` で確認）。
- **検証**: `grep -n "15.7" docs/0003-migration-ops-design.md`（残存 0 件）／ `grep -n ":591" docs/0003-migration-ops-design.md`（残存 0 件）／ `git`（管理外のため `diff` で 20260706 側の無変更を確認）
- **依存**: なし（0-1 / 0-2 と並行可）
- **注意点/リスク**: **`:591` は `0001` §9.4 にも現れる可能性がある。** `0001` / `0002` も含めて `grep -n "591\|15\.7\.\|3\.7\.0" docs/*.md` を走らせ、同種の食い違いを取りこぼさないこと。取りこぼしを見つけた場合も本ステップで一括して直す。

#### ステップ 0-4: 逸脱 X-3 — L1 中間状態の設計上の穴への対処

> **【2026-08-31】本ステップの成果の大半は撤回された。** 実施内容（`0003` 第 9 版の §10.6 新設・M-1・K-19、`0002` 第 9 版の 3 箇所）は、**配布・運用モデルの確定により不要になった**（§7 の撤回ヘッダ ／ `0003` 第 14 版 ／ `0011`）。**維持されたのは `0002` §5.2 の [確定]（欠損 `reading_i` スロットは空配列として復元する）だけであり、その根拠も `0002` 第 11 版で差し替えた。** **本ステップの記述は履歴として残す。**

- **目的**: §7 が確定させた 3 件の不足（穴 1 / 穴 2 / メジャー移行タイミングの誤り）を、実装前に設計側で解消する。**区分 I の逸脱手続き。**
- **対象**:
  - `docs/0003-migration-ops-design.md`（**改変**。同書 §10 に L1 期間の節を新設 ＋ 同書 §10.1 L813 の訂正 ＋ 同書 §12 に K 番号を追加）
  - `docs/0002-datamodel-design.md`（**改変**。§6.1 の共存範囲の記述 ＋ §5.6 の前提の限定）
- **設計書の対応**: `0002` §4.7 / §5.6 / §6.1 ／ `0003` MO-19 / MO-22 / §5.3 / §10.1（L813） / §12
- **作業内容**:
  1. **`0003` §10.1 L813 の誤りを訂正する**（**最も重要**）。「メジャー移行そのもの（`0002` §4.7 の再構築）は L2 以降にしか起きない」を撤回し、**「L1 リリース後の最初の SuggestJob 実行がメジャー移行を実行する」**に書き換える。根拠として §0.1 の根拠表（`(fess) exec/SuggestCreator.java:252,255,258,298` ／ `(sug) Suggester.java:238` ／ `(fess res) fess_indices/fess_config.scheduled_job/scheduled_job.bulk:4`）を引く。
  2. **§10.1 の時間軸に「L1 と L2 の間」という区間を追加する。** 現行の表は「L1 以前」と「L2 以降」の 2 欄しか持たず、**この区間が欄として存在しない**ことが穴の構造的原因である。
  3. **MO-22 が L1 直後の移行で空振りすることを明記する。** G2 は `validateNext` を fess 側が呼ばないため発動しない。**フェーズ A の G1 / G3 ガードが唯一の実効的な安全網である**ことを書く。
  4. **M-1 をリリース手順として書く**（§7.5・決定済み）: **L1 デプロイ直後に SuggestJob を手動起動して再構築を完了させる**。起動手段は既存（`0003` §2.2 が「任意タイミングでの起動手段は既に存在する」と確認済み [確認]）。**この手順を L1 リリースチェックリストの必須項目にする。**
  5. **M-5 を既知の制約として `0003` §12（既知の制約）に追加する**（§7.5・決定済み）: **[提案] K-19** —「**L1 デプロイから初回再構築までの窓（M-1 を実施しない場合は既定で最大約 1 日）に、新 ID バイナリが旧世代インデックスへ書き込むため、同一語が旧 ID と新 ID の 2 ドキュメントに分裂し text 単位の頻度集約（KEEP-03）が一時的に壊れる。旧世代は `dynamic: true` のため書き込みは通り、エラーにならずに壊れる。`0002` §4.4.1 の衝突検査（DM-16）は新 ID で multiGet するため発火しない。汚染は次の再構築で新世代が空から作られることにより解消し、恒久的な破壊ではない。なお、切替後の回復手段は本書 §10（L1 期間の節）が定める暫定 `.prev`（M-6）である。**」
  5b. **M-6（`.prev` の暫定保持）の手順を `0003` §10 の L1 期間の節に追記する**（§7.5.1・**U-7 で採用決定**）。内容は (i) fess 側 alias 操作で `switchIndex()` の直前に `.prev` を付与すること、(ii) **§3.3 の付け替え規則（既存 `.prev` を全 remove → 現検索対象に add）を暫定実装側が守る責任を負う**こと、(iii) **無条件リトライの禁止**（L287 の規則が 2 段構成でこそ重要である旨）、(iv) **ロールバック手順（§5.3 の R1〜R3 の暫定版。`switchIndex()` を使ってはならない）**、(v) **L2 での撤去方法**（`switchIndexRetainingPrevious()` / `rollbackToPrevious()` / `aliasState()` への置換）。
  6. **`0002` §6.1 の共存範囲の記述を限定する**: 「共存が問題になるのは `excluded` フィールドの有無だけである」を、**「読み取り経路について共存が問題になるのは `excluded` の有無だけである。書き込み経路の共存は `0003` §10 の L1 期間の節が扱う」**に書き換える。
  7. **`0002` §5.6 の前提を限定する**: 「INV-1 により既存ドキュメント側の `reading_i` の本数も新 item 側の本数も W に等しい」に、**「ただしこれは既存ドキュメントが INV-1 強制後のバイナリで書かれている場合に限る。L1 期間に旧世代ドキュメントを読む場合は成立せず、`0003` §10 の L1 期間の節が扱う」**を追記する。
  8. **`0002` §5.2 に「W で回したが `reading_i` が存在しない」場合の扱いを定義する**（穴 2 の実体）。**[提案] 欠損スロットは空配列として扱い、例外にしない**（旧世代ドキュメント読み込み時の未定義動作を消すため）。**この 1 点は設計判断なので、改訂時に明示的に決めること。**
  0. **改訂前に版表記の整合を確認する**（**区分 II**・0-2 と同じ）。**`0002` / `0003` とも冒頭は「現在の版: 第 7 版（2026-08-17）」だが改訂履歴には第 8 版の行がある** [確認]。**食い違っていれば先に冒頭表記を正し、版番号は「改訂履歴の最新版 +1」を採る。** **0-2 が先に `0003` を改訂している場合は、その版の次を採る**（固定値を前提にしない）。
  9. **改訂履歴に次版を追加する。** `0003` / `0002` それぞれの変更理由に「**L1 という中間実行状態を設計書が扱っていなかった。設計書は最終形と移行手順の中は精密だが、リリース段の間に置かれた実行状態の記述が欠けていた**」を明記する。
- **DoD**:
  - `0003` §10.1 L813 の記述が訂正され、「L1 と L2 の間」の区間が表に存在する。
  - `0003` にリリース手順として M-1（デプロイ直後の即時再構築）が書かれている。
  - `0003` §12 に K-19（M-5）が追加されている。
  - `0002` §6.1 / §5.6 / §5.2 の 3 箇所が限定・定義されている。
  - `0003` / `0002` の改訂履歴に版と変更理由がある。
  - **`20260706_design_document/docs/` が変更されていない**（Q7）。
- **検証**: `grep -n "L2 以降にしか起きない" docs/0003-migration-ops-design.md`（0 件）／ `grep -n "K-19" docs/0003-migration-ops-design.md`（存在）／ `diff` で 20260706 側の無変更を確認
- **依存**: なし（0-1 / 0-2 / 0-3 と並行可）。**フェーズ C 全体の前提**
- **注意点/リスク**:
  - **このステップが未了のままフェーズ C（特に C-1: ID 置換）に入ると、逸脱手続きの「改訂を先に行う」規律を破る。**
  - 作業内容 8（欠損 `reading_i` スロットの扱い）は**新たな設計判断**である。[提案] のまま実装せず、改訂時に決めて設計書に書くこと。
  - **M-1 は運用手順であり、コード変更を伴わない。** 手順を飛ばすと窓が開く（K-19）。**リリースチェックリストに入れることが実効性の担保である。**

---

### フェーズ A: **R0 準備リリース**（fess 本体の安全網）

> **`modules/fess` の `feature/suggest-l1-precede` ブランチで行う。fess-suggest には一切触れない。**
> **このフェーズが R0（準備リリース）である。** fess-suggest のバージョンに依存せず、`modules/fess` だけで完結する（`0003` 第 14 版 §10.1 の「なぜ R0 を分けるのか」）。

#### ステップ A-1: elevate word 入力の正規化（INV-2 の fess 側担保）

> **本ステップの実装中に逸脱 X-4（区分 I）が発火した**（2026-08-31）。`0003` を**第 10 版**に改訂して **MO-24** を採番済みである。**記録は作業履歴 `0006-deviation-x4-elevate-word-id-symmetry.md`。** 以下の記述はその改訂を反映済みである。

- **目的**: **R1 で** INV-1 / INV-2 がコンストラクタで強制されたときに、fess 本体の管理画面入力が実行時エラーを起こさないようにする。`0003` §10.3 の 3。**あわせて、その正規化が同時にドキュメント `_id` の変更でもあることに対処する**（`0003` §10.3 の 4 ／ MO-24）。
- **対象**: `(fess) helper/SuggestHelper.java`（**改変**。3 メソッド）
  - `:464-487` の **`addElevateWord`**
  - `:449-452` の **`deleteElevateWord`**（**X-4 で追加**）
  - `:431-441` の **`deleteAllElevateWord`**（**X-4 で追加**）
- **設計書の対応**: `0003` §10.3 の 3（**境界条件** の記述） ／ **`0003` §10.3 の 4 ＋ §10.3.1（MO-24）**（**X-4 で追加**） ／ `0002` INV-2（§1） ／ `0002` §5.4（4 分岐は**ライブラリ側**が担う）
- **作業内容**:
  1. `:468` / `:470` の `split(TEXT_SEP)` の**前に trim を入れる**。`0003` §10.3 [確認] が指摘するとおり、`replaceAll(TEXT_SEP + "+", TEXT_SEP)` は連続空白を畳むだけで**先頭・末尾の空白を除去しない**ため、`" test"` のような入力が**空文字要素を含む `readings`** を生成しうる。
  2. **`word` 側も同様に trim する**（`readings` だけ直しても `text` 側が INV-2 を破る）。
  3. **空文字要素を除去する**（trim 後に空になったトークンを落とす）。
  4. **読みトークン数 k と語数 W の一致は fess 側で強制しない。** `0002` §5.4 の 4 分岐が k ≠ W を過不足なく覆うため、fess 側は「区切り文字の衛生」だけを担う。**この分担を コメントで明記する**（次の実装者が二重に検査しないように）。
  5. **削除経路 2 メソッド（`deleteElevateWord`（`:449`）／ `deleteAllElevateWord`（`:431`））にも、作業内容 1〜3 と同じ正規化関数を適用する**（**X-4 / MO-24**）。**正規化前後で語が変わる場合は、生キーと正規化キーの両方で削除する**。変わらない場合は 1 回だけ削除する。**擬似コードは作業履歴 `0006` §7 にある。**
     - **両キー削除にする理由**: 本ステップを含むバイナリへ上げる前に**生キーで投入済みの既存ドキュメント**が残っているため。正規化キーだけで削除すると掃除する手段が全件再構築でも得られない。**削除は存在しない `_id` に対して実質 no-op である**（`(sug) index/writer/SuggestIndexWriter.java:83-91` が例外を握り、fess 側は戻り値を捨てている — `:438` / `:450`）[確認]。
     - **正規化関数は add 側と共有する。** 追加側と削除側で別実装を持たない。
     - **両キー削除の意図をコメントに残す**（次の実装者が「冗長だ」と削らないように）。
- **DoD**:
  - `addElevateWord` に trim と空要素除去が入っている。
  - **`0002` §5.4 の 4 分岐に相当する処理を fess 側に書いていない**こと（責務の二重化をしていない）。
  - **`addElevateWord` と `deleteElevateWord` が同じキー（同じ正規化関数の出力）を使っている**こと（**X-4 / MO-24**）。
  - **削除経路 2 メソッドに両キー削除が入っている**こと。正規化前後で語が変わらない場合は 1 回だけであること（**X-4 / MO-24**）。
  - A-6 で追加する T-F3 が緑。
- **検証**: `mvn -pl . test -Dtest=SuggestHelperTest`（A-6 でテストを足した後）
- **依存**: なし（フェーズ A の先頭）
- **注意点/リスク**:
  - **`(fess) helper/SuggestHelper.java:482-484` が fess 本体で `ElevateWord` を new している唯一の箇所である** [確認]（`new SuggestItem` は 0 件）。管理画面の create / update / CSV アップロード、API の POST / PUT / upload、バッチ一括（`(fess) exec/SuggestCreator.java:258`）のすべてが `addElevateWord(...)`（`:464`）を通るため、**生成経路の影響範囲はこの 1 メソッドに閉じる**（`0003` §10.3 [確認]）。逆に言えば**ここを間違えると全生成経路が壊れる**。
  - **ただし削除は `addElevateWord` を通らない** [確認・**X-4 で訂正**]。`(fess) app/web/admin/elevateword/AdminElevatewordAction.java:409` ／ `(fess) app/web/api/admin/elevateword/ApiAdminElevatewordAction.java:206` は `deleteElevateWord`（`:449`）へ向かう。**`0003` §10.3 の第 9 版までの記述（delete も `addElevateWord` を通る）は誤りであり、第 10 版で訂正した。**
  - **語テキストは入力であると同時に `_id` キーでもある** [確認]（`(sug) entity/SuggestItem.java:116,140` ／ `(sug) util/SuggestUtil.java:91-97`）。**語テキストに触れる変更は、その語を書いた経路と消す経路の両方に同時に及ぶ。** この一般則は **C-1（決定的 ID の置換）でも同じ経路集合に効く**（`0003` §10.3.1 (e)）。
  - **残存リスク**（**【2026-08-31 是正・区分 II】実物で確認し、対象を 2 つに分けた**。旧記述は「孤児は残る（掃除手順は L2 以降）」とだけ書いており、**suggest ドキュメントと settings エントリを区別していなかった**）:
    - **(a) suggest ドキュメントの孤児 — 次回の全件再構築で消える** [確認]。**再構築は `createNextIndex()` が空の新インデックスを作り**（`(sug) Suggester.java:235-260`）、**`storeAllElevateWordsForRebuild()` が DB の行だけを新世代へ書く**（`(fess) exec/SuggestCreator.java:261`）。**DB から消えている語は新世代へコピーされず、旧世代は `removeDisableIndices()`（`:304`）で物理削除される。** **したがって掃除手順は不要である。**
    - **(b) settings エントリの孤児 — 残る** [確認]。`(sug) settings/ElevateWordSettings` のエントリは **`fess_suggest` 設定インデックス側にあり、`createNextIndex()` の対象ではない。** **`deleteAllElevateWord` は DB の行を回すため、DB から消えている語のエントリは名指しされず消えない。** **これは `0003` §10.3.1 (c) の障害 3 が既に指摘しているものである。**
    - **(b) が実害になる唯一の経路** [確認]: **`indexer().deleteAll()` が `restoreElevateWord()` を呼び**（`(sug) index/SuggestIndexer.java:295`）、**`settings.elevateWord().get()` の全エントリを再投入する**（`(sug) index/operations/WordManagementOperations.java:148-152`）。**呼び出し元は `SuggestHelper.deleteAllWords()`（`:365-373`）＝ 管理画面「サジェスト」の全語削除と `/api/admin/suggest` の同操作の 2 つだけであり、再構築経路（`SuggestCreator.create()`）からは呼ばれない** [確認]。**つまり「管理画面から全語削除を実行したときにだけ、孤児エントリが suggest ドキュメントとして復活する」。**
    - **掃除の要否は後続タスクで判断する**（**R1 以降**。`0003` §10.3.1 (c) の障害 3 ／ 作業履歴 `0006` §6 / §10）。**本ステップのスコープではない。**

#### ステップ A-2: 語管理の一括処理を 1 件の失敗で止めない（`0003` §10.4 ／ **MO-25**）

> **本ステップは 2 度の逸脱を経ている。**
> **(1) 着手時に逸脱 X-5（区分 I）が発火し**（2026-08-31）、`0003` を**第 12 版**に改訂して **MO-25** を採番した（記録は `0009-deviation-x5-store-all-delete-phase.md`）。
> **(2) その実装に対する外部レビューで逸脱 X-6（区分 I）が発火し**（2026-08-31）、`0003` を**第 13 版**に改訂して **MO-25 の規則 3（集計単位）と規則 6（適用範囲）を是正した**（記録は `0010-review-response-a2.md`。**新しい MO 番号は起こさない**）。
> **以下の記述は第 13 版を反映済みである。** **実装の正本は `0010` §5（擬似コード ＋ 要件 14 項目）であり、`0009` §7 の擬似コードは上書きされている — 参照しないこと。**

- **目的**: backup 復元経由で入った不正データ 1 件が `create()` を S2 の途中で中断させ、**再構築全体が失敗する**のを防ぐ。**R1 で INV-1 がコンストラクタで強制されると悪化するが、`suggestWord` が空の行については現行バイナリでも既に発生する**（`0003` §10.4 (d) ／ **X-5**）。
  - **【X-6】本ステップの目的に「管理画面／API のエラー契約を変えること」は含まれない。** 失敗隔離は**再構築経路にだけ**掛ける。
- **対象**:
  - `(fess) helper/SuggestHelper.java`（**改変**）
    - **public 3 メソッド**（`storeAllElevateWords(boolean)` ／ `deleteAllElevateWord(boolean)` ／ `storeAllBadWords(boolean)`）— **挙動を A-2 着手前と完全に同一に保つ**（`void`・fail-fast）。**X-6 による差し戻しである。**
    - **再構築専用 2 メソッド**（`storeAllElevateWordsForRebuild()` ／ `storeAllBadWordsForRebuild()`）— **新設**。`apply = true` 固定・失敗隔離あり・**失敗した行数を `int` で返す**。
    - **private 共通実装** — 失敗隔離の有無を引数で切り替える。**同じロジックの 2 実装を作らない**（MO-24 の規則 1 と同じ理由）。
  - `(fess) exec/SuggestCreator.java`（**改変**。**`:255` / `:258` の 2 行のみ**）— 呼び先を `ForRebuild` へ切り替える。**それ以外の行に触れない**（**X-6 で追加**。理由は `0003` 第 13 版 §10.4 (j)）。
  - ※**行番号は A-1 ＋ `0008` 適用後の作業ツリー基準**。**A-2 の実装で大きく移動しているため、着手時に必ず現物で確認すること**（`0007` §2.11 の 6）。
- **設計書の対応**: `0003` **第 13 版** §10.4 ＋ **§10.4 (e) の MO-25**（規則 3・6 は **X-6 で改訂**） ／ **§10.4 (f)**（集計単位の根拠） ／ **§10.4 (i)**（失敗隔離を再構築経路に限定する根拠） ／ **§10.4 (j)**（対象メソッドと A-2 / A-3 の境界） ／ `0003` §4.2.2（G3 が拾う） ／ `0003` §13 の 8（**復元時バリデーションは後続スコープ・不変**）
- **作業内容**:
  1. **再構築経路が駆動するすべての行単位ループを、1 件の失敗で全体を止めず、警告ログを出してスキップする形にする**（**MO-25 の規則 1**）。**対象は 3 ループである** — elevate word の削除ループ／追加ループ／bad word の追加ループ。
     - **削除フェーズを外してはならない。** elevate word の再構築は本体ループの前に削除フェーズを駆動して**同じ DB 行集合を 2 周する**ため、追加ループだけを隔離しても**削除フェーズで落ちてスキップ機構に到達しない**（`0003` §10.4 (c) の 1・4）。
  2. **catch する例外の型を絞らない**（**MO-25 の規則 2**）。`SuggestItem` 化の失敗だけを捕まえる実装は不可である — 現に起きるのは NPE であり、発生点は **`normalizeSeparators(null)`** と **`boost` の `Float` → `float` アンボクシング**（`(sug) entity/ElevateWord.java:66-67`）の 2 つで、いずれも `SuggestItem` の構築より手前にある（`0003` §10.4 (c) の 4・6）。
  3. **【X-6 で全面改訂】失敗件数は「失敗した行の数」とし、行 ID（`getId()`）で dedupe する**（**MO-25 の規則 3** ／ 根拠は `0003` 第 13 版 §10.4 (f)）。**同一行が削除フェーズと追加フェーズの両方で落ちても 1 件と数える。** **第 12 版の「削除フェーズと追加フェーズの合算＝項目処理数」は撤回された。**
     - **dedupe の対象範囲は `ForRebuild` メソッド 1 回の呼び出し全体**（削除フェーズ ＋ 追加フェーズ）。`Set<String>` を `ForRebuild` のローカル変数として生成し、private 実装へ引数で渡して両フェーズで共有する。
     - **`SuggestHelper` のインスタンスフィールドに持ってはならない**（**MO-25 の規則 4**）。`SuggestHelper` は DI のシングルトンであり（`(fess res) app.xml:64` に `instance` 属性の指定が無い）、public 経路は管理画面から `CommonPoolUtil.execute(...)` 経由で**非同期に**呼ばれる。**件数用のフィールドも dedupe 用の `Set` もフィールドにしない。**
  4. **握り潰さない**。警告ログには**対象行の識別情報と例外**を含める。**`getSuggestWord()` は `null` でありうるため単独の識別子にしない** — `getId()` を主にし、語は補助として第 2 引数に出す（**MO-25 の規則 2**）。
  5. **bad word 側の削除フェーズ（`deleteAllBadWords()`）は隔離しない**（**MO-25 の規則 5**）。`settings.badword().deleteAll()` の 1 呼び出しであり**行単位ループを持たない**ため、隔離すべき「1 行」が存在しない。**例外はそのまま伝播させる**（`storeAllBadWordsForRebuild()` からも伝播する）。**この非対称は意図的であり、コメントで明記する。**
  6. **【X-6 で全面改訂】失敗隔離は再構築専用の内部経路に限定する**（**MO-25 の規則 6**）。**public 3 メソッドの挙動は A-2 着手前と完全に同一に保つ**（`void`・fail-fast・例外をそのまま伝播）。**呼び出し元 11 箇所（管理画面／API の 4 クラス）は 1 行も変えない。**
     - **理由**: **同期 4 経路（`AdminElevatewordAction.update()` ／ `ApiAdminElevatewordAction.put$setting()` ／ `AdminBadwordAction.update()` ／ `ApiAdminBadwordAction.put$setting()`）では、例外が `throwValidationError(Api)` に変換されて運用者に届いており、それが唯一の異常検知手段である** [確認]。隔離すると 200 OK ＋ 成功メッセージを返す。**第 12 版の規則 6（「管理画面の 3 経路にも及ぶ。これは受け入れる」）は撤回された**（`0003` 第 13 版 §10.4 (i)）。
     - **`ForRebuild` は別パッケージ（`org.codelibs.fess.exec`）から呼ばれるため public にせざるを得ない。** **「呼び出し元は `SuggestCreator` のみ。管理画面／API から呼んではならない」ことを Javadoc に明記する。**
  7. **`refresh()` の呼び出し位置と回数は A-2 着手前と同じにする。** 3 つの private 実装とも**ループの外・末尾で 1 回**。**elevate word の再構築経路では削除フェーズ内と末尾で合計 2 回走るが、それも A-2 着手前と同じである — 減らさない。**
  8. **【X-6 で追加】`(fess) exec/SuggestCreator.java:255` / `:258` の 2 行を `ForRebuild` の呼び出しに切り替える。** **戻り値は捨ててよい**（`exitCode` への合流は **A-3 の作業内容 5**）。**捨てていることと合流先が A-3 であることをコメントで明記する。**
  9. **【X-6 で追加】`deleteAllElevateWord` の Javadoc の誤りを是正する。** 現在の「a row with a blank `suggestWord` … makes `normalizeSeparators` throw」は 1 段飛ばしている — **`normalizeSeparators("")` は throw せず `""` を返す** [確認]（`(fess) helper/SuggestHelper.java` の実装は `text.replace(...).replaceAll(...).trim()`）。**正しくは「`getSuggestWord()` が `convertEmptyToNull` により空文字を `null` に変換するため `normalizeSeparators(null)` が NPE になる」である**（`(fess) opensearch/config/bsentity/BsElevateWord.java:190-193` ／ `(fess) opensearch/config/allcommon/EsAbstractEntity.java:199-201`）。**`convertEmptyToNull` を経由することを必ず書く。**
- **DoD**:
  - **再構築経路の削除フェーズが 1 件の不正行（`getSuggestWord()` が `null` を返す行）で止まらない**こと（**X-5 / MO-25**）。
  - 不正な elevate word を 1 件含む入力で **`storeAllElevateWordsForRebuild()` が完走し、失敗件数 1 を報告する**こと。**【X-6】第 12 版が「1 以上」へ緩めたのは撤回した** — **行 ID で dedupe するため、両フェーズで落ちた 1 行は 1 件である。等値で検査する**（**MO-25 の規則 3** ／ `0003` 第 13 版 §10.4 (f)）。
  - **`boost` が `null` の行を 1 件含む入力で追加フェーズが止まらず、失敗件数 1 になる**こと（**X-5**）。
  - **bad word の追加ループにも失敗隔離が入っており、`deleteAllBadWords()` には入っていない**こと（**X-5 / MO-25 の規則 5**）。
  - **【X-6 で追加】public 3 メソッド（`storeAllElevateWords(boolean)` / `deleteAllElevateWord(boolean)` / `storeAllBadWords(boolean)`）の挙動が A-2 着手前と完全に同一である**こと — **`void` を返し、同じ不正行に対して例外をそのまま伝播する。** 呼び出し元 11 箇所が無変更であること（**MO-25 の規則 6**）。
  - **【X-6 で追加】`(fess) exec/SuggestCreator.java` の変更が `:255` / `:258` の 2 行に限られている**こと。
  - 失敗件数が A-3 の `exitCode` 判定に到達する（**A-3 で完成する**）。
  - 失敗件数と dedupe 用の `Set` が **`SuggestHelper` のインスタンスフィールドに保持されていない**こと（**MO-25 の規則 4**）。
  - **`AdminBackupAction` の `/_bulk` 復元経路には手を入れていない**こと（`0003` §13 の 8 により後続スコープ・**第 13 版でも不変**）。
  - A-6 で追加するテストが緑。
- **検証**: `mvn test -Dtest=SuggestHelperTest`（A-6 でテストを足した後）。**`int` → `void` の戻し変更では Maven の増分コンパイルが古いテストバイトコードを再利用しうる**（症状は `NoSuchMethodError`）。**テストソースを `touch` するか `mvn clean` を挟むこと**（`0007` §2.7 の枠）。
- **依存**: **A-1**（隔離する削除ループの本体は A-1 / MO-24 が入れた正規化と両キー削除である） ／ **A-3 とは分業が確定済み**（A-2 = 呼び先の切替まで／A-3 = 戻り値の `exitCode` 合流。`0003` 第 13 版 §10.4 (j)）
- **注意点/リスク**:
  - `0003` §10.4 が指摘する経路は `(fess) app/web/admin/backup/AdminBackupAction.java:156,237` の `/_bulk` 復元である。**同ファイルには suggest 専用の分岐が 1 つも無く**、`fess_config` インデックス（`elevate_word` / `bad_word` を含む）が汎用のバルク復元でバリデーションを迂回して入る。**mapping 側にも必須制約は無い** [確認]。**本ステップはその出口側で受け止める方針であり、入口側は塞がない。**
  - **不正行は「スキップされる」だけで DB からは消えない** [確認]。毎回の再構築で同じ行が失敗し、**`exitCode != 0` により G3 が毎回切替を止める。運用者が DB の不正行を直すまでサジェストの世代が更新されなくなる。** これは意図した挙動（`0003` §4.2.2）だが、**「サジェストが古いまま」という症状で現れる**ため**リリース時に運用者へ周知する** [提案]（`0010` §7 の 2）。
  - **【X-6】管理画面の挙動は変わらない。** **したがってリリースノートへの記載は不要である** — 第 12 版の実装が申し送っていた「管理画面 3 経路で例外がスキップに変わることをリリースノートに書く」は**撤回された**（`0009` §11 の 4 は無効）。**ただし「1 件の不正行があると管理画面から elevate word を編集できない」という現状は解消されない**（`0010` §7 の 1。本来の解は入口側バリデーション = `0003` §13 の 8 の後続スコープ）。
  - **【X-6】`ForRebuild` の「`SuggestCreator` のみが呼ぶ」制約は Javadoc でしか表明できない** [確認]（別パッケージのため package-private にできない）。**将来これが管理画面から呼ばれると規則 6 が事実上復活する。** **呼び出し元が 1 箇所であることを grep で確認することを推奨する** [提案]（`0010` §7 の 7 ／ §8 の 7）。
  - **【X-6】規則 2（型を問わない catch）の副作用として、障害時に全行分の WARN が並びうる** [確認]。fail-closed と引き換えのコストであり、**規則 2 を狭めて回避しない**（狭めると X-5 が塞いだ穴が再び開く）。

#### ステップ A-3: 切替可否ガード G1 / G3 の設置（MO-2 / MO-18）

- **目的**: `exitCode` を見ずに切替と旧世代削除まで進む現行の欠陥を塞ぐ。**R0 で単独にリリースできる安全網**（`0003` 第 14 版 §10.1）。
- **対象**:
  - `(fess) exec/SuggestCreator.java`（**改変**。`:243-306` の `create()`）
  - **【X-7 で追加】`(fess) helper/SuggestHelper.java`（**改変**）— 更新エイリアスに対する件数取得メソッドを 1 つ新設する（MO-27）。**それ以外のメソッドに触れない。**
  - **【X-6】着手時点で `:255` / `:258` は既に `storeAllBadWordsForRebuild()` / `storeAllElevateWordsForRebuild()` の呼び出しに切り替わっており（A-2 の作業内容 8）、戻り値だけが捨てられている状態である。** 本ステップはその戻り値を読む。
- **設計書の対応**: `0003` MO-2 / MO-3 / MO-18 ／ **`0003` 第 13 版 §10.4 (j)（A-2 / A-3 の担当範囲の境界）** ／ `0003` §4.2 / §4.3（**変更後の制御フロー図が L461-481 にある**）
- **作業内容**:
  1. **G3 を置く**: `:295` の直後（`:297` の直前）に `exitCode != 0` の検査を入れ、真なら **`switchIndex()`（`:298`）を実行せず** `return exitCode` する。
     - **【2026-09-07・逸脱 X-8 で改訂】`removeDisableIndices()`（`:301`）は不合格時にも実行する** [確定]。**第 16 版までの MO-2 は「切替と `removeDisableIndices()` を実行せずに終了する」と 2 つを束ねていたが、その束ね方が防いでいるのは D-b（切替直後の旧世代の即物理削除）だけであり、切替を飛ばした状態では成立しない** [確認]。**一方 `removeDisableIndices()` の呼び出し元は本ファイルの 1 箇所しか無く、飛ばすと孤児インデックスの回収機構そのものが止まる** — `createNextIndex()` が毎回無条件に次世代を作るため、**ガードが不合格を返し続ける間は実行のたびに孤児が 1 つずつ増える。** **安全性の根拠と `SuggestAliasStateUnknownException` 経路（そちらでは従来どおり呼ばない — K-18 / T-S12）との境界は `0003` 第 17 版 §4.3.1 ／ 判定の全文は `0019`。** **回収は best-effort とし、失敗しても終了コードを変えない。**
  2. **G1 を置く**: S1（`:252` の `createNextIndex()`）の**直前**に旧世代の件数を `suggester.getAllWordsNum()`（`Suggester.java:424`、fess 側の呼び出しは `(fess) helper/SuggestHelper.java:340`）で取得して保持する。S3 相当の位置（G3 の後）で次世代の件数を同じ手段で取得し、**0 でない かつ 旧世代件数の一定割合（既定 50%）以上**を検査する。不合格なら理由をログに出して `return 1`。
     - **【2026-09-04・逸脱 X-7 で解消済み】本項は現行 API では字義どおり実装できない** [確認]。**`getAllWordsNum()` は検索エイリアスしか見ない**（`(sug) Suggester.java:444-453` の `:446`）一方、**次世代は更新エイリアス `index + ".update"` 側にある**（`:459-461` ／ `:263`）。**G1 の判定位置は `switchIndex()` の前であり、その時点で検索エイリアスは旧世代を指したままである。** 字義どおり実装すると新旧どちらも旧世代の件数になり、**G1 は無条件合格の no-op になる**（DoD「次世代件数 0 で切替が中止される」を満たせない）。**対処は確定した（区分 I の逸脱 X-7・MO-27。決定日 2026-09-04）**:
       - **旧世代の件数**: S1（`:252` の `createNextIndex()`）の**直前**に `suggester.getAllWordsNum()`（fess 側の呼び出しは `(fess) helper/SuggestHelper.java:340`）で取得して保持する。**検索エイリアス側でよい** — 判定時点で検索エイリアスは旧世代を指しているためである。
     - **【2026-09-07・レビュー反映（`0020`）】次世代の件数取得は G3 の後に置く**（本項の字面どおり）[確定]。**初回の実装は G3 判定より前に無条件で発行しており、`0018` §4.1（指摘 3）が「プランの記述と違う」と指摘した。** **X-8 の適用によりこれは体裁の問題ではなくなった** — **`getNextGenerationWordsNum()` が例外を投げると `create()` がガードの明示的な `return` を通らずに抜け、X-8 で加えた `removeDisableIndices()` も飛ばされる。** **取り込みが失敗している実行（＝ G3 不合格。まさに孤児が溜まる経路）でこれが起きると X-8 の是正が空振りする。** **G3 不合格なら件数を取らずに `return` すること。**
       - **次世代の件数**: **`(fess) helper/SuggestHelper.java` に更新エイリアス（`suggester.getIndex() + ".update"`）を数える package-private メソッドを新設し、それを使う。** `SearchEngineClient` で `setSize(0)` ＋ `setTrackTotalHits(true)` の `match_all` を発行する（`(sug) Suggester.java:444-453` の `getNum()` と同型）。
       - **更新エイリアスの命名規約を fess 側に複製することになる** [確認]（`getUpdateAlias` は `(sug) Suggester.java:459` の private で参照できない）。**複製である旨と、R1 で `lifecycle.wordCountStats()` へ移して撤去することをコメントに明記する。**
       - **fess-suggest には一切手を入れない**（C-01）。**判定の全文・却下した 2 案・前提の確認は `0016-deviation-x7-g1-next-generation-count.md` ／ 設計は `0003` 第 16 版 §4.2.4（MO-27）。**
  3. **旧世代不在の初回は割合判定を適用しない**（`0003` §4.2 L362）。
     - **【2026-09-02】判定条件は「エイリアス不在」ではなく「旧件数 0」である** [確認]。**`createIndexIfNothing()` が `SuggestHelper` の初期化時に走る**（`(fess) helper/SuggestHelper.java:155` ／ `(sug) Suggester.java:215-216` が検索・更新の両エイリアスを同一インデックスへ付ける）ため、**`SuggestCreator` が動く時点で検索エイリアスは必ず存在する。** **エイリアスの存在検査を入れない**（`0015` §4）。
  4. **G2 はスキップする**（`0003` 第 14 版 §10.1 の R0 / R1 差分表）。`validateNext` は **R1 用の fess-suggest 成果物**（D-6）で入るため R0 では実行できない。**スキップしていることをコメントで明記し、R1 の後続タスク（G2 の fess 側実装）で埋める旨を書く**。**R0 ではメジャー移行が起きないため、G2 の不在は安全網の不足にならない。**
  5. **A-2 の失敗件数を G3 に合流させる**（`0003` §4.2.2「語管理経路も同じく G3 に合流する」）。**【X-6 で改訂】**
     - **`:255` の `storeAllBadWordsForRebuild()` と `:258` の `storeAllElevateWordsForRebuild()` の戻り値（`int`）を受け取り、いずれかが 0 でなければ `exitCode.set(1)` する。** **受け渡し形（戻り値 `int`）は `0010` で確定済みであり、本ステップで再検討しない**（`0009` §11 の 2 はこれで閉じる）。
     - **この数は「失敗した行の数」である**（行 ID で dedupe 済み。`0003` 第 13 版 §10.4 (e) の 3 / (f)）。**「項目処理数」ではない** — 第 12 版の記述を参照しないこと。
     - **G3 は 0 / 非 0 の二値としてしか使わない**（`0003` §4.2.2）。**閾値を設けない。**
     - **public 3 メソッド（`storeAllElevateWords(boolean)` ほか）を呼んではならない** — それらは fail-fast であり失敗件数を返さない（MO-25 の規則 6）。
     - **【2026-09-04 決定】生キー削除（A-1 / MO-24 の移行期クリーンアップ）の失敗は世代切替の阻止へ昇格させない** [確定]。`deleteOneElevateWordRow` の 2 回目の削除（`rawWord` 側）**だけ**を個別に `catch` して WARN を出し、**`failedIds` には入れない。** **理由**: 2 回目は移行期クリーンアップであって**行データの妥当性とは無関係**であり、`0003` §4.2.2 の「不正行を運用者が直すまで世代を更新させない」という意図は**正規化キー側の失敗にしか合わない**（`0014` §2.2 ／ `0015` §5）。**1 回目（正規化キー側）は従来どおり隔離の対象であり、失敗すれば `failedIds` に入る。** **発火経路は `(sug) index/operations/WordManagementOperations.java:127` の `settings.elevateWord().delete(...)` が `try` の外にあること** [確認]（writer 層は `(sug) index/writer/SuggestIndexWriter.java:83-91` で例外を握るため寄与しない）。**`0003` の改訂は不要**（§4.2.2 の意図の**適用範囲の明確化**であって意図そのものの変更ではない ／ 判定は `0016` §6 の 1）。**記録は `0007` §3。**
  6. **割合下限は設定可能にするか固定にするか**: `0003` §13 の 5(a) が「既定 50% は実測に基づかない」としているため、**[提案] 定数として置き、設定キー化は R1 の後続タスク（N-02 と同時）に送る**。
  7. **ガード判定部を検査可能なメソッドへ切り出す**（**軽微なリファクタリング・A-6 のテストの前提**）。現行の `create()` は **`private int create()`**（`(fess) exec/SuggestCreator.java:243`）で、`ComponentUtil.getSuggestHelper()` を静的に取得する一枚岩の制御フローであり、**DI の差し込み口が無い** [確認]。このままでは A-6 の T-S1 / T-S2 相当テスト（`Suggester` をスタブ化して `switchIndex()` が呼ばれないことを検査する）が書けない。
     - **切り出す単位**: 「G1 の判定」「G3 の判定」「切替を実行してよいかの総合判定」を、**引数で件数・`exitCode`・失敗件数を受け取り真偽を返す package-private なメソッド**にする。`SuggestHelper` / `Suggester` の取得は `create()` 側に残す。
     - **`0003` MO-1 と矛盾しない** [確認]。MO-1 が禁じているのは「**fess-suggest に高水準の再構築 API を新設すること**」であり、本ステップは **fess 側内部の整理**である。`0003` §4（L457）が「fess 側に置くと決めているのは**判定と順序制御**であって、エイリアス遷移そのものではない」と明記している。判定の主体は fess 側のままである。
     - **`create()` のシグネチャは変えない**（`private int create()` のまま）。切り出したメソッドだけを package-private にする。**【2026-09-04 追記・区分 II】A-6 のレビュー反映（`0017`）で `create()` の可視性のみ package-private に変えた** — **T-S1（`exitCode != 0` のとき `switchIndex()` / `removeDisableIndices()` が呼ばれないこと）を実行検証するには `create()` を呼べる必要があるためである。引数・戻り値・実行文はいずれも無変更であり、本項の趣旨（ガード切り出しのために `create()` を作り直さない）は守られている**（判定は `0017` §4）。
- **DoD**:
  - `exitCode = 1` のとき `switchIndex()` が呼ばれない。**【2026-09-07・X-8 で改訂】`removeDisableIndices()` は呼ばれる**（作業内容 1 ／ `0003` 第 17 版 §4.3.1）。**第 16 版までの「`switchIndex()` / `removeDisableIndices()` がともに呼ばれない」は撤回する。**
  - 次世代件数 0 で切替が中止される。**【X-7】次世代の件数は更新エイリアスに対して数えていること** — 検索エイリアスを数えていると本項は原理的に満たせない（MO-27）。
  - **旧件数 0（初回）では割合判定が働かない**（**【X-7】「旧世代不在」ではなく「旧件数 0」で判定する。エイリアスの存在検査を入れない**）。
  - **【X-7 で追加】`ForRebuild` 2 メソッドの戻り値が `exitCode` に合流している**こと（作業内容 5。A-2 の DoD「失敗件数が A-3 の `exitCode` 判定に到達する」をここで閉じる）。
  - **【X-7 で追加】`modules/fess-suggest` が無変更である**こと（C-01）。
  - `create()` の戻り値が `process()`（`:236-239`）に伝わり、**`ret == 0` のときだけ `purge()` が走る**現行動作が保たれている。
- **検証**: `mvn test -Dtest=SuggestCreatorTest`（A-6 でテストを足した後）
- **依存**: **A-2**（`ForRebuild` 2 メソッドの新設と `:255` / `:258` の呼び先切替。**受け渡し形は確定済み**）
- **注意点/リスク**:
  - **現行の `create()` は `exitCode` に関係なく `:298` / `:301` を必ず実行する** [確認]。ここが本ステップの本体であり、**挙動が変わる**。既存の統合テストが「切り替わること」を前提にしていないかを確認する。fA
  - **`:244-247` の早期 return 0**（`isSuggestDocuments()` と `isSuggestSearchLog()` が両方 false）を壊さないこと。この経路は `createNextIndex()` すら呼ばない。
  - **MO-1 を守る**: ガードは fess 側に置く。fess-suggest に `rebuild(...)` のような高水準 API を新設しない（`0003` §4.3 L449）。
  - **【2026-09-04 更新】着手前に `0015-assessment-a3-readiness.md`（着手可否判定）と `0016-deviation-x7-g1-next-generation-count.md`（G1 の方針・確定）を読むこと。** **依存関係は充足しており、作業内容 2 の未決も X-7 で解消済みである。****また `(fess) exec/SuggestCreator.java` の行番号は A-2 が足したコメント 3 行分ずれている** — 現物は `create()` = `:243-307` ／ G3 の設置位置 = `:298` の直後・`:300` の直前 ／ `switchIndex()` = `:301` ／ `removeDisableIndices()` = `:304` ／ `return exitCode.get()` = `:306`（`0007` §3 の引き継ぎ 5 ／ `0015` §1.1）。
  - **【2026-09-04 決着】`0007` §2.11 の 11（3 回目のレビュー指摘 2）は作業内容 5 で判断済みである** — **生キー削除の失敗は昇格させない**（2 回目の削除だけを個別 `catch` して WARN。`failedIds` に入れない）。発火点は `(sug) index/operations/WordManagementOperations.java:127` が `try` の外にあること [確認]。`0003` §4.2.2 の意図は正規化キー側の失敗にしか合わない（`0014` §2.2 ／ `0015` §5 ／ `0016` §6 の 1）。
  - **【2026-09-02】`:244-247` の早期 `return 0` より前に G1 の旧件数取得を置かないこと** [提案]。この経路は `createNextIndex()` すら呼ばず、切替も起きないため件数取得が無駄になる（`0015` §6 の 3）。

#### ステップ A-4: `(fess res) suggest_indices/` の `number_of_replicas` 削除（3 ファイル・U-2 の決定）

- **目的**: `0002` DM-6 が挙げる 7 ファイルのうち、**fess 本体側にある 3 ファイル**を **R0** で処理する。**U-2 の決定によりフェーズ C（C-3）から移した。**
- **対象**（すべて**改変**。各ファイルの `:5`）:
  - `(fess res) suggest_indices/suggest_analyzer.json`
  - `(fess res) suggest_indices/_aws/suggest_analyzer.json`
  - `(fess res) suggest_indices/_cloud/suggest_analyzer.json`
- **設計書の対応**: `0002` DM-6 / §3.2 ／ C-14 ／ `0003` §8.2 / §8.4
- **作業内容**:
  1. 各ファイルから **`"number_of_replicas": 0,` の 1 行を削除する**。`refresh_interval` / `number_of_shards` / `auto_expand_replicas` は**据え置き**。
  2. **`total_fields.limit` は追加しない**（`0002` §3.3 が「残り 6 ファイルは削除するだけ」と明記）。
  3. **`(sug res)` 側の 4 ファイルには触れない**（C-3 の担当）。
- **DoD**:
  - 3 ファイルから `number_of_replicas` が消えている。
  - **他のキーが変わっていない**（`diff` で 1 行削除のみであることを確認）。
  - `modules/fess` が `mvn compile` / `mvn test` で通る。
- **検証**: `grep -rn "number_of_replicas" modules/fess/src/main/resources/suggest_indices/`（0 件）／ `git diff --stat`（3 ファイル・各 1 行削除）
- **依存**: なし（A-1〜A-3 と並行可）
- **注意点/リスク**:
  - **実効挙動は変わらない** [確認]。`0003` §8.2 が実機確認済みのとおり、`auto_expand_replicas` が設定されている場合 OpenSearch が `number_of_replicas` を上書きするため、**既存の `0` は一度も効いていない**。**リリースノート項目にしない。**
  - **`suggest_analyzer.json` はクラスパス衝突リソースである** [確認]（`0003` §8.4）。fess 本体側（`WEB-INF/classes`）が fess-suggest jar 側（`WEB-INF/lib`）を遮蔽する。**どちらが優先されるかに関わらず 7 ファイルすべてを直さなければ削除は完了しない**（`0002` §3.2）。**本ステップと C-3 の両方が揃って初めて DM-6 が達成される。**
  - **`(fess res)` 側に `suggest_indices/suggest.json` を新規に置いてはならない**（`0003` §8.4）。本ステップで既存 3 ファイルを触る際に、うっかり新設しないこと。A-6 の assert テストがこれを機械的に守る。

#### ~~ステップ A-5: `.prev` 付与の暫定実装（M-6・U-7 の決定）~~ — **【2026-08-31 削除】**

> **本ステップは削除した。着手前であり、実装は 1 行も存在しない** [確認]（`0007` §5 が「未着手」と記録している）。
>
> **削除の理由**: 本ステップは **L1 期間（新 fess-suggest ＋ 旧 fess 本体）に実際のメジャー移行が走るのに `.prev` が無く、切り替わった後の戻り先が存在しない**という問題への暫定対処だった（§7.5.1 の M-6 / U-7）。**R-P1（常に同時更新）によりその区間が消滅したため、対処すべき問題が無くなった**（`0003` 第 14 版 §10.1 / §10.6）。
>
> **`.prev` そのものは捨てていない。** **R1 では正式な primitive（`switchIndexRetainingPrevious()` / `rollbackToPrevious()` / `aliasState()`）を最初から使う** — 実装は **ステップ D-2**（L1-26 / L1-27 / L1-28）にあり、**削除していない**。**サービスを停止できることは、切替後に問題を発見しないことを意味しない**（`0003` §10.6.3 の 1）。
>
> **本ステップに紐づいていた項目もすべて撤回した**: §3.2 の **P-08** ／ §7.5 の **M-6** と §7.5.1 ／ ステップ **A-6 の作業内容 7** ／ §8 の DoD 11 の「回復（暫定 `.prev`）」。**A-6 の依存から A-5 を外した。**

#### ステップ A-6: **R0** 分のテスト

- **目的**: **R0** の 3 変更に回帰検知能力を与える。**現行の fess 側テストは回帰検知能力を持たない**（`0003` MO-13 / §1.4 の 11）ため、**既存テストの補強ではなく新規作成**になる。
- **対象**: `(fess test) helper/SuggestHelperTest.java`（**改変または新規別クラス**） ／ `(fess test) exec/SuggestCreatorTest.java`（**改変**） ／ **Q11(D) 用の新規テスト**（**新規**） ／ **【2026-09-04 追記・区分 II】`(fess) helper/SuggestHelper.java`（production・**改変**）** — **テストの差し込み口（seam）として protected な 1 行ラッパ 3 つ（`addElevateWordToIndex` / `deleteElevateWordFromIndex` / `addBadWordToIndex`）を新設し、既存の `suggester.indexer().xxx(...)` 呼び出し 8 箇所を置き換えた。** **作業内容 1 の [提案]「`Suggester` / `SuggestIndexer` をスタブ化する」が成立しないためである** — **`SuggestIndexer` の唯一の public コンストラクタが `settings.badword().get(true)` を呼び、その先の `BadWordSettings` → `ArraySettings` のコンストラクタが実クラスタの `Client` を叩くので、単体テストではインスタンス化できない** [確認]。**設計書（`0003` §11.1 / §11.3）はテストのホスト先と検証内容しか定めておらず差し込み口の方式を定めていないため、設計判断は動いていない（新しい X / MO 番号は起こさない）。** **判定の論理と根拠の行番号は `0007` §6.4 を参照。** **【2026-09-04 追記・区分 II】さらにレビュー反映（`0017`）で production 2 ファイルに手を入れた** — **`(fess) exec/SuggestCreator.java` は `create()` の可視性のみ package-private へ（実行文は無変更）、`(fess) helper/SuggestHelper.java` は `getNextGenerationWordsNum()` の検索チェーンを `protected countWordsInIndex(String)` へ切り出した（振る舞いは無変更）。いずれも実行可能なテスト（T-S1 / MO-27）を成立させるための差し込み口であり、設計判断は動いていない**（判定は `0017` §4）。**あわせてテスト 2 本（`(fess test) helper/SuggestHelperNextGenerationCountTest.java` ／ `(fess test) unit/StubSuggester.java` ＋ `(fess test) unit/ModulePaths.java`）を新設した。**
- **設計書の対応**: `0003` §11.3 の T-F3 / MO-13 ／ `0003` §11.1 の T-S1 / T-S2（先行版で検証可能な範囲） ／ `0003` §8.4 / §13 の 7
- **作業内容**:
  1. **T-F3 相当**: `addElevateWord` の入力バリデーション。先頭・末尾に空白を含む語（`" test"`）、全角空白、連続空白、空文字の各ケースで `ElevateWord` に渡る `word` / `readings` に空文字要素が含まれないこと。
     - **MO-24 の検証も同じ T-F3 の範囲に含める**（**X-4** ／ `0003` 第 10 版 §10.3.1 (f)。**新しい T 番号は起こさない**）: ①**`addElevateWord` と `deleteElevateWord` が同じキー（同じ正規化関数の出力）を使う**こと — 正規化で文字列が変わる語（`"東京　タワー"` / `" test"` / `"a  b"`）を追加してから削除し、**ドキュメントが残らない**こと。②**正規化前後で語が変わる場合に、生キー側の削除も発行される**こと。③**変わらない場合は削除が 1 回だけ**であること。④`deleteAllElevateWord` についても同じ 3 点。**`Suggester` / `SuggestIndexer` をスタブ化し、`deleteElevateWord(...)` に渡された引数列を検査する形で足りる**（実クラスタ不要）[提案]。
  2. **A-2 の検証**（**X-5 / X-6** ／ `0003` **第 13 版** §10.4 (g)・**MO-25** ／ `0010` §8 の 3。**新しい T 番号は起こさない**）: 次の **4 点**を検査する。
     - ①**追加フェーズ**: 不正データ（`SuggestItem` 化に失敗する語、および `boost` が `null` の行）を 1 件含む入力で **`storeAllElevateWordsForRebuild()` が完走**し、失敗件数が **1（等値）**であること。
     - ②**削除フェーズ**（**X-5 で追加**）: `getSuggestWord()` が `null` を返す行（`suggestWord` が空文字または未設定）を 1 件含む入力で **再構築経路の削除フェーズが完走**し、**`storeAllElevateWordsForRebuild()` の失敗件数が 1（等値）**であること。**削除フェーズは追加フェーズより先に駆動されるため、ここを検査しないと A-2 の目的（再構築全体を落とさない）が検証されない。**
     - ③`storeAllBadWordsForRebuild()` についても①と同じこと。**`deleteAllBadWords()` は行単位ループを持たないため隔離対象外である**ことを、テスト側でも前提として明示する（`0003` §10.4 (e) の 5）。
     - ④**【X-6 で追加・回帰防止】`storeAllElevateWords(false)` / `deleteAllElevateWord(false)` / `storeAllBadWords(false)` が、同じ不正行に対して従来どおり例外を伝播する**こと。**これは MO-25 の規則 6（失敗隔離を再構築経路に限定する）が守る対象そのものであり、検査が無いと次の実装で再び隔離が public 側へ漏れる**（`0003` 第 13 版 §10.4 (g) の 4 ／ (i)）。
     - **【X-6】失敗件数は「1 以上」ではなく「1」（等値）で検査する。** 失敗件数は**行 ID で dedupe された「失敗した行の数」**であり（`0003` 第 13 版 §10.4 (e) の 3 / (f)）、**1 件の不正行は両フェーズで落ちても 1 件である。** **第 12 版が「1 以上で検査する」としていたのは撤回された** — **等値でなければ二重計上の回帰を検知できない**（`0010` §2.4）。**第 12 版までの記述（`0009` §11 の 3 ／ `0007` §2.11 の 3）を参照しないこと。**
     - **【2026-09-01・3 回目のレビュー指摘 4 の是正版】モック行には必ず一意で非 `null` の `getId()` を設定する**（`0013` §4.2 ／ `0007` §2.11 の 12）。**`failedIds` は `HashSet<String>` で `null` 要素を 1 つしか保持できないため、id を設定し忘れた不正行が複数あると「失敗件数 1（等値）」が dedupe ではなく `null` の潰れで偶然通る。** **本番経路で `getId()` が `null` になることは無い**（`selectList` は検索ヒットの `_id` を必ず入れる — `EsAbstractBehavior:166`）ため、**`getId()` が `null` の行を検査対象にはしない。**
     - **[提案] `ForRebuild` メソッドの呼び出し元が `(fess) exec/SuggestCreator.java` の 1 箇所だけであることを grep で確認する検査を足す**（`0010` §7 の 7 ／ §8 の 7）。**Javadoc でしか表明できない制約であるため、機械的に守る手段がこれしかない。**
     - **⑤【2026-09-07・レビュー反映（`0020`）で追加】生キー削除の失敗を昇格させないこと**（作業内容 5 の 2026-09-04 決定 = `0016` §6 の 1・**[確定]**）。**この決定は 4 文書（`0013` / `0014` / `0015` / `0016`）にまたがって確定させたにもかかわらず、`0018` §3 の時点で `(fess) helper/SuggestHelper.java` の隔離側 `catch` はテスト 7468 件のどれからも実行されていなかった** [確認]（既存 2 クラスは、片方が正規化不変の語しか使わず、もう片方が fail-fast 経路だったため）。**次の 3 件を対にして置く** — **(a) 正規化で語が変わる行（`"東京　タワー"`）で生キー削除だけを失敗させ、`storeAllElevateWordsForRebuild()` の戻り値が 0 であること**（＋ 正規化キーの削除と追加は走っていること）、**(b) 同じ行で正規化キーの削除を失敗させ、戻り値が 1 であること**、**(c) public 側（`deleteAllElevateWord(false)`）は生キー削除の失敗も従来どおり伝播すること**（MO-25 の規則 6）。**(a) と (b) を対にすることが要点である** — **(a) だけでは「どちらのキーの失敗も数えない」実装でも通り、決定の本体（どちらのキーの失敗かで扱いが分かれること）を固定できない**（`0018` §3.3）。
  3. **T-S1 相当（先行版）**: `exitCode = 1` のとき `switchIndex()` が呼ばれないこと。**【2026-09-07・逸脱 X-8 で改訂】あわせて `removeDisableIndices()` が呼ばれることを検査する** — **第 16 版までの「両方とも呼ばれない」は撤回した**（`0003` 第 17 版 §11.1 の T-S1 ／ §4.3.1）。**T-S12（判定不能時は呼ばない）と取り違えないこと。****`0003` §11.1 は T-S9 について「`IngestResult` を返すスタブで足り実クラスタ不要」としており、同じ方針で `Suggester` をスタブ化する。** **前提: A-3 の作業内容 7 でガード判定部が package-private メソッドへ切り出されていること** — 現行の `private int create()`（`(fess) exec/SuggestCreator.java:243`）は一枚岩でスタブの差し込み口が無い [確認]。
     - **【2026-09-04・レビュー反映（`0017`）で更新】初回の実施はガード述語の真偽検査 ＋ ソース構造検査で代替していたが、これは T-S1 の完了条件を満たさない**（レビュー指摘 1）。**現在は `create()` を実際に走らせ、`Suggester` のライフサイクル呼び出しを記録して検査する**（`SuggestCreatorTest:392` / `:410` / `:431` / `:452` / `:469`）。**`Suggester` はスタブ化できる**（コンストラクタは代入と `settings.getAsString` のみ — `0017` §3.1 の 3）。**`SuggestHelper` は `ComponentUtil.register(..., "suggestHelper")` で差し替える。** **構造検査（`:365`）は削除せず併置する。**
  4. **T-S2 相当（先行版）**: 件数が旧世代の 50% 未満／0 件で切替中止。旧世代不在の初回は割合判定を適用しないこと。
     - **【2026-09-04・レビュー反映（`0017`）で追加】MO-27 の実行検査**: **`getNextGenerationWordsNum()` が数えに行く索引名が更新エイリアス（`suggester.getIndex() + ".update"`）であること**（`(fess test) helper/SuggestHelperNextGenerationCountTest.java:39` / `:50`）。**純関数 `canSwitchByWordsNum` の検査だけでは「検索エイリアスへ戻す回帰」を検知できない**（レビュー指摘 2）。
  5. **Q11(D)**: `(fess res) suggest_indices/suggest.json` が**存在しない**ことを assert するテストを追加する（`0003` §8.4 の禁止規則の機械化）。**テスト名とコメントに「置くと fess-suggest jar 側のリソースを遮蔽し、API 引数と JSON の二重管理になる（`0003` §8.4）」という理由を書く。**
  6. **A-4 のリソース回帰**: `(fess res) suggest_indices/` 配下の 3 ファイルに `number_of_replicas` が**含まれない**ことを assert するテストを追加する。**JSON リソースはコンパイルエラーで守られないため、テストで守る。**
  7. ~~**A-5（`.prev`）の検証**~~ — **【2026-08-31 削除】A-5 の削除に伴う。** **`.prev` の検証は fess-suggest 側の T-S4 / T-S5 / T-R1 として R1 で行う**（フェーズ F / `0003` §11.1）。
  8. **既存 `SuggestHelperTest` の握り潰し構造には手を入れない**（**後続タスク**の T-F1 で新規作成する。ここで中途半端に直すと衝突する）。**新規テストは別クラスに置く**ことを推奨する。
- **DoD**:
  - 上記 8 項目のうち**テストを伴う 6 種**が緑（**7 は削除済み**）。
  - **作業内容 1 の MO-24 検証 4 点（①〜④）が緑**（**X-4** ／ §8 の DoD 15）。
  - **作業内容 2 の MO-25 検証 4 点（①〜④）が緑**（**X-5 / X-6** ／ §8 の DoD 16）。**【2026-09-07 追加】⑤（生キー削除の失敗を昇格させないこと。3 件）も緑**（`0020` ／ `0018` §3）。**とくに②（削除フェーズ）と④（public が例外を伝播すること）を落とさないこと** — ②を省くと A-2 の目的そのものが未検証のまま残り、**④を省くと MO-25 の規則 6（X-6 の是正内容）に回帰検知が付かない**。
  - **【X-6】失敗件数の検査が「1 以上」ではなく「1」（等値）になっている**こと。
  - **各テストが実際に失敗しうることを確認する**（実装を一時的に戻して赤くなることを 1 回確かめる）。**現行 fess 側テストの最大の問題は「常に緑」であることなので、これは必須の確認である。**
  - `modules/fess` で `mvn test` が全緑。
- **検証**: `mvn test`（`modules/fess`）
- **依存**: **A-1 / A-2 / A-3 / A-4**
- **注意点/リスク**: 統合テスト（`it/admin/SuggestTests.java` ほか、`@Tag("it")`）は**命名規約が `*IT.java` ではなく `*Tests.java`** であり `modules/fess/pom.xml:79` の `integrationTests` profile で回る [確認]。**本ステップでは統合テストを追加しない**（T-F4 は後続タスク）。 **【2026-09-04 追記】ソース／リソースをファイルとして読む検査（構造検査・grep 検査・リソース検査）は作業ディレクトリに依存させない** — **production クラスのロード元からモジュール根を導く `(fess test) unit/ModulePaths.java` を通す**（レビュー指摘 3 ／ `0017` §1 の 3）。

> **フェーズ A の完了 = R0 をリリースできる。** ここまでを 1 つのリリースとして出す。**R0 のリリースが完了していなくてもフェーズ B〜F の実装は進められる**が、**R1 には必ずフェーズ A の変更が入っていなければならない**（`0003` §10.3 の同一リリース制約）。**R0 として先に別リリースするのは方針であり、その根拠は §5.5 の表の 2 点である**（技術的必然ではない）。

---

### フェーズ B: 基盤型（`api` / `spi` の宣言と DTO）

> **`modules/fess-suggest` の `feature/suggest-l1` ブランチで行う。**
> このフェーズは**宣言と値オブジェクトだけ**を作る。振る舞いはフェーズ D で実装する。分ける理由は、`api` / `spi` / DTO が互いに参照し合うため、実装を混ぜると 1 ステップが巨大になるからである。

#### ステップ B-1: 例外階層の整備

- **目的**: 以降の全ステップが投げる例外の型を先に確定させる。契約表（`0001` §4.2）より前に済ませられる独立作業。
- **対象**:
  - `(sug) exception/SuggestAuthorizationException.java`（**新規**）
  - `(sug) exception/SuggestAliasStateUnknownException.java`（**新規**）
  - `(sug) exception/SuggestSettingsException.java`（**改変**。親を `RuntimeException` → `SuggesterException`）
- **設計書の対応**: `0001` §4.5（例外階層） ／ D-23（`SuggestAliasStateUnknownException` の役割） ／ MO-20（未適用と判定不能を例外型で区別）
- **作業内容**:
  1. `SuggestAuthorizationException extends SuggesterException` を作る。用途は「許可リスト違反＝呼び出し側のバグ」（`0001` §5）。
  2. `SuggestAliasStateUnknownException extends SuggesterException` を作る。**フィールドとして `aliasState()` の取得結果と元の失敗の cause を保持する**。`0001` §4.5 が「メッセージ文字列判別に頼らせない」と明記しているため、**getter を公開する**。
  3. `SuggestSettingsException`（`(sug) exception/SuggestSettingsException.java:31`）の親を `SuggesterException` に変える。
- **DoD**:
  - 新規 2 クラスが存在し、`SuggesterException` を継承している。
  - `SuggestSettingsException` の親が `SuggesterException` である。
  - `mvn -q compile` が通る。**既存の `catch (SuggestSettingsException e)` は捕捉範囲が広がる方向なので無影響**（`0001` §4.5）。
- **検証**: `mvn -q compile` ／ `mvn test -Dtest='org.codelibs.fess.suggest.**'`（該当パッケージのみ）
- **依存**: なし（フェーズ B の先頭）
- **注意点/リスク**: `(fess) helper/SuggestHelper.java:151` が `SuggestSettingsException` を catch している [確認]。親が変わっても catch は成立する（サブクラス関係は維持）。

#### ステップ B-2: `SuggestKind` を `api` のトップレベル enum へ

- **目的**: `api` → `entity` の逆依存を断つ。以降の DTO 定義がこの型に依存するため先に済ませる。
- **対象**:
  - `(sug) api/SuggestKind.java`（**新規**）
  - `(sug) entity/SuggestItem.java`（**改変**。ネスト `Kind`（`:47-69`）の扱い）
- **設計書の対応**: `0001` D-33 / §1 / §2.6.0
- **作業内容**:
  1. `org.codelibs.fess.suggest.api.SuggestKind` を作る。値は `DOCUMENT("document")` / `QUERY("query")` / `USER("user")`。**`toString()` が文字列を返す現行挙動を保つ**。
  2. **`SuggestItem.Kind` は削除せず残す。** fess 本体が `SuggestItem.Kind.USER.toString()` の形で **9 箇所**参照している [確認]（`(fess) api/v2/handlers/SuggestWordsHandler.java:96,98,101` ／ `(fess) helper/SuggestHelper.java:310,311,312,327,328,329`）。C-01（L1 では fess 本体無変更）を守るため、**`Kind` を `@Deprecated` として残し `SuggestKind` へのブリッジにする**（[提案] 相互変換メソッドを置く）。除去は L3。
  3. パッケージ依存の向き（`spi` → `entity` → `api`）が成立していることを確認する。
- **DoD**:
  - `api/SuggestKind.java` が存在し、`api` パッケージが `entity` を参照していない。
  - `SuggestItem.Kind` が残っており、`toString()` が現行と同じ文字列を返す。
  - **`modules/fess` が無変更でコンパイルできる**（この時点で 1 回確認する — 早期に C-01 の壊れを検知するため）。
- **検証**: `mvn -q install -DskipTests`（fess-suggest）→ `mvn -q -o compile`（fess）
- **依存**: なし（B-1 と並行可）
- **注意点/リスク**: **`0001` D-33 は `Kind` を「`SuggestItem` の入れ子から出す」と書いており、残すとは書いていない。** 残す判断は C-01 を守るための本プランの [提案] である。**L3 で除去する旨を `0001` §2.6.0 の近傍に 1 行追記するのが望ましい**が、設計判断の変更ではなく移行段の明確化なので**区分 II として扱う**（ステップ 0-3 に含めてもよい）。

#### ステップ B-3: `QueryCondition` と 5 述語

- **目的**: `AuthorizationFilter` / `BadWordPolicy` / `SuggestIngestService.deleteByCondition` / `SuggestStore` の **4 箇所が共有する型**を先に確定させる。
- **対象**: `(sug) spi/QueryCondition.java` ほか（**新規**）
- **設計書の対応**: `0001` §3.6（L1161-1183） ／ D-25（`mustNotContain` の追加） ／ §7.2（`DENY_ALL`）
- **作業内容**:
  1. `QueryCondition`（record）: `mustMatchAny` / `mustNotMatchAny`（`List<TermsPredicate>`）、`mustContain` / `mustNotContain`（`List<SubstringPredicate>`）、`timeRanges`（`List<TimeRangePredicate>`）。
  2. 述語 3 種: `TermsPredicate(String field, List<String> values)` / `SubstringPredicate(String field, String value)`（**値は常にリテラル。エスケープは実装責務**） / `TimeRangePredicate(String field, Optional<Instant> gte, Optional<Instant> lt)`。
  3. `static final QueryCondition DENY_ALL` と `QueryCondition and(QueryCondition)`。
  4. **コンパクトコンストラクタで `List.copyOf`**（D-20）。
- **DoD**: 型が揃い、`and` と `DENY_ALL` の単体テストが緑。不変性（返した `List` の変更が失敗する）が検証されている。
- **検証**: `mvn test -Dtest='*QueryCondition*'`
- **依存**: なし（B-1 / B-2 と並行可）
- **注意点/リスク**: `SubstringPredicate` の「値はリテラル、エスケープは実装責務」を **Javadoc に明記する**。`BadWordPolicy.matchCondition` が**エスケープ済みワイルドカード**を返す（`0001` §3.5 L1024-1026）のと役割が違う点を混同しないこと。

#### ステップ B-4a: 公開 DTO 群の新設（純粋な追加）

- **目的**: `0001` §2.5 / §2.6 の DTO のうち **`api` 配下に新規追加するもの**を作る。**既存コードを一切壊さない追加のみ**に限定し、破壊的変更は B-4b に分離する（**指摘 2 による分割**）。
- **対象**: `(sug) api/` 配下（**すべて新規**）: `SuggestQuery` / `PopularWordsQuery` / `SuggestResult` / `SuggestHit` / `SuggestCandidate` / `IndexGeneration` / `WordCountStats` / `WordOpResult` / `BadWordImpact` / `IngestOptions` / `RefreshPolicy` / `SearchWordInput` / `IngestResult`（＋ネスト `ItemFailure`） / `DeleteResult` / `AliasState` / `ResponseField` / `AccessScope`
- **設計書の対応**: `0001` D-19（3 型分離） / D-20（不変化） / D-16（`userBoost` の表現） / §2.5 / §2.6
- **作業内容**:
  1. **`record` にするもの**と **`final class` ＋ private ctor にするもの**を D-20 に従って分ける。`SuggestCandidate` は `final class`。他は `record` だが**配列でなく `List` / `Set`**、コンパクトコンストラクタで `copyOf`。
  2. **`SuggestCandidate` の生成 API は 2 つだけ**: `static document(...)`（`userBoost` は空）と `static elevate(...)`（`kinds = {USER}`）。**`excluded` フィールドを持たせない**（D-17 が型で保証する性質）。
  3. `SuggestHit` は projection なので `Optional` / `OptionalLong` / `OptionalDouble` を多用する。`text` / `tags` のみ常に埋まる。
  4. `IngestOptions`: `bulkSize` / `parallelism` / `RefreshPolicy` / `Runnable pacing` / `LongConsumer onProgress` ＋ `static defaults()`。`RefreshPolicy` は **`NONE` / `ON_COMPLETION` の 2 値のみ**（`PER_BATCH` を作らない — `0003` §7.5）。
  5. `AliasState`: `Optional<String> searchIndex / updateIndex / previousIndex` ＋ `List<String> multiplyAssigned`。
  6. **`entity/SuggestItem` には触れない**（B-4b の担当）。
- **DoD**:
  - 全 DTO 型が存在し **`mvn -q test-compile` が通る**（**`compile` ではない** — §6.3 参照）。
  - **`SuggestCandidate` に `excluded` が無い**ことをテストまたはレビューで確認。
  - 不変性テスト（T-18 の前倒し・新規 DTO 分）が緑。
  - **既存テストが 1 つも赤くなっていない**（純粋な追加なので当然そうなるべきであり、赤くなったら追加以外のことをしている）。
- **検証**: `mvn -q test-compile` ／ `mvn test`（全件・**この時点ではまだ全緑であるべき**）
- **依存**: **B-2**（`SuggestKind`）／ **B-3**（`QueryCondition` は `deleteByCondition` の引数）
- **注意点/リスク**: **このステップで既存テストが赤くなったら、追加のつもりで既存型を変更している。** 切り分けの seam はここにある。

#### ステップ B-4b: `entity/SuggestItem` の改変と既存テストの機械的追従

- **目的**: `SuggestItem` を `final class` ＋ private ctor に改め、`excluded` を追加する。**同時に、これによって test-compile 不能になる既存テストの構築呼び出しを機械的に追従させる**（**指摘 2 による必須作業**）。
- **対象**:
  - `(sug) entity/SuggestItem.java`（**改変**。`final class` 化・private ctor・`excluded` 追加・`OptionalDouble` を持たない `double userBoost`・`Instant timestamp`・`id()` の導出メソッド化）
  - `(sug test)` 配下の **15 ファイル**（**改変**。`new SuggestItem(` の **146 箇所**）
  - `(sug test)` 配下の **4 ファイル**（**改変**。`new ElevateWord(` — `SuggesterTest` / `entity/ElevateWordTest` / `index/SuggestIndexerTest` / `settings/ElevateWordSettingsTest`）
- **設計書の対応**: `0001` D-17 / D-19 / D-20 / §2.6 ／ `0002` §7.1（**ただし §7.1 は意味的改修の範囲であり、本ステップは構築呼び出しの追従に限る**）
- **作業内容**:
  1. **`SuggestItem` を `final class` ＋ private ctor にし、生成を static factory に集約する。**
  2. **`excluded`（boolean）を追加**（D-17）。**`userBoost` は `double`（常に確定値）**、`OptionalDouble` も `userBoostSpecified` も持たない（D-16）。
  3. **`SuggestItem.id()` を「`text` からの導出メソッド」にする**（`0001` §2.6.3）。現行はフィールド保持（`(sug) entity/SuggestItem.java:140`）。**実際の ID 生成規則の差し替えはステップ C-1** — 本ステップでは形だけ導出メソッドにする。
  4. **既存テストの構築呼び出しを機械的に追従させる**（**本ステップの核**）。
     - **アサーションは一切変えない。** 生成方法だけを新 API（static factory）に置換する。
     - **意味的な改修は行わない** — `excluded` の検証追加、ID 規則変更に伴う期待値修正、`userBoost` の丸め撤廃に伴う期待値修正、`score` に関するアサーションの削除は**すべて F-1 の担当**である。
     - **この境界を厳守すること。** 追従のついでに期待値を直すと、`0002` §7.1 の「変えない／意図的に変える」の区別が崩れる。
  5. **`ElevateWord` の構築呼び出しも同様に追従させる**（コンストラクタ引数順 `(String, Float, List, List, List, List)` を変える場合。**変えないなら追従不要** — 変える必要があるかを先に判断する）。
- **DoD**:
  - **`mvn -q test-compile` が通る**（**最重要**。main だけの `compile` では検出できない）。
  - **`mvn test` が実行できる**（全緑である必要はない。**「実行できること」が本ステップの DoD であり、赤の中身は F-1 で直す**）。
  - **アサーションを 1 つも変更していない**ことを `git diff` で確認する（生成呼び出しの行だけが変わっているべき）。
  - 赤くなったテストの一覧を作業履歴に記録する。
  - **`modules/fess` が無変更でコンパイルできる**（`(fess) api/v2/handlers/SuggestWordsHandler.java:110` の `getTags()` が `String[]` を返し続ける必要がある）。
- **検証**: `mvn -q test-compile` ／ `mvn test`（実行可能であることの確認） ／ `git diff --stat`（15 + 4 ファイル） ／ fess 側 `mvn -q -o compile`
- **依存**: **B-4a**
- **注意点/リスク**:
  - **`new SuggestItem(` は 15 ファイル・146 箇所ある** [確認]。内訳: `SuggesterTest` / `SuggesterIndexLifecycleTest` / `entity/SuggestItemTest` / `entity/SuggestItemBoundaryTest` / `entity/SuggestItemMergerTest` / `entity/SuggestItemSerializerTest` / `index/SuggestIndexerTest` / `index/SuggestIndexerErrorHandlingTest` / `index/writer/SuggestIndexWriterTest` / `request/suggest/SuggestRequestBuilderTest` / `request/suggest/SuggestResponseTest` / `request/popularwords/PopularWordsRequestTest` / `request/popularwords/PopularWordsRequestBuilderTest` / `request/popularwords/PopularWordsResponseTest` / `util/SuggestUtilTest`。**「大量に赤くなる」ではなく「test-compile が通らなくなる」ため、機械的追従はこのステップで必須である。**
  - **`mvn test -Dtest='...'` では回避できない** [確認]。`-Dtest` は**実行対象を絞るだけで test-compile は全件走る**。追従を後回しにすると **B-4b 以降 F-1 までモジュール全体のテスト実行が不能**になり、§6.1 の二段構えと §6.3 のルールがその区間で成立しなくなる。
  - **`SuggestItem` の public コンストラクタ廃止は D-28 が明示的に受容した非互換である。** fess 本体は `new SuggestItem` を **0 件**しか持たない [確認] ので C-01 は守られるが、**外部利用者に対する source / binary compatibility は失われる**。README / CHANGELOG への記載は E-4。
  - **`getTags()` / `getReadings()` などの配列 getter を消すと fess 本体が壊れる。** `getTags()` は `(fess) SuggestWordsHandler.java:110` が使っている [確認]（`getReadings()` は 0 件）。**配列 getter は L1 では残す。**

#### ステップ B-5: 設定 API の拡張（`IndexSchema` / `RefreshInterval` / `SuggestSettingsBuilder`）

- **目的**: `0001` §6 の設定 API を作る。`createNextIndex(IndexSchema)` と `updateRefreshInterval` の前提。
- **対象**:
  - `(sug) settings/IndexSchema.java`（**新規**）
  - `(sug) settings/RefreshInterval.java`（**新規**。sealed interface）
  - `(sug) settings/SuggestSettingsBuilder.java`（**改変**）
- **設計書の対応**: `0001` D-9 / D-10 / D-18 / §6.1 / §6.2 ／ `0003` MO-8 / §7.3 ／ C-08 / C-13 / C-14
- **作業内容**:
  1. `RefreshInterval`: `sealed interface` permits `record Every(Duration)` / `record Disabled()`。static factory `every(Duration)` / `disabled()`。**`Optional<Duration>` を採らない**理由（`-1` を表現できない）を Javadoc に書く。
  2. `IndexSchema`（record）: `OptionalInt numberOfShards` / `Optional<String> autoExpandReplicas` / `Optional<RefreshInterval> refreshInterval` ＋ `static useDefaults()`。
  3. `SuggestSettingsBuilder` に追加: 時間設定 **6 種 × 2 形 = 12 メソッド**（`searchTimeout(Duration)` / `searchTimeout(String)` を `index` / `bulk` / `indices` / `cluster` / `scroll` にも）、`numberOfShards(int)`、`autoExpandReplicas(String)`、`refreshInterval(RefreshInterval)`、`IndexSchema indexSchema()`。
  4. **単位付き文字列のパーサを fess-suggest 側に置く**（C-08）。OpenSearch の時間表記（`ms` / `s` / `m` / `h` / `d`）に合わせる。**公開する**（`0001` §9.4 が fess 側から使うとしているため。使うのは L2 だが API は L1 で出す）。
  5. **`numberOfReplicas(int)` は定義しない**（D-10 / C-14）。
  6. **既存メソッドのシグネチャを変えない**。`(fess) helper/SuggestHelper.java:134-142` が `setSettingsIndexName` / `bulkTimeout` / `clusterTimeout` / `indexTimeout` / `indicesTimeout` / `searchTimeout` を使っている [確認]。**既存の `searchTimeout(...)` の引数型と、新設する `searchTimeout(Duration)` / `searchTimeout(String)` のオーバーロードが曖昧にならないことを確認する。**
- **DoD**:
  - 3 ファイルが揃い、時間パーサの単体テストが緑（`"10s"` / `"1m"` / `"500ms"` / 不正入力）。
  - `indexSchema()` が設定から `IndexSchema` を返す。
  - **`modules/fess` が無変更でコンパイルできる**（オーバーロードの曖昧化が起きていないことの確認）。
- **検証**: `mvn test -Dtest='SuggestSettingsBuilderTest,*RefreshIntervalTest,*IndexSchemaTest'` ／ fess 側 `mvn -q -o compile`
- **依存**: なし（B-1〜B-4b と並行可）。**ただし fess 側コンパイル確認は B-4b の後**
- **注意点/リスク**: **オーバーロードの曖昧化が C-01 を壊す典型経路である。** `(fess) helper/SuggestHelper.java:136-140` の呼び出しがすべて既存のシグネチャに解決されることを、コンパイルだけでなく**呼び出し先が変わっていないか**まで確認する。

#### ステップ B-6: `api` 4 インタフェースの宣言

- **目的**: 公開契約を型として固定する。実装は空（フェーズ D）。
- **対象**: `(sug) api/SuggestQueryService.java` / `SuggestIndexLifecycle.java` / `SuggestWordAdmin.java` / `SuggestIngestService.java`（すべて**新規**）
- **設計書の対応**: `0001` D-1 / §2.1 / §2.2 / §2.3 / §2.4。メソッド別契約表は §4.2
- **作業内容**:
  1. `SuggestQueryService`（2）: `suggest(SuggestQuery)` / `popularWords(PopularWordsQuery)`。
  2. `SuggestIndexLifecycle`（**12**）: `createIndexIfNothing(IndexSchema)` / `createNextIndex(IndexSchema)` / `switchIndex()` / `switchIndexRetainingPrevious()` / `rollbackToPrevious()` / `removeDisableIndices()` / `refresh()` / `validateNext(SuggestQuery)` / `updateRefreshInterval(IndexGeneration, RefreshInterval)` / `currentIndexName()` / `aliasState()` / `wordCountStats()`。
  3. `SuggestWordAdmin`（7）: `addBadWord` / `deleteBadWord` / `deleteAllBadWords` / `previewBadWordImpact` / `addElevateWord` / `deleteElevateWord` / `restoreElevateWords`。
  4. `SuggestIngestService`（9）: `index` / `indexFromDocuments` / `indexFromSearchWord` / `indexFrom` / `deleteById` / `deleteByCondition` / `deleteAll` / `deleteByKind` / `deleteOldWords`。
  5. **全メソッドが `CompletableFuture<T>` を返す**（D-3）。同期ラッパを作らない。`Result<T>` 型を作らない。
  6. **Javadoc は 1 行要約 ＋ 契約**（`0001` §4.2 の「正常完了条件 / 例外完了条件」を各メソッドに書く）。**`refresh()` には「suggest インデックスのみを対象とする」を明記する**（`0003` MO-7 (b)）。
  7. **メソッド数を数えて 30 であることを確認する**（D-1）。
- **DoD**:
  - 4 インタフェースが存在し、合計 30 メソッド。
  - `mvn -q compile` が通る。
  - **`api` パッケージが OpenSearch の型を一切 import していない**ことを grep で確認（`0001` §1）。
- **検証**: `mvn -q compile` ／ `grep -rn "org.opensearch" src/main/java/org/codelibs/fess/suggest/api/`（0 件）
- **依存**: **B-2 / B-3 / B-4a / B-4b / B-5**（引数・戻り値の型がすべて揃っている必要がある）
- **注意点/リスク**: `SuggestWordAdmin.addElevateWord(ElevateWord)` は **既存 `entity/ElevateWord` を引数に取る**（`0001` §2.3）。**`api` → `entity` の参照になるが、`0001` §1 が許す向きは `spi` → `entity` → `api` である。** この 1 箇所が向きに反していないかを確認し、反しているなら**区分 I の逸脱として §10 に上げる**（本プランでは判断しない）。

#### ステップ B-7: `spi` 7 インタフェースと補助型の宣言

- **目的**: 拡張点を型として固定する。実装はフェーズ D。
- **対象**: `(sug) spi/` 配下（**新規**）: `SuggestSource.java` / `SourceContext.java` / `ScoringStrategy.java` / `ScoringContext.java` / `ScoringPlan.java` / `ScoringFactor.java`（＋ permits 4 種） / `TextProcessor.java` / `ProcessedText.java` / `TextProcessingContext.java` / `SuggestItemMergePolicy.java` / `BadWordPolicy.java` / `AuthorizationFilter.java` / `SuggestStore.java`
- **設計書の対応**: `0001` §3.1〜§3.7 ／ D-24 / D-25 / D-27 / D-30 / D-31 / D-32
- **作業内容**:
  1. `SuggestSource<I>`: `default boolean supports(SourceContext)` / `Stream<SuggestCandidate> produce(I, SourceContext)`。**`kind()` は作らない**（D-30 で削除済み）。**Javadoc に「`userBoost` を指定しない」（D-27）と「`roles` を空にすると `_guest_` が補われ全ユーザ可視になる」（K-2 ／ `0001` §3.1.3）を書く。**
  2. `ScoringStrategy`: `plan(SuggestQuery, ScoringContext)` / `planForPopularWords(PopularWordsQuery, ScoringContext)`。`ScoringFactor` は **sealed interface permits 4 種**。`VectorSimilarityFactor` は `final class` で `float[]` を ctor / getter 両方で `clone()`（D-20 の例外規定）。
  3. `TextProcessor`: `supports` / `process`。
  4. `SuggestItemMergePolicy`: **`SuggestItem initialize(SuggestCandidate incoming, boolean excluded)`** / `SuggestItem merge(SuggestItem existing, SuggestCandidate incoming)`。**`initialize` の `excluded` 引数は D-32 で追加されたもの**であり、呼び出し元が `badWordPolicy.isBadWord` で判定して渡す。
  5. `BadWordPolicy`（6）: `isBadWord` / `matchCondition` / `releaseCondition` / `add` / `remove` / `badWords`。**`add` / `remove` は既に含まれる／含まれない場合 no-op 成功**（D-29 の収束性）。
  6. `AuthorizationFilter`（2）: `toCondition(List<String> roles)` / `canExposeRoles(AccessScope)`。**Javadoc に「roles が null / 空でも `DENY_ALL` を返さず `_guest_` 条件を返す。空条件を返す実装は契約違反」を明記**（D-11 / §7.2）。
  7. `SuggestStore`（**17**）: lifecycle 10（`createIfAbsent` / `createNextGeneration` / `switchSearchAlias` / `switchSearchAliasRetainingPrevious` / `rollbackSearchAliasToPrevious` / `removeDisabledGenerations` / `refresh` / `currentIndexName` / `aliasState` / `wordCountStats`）＋ write 5（`multiGet` / **`bulkPut(List<SuggestItem>)`** / `deleteByCondition` / `updateExcluded` / `preview`）＋ read 2（`search` / `popularWords`）。**`bulkUpsert` は作らない**（D-31）。
  8. **`spi` も OpenSearch の型を露出しない**（`0001` §1）。
- **DoD**:
  - 7 インタフェース＋補助型が揃い `mvn -q compile` が通る。
  - `SuggestStore` が 17 メソッド、`BadWordPolicy` が 6 メソッド。
  - `grep -rn "org.opensearch" src/main/java/org/codelibs/fess/suggest/spi/` が 0 件。
  - **`SuggestSource.kind()` が存在しない**こと。**`SuggestStore.bulkUpsert` が存在しない**こと。
- **検証**: `mvn -q compile` ／ 上記 grep
- **依存**: **B-2 / B-3 / B-4a / B-4b / B-5**
- **注意点/リスク**: `SuggestItemMergePolicy` は**シグネチャのみ** `0001` が確定し、**挙動の正は `0002` §5**（D-8）。本ステップでは宣言のみ。実装は C-4。

---

### フェーズ C: データモデル

> **`0002` の決定を実装する。** フェーズ B の型の上に載る。
> **フェーズ C に入る前に、ステップ 0-4（§7 の逸脱対処）が完了していなければならない。**

#### ステップ C-1: 決定的 ID の置換（DM-8 / DM-16）

- **目的**: `Base64(text)` の 445 文字切り詰めを SHA-256 ハッシュに置き換え、F-05 の衝突を解消する。
- **対象**:
  - `(sug) util/SuggestUtil.java`（**改変**。`:68` の `ID_MAX_LENGTH` 削除、`:84-90` の `createSuggestTextId` 差し替え）
  - `(sug) entity/SuggestItem.java`（**改変**。`:140` の ID 生成）
  - `(sug) entity/SuggestItemSerializer.java`（**改変**。`:130` の `fromSource` 内の再計算）
  - `(sug) index/operations/WordManagementOperations.java`（**改変**。`:129` の `deleteElevateWord`）
- **設計書の対応**: `0002` DM-8 / DM-16 / §4.1 / §4.2 / §4.4 / §4.4.1
- **作業内容**:
  1. `createSuggestTextId(String text)` を **`Base64URL-without-padding(SHA-256(UTF-8(text)))`** に置き換える。**長さは常に 43 文字**。
  2. `ID_MAX_LENGTH = 445` と `substring(0, 445)` を**削除**する。
  3. **ID 生成の 3 箇所すべてが同じ関数を呼ぶ**ことを確認する（`0002` §4.4 の表）。**生成規則が食い違うのが DM-16 が想定する主要な障害モード（b）である。**
  4. **`kinds` を ID に含めない**（DM-9 ／ `0002` §4.2）。
  5. **`(sug) index/writer/SuggestWriter.java:76-102`（`mergeItems`）のバッチ内重複判定に text 突き合わせ検査を入れる**（`0002` §4.4.1）。ID が一致し `text` が一致しない場合は**項目単位の失敗**として扱う（バッチ全体を落とさない）。**既存ドキュメントとの突き合わせ側（multiGet 後）はステップ D-5 で入れる。**
- **DoD**:
  - `createSuggestTextId` の出力が常に 43 文字、URL-safe（`-` `_`、`=` を含まない）。
  - 同一 text → 同一 ID、334 バイト以上の異なる text → 異なる ID（**T-3 の前倒し**）。
  - `ID_MAX_LENGTH` の残存 0 件（grep）。
  - バッチ内重複判定の text 検査が入っており、**T-15 の「バッチ内重複判定経路」側**が緑。
- **検証**: `mvn test -Dtest='SuggestUtilTest,SuggestItemBoundaryTest'` ／ `grep -rn "ID_MAX_LENGTH" src/`（0 件）
- **依存**: **B-4b**（`SuggestItem.id()` が導出メソッドになっていること）／ **0-4**（§7 の逸脱対処完了）
- **注意点/リスク**:
  - **既存テスト 4 本が意図的に赤くなる**（`SuggestUtilTest.testCreateSuggestTextId` / `testCreateSuggestTextIdBoundaryExactly445` / `testCreateSuggestTextIdBoundaryJustUnder445` / `testCreateSuggestTextIdWithLongText`）。`0002` §7.1 が「意図的に変える」と明記している。**F-1 で改修する。**
  - **`SuggestItemBoundaryTest.test_getId_sameTextSameId` / `_differentTextDifferentId` / `_multiWordOrder` は「変えない」**（`0002` §7.1）。ハッシュ化後も成立すべき意味論であり、**赤くなったら実装が誤っている。**
  - **可逆性の喪失は影響しない** [確認]（`0002` §4.4。リポジトリ全体で ID をデコードしている箇所は 0 件）。
  - **本ステップが §7 の中間状態問題の中心である。** 0-4 を飛ばして着手しないこと。

#### ステップ C-2: 不変条件の強制と `ElevateWord` の読みセマンティクス（DM-12 / INV-1〜3）

- **目的**: INV-1 / INV-2 / INV-3 を `SuggestItem` のコンストラクタで強制し、同時に `ElevateWord.toSuggestItem` を §5.4 の 4 分岐に直す。**この 2 つは同一ステップでなければならない。**
- **対象**:
  - `(sug) entity/SuggestItem.java`（**改変**。コンストラクタ `:113-141`）
  - `(sug) entity/ElevateWord.java`（**改変**。`toSuggestItem()` `:143-149`）
  - `(sug) entity/SuggestItemSerializer.java`（**改変**。`:61-62` / `:155-156` の `reading_i` への null 書き込み — INV-4）
- **設計書の対応**: `0002` DM-12 / §1（INV-1〜INV-5） / §2.3(b) / §5.2 / §5.4 ／ `0003` §10.3 の 1・2
- **作業内容**:
  1. **INV-2 の強制**: 語が区切り文字（半角空白）を含まないことをコンストラクタで検査する。
  2. **INV-1 の強制**: `readings` の第 1 次元長 ＝ `text` の語数 W。違反は例外。
  3. **INV-3 の切り捨て**: W ≤ N（既定 10 / 設定可能 / 設定上限 50）。超過語は切り捨て、**`text` と `readings` を同時に切る**。
  4. **INV-4**: `reading_i` に `null` を書き込まない（`SuggestItemSerializer.java:61-62` / `:155-156`）。**空配列 `[]` は受理する**（`0002` T-12）。
  4b. **欠損 `reading_i` スロットの復元**（`0002` §5.2 の [確定]・第 9 版 ／ **テストは第 10 版の T-24**）: `fromSource`（`SuggestItemSerializer.java:84`）を `text` から導出した W で回す際、**`i ∈ [0, W)` のうち source に `reading_i` が存在しないスロットは要素 0 個のリストとして復元する。存在しないことを理由に例外を投げてはならない。** **L1 期間に旧世代ドキュメントを multiGet で引くと必ず通る経路であり、例外にすると 1 件の旧世代ドキュメントで再構築全体が落ちる**（`0002` §5.2 の却下理由）。
  5. **`ElevateWord.toSuggestItem` を §5.4 の 4 分岐にする**:
     - `W == 1` → `readings[0] = { 全 k トークン }`
     - `W > 1 かつ k == W` → `readings[i] = { token[i] }`
     - `W > 1 かつ k > W` → 位置対応。**余剰トークンは切り捨てる**
     - `W > 1 かつ k < W` → 位置対応。**不足分は `readings[i] = { words[i] }`（語自身）で補う**
  6. **`text` を空白分割して `String[W]` にする**（現行は `new String[]{ elevateWord }` の 1 要素固定）。
- **DoD**:
  - `readings.length != W` の `SuggestItem` 構築が失敗する（**T-4**）。
  - 語に空白を含む入力が拒否または分割される（**T-5**）。
  - N 超過で先頭 N 語だけが残り `text` と `readings` が同時に切れる（**T-6**）。
  - §5.4 の 4 ケース表がそのままテストになっており緑（**T-9**）。**特に W == 1 で k > 1 のとき全候補が `reading_0` に入ること。**
  - `reading_i` への null 書き込みが 0 件。
  - **欠損 `reading_i` を持つ source を `fromSource` で読んでも例外にならず空配列として復元され、incoming との合成後に W 本が揃う**（**T-24**）。
- **検証**: `mvn test -Dtest='SuggestItemTest,SuggestItemBoundaryTest,ElevateWordTest,SuggestItemSerializerTest'`
- **依存**: **C-1**（ID がコンストラクタ内で生成されるため）
- **注意点/リスク**:
  - **INV-1 強制と §5.4 化を分離してはならない** [確定]（`0002` §5.2 の注記）。強制だけを先行させると k ≠ W の elevate word 登録が実行時に全滅する。**同一コミットにする。**
  - **`ElevateWordTest.testToSuggestItemWithCompleteData` / `testMultipleReadingsConversion` は「意図的に変える」**（`0002` §7.1）。**このテストは現行の不具合を仕様として固定していた。**
  - **R0（P-01 / P-02）が未リリースの環境に R1 を出すと、`storeAllElevateWords` が 1 件の不正データで再構築全体を落とす**（`0003` §10.4）。**リリース順序を守ること。**
  - **副次効果** [確認]: `(sug) request/popularwords/PopularWordsRequest.java:213` の `mustNot(existsQuery("reading_1"))` により、現行では「単語に読みを 2 つ付けた elevate word」が人気語から除外されている。新規則では W == 1 のとき全候補が `reading_0` に入るため**この除外が解消する**（`0002` §5.4）。**挙動の変化として記録する。**

#### ステップ C-3: mapping と index settings のリソース改訂（DM-2 / DM-3 / DM-6 / DM-7）

- **目的**: To-Be mapping と index settings を適用する。**7 ファイル**の `number_of_replicas` 削除を含む。
- **対象**:
  - `(sug res) suggest_indices/suggest/mappings-default.json`（**改変**）
  - `(sug res) suggest_indices/suggest.json`（**改変**）
  - `(sug res) suggest_indices/suggest_settings.json`（**改変**）
  - `(sug res) suggest_indices/suggest_settings_array.json`（**改変**）
  - `(sug res) suggest_indices/suggest_analyzer.json`（**改変**）
  - `(sug) constants/FieldNames.java`（**改変**。`EXCLUDED` 追加 — C-5 と分担）
  - ※**`(fess res)` 側の 3 ファイルは U-2 の決定により本ステップの対象外**（**ステップ A-4** が担当）
- **設計書の対応**: `0002` DM-2 / DM-3 / DM-6 / DM-7 / §2.1 / §2.2 / §2.6 / §3.2 / §3.3 / §3.4 ／ `0003` §8.4 / §13 の 7
- **着手前ゲート（G-OS1・本ステップの必須の前提）**: **`0002` が根拠にしている OpenSearch の [確認] 2 件は 3.7.0 の `javap` 走査に依るものであり、現行の 3.8.0 では未検証である**（`0004` §2.4 / §2.8 の 2）。**本ステップの作業に入る前に、次の 2 点を 3.8.0 で確認し、結果を作業履歴に記録する。**
  - **(a) `dynamic: "strict_allow_templates"` が 3.8.0 で受理されること。** 不成立なら M-1 が成立せず、mapping 全体の厳格化方針（`0002` §2.2）を設計に差し戻す（区分 I の逸脱）。
  - **(b) `index.mapping.total_fields.limit` に緩和機構（自動拡張・警告のみで通す等）が存在しないこと。** 不成立なら `0002` §3.4 の連動制約（N ≤ 50 ＋ 固定 11 ＋ 余裕 ≤ 100）の前提が変わる。
  - **確認できるまで本ステップに着手しない。** 逆に **C-1 / C-2 はこのゲートに依存しない** — 止めるのは C-3 以降だけである。
- **作業内容**:
  1. **`mappings-default.json`**（`0002` §2.6 の M-1〜M-8）:
     - M-1: トップレベル `dynamic` に **`"strict_allow_templates"`** を追加（現行は指定なし＝既定 `true`）。
     - M-2: `dynamic_templates` を **置換**する。現行の `match: "*"` ＋ `match_mapping_type: "string"` → `keyword`（`:2-12`）を削除し、**`match: "reading_*"` → `keyword`**（`match_mapping_type` なし）にする。**「追加」ではなく「置換」である** — `*` を残すと厳格化が無意味になる。
     - M-3: `score`（`:36-38`）を **削除**。
     - M-4: `excluded`（`boolean`）を **追加**。**`null_value` を置かない**（`0002` §6.3）。
     - M-5: `reading_0`〜`reading_9` を `properties` に**明示列挙**（**正当性の要件ではなく最適化** — DM-2）。
     - M-6〜M-8: `text` は `keyword` のまま変更なし。`embedding` は**追加しない**（P5）。
  2. **`suggest.json`**: `number_of_replicas: 0`（`:5`）を**削除**。`index.mapping.total_fields.limit: 100` を**追加**。`number_of_shards: 1` は値を据え置き、位置づけを「API 無指定時の既定値」に格下げ（コメントで明記）。`refresh_interval: "10s"` は据え置き。
  3. **`(sug res)` 側の残り 3 ファイル**（`suggest_settings.json` / `suggest_settings_array.json` / `suggest_analyzer.json`）: **`number_of_replicas: 0` の 1 行を削除するだけ**。`total_fields.limit` は追加しない（`0002` §3.3）。**`(fess res)` 側の 3 ファイルは A-4 が担当する** — **本ステップと A-4 の両方が揃って初めて DM-6（7 ファイル）が達成される。**
  4. **Q11(A)**: `(sug res) suggest_indices/suggest.json` に **`"_comment"` キー**を追加し、「**このファイルを `(fess res) suggest_indices/` 側に置いてはならない。置くと jar 側のリソースを遮蔽し、API 引数と JSON の二重管理になる（`0003` §8.4）**」と書く。**JSON パーサが未知キーを拒否しないことを確認する**（OpenSearch の settings に未知キーを送ると失敗しうるため、**`"_comment"` を settings 本体ではなくファイル冒頭のコメント形式で置けるか検証し、無理なら別ファイル（`README` 等）に退避する** — §10 に判断を上げる）。
- **DoD**:
  - `mappings-default.json` が §2.1 の統合定義と一致する。
  - **`(sug res)` 側 4 ファイルから `number_of_replicas` が消えている**（`grep -rn "number_of_replicas" modules/fess-suggest/src/main/resources/suggest_indices/` が 0 件）。**fess 本体側 3 ファイルは A-4 の DoD。**
  - `suggest.json` に `total_fields.limit: 100` がある。
  - **To-Be mapping で `reading_10` 以降が動的に受理されること、`reading_i` に `null` を書くと失敗すること、`[]` は受理されることが検証されている**（**T-12**。OpenSearch runner を使うテスト）。
  - **語数上限 N の設定可能上限（50）＋ 固定 11 ＋ 余裕 ≤ 100 の連動制約**（`0002` §3.4）がコメントで明記されている。
- **検証**: `mvn test -Dtest='*MappingTest,SuggesterTest,SuggesterIndexLifecycleTest'` ／ 上記 grep
- **依存**: **C-2**（`excluded` を書き込む側が INV を満たしていること）
- **注意点/リスク**:
  - **`(fess res)` 側 3 ファイルは本ステップの対象外である**（U-2 の決定によりステップ A-4／**R0** へ移した）。**【2026-08-31 改訂】移動の理由は「C-01（L1 では fess 本体無変更）を守るため」ではない** — その読み方は撤回した（`0000` の C-01 注記）。**現在の理由は「実効挙動が変わらないうえ、R0 で先に閉じれば DM-6（7 ファイル）の grep 検査が早く通るから」である**（`0011` §4）。 本ステップで fess 本体側のリソースに触れないこと。
  - **`dynamic: strict_allow_templates` は OpenSearch 2.16 以上が必要**（`0003` §6.3）。現行 3.8.0 なので満たす [確認]。**満たさない環境では `prepareCreate` が mapping を拒否して失敗するが、取り込み前に落ちるので旧世代に影響が出ない**（同節）。
  - **`suggest_analyzer.json` はクラスパス衝突リソース**である [確認]（`0003` §8.4）。fess 本体側（`WEB-INF/classes`）が jar 側（`WEB-INF/lib`）を遮蔽する。**7 ファイル全部を直さなければ削除は完了しない**（`0002` §3.2）。

#### ステップ C-4: マージ規則の単一化（`SuggestItemMergePolicy` の実装）

- **目的**: 走査基準を W 単一化し、バッチ内マージと既存ドキュメントマージを 1 実装に統合する。**`0002` §5 が挙動の正である。**
- **対象**:
  - `(sug) internal/DefaultSuggestItemMergePolicy.java`（**新規**）
  - `(sug) entity/SuggestItemMerger.java`（**改変または移設**。`0002` §5.5 が「本 IF の実装へ移設」と指示）
  - `(sug) entity/SuggestItem.java`（**改変**。`merge(SuggestItem, SuggestItem)` static（`:446-448`）をエンティティから外す）
  - `(sug) entity/SuggestItemSerializer.java`（**改変**。`toSource` / `toUpdatedSource` / `fromSource` の走査基準を W に統一）
- **設計書の対応**: `0002` DM-10 / DM-11 / DM-13 / DM-18 / DM-19 / DM-21 / §5.2 / §5.3 / §5.5 / §5.6 ／ `0001` D-8 / §3.4
- **作業内容**:
  1. **走査基準を W ただ 1 つにする**（DM-10）。`fromSource` の無限ループ（`SuggestItemSerializer.java:87-95`）を廃止し、`text` から導出した W で回す。`toSource` / `toUpdatedSource` の `readings.length` 基準（`:60` / `:147`）も W に揃える。`SuggestItemMerger.java:70` の split 基準が実質の正であり、これに統一する。
  2. **`initialize(SuggestCandidate incoming, boolean excluded)` を実装する**。`excluded` は呼び出し元が `badWordPolicy.isBadWord(text)` で判定して渡す（D-32 / DM-21）。
  3. **`merge(SuggestItem existing, SuggestCandidate incoming)` を `0002` §5.3 の全フィールド表どおりに実装する**:
     - `text`: **existing を保持**
     - `readings`: **位置ごとの和集合**（順序維持・重複排除・existing 優先）
     - `queryFreq` / `docFreq`: **加算**
     - `kinds` / `tags` / `roles` / `languages` / `fields`: **集合和**（順序維持・重複排除）
     - `userBoost`: **present の incoming のみ上書き。empty なら existing を保持**（DM-11。**現行は無条件上書き** — `SuggestItemSerializer.java:181`）
     - `@timestamp`: **max(existing, incoming)**（**現行は無条件に incoming**）
     - `excluded`: **existing を保持**（U4。`SuggestCandidate` は `excluded` を持たない）
  4. **`userBoost` の丸めを撤廃する**（MIG-04）。`(sug) entity/SuggestItem.java:131-135` の `userBoost <= 1` → `1.0` を削除する。
  5. **`initialize` はバッチ内で ID ごとに高々 1 回しか呼ばれない**形にする（`0002` §5.5）。**bad word 判定も ID ごとに 1 回。**
  6. **`score` の書き込みを廃止する**（DM-3）。`SuggestItemSerializer.java:73` / `:182` / `SuggestItem.java:360`。
  7. **`OpType.INDEX` の全置換は維持する**（DM-13 ／ `0002` §5.6）。`OpType.UPDATE` に変えない。
- **DoD**:
  - 走査基準が実装内部の**1 箇所**に閉じている（`0001` §3.4 の要求）。
  - `0002` §5.3 の全フィールドについて合成規則テストが緑（**T-7 / T-8 / T-17 / T-23**）。
  - **`userBoost` の丸めが無い**（`SuggestItemBoundaryTest:212-231` ほかが意図的に赤 → F-1 で改修）。
  - `score` が source に含まれない。
  - elevate word の読み件数を減らして再登録しても、W が同じである限り `reading_i` の本数が変わらない（**T-10**。F-04 の回帰・経路 A）。
- **検証**: `mvn test -Dtest='SuggestItemMergerTest,SuggestItemSerializerTest,SuggestItemTest,*MergePolicyTest'`
- **依存**: **C-2**（INV-1 が成立していないと W 単一化が意味を持たない）／ **B-7**（`SuggestItemMergePolicy` の宣言）
- **注意点/リスク**:
  - **`0002` §5.6 の推論「同一 ID ⇒ 同一 text ⇒ 同一 W ⇒ 既存側も新側も `reading_i` が W 本」は、既存ドキュメントが新バイナリ産である場合にしか成立しない。** 旧世代ドキュメント（INV-1 未強制）を読むと未定義ケースに入る。**→ §7.2 の 2 番目の穴。ステップ 0-4 で手当てした方針に従うこと。**
  - `SuggestItemMergerTest` の `testMerge_frequencies` のコメント `// max(1.0, 2.0)` は**実装と食い違っている** [確認]（`0002` §7.1）。改修時にコメントの誤りも正す。

#### ステップ C-5: `excluded` の否定形フィルタ（DM-14）

- **目的**: suggest 本体インデックスを読む**すべての**クエリ経路に `mustNot(termQuery("excluded", true))` を無条件付与する。
- **対象**:
  - `(sug) constants/FieldNames.java`（**改変**。`EXCLUDED = "excluded"` を追加。現行に該当定数は無い [確認]）
  - `(sug) request/suggest/SuggestRequest.java`（**改変**。`:346` の `filterList` に追加）
  - `(sug) request/popularwords/PopularWordsRequest.java`（**改変**。`:211-235` の `buildQuery` のトップレベル `BoolQueryBuilder` に追加）
- **設計書の対応**: `0002` DM-14 / §6.2 / §6.3 ／ C-02
- **作業内容**:
  1. `FieldNames.EXCLUDED` を追加する。
  2. `SuggestRequest.processRequest()` の `filterList`（`:346-365`）に `boolQuery().mustNot(termQuery(FieldNames.EXCLUDED, true))` を**無条件に追加**する。`:367-374` が `filterList` の各要素を `filter` 節として合成する。
  3. `PopularWordsRequest.buildQuery()` のトップレベル `BoolQueryBuilder` に `mustNot(termQuery(FieldNames.EXCLUDED, true))` を**無条件に追加**する。`:213` の `mustNot(existsQuery("reading_1"))` と並ぶ位置。
  4. **`must(termQuery("excluded", false))` は禁止**。旧世代ドキュメントが一件も一致せず全滅するため。
  5. **条件付きで付けない（「新スキーマのときだけ付ける」）ことはしない** — インデックス世代を検索時に判定する手段が無い（`0002` §6.2）。
  6. **`excludeWords` は廃止せず現行のまま残す**（`PopularWordsRequest.java:87,165-166,229-231`）。目的が異なる独立機構である（`0002` §6.2）。
- **DoD**:
  - 2 経路とも無条件に `mustNot` が入っている。
  - `excluded` を持たないドキュメントがフィルタを通過し、**`must(term(excluded,false))` では 0 件になる**ことが検証されている（**T-11 / T-R3**。**negative 側の検査を省いてはならない**）。
  - `excluded = true` の語が **`PopularWordsRequest` の結果に現れない**（**T-11b**）。**サジェスト側と人気語側を別々に検査する**こと。
  - `excludeWords` の既存挙動が変わっていない。
- **検証**: `mvn test -Dtest='SuggestRequestTest,SuggestRequestQueryBuildingTest,PopularWordsRequestTest'`
- **依存**: **C-3**（`excluded` が mapping にあること）
- **注意点/リスク**: **`SuggestRequestQueryBuildingTest` / `SuggestRequestTest` は OpenSearch runner を必要としない** [確認]。**T-R3 の negative 検査はここに置けば runner なしで回せる。**

---

### フェーズ D: `internal` 実装

> **`0001` の `api` / `spi` に対する既定実装を作る。** fess 本体からは参照不可のパッケージ（`0001` §1）。

#### ステップ D-1: `SuggestStore` の OpenSearch 実装（永続化境界）

- **目的**: `spi/SuggestStore` の 17 メソッドを OpenSearch で実装する。**合成を持たない純粋な永続化境界**（D-31）。
- **対象**: `(sug) internal/OpenSearchSuggestStore.java`（**新規**）ほか
- **設計書の対応**: `0001` D-31 / §3.7 / §3.7.1 ／ `0002` §4.5（realtime get） ／ `0003` §12 の K-12
- **着手前ゲート（G-OS2・本ステップの必須の前提）**: **`GetRequest` / `MultiGetRequest` の `realtime` 既定値が 3.8.0 でも `true` であることを確認し、結果を作業履歴に記録してから着手する。** `0002` §4.5 の [確認] は 3.7.0 の `javap` 走査に依る（`0004` §2.4 / §2.8 の 2）。**既定が `false` に変わっていた場合、refresh を挟まない頻度集約（T-1 / T-2）が静かに壊れる** — 例外は出ず、集約が落ちるだけである。不成立なら `setRealtime(true)` を明示する形に設計を差し戻す（区分 I の逸脱）。
- **作業内容**:
  1. **write 5**: `multiGet(List<String>) → Map<String, SuggestItem>` ／ **`bulkPut(List<SuggestItem>) → IngestResult`**（`OpType.INDEX` の全置換） ／ `deleteByCondition(QueryCondition) → DeleteResult` ／ `updateExcluded(QueryCondition, boolean) → WordOpResult` ／ `preview(QueryCondition, int) → BadWordImpact`。
  2. **read 2**: `search(SuggestQuery, ScoringPlan, QueryCondition)` ／ `popularWords(PopularWordsQuery, ScoringPlan, QueryCondition)`。既存 `request/` の実装を内部で使う。
  3. **lifecycle 10**: 既存 `Suggester` の実装（`:196-360`）を移す。**エイリアス遷移の post-condition 判定はステップ D-2 で足す** — 本ステップでは現行相当の実装まで。
  4. **`QueryCondition` → OpenSearch クエリの変換を 1 箇所に閉じる。** `SubstringPredicate` の**エスケープは実装責務**（`0001` §3.6）。`(sug) util/SuggestUtil.java:398` の `escapeWildcardQuery` を使う（現行は定義されているが未使用 [確認] — F-09）。
  5. **`multiGet` / GET は realtime（既定）のまま**（`0002` §4.5。`realtime = true` は OpenSearch のコンストラクタ既定 [確認]）。`setRealtime(false)` を指定しない。
  6. **`deleteByCondition` の実装は現行の scroll + bulk delete ループを流用する**（`SuggestUtil.java:332-374`）。**`_delete_by_query` API への置換はスコープ外**（MO-15 / K-12）。ただし**現行の欠陥（`:353-355` が `hasFailures()` で例外を投げてループ中断＝部分削除で終わる）を `DeleteResult.failures` に積む形に直す**（D-4 の契約に合わせるため）。
- **DoD**:
  - 17 メソッドが実装され、`mvn -q compile` が通る。
  - `bulkPut` が `List<SuggestItem>` を受け、**`SuggestItemMergePolicy` を引数に取らない**（D-31）。
  - `multiGet` → `bulkPut` の往復が OpenSearch runner テストで動く。
  - `deleteByCondition` の部分失敗が `DeleteResult.failures` に積まれ、例外にならない。
- **検証**: `mvn test -Dtest='*SuggestStoreTest,SuggestIndexWriterTest'`
- **依存**: **B-7**（`SuggestStore` の宣言）／ **C-4**（`SuggestItem` の source 表現が確定していること）
- **注意点/リスク**: **`SuggestStore` に合成を持ち込まないこと。** `multiGet → 合成 → bulkPut` の read-modify-write は **`internal` の取り込み経路が所有する**（D-31 / ステップ D-5）。これを守らないと `mergePolicy()` と `store()` が独立に差し替え可能でなくなる。

#### ステップ D-2: エイリアス primitive と post-condition 判定

- **目的**: `0003` の切替手順・ロールバック手順が要求する atomic primitive を作る。**R1 の中心的な新機能。**
- **対象**: `(sug) internal/` のライフサイクル実装（**改変**）ほか
- **設計書の対応**: `0001` D-21 / D-23 / §2.2 / §2.2.2 ／ `0003` MO-4 / MO-17 / MO-20 / MO-21 / §3.2 / §3.3 / §5.1 / §5.3 / §7.3
- **作業内容**:
  1. **`switchIndexRetainingPrevious()`**: 「既存 `.prev` を**全インデックスから remove** → 現在の検索対象に add → 検索エイリアスを次世代へ移す」を **1 リクエストの aliases actions** に束ねる。**旧世代がエイリアス 0 個になる瞬間を作らない順序**で並べる（`0003` §3.2 L275）。
  2. **`rollbackToPrevious()`**: `remove(現世代, {baseIndex})` ＋ `add(prev対象, {baseIndex})` を **1 リクエスト**。**更新エイリアスには触れない**（MO-19 を API の形で表すため — `0003` §5.3 L547）。保持世代なしは `SuggesterException`。
  3. **`aliasState()`**: `searchIndex` / `updateIndex` / `previousIndex` / `multiplyAssigned` を返す。**fess 側が `_cat/aliases` を直接叩かなくて済むようにする唯一の読み取り面。**
  4. **post-condition 判定を 4 メソッドに適用する**（D-23 / MO-20 / MO-21）: `switchIndex` / `switchIndexRetainingPrevious` / `rollbackToPrevious` / **`createNextIndex`（付替フェーズ）**。下位の aliases request が例外を返しても**エイリアス状態を再取得し、目的の状態になっていれば正常完了する**。判定不能な場合のみ `SuggestAliasStateUnknownException`、未適用確定なら `SuggesterException`。
  5. **`createNextIndex` は P1（作成）/ P2（付替）の 2 段**。**P1 の失敗は従来どおり `SuggesterException`**、P2 のみ post-condition 判定を適用する（`0001` §2.2 L276-281）。
  6. **`updateRefreshInterval(IndexGeneration, RefreshInterval)`** を実装する。現状 `refresh_interval` を動的変更する経路は**皆無** [確認]（`0003` §7.3 L631）。
  7. **`createNextIndex(IndexSchema)` が `refreshInterval` を受け取り、`Disabled` で次世代を作れるようにする**（MO-8）。
  8. **`.prev` は常にちょうど 1 インデックスを指す**という不変条件を、**付与と解除を同一 primitive に閉じる**ことで守る（`0003` §3.3）。
  9. **`removeDisableIndices()` の判定ロジックは変更しない**（MO-4。判定が「エイリアスを 1 つも持たない」なので `.prev` 付与だけで自動的に守られる）。
  10. **`createIndexIfNothing` は post-condition 判定の対象外**（1 リクエストで完結するため — `0001` §2.2 L293）。
- **DoD**:
  - 3 primitive が存在し、それぞれ **1 リクエストの aliases actions** で完結している。
  - **T-S11 が緑**: (a) タイムアウト例外だがサーバ側は適用済み → **正常完了**（**必須**） (b) 例外＋実際に未適用 → `SuggesterException` (c) 状態再取得自体が失敗 → `SuggestAliasStateUnknownException`。
  - **T-S13 が緑**: 同型 3 ケースを `createNextIndex()` に対して。(a) 適用済みなら**正常完了し `IndexGeneration` を返す**（**是正の本体、省略不可**）。**あわせて P1 の失敗が従来どおり `SuggesterException` のままであること。**
  - **T-S5 / T-S10 の primitive 部分が緑**: 2 回連続再構築で `.prev` が常に 1 インデックスのみを指す。切替失敗時に「`.prev` だけ付いて検索が移っていない」「検索が移って `.prev` が付いていない」のいずれも観測されない。
  - **T-R5 / T-R7 が緑**: `rollbackToPrevious()` が更新エイリアスに触れない。`.prev` 0 個で呼ぶと `SuggesterException` で例外完了し**黙って no-op にならない**。
- **検証**: `mvn test -Dtest='SuggesterIndexLifecycleTest,*AliasPrimitiveTest'`（**aliases request を失敗させるスタブが要る**）
- **依存**: **D-1**（`SuggestStore` の lifecycle 面）／ **B-1**（`SuggestAliasStateUnknownException`）／ **B-5**（`RefreshInterval` / `IndexSchema`）
- **注意点/リスク**:
  - **add と remove を必ず 1 リクエストに束ねること** [確定]（`0003` §3.2 L224）。分割すると `Suggester.java:286,298` の `EXPECTED_INDEX_COUNT = 1` 検査に引っかかる。
  - **S1 の孤児発生窓は塞がない**（`0003` §3.2 L226）。作成（`:253`）→ 付替（`:267`）の 2 リクエスト構成は維持する。1 リクエスト化は「旧世代からの remove を作成と同時にできない」ためできない。
  - **`SuggestAliasStateUnknownException` は `aliasState()` の取得結果と cause を保持する**こと（B-1）。fess 側が例外型で 3 分岐するだけで済むようにする（MO-20）。
  - **物理インデックス名はミリ秒粒度**（`Suggester.java:463-465`）。同一ミリ秒内 2 回の `createNextIndex()` は `resource_already_exists_exception` になる［推測・実機未検証］（K-16）。**対処しない。**

#### ステップ D-3: `BadWordPolicy` / `AuthorizationFilter` の実装

- **目的**: bad word 集合の唯一の所有者と、権限条件の唯一の生成点を作る。
- **対象**: `(sug) internal/DefaultBadWordPolicy.java` / `DefaultAuthorizationFilter.java`（**新規**） ／ `(sug) index/SuggestIndexer.java`（**改変**。`badWords` フィールドキャッシュの廃止）
- **設計書の対応**: `0001` D-6 / D-7 / D-11 / D-25 / D-32 / §3.5 / §3.6 / §7 ／ `0002` DM-18 / DM-20 / DM-21 / §6.2
- **作業内容**:
  1. **`BadWordPolicy` の 6 メソッド**を実装する。判定意味論は**正規化後テキストの部分一致 1 つ**（D-6）。**メタ文字のエスケープを規則内に必須化する**（F-09 の解消。`SuggestUtil.escapeWildcardQuery` を使う）。
  2. **`matchCondition(String)` は エスケープ済みワイルドカード**を返す（`text` は `keyword` 型のため）。
  3. **`releaseCondition(String removed)`** = `mustContain(text, removed)` かつ**削除後の集合の全要素**について `mustNotContain`（D-25 / DM-18）。
  4. **`SuggestIndexer.badWords` フィールドキャッシュを廃止する**（D-7 / F-08 の構造的解消）。現行は `addBadWord`（`:398`）で再取得するのに `deleteBadWord`（`:406-409`）で再取得しないという非対称がある [確認]。
  5. **`isBadWord` の役割を変える**（D-32）: drop の判定ではなく **`SuggestItemMergePolicy.initialize` に渡す `excluded` 初期値の判定**。**取り込み時 drop を廃止する。**
  6. **`AuthorizationFilter.toCondition`**: roles が null / 空でも **`DENY_ALL` を返さず `_guest_` 条件を返す**（D-11 / §7.2）。**空条件を返す実装は契約違反。**
  7. **`canExposeRoles(AccessScope)`**: `ADMIN` のときだけ true（D-12）。
  8. **現行の二重合成を解消する**（`0001` §7.3 の対応表）。
- **DoD**:
  - `BadWordPolicy` が 6 メソッド、`AuthorizationFilter` が 2 メソッド。
  - **T-19 が緑**: `foo` と `bar` を登録し `foobar` が `excluded = true` の状態から、`foo` だけ削除しても `foobar` は `true` のまま。`bar` も削除すると `false`。**`foo` にだけ該当する語（`foobaz`）は `foo` の削除で `false` に戻る。この 3 点を 1 本のテストで固定する。**
  - **T-14b（等価性）が緑**: `isBadWord` の Java 部分文字列判定と `matchCondition` のエスケープ済みワイルドカード判定が一致する。
  - **`SuggestIndexer.badWords` フィールドが存在しない**。
  - roles 未指定で全件露出しないこと（デフォルト deny）。
- **検証**: `mvn test -Dtest='BadWordSettingsTest,*BadWordPolicyTest,*AuthorizationFilterTest'`
- **依存**: **B-3**（`QueryCondition`）／ **B-7**（宣言）／ **C-5**（`FieldNames.EXCLUDED`）
- **注意点/リスク**:
  - **`deleteBadWord` は順序固定**（`0001` §2.3.1 L1063-1068）: 1. `policy.remove` → 2. `store.updateExcluded(releaseCondition)`。**逆順不可。**
  - **2 段書き込みは分散トランザクションにしない**（D-29 / DM-20）。「同一操作の再実行により収束する」を契約とする。**自動リトライ・補償トランザクションを実装しない。**
  - **K-2（`roles` への `_guest_` 混入）は解消しない**（`0002` §8.1）。**ただし `SuggestSource.produce` の Javadoc に `roles` の契約を書くこと**（第 7 版で「拡張点の実装者が読む場所に書かれていなかった」ことが問題視された）。

#### ステップ D-4: `TextProcessor` chain と `ScoringStrategy` の既定実装

- **目的**: 現行の normalizer / converter / analysis と function score を、`spi` の形に包む。
- **対象**: `(sug) internal/DefaultTextProcessorChain.java` / `DefaultScoringStrategy.java`（**新規**）ほか
- **設計書の対応**: `0001` §3.2 / §3.3 / §3.9（既定実装 7 件） ／ §3.9.3（順序・可換性）
- **作業内容**:
  1. **既定 `TextProcessor` chain**: 現行の `normalizer/` `converter/` `analysis/` を包む。**`supports = false` の段は飛ばす（chain は止めない）**。追加された `TextProcessor` は**既定 chain の後ろ**に付く（`0001` §3.9 L1414）。
  2. **既定 `ScoringStrategy`**: 現行の function score（`(sug) request/suggest/SuggestQueryBuilder.java:141-167` の `docFreq` LOG2P ／ `queryFreq` LOG2P ／ `userBoost` の field_value_factor、`scoreMode=MULTIPLY` / `boostMode=REPLACE`、単語クエリかつ非ひらがなの `prefixQuery` 加算）を `ScoringPlan` として表現する。
  3. **`planForPopularWords`**: `PopularWordsRequest.java:232-235` の `fieldValueFactorFunction(queryFreq).missing(0)` ＋ `boostMode=REPLACE` ＋ ランダム rescore（`:242-246`）を `ScoringPlan.RandomRescore` で表現する。
  4. **`ScoringPlan` → OpenSearch クエリの変換を `internal` に置く**（`spi` は OpenSearch 型を露出しない）。
- **DoD**:
  - 既定 chain と既定 strategy が存在し、**現行と同一のクエリを生成する**（回帰）。
  - `supports = false` の段が飛ばされ chain が止まらない。
  - `mvn test -Dtest='SuggestRequestQueryBuildingTest'` が緑（クエリ形状の回帰）。
- **検証**: `mvn test -Dtest='SuggestRequestQueryBuildingTest,AnalyzerConverterTest,NormalizerChainTest,ReadingConverterChainTest'`
- **依存**: **B-7**（宣言）
- **注意点/リスク**: **D-6（bad word の判定意味論）と混同しないこと。** `TextProcessor` の正規化と bad word 判定の正規化は同じ正規化を使うが、責務は別である。

#### ステップ D-5: 取り込みパイプラインと既定 `SuggestSource` 2 実装

- **目的**: `multiGet → 合成 → bulkPut` の read-modify-write を `internal` が所有する形にする（D-31）。
- **対象**: `(sug) internal/IngestPipeline.java`（**新規**） ／ `(sug) internal/DocumentSource.java` / `SearchWordSource.java`（**新規**） ／ `(sug) index/writer/SuggestWriter.java` / `SuggestIndexWriter.java`（**改変**）
- **設計書の対応**: `0001` D-24 / D-27 / D-30 / D-31 / D-32 / §3.1 / §3.7.1 / §4.3 ／ `0002` DM-16 / DM-21 / §4.4.1 / §5.5
- **作業内容**:
  1. **取り込みパイプラインの 5 段**（`0001` §3.7.1 L1278-1287）: 正規化 ＋ ID 導出 → バッチ内畳み込み → `multiGet` → MergePolicy 畳み込み → `bulkPut`。
  2. **畳み込みの形**（`0002` §5.5）:
     - 既存あり: `item = merge(existing, c1); item = merge(item, c2); ...`
     - 既存なし: `item = initialize(c1, isBadWord(text)); item = merge(item, c2); ...`
  3. **`multiGet` 後の text 突き合わせ検査を入れる**（DM-16 ／ `0002` §4.4.1）。ID が一致し `text` が一致しない場合は **`IngestResult.failures` に積む**（バッチ全体を落とさない）。**バッチ内重複判定側は C-1 で入れた分と合わせて 2 経路とも検査する。**
  4. **既定 `SuggestSource` 2 実装**: `DocumentSource`（`Supplier<DocumentReader>` を入力）／ `SearchWordSource`（`SearchWordInput` を入力）。**どちらも `SuggestCandidate.document(...)` のみを使い `userBoost` を指定しない**（D-27）。
  5. **`produce()` が返す `Stream` は呼び出し側（ライブラリ）が close する**（`0001` §3.9 L1438）。`try-with-resources` を使う。**`indexFrom` に渡された `SuggestSource` 自体は close 対象外。**
  6. **項目単位の部分失敗は例外にしない**（D-4）。`IngestResult.failures` に積み、**全項目失敗でも正常完了する**。`orElseThrow` 相当を持たせない（`0001` §4.3 L1492）。
  7. **取り込み時 drop を廃止する**（D-32 / DM-21）。bad word 該当の新規候補も `excluded = true` で保存する。
- **DoD**:
  - パイプラインが 5 段で動く。
  - **T-15 が緑**: ID 一致・text 不一致の組が `IngestResult.failures` に積まれ、バッチ全体は落ちない。**既存ドキュメントとの突き合わせ経路とバッチ内重複判定経路の両方で検出される。**
  - **T-22 が緑**: `addBadWord("foo")` 済みで未登録の `foobar` を 100 回取り込むと、①ドキュメントが作られ `excluded = true`（**drop されない**） ②その間サジェストにも人気語にも現れない ③**`deleteBadWord("foo")` 後に `excluded = false` になり `queryFreq` が 100**。
  - **T-23 が緑**: `initialize` の呼び出し回数がバッチ内候補数に依存しない。**既存ドキュメントがある場合は `initialize` が 1 回も呼ばれない。**
  - **T-20 が緑**: 既定 2 ソースが返す `SuggestCandidate` の `userBoost` がすべて `OptionalDouble.empty()`。
  - **T-1 / T-2 が緑**: refresh を挟まずに頻度集約が正しく動く（realtime get への依存の明示）。
- **検証**: `mvn test -Dtest='SuggestIndexerTest,SuggestIndexWriterTest,DefaultContentsParserTest,*IngestPipelineTest'`
- **依存**: **D-1**（`SuggestStore`）／ **D-3**（`BadWordPolicy.isBadWord`）／ **C-4**（`SuggestItemMergePolicy`）
- **注意点/リスク**: **`SuggestSource` を「登録するだけで載る」形にしないこと** [確定]（D-24 で撤回済み）。入力と実行を所有するのは `SuggestIngestService.indexFrom(...)` である。

#### ステップ D-6: `api` 4 インタフェースの実装

- **目的**: 30 メソッドの振る舞いを実装し、非同期・例外契約を満たす。
- **対象**: `(sug) internal/` の 4 実装クラス（**新規**）
- **設計書の対応**: `0001` §2 / §4（契約表は §4.2） / §5（フィールド選択と権限） / D-3 / D-4 / D-15 / D-22 / D-26
- **作業内容**:
  1. **`SuggestQueryService`**: `suggest` / `popularWords`。**フィールド選択（`ResponseField` 許可リスト）を実装する**。**`roles` は `AccessScope.ADMIN` のときだけ選択可**、違反は `SuggestAuthorizationException`（D-12 / §5.3）。
  2. **`SuggestIndexLifecycle`**: D-2 の primitive を包む。**`validateNext(SuggestQuery)`** を実装する — **内部で `suggest()` と同一のクエリ生成を使い、向き先だけ更新エイリアス（`Suggester.java:408`）へ差し替える**（案 (a′)。`0003` §4.2.1 L381）。**否定形フィルタが自動適用されるのが (a′) の実利。** **`wordCountStats()`** は `excluded = true` を含む件数を返す（`0003` §4.1 L327）。
  3. **`SuggestWordAdmin`**: 7 メソッド。**全メソッドを再実行可能・収束型にする**（D-29）。前段は「その状態にする」（既に済んでいても成功）、後段は**呼び出し時点の bad word 集合から条件を再計算する**。
  4. **`SuggestIngestService`**: 9 メソッド。D-5 のパイプラインを包む。
  5. **完了スレッド契約**（`0001` §4.4 L1503）: **トランスポート／コールバックスレッド上で future を完了させてはならない。必ず構築時 `ExecutorService` にディスパッチしてから `complete` / `completeExceptionally` する。**
  6. **Executor 引数をメソッドに持たせない**（L1502）。**既定タイムアウトを設けない**（L1505）。**`cancel(true)` は I/O を中断しない**旨を Javadoc に書く（L1507）。
  7. **スレッド安全性は「concurrent invocation safe」まで**（D-26）。**同一 `text` への write は atomic でも linearizable でもない**ことを契約に書く（K-1）。
- **DoD**:
  - 30 メソッドすべてが実装され、`CompletableFuture` を返す。
  - `0001` §4.2 の契約表（正常完了条件 / 例外完了条件）どおりに動く。
  - `roles` が `SEARCH` スコープで選択できない（`SuggestAuthorizationException`）。
  - `validateNext` が**更新エイリアスに対して**実行される（**T-S3 の fess-suggest 側相当**）。
  - **完了スレッドが構築時 `ExecutorService` である**ことがテストで確認されている。
- **検証**: `mvn test -Dtest='SuggesterTest,SuggestRequestTest,*ServiceTest,*LifecycleTest,*WordAdminTest'`
- **依存**: **D-1 / D-2 / D-3 / D-4 / D-5**
- **注意点/リスク**: **`validateNext` は「合否を決めない」** [確定]（`0003` §4.2.1 L383）。ライブラリは検証クエリを実行して結果を返すだけで、**合否判定は fess 側**（MO-1 との非衝突の根拠）。**ライブラリ側に閾値判定を実装しないこと。**

#### ステップ D-7: refresh 戦略（MO-7 の 3 層）

- **目的**: バッチごと refresh の廃止と、クラスタ全体 refresh の是正。
- **対象**:
  - `(sug) index/operations/ContentIndexingOperations.java`（**改変**。`:345` の refresh 廃止）
  - `(sug) Suggester.java`（**改変**。`:179` の `prepareRefresh()` にインデックス名を渡す）
  - `(sug) internal/` の取り込み実装（**改変**。`IngestOptions.refreshPolicy` の反映）
- **設計書の対応**: `0003` MO-7 / MO-8 / §7.1 / §7.3 / §7.5 ／ C-12 / C-04
- **作業内容**:
  1. **(a)**: `ContentIndexingOperations.java:345` の**バッチごと refresh を廃止する**。現行はループ `:331-350` で `docs.size() >= docPerReq` または末尾ごとに無条件発行、既定 `docPerReq = 2`（`(fess res) fess_config.properties:1502`）＝**2 ドキュメントごとに 1 回**。
  2. **(b)**: `Suggester.java:179` の `prepareRefresh()` が**インデックス名なし＝クラスタ全インデックス refresh** になっている [確認]。**suggest インデックス限定に是正する。**
  3. **(c)**: `IngestOptions.refreshPolicy`（`NONE` / `ON_COMPLETION`）を取り込み経路に反映する。**個別操作は `ON_COMPLETION`、一括操作（`storeAllElevateWords` / `storeAllBadWords` 相当）は `NONE` ＋末尾で 1 回**（`0003` §7.5）。
  4. **`PER_BATCH` 相当の値を作らない**（C-12 が廃止した挙動を選択肢に残さない）。
  5. **`waitController`（`pacing`）の呼び出し位置は変えない**（`0003` §7.6。`ContentIndexingOperations.java:348` でバッチごとに 1 回。**位置変更は本設計では決定せず後続へ**）。
  6. **最適値は決めない**（MO-7 / C-04）。`refresh_interval` の値は `suggest.json:3` の `10s` を据え置き。
- **DoD**:
  - `ContentIndexingOperations` にバッチごと refresh が無い。
  - `Suggester.refresh()` が suggest インデックスのみを対象にする。
  - `IngestOptions.refreshPolicy` が反映され、`NONE` では取り込み中に refresh が発行されない。
  - **`docPerReq` の既定値を変えていない**こと（最適値の決定はスコープ外）。
- **検証**: `mvn test -Dtest='ContentIndexingOperations*,SuggestIndexerTest'`
- **依存**: **D-5**（取り込みパイプライン）／ **B-5**（`IngestOptions`）
- **注意点/リスク**: **(b) の影響は大きい** [確認]（`0003` §7.2）。(b) × (c) が掛け合わさり、`storeAllElevateWords`（`(fess) SuggestHelper.java:411-424` → `:486`）で **elevate word N 語なら N+1 回のクラスタ全体 refresh** が起きていた。是正により**挙動が目に見えて変わる**ので、リリースノート項目にする。

#### ステップ D-8: `SuggesterBuilder` の拡張と `SuggestComponents`（Q12 / X-1 の実装）

- **目的**: SPI の合成点を 1 箇所に閉じる。**ステップ 0-2 で改訂した `0001` 第 9 版に従う。**
- **対象**:
  - `(sug) SuggestComponents.java`（**新規**）
  - `(sug) SuggesterBuilder.java`（**改変**）
- **設計書の対応**: **`0001` 第 9 版 §3.9**（ステップ 0-2 で改訂） ／ D-13 / D-24 / D-30
- **作業内容**:
  1. `SuggestComponents extends AutoCloseable`: `queryService()` / `lifecycle()` / `wordAdmin()` / `ingestService()` ＋ `close()`（**登録済み SPI のうち `AutoCloseable` を登録の逆順で閉じる**。**`ExecutorService` は close 対象外**）。
  2. **`SuggesterBuilder` に SPI 登録メソッドを追加する**: `documentSource` / `searchWordSource`（差し替え）／ `addTextProcessor`（追加・順序＝chain 順）／ `scoringStrategy` / `mergePolicy` / `badWordPolicy` / `authorizationFilter` / `store`（差し替え・最後勝ち）。**`addSource` は作らない**（第 5 版で撤回済み）。
  3. **`buildComponents(Client, SuggestSettings, ExecutorService)` を新設**し `SuggestComponents` を返す（**X-1 の解決**）。
  4. **既存の `build(Client client, String id)`（`(sug) SuggesterBuilder.java:149`）は `Suggester` を返すまま維持する。** 内部で `buildComponents(...)` を呼び、得た `SuggestComponents` を保持する `Suggester` を返す。
  5. **`ServiceLoader` も DI コンテナも使わない**（`0001` §3.9 L1353）。理由: `settingsId` ごとに構成が分かれる／ライブラリが利用者の DI 基盤を前提にできない。
  6. **既存のタイポ `contentsReadigConverter`（`:98`）はそのまま残す**（public API の変更になるため。L3 で直す）。
  7. **`SuggestComponents` / `SuggesterBuilder` の登録メソッドは D-1 の 30 メソッドに数えない**（L1441）。
- **DoD**:
  - `SuggestComponents` が 4 取り出し口 ＋ `close()` を持つ。
  - `buildComponents(...)` が `SuggestComponents` を返す。
  - **`build(Client, String)` が `Suggester` を返す**（**C-01 の要**）。
  - **`modules/fess` が無変更でコンパイルできる**（`(fess) helper/SuggestHelper.java:142` が通ること）。
  - `close()` が登録の逆順で `AutoCloseable` を閉じ、`ExecutorService` を閉じない。
- **検証**: `mvn test -Dtest='SuggesterBuilderTest,*SuggestComponentsTest'` ／ fess 側 `mvn -q -o compile`
- **依存**: **D-1〜D-7**（組み立てる部品が揃っていること）／ **0-2**（設計書の改訂が済んでいること）
- **注意点/リスク**: **ステップ 0-2 が未了のまま本ステップを実装してはならない。** 逸脱手続きの「改訂を先に行う」規律に反する。

---

### フェーズ E: 旧ファサードの委譲（Strangler Fig 第 2 段）

> **旧 `Suggester` / `SuggestIndexer` の public シグネチャを 1 つも変えずに、中身を新部品への委譲に置き換える。**
> **`0001` §8.3 L1847: 旧クラスが新 IF を保持する向きにする**（逆向きだと R2 で削除できない）。

#### ステップ E-1: `DeferredAdapter`

- **目的**: `CompletableFuture` を旧 `Deferred.Promise` に包む一方向アダプタを作る。
- **対象**: `(sug) concurrent/DeferredAdapter.java`（**新規**。package-private の `final class`）
- **設計書の対応**: `0001` §8.4（L1867-1905） / MIG-08
- **作業内容**:
  1. `static <R extends Response> Deferred<R>.Promise toPromise(CompletableFuture<R>)` を作る。
  2. `future.whenComplete` で **`CompletionException` を剥がしてから `reject`**、正常時 `resolve`、`deferred.promise()`（`(sug) concurrent/Deferred.java:146`）を返す。
  3. **逆方向（`Promise` → `CompletableFuture`）は作らない**（新実装が旧型に依存すると L3 で `Deferred` を削除できない）。
  4. **`Response` 境界の制約**: `CompletableFuture<Void>` を返す新 IF は P-b で包めない。**旧 `Suggester.refresh()` などは P-a（同期化委譲）を使う**（L1905）。
- **DoD**:
  - `toPromise` が存在し、正常/異常の両方で旧経路と同じ例外型が観測される。
  - **`CompletionException` が剥がれている**こと（旧 `getResponse()` の受け取る例外を現行と同じにするため）。
  - 逆方向のメソッドが存在しない。
- **検証**: `mvn test -Dtest='DeferredTest,*DeferredAdapterTest'`
- **依存**: **D-6**（包む対象の `CompletableFuture` が存在すること）
- **注意点/リスク**: **挙動が 1 点変わる** [確定]（L1506）: `Promise.getResponse()` の暗黙 1 分待ち（`Deferred.java:212`）に対し、新実装の `join()` は無期限待ちである。**担保は下位のタイムアウト設定へ移る。** リリースノート項目にする。

#### ステップ E-2: `Suggester` の委譲

- **目的**: `Suggester` の public 18 件を新 IF への委譲に置き換える。
- **対象**: `(sug) Suggester.java`（**改変**）
- **設計書の対応**: `0001` D-13 / D-28 / §8.1 / §8.3
- **作業内容**:
  1. **委譲する 11 件**（`0001` §8.1 の A）: `suggest()` / `popularWords()` / `createIndexIfNothing()` / `createNextIndex()` / `switchIndex()` / `removeDisableIndices()` / `settings()` / `getIndex()` / `getAllWordsNum()` / `getDocumentWordsNum()` / `getQueryWordsNum()`。
  2. **P-a（同期化委譲）**: `getAllWordsNum()` → `lifecycle.wordCountStats().join().total()` など。`refresh()` も P-a（`Void` を返すため P-b が使えない）。
  3. **`refresh()` の挙動変更**: 戻り値 `RefreshResponse` は維持しつつ、**対象を suggest インデックスに限定する**（D-7 で実施済み）。
  4. **`settings()` は公開のまま残す**（internal 化しない）。`(fess) helper/SuggestHelper.java` の 6 箇所が使っている [確認]。
  5. **`indexer()` を残す**。fess 本体が **11 箇所**で使っている [確認]。`0001` §8.1 は「廃止」に分類しているが、それは**新 API 側に置かない**という意味であり、**旧ファサードからは L3 まで消せない**。
  6. **`shutdown()` / `getReadingConverter()` / `getNormalizer()` / 7 引数コンストラクタも残す**（fess 本体は使っていない [確認] が、公開シグネチャ維持のため）。**`@Deprecated` を付ける。**
  7. **`static builder()` は維持**（X-1 の決定）。
  8. **旧クラス全体に `@Deprecated` を付与する**（`0001` §8.3 L1837-1838）。
- **DoD**:
  - `Suggester` の public メンバが **18 件のまま**（増減なし）。
  - **すべてのメソッドが `SuggestComponents` 経由で動く**（旧実装の残骸が無い）。
  - **`modules/fess` が無変更でコンパイル・動作する**。
  - `@Deprecated` が付いている。
- **検証**: `mvn test -Dtest='SuggesterTest,SuggesterBuilderTest,SuggesterIndexLifecycleTest,SuggesterRefactoringTest'` ／ fess 側 `mvn -q -o compile`
- **依存**: **D-8**（`SuggestComponents`）／ **E-1**（`DeferredAdapter`）
- **注意点/リスク**: **`0001` §8.1 の「廃止」6 件は「新 API 側に置かない」の意味であり、「旧ファサードから消す」ではない。** 消すと C-01 が壊れる。**この読み替えを作業履歴に明記すること**（次の実装者が誤読しないため）。

#### ステップ E-3: `SuggestIndexer` の委譲

- **目的**: `SuggestIndexer` の public 30 件を新 IF への委譲に置き換える。
- **対象**: `(sug) index/SuggestIndexer.java`（**改変**）
- **設計書の対応**: `0001` D-5 / D-13 / §8.2 / §8.3 / §8.5
- **作業内容**:
  1. **委譲する 12 件**（`0001` §8.2 の A）: `index(SuggestItem)` / `index(SuggestItem[])` / `delete` / `deleteAll` / `deleteDocumentWords` / `deleteQueryWords` / `indexFromDocument(Map[])` / `indexFromDocument(Supplier,int,Runnable)` / `indexFromSearchWord(6引数)` / `deleteBadWord` / `restoreElevateWord` / `deleteOldWords(ZonedDateTime)`。
  2. **P-c（引数の読み替え）**: `index(SuggestItem[])` → `SuggestItem` を `SuggestCandidate` に詰め替え、**`excluded` は捨てる**（`0001` §8.2 の #3）。`deleteOldWords(ZonedDateTime)` → `Instant` に変換。
  3. **P-b（Promise 委譲）**: `indexFromDocument(Supplier,int,Runnable)` → `indexFromDocuments(Supplier, IngestOptions)` を `DeferredAdapter.toPromise` で包む。
  4. **`apply` 引数の 3 メソッドは `@Deprecated` で引数を無視する**（D-5 ／ `0001` §8.5）: `addBadWord(String, boolean)` / `addElevateWord(ElevateWord, boolean)` / `deleteElevateWord(String, boolean)`。**MIG-03 段階で実挙動は変わらない** [確認] — `apply=true` は fess で `(fess) exec/SuggestCreator.java:255,258` の 2 箇所のみで、直前に空インデックスを作るため削除対象 0 件（F-07）。
  5. **`deleteBadWord` の戻り値**: 現行 `void`、新 IF は `WordOpResult`。**旧シグネチャは `void` のまま維持する。**
  6. **残す 18 件**: `deleteByQuery(String)` / `deleteByQuery(QueryBuilder)` / `indexFromQueryLog` 3 件 / コンストラクタ / **setter 9 件** / `restoreElevateWord` ほか。**すべて `@Deprecated`。** fess 本体は setter も `indexFromQueryLog` も使っていない [確認] が、公開シグネチャ維持のため残す。
  7. **setter 9 件の挙動は「no-op ＋ 警告ログ」とする**（**U-3 の決定**）。`setIndexName` / `setSupportedFields` / `setTagFieldNames` / `setRoleFieldName` / `setReadingConverter` / `setNormalizer` / `setAnalyzer` / `setContentsParser` / `setSuggestWriter` は、**シグネチャ（`SuggestIndexer` を返す fluent 形）を維持し、`this` を返すが何も変更しない**。呼ばれたら `logger.warn` で「このメソッドは無効化された。構成は `SuggesterBuilder` の構築時に指定すること」と出す。
     - **例外にしない理由**: `SuggestComponents` が不変であること（`0001` §8.2 L1829）と実行時差し替えは両立しないが、**例外にすると未知の外部利用者が実行時に壊れる**。fess 本体の使用は 0 件 [確認] だが、外部利用者の有無は確認できない。**警告ログなら気づける。**
     - **`@Deprecated` の Javadoc に「呼び出しは無視される」と明記する。** 除去は L3。
  8. **`deleteByQuery(QueryBuilder)`（`:283`）は OpenSearch 型を露出しているが R1 では残す。** `0001` §1 の規約違反だが、**規約は `api` / `spi` に対するものであり、旧ファサードは L3 で消える**。
- **DoD**:
  - `SuggestIndexer` の public メンバが **30 件のまま**。
  - `apply` 引数が無視され、警告ログも出ない（no-op）。
  - **`modules/fess` が無変更でコンパイル・動作する**（`suggester.indexer()` の 11 箇所すべて）。
  - `@Deprecated` が付いている。
- **検証**: `mvn test -Dtest='SuggestIndexerTest,SuggestIndexerErrorHandlingTest'` ／ fess 側 `mvn -q -o compile`
- **依存**: **E-2**（`Suggester.indexer()` が `SuggestComponents` 経由になっていること）
- **注意点/リスク**:
  - **setter 9 件は「実行時に構成を差し替える」ものであり、`SuggestComponents` が不変であることと両立しない**（`0001` §8.2 L1829）。**U-3 の決定により no-op ＋ 警告ログとする**（上記 7）。**silent な no-op にしないこと** — 警告が出ないと「設定したのに効かない」という最も追いにくい壊れ方になる。
  - **警告ログの出力先とレベルを揃える。** `SuggestIndexer` の既存 logger を使い、`warn` レベルとする（`info` だと本番で出ない設定がありうる）。

#### ステップ E-4: 非互換の文書化とリリースノート（**2026-08-31 改訂** — リリースチェックリストの作成を外した）

> **【2026-08-31 改訂】本ステップから「L1 リリースチェックリストの作成」を外した。** 第 13 版までのチェックリストは **M-1（L1 デプロイ直後の SuggestJob 手動起動）の唯一の実効性担保**として置かれていたが、**M-1 と K-19 は撤回された**（§7 ／ `0003` 第 14 版 §10.6 / §12）。
> **R1 のリリース手順書は後続タスクの成果物である**（`0003` 第 15 版 §13 の 16 ／ §10.3 の申し送り 10）。**本タスクは fess-suggest 側の非互換の文書化までを負う。**

- **目的**: D-28 が受容した非互換を、利用者が見つけられる場所に列挙する。**`modules/fess-suggest` は公開 artifact であり**（`pom.xml:92-103`）、**U-9 により旧ファサードは R1 まで維持するが、`entity.SuggestItem` 周りの非互換は R1 で発生する**ため、告知が要る。
- **対象**: `modules/fess-suggest/README.md`（**改変**） ／ `modules/fess-suggest/CLAUDE.md`（**改変**） ／ CHANGELOG 相当（**新規または改変**）
- **設計書の対応**: `0001` **第 10 版** D-28 / §8.3.1（L1865 が「実装タスク」と明記） ／ `0000` §7（MIG-25）
- **作業内容**:
  1. **破壊的変更を列挙する**（D-28）: `entity.SuggestItem` の public コンストラクタ廃止／配列 getter の一部変更／`Promise.getResponse()` の暗黙 1 分待ちが `join()` の無期限待ちに変わる／`Suggester.refresh()` の対象が suggest インデックス限定になる／`userBoost` の丸め撤廃／`score` フィールドの廃止／
  2. **MIG-25**（`0000` §7）: README のバージョン記載を pom から単一ソース化。`modules/fess-suggest/CLAUDE.md` の非同期サンプルを `CompletableFuture` ベースに書き換える。
  3. **旧ファサードの扱いを明記する**（**U-9**）: **旧 `Suggester` / `SuggestIndexer` は R1 では `@Deprecated` として維持し、R2 で除去する**。外部利用者への移行猶予が 1 リリースあることを書く。**`apply` の全廃と setter 9 件の no-op 化（U-3）も併記する** — シグネチャは残るが挙動が変わるため、告知しないと沈黙して振る舞いが変わる。
  4. **運用者向けの注意**（`0003` §10.1 の 3 項目）: G2 スモーククエリが必須になること／**語数が移行前より増えること**（bad word 該当語が `excluded = true` で保存されるため。**検索結果には現れないが管理画面の語数表示や `wordCountStats()` には載る**）／除外語の物理削除は運用者が明示的に実行する操作であること。**手順の本文は `0003` §10.6.1 を参照する形にし、二重管理しない。**
- **DoD**:
  - 上記 4 群が文書化されている。
  - **`@Deprecated` として残す範囲（U-9）と、R2 で消える範囲が読み手に区別できる。**
- **検証**: レビュー（自動検証なし）
- **依存**: **E-3**
- **注意点/リスク**: **非互換の告知先は fess 本体だけではない** [確認]。`modules/fess-suggest` は `maven.codelibs.org` へ deploy される公開 artifact である（`pom.xml:92-103`）。**U-9 が 1 リリースの猶予を与えるのは旧ファサードのシグネチャだけであり、`entity.SuggestItem` の非互換（D-20）には猶予が無い。**

### フェーズ F: テストと最終検証

#### ステップ F-1: 既存テストの改修（`0002` §7.1）

- **目的**: フェーズ B〜E で意図的に赤くなった既存テストを、新仕様に合わせて直す。**「変えない」ものと「意図的に変える」ものを厳密に区別する。**
- **範囲の限定（指摘 2）**: **本ステップは「意味的な改修」に限る。** 構築呼び出しの機械的追従（`new SuggestItem(` の 146 箇所ほか）は **B-4b で完了している**。本ステップが扱うのは**アサーションと期待値**である — `score` に関するアサーションの削除、ID 規則変更に伴う期待値修正、`userBoost` の丸め撤廃に伴う期待値修正、`ElevateWord` の読み割り当ての期待値変更など。
- **対象**: `(sug test)` 配下の既存テスト（**改変**）
- **設計書の対応**: `0002` §7.1（全件表）
- **作業内容**: `0002` §7.1 の表に従って改修する。
  - **変えない**: `SuggestItemMergerTest` の `testMerge_frequencies` / `_tags` / `_roles` / `_fields` / `_languages` / `_preservesText` / `_preservesId`（頻度加算・集合和・text 保持は現行と同一結果になることを回帰として維持）／ `SuggestItemBoundaryTest.test_getId_sameTextSameId` / `_differentTextDifferentId` / `_multiWordOrder`（**むしろ本設計が強化する不変条件そのもの**）。
  - **意図的に変える**: `SuggestItemMergerTest.testMerge_frequencies` のコメント `// max(1.0, 2.0)`（実装と食い違っている [確認]）／ `SuggestItemTest.testMerge`（`:267-298`）／ `SuggestItemTest.testUserBoostMinimum` / `test_userBoostZero` / `test_userBoostNegative` / `SuggestItemBoundaryTest:212-231`（丸め撤廃）／ `SuggestItemSerializerTest:138` / `SuggestItemTest:214` / `SuggestItemBoundaryTest:256,267`（`score` の廃止 — 該当アサーションを削除）／ `SuggestUtilTest.testCreateSuggestTextId`（`:99-117`） / `testCreateSuggestTextIdBoundaryExactly445`（`:490-502`） / `testCreateSuggestTextIdBoundaryJustUnder445`（`:505-516`） / `testCreateSuggestTextIdWithLongText`（`:120-130`）（ハッシュ化・43 文字固定）／ `ElevateWordTest.testToSuggestItemWithCompleteData`（`:198-244`） / `testMultipleReadingsConversion`（`:399-417`）（**このテストは現行の不具合を仕様として固定していた**）。
- **DoD**:
  - `0002` §7.1 の全行が処理済み（「変えない」行は**変えていない**ことも確認する）。
  - `modules/fess-suggest` で `mvn test` が全緑。
  - **「変えない」に分類したテストが赤くなっていた場合、それは実装の誤りである。** テストを直して通したりしていないこと。
- **検証**: `mvn test`（全件）
- **依存**: **E-3**（実装が出揃っていること）
- **注意点/リスク**: **「テストを新仕様に合わせる」と「テストを通すためにテストを緩める」の境界を守ること。** `0002` §7.1 に無い変更を加えた場合は、その理由を作業履歴に必ず記録する。

#### ステップ F-2: 新規テスト T-1〜T-24（`0002` §7.2）

- **目的**: `0002` §7.2 の全テストを実装する。**多くはフェーズ C / D の DoD として先行実装されているので、ここでは網羅性の確認と欠落分の追加を行う。**
- **対象**: `(sug test)` 配下（**新規**）
- **設計書の対応**: `0002` §7.2（T-1〜T-24） / §7.4（T-14 系）
- **作業内容**: 次の対応表で網羅を確認し、未実装分を書く。

| テスト | 検証内容（要約） | 先行実装ステップ |
| --- | --- | --- |
| T-1 / T-2 | 頻度集約の回帰（refresh 廃止後 / multiGet 化後） | D-5 |
| T-3 | 新 ID 方式の同一性・43 文字固定・334 バイト以上の異なる text | C-1 |
| T-4 | INV-1 の強制 | C-2 |
| T-5 | INV-2 の強制 | C-2 |
| T-6 | INV-3 の切り捨て（`text` と `readings` が同時に切れる） | C-2 |
| T-7 | `userBoost` の合成（elevate → 通常取り込みで潰れない／管理者変更は反映） | C-4 |
| T-8 | `excluded` の保持（bad word 登録 → 通常取り込みで `true` のまま／解除で `false`） | C-4 |
| T-9 | `ElevateWord` の割り当て（§5.4 の 4 ケース表） | C-2 |
| T-10 | `reading_i` が消えないこと（F-04 の回帰・経路 A） | C-4 |
| T-11 | 旧世代共存（否定形は通る／肯定形は 0 件） | C-5 |
| T-11b | 人気語経路の除外（**サジェスト側と別々に検査**） | C-5 |
| T-11c | `previewBadWordImpact` の件数（既に `excluded` の語も含む・冪等） | D-3 |
| T-12 | mapping の受理（`reading_10` 以降・`null` は失敗・`[]` は受理） | C-3 |
| **T-24** | **欠損 `reading_i` スロットの復元**（例外にならず空配列 → 合成後に W 本が揃う。`0002` 第 10 版） | **C-2** |
| T-14 系 | bad word 判定の等価性（`0002` §7.4） | D-3 |
| T-15 | ID 衝突・ID 生成バグの検出（**2 経路とも**） | C-1 / D-5 |
| T-16 | 切り捨てによる集約（先頭 N 語一致で同一 ID・**仕様として固定**）＋ 切り捨て件数のカウント | **本ステップで追加** |
| T-17 | `SuggestCandidate` に `excluded` が無いことの型レベル担保 | C-4 |
| T-18 | 公開 DTO の不変性（`UnsupportedOperationException` ＋ 防御的コピー） | B-4a / B-4b |
| T-19 | bad word の重複マッチ解除（**3 点を 1 本で固定**） | D-3 |
| T-20 | `SuggestSource` が `userBoost` を指定しないこと | D-5 |
| T-21 | 2 段書き込みの部分適用と再実行収束（**`updateExcluded` を 1 回だけ失敗させるスタブ**。delete / add の両ケース ＋ 1 段目の冪等性） | **本ステップで追加** |
| T-22 | bad word 該当語の新規取り込みが可逆であること（**③ が第 6 版のモデルでは成立しなかった検証点**） | D-5 |
| T-23 | `initialize` の呼び出し回数がバッチ内候補数に依存しない | D-5 |

- **DoD**: **T-1〜T-24 の全行が実装済みで緑。** 上表に「本ステップで追加」とある T-16 / T-21 を含む。
- **検証**: `mvn test`（全件）
- **依存**: **F-1**
- **注意点/リスク**: **T-21 は最も複雑なテストである**（`SuggestStore.updateExcluded` を 1 回だけ失敗させるスタブが要る）。**「1 段目の冪等性」の検査を省かないこと。**

#### ステップ F-3: fess-suggest 側の T-S / T-R 系（`0003` §11）

- **目的**: `0003` §11.1 の総則で**fess-suggest 側にホストすると定められたテスト**を実装する。
- **対象**: `(sug test)` 配下（**新規**）
- **設計書の対応**: `0003` §11.1（T-S 系） / §11.2（T-R 系） / §11.1 の総則（L907-911）
- **作業内容**:

| テスト | 検証内容 | 先行実装 |
| --- | --- | --- |
| **T-S11** | post-condition による正常完了。(a) タイムアウト例外だがサーバ側は適用済み → **正常完了（必須）** (b) 例外＋未適用 → `SuggesterException` (c) 状態再取得が失敗 → `SuggestAliasStateUnknownException` | D-2 |
| **T-S13** | S1 の付替も post-condition 判定。同型 3 ケースを `createNextIndex()` に対して。(a) は**是正の本体、省略不可**。**P1 の失敗が従来どおり `SuggesterException` のままであることも検査** | D-2 |
| **T-S5（primitive 部分）** | 2 回連続再構築で `.prev` が常に 1 インデックスのみを指す | D-2 |
| **T-S10（primitive 部分）** | 切替の原子性。「`.prev` だけ付いて検索が移っていない」「検索が移って `.prev` が付いていない」のいずれも観測されない | D-2 |
| **T-R3** | 否定形フィルタの必須性。**`must(term(excluded,false))` は 0 件になることの negative 検査を省いてはならない** | C-5 |
| **T-R5** | `rollbackToPrevious()` が更新エイリアスに触れず、**旧世代へ書く経路が API から到達できない** | D-2 |
| **T-R6** | 新バイナリで旧世代へ書くと ID が分裂すること（同一 `text` が 2 ドキュメント、`queryFreq` が合流しない）を **negative test として固定** | **本ステップで追加** |
| **T-R7** | `.prev` 0 個で `rollbackToPrevious()` を呼ぶと `SuggesterException` で例外完了し**黙って no-op にならない** | D-2 |

- **DoD**: 上表 8 件が緑。**特に T-S11(a) / T-S13(a) / T-R3 の negative 側 / T-R6 を省いていないこと。**
- **検証**: `mvn test -Dtest='*AliasPrimitiveTest,*RollbackTest,SuggestRequestQueryBuildingTest'`
- **依存**: **F-2**
- **注意点/リスク**:
  - **T-S1〜T-S4 / T-S8 / T-S9 / T-S12 / T-S14 / T-R2 は fess 本体側であり、ここには置かない** [確定]（`0003` §11.1 の総則が「fess-suggest の runner テストには置かない」と明記）。
  - **T-R6 は §7 の中間状態問題と同じ現象を扱う。** ステップ 0-4 で採った緩和策と矛盾しないテストにすること。

#### ステップ F-4: Q11 の禁止規則の機械化（fess-suggest 側の補完）

- **目的**: ステップ A-6 の (D) と C-3 の (A) を確認し、**fess-suggest 側からも検知できるようにする**。
- **対象**: `(sug test)` 配下（**新規**） ／ `(sug res) suggest_indices/suggest.json`（C-3 で実施済みの確認）
- **設計書の対応**: `0003` §8.4 / §13 の 7
- **作業内容**:
  1. C-3 で入れた `"_comment"` が**残っていること**を確認する。
  2. **`(sug res)` 側の 7 ファイルから `number_of_replicas` が消えていることを assert するテスト**を追加する（リソースの回帰）。**JSON リソースは実装コードと違ってコンパイルエラーで守られないため、テストで守る。**
- **DoD**: リソース回帰テストが緑。`"_comment"` が残っている。
- **検証**: `mvn test -Dtest='SuggesterResourceLoadingTest,*ResourceRegressionTest'`
- **依存**: **C-3**
- **注意点/リスク**: `SuggesterResourceLoadingTest` は既存の runner 不要テスト [確認] なので、ここに足すのが安い。

#### ステップ F-5: 最終検証（本タスクの DoD）

- **目的**: **本タスクの完了条件を満たすことを実証する。**
- **対象**: なし（検証のみ）
- **設計書の対応**: C-01（`0000` の 2026-08-31 注記 — 第 1〜3 段が R1、第 4 段が R2）／ `0003` **第 15 版** §10.1 の R1 定義 ／ `0001` **第 10 版** §8.3.1
- **作業内容**:
  1. `modules/fess-suggest` で **`mvn test` を全件実行し全緑**であることを確認する（**51 + 新規のテストクラス。24 クラスが OpenSearch ノードを起動する**）。ステップ 0-1 で記録した基準線と比較する。
  2. `mvn install` する。
  3. **`modules/fess` を無変更（フェーズ A の変更のみ）でビルドする**: `mvn -o compile` ＋ `mvn -o test`。**`-o`（オフライン）は 2026-08-31 に `modules/fess` で成功を実測済みである** [確認]（`0005` §5。0-1 時点の失敗は依存未取得が原因で、オンライン取得後は解消した）。**ただし DoD は「ビルドが成功すること」であって「オフラインで成功すること」ではない** — `-o` は再現性のための既定であり、**新たな依存が upstream に入って `-o` が失敗した場合は `-o` を外して実行してよい**（その旨を作業履歴に記録すること）。
  4. **`(fess) helper/SuggestHelper.java` / `(fess) exec/SuggestCreator.java` / `(fess) helper/PopularWordHelper.java` / `(fess) api/v2/handlers/SuggestWordsHandler.java` の 4 ファイルに、フェーズ A 以外の変更が入っていないことを `git diff` で確認する。**
  5. **`0001` §8.1 / §8.2 の 48 メンバのシグネチャが 1 つも変わっていないことを機械的に確認する**（[提案] `javap` で**本タスク着手前後**の public シグネチャを出力して diff する）。
     - **`javap -v` は使わない。** `-v` は `Deprecated` 属性・定数プール・行番号表などを出力するため、**フェーズ E で全メンバに `@Deprecated` を付ける本プランでは差分が全メンバに出て diff が無意味になる**。
     - **素の `javap` はアノテーションを出力しない** [確認]（`@Deprecated` を付けたクラスを `javap` すると `public void a();` としか出ず、`Deprecated: true` は `-v` を付けた場合のみ現れる）。**したがって素の `javap` の出力を diff すれば `@Deprecated` の付与は差分に現れない。**
     - 手順: **本タスク着手前**の HEAD で `javap -classpath target/classes org.codelibs.fess.suggest.Suggester org.codelibs.fess.suggest.index.SuggestIndexer > before.txt` を取り、F-5 時点の出力と `diff` する。
  6. ~~**M-1 がリリースチェックリストに必須項目として存在することを確認する**~~ — **【2026-08-31 削除】M-1 とリリースチェックリスト（E-4 の 3b）を撤回したため**（§7 ／ `0003` 第 14 版 §10.6）。**代わりに、`0001` 第 10 版 §8.3.1 が定める互換性の範囲（R1 まで旧ファサードの public シグネチャを維持する）が作業内容 5 の `javap` diff で満たされていることを確認する。**
  7. 結果を作業履歴に記録する。
- **DoD**:
  - `modules/fess-suggest`: `mvn test` 全緑。
  - `modules/fess`: `mvn compile` / `mvn test` が成功し、**フェーズ A 以外の差分が 0**。
  - **48 メンバの public シグネチャ diff が 0**。
  - ~~**`L1-release-checklist.md` に M-1 が【必須】項目として存在する**~~ — **【2026-08-31 削除】**（作業内容 6 の削除に伴う）。
- **検証**: 上記コマンド ＋ `javap` diff
- **依存**: **F-1 / F-2 / F-3 / F-4 ＋ A-6**
- **注意点/リスク**: **「fess 本体がビルドできる」は「fess 本体が壊れていない」を意味しない。** `0003` MO-13 / §1.4 の 11 のとおり、**fess 本体のテストは回帰検知能力を持たない**（`SuggestHelperTest` は `suggester` が null のまま全例外を握り潰し常に緑、`SuggestCreatorTest` の `create()` テストは中身が空、ハンドラ系は 400/500 を許容）。**したがって L1 の互換性は「コンパイルが通る」＋「48 メンバのシグネチャ不変」以上の自動検証を持たない。** この限界を作業履歴とリリース判断に明記すること。**実挙動の確認は L2 の T-F1 / T-F4 まで持ち越される。**

---

## 5. 依存関係と推奨実行順序

### 5.1 依存グラフ

```text
0-1 ─┬─────────────────────────────────────────────────────────────┐
     │                                                             │
0-2 ─┼──────────────────────────────────────────────► D-8          │
     │                                                             │
0-3 ─┘                                                             │
                                                                   │
0-4 ───────────────────────────────────────► C-1（フェーズ C 全体の前提）
                                                                   │
【フェーズ A / modules/fess・L1 と独立に進行可】                    │
A-1 ─┐                                                             │
A-2 ─┼──► A-3 ─────────► A-6 ───────────────────────────────────────┤  （A-5 は削除）
A-4 ─┘（独立）                                                     │
     │                                                             │
【フェーズ B / modules/fess-suggest】                               │
B-1 ─┐                                                             │
B-2 ─┼──► B-4a ─► B-4b ─┬─► B-6 ─┐                                          │
B-3 ─┤         │        │                                          │
B-5 ─┘         └─► B-7 ─┴─► （フェーズ C / D へ）                   │
                                                                   │
【フェーズ C】                                                      │
C-1 ◄──────────────────────────────────────────────────────────────┘
 └─► C-2 ─► C-3 ─► C-5
      └────► C-4 ─────┐
                      │
【フェーズ D】         ▼
D-1 ─► D-2 ─┐    （C-4 は D-5 の前提）
D-3 ────────┤
D-4 ────────┼─► D-5 ─► D-6 ─► D-7 ─► D-8
            │
【フェーズ E】
E-1 ─► E-2 ─► E-3 ─► E-4

【フェーズ F】
F-1 ─► F-2 ─► F-3 ─► F-4 ─► F-5 ◄── A-6
```

### 5.2 推奨実行順序

| 順 | ステップ | 備考 |
| --- | --- | --- |
| 1 | **0-1** | 最初。基準線の記録が以降すべての判断材料になる |
| 2 | **0-2 / 0-3** | 並行可。**0-2 は D-8 の前提**なので早めに済ませる |
| 3 | **0-4** | **フェーズ C のブロッカー。** 0-1 / 0-2 / 0-3 と並行可。**【2026-08-31】0-4 は実施済みだが、その成果（L1 期間の節・M-1・K-19）は要件変更により撤回された**（§7 ／ `0011`）。**残っている成果は `0002` §5.2 の [確定]（根拠を差し替えて維持）である** |
| 4 | **A-1 / A-2 → A-3 → A-6**（**A-4 は独立・いつでも可**。**A-5 は 2026-08-31 に削除**） | **fess-suggest とは完全に独立。** B と並行してよい |
| 5 | **B-1 / B-2 / B-3 / B-5**（並行可） → **B-4a** → **B-4b** → **B-6 / B-7**（並行可） | **B-4b が最大のステップ**（15 ファイル・146 箇所の機械的追従を含む） |
| 6 | **C-1 → C-2 → C-3 / C-4**（C-3 と C-4 は並行可） **→ C-5** | **0-4 の完了が前提** |
| 7 | **D-1 / D-3 / D-4**（並行可） → **D-2** → **D-5** → **D-6** → **D-7** → **D-8** | D-8 は 0-2 も前提 |
| 8 | **E-1 → E-2 → E-3 → E-4** | 順に |
| 9 | **F-1 → F-2 → F-3 → F-4 → F-5** | F-5 は A-6 も前提 |

### 5.3 並行実行できる区間

- **フェーズ A（`modules/fess`）とフェーズ B〜E（`modules/fess-suggest`）は完全に独立**である。別ブランチ・別モジュールなので同時に進めてよい。
- **フェーズ 0 の 0-1 / 0-2 / 0-3 は互いに独立**。
- **B-1 / B-2 / B-3 / B-5 は互いに独立**。
- **D-1 / D-3 / D-4 は互いに独立**（いずれも B-7 の宣言だけに依存する）。
- **C-3（リソース）と C-4（マージ規則）は互いに独立**。

### 5.4 循環の不在

依存グラフに循環は無い。**唯一の注意点は D-8 ↔ E-2 の見かけ上の相互参照**である。`Suggester`（旧）が `SuggestComponents`（新）を保持する**一方向**であり（`0001` §8.3 L1847）、`SuggestComponents` 側は `Suggester` を知らない。**この向きが逆になっていないことを E-2 の DoD で確認する** — 逆向きだと L3 で `Suggester` を削除できなくなる。

### 5.5 リリース順序の制約（**2026-08-31 改訂**）

```text
[フェーズ A の実装完了] ──► ★R0 リリース★ ──► [フェーズ B〜F の実装完了] ──┐
                                                                            ├─► ★R1 リリース★ ──► (R2)
                                        [後続タスク: fess 本体の新 API 切替] ─┘
```

**必須なのは「フェーズ A の成果物が R1 に入っていること」である** [確定]。**「R0 として先に別リリースする」ことは、そこからは導けない** — **R-P1（両モジュールを同時更新する）により、フェーズ A の変更を R1 に同梱することも技術的には可能である。**

**それでも R0 を別リリースとして先に出す** [確定]。**理由は次の 2 つであり、いずれもリリース方式の選択に属する。**

| # | R0 を分ける理由 |
| --- | --- |
| **1** | **ユーザーの要望**: 「fess 本体側の修正量を最小の状態で一旦リリースする」（要件定義 `0000` 第 2 版 §3） |
| **2** | **安全網を現行 fess-suggest の上で先に稼働させ、平常時の日次再構築で実績を積める。** A-1（入力正規化）・A-2（再構築経路の失敗隔離）・A-3（G1 / G3）はいずれも**現行バイナリのままで単独に価値がある**（`0003` 第 14 版 §10.1 の「なぜ R0 を分けるのか」）。**R1 のメジャー移行という一度きりの機会に、初めて動くコードを持ち込まずに済む** |

**したがって運用上の順序制約は「R0 → R1」である** [確定]。**ただしその根拠は「技術的に他に選択肢が無いから」ではなく、上の 2 点である。**

**加えて、R-P1 により次の制約が付く** [確定]:

> **fess-suggest の新版を単独で本番へ入れてはならない。** **R1 では fess 本体と同時に入れる。**
> **本タスクの成果物（フェーズ B〜F）は、それ単独ではリリースできない** — 後続タスク（fess 本体の新 API 切り替え）と束ねて R1 として出す。

**フェーズ A の成果物が R1 に入っていなければならない理由は 2 つである**（**3 つ目は撤回した**）。**これは「R0 として先に出す」理由ではなく、「R1 までに必ず完了していなければならない」理由である。**

| # | 理由 | 根拠 |
| --- | --- | --- |
| 1 | **INV-1 強制と同一リリース制約。** A-1（elevate word 入力の正規化）が入っていないと、R1 の INV-1 強制で管理画面入力が実行時に失敗する | `0003` §10.3 の 3 |
| 2 | **バッチ全体の停止を防ぐ。** A-2（`ForRebuild` 経路の失敗隔離）が入っていないと、backup 復元経由の不正データ 1 件で再構築全体が落ちる | `0003` §10.4 |
| ~~3~~ | **【2026-08-31 撤回】メジャー移行の予防と回復。** ~~L1 リリース直後の最初の SuggestJob がメジャー移行を実行するため、予防は A-3 の G1 / G3 だけ、回復は A-5 の暫定 `.prev` だけである~~ | **R-P1 によりその区間が消滅した**（§0.1 / §7） |

> **理由 3 の撤回は A-3 の削除を意味しない** [確定]。**A-3（G1 / G3）は R0 に残す。** 理由が「L1 期間で唯一の安全網だから」から「**切替可否の判定であり、平常時の日次再構築にも効くから**」へ変わっただけである（`0003` 第 14 版 §10.1 の「なぜ R0 を分けるのか」）。**加えて A-3 は A-2 の失敗件数を `exitCode` へ合流させるステップでもある**（`0007` §3 の引き継ぎ 2）ため、A-2 の DoD を閉じるためにも必要である。

> **理由 1・2 が示すのは「R1 までに完了していること」までである** [確定]。**R0 として先に別リリースする根拠は上の表の 2 点（ユーザー要望 ＋ 安全網の先行稼働）であり、技術的必然ではない。** **この区別を曖昧にすると、「R0 を出し忘れたら R1 も出せない」という誤った運用判断を招く** — 正しくは「**フェーズ A の変更が R1 に入っていなければ R1 を出してはならない**」である。

---

## 6. 検証方針

### 6.1 二段構え（Q10）

| 段 | タイミング | 実行するもの | 理由 |
| --- | --- | --- | --- |
| **ステップ内** | 各ステップの DoD | **該当パッケージのみ**（`mvn test -Dtest='...'`） | **51 テストクラス中 24 が in-JVM で OpenSearch ノードを起動する** [確認]。全件実行はステップごとに回すには重い |
| **フェーズ末** | 各フェーズの最後のステップ | **`mvn test` 全件** | パッケージ横断の破壊を検知する |
| **最終** | F-5 | `mvn test` 全件 ＋ `mvn install` ＋ fess 側 `mvn compile` / `mvn test` ＋ `javap` シグネチャ diff | L1 の DoD |

### 6.2 テストの分類（実行コストの見積もり）

| 分類 | 件数 | 実行環境 |
| --- | --- | --- |
| **OpenSearch runner を起動する既存テスト** | **24 クラス** | ポートバインドとローカル `data` / `logs` / `config` 展開が必要。テスト用 analyzer プラグイン `org.codelibs.opensearch.extension.ExtensionPlugin` を runner に食わせている [確認] |
| **runner 不要の既存テスト** | **27 クラス** | 単体で完結 |
| **新規テスト** | T-1〜T-24 ＋ T-S/T-R 8 件 | **クエリ形状・DTO・マージ規則・ID は runner 不要**（`SuggestRequestQueryBuildingTest` / `SuggestRequestTest` / `SuggestItemMergerTest` 等に置ける）。**mapping の受理（T-12）とエイリアス primitive（T-S 系）は runner 必須** |

> **新規テストはできる限り runner 不要側に置く** [提案]。特に **T-R3（否定形フィルタの negative 検査）は `SuggestRequestQueryBuildingTest` に置けば runner なしで回せる** [確認]。

### 6.3 テストが壊れる 2 つの様態

**「赤くなる」と「コンパイルが通らなくなる」は別物であり、扱いも別である**（外部レビュー指摘 2）。

| 様態 | 起きること | 扱い |
| --- | --- | --- |
| **(I) コンパイル不能** | 型・コンストラクタ・シグネチャの変更により **test-compile が失敗する**。`mvn test` は test-compile を含むため**モジュール全体のテストが 1 本も実行できなくなる**。`-Dtest` で絞っても回避できない（**実行対象を絞るだけで test-compile は全件走る**） | **その変更を行ったステップ内で機械的追従まで完了させる。**（下記ルール 5） |
| **(II) 実行できるが失敗する（赤）** | テストは走るがアサーションが落ちる。仕様変更が意図どおり反映された結果であることが多い | **F-1 に集約して改修する。**（下記ルール 1〜4） |

#### 6.3.1 (II)「意図的に赤くする」テストの扱い

フェーズ B〜E の途中では、`0002` §7.1 が「意図的に変える」と定めた既存テストが赤くなる。**これは正常である。**

| ルール | 内容 |
| --- | --- |
| 1 | **赤くなったテストは、赤くなったステップの作業履歴に一覧として記録する。** どのステップでいくつ赤くなったかを追えるようにする |
| 2 | **改修は F-1 に集約する。** ステップごとに場当たり的に直すと `0002` §7.1 の「変えない／変える」の区別が崩れる |
| 3 | **`0002` §7.1 が「変えない」と分類したテストが赤くなったら、それは実装の誤りである。** テストを直して通してはならない |
| 4 | **フェーズ末の全件実行では、赤いテストの集合が `0002` §7.1 の「変える」リストの部分集合であることを確認する** |

#### 6.3.2 (I)「コンパイル不能」の扱い

| ルール | 内容 |
| --- | --- |
| **5** | **test-compile を壊す変更は、同じステップ内で機械的追従まで行う。** 赤いまま次のステップへ進んでよいのは、**テストが *実行できる* 場合に限る。** |
| 6 | 機械的追従では**アサーションを一切変えない**。生成方法・呼び出し形だけを新 API に置換する。**意味的な改修は F-1 の担当**であり、追従のついでに期待値を直すと `0002` §7.1 の「変えない／意図的に変える」の区別が崩れる |
| 7 | **該当ステップの DoD は `mvn -q compile` ではなく `mvn -q test-compile` にする。** main だけのコンパイルでは (I) を検出できない |
| 8 | 追従の差分は `git diff --stat` で「生成呼び出しの行だけが変わっている」ことを確認する |

> **本プランで (I) が起きるのは B-4b だけである** [確認]（`new SuggestItem(` = 15 ファイル・146 箇所、`new ElevateWord(` = 4 ファイル）。C-1 / C-2 / C-4 は既存シグネチャを保つため (II) に留まる。

### 6.4 fess 本体側の検証の限界（**必ずリリース判断に反映する**）

> **`modules/fess` の既存テストは fess-suggest の変更に対する回帰検知能力を持たない** [確認]。

| テスト | 実態 |
| --- | --- |
| `(fess test) helper/SuggestHelperTest.java`（607 行 / 24 メソッド） | `setUp`（`:41-45`）が `init()` を呼ばず `suggester` は null。`:71` が `assertNull` を期待。各テストは `try { ... assertTrue(true); } catch (Exception e) { assertTrue(true); }` で **NPE を握り潰して必ず緑**。`MockSuggester`（`:502` 以下）は**どこからも注入されていないデッドコード** |
| `(fess test) exec/SuggestCreatorTest.java`（323 行） | **`create()` / `purge()` を一切実行していない。** `:180-257` の `test_create_*` / `test_purge_*` 全 10 テストが `new SuggestCreator.Options(); assertNotNull(options);` のみのプレースホルダ |
| `(fess test) job/SuggestJobTest.java`（1088 行） | 外部プロセス起動の CLI 組み立てのみ。`:125` のコメントが「実行時に例外を握るので Exit Code を保証できない」と自認 |
| `(fess test) api/v2/handlers/SuggestWordsHandlerTest.java`（679 行） | `:82` のコメントが「この JVM に suggest エンジンが無いので 400/500 も受け入れる」と明記。**意図的に握り潰す設計** |
| `(fess test) it/admin/SuggestTests.java` | 唯一 fess-suggest を実際に動かすが `response.status == 0` とキー存在のみ |

**帰結**:

1. **旧ファサードの互換性検証は「コンパイルが通る」＋「48 メンバのシグネチャが不変」までである。** 実挙動の回帰は検知できない。
2. **フェーズ A で追加するテスト（A-6）は、必ず「一度赤くなること」を確認する。** 現行 fess 側テストの最大の問題は「常に緑」であることなので、新規テストが同じ罠に落ちていないことを能動的に確かめる。
3. **既存 `SuggestHelperTest` の握り潰し構造は本タスクでは直さない。** **R1 の後続タスク**の T-F1（`0003` MO-13 が「補強ではなく新規作成」と明記）で作り直す。**中途半端に直すと衝突する。**

---

## 7. 【2026-08-31 撤回】L1 中間状態の設計上の穴（追加調査の結果）

> **本節は全体として役目を終えた。記録として残す。**
>
> **撤回の理由**: 本節は **L1 期間（新 fess-suggest ＋ 旧 fess 本体 ＋ 旧世代インデックスが本番に同時存在する区間）** を安全にするための調査と緩和策である。**R-P1（fess 本体と fess-suggest は常に同時更新する）により、この区間は生じない**（要件定義 `0000` 第 2 版 §2 ／ `0003` 第 14 版 §10.1）。
>
> **撤回するもの**: **穴 1（汚染の窓）** ／ **M-1（デプロイ直後の即時再構築）** ／ **M-5 / K-19** ／ **M-6 とステップ A-5（暫定 `.prev`）** ／ **§7.5 / §7.5.1 の採否判断（U-1 / U-7）** ／ **§7.3（メジャー移行は L1 直後に起きる）の運用上の帰結**。
>
> **撤回しないもの**: **§7.6 の点検結果のうち DM-10 の穴 2 に対する対処**（`0002` 第 9 版 §5.2 の [確定] — **欠損 `reading_i` スロットは空配列として復元する**）。**根拠は L1 期間から差し替えた**が、決定そのものは維持する — **新バイナリが INV-1 未強制のドキュメントを読む経路は、ロールバック後の旧世代への書き込み・backup 復元経由の不正データ・切替不合格のまま旧世代で運用する状態として残る**（`0002` 第 11 版 §5.2 ／ `0003` 第 14 版 §10.6.3 の 3）。
>
> **§7.3 の分析（`SuggestCreator.create()` は毎回が全件再構築であり、`createNextIndex()` は新バイナリ同梱の mapping を読む）は事実として正しく、撤回しない。** **R1 ではその再構築をサービス停止中に運用者が起動する**ため、「いつ起きるか分からない」という前提だけが成立しなくなった。
>
> **以下は撤回前の記述である（記録）。**


> **本節は Q3=(A)（データモデル変更を全部 L1 に同梱する）を選んだ結果、必ず解決が要る論点として調査したものである。**
> **結論: 穴である。しかも当初想定より重い。逸脱手続き（区分 I）の対象であり、ステップ 0-4 で処理する。**

### 7.1 調査の結論

**「L1 バイナリ ＋ 旧世代インデックス ＋ 旧 fess 本体（無変更）」という中間状態を、設計書は扱っていない** [確認]。

| # | 確認した内容 | 根拠 |
| --- | --- | --- |
| 1 | `0002` §4（決定的 ID 再設計）全体に、**新 ID バイナリが旧 ID インデックスに書き込む期間の記述は無い**。§4.4「ID 変更の影響範囲」は「コード上のどこを直すか」のみで、既存インデックスとの**時間的関係**に一切触れていない | `0002` §4.1〜§4.7 を精読 |
| 2 | `0002` §4.7 は「旧世代インデックスとの共存は成立しない」「部分移行・段階適用の選択肢は存在しない」と**宣言するだけ**で、**「成立しない状態が現実に発生しうる期間があるか／どう回避するか」を書いていない**。文脈は「移行方式の選択肢を潰す」ことであり、デプロイ直後の中間状態ではない | `0002` §4.7 |
| 3 | **`0002` 全体で `L1` / `L2` の語は 0 件。** すなわち `0002` はリリース段の存在自体を認識していない | 全文 grep |
| 4 | `0002` §6.1 が **「共存が問題になるのは `excluded` フィールドの有無だけである」と宣言し、書き込み側の共存を §6 の議題から外している**。§6.2 / §6.3 が扱うのは**読み取り経路だけ**である | `0002` §6.1 |
| 5 | MO-19（新バイナリで旧世代へ書くな）は **§5「ロールバック手順」の R4 に紐づいており、禁止しているのは「戻す」という操作**である。L1 期間は「戻す」操作をしていないのに同じ状態になるが、文言・配置・テスト（T-R6 は `T-R` 系）のいずれもロールバック限定 | `0003` §5.3 R4 / L523-547 / §11.2 T-R6 |
| 6 | ただし**禁止の理由（`0003` L531-537）は操作に依存しない**: 新コードが旧インデックスへ同じ語を書くと旧 ID と新 ID のドキュメントが併存し、**text 単位の頻度集約（KEEP-03）が壊れる。旧世代は `dynamic: true` のため書き込み自体は通り、エラーにならずに壊れる** | 同上 |
| 7 | `0003` §10.1 / §10.2 / §10.3 に **L1 期間の運用制約（増分取り込みの停止など）は 1 行も無い**。§10.1 が持つ時間軸は「**L1 以前**」と「**L2 以降**」の 2 つだけで、**「L1 と L2 の間」という区間が表の欄として存在しない** | `0003` §10.1 の 2 つの表（L810 / L818） |
| 8 | `0003` §13（申し送り 14 件）にも該当項目は無い | 全件確認 |
| 9 | **「ID 方式を切り替えるフラグ」「移行モード」に相当する概念は設計書に存在しない** [確認]。ID 生成は `0002` §4.1 で**無条件の単一方式**として定義され、切り替え軸を持たない | 4 文書を `フラグ` / `移行モード` / `互換モード` で grep |

### 7.2 発見した穴（2 件）

#### 穴 1: 新 ID バイナリが旧世代インデックスへ書き込む期間が定義されていない

L1 リリース後、fess 本体は無変更のまま通常どおり増分取り込みを行う（`(fess) helper/SuggestHelper.java:199 indexFromSearchLog` / `:267 indexFromDocuments`、および管理画面からの `addElevateWord`（`:482`）/ `addBadWord`（`:520`））。**書き込み先は更新エイリアス**（`(sug) Suggester.java:408`）で、それは**旧世代インデックスを指したまま**である。

- 同じ語が**旧 ID のドキュメントと新 ID のドキュメントに分裂**する。
- **`0002` §4.4.1 の衝突検査（DM-16）は発火しない** — 新 ID で multiGet するため旧 ID ドキュメントに hit しない。
- 旧世代は `dynamic: true` [確認]（`(sug res) suggest_indices/suggest/mappings-default.json` にトップレベル `dynamic` キーが無い）のため、**`excluded` も動的にマッピングされて書き込みが通り、エラーにならずに壊れる。**

#### 穴 2: `0002` §5.6 の推論が旧世代ドキュメントに対して成立しない

`0002` §5.6（F-04 の解消）は次の 1 文に全体が乗っている:

> 同一 ID ⇒ 同一 `text`（INV-5）⇒ 同一 W。**INV-1 により既存ドキュメント側の `reading_i` の本数も新 item 側の本数も W に等しい。**

**この「既存ドキュメント側も INV-1 を満たす」という前提は、新バイナリが書いたドキュメントについてしか成立しない。** 旧世代ドキュメントは INV-1 未強制の旧バイナリで書かれており、`reading_i` の本数が W と一致しない。しかも**それが例外ではなく常態である**ことを設計書自身が別の節で述べている（`0002` §5.2 L529「k ≠ W は実運用で普通に発生する」／ §5.6 の経路 A が「成立する」）。

さらに `0002` §5.2 は「`fromSource` の無限ループは廃止し、`text` から導出した W で回す」と定めるのみで、**「W で回したが `reading_i` が存在しない」場合の扱いを定義していない**。L1 期間に旧世代ドキュメントを multiGet で引くと、この未定義ケースに入る。

### 7.3 さらに重大な発見: メジャー移行は L2 ではなく L1 直後に起きる

> **`0003` §10.1 の「メジャー移行そのもの（`0002` §4.7 の再構築）は L2 以降にしか起きない」（L813）は成立しない** [確認]。

根拠（すべてコードで確認済み）:

| # | 事実 | 根拠 |
| --- | --- | --- |
| 1 | `0002` §4.7 が「1 回の再構築に束ねる」とした 4 変更（ID ハッシュ化 / 語数上限 N / `ElevateWord` 格納形 / mapping 変更）は、**すべて fess-suggest 側の成果物**であり、fess 本体側の変更を 1 つも含まない | §4.7 の表と各実体の所在 |
| 2 | **`SuggestCreator.create()` は毎回が全件再構築である** | `(fess) exec/SuggestCreator.java:252` `suggestHelper.suggester().createNextIndex();` ／ `:255` `suggestHelper.storeAllBadWords(true);` ／ `:258` `suggestHelper.storeAllElevateWords(true);` ／ `:298` `suggestHelper.suggester().switchIndex();` [確認] |
| 3 | **`createNextIndex()` は新バイナリ同梱の mapping / settings をクラスローダから読む** | `(sug) Suggester.java:238` `final String mappingSource = getDefaultMappings();`（`:239` が `getDefaultIndexSettings()`）。`:467-475` / `:477-485` が `suggest_indices/suggest/mappings-default.json` / `suggest_indices/suggest.json` を `ClassLoader#getResourceAsStream` で読む [確認] |
| 4 | **Suggest Indexer ジョブの既定 cron は `0 12 * * *`（日次）** | `(fess res) fess_indices/fess_config.scheduled_job/scheduled_job.bulk:4` — `{"name":"Suggest Indexer","cronExpression":"0 12 * * *", ... ,"available":true}` [確認] |

**帰結**:

1. **L1 リリース後の最初の SuggestJob 実行が、fess 本体無変更のまま 4 変更すべてを載せた全件再構築を実行する。** メジャー移行は L1 直後に起きる。**L2 が追加するのはガード（G2 / `.prev` 保持 / `wordCountStats` への移行）だけである。**
2. **メジャー移行が最も安全網の薄い時点で発生する。** G2 は `validateNext` を fess 側が呼ばないため**発動しようがなく**、`.prev` 保持も無い。MO-22（メジャー移行時は G2 必須）が**空振りする**。**唯一効く安全網はフェーズ A で先行リリースする G1 / G3 ガードだけである。**
3. **穴 1 / 穴 2 の窓の長さが確定する**: L1 デプロイ 〜 最初の `createNextIndex()` まで、**既定で最大約 1 日**。窓が閉じれば新世代へ移るため汚染は最大 1 世代ぶんで自然に解消するが、**その 1 世代ぶんの頻度分裂は検索結果に現れる。**

### 7.4 逸脱手続きの判定

| 項目 | 判定 |
| --- | --- |
| **区分** | **区分 I（設計判断の誤り・不足）。** 事実の更新ではなく、設計書が扱っていない状態が存在するという不足である |
| **改訂対象** | **`0003`**（§10 に L1 期間の節を新設。§10.1 L813 の誤りを訂正） ＋ **`0002`**（§6.1 の共存範囲の記述、§5.6 の前提の限定） |
| **発火するステップ** | **0-4**（**条件付きではなく確定した実施ステップ**） |
| **ブロックするもの** | **フェーズ C 全体**（特に C-1: ID 置換）。**0-4 の完了前に C-1 に着手してはならない** |
| **採用した緩和策** | **M-1 ＋ M-5**（§7.5・2026-08-24 決定済み） |

### 7.5 緩和策 — **M-1 ＋ M-5 に決定済み**

> **決定**: **M-1（L1 リリース手順への即時再構築の組み込み）＋ M-5（残る窓を既知の制約 K-19 として記録）＋ M-6（`.prev` 付与の暫定版をフェーズ A に先行）の併用。**
> **M-1 / M-5 は「穴 1（汚染の窓）」に、M-6 は「R-2 の本体（切り替わった後の戻り先の不在）」に効く。両者は別の問題への対処である**（§7.5.1）。
> **決定者**: ユーザー ／ **決定日**: 2026-08-24 ／ **反映先**: ステップ 0-4
>
> **決定の内容**:
> 1. **M-1**: L1 デプロイ直後に SuggestJob を手動起動して再構築を完了させる手順を、`0003` に**リリース手順として記述し、L1 リリースチェックリストの必須項目にする**。起動手段は既存（`0003` §2.2 [確認]）。
> 2. **M-5**: それでも残る窓（手順を飛ばした場合は既定で最大約 1 日）を、`0003` §12 に **[提案] K-19** として記録する。
>
> **採用理由**: (a) **コード変更が 0** で L1 のスコープを膨らませない。(b) 汚染は次の再構築で新世代が空から作られることにより解消するため、**恒久的な破壊ではない**。(c) M-3（ID 方式フラグ）は設計に無い概念を持ち込み、ID 生成 3 箇所すべてに分岐が入って DM-16（生成規則の食い違いを検出する）と逆行し、**L3 まで負債が残る**。
>
> **残る弱点（K-19 として明記すること）**: **M-1 は運用手順であり、飛ばされると窓が開く。** 実効性の担保はリリースチェックリストへの記載のみである。

| # | 案 | 内容 | 長所 | 短所 |
| --- | --- | --- | --- | --- |
| **M-1** | **L1 リリース手順に「即時再構築」を組み込む** | L1 デプロイ直後に SuggestJob を手動起動し（`0003` §2.2 が「任意タイミングでの起動手段は既に存在する」と確認済み [確認]）、窓を数分に縮める | 追加のコード変更が **0**。設計書への追記だけで済む | 窓はゼロにならない（デプロイ〜手動起動の間）。**運用手順に依存する**（手順を飛ばすと最大 1 日の窓が開く） |
| **M-2** | **L1 デプロイ前に SuggestJob を停止し、デプロイ後に再構築してから再開する** | 窓を完全に閉じる運用手順 | **窓がゼロになる。** コード変更 0 | 運用負荷が高い。管理画面からの elevate/bad word 追加は止められない（Web 側が動いている限り書き込みは起きうる） |
| **M-3** | **ID 方式を切り替えるフラグを設ける** | `SuggestSettings` に ID 方式のフラグを持たせ、L1 では旧方式のまま動かし、L2 の再構築で新方式に切り替える | 窓が構造的に閉じる。運用手順に依存しない | **設計書に存在しない概念を新設する**（`0002` §4.1 は無条件の単一方式）。ID 生成 3 箇所すべてに分岐が入り、DM-16 の「生成規則の食い違いを検出する」という目的と逆行する。**フラグの除去（L3）まで負債が残る** |
| **M-4** | **L1 期間の増分書き込みを検出して拒否する** | 更新エイリアスが指すインデックスの世代を判定し、旧世代なら書き込みを例外にする | 沈黙して壊れるのを防ぐ | **世代を判定する手段が無い**（`0002` §6.2 が「インデックス世代を検索時に判定する手段を持たない」と明記）。mapping に `excluded` があるかで代替判定はできるが、**新設概念であり `0002` §6.3 の「`excluded` が無い＝除外されていない」という読み替えと衝突しうる** |
| **M-5** | **穴として記録し、受容する** | `0003` に「L1 期間に最大 1 世代ぶんの頻度分裂が起こりうる」を既知の制約（K 番号）として追加する | 最小コスト | **頻度分裂は検索結果に現れる**。KEEP-03 が壊れる期間を明示的に許容することになる |
| **M-6** ✅**採用** | **`.prev` 付与の暫定版をフェーズ A に先行させる** | フェーズ A に **fess 側 alias 操作による `.prev` 付与**を置く。`switchIndex()` の直前に現検索対象へ付与し、`0003` §3.3 の付け替え規則（**既存 `.prev` を全インデックスから remove → 現検索対象に add**）を含める。ロールバックも alias 操作の直接実行とする。**L2 で `switchIndexRetainingPrevious()` / `rollbackToPrevious()` へ移行して撤去する** | **実際に起きるメジャー移行に戻り先ができる。** §0.1 のとおり G2 が空振りする以上、**G1 / G3 を通過した「件数は十分だが検索が壊れている」型の事故に対する唯一の回復手段**になる。`removeDisableIndices()` の**削除判定は無変更のまま**なので、付けるだけで旧世代が物理削除から外れる（`0003` §5.1 / `Suggester.java:345-353`）。DM-14 の否定形フィルタが旧世代への切戻しを既に保護している（`0003` MO-5） | **2 リクエストの 2 段構成なので中間状態が残る**（`0003` L269 が第 3 版の形として明示）— (1) 成功・(2) 失敗の窓で「`.prev` と検索エイリアスが同じ旧世代を指す」状態になり、再実行時に `.prev` の解除が要る。**1 リクエスト化で消えるはずだった状態を暫定的に復活させる**。L2 で撤去する暫定コードがフェーズ A に残る。**MO-17 が primitive 化した理由（「`.prev` は常にちょうど 1 インデックスを指す」不変条件は付与と解除が散らばると守れない）に一時的に逆行する** |

**上表は検討の記録として残す。** 採用しなかった M-2 / M-3 / M-4 の却下理由が、K-19 を読む次の人にとって文脈になる。

#### 7.5.1 M-6（`.prev` 先行）— **採用決定**

> **決定**: **M-6 を採用する**（M-1 ＋ M-5 と併せて 3 案の併用）。
> **決定者**: ユーザー ／ **決定日**: 2026-08-24（外部レビュー指摘 1 を受けた追加判断 = U-7 の (a)） ／ **反映先**: **ステップ A-5**（新設）・§3.2 の P-08・ステップ 0-4
>
> **M-1〜M-5 はすべて「穴 1（汚染の窓）」への対処であり、R-2 の本体である「切り替わった後の戻り先が無い」には効かない。** M-6 だけがそこに効く。**この区別は §10.2 の R-2 に反映してある。**

**M-6 が検討表に無かった理由** [確認]: `0003` §3.2（L269）が示すとおり、`.prev` 付与は**第 3 版まで fess 側の `SearchEngineClient` による alias 操作で行う 2 リクエスト 2 段構成**だった。MO-17（`0001` 第 4 版 D-21）が primitive 化して 1 リクエストに束ねたため、本プラン §3.2 は「`.prev` 保持は先行できない [確認]」とした。**これは `switchIndexRetainingPrevious()` を正式経路とするなら正確だが、「fess 側 alias 操作で `.prev` を付ける」こと自体は技術的に可能なまま**である。**削除判定のロジックは今も無変更である**（`0003` §5.1 の表が「既存の削除判定への影響: 無し」と明記し、第 4 版の注記も「削除判定のロジックが無変更である**という点は変わらない**」と述べている）。

**設計がこの選択肢を落としたのは、「メジャー移行は L2 以降にしか起きない」という前提の下で `.prev` 先行が nice-to-have だったからである。§0.1 の発見はこの前提を覆した。**

➡️ **本プランの推奨: 採用する。**

| # | 理由 |
| --- | --- |
| 1 | **G1 / G3 は「切り替えないこと」しかできない。** 通過してしまった切替を**元に戻す**手段は `.prev` 以外に無い（`0003` §5.3 R2 が `.prev` 0 個を「ロールバック不可」と定義している）。**MO-22 が防ごうとした事故（件数も取り込みも正常なのに検索だけ 0 件）はまさに G1 / G3 を通過する型**であり、L1 期間はこれが無防備になる |
| 2 | **失敗時の被害が非対称である。** M-6 を採らずに事故ると**1 世代ぶんのサジェストデータが復旧不能**（旧世代は `removeDisableIndices()` に物理削除される）。M-6 を採って中間状態に落ちても、**「`.prev` と検索エイリアスが同じ旧世代を指す」＝ 戻り先が現行世代しか無い**という、M-6 が無い場合と同じ状態に留まるだけである。**下振れが元の状態より悪くならない** |
| 3 | **2 段構成の中間状態は第 3 版の設計が受容していた形そのものである。** MO-17 はそれを**改善**したのであって、旧形が安全でないと判定したわけではない |
| 4 | 撤去コストが小さい。L2 で `switchIndexRetainingPrevious()` に置換する際、**削除するのは fess 側の alias 操作コードだけ**である（ライブラリ側に暫定コードを残さない） |

**採用に伴う変更**（実施済み）: **ステップ A-5**（`.prev` 付与の暫定実装 ＋ ロールバック手順書 ＋ **L2 での撤去箇所一覧**）を新設し、**A-3 の後・A-6 の前**に置いた。**A-6 の作業内容 7** に `.prev` の検証 4 項目（**T-S4 / T-S5 / T-R1 の先行版相当**）を追加した。**§3.2 の分類表に P-08** として加えた。**ステップ 0-4** の `0003` 改訂内容に M-6 の暫定手順とロールバック手順の追記を含めた。

> **撤去の担保**: 暫定実装は **L2 で `switchIndexRetainingPrevious()` / `rollbackToPrevious()` / `aliasState()` に置換して撤去する**。撤去箇所の一覧を **A-5 の作業内容 5** で作業履歴に残すことを DoD にした。**撤去対象は fess 側のコードだけであり、ライブラリ側に暫定コードは残らない。**

### 7.6 同種の穴の点検（追加指示 3）

**DM-3 / DM-10 / DM-14 について、同じ観点（L1 バイナリ ＋ 旧世代インデックス）で点検した結果である。**

| 決定 | L1 期間の挙動 | 設計書の記述 | 判定 |
| --- | --- | --- | --- |
| **DM-3**（`score` 廃止・`excluded` 追加） | 旧世代は `dynamic: true` なので `excluded` は `boolean` として動的にマッピングされ、**書き込みは通る**。`score` は新バイナリが書かなくなり、`OpType.INDEX` の全置換により**旧世代ドキュメントの `score` は上書き時に消える** | **記述は無い**（`0002` §2.6 の M-3 / M-4 は差分の宣言のみ） | **破綻しない。** `score` は検索側が一切参照していない [確認]（`0002` §2.6 の M-3 影響欄）。`excluded` の書き込みも `0002` §6.3 の読み替えと矛盾しない。**記述が無いこと自体は問題だが、実害が無いので区分 II 相当の追記で足りる** |
| **DM-10**（走査基準の W 統一） | 旧世代ドキュメント（INV-1 未強制）を multiGet で引くと `reading_i` の本数が W と一致せず、**未定義ケースに入る** | **記述は無い。** `0002` §5.6 は既存ドキュメントを暗黙に新バイナリ産と想定している | **穴である**（**§7.2 の穴 2**）。実害は F-04 と同型の余剰 `reading_i` 欠落（旧来から起きていた現象）＋ 欠損 `reading_i` に対する未定義動作。**0-4 の改訂対象に含める**（ステップ 0-4 の作業内容 7・8） |
| **DM-14**（否定形フィルタ） | `excluded` を持たない旧世代ドキュメントが `mustNot(term(excluded, true))` を通過する | **記述がある。** `0002` §6.1 が「MIG-13 を適用したコードが `excluded` を持たない旧世代インデックスを**検索する**期間が存在しうる」「エイリアス切替の**前**後で検索側のコードは同一」と明記。「切替の前」＝ L1 期間を（L1 と名指しせずに）含む | **穴ではない。** **DM-14 だけが読み取り側の中間状態を正しく扱っている。** これが本節の調査で「§6 は読み取り経路しか扱っていない」と判定した根拠でもある |

> **付随して見つかった軽微な不整合** [確認]: **`0001` / `0002` / `0003` の 3 文書とも冒頭が「現在の版: 第 7 版（2026-08-17）」のままだが、改訂履歴には第 8 版の行がある**（2026-08-22 の閉包リファクタリング。`0000` §0.2 も「各文書の第 8 版」と述べている）。**冒頭表記が第 8 版への更新時に据え置かれた**ものである。設計内容には影響しないため**区分 II**として扱い、ステップ 0-2 / 0-4 の作業内容 0 で是正する（§9.2）。
>
> **共通の型**: X-1（`SuggesterBuilder.build(...)` の戻り値）・穴 1・穴 2 はいずれも **「L1 という中間状態で何が起きるか」を設計書が詰めきれていない**ことに起因する。設計書は「最終形（L2 / L3 完了後）」と「移行手順（再構築の中）」は精密だが、**リリース段の間に置かれた実行状態**の記述が薄い。**実装中に同種の穴を追加で見つけたら、迷わず区分 I として扱うこと。**

---

## 8. 完了条件（本タスクの DoD）

| # | 条件 | 検証方法 |
| --- | --- | --- |
| 1 | `modules/fess-suggest` で **`mvn test` が全緑** | `mvn test`（全件）。ステップ 0-1 の基準線と比較（U-6 の除外リストを適用） |
| 1b | **B-4b 以降、モジュール全体の `mvn test-compile` が常に通る**（§6.3 のルール 5・7） | 各ステップの DoD |
| 2 | `0002` §7.1 の既存テスト改修が全行処理済み。**「変えない」行が実際に変わっていない** | F-1 の DoD ＋ 作業履歴 |
| 3 | **T-1〜T-24 が全件実装済みで緑**（T-24 は `0002` 第 10 版で追加） | F-2 の DoD |
| 4 | **T-S11 / T-S13 / T-R3 / T-R5 / T-R6 / T-R7 ＋ T-S5・T-S10 の primitive 部分が緑** | F-3 の DoD |
| 5 | **`modules/fess` がフェーズ A の変更のみでビルドできる**（`mvn compile` / `mvn test`）。**【2026-08-31】これは旧ファサードの互換性（U-9）が保たれていることの検査であり、「fess 本体を無変更のまま本番稼働させる」という運用要件ではない**（§0 の到達点 4） | F-5 |
| 6 | **旧 `Suggester`（18）/ `SuggestIndexer`（30）の計 48 メンバの public シグネチャが 1 つも変わっていない** | `javap` diff（F-5） |
| 7 | `api` / `spi` が **OpenSearch の型を一切露出していない** | grep（B-6 / B-7） |
| 8 | `api` 4 IF の合計が **30 メソッド**、`SuggestStore` が 17、`BadWordPolicy` が 6 | B-6 / B-7 の DoD |
| 9 | **7 ファイルすべてから `number_of_replicas` が消えている**（fess-suggest 側 4 = C-3 ／ fess 本体側 3 = **A-4**） | grep（A-4 / C-3 / F-4 / A-6） |
| 10 | **逸脱手続きが 7 件（X-1 / X-2 / X-3 / X-4 / X-5 / X-6 / X-7）すべて処理済み**で、それぞれ改訂 → 記録 → 実装の順になっている。**X-4 は実装中（A-1）に、X-5 は着手時（A-2）に、X-6 は A-2 の実装に対する外部レビューで、X-7 は A-3 の着手可否判定で発火したもの**である。**【2026-09-04 追記】X-7 は「改訂（`0003` 第 16 版）→ 記録（`0016`）→ 実装」の順序規律を満たす** — 記録の完了時点でコードは 1 行も変えていない（`0016` §7）。**【2026-08-31 追記】X-6 は「改訂（`0003` 第 13 版）→ 記録（`0010`）→ 再実装」の順序規律を満たす** — 記録の完了時点でコードは 1 行も変えていない（`0010` §11 の 1）。**X-6 は MO-25 の改訂であり新しい MO 番号を起こしていないため、MO-25 に対応する X 番号は X-5 / X-6 の 2 つになる**（判定は `0010` §1.2）。**X-5 は「改訂 → 記録 → 実装」の順序規律を満たしている**（記録は `0009`）。**【2026-08-31 追記】X-4 には A-1 レビュー反映による追補改訂（`0003` 第 11 版・区分 I）がある。この追補は「実装（コメントのみ）→ 改訂 → 記録」の順であり順序規律を満たさないが、新しい実装判断を含まないため本 DoD の趣旨には抵触しない — 判定の根拠は `0008` §2.5 に明記してある。本 DoD を閉じる際にこの例外を確認すること** | git 履歴 ＋ 作業履歴 |
| 11 | **フェーズ A の全 5 ステップ（A-1 / A-2 / A-3 / A-4 / A-6）が完了し、R0 をリリースできる状態である。** **【2026-08-31 改訂】「予防（G1/G3・A-3）と回復（暫定 `.prev`・A-5）の両方が入っていること」という条件は撤回した** — **A-5 を削除したため**（§4 ／ `0011`）。**回復手段（`.prev` 保持とロールバック）は R1 で正式 primitive として入る**（ステップ D-2）。**【2026-09-04 追記】A-6 が完了し、本条件は充足した** — フェーズ A の全 5 ステップ（A-1 / A-2 / A-3 / A-4 / A-6）が完了し、**`modules/fess` の `mvn test` が 7461 件で全緑である** [確認]。記録は `0007` §6 ／ 完了宣言は同 §7。**同日のレビュー反映（`0017`）後は 7468 件で全緑である** [確認] | A-6 の DoD ／ **作業履歴 `0007` §6.8・§7** |
| 12 | **§6.4 の「fess 側テストが回帰検知能力を持たない」という限界がリリース判断に明記されている** | E-4 / F-5 の作業履歴 |
| ~~**13**~~ | **【2026-08-31 撤回】~~L1 リリースチェックリストが成果物として存在し、M-1（デプロイ直後の SuggestJob 手動起動）が【必須】項目として入っている~~。** **M-1 と K-19 を撤回したため、本条件は消滅した**（§7 ／ `0003` 第 14 版 §10.6 / §12）。**代わりに、R1 の移行手順（`0003` 第 14 版 §10.6.1 の 9 手順）は後続タスクの成果物である** — 本タスクでは §10.3 に申し送る | — |
| **14** | **OpenSearch 3.8.0 の未検証 3 点（`strict_allow_templates` / `total_fields` の緩和機構の不在 / `GetRequest` の `realtime` 既定値）が、C-3（G-OS1）と D-1（G-OS2）の着手前ゲートで確認され、結果が作業履歴に残っている** | C-3 / D-1 の作業履歴 |
| **15** | **MO-24（elevate word の追加経路と削除経路の `_id` 対称性）が実装され、A-6 で検証されている。** `addElevateWord` と `deleteElevateWord` が**同じ正規化関数の出力をキーとして使う**こと、および**正規化前後で語が変わる場合に生キーと正規化キーの両方で削除する**ことの 2 点。`0003` **第 11 版**（安全性根拠は同版 §10.3.1 (d) の 3 を正とする）§10.3 の 4 / §10.3.1 | A-1 の DoD ＋ **A-6 の T-F3** ／ 作業履歴 `0006`・`0008`・**`0007` §6.3 の 1**。**【2026-09-04 追記】A-6 で `(fess test) helper/SuggestHelperElevateWordTest.java` の 9 件（T-F3 分 4 ＋ MO-24 分 5）が緑になり、本条件は充足した** [確認] |
| **16** | **MO-25（全件再投入系メソッドの失敗隔離）が実装され、A-6 で検証されている。** **【X-6 で全面改訂】** ①**再構築経路の削除フェーズと追加フェーズの両方**にスキップ機構が入っていること ②**失敗件数が「失敗した行の数」（行 ID で dedupe した 1 つの数）として `ForRebuild` メソッドの戻り値で返り、`SuggestHelper` のインスタンスフィールドに保持されていない**こと（**件数用フィールドも dedupe 用 `Set` も持たない**） ③**bad word 側の削除フェーズ（`deleteAllBadWords()`）には入れていない**こと ④**public 3 メソッド（`storeAllElevateWords(boolean)` / `deleteAllElevateWord(boolean)` / `storeAllBadWords(boolean)`）の挙動が A-2 着手前と完全に同一である**こと（`void`・fail-fast・例外をそのまま伝播。呼び出し元 11 箇所が無変更） ⑤**`(fess) exec/SuggestCreator.java` の変更が `:255` / `:258` の 2 行に限られ、`ForRebuild` の呼び出し元がその 1 ファイルだけである**こと。`0003` **第 13 版** §10.4 (e) / (f) / (g) / (i) / (j) | A-2 の DoD ＋ **A-6 の作業内容 2（4 点）** ／ 作業履歴 `0009`・**`0010`**・**`0007` §6.3 の 2**。**【2026-09-04 追記】A-6 で `(fess test) helper/SuggestHelperRebuildIsolationTest.java` の 9 件が緑になり、本条件は充足した** [確認]。**⑤（`ForRebuild` の呼び出し元が 1 ファイルだけ）も同ファイル `:173` の grep 検査で機械化した** |

**満たさないもの（明示的にスコープ外）**: 実 OpenSearch を起動して fess から再構築を 1 回通す検証（Q10=(B) により**後続タスク**へ。**R1 の停止中移行手順の検証としてそこで行う** — `0003` **第 15 版** §10.6.1）。

---

## 9. 成果物一覧

### 9.1 作業履歴ドキュメント（Q9=(B)）

**フェーズ単位で 1 ファイル。逸脱手続きの発火は独立した 1 ファイル。**

| 通し番号 | ファイル名 | 内容 |
| --- | --- | --- |
| 0001 | `0001-work-plan.md` | **本書** |
| **0002** | `0002-deviation-x1-builder-return-type.md` | **逸脱 X-1**（区分 I）。`0001` 第 9 版改訂の記録。ステップ 0-2 |
| **0003** | `0003-deviation-x3-l1-interim-state.md` | **逸脱 X-3**（区分 I）。`0003` / `0002` の改訂記録、**メジャー移行タイミングの訂正**、採用した緩和策（**M-1 ＋ M-5**）と K-19 の全文。ステップ 0-4 |
| 0004 | `0004-phase-0-preparation.md` | フェーズ 0（0-1 / 0-3）。ビルド前提の実測、**区分 II の軽微改訂（X-2）**、基準線の記録 |
| **0005** | `0005-review-response-phase0.md` | **外部レビュー（第 2 回・2026-08-31）の反映。** フェーズ 0 の作業記録に対する指摘 6 件の処遇、**`0002` 第 10 版改訂（T-24 の追加 — 逸脱 X-3 の追補・区分 I）**、`mvn -o compile` の実測、本プランへの反映（§13） |
| **0006** | `0006-deviation-x4-elevate-word-id-symmetry.md` | **逸脱 X-4**（区分 I）。**ステップ A-1 の実装中に発火。** `0003` **第 10 版**改訂の記録（**MO-24** — elevate word の追加経路と削除経路の `_id` 対称性 ＋ 移行期の新旧両キー削除）、代替案 3 案の採否、**残存リスク**（生キーで投入済みの既存ドキュメント）、実装側が満たすべき仕様の擬似コード |
| 0007 | `0007-phase-a-fess-precede.md` | フェーズ A（A-1〜A-6）。先行リリース分 ＋ **U-2 により移設した `(fess res)` 3 ファイルの `number_of_replicas` 削除（A-4）** （**A-5 は 2026-08-31 に削除。着手前だったため実装記録は存在しない**） |
| **0008** | `0008-review-response-a1.md` | **外部レビュー（ステップ A-1 の実装）の反映。** 指摘 5 件の処遇、**`0003` 第 11 版改訂**（MO-24 (d) の規則 3 の根拠の是正 — **逸脱 X-4 の追補・区分 I。新しい X 番号は起こさない**）、**是正後の行番号一覧**（`0007` §1 を上書きする） |
| **0009** | `0009-deviation-x5-store-all-delete-phase.md` | **逸脱 X-5**（区分 I）。**ステップ A-2 の着手時に発火。** `0003` **第 12 版**改訂の記録（**MO-25** — 全件再投入系メソッドの失敗隔離をすべての行単位ループへ拡張。削除フェーズを含む ＋ 失敗件数の合算）、代替案 3 系統の採否、**残存リスク**、実装側が満たすべき仕様の擬似コード |
| **0010** | `0010-review-response-a2.md` | **外部レビュー（ステップ A-2 の実装）の反映 ＝ 逸脱 X-6**（区分 I）。指摘 5 件の処遇、**`0003` 第 13 版改訂**（MO-25 の**規則 3 = 失敗件数を行 ID で dedupe した行数に**／**規則 6 = 失敗隔離を再構築専用経路に限定し public は fail-fast のまま**／(f) の全面書き直し／(i)・(j) の新設）、**区分と X 番号の判定**（新しい X 番号を起こし、新しい MO 番号は起こさない）、**実装側が満たすべき仕様の擬似コード（`0009` §7 を上書きする）**、**「DoD ではなく実装を曲げるべきだった」という自己訂正** |
| **0011** | `0011-requirements-revision-release-model.md` | **要件定義の改訂（2026-08-31）。** **逸脱手続き（X 番号）ではなく、ユーザーによる配布・運用モデルの確定＝要件変更である。** R-P1〜R-P3 の確定、リリース段の R0 / R1 / R2 への組み替え、**撤回した項目の一覧（M-1 / M-5 / M-6 / K-19 / ステップ A-5 / P-08 / U-1 / U-7 / C-01 の運用上の読み方）**、**維持した項目とその根拠の差し替え**、`0003` 第 14 版・`0002` 第 11 版・`0000` の改訂記録 |
| **0012** | `0012-review-response-requirements-revision.md` | **外部レビュー（要件定義の改訂 `0011` に対するもの）の反映。** 指摘 4 件（**Blocker 2 / Major 1 / Medium 1**）の処遇 — **`0001` を第 10 版へ**（§8.3.1 / D-28 が旧 L1 モデルのままだった）／ **`0003` を第 15 版へ**（§10.6.1 の R1 手順が §4.3 の制御フローと矛盾していた ＋ §10.6.2 の `[要確認]` を確定させて閉じた）／ 本書 active 部分からの旧 L1 / L2 表現の除去。**X 番号は起こさない（判定は同書 §1）**。**さらに同日 2 回目のレビュー（改訂後のプランに対するもの・Blocker 0 / Major 3 / Minor 1）の反映を同書 §10 に記録した** — **A-2 の上位スコープ表を X-6 後の `ForRebuild` 仕様へ是正**（`0010` の撤回内容が上位表に未反映だった）／ **R0 先行の根拠から消滅した制約（C-01）を除去し、必須条件と決定を分離** ／ **申し送り 10 を `0003` 第 15 版基準へ** ／ **§3.3 の送り先列を R1 / R2 へ実置換**。**設計判断は動いていない**。**さらに 3 回目のレビュー（Approve・軽微修正推奨）の反映を同書 §11 に記録した** — **U-2 の理由を現在形へ** ／ **§6.4・§11 の旧 L1 / L2 表現の置換**（MO-19 / MO-22 の陳腐化した割当ても是正）／ **自己検証のステップ数 38 → 39 と発火件数 4 → 6 の是正** ／ **A-1 の残存リスクを実物確認により (a) suggest ドキュメント＝再構築で消える ／ (b) settings エントリ＝残る に分離（区分 II）** ／ **文末の読み順から撤回済みの §0.1 を外した** |
| **0013** | `0013-review-phase-a-a1-a2.md` | **外部レビュー（ステップ A-1 / A-2 の実施結果に対する独立検証・2026-09-01）。** **A-1 と A-2 を同時に、実装完了後の作業ツリー全体に対して見た通算 4 回目のレビュー。** 指摘 6 件（Medium 2 / Low 2 / Info 2）。**コードも設計書も変更していない**（逸脱手続きは発火していない — 同書 §5） |
| **0014** | `0014-review-response-phase-a.md` | **`0013` の反映（2026-09-01）。** 6 件すべてを妥当と判断（**指摘 4 だけは前提が成立しないことを実物で確認し、是正した形で反映**）。**コード変更は `(fess) helper/SuggestHelper.java` の 1 ファイルのみ**（指摘 3 = `storeOneElevateWordRow` の切り出し）。**設計書は無改訂（第 15 版のまま）・X 番号も起こさない**（判定は同書 §4）。**指摘 2 は A-3 への申し送りとした** |
| **0015** | `0015-assessment-a3-readiness.md` | **ステップ A-3 の着手可否判定（2026-09-02）。** **新しいステップではなく実装でもない。** 依存関係の充足確認、作業内容 7 項目の実施可否、**G1 の次世代件数が現行 API では取得できないことの検出（区分 I の逸脱として発火する見込み・未決 [要確認]）**、選択肢 3 案と推奨、作業内容 3 の実際の形、作業内容 5 が伴う判断。**コードも設計書も変更していない** |
| **0016** | `0016-deviation-x7-g1-next-generation-count.md` | **逸脱 X-7（区分 I・ステップ A-3）の記録（2026-09-04）。** **`0003` §4.2 の G1 が指定する `getAllWordsNum()` では次世代を数えられない**（検索エイリアスしか見ない）ため**設計どおり実装すると G1 が no-op になる**という欠陥に対し、**案 (a)（fess 側で更新エイリアスを直接数える）をユーザー決定で採用**し、**`0003` を第 16 版へ改訂して MO-27 を採番した**。**`modules/fess-suggest` は無変更（C-01）。本書の時点ではコード変更なし** — 実装は本書の記録後（プラン §2.1 の順序） |
| **0017** | `0017-review-response-a6.md` | **外部レビュー（ステップ A-6 の実施結果）の反映（2026-09-04）。** 指摘 3 件（**Major 2 / Low 1**）をすべて妥当と判断し是正 — **T-S1 を `create()` の実行検査へ**（構造検査のみでは完了条件を満たさない）／ **MO-27 に実行検査を新設**（更新エイリアスを数えることの回帰検知）／ **ソース検査のパス解決を作業ディレクトリ非依存へ**。**production は 2 ファイル（`create()` の可視性 ／ `countWordsInIndex` の切り出し）で、いずれも差し込み口。設計書は第 16 版のまま無改訂・X 番号も MO 番号も起こさない**（判定は同書 §4） |
| **0018** | `0018-review-phase-a-complete.md` | **外部レビュー（フェーズ A の全 5 ステップの実施結果に対する独立検証・2026-09-07）。** **A-1〜A-6 が揃った状態を一度に見た通算 6 回目のレビュー。** 指摘 5 件（**Medium 2 / Low 2 / Info 1**）。**コードも設計書も変更していない**（逸脱手続きは発火していない — 同書 §6） |
| **0019** | `0019-deviation-x8-remove-disable-indices-on-guard-failure.md` | **逸脱 X-8（区分 I）の記録（2026-09-07）。** **`0018` §2（指摘 1）で発火。** **MO-2 が不合格時の行動に「`removeDisableIndices()` を実行しない」を束ねており、同メソッドが担うもう 1 つの責務（孤児インデックスの回収。呼び出し元は `SuggestCreator` の 1 箇所のみ）を勘定に入れていなかった**ため、**ガードが不合格を返し続ける間は孤児が単調増加する**という欠陥に対し、**案 A（不合格時も実行する）をユーザー決定で採用**し、**`0003` を第 17 版へ改訂して §4.3.1 を新設した**（**新しい MO 番号は起こさない**）。**`SuggestAliasStateUnknownException` 経路との境界（T-S12）を明示した点が `0018` の提案より狭い。** **`modules/fess-suggest` は無変更（C-01）。本書の時点ではコード変更なし** — 実装は本書の記録後（§2.1 の順序） |
| **0020** | `0020-review-response-phase-a-complete.md` | **`0018` の反映（2026-09-07）。** 5 件すべてを妥当と判断して対応 — **指摘 1 = 逸脱 X-8**（`0019`）／ **指摘 2 = 生キー削除の失敗を昇格させない決定への回帰検知 3 件**（`0018` の提案 2 件に public 経路の 1 件を足した）／ **指摘 3 = 次世代件数の取得を G3 の後へ**（**X-8 の適用により体裁の問題ではなくなった** — 同書 §3.1）／ **指摘 4 = `suggester` フィールドの隠蔽解消** ／ **指摘 5 = `0007` §7 の記述訂正**。**`static canSwitchIndex(...)` の削除を伴う**（同書 §3.2） |
| 0021 | `0021-phase-b-api-spi-foundation.md` | フェーズ B（B-1 / B-2 / B-3 / **B-4a** / **B-4b** / B-5 / B-6 / B-7）。基盤型。**B-4b の機械的追従で赤くなったテストの一覧を必ず記録する** |
| 0022 | `0022-phase-c-datamodel.md` | フェーズ C（C-1〜C-5）。データモデル |
| 0023 | `0023-phase-d-internal.md` | フェーズ D（D-1〜D-8）。`internal` 実装 |
| 0024 | `0024-phase-e-facade-delegation.md` | フェーズ E（E-1〜E-4）。旧ファサード委譲 |
| 0025 | `0025-phase-f-test-verification.md` | フェーズ F（F-1〜F-5）。テストと最終検証 |

> **実装中に新たな逸脱が発生した場合は、その時点の最大番号 +1 で独立ファイルを作る**（`00NN-deviation-xN-*.md`）。フェーズのファイルに混ぜない。**この規則の適用により 0006 が逸脱 X-4 に割り当てられ、フェーズ A〜F の 6 ファイルは 0007〜0012 へ繰り下がった**（2026-08-31）。**さらに 0008 が A-1 のレビュー反映、0009 が逸脱 X-5 に割り当てられ、フェーズ B〜F の 5 ファイルは 0010〜0014 へ繰り下がった**（2026-08-31）。**さらに 0010 が A-2 のレビュー反映（＝逸脱 X-6）に割り当てられ、フェーズ B〜F の 5 ファイルは 0011〜0015 へ繰り下がった**（2026-08-31）。**さらに 0011 が要件定義の改訂（配布・運用モデルの確定）に割り当てられ、フェーズ B〜F の 5 ファイルは 0012〜0016 へ繰り下がった**（2026-08-31）。**さらに 0012 が `0011` に対する外部レビューの反映に割り当てられ、フェーズ B〜F の 5 ファイルは 0013〜0017 へ繰り下がった**（2026-08-31）。**さらに 0013 が A-1 / A-2 に対する 3 回目の外部レビュー、0014 がその反映に割り当てられ、フェーズ B〜F の 5 ファイルは 0015〜0019 へ繰り下がった**（2026-09-01）。**さらに 0015 が A-3 の着手可否判定に割り当てられ、フェーズ B〜F の 5 ファイルは 0016〜0020 へ繰り下がった**（2026-09-02）。**さらに 0016 が逸脱 X-7（A-3 の G1 の取得方法）に割り当てられ、フェーズ B〜F の 5 ファイルは 0017〜0021 へ繰り下がった**（2026-09-04）。**さらに 0017 が A-6 に対する外部レビューの反映に割り当てられ、フェーズ B〜F の 5 ファイルは 0018〜0022 へ繰り下がった**（2026-09-04）。**さらに 0018 がフェーズ A 全体に対する外部レビュー、0019 が逸脱 X-8、0020 がその反映に割り当てられ、フェーズ B〜F の 5 ファイルは 0021〜0025 へ繰り下がった**（2026-09-07）。**繰り下げの規則は逸脱に限らず、独立記録を要する事象すべてに適用する。****以後さらに逸脱・レビュー反映が発生した場合も同様に繰り下げる。**
>
> **[確認] `0007` §2.8 は「番号 `0010` は台帳でフェーズ B に割当て済みだった」ことを A-2 の記録を独立ファイルにしない理由の 1 つに挙げているが、その後 `0010` は本繰り下げにより A-2 のレビュー反映に再割当てされた。** **A-2 の実装記録が `0007` §2 に統合されているという結論は変わらない**（Q9=(B)「フェーズ単位で 1 ファイル」）。

### 9.2 設計書の改訂

| ファイル | 改訂内容 | 版 | ステップ |
| --- | --- | --- | --- |
| `docs/0001-api-design.md` | 同書 §3.9 / §8.1 #11 / D-28 の書き換え（`build()` の戻り値型） | **改訂時点の次版**（下記注意） | 0-2 |
| `docs/0003-migration-ops-design.md` | 同書 §10.5 のビルド前提・MO-9 / 同書 §8.2 の行番号・同書 §6.3 の OpenSearch バージョン ＋ **冒頭「現在の版」表記の是正** | **据え置き**（区分 II） | 0-3 |
| `docs/0000-design-overview.md` | 正本方針（Q7）の 1 行追記 | **据え置き**（区分 II） | 0-3 |
| `docs/0003-migration-ops-design.md` | **同書 §10 に L1 期間の節を新設** ／ **同書 §10.1 L813 の訂正**（「メジャー移行は L2 以降にしか起きない」は誤り） ／ **M-1 をリリース手順として追記** ／ **同書 §12 に K-19（M-5）を追加** ／ MO-22 の空振りを明記 ／ **M-6 の暫定手順・ロールバック手順・L2 での撤去方法を追記**（U-7 で採用決定） | **改訂時点の次版**（下記注意） | 0-4 |
| `docs/0002-datamodel-design.md` | 同書 §6.1 の共存範囲の限定 ／ 同書 §5.6 の前提の限定 ／ **同書 §5.2 に「W で回したが `reading_i` が存在しない」場合の扱いを定義** | **改訂時点の次版**（下記注意） | 0-4 |
| `docs/0002-datamodel-design.md` | **同書 §7.2 に T-24 を追加**（欠損 `reading_i` スロットの復元 — 0-4 で [確定] にした挙動の回帰が無かった）／ §5.2 の [確定] から T-24 への参照 | **第 10 版**（2026-08-31・実施済み） | **レビュー反映（`0005`）** |
| `docs/0003-migration-ops-design.md` | **同書 §10.3 の同一リリース制約を 3 項目から 4 項目へ拡張**（削除経路 `:431` / `:449` も同じ正規化を通す）／ **§10.3.1 を新設し MO-24 を採番**（add/delete の `_id` 対称性 ＋ 移行期の新旧両キー削除 ＋ 一般則「語テキストは入力であると同時に `_id` キーでもある」）／ **§10.3 の「delete も `addElevateWord` を通る」という記述の訂正** ／ §0 の決定表に MO-24 を追加。**MO-1〜MO-23・mapping・§11 のテスト仕様は無変更** | **第 10 版**（2026-08-31・実施済み） | **A-1**（実装中に発火した逸脱 X-4。記録は `0006`） |
| `docs/0003-migration-ops-design.md` | **同書 §10.3.1 (d) の規則 3（両キー削除の安全性の根拠）を全面的に書き直した。** 第 10 版の根拠は「削除は存在しない `_id` への no-op」に依っていたが、**`deleteElevateWord` は settings エントリの削除も伴う 2 段操作である**ことを数えていなかった。第 11 版は (i) その settings 削除が (c) の障害 3 が挙げた掃除対象そのものであること (ii) 生キーは正規化で落ちる空白を保持したままであり追加経路が書くキーと一致しえないこと (iii) settings 側もキー一括削除ではなく ID 指定の 1 件削除であること、を根拠として明示した。**MO-24 の規則 1・2・4／対象メソッド／検証の所在は不変。MO-1〜MO-23・§11 のテスト仕様も無変更** | **第 11 版**（2026-08-31・実施済み） | **A-1 のレビュー反映**（**X-4 の追補改訂・区分 I。新しい X 番号は起こさない**。記録は `0008`） |
| `docs/0003-migration-ops-design.md` | **同書 §10.4 を全面的に書き直し、表題を「全件再投入系メソッドの失敗隔離」に改めた** ／ **MO-25 を採番**（失敗隔離は `storeAll*` が駆動する**すべての行単位ループ**に適用する。**削除フェーズを含む**）／ **失敗件数の集計単位を「削除フェーズと追加フェーズの合算値 1 つ」と定義**（根拠は §4.2 の G3 が件数を 0 / 非 0 の二値としてしか使わないこと）／ **追加フェーズにも `SuggestItem` 化以外の失敗点があること**（`boost` のアンボクシング）の明記 ／ **`storeAllBadWords` の削除フェーズは行単位ループを持たないため対象外**という非対称の明記 ／ §0 の決定表に MO-25 を追加 ／ §4.2.2 の語管理経路の行に集計単位への参照を 1 文追加 ／ **§10.4 冒頭の `AdminBackupAction.java:157,238` を `:156,237` に訂正**（区分 II の付随訂正）。**MO-1〜MO-24・mapping・§11 のテスト仕様・§13 の 8 は無変更** | **第 12 版**（2026-08-31・実施済み） | **A-2**（着手時に発火した逸脱 X-5。記録は `0009`） |
| `docs/0003-migration-ops-design.md` | **同書 §10.4 (e) の MO-25 の規則 3 と規則 6 を是正した。** **規則 3**: 「削除フェーズと追加フェーズの合算＝項目処理数」→ **「失敗した行の数。行 ID（`getId()`）で dedupe し、同一行が両フェーズで落ちても 1 件と数える」**。第 12 版の根拠 (f) は 4 件のうち 1〜3 が「フェーズ別に 2 つ返す案」の否定にしか効かず、4 が**事実誤認**（突き合わせの鍵は `suggestWord` ではなく `getId()`）であった。**規則 6**: 「管理画面の 3 経路にも及ぶ。これは受け入れる」→ **「失敗隔離は再構築専用の内部経路（`storeAllElevateWordsForRebuild()` / `storeAllBadWordsForRebuild()`）に限定し、public 3 メソッドの挙動は fail-fast のまま変えない」**。**同期 4 経路で例外が `throwValidationError(Api)` として運用者に届いており、それが唯一の異常検知手段である**という点を第 12 版は評価していなかった。／ **(f) を「失敗件数の集計単位の根拠」として全面的に書き直した**（第 12 版の 4 根拠の再評価表を含む） ／ **(i)（失敗隔離を再構築経路に限定する根拠）と (j)（対象メソッドと A-2 / A-3 の担当範囲の境界）を新設** — **`(fess) exec/SuggestCreator.java:255` / `:258` の 2 行の切替は A-2 の担当であり、戻り値の `exitCode` 合流は A-3 の担当である**ことを明記 ／ (g) の検証を「1 以上」→「1（等値）」に是正し **4 点目（public が例外を伝播することの回帰検査）を追加** ／ §0 の決定表の MO-25 行と §4.2.2 の語管理経路の行を是正。**新しい MO 番号は起こさない**（MO-25 の改訂である）。**MO-1〜MO-24・mapping・§11 のテスト仕様・§13 の 8 は無変更。§10.4 の (a)〜(d) と節記号も無変更**（既存参照が壊れない） | **第 13 版**（2026-08-31・実施済み） | **A-2 のレビュー反映**（**逸脱 X-6・区分 I。新しい X 番号を起こす — 判定は `0010` §1.2**。記録は `0010`） |

| `docs/0003-migration-ops-design.md` | **配布・運用モデルの確定に伴うリリース段の組み替え。** §10.1 を R0 / R1 / R2 へ全面改訂（**MO-26** 新設）／ §10.6 を「R1 の停止中移行手順」へ全面改訂（**M-1 / M-6 を撤回**）／ §12 の **K-19 を解消済みに更新** ／ §4.2.3 の **MO-22 空振り記述を撤回** ／ §10 冒頭に用語の読み替え注記 ／ §10.3 に R0 / R1 の割当て | **第 14 版**（2026-08-31・実施済み） | **要件定義の改訂（`0011`）** |
| `docs/0002-datamodel-design.md` | **§5.2 の [確定]（欠損 `reading_i` スロットは空配列として復元する）の根拠を L1 期間から差し替え**（決定そのものは維持）／ §5.6 の前提の限定・§6.1 の共存範囲の限定・T-24 の参照先を同様に差し替え | **第 11 版**（2026-08-31・実施済み） | **要件定義の改訂（`0011`）** |
| `docs/0000-design-overview.md` | **C-01 の 4 段とリリース段の対応を注記**（第 1〜3 段が R1、第 4 段が R2。「fess 本体を無変更のまま本番稼働させる中間状態」は存在しない） | **据え置き**（注記のみ） | **要件定義の改訂（`0011`）** |
| `docs/0001-api-design.md` | **C-01 / D-28 の意味の更新。** §8.3.1 の維持対象を「fess 本体が L1 のまま動くこと」から**「R1 まで旧ファサードの public シグネチャを維持すること」**へ書き換え、理由を (a) Strangler の段階化 (b) 公開 artifact への 1 リリース猶予（U-9） (c) 開発・ビルド互換性 の 3 点に整理 ／ **「旧 fess 本体 ＋ 新 fess-suggest を本番稼働させることは要求しない」と明記** | **第 10 版**（2026-08-31・実施済み） | **レビュー反映（`0012`）** |
| `docs/0003-migration-ops-design.md` | **§10.6.1 を §4.3 の制御フローに合わせて書き直し**（ガードも切替も `SuggestCreator` の内側にある）／ **§10.6.1.1（採らなかった案）・§10.6.1.2（ガード不合格時）を新設** ／ **§10.6.2 の `[要確認]` を「サービス停止」の定義として確定** ／ §13 の 15・16 ／ §14 の V3 | **第 15 版**（2026-08-31・実施済み） | **レビュー反映（`0012`）** |
| `docs/0003-migration-ops-design.md` | **§0 の決定表に MO-27 を追加** ／ **§4.2 の G1 の取得方法欄を全面改訂**（新旧で見るエイリアスが異なる） ／ **§4.2 の「旧世代不在の初回」の判定条件を「旧件数 0」と明記**（エイリアスの存在検査を入れない） ／ **§4.2.4 を新設**（MO-27 の本体 — 成立しない事実 7 点・帰結 4 点・R0 / R1 の対処・却下 2 案・MO-1 と衝突しない根拠・代償・refresh 済みの確認） ／ **§4.3 の制御フロー図に G1 の取得先を追記し、行番号を A-2 適用後の現物へ是正**（区分 II の付随訂正） ／ **§10.1 の R0 / R1 差分表の G1 行と直後の注記を是正**（「R0 で現行 API を使うことは設計の妥協ではない」は次世代については成立しない） | **第 16 版**（2026-09-04・実施済み） | **A-3 の着手可否判定で発火**（**逸脱 X-7・区分 I。新しい X 番号と MO 番号（MO-27）を起こす — 判定は `0016` §4**。記録は `0016`） |
| `docs/0003-migration-ops-design.md` | **§10.1 の「唯一のリリース順序制約」の書き方を是正** — **(1) 技術的な必須条件（§10.3 の同一リリース制約）と (2) R0 を別リリースにする決定 を分離した。**「R0 を出し忘れたら R1 も出せない」という誤読を防ぐため | **第 15 版のまま**（段落追加のみ） | **レビュー反映（`0012` §10.2）** |
> **版番号を固定値で書かない**（外部レビュー指摘 6）。**理由は 2 つある。**
>
> 1. **0-2 と 0-4 の実施順が入れ替わると番号がずれる。** 両ステップは §5.2 で並行可としており、どちらが先に `0003` を触るかは実行時に決まる。**改訂するステップが、その時点の改訂履歴の最新版 +1 を採る。**
> 2. **設計書側に既存の不整合がある** [確認]。`0001` / `0002` / `0003` の 3 文書とも**冒頭が「現在の版: 第 7 版（2026-08-17）」のまま**だが、**改訂履歴には第 8 版の行がある**（2026-08-22 の閉包リファクタリング。`0000` §0.2 も「各文書の第 8 版」と述べている）。**冒頭表記が第 8 版への更新時に据え置かれた**ものであり、「第 9 版」という固定値はこの不整合の上に乗ってしまう。
>
> **したがって 0-2 / 0-4 の作業内容 0 に「改訂前に冒頭の『現在の版』と改訂履歴の最新版が一致しているか確認し、食い違っていれば先に冒頭表記を正す（区分 II）」を置いてある。**

**`agent_docs/tasks/20260706_design_document/docs/` の 5 本は一切変更しない**（Q7=(A)）。

### 9.3 コード成果物

| モジュール | ブランチ | 主な成果物 |
| --- | --- | --- |
| `modules/fess` | `feature/suggest-l1-precede` | `helper/SuggestHelper.java`（改変）／ `exec/SuggestCreator.java`（改変）／ 新規テスト 5 種 |
| `modules/fess-suggest` | `feature/suggest-l1` | `api/`（新規 20 型前後）／ `spi/`（新規 15 型前後）／ `internal/`（新規 10 クラス前後）／ `entity/` `index/` `request/` `settings/` `util/` `constants/` `concurrent/`（改変）／ リソース 5 ファイル（改変）／ 新規テスト 30 本以上 |

---

## 10. リスクと未解決事項

### 10.1 判断事項

#### 10.1.1 決定済み（2026-08-24）

> **プランの実行前に決める必要がある項目は無くなった。** 以下 4 件はユーザー決定済みで、本文に反映してある。**U-7 は外部レビュー（§12）の指摘 1 を受けた追加判断である。**
>
> **【2026-08-31】U-1 と U-7 は撤回した**（U-8 による）。**U-2 / U-3 は維持する。追加の決定 U-8 / U-9 / U-10 は §1.1 にある。**

| # | 事項 | 決定 | 反映先 |
| --- | --- | --- | --- |
| ~~**U-1**~~ | **【2026-08-31 撤回】**~~L1 リリース〜初回再構築の窓で、新 ID バイナリが旧世代インデックスへ書き込む問題（§7.2 の穴 1）~~ | ~~M-1 ＋ M-5 の併用~~ → **撤回**（U-8。窓が生じる区間が消滅した） | §7 の撤回ヘッダ ／ `0011` |
| **U-2** | `(fess res) suggest_indices/` の 3 ファイル（`suggest_analyzer.json` / `_aws/` / `_cloud/`）からの `number_of_replicas` 削除をどの段に置くか | **フェーズ A（R0）に置く。** **【2026-08-31 改訂】決定は不変だが理由を差し替えた** — 旧理由「`modules/fess` への変更であり C-01（L1 では fess 本体無変更）に抵触するため先行リリースに含める」は**その制約が消滅したため撤回**（R-P1 により R1 へ戻すことも可能）。**現在の理由は (1) `auto_expand_replicas` により実効挙動が変わらない**（`0003` §8.2 が実機確認済み）**(2) R0 で先に閉じれば DM-6（7 ファイル）の grep 検査が早く通る (3) A-6 に既にリソース回帰テストの作業内容がある**（`0011` §4） | **ステップ A-4** ／ §3.1 の L1-19 ／ §3.2 の P-05 ／ ステップ C-3（対象外に変更） |
| **U-3** | `SuggestIndexer` の setter 9 件を旧ファサードに残す際の挙動。`SuggestComponents` の不変性と両立しない（`0001` §8.2 L1829） | **no-op ＋ 警告ログ。** シグネチャ（fluent 形）を維持し `this` を返すが何も変更せず、`warn` で「無効化された。構成は `SuggesterBuilder` の構築時に指定すること」を出す | **ステップ E-3**（作業内容 7） |
| ~~**U-7**~~ | **【2026-08-31 撤回】**~~M-6（`.prev` 付与の暫定版をフェーズ A に先行させる）の採否~~ | ~~(a) 採用する~~ → **撤回**（U-8。**ステップ A-5 を削除**。R1 では正式 primitive を最初から使う） | §4 の A-5 削除ブロック ／ §7.5.1 ／ `0011` |

#### 10.1.2 該当ステップ着手時に判断する（既定線あり）

**いずれもプラン全体をブロックしない。** 該当ステップに着手するまでに決まればよい。**下表の [提案] を既定線とし、それで進められない事実が出た時点で判断する。**

| # | 事項 | 選択肢 | 着手ステップ | **既定線（本書の [提案]）** |
| --- | --- | --- | --- | --- |
| **U-4** | **`(sug res) suggest_indices/suggest.json` への `"_comment"` 追加が技術的に可能か。** OpenSearch の index settings に未知キーを送ると拒否されうる | (a) `suggest.json` に `"_comment"` を入れる（**要実機検証**） ／ (b) settings 本体の外に置ける形を探す ／ (c) README に退避する | **C-3** | **まず (a) を実機検証し、拒否されるなら (c)。** Q11 の主眼は (D) の assert テスト（A-6）であり、(A) は補助である |
| **U-5** | **`SuggestWordAdmin.addElevateWord(ElevateWord)` が `api` → `entity` の参照になる点。** `0001` §1 が定める依存方向は `spi` → `entity` → `api` であり、この 1 箇所が逆向きに見える | (a) 設計書の意図どおり（`entity` は `api` から参照可）と解釈して進む ／ (b) 区分 I の逸脱として `0001` §1 を改訂する ／ (c) `api` 側に elevate word の DTO を新設する | **B-6** | **まず `0001` §1 を精読して (a) で成立するか確かめ、判断できなければ (b)。** (c) は fess 本体が `ElevateWord` のコンストラクタに依存している [確認]（`(fess) helper/SuggestHelper.java:483-484`）ため L1 では採りにくい |
| **U-6** | **ステップ 0-1 の基準線で `mvn test` が赤い場合の扱い** | (a) 赤いテストを先に直す ／ (b) 一覧化して以降の DoD から除外する | **0-1** | **(b)。** 本タスクの変更に起因しない赤は本タスクのスコープ外。**ただし除外リストを作業履歴（`0004-phase-0-preparation.md`）に明記し、F-5 の最終検証でも同じリストを使う** |

### 10.2 リスク

| # | リスク | 影響 | 緩和 |
| --- | --- | --- | --- |
| **R-1** | **旧ファサードの互換性検証が「コンパイルが通る」以上のものを持たない**（§6.4）。fess 本体のテストは回帰検知能力ゼロ | **R1 リリース後に実挙動の回帰が本番で顕在化する** | フェーズ A で追加するテスト（A-6）を「一度赤くなること」まで確認する。`javap` によるシグネチャ diff（F-5）を必須にする。**限界をリリース判断に明記する**（DoD 12） |
| ~~**R-2**~~ | **【2026-08-31 撤回】**~~メジャー移行が L1 直後の最初の SuggestJob で起きる（§0.1 / §7.3）。G2 も `.prev` 保持も無い状態で mapping・ID 方式・格納形が一斉に変わる~~ | ~~サジェスト全体が壊れ、戻り先も無い~~ | **R-P1 によりこのリスクは消滅した。** **R1 ではメジャー移行が停止中に運用者の起動で走り、G1 / G2 / G3 と正式な `.prev` 保持が揃っている**（`0003` 第 14 版 §10.6.1） |
| **R-3** | **`SuggestItem` の改変が既存テストを「赤くする」ではなく test-compile 不能にする。** `new SuggestItem(` は **15 ファイル・146 箇所**、`new ElevateWord(` は 4 ファイルにある [確認] | 追従を後回しにすると **B-4b 以降 F-1 までモジュール全体のテスト実行が不能**になり、§6.1 の二段構えと §6.3 のルールがその区間で成立しない。`mvn test -Dtest='...'` でも回避できない（`-Dtest` は実行対象を絞るだけで test-compile は全件走る） | **B-4a（純粋な追加）/ B-4b（破壊的変更＋機械的追従）に分割し、B-4b の DoD を「`mvn test-compile` が通る」「`mvn test` が実行できる」にした。** 追従は**アサーションを変えない機械的置換に限定**し、意味的改修は F-1 に残す。§6.3 に「コンパイル不能」カテゴリを新設 |
| **R-4** | **`0001` §8 の「廃止」21 件を「旧ファサードから消す」と誤読すると C-01 が壊れる** | fess 本体が `indexer()`（11 箇所）/ `settings()`（6 箇所）でコンパイルエラーになる | E-2 / E-3 の注意点に明記済み。**読み替えを作業履歴にも書く**。B-2 / B-4b / B-5 / D-8 / E-2 / E-3 の各 DoD に「fess 側 `mvn compile`」を入れて早期検知する |
| **R-5** | **オーバーロード追加による曖昧化**（特に B-5 の時間設定 12 メソッド、`SuggestRequestBuilder.addRole` のメソッド参照 `builder::addRole`） | fess 本体がコンパイルエラーになる、または**呼び出し先が黙って変わる** | B-5 の DoD に fess 側コンパイルを入れる。**コンパイルだけでなく「呼び出し先が変わっていないか」まで確認する** |
| **R-6** | **`mvn test` の実行コストが高い**（51 クラス中 24 が in-JVM で OpenSearch ノードを起動、ポートバインドとローカル展開が必要） | ステップごとの検証が回らなくなり、まとめて検証する誘惑が生じる | §6.1 の二段構え。**新規テストはできる限り runner 不要側に置く**（§6.2） |
| **R-7** | **フェーズ A の変更を含めずに R1 を出すと、`storeAllElevateWords` 系が 1 件の不正データで再構築全体を落とす**（`0003` §10.4）。**【2026-08-31 是正】「R0 のリリースを飛ばすと起きる」ではない** — R0 を飛ばしてもフェーズ A の変更が R1 に入っていれば事故は起きない（§5.5） | 再構築が失敗し続け、サジェストが更新されなくなる | **DoD 11（フェーズ A の 5 ステップ完了）を R1 リリースの前提条件にする。** R0 として先に出す判断は §5.5 の表の 2 点による |
| **R-8** | **`(fess res)` 側 3 ファイルの `number_of_replicas` 削除（U-2）を忘れると DM-6 が未達になる** | `auto_expand_replicas` との併記が残り、C-14 の意図が果たされない。**ただし実害は小さい** [確認]（`0003` §8.2 が「`auto_expand_replicas` が設定されている場合 OpenSearch が `number_of_replicas` を上書きするため、既存の `number_of_replicas: 0` は一度も効いていない」と実機確認済み） | **A-4（fess 本体側 3 ファイル）と C-3（fess-suggest 側 4 ファイル）の両方が揃って初めて DM-6 が達成される。** A-6 と F-4 のリソース回帰テストで両側を守る |
| **R-9** | **設計書の改訂（0-2 / 0-3 / 0-4）を後回しにして実装を先に進める誘惑** | 逸脱手続きの規律が崩れ、「なぜこう実装したか」が追えなくなる | §2.4 の git 運用（改訂を実装より前のコミットにする）。**0-2 は D-8 の、0-4 は C-1 の明示的な前提条件にしてある** |
| **R-10** | **`0002` §7.1 の「変えない」テストを、通すために緩めてしまう** | 本設計が強化するはずの不変条件（特に `test_getId_sameTextSameId` 系）が検査されなくなる | §6.3 のルール 3。F-1 の DoD に「変えない行が実際に変わっていないことの確認」を入れてある |

### 10.3 本タスクのスコープ外（後続への申し送り）

| # | 事項 | 送り先 |
| --- | --- | --- |
| 1 | `0003` §13 の 3（JobLog の可観測性 / K-14）・4（再構築中断の自動検知 / K-13 / MO-16）・6（最小 OpenSearch 要件の文書反映）・8（backup 復元経路のバリデーション）・11（クエリ語数分布の取得 / OB-3） | 後続タスク |
| 2 | `0003` §13 の 5（実測依存項目 a〜e。G1 の割合下限・`docPerReq`・`refresh_interval`・`waitController` の位置・`scroll.size`） | 性能実測タスク（C-04） |
| 3 | `0003` §13 の 12（メジャー移行の指定方法）・13（自動採取の実装位置）・14（除外語物理削除の運用導線）・9（`FessConfig` 8 箇所） | **後続タスク**（いずれも fess 本体側 ＝ R1 の構成要素）。**【2026-08-31】12・13（G2 の fess 側実装）は R1 の必須項目である** — `0003` 第 14 版 §4.2.3 が「R1 では G2 が最初のメジャー移行から効く」と定めたため |
| 4 | K-1（楽観ロック）／ MIG-15 第 2 段（`scripted_upsert`） | `0001` D-31 が「その段で改めて設計する」 |
| 5 | K-2（`roles` への `_guest_` 混入）の**リリース判断**。`0000` §9C.4 が「メジャー版のリリース時に『この挙動を維持する』と明示的に判断する」と定めている。**「既知の制約だから後で」で流さないこと** | **R1 のリリース判断**（コードは変えないが判断は要る） |
| 6 | `Suggester.builder()` のタイポ `contentsReadigConverter`（`(sug) SuggesterBuilder.java:98`）の修正 | **R2**（public API の変更になるため） |
| 7 | `SuggestItem.Kind` の除去（B-2 で `@Deprecated` として残す） | **R2** |
| 8 | 既存 `(fess test) helper/SuggestHelperTest.java` の握り潰し構造の作り直し（T-F1） | **後続タスク**（`0003` MO-13 が「補強ではなく新規作成」と明記） |
| 9 | `knn_vector`（`0003` §9） | Phase 4 |
| **10** | **R1 のリリース手順書** — **`0003` 第 15 版 §10.6 の確定済み手順を、具体的な運用手順へ落とす。** **設計として決着済みであり後続タスクで蒸し返さないこと**: (a) **手順は §10.6.1 の 9 手順**（**手順 4 は SuggestJob の 1 回起動であり、G1 / G2 / G3 と切替はその内側で走る** — §10.6.1.1 の分割案は却下済み）、(b) **「サービス停止」＝ fess のプロセスは稼働させたまま外部ユーザーアクセスと crawler を遮断する**（§10.6.2 で (a) を採用済み）。**後続タスクが決めるのは、環境依存の遮断手順（LB / リバースプロキシの設定・crawler ジョブの停止操作）と、ジョブ結果の判定手段（§2.3）・ガード不合格時の再実行手順（§10.6.1.2）の手順書への落とし込みである**（`0003` 第 15 版 §13 の 15・16） | **後続タスク**（R1） |
| **11** | **fess 本体 main 4 クラスの新 API 切り替え**（旧 L2。`0001` §9） | **後続タスク**（R1） |

---

## 11. 自己検証

| # | 検証項目 | 結果 |
| --- | --- | --- |
| 1 | **【2026-08-31 改訂】要件定義のゴール（第 2 版 §4 の 4 到達点）がカバーされているか** | ✅ 到達点 1（R0 が出せる）→ フェーズ A（A-5 を除く 5 ステップ）。到達点 2・3（fess-suggest 側の実装と旧ファサードの委譲）→ §3.1 の L1-01〜L1-40 とフェーズ B〜F。到達点 4（`modules/fess` を無変更でビルドできる）→ DoD 5 / 6（F-5）。**旧ゴール「L1 を実施可能な状態」との差は、リリース段の呼称と「fess 本体を無変更のまま本番稼働させる」という運用要件の削除だけであり、実装スコープは変わっていない** |
| 2 | **`0001` の D-1〜D-33 が全件カバーされているか** | ✅ D-1〜D-33 のうち、**本タスク（R1 で出す fess-suggest 側）に属するもの**は §3.1 の L1-01〜L1-40 に対応付けた。**D-14（fess 本体 5 ファイル）と D-22（fess 側の `hasFailures()` 読み替え）は **R1 の後続タスク****（§3.3 の N-01）。**D-28 は E-4 で文書化**。**D-31 / D-32 / D-33 は L1** |
| 3 | **`0002` の DM-1〜DM-21 が全件カバーされているか** | ✅ DM-1（不変条件への集約）→ C-2、DM-2/3 → C-3、DM-4 → C-2、DM-5（`text` は `keyword` のまま）→ C-3（変更しないことの確認）、DM-6/7 → C-3、DM-8/9 → C-1、DM-10/11 → C-4、DM-12 → C-2、DM-13 → C-4、DM-14 → C-5、DM-15 → §7（中間状態の論点）、DM-16 → C-1 / D-5、DM-17（切り捨ての観測項目）→ F-2 の T-16、DM-18/19 → D-3 / C-4、DM-20 → D-3、DM-21 → C-4 / D-3 / D-5 |
| 4 | **`0003` の MO-1〜MO-27 が全件処理されているか** | ✅ MO-1（高水準 API を置かない）→ A-3 / D-6 の注意点、MO-2 → A-3、MO-3 → A-3、MO-4 → D-2、MO-5 → D-2、MO-6 → §7、MO-7/8 → D-7 / D-2、MO-9 → 0-3（行番号訂正）＋ **R1 の後続タスク**（N-02）、MO-10 → B-5（API 引数経路）、MO-11 → スコープ外、MO-12 → §5.5、MO-13 → §6.4 / A-6、MO-14/15/16 → §10.3、MO-17 → D-2、MO-18 → A-3、MO-19（ロールバック時の更新エイリアスの扱い）→ **`0003` §5.3 の R4 ／ D-2**（**【2026-08-31 是正】旧記述の「§7（穴 1 の根拠）」は撤回済みの節を指していた**）、MO-20/21 → D-2、MO-22 → **R1 の後続タスク（G2 の fess 側実装。N-03）**（**【2026-08-31 是正】旧記述の「L1 直後の移行で空振りする」は `0003` 第 14 版で撤回された。R1 では G2 が最初のメジャー移行から必須である**）、MO-23 → §10.3、**MO-24 → A-1（実装中に発火した逸脱 X-4。`0003` 第 10 版で採番）** ／ **【2026-08-31 追記】MO-24 → A-1（実施済み）、MO-25 → A-2（実施済み）＋ A-3（`exitCode` 合流）、MO-26（R1 は停止中に更新・再構築・検証・切替まで完了させる）→ 本タスクのスコープ外（R1 の運用手順書 ＝ 後続タスク）** ／ **【2026-09-04 追記】MO-27（G1 の次世代件数は更新エイリアスに対して数える）→ A-3**（A-3 の着手可否判定で発火した逸脱 X-7。`0003` 第 16 版で採番。記録は `0016`） |
| 5 | **ステップが MECE か** | ✅ **39 ステップ**に重複なし（**【2026-08-31 是正】A-5 の削除後の実数。フェーズ 0 = 4 ／ A = 5 ／ B = 8 ／ C = 5 ／ D = 8 ／ E = 4 ／ F = 5**。§4 の「7 フェーズ・39 ステップ」と一致する）。フェーズ間の境界は「宣言（B）／データモデル（C）／実装（D）／委譲（E）／検証（F）」で切っており、同一ファイルを複数フェーズで触る場合は各ステップの作業内容で担当範囲を明示した（例: `SuggestItem.java` は B-4b / C-1 / C-2 / C-4 で触るが、それぞれ「型の形」「ID 生成」「不変条件」「マージ」と担当が分かれる） |
| 6 | **依存関係に循環がないか／検証手段が成立するか** | ✅ §5.4 で確認。**F-5 の `javap` diff は素の `javap` を使う**（`-v` を付けると `Deprecated` 属性が全メンバの差分になり無意味化する — 実挙動を確認済み [確認]）。唯一の注意点（D-8 ↔ E-2）は一方向であることを E-2 の DoD で検査する |
| 7 | **各ステップが 1 セッションで完結する粒度か** | ⚠️ **B-4 は外部レビュー（指摘 2）を受けて B-4a / B-4b に分割済み。** 残る大きいステップは **B-4b**（15 ファイル・146 箇所の機械的追従）と **D-6**（`api` 4 IF の実装）である。B-4b は機械的作業なので 1 セッションで完結しうるが、**D-6 は実装時にさらなる分割が必要になる可能性がある。分割する場合は本プランを改訂する** |
| 8 | **逸脱手続きが機能する形になっているか** | ✅ §2.1 で区分 I / II を定義し、**§2.2 で発火 7 件（X-1〜X-7）を特定**（**【2026-08-31 是正】「4 件」は X-5 / X-6 の発火前の数である。【2026-09-04 是正】「6 件」は X-7 の発火前の数である**）、§9.1 で独立ファイルを割り当て、§5.2 で 0-2 → D-8 / 0-4 → C-1 のブロック関係を明示した。**実装中発火（X-4・A-1）でも同じ手続きが機能した**（改訂 → 記録 → 実装の順で、`0003` 第 10 版 ＋ 作業履歴 `0006` を実装前に作成した） |
| 8b | **外部レビュー指摘が処理されているか** | ✅ §12 に指摘 1〜6 の採否・理由・反映先を記録した。**採用 5 件・不採用 1 件（前提が誤り。ただし予防的手当てを実施）** |
| 9 | **判断事項が整理されているか** | ✅ §10.1.1 に決定済み（U-1 / U-2 / U-3 / U-7・2026-08-24。**うち U-1 / U-7 は 2026-08-31 に撤回**）、**§1.1 に U-8 / U-9 / U-10（2026-08-31 の配布・運用モデル確定）**、§10.1.2 に着手時判断 3 件（U-4 / U-5 / U-6）を既定線つきで分離した |

---

## 12. 外部レビューの反映（第 1 回・2026-08-24）

**設計書群が持つ外部レビュー反映の規律（`0000` §9 / §9A / §9B / §9C）に倣い、本プランに対するレビュー指摘の処遇を記録する。**

### 12.1 反映結果

| # | 指摘 | 判定 | 理由 | 反映先 |
| --- | --- | --- | --- | --- |
| **1** | §7.5 の緩和策表（M-1〜M-5）は**すべて穴 1（汚染の窓）への対処**であり、**R-2 の本体である「メジャー移行が `.prev` 保持なしで走る ＝ 切り替わった後の戻り先が無い」への対処が検討表に無い** | **採用（M-6 として追加。U-7 で (a) 採用が決定）** | 主張は正しい [確認]。`0003` §3.2（L269）が「第 3 版までは `.prev` 付与を fess 側で `SearchEngineClient` を用いて行う 2 リクエスト 2 段構成だった」と述べ、同 §5.1（L497）が「**削除判定のロジックが無変更である**という点は変わらない」と明記している。**`.prev` 付与を fess 側 alias 操作で先行させることは技術的に可能なまま**である。設計がこの選択肢を落としたのは「メジャー移行は L2 以降」という **§7.3 で誤りと判明した前提**の下で `.prev` 先行が nice-to-have だったからであり、§0.1 の発見がこの前提を覆した | **§7.5 に M-6 を追加**（長所・短所を `0003` L269 / L497 の根拠付きで記載） ／ **§7.5.1 を新設**（[提案] と推奨理由 4 点、採用時の A-5 / P-08、不採用時の記載義務） ／ **U-7 として起票し (a) 採用が決定**（2026-08-24 ／ §10.1.1） ／ **ステップ A-5 を新設**（`.prev` 暫定実装・付け替え規則・**無条件リトライ禁止**（`0003` L287）・ロールバック手順・**L2 での撤去箇所一覧**） ／ **A-6 の作業内容 7 に `.prev` の検証 4 項目**（T-S4 / T-S5 / T-R1 の先行版相当） ／ **§3.2 に P-08** ／ **ステップ 0-4 に作業内容 5b** ／ **§10.2 の R-2 を全面書き換え**（予防と回復を分け、**M-1 は穴 1 への対処であって R-2 の本体には効かない**ことを明示） ／ §4 のフェーズ表・§5.1 の依存グラフ・§8 の DoD 11・§9.1 |
| **2** | B-4 は既存テストを「赤くする」のではなく **test-compile 不能**にする。`mvn test -Dtest='...'` でも回避できない | **採用（指摘より範囲が広い）** | 主張は正しく、**プランの記載は範囲を過小評価していた** [確認]。`new SuggestItem(` は **15 ファイル・146 箇所**（プランは 3 ファイルしか挙げていなかった）、`new ElevateWord(` は 4 ファイル。`-Dtest` は**実行対象を絞るだけで test-compile は全件走る**ため、追従を後回しにすると **B-4b 以降 F-1 までモジュール全体のテスト実行が不能**になり、§6.1 の二段構えと §6.3 のルールがその区間で成立しない | **B-4 を B-4a（純粋な追加）/ B-4b（破壊的変更＋機械的追従）に分割** ／ **B-4b の DoD を `mvn -q compile` → `mvn -q test-compile` に変更**し「`mvn test` が実行できること」を追加 ／ **15 ファイルの全件を B-4b の注意点に明記** ／ **§6.3 を「テストが壊れる 2 つの様態」に再構成**し (I) コンパイル不能 / (II) 赤 を分離、**ルール 5〜8 を新設**（「test-compile を壊す変更は同じステップ内で機械的追従まで行う。赤いまま次へ進んでよいのはテストが*実行できる*場合に限る」） ／ **F-1 の範囲を「意味的な改修」に限定** ／ **R-3 を書き換え** ／ §5.1 / §5.2 / §8 の DoD 1b / §9.1 / §11 |
| **3** | ステップ内番号の重複（A-6 に「6.」が 2 つ、E-3 に「7.」が 2 つ） | **採用** | 実在 [確認] | **A-6 の 2 つ目を「7.」に、E-3 の 2 つ目を「8.」に採番し直した。** A-6 の DoD 文言（「上記 6 種」）も整合させた |
| **4** | A-3 のガード判定に**テスト用の切れ目が無く**、A-6 の T-S1 / T-S2 相当テストが書けない | **採用** | 正しい [確認]。`(fess) exec/SuggestCreator.java:243` は **`private int create()`** で `ComponentUtil.getSuggestHelper()` を静的に取得する一枚岩であり、DI の差し込み口が無い | **A-3 の作業内容 7 を新設**（ガード判定部を package-private メソッドへ切り出す軽微なリファクタリング。切り出す単位・`create()` のシグネチャは変えないことを明記） ／ **`0003` MO-1 と矛盾しない根拠**を `0003` §4（L457）の「fess 側に置くと決めているのは判定と順序制御」で示した ／ **A-6 の作業内容 3 に前提として参照**させた |
| **5** | `@Deprecated` がクラスファイルに現れるため `javap` の素朴な diff は全メンバで差分を出す | **不採用（前提が誤り）＋ 予防的手当て** | **成立しない** [確認]。**素の `javap` はアノテーションを出力しない** — `@Deprecated` を付けたメソッドも `public void a();` としか出力されず、`Deprecated: true` は **`-v` を付けた場合のみ**現れる。本プラン F-5 の記述は「[提案] `javap` で L1 前後の public シグネチャを出力して diff する」であり**素の `javap`** を指すため、問題は起きない。**ただし将来 `-v` を足したくなる読み手を止める必要はある** | **F-5 の作業内容 5 に「`javap -v` は使わない」を理由付きで明記**（`-v` は `Deprecated` 属性・定数プール・行番号表を出力し、フェーズ E で全メンバに `@Deprecated` を付ける本プランでは差分が全メンバに出て diff が無意味になる）＋ **具体的な取得手順を追加** ／ **§11 の自己検証 6 にも同旨を追記** |
| **6** | §9.2 で 0001 / 0002 / 0003 が揃って「第 9 版」になるが、0-2 と 0-4 の実施順が入れ替わると版番号がずれる | **採用（設計書側に既存の不整合あり）** | 主張は妥当で、**さらに「第 9 版」という固定値の前提自体が怪しい** [確認]。`0001` / `0002` / `0003` の 3 文書とも**冒頭が「現在の版: 第 7 版（2026-08-17）」のまま**だが、**改訂履歴には第 8 版の行がある**（`0000` §0.2 も「各文書の第 8 版」と述べている）。**冒頭表記が第 8 版への更新時に据え置かれた**ものである | **§9.2 の版番号を「改訂時点の次版」という相対表記に改め**、固定値を廃した ／ **注意書きで理由 2 点（実施順の入替・既存の不整合）を明示** ／ **0-2 / 0-4 の作業内容に「0.」を新設**し、「改訂前に冒頭の『現在の版』と改訂履歴の最新版が一致しているか確認し、食い違っていれば先に冒頭表記を正す（区分 II）」を置いた ／ **§7.6 の末尾に観察として 1 行記録** |

### 12.2 判定の内訳

**採用 5 件 ／ 不採用 1 件（指摘 5・前提が誤り。ただし予防的手当てを実施）。**

- **指摘 1 と 2 は本プランの構造を変えた。** 指摘 1 は §7.5 の緩和策表が**穴 1 だけを見ていた**という設計上の見落としを突いており、指摘 2 は**「テストが壊れる」を 1 種類だと思っていた**という検証方針の欠陥を突いている。いずれも新しいステップを生んだ — 指摘 1 は **A-5**（U-7 で採用決定）、指摘 2 は **B-4a / B-4b** である。
- **指摘 3・4・6 は記述の精度の問題**であり、方針は変わらない。
- **指摘 5 は不採用だが、指摘が想定した失敗（`javap` diff が無意味になる）自体は `-v` を付ければ現実に起こる。** 前提が誤っていても**注意喚起としての価値がある**ため、F-5 に禁止事項として明記した。

### 12.3 レビューが当てた共通の型

> **指摘 1 と 2 はどちらも「本プランが前提を 1 つに絞りすぎていた」ことに起因する。**

| # | 絞りすぎた前提 | 実際 |
| --- | --- | --- |
| 1 | 「L1 中間状態の問題 ＝ 汚染の窓（穴 1）」 | **R-2 には「予防」と「回復」の 2 面があり、M-1〜M-5 は予防にしか効かない** |
| 2 | 「テストが壊れる ＝ 赤くなる」 | **コンパイル不能という、赤より上流で全体を止める様態がある** |

**§7.6 が記録した「L1 という中間状態を設計書が詰めきれていない」という型と同じく、本プランも「中間の状態」を単純化していた。** 実装中に同種の単純化を見つけたら、§2.1 の逸脱手続き（区分 I）または本節への追記で処理すること。

---

## 13. 外部レビューの反映（第 2 回・2026-08-31 — **フェーズ 0 の作業記録に対するもの**）

**レビュー対象は本プランではなく、フェーズ 0 の作業記録 3 本（`0002` / `0003` / `0004`）である。判定は「条件付き Approve」— フェーズ A / B と C-1 は進めてよい。** 反映の全記録は作業履歴 `0005-review-response-phase0.md` にある。

### 13.1 反映結果

| # | 指摘 | 重み | 判定 | 反映先 |
| --- | --- | --- | --- | --- |
| **1** | **0-4 で [確定] にした「欠損 `reading_i` → 空配列」に対応するテスト仕様が無い。** `0003` §11 の 1 は「C-2 か F-2 で追加し、そのとき `0002` に T 番号を起こす」と申し送っているが、**0-4 はそもそも「実装前に設計上の未定義状態を消す」ための逸脱処理であり、後回しにすると目的が半分残る** | **重要** | **採用** | **`0002` を第 10 版に改訂し §7.2 に T-24 を新設**（逸脱 X-3 の追補・区分 I）／ §5.2 の [確定] から T-24 への参照 ／ **C-2 の作業内容 4b と DoD に T-24** ／ **F-2 を T-1〜T-24 に拡張** ／ **§8 の DoD 3** ／ `0003` §11 の 1 を解消済みに更新 |
| **2** | **OpenSearch 3.8.0 の未検証 3 点を「食い違ったら疑う」ではなく実装前ゲートにすべき。** C-3 の前に mapping/settings 系 2 点、D-1 の前に realtime GET | **重要** | **採用** | **C-3 に着手前ゲート G-OS1**（`strict_allow_templates` / `total_fields` の緩和機構の不在）／ **D-1 に着手前ゲート G-OS2**（`GetRequest` の `realtime` 既定値）／ **§8 の DoD 14** ／ `0004` §2.8 の 2 をゲート指定に書き換え。**C-1 / C-2 は止めない** |
| **3** | **M-1 の「リリースチェックリスト」が成果物として宙に浮いている。** `0003` §11 の 4 は E-4 で作ることを「推奨」に留めているが、**K-19 自身が「実効性の担保はチェックリストへの記載のみ」と認めている以上、推奨では弱い** | **中** | **採用** | **E-4 の対象に `L1-release-checklist.md`（新規）を追加**し、**作業内容 3b と DoD に必須 4 項目**（フェーズ A の本番投入 ／ **M-1** ／ G2 スモーク ／ 語数増の周知）／ **F-5 の作業内容 6 と DoD に「M-1 が【必須】項目として存在すること」の確認**／ **§8 の DoD 13** ／ `0003` §11 の 4 を更新 |
| **4** | **`mvn -o compile` の扱いがプランと作業記録で食い違ったまま。** `0004` §1.4 の 2 は「以降 `-o` を前提にしない」とする一方、**F-5 は明示的に `mvn -o compile` ＋ `mvn -o test` を要求している** | **中** | **採用（実測して解消）** | **`modules/fess` で `mvn -o compile` を再実行し EXIT=0 / BUILD SUCCESS（40.5 秒）を実測した**（2026-08-31・`0005` §5）。**0-1 の失敗はオンライン取得前だったことが原因と確定した。** `0004` §1.4 の 2 と §1.5 を実測値で更新 ／ **F-5 の作業内容 3 に「`-o` は再現性のための既定であり、DoD は『ビルドが成功すること』であって『オフラインで成功すること』ではない」を明記** |
| **5** | **`0004` の「フェーズ F まで `688 / 0 / 0 / 0` を維持すべき」は誤り。** §6.3.1 は **B〜E で `0002` §7.1 の「意図的に変える」テストが赤くなることを正常とし、F-1 まで直さない**と定めている | 軽微 | **採用** | `0004` §1.3 (3) と §1.6 の 1 を**「着手前基準線」＋「B〜E での失敗は `0002` §7.1 の『意図的に変える』集合に限定されることを確認する」**に書き換え |
| **6** | **`0002`（逸脱 X-1）のタイトルが紛らわしい。** `Suggester.builder()` 自体の戻り値は `SuggesterBuilder` であり、壊れるのは **`SuggesterBuilder.build(...)` の戻り値**である（本文はそこを正しく整理できている） | 軽微 | **採用** | `0002-deviation-x1-builder-return-type.md` の**文書内タイトルを「逸脱 X-1 — `SuggesterBuilder.build(...)` の戻り値型」に変更**（**ファイル名は §9.1 の割当てを保つため変更しない**）／ 本プラン §2.2 の X-1 行・**ステップ 0-2 の見出し**・§7.6 の「共通の型」も同じ呼称に是正 |

### 13.2 判定の内訳

**採用 6 件 ／ 不採用 0 件。**

- **指摘 1 と 3 は同じ型である** — **「0-4 で決めたことの実効性を担保する成果物が、どちらも『後で誰かが作る』に委ねられていた」。** 指摘 1 は T-24（設計上の [確定] を検査するテスト）、指摘 3 はリリースチェックリスト（運用手順 M-1 の唯一の担保）。**いずれも申し送りから DoD へ格上げした。**
- **指摘 2 は「未検証であることの記録」と「未検証のまま進む」の区別を突いている。** `0004` §2.4 が 3.7.0 の検証記録を書き換えなかった判断自体は正しく、レビューもそこは是としている。**足りなかったのは、その未検証をいつ閉じるかの指定である。**
- **指摘 4 は実測 1 回で閉じた。** プランと作業記録の食い違いは、**実測で片方が正しいと分かればそれで終わる**類のものだった。
- **指摘 5 / 6 は記述の精度の問題**であり、方針は変わらない。

### 13.3 レビューが当てた共通の型

> **§12.3 が記録した「前提を 1 つに絞りすぎていた」とは別の型である。今回は「決めたが、閉じ方を指定しなかった」。**

| # | 決めたこと | 閉じ方が未指定だったもの |
| --- | --- | --- |
| 1 | 欠損 `reading_i` ＝ 空配列（`0002` §5.2 の [確定]） | **それを検査するテスト**（→ T-24） |
| 2 | 3.7.0 の検証記録は書き換えない（`0004` §2.4） | **3.8.0 でいつ再検証するか**（→ G-OS1 / G-OS2） |
| 3 | M-1 をリリース手順にする（`0003` §10.6.3） | **手順を載せるチェックリストを誰が作るか**（→ E-4 の DoD） |

**[確定] や [提案] を書いたら、それが実装・検証・運用のどこで閉じるかを同時に指定すること。** **申し送りに「C-2 か F-2 で」「E-4 で作ることを推奨」と書いた時点で、閉じ方は指定されていない。**


---

> **本プランは確定版である（2026-08-24。第 2 回レビューの反映は 2026-08-31）。** Q1〜Q12 および U-1 / U-2 / U-3 / U-7 はすべてユーザー決定済みで本文に反映してある。**実行前に決めるべき項目は残っていない。**
>
> **実装中発火の逸脱 X-4（2026-08-31・区分 I・ステップ A-1）を反映した。** `docs/0003-migration-ops-design.md` を**第 10 版**に改訂して **MO-24** を採番し、§2.2 / ステップ A-1 / §8 の DoD 15 / §9.1 / §9.2 / §11 を更新した。**§9.1 の作業履歴は 0006 が逸脱 X-4 に割り当てられ、フェーズ A〜F は 0007〜0012 へ繰り下がっている。** 記録は `0006-deviation-x4-elevate-word-id-symmetry.md`。

> **着手時発火の逸脱 X-5（2026-08-31・区分 I・ステップ A-2）を反映した。** `docs/0003-migration-ops-design.md` を**第 12 版**に改訂して **MO-25** を採番し、§2.2 ／ ステップ A-2 ／ ステップ A-6 ／ §8 の DoD 10・**DoD 16** ／ §9.1 ／ §9.2 を更新した。**§9.1 の作業履歴は 0008 が A-1 レビュー反映、0009 が逸脱 X-5 に割り当てられ、フェーズ B〜F は 0010〜0014 へ繰り下がっている。** 記録は `0009-deviation-x5-store-all-delete-phase.md`。**なお本注記が書いていた「失敗件数は等値ではなく『1 以上』で検査する」は、下の X-6 により撤回されている。**

> **A-2 の実装に対する外部レビューで発火した逸脱 X-6（2026-08-31・区分 I・ステップ A-2）を反映した。** `docs/0003-migration-ops-design.md` を**第 13 版**に改訂して **MO-25 の規則 3（集計単位）と規則 6（適用範囲）を是正**し（**新しい MO 番号は起こさない**）、§2.2（**発火 6 件**）／ ステップ A-2（**対象に `(fess) exec/SuggestCreator.java` の 2 行を追加。作業内容 9 項・DoD 10 項**）／ ステップ A-3（作業内容 5）／ ステップ A-6（作業内容 2 と DoD — **失敗件数は「1 以上」ではなく「1」（等値）で検査する。public が例外を伝播することの回帰検査を追加**）／ §8 の DoD 10・**DoD 16** ／ §9.1 ／ §9.2 を更新した。**§9.1 の作業履歴は 0010 が A-2 レビュー反映（＝逸脱 X-6）に割り当てられ、フェーズ B〜F は 0011〜0015 へ繰り下がっている。** 記録は `0010-review-response-a2.md`。

> **【2026-08-31】上記 X-6 の反映後の実装に対する 2 回目の外部レビュー（Approve・軽微修正推奨）を反映した。** **本プランの改訂は本注記の追加のみである。** 是正したのは `(fess) helper/SuggestHelper.java` の **Javadoc 3 ブロック**（`storeAllElevateWords` / `deleteAllElevateWord` / `storeAllBadWords`）だけで、**実行文は 0 行・設計判断は 1 つも変わっていない。** **したがって `docs/0003-migration-ops-design.md` は第 13 版のまま無改訂であり、新しい X 番号も MO 番号も起こさない**（区分の判定は `0010` §13.5）。**ステップ A-2 / A-6 の本文も無変更である** — レビュアーが指摘した「プランが古い形のまま」は**改訂前のプランを参照したことによるものであり、現行の記述（`:443-446` / `:467` / `:470` / `:586-592`）は既に第 13 版を反映している**（`0010` §13.2）[確認]。**A-3 は `ForRebuild` の戻り値を必ず `exitCode` へ合流させること**（同レビューの指摘 3。`0010` §13.4）。記録は `0010-review-response-a2.md` **§13** ／ `0007-phase-a-fess-precede.md` §2。

> **【2026-09-04】A-3 の着手可否判定で発火した逸脱 X-7（区分 I・ステップ A-3）を反映した。** **`0015` §3 が検出し `[要確認]` として残していた「G1 の次世代件数が現行 API では取得できない」に対し、ユーザーが案 (a)（fess 側で更新エイリアスを直接数える）を採ることを決定した。** `docs/0003-migration-ops-design.md` を**第 16 版**に改訂して **MO-27 を採番**し（§0 の決定表 ／ §4.2 の G1 行 ／ **§4.2.4 を新設** ／ §4.3 の制御フロー図 ／ §10.1 の R0 / R1 差分表と直後の注記）、本プランの §2.2（**発火 7 件**）／ ステップ A-3（**対象に `(fess) helper/SuggestHelper.java` を追加。作業内容 2 の `[要確認]` を解消。作業内容 5 に生キー削除の判断を追記。DoD 6 項**）／ §8 の DoD 10 ／ §9.1 ／ §9.2 ／ §10 の点検 4・8 を更新した。**§9.1 の作業履歴は 0016 が逸脱 X-7 に割り当てられ、フェーズ B〜F は 0017〜0021 へ繰り下がっている。** **あわせて A-3 の中で `0007` §2.11 の 11（生キー削除の失敗を世代切替の阻止へ昇格させるか）を「昇格させない」と決定した** — **`0003` の改訂は不要**（`0016` §6 の 1）。記録は `0016-deviation-x7-g1-next-generation-count.md` ／ 実装の記録は `0007-phase-a-fess-precede.md` §3。

> **【2026-09-04】ステップ A-6（**R0** 分のテスト）が完了し、フェーズ A の全 5 ステップ（A-1 / A-2 / A-3 / A-4 / A-6）が揃った。R0 をリリースできる状態である**（§8 の DoD 11）。**本プランの改訂は、ステップ A-6 の「対象」欄への 1 行追記（**区分 II の事実更新**）と、§8 の DoD 11 / 15 / 16 の検証欄への追記、および本注記の追加のみである。** **追記の内容は「テストの差し込み口として production の `(fess) helper/SuggestHelper.java` に protected な 1 行ラッパ 3 つを新設した」ことである** — **プラン A-6 の作業内容 1 が [提案] としていた「`Suggester` / `SuggestIndexer` をスタブ化する」が、`SuggestIndexer` を単体テストでインスタンス化できないため成立しないことを実物で確認したことによる** [確認]。**設計書（`0003` §11.1 / §11.3）はテストのホスト先と検証内容しか定めておらず差し込み口の方式を定めていないため、設計判断は 1 つも動いていない。** **したがって `docs/0003-migration-ops-design.md` は第 16 版のまま無改訂であり、新しい X 番号も MO 番号も起こしていない**（区分の判定は `0007` §6.4）。**A-6 の記録は独立ファイルにせず `0007-phase-a-fess-precede.md` §6 に収めた**（Q9=(B)「フェーズ単位で 1 ファイル」。§9.1 の繰り下げ規則は逸脱が発火した場合の規則であり、本ステップは発火していない）。**したがって §9.1 の台帳の繰り下げも発生していない。** **検証は `mvn test`（`modules/fess` 全体）= `Tests run: 7461, Failures: 0, Errors: 0, Skipped: 0` / `BUILD SUCCESS`** [確認]。

> **【2026-09-04】ステップ A-6 の実施結果に対する外部レビュー（要修正・Major 2 / Low 1）を反映した。** **指摘 3 件はいずれも「テストが実際には検証していない」というものであり、すべて妥当と判断して是正した** — **(1) T-S1 をソース構造検査から `create()` の実行検査へ**（構造検査だけでは `switchIndex()` / `removeDisableIndices()` が呼ばれないことを検証していなかった）／ **(2) MO-27（次世代の件数を更新エイリアスで数えること）に実行検査を新設**（検索エイリアスへ戻す回帰を既存テストが 1 件も検知できなかった）／ **(3) ソース・リソースをファイルとして読む検査のパス解決を作業ディレクトリ非依存へ**。 **本プランの改訂は、ステップ A-6 の対象欄・作業内容 3・作業内容 4・注意点への追記、ステップ A-3 の作業内容 7 への追記（`create()` の可視性のみ package-private にした旨）、§8 の DoD 11 の件数更新、§9.1 の台帳への 0017 追加とフェーズ B〜F の 0018〜0022 への繰り下げ、および本注記の追加のみである。** **production の変更は 2 ファイル**（`(fess) exec/SuggestCreator.java` の `create()` の可視性 ／ `(fess) helper/SuggestHelper.java` の `countWordsInIndex(String)` の切り出し）**であり、いずれも実行可能なテストの差し込み口で、実行文の振る舞いは 1 つも変えていない。** **したがって `docs/0003-migration-ops-design.md` は第 16 版のまま無改訂であり、新しい X 番号も MO 番号も起こしていない**（区分の判定は `0017` §4）。 **検証は `mvn test`（`modules/fess` 全体）= `Tests run: 7468, Failures: 0, Errors: 0, Skipped: 0` / `BUILD SUCCESS`** [確認]。**記録は `0017-review-response-a6.md`。**
>
> 残る **U-4 / U-5 / U-6** は該当ステップ（C-3 / B-6 / 0-1）に着手する時点で判断すればよく、§10.1.2 に既定線を置いてある。**実装着手前に決めるべき項目は残っていない。**
>
> **外部レビュー（第 1 回・2026-08-24）の反映結果は §12 に、第 2 回（2026-08-31・フェーズ 0 の作業記録に対するもの）の反映結果は §13 にある。**
>
> **実装着手前に閉じるべきゲートが 2 つある**（§13 の指摘 2）: **C-3 の前に G-OS1**（`strict_allow_templates` / `total_fields`）、**D-1 の前に G-OS2**（`GetRequest` の `realtime` 既定値）。**フェーズ A / B と C-1 / C-2 はゲートに掛からない。**
>
> **実装の着手順序は §5.2 に従う。** 最初に読むべきは **§0 / §0.0（現行の R0 / R1 / R2 モデルと旧 L1 / L2 / L3 からの読み替え）**・**§2.1（逸脱手続き）**・**§5.5（リリース順序と、R0 を分ける理由）**である。
>
> **§0.1 と §7 を先に読まないこと** [確定]。**どちらも 2026-08-31 に撤回された旧 L1 モデルの記録であり、読むと消滅した中間状態を前提に実装してしまう。** 撤回の経緯を追う必要が生じたときだけ、撤回ヘッダとあわせて読む。
