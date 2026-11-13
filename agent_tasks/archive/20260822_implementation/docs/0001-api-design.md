# 0001 インタフェース・API 設計書

> 対象: fess-suggest 改善設計 ／ 実施日: 2026-08-12（初版） ／ 現在の版: **第 10 版**（2026-08-31）
> 凡例: `0000-design-overview.md` §3.1 に同じ
>
> **対象 MIG**: MIG-03, MIG-05, MIG-06, MIG-07, MIG-08, MIG-09, MIG-10, MIG-11, MIG-12, MIG-15 第 1 段（いずれも完全設計） ／ MIG-01（**シグネチャのみ**。挙動の正は `0002` §5.3） ／ MIG-13, MIG-16, MIG-17（API 側の受け口のみ。実体は `0002` / `0003`） ／ MIG-14, MIG-15 第 2 段, MIG-18〜24（拡張点の形状のみ）
> **消化する申し送り**: `apply` 引数の最終形 → §8.5 ／ `roles` の許可リストと権限扱い → §5 ／ **`0002` §9 の 5（`userBoost` の「指定あり／なし」の型表現）→ §2.6** ／ **`0003` §13 の 2b（G2 スモーククエリの実行経路）→ §2.2** ／ **`0003` §13 の 2（`SuggestCreator` の変更対象化）→ §9.1 / §9.5**
> **第 4 版で消化する外部レビュー指摘**: 型の役割分離 → §2.6 ／ 生成制約の型化 → §2.6 / §3.9 ／ 部分失敗と切替ガードの接続 → §9.2（判定の正は `0003` §4.2） ／ alias primitive → §2.2 ／ SPI の合成点 → §3.9 ／ `ScoringStrategy` の拡張可能範囲 → §3.2 ／ 公開メソッド数の訂正（24 → 28）→ §0 の D-1
> **第 5 版で消化する外部レビュー指摘（第 2 回）**: エイリアス状態の読み取り面と post-condition 契約 → §2.2 / §2.2.2（D-23） ／ `SuggestSource` の実行可能性 → §2.4 / §3.1（D-24） ／ bad word の重複マッチ解除 → §2.3 / §3.5 / §3.6（D-25） ／ スレッド安全性契約の限定 → §4.4（D-26） ／ `SuggestSource` の順序非依存の限定 → §3.9.3（D-27） ／ C-01 の互換性の範囲 → §8.3（D-28）
> **第 6 版で消化する外部レビュー指摘（第 3 回）**: `createNextIndex()` のエイリアス付替が D-23 の対象から漏れていた → §2.2 / §2.2.2（**D-23 の対象拡張**） ／ `SuggestWordAdmin` の 2 段書き込みの部分適用 → §2.3.1（D-29） ／ `SuggestSource.kind()` と `SuggestCandidate.kinds` の二重の権威 → §3.1（D-30） ／ §3.9 冒頭に残った第 4 版の記述 → §3.9 / §3.1.1（文書修正）
> **第 7 版で消化する外部レビュー指摘（第 4 回）**: `SuggestStore` と `SuggestItemMergePolicy` の責務境界が閉じていない → §3.7 / §3.7.1（**D-31**） ／ bad word の取り込み時 drop が C-02 の可逆性と矛盾する → §3.5.2（**D-32**） ／ `Kind` を `SuggestItem` の内側から出す → §2.6.0（**D-33**） ／ `SuggestSource` を公開拡張点にしたことによる `roles` 混入リスク（K-2）→ §3.1.3 / §7.4
> **第 9 版で解消する設計矛盾（実装タスク `20260822_implementation` の逸脱 X-1）**: `SuggesterBuilder.build(...)` の戻り値型が §8.3 の「旧 public シグネチャを 1 つも変えない」および C-01 と両立していなかった → §3.9.1 / §8.1 の 11 / §8.3.1（D-28 の範囲に追記）
> **第 10 版で反映する前提の変更（逸脱手続きの対象外 — ユーザーによる配布・運用モデルの確定。要件定義 `20260822_implementation/0000` 第 2 版 §2 の R-P1〜R-P3）**: **§8.3.1 が C-01 の維持対象に挙げていた「fess 本体が L1（fess-suggest だけ新版）のまま動くこと」が、R-P1（fess 本体と fess-suggest は常に同時更新する）と矛盾していた** → **§8.3.1 の当該行を「R1 まで旧 `Suggester` / `SuggestIndexer` の public シグネチャを維持すること」に置き換え、維持する理由を 3 つに書き直した**（Strangler の段階化 ／ 公開 artifact への 1 リリース猶予 ／ fess 本体の新 API 切り替え前後の開発・ビルド互換性） ／ **D-28 の記述を同じ向きに更新** ／ §3.9.1 / §8.1 の 11 に残る「L1 では fess 本体が無変更で動く」という表現の読み替え。**D-1〜D-33 の決定内容・公開 4 IF のシグネチャ・30 メソッド・番号体系に変更は無い。** **X-1 の対処（`build(...)` は `Suggester` を返す）は維持する** — 理由が「L1 で fess 本体がコンパイルできなくなるから」から「**R1 まで旧ファサードの互換性を保つと決めたから**（U-9）」に変わっただけである。
> **依存する [確定] 番号**: `0000` §5 の C-01, C-02, C-03, C-04, C-05, C-06, C-07, C-08, C-09, C-10, C-11, C-12, C-13, C-14 ／ `0000` §5.1 の P2, P3, P6, P9, P10, P12, P13, U2, U4, U5
> **消化する [確認] 事項**: F-06（`userBoost` 潰れの受け口）, F-07, F-08, F-09, F-11（`0000` §5.2）

## 改訂履歴

**判断の変更を追跡可能にするために置く。** 設計の反転（特に D-6）は、付録 A に却下行が存在する理由の文脈になるため、本表を読まずに `0016` と本書を並べると「なぜ却下したのか」が復元できない。

| 版 | 日付 | 変更 | 作業履歴 |
| --- | --- | --- | --- |
| 初版 | 2026-08-12 | ステップ 3（3-1〜3-10）の執筆 | `20260706_design_document/0007` |
| **第 2 版** | 2026-08-12 | **D-6 を部分一致維持へ差し戻した**（初版は完全一致に統一するとしていたが、提案書の [確定] 前提（`improvement-proposal.md:380` の MIG-03 定義ほか）と矛盾するため。付録 A.2 の却下行はこの差し戻しの帰結であり、`0016` §2.3 / §7 の term 完全一致化を採らない旨を記録している）。あわせて完了スレッド契約（§4.4 / §4.4.1）を追加、D-1（19 → 24 メソッド）・D-14（5 → 4 ファイル）の数値を本文に合わせて訂正 | `20260706_design_document/0008` |
| **第 3 版** | 2026-08-13 | **ステップ 7 の通し整合レビューによる改訂。** (1) `SuggestIndexLifecycle.validateNext(SuggestQuery)` を新設し `0003` の G2 スモーククエリの実行経路を確定（D-15、§2.2）。(2) `SuggestItem` の `userBoost` に「指定あり／なし」を生成 API の分離で導入（D-16、§2.5→ 第 4 版で §2.6 へ移動）。(3) `(fess) exec/SuggestCreator.java` を変更ファイル一覧に追加（§9.1 / §9.5）。(4) fess 側の新設設定キーを `index.document.suggest.*` に訂正（§9.4、`0003` MO-9）。(5) 本文中の他文書参照を作業プランのステップ番号から実節番号へ置換 | `20260706_design_document/0014` |
| **第 4 版** | 2026-08-17 | **外部レビュー指摘の反映。** (1) **`SuggestCandidate` / `SuggestItem` / `SuggestHit` の 3 型に分離**（D-19、§2.6）。(2) **`userBoostSpecified` を廃止**し、`SuggestCandidate.userBoost` を `OptionalDouble` とした（**D-16 の反転** — 下記）。(3) 公開 DTO を **`final class` ＋ 不変コレクション**に改め、配列を公開面から外した（D-20、§2.6）。(4) **`switchIndexRetainingPrevious` / `rollbackToPrevious`** を新設（D-21、§2.2）。(5) **fess 側の全件再構築で `IngestResult.hasFailures()` を失敗として扱う**接続を明示（D-22、§9.2）。(6) **§3.9（SPI の合成点）を新設**。(7) `ScoringStrategy` の拡張可能範囲を明文化（§3.2）。(8) **D-1 の公開メソッド数を 24 → 28 に訂正**。(9) `SuggestStore.multiGet` の宣言欠落を補った（§3.7） | `20260706_design_document/0015` |
| **第 5 版** | 2026-08-17 | **外部レビュー（第 2 回）指摘の反映。** (1) **`aliasState()` を新設**し、エイリアス遷移メソッドの正常完了を「例外が出なかった」ではなく **post-condition の成立**として定義した（D-23、§2.2 / §2.2.2）。(2) **`SuggestSource<I>` を型付きの変換 Adapter に改め、実行点 `SuggestIngestService.indexFrom(...)` を新設**した（D-24、§2.4 / §3.1）。**「登録するだけで載る」という §2.4 の記述は誤りであり撤回した**。(3) **`deleteBadWord` の解除対象を「削除後の bad word 集合のいずれにも該当しない語」に限定**し、`BadWordPolicy.releaseCondition` と `QueryCondition.mustNotContain` を追加した（D-25、§2.3 / §3.5 / §3.6）。(4) **スレッド安全性契約を「concurrent invocation safe」に限定**し、同一 `text` への並行 write が線形化可能でないことを契約に明示した（D-26、§4.4）。(5) **`SuggestSource` の順序非依存の主張を `userBoost` を除く範囲に限定**し、`SuggestSource` が `userBoost` を指定しないことを契約とした（D-27、§3.9.3 / §3.1）。(6) **C-01 の互換性の範囲を明文化**した（D-28、§8.3）。(7) D-1 の公開メソッド数を 28 → **30** に更新 | `20260706_design_document/0016` |
| **第 6 版** | 2026-08-17 | **外部レビュー（第 3 回）指摘の反映。** (1) **D-23 の対象に `createNextIndex()` のエイリアス付替フェーズを加えた**（Blocker。§2.2.2 に 2 段構成専用の post-condition を追加）。第 5 版は `0003` §3.2 が「この規則は S1 の更新エイリアス付替にも適用する」と書いている一方で、本書の D-23 とメソッド別契約表が `createNextIndex()` を対象に含めておらず、**文書間で直接矛盾していた**。(2) **`SuggestWordAdmin` の 2 段書き込み（設定更新 → インデックス反映）が部分適用しうることを認め、「同一操作の再実行で収束する」を契約とした**（D-29、§2.3.1）。(3) **`SuggestSource.kind()` を削除**し、`SuggestCandidate.kinds` を Kind の唯一の正とした（D-30、§3.1）。(4) §3.9 冒頭と §3.1.1 に残っていた第 4 版の記述（「登録するだけで載る」「`addSource` の意味」）を第 5 版の決定に合わせて書き換えた | `20260706_design_document/0017` |
| **第 7 版** | 2026-08-17 | **外部レビュー（第 4 回）指摘の反映。** (1) **`SuggestStore` を純粋な永続化境界に改めた**（Blocker。D-31、§3.7 / §3.7.1）。`bulkUpsert(List<SuggestCandidate>, SuggestItemMergePolicy)` を **`bulkPut(List<SuggestItem>)`** に置き換え、`multiGet → 合成 → bulkPut` の read-modify-write を `internal` の取り込み経路が所有する形にした。第 6 版までは D-19 が「ストアの Put / Get は同じ `SuggestItem`」と述べる一方で **`SuggestItem` を PUT する API が存在せず**、かつ**任意の Java 製 `SuggestItemMergePolicy` を将来の Painless 版ストアが実行する方法が無い**という、実現不能な一般化を公開契約に持ち込んでいた。**「第 2 段（`scripted_upsert`）は公開契約を変えずに載る」という §3.7 / §4.4.0 の主張は撤回した。**(2) **bad word の取り込み時 drop を廃止し、該当する新規候補も `excluded = true` で保存する形にした**（Blocker。D-32、§3.5.2）。第 6 版までは C-02 が「即時・**可逆**な論理除外」と定める一方で、新規流入だけは不可逆に捨てられていた。(3) **`SuggestItem.Kind` をトップレベル enum `api.SuggestKind` へ出した**（D-33、§2.6.0）。(4) **K-2（`roles` の集合和）をリリース判断項目として明示**し、`SuggestSource` 実装に対する `roles` の契約を §3.1.3 に置いた | `20260706_design_document/0018` |
| **第 8 版** | 2026-08-22 | **設計書セットの閉包リファクタリング（設計内容の変更なし）。** (1) **本文から作業記録（`00XX-*.md`）への相対リンクを除去**し、前提はすべて番号参照（`0000` 経由で解決）に置き換えた。(2) **作業記録への参照を改訂履歴の「作業履歴」列と付録の 2 箇所に限定**し、表記を相対パスから「タスク名／文書番号」のテキスト（例: `20260706_design_document/0010`）に改めた（設計書を `docs/` 直下や `agent_docs/global/references/` へ移設してもリンク切れしない）。(3) **冒頭宣言の「消化する [確認] 事項」欄の参照先を `0000` §5.2 に変更**（F 番号のスナップショットが `0000` に新設されたため）。(4) `§9.4` の freegen の型推論に関する記述の出典を **C-08 の前提**として参照する形に改めた。**決定・番号体系・仕様・テスト仕様に変更は無い。** 規律は `0000` §3.5 | `20260706_design_document/0019` |
| **第 9 版** | 2026-08-24 | **逸脱 X-1 の解消（実装タスクの逸脱手続き・区分 I）。** **同書 §3.9 の「`build(...)` の戻り値を `SuggestComponents` に変える」は、同書 §8.3（旧 public シグネチャを 1 つも変えない）および C-01（L1 では fess 本体が無変更で動く）と両立しなかった。`(fess) helper/SuggestHelper.java:142` が戻り値を `Suggester` 型フィールド（`:86`）へ代入しているため、L1 でコンパイルエラーになる** [確認]。 これを次のとおり改めた — (1) **`SuggesterBuilder.build(Client, SuggestSettings, ExecutorService)` および既存の `build(Client, String)` の戻り値は `Suggester` のまま維持する**（§3.9.1）。(2) **`SuggestComponents` を得る入口を `buildComponents(Client, SuggestSettings, ExecutorService)` として別メソッドで新設する**（§3.9.1）。(3) §8.1 の 11 を「シグネチャを維持したまま存続する。`SuggestComponents` は `buildComponents(...)` から得る」に書き換えた。(4) `build(...)` は内部で `buildComponents(...)` を呼び、得た `SuggestComponents` を保持する `Suggester` を返すことを明記した（D-13 の「旧クラスが新 IF を保持する向き」は保たれる）。(5) **D-28（C-01 が維持する互換性の範囲）に `Suggester.builder()` / `build(...)` が維持する側である旨を追記した**（§8.3.1）。 **あわせて区分 II の是正として、冒頭の「現在の版」表記が第 8 版への更新時に第 7 版のまま据え置かれていたのを本版で正した。** **公開 4 IF のシグネチャ・D-1 の 30 メソッド・番号体系に変更は無い。** | `20260822_implementation/0002` |
| **第 10 版** | 2026-08-31 | **配布・運用モデルの確定に伴う C-01 / D-28 の意味の更新（逸脱手続きの対象外 — 要件変更）。** **第 9 版までの §8.3.1 は「fess 本体が L1（fess-suggest だけ新版）のまま動くこと」を C-01 が守る実体としていたが、R-P1 により「新 fess-suggest ＋ 旧 fess 本体」という本番状態は生じない。** (1) **§8.3.1 の当該行を「R1 まで旧 `Suggester` / `SuggestIndexer` の public シグネチャを維持する」へ置き換え**、理由を **(a) Strangler 実装の段階化 (b) `fess-suggest` が公開 artifact であることによる 1 リリース猶予（U-9） (c) fess 本体を新 API へ切り替える前後の開発・ビルド互換性** の 3 点に整理した。**「旧 fess 本体 ＋ 新 fess-suggest を本番稼働させること」は要求しない**と明記した。(2) **D-28 の記述を同じ向きに更新**した。(3) §3.9.1 / §8.1 の 11 に残る「L1 では fess 本体が無変更で動く」の読み替えを注記した。**決定内容・シグネチャ・番号体系に変更は無い。X-1 の対処も維持する** | `20260822_implementation/0012` |

> **第 4 版における D-16 の反転について。** 第 3 版の D-16 は「`OptionalDouble` を公開 record のフィールドに持ち込まない」を却下理由の中心に置いていたが、**その判断は `userBoost` を保持する型が「保存されている現在状態」であるという前提に依存していた**。第 4 版で取り込み側を `SuggestCandidate`（＝状態ではなく**更新の意思**を表す型）へ分離した結果、`OptionalDouble` の「指定あり／なし」という意味論が型の役割と一致する。**`SuggestItem`（現在状態）には引き続き `OptionalDouble` を置かない**（保存された語の `userBoost` は常に確定値である）ため、第 3 版の懸念そのものは維持されている。`userBoostSpecified` という補助 boolean は、状態を表す型に更新指示を混ぜたことの副産物であり、分離とともに消える。

---

## 0. エグゼクティブサマリ

本書は「fess-suggest の公開契約」を確定させる。決定の一覧は次のとおりで、以降の節はその根拠と全シグネチャである。

| # | 決定 | 節 | 根拠 |
| --- | --- | --- | --- |
| D-1 | 公開面は **`api` 4 インタフェース・計 30 メソッド**（§2.1 の 2 ＋ §2.2 の **12** ＋ §2.3 の 7 ＋ §2.4 の **9**）。旧 `Suggester`（public 18）＋ `SuggestIndexer`（public 30）の 48 公開メンバを再配置する ※**初版〜第 3 版の「24」は誤り**（`validateNext` / `updateRefreshInterval` を第 3 版で追加した際に数値が追随していなかった）。第 4 版の D-21 で 2 件を追加し 28、**第 5 版の D-23（`aliasState`）と D-24（`indexFrom`）で 2 件を追加し 30** になった | §2 / §8 | C-05 |
| D-2 | **`suggest` / `suggestWithDetail` の 2 分割を採らない**。`suggest` 1 本＋レスポンスのフィールド選択に統一する（A2 の再判断） | §2.1 / §5 | C-10 |
| D-3 | **公開 4 IF の全メソッドが `CompletableFuture` を返す**。同期ラッパ API は提供しない。同期が要る呼び出し元は `join()` する | §4 | C-06 |
| D-4 | **項目単位の部分失敗は例外にしない**（`IngestResult.failures` に積む）。操作全体の失敗のみ `SuggesterException` で例外完了する（A7 の決着） | §4.3 | C-06 |
| D-5 | `apply` 引数を新 API から**全廃**する（`addBadWord` / `addElevateWord` / `deleteElevateWord` の 3 箇所） | §8.5 | P6, F-07 |
| D-6 | bad word の判定意味論を**正規化後テキストの部分一致 1 つ**に統一する（提案書の [確定] 前提を維持）。`BadWordPolicy` が唯一の所有者となり、**取り込み時の `excluded` 初期値判定**（第 7 版まで「取り込みフィルタ」— D-32）とストア問い合わせ条件の両方を同一クラスから導出する。**メタ文字のエスケープを規則内に必須化する** | §3.5 | C-02, F-09, `improvement-proposal.md:380` |
| D-7 | bad word 集合の所有者を `BadWordPolicy` に一本化し、`SuggestIndexer.badWords` フィールドキャッシュを廃止する（F-08 の構造的解消） | §3.5 | U2 |
| D-8 | `SuggestItemMergePolicy` は**シグネチャのみ**本書で確定する。挙動の正は `0002` §5 | §3.4 | 作業プラン §4 |
| D-9 | 設定は**既存の `settings.SuggestSettingsBuilder` を拡張**する（新パッケージに同名型を作らない）。時間は `Duration`、単位付き文字列のパースは fess-suggest 側 | §6 | C-08 |
| D-10 | shards は API で受ける。**`number_of_replicas` の受け口は設けず** `auto_expand_replicas` のみ | §6.2 | C-13, C-14 |
| D-11 | 権限条件の生成を `AuthorizationFilter` に集約し、**ロール未指定でも全件露出しない**（デフォルト deny 維持） | §7 | C-09 |
| D-12 | `roles` はレスポンスの許可リストに含めるが、**`AccessScope.ADMIN` の呼び出しでのみ**選択できる | §5.3 | C-10 |
| D-13 | 旧 `Suggester` / `SuggestIndexer` は**シグネチャを維持したまま新部品へ委譲**する（Strangler Fig 第 2 段）。`Deferred.Promise` は `CompletableFuture` からのアダプタで供給する | §8.3 / §8.4 | C-01 |
| D-14 | fess 本体の変更は **5 ファイル**（Java 4: `SuggestHelper` / `SuggestWordsHandler` / `PopularWordHelper` / **`SuggestCreator`** ＋ 設定 1: `fess_config.properties`）。**公開シグネチャは変えない**。`SuggestCreator` は API 適合の観点では変更不要だが、`0003` §4.3 の切替可否ガードにより変更対象になる（第 3 版で訂正 — §9.1 / §9.5） | §9 | C-07, `0003` §4.3 |
| **D-15** | **切替前の検証クエリは `SuggestIndexLifecycle.validateNext(SuggestQuery)` で受ける。** `SuggestQuery` に対象インデックスの指定要素を追加せず、**本番と同一のクエリ生成をライブラリ内部で更新エイリアスに向ける**。`0003` §4.2 の G2 スモーククエリの実行経路がこれで確定する | §2.2 | `0003` §13 の 2b |
| **D-16** | **`userBoost` の「指定あり／なし」は `SuggestCandidate.userBoost`（`OptionalDouble`）で表現する。** 「指定なし」は `OptionalDouble.empty()` である。**`SuggestItem`（保存されている現在状態）は `double userBoost` を常に確定値として持ち、`OptionalDouble` も `userBoostSpecified` も持たない** ※**第 4 版で結論が反転した**（改訂履歴の注記） | §2.6 | `0002` §9 の 5（DM-11） |
| **D-18** | **`refresh_interval` は `RefreshInterval`（`Every(Duration)` / `Disabled`）で表現し、`SuggestIndexLifecycle.updateRefreshInterval` で動的変更できる。** `Optional<Duration>` では OpenSearch の `-1`（自動 refresh 無効）を表せず、`0003` §7.3 の再構築中の停止・復帰が成立しなかった | §2.2 / §6.2 | C-12, `0003` §7.3（MO-8） |
| **D-17** | **`excluded` は `SuggestItem` だけが持ち、`SuggestCandidate` は持たない。** マージ結果が `OpType.INDEX` の全置換で書かれる以上（`0002` §5.6）、現在状態の型が `excluded` を持たなければ取り込みのたびに除外が消える。一方、取り込み側の型に無ければ**「取り込み経路から `excluded` を設定できない」が規約ではなく型として成立する** ※**第 7 版で意味が精密化された**（D-32）。新規語の `excluded` 初期値は `BadWordPolicy` から**ライブラリが計算して** `SuggestItemMergePolicy.initialize` に渡すため、**呼び出し元が任意の値を指定できない**という性質は変わらない | §2.6 / §3.4 | U4, `0002` §5.3 / §5.6 |
| **D-19** | **型を 3 つに分ける（第 4 版）。** `SuggestCandidate`（取り込みたい情報＝部分的）／ `SuggestItem`（保存されている 1 語の完全状態）／ `SuggestHit`（検索レスポンスの projection＝部分的）。**ストアの Put / Get は同じ `SuggestItem` のまま**であり、境界は「取り込み意思」「永続状態」「検索 projection」の間に置く ※**第 7 版まで、この「Put / Get は同じ型」はシグネチャ上成立していなかった**（`SuggestItem` を PUT する API が無かった）。**D-31 の `bulkPut(List<SuggestItem>)` によって文字どおり成立する** | §2.6 / §3.7.1 | 外部レビュー指摘 1・2 |
| **D-20** | **公開 DTO のうち可変配列を持つものは `record` をやめ `final class` とし、コレクションは `List` / `Set` の不変コピーで保持する。** `record` が不変にするのは参照だけであり、`String[][]` / `Kind[]` の中身は呼び出し側から書き換えられる。§4.4 の「DTO は共有してよい」はこの前提の上でのみ成立する | §2.6 | 外部レビュー指摘 2 |
| **D-21** | **`SuggestIndexLifecycle` に `switchIndexRetainingPrevious()` と `rollbackToPrevious()` を置く。** 高水準の再構築 orchestration（`0003` MO-1 が置かないと決めたもの）と**エイリアス遷移の atomic primitive** は別である。`.prev` 付与と検索エイリアス切替を 1 リクエストに束ねられるようになり、`0003` §3.2 S4 の中間状態が消える | §2.2 | `0003` MO-1 / MO-17, 外部レビュー指摘 5 |
| **D-22** | **項目単位の部分失敗を「失敗」と読み替える責務は呼び出し元にある。** D-4（ライブラリは部分失敗で例外完了しない）は維持したうえで、**fess の全件再構築経路は `IngestResult.hasFailures()` を失敗として扱う**。判定の正は `0003` §4.2 の G3 | §9.2 | D-4, `0003` §4.2（MO-18） |
| **D-23** | **エイリアスを動かすメソッドの「正常完了」を post-condition の成立として定義する。** `switchIndex` / `switchIndexRetainingPrevious` / `rollbackToPrevious` / **`createNextIndex`（第 6 版で追加。エイリアス付替フェーズが対象）** は、下位の aliases request が例外を返しても**エイリアス状態を再取得し、目的の状態になっていれば正常完了する**。判定不能な場合のみ `SuggestAliasStateUnknownException` で例外完了する。あわせて運用確認用の読み取り面 **`aliasState()`** を公開する | §2.2 / §2.2.2 | 外部レビュー（第 2 回）指摘 1 ／ **（第 3 回）指摘 1** |
| **D-24** | **`SuggestSource<I>` は「入力 I → `SuggestCandidate` の列」への型付き変換 Adapter であり、入力と実行を所有するのは `SuggestIngestService` である。** 実行点として **`indexFrom(SuggestSource<I>, I, IngestOptions)`** を置く。**「`SuggestSource` を登録するだけで新しい供給元が動く」形は採らない** | §2.4 / §3.1 / §3.9 | 外部レビュー（第 2 回）指摘 2 |
| **D-25** | **`deleteBadWord` が `excluded` を解除するのは「削除後の bad word 集合のいずれにも該当しなくなった語」だけである。** 判定規則の所有者は引き続き `BadWordPolicy` であり、**`releaseCondition(String)`** がこの条件を返す。`QueryCondition` に **`mustNotContain`** を追加する | §2.3 / §3.5 / §3.6 | 外部レビュー（第 2 回）指摘 3, C-02 |
| **D-26** | **スレッド安全性の契約は「concurrent invocation safe」までである。** 同一 `text` に対する write は atomic でも linearizable でもなく、**異なる呼び出し元が同時に書くと `queryFreq` / `docFreq` の更新を失いうる**（K-1）。「壊れない」と「頻度が失われない」を区別して契約に書く | §4.4 | 外部レビュー（第 2 回）指摘 4, `0002` K-1（F-10） |
| **D-27** | **`SuggestSource` は `userBoost` を指定しない**（`SuggestCandidate.document(...)` のみを使う）。`userBoost` を指定できるのは `SuggestWordAdmin` の elevate word 経路だけである。**複数ソースの結果が順序に依存しないのは `userBoost` を除く全フィールドについてであり**、指定ありの候補が同一 `text` に複数来た場合は後勝ち（＝供給順に依存）である | §3.1 / §3.9.3 | 外部レビュー（第 2 回）指摘 5 |
| **D-28** | **C-01 が維持する互換性は「`Suggester` / `SuggestIndexer` の public シグネチャを R1 まで維持すること」に限る**（**第 10 版で書き換え** — 第 9 版までは「fess 本体が L1 のまま動くこと」を含めていたが、**R-P1 によりその本番状態は生じない**。**維持する理由は §8.3.1 の (a)(b)(c)**）。 `entity.SuggestItem` の public コンストラクタ廃止（D-20）により、**fess-suggest の外部利用者に対する source / binary compatibility は維持されない**。メジャーアップデートとして受容する。**第 9 版で維持する側に `Suggester.builder()` とその `build(...)` を明示した**（逸脱 X-1。§8.3.1） | §8.3 | 外部レビュー（第 2 回）指摘 6, C-01, D-20, 逸脱 X-1 |
| **D-29** | **`SuggestWordAdmin` の 7 メソッドは「設定インデックスの更新」と「suggest インデックスの反映」の 2 段書き込みであり、分散トランザクションにしない。** 代わりに**全メソッドを再実行可能・収束型として定義する** — 前段は「その状態にする」（既に済んでいても成功）、後段は**呼び出し時点の bad word 集合から条件を再計算する**。契約として「**後段が失敗した場合は部分適用状態になりうる。同一操作の再実行により収束する**」を書く | §2.3.1 / §4.2 | 外部レビュー（第 3 回）指摘 2, D-25, `0002` DM-20 |
| **D-30** | **`SuggestSource.kind()` を削除し、`SuggestCandidate.kinds` を Kind の唯一の正とする。** ソース宣言と候補の実値という 2 つの権威を置くと、両者の一致を誰も保証しない。`SuggestCandidate` は**それ自体で完結した「更新の意思」**（D-19）であり、Kind もその一部である。既定 2 ソースの Kind は「型が宣言する属性」ではなく「実装が返す値」になる | §3.1 / §3.9.2 | 外部レビュー（第 3 回）指摘 3, D-19, D-24 |
| **D-31** | **`SuggestStore` は純粋な永続化境界であり、合成を持たない。** 書き込み面を **`bulkPut(List<SuggestItem>)`** とし、`multiGet → SuggestItemMergePolicy で合成 → bulkPut` の read-modify-write は **`internal` の取り込み経路が所有する**。これにより (a) D-19 の「Put / Get は同じ `SuggestItem`」がシグネチャ上も成立し、(b) `mergePolicy()` と `store()` が**実際に独立して差し替え可能**になる。**MIG-15 第 2 段（`scripted_upsert`）は「同じシグネチャの別実装」ではなく、その段で改めて設計する原子マージ能力の追加である** — 第 6 版までの「公開契約を変えずに載る」という主張は撤回する | §3.4 / §3.7 / §3.7.1 | 外部レビュー（第 4 回）指摘 1, D-19, C-03 |
| **D-32** | **bad word に該当する新規候補を取り込み時に捨てない。`excluded = true` で保存する。** 第 6 版までは「既存語は可逆に隠す（`excluded`）／新規流入は不可逆に捨てる（`isBadWord` フィルタ）」という非対称があり、C-02 の「即時・**可逆**な論理除外」と矛盾していた。`BadWordPolicy.isBadWord` は**残るが役割が変わる** — drop の判定ではなく **`SuggestItemMergePolicy.initialize` に渡す `excluded` 初期値の判定**である。**インデックスに残り続ける除外語の物理削除は、運用が明示的に選ぶ操作**（`deleteByCondition` の `excluded` 条件）として分離する | §3.4 / §3.5.2 / §2.4 | 外部レビュー（第 4 回）指摘 2, C-02, D-17, `0002` DM-21 |
| **D-33** | **`Kind` を `SuggestItem` の入れ子から出し、トップレベル enum `org.codelibs.fess.suggest.api.SuggestKind` とする。** Kind は永続エンティティ固有の概念ではなく、`SuggestCandidate` / `SuggestItem` / `SuggestHit` / `SuggestQuery` / `WordCountStats` / `deleteByKind` が共有する**ドメイン語彙**である。第 6 版の形では `api` の型が `entity.SuggestItem` を参照しており（`deleteByKind(SuggestItem.Kind)` ほか）、**`api` → `entity` の逆依存が公開面に出ていた** | §1 / §2.6.0 | 外部レビュー（第 4 回）指摘 5, D-19 |

