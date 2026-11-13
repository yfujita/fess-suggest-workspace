#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OPENSEARCH_DOCKER_DIR="$WORKSPACE_DIR/modules/docker-fess/opensearch"
DATA_DIR="$WORKSPACE_DIR/opensearch/data"
DICTIONARY_DIR="$WORKSPACE_DIR/opensearch/dictionary"
VERSION="3.9"
DETACH=false
IMAGE_NAME="fess-opensearch"
CONTAINER_NAME="fess-opensearch"

usage() {
  cat <<'EOF'
Usage: scripts/run-opensearch.sh [-d|--detach] [--version VERSION|-v VERSION]

Build and run the Fess OpenSearch Docker image.
  -d, --detach           Run in the background (default: foreground)
  -v, --version VERSION  OpenSearch version (default: 3.9)
  -h, --help             Show this help
EOF
}

error() {
  echo "Error: $*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    -v|--version)
      (($# >= 2)) || error "Missing value for $1"
      VERSION="$2"
      shift 2
      ;;
    --version=*)
      VERSION="${1#*=}"
      [[ -n "$VERSION" ]] || error "Missing value for --version"
      shift
      ;;
    -d|--detach)
      DETACH=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1 (use --help for usage)"
      ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ || "$VERSION" == "snapshot" ]] \
  || error "Invalid version: $VERSION"

DOCKERFILE_DIR="$OPENSEARCH_DOCKER_DIR/$VERSION"
DOCKERFILE="$DOCKERFILE_DIR/Dockerfile"
[[ -f "$DOCKERFILE" ]] || error "Dockerfile not found for OpenSearch $VERSION: $DOCKERFILE"

command -v docker >/dev/null 2>&1 || error "Docker is required but was not found"

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  error "Container '$CONTAINER_NAME' already exists. Remove it with 'docker rm -f $CONTAINER_NAME' before retrying."
fi

docker build --tag "$IMAGE_NAME:$VERSION" --file "$DOCKERFILE" "$DOCKERFILE_DIR"

DOCKER_RUN_OPTIONS=(run)
if [[ "$DETACH" == true ]]; then
  DOCKER_RUN_OPTIONS+=(--detach)
fi

echo "Starting OpenSearch $VERSION on http://localhost:9200"
mkdir -p "$DATA_DIR" "$DICTIONARY_DIR"
docker "${DOCKER_RUN_OPTIONS[@]}" \
  --name "$CONTAINER_NAME" \
  --rm \
  --publish 127.0.0.1:9200:9200 \
  --env cluster.name=fess \
  --env discovery.type=single-node \
  --env DISABLE_SECURITY_PLUGIN=true \
  --env DISABLE_INSTALL_DEMO_CONFIG=true \
  --env FESS_DICTIONARY_PATH=/usr/share/opensearch/config/dictionary \
  --env OPENSEARCH_JAVA_OPTS="-Xms3g -Xmx3g" \
  --ulimit memlock=-1:-1 \
  --mount "type=bind,source=$DATA_DIR,target=/usr/share/opensearch/data" \
  --mount "type=bind,source=$DICTIONARY_DIR,target=/usr/share/opensearch/config/dictionary" \
  "$IMAGE_NAME:$VERSION"

if [[ "$DETACH" == true ]]; then
  echo "OpenSearch $VERSION started as '$CONTAINER_NAME'"
fi