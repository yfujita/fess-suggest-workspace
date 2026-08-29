# 0012 ステップ 6: `docs/0003-migration-ops-design.md` の執筆

> 対象タスク: `20260706_design_document` ／ 実施日: 2026-08-13
> 対象ステップ: 作業プラン `0003-design-document-work-plan.md` §3 **ステップ 6**（作業内容 1〜9）
> 前提: ステップ 5（`0010-datamodel-design.md` ／ `0011-step5-review-reflection.md`）完了
> 凡例: `docs/0000-design-overview.md` §3.1 に同じ

---

## 1. 実施サマリ

| 項目 | 内容 |
| --- | --- |
| **成果物** | `docs/0003-migration-ops-design.md`（新規。55,709 文字 / 95,994 バイト） |
| **決定** | **MO-1〜MO-16**（同書 §0 のサマリ表）。**`MO` は本ステップで新設した接頭辞** |
| **執筆前に確定させた判断** | **5 件**（§3）。一次情報の実査で浮上し、作業プランが決めていなかった論点 |
| **新規発見** | **N-8**（`SuggestCreator.create()` に失敗時ガードが無い）、**N-9**（JobLog に失敗が現れない）、**N-10**（`Suggester.refresh()` がクラスタ全インデックスを refresh する）、**N-11**（`removeDisableIndices()` の判定はエイリアス 0 個 ＋ 前方一致であり「旧インデックス」に限定されない）、**N-12**（`createNextIndex()` は 2 リクエストの 2 段構成で孤児インデックスの発生窓がある）、**N-13**（cron 定義の実体は OpenSearch のドキュメントで `.bulk` の書き換えは既存環境に反映されない）、**N-14**（fess ↔ fess-suggest の連携テストは回帰検知能力ゼロ）、**N-15**（`suggest.version` とモジュール実体のバージョン不整合） |
| **既存資料への訂正** | **6 件**（同書 付録 A。うち 1 件は `legacy/02-architecture.md` の不足 5 点 G-1〜G-5 を内訳に持つ） |
| **コード変更** | **なし**（P10） |

### 1.1 本ステップの最重要成果

> **ゼロダウンタイム切替の機構（二重エイリアス）そのものは健全であり、壊れているのは呼び出し側の制御フローである。**

`switchIndex()` は alias の remove/add を 1 リクエストに束ねており原子的である（`Suggester.java:318-324`）。一方、それを呼ぶ `(fess) exec/SuggestCreator.java:297-301` には **`exitCode` のガードも検証ステップも存在しない**。したがって**取り込みが失敗して不完全なインデックスであっても検索エイリアスが切り替わり、直後の `:301` で健全な旧世代が物理削除される**。

この切り分けが本書の構成を決めた。作業プランは作業内容 1 を「二重エイリアス切替手順の記述」としていたが、**現行フローの欠陥を先に定義しないと、書いた手順が「今そうなっている手順」なのか「そうすべき手順」なのか読者に区別できない**。そのため 6-1 を §1（現行フローと 4 つの欠陥）と §3（To-Be 手順）の 2 節に分けた。

### 1.2 ロールバックが成立する前提が現行コードに無い

作業内容 3 は「ロールバック手順」を求めているが、**`switchIndex()` の直後に `removeDisableIndices()` が旧世代を削除するため、現状では戻し先が残らない**。`removeDisableIndices()` の判定が「エイリアスを 1 つも持たない」であること（`Suggester.java:345-353`）を利用し、**旧世代に保持用エイリアス `{baseIndex}.prev` を付けることで削除対象から外す**方式を採った（MO-4）。fess-suggest のコード変更を要しない点が決め手である。

---

## 2. 一次情報の実査

作業プラン §6.2 が「ステップ 6 の着手前に該当実装を読み切ってから書く」としていたリスクに対応し、**執筆前に 2 系統のコード実査を並行実施した**。いずれも読むだけで変更はしていない。

