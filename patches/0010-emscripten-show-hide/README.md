# Show and hide the canvas of an Emscripten window

Stock SDL's Emscripten driver has no `ShowWindow` or `HideWindow`, so `SDL_HideWindow` leaves the canvas on the page, and a window created with `SDL_WINDOW_HIDDEN` is visible. A GPU frame acquired for a hidden window then presents an undrawn texture and blanks the canvas.

This patch hides the canvas by setting its inline `display` to `none`, and restores the previous inline value when it is shown. For example, on a page whose stylesheet sets `canvas { display: block; }`, `SDL_HideWindow` sets `style.display = "none"`, and `SDL_ShowWindow` sets it back to `""`, so the stylesheet applies again.

- A window created with `SDL_WINDOW_HIDDEN` now hides its canvas until `SDL_ShowWindow`. In stock SDL its canvas is visible.
- SDL sends `SDL_EVENT_WINDOW_SHOWN` and `SDL_EVENT_WINDOW_HIDDEN` as on other platforms. Showing gives the window mouse and keyboard focus, and hiding takes it away.
- When the page becomes visible again, a window that the app hid stays hidden and gets no `SDL_EVENT_WINDOW_SHOWN`.
- A hidden canvas has no CSS size, so a browser resize while it is hidden keeps the window's size. On show, a resizable window sized by CSS takes its CSS size again.
- Destroying a window shows its canvas again, as stock SDL leaves it.
- A `SDL_WINDOW_FILL_DOCUMENT` window hides the rest of the page on a separate element, so hiding its canvas leaves the page blank until it is shown.

`SDL_HideWindow` does nothing while the page is hidden, because SDL already marks the window hidden then. This is stock SDL behavior.

## Testing

`tests/webgpu` creates a window with `SDL_WINDOW_HIDDEN`, then shows, hides and destroys it, and checks the canvas's computed `display` after each step. It then checks that a window created shown has a displayed canvas. See `patches/0007-webgpu-backend/README.md` for how to run it.
