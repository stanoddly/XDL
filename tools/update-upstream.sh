#!/usr/bin/env bash
# Moves each submodule under external/ to the newest release-3.* tag of its upstream, and raises XDL_VERSION to match: <SDL version>-1
# when SDL moves, otherwise the -N suffix goes up by one. Stages both, and prints a pull request title, an empty line and a body.
# Prints nothing and changes nothing when every project is on its newest release.
# Only the index moves, so commit with plain `git commit`: `git commit --all` would take back an initialized submodule's checkout.
# Usage: tools/update-upstream.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 0 )) || die "usage: update-upstream.sh"
cd "$repo_root"

read_version

# Prints the tag names in <ls-remote output> that name <commit>, without the refs/tags/ prefix and the ^{} suffix.
tag_names() {
  awk -v commit="$2" '$1 == commit || commit == "" { name = $2; sub(/^refs\/tags\//, "", name); sub(/\^\{\}$/, "", name); print name }' <<< "$1"
}

targets=()
changes=()
sdl_target=""
for path in $(git config --file .gitmodules --get-regexp '^submodule\.external/.*\.path$' | awk '{ print $2 }'); do
  project=${path#external/}
  url=$(git config --file .gitmodules --get "submodule.$path.url")
  tags=$(git ls-remote --tags "$url" 'refs/tags/release-3.*') || die "Cannot list the tags of $url."
  # By number, so release-3.4.20 comes after release-3.4.8. Other tags, such as release-3.5.0-rc1, are not releases.
  newest=$(tag_names "$tags" "" | grep -E '^release-3\.[0-9]+\.[0-9]+$' | sort -u | sort -t. -k2,2n -k3,3n | tail -n 1) \
    || die "$url has no release-3.* tag."
  # Upstream tags are lightweight, so the tag line names the commit. An annotated tag's ^{} line names it instead.
  commit=$(awk -v tag="refs/tags/$newest" '$2 == tag "^{}" { peeled = $1 } $2 == tag { named = $1 } END { print (peeled != "" ? peeled : named) }' <<< "$tags")
  current=$(git rev-parse ":$path")
  targets+=("$project $newest")
  if [[ "$commit" != "$current" ]]; then
    current_tag=$(tag_names "$tags" "$current" | head -n 1)
    git update-index --cacheinfo "160000,$commit,$path"
    changes+=("- $project: ${current_tag:-${current:0:12}} to [$newest](${url%.git}/releases/tag/$newest)")
    [[ "$project" != SDL ]] || sdl_target=${newest#release-}
  fi
done

(( ${#changes[@]} > 0 )) || exit 0
if [[ -n "$sdl_target" ]]; then
  new_version=$sdl_target-1
else
  new_version=$sdl_version-$((suffix + 1))
fi
echo "$new_version" > XDL_VERSION
git add XDL_VERSION

title=$(printf ', %s' "${targets[@]}")
echo "Update to ${title#, }"
echo
echo "Moves to the newest upstream releases:"
echo
printf '%s\n' "${changes[@]}"
echo "- XDL_VERSION: $version to $new_version"
echo
echo "Review it on this branch as MAINTAINING.md describes for moving SDL or a satellite to a new release. Merging it releases v$new_version."