### 0.1 本書の節と作業プランのステップ番号の対応

**`0000` §4.2 はステップ 7 で実節番号に置換済みである。** 本表は作業プランのステップ番号から本書の節を引くための対応表として残す。

| 作業プラン | 本書の節 |
| --- | --- |
| 3-1（0016 との差分表） | **付録 A** |
| 3-2（公開 4 IF） | **§2** |
| 3-3（spi と補助型） | **§3** |
| 3-4（非同期・例外契約） | **§4** |
| 3-5（フィールド選択と権限） | **§5** |
| 3-6（設定 API） | **§6** |
| 3-7（権限集約） | **§7** |
| 3-8（旧 → 新の対応表・委譲設計） | **§8** |
| 3-9（fess 本体側の適合） | **§9** |

---

## 1. パッケージ規約と適用範囲

| パッケージ | 内容 | fess 本体からの参照 |
| --- | --- | --- |
| `org.codelibs.fess.suggest.api` | 公開 4 インタフェースとその DTO（§2）。**共有ドメイン語彙 `SuggestKind` を含む**（D-33 / §2.6.0） | **可** |
| `org.codelibs.fess.suggest.spi` | 拡張点 7 インタフェースと補助型（§3） | 不可（実装の差し替えを行う場合を除く） |
| `org.codelibs.fess.suggest.internal` | 上記の実装 | **不可** |
| `org.codelibs.fess.suggest.settings` | 設定（**既存パッケージを拡張する** — §6） | 可 |
| `org.codelibs.fess.suggest.entity` | `SuggestItem` / `ElevateWord`（**既存パッケージを維持する**） | 可 |

- **パッケージ間の依存は `spi` → `entity` → `api` の一方向である**（第 7 版 / D-33）。`api` は `entity` を参照しない。第 6 版までは `SuggestIngestService.deleteByKind(SuggestItem.Kind)` ・ `SuggestQuery.kinds` ・ `WordCountStats.byKind` の 3 箇所が `api` から `entity.SuggestItem` を参照しており、**`api` を単独で読める公開面という前提が崩れていた**。`SuggestKind` を `api` へ出すことでこの向きが揃う。
- `api` / `spi` は **OpenSearch の型（`QueryBuilder` / `SearchResponse` / `Client` 等）を一切露出しない**。現行 `SuggestIndexer.deleteByQuery(QueryBuilder)`（`index/SuggestIndexer.java:283`）と `(fess) helper/SuggestHelper.java:314,331` の `SuggestUtil.deleteByQuery(..., BoolQueryBuilder)` 直呼びは、この規約の違反にあたるため §8.2 / §9 で置換する。
- 本書のコードブロックは**確定シグネチャ**であり、擬似コードではない。Javadoc は 1 行要約のみ記載する（実装時に `@param` / `@return` を補う）。
- 言語前提は Java 21+（`record` / `sealed` を使用）。現行 `pom.xml` の設定に従う。

---

## 2. 公開 4 インタフェース（api）

### 2.1 `SuggestQueryService` — 検索・人気語

**責務**: サジェスト検索と人気語取得。ランキングは検索時 function score の単系統（死蔵 `score` を参照しない — MIG-02）。
**利用者**: `(fess) api/v2/handlers/SuggestWordsHandler.java` / `(fess) helper/PopularWordHelper.java`。

```java
package org.codelibs.fess.suggest.api;

public interface SuggestQueryService {

    /** サジェスト候補を検索する。返却属性は query.responseFields() で決まる（§5）。 */
    CompletableFuture<SuggestResult> suggest(SuggestQuery query);

    /** 人気語を取得する。返却属性は query.responseFields() で決まる（§5）。 */
    CompletableFuture<SuggestResult> popularWords(PopularWordsQuery query);
}
```

**A2（`SuggestWords` / `SuggestResult` の 2 分割）を再判断した結果、2 分割を採らない** [提案]。理由は 3 点。

1. **同じ事柄を制御する旋回ノブが 2 つになる。** C-10 でレスポンスのフィールド選択を導入すると、「どの属性が返るか」を決める手段がメソッド選択とフィールド指定の 2 系統になる。ISS-03 の本質は「返却内容が呼び出し側から見えない」ことであり、ノブが 2 つある状態はその再発である。
2. **fess の実需要が `text` と `tags` だけである** [確認]。`(fess) api/v2/handlers/SuggestWordsHandler.java:105-111` は `item.getText()` と `item.getTags()` しか読まず、`(fess) helper/PopularWordHelper.java:120` は `getItems()` から `getText()` のみを取る。既定（text / tags）が両者を満たすため、軽量版を別メソッドにする動機がない。
3. **ISS-03 は既定値の明示と自己記述で解ける。** 現行の問題は `SuggestRequest.java:103` の `private boolean suggestDetail = true;` という**暗黙の既定**である。新 API では既定を `Set.of(TEXT, TAGS)` として明示し、`SuggestResult.populatedFields()` が実際に埋まった属性を宣言する（§5.2）。型ではなく値で自己記述させる。

したがって `SuggestWords` 型は**新設しない**。

### 2.2 `SuggestIndexLifecycle` — インデックスのライフサイクル

**責務**: インデックス作成・世代切替・破棄・**エイリアス遷移の atomic primitive の提供**・統計。二重エイリアスによるゼロダウンタイム再構築（KEEP-02）の露出面。
**利用者**: `(fess) exec/SuggestCreator.java:252,298,301`、`(fess) helper/SuggestHelper.java:155`。

> **責務の範囲を「エイリアス管理」と広く書かない**（第 4 版で是正）。本 IF が提供するのは**エイリアス遷移を 1 リクエストで原子的に行う primitive** であって、再構築の制御フロー（いつ切り替えるか、切り替えてよいか）は持たない。**判定と順序制御は呼び出し元である fess 側にある**（`0003` §4.3 / MO-1・MO-2）。この区別を曖昧にすると、`0003` が fess 側に置くと決めたガードをライブラリ側に引き込む圧力が生じる。

```java
public interface SuggestIndexLifecycle {

    /** 既存インデックスが無ければ初期インデックスと二重エイリアスを作成する。作成したら true。 */
    CompletableFuture<Boolean> createIndexIfNothing(IndexSchema schema);

    /** 次世代インデックスを作成し、更新エイリアスのみを付け替える。世代ハンドルを返す。
     *  エイリアス付替フェーズの正常完了は post-condition の成立で定義する（D-23 / §2.2.2）。 */
    CompletableFuture<IndexGeneration> createNextIndex(IndexSchema schema);

    /** 検索エイリアスを最新世代へ原子的に切り替える。 */
    CompletableFuture<Void> switchIndex();

    /** 現在の検索対象へ保持用エイリアスを付け替えつつ、検索エイリアスを最新世代へ移す。
     *  両操作を 1 リクエストに束ねるため、片方だけが適用された中間状態が生じない（D-21）。 */
    CompletableFuture<Void> switchIndexRetainingPrevious();

    /** 検索エイリアスを保持用エイリアスが指す世代へ戻す。更新エイリアスには触れない（D-21）。 */
    CompletableFuture<Void> rollbackToPrevious();

    /** どちらのエイリアスも指していない旧世代インデックスを物理削除する。 */
    CompletableFuture<Void> removeDisableIndices();

    /** suggest インデックスのみを refresh する（他インデックスは対象にしない）。 */
    CompletableFuture<Void> refresh();

    /** 切替前の世代に対して検証クエリを実行する。本番と同一のクエリ生成を更新エイリアスに向ける（D-15）。 */
    CompletableFuture<SuggestResult> validateNext(SuggestQuery query);

    /** 指定世代の refresh_interval を動的に変更する。再構築中の DISABLED から既定へ戻すために使う（D-18）。 */
    CompletableFuture<Void> updateRefreshInterval(IndexGeneration generation, RefreshInterval interval);

    /** 現在の検索エイリアスが指す物理インデックス名。 */
    CompletableFuture<String> currentIndexName();

    /** 検索・更新・保持用の 3 エイリアスの解決結果をまとめて返す（D-23）。運用・調査用の読み取り面。 */
    CompletableFuture<AliasState> aliasState();

    /** 登録語数の統計（Kind 別内訳つき）。 */
    CompletableFuture<WordCountStats> wordCountStats();
}

/** 3 エイリアスの解決結果。いずれも「解決できない（0 個）」を empty で表す。
 *  1 つのエイリアスが 2 つ以上のインデックスを指す異常状態は multiplyAssigned に載る（D-23）。 */
public record AliasState(
        Optional<String> searchIndex,      // {baseIndex}
        Optional<String> updateIndex,      // {baseIndex}.update
        Optional<String> previousIndex,    // {baseIndex}.prev
        List<String> multiplyAssigned      // 2 つ以上のインデックスを指しているエイリアス名
) {}
```

- `refresh()` の Javadoc に「suggest インデックスのみ」と書くのは仕様の明示である [確認]。現行 `Suggester.java:179` は `client.admin().indices().prepareRefresh()` を**インデックス名を渡さずに**呼んでおり、クラスタ全インデックスを refresh する。新 API はこれを suggest インデックス限定に狭める（挙動変化。`0004-corrections.md` の E-24 で訂正として記録済み）。
- **`validateNext(SuggestQuery)` は切替可否ガードのためだけに存在する**（D-15）。`0003` §4.2 の G2（スモーククエリ）は**検索エイリアスが切り替わる前の世代**に対して実行する必要があるが、`SuggestQuery`（§2.5）には対象インデックスの指定要素が無く、`SuggestQueryService.suggest` では更新エイリアス側を引けない [確認]。
  - **`SuggestQuery` 側に世代指定を足さない**のは、運用専用の要素を通常の検索契約に混ぜないためである。検索の呼び出し元（fess の `SuggestWordsHandler` 等）から見て意味のない項目が増える。
  - **fess 側で低レベルクエリを直接組む案を採らない**のは、検証クエリが本番経路と乖離しうるためである。`validateNext` はライブラリ内部で `suggest()` と**同一のクエリ生成**を使い、向き先だけを更新エイリアス（`Suggester.java:408` が返す名前）に差し替える。これにより「切替後に本番クエリが通ること」を切替前に検証できる。
  - 戻り値は `SuggestResult`（§2.5）であり、判定（件数下限・期待語の出現）は**呼び出し元である fess 側のガード**（`0003` §4.3）が行う。ライブラリは合否を決めない。
- **`updateRefreshInterval` は再構築中の `refresh_interval` 復帰にだけ使う**（`0003` §7.3 の MO-8）。`createNextIndex` は作成時に `IndexSchema.refreshInterval` を渡せるが（§6.2）、**作成後に値を戻す経路が現行にも新 API にも無かった** [確認]。世代を明示的に引数に取るのは、切替前の次世代インデックスを対象にするためである（検索エイリアス側ではない）。汎用の settings 更新 API は設けない — 死蔵の設定変更経路を作らないため（設計原則 4）。
- `createIndexIfNothing` / `createNextIndex` が `IndexSchema` を引数に取るのは C-13（shards を API で受ける）の帰結である。無指定時の既定は `(res) suggest_indices/suggest.json` の値（§6.2）。
- Kind 別個別メソッド（`Suggester.java:432,440`）を `WordCountStats.byKind` に集約する。新しい Kind を追加しても API が増えない。

#### 2.2.1 `switchIndexRetainingPrevious` / `rollbackToPrevious`（D-21・第 4 版で新設）

**この 2 つは `0003` の手順が必要としていた atomic primitive であり、fess 側で `SearchEngineClient` を直接叩いていた操作をライブラリへ戻したものである。**

| メソッド | 内容 | 置き換える `0003` の手順 |
| --- | --- | --- |
| `switchIndexRetainingPrevious()` | (1) 既存の保持用エイリアスを全インデックスから remove、(2) 現在の検索対象へ add、(3) 検索エイリアスを remove / add で次世代へ移す — の**3 アクションを 1 リクエストの aliases actions に束ねる** | `0003` §3.2 の S4-(1) ＋ S4-(2)。**2 リクエストに分かれていた中間状態が消える** |
| `rollbackToPrevious()` | 検索エイリアスを保持用エイリアスの指す世代へ戻す（remove / add を 1 リクエストで）。**更新エイリアスには触れない** | `0003` §5.3 の R3 |

- **保持用エイリアス名はライブラリが決める。** `{baseIndex}.prev` は `Suggester.java:455-465` と同じ命名規則の下に置き、fess 側が名前を組み立てない。名前を呼び出し側に持たせると、`0003` §1.4 の削除判定（エイリアスを 1 つも持たないもの）との対応が呼び出し側の規律に依存する。
- **`switchIndex()` は残す。** 保持を伴わない切替（初回や、保持が不要と運用側が判断した場合）に使う。`switchIndexRetainingPrevious()` はその上位互換ではなく**別の遷移**である。
- **`rollbackToPrevious()` は更新エイリアスを動かさない。** 動かす形（＝新バイナリのまま旧世代へ書き戻す）は **ID 方式の相違により禁止**である（`0003` §5.3 の R4-B ／ `0002` DM-15）。**禁止された遷移を実行できるメソッドを置かない**ことで、危険な運用手順が API から到達不能になる。
- **保持世代が存在しない場合、`rollbackToPrevious()` は `SuggesterException` で例外完了する**（`0003` §5.3 の R2 が「ロールバック不可」と判定する状態）。黙って no-op にしない。

#### 2.2.2 エイリアスを動かすメソッドの「正常完了」は post-condition で定義する（D-23・第 5 版／第 6 版で対象拡張）

> **エイリアス操作の失敗を「状態は変わっていない」と読み替えてはならない**（第 4 版で追加した契約）。aliases request が例外で戻っても、**タイムアウトの場合はサーバ側で適用済みでありうる**。「失敗したから元に戻っている」という前提の retry は、二重適用または未適用の取り違えを起こす。

**第 4 版はこの規則を書いたが、判定に必要な読み取り面を `currentIndexName()`（検索エイリアスしか返さない）のまま実装タスクへ送っていた。これは実装詳細ではなく、移行安全性を成立させるための契約そのものである。第 5 版で公開面を閉じる。**

**決定は 2 つある。**

**(1) post-condition の判定はライブラリが吸収する。** `switchIndex()` / `switchIndexRetainingPrevious()` / `rollbackToPrevious()` / **`createNextIndex()`（第 6 版で追加）** の **正常完了の意味を「aliases API が 200 を返した」ではなく「目的の状態になっている」とする。** 実装は次を行う。

| # | 実装の手順 |
| --- | --- |
| 1 | aliases request を発行する |
| 2 | **例外なく完了したらそのまま正常完了する**（追加の読み取りは行わない） |
| 3 | **例外・タイムアウトを検知したら `aliasState()` 相当の再取得を行い、post-condition が成立していれば正常完了する** |
| 4 | post-condition が不成立と確定したら `SuggesterException` で例外完了する（＝未適用。呼び出し元は中止してよい） |
| 5 | **再取得自体が失敗する、または状態が post-condition とも pre-condition とも一致しない場合のみ `SuggestAliasStateUnknownException`（§4.5）で例外完了する** |

各メソッドの post-condition は次のとおりである。

| メソッド | post-condition |
| --- | --- |
| `switchIndex()` | 検索エイリアスと更新エイリアスが**同一のインデックス**を指す |
| `switchIndexRetainingPrevious()` | 検索・更新エイリアスが同一の新世代を指し、**`.prev` が切替前の検索対象をちょうど 1 つ指す** |
| `rollbackToPrevious()` | 検索エイリアスが `.prev` の指すインデックスを指し、**更新エイリアスは動いていない** |
| **`createNextIndex()`**（第 6 版） | **作成した新世代が存在し、更新エイリアスが新世代をちょうど 1 つ指し、検索エイリアスは切替前の世代を指したままである**（§2.2.3） |

**(2) `aliasState()` を公開する。** 用途は**運用・調査**であり、上記 (1) の判定を呼び出し元に肩代わりさせるためではない。`0003` §3.2 の S4 / §5.3 の R2 が現在 `GET /_cat/aliases/{baseIndex}*` を直接叩いているのを置き換える（`0003` MO-20）。**`{baseIndex}` はライブラリが設定インデックスから解決する値であり**（`0004-corrections.md` の G-1 — 設定値を変えても変わらない）、**fess 側が名前を組み立てるべきではない**。

- **なぜ「呼び出し元が `aliasState()` を見て判定する」形にしないか。** 判定を呼び出し元に置くと、失敗時分岐の正しさが**呼び出し元ごとの規律**に依存する。`0003` §3.2 が定める「二重適用と未適用を取り違えない」という不変条件は、**遷移を発行した主体と同じ層でしか担保できない**。§2.2 の冒頭が「判定と順序制御は fess 側にある」と書いているのは**再構築の制御フロー**（いつ切り替えるか・切り替えてよいか）の話であり、**遷移メソッド自身が自分の効果を確認すること**はその責務分担に反しない。MO-1（再構築を束ねる高水準 API を新設しない）とも衝突しない。
- **`SuggestAliasStateUnknownException` を `SuggesterException` の別派生にするのは、呼び出し元の分岐が 3 通りだからである。** 「成功 → 続行」「未適用 → `exitCode = 1` で終了」「判定不能 → 切替を進めず終了し手順書の調査手順へ回す」（`0003` §3.2 の S4）。この 3 分岐は**例外型で表さないと呼び出し元が書けない**。
- **リトライはライブラリも行わない。** 上記 3 で post-condition が成立していれば「既に適用済み」として正常完了するため、呼び出し元の無条件リトライが不要になる。**未適用と確定した場合の再発行は呼び出し元の判断**である（再構築を続行してよいかはライブラリが決めない）。

#### 2.2.3 `createNextIndex()` も 2 リクエストであり、同じ規則の対象である（第 6 版で是正）

**第 5 版の D-23 は `switchIndex` 系 3 メソッドだけを対象にしていたが、これは誤りである。** `createNextIndex()` 自身が

| # | フェーズ | 内容 |
| --- | --- | --- |
| P1 | **インデックス作成** | `prepareCreate` ＋ acknowledge 検査 ＋ yellow 待ち（`Suggester.java:247-260`） |
| P2 | **更新エイリアスの付替** | 新世代への add と全旧世代からの remove を **1 リクエストの aliases actions に束ねる**（`:262-267`） |

という **2 リクエストの 2 段構成**であり、**P2 は §2.2.2 の冒頭が述べる「タイムアウトしてもサーバ側では適用済みでありうる」aliases request そのものである**。

**`0003` §3.2 は第 4 版の時点で「この規則は S1 の更新エイリアス付替にも同じく適用する」と明記していた。第 5 版で本書側の D-23 とメソッド別契約表（§4.2）がこれを取りこぼしていたのは、思想の相違ではなく文書間の接続漏れである。**

**取りこぼした場合に残る状態**（これが是正の動機である）:

```text
P2 がクライアント側 timeout ／ サーバ側では適用済み
  → createNextIndex() が SuggesterException で例外完了
  → 呼び出し元（(fess) exec/SuggestCreator.java:252）が S2 以降を実行しない
  → 残る状態: search alias → 旧世代 ／ update alias → 空の新世代
```

**この状態では、以後のリアルタイム増分書き込み（`indexFromSearchWord` / `addElevateWord` / `addBadWord`）がすべて空の新世代に入り、検索結果に現れない**（`0003` §2.4 の注記が指摘している穴と同一の状態である）。次回ジョブで回収されるとはいえ、**「本当は成功していたのに失敗として扱った」ことによって作られる状態**であり、post-condition を見れば避けられる。

**P1 と P2 で扱いが異なる。**

| フェーズ | 失敗時の扱い |
| --- | --- |
| **P1（作成）** | **従来どおり `SuggesterException`。** 物理インデックス名はミリ秒精度のタイムスタンプ付き（`Suggester.java:463-465`）であり、**作成がサーバ側で成立していても次回は別名の世代を作る**。取り残しはエイリアス 0 個の孤児として `removeDisableIndices()` が回収する（`0003` §2.4）。post-condition 判定を持ち込む利得が無い |
| **P2（付替）** | **§2.2.2 の 5 段の手順を適用する。** 判定対象は下表 |

`createNextIndex()` の判定は 3 通りである。**判定に使う「新世代」は P1 で自分が作った物理インデックス名であり、`aliasState()` の結果と突き合わせられる。**

| 再取得した状態 | 判定 | 戻り |
| --- | --- | --- |
| 新世代が存在し、**`updateIndex` == 新世代**、`searchIndex` == 切替前の世代 | **適用済み** | **正常完了**し `IndexGeneration` を返す |
| 新世代が存在し、**`updateIndex` == 切替前の世代**（pre-condition のまま） | **未適用と確定** | `SuggesterException`。**新世代はエイリアス 0 個の孤児として残り、`removeDisableIndices()` が回収する** |
| `aliasState()` 自体が失敗する ／ `updateIndex` が empty ／ `multiplyAssigned` に更新エイリアスが載る ／ 上記いずれにも一致しない | **判定不能** | **`SuggestAliasStateUnknownException`**（§4.5） |

- **`searchIndex` を post-condition に含めるのは、P2 が検索エイリアスに触れないことを確認するためである。** 検索エイリアスが動いていれば、それは `createNextIndex()` の効果ではない別の異常（同時実行など）であり、「判定不能」に落とすのが正しい。
- **呼び出し元の分岐は S4 と同型になる**（`0003` §3.2 の S1）。正常完了 → S2 へ進む ／ `SuggesterException` → `exitCode = 1`（次回実行で S1 からやり直せる） ／ `SuggestAliasStateUnknownException` → `exitCode = 1` とし K-18 の調査手順へ回す。
- **`createIndexIfNothing()` は対象外である。** 作成とエイリアス付与が 1 リクエストであり（`Suggester.java:210-218`）、2 段構成に固有の中間状態が無い。失敗時は「作られたか否か」の 2 状態しかなく、再実行が `prepareExists` で吸収する。

### 2.3 `SuggestWordAdmin` — 語管理（bad word / elevate word）

**責務**: bad word・elevate word の登録と取り消し。判定規則は `BadWordPolicy`（§3.5）が単一の正。
**利用者**: fess 管理画面（`(fess) helper/SuggestHelper.java:482,509,521,531,438,450` 経由）。

```java
public interface SuggestWordAdmin {

    /** bad word を登録し、既存の該当語に excluded=true を立てる（論理除外。C-02）。 */
    CompletableFuture<WordOpResult> addBadWord(String word);

    /** bad word を取り消し、削除後の bad word 集合のいずれにも該当しなくなった語だけ excluded を false へ戻す（D-25）。 */
    CompletableFuture<WordOpResult> deleteBadWord(String word);

    /** 登録済み bad word をすべて取り消す。fess 側の全件同期（storeAllBadWords）の受け口。 */
    CompletableFuture<WordOpResult> deleteAllBadWords();

    /** この bad word を適用すると何語が除外されるかを、変更せずに提示する（ドライラン。MIG-13）。 */
    CompletableFuture<BadWordImpact> previewBadWordImpact(String word);

    /** elevate word を登録し、インデックスへ反映する。 */
    CompletableFuture<WordOpResult> addElevateWord(ElevateWord word);

    /** elevate word を取り消し、インデックスから除去する。 */
    CompletableFuture<WordOpResult> deleteElevateWord(String word);

    /** 登録済み elevate word をすべてインデックスへ再投入する。 */
    CompletableFuture<WordOpResult> restoreElevateWords();
}
```

- **`apply` 引数は 3 メソッドすべてから削除する**（P6）。現行は `addBadWord(String,boolean)`（`index/SuggestIndexer.java:395`）・`addElevateWord(ElevateWord,boolean)`（`:417`）・`deleteElevateWord(String,boolean)`（`:428`）の 3 箇所にある。決着の詳細は §8.5。
- `deleteBadWord` が `excluded` を `false` へ戻すのは C-02（可逆な論理除外）の帰結であり、U4（マージ時は既存値保持）と対になる。**既存語の `excluded` を反転させるのはこの経路だけである。** 取り込み経路が `excluded` に触れるのは**新規語の初期値を決めるときに限られ**（第 7 版 / D-32 / §3.5.2）、既存ドキュメントの値は `merge` が保持する（U4）。
- **`deleteBadWord` の解除対象は「その bad word に該当する語」ではない**（D-25・第 5 版で是正）。判定規則は部分一致であるため（§3.5 の D-6）、**1 つの語が複数の bad word に同時に該当しうる**。bad word `foo` と `bar` が登録されている状態でサジェスト語 `foobar` は両方に該当し、ここで `foo` だけを削除して `matchCondition("foo")` の対象を一律 `excluded = false` にすると、**まだ `bar` に該当している `foobar` まで復活する**。正しい対象は**削除後の bad word 集合に照らして、もうどの bad word にも該当しない語**である。条件の生成は `BadWordPolicy.releaseCondition(String)`（§3.5）が持つ。
  - **`addBadWord` 側にはこの問題が無い。** `excluded = true` の付与は単調であり、既に `true` の語へ再度 `true` を書いても意味が変わらない。**非対称なのは解除だけ**である。
  - **`deleteAllBadWords` は集合が空になるため、`excluded = true` の全ドキュメントを一律 `false` に戻す**（`releaseCondition` を使わない）。これは `(fess) helper/SuggestHelper.java` の全件同期（`storeAllBadWords`）が「全削除 → 全登録」の形を取ることに対応する。
- 現行 `restoreElevateWord()`（`index/SuggestIndexer.java:437`）は単数形だが、実体は登録済み elevate word の**全件**再投入である。名前を複数形に改める。

#### 2.3.1 2 段書き込みの部分適用と収束（D-29・第 6 版）

**本 IF の 7 メソッドはすべて「設定インデックスの更新」と「suggest インデックスの反映」の 2 段書き込みである。** 例えば `deleteBadWord` は §3.5.1 のとおり

| # | 手順 | 書き込み先 |
| --- | --- | --- |
| 1 | `policy.remove(word)` | **設定インデックス** |
| 2 | `store.updateExcluded(policy.releaseCondition(word), false)` | **suggest インデックス** |

であり、**2 が失敗すると部分適用状態が残る**。

| 操作 | 2 が失敗したときに残る状態 | 破れる不変条件 |
| --- | --- | --- |
| `deleteBadWord("foo")` | bad word 集合からは `foo` が消えているが、`foo` にしか該当しない語の `excluded` が `true` のまま | **`excluded == true` ⇔ 現在の bad word 集合のいずれかに該当する**（`0002` DM-18） |
| `addBadWord("foo")` | bad word 集合には `foo` が入っているが、既存の該当語が `excluded = false` のまま検索に出続ける | 同上 |
| `addElevateWord` / `deleteElevateWord` / `restoreElevateWords` | 設定と suggest インデックス上の elevate 反映がずれる | elevate word の登録と `userBoost` の対応 |

**第 5 版の契約は「設定更新失敗・更新クエリ失敗なら `SuggesterException`」までしか定めておらず、この状態をどう扱うかが書かれていなかった。**

**採る方針: 分散トランザクションを持ち込まず、操作を再実行可能・収束型にする。**

> **`SuggestWordAdmin` の全メソッドは、同一引数での再実行が安全であり、かつ収束する。**
> **前段は「その状態にする」（既にその状態でも成功する）**、**後段は呼び出し時点の bad word 集合から条件を再計算する。**
> **後段が失敗した場合、操作は部分適用状態になりうる。同一操作の再実行により正しい状態へ収束する。**

この性質が成立する理由は、**2 段目の入力が「1 段目で何が変わったか」ではなく「現在の bad word 集合」だからである** [確認]。

| 操作 | 1 段目の再実行 | 2 段目の再計算 | 収束後の状態 |
| --- | --- | --- | --- |
| `deleteBadWord("foo")` | 集合に `foo` が無ければ何もしない（成功） | `releaseCondition("foo")` ＝ `mustContain(text,"foo")` かつ **現在の集合の全要素について** `mustNotContain` | `foo` にしか該当しない語だけが `false` に戻る（§3.5.1） |
| `addBadWord("foo")` | 集合に `foo` が既にあれば何もしない（成功） | `matchCondition("foo")` は集合に依存しない 1 述語 | `foo` を含む語が `excluded = true`（付与は単調） |
| `deleteAllBadWords()` | 集合を空にする | 集合が空なので `excluded = true` を一律 `false` | 全解除 |
| `restoreElevateWords()` | 参照のみ | 登録済み全件を再投入 | 設計上もともと全件再投入であり冪等 |

- **`remove` / `add` を「差分の適用」ではなく「状態の宣言」として定義することが要点である。** `BadWordPolicy.add` / `remove` の Javadoc に「**既にその状態であれば何もせず成功する**」を明記する（§3.5）。第 5 版の記述は暗黙にこれを仮定していたが書かれていなかった。
- **順序は逆にできない**（§3.5.1）。`releaseCondition` が削除後の集合を必要とするため、設定更新が先である。**したがって「設定だけ進んだ」方向の部分適用しか起きない** — この非対称は意図したものであり、逆順（インデックス先行）だと「除外されるべき語が一時的に検索に出る窓」と「集合更新失敗時に解除だけが残る」の両方が生じる。
- **自動リトライはライブラリ側で行わない。** D-23 の判断と同じ理由である（失敗後にどうするかは呼び出し元の判断であり、無条件リトライを内部に持つと呼び出し元から進捗が見えなくなる）。**呼び出し元に求めるのは「同じ操作をもう一度呼ぶ」だけである。**
- **fess 側の全件同期（`storeAllBadWords`）はこの収束性の上に乗る** [確認]。`(fess) helper/SuggestHelper.java` の全件同期は「全削除 → 全登録」であり、途中失敗しても次回の全件同期が正しい状態を作る。
- **回帰テストは `0002` §7.2 の T-21 に置く**（`0002` DM-20）。

> **なぜ補償トランザクション（2 段目失敗時に 1 段目を巻き戻す）を採らないか。** 巻き戻し自体が同じ 2 段問題を持ち（巻き戻しが失敗したらどうするか）、状態が増えるだけである。**収束型は「壊れた状態が残らない」ことは保証しないが、「同じ操作を繰り返せば直る」ことは保証する。** 運用手順として書けるのは後者だけである。

### 2.4 `SuggestIngestService` — 取り込みと削除

**責務**: ドキュメント本文・検索語からの取り込みと、条件・種別・時刻による削除。
**利用者**: `(fess) helper/SuggestHelper.java:251-253,272,367,382,397,314,331`。

