#!/usr/bin/env bash
# Copies XDL3 and the satellite libraries from <install prefix> into <out dir> under the file names XDL publishes, and prints each copy.
# The names drop the version, so .NET finds them for DllImport("XDL3") and the others. The soname or install name inside stays versioned.
# The browser archives drop the lib prefix, because the .NET browser build takes each archive's file name as its DllImport module.
# Usage: tools/collect-runtime.sh <rid> <install prefix> <out dir>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 3 )) || die "usage: collect-runtime.sh <rid> <install prefix> <out dir>"
rid=$1
install_prefix=$2
out_dir=$3

case "$rid" in
  linux-*|osx-*|win-*|browser-*) ;;
  *) die "Unknown RID: $rid" ;;
esac

mkdir -p "$out_dir"
for library in XDL3 XDL3_image XDL3_ttf XDL3_mixer; do
  case "$rid" in
    linux-*) installed=lib/lib$library.so.0 published=lib$library.so ;;
    osx-*) installed=lib/lib$library.0.dylib published=lib$library.dylib ;;
    win-*) installed=bin/$library.dll published=$library.dll ;;
    browser-*) installed=lib/lib$library.a published=$library.a ;;
  esac
  [[ -f "$install_prefix/$installed" ]] || die "$install_prefix/$installed does not exist."
  cp -L "$install_prefix/$installed" "$out_dir/$published"
  echo "$out_dir/$published"
done
