# 0001 - 改善提案書のブラッシュアップ

## 概要

`docs/improvement-proposal.md` を、`0000-requirements-definition.md` の4つのブラッシュアップポイント
（①改善の進め方の具体化、②移行の技術的ルール、③badword、④scripted_upsert/multiGet）を反映して改訂した。
既存の記述ルール（[事実]/[提案]/[要確認] 凡例、ISS/TBD/MIG/KEEP 番号体系、§参照）を踏襲。

## 事実確認（コード裏取り）

改訂前に modules/fess-suggest の実コードを確認し、特に badword 論点を裏取りした。

- **badword は「部分一致」の2機構が存在**（これが③の整合の核心）:
  1. **登録時フィルタ（非破壊・可逆）**: `SuggestItem.isBadWord`（`entity/SuggestItem.java:455-462`）が
     `text.contains(badWord)` の **部分一致（Java substring, 正規化後テキスト）** で判定し、
     `IndexingOperations.index`（`index/operations/IndexingOperations.java:78`）が
     `.filter(item -> !item.isBadWord(badWords))` で **新規登録アイテムを除外（インデックスしないだけ）**。
  2. **登録時削除（破壊的・不可逆）**: `WordManagementOperations.addBadWord(apply=true)`
     （`index/operations/WordManagementOperations.java:81`）が
     `wildcardQuery(FieldNames.TEXT, "*" + normalized + "*")` の deleteByQuery で
     **既存インデックス済み文書を物理削除**。
  - 両者とも部分一致だが、①は可逆・非破壊、②は不可逆・破壊的。
  - かつ ①は Java `contains`、②は OpenSearch `wildcard` と **マッチ実装が二重化**（`wildcard` はメタ文字 `*?` を
    解釈するため、badword に記号が含まれると `contains` と挙動が乖離し得る）。
- `BadWordSettings.getValidationError`（`settings/BadWordSettings.java:125-133`）は空白を含む badword を拒否（単語単位前提）。
- `text` フィールドは `keyword` 型（`suggest_indices/suggest/mappings-default.json`）。`score` は `double`（死蔵、既存メモと一致）。
- 非同期は独自 `Deferred`/`Promise`（`concurrent/`、CLAUDE.md 記載）。書き込みは Get-then-update（既存メモと一致）。

## 変更点の要約

### 1. 改善の進め方（Strangler Fig の具体化）— §4.1.1 を新設
- api/spi/internal（NEW）を既存 index/request/Suggester に並置するパッケージ構成を明記。
- 手順を「NEW 実装＋既存テスト流用で等価性担保 → 既存ファサードを新部品へ委譲（公開シグネチャ維持で互換）→
  fess 本体の呼び出しを新 API へ切替 → 旧除去（or @Deprecated 残置）」の4段に落とし込み。
- 例として MIG-01（SuggestItemMergePolicy を spi に、SuggestItemMergerTest 流用で等価回帰）を明記。
- §1.4 サマリにも Strangler Fig の1行要約を追加。

### 2. 移行の技術的ルール（過渡期）— §4.1.2 を新設
- データ移行: スキーマ変更系は二重エイリアス再構築（KEEP-02）で新世代を並行構築→検索エイリアス切替→旧除去。
- 非同期/例外: NEW は CompletableFuture + Result 型。ファサードをアダプタ層とし
  「CompletableFuture→Promise」「Result エラー→SuggesterException(throw)」変換で fess を遮断。
- 先行 PoC: OpenSearch 3.7.0 で scripted_upsert/knn/fuzzy 等は利用可能（バージョン確定 PoC は不要）。Phase 0 は残す場合、性能・実現性の実測（scripted_upsert の script 複雑度・スループット、セマンティックの容量/レイテンシ）に充当。
- §4.4 ロードマップに **Phase 0（性能・実現性検証、任意）** を追加、図とフェーズ表を更新（バージョン検証目的ではなく性能実測目的）。

### 3. badword（③）— 下記「badword 論点の設計判断」参照
- §2.1 に2機構の事実を追加、§2.2 ISS-04・§2.3 TBD-03・§3.3 ISS-04 行・§3.7 G8・
  §4.2 MIG-03/MIG-13・§4.3 クイックウィン・§5.2/§5.3 を整合改訂。

