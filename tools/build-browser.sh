#!/usr/bin/env bash
# Builds XDL3 and the satellites as static Emscripten libraries for the .NET browser runtime, and installs them into <install prefix> with
# emdawnwebgpu, the WebGPU binding that XDL3 calls (tools/build-emdawnwebgpu.sh).
# They link only into a .NET runtime built with the same Emscripten, so put that one on PATH first: source tools/emsdk-env.sh.
# Run tools/apply.sh for SDL and each satellite first. Builds in build/cmake-browser and build/cmake-browser-<satellite>.
# Usage: tools/build-browser.sh <install prefix> [extra CMake flags for XDL3]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# >= 1 )) || die "usage: build-browser.sh <install prefix> [extra CMake flags for XDL3]"
install_prefix=$1
shift
emcc=$(command -v emcc) || die "No emcc on PATH. Run: source tools/emsdk-env.sh"
[[ -e "$repo_root/build/SDL/.git" ]] || die "build/SDL does not exist. Run tools/apply.sh first."

toolchain=$(dirname "$emcc")/cmake/Modules/Platform/Emscripten.cmake
# The exception handling of the .NET browser runtime. Code built without these flags does not link into it.
exception_flags="-fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0"
jobs=$(nproc 2> /dev/null || sysctl -n hw.ncpu)
mkdir -p "$install_prefix"
install_prefix=$(cd "$install_prefix" && pwd)

# Fresh configures, so the libraries come from the emcc on PATH and not from a compiler that an older configure cached.
build_dir=$repo_root/build/cmake-browser
rm -rf "$build_dir"
cmake -S "$repo_root/build/SDL" -B "$build_dir" "-DCMAKE_TOOLCHAIN_FILE=$toolchain" -DCMAKE_BUILD_TYPE=Release -DSDL_SHARED=OFF -DSDL_STATIC=ON \
  -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_DISABLE_INSTALL_DOCS=ON "-DCMAKE_C_FLAGS=$exception_flags" "-DCMAKE_CXX_FLAGS=$exception_flags" \
  -DCMAKE_INSTALL_LIBDIR=lib "$@"
cmake --build "$build_dir" --parallel "$jobs"
cmake --install "$build_dir" --prefix "$install_prefix"

# The Emscripten toolchain finds packages only inside its sysroot, so SDL3_DIR names the XDL3 just installed. HarfBuzz, the only C++ code,
# raises -Wunused to an error by pragma, and Emscripten's clang counts -Wunused-template, which HarfBuzz's own headers trigger, in it.
for project in SDL_image SDL_ttf SDL_mixer; do
  rm -rf "$repo_root/build/cmake-browser-$project"
  "$repo_root/tools/build-project.sh" --build-dir "$repo_root/build/cmake-browser-$project" "$project" "$install_prefix" "-DCMAKE_TOOLCHAIN_FILE=$toolchain" \
    "-DSDL3_DIR=$install_prefix/lib/cmake/SDL3" -DBUILD_SHARED_LIBS=OFF "-DCMAKE_C_FLAGS=$exception_flags" \
    "-DCMAKE_CXX_FLAGS=$exception_flags -DHB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR"
done

# THIRD-PARTY-NOTICES.txt carries LICENSES/webgpu-native-BSD-3-Clause.txt for the webgpu.h that XDL3 compiles against. The header comes
# with the Emscripten, so this fails when a new one carries another license text.
header=$("$(dirname "$emcc")/em-config" CACHE)/ports/emdawnwebgpu/emdawnwebgpu_pkg/webgpu/include/webgpu/webgpu.h
sed -n '/^\/\/ BSD 3-Clause License$/,/SUCH DAMAGE\.$/p' "$header" | sed -E 's#^// ?##' | diff - "$repo_root/LICENSES/webgpu-native-BSD-3-Clause.txt" \
  || die "The license text in $header differs from LICENSES/webgpu-native-BSD-3-Clause.txt."

"$repo_root/tools/build-emdawnwebgpu.sh" "$install_prefix"
