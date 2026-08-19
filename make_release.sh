#!/bin/bash
# Build the octest Octave package tarball.
#
# The repository keeps the framework files at its root for
# discoverability; this script lays them out temporarily in the Octave
# package format (inst/, DESCRIPTION, COPYING), packs them into
# octest-<VERSION>.tar.gz and removes the temporary directory again.
#
# Usage: ./make_release.sh VERSION
#
# Prints the sha256 of the produced tarball, for the Octave packages
# index entry.
set -euo pipefail
cd "$(dirname "$0")"

version="${1:-}"
if [ -z "$version" ]; then
    echo "missing VERSION argument" >&2
    echo "usage: $0 VERSION" >&2
    exit 1
fi
out="octest-${version}.tar.gz"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
pkg="$stage/octest-${version}"
mkdir -p "$pkg/inst" "$pkg/doc"

# the framework sources, temporarily laid out in the package format
cp OctaveTestCase*.m runoctests.m testParams.m "$pkg/inst/"
cp docs/*.md "$pkg/doc/"
cp LICENSE "$pkg/COPYING"

cat > "$pkg/DESCRIPTION" << EOF
Name: octest
Version: ${version}
Date: $(date +%F)
Author: Roberto Moura <roberto@ffmoura.com>
Maintainer: Roberto Moura <roberto@ffmoura.com>
Title: Lightweight test framework for Octave
Description: Test runner with parameterized tests, performance measurement
 and setUp/tearDown support.  Discovers every Test_*.m file under the test
 root (TEST_ROOT or the working directory) and reports isolated verdicts
 per case, with Student-t based sampling for while tc.keepMeasuring
 performance tests.  Also runs on MATLAB.
Categories: development
License: MIT
Depends: octave (>= 6.0.0)
EOF

tar -C "$stage" -czf "$out" "octest-${version}"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$out"
else
    shasum -a 256 "$out"
fi
