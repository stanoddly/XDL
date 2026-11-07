# Turn off JBIG in the vendored libtiff

SDL_image turns off most optional codecs of its vendored libtiff, but not JBIG. libtiff enables JBIG whenever the build machine has the library, so the built library can need a `libjbig` that nobody ships, and it then fails to load. For example, `libjbig.so.0` from an Ubuntu build machine doesn't exist on Fedora.

The only loss is JBIG-compressed TIFF support.

## Testing

Build with the JBIG development files installed. `tools/check-dependencies.sh <prefix>/lib/libXDL3_image.so.0` passes. Without this patch it fails and names `libjbig`.
