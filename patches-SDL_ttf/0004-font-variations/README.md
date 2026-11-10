# Set the axes of a variable font

Stock SDL_ttf opens a variable font at its default instance. `TTF_PROP_FONT_CREATE_FACE_NUMBER` reaches FreeType's named instances, as `instance << 16`, but only the weights the font names. Cantarell, for example, names Light 300 and Bold 700, but not 200 or 600.

This patch adds `XDL_SetFontVariations(font, variations)` to `SDL3_ttf/XDL_ttf.h`. `variations` is a comma-separated list in HarfBuzz's variation syntax: `wght=600` or `wght=300,wdth=87.5`. The function sets FreeType's design coordinates, then updates the font's metrics, clears its caches and calls `hb_ft_font_changed`, which reads the coordinates into HarfBuzz. Glyphs, advances and shaping then use the new values.

- A value outside an axis's range is clamped to it.
- An axis the list leaves out keeps the value of the named instance that the face number selected, or the font's default. NULL or an empty string restores those values for every axis.
- An axis the font does not have, an item HarfBuzz cannot parse, or a non-empty list for a font without axes fails and keeps the previous values. NULL for such a font succeeds.
- When the font has a `wght` axis, `TTF_GetFontWeight` returns its new value.

`TTF_CopyFont` does not copy the values, so a copy reads its weight from its own face's OS/2 table instead of taking the original's. Without HarfBuzz the function fails with "That operation is not supported"; XDL always builds with HarfBuzz.

## Depends on

`0002-char-spacing`: it adds `SDL3_ttf/XDL_ttf.h`.

## Testing

`tests/satellites/ttf-typography` renders `Hello` with Cantarell at weights 200, 400 and 600 and checks that a heavier weight covers more pixels. It checks that `wdth=90` fails and keeps the weight, that `wght=5000` clamps to 800, that NULL restores 400, that NULL on named instance 2 restores Light 300, and that a copy of a font at weight 600 renders and reports 400.
