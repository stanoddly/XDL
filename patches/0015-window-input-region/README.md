# Let mouse input through a transparent window outside given rectangles

Adds `XDL_SetWindowInputRegion`, declared in `XDL/XDL.h`. A transparent window passes the rectangles that take mouse input, in window coordinates. A click inside one reaches the window as its own mouse events and not the window beneath. A click anywhere else reaches the window beneath. A count of 0 lets all input through. Each call replaces the previous region and any shape set by `SDL_SetWindowShape`. The region does not change what the window shows, so an app can update it every frame.

For example, a transparent window over the whole display passes the rectangles of the few things it draws, and the rest of the desktop stays usable.

- **Wayland:** the rectangles become the surface's input region, scaled to surface coordinates as in `0004-window-shape-passthrough`. The region takes effect with the next present.
- **X11:** `XShapeCombineRectangles` with `ShapeInput`. It fails without the SHAPE extension.
- **Windows:** Windows has no input region that leaves drawing alone. So the window becomes input-transparent, and a low-level mouse hook blocks a left press inside the region and its release, and reports both to the window. A press goes through when a window above covers that point.
- **macOS:** Cocoa has no input region either. `ignoresMouseEvents` follows whether the cursor is inside a rectangle, on each call and on the window's own mouse motion.

Mouse passthrough events report input that goes to other windows. That is a different use case, so a window can't have both. `XDL_SetWindowInputRegion` fails while the window has them enabled, and enabling them fails once the window has a region.

The code comes from botoddly/SDL#4, which replaced mouse passthrough events with the input region. This patch keeps them and adds the region beside them. On Wayland it scales the rectangles to surface coordinates, which botoddly/SDL#4 does not.

## Depends on

- `0004-window-shape-passthrough`: the Windows step makes the window input-transparent with its shape code.
- `0006-mouse-passthrough-events`: the region shares its tracking of forwarded buttons and its dynamic API slot order.

## Known gaps

- Windows and macOS are only compiled, by CI. Only Wayland and X11 were run.
- On Windows, the region has its own mouse hook thread. When another window in the process has mouse passthrough events, there are two hooks.
- Windows silently removes a low-level mouse hook that keeps missing its timeout. The region then stops taking input, and the app is not told.

## Testing

`testautomation --filter video_setWindowInputRegion` covers the API on every driver. It expects success on Wayland, X11, Windows and macOS, and failure elsewhere.

On a desktop, run `testinputregion` over another window. It draws two squares that take mouse input and logs the events. Clicks elsewhere reach the window beneath. With `--move`, the squares slide and the region is set every frame.
