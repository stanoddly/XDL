#!/usr/bin/env bash
# Copies XDL3 and the satellite libraries from <install prefix> into <out dir> under the file names XDL publishes, and prints each copy.
# The names drop the version, so .NET finds them for DllImport("XDL3") and the others.
# The installed libraries name XDL3 by its versioned soname or install name, and only the system's paths find it, so a satellite loaded
# before XDL3 failed. On Linux and macOS each copy gets its published name as soname or install name, and a satellite needs XDL3 from
# its own directory. On Windows the names already match, and .NET loads a DLL by path with LOAD_WITH_ALTERED_SEARCH_PATH, which searches
# that DLL's directory first.
# The browser archives drop the lib prefix, because the .NET browser build takes each archive's file name as its DllImport module.
# Usage: tools/collect-runtime.sh <rid> <install prefix> <out dir>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 3 )) || die "usage: collect-runtime.sh <rid> <install prefix> <out dir>"
rid=$1
install_prefix=$2
out_dir=$3
satellites=(XDL3_image XDL3_ttf XDL3_mixer)

case "$rid" in
  linux-*)
    # patchelf 0.14.3, Ubuntu 22.04's, mixes up the names and writes libraries that crash on load. XDL tests 0.19.3.
    command -v patchelf > /dev/null || die "No patchelf on PATH. Run: pipx install patchelf==0.19.3.0"
    patchelf_version=$(patchelf --version | awk '{ print $2 }')
    IFS=. read -r major minor _ <<< "$patchelf_version"
    (( major > 0 || minor >= 19 )) || die "patchelf $patchelf_version is older than 0.19. Run: pipx install patchelf==0.19.3.0"
    ;;
  osx-*) command -v install_name_tool > /dev/null && command -v codesign > /dev/null || die "No install_name_tool or codesign on PATH." ;;
  win-*|browser-*) ;;
  *) die "Unknown RID: $rid" ;;
esac

mkdir -p "$out_dir"
copies=()
for library in XDL3 "${satellites[@]}"; do
  case "$rid" in
    linux-*) installed=lib/lib$library.so.0 published=lib$library.so ;;
    osx-*) installed=lib/lib$library.0.dylib published=lib$library.dylib ;;
    win-*) installed=bin/$library.dll published=$library.dll ;;
    browser-*) installed=lib/lib$library.a published=$library.a ;;
  esac
  [[ -f "$install_prefix/$installed" ]] || die "$install_prefix/$installed does not exist."
  cp -L "$install_prefix/$installed" "$out_dir/$published"
  copies+=("$out_dir/$published")
done

# check-dependencies.sh fails a satellite that still needs the versioned name, because these tools skip a name they do not find.
case "$rid" in
  linux-*)
    patchelf --set-soname libXDL3.so "$out_dir/libXDL3.so"
    for library in "${satellites[@]}"; do
      patchelf --set-soname "lib$library.so" --replace-needed libXDL3.so.0 libXDL3.so --set-rpath '$ORIGIN' "$out_dir/lib$library.so"
    done
    ;;
  osx-*)
    # The edit breaks the linker's ad-hoc signature, which arm64 needs to load the library.
    install_name_tool -id @rpath/libXDL3.dylib "$out_dir/libXDL3.dylib"
    for library in "${satellites[@]}"; do
      install_name_tool -id "@rpath/lib$library.dylib" -change @rpath/libXDL3.0.dylib @loader_path/libXDL3.dylib "$out_dir/lib$library.dylib"
    done
    for library in XDL3 "${satellites[@]}"; do
      codesign --force --sign - "$out_dir/lib$library.dylib"
    done
    ;;
esac

printf '%s\n' "${copies[@]}"
