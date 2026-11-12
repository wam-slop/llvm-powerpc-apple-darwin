#!/usr/bin/env bash
set -eu

prefix=${PPC_DARWIN_PREFIX:-$(cd "$(dirname "$0")/../.." && pwd)}
sdk=${1:?usage: register-sdk.sh <path to MacOSX10.5.sdk or MacOSX10.4u.sdk>}
sdk=${sdk%/}
name=$(basename "$sdk")

case $name in
    MacOSX10.5.sdk | MacOSX10.4u.sdk) ;;
    *) echo "$name: expected MacOSX10.5.sdk or MacOSX10.4u.sdk" >&2; exit 1 ;;
esac
[ -f "$sdk/usr/include/stdio.h" ] || { echo "$sdk doesn't look like an SDK" >&2; exit 1; }
[ -f "$sdk/usr/lib/libSystem.B.dylib" ] || { echo "$sdk has no libSystem.B.dylib" >&2; exit 1; }

mkdir -p "$prefix/SDKs"
rm -rf "$prefix/SDKs/$name"
cp -a "$sdk" "$prefix/SDKs/$name"
echo "$prefix/SDKs/$name"
