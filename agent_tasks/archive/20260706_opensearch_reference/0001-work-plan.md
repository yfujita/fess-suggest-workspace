# 作業プラン: 20260706_opensearch_reference（OpenSearch 技術検証）

> 本ドキュメントは要件定義 `0000-requirements-definition.md` に基づく作業プランである。実装ではなく **技術検証（PoC）とレポート作成** を目的とする。

## 概要

fess-suggest 抜本改善の後続設計（インデックス設計・インターフェース設計）に着手できるようにするため、未確定の OpenSearch 仕様・API を実機で検証し、前提条件を確定させる。具体的には次の3点を検証・作成し、成果物レポート `opensearch_tech_verification.md` にまとめる。

1. `scripted_upsert` による「未存在=Insert / 存在=スクリプト(Painless)で Update」の動作検証（現行 Get-then-update 置換の実現性確認、改善案 MIG-15 第2段の裏取り）
2. `knn`（ベクトル検索）を利用するためのマッピング定義・クエリ構文の要件検証（改善案 MIG-24 / 拡張点 E3 の裏取り）
3. 上記を踏まえた新 fess-suggest インデックスマッピング定義（JSON）のドラフト作成

## 前提・スコープ

### 前提（既存コード・改善案から確定済みの事実）

- **対象バージョン**: OpenSearch 3.7.0（改善案 §5.1 で TBD-01 クローズ済み・[事実]）。`scripted_upsert` / `knn` / `fuzzy` / Painless はいずれも利用可能とされている。本タスクは「バージョン可否の証明」ではなく、**具体的な API 仕様・構文・fess-suggest 用途での妥当性の確定** が目的。
- **現行スキーマ**: `modules/fess-suggest/src/main/resources/suggest_indices/suggest/mappings-default.json`
  - `dynamic_templates`: string → `keyword`
  - `properties`: `@timestamp`(date/epoch_millis), `docFreq`(long), `queryFreq`(long), `userBoost`(double), `score`(double・**死蔵**), `text`(keyword), `kinds`/`tags`/`roles`/`languages`/`fields`(keyword)
  - `reading_*` フィールド（`FieldNames.READING_PREFIX="reading_"`）は dynamic_template により keyword 化
- **現行インデックス設定**: `modules/fess-suggest/src/main/resources/suggest_indices/suggest.json`（`number_of_shards=1` / `number_of_replicas=0` / `refresh_interval=10s` / `auto_expand_replicas=0-1`）
- **現行の書き込みロジック**: `modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/index/writer/SuggestIndexWriter.java:54-69`
  - N 件ごとに `prepareGet`（同期・N 回）→ `getUpdatedSource()` でマージ → 1 回 bulk（`IndexRequest.OpType.INDEX`）。`scripted_upsert` は未使用。
  - マージ本体は `SuggestItem#getSource()` / `getUpdatedSource(existingSource)`（`modules/fess-suggest/src/main/java/org/codelibs/fess/suggest/entity/SuggestItem.java:380-398`）。→ **Painless スクリプト化の対象ロジック**。
- **現行の bad word 削除**: `WordManagementOperations.java:81` の `wildcardQuery(TEXT, "*badword*")` による deleteByQuery（本タスクの検証対象外だが新スキーマ検討時に留意）。

### スコープ

- 対象: 技術検証（scripted_upsert / knn）と新スキーマドラフト、レポート作成。
- スコープ外:
  - fess-suggest / fess 本体の実装変更（本タスクでは行わない）。
  - 適合率・スループット・レイテンシ・容量の定量評価（負荷試験・A/B。改善案 §5.3 の通り後続タスク）。
  - 埋め込みモデル・推論基盤の構築（knn は「マッピング・クエリ要件の確定」までを対象とし、実運用のベクトル生成基盤は後続）。
  - bad word 可逆化などの他 MIG の設計（別タスク）。

## ステップ

### ステップ1: 公式ドキュメント調査（Web 参照）

