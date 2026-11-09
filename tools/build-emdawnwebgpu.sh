#!/usr/bin/env bash
# Builds what --use-port=emdawnwebgpu adds to a link, so that an app can link it from the release instead of through the port: webgpu.cpp
# compiled into <install prefix>/lib/libemdawnwebgpu.a, and the port's JavaScript libraries copied into <install prefix>/share/emdawnwebgpu/.
# The port compiles webgpu.cpp into the Emscripten cache at link time, and the cache of the .NET wasm-tools workload is read-only.
# The sources come from the port in the cache of the emcc on PATH, the one whose webgpu.h XDL3 compiles against, so both have the same
# Dawn version. tools/build-browser.sh runs this after building XDL3, which puts the port there.
# Usage: tools/build-emdawnwebgpu.sh <install prefix>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 1 )) || die "usage: build-emdawnwebgpu.sh <install prefix>"
install_prefix=$1
emcc=$(command -v emcc) || die "No emcc on PATH. Run: source tools/emsdk-env.sh"
emscripten_dir=$(dirname "$emcc")
port_dir=$("$emscripten_dir/em-config" CACHE)/ports/emdawnwebgpu/emdawnwebgpu_pkg/webgpu
[[ -f "$port_dir/src/webgpu.cpp" ]] || die "$port_dir has no src/webgpu.cpp. Build XDL3 first, which fetches the port."

# The port's flags for a build without -sASSERTIONS. Without -g, which the port relies on the link to strip. Without -sSHARED_MEMORY,
# because the .NET browser runtime is single-threaded. The exception flags of tools/build-browser.sh do not matter with -fno-exceptions.
build_dir=$repo_root/build/emdawnwebgpu
rm -rf "$build_dir"
mkdir -p "$build_dir" "$install_prefix/lib" "$install_prefix/share/emdawnwebgpu"
"$emscripten_dir/em++" -c -O2 -DNDEBUG -std=c++20 -fno-exceptions -Wall -Werror -isystem "$port_dir/include" "$port_dir/src/webgpu.cpp" \
  -o "$build_dir/webgpu.o"
rm -f "$install_prefix/lib/libemdawnwebgpu.a"
"$emscripten_dir/emar" rcs "$install_prefix/lib/libemdawnwebgpu.a" "$build_dir/webgpu.o"

# A link takes these in this order, because library_webgpu.js reads the tables of the other three.
for library in library_webgpu_enum_tables.js library_webgpu_generated_struct_info.js library_webgpu_generated_sig_info.js library_webgpu.js; do
  cp "$port_dir/src/$library" "$install_prefix/share/emdawnwebgpu/"
done

# THIRD-PARTY-NOTICES.txt carries LICENSES/emdawnwebgpu-Emscripten-MIT-NCSA.txt for webgpu.cpp and the JavaScript libraries, so this fails
# when a new port carries another license text.
diff "$port_dir/src/LICENSE" "$repo_root/LICENSES/emdawnwebgpu-Emscripten-MIT-NCSA.txt" \
  || die "The license text in $port_dir/src/LICENSE differs from LICENSES/emdawnwebgpu-Emscripten-MIT-NCSA.txt."
