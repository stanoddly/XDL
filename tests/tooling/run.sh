#!/usr/bin/env bash
# Runs tools/apply.sh and tools/export.sh on a throwaway repo with a small fake SDL.
set -euo pipefail

tools_source=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../tools" && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Tester GIT_AUTHOR_EMAIL=tester@invalid GIT_COMMITTER_NAME=Tester GIT_COMMITTER_EMAIL=tester@invalid

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
git -C "$xdl" -c protocol.file.allow=always submodule --quiet add "$sdl" external/SDL
mkdir -p "$xdl/patches/0001-alpha" "$xdl/patches/0002-beta" "$xdl/tools"
cp "$tools_source"/*.sh "$xdl/tools/"
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
git -C "$xdl/external/SDL" -c protocol.file.allow=always fetch --quiet origin
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

echo "$passed checks passed"