```java
public interface SuggestIngestService {

    /** 取り込み候補を直接バルク登録する（マージは SuggestItemMergePolicy が担当）。 */
    CompletableFuture<IngestResult> index(List<SuggestCandidate> candidates);

    /** DocumentReader からバルク取り込みする。bulkSize / refresh / ペーシングは options で決まる。 */
    CompletableFuture<IngestResult> indexFromDocuments(Supplier<DocumentReader> readerSupplier, IngestOptions options);

    /** 検索語 1 件を取り込む（リアルタイム検索ログ反映）。 */
    CompletableFuture<IngestResult> indexFromSearchWord(SearchWordInput input);

    /** 任意の SuggestSource を入力とともに駆動して取り込む（D-24）。新しい供給元を載せる唯一の実行点。 */
    <I> CompletableFuture<IngestResult> indexFrom(SuggestSource<I> source, I input, IngestOptions options);

    /** ID 指定で削除する。 */
    CompletableFuture<DeleteResult> deleteById(String id);

    /** 構造化条件で削除する（Lucene クエリ文字列や QueryBuilder は受け取らない）。 */
    CompletableFuture<DeleteResult> deleteByCondition(QueryCondition condition);

    /** 全件削除する。 */
    CompletableFuture<DeleteResult> deleteAll();

    /** 指定 Kind の語を削除する。 */
    CompletableFuture<DeleteResult> deleteByKind(SuggestKind kind);

    /** threshold より古い語を削除する。deleteByCondition の時刻条件に対する糖衣。 */
    CompletableFuture<DeleteResult> deleteOldWords(Instant threshold);
}
```

- **`index` が受けるのは `SuggestCandidate` であって `SuggestItem` ではない**（D-19）。検索結果（`SuggestHit`）はもちろん、ストアから読み出した `SuggestItem` も**そのまま取り込み API へ渡せない**。第 3 版までは検索結果として部分的にしか埋まっていない `SuggestItem` を `index(...)` へ渡せてしまい、`excluded` / `queryFreq` などを意図せず巻き戻す経路が型の上で開いていた。
- **`indexFromQueryLog` は新 API に持たない**（MIG-07 / ISS-01）。現行 3 オーバーロード（`index/SuggestIndexer.java:322,332,344`）は fess 本体から一度も呼ばれていない [確認]（`(fess)` 配下の `indexer().` 呼び出しは §8.2 の表がすべて）。必要になった時点で **`SuggestSource<QueryLogInput>`（§3.1）を実装し、`indexFrom(source, input, options)` で駆動する**。
  - **第 4 版までの「合成点に登録するだけで載る」という記述は誤りであり、第 5 版で撤回した**（D-24）。`SuggestSource` は入力を受け取れず、`SuggestIngestService` には登録済みソースを実行するメソッドが無かったため、**この記述どおりの拡張は実行不可能だった**。設計の是正内容は §3.1 にある。
- **`indexFromDocuments` / `indexFromSearchWord` は `indexFrom` の糖衣である**（D-24）。前者は既定の `DocumentSource`、後者は既定の `SearchWordSource`（§3.9.2）を `indexFrom` に適用したものと等価であり、**fess 本体が呼ぶ 2 経路を名前付きで残すために置く**。`indexFromDocuments` が `IngestOptions` を取り `indexFromSearchWord` が取らないのは現行の呼び出し形（`(fess) helper/SuggestHelper.java:251-253` ／ `:272`）に合わせたものである。
- `deleteByCondition(QueryCondition)` が現行の `deleteByQuery(String)` / `deleteByQuery(QueryBuilder)`（`:273` / `:283`）の後継である。`QueryCondition`（§3.6）は `(fess) helper/SuggestHelper.java:305-315,321-331` が組み立てている「時刻範囲 ＋ `kinds` の must / mustNot」をそのまま表現できる。
- **除外語の物理削除は `deleteByCondition` で表現する**（第 7 版 / D-32）。D-32 により bad word 該当語はインデックスに `excluded = true` で残り続けるため、**それを物理的に消したい運用のために専用 API を新設しない** — `mustMatchAny("excluded", ["true"])` を持つ `QueryCondition` を `deleteByCondition` に渡せば足りる（§3.6）。**この操作は不可逆であり、ライブラリが自動で行うことは無い。** 運用手順としての位置づけは `0003` §12.1 にある。
  - **専用メソッド（`purgeExcluded()` 等）を置かない理由**: 「除外語をすべて消す」は `deleteByCondition` の 1 用例にすぎず、Kind 別・期間別の絞り込みと組み合わせたい（例: 「30 日以上更新されていない除外語だけ消す」）ことが十分にありうる。専用メソッドを置くとその組み合わせごとに API が増える。これは `deleteDocumentWords()` / `deleteQueryWords()` を `deleteByKind` に集約した判断（§8.2 の 8・9）と同じ形である。

### 2.5 公開 DTO

```java
/** サジェスト検索条件。無指定項目は既定値で埋まる。 */
public record SuggestQuery(
        String query,                      // 既定 ""
        int size,                          // 既定 10
        List<String> tags,
        List<String> roles,                // 呼び出しユーザのロール集合。_guest_ 補完は AuthorizationFilter が行う（§7）
        List<String> fields,
        List<SuggestKind> kinds,           // D-33: トップレベル enum（§2.6.0）
        List<String> languages,
        float prefixMatchWeight,           // 既定 2.0f
        boolean matchWordFirst,            // 既定 true
        boolean skipDuplicateWords,        // 既定 true
        Set<ResponseField> responseFields,  // 既定 Set.of(TEXT, TAGS)（§5）
        AccessScope accessScope            // 既定 SEARCH（§5.3）
) {
    public static Builder builder() { /* ... */ }
    public static final class Builder { /* fluent setter 群 */ }
}

/** 人気語取得条件。 */
public record PopularWordsQuery(
        int size,
        List<String> tags,
        List<String> roles,
        List<String> fields,
        List<String> languages,
        List<String> excludeWords,
        String seed,
        int windowSize,
        int queryFreqThreshold,            // MIG-14 の受け口（既に可変）
        Set<ResponseField> responseFields,
        AccessScope accessScope
) {
    public static Builder builder() { /* ... */ }
    public static final class Builder { /* fluent setter 群 */ }
}

/** 検索結果。populatedFields が「実際に埋まっている属性」を宣言する（ISS-03 の自己記述化）。 */
public record SuggestResult(
        String index,
        long tookMs,
        long total,
        List<String> words,
        List<SuggestHit> items,          // D-19: 完全状態ではなく projection
        Set<ResponseField> populatedFields
) {
    /** 返却語数。 */
    public int num() { return words.size(); }
}

/** 世代ハンドル。 */
public record IndexGeneration(String physicalIndexName, Instant createdAt) {}

/** 語数統計。Kind 別内訳を Map で保持し、Kind 追加で API が増えないようにする。 */
public record WordCountStats(long total, Map<SuggestKind, Long> byKind) {}

/** 語管理操作の結果。affectedDocs は excluded の付け外しを含む影響件数。 */
public record WordOpResult(long affectedDocs, long tookMs) {}

/** bad word 適用のドライラン結果。 */
public record BadWordImpact(long matchedCount, List<String> sampleWords) {}

/** 取り込みオプション（§6.3）。 */
public record IngestOptions(int bulkSize, int parallelism, RefreshPolicy refreshPolicy,
                            Runnable pacing, LongConsumer onProgress) {
    /** 既定値。bulkSize の最適値は実測依存のためスコープ外（`0000` §2.2）。 */
    public static IngestOptions defaults() { /* ... */ }
}

/** 取り込み完了後の refresh の扱い。毎バッチ refresh は値域に含めない（C-12）。 */
public enum RefreshPolicy { NONE, ON_COMPLETION }

/** 検索語入力。現行 indexFromSearchWord の 6 引数を record に集約する。 */
public record SearchWordInput(String word, List<String> fields, List<String> tags,
                              List<String> roles, long queryFreq, List<String> languages) {}

/** 取り込み結果。項目単位の失敗は failures に積む（§4.3）。 */
public record IngestResult(int numberOfSuggestDocs, int numberOfInputDocs,
                           List<ItemFailure> failures, long tookMs) {
    /** 失敗した項目が 1 件でもあるか。 */
    public boolean hasFailures() { return !failures.isEmpty(); }

    /** 項目単位の失敗。id は決定的 ID（`0002` §4）。 */
    public record ItemFailure(String id, String text, String reason) {}
}

/** 削除結果。 */
public record DeleteResult(long deletedDocs, List<IngestResult.ItemFailure> failures, long tookMs) {
    /** 失敗した項目が 1 件でもあるか。 */
    public boolean hasFailures() { return !failures.isEmpty(); }
}
```

### 2.6 サジェスト語を表す 3 つの型（D-19・第 4 版）

**第 3 版までは `SuggestItem` 1 型が「取り込み入力・ストア読み出し・マージ結果・検索結果」の 4 役を兼ねていた。第 4 版でこれを 3 型に分ける。**

```text
SuggestCandidate ──merge──┐
                          ↓
                    SuggestItem        ← Store GET / PUT はこの 1 型
                   （完全な状態）
                          │
                          ↓ search / projection
                     SuggestHit
```

| 型 | 意味 | 完全性 | 生成元 |
| --- | --- | --- | --- |
| **`SuggestCandidate`** | **これから取り込みたい情報**（＝更新の意思） | 部分的 | `SuggestSource.produce(input, ctx)`（§3.1）・`SuggestWordAdmin` の elevate word 経路 |
| **`SuggestItem`** | **保存されているサジェスト語 1 件の完全な状態** | **完全** | `SuggestStore.multiGet`（§3.7）・`SuggestItemMergePolicy`（§3.4） |
| **`SuggestHit`** | **検索レスポンスの projection** | 部分的 | `SuggestStore.search` / `popularWords`（§3.7） |

**分割の境界を「Put / Get の間」に置かないことが要点である。** ストアからの読み出しと書き込みは同じ `SuggestItem` であり、`item = store.multiGet(id)` → 合成 → `store.bulkPut(items)` が同一型で成立する。**分けるべきなのはその前後**、すなわち「取り込み意思」と「検索 projection」である。

> **第 6 版までこの記述はシグネチャ上成立していなかった** [確認]（第 7 版で是正 — D-31）。本文は `store.put(item)` を前提に書かれていたが、§3.7 の `SuggestStore` に `SuggestItem` を書き込むメソッドは存在せず、書き込み面は `bulkUpsert(List<SuggestCandidate>, SuggestItemMergePolicy)` だった。**すなわち Get は `SuggestItem`、Put は `SuggestCandidate` であり、「Put / Get の間に境界を置かない」という本節の主張と実際の公開面が食い違っていた。** 第 7 版で `bulkPut(List<SuggestItem>)` に改めたことで、上記のとおり読める。詳細と代替案の比較は §3.7.1 にある。

#### 2.6.0 `SuggestKind`（D-33・第 7 版）

**Kind は 3 型すべてと検索条件・統計が共有するドメイン語彙であり、永続エンティティの内側に置かない。**

```java
package org.codelibs.fess.suggest.api;

/** サジェスト語の種別。取り込み候補・永続状態・検索 projection・検索条件・統計が共有する。 */
public enum SuggestKind { DOCUMENT, QUERY, USER }
```

| 参照元 | 参照の形 |
| --- | --- |
| `SuggestCandidate.kinds` | `Set<SuggestKind>`（§2.6.2） |
| `SuggestItem.kinds` | `Set<SuggestKind>`（§2.6.3） |
| `SuggestHit.kinds` | `Optional<Set<SuggestKind>>`（§2.6.4） |
| `SuggestQuery.kinds` | `List<SuggestKind>`（§2.5） |
| `WordCountStats.byKind` | `Map<SuggestKind, Long>`（§2.5） |
| `SuggestIngestService.deleteByKind` | 引数（§2.4） |

- **値域は現行 `entity/SuggestItem.java:47-53` の `Kind` enum（`document` / `query` / `user`）と同一である** [確認]。**永続表現（`kinds` フィールドに書かれる文字列）の正は `0002` §2.5 にあり、本移設で変わらない。** 変えるのは Java の型の置き場所だけである。
- **第 6 版の形が抱えていた問題**: `api` パッケージの `SuggestQuery` / `WordCountStats` / `SuggestIngestService` が `entity.SuggestItem.Kind` を参照していたため、**`api` を読むだけでは公開面が閉じず、`entity` を経由する必要があった**。D-19 で `SuggestItem` の役割を「保存されている完全状態」に限定した以上、他の 5 箇所がその内側の型を参照し続けるのは分離の意図と合わない。
- **これは互換性を壊す変更である。** `(fess) api/v2/handlers/SuggestWordsHandler.java:96,98,101` が `SuggestItem.Kind.USER` を参照している [確認]。ただし当該箇所は §9.3 で**いずれにせよ書き換える対象**（現行は `.toString()` で文字列を渡している）であり、追加の作業は生じない。D-28 が定めた互換性の範囲（`Suggester` / `SuggestIndexer` の public シグネチャ）にも `Kind` の所在は含まれない。
- **`SuggestItem.Kind` を deprecated な別名として残さない。** Java の enum は型別名を作れず、残す方法は「旧 enum を保持して相互変換する」しかない。**値域が 2 箇所に存在する状態は D-30 が排除した「2 つの権威」と同じ形**であり、メジャーアップデート（D-28）で持ち込む理由が無い。

#### 2.6.1 第 3 版が破綻していた理由

| # | 破綻 |
| --- | --- |
| 1 | **検索 projection が不変条件と両立しない。** §5.1 は「選択しないフィールドはストアから読み出さない」と定め、既定は `{TEXT, TAGS}` である。一方 `0002` INV-1 は `readings` の第 1 次元長 ＝ `text` の語数 W を要求し、`0002` §5.2 はこれを `entity/SuggestItem` のコンストラクタで強制すると定めている。**`readings` を取得しない検索結果を `SuggestItem` として構築する方法が存在しない**（`null` も `[]` も INV-1 違反、ダミー値は実際の値ではなく、実値を読めば source filtering の意味が消える） |
| 2 | **`userBoostSpecified` はサジェスト語の状態ではない。** それが表すのは「今回の入力が `userBoost` を上書きする意思を持つか」であり、**更新コマンド側の情報**である。ストアから読み出した現在状態に対して `userBoostSpecified()` と問うても意味が定まらない |
| 3 | **生成 API の分離では型として守れない。** `public record` は public な canonical constructor を持つため、`new SuggestItem(..., 100.0, true, true, ...)` が書ける。「`withUserBoost` 以外から `true` にしない」「取り込み経路から `excluded=true` に到達できない」は**文章上の規約にとどまっていた** |
| 4 | **部分的にしか埋まっていない検索結果を取り込み API へ渡せた。** `SuggestIngestService.index(List<SuggestItem>)` の引数型が検索結果と同一だった |

#### 2.6.2 `SuggestCandidate`

```java
package org.codelibs.fess.suggest.api;

/** 取り込み候補。文書・検索語・elevate word から生成され、SuggestItem へ合成される。
 *  「現在の状態」ではなく「更新したいこと」を表すため、excluded を持たない。 */
public final class SuggestCandidate {

    private final String text;
    private final List<List<String>> readings;
    private final List<String> fields;
    private final List<String> tags;
    private final List<String> roles;
    private final List<String> languages;
    private final long queryFreq;
    private final long docFreq;
    private final OptionalDouble userBoost;   // D-16: empty ＝ 指定なし
    private final Set<SuggestKind> kinds;

    private SuggestCandidate(/* 全フィールド */) { /* 不変コピーと INV-2 / INV-3 の検査 */ }

    /** 通常取り込み（文書・検索語・その他の SuggestSource）。userBoost は常に「指定なし」。 */
    public static SuggestCandidate document(
            String text,
            List<List<String>> readings,
            List<String> fields,
            List<String> tags,
            List<String> roles,
            List<String> languages,
            long queryFreq,
            long docFreq,
            Set<SuggestKind> kinds) { /* userBoost = OptionalDouble.empty() */ }

    /** elevate word 経路。userBoost を「指定あり」で与える。SuggestSource から呼んではならない（D-27）。 */
    public static SuggestCandidate elevate(
            String text,
            List<List<String>> readings,
            List<String> tags,
            List<String> roles,
            double userBoost) { /* kinds = {USER}, fields/languages = 空, queryFreq = docFreq = 0 */ }

    // getter 群（コレクションは不変ビューを返す）
}
```

**引数の由来** [確認]: `document(...)` の 9 引数は現行 `index/contents/DefaultContentsParser.java:100-110`（文書経路）と `:137-146`（検索語経路）が `new SuggestItem(...)` へ渡している値から、`userBoost`（センチネル `-1`）・`@timestamp`・`score` を除いたものである。`elevate(...)` の 5 引数は `entity/ElevateWord.java:143-149` が渡している値に対応する（同経路は `fields` / `languages` / 頻度を渡していない）。**引数が多いことを理由に builder を導入しない** — 生成箇所は上記 2 ファイルの計 3 箇所しかなく（§10 の申し送り 13）、外部からの生成は `SuggestSource` 実装の `document(...)` に限られる。

| 設計 | 理由 |
| --- | --- |
| **`userBoost` が `OptionalDouble`** | 通常取り込みは「指定なし」、elevate word だけが「指定あり」であり、**指定ありの incoming のみが既存値を上書きする**（`0002` §5.3 の DM-11）。合成規則が `incoming.userBoost().isPresent()` の 1 分岐で書けるようになり、**補助 boolean `userBoostSpecified` が不要になる**。現行の 2 段構え（`index/contents/DefaultContentsParser.java:107-108,:144` がセンチネル `-1` を渡し、`entity/SuggestItem.java:131-135` が 1 に丸める）を廃し、MIG-04（丸め撤廃）の受け皿になる |
| **`excluded` を持たない**（D-17） | 「取り込み経路から `excluded` を設定できない」が**型として成立する**。第 3 版が生成 API の分離で守ろうとしていた制約が、フィールドの不在に置き換わる |
| **`id` を持たない** | ID は `text` の関数である（`0002` INV-5 / §4.2）。候補側に ID を持たせると、`text` と ID が食い違う値を外部から作れてしまう |
| **`@timestamp` を持たない** | 取り込み時刻は合成側が決める（`0002` §5.3 の max 規則）。候補側から過去の時刻を注入できないようにする |
| **`elevate(...)` は `SuggestSource` から呼ばない**（D-27・第 5 版） | `userBoost` の合成規則は「指定ありの incoming が上書きする」であり（`0002` DM-11）、**指定ありが複数来ると合成が可換でなくなる**（§3.9.3）。`userBoost` を指定できる経路を `SuggestWordAdmin` の elevate word だけに限ることで、複数ソースの合成が順序非依存であるという主張が成立する。**`elevate(...)` を非 public にできないのは、呼び出し元 `entity/ElevateWord` が別パッケージであるためである**（§1 のパッケージ規約）。したがってこれは**型ではなく契約で守る制約**であり、この点は D-17（`excluded` をフィールドごと持たない）と性質が異なる |

#### 2.6.3 `SuggestItem`

```java
package org.codelibs.fess.suggest.entity;   // 既存パッケージを維持する（§1）

/** 保存されているサジェスト語 1 件の完全な状態。ストアの Get / Put の双方でこの型を使う。 */
public final class SuggestItem {

    private final String text;
    private final List<List<String>> readings;   // INV-1: size() == W
    private final List<String> fields;
    private final List<String> tags;
    private final List<String> roles;
    private final List<String> languages;
    private final long queryFreq;
    private final long docFreq;
    private final double userBoost;              // 常に確定値。Optional でも Specified でもない
    private final boolean excluded;              // D-17
    private final Instant timestamp;
    private final Set<SuggestKind> kinds;

    private SuggestItem(/* ... */) { /* 不変コピーと INV-1〜INV-4 の強制（`0002` §5.2） */ }

    /** ID は text から決定的に導出する（`0002` §4.1）。フィールドとして保持しない。 */
    public String id() { /* Base64URL(SHA-256(UTF-8(text))) */ }

    // getter 群（コレクションは不変ビューを返す）
}
```

- **`id` をフィールドに持たない。** 導出メソッドにすることで、`text` と ID が食い違う `SuggestItem` が**存在しえなくなる**。`0002` INV-5（ID は `text` のみの関数）が型の上で成立する。
- **`0002` の不変条件の強制先はこの型である。** INV-1（`readings.size() == W`）・INV-2（語が区切り文字を含まない）・INV-3（W ≤ N）・INV-4（`readings` の各要素に `null` を含めない）を private コンストラクタで検査する。**検索 projection はこの型を通らない**ため、§2.6.1 の 1 の矛盾は生じない。
- **`score` を保持しない**（MIG-02）。フィールドの意味・決定的 ID・マージ挙動は `0002` が正である。
- **`excluded` を実際に反転させるのは `SuggestWordAdmin` の bad word 操作だけ**である（§2.3 / §3.5）。マージ経路は既存値を保持する（`0002` §5.3 / U4）。

#### 2.6.4 `SuggestHit`

```java
package org.codelibs.fess.suggest.api;

/** 検索レスポンスの projection。responseFields で選択されなかった属性は empty である。
 *  完全なドメインエンティティではないことを型名で示す。 */
public record SuggestHit(
        String text,                              // 既定で常に埋まる
        List<String> tags,                        // 既定で常に埋まる
        Optional<List<List<String>>> readings,
        Optional<List<String>> fields,
        Optional<List<String>> languages,
        Optional<Set<SuggestKind>> kinds,
        OptionalLong queryFreq,
        OptionalLong docFreq,
        OptionalDouble userBoost,
        Optional<Instant> timestamp,
        Optional<List<String>> roles              // AccessScope.ADMIN でのみ埋まりうる（§5.3）
) {}
```

- **`text` / `tags` を `Optional` にしないのは、`ResponseField` の既定が `{TEXT, TAGS}` であり（§5.1）、この 2 つを外す構成を許さないためである。** 既定から属性を減らす方向の選択は受け付けない（現行互換の保証）。
- `Optional` を並べても **`populatedFields()` は残す**（§5.1）。`Optional.empty()` は「選択されなかった」と「選択されたが値が無い」を区別できない。前者は `populatedFields()` が、後者は `Optional` が表す。
- **`SuggestHit` から `SuggestItem` / `SuggestCandidate` への変換 API を用意しない。** 部分的な projection から完全状態を復元する経路を型として塞ぐ（§2.6.1 の 4）。

#### 2.6.5 公開 DTO の不変性（D-20）

**`record` が不変にするのは参照だけである。** 第 3 版のシグネチャは `String[][] readings` / `String[] roles` / `Kind[] kinds` を持っており、`item.roles()[0] = "admin"` が成立した。§4.4 の「DTO はすべて不変であり共有してよい」という契約は、この形では**成立していなかった**。

| 対象 | 第 4 版の扱い |
| --- | --- |
| `SuggestCandidate` / `SuggestItem` | **`final class` ＋ private コンストラクタ**。コレクションは `List.copyOf` / `Set.copyOf` で防御的にコピーし、getter は不変ビューを返す。`record` をやめるのは、canonical constructor を非公開にできないためでもある（§2.6.1 の 3） |
| `SuggestHit` / `SuggestQuery` / `PopularWordsQuery` / `SuggestResult` ほか | `record` のままでよい。ただし**フィールドは配列ではなく `List` / `Set` とし、コンパクトコンストラクタで `List.copyOf` する** |
| `ScoringContext.queryEmbedding` / `ScoringPlan.VectorSimilarityFactor.queryVector` | **`float[]` を維持するが `record` をやめる**（§3.2）。ベクトルは次元数が大きく `List<Float>` のボクシングが割に合わないため、**コンストラクタと getter の両方で `clone()` する `final class`** とする。**これは意識的な例外であり、理由をシグネチャの近くに書く** |

---

## 3. 拡張点（spi）と補助型

**1 行インタフェースは 1 件もない。** すべての補助型はフィールドまで定義する（P3）。

### 3.1 `SuggestSource<I>` / `SourceContext`

**責務**: 「**入力 I** → `SuggestCandidate` の列」への変換のみ。**入力を取得する経路と実行の駆動は持たない。** 書き込み・集約・スコアリングは共通機構が担う。

```java
package org.codelibs.fess.suggest.spi;

/** 取り込み候補への変換 Adapter。I は「何を読み込むか」を表す入力型（D-24）。 */
public interface SuggestSource<I> {

    /** このソースが現在のコンテキストで供給可能か。 */
    default boolean supports(SourceContext ctx) { return true; }

    /** 入力を候補へ段階変換する。大量データでも全件をメモリに載せない。
     *  返す Stream は呼び出し側（共通の取り込み機構）が close する（§3.9.4）。
     *  Kind は返す SuggestCandidate.kinds が唯一の正である（D-30）。
     *  実装は SuggestCandidate.document(...) のみを使い、userBoost を指定しない（D-27）。
     *  roles を空にすると _guest_ が補われ、その語は全ユーザに見えるようになる（§3.1.3）。 */
    Stream<SuggestCandidate> produce(I input, SourceContext ctx);
}

/** 供給コンテキスト。現行 SuggestIndexer が保持する取り込み設定（`index/SuggestIndexer.java:180-184`）に対応する。
 *  「何を読み込むか」は入力 I が持ち、本型は「どう解釈するか」だけを持つ。 */
public record SourceContext(
        List<String> supportedFields,
        List<String> tagFieldNames,
        String roleFieldName,
        String langFieldName,
        List<String> languages,
        LongConsumer onProgress
) {}
```

#### 3.1.1 第 4 版の `SuggestSource` は実行できなかった（D-24・第 5 版で是正）

**第 4 版の `produce(SourceContext)` には「何を読み込むか」を渡す引数が無く、`SuggestIngestService` にも登録済みソースを実行するメソッドが無かった。** それにもかかわらず §2.4 は「QueryLog は `SuggestSource` を追加し合成点に登録するだけで載る」としていた。**この 3 つは同時に成立しない。**

**取りうる形は 2 つあり、本設計は前者を採る。**

| 案 | 形 | 判定 |
| --- | --- | --- |
| **(A) 変換 Adapter**（採用） | `SuggestSource<I>.produce(I, ctx)`。入力と実行は `SuggestIngestService.indexFrom(source, input, options)` が所有する | **採用。** 既定 2 ソースが**呼び出しごとに異なる入力**を要求するため、これ以外では成立しない（下記） |
| (B) pull source | `produce(ctx)` のまま。ソースが自分の読み込み先を構築時に持ち、`ingestRegisteredSources(ctx, options)` が全登録ソースを回す | **却下** |

**(B) を却下する決め手は既定の `DocumentSource` である** [確認]。fess は再構築のたびに `ESSourceReader` を新しく構築して渡す（`(fess) helper/SuggestHelper.java:251-253,272-274` が `Supplier<DocumentReader>` を毎回作る）。**読み込み先は構築時ではなく呼び出しごとに決まる**ため、`SuggesterBuilder` に登録した時点で入力が固定される (B) では既定ソースすら表現できない。`SearchWordSource` も同様に、呼び出しごとの `SearchWordInput` が入力である。

**この変更で `SuggestSource` は「登録するもの」から「駆動するもの」になる。** その帰結として、**`SuggesterBuilder` から任意ソースの追加登録メソッド（第 4 版の `addSource`）が消え、既定 2 ソースの差し替えメソッドだけが残る**（§3.9.1 / §3.9.2）。

**織り込まないもの**（C-11）: `SuggestSource` に**ソース別重み付けとマージ規則を組み込まない**（MIG-19 同義語/関連語・MIG-20 トレンド）。`supports()` と `produce()` だけを持ち、複数ソースの候補は共通のマージ規則（§3.4）と共通のスコアリング（§3.2）が処理する。ソース別重みを IF に入れると、MIG-19/20 の要件が固まっていない段階で「重みの合成規則」を先に決めることになり、決められない前提を設計に持ち込む。

#### 3.1.2 Kind の正は `SuggestCandidate` 側にある（D-30・第 6 版）

**第 5 版の `SuggestSource` は `kind()` を持ち、同時に `SuggestCandidate.document(...)` が `Set<Kind> kinds` を受け取っていた**（型名は第 7 版で `SuggestKind` へ — D-33）。この形では次が書けてしまう。

```java
class FooSource implements SuggestSource<X> {
    Kind kind() { return Kind.DOCUMENT; }                       // 宣言
    Stream<SuggestCandidate> produce(X in, SourceContext ctx) {
        return Stream.of(SuggestCandidate.document(..., Set.of(Kind.QUERY)));   // 実値
    }
}
```

**「このソースが供給する Kind」を宣言させておきながら、その宣言と候補の実値が一致することを誰も保証していなかった。** これは D-27 が `userBoost` について解消した「2 つの正」と同じ形の問題である（危険度は低いが、性質は同じ）。

**採る形: `kind()` を削除し、`SuggestCandidate.kinds` を唯一の正とする。**

| 選択肢 | 判定 |
| --- | --- |
| **(A) `kind()` を削除し Candidate を唯一の正とする**（採用） | **採用。** `SuggestCandidate` は D-19 で「それ自体で完結した更新の意思」として定義された型であり、Kind もその一部である。**削っても失われる情報が無い** — 第 5 版の本書内で `kind()` を読む記述は 1 つも無く、取り込み経路も検索経路も `SuggestItem.kinds`（＝ Candidate 由来）しか見ない |
| (B) `kind()` を正とし、`indexFrom` が Candidate に Kind を付与する | 却下。**1 ソースが複数 Kind を供給できなくなる**。既定 2 ソースは単一 Kind だが、MIG-19（同義語/関連語）は将来 `QUERY` と `DOCUMENT` の両方を返しうる。拡張点を先に狭める |
| (C) 両方残し `indexFrom` が一致を検査する | 却下。**冗長な宣言を残したまま実行時検査を足すだけ**であり、実装者が同じ情報を 2 箇所に書く状態は解消しない |

- **既定 2 ソースの Kind は「型が宣言する属性」ではなく「実装が返す値」になる。** `DocumentSource` は `SuggestKind.DOCUMENT` を含む候補を、`SearchWordSource` は `SuggestKind.QUERY` を含む候補を返す（§3.9.2）。この対応は現行 `index/contents/DefaultContentsParser.java` の 2 経路がそれぞれ固定の Kind で `SuggestItem` を組み立てているのと同じ形である [確認]。
- **`SuggestIngestService.deleteByKind(Kind)`（§2.4）は影響を受けない。** 削除条件は保存済みドキュメントの `kinds` フィールドに対する述語であり（§3.6 の表）、ソースの宣言とは無関係である。
- **`WordCountStats.byKind`（§2.2）も影響を受けない。** 集計対象は同じく保存済みドキュメントの `kinds` である。

#### 3.1.3 `SuggestSource` 実装に対する `roles` の契約（第 7 版）

**`roles` の合成規則は集合和であり、緩む方向にしか動かない**（`0002` K-2）。**したがって、1 つのソースが `roles` を空で返しただけで、その `text` は以後すべてのユーザに見える。**

```text
DocumentSource が "設計会議議事録" を roles = [role_A] で供給   → 見えるのは role_A のみ
FooSource      が同じ text を roles = [] で供給                 → _guest_ が補われる
                                                               → 集合和により roles = [role_A, _guest_]
                                                               → 以後、全ユーザに見える
```

**`_guest_` の補完位置** [確認]: 現行は `entity/SuggestItem.java:121-126` が `roles` が null または空のときに `SuggestConstants.DEFAULT_ROLE`（`SuggestConstants.java:40` の `_guest_`）を入れる。新設計でこの補完がどこに残るかは `0002` §5.3 の合成規則側の決定である。

**採る契約**:

> 1. **`SuggestSource` の実装は、供給する語のアクセス制御が「全ユーザに公開」でない限り、`roles` を明示的に与えなければならない。**
> 2. **`roles` を空で返すことは「全ユーザに公開してよい」という積極的な宣言である。** 「分からないので空にする」は契約違反である。
> 3. **ライブラリはこれを検査しない。** 空の `roles` は正当な入力（実際に公開してよい語）と区別がつかないためである。

