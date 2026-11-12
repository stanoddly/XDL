#!/usr/bin/env bash
# Prints the version of the SDL release that the index pins in external/SDL, such as 3.4.20.
# Usage: tools/sdl-version.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

(( $# == 0 )) || die "usage: sdl-version.sh"
read_sdl_version ""
echo "$sdl_version"
