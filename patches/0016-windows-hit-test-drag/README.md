# Move a window dragged by its hit test without the Windows modal loop

On Windows, a hit test that answers `SDL_HITTEST_DRAGGABLE` makes stock SDL return `HTCAPTION`. A left press there then makes `DefWindowProc` run the system's modal move loop inside `SDL_PumpEvents` until the button is released. An app with its own loop gets no frames meanwhile, so every window it draws freezes. Wayland, X11 and macOS ask the compositor, the window manager or the window server to move the window, and the app's loop keeps running.

This patch moves the window itself instead. On `WM_NCLBUTTONDOWN` at a point where the hit test answers `SDL_HITTEST_DRAGGABLE`, it captures the mouse and skips `DefWindowProc`. Each `WM_MOUSEMOVE` moves the window with `SetWindowPos`, keeping the cursor where it pressed the window. The release, any loss of the capture, or the window being maximized or minimized ends the drag. `SDL_EVENT_WINDOW_MOVED` arrives during the drag. As before, the left press reaches the app as no mouse event. Until the left release, the drag owns the mouse, so no press, release or motion of any button reaches the app either. A cursor clip from a mouse grab or a mouse rectangle is lifted when the drag starts, so a grabbed cursor can follow the window.

A maximized window, a window without a hit test and the resize hit test results still go to `DefWindowProc`, as in stock SDL.

## Known gaps

- Only compiled, with mingw-w64. It has not been run on Windows.
- The drag has no Aero Snap and no shake to minimise, and Escape does not cancel it.
- A resizable window dragged onto a display of another DPI takes the size Windows suggests, but the cursor keeps its offset in the old pixels, so it can end up outside the window. A window that is not resizable keeps its size.
- Pen and touch drags have not been tried.

## Testing

On Windows, run `testhittesting` and drag the window by its draggable area. `Window event moved to` lines are logged while the window moves, not only after the release, and no `button down!` or `button up!` is logged for the drag. A right click during the drag logs nothing and does not end it. Try it with a pen and with touch too.