- 目的: 実機検証に入る前に、OpenSearch 3.7.0 の公式ドキュメントを Web で参照し、`scripted_upsert` / `knn` の**正式な仕様・構文・制約・推奨構成**を一次情報として押さえる。実機検証（ステップ3・4）はここで整理した仕様の裏取り・用途適合確認に位置づける。
- 対象モジュール/ファイル: 調査メモを `agent_docs/tasks/20260706_opensearch_reference/verification/` 配下（例 `00-docs-research.md`）に集約。ソースコードは変更しない。
- 作業内容:
  1. **バージョン確認**: OpenSearch 3.7.0 のリリースノート/ドキュメントを参照し、`scripted_upsert`・`knn`・Painless・`fuzzy` が当該バージョンで利用可能なこと、および 2.x からの破壊的変更・非推奨事項を確認する（改善案 §5.1 TBD-01 クローズの裏取り）。
  2. **`scripted_upsert` 仕様**: `_update` API / Bulk `update` アクションでの `scripted_upsert`・`upsert`・`script`・`retry_on_conflict` の公式仕様と、Painless で利用可能な API（配列操作・null 安全・型変換）を整理する。
  3. **`knn` 仕様**: `knn_vector` マッピング（`dimension` / `method` / `engine`(lucene/faiss/nmslib) / `space_type`）、`index.knn` 設定、kNN クエリ構文、ハイブリッド検索（keyword + vector）の推奨パターン、`hybrid` クエリ＋検索パイプライン（`normalization-processor`）によるスコア正規化・統合、次元・engine ごとのリソース/制約を整理する。
  4. **一次情報の URL と参照日を記録**し、レポートの根拠（[事実] 出典）として引用できる形にする。
- 完了条件: `scripted_upsert` と `knn` について、実機で検証すべき項目リスト（確認したい挙動・エッジケース）が公式ドキュメントベースで洗い出され、各項目に一次情報の出典が紐づいている状態。
- 注意点/リスク: バージョンによりデフォルト engine やパラメータ既定値が変わり得るため、必ず 3.7.0（または最も近い 3.x）系のドキュメントを参照し、参照したバージョンを明記する。ドキュメントと実機挙動が食い違った場合は実機を優先し、差分をレポートに残す。

### ステップ2: 検証環境の準備

- 目的: 実機検証のための OpenSearch 3.7.0 環境と検証手順の土台を用意する。
- 対象モジュール/ファイル: 新規作業ディレクトリ（例 `agent_docs/tasks/20260706_opensearch_reference/verification/` 配下に検証用スクリプト・リクエスト JSON を配置）。ソースコードは変更しない。
- 作業内容:
  1. OpenSearch 3.7.0 を起動する手段を確定する。第一候補は **Docker（`opensearchproject/opensearch:3.7.0`）** による単一ノード起動（`knn` プラグイン同梱の確認を含む）。REST API（curl / OpenSearch Dashboards Dev Tools 相当）で検証する。
  2. 既存テスト基盤（`opensearch-runner`）のバージョンを確認する（ローカル `.m2` には `opensearch-runner 2.18.0.0` が存在）。**テスト用 runner が 2.x の場合、3.7.0 固有挙動や knn プラグイン同梱状況が異なり得る**ため、本検証は runner ではなく実バージョンの OpenSearch で行う方針とする（この判断をレポートに明記）。
  3. 検証で用いるインデックス名・サンプルドキュメント・共通の前処理（インデックス作成/削除）を定義する。
- 完了条件: OpenSearch 3.7.0 に対して REST でインデックス作成・ドキュメント投入・検索が実行でき、`knn` が利用可能（プラグイン有効）であることを1コマンドで確認できる。
- 注意点/リスク: 検証環境（Docker）が利用不可の場合は、代替として公式ドキュメント精査＋可能な範囲の runner 検証に切り替える。その場合「実機未検証項目」をレポートに明示する（後述リスク参照）。バージョン差異（3.7.0 vs runner 2.18）を明確に切り分ける。

