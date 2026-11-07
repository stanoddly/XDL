/*
 * Loads XDL3 and then each satellite from one directory, by the file names XDL publishes, and decodes a PNG through XDL3_image.
 * A satellite needs XDL3 by its soname or install name, which differs from the published file name, so this proves that the loader
 * reuses the XDL3 already loaded.
 * Usage: runtime-layout <directory> <expected start of SDL_GetRevision()>
 */
#include <SDL3/SDL.h>
#include <stdio.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#define LIBRARY_PREFIX ""
#define LIBRARY_SUFFIX ".dll"
typedef HMODULE library;
static library load_library(const char *path) { return LoadLibraryA(path); }
static void *find_symbol(library handle, const char *name) { return (void *)GetProcAddress(handle, name); }
static void print_load_error(const char *path) { fprintf(stderr, "cannot load %s: error %lu\n", path, GetLastError()); }
#else
#include <dlfcn.h>
#define LIBRARY_PREFIX "lib"
#ifdef __APPLE__
#define LIBRARY_SUFFIX ".dylib"
#else
#define LIBRARY_SUFFIX ".so"
#endif
typedef void *library;
static library load_library(const char *path) { return dlopen(path, RTLD_NOW | RTLD_LOCAL); }
static void *find_symbol(library handle, const char *name) { return dlsym(handle, name); }
static void print_load_error(const char *path) { fprintf(stderr, "cannot load %s: %s\n", path, dlerror()); }
#endif

/* A 2x1 RGBA PNG: one red pixel, then one blue pixel. */
static const unsigned char png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02,
    0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0xf4, 0x22, 0x7f, 0x8a, 0x00, 0x00, 0x00, 0x0e, 0x49, 0x44, 0x41,
    0x54, 0x78, 0xda, 0x63, 0xf8, 0xcf, 0xc0, 0x00, 0x42, 0xff, 0x01, 0x0f, 0xf9, 0x03, 0xfd, 0x98, 0x79, 0xd7, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
};

static const char *directory;

static library load(const char *name)
{
    char path[4096];
    library handle;

    snprintf(path, sizeof(path), "%s/%s%s%s", directory, LIBRARY_PREFIX, name, LIBRARY_SUFFIX);
    handle = load_library(path);
    if (!handle) {
        print_load_error(path);
    }
    return handle;
}

static void *find(library handle, const char *name)
{
    void *function = find_symbol(handle, name);
    if (!function) {
        fprintf(stderr, "missing symbol %s\n", name);
    }
    return function;
}

int main(int argc, char **argv)
{
    library xdl, image, ttf, mixer;
    const char *(SDLCALL *get_revision)(void);
    SDL_IOStream *(SDLCALL *io_from_const_mem)(const void *, size_t);
    bool (SDLCALL *read_surface_pixel)(SDL_Surface *, int, int, Uint8 *, Uint8 *, Uint8 *, Uint8 *);
    void (SDLCALL *destroy_surface)(SDL_Surface *);
    SDL_Surface *(SDLCALL *load_png)(SDL_IOStream *, bool);
    int (SDLCALL *ttf_version)(void);
    int (SDLCALL *mix_version)(void);
    SDL_Surface *surface;
    Uint8 left[4], right[4];
    bool pixels_read;

    if (argc != 3) {
        fprintf(stderr, "usage: runtime-layout <directory> <expected start of SDL_GetRevision()>\n");
        return 2;
    }
    directory = argv[1];

    if (!(xdl = load("XDL3")) || !(image = load("XDL3_image")) || !(ttf = load("XDL3_ttf")) || !(mixer = load("XDL3_mixer"))) {
        return 1;
    }

    get_revision = (const char *(SDLCALL *)(void))find(xdl, "SDL_GetRevision");
    io_from_const_mem = (SDL_IOStream *(SDLCALL *)(const void *, size_t))find(xdl, "SDL_IOFromConstMem");
    read_surface_pixel = (bool (SDLCALL *)(SDL_Surface *, int, int, Uint8 *, Uint8 *, Uint8 *, Uint8 *))find(xdl, "SDL_ReadSurfacePixel");
    destroy_surface = (void (SDLCALL *)(SDL_Surface *))find(xdl, "SDL_DestroySurface");
    load_png = (SDL_Surface *(SDLCALL *)(SDL_IOStream *, bool))find(image, "IMG_Load_IO");
    ttf_version = (int (SDLCALL *)(void))find(ttf, "TTF_Version");
    mix_version = (int (SDLCALL *)(void))find(mixer, "MIX_Version");
    if (!get_revision || !io_from_const_mem || !read_surface_pixel || !destroy_surface || !load_png || !ttf_version || !mix_version) {
        return 1;
    }

#ifndef _WIN32
    /* dlsym on a satellite's handle also searches the libraries it loaded, so a second copy of XDL3 shows up as another address. */
    if (find_symbol(image, "SDL_GetRevision") != (void *)get_revision || find_symbol(ttf, "SDL_GetRevision") != (void *)get_revision ||
        find_symbol(mixer, "SDL_GetRevision") != (void *)get_revision) {
        fprintf(stderr, "a satellite loaded another copy of XDL3\n");
        return 1;
    }
#endif

    /* SDL appends the vendor text, such as " (XDL-3.4.20-1)". */
    if (strncmp(get_revision(), argv[2], strlen(argv[2])) != 0) {
        fprintf(stderr, "SDL_GetRevision() is \"%s\", expected it to start with \"%s\"\n", get_revision(), argv[2]);
        return 1;
    }

    surface = load_png(io_from_const_mem(png, sizeof(png)), true);
    if (!surface) {
        fprintf(stderr, "IMG_Load_IO failed\n");
        return 1;
    }
    pixels_read = read_surface_pixel(surface, 0, 0, &left[0], &left[1], &left[2], &left[3]) &&
                  read_surface_pixel(surface, 1, 0, &right[0], &right[1], &right[2], &right[3]);
    if (surface->w != 2 || surface->h != 1 || !pixels_read || left[0] != 255 || left[2] != 0 || right[0] != 0 || right[2] != 255) {
        fprintf(stderr, "the PNG decoded wrongly\n");
        return 1;
    }
    destroy_surface(surface);

    printf("%s, SDL_ttf %d, SDL_mixer %d: loaded from %s\n", get_revision(), ttf_version(), mix_version(), directory);
    return 0;
}
