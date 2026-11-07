# Maintaining XDL

`tools/apply.sh` turns `patches/` into commits in `build/SDL`. `tools/export.sh` turns those commits back into `patches/`.

SDL_image, SDL_ttf and SDL_mixer work the same way. Pass the project name, as in `tools/apply.sh SDL_image`, and the tools use `external/SDL_image`, `patches-SDL_image/` and `build/SDL_image`. The sections below name SDL; read `build/<project>` for a satellite.

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

Create `patches/NNNN-name/README.md` with a plain title, what the patch does and why, and a `## Testing` section. Add `## Depends on` or `## When to drop it` only when there is something real to say. Then add commits with `name: ` subjects and export.

## Adding to the public API

Declare it in `include/XDL/XDL.h` with an `XDL_` prefix, and append it to `SDL_dynapi_procs.h`, `SDL_dynapi_overrides.h` and `SDL_dynapi.sym`. If it changes XDL's dynamic API table in an incompatible way, increase the counter in `SDL_DYNAPI_VERSION`.

## Releases

Merging a pull request that raises `XDL_VERSION` to `main` releases it. The Release workflow builds every RID and publishes the GitHub release `v<XDL_VERSION>`. It holds one zip per RID with `runtimes/<rid>/native/`, `THIRD-PARTY-NOTICES.txt`, and notes with each library's tag and commit.

`XDL_VERSION` is `<SDL version>-<N>`, such as `3.4.20-1`. N starts at 1 for each SDL release. Raise N for any change to what a release contains: the submodules, the patches, the licenses, the build tools or the workflows that build. `tools/check-version.sh` lists these files. CI fails a pull request that changes one of them while `v<XDL_VERSION>` exists. A change to docs or tests needs no raise and releases nothing.

A failed release publishes nothing. Fix the cause, then run Release by hand on `main`. If two pull requests raised `XDL_VERSION` to the same value, Release fails after the second one. Raise N again to release it.

## Update pull requests

The Update upstream workflow runs every day. When SDL or a satellite has a newer `release-3.*` tag, it opens a pull request from the `update-upstream` branch. The pull request moves the submodules and raises `XDL_VERSION`, and the workflow starts Build on it. It never merges.

Review it as the next two sections describe, and push any fix to its branch. Build usually fails at "Apply and export" on such a branch. When `tools/apply.sh` stopped with "does not apply", a patch needs work in `build/<project>`. Otherwise the patches only need a new export: run `tools/apply.sh` and `tools/export.sh` for the project, and push the changed patches. Merging the pull request releases it.

- While it is open, newer releases wait.
- To skip a release, close the pull request. A new one opens only when a newer release changes the title.
- GitHub turns off the schedule of a public repository after 60 days without activity. Enable the workflow again on its page under Actions.

## Moving to a new SDL release

1. Record the notices, as in step 1 of [Moving a satellite to a new release](#moving-a-satellite-to-a-new-release). Then move the submodule, with full history: `git -C external/SDL fetch --tags origin`, `git -C external/SDL checkout <new-tag>`, `git add external/SDL`.
2. Review `git diff <old-tag> <new-tag>` for the paths the patches touch. A new file can apply and compile while SDL changes behavior around it. Also confirm that SDL has not claimed shader format bit `1u << 6`, which XDL uses for WGSL.
3. Run `tools/apply.sh`. At a conflict, read the patch's README, resolve it in `build/SDL`, and run `git am --continue`. To start over, run `git am --abort` there, then `tools/apply.sh`.
4. If the release adds functions to `SDL_dynapi_procs.h`, keep XDL's lines last and increase the counter in `SDL_DYNAPI_VERSION`. XDL's slots move, so an older XDL app would otherwise call the wrong function through `SDL3_DYNAMIC_API`.
5. Run `tools/export.sh`, then update any README that changed.
6. Rebuild XDL and the satellites, and compare the notices, as in [Third-party notices](#third-party-notices).
7. Set `XDL_VERSION` to `<SDL version>-1`. An [update pull request](#update-pull-requests) has already done this and the move of step 1, so take the before files of step 1 from `main`.

## Moving a satellite to a new release

1. Before the move, record the notices and the files with license texts, from a Linux Ninja build of every project:

   ```
   tools/third-party-notices.sh build/install build/notices-before.txt
   cat build/notices/*.sources | xargs grep -l -i -E "licen[cs]e|copyright|permission to use|permission is hereby|freely granted|public domain|unicode\.org" \
     | sed "s|^$(pwd -P)/||" | sort > build/license-files-before.txt
   ```

2. Move the submodule: `git -C external/SDL_image fetch --tags origin`, `git -C external/SDL_image checkout <new-tag>`, `git add external/SDL_image`.
3. Review `git diff <old-tag> <new-tag>` for the paths the patches touch, and for `AGENTS.md` or `CLAUDE.md` files. Such files tell agents not to contribute upstream; delete them in a patch, as `patches-SDL_mixer/0001-remove-instruction-files` does.
4. Run `tools/apply.sh SDL_image` and `tools/export.sh SDL_image`, and resolve conflicts as for SDL.
5. Check the codecs in `tools/build-project.sh`. Each satellite's list of vendored submodules matches its CMake flags. A new codec option or submodule needs a decision there, and its license must allow linking into a zlib-licensed library.
6. Run `tools/build-project.sh SDL_image build/install`, then `tools/check-dependencies.sh` on the library. Compare the codec summary that CMake prints with the old one.
7. Run step 1 again into `build/notices-after.txt` and `build/license-files-after.txt`, and compare them, as described in [Third-party notices](#third-party-notices).
8. Raise the `-N` suffix of `XDL_VERSION`, such as `3.4.20-1` to `3.4.20-2`. An update pull request has already done this.

## Third-party notices

CI's `linux-x64` job runs `tools/third-party-notices.sh` and uploads the result as the `third-party-notices` artifact. The file holds each library's license, the codec licenses that SDL_image and SDL_mixer install, notices copied from single source files, and every copyright line of every compiled source and header. The script finds the compiled files through `ninja -t query` and `ninja -t deps`, so it needs Ninja builds, and it covers only what Linux x64 compiles.

The copied notices are a list kept by hand in the script. After a move of SDL or a satellite, compare the before and after files of the section above. A new copyright holder or a new file with a license text points to code to read. Add a `notice` or `notice_file` entry when that code's license asks to keep its notice in copies or documentation and the library's own license does not cover it. Public-domain code and zlib-licensed code need no entry. A notice that moved makes the script fail with "missing or empty"; fix its start and end patterns.

Other platforms compile some sources that Linux x64 does not, such as Windows and macOS backends and ARM code in libpng and Opus. Read their license headers by hand when a move touches them.

## Marking a build

Pass `-DSDL_VENDOR_INFO=XDL-<version> -DSDL_REVISION=SDL-<SDL version>-<XDL commit>`. The vendor text helps meet the zlib rule that altered versions are plainly marked. The explicit revision is needed because SDL otherwise uses `git describe`, whose result depends on which tags a clone has. The satellites have no vendor text. Their library names, `XDL3_image`, `XDL3_ttf` and `XDL3_mixer`, mark them instead.

## Reviewing a patch change

CI applies the base branch's series and the PR's series, then writes their `git range-diff` to the job summary. To run it locally, use `tools/range-diff.sh <base revision>`.
