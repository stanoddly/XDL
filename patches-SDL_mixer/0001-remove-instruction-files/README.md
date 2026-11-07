# Remove SDL_mixer's agent instructions

Deletes SDL_mixer's `CLAUDE.md` and `AGENTS.md`. Those files tell agents not to contribute to SDL_mixer, which would mislead an agent working on XDL, a downstream project under zlib.

The rule still holds for SDL_mixer itself: XDL sends nothing LLM-written to `libsdl-org`, and XDL's own `AGENTS.md` says so.

## Testing

After `tools/apply.sh SDL_mixer`, neither file exists in `build/SDL_mixer`.