| 系統 | 範囲 | 主な成果 |
| --- | --- | --- |
| A | fess-suggest 側（`Suggester` の 4 メソッド、refresh 呼び出し全件、settings 読込経路、`deleteByQuery`、`knn` の不在） | N-10 / N-11 / N-12、7 ファイル表の再確認 |
| B | fess 本体側（`SuggestJob` / `SuggestCreator`、`SuggestHelper`、設定キー、リソース、バージョン依存、elevate/bad word の登録経路） | N-8 / N-9 / N-13 / N-14 / N-15、MIG-17 の命名根拠 |

実査結果は執筆時の一次ソースとして集約し、本書の事実主張はすべてそこに `file_path:line` 付きで裏づけられている（同書 付録 B）。

### 2.1 `legacy/02-architecture.md` の検証結果

**一次情報とされていた `legacy/02-architecture.md:80-91` の行番号は、すべて現行コードと一致していた**（誤りではない）。しかし**そのまま転記すると誤解を生む不足が 5 点**あった。

| # | 不足 |
| --- | --- |
| G-1 | `{baseIndex}` が未定義。実体は `fess` ではなく **`fess.suggest`** であり、しかも**設定インデックスに永続化される**ため設定値を後から変えても変わらない |
| G-2 | 「切替が原子的」は alias 付替**単体**の話。**4 ステップ全体は原子的でない** |
| G-3 | `removeDisableIndices()` は「旧インデックスの削除」ではない。**クラスタ全インデックスに対する前方一致 ＋ エイリアス 0 個**の判定である |
| G-4 | `createNextIndex()` は**2 リクエストの 2 段構成**。孤児インデックスの発生窓がある |
| G-5 | `createIndexIfNothing()`（初回セットアップ）がライフサイクルに現れない |

とくに **G-2 は本書の中核メッセージ（§1.1）を打ち消しかねない**ため、「alias 付替は atomic だが再構築プロセス全体には検証も失敗時ガードも無い」と明示的に分けて書いた。

---

## 3. 執筆前に確定させた 5 つの判断

実査の結果、作業プランが決めていない論点が 5 件浮上した。**いずれも決めないと手順が書けない**ため、執筆前に確定させた。

| # | 論点 | 決定 | 根拠 | 反映先 |
| --- | --- | --- | --- | --- |
| 1 | **失敗時ガードを fess-suggest / fess のどちらに置くか** | **fess 本体側（`SuggestCreator.create()`）**。fess-suggest に新 API を足さない | ライフサイクル制御の呼び出し元は既に fess 側 4 箇所に閉じており、**fess-suggest 内部からの呼び出しは 1 つも無い**。高水準 API を新設すると確定済みの `0001` §2.2 に遡及改訂が発生する。検証基準は fess 側の設定値に依存する | §4.3（MO-2 / MO-1） |
| 2 | **旧世代の保持方法** | **保持用エイリアス `{baseIndex}.prev` の付与**。`removeDisableIndices()` を呼ばない方式は採らない | 判定が「エイリアス 0 個」なので付けるだけで削除対象から外れ、**fess-suggest のコード変更が不要**。呼ばない方式は孤児インデックスの GC を止めてしまう | §5.1（MO-4） |
| 3 | **再構築中断の検知と復旧** | **監視項目＋手順書として定義。自動化は後続スコープ** | 「更新エイリアスだけが新世代を指す」状態を放置すると elevate word の追加が検索側に反映されない。検知には時間軸の条件が要り、設計ではなく運用基盤の話になる | §2.4（MO-16）／ K-13 |
| 4 | **`SuggestCreator` の多重起動防止** | **現行機構（`scheduler.concurrent.exec.mode=QUIT` ＋ sessionId 管理）に委ね変更しない。既知の制約として記録** | `Suggester` レベルのロックは存在しない。`EXPECTED_INDEX_COUNT` 検査は防止ではなく検知である | K-11（MO-14） |
| 5 | **`_delete_by_query` API への置換** | **スコープ外。既知の技術的負債として記録** | MIG のいずれにも属さず、`0001` §3.7 の `SuggestStore` 抽象の実装判断に属する | K-12（MO-15） |

### 3.1 追加で確定させた 2 件（MIG のスコープ解釈）

