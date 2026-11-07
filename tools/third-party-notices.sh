#!/usr/bin/env bash
# Writes the licenses and notices for XDL3 and the satellite libraries to <out file>.
# Reads the Linux Ninja builds in build/cmake and build/cmake-<satellite>, and the codec licenses that SDL_image and SDL_mixer install
# into <install prefix>. Needs GNU realpath, so it runs on Linux. Leaves each library's compiled sources in build/notices/<library>.sources.
# Usage: tools/third-party-notices.sh <install prefix> <out file>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 2 )) || die "usage: third-party-notices.sh <install prefix> <out file>"
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
# The licenses that SDL_image or SDL_mixer installs for the codecs it builds, such as optional/LICENSE.libpng.txt.
codec_licenses() {
  local satellite=$1 library=$2 file found=""
  for file in "$install_prefix/share/licenses/SDL3_${satellite#SDL_}/optional"/LICENSE.*.txt; do
    [[ -f "$file" ]] || continue
    found=1
    file=${file#"$install_prefix/"}
    section "$satellite: $(basename "$file" .txt | sed 's/^LICENSE\.//') license ($library)" "$file" "$(cat "$install_prefix/$file")"
  done
  [[ -n "$found" ]] || die "$install_prefix/share/licenses/SDL3_${satellite#SDL_}/optional has no codec licenses."
}

# Prints each given file, or a UTF-8 copy of it if it is not valid UTF-8. Such a file is taken as Latin-1, as libxmp's mkstemp.c is.
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
  printf 'Licenses and notices for XDL3 and its satellite libraries XDL3_image, XDL3_ttf and XDL3_mixer. Each satellite also contains the\n'
  printf 'libraries it vendors: XDL3_image zlib, libpng, libtiff and libwebp; XDL3_ttf FreeType, HarfBuzz, plutosvg and plutovg; XDL3_mixer\n'
  printf 'FLAC, Ogg, Vorbis, Opus, opusfile, libxmp and WavPack. Below are the license of each library, the FreeType acknowledgment, the\n'
  printf 'notices of third-party code whose license the library'"'"'s own does not cover, and the copyright lines of every source and header\n'
  printf 'compiled into each library, from the Linux x64 build.\n\n'

  notice_file "XDL license" LICENSE
  notice_file "SDL license (XDL3)" build/SDL/LICENSE.txt
  notice_file "SDL_image license (XDL3_image)" build/SDL_image/LICENSE.txt
  codec_licenses SDL_image XDL3_image
  notice_file "SDL_ttf license (XDL3_ttf)" build/SDL_ttf/LICENSE.txt
  notice_file "FreeType license (XDL3_ttf)" build/SDL_ttf/external/freetype/LICENSE.TXT
  notice_file "FreeType License, the FTL, under which XDL3_ttf uses FreeType" build/SDL_ttf/external/freetype/docs/FTL.TXT
  printf '==== FreeType acknowledgment (XDL3_ttf)\n\n%s\n\n' "$freetype_acknowledgment"
  notice_file "HarfBuzz license (XDL3_ttf)" build/SDL_ttf/external/harfbuzz/COPYING
  notice_file "plutosvg license (XDL3_ttf)" build/SDL_ttf/external/plutosvg/LICENSE
  notice_file "plutovg license (XDL3_ttf)" build/SDL_ttf/external/plutovg/LICENSE
  notice_file "SDL_mixer license (XDL3_mixer)" build/SDL_mixer/LICENSE.txt
  codec_licenses SDL_mixer XDL3_mixer

  # Found with a search of every compiled source and header for copyright lines and license texts. Public-domain code and zlib-licensed
  # code, whose licenses ask for no notice in a binary, are not listed.
  # NOTICES

  library_copyrights "XDL, including SDL" XDL3 SDL
  library_copyrights "SDL_image" XDL3_image SDL_image
  library_copyrights "SDL_ttf" XDL3_ttf SDL_ttf
  library_copyrights "SDL_mixer" XDL3_mixer SDL_mixer
} > "$out_file"
