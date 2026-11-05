# Let input pass through a fully transparent window shape

Makes `SDL_SetWindowShape` usable for a transparent window that takes no input:

- **Wayland:** adds shape support, which stock SDL lacks. The shape becomes the surface's input region, so transparent pixels pass input through. A new shape takes effect at the surface's next commit, normally the window's next present, so the click area matches what is on screen. An app that changes only the shape must present once.
- **Windows:** a window region clips drawing as well as input, so an empty region would hide the window. A transparent window whose shape has no opaque pixel now stays visible and uses `WS_EX_TRANSPARENT` instead.

## Testing

On Wayland and Windows desktops, run `testmousepassthrough` from `0006-mouse-passthrough-events`, with a window beneath it. Clicks reach the window beneath. With `--opaque`, the square in the middle receives them instead. On Wayland, it logs that passthrough events are unsupported and tests only the shape.
