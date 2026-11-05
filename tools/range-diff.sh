#!/usr/bin/env bash
# Prints a git range-diff between the patch series of an XDL revision and the series of HEAD.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

base_revision=${1:?usage: range-diff.sh <base revision>}
require_sdl_submodule

if ! git -C "$repo_root" rev-parse --verify --quiet "$base_revision:external/SDL" > /dev/null; then
  echo "$base_revision has no patch series."
  exit 0
fi

scratch=$(mktemp -d)
remove_scratch() {
  rm -rf "$scratch"
  git -C "$sdl_submodule" worktree prune
}
trap remove_scratch EXIT

# Prints the range of the applied series, as <SDL commit>..<last patch>.
apply_series() {
  local revision=$1 target=$scratch/$2 patch patches=()
  local sdl_commit
  sdl_commit=$(git -C "$repo_root" rev-parse "$revision:external/SDL")
  add_sdl_worktree "$target/SDL" "$sdl_commit"
  if git -C "$repo_root" cat-file -e "$revision:patches" 2> /dev/null; then
    git -C "$repo_root" archive "$revision" patches | tar -x -C "$target"
    while IFS= read -r patch; do
      patches+=("$patch")
    done < <(list_patches "$target/patches")
  fi
  if (( ${#patches[@]} > 0 )); then
    am_patches "$target/SDL" "${patches[@]}" >&2
  fi
  echo "$sdl_commit..$(git -C "$target/SDL" rev-parse HEAD)"
}

base_range=$(apply_series "$base_revision" base)
head_range=$(apply_series HEAD head)
git -C "$sdl_submodule" range-diff --no-color "$base_range" "$head_range"
