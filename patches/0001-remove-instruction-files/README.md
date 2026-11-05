# Remove SDL's agent instructions

Deletes SDL's `CLAUDE.md` and `AGENTS.md`. Those files tell agents not to contribute to SDL, which would mislead an agent working on XDL, a downstream project under zlib.

The rule still holds for SDL itself: XDL sends nothing LLM-written to `libsdl-org`, and XDL's own `AGENTS.md` says so.

## Testing

After `tools/apply.sh`, neither file exists in `build/SDL`.
