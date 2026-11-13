# OpenSearch Docker Compose 設定の追加

## 実施内容

- `opensearch/compose.yaml` を追加し、Fess が使用する OpenSearch `3.9.0` の単一ノードを定義した。
- Fess の接続先に合わせて HTTP `9200` を localhost のみに公開し、開発環境向けに security plugin を無効化した。
- `/usr/share/opensearch/data` を名前付き volume `opensearch-data` に割り当て、コンテナ再作成後もデータを保持する設定にした。
- memlock 上限を設定した。
- 初回起動で Docker が `vm.max_map_count` をコンテナ内から設定できず OCI runtime エラーになったため、Compose の `sysctls` 設定を削除した。この値はホスト側で必要に応じて設定する。

## 確認

- `docker compose -f opensearch/compose.yaml config` が成功することを確認した。
- `docker compose -f opensearch/compose.yaml up -d` で起動し、`/_cluster/health` が `green`（1 node）を返すことを確認した。
