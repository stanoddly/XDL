# remove-instruction-files

**What it does:** deletes SDL's `CLAUDE.md` and `AGENTS.md`.

**Why XDL needs it:** those files tell agents not to contribute to SDL. They would mislead an agent working on XDL, which is a downstream project under zlib. The rule still holds for SDL itself: XDL sends nothing LLM-written to `libsdl-org`. XDL's own `AGENTS.md` says so.

**Depends on:** nothing.

**How to test:** after `tools/apply.sh`, neither file exists in `build/SDL`.

**When to drop it:** when SDL removes both files.
