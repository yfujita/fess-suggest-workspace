# 0002 検証環境の準備（ステップ2）

> タスク: `20260706_opensearch_reference` ステップ2（作業プラン `0001-work-plan.md` §ステップ2）。
> 実施日: 2026-07-06。凡例は改善案/00-docs-research に準拠（**[事実]** 実機/一次情報で確認 / **[提案]** 本メモの判断 / **[要確認]** 後続で確定）。
> 目的: 後続ステップ3(`scripted_upsert`)・4(`knn`)の実機検証に使う OpenSearch 3.7.0 環境と共通土台（インデックス名・サンプル・前処理）を用意し、**knn が利用可能であること**を1コマンドで確認できる状態にする。

---

## 1. 実施サマリ（結論）

- **[事実] OpenSearch 3.7.0 を Docker で起動し、REST 疎通・knn 有効を実機確認した。** 完了条件(DoD)を満たす。
- 起動手段は **Docker（`opensearchproject/opensearch:3.7.0`）／単一ノード／security 無効／heap 1g**。ホストポートは 9201（9200 競合回避）。コンテナ名 `os370-verify`。
- **[事実・プラン前提の訂正] `opensearch-runner` は 2.18.0.0 ではなく 3.7.0.0 が実際のピン止めバージョン**（fess-parent 15.7.0）。ただし runner は knn プラグインを同梱しないため、本検証は Docker 版で行う（§3）。
- 共通土台として検証用インデックス2種（`suggest_verify` / `knn_smoke`）・サンプルドキュメント・冪等な前処理スクリプトを `verification/env/` に整備し、通し疎通(`smoke-test.sh`)がグリーン。
- 疎通の副産物として、後続ステップ4のチェックリスト **K3・K4・K5 を前倒しで実証**（§5）。

## 2. 起動手段の決定と根拠

- **決定: Docker `opensearchproject/opensearch:3.7.0` 単一ノード。** [事実]
  - 環境情報どおり Docker 利用可（v20.10.13、デーモン起動中）。イメージ pull 成功、起動後 `GET /` で `"number":"3.7.0"` / `"lucene_version":"10.4.0"` を確認。
  - security 無効化（`DISABLE_SECURITY_PLUGIN=true` + `DISABLE_INSTALL_DEMO_CONFIG=true`）により TLS/初期管理者パスワード（2.12+ の `OPENSEARCH_INITIAL_ADMIN_PASSWORD`）でハマらず、平文 HTTP・curl で検証可能。単一ノードは `discovery.type=single-node`。heap は開発用に `-Xms1g -Xmx1g`。
  - ポート: 既存 9200 リスナは無し（`lsof` 確認）だが将来競合を避け **9201→9200** にマッピング。
- **プラグイン確認**: `_cat/plugins` に **`opensearch-knn 3.7.0.0`** と **`opensearch-neural-search 3.7.0.0`** が同梱されていることを確認（他に ml/ltr/security 等フル同梱）。→ knn/ハイブリッド検証に必要なプラグインが揃っている。[事実]

### 起動コマンド（再現用）
```bash
docker run -d --name os370-verify \
  -p 9201:9200 \
  -e "discovery.type=single-node" \
  -e "DISABLE_SECURITY_PLUGIN=true" \
  -e "DISABLE_INSTALL_DEMO_CONFIG=true" \
  -e "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g" \
  opensearchproject/opensearch:3.7.0
```
（スクリプト版: `verification/env/docker-run.sh`）

## 3. opensearch-runner を使わない判断と、プラン前提の訂正

作業プラン §ステップ2-2 は「runner は 2.18.0.0（2.x）」を前提に「3.7.0 固有挙動が異なり得るため runner を使わない」としていた。実機調査の結果、前提を次のとおり**訂正**する。

