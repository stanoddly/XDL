#!/usr/bin/env bash
# Writes the licenses and notices for XDL3 and the satellite libraries to <out file>.
# Reads the Linux Ninja builds in build/cmake and build/cmake-<satellite>, and the codec licenses that SDL_image and SDL_mixer install
# into <install prefix>. Needs GNU realpath, so it runs on Linux. Leaves each library's compiled sources in build/notices/<library>.sources.
# Usage: tools/third-party-notices.sh <install prefix> <out file>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 2 )) || die "usage: third-party-notices.sh <install prefix> <out file>"
# The same order on every machine, so two files compare line by line.
export LC_ALL=C
install_prefix=$(cd "$1" && pwd -P)
out_file=$2
repo_real=$(cd "$repo_root" && pwd -P)
lists=$repo_root/build/notices
rm -rf "$lists"
mkdir -p "$lists"

# Prints the objects linked into <target>, following the static libraries and library symlinks built in the same directory.
linked_objects() {
  local build_dir=$1 target=$2 input
  ninja -C "$build_dir" -t query "$target" | awk '/^  input:/ { take = 1; next } /^  outputs:/ { take = 0 } take && $1 != "||" { print $NF }' |
    while read -r input; do
      case "$input" in
        /*) ;;
        *.o) echo "$input" ;;
        *.a|*.so*) linked_objects "$build_dir" "$input" ;;
      esac
    done
}

# Writes every source and header compiled into <target>, from the dependency files of its objects, inside the repo and outside the
# install prefix. Generated files, such as the Wayland protocol code, stay.
compiled_files() {
  local name=$1 build_dir=$repo_root/$2 target=$3
  [[ -f "$build_dir/.ninja_deps" ]] || die "$2 has no .ninja_deps. Build it with -GNinja first."
  linked_objects "$build_dir" "$target" | sort -u > "$lists/$name.objects"
  [[ -s "$lists/$name.objects" ]] || die "$2 links no objects into $target."
  xargs ninja -C "$build_dir" -t deps < "$lists/$name.objects" | awk '/^    / { print $1 }' | (cd "$build_dir" && xargs realpath -m --) |
    grep "^$repo_real/" | grep -v "^$install_prefix/" | sort -u > "$lists/$name.sources"
}

compiled_files XDL3 build/cmake SDL3-shared
compiled_files XDL3_image build/cmake-SDL_image SDL3_image-shared
compiled_files XDL3_ttf build/cmake-SDL_ttf SDL3_ttf-shared
compiled_files XDL3_mixer build/cmake-SDL_mixer SDL3_mixer-shared
# Only the browser build compiles SDL's Emscripten backends, the generic and dummy ones it falls back to, and XDL's WebGPU backend.
# Every checkout has their sources, so they are added here. Each listed directory must have sources, so a move fails. The glob also
# takes in a new Emscripten backend. The satellites compile the same sources in both builds.
browser_sources=()
for directory in gpu/webgpu audio/emscripten camera/emscripten filesystem/emscripten joystick/emscripten locale/emscripten main/emscripten \
  misc/emscripten power/emscripten sensor/emscripten video/emscripten haptic/dummy process/dummy thread/generic tray/dummy; do
  found=""
  for file in "$repo_real/build/SDL/src/$directory"/*; do
    if [[ -f "$file" ]]; then
      browser_sources+=("$file")
      found=1
    fi
  done
  [[ -n "$found" ]] || die "build/SDL/src/$directory has no sources. Update the browser backends in this script."
done
for file in "$repo_real"/build/SDL/src/*/emscripten/*; do
  if [[ -f "$file" ]]; then
    browser_sources+=("$file")
  fi
done
printf '%s\n' "${browser_sources[@]}" | sort -u - "$lists/XDL3.sources" -o "$lists/XDL3.sources"

# Writes one section. An empty text fails like a missing one, so an update cannot drop a notice silently.
section() {
  [[ -n "${3//[[:space:]]/}" ]] || die "the notice of $1 is missing or empty in $2"
  printf '==== %s (%s)\n\n%s\n\n' "$1" "$2" "$3"
}
# Copies a notice verbatim, from the first line matching <start> through the next line matching <end>.
notice() {
  local text=""
  text=$(NOTICE_START=$3 NOTICE_END=$4 awk '!found && $0 ~ ENVIRON["NOTICE_START"] { found = 1 } found { print } found && $0 ~ ENVIRON["NOTICE_END"] { done = 1; exit } END { exit !done }' "$repo_root/$2") || text=""
  section "$1" "$2" "$text"
}
notice_file() {
  local text=""
  text=$(cat "$repo_root/$2") || text=""
  section "$1" "$2" "$text"
}
# The licenses that SDL_image or SDL_mixer installs for the codec libraries it builds, such as optional/LICENSE.libpng.txt. XDL builds
# none today, so this prints nothing until a codec library is turned on in tools/build-project.sh.
codec_licenses() {
  local satellite=$1 library=$2 file
  for file in "$install_prefix/share/licenses/SDL3_${satellite#SDL_}/optional"/LICENSE.*.txt; do
    [[ -f "$file" ]] || continue
    file=${file#"$install_prefix/"}
    section "$satellite: $(basename "$file" .txt | sed 's/^LICENSE\.//') license ($library)" "$file" "$(cat "$install_prefix/$file")"
  done
}

# Prints each given file, or a UTF-8 copy of it if it is not valid UTF-8. Such a file is taken as Latin-1, as libxmp's mkstemp.c was.
utf8_files() {
  local file copy
  while read -r file; do
    if iconv -f UTF-8 -t UTF-8 "$file" > /dev/null 2>&1; then
      echo "$file"
    else
      copy=$(mktemp "$lists/latin1.XXXXXX")
      iconv -f ISO-8859-1 -t UTF-8 "$file" > "$copy"
      echo "$copy"
    fi
  done
}
# The copyright lines of the given files, without comment decoration. A line ending in "by", "and" or a comma, or with years but no
# holder, continues on the next line of the same file. Lines with a double quote are string literals and documentation examples.
copyright_lines() {
  xargs -r awk '
    function clean(s) { sub(/^[[:space:]\/*#|]+/, "", s); sub(/[[:space:]\/*|]+$/, "", s); gsub(/[[:space:]]+/, " ", s); return s }
    function continues(s,    holder) {
      holder = s
      sub(/^[Cc][Oo][Pp][Yy][Rr][Ii][Gg][Hh][Tt][[:space:]]*(\([Cc]\)|©)?/, "", holder)
      return s ~ /(,| and| by)$/ || holder !~ /[A-Za-z]/
    }
    function emit(s) { if (continues(s)) { pending = s } else { print s } }
    FNR == 1 && pending != "" { print pending; pending = "" }
    pending != "" { line = pending " " clean($0); pending = ""; emit(line); next }
    tolower($0) ~ /copyright[[:space:]]*(\(c\)|©|[0-9][0-9][0-9][0-9])/ && $0 !~ /"/ { emit(clean($0)) }
    END { if (pending != "") { print pending } }' | sort -u
}
# The copyright lines of one library's compiled files, split into the project's own code and each vendored library, by the directory
# under build/<project>/external/ or build/cmake-<project>/external/.
library_copyrights() {
  local title=$1 library=$2 project=$3 group
  awk -v own="$project" -v source="$repo_real/build/$project/external/" -v generated="$repo_real/build/cmake-$project/external/" '
    { group = own }
    index($0, source) == 1 { split(substr($0, length(source) + 1), part, "/"); group = part[1] }
    index($0, generated) == 1 { split(substr($0, length(generated) + 1), part, "/"); group = part[1]; sub(/-build$/, "", group) }
    { print group "\t" $0 }' "$lists/$library.sources" > "$lists/$library.groups"
  for group in $(cut -f1 "$lists/$library.groups" | sort -u); do
    [[ "$group" == "$project" ]] && group_title=$title || group_title=$group
    section "Copyright lines of $group_title ($library)" "every distinct copyright line in its sources and headers compiled into this library" \
      "$(awk -F'\t' -v group="$group" '$1 == group { print $2 }' "$lists/$library.groups" | utf8_files | copyright_lines)"
  done
}

freetype_year=$(grep -m1 -oE 'Copyright \(C\) 1996-[0-9]{4}' "$repo_root/build/SDL_ttf/external/freetype/include/freetype/freetype.h" | grep -oE '[0-9]{4}$') \
  || die "no copyright year in FreeType's freetype.h"
freetype_acknowledgment="Portions of this software are copyright © $freetype_year The FreeType Project (www.freetype.org). All rights reserved."

{
  printf 'Licenses and notices for XDL3 and its satellite libraries XDL3_image, XDL3_ttf and XDL3_mixer. XDL3_ttf also contains FreeType\n'
  printf 'and HarfBuzz. Below are the license of each library, the FreeType acknowledgment, the notices of third-party code whose license\n'
  printf 'the library'"'"'s own does not cover, and the copyright lines of every source and header compiled into each library, from the Linux\n'
  printf 'x64 build and the browser build.\n\n'

  notice_file "XDL license" LICENSE
  notice_file "SDL license (XDL3)" build/SDL/LICENSE.txt
  notice_file "SDL_image license (XDL3_image)" build/SDL_image/LICENSE.txt
  codec_licenses SDL_image XDL3_image
  notice_file "SDL_ttf license (XDL3_ttf)" build/SDL_ttf/LICENSE.txt
  notice_file "FreeType license (XDL3_ttf)" build/SDL_ttf/external/freetype/LICENSE.TXT
  notice_file "FreeType License, the FTL, under which XDL3_ttf uses FreeType" build/SDL_ttf/external/freetype/docs/FTL.TXT
  printf '==== FreeType acknowledgment (XDL3_ttf)\n\n%s\n\n' "$freetype_acknowledgment"
  notice_file "HarfBuzz license (XDL3_ttf)" build/SDL_ttf/external/harfbuzz/COPYING
  notice_file "SDL_mixer license (XDL3_mixer)" build/SDL_mixer/LICENSE.txt
  codec_licenses SDL_mixer XDL3_mixer

  # Found with a search of every compiled source and header for copyright lines and license texts. Public-domain code and zlib-licensed
  # code, whose licenses ask for no notice in a binary, are not listed.
  notice "SDL: math functions from Sun's libm (XDL3)" build/SDL/src/libm/e_atan2.c 'Copyright \(C\) 1993 by Sun Microsystems' 'is preserved\.'
  notice_file "SDL: YUV to RGB conversion (XDL3)" build/SDL/src/video/yuv2rgb/LICENSE
  notice "SDL: keysym to UCS conversion (XDL3)" build/SDL/src/events/imKStoUCS.c 'Copyright \(C\) 2003-2006,2008 Jamey Sharp' 'DEALINGS IN THE SOFTWARE\.$'
  # HIDAPI offers GPL-3.0, BSD-3-Clause or its original license. XDL uses it under BSD-3-Clause.
  notice_file "SDL: HIDAPI (XDL3)" build/SDL/src/hidapi/LICENSE-bsd.txt
  notice "SDL: EDID parser (XDL3)" build/SDL/src/video/x11/edid-parse.c 'Copyright 2007 Red Hat, Inc\.' 'USE OR OTHER DEALINGS IN THE SOFTWARE\.$'
  notice "SDL: XSETTINGS client (XDL3)" build/SDL/src/video/x11/xsettings-client.c 'Copyright © 2001, 2007 Red Hat, Inc\.' 'USE OR PERFORMANCE OF THIS SOFTWARE\.$'
  notice "SDL: XDG user directory lookup (XDL3)" build/SDL/src/filesystem/unix/SDL_sysfilesystem.c 'Copyright \(c\) 2007 Red Hat, Inc\.' '^  SOFTWARE\.$'
  notice "SDL: Mesa OpenGL header (XDL3)" build/SDL/include/SDL3/SDL_opengl.h 'Copyright \(C\) 1999-2006  Brian Paul' 'OTHER DEALINGS IN THE SOFTWARE\.$'
  notice "SDL: Khronos platform header (XDL3)" build/SDL/include/SDL3/SDL_egl.h 'Copyright \(c\) 2008-2018 The Khronos Group Inc\.' 'OTHER DEALINGS IN THE MATERIALS\.$'
  # The Vulkan headers in src/video/khronos and the EGL part of SDL_egl.h are Apache-2.0, and no pinned source carries its text.
  notice_file "SDL: Khronos Vulkan and EGL headers, under the Apache License 2.0 (XDL3)" LICENSES/Apache-2.0.txt
  # The Direct3D 12 headers in src/video/directx come from microsoft/DirectX-Headers and name its MIT license without its text.
  # Only Windows builds compile them, so the Linux search does not find them.
  notice_file "SDL: Direct3D 12 headers from DirectX-Headers, in the Windows builds (XDL3)" LICENSES/DirectX-Headers-MIT.txt
  # The WebGPU backend compiles against webgpu.h of Emscripten's emdawnwebgpu port, which carries this license. Only the browser build
  # has the port, so the repo keeps a copy of the text, and that build checks that the header still carries it.
  notice_file "XDL: WebGPU header of Emscripten's emdawnwebgpu port, in the browser build (XDL3)" LICENSES/webgpu-native-BSD-3-Clause.txt
  # The generated Wayland protocol code carries the license of each protocol's XML. pointer-gestures has no notice.
  for protocol in alpha-modifier-v1 color-management-v1 cursor-shape-v1 fractional-scale-v1 frog-color-management-v1 idle-inhibit-unstable-v1 \
    input-timestamps-unstable-v1 keyboard-shortcuts-inhibit-unstable-v1 pointer-constraints-unstable-v1 pointer-warp-v1 primary-selection-unstable-v1 \
    relative-pointer-unstable-v1 tablet-v2 text-input-unstable-v3 viewporter wayland xdg-activation-v1 xdg-decoration-unstable-v1 xdg-dialog-v1 \
    xdg-foreign-unstable-v2 xdg-output-unstable-v1 xdg-shell xdg-toplevel-icon-v1; do
    notice "SDL: Wayland protocol $protocol (XDL3)" "build/cmake/wayland-generated-protocols/$protocol-protocol.c" '^ \* Copyright' ' SOFTWARE\.$'
  done
  notice "SDL_image: GIF decoder adapted from XPaint (XDL3_image)" build/SDL_image/src/IMG_gif.c 'Copyright 1990, 1991, 1993 David Koblas' 'provided "as is"'
  notice "SDL_image: QOI codec (XDL3_image)" build/SDL_image/src/qoi.h 'Copyright\(c\) 2021 Dominic Szablewski' '^SOFTWARE\.$'
  notice "FreeType: BDF driver (XDL3_ttf)" build/SDL_ttf/external/freetype/src/bdf/README '^License$' '^THE USE OR OTHER DEALINGS IN THE SOFTWARE\.$'
  notice "FreeType: PCF driver (XDL3_ttf)" build/SDL_ttf/external/freetype/src/pcf/README '^License$' '^SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE\.$'
  notice "FreeType: PCF bitmap utilities (XDL3_ttf)" build/SDL_ttf/external/freetype/src/pcf/pcfutil.c 'Copyright 1990, 1994, 1998  The Open Group' 'written authorization from The Open Group\.'
  notice "FreeType: HarfBuzz glue of the auto-hinter (XDL3_ttf)" build/SDL_ttf/external/freetype/src/autofit/ft-hb.c 'Copyright © 2009, 2023  Red Hat' 'OR MODIFICATIONS\.$'
  notice_file "HarfBuzz: Universal Shaping Engine data (XDL3_ttf)" build/SDL_ttf/external/harfbuzz/src/ms-use/COPYING
  notice "HarfBuzz: Unicode character database functions (XDL3_ttf)" build/SDL_ttf/external/harfbuzz/src/hb-ucd.cc 'Copyright \(C\) 2012 Grigori Goronzy' 'USE OR PERFORMANCE OF THIS SOFTWARE\.'
  notice "HarfBuzz: fasthash (XDL3_ttf)" build/SDL_ttf/external/harfbuzz/src/hb-algs.hh 'Copyright \(C\) 2012 Zilong Tan' '^   SOFTWARE\.$'
  # No pinned source carries the license of the Unicode data HarfBuzz generates its tables from, so the repo keeps a copy of
  # https://www.unicode.org/license.txt.
  notice_file "HarfBuzz: tables generated from Unicode data (XDL3_ttf)" LICENSES/Unicode-3.0.txt
  notice_file "SDL_mixer: dr_libs license (XDL3_mixer)" build/SDL_mixer/src/dr_libs/LICENSE

  library_copyrights "XDL, including SDL" XDL3 SDL
  library_copyrights "SDL_image" XDL3_image SDL_image
  library_copyrights "SDL_ttf" XDL3_ttf SDL_ttf
  library_copyrights "SDL_mixer" XDL3_mixer SDL_mixer
} > "$out_file"
