#!/usr/bin/env bash
# Prints a git range-diff between a project's patch series at an XDL revision and its series at HEAD. The project defaults to SDL.
# Usage: tools/range-diff.sh <base revision> [project]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

base_revision=${1:?usage: range-diff.sh <base revision> [project]}
select_project "${2:-SDL}"
require_project_submodule
git -C "$repo_root" rev-parse --verify --quiet "$base_revision^{commit}" > /dev/null || die "Unknown revision: $base_revision"

if ! git -C "$repo_root" rev-parse --verify --quiet "$base_revision:external/$project" > /dev/null; then
  echo "$base_revision has no patch series."
  exit 0
fi

scratch=$(mktemp -d)
remove_scratch() {
  rm -rf "$scratch"
  git -C "$project_submodule" worktree prune
}
trap remove_scratch EXIT

# Prints the range of the applied series, as <project commit>..<last patch>. It runs in a command substitution, where set -e is off, so a failed patch has to exit by itself.
apply_series() {
  local revision=$1 target=$scratch/$2 patch patches=()
  local pinned_commit
  pinned_commit=$(git -C "$repo_root" rev-parse "$revision:external/$project")
  add_project_worktree "$target/$project" "$pinned_commit"
  if git -C "$repo_root" cat-file -e "$revision:$patches_name" 2> /dev/null; then
    git -C "$repo_root" archive "$revision" "$patches_name" | tar -x -C "$target"
    while IFS= read -r patch; do
      patches+=("$patch")
    done < <(list_patches "$target/$patches_name")
  fi
  if (( ${#patches[@]} > 0 )); then
    am_patches "$target/$project" "${patches[@]}" >&2 || die "The patch series of $revision does not apply."
  fi
  echo "$pinned_commit..$(git -C "$target/$project" rev-parse HEAD)"
}

base_range=$(apply_series "$base_revision" base)
head_range=$(apply_series HEAD head)
# git range-diff refuses an empty range.
if [[ "${base_range%%..*}" == "${base_range##*..}" ]]; then
  echo "$base_revision has no patch series."
elif [[ "${head_range%%..*}" == "${head_range##*..}" ]]; then
  echo "HEAD has no patch series."
else
  git -C "$project_submodule" range-diff --no-color "$base_range" "$head_range"
fi