- **[事実] `~/.m2/repository/org/codelibs/opensearch/opensearch-runner/` に存在するバージョン**: `2.7.0.0 / 2.14.0.0 / 2.18.0.0 / 2.19.1.0 / 3.3.0.0 / 3.4.0.0 / 3.7.0.0`。
- **[事実] fess-suggest が実際にピン止めするのは 3.7.0.0**: `modules/fess-suggest/pom.xml` は親 `org.codelibs.fess:fess-parent:15.7.0` を継承し、そこで `opensearch.version=3.7.0` / `opensearch.runner.version=3.7.0.0` / `lucene.version=10.4.0` が定義されている。→ **runner のバージョンは 2.x ではなく 3.7.0.0（OpenSearch 3.7.0 相当）**。プランの「runner=2.x だからバージョン差がある」という論拠は成立しない。
- **[事実・より強い論拠] それでも Docker 版で検証すべき理由 = runner は knn プラグインを同梱しない。** `opensearch-runner-3.7.0.0.jar` の中身・`.pom` を確認したところ **knn への参照は皆無**で、`.m2` にも knn プラグイン成果物は無い。runner は OpenSearch コアを組み込み起動するだけで、**faiss/nmslib の JNI ネイティブライブラリを含む `opensearch-knn` プラグインは載らない**。knn（ベクトル）検証には、全プラグイン同梱の公式ディストリビューション（Docker イメージ）が必須。
- **結論**: バージョン差ではなく**プラグイン同梱の有無**を理由に、本検証は Docker 版 OpenSearch 3.7.0 で実施する。`scripted_upsert`（コア機能）は runner でも動くが、knn と同一環境に揃える意味でも Docker に一本化する。[提案]

## 4. knn 有効の実機確認（DoD の1コマンド）

`verification/env/healthcheck.sh` を実行。抜粋（2026-07-06 実行）:
```
=== version (http://localhost:9201) ===
    "distribution" : "opensearch",
    "number" : "3.7.0",
    "lucene_version" : "10.4.0",
=== cluster health ===
"status":"green"
"number_of_nodes":1
=== knn plugin ===
name         component                            version
9181e73f5364 opensearch-knn                       3.7.0.0
9181e73f5364 opensearch-neural-search             3.7.0.0
RESULT: knn 利用可能 (opensearch-knn プラグイン有効)
```
→ **knn プラグイン有効を1コマンドで確認できる**（見つからなければ exit 1）。DoD 充足。[事実]

## 5. 定義した共通の検証土台

`verification/env/` に配置（詳細は同ディレクトリ `README.md`）。接続先は `OS_URL=http://localhost:9201`（環境変数で上書き可）。

### 5.1 検証用インデックス
- **`suggest_verify`（`IDX_BASE`）**: ステップ3(scripted_upsert)用の共通土台。現行 `mappings-default.json` + `suggest.json` を写経（`dynamic_templates` string→keyword、`@timestamp`(epoch_millis)/`docFreq`,`queryFreq`(long)/`userBoost`,`score`(double)/`text`,`kinds`,`tags`,`roles`,`languages`,`fields`(keyword)、`shards=1`/`replicas=0`/`refresh=10s`/`auto_expand_replicas=0-1`）。定義: `base-index.json`。
- **`knn_smoke`（`IDX_KNN`）**: ステップ2/4用の knn 疎通土台。`knn_vector`（`dimension=4`（仮値・[要確認]）/`space_type=cosinesimil`/`method: hnsw`/`engine=lucene`/`ef_construction=100`/`m=16`）＋ keyword フィールド（text/roles）を共存。`index.knn: true`。定義: `knn-smoke-index.json`。
  - engine は 00-docs-research §3.2 の第一候補 **lucene**（filter 適合・小規模向け）を採用。faiss は後続の比較対象。

