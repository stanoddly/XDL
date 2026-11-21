# Report a press on the key window at its own place on macOS

On macOS, stock SDL reports a mouse button on the key window at SDL's stored cursor position, not at the event's own. That position is the last motion SDL saw, and it can belong to another window. For example, an app has a transparent window over the whole display and a smaller window under it, which is key. The pointer moves over the smaller window, but SDL's mouse focus and position stay on the window above. A press on the smaller window then calls `SDL_UpdateMouseFocus` with the other window's position, which lies outside the smaller window. The focus stays where it was, and the press is reported with the other window's ID, at the other window's position.

This patch moves SDL to the button's own place first, as SDL's X11 backend does. Before a button of the key window at a point inside it, when SDL's mouse focus is another window or the stored position differs from the event's, it sends a motion to the window at the event's position. The focus moves to the window, and the button reports that window and its place. A button outside the window, such as a release after a drag, is reported as in stock SDL. Relative mode is left alone. A window that is not key already reports a button at the event's position, as in stock SDL.

`testinputregion` gets a `--below` option for testing it: a plain window of the same app beneath the transparent one, which takes keyboard focus.

## Testing

On macOS, run `testinputregion --fullscreen --below`. Move the pointer from outside the plain window onto it, away from the squares, and click it. The `button 1 down` and `button 1 up` lines name the plain window, logged as `Window N is beneath it`, at the pointer's place in it. In an app with such windows, stock SDL named the transparent window, at its stored position. Whether this test reproduces that has not been tried.
