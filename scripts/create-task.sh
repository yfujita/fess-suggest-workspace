#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TASKS_DIR="$WORKSPACE_DIR/agent_docs/tasks"

usage() {
  cat <<'EOF'
Usage: scripts/create-task.sh [task-name]

Create a dated task directory under agent_docs/tasks and add a requirements template.
  task-name  Task name (prompted for when omitted)
  -h, --help  Show this help

The task directory is named YYYYMMDD_<task-name>.
Task names may contain ASCII letters, numbers, underscores, and hyphens.
EOF
}

error() {
  echo "Error: $*" >&2
  exit 1
}

if (($# == 1)) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

if (($# == 0)); then
  [[ -t 0 ]] || error "Task name is required when input is not interactive"
  read -r -p "Task name: " TASK_NAME
elif (($# == 1)); then
  TASK_NAME="$1"
else
  error "Expected at most one task name (use --help for usage)"
fi

[[ "$TASK_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] \
  || error "Invalid task name: use ASCII letters, numbers, underscores, or hyphens, starting with a letter or number"

TASK_DIR="$TASKS_DIR/$(date +%Y%m%d)_$TASK_NAME"
[[ ! -e "$TASK_DIR" ]] || error "Task directory already exists: $TASK_DIR"

mkdir -p "$TASKS_DIR"
mkdir "$TASK_DIR"

cat > "$TASK_DIR/0000-requirements-definition.md" <<EOF
# タスク: $TASK_NAME

## 背景・目的

[タスクの背景と目的を記述する]

## 要件

- [実現する要件を記述する]

## 対応範囲

- [対応する範囲を記述する]

## 完了条件

- [完了を判断する条件を記述する]
EOF

echo "Created task directory: $TASK_DIR"
