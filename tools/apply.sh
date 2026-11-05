#!/usr/bin/env bash
# Recreates build/SDL at the pinned SDL commit and applies every patch.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_sdl_submodule
if [[ -e "$worktree/.git" ]]; then
  require_finished_worktree
  [[ "$(in_worktree rev-parse HEAD)" == "$(in_worktree rev-parse --verify --quiet "$exported_ref" || true)" ]] \
    || die "build/SDL has commits that tools/export.sh has not written. Export them, or discard them with: git -C external/SDL worktree remove --force build/SDL"
  git -C "$sdl_submodule" worktree remove --force "$worktree"
elif [[ -e "$worktree" ]]; then
  die "build/SDL exists but is not a git worktree. Remove it first."
fi

pinned_commit=$(git -C "$repo_root" rev-parse :external/SDL)
add_sdl_worktree "$worktree" "$pinned_commit"
in_worktree update-ref "$base_ref" "$pinned_commit"
in_worktree update-ref "$exported_ref" "$pinned_commit"

patches=()
while IFS= read -r patch; do
  patches+=("$patch")
done < <(list_patches "$patches_dir")
(( ${#patches[@]} > 0 )) || exit 0

if ! am_patches "$worktree" "${patches[@]}"; then
  next=$(<"$(in_worktree rev-parse --path-format=absolute --git-path rebase-apply/next)")
  die "${patches[next - 1]#"$repo_root"/} does not apply. In build/SDL, resolve it and run git am --continue, then run tools/export.sh. To start over, run git am --abort there, then tools/apply.sh."
fi
in_worktree update-ref "$exported_ref" HEAD
