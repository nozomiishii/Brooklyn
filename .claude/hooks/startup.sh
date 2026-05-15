#!/usr/bin/env bash
set -euo pipefail
# セッション開始時に worktree を整える（可能なら origin/main 取り込み）。

git fetch origin --quiet

# 既存の commit や未保存変更を壊さない範囲で HEAD を origin/main まで進める。
if git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
  # merge commit を作らず HEAD を進めるだけ → linear history を維持
  git merge --ff-only origin/main --quiet
fi
