# 共通設定・ヘルパー（source して使う）
# 使い方: `source ./common.sh` した上で各スクリプトを実行、または各スクリプト冒頭で source される。
#
# 環境変数で上書き可能:
#   OS_URL       : OpenSearch エンドポイント（既定 http://localhost:9201）
#   OS_CONTAINER : 検証用コンテナ名（既定 os370-verify）
#   OS_IMAGE     : 使用イメージ（既定 opensearchproject/opensearch:3.7.0）
#   OS_PORT      : ホスト側公開ポート（既定 9201）

export OS_URL="${OS_URL:-http://localhost:9201}"
export OS_CONTAINER="${OS_CONTAINER:-os370-verify}"
export OS_IMAGE="${OS_IMAGE:-opensearchproject/opensearch:3.7.0}"
export OS_PORT="${OS_PORT:-9201}"

# 検証用インデックス名（後続ステップ3/4で再利用する共通土台）
export IDX_BASE="${IDX_BASE:-suggest_verify}"   # ステップ3(scripted_upsert)用: 現行 mappings-default.json を写経した土台
export IDX_KNN="${IDX_KNN:-knn_smoke}"           # ステップ2/4用: knn 疎通確認・ベクトル検索の土台

# このスクリプト群が置かれているディレクトリ（絶対パス化）
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export ENV_DIR

# curl ショートハンド（JSON, 失敗時もレスポンス本文を表示）
os_curl() {
  curl -sS -H 'Content-Type: application/json' "$@"
}

# インデックス削除（存在しなくてもエラーにしない）
os_delete_index() {
  local idx="$1"
  os_curl -X DELETE "${OS_URL}/${idx}" -o /dev/null -w '' 2>/dev/null || true
  echo "deleted (if existed): ${idx}"
}

# リフレッシュ（検索前に可視化）
os_refresh() {
  local idx="$1"
  os_curl -X POST "${OS_URL}/${idx}/_refresh" >/dev/null
}