- **これは §7.2 のデフォルト deny と矛盾しない。** §7.2 が保証するのは**検索側**（ロール未指定の呼び出しで全件が出ないこと）であり、**取り込み側で語に付与される `roles` の広さ**は別の話である。**両者を混同すると「デフォルト deny だから安全」と読めてしまう**ため、ここに分けて書く。
- **この危険は第 5 版の D-24 で増えた。** `indexFrom` を公開したことで供給元を足しやすくなり、**`roles` を意識しない実装が同一 `text` に `_guest_` を混ぜる経路が増える**。K-2 は既知の制約として `0002` §8 にあるが、**「後続スコープ」として流すのではなく、メジャー版のリリース判断項目として明示する**（§7.4 / `0000` §9C.4）。

### 3.2 `ScoringStrategy` / `ScoringContext` / `ScoringPlan`

**責務**: 検索時 function score 単系統の構成を組み立てる。OpenSearch の型は返さない（`SuggestStore` が `ScoringPlan` を翻訳する）。

```java
public interface ScoringStrategy {

    /** サジェスト検索のスコアリング構成を組み立てる。 */
    ScoringPlan plan(SuggestQuery query, ScoringContext ctx);

    /** 人気語取得のスコアリング構成を組み立てる。検索とは別系統である（下記の [確認] を参照）。 */
    ScoringPlan planForPopularWords(PopularWordsQuery query, ScoringContext ctx);
}

/** スコアリングの入力。queryEmbedding が可変配列を持つため record ではなく final class とし、
 *  コンストラクタと getter の両方で clone する（D-20 の例外規定 — §2.6.5）。 */
public final class ScoringContext {

    private final String normalizedQuery;
    private final List<String> queryTerms;
    private final boolean singleWordQuery;    // `request/suggest/SuggestQueryBuilder.java:174-177`
    private final boolean hiraganaQuery;      // 同 `:184-186`
    private final List<String> languages;
    private final float[] queryEmbedding;     // MIG-24: ベクトル類似度の加点入力。null 可

    /** 埋め込みベクトルの複製を返す。empty は「ベクトル検索を行わない」を意味する。 */
    public Optional<float[]> queryEmbedding() { /* clone して返す */ }
    // 他 getter 群（コレクションは不変ビュー）
}

/** スコアリング構成。現行 `request/suggest/SuggestQueryBuilder.java:141-167` の function score を型で表現したもの。 */
public record ScoringPlan(List<ScoringFactor> factors, CombineMode combineMode, ScoreMode scoreMode,
                          Optional<RandomRescore> rescore) {

    /** ランダム rescorer。人気語のシャッフルに使う。 */
    public record RandomRescore(String seed, String field, int windowSize,
                                float queryWeight, float rescoreQueryWeight) {}

    /** 加点要素。sealed により実装が取りうる要素を閉じる。 */
    public sealed interface ScoringFactor
            permits FieldValueFactor, MatchFactor, FuzzyMatchFactor, VectorSimilarityFactor {}

    /** 数値フィールドの値による加点（docFreq / queryFreq / userBoost）。 */
    public record FieldValueFactor(String field, float missing, Modifier modifier, float weight)
            implements ScoringFactor {}

    /** 完全一致・前方一致による加点。 */
    public record MatchFactor(MatchKind kind, String field, String value, float weight)
            implements ScoringFactor {}

    /** あいまい一致による加点。MatchFactor と別型にすることで、完全一致と混同せず低重みを与えられる（MIG-21）。 */
    public record FuzzyMatchFactor(String field, String value, int maxEdits, int prefixLength, float weight)
            implements ScoringFactor {}

    /** ベクトル類似度による加点（MIG-24）。ScoringContext.queryEmbedding を入力とする。
     *  可変配列を持つため record ではなく final class とし、コンストラクタと getter で clone する（§2.6.5）。 */
    public static final class VectorSimilarityFactor implements ScoringFactor {
        private final String field;
        private final float[] queryVector;
        private final float weight;
        public float[] queryVector() { /* clone して返す */ }
        // 他 getter 群
    }

    /** 完全一致と前方一致の区別。 */
    public enum MatchKind { EXACT, PREFIX }

    /** 数値の変換方法。 */
    public enum Modifier { NONE, LOG2P }

    /** クエリスコアと加点の合成方法。 */
    public enum CombineMode { MULTIPLY, SUM, REPLACE }

    /** 加点要素どうしの合成方法。 */
    public enum ScoreMode { MULTIPLY, SUM, MAX }
}
```

**拡張予約がシグネチャで検証できること**（C-11）:

| 機能 | シグネチャ上の受け口 | 現行との対応 |
| --- | --- | --- |
| MIG-24 ベクトル | `ScoringContext.queryEmbedding` で受け取り、`VectorSimilarityFactor` で加点する | 現行に相当物なし。`0003` の `knn_vector` 後付け手順と対 |
| MIG-21 fuzzy | `FuzzyMatchFactor` が `MatchFactor` と**別型**であり、独立した `weight` を持つ | 現行の前方一致加点（`SuggestQueryBuilder.java:146-147`、weight = `prefixMatchWeight`）は `MatchFactor(PREFIX, ...)` に写る |
| 死蔵 score 不参照 | `FieldValueFactor.field` に取れるのは `docFreq` / `queryFreq` / `userBoost`。`score` は `0002` の mapping から消えるため参照先が存在しない | `SuggestQueryBuilder.java:150-159` と同じ 3 要素 |

**人気語が別系統のスコアリングを持つことを本ステップのコード実査で確認した** [確認]。`request/popularwords/PopularWordsRequest.java:232-235` は `queryFreq` の `fieldValueFactorFunction`（`missing(0)`・`boostMode(REPLACE)`）のみを使い、サジェスト検索の 4 要素（`SuggestQueryBuilder.java:146-159`）とは構成が異なる。さらに `:244` の `randomFunction().seed(seed).setField("_seq_no")` による rescorer を `:182` で `windowSize` 付きで適用する。この 2 系統目を `ScoringStrategy` が扱えないと、人気語のスコアリングだけが抽象化の外に残り MIG-11 が半分しか達成されない。したがって `planForPopularWords` を別メソッドとして持ち、`ScoringPlan.rescore` に rescorer を表現する。`RandomRescore.field` を引数に持つのは、現行が `_seq_no` を使っている（`:244`）ことを設計に固定しないためである。

**`ScoringStrategy` の拡張可能範囲を取り違えないこと**（第 4 版で明文化）。`ScoringPlan.ScoringFactor` は `sealed` であり、実装が取りうる加点要素は `FieldValueFactor` / `MatchFactor` / `FuzzyMatchFactor` / `VectorSimilarityFactor` の **4 種に閉じている**。したがって:

> **`ScoringStrategy` は「任意のスコアリング方式を後から追加する」ための SPI ではない。ライブラリがあらかじめサポートする scoring vocabulary（上記 4 種）の組み合わせ・重み・合成方法を差し替えるための SPI である。**

- **これは意図的な制約である。** 任意の方式を許すには OpenSearch の DSL を公開面に露出させるしかなく、`api` / `spi` が OpenSearch の型を出さないという §1 の規約と衝突する。`sealed` を外して外部実装の `ScoringFactor` を許すと、それを翻訳できない `SuggestStore` 実装が実行時に落ちる。
- **語彙そのものを増やす変更は本 IF の利用者ではなくライブラリ側の改訂である。** `permits` 節への追加と `SuggestStore` 実装の翻訳追加が対になる（`FuzzyMatchFactor` / `VectorSimilarityFactor` を C-11 の予約として**先に語彙へ入れてある**のはこのためである）。
- 「拡張点」という語から期待される自由度と実際の自由度を一致させるため、**この段落を `ScoringStrategy` の Javadoc にも書く**。

**`ScoringContext` に汎用の属性マップ（`Map<String,Object>`）を置かない** [提案]。任意属性の受け口は事実上「検索コンテキストの予約」であり、C-11 が明示的に**織り込まない**と決めた MIG-22（パーソナライズ）をシグネチャで先取りすることになる。プライバシー要件が未確認のまま拡張点だけ開けない。

### 3.3 `TextProcessor` / `ProcessedText` / `TextProcessingContext`

**責務**: 「テキスト → 正規化テキスト・トークン・読み」への変換を Chain で合成する。現行の `normalizer/` `converter/` `analysis/` を統一抽象化する（MIG-12 は踏襲の明文化であり、実装の置換ではない）。

```java
public interface TextProcessor {

    /** このプロセッサが当該コンテキストを扱えるか。言語別実装の選択に使う（MIG-23）。 */
    default boolean supports(TextProcessingContext ctx) { return true; }

    /** テキストを処理する。Chain の各段は前段の出力を入力として受け取る。 */
    ProcessedText process(String input, TextProcessingContext ctx);
}

/** 処理結果。readings は「トークンごとの読み候補リスト」であり、現行 `String[][]`（`entity/SuggestItem.java:81`）に対応する。 */
public record ProcessedText(String normalized, List<String> tokens, List<List<String>> readings) {}

/** 処理コンテキスト。 */
public record TextProcessingContext(String field, List<String> languages, Direction direction) {

    /** ドキュメント側とクエリ側の二系統。現行の readingConverter / contentsReadingConverter に対応する。 */
    public enum Direction { DOCUMENT, QUERY }
}
```

- `Direction` は現行 `Suggester` コンストラクタ（`Suggester.java:138-140`）が `readingConverter` と `contentsReadingConverter` の 2 本を受け取っている構造を型に写したものである [確認]。
- **MIG-23 多言語**: `supports(ctx)` が `ctx.languages()` を見て真偽を返すことで、言語別実装を Chain に**追加**できる。既存実装を差し替える必要がない。
- **MIG-21 誤字正規化**: `normalized` を書き換える `TextProcessor` を Chain に 1 段足すだけで載る。`ProcessedText` に新しいフィールドを追加しない。
- `ReadingConverter#getMaxReadingNum`（`converter/ReadingConverter.java:31-33`、既定 10）は **1 語あたりの読み候補数**の上限であり、`ProcessedText.readings` の**内側**のリスト長に効く。外側のリスト長（＝トークン数）の上限は本 IF では規定しない（`0002` §2 の語数上限が正 — U3）。E-01 / E-02 を参照。

### 3.4 `SuggestItemMergePolicy`

**責務**: マージ規則を 1 箇所に持つ。同一バルク内のマージと既存ドキュメントとのマージを同一規則で行う（MIG-01 / ISS-05）。
**呼び出し元**: `internal` の取り込み経路のみ（§3.7.1 の畳み込みループ）。**`SuggestStore` は本 IF を受け取らない**（第 7 版 / D-31）。

```java
public interface SuggestItemMergePolicy {

    /** 既存ドキュメントが無い場合の初期値を決める。
     *  excluded は取り込み時点の bad word 集合から呼び出し元が判定した値である（D-32 / §3.5.2）。 */
    SuggestItem initialize(SuggestCandidate incoming, boolean excluded);

    /** 既存ドキュメントと取り込み候補を合成する。excluded は existing の値を保持する（U4）。 */
    SuggestItem merge(SuggestItem existing, SuggestCandidate incoming);
}
```

**`initialize` が `excluded` を引数で受けるのは第 7 版の変更である**（D-32）。理由は 3 つある。

| # | 理由 |
| --- | --- |
| 1 | **`SuggestCandidate` に `excluded` を持たせないという D-17 を維持したまま、新規語の初期除外を表現できる唯一の形である。** 候補側にフィールドを足すと、`index(List<SuggestCandidate>)` の呼び出し元が任意に除外を指定できてしまう |
| 2 | **`SuggestItemMergePolicy` が `BadWordPolicy` を参照しなくて済む。** 既定実装がもう一方の SPI を保持すると、`badWordPolicy(...)` を差し替えたときに `mergePolicy(...)` 側の既定実装が古い参照を握る、という組み合わせ依存が生じる。**判定を呼び出し元（取り込み経路）が済ませて値だけ渡す形なら、2 つの SPI は互いを知らない** |
| 3 | **`merge` 側は引数が要らない。** 既存ドキュメントがある場合の `excluded` は `existing` の値を保持する（U4）ためであり、**「新規語だけが bad word 判定を受ける」という非対称がシグネチャに現れる**。既存語の除外・解除は `SuggestWordAdmin` の経路（`updateExcluded`）が行う（§2.3） |

> **引数と戻り値の型が非対称であることが本 IF の要点である**（第 4 版 / D-19）。入力は「更新したいこと」（`SuggestCandidate`）、出力は「保存される完全状態」（`SuggestItem`）であり、**合成とは前者を後者へ畳み込む操作**である。第 3 版は両側とも `SuggestItem` で、「incoming の `excluded` は無視する」「incoming の `userBoostSpecified` を見る」といった**読み飛ばし規約**を実装側の規律に委ねていた。非対称にすると、無視すべき属性がそもそも引数の型に存在しない。

> **挙動の正は本書ではなく `0002` §5.3 にある。** 本書はシグネチャのみを確定する（作業プラン §4「5-3 で挙動を決め 3-3 が従う」）。以下は**シグネチャに対する要求**であって、合成規則の決定ではない。

| 要求 | シグネチャ上の対応 | 根拠 |
| --- | --- | --- |
| `excluded` は既存値を保持し、既存に無い場合のみ `false` で初期化する | 「既存なし」の分岐を `initialize` として**別メソッドに分けている**ため、`merge` が `excluded` を existing から引き写す実装を書ける。1 メソッドで `existing == null` を許すと両者が同じコードパスに混ざる。**加えて `SuggestItem`（戻り値）が `excluded` を保持し、`SuggestCandidate`（引数）が保持しない**（D-17）。戻り値が全置換で書かれる以上、型に無い属性は書き込む source に載らない。**「incoming の `excluded` を無視する」という規約が不要になる** | U4 / `0002` §5.6 |
| elevate word の `userBoost` が通常取り込みで潰れない | `merge(existing, incoming)` が**両方の値を受け取る**。現行 `entity/SuggestItemSerializer.java:181` は既存値を参照せず新値で無条件上書きしており、この形では表現できない片側書き込みだった。**「指定あり／なし」の判別は `SuggestCandidate.userBoost()` が `OptionalDouble` であること**（D-16）で足りる | P13 / U5 / F-06 ③ |
| 走査基準の単一化（`reading_i` の消滅を防ぐ） | `merge` が単一の実装内で W を 1 回だけ計算するため、走査基準は実装内部の 1 箇所に閉じる。現行は `entity/SuggestItemMerger.java:70` と `entity/SuggestItemSerializer.java:60,147` と同 `:87-95` の 3 通りに割れている | MIG-01 / F-04 |

**`SuggestItem.merge(SuggestItem, SuggestItem)`（`entity/SuggestItem.java:446-448`、static メソッド）と `entity/SuggestItemMerger` は本 IF の実装へ移設し、エンティティから合成ロジックを外す。**

### 3.5 `BadWordPolicy`

**責務**: bad word の**唯一の判定規則**を持ち、bad word 集合の所有者になる。

```java
public interface BadWordPolicy {

    /** 正規化済みテキストが bad word に該当するか。
     *  新規語の excluded 初期値の判定と、既存語への excluded 付与の唯一の判定規則（D-32）。 */
    boolean isBadWord(String normalizedText);

    /** 指定 bad word に該当する既存語を選び出す条件。excluded の付与とドライランが共有する。 */
    QueryCondition matchCondition(String normalizedBadWord);

    /** removed に該当し、かつ現在の bad word 集合のいずれにも該当しない語を選ぶ条件（D-25）。
     *  excluded の解除に使う。remove(removed) の「後」に呼ぶこと。 */
    QueryCondition releaseCondition(String removedBadWord);

    /** bad word が集合に含まれる状態にする。集合の更新と再読み込みを内包する。
     *  既に含まれる場合は何もせず成功する（再実行可能。D-29）。 */
    void add(String badWord);

    /** bad word が集合に含まれない状態にする。集合の更新と再読み込みを内包する。
     *  既に含まれない場合は何もせず成功する（再実行可能。D-29）。 */
    void remove(String badWord);

    /** 現在の bad word 集合のスナップショット。 */
    List<String> badWords();
}
```

**単一規則の中身**: **正規化後テキストの部分一致（部分文字列の包含）** とする。

これは設計上の選択ではなく、**提案書が要件レベルで [確定] させている前提の踏襲である** [確認]。

| 出典 | 記述 |
| --- | --- |
| `improvement-proposal.md:380`（**MIG-03 の定義そのもの**） | 「bad word マッチ規則の統一（**部分一致を 1 `BadWordPolicy` に**、`contains`/`wildcard` 乖離・メタ文字誤爆を解消）」 |
| 同 `:499`（§5.2 の [確定] 行の前提節） | 「**部分一致は要件どおり維持（全て bad word 扱い）を前提に**」 |
| 同 `:211`（Q3） | 「**部分一致（要件どおり全て bad word 扱い）を維持したまま**、不可逆な巻き添え物理削除を可逆な論理除外に置換。マッチ実装の二重化も解消」 |
| 同 `:132`（ISS-04 本文） | 「※**部分一致自体は要件上「意図した挙動」であり課題ではない**」 |

**ISS-04 が課題と認定したのは「不可逆性」と「実装の二重化・メタ文字誤爆」であって、部分一致という判定意味論ではない。** 本設計書の職務は MIG-03 を実装することであり、その定義を再解釈することではない。判定意味論を変える場合は提案書側の訂正とユーザー判断を要するため、**変えない**。

現行は同じ「部分一致」という意味論が 2 つの実装に分かれている [確認]。**規則が 2 つあるのではなく、1 つの規則が 2 箇所で別々に実装されていることが問題である。**

| 経路 | 現行の実装 | 位置 |
| --- | --- | --- |
| 取り込み時フィルタ（**新設計では `excluded` 初期値の判定** — D-32） | `text.contains(badWord)`（Java のメモリ内判定） | `entity/SuggestItem.java:455-462`。呼び出しは `index/operations/IndexingOperations.java:78` |
| `apply=true` の物理削除 | `wildcardQuery(text, "*" + normalized + "*")`（ストア側判定。**未エスケープ**） | `index/operations/WordManagementOperations.java:81` |

**解消の形**: `BadWordPolicy` が「部分一致」という**意味論を単独で所有**し、`isBadWord`（メモリ内判定）と `matchCondition`（ストア問い合わせ条件）の**両方を同一クラスから導出する**。実装が 2 つあること自体は避けられない（片方は Java の文字列判定、もう片方は OpenSearch のクエリ）が、**同じクラスの中で対になって定義されるため、片方だけが変更されて乖離する状態が構造的に起きない**。これが ISS-04 の (b)「`contains`/`wildcard` 二重化に伴う保守負担」の解消である。

**`matchCondition` の実装方式: エスケープ済みワイルドカード**（`QueryCondition.SubstringPredicate` — §3.6）とする [提案]。判断の根拠は `text` フィールドの mapping 型である [確認]。

- `(res) suggest_indices/suggest/mappings-default.json:42-44` により **`text` は `keyword` 型**であり、解析されない。したがって `match_phrase` 等のトークン列一致は使えない（トークンが 1 つしか無く、部分文字列に一致しない）。
- `keyword` フィールドに対する部分文字列一致は、**`wildcard` クエリ（`*value*`）が唯一の現実的な手段**である。`wildcard` 型フィールドや ngram サブフィールドの追加は mapping の変更を伴い、MIG-03 が「スキーマ変更なしの局所変更」であるという位置づけ（`improvement-proposal.md:380` の「なし/小」）を崩す。
- したがって **`*` と `?` のエスケープが必須**になる。

**F-09（wildcard の未エスケープ）の解消**: **エスケープを規則の内側に必須化する。** `BadWordPolicy` の契約として次を定める。

1. `matchCondition(normalizedBadWord)` が返す `SubstringPredicate.value` は、**呼び出し側から見て常にリテラル**である。値に `*` / `?` が含まれていても、その語そのものを含む語だけが一致する。
2. メタ文字のエスケープは `BadWordPolicy` の実装（およびそれを翻訳する `SuggestStore` 実装）の責務であり、**呼び出し側にエスケープを要求しない**。エスケープを呼び出し側の規律に委ねると F-09 が再発する。
3. `isBadWord` の Java 側判定（`String.contains` 相当）はメタ文字を解釈しないため、**エスケープ後のワイルドカード判定と結果が一致する**。この一致がテストで検査すべき不変条件である（§10 の申し送り 2）。

**`util/SuggestUtil.java:398-400` の `escapeWildcardQuery`（`*` → `\*` / `?` → `\?`）は `BadWordPolicy` 実装に取り込む。** 現行は利用箇所ゼロだが（本ステップで再確認 [確認]）、この設計では**必ず呼ばれる経路に入るため死蔵ではなくなる**。

> **`text` の mapping 型への依存**: 上記の実装方式は `text` が `keyword` であることに依存している。`0002` §2 の To-Be mapping で `text` の型を変える場合（解析フィールドやサブフィールドを足す場合を含む）、`matchCondition` の実装方式を選び直す必要がある。§10 の申し送り 9 として登録する。
>
> **normalizer への依存**: 上記 3 の等価性は、さらに **`text` に keyword normalizer が設定されていないこと**に依存する [確認]（現行 mapping には normalizer / analyzer の指定が 1 件も存在しない）。normalizer があると OpenSearch 側は正規化後の索引値に対して照合する一方、`isBadWord` は正規化前の Java 文字列を見るため、**両判定が乖離しうる**。§10 の申し送り 10 として `0002` に引き渡す。

**F-08（キャッシュ更新の非対称）の解消**: bad word 集合の所有者を `BadWordPolicy` に一本化し、`index/SuggestIndexer.java:124` の `protected String[] badWords` フィールドキャッシュを**廃止**する。現行は `addBadWord` が `:398` で `settings.badword().get(true)` を呼び直す一方、`deleteBadWord`（`:406-409`）は呼び直さないため、削除しても indexer が古い配列でフィルタし続ける。`add` / `remove` が集合更新を内包する設計では、更新箇所が 1 つしかないため**非対称が起きようがない**。呼び出し側にキャッシュ更新の責務を残さないことが解消の本体である。

#### 3.5.1 解除は「該当しなくなった語」に限る（D-25・第 5 版）

**判定規則が部分一致である以上、1 つのサジェスト語が複数の bad word に同時に該当しうる。** 第 4 版は付与と解除の両方に `matchCondition` を使う設計だったため、**重複マッチの解除が壊れていた**。

| 状態 | bad word 集合 | `foobar` の `excluded` |
| --- | --- | --- |
| 初期 | `{}` | `false` |
| `addBadWord("foo")` | `{foo}` | `true` |
| `addBadWord("bar")` | `{foo, bar}` | `true` |
| **`deleteBadWord("foo")`** | `{bar}` | **第 4 版: `false`（誤り）／ 第 5 版: `true`** |

**第 4 版が誤るのは、`updateExcluded(matchCondition("foo"), false)` が「`foo` を含む語」を一律に解除するためである。** `foobar` はまだ `bar` に該当しており、除外を維持しなければならない。

**採る規則**:

> **`releaseCondition(removed)` ＝ `mustContain(text, removed)` かつ `mustNotContain(text, b)` for all b ∈ （削除後の bad word 集合）**

`QueryCondition.mustNotContain` は第 5 版で追加した述語である（§3.6）。`deleteBadWord` の実装手順は次のとおりで、**順序に意味がある**。

| # | 手順 |
| --- | --- |
| 1 | `policy.remove(word)` — bad word 集合から削除する（設定インデックスの更新を含む） |
| 2 | `store.updateExcluded(policy.releaseCondition(word), false)` — **削除後の集合**に照らして解除する |

**順序を逆にすると `releaseCondition` が削除前の集合を見て、`removed` 自身が `mustNotContain` に入り、条件が充足不能になる**（1 件も解除されない）。この順序制約は `releaseCondition` の Javadoc に書く。

> **2 が失敗した場合は部分適用状態が残る**（D-29・第 6 版）。1 は設定インデックス、2 は suggest インデックスへの別リクエストであり、分散トランザクションにしない。**手順 2 の条件が「削除後の集合」から毎回**再計算**されるため、`deleteBadWord(word)` をそのまま再実行すれば正しい状態へ収束する** — 1 は集合に `word` が無ければ何もせず成功し、2 は現在の集合で条件を組み直す。契約と収束表は §2.3.1 にある。

**却下した代替案**:

| 案 | 却下理由 |
| --- | --- |
| **解除 → 残りの bad word で再付与の 2 パス** | 2 パスの間に**除外されるべき語が検索に現れる窓**ができる。`updateExcluded` は 1 回の update-by-query であり、1 パスにすればこの窓が無い |
| **`excluded` を boolean ではなく「該当する bad word のリスト」にする** | 正確ではあるが、`0002` §6.2 の除外フィルタ（`mustNot(term(excluded, true))`）が `exists` 判定に変わり、**旧世代ドキュメント共存（DM-14）の前提が崩れる**。データモデルの変更コストが解除の正確さに見合わない |
| **解除しない（`excluded` は一方向）** | C-02 が「可逆な論理除外」を選んだ理由に反する |

> **`mustNotContain` の項数は bad word の登録数に比例する。** 大量登録時に 1 クエリの述語数が増えるため、**実装は上限を持たずに素直に組み立て、性能上の問題が観測された時点で対処する**（C-04 により本設計は性能実測を行わない）。付与（`addBadWord`）側は 1 述語のままであり影響を受けない。

#### 3.5.2 取り込み時 drop を廃止する（D-32・第 7 版）

**第 6 版は「取り込み時フィルタ（drop）」と「`excluded` フラグ」を目的の違う 2 つの手段として両方残していた。第 7 版でこれを 1 つにする。**

##### 第 6 版が抱えていた矛盾 [確認]

| 出典 | 記述 |
| --- | --- |
| `0000` §5 の **C-02** | bad word の適用方式は「**即時・可逆な論理除外**（`excluded` フラグ）」。①物理削除は明示オプションとしても残さない |
| 第 6 版 本節 | `isBadWord` による取り込み時フィルタの目的は「**新規流入の防止**」／ `excluded` の目的は「**既存語**の論理除外（可逆）」 |
| 第 6 版 `0002` §6 の表 ② | 取り込み時のフィルタ除外は「**維持**」 |

**この 3 つを合わせると、bad word の適用は「既存語については可逆・新規流入については不可逆」という非対称になる。**

```text
bad word 集合 = {foo}
  → 検索ログから "foobar" が 100 回入る
  → isBadWord("foobar") == true なので 100 回とも捨てられる（ドキュメントが作られない）
deleteBadWord("foo")
  → releaseCondition("foo") が選ぶ対象そのものが存在しない
  → 100 回ぶんの queryFreq は復元されない
```

**C-02 が物理削除（①）を却下した理由は不可逆性そのものだった**（`0002` §6 の「現行 ① は不可逆であり、`deleteBadWord` は削除済みドキュメントを復元しない」）。取り込み時 drop は、同じ不可逆性を**別の入口に残していた**にすぎない。

##### 採る形

> **bad word に該当する新規候補も保存する。ただし `excluded = true` を初期値として保存する。**

| 経路 | 第 6 版 | **第 7 版** |
| --- | --- | --- |
| 既存語 ＋ `addBadWord` | `excluded = true`（可逆） | 同左（変更なし） |
| 既存語 ＋ `deleteBadWord` | `releaseCondition` で `false` へ（可逆） | 同左（変更なし） |
| **新規候補が bad word に該当** | **drop（不可逆）** | **`excluded = true` で保存（可逆）** |
| 既存語（`excluded` 既設定）への再取り込み | 該当すれば drop され、既存の `excluded` は変わらない | **`merge` が `existing.excluded` を保持**（U4。変更なし） |

**実装位置**: 取り込み経路（`internal`。§3.7.1 の畳み込みループ）が、既存ドキュメントが無い候補についてのみ `policy.isBadWord(text)` を評価し、その結果を `SuggestItemMergePolicy.initialize(candidate, excluded)` へ渡す（§3.4）。**現行 `index/operations/IndexingOperations.java:78` が配列から要素を取り除いていた位置が、そのまま「初期値を決める位置」に変わる。**

##### この形が満たすもの

| # | 性質 |
| --- | --- |
| 1 | **C-02 の「可逆」が全ドキュメントについて文字どおり成立する。** 「既存インデックス語に限る」という限定が不要になる |
| 2 | **`0002` DM-18 の同値関係（`excluded == true` ⇔ 現在の bad word 集合のいずれかに該当する）が、新規流入語についても成立する。** 第 6 版では「捨てられた語」がこの同値関係の外にいた |
| 3 | **`deleteBadWord` の後、`foo` を含む語に蓄積された `queryFreq` / `docFreq` がそのまま復活する。** 検索ログ由来の頻度履歴が失われない |
| 4 | **モデルが 1 つになる。** 「drop されたのか、除外されているだけなのか」を運用者が区別する必要が無くなり、`previewBadWordImpact`（MIG-13）の件数が唯一の実態を表す |

##### 代償と、それをどう扱うか

**代償は、bad word に該当する語がインデックスに残り続けることである。** 全件再構築でも drop されないため、**定常状態のドキュメント数は「bad word に該当する語の全集合」ぶん多くなる**（第 6 版のモデルでは 0 だった）。

| 影響 | 扱い |
| --- | --- |
| **検索レイテンシ** | **除外フィルタ `mustNot(term(excluded, true))` は第 6 版から変わらない**（`0002` DM-14）。増えるのは転置索引の規模であって述語の数ではない。実測は C-04 によりスコープ外であり、`0002` §6.4 の計測申し送りに合流する |
| **ディスク使用量・再構築時間** | 増える。増分の大きさは bad word の登録数と部分一致の広さに依存し、**実測に依存する**（C-04） |
| **削除したい運用への手当て** | **`deleteByCondition` に `mustMatchAny("excluded", ["true"])` を渡す**（§2.4 / §3.6）。**「可逆が既定・物理削除は運用が明示的に選ぶ」という形になり、C-02 の「①物理削除は明示オプションとしても残さない」とは矛盾しない** — C-02 が禁じたのは *bad word の適用方式として* 物理削除を選ぶことであり、汎用の条件付き削除でインデックスを掃除する運用まで禁じてはいない。運用手順は `0003` §12.1 |

##### 却下した代替案

| 案 | 却下理由 |
| --- | --- |
| **drop を維持し、C-02 を「既存インデックス語の可逆な論理除外」に狭める** | 文書間の整合は取れるが、**中心モデルに非対称が残る**。「除外は可逆である」と「一部は不可逆である」を運用者が両方覚える必要があり、`previewBadWordImpact` の件数も「これから除外される語」しか表さない（既に捨てられた語は数えられない）。**せっかく物理削除を論理除外に置換するのに、入口の不可逆性だけが残る** |
| **drop を維持し、失われるのは検索ログ由来の頻度だけだと注記する**（文書由来の語は次回の全件再構築で復活する） | **事実としては正しいが、契約としては書けない。** 「いつ復活するか」が再構築の実行間隔に依存し、`Kind` によって可逆性が違う（`QUERY` は永久に失われ、`DOCUMENT` は次回再構築で戻る）。**型によって意味が変わる契約は、API の説明として成立しない** |
| **`excluded = true` で保存したうえで、全件再構築のときだけ drop する** | 再構築を境に不可逆性が発生する。**「再構築を跨ぐと bad word の解除が効かなくなる」という、第 6 版より発見しにくい形の非対称になる** |
| **`SuggestCandidate` に `excluded` を持たせ、呼び出し元が指定する** | D-17 に反する。取り込み経路から任意に除外を設定できるようになり、`excluded` の権威が `SuggestWordAdmin` 以外に増える |

### 3.6 `AuthorizationFilter` / `QueryCondition`

