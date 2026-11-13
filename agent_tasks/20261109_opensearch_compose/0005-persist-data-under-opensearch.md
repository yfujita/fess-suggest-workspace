# OpenSearch データのワークスペース内永続化

## 実施内容

- OpenSearch のデータディレクトリを `opensearch/data/` に bind mount するようにした。
- 起動時に保存先ディレクトリを作成し、データファイルは `.gitignore` でGit管理対象外にした。

## 確認

- `bash -n scripts/run-opensearch.sh` が成功することを確認する。
- Dockerコマンドをモックし、保存先のbind mountが指定されることを確認する。
