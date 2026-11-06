#include <SDL3/SDL.h>
#include <XDL/XDL.h>
#include <stdio.h>

int main(void)
{
    puts(SDL_GetRevision());
    return XDL_SetWindowMousePassthroughEvents(NULL, true) ? 1 : 0;
}