### ステップ3: `scripted_upsert` の API 検証

- 目的: 「ドキュメント未存在時=Insert、存在時=Painless スクリプトで Update（頻度加算・属性マージ）」が意図通り動作し、現行 Get-then-update（`SuggestIndexWriter`）を置換できるかを確定する。
- 対象モジュール/ファイル: 検証用リクエスト JSON（`verification/scripted_upsert/`）。参照元ロジックは `SuggestItem#getUpdatedSource`（マージ規則の写経対象）。
- 作業内容:
  1. 検証対象マージ規則の抽出: `getUpdatedSource()` が行っている「`queryFreq`/`docFreq` の加算」「`readings`/`tags`/`roles`/`languages`/`fields` の集合マージ」「`userBoost`/`timestamp` の更新」を列挙し、Painless で再現すべき仕様として整理する。
  2. **スクリプト単体のロジック検証（先行実施・推奨手順）**: いきなり `_update` API で試すのではなく、まず `_scripts/painless/_execute` API を使って Painless スクリプト単体を検証する。`context: "update"` と `context_setup`（`document` に既存ソース想定の JSON を渡す）で、頻度加算・配列の集合マージ・null 安全・型変換を小さく試し、型エラー/NullPointer を早期に潰す。これによりデバッグの試行錯誤時間を短縮する。
  3. `_update` API（`scripted_upsert: true` + `upsert` + `script`）の最小リクエストで、(a) 未存在 ID への初回投入=Insert、(b) 同一 ID への再投入=スクリプトによる加算・マージ、を検証する（ステップ2で単体検証済みのスクリプトを組み込む）。
  4. Bulk API 経由（`update` アクション + `scripted_upsert`）でも同様に動作すること、および `retry_on_conflict` による並行更新時の read-modify-write 競合回避を検証する（改善案 §3.3 の「原子的集約で頻度取りこぼし防止」の裏取り）。
  5. スクリプト複雑度・可読性・保守性を評価する（改善案が「script 複雑化ゆえ慎重」とする論点。stored script 化の要否も検討）。
- 完了条件: Insert/Update 双方の期待結果（頻度加算・配列マージ）を満たすリクエスト JSON とレスポンスが取得でき、採用する `scripted_upsert` 仕様（script 本体・パラメータ・bulk 構文・`retry_on_conflict` 方針）がレポートに転記できる状態。
- 注意点/リスク: Painless の配列 dedup（集合マージ）実装が煩雑になり得る。keyword 配列の重複排除方針（Painless 内 or 呼び出し側整形）を決める。エラー時（型不一致・null）の挙動も1ケース確認する。

### ステップ4: `knn`（ベクトル検索）のマッピング・API 検証

- 目的: セマンティック検索拡張（MIG-24 / E3）に必要な knn の**マッピング定義要件とクエリ構文**を確定する。実運用の埋め込み生成はスコープ外だが、フィールド定義とクエリの成立性は本タスクで確定する。
- 対象モジュール/ファイル: 検証用リクエスト JSON（`verification/knn/`）。
- 作業内容:
  1. `knn_vector` フィールドのマッピング要件を検証する: `dimension`、`method`（engine=`lucene`/`nmslib`/`faiss` の選択肢）、`space_type`（cosine/l2 等）、インデックス設定 `index.knn: true` の要否。
  2. サンプルベクトルを投入し、kNN クエリ（`knn` クエリ / `k` 指定）で近傍検索が成立することを検証する。
  3. **サジェスト用途との整合を確認する**: 既存の前方一致 keyword 検索・function score と knn を**同一インデックスで共存**できるか（ハイブリッド: keyword + vector）、またクエリ時の組み合わせ方（別クエリで取得しアプリ側マージ / スコア結合）を検証する。
  4. **スコア正規化・統合手段の確認**: OpenSearch 3.x 系では、`hybrid` クエリ ＋ 検索パイプライン（Search Pipelines）の `normalization-processor` によるスコア正規化・統合や、neural 検索プラグインのハイブリッドクエリ機能が推奨パターンとなっている。keyword スコアと knn スコアはスケールが異なり単純加算では偏るため、検索パイプライン等を用いた正規化・統合のベストプラクティスを公式ドキュメントで確認し、fess-suggest への適用可否（アプリ側マージ vs パイプライン統合）を評価する。
  5. リソース影響の定性評価: `dimension` とドキュメント数に対するインデックスサイズ・メモリ（HNSW グラフ）増加の傾向を、公式ドキュメントベースで整理する（定量測定はスコープ外）。
  6. 既存の二重エイリアス再構築（KEEP-02）・シャード設定との親和性を確認する。