| # | 論点 | 決定 |
| --- | --- | --- |
| 6 | **MIG-16 の範囲** | **3 層に分ける**（MO-7）。(a) 取り込みバッチごとの refresh の廃止、**(b) `Suggester.refresh()` のインデックス無指定＝クラスタ全インデックス refresh の是正を MIG-16 に含める**、(c) 管理操作ごとの refresh は `0001` §6.3 の `RefreshPolicy` で制御 |
| 7 | **`suggest.source.reader.scroll.size`（既定 1）** | **スコープ外**とし申し送りに落とす。ただし「**refresh を減らしても読み出しが 1 件ずつ scroll のままでは再構築時間は改善しない**」ため、MIG-16 の効果測定では必ず同時に変数として扱う旨を明記 |

**6 は既存資料が捉えていない層である。** `(fess) helper/SuggestHelper.java` の 12 箇所の refresh 呼び出しはすべて `Suggester.refresh()`（`Suggester.java:179`、インデックス名を渡していない）を経由するため、**クラスタ全インデックスの refresh** を発行する。とくに `storeAllElevateWords` はループ内で呼ぶため **elevate word N 語で N+1 回**になり、これが再構築のたびに実行される。是正の方向自体は `0001` §2.2 が既に決めていたが、**MIG-16 の構成要素として位置づけられていなかった**（同書 付録 A の 2）。

---

## 4. 本書の構成上の判断

作業プランの作業内容 1〜9 をそのまま節にせず、**読解順に並べ替えた**（同書 §0.1 に対応表）。

| 作業プラン | 本書の節 | 並べ替えの理由 |
| --- | --- | --- |
| （なし） | **§1 現行フローと 4 つの欠陥** | §1.1 のとおり。本書固有の節 |
| 6-9（`SuggestJob` との協調） | **§2** | 起動経路を知らないと以降の手順の実行主体が読めないため、手順より前に置いた |
| 6-1（切替手順） | **§3** | |
| 6-2（検証基準） | **§4** | |
| 6-3（ロールバック） | **§5** | |
| 6-4（束ねるルール） | **§6** | |
| 6-5（refresh 戦略） | **§7** | |
| 6-6（shards/replicas） | **§8** | |
| 6-7（`knn_vector`） | **§9** | |
| 6-8（同期リリース） | **§10** | |

手順は **S0〜S5 の 6 ステップ**とし、各ステップに「**何をするか / 実装箇所 / 成功判定 / 失敗時の分岐**」の 4 属性を持たせた。完了条件が「運用者が手順書として実行できる粒度」を求めているため、実装箇所と失敗時の分岐は省略できない。ロールバックも同形式で **R1〜R4** とした。

---

## 5. 各節で確定させた主な内容

| 節 | 決定 | 要点 |
| --- | --- | --- |
| §3 | — | **S0（初回セットアップ）を手順に含めた。** 既存資料はこれを落としている（G-5）。S0 は作成と両エイリアス付与が 1 リクエストだが S1 は 2 段構成であり**非対称**である |
| §4 | MO-3 | 判定は **G1（件数の絶対下限。旧世代比 50%。設定可能）／ G2（スモーククエリ。未設定ならスキップ）／ G3（取り込み例外なし）** の 3 つ。**「新旧の件数が一致すること」を条件にしてはならない** — ID のハッシュ化で増え、語数上限 N の切り捨てで減るため両方向にずれる |
| §5 | MO-5 | ロールバックは `.prev` へ戻すのみ。**新世代に書いた内容を旧世代へ戻す経路は存在しない。** `.prev` は付けっぱなしにせず、S4 で「既存の `.prev` を remove ＋ 現検索対象に add」を 1 リクエストで行う |
| §6 | MO-6 | `0002` §4.7 の 4 変更を**再掲せず参照**し、移行手順の側の帰結だけを書いた。あわせて **OpenSearch 2.16 以上**という新しい動作要件（`0002` §9 の 2）を消化した |
| §7 | MO-7 / MO-8 | `refresh_interval = -1` は**停止側が既存の受け口**（`IndexSchema.refreshInterval`）で足り、**復帰側（`_settings` API ＋ 明示 refresh 1 回）だけが新規実装**である。**動的変更の経路は現状まったく存在しない**（`prepareUpdateSettings` の使用箇所 0 件） |
| §8 | MO-9 / MO-10 | キー名は **`index.document.suggest.number_of_shards` / `...auto_expand_replicas`**。`fess_config.properties:591` の直後に置く（crawler 系 `:595-605` と同型）。**fess 本体の既存流儀（プレースホルダ置換）を採らない理由**を明記した — C-13 の決定であり、レビューで必ず問われるため |
| §9 | MO-11 | `0002` §2.2 の `strict_allow_templates` により **`embedding` は mapping への明示が必須**（既存 dynamic_templates は string→keyword なので `knn_vector` をカバーしない）。`dimension` は予約に留める |
| §10 | MO-12 / MO-13 | 同期リリース対象は **main 4 クラス**（`SuggestHelper` / `SuggestCreator` / `SuggestWordsHandler` / `PopularWordHelper`）。申し送り 7b の同一リリース制約に **`SuggestHelper.java:466-471`（fess 本体側）を追加**した。**連携テストは「補強」ではなく「新規作成」**である |