```java
public interface AuthorizationFilter {

    /** ロール集合から権限条件を組み立てる（_guest_ 補完を含む）。null・空でも全件露出しない。 */
    QueryCondition toCondition(List<String> roles);

    /** レスポンスに roles を含めてよい呼び出しかを判定する（§5.3）。 */
    boolean canExposeRoles(AccessScope scope);
}

/** 構造化検索条件。OpenSearch の型を露出せずに権限条件・除外条件・削除条件を表す。 */
public record QueryCondition(
        List<TermsPredicate> mustMatchAny,
        List<TermsPredicate> mustNotMatchAny,
        List<SubstringPredicate> mustContain,
        List<SubstringPredicate> mustNotContain,   // D-25: いずれも含まない（bad word の解除条件）
        List<TimeRangePredicate> timeRanges
) {
    /** 指定フィールドが values のいずれかに完全一致する述語。 */
    public record TermsPredicate(String field, List<String> values) {}

    /** 指定フィールドが value を部分文字列として含む述語。
     *  value は常にリテラルとして扱われ、メタ文字のエスケープは実装側の責務である（§3.5）。 */
    public record SubstringPredicate(String field, String value) {}

    /** 時刻フィールドの範囲述語（gte 以上・lt 未満）。 */
    public record TimeRangePredicate(String field, Optional<Instant> gte, Optional<Instant> lt) {}

    /** 何にも一致しない条件（フェイルセーフ用）。 */
    public static final QueryCondition DENY_ALL = /* ... */;

    /** 2 つの条件の論理積。5 種の述語リストをそれぞれ連結する。権限条件と業務条件の合成に使う。 */
    public QueryCondition and(QueryCondition other) { /* ... */ }
}
```

`QueryCondition` が **5 種**の述語で足りることの根拠 [確認]:

| 用途 | 述語 | 現行の該当箇所 |
| --- | --- | --- |
| 権限フィルタ | `mustMatchAny(roles, [...roles, "_guest_"])` | `request/suggest/SuggestRequest.java:352-357` |
| `excluded` による除外 | `mustNotMatchAny(excluded, ["true"])` | C-02（`0002` §6） |
| **bad word の該当語選択（部分一致）** | **`mustContain(text, word)`** | §3.5。現行 `index/operations/WordManagementOperations.java:81` の `wildcardQuery(text, "*"+w+"*")` に対応する |
| **bad word 解除時の残存判定**（第 5 版で追加） | **`mustNotContain(text, b)` × 残る bad word 数** | §3.5.1（D-25）。**現行に対応する実装は無い**（現行の解除は設定から語を消すだけでドキュメントに触れない — `WordManagementOperations.java:91-93`） |
| 古い語の purge | `timeRanges(@timestamp, lt=T)` ＋ `kinds` の must / mustNot | `(fess) helper/SuggestHelper.java:305-315,321-331` |
| Kind 指定の削除 | `mustMatchAny(kinds, [kind])` | `index/SuggestIndexer.java:303,312` |
| **除外語の物理削除**（第 7 版で追加） | **`mustMatchAny(excluded, ["true"])`** | §2.4 / §3.5.2（D-32）。**述語の種類は増えない** — `excluded` による除外（上記 2 行目）が使う `mustNotMatchAny` と同じ `TermsPredicate` を向きだけ変えて使う |

- **リスト内の意味論**: `mustMatchAny` / `mustNotMatchAny` は「リストの各要素をすべて満たす」（要素**内**の `values` が OR、要素**間**が AND）。`mustContain` も同様に要素間 AND である。**`mustNotContain` は「リストのどれも含まない」＝ 要素間が AND（各否定の連言）** であり、`mustNotMatchAny` と同じ向きに読める。
- `DENY_ALL` は 5 リストのうち**充足不能な述語を 1 つ持つ**形で表す（例: `mustMatchAny(roles, [])` を「一致する値が存在しない」と解釈する）。空の `QueryCondition`（全リストが空）は「無条件」を意味し、`DENY_ALL` と取り違えないよう両者を明確に別物として定義する。
- `SubstringPredicate` を追加したことで **`SuggestStore` 実装の翻訳対象が 1 つ増える**（§3.7）。`mustNotContain` も同じ `SubstringPredicate` を使うため**翻訳規則は増えず、エスケープの必須化（§3.5 の F-09）がそのまま適用される**。`SuggestStore` の**シグネチャは変わらない** — `deleteByCondition` / `updateExcluded` / `preview` はいずれも `QueryCondition` を受け取る形のままである。

### 3.7 `SuggestStore`

**責務**: OpenSearch 直結を隔離する。世代・エイリアス・バルク書き込み・検索を抽象化し、実装のみが OpenSearch の型を知る。

```java
public interface SuggestStore {

    // --- lifecycle（§2.2 が委譲） ---
    /** インデックスが無ければ作成する。 */
    CompletableFuture<Boolean> createIfAbsent(IndexSchema schema);
    /** 次世代インデックスを作成し更新エイリアスを付け替える。
     *  付替フェーズは post-condition で判定する（D-23 / §2.2.3）。 */
    CompletableFuture<IndexGeneration> createNextGeneration(IndexSchema schema);
    /** 検索エイリアスを最新世代へ原子的に切り替える。 */
    CompletableFuture<Void> switchSearchAlias();
    /** 保持用エイリアスの付け替えと検索エイリアス切替を 1 リクエストで行う（D-21）。 */
    CompletableFuture<Void> switchSearchAliasRetainingPrevious();
    /** 検索エイリアスを保持用エイリアスの世代へ戻す（D-21）。更新エイリアスには触れない。 */
    CompletableFuture<Void> rollbackSearchAliasToPrevious();
    /** どのエイリアスも指していない世代を削除する。 */
    CompletableFuture<Void> removeDisabledGenerations();
    /** suggest インデックスのみを refresh する。 */
    CompletableFuture<Void> refresh();
    /** 検索エイリアスが指す物理インデックス名。 */
    CompletableFuture<String> currentIndexName();
    /** 3 エイリアスの解決結果（D-23）。上記のエイリアスを動かす 4 メソッドの post-condition 判定にも使う。 */
    CompletableFuture<AliasState> aliasState();
    /** 語数統計。 */
    CompletableFuture<WordCountStats> wordCountStats();

    // --- write（§2.4 / §2.3 が委譲） ---
    /** ID 指定で既存ドキュメントをまとめて読み出す。存在しない ID はキーに現れない（MIG-15 第 1 段）。 */
    CompletableFuture<Map<String, SuggestItem>> multiGet(List<String> ids);
    /** 合成済みの完全状態をバルク書き込みする（全置換 — `0002` §5.6）。合成は行わない（D-31 / §3.7.1）。 */
    CompletableFuture<IngestResult> bulkPut(List<SuggestItem> items);
    /** 条件に一致するドキュメントを削除する。 */
    CompletableFuture<DeleteResult> deleteByCondition(QueryCondition condition);
    /** 条件に一致するドキュメントの excluded を一括で更新する（論理除外の付与・解除）。 */
    CompletableFuture<WordOpResult> updateExcluded(QueryCondition condition, boolean excluded);
    /** 条件に一致する件数とサンプルを返す（ドライラン用。変更しない）。 */
    CompletableFuture<BadWordImpact> preview(QueryCondition condition, int sampleSize);

    // --- read（§2.1 が委譲） ---
    /** サジェスト検索。auth は権限条件、plan はスコアリング構成。 */
    CompletableFuture<SuggestResult> search(SuggestQuery query, ScoringPlan plan, QueryCondition auth);
    /** 人気語取得。plan は planForPopularWords が返した構成（rescorer を含みうる）。 */
    CompletableFuture<SuggestResult> popularWords(PopularWordsQuery query, ScoringPlan plan, QueryCondition auth);
}
```

**`QueryCondition` の翻訳は `SuggestStore` 実装の責務である。** 5 種の述語（§3.6）をストアのクエリへ写す際、**`SubstringPredicate` はエスケープ済みワイルドカードとして翻訳する**（`text` が `keyword` 型であるため。§3.5）。`SubstringPredicate.value` は常にリテラルとして扱い、値に含まれる `*` / `?` を実装側でエスケープする。この責務を `SuggestStore` 実装に置くのは、エスケープ規則がストアの問い合わせ言語に依存するためであり、`BadWordPolicy` 側では「リテラルである」という意味だけを保証する。

**post-condition による判定は `SuggestStore` 実装の内側に置く**（D-23・第 5 版／第 6 版で `createNextGeneration` を追加）。`switchSearchAlias` / `switchSearchAliasRetainingPrevious` / `rollbackSearchAliasToPrevious` ／ **`createNextGeneration`（付替フェーズのみ）** の 4 メソッドが、失敗時に自身で `aliasState()` 相当の再取得を行い、§2.2.2 の 5 段の手順を実行する。**`SuggestIndexLifecycle` 側は単純委譲でよい** — エイリアス名の生成規則とエイリアス API の呼び出しはどちらも `SuggestStore` 実装の中にあり、**判定だけを上位層に置くと、名前の知識が 2 層に分かれる**。**`createNextGeneration` の場合、判定に必要な「新世代の物理インデックス名」を知っているのも同じ実装内である**（名前の生成規則が `SuggestStore` 実装にあるため）。

**`SuggestStore` は永続化境界であり、合成規則を持たない**（第 7 版 / D-31。詳細は §3.7.1）。

> **`multiGet` は第 3 版で宣言が欠落していた**（第 4 版で補った）。§2.5 の本文は「ストアからの読み出し（`SuggestStore.multiGet` — §3.7）」と参照していたが、§3.7 のシグネチャ一覧に当該メソッドが無く、MIG-15 第 1 段（`prepareGet` N 回 → multiGet 1 回）の受け口が公開面に存在しなかった。**戻り値を `Map<String, SuggestItem>` とするのは、ID から完全状態を引く操作だからである**（`SuggestHit` ではない — D-19）。

#### 3.7.1 Store と MergePolicy の責務境界（D-31・第 7 版）

##### 第 6 版が閉じていなかったこと [確認]

| # | 事実 |
| --- | --- |
| 1 | **D-19 と §2.6 は「ストアの Put / Get は同じ `SuggestItem`」「`store.put(item)` が同一型で成立する」と書いていた** |
| 2 | **ところが `SuggestStore` に `SuggestItem` を書き込むメソッドは無かった。** GET は `multiGet(...) -> Map<String, SuggestItem>`、WRITE は `bulkUpsert(List<SuggestCandidate>, SuggestItemMergePolicy)` であり、**Get と Put の型が違った** |
| 3 | `SuggesterBuilder` は `mergePolicy(...)` と `store(...)` を**独立に差し替えられる**（§3.9.1）。ところが**任意の Java 製 `SuggestItemMergePolicy` を、Painless で合成する将来のストア実装が一般に実行する方法は存在しない** |
| 4 | 第 6 版は 3 に対して「**挙動を一致させるのは実装側の責務**」とだけ書いていた。**これは既定の 2 実装の組み合わせについてしか意味を成さず、利用者が書いたカスタム MergePolicy については実現不能な要求である** |

**すなわち、まだ存在しない第 2 段（`scripted_upsert`）のために、実現できない一般化を第 1 段の公開契約に持ち込んでいた。**

##### 採る形

> **`SuggestStore` は「完全状態を読む／完全状態を書く／条件で消す・更新する／検索する」だけを持つ。read-modify-write の組み立ては `internal` の取り込み経路が所有する。**

```text
SuggestIngestService.index / indexFrom（internal 実装）
  │
  ├─ 1. 候補を正規化し（TextProcessor）、text から ID を導出する（`0002` §4.1）
  ├─ 2. 同一 ID の候補をバッチ内で先に畳み込む
  ├─ 3. store.multiGet(ids)                          ← SuggestStore（読み出し）
  ├─ 4. ID ごとに畳み込む                              ← SuggestItemMergePolicy
  │       existing あり  : item = merge(existing, c1); item = merge(item, c2); ...
  │       existing なし  : item = initialize(c1, badWordPolicy.isBadWord(text));  // D-32
  │                        item = merge(item, c2); ...
  └─ 5. store.bulkPut(items)                          ← SuggestStore（書き込み）
```

- **4 の「existing なし」分岐が `initialize` を 1 回だけ呼ぶことが、`0002` §5.5（バッチ内マージと既存ドキュメントマージの同一化）の実装形である。** 2 件目以降は `merge` に入るため、**バッチ内で同一 `text` が何件来ても `excluded` の判定は 1 回**であり、判定回数が結果に影響しない。
- **`bulkPut` は全置換（`OpType.INDEX`）である**（`0002` §5.6）。`SuggestItem` は完全状態であるため、部分更新の意味論を持ち込む必要が無い。
- **項目単位の部分失敗は `IngestResult.failures` に積む**（D-4）。`bulkUpsert` から `bulkPut` への変更で戻り値の契約は変わらない。

##### この形が満たすもの

| # | 性質 |
| --- | --- |
| 1 | **D-19 の「Put / Get は同じ `SuggestItem`」がシグネチャ上も成立する。** §2.6 の説明が実際の公開面と一致する |
| 2 | **`mergePolicy()` と `store()` が本当に独立して差し替え可能になる。** 合成は常に Java 側の 1 実装が行い、ストア実装が何であっても同じ規則が適用される。§3.9.1 の「差し替え」という言葉が組み合わせ制約を持たない |
| 3 | **`SuggestItemMergePolicy` が「Java 側の合成規則が単一の正である」（E-03 / MIG-01）を無条件に満たす。** 第 6 版は「Painless 版が同じ挙動を実装する」という**検証不能な条件付き**でしかこれを主張できなかった |
| 4 | **`SuggestStore` の実装者に求められる知識が減る。** OpenSearch のドキュメント表現（`0002` §5.6 のシリアライズ）と問い合わせ翻訳（§3.6）だけで実装でき、合成規則（`0002` §5.3）を読む必要が無い |

##### C-03 との関係 — 「公開契約を変えずに載る」は撤回する

**C-03（`0000` §5）は「`scripted_upsert`（第 2 段）は `SuggestStore` の拡張点だけ用意し、Painless 仕様は含めない」である。この決定は維持する** — 第 2 段が差し替わる場所は引き続き `SuggestStore` の実装であり、`api` 4 IF も `SuggestIngestService` の呼び出し形も変わらない。

**変えるのは、第 6 版 §3.7 と §4.4.0 が加えていた「第 2 段は `bulkUpsert` の別実装として載る／公開契約を変えずに載る」という、より強い主張である。**

| 段 | 実装 | 本設計での扱い |
| --- | --- | --- |
| 第 1 段 | `multiGet` 1 回 → `SuggestItemMergePolicy` で合成 → `bulkPut` | **確定設計**。現行 `index/writer/SuggestIndexWriter.java:55` の `prepareGet` を item 数ぶん繰り返す形を置換する（MIG-15 第 1 段） |
| 第 2 段 | `scripted_upsert` による OpenSearch 側原子的集約 | **`SuggestStore` に「原子マージ能力」を追加する形で載る。** その能力のシグネチャ・Painless スクリプト仕様・冪等性・失敗時挙動・カスタム MergePolicy との関係は、**すべて第 2 段で設計する**（`0000` §2.2 のスコープ外）。F-10（楽観ロック欠如）の解消もこの段に束ねる（P12） |

**第 2 段で必ず決めなければならないこと**（§10 の申し送り 18 として登録する）:

1. **能力の表現形**（`SuggestStore` に任意メソッドを足す／能力問い合わせを置く／別 SPI に切る のいずれか）。
2. **カスタム `SuggestItemMergePolicy` が設定されている場合の扱い。** 「原子マージ能力を使わず第 1 段の経路にフォールバックする」が素直な既定である。**この分岐を明示的に持てるのは、第 7 版で合成の所有者を `internal` 側に置いたからである** — 第 6 版の形では、ストア実装が渡された policy をどう扱うかを外から観測できなかった。
3. **合成規則を 2 言語で二重管理する期間をどう区切るか**（§4.4.0 の 1 が挙げた懸念であり、これ自体は第 7 版でも変わらない）。

##### 却下した代替案

| 案 | 却下理由 |
| --- | --- |
| **`bulkUpsert(List<SuggestCandidate>, SuggestItemMergePolicy)` を維持し、D-19 の「Put / Get は同じ型」を撤回する** | 文書の整合は取れるが、**上記の 3（カスタム MergePolicy を Painless 版が実行できない）が解決しない**。さらに「`mergePolicy()` と `store()` は独立に差し替えられない」という組み合わせ制約を公開契約に書く必要が生じ、**7 つの SPI のうち 2 つだけが暗黙に結合している**状態になる |
| **`bulkUpsert` と `bulkPut` を両方置く** | 「どちらを呼べばよいか」が実装者にも呼び出し元にも決まらない。**合成の所有者が 2 箇所ある状態は MIG-01 が解消しようとしているものそのもの**である |
| **`SuggestItemMergePolicy` を「宣言的なマージ仕様（`MergeSpec`）」に変え、Java と Painless の両方へコンパイルできる形にする** | 第 2 段の設計を第 1 段に前倒しすることになる。**合成規則の表現力（`0002` §5.3 の位置対応 `readings` 合成など）を宣言的 DSL で表せるかが未検証**であり、検証には Painless 側の実装が要る。C-03 が「Painless 仕様は含めない」と決めた範囲を超える |

**F-11（`deleteByQuery` の手動ループ）の置き換え余地**: 現行 `util/SuggestUtil.java:332-374` は OpenSearch の `_delete_by_query` API ではなく、`setSize(500)`（`:337`）の scroll ＋ bulk `DeleteRequest`（`:349-350`）の手動ループであり、末尾（`:368`）で `prepareRefresh` を同期発行する。`deleteByCondition(QueryCondition)` は**条件を渡す形**なので、実装を `_delete_by_query`（`conflicts` / `slices` / `refresh` パラメータを持つ）へ差し替えられる。ただし置き換えの可否判断（部分失敗の扱いと性能）は本書では行わない。末尾の同期 refresh を `RefreshPolicy`（§6.3）に委ねる点は `0003` の refresh 戦略と接する。

### 3.8 拡張点に織り込むもの／織り込まないもの（C-11 の対応表）

| MIG | 扱い | シグネチャ上の所在 |
| --- | --- | --- |
| MIG-24 セマンティック/ベクトル | **織り込む** | `ScoringContext.queryEmbedding` ／ `ScoringPlan.VectorSimilarityFactor`（§3.2） |
| MIG-21 タイプミス補正 fuzzy | **織り込む** | `ScoringPlan.FuzzyMatchFactor`（`MatchFactor` と別型・独立 weight） ／ `TextProcessor` の誤字正規化段（§3.3） |
| MIG-23 多言語強化 | **織り込む** | `TextProcessor.supports(ctx)` と `TextProcessingContext.languages`（§3.3） |
| MIG-19 同義語/関連語 | **織り込まない** | `SuggestSource<I>` は `supports(ctx)` と `produce(input, ctx)` のみ（第 6 版で `kind()` を削除 — D-30）。**ソース別重み付け・マージ規則を IF に持たない**（§3.1） |
| MIG-20 人気急上昇語/トレンド | **織り込まない** | 同上 |
| MIG-22 パーソナライズ | **織り込まない** | `SuggestQuery` にも `ScoringContext` にも**検索コンテキストの汎用受け口を置かない**（§3.2 / §2.5） |
| MIG-18 蓄積属性の露出 | **織り込む**（受け皿が本体） | `ResponseField` の許可リスト（§5.2）。許可リストを定義した時点で API 側の準備は完了する |
| MIG-14 人気語条件の調整可能化 | **織り込む**（受け口のみ） | `PopularWordsQuery.queryFreqThreshold`（既に可変） |

### 3.9 SPI の合成点（composition root・第 4 版で新設）

**シグネチャだけでは拡張点にならない。** 7 つの SPI について、**どれを構築時に差し替え、どれを呼び出しごとに渡し、どの順で呼ばれ、誰が後始末をするか**が公開契約の一部である。本節がそれを定める。

**第 5 版で SPI は 2 種類に分かれた**（D-24）。`SuggestSource` だけが「**`indexFrom` ごとに渡すもの**」であり、残り 6 つは「**構築時に差し替えるもの**」である。§3.9.1 は後者の登録面、§3.9.4 は両者の所有権とライフサイクルを定める。

> **第 4 版の本節冒頭は「`SuggestSource` の実装を足すだけで載る」（§2.4）を前提に「足した実装をどこに登録するか」を定めていた。第 5 版でその前提（および `SuggesterBuilder.addSource`）は撤回されており、第 6 版で本文を書き換えた**（外部レビュー第 3 回 指摘 4）。撤回の理由は §3.1.1 にある。

#### 3.9.1 合成点は `SuggesterBuilder` である

**`ServiceLoader` も DI コンテナも使わない。** 既存の `SuggesterBuilder`（`Suggester.java:374` が返す。§8.1 の 11 で「構築 API として存続」と決定済み）を唯一の合成点とする。

```java
package org.codelibs.fess.suggest;

public final class SuggesterBuilder {

    // --- SPI の登録（すべて省略可能。省略時は 3.9.2 の既定実装） ---
    /** 既定ソース（DocumentSource / SearchWordSource）を差し替える（3.9.2）。
     *  追加のソースは登録せず SuggestIngestService.indexFrom で駆動する（D-24）。 */
    public SuggesterBuilder documentSource(SuggestSource<Supplier<DocumentReader>> source);
    public SuggesterBuilder searchWordSource(SuggestSource<SearchWordInput> source);
    /** テキスト処理を Chain の末尾に追加する。呼び出し順が Chain の順になる（3.9.3）。 */
    public SuggesterBuilder addTextProcessor(TextProcessor processor);
    /** 以下は「差し替え」であり、複数回呼ぶと最後の 1 つが勝つ。 */
    public SuggesterBuilder scoringStrategy(ScoringStrategy strategy);
    public SuggesterBuilder mergePolicy(SuggestItemMergePolicy policy);
    public SuggesterBuilder badWordPolicy(BadWordPolicy policy);
    public SuggesterBuilder authorizationFilter(AuthorizationFilter filter);
    public SuggesterBuilder store(SuggestStore store);

    /** 4 つの公開 IF をまとめて保持するハンドルを構築する（第 9 版で新設）。 */
    public SuggestComponents buildComponents(Client client, SuggestSettings settings, ExecutorService executor);

    // --- 構築（旧ファサード。戻り値型は現行のまま維持する — 第 9 版 / 逸脱 X-1） ---
    /** 内部で buildComponents(...) を呼び、得た SuggestComponents を保持する Suggester を返す。 */
    public Suggester build(Client client, SuggestSettings settings, ExecutorService executor);
    /** 現行の 2 引数版（SuggesterBuilder.java:149）。settings / executor は builder の設定から解決する。 */
    public Suggester build(Client client, String id);
}

/** 構築結果。4 IF の取り出し口と、SPI 実装の後始末を担う。 */
public interface SuggestComponents extends AutoCloseable {
    SuggestQueryService queryService();
    SuggestIndexLifecycle lifecycle();
    SuggestWordAdmin wordAdmin();
    SuggestIngestService ingestService();

    /** 登録された SPI 実装のうち AutoCloseable なものを登録の逆順で閉じる（3.9.4）。 */
    @Override void close();
}
```

- **`ServiceLoader` を採らない理由**: fess は 1 つの JVM に複数のサジェスト構成を持ちうる（`settingsId` ごとに `SuggestSettings` が分かれる — `settings/SuggestSettings.java:486`）。`ServiceLoader` はクラスパス全体で 1 組の実装しか選べず、構成ごとの差し替えができない。
- **DI コンテナに委ねない理由**: fess-suggest はライブラリであり、利用者の DI 基盤（fess は Lasta DI）を前提にできない。`SuggesterBuilder` は DI の**内側**から呼ばれる（`(fess) helper/SuggestHelper.java:134-142` が既にそうしている）。
- **`build(...)` は `Suggester` を返し、`SuggestComponents` は `buildComponents(...)` から得る**（第 9 版 / 逸脱 X-1）。**第 8 版までは `build(...)` の戻り値を `SuggestComponents` に変えるとしていたが、これは §8.3 の「旧クラスは public シグネチャを 1 つも変えない」および C-01（L1 では fess 本体が無変更で動く）と両立しなかった。** `(fess) helper/SuggestHelper.java:142` が `Suggester.builder()...build(client, id)` の戻り値を `Suggester` 型フィールド（`:86`）へ代入しているため [確認]、戻り値型を変えると **L1 の時点で fess 本体がコンパイルできなくなる**。
- **`build(...)` と `buildComponents(...)` の関係**: `build(...)` は内部で `buildComponents(...)` を呼び、**得た `SuggestComponents` を保持する `Suggester` を返す**。したがって旧ファサード `Suggester` は Strangler Fig 第 2 段で `SuggestComponents` を保持する側になる（§8.3）。**D-13 の「旧クラスが新 IF を保持する向き」（新 IF が旧クラスを参照しない）は保たれ**、L3 で `Suggester` を削除しても `SuggestComponents` は残る。
- **新規の呼び出し元は `buildComponents(...)` を使う。** `build(...)` の 2 つのオーバーロードは C-01 が維持すると決めた互換性の面であり（§8.3.1）、第 4 段（MIG-05 ＝ **R2**）で `Suggester` を除去する際に一緒に消える。
- **【第 10 版】上の「L1 の時点で fess 本体がコンパイルできなくなる」という理由付けは、リリース段の組み替え後も有効である** [確定]。**ただし読み方が変わる** — **`modules/fess` を無変更でビルドできることは、R1 まで旧ファサードを維持するという決定（U-9 / §8.3.1）の帰結であって、「旧 fess 本体を本番で動かす」ためではない**（`0003` 第 14 版 §10.1）。**本文の `L1` は `R1` と読む。**

#### 3.9.2 既定実装

**7 つの SPI すべてに既定実装があり、`SuggesterBuilder` は無設定でも構築できる。** 既定を持たない SPI があると「拡張点」ではなく「必須の穴」になる。

| SPI | 既定実装 | 備考 |
| --- | --- | --- |
| `SuggestSource<I>` | **`DocumentSource`（`I = Supplier<DocumentReader>`。`SuggestKind.DOCUMENT` を含む候補を返す）と `SearchWordSource`（`I = SearchWordInput`。`SuggestKind.QUERY` を含む候補を返す）の 2 つ** | 現行 `index/contents/DefaultContentsParser.java` の 2 経路に対応する。**この 2 つは「登録リスト」ではなく、`indexFromDocuments` / `indexFromSearchWord` が使う名前付きスロットである**（D-24）。`documentSource(...)` / `searchWordSource(...)` は**追加ではなく差し替え**であり、それ以外のソースは登録せず `indexFrom(source, input, options)` で駆動する。**Kind は IF の宣言ではなく `produce()` が返す `SuggestCandidate.kinds` である**（D-30 / §3.1.2） |
| `TextProcessor` | 現行の `normalizer/` `converter/` `analysis/` を包む既定 Chain | MIG-12 は踏襲の明文化であり実装の置換ではない（§3.3） |
| `ScoringStrategy` | 現行 `request/suggest/SuggestQueryBuilder.java:141-167` ／ `request/popularwords/PopularWordsRequest.java:232-244` を `ScoringPlan` で表現したもの | 既定で現行と同一のスコアリングになる |
| `SuggestItemMergePolicy` | `0002` §5.3 の合成規則の実装 | 挙動の正は `0002`。**`SuggestStore` の実装が何であっても、合成はこの 1 実装が行う**（第 7 版 / D-31 / §3.7.1） |
| `BadWordPolicy` | 正規化後テキストの部分一致（§3.5） | |
| `AuthorizationFilter` | `_guest_` 補完 ＋ デフォルト deny（§7.2） | **差し替え時もデフォルト deny は契約である**（§7.2）。空条件を返す実装は契約違反 |
| `SuggestStore` | OpenSearch 実装（`multiGet` ＋ `bulkPut`。MIG-15 第 1 段） | **合成を含まない**（第 7 版 / D-31）。第 2 段の `scripted_upsert` は**原子マージ能力の追加**としてここに載る（§3.7.1） |

#### 3.9.3 順序と可換性

**登録によって順序が生じるのは `TextProcessor` だけである**（第 5 版。`SuggestSource` は D-24 により登録リストではなくなった）。ただし **`SuggestSource` を複数回 `indexFrom` で駆動したときの合成の可換性**は依然として契約であるため、両方をここに置く。

| 対象 | 順序の意味 | 規則 |
| --- | --- | --- |
| `TextProcessor` | **Chain の適用順**。前段の出力が後段の入力になるため**結果は順序に依存する** | `addTextProcessor` の呼び出し順が Chain の順。`supports(ctx)` が false を返す段は**飛ばされる**（Chain が止まるのではない）。**既定 Chain の後ろに追加される**ため、MIG-21（誤字正規化）や MIG-23（言語別）は既定の正規化の後段に載る |
| **複数 `SuggestSource` の合成** | 同一 `text` の候補が複数ソースから来た場合、マージ規則（`0002` §5.3）が合成する。**`userBoost` を除く全フィールドについて結果は順序に依存しない**（`queryFreq` / `docFreq` は加算、`kinds` / `tags` / `roles` / `languages` / `fields` は集合和、`readings` は位置ごとの和集合） | 下記 |

**`userBoost` だけが可換ではない**（D-27・第 5 版で是正）。合成規則は「**present の incoming が existing を上書きする**」（`0002` DM-11）であり、**指定ありの候補が同一 `text` に 2 つ来ると後勝ちになる**。boost 2.0 の候補 A と boost 5.0 の候補 B が同じ `text` に来れば、A → B なら 5.0、B → A なら 2.0 になる。**第 4 版の「結果は順序に依存しない」という無条件の主張は、この場合について誤りだった。**

**採る契約**:

> 1. **`SuggestSource` は `userBoost` を指定しない。** 実装は `SuggestCandidate.document(...)` のみを使う（§2.6.2 / §3.1）。
> 2. **`userBoost` を指定できるのは `SuggestWordAdmin` の elevate word 経路だけである**（`SuggestCandidate.elevate(...)`）。
> 3. 上記 1 の下で、**複数ソースの合成は全フィールドについて可換である。**
> 4. 契約に反して指定ありの候補が同一 `text` に複数来た場合、**規則は「後勝ち」であり、結果は供給順に依存する。** 例外にはしない。

- **なぜ「複数指定時の競合規則」（max / min / 平均など）を定義しないか。** どれを選んでも「管理者が boost を引き下げられない」等の別の破綻を生む（`0002` §5.3 の却下表がこれを検討済みである）。**`userBoost` は「集約する値」ではなく「管理者の最新の指示」であり、複数の供給元が同時に指示を出す状態そのものを設計から排除するのが正しい。**
- **なぜ「Source 順序は意味を持つ」に変えないか。** 順序に意味を持たせると、C-11 が「織り込まない」と決めたソース別重み付け（MIG-19 / MIG-20）を**順序という形で半端に導入する**ことになる。上記 1 の禁止は、拡張点を弱めるのではなく**拡張点の役割を「候補の供給」に限定し続ける**ための制約である。
- **この制約は型では守れない**（§2.6.2 の表）。`elevate(...)` を非 public にできないためである。**したがってレビュー時の確認項目とし、`0002` §7.2 に回帰テスト（T-20）を置く。**

#### 3.9.4 SPI 実装のライフサイクルと `Stream` の close

