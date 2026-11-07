#!/usr/bin/env bash
# Runs tools/apply.sh and tools/export.sh on a throwaway repo with a small fake SDL.
set -euo pipefail

tools_source=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../tools" && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Tester GIT_AUTHOR_EMAIL=tester@invalid GIT_COMMITTER_NAME=Tester GIT_COMMITTER_EMAIL=tester@invalid
# The fake submodules, nested ones included, are clones of local paths.
export GIT_ALLOW_PROTOCOL=file

passed=0
pass() {
  passed=$((passed + 1))
  echo "ok: $1"
}
fail() {
  echo "FAILED: $1" >&2
  exit 1
}

# Runs a command that must fail, and whose error must contain the given text.
expect_refusal() {
  local description=$1 expected=$2 output
  shift 2
  if output=$("$@" 2>&1); then
    fail "$description: the command succeeded"
  fi
  [[ "$output" == *"$expected"* ]] || fail "$description: expected \"$expected\" in: $output"
  pass "$description"
}

sdl=$scratch/sdl
xdl=$scratch/xdl

git init --quiet "$sdl"
printf 'one\ntwo\nthree\n' > "$sdl/lines.txt"
printf 'left\r\nmiddle\r\nright\r\n' > "$sdl/windows.txt"
git -C "$sdl" add .
git -C "$sdl" commit --quiet -m "SDL base"

