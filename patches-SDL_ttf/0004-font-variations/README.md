# Set the axes of a variable font

Stock SDL_ttf opens a variable font at its default instance. `TTF_PROP_FONT_CREATE_FACE_NUMBER` reaches FreeType's named instances, as `instance << 16`, but only the weights the font names. Cantarell, for example, names Light 300 and Bold 700, but not 200 or 600.

This patch adds `XDL_SetFontVariations(font, variations)` to `SDL3_ttf/XDL_ttf.h`. `variations` is a comma-separated list in HarfBuzz's variation syntax: `wght=600` or `wght=300,wdth=87.5`. The function sets FreeType's design coordinates, then updates the font's metrics, clears its caches and calls `hb_ft_font_changed`, which reads the coordinates into HarfBuzz. Glyphs, advances and shaping then use the new values.

- A value outside an axis's range is clamped to it.
- An axis the list leaves out keeps the value of the named instance that the face number selected, or the font's default. NULL or an empty string restores those values for every axis.
- An axis the font does not have, an item HarfBuzz cannot parse, or a non-empty list for a font without axes fails and keeps the previous values. NULL for such a font succeeds.
- When the font has a `wght` axis, `TTF_GetFontWeight` returns its new value.

`TTF_CopyFont` copies the values and the weight, before it creates the copy's HarfBuzz font, which reads them. `TTF_OpenFontWithProperties` with `TTF_PROP_FONT_CREATE_EXISTING_FONT` can name another face number or file:

- A copy at another face number, such as another named instance, is that face as opened, with its own values and weight.
- When the original has values, a copy of another file at the same face number takes them only when its axes are the same. Otherwise it keeps its own defaults and reads its weight from its own face.
- A copy at the same face number of a font without values, or whose values were restored with NULL, takes no values. It keeps the original's weight, as stock SDL_ttf does.

Without HarfBuzz the function fails with "That operation is not supported"; XDL always builds with HarfBuzz.

## Depends on

`0002-char-spacing`: it adds `SDL3_ttf/XDL_ttf.h`.

## Testing

`tests/satellites/ttf-typography` renders `Hello` with Cantarell at weights 200, 400 and 600 and checks that a heavier weight covers more pixels. It checks that `wdth=90` fails and keeps the weight, that `wght=5000` clamps to 800, that NULL restores 400, that NULL on named instance 2 restores Light 300, that a copy of a font at weight 600 renders like it and reports 600, that a copy after NULL reports and renders 400, that a copy of named instance 2 keeps its weight, and that a copy of a 600 font at face number `2 << 16` renders Light 300 and reports what that instance reports when opened. The branch for another file with other axes has no test, because the test has one variable font.