| 項目 | 契約 |
| --- | --- |
| **生成** | SPI 実装は**呼び出し側が生成して `SuggesterBuilder` に渡す**。ライブラリはリフレクションでインスタンス化しない |
| **構築後の不変性** | `build(...)` 以降、SPI 実装の差し替え・追加はできない。§4.4 のスレッド安全性契約と §8.2 の実行時 setter 廃止（22〜30）に対応する |
| **破棄** | `SuggestComponents.close()` が、登録された SPI 実装のうち `AutoCloseable` を実装するものを**登録の逆順で**閉じる。`AutoCloseable` でない実装は何もしない。**`ExecutorService` は呼び出し側の所有物であり `close()` の対象にしない**（構築時に受け取ったものを勝手に落とさない） |
| **`indexFrom` に渡した `SuggestSource`**（第 5 版） | **登録されていないため `SuggestComponents.close()` の対象にならない。** ライブラリが閉じるのは `produce()` が返した `Stream` だけであり（下記）、**ソース実装そのものの寿命は呼び出し側が持つ**。既定 2 ソース（`documentSource` / `searchWordSource` で差し替えたものを含む）は登録済みであるため上記の破棄規則に従う |
| **`SuggestSource.produce()` が返す `Stream`** | **close するのは呼び出し側（取り込み機構）である。** `try (Stream<SuggestCandidate> s = source.produce(input, ctx)) { ... }` の形で必ず閉じる。**実装側は `Stream.onClose(...)` に後始末を登録してよい**。現行 `index/contents/document/ESSourceReader.java` が scroll コンテキストを持つため、この契約が無いと scroll が解放されない |
| **例外** | `produce()` の途中で例外が出た場合も `Stream` は close される。取り込み全体は `SuggesterException` で例外完了する（§4.2 の「リクエストが成立しない」に該当） |

> **`SuggestComponents` を追加しても D-1 の 30 メソッドは変わらない。** `SuggestComponents` は 4 IF の**取り出し口**であって公開契約のメソッド面ではない。同様に `SuggesterBuilder` の登録メソッドも、第 9 版で新設した `buildComponents(...)` も D-1 に数えない（いずれも構築 API であり、`Suggester.builder()` として既に §8.1 の 11 に計上済み）。

---

## 4. 非同期・例外契約

### 4.1 単一規則

C-06 に基づき次を規則とする。

1. **公開 4 IF のメソッドはすべて `CompletableFuture<T>` を返す。** 例外は 1 つもない。
2. **同期版の API を提供しない。** 0016 §6 が挙げた `Suggesters.sync(service)` 型のラッパは**採らない**。同期が必要な呼び出し元は `join()` を書く。
3. **`Result<T>` 型を導入しない。** エラーは `SuggesterException`（およびその派生）で表す。
4. **非同期経路の例外は `CompletionException` にラップされて現れる。** `join()` した呼び出し元は `CompletionException.getCause()` が `SuggesterException` であることを前提にしてよい。

**A6（非同期の適用範囲）の決着**: 0016 は lifecycle 系を同期・`refresh()` のみ非同期としていたが、**全メソッド非同期に統一する**。境界を「I/O の有無」に置くと `currentIndexName()` のようにクラスタ状態を引くメソッドの分類が判断依存になり、「このメソッドは同期か非同期か」を毎回調べる状態が残る。同期ラッパを別途用意しないのは、それが「同じ操作に 2 つの呼び方がある」状態を作り、ISS-09（不均一さ）を形を変えて再生産するためである。fess 側で同期が必要なのは 3 箇所しかなく、いずれも `join()` の 1 行で済む（§9）。

### 4.2 メソッド別の契約表

**「同期」列が無いのは全件非同期だからである。** 表は例外の振る舞いを検査するためにある。

| IF | メソッド | 正常完了の条件 | 例外完了する場合 |
| --- | --- | --- | --- |
| `SuggestQueryService` | `suggest` | 検索が成立した（0 件でも正常） | 検索失敗・タイムアウト・**許可リスト違反**（§5.3）→ `SuggesterException` / `SuggestAuthorizationException` |
| | `popularWords` | 同上 | 同上 |
| `SuggestIndexLifecycle` | `createIndexIfNothing` | 作成した（true）／既にあった（false） | 作成失敗・acknowledge されない → `SuggesterException` |
| | `createNextIndex` | **世代が作成され、エイリアス付替の post-condition が成立した**（付替リクエストが例外を返した場合でも、状態を再取得して成立していれば正常完了する。D-23 / §2.2.3） | **作成フェーズの失敗**（acknowledge されない等）→ `SuggesterException` ／ **付替が未適用と確定**（更新エイリアスが切替前の世代のまま）→ `SuggesterException`（新世代は孤児として残り `removeDisableIndices` が回収する） ／ **付替の成否を判定できない** → `SuggestAliasStateUnknownException` |
| | `switchIndex` / `switchIndexRetainingPrevious` / `rollbackToPrevious` | **post-condition が成立した**（下位リクエストが例外を返した場合でも、状態を再取得して成立していれば正常完了する。D-23 / §2.2.2） | 世代数が想定外（現行 `Suggester.java:286-292` の検査）・**post-condition が不成立と確定**→ `SuggesterException` ／ **成否を判定できない** → `SuggestAliasStateUnknownException`。`rollbackToPrevious` は保持世代が無い場合も `SuggesterException`（§2.2.1） |
| | `removeDisableIndices` | 削除対象 0 件でも正常 | 削除失敗 → `SuggesterException` |
| | `refresh` | refresh 発行成功 | 失敗 → `SuggesterException` |
| | `currentIndexName` | エイリアスが解決できた | 解決できない → `SuggesterException` |
| | `aliasState` | **3 エイリアスの現在の解決結果を取得できた**（1 つも解決できなくても正常。すべて empty の `AliasState` を返す） | 取得リクエストが失敗 → `SuggesterException` |
| | `wordCountStats` | 集計成功 | 失敗 → `SuggesterException` |
| `SuggestWordAdmin` | `addBadWord` / `deleteBadWord` / `deleteAllBadWords` | 設定更新と `excluded` 更新が**ともに**成立（対象 0 件でも正常） | 設定更新失敗・更新クエリ失敗 → `SuggesterException`。**後段（`excluded` 更新）の失敗では部分適用状態が残りうる。同一操作の再実行で収束する**（D-29 / §2.3.1） |
| | `previewBadWordImpact` | 件数取得成功（0 件でも正常） | 取得失敗 → `SuggesterException`。**変更を行わないため部分適用は起きない** |
| | `addElevateWord` / `deleteElevateWord` / `restoreElevateWords` | 設定更新とインデックス反映が**ともに**成立 | いずれか失敗 → `SuggesterException`。**後段の失敗では部分適用状態が残りうる。同一操作の再実行で収束する**（D-29 / §2.3.1） |
| `SuggestIngestService` | `index` / `indexFromDocuments` / `indexFromSearchWord` / `indexFrom` | **バルクリクエストが成立した**（項目単位の失敗があっても正常。§4.3） | リクエストが成立しない（接続断・タイムアウト・インデックス不在）→ `SuggesterException`。**`SuggestSource.produce()` が投げた場合も同様**（§3.9.4） |
| | `deleteById` / `deleteByCondition` / `deleteAll` / `deleteByKind` / `deleteOldWords` | 削除リクエストが成立した（0 件でも正常） | 同上 |

### 4.3 バルク部分失敗の扱い（A7 の決着）

**項目単位の失敗は例外にしない。`IngestResult.failures` / `DeleteResult.failures` に積み、future は正常完了する。**

境界は「**呼び出し側が『どこまで進んだか』を知りうるか**」に置く。

| 状況 | 扱い |
| --- | --- |
| バルクリクエストが送れず、項目単位の成否が得られない（接続断・タイムアウト・認可失敗・インデックス不在） | **例外完了**（`SuggesterException`）。進捗を語れないため |
| バルクリクエストは成立し、項目単位に成否が返った | **正常完了**し、失敗項目を `failures` に積む |
| 上記のうち**全項目が失敗**した場合 | **正常完了**（`failures` に全件が入る）。0 件成功と 1 件成功で呼び出し側の分岐が変わることを避ける |

`failures` を持つ record は C-06 が禁じた `Result<T>` 型ではない。`Result<T>` は「成功値と失敗値の二者択一で例外を置き換える型」であり、ここで導入するのは**成功したレスポンスの一部として失敗項目を報告するフィールド**である。この区別を実装時に崩さないため、`IngestResult` / `DeleteResult` に `orElseThrow` 相当のメソッドを持たせない。

現行挙動との関係 [確認]: 現行も `index/writer/SuggestIndexWriter.java:71-78` が bulk の失敗を `SuggestWriterResult` に積み、`index/operations/IndexingOperations.java:88` が `SuggestIndexResponse` に載せて返しており、**項目単位の失敗で例外を投げていない**。本決定は現行挙動の維持である。

### 4.4 スレッド安全性・タイムアウト・キャンセル・Executor

| 項目 | 契約 |
| --- | --- |
| **スレッド安全性（concurrent invocation safe）** | `api` 4 IF と `spi` 7 IF の実装は**複数スレッドからの同時呼び出しで壊れてはならない**（内部状態の破壊・データ競合・例外を起こさない）。**DTO は D-20 の不変化（`List` / `Set` の防御的コピー、配列を持つ型は `final class` ＋ clone）が適用された前提で共有してよい。** 第 3 版までのシグネチャは `String[][]` / `Kind[]` を公開しており、`record` であっても中身が書き換え可能だったため、この契約は成立していなかった（§2.6.5）。ただし `settings.SuggestSettings` の**変更操作**（`set` 等）はスレッドセーフではないため、設定変更は初期化時に限る契約とする |
| **同一 `text` への並行 write は atomic ではない**（D-26・第 5 版） | **上記の「スレッドセーフ」は「Java オブジェクトとして壊れない」までであり、「頻度が失われない」ではない。** 取り込みは `multiGet` → 合成 → `bulkPut` の read-modify-write であり（§3.7.1）、**楽観ロック（`setIfSeqNo` / `setIfPrimaryTerm`）を使わない**（`0002` §4.6 / K-1）。**異なる呼び出し元が同一 `text` を含むバッチを同時に書くと、`queryFreq` / `docFreq` の加算を失う。** 契約としては **concurrent invocation safe だが、同一 `text` に対する write は atomic でも linearizable でもない**と読むこと。**同一呼び出しの中では競合しない**（`parallel` フラグはパース処理のみを並列化し、書き込みは逐次である — `0004-corrections.md` の E-20） |
| **Executor** | 各メソッドに `Executor` 引数を**持たせない**。実装は構築時に `ExecutorService` を受け取る（現行 `Suggester.java:138-140` / `index/SuggestIndexer.java:174-176` の `threadPool` 引数と同じ）。呼び出し側が実行スレッドを選びたい場合は、標準の `thenApplyAsync(fn, executor)` 等を使う |
| **完了スレッド（実装契約）** | **実装は、基盤のトランスポート／コールバックスレッド上で future を完了させてはならない。** 必ず構築時に受け取った `ExecutorService` へディスパッチしてから `complete` / `completeExceptionally` する。D-3 により呼び出し側が `join()` を書く前提であるため、この契約が無いと**トランスポートスレッド上でのブロック**が起こりうる（§4.4.1） |
| **継続内でのブロック（呼び出し側契約）** | 上記だけでは不十分である。`thenAccept` 等で登録した継続は**完了スレッド＝ライブラリの `ExecutorService` 上**で走るため、その中で別のライブラリ操作を `join()` すると同一プールを待つことになる。**継続の中で `join()` を呼ばない。** 待ち合わせが必要なら `thenCompose` で合成するか、呼び出し側の `Executor` を明示した `*Async` を使う |
| **タイムアウト** | 下位の I/O タイムアウトは `SuggestSettings` の 6 種（`settings/TimeoutSettings.java:47,63,79,95,111,127` の search / index / bulk / indices / cluster / scroll）で制御し、超過時は `SuggesterException` で例外完了する。**`CompletableFuture` 自体に既定タイムアウトを設けない** |
| | **挙動変化**: 現行 `Deferred.Promise.getResponse()`（`concurrent/Deferred.java:211-213`）は**引数なしで 1 分待ち**、超過で `SuggesterException` を投げる。`join()` に置き換えると無期限待ちになるため、待ち時間の担保は上記の下位タイムアウトに移る。fess の 2 箇所（§9）はいずれも下位タイムアウトが効く経路であることを確認済み [確認] |
| **キャンセル** | `cancel(true)` は**実行中の I/O を中断しない**。後続の合成をやめるだけである。OpenSearch クライアント呼び出しに割り込む手段を持たないため、保証できないことを保証すると書かない |
| **進捗** | 長時間の取り込みは `IngestOptions.onProgress`（累計処理件数）で通知する。`CompletableFuture` に進捗の概念はないため、コールバックで補う |

#### 4.4.0 なぜ F-10 の解消を第 5 版で前倒ししないか（D-26）

**「メジャーアップデートでここまで手を入れるなら MIG-15 第 2 段（`scripted_upsert`）を前倒しすべきではないか」は妥当な問いである。前倒ししない理由は 2 つあり、いずれも本設計書の外にある。**

1. **`scripted_upsert` は Painless スクリプトの仕様確定を要し、それは `0000` §2.2 が明示的にスコープ外としたもの**である（C-03 / E-03）。合成規則の正が Java 側（`SuggestItemMergePolicy`）にある状態で Painless 版を先に載せると、**同じ規則が 2 つの言語で二重管理される期間**が生じる。これは MIG-01（マージ規則の単一化）が解消しようとしている状態そのものである。
2. **`SuggestStore` は差し替え点として設計されており**（§3.7 の C-03）、第 2 段は**`api` 4 IF と `SuggestIngestService` の呼び出し形を変えずに載る**。前倒しの利得は「今回のリリースで直る」ことだけである。

> **上記 2 は第 7 版で弱めた**（D-31 / §3.7.1）。第 5 版・第 6 版は「第 2 段は `bulkUpsert` の**別実装**として載るので公開契約は一切変わらない」と書いていたが、**その前提だった `bulkUpsert(List<SuggestCandidate>, SuggestItemMergePolicy)` は第 7 版で `bulkPut(List<SuggestItem>)` に置き換わった**。第 2 段は `SuggestStore` への**原子マージ能力の追加**になるため、`spi` の面は変わる。**`api` 4 IF が変わらないこと・前倒ししない判断そのものは変わらない** — むしろ「第 2 段で何を決めるかが未定である」ことが §3.7.1 で明示された結果、前倒ししない理由は強くなっている。

**したがって本版で行うのは契約の是正だけである。** 「壊れない」と「頻度が失われない」を区別して書き、利用者が「並行して `index()` してよい ＝ 頻度も失われない」と読める状態を解消する。**解消そのものは K-1（`0002` §8）のまま後続スコープに残す。**

#### 4.4.1 完了スレッド契約を置く理由

D-3（全メソッド非同期・同期ラッパなし・呼び出し側が `join()`）を採ると、**「どのスレッドが future を完了させるか」が例外契約と同格の必須事項になる**。契約が無い場合に起きる具体的な事故は次のとおりである。

1. 実装が OpenSearch クライアントの応答（トランスポート）スレッド上で future を完了させる。
2. `thenAccept(...)` で登録された継続がそのトランスポートスレッド上で実行される。
3. 継続の中で別のライブラリ操作を `join()` すると、**トランスポートスレッドがブロックされる**。最良でも I/O スレッドの枯渇、最悪の場合は応答を処理するスレッドが無くなって進行不能になる。

本書は **(a) 実装側の完了スレッド契約**（トランスポートスレッド上で完了させない）と **(b) 呼び出し側の継続内非ブロック契約**（継続内で `join()` しない）の**両方**を課す。(a) だけでは不十分である — (a) を守っても継続はライブラリの `ExecutorService` 上で走るため、そこで同一プールの別操作を `join()` すればプール枯渇の可能性が残る。(b) だけでも不十分である — 呼び出し側の規律に依存するため、規律が破れたときの被害が「アプリのスレッドが 1 本止まる」ではなく「ライブラリ全体が止まる」になる。

§9.2 の `(fess) helper/SuggestHelper.java:294-297` の置換例は、この契約に適合するよう **`join()` を使わず `thenCompose` で合成する形**にしてある。

### 4.5 例外階層

```
RuntimeException
 └ SuggesterException                 （既存: exception/SuggesterException.java:32）
    ├ SuggestIndexException           （既存: exception/SuggestIndexException.java:33）
    ├ SuggestSettingsException        （★ 既存は RuntimeException 直下。SuggesterException 配下へ移す）
    ├ SuggestAuthorizationException   （★ 新設。§5.3 の許可リスト違反）
    └ SuggestAliasStateUnknownException（★ 第 5 版で新設。D-23 / §2.2.2 の判定不能）
```

- **`SuggestSettingsException` の親を変更する** [提案]。現行 `exception/SuggestSettingsException.java:31` は `RuntimeException` を直接継承しており、`SuggesterException` で捕捉できない。呼び出し側が「fess-suggest 由来の失敗」を 1 つの型で捕まえられないため、単一の根に揃える。**捕捉範囲が広がる方向の変更**であり、既存の `catch (SuggestSettingsException)` は影響を受けない。
- `SuggestAuthorizationException` を新設するのは、許可リスト違反（`AccessScope.SEARCH` で `ROLES` を要求する等）を**呼び出し側のバグ**として他の I/O 失敗と区別するためである。
- **`SuggestAliasStateUnknownException` を新設するのは、呼び出し元の分岐が「成功 / 未適用 / 判定不能」の 3 通りだからである**（§2.2.2）。`SuggesterException` 1 つでは「切替を再試行してよい未適用」と「人手の調査が要る判定不能」を区別できず、`0003` §3.2 の S4 が定める失敗時分岐が呼び出し元で書けない。**メッセージ文字列での判別に頼らせない。** 保持するフィールドは **`aliasState()` の取得結果（取得できた場合）と、元の失敗の cause** である。

---

## 5. レスポンスのフィールド選択と権限（C-10）

### 5.1 指定方式

`SuggestQuery` / `PopularWordsQuery` の `responseFields`（`Set<ResponseField>`）で指定する。文字列ではなく **enum** にするのは、許可リストを型で閉じ、実行時の綴り誤りと未知フィールドの要求を成立させないためである。

- **既定値は `Set.of(ResponseField.TEXT, ResponseField.TAGS)`**（現行互換）。無指定時のレスポンスは現行と変わらない。
- `responseFields` は**取得するもの**を決める。実装は `_source` の取得対象を絞るため、選択しないフィールドはストアから読み出されない。
- **返却型は `SuggestHit` である**（D-19）。`SuggestHit` は projection 専用の型であり、`0002` の不変条件（INV-1 など）を満たす必要がない。**選択しなかった属性が読み出されないことと、保存される語が完全であることは、別々の型が受け持つ。**
- `SuggestResult.populatedFields()` が「実際に埋まっている属性」を返す。呼び出し側は `SuggestHit` の `Optional` の空を見て「選択されなかったのか、値が無いのか」を推測しない（§2.6.4）。

### 5.2 選択可能フィールドの許可リスト

```java
public enum ResponseField {
    TEXT, TAGS, KINDS, FIELDS, LANGUAGES, READINGS, QUERY_FREQ, DOC_FREQ, USER_BOOST, TIMESTAMP, ROLES
}
```

| `ResponseField` | 対応するインデックスフィールド | 既定 | 権限 | 備考 |
| --- | --- | --- | --- | --- |
| `TEXT` | `text`（`constants/FieldNames.java:54`） | ● | 制限なし | |
| `TAGS` | `tags`（`:70`） | ● | 制限なし | `(fess) api/v2/handlers/SuggestWordsHandler.java:108` が `types` として返している属性 |
| `KINDS` | `kinds`（`:66`） | | 制限なし | 値域は `document` / `query` / `user`（F-12。`0002` §2 が正） |
| `FIELDS` | `fields`（`:74`） | | 制限なし | |
| `LANGUAGES` | `languages`（`:76`） | | 制限なし | |
| `READINGS` | `reading_*`（`:56` の接頭辞） | | 制限なし | 語数分の可変フィールド（F-01）。`ProcessedText.readings` と同じ構造で返す |
| `QUERY_FREQ` | `queryFreq`（`:60`） | | 制限なし | MIG-18 の主対象 |
| `DOC_FREQ` | `docFreq`（`:62`） | | 制限なし | 同上 |
| `USER_BOOST` | `userBoost`（`:64`） | | 制限なし | 丸め撤廃後の連続値（MIG-04） |
| `TIMESTAMP` | `@timestamp`（`:68`） | | 制限なし | |
| **`ROLES`** | `roles`（`:72`） | | **`AccessScope.ADMIN` のみ** | §5.3 |

**許可リストに含めないもの**と理由:

| 除外するもの | 理由 |
| --- | --- |
| `score`（`constants/FieldNames.java:58`） | MIG-02 で mapping から削除されるため参照先が存在しない |
| `_id`（`:52`） | 決定的 ID は `text` のハッシュ（`0002` §4）であり、外部に意味を持たない。露出すると ID 方式の変更が API の互換性問題になる |
| `excluded`（MIG-13 で追加） | 検索経路では `mustNot(excluded=true)` により `excluded=true` の文書がそもそも返らないため、常に `false` しか返らない死蔵の選択肢になる。管理系の用途は `previewBadWordImpact`（§2.3）が満たす |

**MIG-18（蓄積属性の UI/API 露出）の受け皿はこの許可リストである。** `QUERY_FREQ` / `DOC_FREQ` / `USER_BOOST` / `KINDS` / `READINGS` を列挙した時点で、MIG-18 に必要な API 側の準備は完了している。残るのは fess 側の UI であり、本書の対象外である。

### 5.3 `roles` の権限上の扱い

`roles` は「その語がどのロールに可視か」という**権限メタデータ**であり、検索経路の応答に載せると、権限構成が検索利用者に漏れる。

```java
/** 呼び出し経路の区分。既定は SEARCH。 */
public enum AccessScope { SEARCH, ADMIN }
```

| 呼び出し経路 | `AccessScope` | `ROLES` の選択 |
| --- | --- | --- |
| 検索 API・オートコンプリート（`(fess) api/v2/handlers/SuggestWordsHandler.java`） | `SEARCH`（既定） | **不可**。要求すると `SuggestAuthorizationException` で例外完了する |
| 人気語（`(fess) helper/PopularWordHelper.java`） | `SEARCH`（既定） | **不可** |
| 管理画面・管理 API（fess 側で管理者認可を通過した経路） | `ADMIN`（呼び出し側が明示指定） | **可** |

- 判定は `AuthorizationFilter.canExposeRoles(scope)`（§3.6）が行う。判定規則を権限の単一の正と同じクラスに置き、フィールド選択の実装側に権限判断を分散させない。
- **要求を黙って落とさない。** `SEARCH` で `ROLES` を要求した場合、その属性を除いて返すのではなく例外にする。黙って落とすと呼び出し側は「値が無い」のか「落とされた」のかを区別できず、`populatedFields()` の自己記述性（§5.1）と矛盾する。
- `ADMIN` を指定しても**権限フィルタ自体は適用される**（デフォルト deny は維持 — §7）。`AccessScope` が変えるのは返却属性の許可範囲だけで、可視文書の範囲ではない。
- `AccessScope` は fess-suggest 側では**認証しない**。fess 本体が管理者認可を通過した経路でのみ `ADMIN` を渡す責務を負う。ライブラリ単体では信頼境界を張れないため、これを契約として明記する。

---

## 6. 設定 API

### 6.1 方針: 既存の `SuggestSettingsBuilder` を拡張する

**新しいパッケージに `SuggestSettings` / `SuggestSettingsBuilder` を新設しない** [提案]。`settings/SuggestSettings.java:110` と `settings/SuggestSettingsBuilder.java:27` は既に存在し、fess 本体が `(fess) helper/SuggestHelper.java:134-142` で使っている。同名型を `api` に作ると、fess 側の import が二重になり C-07（fess の公開面を変えない）と衝突する。既存型に受け口を**足す**。

### 6.2 時間設定（C-08）とインデックス設定（C-13 / C-14）

```java
package org.codelibs.fess.suggest.settings;

public class SuggestSettingsBuilder {

    // --- 時間設定: Duration を正とし、単位付き文字列は fess-suggest 側でパースする（C-08） ---
    /** 検索タイムアウト。 */
    public SuggestSettingsBuilder searchTimeout(Duration timeout);
    /** 検索タイムアウト。"3m" のような単位付き文字列を Duration へパースする。 */
    public SuggestSettingsBuilder searchTimeout(String timeout);
    // index / bulk / indices / cluster / scroll も同じ 2 形を持つ

    // --- インデックス設定: API を正とし、JSON は既定値に格下げする（C-13） ---
    /** シャード数。未指定なら (res) suggest_indices/suggest.json の値を使う。 */
    public SuggestSettingsBuilder numberOfShards(int shards);
    /** auto_expand_replicas の値（例 "0-1"）。number_of_replicas を設定する API は設けない（C-14）。 */
    public SuggestSettingsBuilder autoExpandReplicas(String range);
    /** refresh_interval。MIG-16 と表裏の設定であり、実体の位置づけは 0002 §3 が正。 */
    public SuggestSettingsBuilder refreshInterval(RefreshInterval interval);

    /** 構築した設定から IndexSchema を得る。ライフサイクル API に渡す（§2.2）。 */
    public IndexSchema indexSchema();
}

/** インデックス構築パラメータ。未指定は「JSON の既定値を使う」を意味する。 */
public record IndexSchema(
        OptionalInt numberOfShards,
        Optional<String> autoExpandReplicas,
        Optional<RefreshInterval> refreshInterval
) {
    /** すべて未指定（JSON の既定値に従う）。 */
    public static IndexSchema useDefaults() { /* ... */ }
}

/** refresh_interval の値域。Disabled は OpenSearch の "-1"（自動 refresh 無効）に対応する（D-18）。 */
public sealed interface RefreshInterval permits RefreshInterval.Every, RefreshInterval.Disabled {

    /** 一定間隔で refresh する。 */
    record Every(Duration interval) implements RefreshInterval {}

    /** 自動 refresh を行わない（再構築中に使う）。 */
    record Disabled() implements RefreshInterval {}

    static RefreshInterval every(Duration interval) { return new Every(interval); }
    static RefreshInterval disabled() { return new Disabled(); }
}
```

**`Optional<Duration>` を採らない理由**（D-18）: `Duration` は負値を表現できるが「`-1` ＝ 自動 refresh 無効」という OpenSearch 固有の約束を型が説明しない。`Duration.ofSeconds(-1)` が「1 秒前」なのか「無効」なのかは呼び出し側から読めず、**`0003` §7.3 が要求する「再構築中は停止し、切替直前に既定へ戻す」がシグネチャの上で表現できていなかった** [確認]。`sealed interface` にすることで、**無効化は `Disabled` を選ぶ以外に書きようがなくなる**。

| 確定事項 | 本節での受け皿 |
| --- | --- |
| **C-08**（境界で変換。fess-suggest 側 API のみ `Duration`。`"3m"` のパースは fess-suggest 側。Lasta Config には手を入れない） | 各時間設定が `Duration` 版と `String` 版の 2 形を持つ。fess は現行どおり `String` を渡す（`(fess) helper/SuggestHelper.java:136-140`）ので**呼び出しコードを変えずに済む**。`Duration` を使いたいライブラリ利用者は型付き版を選べる |
| **C-13**（shards は API で受け、`suggest_indices/*.json` は既定値に格下げ、`${...}` 置換は導入しない） | `numberOfShards(int)` が正。`IndexSchema` の未指定は「JSON の値を使う」を意味する。`Suggester.getDefaultIndexSettings()`（`Suggester.java:476-483`）が読む JSON にプレースホルダを入れず、**読み込んだ設定に API 値を上書きする**形にする |
| **C-14**（`auto_expand_replicas` を設定でき `number_of_replicas` は復活させない） | `autoExpandReplicas(String)` のみを置き、`numberOfReplicas(int)` を**定義しない**。API に存在しなければ復活しようがない |
| **MIG-16 の refresh 制御**（A8） | 2 段構え。インデックス側の `refreshInterval(RefreshInterval)`（本節。作成時指定）＋ `SuggestIndexLifecycle.updateRefreshInterval`（§2.2。作成後の復帰）と、取り込み側の `IngestOptions.refreshPolicy`（§6.3）。**戦略の正は `0003` §7** |

`Duration` のパース規則は OpenSearch の時間表記（`ms` / `s` / `m` / `h` / `d`）に合わせる。fess が既に `index.search.timeout=3m` の形で単位付き文字列を渡している（`(fess) src/main/resources/fess_config.properties:683` 相当）ため、この規則以外を受け付ける必要はない。

### 6.3 取り込みオプション（A8 / MIG-16）

```java
public record IngestOptions(int bulkSize, int parallelism, RefreshPolicy refreshPolicy,
                            Runnable pacing, LongConsumer onProgress) { /* §2.5 に再掲 */ }

public enum RefreshPolicy { NONE, ON_COMPLETION }
```

| 項目 | 設計 |
| --- | --- |
| `bulkSize` | 現行 `docPerReq`（`(fess) helper/SuggestHelper.java:270`、既定 2）の後継。**最適値は決めない**（`0000` §2.2）。既定値の引き上げ自体は MIG-16 の対象だが、値は実測依存 |
| `refreshPolicy` | 値域は `NONE` / `ON_COMPLETION` の **2 値のみ**。既定は `ON_COMPLETION`。**毎バッチ refresh（`PER_BATCH`）を値域に持たない**のは、C-12 が廃止すると決めた挙動を選択肢として残すと死蔵オプションになるため（設計原則 4）。現行 `index/operations/ContentIndexingOperations.java:345` の同期 refresh がこの選択肢の廃止対象である |
| `pacing` | CPU 負荷制御。現行 `waitController`（`(fess) helper/SuggestHelper.java:291-293` が `calibrateCpuLoad()` と `sleep(interval)` を渡している）と同じ責務。**`bulkSize` に負荷制御の意味を持たせない**ことを C-12 の帰結として明記する |
| `parallelism` | 現行 `index/SuggestIndexer.java:185` の `parallel` フラグ（boolean）を並列度に一般化する。**F-10（楽観ロック欠如）により並列度を上げるとロストアップデートの確率が上がる**ため、既定は逐次（1）とし、既知の制約は `0002` §4 が扱う |
| `onProgress` | 累計処理件数を受ける。0016 の `Runnable onProgress` は情報を伝えられないため `LongConsumer` に改める |

---

## 7. 権限集約（MIG-09 / C-09）

### 7.1 集約後の責務分担

| 責務 | 担当 |
| --- | --- |
| 現在のユーザーのロール一覧を解決する | **fess 本体**（`(fess) helper/RoleQueryHelper` の `build(SearchRequestType)`） |
| ロール集合を API に渡す | **fess 本体**（`SuggestQuery.roles`） |
| `_guest_` の補完 | **fess-suggest**（`AuthorizationFilter.toCondition`） |
| 権限条件（`QueryCondition`）の生成 | **fess-suggest**（同上） |
| 条件のクエリ変換 | **fess-suggest**（`SuggestStore` 実装） |
| レスポンスへの `roles` 露出可否の判定 | **fess-suggest**（`AuthorizationFilter.canExposeRoles` — §5.3） |

### 7.2 デフォルト deny の維持

`toCondition(roles)` は `roles` が `null` でも空でも **`QueryCondition.DENY_ALL` を返さず、`_guest_` のみを許可する条件を返す**。

