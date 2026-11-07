#!/usr/bin/env bash
# Fetches a satellite's vendored codecs, then builds it in build/cmake-<satellite> and installs it, against the XDL3 in <install prefix>.
# Run tools/apply.sh <satellite> first. The codecs are the ones XDL publishes.
# Usage: tools/build-project.sh <satellite> <install prefix> [extra CMake flags]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# >= 2 )) || die "usage: build-project.sh <satellite> <install prefix> [extra CMake flags]"
select_project "$1"
install_prefix=$2
shift 2
[[ -e "$worktree/.git" ]] || die "build/$project does not exist. Run tools/apply.sh $project first."

# Each list holds what its flags need, so a change to one is a change to the other.
case "$project" in
  SDL_image)
    vendored=(external/zlib external/libpng external/libtiff external/libwebp)
    flags=(-DSDLIMAGE_VENDORED=ON -DSDLIMAGE_DEPS_SHARED=OFF -DSDLIMAGE_AVIF=OFF -DSDLIMAGE_SAMPLES=OFF -DSDLIMAGE_STRICT=ON)
    ;;
  SDL_ttf)
    vendored=(external/freetype external/harfbuzz external/plutosvg external/plutovg)
    flags=(-DSDLTTF_VENDORED=ON -DSDLTTF_HARFBUZZ=ON -DSDLTTF_PLUTOSVG=ON -DSDLTTF_SAMPLES=OFF -DSDLTTF_STRICT=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5)
    ;;
  SDL_mixer)
    vendored=(external/flac external/ogg external/vorbis external/opus external/opusfile external/libxmp external/wavpack)
    # GME is off because it would link LGPL code statically into a zlib-licensed library.
    flags=(-DSDLMIXER_VENDORED=ON -DSDLMIXER_DEPS_SHARED=OFF -DSDLMIXER_MP3_MPG123=OFF -DSDLMIXER_GME=OFF -DSDLMIXER_TESTS=OFF -DSDLMIXER_EXAMPLES=OFF -DSDLMIXER_STRICT=ON)
    ;;
  *)
    die "$project is not a satellite library."
    ;;
esac

in_worktree submodule --quiet update --init --depth 1 "${vendored[@]}"

mkdir -p "$install_prefix"
install_prefix=$(cd "$install_prefix" && pwd)
build_dir=$repo_root/build/cmake-$project

# A bare --parallel gives make no job limit, and vendored HarfBuzz is a heavy compile.
jobs=$(nproc 2> /dev/null || sysctl -n hw.ncpu)

cmake -S "$worktree" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON "-DCMAKE_PREFIX_PATH=$install_prefix" -DCMAKE_INSTALL_LIBDIR=lib "${flags[@]}" "$@"
cmake --build "$build_dir" --config Release --parallel "$jobs"
cmake --install "$build_dir" --prefix "$install_prefix" --config Release
