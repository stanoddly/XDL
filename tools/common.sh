# Sourced by the other tools. Written for bash 3.2, because macOS runners may provide it.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
patches_dir=$repo_root/patches
sdl_submodule=$repo_root/external/SDL
worktree=$repo_root/build/SDL
base_ref=refs/worktree/xdl-base
exported_ref=refs/worktree/xdl-exported

die() {
  echo "$(basename "$0"): $*" >&2
  exit 1
}

in_worktree() {
  git -C "$worktree" "$@"
}

require_sdl_submodule() {
  [[ -e "$sdl_submodule/.git" ]] || die "external/SDL is not initialized. Run: git submodule update --init external/SDL"
}

require_finished_worktree() {
  local state
  for state in rebase-apply rebase-merge; do
    [[ ! -e "$(in_worktree rev-parse --path-format=absolute --git-path "$state")" ]] \
      || die "build/SDL has a git am or rebase in progress. Finish it, or abort it there."
  done
  [[ -z "$(in_worktree status --porcelain)" ]] || die "build/SDL has uncommitted changes. Commit or discard them first."
}

add_sdl_worktree() {
  git -C "$sdl_submodule" config core.autocrlf false
  git -C "$sdl_submodule" worktree prune
  mkdir -p "$(dirname "$1")"
  git -C "$sdl_submodule" worktree add --quiet --detach "$1" "$2"
}

list_patches() {
  find "$1" -mindepth 2 -maxdepth 2 -name '*.patch' | LC_ALL=C sort
}

am_patches() {
  local target=$1
  shift
  GIT_COMMITTER_NAME=XDL GIT_COMMITTER_EMAIL=xdl@invalid git -C "$target" am -3 --keep-cr --quoted-cr=nowarn --no-gpg-sign --quiet "$@"
}