- 現行 `request/suggest/SuggestRequest.java:352-357` は、渡されたロール集合に `_guest_` を足した集合で `roles` フィールドの filter を必ず作る（`:357`）。ロール未指定なら `_guest_` だけが残り、guest 可視の文書しか一致しない。**「フィルタが消えて全件が返る」経路が存在しない**ことがデフォルト deny の実体である [確認]。
- 新 API でもこの性質を維持する。`toCondition` が空条件（`QueryCondition` の述語 0 件）を返す実装を禁じ、**必ず `roles` に対する `TermsPredicate` を 1 つ以上含める**ことを契約とする。

### 7.3 現行の二重合成の解消（対応表）

| 現行の位置 | 現行の内容 | 新設計での位置 |
| --- | --- | --- |
| `(fess) api/v2/handlers/SuggestWordsHandler.java:83` | `ComponentUtil.getRoleQueryHelper().build(SearchRequestType.SUGGEST).forEach(builder::addRole)` — ロールを 1 件ずつ builder に積む | `SuggestQuery.Builder.roles(List<String>)` の**一括渡し 1 行**に置換（§9） |
| `request/suggest/SuggestRequest.java:352-357` | 受け取ったロール集合に `_guest_` を補完し、`roles` フィールドの filter を組み立てる | `AuthorizationFilter.toCondition(List<String>)` へ移設 |
| `(fess) helper/PopularWordHelper.java:97-102` | `RoleQueryHelper.build(...)` の結果を空文字除去して配列化し、`:114` で 1 件ずつ `addRole` | `PopularWordsQuery.Builder.roles(List<String>)` の一括渡しに置換 |

### 7.4 デフォルト deny が保証しない範囲（K-2・第 7 版で明示）

**§7.2 のデフォルト deny は「検索の入口」の性質であって、「保存されている語の可視範囲」の性質ではない。** 両者を混同すると、K-2（`0002` §8）が実務上どれだけ効くかを見誤る。

| 問い | 答え |
| --- | --- |
| ロール未指定の呼び出しで全件が返るか | **返らない**（§7.2）。`_guest_` 可視の語だけが返る |
| ある語が `_guest_` を持ってしまう経路はあるか | **ある。** `roles` が空の候補が 1 件でも同一 `text` に合流すれば、集合和により `_guest_` が付く（§3.1.3 / `0002` K-2） |
| その語は誰に見えるか | **全ユーザ**。`_guest_` はすべての権限条件に含まれるため |

**したがって K-2 は「集合和という合成規則を選んだことの帰結」であり、デフォルト deny では塞がらない。**

| 事項 | 第 7 版での扱い |
| --- | --- |
| **K-2 の挙動そのもの** | **維持する**（`0002` §8 のとおり後続スコープ）。合成規則を「積集合」や「最初のソースが勝つ」に変えると、**複数ソースから供給される語が誰にも見えなくなる**方向の破綻を生む。権限モデルの再設計（MIG-09 / MIG-22）なしに単独で変えられない |
| **リリース判断** | **「後続スコープだから」で流さず、メジャー版のリリース時に『この挙動を維持する』と明示的に判断する。** 判断項目としての登録先は `0000` §9C.4 |
| **契約の明文化** | §3.1.3（`SuggestSource` 実装に対する `roles` の契約）と `SuggestSource.produce` の Javadoc（§3.1）。**第 6 版までは K-2 が `0002` の既知制約表にしか無く、拡張点の実装者が読む場所に書かれていなかった** |
| **回復手段** | **全件再構築が唯一の回復手段である**（`0003` §12.2）。新世代は空から作られるため、一過性の混入（例: `roles` 未指定で一度だけ登録された elevate word をその後修正した場合）は次回の再構築で解消する。**ただし供給元そのものが `roles` を空で返し続ける場合は再構築しても再混入する** |

> **0016 §2.2 設計メモの「fess 本体側の `addRole` 二重呼び出しは廃止」という記述は正確ではない** [確認]。`(fess) api/v2/handlers/SuggestWordsHandler.java:83` の `addRole` は**ユーザーのロールを渡す唯一の経路**であり、これ自体は重複ではない。ISS-06 が指す問題は「最終的な権限条件が fess 側（ロール収集）と fess-suggest 側（`_guest_` 補完・filter 生成）の 2 箇所に分かれており、片方だけを読んでも成立する条件が分からない」ことである。したがって解消は「`addRole` を消す」ことではなく「**条件の生成を 1 箇所に寄せ、fess 側は入力を渡すだけにする**」ことである。fess 側の `RoleQueryHelper` はロール解決という fess 固有の責務を持つため**残す**。

---

## 8. 旧 → 新の対応表と旧ファサードの委譲設計

### 8.1 `Suggester` の public 全件（18 件）

**実測値**: `Suggester.java` の public メンバは **18 件**（public メソッド 17 件 ＋ public コンストラクタ 1 件）。作業プラン §3 ステップ 3-8 の「public 18」と一致する。

| # | 現行 public メンバ | 行 | 新 API の対応 |
| --- | --- | --- | --- |
| 1 | `Suggester(Client, SuggestSettings, ReadingConverter, ReadingConverter, Normalizer, SuggestAnalyzer, ExecutorService)` | `:138` | 構築は builder / DI に一本化。公開コンストラクタは**廃止**（理由: 7 引数の位置指定は誤りやすく、`SuggesterBuilder` が既に存在するため二重の構築経路になっている） |
| 2 | `SuggestRequestBuilder suggest()` | `:159` | `SuggestQueryService.suggest(SuggestQuery)`。builder は `SuggestQuery.builder()` へ移る |
| 3 | `PopularWordsRequestBuilder popularWords()` | `:167` | `SuggestQueryService.popularWords(PopularWordsQuery)` |
| 4 | `RefreshResponse refresh()` | `:175` | `SuggestIndexLifecycle.refresh()`。戻り値を `CompletableFuture<Void>` にし、OpenSearch の `RefreshResponse` を露出しない。**対象を suggest インデックスに限定する**（`:179` は現在インデックス名を渡していない） |
| 5 | `void shutdown()` | `:185` | 新 IF に置かない。実装が `AutoCloseable` を実装し、DI コンテナのライフサイクルで閉じる（**廃止理由**: 4 IF はいずれも「使う側の操作」の集合であり、生成した側の後始末を利用者インタフェースに混ぜない） |
| 6 | `boolean createIndexIfNothing()` | `:196` | `SuggestIndexLifecycle.createIndexIfNothing(IndexSchema)` |
| 7 | `void createNextIndex()` | `:235` | `SuggestIndexLifecycle.createNextIndex(IndexSchema)`。戻り値に世代ハンドルを追加 |
| 8 | `void switchIndex()` | `:282` | `SuggestIndexLifecycle.switchIndex()` |
| 9 | `void removeDisableIndices()` | `:339` | `SuggestIndexLifecycle.removeDisableIndices()` |
| 10 | `SuggestIndexer indexer()` | `:366` | **廃止**（理由: 「indexer を取り出してから操作する」という間接層が、用途別 IF の直接注入と二重になる。ISS-13 の中心） |
| 11 | `static SuggesterBuilder builder()` | `:374` | 構築 API として存続。**シグネチャを維持したまま存続する**（`SuggesterBuilder.build(...)` は `Suggester` を返し続ける）。**`SuggestComponents` は `buildComponents(...)` から得る**（§3.9.1・第 9 版 / 逸脱 X-1）。SPI の登録もここに集約する |
| 12 | `SuggestSettings settings()` | `:383` | **公開のまま残す**（`internal` 化しない）。理由は §8.1.1 |
| 13 | `ReadingConverter getReadingConverter()` | `:391` | **廃止**（理由: `TextProcessor`（§3.3）の内部構成であり、利用者が取り出す必要がない。fess 本体から参照されていない [確認]） |
| 14 | `Normalizer getNormalizer()` | `:399` | **廃止**（理由: 同上） |
| 15 | `String getIndex()` | `:416` | `SuggestIndexLifecycle.currentIndexName()`。改名して「エイリアスではなく物理名を返す」ことを自己説明的にする |
| 16 | `long getAllWordsNum()` | `:424` | `SuggestIndexLifecycle.wordCountStats().total()` |
| 17 | `long getDocumentWordsNum()` | `:432` | `wordCountStats().byKind().get(SuggestKind.DOCUMENT)` |
| 18 | `long getQueryWordsNum()` | `:440` | `wordCountStats().byKind().get(SuggestKind.QUERY)`（**廃止理由**: Kind 別の個別メソッドは Kind を増やすたびに API が増える。ISS-12 と衝突する） |

#### 8.1.1 `settings()` を internal 化しない理由

0016 §7 は `Suggester.settings()` を「internal 化」としていたが、**fess 本体が実際に使っている** [確認]。

| 位置 | 用途 |
| --- | --- |
| `(fess) helper/SuggestHelper.java:147,150` | `settings().array()` で `SUPPORTED_FIELDS` を再設定 |
| `(fess) helper/SuggestHelper.java:273-274` | `ESSourceReader` の構築引数として `settings()` を渡す |
| `(fess) helper/SuggestHelper.java:314,331` | `SuggestUtil.deleteByQuery(client, settings(), getIndex(), boolQueryBuilder)` |
| `(fess) helper/SuggestHelper.java:493` | `settings().badword().deleteAll()` |

これらのうち `:314,331` は `SuggestIngestService.deleteByCondition` へ、`:493` は `SuggestWordAdmin.deleteAllBadWords` へ移せる（§9）。`:147,150` は `SuggestSettingsBuilder` の構築時指定へ移せる。**`:273-274` の `ESSourceReader` 構築だけが残る**ため、`settings()` は当面公開のまま残す。この残件は §10 の申し送り 1 とする。

### 8.2 `SuggestIndexer` の public 全件（30 件）

**実測値**: `index/SuggestIndexer.java` の public メンバは **30 件**（public メソッド 29 件 ＋ public コンストラクタ 1 件）。**作業プラン §3 ステップ 3-8 の「public 28」は概数であり、実数と食い違う。以降は実数 30 を採る。**（`grep -c '^    public ' index/SuggestIndexer.java` = 30。`:227` の `createContext` と `:235` の `getBadWords` は `private` であり計上していない。）

| # | 現行 public メンバ | 行 | 新 API の対応 |
| --- | --- | --- | --- |
| 1 | `SuggestIndexer(Client, String, ReadingConverter, ReadingConverter, Normalizer, SuggestAnalyzer, SuggestSettings, ExecutorService)` | `:174` | 構築は builder / DI に一本化。公開コンストラクタは**廃止**（理由: §8.1 の 1 と同じ） |
| 2 | `SuggestIndexResponse index(SuggestItem)` | `:243` | `SuggestIngestService.index(List)`（単数は `List.of(candidate)`）。**単数版は廃止**（理由: 1 件専用経路があるとバルク既定化が徹底されない。MIG-15） |
| 3 | `SuggestIndexResponse index(SuggestItem[])` | `:253` | `SuggestIngestService.index(List<SuggestCandidate>)`。**`SuggestItem` からの変換は行わない** — 旧ファサードは受け取った `SuggestItem` を `SuggestCandidate` へ詰め替える（`excluded` は捨てる。P-c — §8.3） |
| 4 | `SuggestDeleteResponse delete(String id)` | `:263` | `SuggestIngestService.deleteById(String)` |
| 5 | `SuggestDeleteResponse deleteByQuery(String queryString)` | `:273` | **廃止**（理由: Lucene クエリ文字列を外部に露出し、`SuggestStore` 抽象を貫通する。代替は `deleteByCondition(QueryCondition)`） |
| 6 | `SuggestDeleteResponse deleteByQuery(QueryBuilder)` | `:283` | **廃止**（理由: OpenSearch の型が公開面に出る。代替は同上） |
| 7 | `SuggestDeleteResponse deleteAll()` | `:292` | `SuggestIngestService.deleteAll()` |
| 8 | `SuggestDeleteResponse deleteDocumentWords()` | `:303` | `SuggestIngestService.deleteByKind(SuggestKind.DOCUMENT)` |
| 9 | `SuggestDeleteResponse deleteQueryWords()` | `:312` | `SuggestIngestService.deleteByKind(SuggestKind.QUERY)`（**廃止理由**: Kind ごとの個別メソッドは Kind を増やすたびに API が増える） |
| 10 | `SuggestIndexResponse indexFromQueryLog(QueryLog)` | `:322` | **廃止**（ISS-01 のデッドパス。fess 本体から呼ばれていない [確認]。必要時は `SuggestSource` の実装として載る — MIG-07） |
| 11 | `SuggestIndexResponse indexFromQueryLog(QueryLog[])` | `:332` | **廃止**（同上） |
| 12 | `Deferred<SuggestIndexResponse>.Promise indexFromQueryLog(QueryLogReader, int, long)` | `:344` | **廃止**（同上） |
| 13 | `SuggestIndexResponse indexFromDocument(Map<String,Object>[])` | `:355` | `SuggestIngestService.index(List)` に統合（ドキュメント → `SuggestCandidate` の変換は `SuggestSource` の責務） |
| 14 | `Deferred<SuggestIndexResponse>.Promise indexFromDocument(Supplier<DocumentReader>, int, Runnable)` | `:367` | `SuggestIngestService.indexFromDocuments(Supplier<DocumentReader>, IngestOptions)`。`int` / `Runnable` は `IngestOptions` に集約（§6.3） |
| 15 | `SuggestIndexResponse indexFromSearchWord(String, String[], String[], String[], int, String[])` | `:383` | `SuggestIngestService.indexFromSearchWord(SearchWordInput)`。6 引数を record に集約 |
| 16 | `SuggestDeleteResponse addBadWord(String, boolean apply)` | `:395` | `SuggestWordAdmin.addBadWord(String)`。**`apply` を削除**（P6 / §8.5） |
| 17 | `void deleteBadWord(String)` | `:406` | `SuggestWordAdmin.deleteBadWord(String)`。戻り値を `WordOpResult` にする（現行 `void` は影響件数を返せない） |
| 18 | `SuggestIndexResponse addElevateWord(ElevateWord, boolean apply)` | `:417` | `SuggestWordAdmin.addElevateWord(ElevateWord)`。**`apply` を削除** |
| 19 | `SuggestDeleteResponse deleteElevateWord(String, boolean apply)` | `:428` | `SuggestWordAdmin.deleteElevateWord(String)`。**`apply` を削除** |
| 20 | `SuggestIndexResponse restoreElevateWord()` | `:437` | `SuggestWordAdmin.restoreElevateWords()`。複数形に改名（実体は全件再投入） |
| 21 | `SuggestDeleteResponse deleteOldWords(ZonedDateTime)` | `:447` | `SuggestIngestService.deleteOldWords(Instant)`。型を `Instant` へ |
| 22 | `SuggestIndexer setIndexName(String)` | `:457` | **廃止**（理由: 実行時 setter は「取り込み中に対象インデックスが変わりうる」状態を作る。構築時設定に移す） |
| 23 | `SuggestIndexer setSupportedFields(String[])` | `:467` | **廃止**（構築時設定 / `SourceContext.supportedFields`） |
| 24 | `SuggestIndexer setTagFieldNames(String[])` | `:477` | **廃止**（構築時設定 / `SourceContext.tagFieldNames`） |
| 25 | `SuggestIndexer setRoleFieldName(String)` | `:487` | **廃止**（構築時設定 / `SourceContext.roleFieldName`） |
| 26 | `SuggestIndexer setReadingConverter(ReadingConverter)` | `:497` | **廃止**（構築時設定 / `TextProcessor` の Chain 構成） |
| 27 | `SuggestIndexer setNormalizer(Normalizer)` | `:508` | **廃止**（同上） |
| 28 | `SuggestIndexer setAnalyzer(SuggestAnalyzer)` | `:519` | **廃止**（同上） |
| 29 | `SuggestIndexer setContentsParser(ContentsParser)` | `:530` | **廃止**（構築時設定 / `SuggestSource` の実装差し替え） |
| 30 | `SuggestIndexer setSuggestWriter(SuggestWriter)` | `:541` | **廃止**（構築時設定 / `SuggestStore` の実装差し替え） |

**22〜30 の共通の廃止理由**: 実行時 setter 群は「構成が途中で変わりうる可変オブジェクト」を公開面に置くもので、スレッド安全性（§4.4）と両立しない。すべて構築時（builder / DI）の指定へ移し、`api` / `spi` の実装は構築後に不変とする。

**未割り当ては 0 件。** `Suggester` 18 件・`SuggestIndexer` 30 件の全 48 メンバが、新 IF への対応または廃止理由付きの廃止に割り当てられている。

### 8.3 Strangler Fig 第 2 段の委譲設計（C-01）

C-01 の 4 段（NEW 実装 → 旧ファサードから委譲 → 呼び出し切替 → 旧除去）のうち、**第 2 段**の形を定める。

- 旧 `Suggester` / `SuggestIndexer` は**クラスとして残し、public シグネチャを 1 つも変えない**。中身を新部品への委譲に差し替える。
- 旧クラスはこの段で `@Deprecated` を付ける。除去は第 4 段（MIG-05）。
- 委譲の形は次の 3 パターンに分類でき、48 メンバすべてがどれかに当てはまる。

| パターン | 内容 | 例 |
| --- | --- | --- |
| **P-a: 同期化委譲** | 新 IF を呼び `join()` して旧の同期戻り値へ変換する | `Suggester.getAllWordsNum()` → `lifecycle.wordCountStats().join().total()` |
| **P-b: Promise 委譲** | 新 IF の `CompletableFuture` を `Deferred.Promise` に包んで返す（§8.4） | `SuggestIndexer.indexFromDocument(Supplier, int, Runnable)` |
| **P-c: 引数の読み替え** | 旧引数を新 DTO に詰め替える。値が新 API に存在しない引数は**捨てる** | `addBadWord(word, apply)` → `admin.addBadWord(word).join()`（`apply` を捨てる。§8.5） |

旧ファサードの `Suggester.indexer()`（`:366`）は、委譲先の 4 IF を保持する `SuggestIndexer` インスタンスを返す。**旧クラスが新 IF を保持する向きにする**（新 IF が旧クラスを参照しない）。逆向きにすると第 4 段で旧クラスを削除できない。

#### 8.3.1 C-01 が維持する互換性の範囲（D-28・第 5 版で明文化）

**「public シグネチャを 1 つも変えない」が守る対象は限定されている。** これを書かないと、**fess-suggest の外部利用者に対しても互換であるかのように読める。**

| 対象 | 維持されるか |
| --- | --- |
| **`Suggester` / `SuggestIndexer` の public メソッドシグネチャ** | **維持する。** 48 公開メンバの名前・引数型・戻り値型を変えない（§8.1 / §8.2） |
| **`Suggester.builder()` と `SuggesterBuilder.build(...)`** | **維持する**（第 9 版で明示 / 逸脱 X-1）。`build(Client, String)`（`(sug) SuggesterBuilder.java:149`）も `build(Client, SuggestSettings, ExecutorService)` も **`Suggester` を返し続ける**。`SuggestComponents` を得る入口は `buildComponents(...)` として別に置く（§3.9.1）。**`(fess) helper/SuggestHelper.java:142` が戻り値を `Suggester` 型フィールド（`:86`）へ代入している** [確認] ため、ここを変えると C-01 が成立しない |
| **R1 まで旧 `Suggester` / `SuggestIndexer` を維持すること**（**第 10 版で書き換え**） | **維持する。** **理由は 3 つある** — **(a)** Strangler Fig の第 1〜3 段を実装上分けて進められる（`0003` 第 14 版 §10.1 の R1 が第 1〜3 段、R2 が第 4 段）。**(b)** `modules/fess-suggest` は `maven.codelibs.org` へ deploy される公開 artifact であり、外部利用者に 1 リリースぶんの猶予を与える（**U-9** — 要件定義 `20260822_implementation/0000` 第 2 版 §3.1）。**(c)** fess 本体を新 API へ切り替える前後で、**`modules/fess` を無変更のままビルドできる**ことを互換性の検査に使える。**ただし「旧 fess 本体 ＋ 新 fess-suggest を本番稼働させること」は要求しない** [確定] — **第 9 版までの本行は「fess 本体が L1（fess-suggest だけ新版）のまま動くこと」を維持対象としていたが、R-P1（両モジュールは常に同時更新する）によりその本番状態は生じない**（`0003` 第 14 版 §10.1） |
| **`entity.SuggestItem` を fess-suggest の外部から `new` できること** | **維持しない。** D-20 により public コンストラクタが無くなる。**`SuggestIndexer.index(SuggestItem)` はシグネチャとしては残るが、引数を外部で構築する手段が無くなる** |
| **`entity.SuggestItem` の配列 getter**（`String[][] getReadings()` 等） | **維持しない。** D-20 により `List` 系へ変わる |
| **fess-suggest 外部利用者に対する source / binary compatibility** | **維持しない** |

> **これは意識的な判断である。** 本設計はメジャーアップデートであり（`0002` §4.7 が全件再構築を必須としている時点で、無停止のドロップイン置換は成立しない）、**D-19 / D-20 の型分離は `SuggestItem` の生成を閉じることで成立している**。public コンストラクタを残すと §2.6.1 の 3（生成 API の分離では型として守れない）に逆戻りする。
>
> **したがって C-01 は「fess-suggest の外部 API 互換性」ではなく、「`Suggester` / `SuggestIndexer` と fess 本体の移行を段階化するための互換性」と読むこと。** 移行対象は fess 本体 1 つであり（`(fess)` 配下に `new SuggestItem` は 0 件 — §10 の申し送り 13）、その範囲では上記の非互換は問題にならない。
>
> **【第 10 版】この互換性は「開発・ビルドの段階化」のためのものであって、「本番での混在」のためではない** [確定]。**両者は別物である** — 前者は `modules/fess` を無変更でコンパイルできること、後者は旧 fess 本体と新 fess-suggest を同時に本番で動かすことである。**本設計が要求するのは前者だけである。**
>
> **外部利用者への告知が要る。** `README.md` と CHANGELOG に破壊的変更として列挙する（実装タスク。§10 の申し送り 16）。

### 8.4 `Deferred`/`Promise` ↔ `CompletableFuture` アダプタ（MIG-08）

現行の `concurrent/Deferred.java` は次を持つ [確認]。

| 所属 | API | 位置 | 挙動 |
| --- | --- | --- | --- |
| `Deferred` | `class Deferred<RESPONSE extends Response>` | `:52` | `Response` を実装した型に限定される |
| `Deferred` | `void resolve(RESPONSE)` / `void reject(Throwable)` | `:76` / `:102` | 2 度目以降の呼び出しは無視（`:79-81` / `:105-107`）。コールバック中の例外は握り潰す（`:93` / `:119`） |
| `Deferred` | `Promise then(Consumer)` / `Promise error(Consumer)` | `:129` / `:138` | **`Promise` 側の同名メソッドへ委譲するだけ**（`:130` / `:139`）。`Promise` 側と混同しないこと |
| `Deferred` | **`Promise promise()`** | **`:146`** | 内部の `Promise` インスタンス（`:64` で生成）を返す。**`DeferredAdapter` が使う** |
| `Promise` | `class Promise`（内部クラス） | `:153` | `Deferred` のインスタンスに束縛される |
| `Promise` | `Promise then(Consumer)` / `Promise error(Consumer)` | `:166` / `:189` | 実体。登録済みかつ解決済みなら即時実行 |
| `Promise` | `RESPONSE getResponse()` | `:211-213` | **既定 1 分待ち**。タイムアウトで `SuggesterException` |
| `Promise` | `RESPONSE getResponse(long, TimeUnit)` | `:221` | 待ち時間指定。エラー時は `SuggesterException` でラップ（`:228`） |

アダプタは**一方向（`CompletableFuture` → `Promise`）のみ**用意する。

```java
/** 旧ファサード専用のアダプタ。新 API 側からは参照しない。 */
final class DeferredAdapter {
    /** CompletableFuture を旧 Promise に見せる。旧ファサードの委譲（P-b）でのみ使う。 */
    static <R extends Response> Deferred<R>.Promise toPromise(CompletableFuture<R> future) {
        final Deferred<R> deferred = new Deferred<>();
        future.whenComplete((r, t) -> {
            if (t != null) {
                deferred.reject(t instanceof CompletionException ? t.getCause() : t);
            } else {
                deferred.resolve(r);
            }
        });
        return deferred.promise();
    }
}
```

- `deferred.promise()`（`concurrent/Deferred.java:146`）を使うのは、`Deferred` 側の `then` / `error`（`:129` / `:138`）が内部の `Promise`（`:64`）へ委譲するだけであり、返すべきものが `Promise` インスタンスそのものだからである。
- **逆方向（`Promise` → `CompletableFuture`）は作らない。** 新実装が旧型に依存すると第 4 段で `Deferred` を削除できない。
- `CompletionException` を剥がしてから `reject` するのは、旧経路の呼び出し元（`getResponse()`）が受け取る例外を現行と同じにするためである。現行 `:228` は `reject` された `Throwable` を `SuggesterException` の cause に入れる。
- `Response` 境界のため、`CompletableFuture<Void>` を返す新 IF は P-b では包めない。該当するのは旧 `Suggester.refresh()`（`RefreshResponse` を返す）などで、これらは P-a（同期化委譲）を使う。

### 8.5 `apply` の最終形（P6・申し送りの着地）

**新 API から削除する。旧ファサードは `@Deprecated` で受け取り、値を無視する（no-op 化）。**

```java
/** @deprecated apply は無視される。SuggestWordAdmin.addBadWord(String) を使うこと。 */
@Deprecated
public SuggestDeleteResponse addBadWord(final String badWord, final boolean apply) {
    return /* admin.addBadWord(badWord).join() を旧レスポンス型へ変換 */;
}
```

同じ形を `addElevateWord(ElevateWord, boolean)`（`index/SuggestIndexer.java:417`）と `deleteElevateWord(String, boolean)`（`:428`）にも適用する。

#### 段階別の `apply=true` の挙動

| 段階 | `apply=true` の挙動 | `apply=false` の挙動 | 実挙動の変化 |
| --- | --- | --- | --- |
| **現行** | `index/operations/WordManagementOperations.java:81` の wildcard `deleteByQuery` を発火する | 設定への登録のみ | — |
| **MIG-03 段階**（マッチ規則統一・物理削除の既定オフ。`excluded` はまだ無い） | **物理削除を発火しない。設定への登録のみ**（＝ `apply=false` と同一） | 変わらず | **無い**（下記） |
| **MIG-13 段階**（`excluded` 導入後） | 登録 ＋ 該当語に `excluded=true` を立てる | **同左**（`apply` の値によらず同じ） | `apply=false` 経路で除外が即時に効くようになる。C-02 が意図した変更 |

**MIG-03 段階で実挙動が変わらないことの根拠（F-07 / E-09 で訂正済みの事実を使用）** [確認]:

- fess 本体で `apply=true` を渡すのは `(fess) exec/SuggestCreator.java:255`（`storeAllBadWords(true)`）と `:258`（`storeAllElevateWords(true)`）の **2 箇所のみ**である。本ステップで再確認した [確認]。
- その直前 `(fess) exec/SuggestCreator.java:252` が `suggestHelper.suggester().createNextIndex()` を呼び、**新規の空インデックス**を作っている。`storeAllBadWords(true)` の先（`(fess) helper/SuggestHelper.java:509` → `index/SuggestIndexer.java:395` → `index/operations/WordManagementOperations.java:81`）の wildcard `deleteByQuery` は、**削除対象を 1 件も持たない**。
- 管理画面・管理 API はすべて `apply=false` を渡す。**`0000` §6 の E-09 により、作業プランおよび `0004` §3 F-07 の表が挙げた行番号のうち `AdminBadwordAction.java:349,403` / `ApiAdminBadwordAction.java:155,211` は `storeAllBadWords` であって `addBadWord` ではない**ことが訂正されている。elevate word 側の 4 箇所も `apply=false` である。
- したがって `apply=true` の物理削除は**既に実質 no-op** であり、これを明示的な no-op に変えても観測可能な挙動は変わらない。

---

## 9. fess 本体側の API 適合設計（C-07）

### 9.1 変更ファイル一覧

**C-07 の「fess 側修正は 3 ファイルの局所変更」は MIG-08 の範囲についての結論である。** MIG-06 / 09 / 10 / 17 を含めると **計 5 ファイル**（Java 4 ＋ 設定 1）になる。

| # | ファイル | 対象 MIG | 公開シグネチャの変更 |
| --- | --- | --- | --- |
| 1 | `(fess) helper/SuggestHelper.java` | MIG-06 / 08 / 09 / 17 | **なし**（内部のみ） |
| 2 | `(fess) api/v2/handlers/SuggestWordsHandler.java` | MIG-06 / 08 / 09 | なし |
| 3 | `(fess) helper/PopularWordHelper.java` | MIG-08 / 10 | なし |
| 4 | **`(fess) exec/SuggestCreator.java`** | MIG-02 / 13（再構築の切替可否ガード） | **なし**（`main` の内部フローのみ） |
| 5 | `(fess res) fess_config.properties` | MIG-10 / 17 | 設定値・設定項目の変更 |

> **第 3 版での訂正**: 初版・第 2 版は `SuggestCreator` を「変更しない」としていた。**API 適合の観点ではその結論は正しい**（§9.5）が、`0003` §4.3 が同ファイルに切替可否ガードを置くため、**リリース単位としては変更対象である**。矛盾ではなく不足であった（`0004-corrections.md` §4）。

### 9.2 `(fess) helper/SuggestHelper.java`

| 位置 | 現行 | 変更後 |
| --- | --- | --- |
| `:267` | `public void indexFromDocuments(Consumer<Boolean> success, Consumer<Throwable> error)` | **シグネチャを維持する**（C-07） |
| `:272` | `suggester.indexer().indexFromDocument(() -> {...}, docPerReq, () -> {...})` | `ingestService.indexFromDocuments(readerSupplier, options)`。`docPerReq` と `waitController` は `IngestOptions`（§6.3）へ移す |
| `:294-297` | `.then(response -> { refresh(); success.accept(true); }).error(t -> error.accept(t))` | **下記の置換形**（D-22）。`unwrap` は `CompletionException` を剥がす。**継続の中で `join()` を呼ばない**（§4.4 / §4.4.1）ため、現行の `refresh()`（`:295`。置換後は内部で `lifecycle.refresh().join()` する — 本表の `:538-539` の行）を継続内で呼ばず、`thenCompose` で合成する |
| `:251-253` | `suggester.indexer().indexFromSearchWord(sb.toString(), fields, tags, roles, 1, langs)` | `ingestService.indexFromSearchWord(new SearchWordInput(...))` |
| `:314`, `:331` | `SuggestUtil.deleteByQuery(client, suggester.settings(), suggester.getIndex(), boolQueryBuilder)` | `ingestService.deleteByCondition(condition).join()`。`condition` は `@timestamp` の `TimeRangePredicate` ＋ `kinds` の must / mustNot（§3.6 の表） |
| `:340`, `:349`, `:358` | `suggester.getAllWordsNum()` / `getDocumentWordsNum()` / `getQueryWordsNum()` | `lifecycle.wordCountStats().join()` を 1 回呼び、`total()` / `byKind()` から取る |
| `:367`, `:382`, `:397` | `indexer().deleteAll()` / `deleteDocumentWords()` / `deleteQueryWords()` | `ingestService.deleteAll().join()` / `deleteByKind(DOCUMENT).join()` / `deleteByKind(QUERY).join()` |
| `:438`, `:450` | `indexer().deleteElevateWord(word, apply)` | `wordAdmin.deleteElevateWord(word).join()`（`apply` を渡さない） |
| `:482-484` | `indexer().addElevateWord(new ElevateWord(...), apply)` | `wordAdmin.addElevateWord(new ElevateWord(...)).join()` |
| `:493` | `suggester.settings().badword().deleteAll()` | `wordAdmin.deleteAllBadWords().join()` |
| `:509`, `:521` | `indexer().addBadWord(word, apply)` | `wordAdmin.addBadWord(word).join()` |
| `:531` | `indexer().deleteBadWord(badWord)` | `wordAdmin.deleteBadWord(badWord).join()` |
| `:134-142` | `SuggestSettings.builder()` に 6 種のタイムアウトを設定して `Suggester.builder()...build(...)` | 同じ builder に **`numberOfShards(...)` を追加**（MIG-17）。値は `fess_config.properties` の新規プロパティから読む（§9.4） |
| `:147,150` | `suggester.settings().array()` で `SUPPORTED_FIELDS` を設定 | `SuggestSettingsBuilder` の構築時指定へ移す |
| `:155` | `suggester.createIndexIfNothing()` | `lifecycle.createIndexIfNothing(settingsBuilder.indexSchema()).join()` |
| `:166` | `public Suggester suggester()` | **シグネチャを維持する**（旧ファサードを返す。§9.5 の前提） |
| `:538-539` | `public synchronized void refresh() { suggester.refresh(); }` | `lifecycle.refresh().join()`。**refresh 対象が suggest インデックスに限定される**（§2.2） |

