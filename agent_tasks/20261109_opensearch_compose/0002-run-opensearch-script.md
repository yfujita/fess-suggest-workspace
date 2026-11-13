# OpenSearch 起動スクリプトの追加

## 実施内容

- `scripts/run-opensearch.sh` を追加し、`modules/docker-fess/opensearch/<version>/Dockerfile` からイメージをビルドして起動するようにした。
- `-v` / `--version` でバージョンを指定でき、省略時は `3.9` を使用する。
- 単一ノード、localhost の `9200` 公開、security plugin 無効化、名前付き volume によるデータ永続化を設定した。
- 未対応バージョン、既存コンテナ、Docker未導入時はエラーを表示して終了する。

## 確認

- `bash -n scripts/run-opensearch.sh` が成功することを確認する。
- `--help` と異常な引数で想定どおり終了することを確認する。
