# Fix a skipped 3D position change

`MIX_SetTrack3DPosition` in SDL_mixer 3.2.4 compares the new y with the stored z instead of the stored y. Example: a track at (0, 0, 5) moved to (0, 5, 5) keeps its old position. x and z are unchanged and the new y equals the stored z, so the function never stores the new position and never calls `MIX_Spatialize`. Panning and distance attenuation stay at (0, 0, 5).

The patch is upstream commit 815594e on `release-3.2.x`, cherry-picked from 72cb03c on `main`. It fixes `libsdl-org/SDL_mixer#904`.

## When to drop it

Drop it when SDL_mixer moves to a release after 3.2.4 that contains 815594e. `tools/apply.sh SDL_mixer` does not stop there. `git am` sees the change as already applied and makes no commit, so `tools/export.sh SDL_mixer` deletes the `.patch` file. Delete this directory then.

## Testing

After `tools/apply.sh SDL_mixer`, `MIX_SetTrack3DPosition` in `build/SDL_mixer/src/SDL_mixer.c` compares `tposition3d[1]` with `position->y`.
