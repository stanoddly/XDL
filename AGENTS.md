# XDL for agents

XDL holds patches for a released SDL, and for released SDL_image, SDL_ttf and SDL_mixer, called satellites. See [MAINTAINING.md](MAINTAINING.md) for the full workflow.

- Never edit a `.patch` file by hand. Edit source in `build/SDL`, commit there, and run `tools/export.sh`.
- A satellite works the same way with its name: `patches-SDL_image/`, `build/SDL_image`, `tools/apply.sh SDL_image`, `tools/export.sh SDL_image`.
- Never add source of SDL, a satellite or a library it vendors to this repo.
- To read a patch in context, run `git submodule update --init external/SDL`, then `tools/apply.sh`, and read `build/SDL`. For a satellite, use its name in both commands.
- A commit in `build/SDL` has a single-line subject that starts with its patch name: `library-name: Build the library as XDL3`.
- Keep one logical step per commit, and update the patch's `README.md` when its behavior changes.
- Anything XDL adds to the public API uses the `XDL_` prefix and lives in `include/XDL/XDL.h`, or for a satellite in its own header such as `include/SDL3_ttf/XDL_ttf.h`.
- Send nothing LLM-written to `libsdl-org`: no code, PRs, issues or comments. SDL's `AGENTS.md` bars it.
- Run `tests/tooling/run.sh` after changing anything in `tools/`.
