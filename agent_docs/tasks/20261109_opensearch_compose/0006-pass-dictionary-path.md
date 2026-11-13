# OpenSearch の辞書パス設定

## 実施内容

- `modules/docker-fess/opensearch/3.9/Dockerfile` の `configsync.config_path` が `${FESS_DICTIONARY_PATH}` を参照するため、コンテナ環境変数に辞書パスを設定した。
- Compose設定に合わせ、辞書ディレクトリも `opensearch/dictionary/` に bind mount して永続化するようにした。
- 辞書データを `.gitignore` に追加した。

## 確認

- `bash -n scripts/run-opensearch.sh` が成功することを確認する。
- Dockerコマンドをモックし、環境変数とデータ・辞書の両bind mountが渡されることを確認する。
