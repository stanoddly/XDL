#!/usr/bin/env bash
# Fails if a published library needs stock SDL, does not need XDL3, or needs a library that its platform's allowlist does not name.
# Usage: tools/check-dependencies.sh <library file>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

library=${1:?usage: check-dependencies.sh <library file>}
[[ -f "$library" ]] || die "$library does not exist."
name=$(basename "$library")

list_dlls() {
  local dumpbin
  # The Host folder differs on ARM64. Any host's dumpbin reads any architecture.
  dumpbin=$("C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe" -latest -find 'VC/Tools/MSVC/*/bin/Host*/*/dumpbin.exe' | tr -d '\r' | sed -n 1p)
  [[ -n "$dumpbin" ]] || die "vswhere found no dumpbin."
  # With a dash, because Git Bash would rewrite /dependents as a path.
  "$dumpbin" -dependents "$library" | tr -d '\r' | sed -n 's/^[[:space:]]*\([^[:space:]]*\.[dD][lL][lL]\)[[:space:]]*$/\1/p'
}

is_allowed() {
  case "$name" in
    *.so | *.so.*)
      case "$1" in
        libXDL3.so.0 | libc.so.6 | libm.so.6 | libdl.so.2 | libpthread.so.0 | librt.so.1 | libgcc_s.so.1 | libstdc++.so.6 | ld-linux-*) return 0 ;;
      esac
      ;;
    *.dylib)
      case "$1" in
        @rpath/libXDL3.0.dylib | /usr/lib/* | /System/Library/*) return 0 ;;
      esac
      ;;
    *.dll)
      case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        xdl3.dll | advapi32.dll | gdi32.dll | imm32.dll | kernel32.dll | ole32.dll | oleaut32.dll | setupapi.dll | shell32.dll | user32.dll | version.dll | winmm.dll) return 0 ;;
      esac
      ;;
  esac
  return 1
}

case "$name" in
  *.so | *.so.*)
    dependencies=$(readelf -d "$library" | sed -n 's/.*(NEEDED).*\[\(.*\)\]$/\1/p')
    ;;
  *.dylib)
    # otool -L also lists the library's own install name.
    own_name=$(otool -D "$library" | tail -n 1)
    dependencies=$(otool -L "$library" | tail -n +2 | sed -E 's/^[[:space:]]+(.*) \(compatibility.*$/\1/' | grep -vxF "$own_name" || true)
    ;;
  *.dll)
    dependencies=$(list_dlls)
    ;;
  *)
    die "$name is not a .so, .dylib or .dll file."
    ;;
esac

# Every real library needs at least libc, KERNEL32 or libSystem. An empty list means the output could not be parsed.
[[ -n "$dependencies" ]] || die "$name has no dependencies, or they could not be read."

failed=false
needs_xdl3=false
while IFS= read -r dependency; do
  [[ -n "$dependency" ]] || continue
  case "$(printf '%s' "$dependency" | tr '[:upper:]' '[:lower:]')" in
    *sdl3*)
      echo "$name needs stock SDL: $dependency" >&2
      failed=true
      continue
      ;;
    *xdl3*)
      needs_xdl3=true
      ;;
  esac
  if ! is_allowed "$dependency"; then
    echo "$name needs $dependency, which is not on the allowlist." >&2
    failed=true
  fi
done <<< "$dependencies"

# XDL3 itself is the one library that does not link against XDL3.
if [[ "$needs_xdl3" == false && ! "$name" =~ ^(lib)?XDL3(\.|$) ]]; then
  echo "$name does not need XDL3." >&2
  failed=true
fi

[[ "$failed" == false ]] || exit 1
echo "$name: ok"
