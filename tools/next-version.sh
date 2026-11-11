#!/usr/bin/env bash
# Prints the version that Release publishes for HEAD: <SDL version>-<N>, such as 3.4.20-13, where N is one more than the highest N of
# the tags v<SDL version>-*, or 1 when there is none. Fails when no release input changed since the newest release tag.
# Usage: tools/next-version.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 0 )) || die "usage: next-version.sh"
cd "$repo_root"

# Everything that changes what a release contains. build.yml is here because its matrix flags change the binaries, and .gitattributes
# because it decides how the patches are checked out.
release_inputs=(.gitattributes LICENSE LICENSES external 'patches*' tools/apply.sh tools/common.sh tools/sdl-version.sh tools/build-project.sh tools/build-browser.sh
  tools/emsdk-env.sh tools/collect-runtime.sh tools/third-party-notices.sh .github/workflows/build.yml .github/workflows/release.yml)

read_sdl_version HEAD

# Each line is the four numbers of a release tag and the tag, oldest first. Other tags are not releases.
releases=$(git tag --list 'v*' | sed -nE 's/^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-([1-9][0-9]*)$/\1 \2 \3 \4 &/p' \
  | sort -k1,1n -k2,2n -k3,3n -k4,4n)
newest=$(tail -n 1 <<< "$releases" | awk '{ print $5 }')
if [[ -n "$newest" ]]; then
  # A rerun of an old Release run starts at its old commit, which must not be released under a newer version.
  git merge-base --is-ancestor "$newest" HEAD || die "HEAD does not contain $newest. Start a new run on main."
  [[ -n "$(git diff --name-only "$newest" HEAD -- "${release_inputs[@]}")" ]] || die "Nothing to release: no release input changed since $newest."
fi
suffix=$(awk -v version="$sdl_version" '$1 "." $2 "." $3 == version { suffix = $4 } END { print suffix + 0 }' <<< "$releases")
echo "$sdl_version-$((suffix + 1))"
