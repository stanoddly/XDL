#!/usr/bin/env bash
# Writes the commits in build/SDL back to patches/. A commit's subject starts with its patch name: "library-name: Rename the library".
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[[ -e "$worktree/.git" ]] || die "build/SDL does not exist. Run tools/apply.sh first."
require_finished_worktree
base_commit=$(in_worktree rev-parse --verify "$base_ref")

[[ -z "$(in_worktree rev-list --merges "$base_commit..HEAD")" ]] || die "build/SDL contains a merge commit."

directories=()
while IFS= read -r directory; do
  directories+=("$directory")
done < <(find "$patches_dir" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)

directory_index() {
  local index=0 directory
  for directory in ${directories[@]+"${directories[@]}"}; do
    if [[ "$(basename "$directory" | sed 's/^[0-9]*-//')" == "$1" ]]; then
      echo "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

first_commits=()
last_commits=()
current_index=-1
while read -r commit subject; do
  patch_name=${subject%%: *}
  index=$(directory_index "$patch_name") || die "Commit ${commit:0:12} \"$subject\" names no patch directory."
  if (( index < current_index )); then
    if [[ -n "${first_commits[index]:-}" ]]; then
      die "Commit ${commit:0:12} \"$subject\" is not next to the other commits of $patch_name."
    fi
    die "Commit ${commit:0:12} \"$subject\" is out of directory order."
  fi
  current_index=$index
  first_commits[index]=${first_commits[index]:-$commit}
  last_commits[index]=$commit
done < <(in_worktree log --reverse --format='%H %s' "$base_commit..HEAD")

find "$patches_dir" -mindepth 2 -maxdepth 2 -name '*.patch' -delete

# --full-index because abbreviated blob ids grow with the size of the clone, which would change the patch files.
index=0
for directory in ${directories[@]+"${directories[@]}"}; do
  if [[ -n "${first_commits[index]:-}" ]]; then
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null in_worktree format-patch --zero-commit --no-signature --no-numbered --full-index \
      --output-directory "$directory" "${first_commits[index]}^..${last_commits[index]}" > /dev/null
  fi
  index=$((index + 1))
done

in_worktree update-ref "$exported_ref" HEAD
