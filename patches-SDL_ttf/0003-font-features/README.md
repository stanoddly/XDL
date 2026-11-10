# Set the OpenType features of shaping

Stock SDL_ttf passes HarfBuzz only the `kern` feature, so an app cannot turn on tabular figures, turn off ligatures or select a stylistic set. A counter whose digits change then changes width.

This patch adds `XDL_SetFontFeatures(font, features)` to `SDL3_ttf/XDL_ttf.h`. `features` is a comma-separated list in HarfBuzz's feature syntax: `tnum`, `tnum,-liga` or `ss01=1`. HarfBuzz also reads CSS's form, such as `"tnum" 1`. Shaping passes the list after SDL_ttf's own `kern` feature, so a `kern` item wins over `TTF_SetFontKerning`. NULL or an empty string clears the list. An item HarfBuzz cannot parse, such as the empty item in `tnum,`, fails and keeps the previous list. A feature the font does not have changes nothing.

Each font in a fallback chain shapes with its own features. `TTF_CopyFont` copies them. Without HarfBuzz the function fails with "That operation is not supported"; XDL always builds with HarfBuzz.

## Depends on

`0002-char-spacing`: it adds `SDL3_ttf/XDL_ttf.h`.

## Testing

`tests/satellites/ttf-typography` checks with Cantarell, whose figures are proportional, that `1111.11` is narrower than `8888.88`, that `tnum` makes them equal, that `tnum,` fails and keeps `tnum`, that NULL clears it, and that a copy keeps `tnum`.