- 完了条件: knn を使うための必須マッピング項目・インデックス設定・クエリ構文が確定し、サジェスト既存フィールドとの共存可否・推奨構成（ハイブリッド方式）・スコア正規化/統合手段（検索パイプライン等）がレポートに記述できる状態。
- 注意点/リスク: engine/method によりパラメータ・制約（次元上限、更新性能）が異なる。fess の埋め込みモデル未定のため `dimension` は「仮値＋要確認」とし、後続で確定する前提を明記。プラグイン（knn）が環境で無効な場合はステップ1のリスク手当てに従う。

### ステップ5: 現行スキーマ棚卸しと新スキーマドラフト作成

- 目的: 検証結果と改善案の設計判断を反映した、新 fess-suggest インデックスマッピング定義（JSON）のドラフトを作成する。
- 対象モジュール/ファイル: 現行 `suggest/mappings-default.json` / `suggest.json` を基点に、ドラフト JSON を `verification/` またはレポート内に作成（**本タスクでは実ファイルは差し替えない**）。
- 作業内容:
  1. 現行 mapping の各フィールドを「維持 / 変更 / 廃止 / 追加」で棚卸しする。
     - 廃止候補: `score`（死蔵フィールド、改善案 MIG-02 案A）。→ 廃止か保持かは改善案 §5.2 の未確定事項として両論併記。
     - 追加候補: knn 用 `knn_vector` フィールド（E3）、bad word 可逆化用 `excluded` フラグ（MIG-13）、トレンド用の時系列 freq（MIG-20）等。**本タスクでは knn フィールドと score 扱いを主対象**とし、他は「拡張余地」として枠だけ示す。
  2. **`dynamic` 設定の厳格化を検討する**: 現行は `dynamic_templates`（string→keyword）に依存し未知フィールドが自動追加される。予期せぬフィールド追加によるマッピング肥大化・意図しない型付けを防ぐため、新スキーマで `dynamic: "strict"` を採用できないか検討する。ただし `reading_*` のような**動的に増えるフィールド**（`FieldNames.READING_PREFIX`）を dynamic_template で許容している点と両立するかを確認し、strict 化する場合は reading_* を明示定義 or 別対応にするなどの整合案を示す。strict 化が難しい場合は `dynamic: false`（保存はするがインデックスしない）等の中間案も比較する。
  3. `scripted_upsert` 前提でのフィールド設計整合を確認する（加算対象=long、マージ対象=keyword 配列である現行型が Painless 加算・集合マージに適合するか）。
  4. インデックス設定（shards/replicas/refresh、`index.knn`）のドラフトを作成する（MIG-17 シャード可変化・TBD-05 は「要確認」として既定値を提示）。
  5. ドラフトに各フィールドの根拠（維持/変更理由・対応 MIG/ISS・[事実]/[提案]/[要確認] の区別）を注記する。
- 完了条件: 新スキーマ mapping JSON ドラフトと index settings ドラフトが完成し、各フィールドに設計意図・出典・確定度が付記され、「インデックス設計」タスクがそのまま議論の起点にできる状態。
- 注意点/リスク: 本タスクはドラフトであり最終確定ではない。埋め込み次元・score 採否・シャード数は未確定事項として明示し、断定しない。既存データ移行（二重エイリアス再構築 KEEP-02）で吸収できる変更範囲かを注記する。

