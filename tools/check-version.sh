#!/usr/bin/env bash
# Fails when XDL_VERSION is already released as a tag and a release input changed between <base revision> and HEAD, because that change
# would never be released.
# Usage: tools/check-version.sh <base revision>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 1 )) || die "usage: check-version.sh <base revision>"
base_revision=$1
git -C "$repo_root" rev-parse --verify --quiet "$base_revision^{commit}" > /dev/null || die "Unknown revision: $base_revision"

# Everything that changes what a release contains. build.yml is here because its matrix flags change the binaries, and .gitattributes
# because it decides how the patches are checked out.
release_inputs=(XDL_VERSION .gitattributes LICENSE LICENSES external 'patches*' tools/apply.sh tools/common.sh tools/build-project.sh tools/collect-runtime.sh
  tools/third-party-notices.sh .github/workflows/build.yml .github/workflows/release.yml)

read_version
tag=v$version

if ! git -C "$repo_root" rev-parse --verify --quiet "refs/tags/$tag" > /dev/null; then
  echo "$tag is not released yet."
  exit 0
fi
changed=$(git -C "$repo_root" diff --name-only "$base_revision" HEAD -- "${release_inputs[@]}")
[[ -z "$changed" ]] || die "$tag is already released, and these release inputs changed since $base_revision:
$changed
Raise the -N suffix in XDL_VERSION, so the change gets its own release."
echo "$tag is released, and no release input changed since $base_revision."