git init --quiet "$xdl"
git -C "$xdl" submodule --quiet add "$sdl" external/SDL
mkdir -p "$xdl/patches/0001-alpha" "$xdl/patches/0002-beta" "$xdl/tools"
cp "$tools_source"/*.sh "$xdl/tools/"
cp "$tools_source/../.gitattributes" "$xdl/"
echo "alpha readme" > "$xdl/patches/0001-alpha/README.md"
echo "beta readme" > "$xdl/patches/0002-beta/README.md"
printf '/build/\n' > "$xdl/.gitignore"
git -C "$xdl" add .
git -C "$xdl" commit --quiet -m "Set up"

apply="$xdl/tools/apply.sh"
export_patches="$xdl/tools/export.sh"
worktree=$xdl/build/SDL

commit_change() {
  printf '%s\n' "$2" >> "$worktree/$1"
  git -C "$worktree" add .
  git -C "$worktree" commit --quiet -m "$3"
}
require_clean_patches() {
  git -C "$xdl" diff --exit-code --quiet -- patches/ || fail "$1: patches/ changed"
  [[ -z "$(git -C "$xdl" status --porcelain --untracked-files=all -- patches/)" ]] || fail "$1: patches/ has new files"
}
commit_patches() {
  git -C "$xdl" add patches
  git -C "$xdl" commit --quiet -m "$1"
}

"$apply"
[[ -f "$worktree/lines.txt" ]] || fail "apply did not create the worktree"
pass "apply works with no patches"

commit_change lines.txt four "alpha: Add four"
commit_change other.txt new "alpha: Add a file"
printf 'left\r\nchanged\r\nright\r\n' > "$worktree/windows.txt"
git -C "$worktree" add .
git -C "$worktree" commit --quiet -m "beta: Change a CRLF file"
"$export_patches"
[[ "$(find "$xdl/patches/0001-alpha" -name '*.patch' | wc -l)" -eq 2 ]] || fail "alpha should have 2 patches"
[[ "$(find "$xdl/patches/0002-beta" -name '*.patch' | wc -l)" -eq 1 ]] || fail "beta should have 1 patch"
[[ -f "$xdl/patches/0001-alpha/0002-alpha-Add-a-file.patch" ]] || fail "patch file name"
[[ -f "$xdl/patches/0002-beta/0001-beta-Change-a-CRLF-file.patch" ]] || fail "patch numbering restarts in each directory"
grep -q '^From 0000000000000000000000000000000000000000 ' "$xdl/patches/0001-alpha/0001-alpha-Add-four.patch" || fail "--zero-commit"
grep -q '^Subject: \[PATCH\] alpha: Add four$' "$xdl/patches/0001-alpha/0001-alpha-Add-four.patch" || fail "--no-numbered"
! grep -q '^-- $' "$xdl/patches/0001-alpha/0001-alpha-Add-four.patch" || fail "--no-signature"
[[ "$(<"$xdl/patches/0001-alpha/README.md")" == "alpha readme" ]] || fail "export changed a README"
pass "export writes patches into their directories"

commit_patches "First series"
exported_tree=$(git -C "$worktree" rev-parse 'HEAD^{tree}')
"$apply"
[[ "$(git -C "$worktree" rev-parse 'HEAD^{tree}')" == "$exported_tree" ]] || fail "applied tree differs"
[[ "$(git -C "$worktree" show HEAD:windows.txt | od -c | grep -c '\\r')" -gt 0 ]] || fail "CRLF was lost"
git -C "$worktree" log -1 --format=%cn | grep -q '^XDL$' || fail "fixed committer identity"
"$export_patches"
require_clean_patches "round trip"
pass "apply then export leaves patches unchanged"

printf 'edit\n' >> "$worktree/lines.txt"
expect_refusal "apply refuses uncommitted changes" "uncommitted changes" "$apply"
expect_refusal "export refuses uncommitted changes" "uncommitted changes" "$export_patches"
git -C "$worktree" checkout --quiet -- lines.txt

commit_change lines.txt five "beta: Add five"
expect_refusal "apply refuses unexported commits" "has not written" "$apply"
exported_head=$(git -C "$worktree" rev-parse HEAD~1)
git -C "$worktree" reset --quiet --hard "$exported_head"

commit_change lines.txt x "alpha: Not adjacent"
expect_refusal "export refuses non-adjacent commits" "not next to" "$export_patches"
require_clean_patches "non-adjacent refusal"
git -C "$worktree" reset --quiet --hard "$exported_head"

commit_change lines.txt x "nobody: Unknown"
expect_refusal "export refuses an unknown patch name" "names no patch directory" "$export_patches"
require_clean_patches "unknown name refusal"
git -C "$worktree" reset --quiet --hard "$exported_head"

base_commit=$(git -C "$worktree" rev-parse refs/worktree/xdl-base)
git -C "$worktree" reset --quiet --hard "$base_commit"
commit_change beta.txt x "beta: First"
commit_change alpha.txt x "alpha: Too late"
expect_refusal "export refuses reversed directory order" "out of directory order" "$export_patches"
require_clean_patches "reversed order refusal"
git -C "$worktree" reset --quiet --hard "$exported_head"

commit_change lines.txt four-fixed "fixup! alpha: Add four"
expect_refusal "export refuses an unsquashed fixup" "names no patch directory" "$export_patches"
git -C "$worktree" reset --quiet --hard "$exported_head"

printf 'second\n' >> "$worktree/other.txt"
git -C "$worktree" add .
git -C "$worktree" commit --quiet --fixup "$(git -C "$worktree" log --format=%H --grep='^alpha: Add a file$')"
GIT_SEQUENCE_EDITOR=: git -C "$worktree" rebase --quiet -i --autosquash "$(git -C "$worktree" rev-parse refs/worktree/xdl-base)" > /dev/null
"$export_patches"
grep -q '^+second$' "$xdl/patches/0001-alpha/0002-alpha-Add-a-file.patch" || fail "the fixup did not reach the patch"
[[ "$(find "$xdl/patches" -name '*.patch' | wc -l)" -eq 3 ]] || fail "the fixup changed the patch count"
pass "changing a patch with a fixup commit"
commit_patches "Second series"
second_series=$(git -C "$xdl" rev-parse HEAD)

printf 'not a patch\n' > "$xdl/patches/0002-beta/0002-broken.patch"
expect_refusal "apply names the patch that does not apply" "patches/0002-beta/0002-broken.patch" "$apply"
expect_refusal "apply refuses while git am is in progress" "in progress" "$apply"
expect_refusal "export refuses while git am is in progress" "in progress" "$export_patches"
git -C "$worktree" am --abort
rm "$xdl/patches/0002-beta/0002-broken.patch"
"$apply"
pass "apply works again after git am --abort"

# A new SDL commit conflicts with the first patch. The later patches must stay queued.
printf 'one\ntwo\nthree\nupstream\n' > "$sdl/lines.txt"
git -C "$sdl" add .
git -C "$sdl" commit --quiet -m "SDL next"
git -C "$xdl/external/SDL" fetch --quiet origin
git -C "$xdl/external/SDL" checkout --quiet "$(git -C "$sdl" rev-parse HEAD)"
git -C "$xdl" add external/SDL
expect_refusal "apply stops at a conflict after an SDL upgrade" "0001-alpha-Add-four.patch" "$apply"
printf 'one\ntwo\nthree\nupstream\nfour\n' > "$worktree/lines.txt"
git -C "$worktree" add lines.txt
GIT_EDITOR=: git -C "$worktree" am --continue > /dev/null
[[ "$(git -C "$worktree" log --format=%s "$(git -C "$sdl" rev-parse HEAD)..HEAD" | wc -l)" -eq 3 ]] || fail "git am --continue should finish the series"
expect_refusal "apply refuses a resolved series before it is exported" "has not written" "$apply"
"$export_patches"
commit_patches "Upgrade"
"$apply"
"$export_patches"
require_clean_patches "round trip after upgrade"
pass "upgrade: resolve, continue and export"

range_diff=$("$xdl/tools/range-diff.sh" "$second_series")
[[ "$range_diff" == *"alpha: Add four"* ]] || fail "range-diff output: $range_diff"
[[ "$(git -C "$xdl/external/SDL" worktree list | wc -l)" -eq 2 ]] || fail "range-diff left worktrees behind"
pass "range-diff compares two series"

expect_refusal "apply refuses an unknown project" "not a submodule" "$apply" nobody
expect_refusal "export refuses an unknown project" "not a submodule" "$export_patches" nobody
expect_refusal "range-diff refuses an unknown project" "not a submodule" "$xdl/tools/range-diff.sh" HEAD nobody

# A second project, with a vendored codec as a nested submodule.
before_satellite=$(git -C "$xdl" rev-parse HEAD)
sdl_head=$(git -C "$worktree" rev-parse HEAD)
codec=$scratch/codec
satellite=$scratch/satellite
git init --quiet "$codec"
echo "codec" > "$codec/codec.txt"
git -C "$codec" add .
git -C "$codec" commit --quiet -m "Codec base"
git init --quiet "$satellite"
printf 'left\r\nmiddle\r\nright\r\n' > "$satellite/windows.txt"
git -C "$satellite" submodule --quiet add "$codec" external/codec
git -C "$satellite" add .
git -C "$satellite" commit --quiet -m "Satellite base"
git -C "$xdl" submodule --quiet add "$satellite" external/SDL_fake
git -C "$xdl" commit --quiet -m "Add SDL_fake"
without_series=$(git -C "$xdl" rev-parse HEAD)
fake_worktree=$xdl/build/SDL_fake

apply_errors=$("$apply" SDL_fake 2>&1 > /dev/null)
[[ -z "$apply_errors" ]] || fail "apply printed errors for a project with no patch directory: $apply_errors"
[[ -f "$fake_worktree/windows.txt" ]] || fail "apply did not create the project's worktree"
pass "apply works for a project with no patch directory"
expect_refusal "export refuses a project with no patch directory" "patches-SDL_fake does not exist" "$export_patches" SDL_fake

mkdir -p "$xdl/patches-SDL_fake/0001-gamma"
echo "gamma readme" > "$xdl/patches-SDL_fake/0001-gamma/README.md"
printf 'left\r\nchanged\r\nright\r\n' > "$fake_worktree/windows.txt"
git -C "$fake_worktree" add .
git -C "$fake_worktree" commit --quiet -m "gamma: Change a CRLF file"
"$export_patches" SDL_fake
[[ -f "$xdl/patches-SDL_fake/0001-gamma/0001-gamma-Change-a-CRLF-file.patch" ]] || fail "export did not write the project's patch"
require_clean_patches "exporting another project"
[[ "$(git -C "$worktree" rev-parse HEAD)" == "$sdl_head" ]] || fail "exporting another project changed build/SDL"
pass "a project's export leaves SDL's patches and worktree alone"

git -C "$xdl" check-attr text -- patches-SDL_fake/0001-gamma/README.md | grep -q 'text: unset' || fail "patches-SDL_fake has no -text attribute"
git -C "$xdl" add patches-SDL_fake
git -C "$xdl" commit --quiet -m "Add gamma"
"$apply" SDL_fake
[[ "$(git -C "$fake_worktree" show HEAD:windows.txt | od -c | grep -c '\\r')" -gt 0 ]] || fail "the project's CRLF was lost"
"$export_patches" SDL_fake
[[ -z "$(git -C "$xdl" status --porcelain --untracked-files=all -- patches-SDL_fake/)" ]] || fail "the project's round trip changed its patches"
pass "a project's CRLF patch survives apply and export"

git -C "$fake_worktree" submodule --quiet update --init external/codec
[[ -f "$fake_worktree/external/codec/codec.txt" ]] || fail "the nested submodule was not fetched"
# Like vendored zlib, whose build renames a tracked header.
echo "built" >> "$fake_worktree/external/codec/codec.txt"
"$export_patches" SDL_fake
"$apply" SDL_fake
pass "apply and export work with a changed file in a nested submodule"

git -C "$fake_worktree" submodule --quiet update --init external/codec
echo "moved" >> "$fake_worktree/external/codec/codec.txt"
git -C "$fake_worktree/external/codec" add .
git -C "$fake_worktree/external/codec" commit --quiet -m "Moved"
expect_refusal "apply refuses a nested submodule on another commit" "uncommitted changes" "$apply" SDL_fake
git -C "$fake_worktree" submodule --quiet update external/codec
"$apply" SDL_fake

[[ "$("$xdl/tools/range-diff.sh" "$before_satellite" SDL_fake)" == *"no patch series"* ]] || fail "range-diff from a base without the project"
[[ "$("$xdl/tools/range-diff.sh" "$without_series" SDL_fake)" == *"no patch series"* ]] || fail "range-diff from a base without patches"
range_diff=$("$xdl/tools/range-diff.sh" HEAD SDL_fake)
[[ "$range_diff" == *"gamma: Change a CRLF file"* ]] || fail "the project's range-diff output: $range_diff"
[[ "$(git -C "$xdl/external/SDL_fake" worktree list | wc -l)" -eq 2 ]] || fail "the project's range-diff left worktrees behind"
pass "range-diff handles a project"

with_series=$(git -C "$xdl" rev-parse HEAD)
git -C "$xdl" rm --quiet -r patches-SDL_fake
git -C "$xdl" commit --quiet -m "Remove gamma"
[[ "$("$xdl/tools/range-diff.sh" "$with_series" SDL_fake)" == *"HEAD has no patch series"* ]] || fail "range-diff to a HEAD without patches"
git -C "$xdl" reset --quiet --hard "$with_series"
pass "range-diff reports a HEAD with no patches"

expect_refusal "range-diff refuses an unknown revision" "Unknown revision: mian" "$xdl/tools/range-diff.sh" mian SDL_fake

printf 'not a patch\n' > "$xdl/patches-SDL_fake/0001-gamma/0000-broken.patch"
git -C "$xdl" add patches-SDL_fake
git -C "$xdl" commit --quiet -m "Break gamma"
expect_refusal "range-diff fails on a patch that does not apply" "does not apply" "$xdl/tools/range-diff.sh" "$with_series" SDL_fake
[[ "$(git -C "$xdl/external/SDL_fake" worktree list | wc -l)" -eq 2 ]] || fail "the failed range-diff left worktrees behind"
git -C "$xdl" reset --quiet --hard "$with_series"

git -C "$xdl" submodule --quiet deinit --force external/SDL_fake
expect_refusal "apply refuses an uninitialized project" "is not initialized" "$apply" SDL_fake
expect_refusal "range-diff refuses an uninitialized project" "is not initialized" "$xdl/tools/range-diff.sh" HEAD SDL_fake
git -C "$xdl" submodule --quiet update --init external/SDL_fake

# Without a worktree to compare, only the right default can recreate build/SDL.
sdl_tree=$(git -C "$worktree" rev-parse 'HEAD^{tree}')
fake_head=$(git -C "$fake_worktree" rev-parse HEAD)
git -C "$xdl/external/SDL" worktree remove --force "$worktree"
"$apply"
[[ -f "$worktree/lines.txt" ]] || fail "the default project is not SDL"
[[ "$(git -C "$worktree" rev-parse 'HEAD^{tree}')" == "$sdl_tree" ]] || fail "the default project's tree changed"
[[ "$("$xdl/tools/range-diff.sh" HEAD)" == *"alpha: Add four"* ]] || fail "range-diff's default project is not SDL"
commit_change lines.txt default "beta: Prove the default"
"$export_patches"
[[ -f "$xdl/patches/0002-beta/0002-beta-Prove-the-default.patch" ]] || fail "export's default project is not SDL"
[[ "$(git -C "$fake_worktree" rev-parse HEAD)" == "$fake_head" ]] || fail "the default project changed build/SDL_fake"
[[ -z "$(git -C "$xdl" status --porcelain --untracked-files=all -- patches-SDL_fake/)" ]] || fail "the default project changed patches-SDL_fake"
git -C "$xdl" checkout --quiet -- patches
git -C "$xdl" clean --quiet -fd -- patches
"$apply"
require_clean_patches "default project"
pass "with no argument, the tools use patches/ and build/SDL and leave other projects alone"

# Upstreams for update-upstream.sh: SDL has lightweight release tags and a newer prerelease, the satellite an annotated release tag.
upstream_sdl=$scratch/upstream-sdl
upstream_satellite=$scratch/upstream-satellite
release=$scratch/release
upstream_commit() {
  git -C "$1" commit --quiet --allow-empty -m "$2"
  git -C "$1" tag "$2"
}
git init --quiet "$upstream_sdl"
upstream_commit "$upstream_sdl" release-3.4.9
upstream_commit "$upstream_sdl" release-3.4.10
upstream_commit "$upstream_sdl" prerelease-3.5.0
git init --quiet "$upstream_satellite"
upstream_commit "$upstream_satellite" release-3.2.2
git init --quiet "$release"
mkdir -p "$release/tools"
cp "$tools_source"/*.sh "$release/tools/"
cp "$tools_source/../.gitattributes" "$release/"
git -C "$release" submodule --quiet add "$upstream_sdl" external/SDL
git -C "$release" submodule --quiet add "$upstream_satellite" external/SDL_fake
git -C "$release/external/SDL" checkout --quiet release-3.4.9
echo 3.4.9-1 > "$release/XDL_VERSION"
git -C "$release" add .
git -C "$release" commit --quiet -m "Set up"
update_upstream="$release/tools/update-upstream.sh"
check_version="$release/tools/check-version.sh"

summary=$("$update_upstream")
[[ "$(head -n 1 <<< "$summary")" == "Update to SDL release-3.4.10, SDL_fake release-3.2.2" ]] || fail "update-upstream: unexpected title in: $summary"
[[ "$(git -C "$release" rev-parse :external/SDL)" == "$(git -C "$upstream_sdl" rev-parse release-3.4.10)" ]] \
  || fail "update-upstream did not move SDL to release-3.4.10"
[[ "$(git -C "$release" show :XDL_VERSION)" == 3.4.10-1 ]] || fail "update-upstream: XDL_VERSION is not 3.4.10-1 after an SDL release"
pass "update-upstream moves SDL to its newest release by number, skips prereleases and restarts the suffix"
git -C "$release" commit --quiet -m "Update"
[[ -z "$("$update_upstream")" ]] && git -C "$release" diff --cached --quiet && git -C "$release" diff --quiet -- XDL_VERSION \
  || fail "update-upstream changed something with nothing to move"
pass "update-upstream does nothing when every project is on its newest release"

git -C "$upstream_satellite" commit --quiet --allow-empty -m "Satellite release"
git -C "$upstream_satellite" tag -a release-3.2.3 -m "Satellite release"
"$update_upstream" > /dev/null
[[ "$(git -C "$release" rev-parse :external/SDL_fake)" == "$(git -C "$upstream_satellite" rev-parse 'release-3.2.3^{commit}')" ]] \
  || fail "update-upstream did not move SDL_fake to the commit of an annotated tag"
[[ "$(git -C "$release" show :XDL_VERSION)" == 3.4.10-2 ]] || fail "update-upstream: XDL_VERSION is not 3.4.10-2 after a satellite release"
pass "update-upstream raises the suffix for a satellite release and reads annotated tags"
git -C "$release" commit --quiet -m "Update the satellite"

"$check_version" HEAD~1 > /dev/null
pass "check-version accepts a version without a tag"
git -C "$release" tag v3.4.10-2
echo "notes" > "$release/NOTES.md"
git -C "$release" add NOTES.md
git -C "$release" commit --quiet -m "Add notes"
"$check_version" HEAD~1 > /dev/null
pass "check-version accepts a change that is not a release input"
mkdir -p "$release/patches-SDL_fake/0001-change"
echo "change readme" > "$release/patches-SDL_fake/0001-change/README.md"
git -C "$release" add patches-SDL_fake
git -C "$release" commit --quiet -m "Add a patch"
expect_refusal "check-version refuses a released version with changed release inputs" "patches-SDL_fake/0001-change/README.md" "$check_version" v3.4.10-2
echo 3.4.10-3 > "$release/XDL_VERSION"
git -C "$release" commit --quiet -am "Raise the version"
"$check_version" v3.4.10-2 > /dev/null
pass "check-version accepts the change once the suffix is raised"
expect_refusal "check-version refuses an unknown revision" "Unknown revision: v9" "$check_version" v9

collect_runtime="$xdl/tools/collect-runtime.sh"
prefix=$scratch/prefix
mkdir -p "$prefix/lib" "$prefix/bin"
for library in XDL3 XDL3_image XDL3_ttf XDL3_mixer; do
  echo "$library" > "$prefix/lib/lib$library.so.0.1.0"
  ln -s "lib$library.so.0.1.0" "$prefix/lib/lib$library.so.0"
  echo "$library" > "$prefix/bin/$library.dll"
done
"$collect_runtime" linux-x64 "$prefix" "$scratch/runtime/linux" > /dev/null
[[ "$(ls "$scratch/runtime/linux" | LC_ALL=C sort | tr '\n' ' ')" == "libXDL3.so libXDL3_image.so libXDL3_mixer.so libXDL3_ttf.so " ]] \
  || fail "collect-runtime: unexpected Linux files: $(ls "$scratch/runtime/linux")"
[[ ! -L "$scratch/runtime/linux/libXDL3_ttf.so" && "$(cat "$scratch/runtime/linux/libXDL3_ttf.so")" == XDL3_ttf ]] \
  || fail "collect-runtime: libXDL3_ttf.so is not a copy of the installed library"
pass "collect-runtime copies the Linux libraries under their published names"
"$collect_runtime" win-arm64 "$prefix" "$scratch/runtime/windows" > /dev/null
[[ "$(ls "$scratch/runtime/windows" | LC_ALL=C sort | tr '\n' ' ')" == "XDL3.dll XDL3_image.dll XDL3_mixer.dll XDL3_ttf.dll " ]] \
  || fail "collect-runtime: unexpected Windows files: $(ls "$scratch/runtime/windows")"
pass "collect-runtime copies the Windows libraries"
expect_refusal "collect-runtime refuses an unknown RID" "Unknown RID: android-arm64" "$collect_runtime" android-arm64 "$prefix" "$scratch/runtime/android"
expect_refusal "collect-runtime refuses a missing library" "lib/libXDL3.0.dylib does not exist" "$collect_runtime" osx-arm64 "$prefix" "$scratch/runtime/osx"

if [[ "$(uname)" == Linux ]]; then
  check_dependencies="$xdl/tools/check-dependencies.sh"
  libraries=$scratch/libraries
  mkdir -p "$libraries"
  echo 'void placeholder(void) {}' > "$libraries/placeholder.c"
  # Links <file> with the soname <soname> against the given libraries, even though it uses none of their symbols.
  link_library() {
    local file=$1 soname=$2
    shift 2
    gcc -shared -o "$libraries/$file" "-Wl,-soname,$soname" "$libraries/placeholder.c" "-L$libraries" -Wl,--no-as-needed "$@"
  }
  link_library libXDL3.so libXDL3.so.0
  link_library libSDL3.so libSDL3.so.0
  link_library libfake.so libfake.so
  link_library libXDL3_good.so libXDL3_good.so.0 -lXDL3
  link_library libXDL3_undeclared.so libXDL3_undeclared.so.0 -lXDL3 -lfake
  link_library libXDL3_stock.so libXDL3_stock.so.0 -lXDL3 -lSDL3
  link_library libXDL3_alone.so libXDL3_alone.so.0

  "$check_dependencies" "$libraries/libXDL3.so" > /dev/null
  "$check_dependencies" "$libraries/libXDL3_good.so" > /dev/null
  pass "check-dependencies accepts XDL3 and a library that needs it"
  expect_refusal "check-dependencies refuses an undeclared library" "libfake.so, which is not on the allowlist" "$check_dependencies" "$libraries/libXDL3_undeclared.so"
  expect_refusal "check-dependencies refuses stock SDL" "needs stock SDL: libSDL3.so.0" "$check_dependencies" "$libraries/libXDL3_stock.so"
  expect_refusal "check-dependencies refuses a library without XDL3" "does not need XDL3" "$check_dependencies" "$libraries/libXDL3_alone.so"

  mkdir -p "$libraries/empty"
  link_library empty/libXDL3.so libXDL3.so.0 -nostdlib
  expect_refusal "check-dependencies refuses an empty dependency list" "could not be read" "$check_dependencies" "$libraries/empty/libXDL3.so"

  # A stand-in for otool, which prints the file it is given as that library's dependencies. The first line is the install name.
  mkdir -p "$libraries/bin"
  cat > "$libraries/bin/otool" <<'EOF'
#!/usr/bin/env bash
echo "$2:"
if [[ "$1" == -D ]]; then
  sed -n 1p "$2"
else
  sed 's/^\(.*\)$/\t\1 (compatibility version 1.0.0, current version 1.0.0)/' "$2"
fi
EOF
  chmod +x "$libraries/bin/otool"
  printf '%s\n' @rpath/libXDL3_image.0.dylib @rpath/libXDL3.0.dylib /usr/lib/libSystem.B.dylib /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation > "$libraries/libXDL3_image.dylib"
  printf '%s\n' @rpath/libXDL3_stock.0.dylib @rpath/libSDL3.0.dylib > "$libraries/libXDL3_stock.dylib"
  PATH="$libraries/bin:$PATH" "$check_dependencies" "$libraries/libXDL3_image.dylib" > /dev/null
  pass "check-dependencies reads otool output"
  expect_refusal "check-dependencies refuses a dylib that needs stock SDL" "needs stock SDL: @rpath/libSDL3.0.dylib" env "PATH=$libraries/bin:$PATH" "$check_dependencies" "$libraries/libXDL3_stock.dylib"
fi

echo "$passed checks passed"
