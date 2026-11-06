# XDL

XDL is an altered version of [SDL](https://github.com/libsdl-org/SDL). It is not an official SDL release.

The repo holds patches, not SDL source. `external/SDL` pins a released SDL tag, and `tools/apply.sh` applies `patches/` to it in `build/SDL`, which git ignores.

## Why XDL exists

SDL does not accept contributions made with generative AI, and XDL respects that rule. A developer who uses an agent to fix an SDL bug therefore cannot share the fix through SDL.

XDL is for those developers. A fix becomes a patch here, so others can benefit from it, and nothing LLM-written goes to SDL. [AGENTS.md](AGENTS.md) tells an agent how to work in this repo.

## Build

```sh
git clone --recurse-submodules https://github.com/stanoddly/XDL.git
cd XDL
tools/apply.sh
cmake -S build/SDL -B build/cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build/cmake --config Release
```

The library is `XDL3`: `libXDL3.so.0`, `XDL3.dll` or `libXDL3.0.dylib`. The `SDL_` function names, `SDL3/` headers, `SDL3::` CMake targets and the `sdl3` pkg-config package stay the same, so code written for SDL builds against it. What XDL adds to the API is in `XDL/XDL.h`. Do not load XDL and a stock SDL in one process, because their symbols clash.

## Patches

Each directory in `patches/` is one change, with a `README.md` that explains it. [MAINTAINING.md](MAINTAINING.md) covers changing a patch and moving to a new SDL release.

## Bugs

Report XDL bugs in this repo, not to SDL. Report a problem to SDL only if a human has reproduced it on stock SDL.

## License

XDL uses the zlib license. See [LICENSE](LICENSE).
