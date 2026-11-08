#!/usr/bin/env bash
# Fetches a satellite's vendored libraries, then builds it in <build dir>, by default build/cmake-<satellite>, and installs it, against
# the XDL3 in <install prefix>. Run tools/apply.sh <satellite> first. The codecs are the ones XDL publishes.
# Usage: tools/build-project.sh [--build-dir <build dir>] <satellite> <install prefix> [extra CMake flags]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage="usage: build-project.sh [--build-dir <build dir>] <satellite> <install prefix> [extra CMake flags]"
build_dir=""
if [[ "${1:-}" == --build-dir ]]; then
  (( $# >= 2 )) || die "$usage"
  build_dir=$2
  shift 2
fi
(( $# >= 2 )) || die "$usage"
select_project "$1"
install_prefix=$2
shift 2
[[ -e "$worktree/.git" ]] || die "build/$project does not exist. Run tools/apply.sh $project first."

# Each list holds what its flags need, so a change to one is a change to the other.
case "$project" in
  SDL_image)
    # PNG goes through SDL's own code. The formats that need a library are off: animated PNG, TIFF, WebP and AVIF. ImageIO is off, because
    # on macOS it would load those formats and more, so a game tested there would fail elsewhere.
    vendored=()
    flags=(-DSDLIMAGE_VENDORED=ON -DSDLIMAGE_DEPS_SHARED=OFF -DSDLIMAGE_BACKEND_IMAGEIO=OFF -DSDLIMAGE_PNG_LIBPNG=OFF -DSDLIMAGE_TIF=OFF
      -DSDLIMAGE_WEBP=OFF -DSDLIMAGE_AVIF=OFF -DSDLIMAGE_SAMPLES=OFF -DSDLIMAGE_STRICT=ON)
    ;;
  SDL_ttf)
    # Without plutosvg, fonts with SVG color glyphs, such as some emoji fonts, draw no such glyphs.
    vendored=(external/freetype external/harfbuzz)
    flags=(-DSDLTTF_VENDORED=ON -DSDLTTF_HARFBUZZ=ON -DSDLTTF_PLUTOSVG=OFF -DSDLTTF_SAMPLES=OFF -DSDLTTF_STRICT=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5)
    ;;
  SDL_mixer)
    # FLAC, Ogg Vorbis and MP3 go through the decoders in SDL_mixer's own source: dr_flac, stb_vorbis and dr_mp3. The formats that need a
    # library are off: Opus, WavPack and tracker music. MIDI is off, because Timidity needs instrument files that XDL does not ship. GME
    # is off because it would link LGPL code statically into a zlib-licensed library.
    vendored=()
    flags=(-DSDLMIXER_VENDORED=ON -DSDLMIXER_DEPS_SHARED=OFF -DSDLMIXER_FLAC_LIBFLAC=OFF -DSDLMIXER_VORBIS_VORBISFILE=OFF -DSDLMIXER_MP3_MPG123=OFF
      -DSDLMIXER_OPUS=OFF -DSDLMIXER_WAVPACK=OFF -DSDLMIXER_MOD=OFF -DSDLMIXER_MIDI=OFF -DSDLMIXER_GME=OFF -DSDLMIXER_TESTS=OFF -DSDLMIXER_EXAMPLES=OFF
      -DSDLMIXER_STRICT=ON)
    ;;
  *)
    die "$project is not a satellite library."
    ;;
esac

# Bash 3.2 rejects an empty array under set -u, and git would fetch every submodule without paths.
if (( ${#vendored[@]} > 0 )); then
  in_worktree submodule --quiet update --init --depth 1 "${vendored[@]}"
fi

mkdir -p "$install_prefix"
install_prefix=$(cd "$install_prefix" && pwd)
build_dir=${build_dir:-$repo_root/build/cmake-$project}

# A bare --parallel gives make no job limit, and vendored HarfBuzz is a heavy compile.
jobs=$(nproc 2> /dev/null || sysctl -n hw.ncpu)

cmake -S "$worktree" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON "-DCMAKE_PREFIX_PATH=$install_prefix" -DCMAKE_INSTALL_LIBDIR=lib "${flags[@]}" "$@"
cmake --build "$build_dir" --config Release --parallel "$jobs"
cmake --install "$build_dir" --prefix "$install_prefix" --config Release