### ステップ6: 検証レポート `opensearch_tech_verification.md` の作成

- 目的: 要件で指定された成果物を作成し、後続設計の前提条件を確定させる。
- 対象モジュール/ファイル: `agent_docs/tasks/20260706_opensearch_reference/opensearch_tech_verification.md`（新規）。検証用リクエスト JSON も同タスク配下に整理保存。
- 作業内容: 以下を1本のレポートに統合する。
  1. 検証環境・決定バージョン（OpenSearch 3.7.0、検証手段、runner との差異）
  2. `scripted_upsert` 検証結果（採用スクリプト・bulk 構文・競合対策・複雑度評価・採否/時期の推奨）
  3. `knn` 検証結果（必須マッピング/設定/クエリ構文・既存フィールド共存方式・リソース傾向・要確認）
  4. 新スキーマドラフト（mapping JSON + index settings JSON + 変更理由表）
  5. 未確定事項・後続への申し送り（埋め込み基盤、score 採否、シャード、負荷試験）
- 完了条件: レポートに「インデックス設計」「インターフェース設計」に着手できる前提（採用 API 仕様・スキーマドラフト・未確定事項の一覧）が揃っている（＝要件の Definition of Done を満たす）。
- 注意点/リスク: [事実]/[提案]/[要確認] を改善案と同じ凡例で明確に区別する。実機未検証の項目があればその旨と代替根拠（公式ドキュメント）を明記する。

## 検証方針

- **公式ドキュメント調査を起点とし、実機検証で裏取りする**二段構えとする。まず OpenSearch 3.7.0 の公式ドキュメント（一次情報）で正式仕様・構文・制約を把握し（ステップ1）、その上で実機の REST API に対する実リクエスト/レスポンスで用途適合を確認する。リクエスト JSON と参照 URL・参照日を成果物として残す（再現可能性・出典の担保）。
- ドキュメントと実機挙動が食い違った場合は **実機を優先**し、差分を明記する。
- 検証観点は「fess-suggest の現行ロジック（`SuggestItem#getUpdatedSource` のマージ規則、前方一致 keyword 検索）を置換・拡張できるか」に置き、単なる API 単体動作でなく**用途適合**を確認する。
- 定量性能（スループット・レイテンシ・容量）は測定せず、定性評価＋公式ドキュメント根拠にとどめる（負荷試験は後続タスク、改善案 §5.3）。
- 各検証項目の合否と、確定できた事項/できなかった事項を明確に分離してレポートする。

## リスクと未確定事項

- **検証環境の可用性**: OpenSearch 3.7.0（Docker）と knn プラグインが利用できない場合、実機検証が一部できない。→ その場合は公式ドキュメント精査を根拠とし、「実機未検証」を明示（ユーザーに環境利用可否を確認）。
x- **埋め込みモデル/次元の未定**: knn の `dimension`・`method`・`space_type` は採用モデル依存。本タスクでは仮値で構文検証し、確定は後続（MIG-24 前提の「要確認」）。
- **score 採否・シャード数**: 改善案 §5.2 の未確定（案A/案B、TBD-05）に依存。新スキーマドラフトでは両論併記・既定値提示にとどめ断定しない。
- **Painless スクリプト複雑度**: 配列の集合マージ実装が煩雑化し得る。stored script 化・呼び出し側整形との分担は検証結果を見て判断（採否の最終判断はユーザー）。
- **確認したい事項（ユーザー）**: (1) 検証環境として Docker(OpenSearch 3.7.0) を用意してよいか、(2) knn の想定埋め込みモデル/次元の当たりがあるか、(3) 本タスクのドラフトで score を「廃止前提」で描いてよいか（両論併記でよいか）。
  1. 結論: 「廃止前提」で描き、注記として復活の余地を残す形を推奨します。
  2. Embeddingはモデルを用意できていないので後回し。IFだけ用意できていればいい。
  3. 結論: 「廃止前提」で描き、注記として復活の余地を残す形を推奨します。
