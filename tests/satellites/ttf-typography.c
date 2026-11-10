/* Checks XDL's additions to SDL_ttf: XDL_SetFontCharSpacing, XDL_SetFontFeatures and XDL_SetFontVariations.
 * Usage: ttf-typography <Cantarell-VF.otf> */
#include <SDL3/SDL.h>
#include <SDL3_ttf/SDL_ttf.h>
#include <SDL3_ttf/XDL_ttf.h>
#include <stdio.h>

static int failures = 0;

static void check(bool condition, const char *what)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", what);
        ++failures;
    }
}

static int Width(TTF_Font *font, const char *text)
{
    int width = 0;
    int height = 0;
    if (!TTF_GetStringSize(font, text, 0, &width, &height)) {
        fprintf(stderr, "TTF_GetStringSize: %s\n", SDL_GetError());
        ++failures;
    }
    return width;
}

static Uint64 Coverage(TTF_Font *font, const char *text)
{
    SDL_Color white = { 255, 255, 255, 255 };
    SDL_Surface *surface = TTF_RenderText_Blended(font, text, 0, white);
    if (!surface) {
        fprintf(stderr, "TTF_RenderText_Blended: %s\n", SDL_GetError());
        ++failures;
        return 0;
    }

    Uint64 sum = 0;
    for (int y = 0; y < surface->h; ++y) {
        const Uint32 *row = (const Uint32 *)((const Uint8 *)surface->pixels + y * surface->pitch);
        for (int x = 0; x < surface->w; ++x) {
            sum += row[x] >> 24;
        }
    }
    SDL_DestroySurface(surface);
    return sum;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: ttf-typography <Cantarell-VF.otf>\n");
        return 2;
    }
    if (!TTF_Init()) {
        fprintf(stderr, "TTF_Init: %s\n", SDL_GetError());
        return 1;
    }

    TTF_Font *font = TTF_OpenFont(argv[1], 24.0f);
    if (!font) {
        fprintf(stderr, "TTF_OpenFont: %s\n", SDL_GetError());
        return 1;
    }

    // Cantarell's figures are proportional, and its tnum feature makes them tabular
    check(Width(font, "1111.11") < Width(font, "8888.88"), "figures are proportional by default");
    check(XDL_SetFontFeatures(font, "tnum"), "XDL_SetFontFeatures(\"tnum\")");
    check(Width(font, "1111.11") == Width(font, "8888.88"), "tnum makes figures tabular");
    check(!XDL_SetFontFeatures(font, "tnum,"), "an empty feature fails");
    check(Width(font, "1111.11") == Width(font, "8888.88"), "a failed call keeps the features");
    check(XDL_SetFontFeatures(font, NULL), "XDL_SetFontFeatures(NULL)");
    check(Width(font, "1111.11") < Width(font, "8888.88"), "NULL clears the features");

    int normal = Width(font, "Hello");
    // q with a combining tilde is one cluster of two glyphs, and Cantarell has no precomposed glyph for it
    int marked = Width(font, "q\xCC\x83");
    check(XDL_SetFontCharSpacing(font, 2.0f), "XDL_SetFontCharSpacing(2)");
    check(Width(font, "Hello") == normal + 10, "2 px of spacing after each of 5 characters");
    check(Width(font, "q\xCC\x83") == marked + 2, "a letter and its mark get the spacing once");
    check(XDL_SetFontCharSpacing(font, 0.5f), "XDL_SetFontCharSpacing(0.5)");
    check(Width(font, "Hello") > normal, "fractional spacing widens text");
    check(!XDL_SetFontCharSpacing(font, SDL_sqrtf(-1.0f)), "NaN spacing fails");
    check(XDL_SetFontCharSpacing(font, 0.0f), "XDL_SetFontCharSpacing(0)");
    check(Width(font, "q\xCC\x83") == marked, "0 removes the spacing from a cluster");
    check(Width(font, "Hello") == normal, "0 removes the spacing");

    Uint64 regular = Coverage(font, "Hello");
    check(XDL_SetFontVariations(font, "wght=200"), "XDL_SetFontVariations(\"wght=200\")");
    check(TTF_GetFontWeight(font) == 200, "the weight follows the wght axis");
    Uint64 light = Coverage(font, "Hello");
    check(XDL_SetFontVariations(font, "wght=600"), "XDL_SetFontVariations(\"wght=600\")");
    Uint64 semibold = Coverage(font, "Hello");
    check(light < regular && regular < semibold, "a heavier weight covers more pixels");
    check(XDL_SetFontFeatures(font, "tnum") && XDL_SetFontCharSpacing(font, 2.0f), "features and spacing to copy");
    int tracked = Width(font, "Hello");
    TTF_Font *copy = TTF_CopyFont(font);
    check(copy != NULL, "TTF_CopyFont");
    if (copy) {
        check(TTF_GetFontWeight(copy) == 600 && Coverage(copy, "Hello") == semibold, "a copy takes the variations and their weight");
        check(Width(copy, "1111.11") == Width(copy, "8888.88"), "a copy takes the features");
        check(Width(copy, "Hello") == tracked, "a copy takes the spacing");
        TTF_CloseFont(copy);
    }
    check(XDL_SetFontFeatures(font, NULL) && XDL_SetFontCharSpacing(font, 0.0f), "clear the features and spacing");
    check(!XDL_SetFontVariations(font, "wdth=90"), "an axis the font lacks fails");
    check(TTF_GetFontWeight(font) == 600, "a failed call keeps the variations");
    check(XDL_SetFontVariations(font, "wght=5000"), "XDL_SetFontVariations(\"wght=5000\")");
    check(TTF_GetFontWeight(font) == 800, "a value is clamped to the axis");
    check(XDL_SetFontVariations(font, NULL), "XDL_SetFontVariations(NULL)");
    check(TTF_GetFontWeight(font) == 400 && Coverage(font, "Hello") == regular, "NULL restores the default instance");
    copy = TTF_CopyFont(font);
    check(copy != NULL && TTF_GetFontWeight(copy) == 400 && Coverage(copy, "Hello") == regular, "a copy of a restored font is at the default instance");
    TTF_CloseFont(copy);

    // Named instance 2 of Cantarell is Light 300
    SDL_PropertiesID props = SDL_CreateProperties();
    SDL_SetStringProperty(props, TTF_PROP_FONT_CREATE_FILENAME_STRING, argv[1]);
    SDL_SetFloatProperty(props, TTF_PROP_FONT_CREATE_SIZE_FLOAT, 24.0f);
    SDL_SetNumberProperty(props, TTF_PROP_FONT_CREATE_FACE_NUMBER, 2 << 16);
    TTF_Font *instance = TTF_OpenFontWithProperties(props);
    SDL_DestroyProperties(props);
    check(instance != NULL, "open named instance 2");
    if (instance) {
        // Stock SDL_ttf reads the weight of a named instance from the OS/2 table, which holds the default instance's
        int opened_weight = TTF_GetFontWeight(instance);
        check(XDL_SetFontVariations(instance, NULL), "XDL_SetFontVariations(NULL) on a named instance");
        check(TTF_GetFontWeight(instance) == 300, "NULL restores the named instance");
        Uint64 instance_coverage = Coverage(instance, "Hello");
        copy = TTF_CopyFont(instance);
        check(copy != NULL && TTF_GetFontWeight(copy) == 300 && Coverage(copy, "Hello") == instance_coverage, "a copy of a named instance keeps its weight");
        TTF_CloseFont(copy);

        // A copy at another face number is that face, not the original's values
        check(XDL_SetFontVariations(font, "wght=600"), "XDL_SetFontVariations(\"wght=600\") before a copy at another face");
        props = SDL_CreateProperties();
        SDL_SetPointerProperty(props, TTF_PROP_FONT_CREATE_EXISTING_FONT, font);
        SDL_SetNumberProperty(props, TTF_PROP_FONT_CREATE_FACE_NUMBER, 2 << 16);
        copy = TTF_OpenFontWithProperties(props);
        SDL_DestroyProperties(props);
        check(copy != NULL && TTF_GetFontWeight(copy) == opened_weight && Coverage(copy, "Hello") == instance_coverage, "a copy at another named instance is that instance as opened");
        TTF_CloseFont(copy);
        TTF_CloseFont(instance);
    }

    TTF_CloseFont(font);
    TTF_Quit();

    if (failures) {
        fprintf(stderr, "%d checks failed\n", failures);
        return 1;
    }
    printf("ok\n");
    return 0;
}
