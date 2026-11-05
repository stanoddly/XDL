# library-name

**What it does:** names the built library `XDL3` instead of `SDL3`: `libXDL3.so.0`, `XDL3.dll`, `libXDL3.0.dylib` and `libXDL3.a`. As in stock SDL, the static library gets a `-static` suffix (`XDL3-static`) on platforms where it would otherwise clash with the DLL's import library, and for Apple frameworks. `pkg-config --libs sdl3` prints `-lXDL3`, and the Windows version resource names `XDL3.dll`.

The `SDL_` function names, `SDL3/` headers, `SDL3::` CMake targets and the `sdl3` pkg-config package name stay. Patches and libraries built for SDL, such as SDL_image, keep working.

**Why XDL needs it:** a stock `libSDL3` cannot then load in XDL's place, and a later XDL based on SDL 4 can sit beside it.

**Depends on:** nothing.

**How to test:** build and install, then:

- `readelf -d <prefix>/lib/libXDL3.so.0` shows the soname `libXDL3.so.0`.
- `pkg-config --libs sdl3` prints `-lXDL3`.
- `tests/consumer` finds the installed package with `find_package(SDL3)` and links.

**When to drop it:** never, while XDL ships its own library.
