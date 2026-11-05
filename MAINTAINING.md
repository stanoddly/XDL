# Maintaining XDL

`tools/apply.sh` turns `patches/` into commits in `build/SDL`. `tools/export.sh` turns those commits back into `patches/`.

## Commit subjects

A commit belongs to the patch directory named at the start of its subject, without the number. For example, `library-name: Build the library as XDL3` belongs to `patches/0002-library-name/`.

`export.sh` fails if a subject names no directory, or if a directory's commits are not next to each other and in directory order.

## Changing a patch

1. Run `tools/apply.sh`, then edit and build in `build/SDL`.
2. In `build/SDL`, run `git commit --fixup <commit>`, then `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash refs/worktree/xdl-base`. This history is local and is never pushed.
3. Run `tools/export.sh` and review `git diff patches/`.

Build outside the worktree, with `cmake -S build/SDL -B build/cmake`, so `apply.sh` does not delete the build.

To add a step, commit it in `build/SDL` at its place in the series, with `git rebase -i` if it is not last.

## Adding a patch

Create `patches/NNNN-name/README.md` with five parts: what it does, why XDL needs it, which earlier patches it depends on, how to test it, and when to drop it. Then add commits with `name: ` subjects and export.

## Moving to a new SDL release

1. Move the submodule, with full history: `git -C external/SDL fetch --tags origin`, `git -C external/SDL checkout <new-tag>`, `git add external/SDL`.
2. Review `git diff <old-tag> <new-tag>` for the paths the patches touch. A new file can apply and compile while SDL changes behavior around it.
3. Run `tools/apply.sh`. At a conflict, read the patch's README, resolve it in `build/SDL`, and run `git am --continue`. To start over, run `git am --abort` there, then `tools/apply.sh`.
4. Run `tools/export.sh`, then update any README that changed.
5. Update `XDL_VERSION` in `.github/workflows/build.yml`.

## Marking a build

Pass `-DSDL_VENDOR_INFO=XDL-<version> -DSDL_REVISION=SDL-<SDL version>-<XDL commit>`. The vendor text helps meet the zlib rule that altered versions are plainly marked. The explicit revision is needed because SDL otherwise uses `git describe`, whose result depends on which tags a clone has.

## Reviewing a patch change

CI applies the base branch's series and the PR's series, then writes their `git range-diff` to the job summary. To run it locally, use `tools/range-diff.sh <base revision>`.