### 5.1 申し送り 7b の範囲が広がった

`0002` §9 の 7b は「`SuggestItem` コンストラクタでの INV-1 強制と `ElevateWord.toSuggestItem` の §5.4 化は同一リリース」としていた。実査により、**`(fess) helper/SuggestHelper.java:466-471`（reading 未指定時に語を空白分割するフォールバック）も同一リリースに含める必要がある**ことが判明した。

あわせて **`0002` §5.4 の位置対応の根拠が正しいこと**を裏づけた。`:468` のフォールバックは `word` を空白分割するため、`SuggestItem` コンストラクタ（`entity/SuggestItem.java:116`）が `String.join` で結合したあとの語数 W と常に一致する（k == W）。**INV-1 に違反しうるのは `:470`（reading の明示入力）だけ**である。

---

## 6. スコープ外（本ステップで**やっていない**こと）

| # | 内容 | 理由 |
| --- | --- | --- |
| 1 | コード変更 | P10 |
| 2 | 過去タスク文書の書き換え | P9。訂正は同書 付録 A に列挙し、`0000` §6 への反映はステップ 7 |
| 3 | `0000` / `0001` / `0002` の改訂 | ステップ 7 の担当。本書は申し送りとして提出した（§7 の 2・3） |
| 4 | 実測に依存する最適値の決定 | C-04。G1 の 50%、`docPerReq`、`refresh_interval` の値、`scroll.size` はいずれも後続タスク |
| 5 | JobLog の可観測性の修正 | 既存のジョブ運用（アラート条件）に影響するため fess 本体側の互換判断が要る |
| 6 | 中断検知の自動化 | 決定 3。監視条件の定義に留めた |

---

## 7. 完了条件の判定

| 完了条件（作業プラン §3 ステップ 6） | 判定 |
| --- | --- |
| **運用者が手順書として実行できる粒度になっている**（「二重エイリアスで切り替える」で終わっていない） | **pass**。§3.2 が S0〜S5 の 6 ステップ、§5.3 が R1〜R4 のロールバック手順を、各ステップ 4 属性の表として持つ |
| **申し送り 3（`refresh_interval=-1` 定石）が消化済み** | **pass**。同書 §7.3 |
| 作業内容 1〜9 の全件消化 | **pass**。同書 §0.1 の対応表 |
| **V9**（コード根拠。特に 0003 の手順） | **pass**。手順の全ステップに実装箇所を併記 |
| **V7**（文書間整合） | **pass**。`0002` の mapping ↔ 本書の切替対象、`0001` の `SuggestIndexLifecycle` / `IndexSchema` / `RefreshPolicy` ↔ 本書の手順。**`0001` §9.1 / §9.4 との差分は付録 A の 3・4 として明示的に申し送った** |
| **V3**（`[要確認]` 残存 0 件） | **pass** |
| **V6**（分量） | **注意**。**91.7%**（提案書比）。§8 参照 |

### 7.1 V6（分量）について

本書は **55,709 文字 / 95,994 バイト**で、提案書（60,700 文字）比 **91.7%** である。目安の 1/5 を大きく超える。

| 文書 | 提案書比 |
| --- | --- |
| `0001` | 126.0% |
| `0002` | 86.6% |
| **`0003`** | **91.7%** |