#### 9.2.1 `:294-297` の置換形 — 部分失敗を再構築の失敗として扱う（D-22）

```java
ingestService.indexFromDocuments(readerSupplier, options)
    .thenCompose(result -> {
        if (result.hasFailures()) {
            // 項目単位の失敗はライブラリ契約では正常完了だが（D-4）、
            // fess の全件再構築では「不完全な世代」を意味するため失敗として扱う。
            throw new SuggestIndexException(
                    result.failures().size() + " items failed out of "
                            + result.numberOfInputDocs() + " input docs");
        }
        return lifecycle.refresh();
    })
    .thenAccept(v -> success.accept(true))
    .exceptionally(t -> { error.accept(unwrap(t)); return null; });
```

**この 3 行が無いと切替可否ガードが機能しない** [確認]。理由は次の連鎖である。

| # | 事象 |
| --- | --- |
| 1 | D-4 により、bulk の項目単位の失敗では future が例外完了しない（**全項目が失敗しても正常完了する** — §4.3） |
| 2 | したがって `success.accept(true)` が呼ばれ、`(fess) exec/SuggestCreator.java:271,282,293` の `exitCode.set(1)` はどれも発火しない |
| 3 | `0003` §4.2 の G3 は `exitCode == 0` を見るため**合格する** |
| 4 | G1（件数の絶対下限・既定 50%）は欠損が半分未満なら通過し、G2 は任意設定である |
| 5 | 結果として**欠損したままの新世代が検索エイリアスに昇格し、`removeDisableIndices()` の対象から外れていない旧世代が失われうる** |

- **D-4 自体は変えない。** 汎用ライブラリの API として「部分失敗はレスポンスの一部として報告する」は妥当であり、`IngestResult.failures` に積む形は維持する。**変えるのは呼び出し元の読み替え**である。
- **`SuggestIndexException` を投げるのは `thenCompose` の継続内である。** `CompletableFuture` は継続内の例外を future の例外完了に変換するため、`exceptionally` が受けて `error.accept(...)` に落ち、`(fess) exec/SuggestCreator.java:282` 相当の経路で `exitCode = 1` になる。**既存の制御フローに新しい分岐を足さずに G3 へ接続できる。**
- **判定の正は `0003` §4.2 の G3 である**（本節はその実現手段）。G3 の定義自体も「例外なし」から「**例外なし かつ 項目単位の失敗なし**」へ改められている（`0003` MO-18）。
- `storeAllBadWords` / `storeAllElevateWords` の変換失敗も同じく `exitCode` に反映する（`0003` §10.4）。**取り込み経路と語管理経路の両方が G3 に集約される。**

**`apply` 引数を持つ fess 側の public メソッド**（`storeAllBadWords(boolean)`（`:500` 付近）、`addBadWord(String,boolean)`（`:520` 付近）、`storeAllElevateWords(boolean)`、`addElevateWord(..., boolean)`、`deleteElevateWord(..., boolean)`）は、**fess の公開面であるためシグネチャを維持し、引数を無視する**。これは fess 側の変更を最小化する C-07 の方針に従う判断であり、fess 側の `apply` 引数の除去は本設計のスコープ外とする（§10 の申し送り 3）。

### 9.3 `(fess) api/v2/handlers/SuggestWordsHandler.java`

| 位置 | 現行 | 変更後 |
| --- | --- | --- |
| `:76` | `final SuggestRequestBuilder builder = suggestHelper.suggester().suggest();` | `SuggestQuery.Builder` を使う |
| `:83` | `ComponentUtil.getRoleQueryHelper().build(SearchRequestType.SUGGEST).forEach(builder::addRole);` | `queryBuilder.roles(ComponentUtil.getRoleQueryHelper().build(SearchRequestType.SUGGEST));` の**一括渡し 1 行**（MIG-09 / §7.3） |
| `:96,98,101` | `builder.addKind(SuggestItem.Kind.USER.toString())` 等（文字列） | `queryBuilder.addKind(SuggestKind.USER)`（enum。`SuggestQuery.kinds` は `List<SuggestKind>`）。**import が `entity.SuggestItem` から `api.SuggestKind` に変わる**（第 7 版 / D-33） |
| `:104` | `final SuggestResponse suggestResponse = builder.execute().getResponse();` | `final SuggestResult result = queryService.suggest(query).join();`（`getResponse()` → `join()` 相当の 1 行置換 — C-07） |
| `:105-111` | `suggestResponse.getItems()` から `text` と `tags` を取る | `result.items()` から同じ 2 属性を取る。**`responseFields` の既定（TEXT, TAGS）がこの用途と一致する**ため、指定を書く必要がない（§5.1） |

`AccessScope` は指定しない（既定 `SEARCH`）。この経路は `ROLES` を返さない（§5.3）。

### 9.4 `(fess) helper/PopularWordHelper.java` と `fess_config.properties`

| 位置 | 現行 | 変更後 |
| --- | --- | --- |
| `(fess) helper/PopularWordHelper.java:120` | `popularWordsRequestBuilder.execute().getResponse().getItems()...` | `queryService.popularWords(query).join().items()...`（`getResponse()` → `join()` 相当の 1 行置換 — C-07） |
| `:107-118` | `PopularWordsRequestBuilder` に `setSize` / `setWindowSize` / `setQueryFreqThreshold` / `setSeed` と `addTag` / `addRole` / `addField` / `addExcludeWord` をループで積む | `PopularWordsQuery.builder()` の一括渡し（`roles` は §7.3 に従い `List` で渡す） |
| `:77` | `.expireAfterWrite(fessConfig.getSuggestPopularWordCacheExpireAsInteger().longValue(), TimeUnit.MINUTES)` | `.expireAfterWrite(parsed)` — 単位付き文字列をパースした `Duration` を使う |
| `(fess res) fess_config.properties:1514` | `suggest.popular.word.cache.expire=60` | **`suggest.popular.word.cache.expire=60m`**（ISS-02 の解消 — C-08） |
| 同 `:639` の直後 | （シャード・レプリカ設定なし） | **`index.document.suggest.number_of_shards=1` と `index.document.suggest.auto_expand_replicas=0-1` を新設**（MIG-17 / C-13 / C-14）。`(fess) helper/SuggestHelper.java:134-142` が読んで `SuggestSettingsBuilder.numberOfShards(...)` / `.autoExpandReplicas(...)` に渡す |

> **第 3 版での訂正（キー名と配置）**: 初版・第 2 版は `suggest.index.number_of_shards`（`:1441` 付近）としていたが、**fess 本体のどちらの命名流儀にも一致しない**。`index.document.suggest.index=fess`（`(fess res) fess_config.properties:639`）と同 `:643-653` の crawler 系（`index.document.crawler.queue.number_of_shards` 等）が同型であり、**`index.document.suggest.*` が正**である [確認]。`auto_expand_replicas` 側のキーも同時に定義する。決定の正は `0003` §8.2（MO-9）であり、本節はそれに従う（`0004-corrections.md` §4）。

**`:1453` の値を `60m` に変えると `getSuggestPopularWordCacheExpireAsInteger()` が生成されなくなる** [確認]。freegen は既定値をパースして通った型のアクセサを生成する値駆動の推論であり（C-08 の前提 — `0000` §5）、`60m` は整数として解釈できない。したがって `:77` は `getSuggestPopularWordCacheExpire()`（String 版）を使う形に変わる。

パース手段は **fess-suggest が公開する単位付き文字列パーサを fess から使う** [提案]。理由: §6.2 で fess-suggest 側が `"3m"` 形式のパース規則を持つため、fess 側で別のパーサ（`TimeValue.parseTimeValue` 等）を使うと**同じ表記に 2 つの規則**ができる。なお現行のコメント（`:1452` の「Cache expiration (seconds)」）と実装（`:77` の `TimeUnit.MINUTES`）の乖離は、C-08 のとおり**実装側の分を正**として `60m` に固定することで解消する。

### 9.5 `(fess) exec/SuggestCreator.java` が API 適合の観点では変更不要である理由

`SuggestCreator` は `suggestHelper.suggester()` 経由で `createNextIndex()`（`:252`）/ `switchIndex()`（`:298`）/ `removeDisableIndices()`（`:301`）を呼び、`indexFromDocuments` の完了を `CountDownLatch`（`:263`, `:276`）で待つ。

- `SuggestHelper.suggester()` が**旧ファサード `Suggester` を返し続ける**限り（§9.2 の `:166`）、これら 3 つの呼び出しは §8.3 の P-a（同期化委譲）で動く。**Strangler Fig 第 2 段の時点では変更が不要**である。
- `CountDownLatch` は C-07 のとおり**維持する**。`indexFromDocuments` の fess 側シグネチャ（`Consumer<Boolean>` / `Consumer<Throwable>`）が変わらないため、`join()` 化する動機がない。
- 第 4 段（旧ファサード除去 = MIG-05）でこのファイルの変更が必要になる。その時期は `0003` の担当である。

> **ただし本ファイルは変更対象である**（第 3 版で追記）。上記は「**公開契約の適合という観点では**変更が要らない」という結論であって、変更が無いという意味ではない。`0003` §4.3 は切替可否ガード（`exitCode != 0` または検証不合格なら `switchIndex()` / `removeDisableIndices()` を実行しない）を `SuggestCreator.create()` に置く。**ガードの正は `0003`、API 適合の正は本節**であり、両者は別軸である。§9.1 の一覧には変更対象として計上した。

> **リリース手順・fess-suggest との同期タイミングは `0003` に委ねる。** 本節は「変更後の形」だけを示す（作業プラン §3 ステップ 3-9 の注記）。Phase 1b（MIG-06 / 08 / 09 / 10）が fess 本体 PR の同期リリースを前提とすること、fess 連携テストの補強が必須であることも `0003` §10 が扱う。

---

## 10. 未確定事項・申し送り

**`[要確認]` は本書に 1 件も存在しない**（V3）。以下は「決めたうえで他文書・後続タスクに引き渡す事項」である。

| # | 事項 | 引き継ぎ先 |
| --- | --- | --- |
| 1 | **`Suggester.settings()` の最後の依存先**: `(fess) helper/SuggestHelper.java:273-274` の `ESSourceReader` 構築が `SuggestSettings` を要求するため、`settings()` を公開のまま残さざるを得ない（§8.1.1）。`ESSourceReader` 側の受け取り方を変えれば公開面から外せる | 実装タスク（MIG-06 の後） |
| 2 | **bad word 判定の等価性テスト**（§3.5）: 判定意味論は部分一致のまま変えないため、**回帰テストは「現行と同一結果になる」側**である。加えて `BadWordPolicy` に固有の不変条件として、①`isBadWord`（Java の部分文字列判定）と `matchCondition`（エスケープ済みワイルドカード）が**同じ語集合に一致すること** ②bad word に `*` / `?` を含む場合でもその語自体を含む語だけが一致すること（F-09 の回帰） ③**重複マッチの解除**（`foo` / `bar` / `foobar` のケース。§3.5.1 の D-25）を検査する必要がある | `0002` §5 / §7 のテスト仕様 |
| 3 | **fess 側 public メソッドの `apply` 引数**: `SuggestHelper.addBadWord(String,boolean)` 等は fess の公開面であるため引数を残し、値を無視する（§9.2）。fess 側からの除去は別途 fess 本体の互換判断が要る | 後続タスク（fess 本体側） |
| 4 | **`SuggestItemMergePolicy` の挙動**: 本書はシグネチャのみを確定した。`initialize` / `merge` の中身（`excluded` の保持 — U4、**新規語の `excluded` 初期値 — D-32**、`userBoost` の合成 — P13/U5、走査基準の単一化 — F-04）は未確定である | **`0002` §5**（本書 §3.4 の要求表がその入力） |
| ~~11~~ | **解消済み（第 5 版）。** エイリアス状態の読み取り面は `AliasState` ＋ `aliasState()` として公開面に置き、**post-condition による正常完了の判定はライブラリ側が吸収する**ことに決めた（D-23、§2.2 / §2.2.2）。**実装タスクへ送らない** | **決着済み** → §2.2.2 |
| **12** | **`SuggestComponents` の命名と粒度**（§3.9.1）: 4 IF の取り出し口を 1 型にまとめたが、fess 側は `SuggestHelper` が 4 IF を個別に保持する形でもよい。DI での注入単位をどちらにするかは実装時に決める | 実装タスク（MIG-06） |
| **13** | **`SuggestCandidate` の生成箇所の棚卸し**（§2.6.2）: 現行で `new SuggestItem` している箇所（`index/contents/DefaultContentsParser.java`・`entity/ElevateWord.java:143-149`）を `SuggestCandidate.document(...)` / `.elevate(...)` のどちらに割り当てるかを実装時に全件確認する。**fess 本体側に `new SuggestItem` は 0 件である** [確認]（`0003` §10.3）。**第 5 版でシグネチャを確定したため、確認は割り当ての確定作業のみである** | 実装タスク |
| **14** | **`indexFrom` の型パラメータと既定 2 経路の実装共有**（§2.4 / §3.1）: `indexFromDocuments` / `indexFromSearchWord` を `indexFrom` の糖衣として実装するか、内部経路を分けるかを実装時に決める。**公開契約はどちらでも同じ**である（前者が意図であり、後者を選ぶ場合は挙動の一致を実装側の責務とする） | 実装タスク |
| **15** | **`mustNotContain` の述語数**（§3.5.1）: bad word 登録数に比例して `deleteBadWord` の 1 クエリの述語数が増える。**上限を設けず素直に組み立てる**と決めたため、大量登録環境での実測が要る（C-04 により本設計は性能実測を行わない） | 後続タスク（性能実測。`0000` §2.2） |
| **16** | **外部利用者への破壊的変更の告知**（§8.3.1）: `entity.SuggestItem` の public コンストラクタ廃止と配列 getter の `List` 化は、fess-suggest の外部利用者に対する source / binary 非互換である。`README.md` と CHANGELOG に列挙する | 実装タスク（MIG-25 の README 単一ソース化と同時） |
| **17** | **部分適用時の再実行導線**（§2.3.1 の D-29・第 6 版）: 本書はライブラリ側の契約として「同一操作の再実行で収束する」を定めたが、**fess 管理画面が bad word / elevate word の操作失敗をどうユーザに提示し、再実行させるか**は fess 本体側の UI の判断である。**呼び出し元（`(fess) helper/SuggestHelper.java:482,509,521,531,438,450`）が例外を握り潰さないことだけが前提条件**であり、握り潰すと部分適用状態が誰にも見えなくなる | 実装タスク（fess 本体側）／ `0003` §10.2 の同期リリース範囲 |
| 5 | **`refresh()` の対象範囲が変わる**: 現行 `Suggester.java:179` はインデックス名を渡さず全インデックスを refresh している。新 API は suggest インデックス限定とする（§2.2）。**これは既存資料のどこにも記載がない新規の [確認] 事項**であり、`0000` §6 の訂正一覧に **E-13 以降の候補**として追加すべきかをステップ 7 で判断する | ステップ 7（`0000` §6） |
| 6 | **`SuggestSettingsException` の親クラス変更**（§4.5）: `RuntimeException` 直下から `SuggesterException` 配下へ移す。捕捉範囲が広がる方向であり既存の catch は壊れないが、ライブラリ利用者への告知が要る | 実装タスク（MIG-08） |
| 7 | **`IngestOptions.bulkSize` の既定値と `parallelism` の既定値** | 後続タスク（性能実測。`0000` §2.2） |
| 8 | **`RefreshPolicy` と `refresh_interval` の使い分けの運用手順** | `0003` §7（refresh 戦略） |
| 9 | **`matchCondition` の実装方式が `text` の mapping 型に依存する**（§3.5）: 現行 `(res) suggest_indices/suggest/mappings-default.json:42-44` が `text: keyword` であることを前提に、エスケープ済みワイルドカードを選んでいる。To-Be mapping で `text` の型やサブフィールドを変える場合は実装方式を選び直す必要がある | **`0002` §2**（mapping 確定時に突き合わせる） |
| **18** | **MIG-15 第 2 段の「原子マージ能力」の設計**（§3.7.1 の D-31・第 7 版）: 第 7 版で `SuggestStore` から合成を外したため、第 2 段（`scripted_upsert`）は**同一シグネチャの別実装ではなく能力の追加**になる。その段で決めるのは (a) 能力の表現形（`SuggestStore` への追加メソッド／能力問い合わせ／別 SPI）、(b) **カスタム `SuggestItemMergePolicy` が設定されている場合のフォールバック**、(c) Java と Painless で合成規則を二重管理する期間の区切り、の 3 点である | 後続タスク（MIG-15 第 2 段。`0000` §2.2） |
| **19** | **除外語の物理削除の運用導線**（§2.4 の D-32・第 7 版）: D-32 により bad word 該当語がインデックスに残り続けるため、`deleteByCondition(mustMatchAny("excluded", ["true"]))` を運用者が実行できる導線が要る。**ライブラリ側は `deleteByCondition` で足りており、新設 API は無い。** 決めるのは fess 管理画面に置くか、`SuggestCreator` の起動オプションにするか、手順書だけに留めるか | 実装タスク（fess 本体側）／ `0003` §12.1 |
| **20** | **`SuggestKind` 移設に伴う import の一括置換**（§2.6.0 の D-33・第 7 版）: `SuggestItem.Kind` を参照している箇所を `api.SuggestKind` へ機械的に置き換える。**fess 本体側は `(fess) api/v2/handlers/SuggestWordsHandler.java:96,98,101` の 1 ファイルのみ** [確認]。fess-suggest 内部の参照箇所は実装時に全件確認する | 実装タスク |
| 10 | **`text` に keyword normalizer を設定しないこと**（申し送り 2 の不変条件の前提）: 申し送り 2 の等価性（`isBadWord` の Java 部分文字列判定 ＝ `matchCondition` のワイルドカード判定）は、**索引値と原文が一致すること**にも依存する。normalizer（`lowercase` 等）があると OpenSearch 側は正規化後の索引値に対して照合し、Java 側は正規化前の文字列を見るため、**両判定が乖離しうる**。現行 mapping には normalizer / analyzer の指定が **1 件も存在しない** [確認]（`(res) suggest_indices/suggest/mappings-default.json` 全体で該当なし）ため等価性は現在成立している。To-Be mapping で normalizer を導入する場合は、**導入しないか、`BadWordPolicy` の正規化と索引側の正規化を一致させるか**のどちらかを明示的に選ぶ必要がある | **`0002` §2**（mapping 確定時の確認事項） |

---

## 付録 A. `0016-improved-api-interface.md` との差分表（P2）

`20260622_improvement_proposal/0016-improved-api-interface.md` は本書のベースだが、その後の [確定] により覆った点がある。**過去タスクの文書は凍結されている（P9）ため、0016 を書き換えず本表で上書きする。**

| # | 0016 の記述（位置） | 本設計書の決定 | 根拠 | 本書の節 |
| --- | --- | --- | --- | --- |
| **A1** | `bulkUpsert` は **`scripted_upsert` 第一候補・multiGet フォールバック**（`0016` §2.4 設計メモ・§4 設計メモ） | **逆転**。multiGet が確定設計、`scripted_upsert` は `SuggestStore` の差し替え可能な実装（拡張点）に留める。Painless 仕様はスコープ外。**第 7 版でメソッド名は `bulkPut` になり、合成は `SuggestStore` の外へ出た**（D-31 / §3.7.1） | **C-03** | §3.7 / §3.7.1 |
| **A2** | `SuggestWords` / `SuggestResult` の **2 分割**で detail を表現し、`suggest()` / `suggestWithDetail()` の 2 メソッドに分ける（`0016` §2.2） | **2 分割を採らない**。`suggest()` 1 本＋レスポンスのフィールド選択に統一し、`SuggestWords` 型を新設しない。既定は現行互換（text / tags）。ISS-03 は「既定の明示」と `populatedFields()` の自己記述で解消する | **C-10** | §2.1 / §5 |
| **A3** | `IndexSchema(int numberOfShards, int numberOfReplicas, boolean logicalDeleteField)`（`0016` §4） | `numberOfReplicas` を**削除**し `autoExpandReplicas` に置換する。`logicalDeleteField` も持たない（`excluded` の有無は mapping の話であり `0002` の担当）。未指定を表現するため各項目を `Optional` 系にする | **C-13 / C-14** | §6.2 |
| **A4** | 「fess 本体の**設定基盤を型安全化**する」（`0016` §8 の「設定基盤（Lasta Config）／型安全設定（`Duration` 等）化」） | **誤り**。Lasta Config は `Duration` を扱えない [確認]。**境界で変換**する。fess-suggest 側 API のみ `Duration` を持ち、fess は単位付き文字列を String のまま渡す。**Lasta Config には手を入れない** | **C-08** | §6.2 / §9.4 |
| **A5** | `addBadWord(String word, boolean apply)`（`0016` §2.3） | **`apply` を削除**する。`addElevateWord` / `deleteElevateWord` も同じ。旧ファサードは `@Deprecated` で受け取り値を無視する | **P6**（根拠 **F-07**、呼び出し箇所は **E-09** で訂正済み） | §8.5 |
| **A6** | lifecycle 系は**同期**、`refresh()` のみ `CompletableFuture`（`0016` §2.1） | **全メソッド非同期に統一**する。同期ラッパ API（`Suggesters.sync(...)`）も提供しない。同期が要る呼び出し元は `join()` する | **C-06** | §4.1 |
| **A7** | `WordOpResult` / `IngestResult` が **`List<Throwable> errors`** を戻り値に持つ（`0016` §2.3・§2.4） | `Result` 型は導入しない。**項目単位の部分失敗は `failures` に積んで正常完了、操作全体の失敗は `SuggesterException` で例外完了**と明示的に決着させる。`Throwable` ではなく `ItemFailure(id, text, reason)` を積む（例外オブジェクトを大量に保持しない） | **C-06** | §4.3 |
| **A8** | `IngestOptions(int bulkSize, int parallelism, Runnable onProgress)`（`0016` §2.4） | **refresh 制御パラメータ `RefreshPolicy` を追加**する。値域は `NONE` / `ON_COMPLETION` の 2 値（毎バッチ refresh は値域に持たない）。`onProgress` は情報を伝えられる `LongConsumer` に改め、CPU 抑制用の `pacing` を分離する | **C-12** | §6.3 |

### A.1 0016 §9「要確認事項」8 項目のクローズ状況

**0016 §9 の表が挙げる 8 項目は全件クローズしている。** 本書に `[要確認]` を持ち込まないための確認である。

| 0016 §9 の項目 | クローズ内容 | 参照 |
| --- | --- | --- |
| **TBD-01**（OpenSearch/Lucene 数値バージョン未解決。`scripted_upsert` / `script_score` / `knn` / `fuzzy` の利用可否） | **クローズ**。OpenSearch 3.7.0 でいずれも利用可能 [確認]。ただし `scripted_upsert` は C-03 により拡張点のみ | C-04（`0000` §5） |
| **score の扱い（案 A / 案 B）** | **クローズ**。案 A（死蔵廃止・検索時計算）に確定。両論併記を持ち込まない | MIG-02（実体は `0002` §2） |
| **並行基盤の互換**（fess 本体が独自 `Promise` コールバックに依存するか） | **クローズ**。依存は `(fess) helper/SuggestHelper.java:294-297` の 1 箇所のみ [確認]。公開面を変えずに置換できる | C-07 ／ 本書 §8.4 / §9.2 |
| **権限責務の再配置**（`RoleQueryHelper` と `AuthorizationFilter` の境界） | **クローズ**。ロール解決は fess（`RoleQueryHelper` を残す）、条件生成は fess-suggest（`AuthorizationFilter`）。デフォルト deny を維持 | C-09 ／ 本書 §7 |
| **設定の型安全化**（Lasta Config が `Duration` を扱えるか） | **クローズ**。扱えない [確認]。境界で変換する | C-08 ／ 本書 §6.2（A4） |
| **バルク件数の最適値**（TBD-04） | **クローズ**（設計判断としては解消）。`IngestOptions.bulkSize` で可変にし、**最適値は決めない**。実測は後続タスク | C-12 ／ `0000` §2.2 ／ 本書 §6.3 |
| **シャード可変の是非**（TBD-05） | **クローズ**。2018-04-19 `d8b5ccc` による 5 → 1 の意図的な引き下げ [確認]。既定は 1 に据え置き、API で可変にする | C-13 ／ E-05（`0000` §6） ／ 本書 §6.2 |
| **detail 分離の粒度**（`SuggestWords`/`SuggestResult` の 2 分割で UI 要件を満たすか） | **クローズ**。**2 分割そのものを採らない**ことで問い自体が消える。フィールド選択（許可リスト ＋ 既定 text/tags）が UI 要件の未確定を吸収する | C-10 ／ 本書 §2.1（A2）・§5 |

### A.2 その他、0016 の記述を本書が上書きした点

差分 8 点に含まれないが、実コードとの照合で覆った記述を記録する。

| 0016 の記述 | 実際 | 本書の節 |
| --- | --- | --- |
| `Suggester.settings()/getReadingConverter()/getNormalizer()` を**まとめて internal 化**（`0016` §7） | `settings()` は fess 本体が 4 箇所で使用しており internal 化できない [確認]。`getReadingConverter()` / `getNormalizer()` は未使用のため廃止できる | §8.1 / §8.1.1 |
| 「fess 本体側の `addRole` **二重呼び出し**は廃止」（`0016` §2.2） | `addRole` は**ユーザーのロールを渡す唯一の経路**であり重複ではない。ISS-06 の実体は「条件の生成が 2 箇所に分かれている」ことである | §7.3 |
| 現行公開面は「`Suggester` public ~18 ＋ `SuggestIndexer` public ~28」（`0016` §1・§7） | 実測は `Suggester` **18**（メソッド 17 ＋ コンストラクタ 1）、`SuggestIndexer` **30**（メソッド 29 ＋ コンストラクタ 1） | §8.1 / §8.2 |
| **bad word 削除を `termQuery(TEXT, word)` の完全一致に変更する**（`0016` §2.3 の Javadoc・設計メモ「最優先クイックウィン」、および §7 の対応表「term 一致化（ISS-04, MIG-03 最優先）」） | **採らない。** 提案書は部分一致の維持を要件レベルの [確定] 前提としている — `improvement-proposal.md:380`（MIG-03 の定義「**部分一致を 1 `BadWordPolicy` に**」）、`:499`（「**部分一致は要件どおり維持**（全て bad word 扱い）**を前提に**」）、`:211`（Q3「**部分一致…を維持したまま**」）、`:132`（ISS-04「※**部分一致自体は要件上「意図した挙動」であり課題ではない**」）。ISS-04 が課題としたのは**不可逆性**と**実装の二重化・メタ文字誤爆**であって判定意味論ではない。**判定意味論は部分一致のまま維持し、二重化は `BadWordPolicy` による所有で、メタ文字誤爆はエスケープの規則内必須化で解消する** | §3.5 / §3.6 |

---

## 付録 B. 参照した一次情報

### B.1 プロダクションコード

無印 = `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/` 配下、`(fess)` = `modules/fess/src/main/java/org/codelibs/fess/` 配下、`(res)` = `modules/fess-suggest/src/main/resources/` 配下（`0000` §3.1）。

**本書執筆にあたり実読したファイルは以下である。個々の行番号は本文の各主張に `file_path:line` として付してあるため、ここでは再掲しない**（`0000` §3.3 の記述ルール 1）。

- fess-suggest: `Suggester.java` ／ `index/SuggestIndexer.java` ／ `index/writer/SuggestIndexWriter.java` ／ `index/writer/SuggestWriter.java` ／ `index/operations/IndexingOperations.java` ／ `index/operations/WordManagementOperations.java` ／ `index/operations/ContentIndexingOperations.java` ／ `entity/SuggestItem.java` ／ `entity/SuggestItemSerializer.java` ／ `entity/SuggestItemMerger.java` ／ `request/suggest/SuggestRequest.java` ／ `request/suggest/SuggestQueryBuilder.java` ／ `request/suggest/SuggestResponse.java` ／ `request/popularwords/PopularWordsRequest.java` ／ `concurrent/Deferred.java` ／ `converter/ReadingConverter.java` ／ `normalizer/Normalizer.java` ／ `analysis/SuggestAnalyzer.java` ／ `index/contents/ContentsParser.java` ／ `index/contents/document/DocumentReader.java` ／ `settings/SuggestSettings.java` ／ `settings/SuggestSettingsBuilder.java` ／ `settings/TimeoutSettings.java` ／ `constants/FieldNames.java` ／ `util/SuggestUtil.java` ／ `exception/`（3 クラス） ／ `(res) suggest_indices/suggest/mappings-default.json`
- fess 本体: `(fess) helper/SuggestHelper.java` ／ `(fess) api/v2/handlers/SuggestWordsHandler.java` ／ `(fess) helper/PopularWordHelper.java` ／ `(fess) exec/SuggestCreator.java` ／ `(fess) src/main/resources/fess_config.properties`

### B.2 タスク内文書

| 文書 | 用途 |
| --- | --- |
| `0000-design-overview.md` | §3.1 凡例 ／ §3.2 冒頭宣言 ／ §3.3 記述ルール ／ §3.4 番号台帳 ／ §4.2 MIG 対応表 ／ §5・§5.1 [確定]（C-01〜C-14 / P / U） ／ §6 訂正一覧（**E-01〜E-12**。特に E-03 / E-05 / E-06 / E-09 を本書で使用） |
| `20260706_design_document/0001` | C-01〜C-14 の原典。§1.1（Lasta Config が `Duration` 非対応）・§1.2（`Deferred` の fess 側依存 1 箇所）を A4 / A.1 で参照 |
| `20260706_design_document/0003` | §3 ステップ 3（3-1〜3-10）の作業定義、§5（V1〜V11）、§6.1（U1〜U5） |
| `20260706_design_document/0004` | F-06 / F-07 / F-08 / F-09 / F-11 の [確認]（T 番号は **E-08 / E-09 経由**で参照した） |
| `20260622_improvement_proposal/0016-improved-api-interface.md` | 本書のベース。**編集していない**（P9）。差分は付録 A で上書き |