### 5.2 サンプルドキュメント
- `sample-docs.ndjson`: 現行 `SuggestItem` を模した3件（`text`, `reading_0/1`, `docFreq`, `queryFreq`, `userBoost`, `kinds`, `tags`, `roles`, `languages`, `fields`）。`opensearch` / `opensearch dashboards` / `検索エンジン`。→ ステップ3の頻度加算・配列マージ検証にそのまま使える。
- `knn-sample-docs.ndjson`: サンプルベクトル3件（`embedding`(dim=4) + `roles`）。roles 付きで knn+filter を試せる。

### 5.3 前処理・スクリプト（冪等）
- `common.sh`（環境変数＋`os_curl`/`os_delete_index`/`os_refresh` ヘルパー）、`docker-run.sh`/`docker-stop.sh`、`healthcheck.sh`、`setup-base-index.sh`、`setup-knn-index.sh`、`smoke-test.sh`。各 setup は「削除→再作成→投入→count」で冪等。

### 5.4 通し疎通で確認できた挙動（ステップ4チェックリストの前倒し実証）
- **[事実] keyword prefix 検索**: `prefix: {text: "opensearch"}` が `d1/d2` の2件を返す（前方一致サジェストの土台が成立）。
- **[事実] K3（`index.knn:true` 前提での knn 成立）**: `knn` クエリ `k=3` が cosine スコア順（v1≈0.9999 > v2≈0.9998 > v3≈0.7298）で3件返る。
- **[事実] K4（keyword と `knn_vector` の同一インデックス共存）**: `knn_smoke` に text/roles(keyword) と embedding(knn_vector) を共存させ、両クエリ成立。
- **[事実] K5（lucene engine の filter）**: `knn` + `filter: {term:{roles:"user"}}` が v1/v2 のみに絞り込み（lucene の smart filtering 動作を確認）。
- **[事実] dynamic_template**: 明示定義していない `reading_0`/`reading_1` が keyword にマップされることを `_mapping` で確認（ステップ5 の strict 化検討時の判断材料）。

## 6. コンテナのライフサイクル
- 検証後もコンテナは**起動したまま**（ステップ3/4で再利用）。名前 `os370-verify`、`:9201`。
- 起動: `verification/env/docker-run.sh` / 停止削除: `docker-stop.sh` / 停止のみ: `docker-stop.sh --keep`。

## 7. 実機で未確認の項目（後続で確認）
- **[要確認] K1**（nmslib が 3.7 で「作成拒否」か「警告のみ」か）: 本ステップは lucene のみ疎通。ステップ4で nmslib マッピングを投げて挙動確認。
- **[要確認] K2**（faiss での cosinesimil・space_type 既定）: 本ステップは lucene+cosinesimil のみ。ステップ4で faiss 側も確認。
- **[要確認] K6**（`hybrid` クエリ + `normalization-processor`）・**K7**（メモリ式）・**K8**（method オブジェクト方式のみでの記述）・**K9**（alias 再構築親和性）: 未実施。ステップ4/5で。
- **[要確認] `dimension`**: 埋め込みモデル未定のため仮値 4。IF 検証目的（プラン §前提のユーザー回答どおり embedding は後回し）。

## 8. ステップ3・4への申し送り
- 接続: `OS_URL=http://localhost:9201`。インデックス: `IDX_BASE=suggest_verify` / `IDX_KNN=knn_smoke`。ヘルパーは `common.sh` を source。
- **ステップ3**: `suggest_verify` を土台に `_update`(scripted_upsert) を実行。00-docs-research §4-S1 のとおり Painless の `update` context は `_execute` に無いため、使い捨てインデックス＋実 `_update` で検証する。写経対象マージ規則は `SuggestItem#getUpdatedSource`。
- **ステップ4**: `knn_smoke` を出発点に engine（lucene↔faiss）・nmslib 挙動(K1)・cosinesimil(K2)・hybrid+正規化(K6) を追加検証。lucene の filter が効くことは本ステップで実証済み。
- **ステップ5**: knn は method オブジェクト方式で記述（index レベル knn 設定は 3.0 で廃止）。`reading_*` が dynamic_template で keyword 化される点は strict 化検討の論点。
