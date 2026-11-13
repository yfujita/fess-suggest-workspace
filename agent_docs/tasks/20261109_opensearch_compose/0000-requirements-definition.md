# OpenSearch Docker Compose 設定

## 要件

- `opensearch/` 配下に OpenSearch を起動する Docker Compose 設定を追加する。
- OpenSearch のバージョンは Fess の設定に合わせる（`modules/fess/src/main/resources/fess-setup.properties`）。
- Fess から接続できるよう HTTP ポート `9200` を使用し、ローカルホストからのみ接続可能にする。
- 開発用の単一ノードとして起動し、インデックスデータを名前付き volume に永続化する。
- Fess のデフォルト接続先 `http://localhost:9200` に合わせるため、security plugin を無効にする。

## 起動スクリプト

- `scripts/run-opensearch.sh` から `modules/docker-fess/opensearch/<version>/Dockerfile` を使ってイメージをビルドし、OpenSearch を起動する。
- `-v` / `--version` オプションでバージョンを指定でき、省略時は `3.9` を使用する。
- `-d` / `--detach` を指定した場合はバックグラウンドで起動し、省略時はフォアグラウンドで起動する。
- Compose 設定と同じ単一ノード、localhost の HTTP `9200`、security plugin 無効化を行う。
- OpenSearch のデータと辞書をワークスペース内 `opensearch/data/` と `opensearch/dictionary/` に bind mount して永続化し、Git の管理対象外にする。
