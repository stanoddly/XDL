# Sourced by the other tools. Written for bash 3.2, because macOS runners may provide it.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
base_ref=refs/worktree/xdl-base
exported_ref=refs/worktree/xdl-exported

die() {
  echo "$(basename "$0"): $*" >&2
  exit 1
}

# Sets the paths of a project: SDL, or a library such as SDL_image that has a submodule at external/<project>.
select_project() {
  project=$1
  [[ "$(git -C "$repo_root" config --file .gitmodules --get "submodule.external/$project.path" || true)" == "external/$project" ]] \
    || die "external/$project is not a submodule of this repo."
  project_submodule=$repo_root/external/$project
  worktree=$repo_root/build/$project
  patches_name=patches-$project
  if [[ "$project" == SDL ]]; then
    patches_name=patches
  fi
  patches_dir=$repo_root/$patches_name
}

in_worktree() {
  git -C "$worktree" "$@"
}

require_project_submodule() {
  [[ -e "$project_submodule/.git" ]] || die "external/$project is not initialized. Run: git submodule update --init external/$project"
}

# Ignores files changed inside a nested submodule, because vendored zlib renames a tracked header when it is built. A nested submodule on another commit still counts.
require_finished_worktree() {
  local state
  for state in rebase-apply rebase-merge; do
    [[ ! -e "$(in_worktree rev-parse --path-format=absolute --git-path "$state")" ]] \
      || die "build/$project has a git am or rebase in progress. Finish it, or abort it there."
  done
  [[ -z "$(in_worktree status --porcelain --ignore-submodules=dirty)" ]] || die "build/$project has uncommitted changes. Commit or discard them first."
}

add_project_worktree() {
  git -C "$project_submodule" config core.autocrlf false
  git -C "$project_submodule" worktree prune
  mkdir -p "$(dirname "$1")"
  git -C "$project_submodule" worktree add --quiet --detach "$1" "$2"
}

list_patches() {
  [[ -d "$1" ]] || return 0
  find "$1" -mindepth 2 -maxdepth 2 -name '*.patch' | LC_ALL=C sort
}

am_patches() {
  local target=$1
  shift
  GIT_COMMITTER_NAME=XDL GIT_COMMITTER_EMAIL=xdl@invalid git -C "$target" am -3 --keep-cr --quoted-cr=nowarn --no-gpg-sign --quiet "$@"
}
