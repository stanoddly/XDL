# XDL for agents

XDL holds patches for a released SDL. See [MAINTAINING.md](MAINTAINING.md) for the full workflow.

- Never edit a `.patch` file by hand. Edit source in `build/SDL`, commit there, and run `tools/export.sh`.
- Never add SDL source to this repo.
- To read a patch in context, run `git submodule update --init external/SDL`, then `tools/apply.sh`, and read `build/SDL`.
- A commit in `build/SDL` has a single-line subject that starts with its patch name: `library-name: Build the library as XDL3`.
- Keep one logical step per commit, and update the patch's `README.md` when its behavior changes.
- Anything XDL adds to the public API uses the `XDL_` prefix and lives in `include/XDL/XDL.h`.
- Send nothing LLM-written to `libsdl-org`: no code, PRs, issues or comments. SDL's `AGENTS.md` bars it.
- Run `tests/tooling/run.sh` after changing anything in `tools/`.