**提案書・`0001`・`0002` の内容は転記していない**（`0002` §4.7 の 4 変更、§6.2 の否定形フィルタの理由、`0001` §6.2 / §6.3 の API 定義はいずれも参照に留めた）。超過は (1) 作業内容が 9 項目あること、(2) 完了条件が手順書の粒度を求めたこと、(3) **一次情報が 12 行しか無く新規書き起こしであること**（作業プラン §6.2 のリスクが顕在化した）による。

**3 文書とも同じ傾向で超過しており、これは個々の執筆の問題ではなく V6 の目安そのものが 4 文書構成（P1）と噛み合っていない可能性が高い。** 目標内に収めるにはテスト仕様・既知の制約・訂正一覧を別文書へ分離する必要があり、**P1 の変更にあたる**。最終判定はステップ 7（`0000` §8.1 の 7-5）に委ねる。

---

## 8. ステップ 7 への申し送り

同書 §13 の 9 件がすべて。うちステップ 7 が直接処理するものは以下。

| # | 事項 | 作業 |
| --- | --- | --- |
| 1 | **`0000` §3.4 の番号台帳に `MO` の行が無い** | `0002` §9 の 8 が指摘した `D` / `DM` と合わせ **3 系統をまとめて追加** |
| 2 | **`0001` §9.1 の変更ファイル一覧に `(fess) exec/SuggestCreator.java` を追加** | 同 §9.5 の「変更しない」は API 適合の観点での結論であり、失敗時ガードは別軸。**矛盾ではなく不足** |
| 3 | **`0001` §9.4 の設定キー `suggest.index.number_of_shards` を上書き** | → `index.document.suggest.number_of_shards` ＋ `auto_expand_replicas` 側も新設 |
| 4 | **付録 A の 6 件に E 番号を採番し `0000` §6 へ** | `../0009` §7 の 6 件、`0002` 付録 A の 6 件と通しで採番する |
| 5 | **`0000` §8.2 の着地確認表の読み替え** | 「`refresh_interval=-1` 定石 → 0003 §5」は**本書 §7.3**、「決定的 ID 再設計 → 0003 §6-1」は**本書 §3〜§6** |
| 6 | **`0000` §4.2 の節番号解決** | MIG-16 → §7、MIG-17 → §8、MIG-24 → §9、ID-01 / MIG-02 → §3〜§6、Phase 1b → §10 |

---

## 9. 参照した一次情報

同書 付録 B にすべて列挙してある。本ステップで**新たに読んだ**主なものは以下。

- **fess-suggest**: `Suggester.java`（全文）／ `SuggesterBuilder.java` ／ `settings/SuggestSettingsBuilder.java` ／ `index/operations/ContentIndexingOperations.java` ／ `index/operations/DeletionOperations.java` ／ `index/contents/document/ESSourceReader.java` ／ `util/SuggestUtil.java`
- **fess 本体（main）**: `exec/SuggestCreator.java`（全文）／ `job/SuggestJob.java`（全文）／ `helper/ProcessHelper.java` ／ `helper/SystemHelper.java` ／ `app/job/ScriptExecutorJob.java` ／ `app/web/admin/scheduler/AdminSchedulerAction.java` ／ `app/web/api/admin/scheduler/ApiAdminSchedulerAction.java` ／ `app/web/admin/backup/AdminBackupAction.java` ／ `opensearch/config/exentity/ScheduledJob.java` ／ `opensearch/client/SearchEngineClient.java` ／ `crawler/util/FessCrawlerConfig.java`
- **fess 本体（リソース）**: `fess_config.properties` ／ `fess_job.xml` ／ `fess_indices/fess_config.scheduled_job/scheduled_job.bulk` ／ `fess_indices/fess.json` ／ `crawler_opensearch+crawlerConfig.xml` ／ `WEB-INF/env/suggest/resources/log4j2.xml`
- **テスト**: `SuggestHelperTest` ／ `SuggestCreatorTest` ／ `SuggestJobTest` ／ `SuggestWordsHandlerTest` ／ `it/admin/SuggestTests`
- **ビルド**: `modules/fess/pom.xml` ／ `modules/fess-suggest/pom.xml` ／ `fess-parent-15.7.0.pom`
