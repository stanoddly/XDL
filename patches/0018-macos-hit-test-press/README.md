# Test a left press itself for a window drag on macOS

On macOS, stock SDL lets a hit test drag a window by switching the window's `movableByWindowBackground` on and off. It sets that switch from the hit test only while it handles a mouse event, at that event's place. macOS sends mouse motion only to the key window, so over a window that is not key the switch keeps the answer of the last event SDL saw. A left press on a point where the hit test answers `SDL_HITTEST_NORMAL`, after the pointer left a draggable point unseen, then starts a window drag, and SDL drops the press as the end of a drag. Only the next press reaches the app.

This patch runs the hit test at the place of every left mouse press in the window's content area, in `-[SDL3Window sendEvent:]`, before AppKit handles the press. AppKit then drags the window only from a draggable point. A press on any other point reaches the app as a button down wherever stock SDL delivers it: a press that makes the window key does so only with `SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH`. A pen's press is left alone, as SDL's pen events skip the hit test.

## Testing

On macOS, run `SDL_MOUSE_FOCUS_CLICKTHROUGH=1 ./testhittesting`, so a press that makes the window key reaches it. With the test window key, move the pointer onto a draggable area. Without moving it, switch to another app with Command-Tab. Then move the pointer onto a point of the test window that is not draggable and press. `button down!` is logged and the window does not move. A press on a draggable area still drags the window and logs no `button down!`.
