# Add space between characters

Stock SDL_ttf 3.2 cannot track letters tighter or looser. This patch adds `XDL_SetFontCharSpacing(font, spacing)` in the new header `SDL3_ttf/XDL_ttf.h`. It adds `spacing` pixels after each character, also after the last one. For example, 2 px makes `Hello` 10 px wider. A negative value moves characters closer.

With HarfBuzz, a character is a cluster, and the spacing follows its last glyph. `q` with a combining tilde is two glyphs in one cluster, so the tilde stays over the `q` and the pair gets 2 px once. A ligature such as `ffi` is one cluster too. Without HarfBuzz each glyph gets the spacing.

The spacing is a float and is kept in 26.6 fixed point, as SDL_ttf keeps positions. With HarfBuzz, 0.25 px after each character adds 1 px over 4 characters. A value outside -32768 to 32767, or NaN, fails.

SDL_ttf's main branch has a similar function, `TTF_SetFontCharSpacing` (libsdl-org/SDL_ttf#578), not yet released. It differs in two ways: it takes whole pixels, and it adds the spacing after every glyph, also with HarfBuzz, so the tilde above would sit 2 px right of the `q`. XDL keeps its own name, float parameter and clusters.

The header is installed next to `SDL_ttf.h`, so a binding generator maps it to `XDL3_ttf` like the rest of SDL_ttf. `TTF_CopyFont` does not copy the spacing, as it does not copy the direction, script or language.

## When to drop it

Not when a release brings `TTF_SetFontCharSpacing` as it is on main, because of the two differences above. Drop it only when SDL_ttf offers fractional spacing per cluster.

## Testing

`tests/satellites/ttf-typography` measures `Hello` with 2 px, 0.5 px and 0 px of spacing, checks that `q` with a combining tilde gets 2 px once, and checks that NaN fails.