### 4. scripted_upsert / multiGet（④）
- MIG-15 を **第1段=multiGet（低リスク・往復削減の大半に到達）／第2段=scripted_upsert（本命・後続・慎重。OpenSearch 3.7.0 で利用可、慎重理由は script 複雑度）**
  の段階構成に改訂（§3.3 ISS-10・§3.4 ISS-10・§4.2 MIG-15・§4.3 マトリクス＆クイックウィン・§4.4 Phase 3・§5.1 TBD-01・§5.2）。
- クイックウィンに「MIG-15第1段（multiGet）」を追加。

## badword 論点の設計判断（要件と既存 MIG-03/ISS-04 の衝突をどう整合させたか）

**衝突の構図**: 新要件「部分マッチしたものは全て badword 扱いにしたい」に対し、既存 MIG-03/ISS-04 は
「誤削除防止のため `wildcard(*badword*)`→`term` 完全一致化」を推奨しており、**部分一致 vs 完全一致で方向が真逆**だった。

**切り分け（コード事実に基づく）**: 上記2機構の分析により、ISS-04 が問題視していた「誤削除」は
実際には次の2つが混在していたことが判明した。
- (a) **部分マッチで既存/新規語が除外される** こと自体 → 要件上 **意図した挙動**であり、課題ではない。
- (b) **登録時に既存語を物理 deleteByQuery で不可逆に消す** こと → 削除後に badword を取り消しても
  既存語が復元されない **不可逆性** と、`contains`/`wildcard` の **マッチ実装二重化**（乖離・メタ文字誤爆）が真の課題。

**結論（整合方針）**: 「マッチの方向（部分一致）は要件どおり維持」しつつ「削除 vs 論理除外・可逆性」を切り分けて再設計した。
- **部分一致は維持**（全て badword 扱い）。むしろ `contains` と `wildcard` を **単一の `BadWordPolicy`（spi）に統一**し、
  部分一致セマンティクスを1箇所に集約（原則3「単一の真実」）。メタ文字誤爆も解消。
- **不可逆な物理削除を可逆化**:
  - MIG-03（低コスト・スキーマ変更なし・クイックウィン）: マッチ規則統一＋**登録時の物理削除を既定オフにし、
    次回の再構築（KEEP-02、ソースから現行 badword で再導出）で反映**＝可逆。
  - MIG-13（中コスト・要 `excluded` スキーマ）: **即時かつ可逆な論理除外**（`excluded` フラグ＋検索時フィルタ）と
    **ドライラン**（適用前に除外対象件数/サンプルを提示し「巻き添え」を可視化）を上積み。

これにより **要件（部分マッチは全て badword 扱い）を満たしつつ、誤削除（＝不可逆な巻き添え物理削除）リスクを機構的に排除** する。
既存 MIG-03/ISS-04 の記述は「term 完全一致化」を削除し「マッチ統一＋可逆化」へ置換した（矛盾を解消）。

## 要確認事項（ユーザー判断が必要な点）

- **badword の即時削除 vs 可逆性の既定挙動**（§5.2 に追加）: ①即時・不可逆な物理削除（現状）／②再構築で反映＝可逆（MIG-03）／
  ③即時・可逆な論理除外（MIG-13）のどれを既定にするか。**③推奨**だが、攻撃的語の即時抹消が必須で再構築間隔が長い運用では
  ②の「再構築待ち」が許容されない可能性があり要確認。過渡期に①をオプション残置するかも判断事項。
- **scripted_upsert の採否・時期**（§5.2）: まず multiGet で止めるか第2段まで進めるか。`scripted_upsert` は OpenSearch 3.7.0 で利用可能なため、判断軸は script 複雑度・性能実測・並行競合の実害。
- **TBD-01（クローズ）**（§5.1）: OpenSearch/Lucene 数値バージョンは **3.7.0 で確定**。scripted_upsert/knn/fuzzy 等はいずれも利用可能で、バージョン起因の要確認は解消（残るのは script 複雑度・埋め込み基盤・実測）。
- **非同期の fess 露出**（§4.1.2/§5.2）: 呼び出し切替段で CompletableFuture/Result を fess まで露出させるか、
  ファサードのアダプタで吸収し続けるか。
- 移行戦略（B推奨）・score 案A/案B・設定型化・Promise 置換互換は既存のまま据え置き。

## 影響範囲・未実施

- 本作業は提案書（ドキュメント）の改訂のみ。コード変更・ビルド・テストは未実施（提案＝意思決定材料であり実装指示ではない）。
- 中間成果物（`0005`/`0009`/`0013` 等、20260622 タスク配下）本体は未改訂。必要なら別途同期が要る（要確認）。
