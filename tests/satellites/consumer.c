#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <SDL3_mixer/SDL_mixer.h>
#include <SDL3_ttf/SDL_ttf.h>
#include <stdio.h>

int main(void)
{
    printf("%d %d %d\n", IMG_Version(), TTF_Version(), MIX_Version());
    return 0;
}
