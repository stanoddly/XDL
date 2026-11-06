# Report mouse input that passes through a window

Adds `XDL_SetWindowMousePassthroughEvents`, declared in `XDL/XDL.h`. While it is enabled, mouse input over a window's area that goes to another window is also reported to this window as ordinary motion and button events. The input still reaches the window beneath. The header documents the exact rules.

It works on Windows, macOS, and X11 with XInput 2.1 or later. It does not work on Wayland, and under Xwayland it receives no input outside X11 windows.

The function is part of SDL's dynamic API table, because that table is what exports it. XDL also has its own `SDL_DYNAPI_VERSION`. Tables are copied by position, so without that a newer stock SDL loaded through `SDL3_DYNAMIC_API` would fill this slot with an unrelated function.

## Depends on

`0004-window-shape-passthrough`: the Windows step extends its shape code.

## Testing

`ctest` covers the API with the `dummy` video driver, and `testsymbols` confirms the export.

On Windows, macOS and X11 desktops, run `testmousepassthrough` with a window beneath it. Moving and clicking logs events and draws a dot, and the window beneath still gets the clicks.

To test the dynamic API, set `SDL3_DYNAMIC_API` to a stock `libSDL3` and run a program linked to XDL. It warns and falls back to XDL.
