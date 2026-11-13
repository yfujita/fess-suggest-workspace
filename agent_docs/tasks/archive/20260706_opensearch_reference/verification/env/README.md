# 検証環境 (OpenSearch 3.7.0) — 再現手順

タスク `20260706_opensearch_reference` ステップ2で用意した検証環境。後続ステップ3(`scripted_upsert`)・ステップ4(`knn`)で再利用する。

## 前提
- Docker が利用可能（本検証時: v20.10.13）。
- ホスト側ポート **9201** を使用（9200 は他用途と競合し得るため回避）。
- security プラグインは無効化（単一ノード・技術検証専用の最小構成。**本番設定ではない**）。

## クイックスタート
```bash
cd agent_docs/tasks/20260706_opensearch_reference/verification/env
./docker-run.sh       # OpenSearch 3.7.0 起動 (コンテナ名 os370-verify, :9201)
./healthcheck.sh      # 【DoD】version + health + knn プラグイン有効を1コマンド確認
./smoke-test.sh       # health→keyword検索→knn検索まで通し疎通
```

## ファイル一覧
| ファイル | 役割 |
|---|---|
| `common.sh` | 共通の環境変数（`OS_URL`, `IDX_BASE`, `IDX_KNN` 等）と curl/削除/refresh ヘルパー。他スクリプトが source する |
| `docker-run.sh` | コンテナ起動（single-node / security 無効 / heap 1g）。起動完了まで待機 |
| `docker-stop.sh` | 停止＋削除。`--keep` で停止のみ |
| `healthcheck.sh` | **DoD の1コマンド確認**。knn 無ければ exit 1 |
| `base-index.json` | ステップ3用の共通土台インデックス定義（現行 mappings-default.json + suggest.json を写経） |
| `sample-docs.ndjson` | 現行 SuggestItem を模したサンプル3件（text/freq/roles/tags/reading_* 等） |
| `setup-base-index.sh` | `suggest_verify` を再作成しサンプル投入 |
| `knn-smoke-index.json` | knn 疎通用インデックス定義（`knn_vector` dim=4 / engine=lucene / cosinesimil / `index.knn:true`） |
| `knn-sample-docs.ndjson` | サンプルベクトル3件（roles 付きで filter 検証も可能） |
| `setup-knn-index.sh` | `knn_smoke` を再作成しベクトル投入 |
| `smoke-test.sh` | 上記を通しで実行するエンドツーエンド疎通 |

## 共通の検証土台（後続ステップへの申し送り）
- 接続先: `OS_URL=http://localhost:9201`（環境変数で上書き可）
- インデックス名: `IDX_BASE=suggest_verify`（scripted_upsert 用） / `IDX_KNN=knn_smoke`（knn 用）
- 前処理: `os_delete_index <idx>` / `os_refresh <idx>`（`common.sh`）。各 setup スクリプトは冪等（削除→再作成）。

## 停止・破棄
```bash
./docker-stop.sh          # 停止＋削除
./docker-stop.sh --keep   # 停止のみ（データ保持）
```
検証終了後もコンテナは起動したまま残してよい（ステップ3/4で再利用）。
